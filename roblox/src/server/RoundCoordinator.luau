--!strict
-- Orchestrates the playable loop on a Roblox game server: polls /state, accepts
-- picks until OPEN closes, delta-flushes throws (5s cadence /
-- 10-pick / final flush), computes the local reveal from mirrored GameRules,
-- and reconciles authoritative per-player results on the next OPEN.
--
-- THERE IS NO LOCKOUT LEAD ANY MORE. Picks close when OPEN closes — a phase boundary the
-- server publishes — so the instant is read off `phaseEndsAt` rather than computed by
-- subtracting a constant that two files had to agree on.
local RoundCoordinator = {}
RoundCoordinator.__index = RoundCoordinator

local FLUSH_INTERVAL_MS = 5000
local FLUSH_PICK_THRESHOLD = 10

export type Callbacks = {
    onRound: ((info: any) -> ())?,
    onReveal: ((reveal: any) -> ())?,
    onReconciled: ((rows: any) -> ())?,
    onSchedule: ((sched: any) -> ())?,
}

export type Deps = {
    net: any, -- getState, getRoundResult, postThrows, getInstanceResults
    clock: any, -- addSample, hasSync, toLocalTime
    buffer: any, -- ThrowBuffer-shaped
    rules: any, -- GameRules-shaped (calculateResult)
    log: (msg: string) -> (),
    random: () -> number,
    now: () -> number, -- local epoch ms
    instanceId: string,
    callbacks: Callbacks?,
}

local VALID_THROWS = { R = true, P = true, S = true }

function RoundCoordinator.new(deps: Deps)
    return setmetatable({
        _deps = deps,
        _roundId = nil :: string?,
        _phase = nil :: string?,
        _roundCount = 0,
        _resultLogged = false,
        _lockoutAtMs = nil :: number?,
        _seq = 0,
        _lastFlushMs = nil :: number?,
        _picksClosed = false,
        _pendingReconcileRoundId = nil :: string?,
        _whiffed = {} :: { [string]: boolean },
        _publishedStrikeMs = nil :: number?,
        _publishedRoundId = nil :: string?,
    }, RoundCoordinator)
end

-- Returns (accepted, reason?). Reasons: BAD_THROW | PICKS_CLOSED | LOCKED.
function RoundCoordinator.submitPick(self: any, userId: string, throwValue: string): (boolean, string?)
    if not VALID_THROWS[throwValue] then
        return false, "BAD_THROW"
    end
    -- OPEN ONLY. This is the asymmetry that makes LOCK work: player input ends here,
    -- while _maybeFlush below keeps posting through LOCK so the picks already taken
    -- reach the server. Gating both the same way either lets players throw two seconds
    -- past the deadline or strands every buffered pick.
    if self._phase ~= "OPEN" or self._picksClosed then
        return false, "PICKS_CLOSED"
    end
    if self._lockoutAtMs and self._deps.now() >= self._lockoutAtMs then
        return false, "LOCKED"
    end
    self._deps.buffer:setPick(userId, throwValue)
    return true
end

function RoundCoordinator._flush(self: any)
    local d: Deps = self._deps
    local delta = d.buffer:takeDelta()
    if #delta == 0 then
        return
    end
    self._seq += 1
    local res = d.net:postThrows({
        instanceId = d.instanceId,
        roundId = self._roundId,
        seq = self._seq,
        throws = delta,
    })
    if res.ok then
        return
    end
    if res.error == "PICKS_CLOSED" or res.error == "ROUND_MISMATCH" then
        -- Whiff: these picks didn't make the round. Never invent results (spec §9).
        self._picksClosed = true
        for _, entry in delta do
            self._whiffed[entry.robloxUserId] = true
        end
        d.log(`[FLUSH] {#delta} pick(s) whiffed: {res.error}`)
    else
        d.buffer:requeue(delta)
        d.log(`[FLUSH] failed ({res.error or res.status}), requeued {#delta} pick(s)`)
    end
end

function RoundCoordinator._maybeFlush(self: any)
    local d: Deps = self._deps
    if (self._phase ~= "OPEN" and self._phase ~= "LOCK") or self._picksClosed then
        return
    end
    local unflushed = d.buffer:unflushedCount()
    if unflushed == 0 then
        return
    end
    local nowMs = d.now()
    -- BEING IN LOCK COUNTS AS BEING PAST THE LOCKOUT — see both `pastLockout` lines below.
    -- LOCK is 2s and exists precisely to get whatever is buffered out the door; picks already
    -- closed with OPEN, so waiting on the 5s cadence would strand them.
    --
    -- The phase test is not merely a shortcut for the clock test. `_lockoutAtMs` is only ever
    -- assigned when `d.clock:hasSync()` is true, so on a server whose clock never synced it stays
    -- nil and `nowMs >= _lockoutAtMs` can never fire — a pick taken in OPEN's last 5s would then
    -- sit unflushed through LOCK and be destroyed by `clearRound()` at the boundary. The
    -- server-published phase is the authoritative signal; the clock is the local estimate.
    if self._lastFlushMs == nil then
        -- First sighting of picks this round: start the cadence clock.
        -- Still check threshold/lockout triggers immediately before returning.
        self._lastFlushMs = nowMs
        local pastLockout = self._phase == "LOCK" or (self._lockoutAtMs ~= nil and nowMs >= self._lockoutAtMs)
        if unflushed >= FLUSH_PICK_THRESHOLD or pastLockout then
            self._lastFlushMs = nowMs
            self:_flush()
        end
        return
    end
    local elapsed = nowMs - self._lastFlushMs
    local pastLockout = self._phase == "LOCK" or (self._lockoutAtMs ~= nil and nowMs >= self._lockoutAtMs)
    if elapsed >= FLUSH_INTERVAL_MS or unflushed >= FLUSH_PICK_THRESHOLD or pastLockout then
        self._lastFlushMs = nowMs
        self:_flush()
    end
