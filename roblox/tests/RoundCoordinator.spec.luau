--!strict
local harness = require("./harness")
local RoundCoordinator = require("../src/server/RoundCoordinator")
local ThrowBuffer = require("../src/server/ThrowBuffer")
local GameRules = require("../src/shared/GameRules")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function makeFakes(
    states: { any },
    results: { any },
    opts: { nows: { number }?, instanceResults: { any }? }
)
    local logs: { string } = {}
    local postCalls: { any } = {}
    local instanceCalls: { any } = {}
    local stateIdx, resultIdx, instanceIdx = 0, 0, 0
    local nowIdx = 0
    local nows = opts and opts.nows
    local instanceResults = opts and opts.instanceResults or {}
    local clockSamples = 0
    return {
        logs = logs,
        postCalls = postCalls,
        instanceCalls = instanceCalls,
        net = {
            getState = function(_self): any
                stateIdx = math.min(stateIdx + 1, #states)
                return states[stateIdx]
            end,
            getRoundResult = function(_self, _roundId: string): any
                resultIdx = math.min(resultIdx + 1, #results)
                return results[resultIdx]
            end,
            postThrows = function(_self, batch: any): any
                table.insert(postCalls, batch)
                return { ok = true, data = { accepted = #batch.throws, rejected = {} } }
            end,
            getInstanceResults = function(_self, instanceId: string, roundId: string): any
                table.insert(instanceCalls, { instanceId = instanceId, roundId = roundId })
                instanceIdx = math.min(instanceIdx + 1, math.max(#instanceResults, 1))
                return instanceResults[instanceIdx] or { ok = true, data = {} }
            end,
        },
        clock = {
            addSample = function(_self, _st, _rtt, _lr)
                clockSamples += 1
            end,
            hasSync = function(_self)
                return true
            end,
            toLocalTime = function(_self, serverMs: number)
                return serverMs -- identity: tests use one epoch for both clocks
            end,
            samples = function()
                return clockSamples
            end,
        },
        now = function(): number
            if nows then
                nowIdx = math.min(nowIdx + 1, #nows)
                return nows[nowIdx]
            end
            return 0
        end,
        log = function(msg: string)
            table.insert(logs, msg)
        end,
        random = function()
            return 0
        end,
    }
end

local function makeCoordinator(f: any, callbacks: any?)
    return RoundCoordinator.new({
        net = f.net :: any,
        clock = f.clock :: any,
        buffer = ThrowBuffer.new(),
        rules = GameRules,
        log = f.log,
        random = f.random,
        now = f.now,
        instanceId = "job-T",
        callbacks = callbacks,
    })
end

local function okState(roundId: string, phase: string, roundCount: number, phaseEndsAt: number?)
    return {
        ok = true,
        data = {
            roundId = roundId,
            phase = phase,
            roundCount = roundCount,
            serverTime = 1,
            phaseEndsAt = phaseEndsAt or 100000,
        },
        rttMs = 10,
        localReceiveMs = 1,
    }
end

describe("RoundCoordinator.pollOnce", function()
    test("logs new round and phase, feeds the clock", function()
        local f = makeFakes({ okState("r1", "ACTIVE", 7) }, {}, {})
        local c = makeCoordinator(f)
        local delay = c:pollOnce()
        expect(#f.logs).toBe(1)
        expect(f.logs[1]).toBe("[ROUND 7] r1 ACTIVE")
        expect(f.clock.samples()).toBe(1)
        expect(delay).toBe(1) -- 1s + jitter(0)
    end)

    test("logs each phase change once, not on repeat polls", function()
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7), okState("r1", "ACTIVE", 7), okState("r1", "TALLY", 7) },
            {
                {
                    ok = true,
                    data = { worldThrow = "S", distribution = { R = 100, P = 0, S = 0 }, totalPlayers = 1 },
                },
            },
            {}
        )
        local c = makeCoordinator(f)
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        expect(f.logs[1]).toBe("[ROUND 7] r1 ACTIVE")
        expect(f.logs[2]).toBe("[ROUND 7] r1 TALLY")
        expect(f.logs[3]).toBe("[ROUND 7] WORLD THROW: S | R 100% P 0% S 0% | players 1")
        expect(#f.logs).toBe(3)
    end)

    test("fetches the result exactly once per round even across REVEAL polls", function()
        local f = makeFakes(
            { okState("r1", "TALLY", 7), okState("r1", "REVEAL", 7), okState("r1", "REVEAL", 7) },
            {
                {
                    ok = true,
                    data = { worldThrow = "P", distribution = { R = 0, P = 100, S = 0 }, totalPlayers = 2 },
                },
            },
            {}
        )
        local c = makeCoordinator(f)
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        local resultLogs = 0
        for _, l in f.logs do
            if l:find("WORLD THROW") then
                resultLogs += 1
            end
        end
        expect(resultLogs).toBe(1)
    end)

    test("notReady result retries on the next poll", function()
        local f = makeFakes({ okState("r1", "TALLY", 7), okState("r1", "REVEAL", 7) }, {
            { ok = false, notReady = true },
            {
                ok = true,
                data = { worldThrow = "R", distribution = { R = 0, P = 0, S = 0 }, totalPlayers = 0 },
            },
        }, {})
        local c = makeCoordinator(f)
        c:pollOnce()
        c:pollOnce()
        local found = false
        for _, l in f.logs do
            if l:find("WORLD THROW: R") then
                found = true
            end
        end
        expect(found).toBe(true)
    end)

    test("state failure logs and backs off harder", function()
        local f = makeFakes({ { ok = false, error = "TRANSPORT_FAILED" } }, {}, {})
        local c = makeCoordinator(f)
        local delay = c:pollOnce()
        expect(f.logs[1]).toBe("[NET] state failed: TRANSPORT_FAILED")
        expect(delay).toBe(3)
    end)

    test("a new roundId resets the per-round result latch", function()
        local f = makeFakes(
            { okState("r1", "REVEAL", 7), okState("r2", "ACTIVE", 8), okState("r2", "TALLY", 8) },
            {
                {
                    ok = true,
                    data = { worldThrow = "S", distribution = { R = 0, P = 0, S = 0 }, totalPlayers = 0 },
                },
                {
                    ok = true,
                    data = { worldThrow = "R", distribution = { R = 0, P = 0, S = 0 }, totalPlayers = 0 },
                },
            },
            {}
        )
        local c = makeCoordinator(f)
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        local throws = {}
        for _, l in f.logs do
            local w = l:match("WORLD THROW: (%a)")
            if w then
                table.insert(throws, w)
            end
        end
        expect(throws).toEqual({ "S", "R" })
    end)
end)

describe("RoundCoordinator v2 picks + flush", function()
    test("accepts a pick during ACTIVE before lockout; rejects after lockout", function()
        -- phaseEndsAt 30000 -> lockout 28000. The nows queue feeds submitPick's
        -- lockout checks (pollOnce consumes no now() when there are no picks):
        -- first submit sees 0 (< 28000, accepted), second sees 29000 (locked).
        local f = makeFakes({ okState("r1", "ACTIVE", 7, 30000) }, {}, { nows = { 0, 29000 } })
        local c = makeCoordinator(f)
        c:pollOnce()
        local ok1 = c:submitPick("9", "R")
        expect(ok1).toBe(true)
        local ok2, reason = c:submitPick("9", "P")
        expect(ok2).toBe(false)
        expect(reason).toBe("LOCKED")
    end)

    test("rejects picks outside ACTIVE and invalid throws", function()
        local f = makeFakes({ okState("r1", "TALLY", 7) }, { { ok = false, notReady = true } }, {})
        local c = makeCoordinator(f)
        c:pollOnce()
        local ok, reason = c:submitPick("9", "R")
        expect(ok).toBe(false)
        expect(reason).toBe("PICKS_CLOSED")
        local ok2, reason2 = c:submitPick("9", "X")
        expect(ok2).toBe(false)
        expect(reason2).toBe("BAD_THROW")
    end)

    test("flushes on the 5s cadence with incrementing seq", function()
        -- now() consumption: submitPick takes 0; the next poll's flush check takes
        -- 1000 (becomes the cadence baseline, no flush); the last takes 6500
        -- (5.5s elapsed -> flush). Polls with zero unflushed picks consume no now().
        local f = makeFakes({
            okState("r1", "ACTIVE", 7, 99000),
            okState("r1", "ACTIVE", 7, 99000),
            okState("r1", "ACTIVE", 7, 99000),
        }, {}, { nows = { 0, 1000, 6500 } })
        local c = makeCoordinator(f)
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R") -- now=0
        c:pollOnce() -- now=1000: becomes baseline -> no flush
        expect(#f.postCalls).toBe(0)
        c:pollOnce() -- now=6500: 5.5s since baseline -> flush
        expect(#f.postCalls).toBe(1)
        expect(f.postCalls[1].seq).toBe(1)
        expect(f.postCalls[1].roundId).toBe("r1")
        expect(f.postCalls[1].instanceId).toBe("job-T")
        expect(f.postCalls[1].throws[1].robloxUserId).toBe("9")
    end)

    test("flushes immediately when 10 picks accumulate", function()
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 99000), okState("r1", "ACTIVE", 7, 99000) },
            {},
            { nows = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1000 } }
        )
        local c = makeCoordinator(f)
        c:pollOnce()
        for i = 1, 10 do
            c:submitPick(tostring(i), "R")
        end
        c:pollOnce() -- only ~1s elapsed but 10 picks -> flush
        expect(#f.postCalls).toBe(1)
        expect(#f.postCalls[1].throws).toBe(10)
    end)

    test("final flush fires once past lockout even under the 5s cadence", function()
        -- lockout = 10000-2000 = 8000. submitPick sees 4000; next poll's flush
        -- check sees 4500 (baseline, no flush); last poll sees 8100 >= lockout -> flush.
        local f = makeFakes({
            okState("r1", "ACTIVE", 7, 10000),
            okState("r1", "ACTIVE", 7, 10000),
            okState("r1", "ACTIVE", 7, 10000),
        }, {}, { nows = { 4000, 4500, 8100 } })
        local c = makeCoordinator(f)
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R") -- now=4000
        c:pollOnce() -- now=4500: baseline, 1 pick, before lockout -> no flush
        expect(#f.postCalls).toBe(0)
        c:pollOnce() -- now=8100 >= lockout 8000 -> final flush
        expect(#f.postCalls).toBe(1)
    end)

    test("transport-failed flush requeues the delta for the next poll", function()
        -- submitPick sees 0; flush-check nows: 1000 (baseline), 7000 (flush 1, fails,
        -- baseline moves to 7000), 13000 (flush 2 succeeds with the requeued pick).
        local f = makeFakes({
            okState("r1", "ACTIVE", 7, 99000),
            okState("r1", "ACTIVE", 7, 99000),
            okState("r1", "ACTIVE", 7, 99000),
        }, {}, { nows = { 0, 1000, 7000, 13000 } })
        f.net.postThrows = function(_self, batch: any): any
            table.insert(f.postCalls, batch)
            if #f.postCalls == 1 then
                return { ok = false, error = "TRANSPORT_FAILED" }
            end
            return { ok = true, data = { accepted = #batch.throws, rejected = {} } }
        end
        local c = makeCoordinator(f)
        c:pollOnce() -- no picks: consumes no now()
        c:submitPick("9", "R")
        c:pollOnce() -- baseline, no flush
        c:pollOnce() -- flush 1 fails -> requeue
        c:pollOnce() -- flush 2 retries the same pick with a higher seq
        expect(#f.postCalls).toBe(2)
        expect(f.postCalls[2].throws[1].robloxUserId).toBe("9")
        expect(f.postCalls[2].seq).toBe(2)
    end)
end)

describe("RoundCoordinator v2 reveal + reconciliation", function()
    test("reveal computes per-player local results and fires onReveal once", function()
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7, 99000), okState("r1", "TALLY", 7), okState("r1", "REVEAL", 7) },
            {
                {
                    ok = true,
                    data = { worldThrow = "S", distribution = { R = 50, P = 50, S = 0 }, totalPlayers = 2 },
                },
            },
            { nows = { 0, 1, 2, 1000, 2000 } }
        )
        local reveals: { any } = {}
        local c = makeCoordinator(f, {
            onReveal = function(r: any)
                table.insert(reveals, r)
            end,
        })
        c:pollOnce()
        c:submitPick("9", "R") -- beats S -> WIN
        c:submitPick("10", "P") -- loses to S -> LOSS
        c:pollOnce() -- TALLY: result fetched, reveal fired
        c:pollOnce() -- REVEAL: no second fire
        expect(#reveals).toBe(1)
        expect(reveals[1].worldThrow).toBe("S")
        expect(reveals[1].results["9"].result).toBe("WIN")
        expect(reveals[1].results["9"].pick).toBe("R")
        expect(reveals[1].results["10"].result).toBe("LOSS")
    end)

    test("whiffed picks are excluded from local reveal results (never invent results)", function()
        -- Player 9 flushes successfully (cadence); player 10 picks late and the
        -- final lockout-triggered flush whiffs (PICKS_CLOSED). Reveal must not
        -- include player 10 (spec §9 – server never invents results).
        --
        -- nows queue consumption:
        --   submitPick("9","R")  -> now[1]=0    (lockout check)
        --   pollOnce() picks>0, _lastFlushMs nil -> now[2]=1000 (baseline, no flush)
        --   pollOnce() elapsed 6000 >= 5000     -> now[3]=7000 (cadence flush #1 SUCCEEDS)
        --   submitPick("10","P") -> now[4]=7500  (lockout check, 7500<8000 accepted)
        --   pollOnce() pastLockout 8100>=8000   -> now[5]=8100 (final flush WHIFFS)
        --   pollOnce() TALLY: no picks->no now()
        local f = makeFakes({
            okState("r1", "ACTIVE", 7, 10000),
            okState("r1", "ACTIVE", 7, 10000),
            okState("r1", "ACTIVE", 7, 10000),
            okState("r1", "ACTIVE", 7, 10000),
            okState("r1", "TALLY", 7),
        }, {
            {
                ok = true,
                data = { worldThrow = "S", distribution = { R = 100, P = 0, S = 0 }, totalPlayers = 1 },
            },
        }, { nows = { 0, 1000, 7000, 7500, 8100 } })
        local postCount = 0
        f.net.postThrows = function(_self, batch: any): any
            postCount += 1
            table.insert(f.postCalls, batch)
            if postCount == 1 then
                return { ok = true, data = { accepted = #batch.throws, rejected = {} } }
            end
            return { ok = false, status = 409, error = "PICKS_CLOSED" }
        end
        local reveals: { any } = {}
        local c = makeCoordinator(f, {
            onReveal = function(r: any)
                table.insert(reveals, r)
            end,
        })
        c:pollOnce() -- ACTIVE, no picks: consumes no now()
        c:submitPick("9", "R") -- now=0; R beats S -> WIN
        c:pollOnce() -- now=1000: baseline set, no flush
        c:pollOnce() -- now=7000: elapsed 6000 >= 5000 -> flush #1 (player 9) SUCCEEDS
        c:submitPick("10", "P") -- now=7500 < lockout 8000 -> accepted
        c:pollOnce() -- now=8100 >= lockout 8000 -> final flush (player 10) WHIFFS
        c:pollOnce() -- TALLY: reveal fires
        expect(#reveals).toBe(1)
        expect(reveals[1].results["9"].result).toBe("WIN")
        expect(reveals[1].results["10"]).toBeNil() -- whiffed: must not invent a result
    end)

    test("reconciliation fetches instance results on the next ACTIVE and passes rows through", function()
        local rows = { { robloxUserId = "9", result = "WIN", totalPoints = 0, pot = 1, streak = 1 } }
        local f = makeFakes({
            okState("r1", "ACTIVE", 7, 99000),
            okState("r1", "REVEAL", 7),
            okState("r2", "ACTIVE", 8, 99000),
        }, {
            {
                ok = true,
                data = { worldThrow = "S", distribution = { R = 100, P = 0, S = 0 }, totalPlayers = 1 },
            },
        }, { nows = { 0, 1, 1000, 2000, 3000 }, instanceResults = { { ok = true, data = rows } } })
        local reconciled: { any } = {}
        local c = makeCoordinator(f, {
            onReconciled = function(r: any)
                table.insert(reconciled, r)
            end,
        })
        c:pollOnce()
        c:submitPick("9", "R")
        c:pollOnce() -- REVEAL for r1
        c:pollOnce() -- r2 ACTIVE: reconciliation for r1 fires
        expect(#f.instanceCalls).toBe(1)
        expect(f.instanceCalls[1].roundId).toBe("r1")
        expect(#reconciled).toBe(1)
        expect(reconciled[1][1].robloxUserId).toBe("9")
    end)
end)
