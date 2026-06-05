--!strict
-- Walking-skeleton coordinator: polls /state ~1Hz, feeds the RoundClock,
-- logs round/phase transitions, and fetches each round's result exactly once
-- when it enters TALLY/REVEAL. Throw submission arrives in milestone 3.
local RoundCoordinator = {}
RoundCoordinator.__index = RoundCoordinator

export type Deps = {
    net: any, -- NetworkClient-shaped: getState, getRoundResult
    clock: any, -- RoundClock-shaped: addSample
    log: (msg: string) -> (),
    random: () -> number, -- [0,1) for poll jitter
}

function RoundCoordinator.new(deps: Deps)
    return setmetatable({
        _deps = deps,
        _roundId = nil :: string?,
        _phase = nil :: string?,
        _roundCount = 0,
        _resultLogged = false,
    }, RoundCoordinator)
end

-- Returns the suggested delay (seconds) until the next poll.
function RoundCoordinator.pollOnce(self: any): number
    local d: Deps = self._deps
    local res = d.net:getState()
    if not res.ok then
        d.log(`[NET] state failed: {res.error or res.status}`)
        return 3 -- back off harder when the server is unreachable
    end

    local state = res.data
    d.clock:addSample(state.serverTime, res.rttMs, res.localReceiveMs)

    if state.roundId ~= self._roundId then
        self._roundId = state.roundId
        self._roundCount = state.roundCount
        self._phase = nil
        self._resultLogged = false
    end

    if state.phase ~= self._phase then
        self._phase = state.phase
        d.log(`[ROUND {self._roundCount}] {self._roundId} {state.phase}`)
    end

    if (state.phase == "TALLY" or state.phase == "REVEAL") and not self._resultLogged then
        local result = d.net:getRoundResult(self._roundId)
        if result.ok then
            self._resultLogged = true
            local r = result.data
            d.log(
                `[ROUND {self._roundCount}] WORLD THROW: {r.worldThrow}`
                    .. ` | R {r.distribution.R}% P {r.distribution.P}% S {r.distribution.S}%`
                    .. ` | players {r.totalPlayers}`
            )
        end
        -- notReady: leave the latch open; next poll retries
    end

    return 1 + d.random() * 0.25
end

return RoundCoordinator