end

function RoundCoordinator._fetchRevealIfDue(self: any, state: any)
    local d: Deps = self._deps
    if not (state.phase == "LOCK" or state.phase == "REVEAL") or self._resultLogged then
        return
    end
    local result = d.net:getRoundResult(self._roundId)
    if not result.ok then
        if not result.notReady then
            d.log(`[RESULT] fetch failed: {result.error or result.status}`)
        end
        return -- latch stays open; next poll retries
    end
    self._resultLogged = true
    local r = result.data
    d.log(
        `[ROUND {self._roundCount}] WORLD THROW: {r.worldThrow}`
            .. ` | R {r.distribution.R}% P {r.distribution.P}% S {r.distribution.S}%`
            .. ` | players {r.totalPlayers}`
    )
    local results: { [string]: any } = {}
    for userId, pick in d.buffer:picks() do
        if not self._whiffed[userId] then
            results[userId] = { pick = pick, result = d.rules.calculateResult(pick, r.worldThrow) }
        end
    end
    if d.callbacks and d.callbacks.onReveal then
        d.callbacks.onReveal({
            roundId = self._roundId,
            worldThrow = r.worldThrow,
            distribution = r.distribution,
            totalPlayers = r.totalPlayers,
            results = results,
            whiffed = self._whiffed,
        })
    end
end

function RoundCoordinator._reconcileIfDue(self: any)
    local d: Deps = self._deps
    if not self._pendingReconcileRoundId or self._phase ~= "OPEN" then
        return
    end
    local res = d.net:getInstanceResults(d.instanceId, self._pendingReconcileRoundId)
    if res.ok then
        d.log(`[RECON] round {self._pendingReconcileRoundId}: {#res.data} row(s)`)
        if d.callbacks and d.callbacks.onReconciled then
            d.callbacks.onReconciled(res.data)
        end
        self._pendingReconcileRoundId = nil
    elseif not res.notReady then
        d.log(`[RECON] failed for {self._pendingReconcileRoundId}: {res.error or res.status}`)
        self._pendingReconcileRoundId = nil -- hard failure: don't retry forever
    end
end

function RoundCoordinator.pollOnce(self: any): number
    local d: Deps = self._deps
    local res = d.net:getState()
    if not res.ok then
        d.log(`[NET] state failed: {res.error or res.status}`)
        return 3
    end

    local state = res.data
    d.clock:addSample(state.serverTime, res.rttMs, res.localReceiveMs)

    if state.roundId ~= self._roundId then
        if self._roundId and next(d.buffer:picks()) ~= nil then
            self._pendingReconcileRoundId = self._roundId
        end
        d.buffer:clearRound()
        self._roundId = state.roundId
        self._roundCount = state.roundCount
        self._phase = nil
        self._resultLogged = false
        self._lockoutAtMs = nil
        self._seq = 0
        self._lastFlushMs = nil
        self._picksClosed = false
        self._whiffed = {}
    end

    -- The lockout IS the end of OPEN. The durable invariant is `lockout = strike - lockMs`
    -- — true whatever OPEN's own duration is tuned to — read off the schedule instead of
    -- inferred from it.
    if state.phase == "OPEN" and d.clock:hasSync() then
        self._lockoutAtMs = d.clock:toLocalTime(state.phaseEndsAt)
    end

    if state.phase ~= self._phase then
        self._phase = state.phase
        d.log(`[ROUND {self._roundCount}] {self._roundId} {state.phase}`)
        if d.callbacks and d.callbacks.onRound then
            local secondsToLockout: number? = nil
            if state.phase == "OPEN" and self._lockoutAtMs then
                secondsToLockout = math.max(0, (self._lockoutAtMs - d.now()) / 1000)
            end
            d.callbacks.onRound({
                roundId = self._roundId,
                phase = state.phase,
                roundCount = self._roundCount,
                secondsToLockout = secondsToLockout,
                tape = state.tape,
            })
        end
    end

    -- Publish the round's absolute schedule (round-metronome spec): the strike is
    -- reveal start = end of OPEN + the whole of LOCK. Republish on roundId change or
    -- when sync refinement moves the strike > 150ms; clients slew, so small edits are cheap.
    local dur = state.durations
    if dur and d.clock:hasSync() then
        local endLocal = d.clock:toLocalTime(state.phaseEndsAt)
        local strikeAtMs
        if state.phase == "OPEN" then
            strikeAtMs = endLocal + dur.lockMs
        elseif state.phase == "LOCK" then
            strikeAtMs = endLocal
        else -- REVEAL: the NEXT round's strike
            strikeAtMs = endLocal + dur.openMs + dur.lockMs
        end
        if
            self._publishedStrikeMs == nil
            or self._publishedRoundId ~= state.roundId
            or math.abs(strikeAtMs - self._publishedStrikeMs) > 150
        then
            self._publishedStrikeMs = strikeAtMs
            self._publishedRoundId = state.roundId
            if d.callbacks and d.callbacks.onSchedule then
                d.callbacks.onSchedule({
                    roundId = state.roundId,
                    roundCount = state.roundCount,
                    strikeAtMs = strikeAtMs,
                    periodMs = dur.openMs + dur.lockMs + dur.revealMs,
                    openMs = dur.openMs,
                    lockMs = dur.lockMs,
                    revealMs = dur.revealMs,
                })
            end
        end
    end

    self:_maybeFlush()
    self:_fetchRevealIfDue(state)
    self:_reconcileIfDue()

    return 1 + d.random() * 0.25
end

return RoundCoordinator
