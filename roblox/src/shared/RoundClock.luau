--!strict
-- Estimates the offset between local clock and the game server's clock from
-- /state samples. Keeps the lowest-RTT sample (Cristian's algorithm): a
-- routing spike inflates RTT, so spiked samples are discarded rather than
-- averaged in. Design tolerance is seconds (spec §4), so RTT/2 asymmetry
-- error is immaterial.
local RoundClock = {}
RoundClock.__index = RoundClock

export type RoundClock = typeof(setmetatable({} :: { _offsetMs: number?, _bestRttMs: number }, RoundClock))

function RoundClock.new(): RoundClock
    return setmetatable({ _offsetMs = nil :: number?, _bestRttMs = math.huge }, RoundClock)
end

function RoundClock.addSample(self: RoundClock, serverTimeMs: number, rttMs: number, localReceiveMs: number)
    if rttMs < self._bestRttMs then
        self._bestRttMs = rttMs
        self._offsetMs = (serverTimeMs + rttMs / 2) - localReceiveMs
    end
end

function RoundClock.hasSync(self: RoundClock): boolean
    return self._offsetMs ~= nil
end

function RoundClock.toServerTime(self: RoundClock, localMs: number): number
    assert(self._offsetMs, "RoundClock has no sync yet")
    return localMs + self._offsetMs
end

function RoundClock.toLocalTime(self: RoundClock, serverMs: number): number
    assert(self._offsetMs, "RoundClock has no sync yet")
    return serverMs - self._offsetMs
end

function RoundClock.reset(self: RoundClock)
    self._offsetMs = nil
    self._bestRttMs = math.huge
end

return RoundClock
