--!strict
-- THE STATS ROOM'S FEED. Extracted verbatim out of main.server.luau 2026-09-06 (server-file
-- split, phase one, task 3) -- the state (`lastStats`, `lastTape`, `lastTapeId`, the name-filter
-- memo), the 47s stats poller, the personal slip and its 60s loop, and the join push. Nothing
-- about the behaviour changed; the only edits were turning the entry file's top-level locals into
-- fields of this object and taking its Roblox services and neighbours by injection.
--
-- Runtime adapter: every loop in here yields on HTTP and fires RemoteEvents, so it has no Lune
-- spec of its own. The part that CAN be tested off-Roblox is the shape-walking the payloads go
-- through on their way to the wire, and that lives in ReplicatedStorage.RoshamboShared.StatsFilters
-- (specced in tests/StatsFilters.spec.luau). This file builds one of those over its cached filter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatsFilters = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("StatsFilters"))

local StatsFeed = {}
StatsFeed.__index = StatsFeed

export type Deps = {
    net: any,
    -- The EXTERNAL-name filter itself (TextService), taken by injection because it yields and
    -- needs a player present; the memo of its results is this object's own.
    filterName: (name: string) -> string,
    fireAll: (payload: any) -> (),
    fireTo: (player: Player, payload: any) -> (),
    firePersonal: (player: Player, payload: any) -> (),
    players: Players,
    task: any,
    getRosterEntry: (uid: string) -> any,
    setRosterEntry: (uid: string, entry: any) -> (),
    pushRoster: () -> (),
}

function StatsFeed.new(deps: Deps)
    -- FIX 4: names in leaders/recordsWeek/recordsAll/heat are EXTERNAL (player-chosen display
    -- names) and this feed broadcasts to every client, world-visible on the Stats room's walls —
    -- unlike the pushStatsPersonal 404 fallback below, which sends a name Roblox has already
    -- moderated. StatsBoardModel.sanitize is not a substitute: it only uppercases and strips
    -- non-ASCII, so ASCII abuse (still filterable, still offensive) passes straight through.
    --
    -- Cached by raw name so a name that keeps ranking round after round costs one filter call, not
    -- one per 60s cycle. UNBOUNDED on purpose: the key space is the set of names that have ever
    -- ranked into a top-10 (leaderboard, streak/bank/round records, or heat) — small next to the
    -- player population, and this table lives only for the game server's process lifetime anyway.
    local nameFilterCache: { [string]: string } = {}
    local function cachedFilterName(name: string): string
        local cached = nameFilterCache[name]
        if cached then
            return cached
        end
        local filtered = deps.filterName(name)
        nameFilterCache[name] = filtered
        return filtered
    end

    return setmetatable({
        _d = deps,
        _filters = StatsFilters.new(cachedFilterName),
        _lastStats = nil :: any,
        _lastTape = {} :: any,
        _lastTapeId = nil :: string?,
    }, StatsFeed)
end

-- The last broadcast stats payload, or nil before the first poll lands. The round callback in the
-- entry file re-broadcasts it with a fresh tape the instant a round settles, which is why this
-- object is built long before :start() is called.
function StatsFeed:current(): any?
    return self._lastStats
end

-- The last round tape. Never nil: it starts as an empty list, so callers index it directly.
function StatsFeed:tape(): any
    return self._lastTape
end

-- Records the newest tape and returns whether it GREW (a new newest id), which is the entry file's
-- gate on re-broadcasting: `onRound` fires on each phase change, but the tape only grows at
-- settlement.
function StatsFeed:setTape(tape: any, id: string?): boolean
    local grew = id ~= self._lastTapeId
    self._lastTape = tape
    self._lastTapeId = id
    return grew
end

-- The personal slip. Per-player, so it is pushed per-player: on join, and on the same 60s beat.
--
-- ⚠ IT ALSO FEEDS THE ROSTER, AT NO EXTRA COST. The status bars over a player's head need that
-- player's GRADE and RANK, and this response already carries both — so harvesting them here means
-- the bars refresh on a beat that already exists rather than adding a per-player request per
-- round. Rank moves as OTHER people play, so it genuinely needs refreshing; grade only ever
-- increases and only for its owner, which is why a join-time snapshot was enough for it alone.
function StatsFeed:pushPersonal(player: Player)
    local deps = self._d
    local res = deps.net:getStatsPlayer(tostring(player.UserId))
    -- A 404 is the NORMAL state for someone who has never thrown. Send the empty shape rather
    -- than nothing, so the slip renders its zeros instead of hanging on "no data".
    deps.firePersonal(player, if res.ok then res.data else { displayName = player.DisplayName })
    if res.ok then
        local d = res.data
        local standing = d.week and d.week.standing
        local entry = deps.getRosterEntry(tostring(player.UserId)) or {}
        entry.grade = d.grade or entry.grade
        entry.gradeName = d.gradeName or entry.gradeName
        entry.band = d.band or entry.band
        -- ABSENT, not zero, when unqualified: the bar's absence is itself information — this
        -- player has not put in the 360 throws to be measured at all.
        entry.rank = standing and standing.rank or nil
        entry.of = standing and standing.of or nil
        deps.setRosterEntry(tostring(player.UserId), entry)
        deps.pushRoster()
    end
end

function StatsFeed:onJoin(player: Player)
    local deps = self._d
    if self._lastStats then
        deps.fireTo(player, self._lastStats) -- re-fire is an idempotent client update
    end
    deps.task.spawn(function()
        self:pushPersonal(player)
    end)
end

-- Called at the exact point in the entry file where this machinery used to run inline, so the
-- PlayerAdded connect below keeps its place in that file's connect order.
function StatsFeed:start()
    local deps = self._d
    local filters = self._filters

    -- THE STATS ROOM'S FEED. Separate from the BoardData poller above on purpose: that one is the
    -- arena's 30s heartbeat and these are four REST reads whose own Cache-Control is 15-30s, so
    -- pulling them on the same tick would triple the arena's request rate for walls nobody may be
    -- standing in front of. 60s is slower than any of the caches and still far finer than the
    -- cadence at which a career board actually moves.
    deps.task.spawn(function()
        while true do
            local leaders = deps.net:getLeaderboards("world")
            local week = deps.net:getStatsRecords("week")
            local all = deps.net:getStatsRecords("all")
            local heat = deps.net:getStatsHeat("day", nil)
            local board = deps.net:getStatsBoard()
            -- Each field is independently nil-able: one endpoint failing must leave the other three
            -- boards showing their last good content rather than blanking the whole room.
            self._lastStats = {
                leaders = if leaders.ok
                    then filters.top(leaders.data.leaders)
                    else (self._lastStats and self._lastStats.leaders),
                recordsWeek = if week.ok
                    then filters.records(week.data)
                    else (self._lastStats and self._lastStats.recordsWeek),
                recordsAll = if all.ok
                    then filters.records(all.data)
                    else (self._lastStats and self._lastStats.recordsAll),
                heat = if heat.ok
                    then filters.heat(heat.data)
                    else (self._lastStats and self._lastStats.heat),
                board = if board.ok
                    then filters.board(board.data)
                    else (self._lastStats and self._lastStats.board),
                depths = if board.ok then board.data.depths else (self._lastStats and self._lastStats.depths),
                tape = self._lastTape,
            }
            deps.fireAll(self._lastStats)
            -- 47, NOT 60. A 60s wait is exactly the round period (OPEN 51 + LOCK 2 +
            -- REVEAL 7), so the poll would alias with the round and refresh the slow
            -- boards at the same phase offset forever. 47 still clears the 30s and 15s
            -- Cache-Control windows on the endpoints it reads.
            deps.task.wait(47)
        end
    end)

    local function onPlayerJoinStats(player: Player)
        self:onJoin(player)
    end
    deps.players.PlayerAdded:Connect(onPlayerJoinStats)
    for _, p in deps.players:GetPlayers() do
        deps.task.spawn(onPlayerJoinStats, p) -- defect (n): catch a join that landed before this connect
    end

    deps.task.spawn(function()
        while true do
            deps.task.wait(60)
            for _, player in deps.players:GetPlayers() do
                deps.task.spawn(function()
                    self:pushPersonal(player)
                end)
            end
        end
    end)
end

return StatsFeed
