--!strict
-- The single client-side round timeline (spec: 2026-07-23-round-metronome-design).
-- Pure and clock-agnostic: callers pass `now` in seconds (GetServerTimeNow at
-- runtime, plain numbers in tests). Slew-not-snap: schedule refinements within
-- SLEW_TOLERANCE bend the effective timeline at SLEW_RATE so gear rotation never
-- steps; larger shifts (server restart, new period) hard re-anchor.
local RoundMetronome = {}
RoundMetronome.__index = RoundMetronome

local SLEW_TOLERANCE = 2.0 -- seconds; beyond this, snap
local SLEW_RATE = 0.05 -- seconds of correction per second of wall time

export type Schedule = {
    roundId: string?,
    strikeAt: number,
    periodSec: number,
    activeSec: number,
    tallySec: number,
    revealSec: number,
}

export type Reading = {
    drawP: number,
    camAngle: number,
    omega: number,
    periodSec: number,
    prevStrikeAt: number,
    nextStrikeAt: number,
}

function RoundMetronome.new()
    return setmetatable({
        _strikeAt = nil :: number?,
        _targetStrikeAt = nil :: number?,
        _periodSec = nil :: number?,
        _activeSec = 0,
        _tallySec = 0,
        _revealSec = 0,
        _lastNow = nil :: number?,
    }, RoundMetronome)
end

-- Strike instants tile every period: map the incoming anchor into the congruence
-- class nearest the current one, so a next-round schedule isn't read as a shift.
local function nearest(strikeAt: number, period: number, ref: number): number
    return strikeAt + math.round((ref - strikeAt) / period) * period
end

function RoundMetronome.setSchedule(self: any, sched: Schedule, _now: number)
    self._activeSec = sched.activeSec
    self._tallySec = sched.tallySec
    self._revealSec = sched.revealSec
    if self._strikeAt == nil or self._periodSec ~= sched.periodSec then
        -- first schedule, or a period change (e.g. the 20s->60s launch): adopt
        self._strikeAt = sched.strikeAt
        self._targetStrikeAt = sched.strikeAt
        self._periodSec = sched.periodSec
        return
    end
    local target = nearest(sched.strikeAt, sched.periodSec, self._strikeAt)
    if math.abs(target - self._strikeAt) > SLEW_TOLERANCE then
        self._strikeAt = sched.strikeAt -- hard re-anchor (restart / discontinuity)
        self._targetStrikeAt = sched.strikeAt
    else
        self._targetStrikeAt = target -- converge inside read()
    end
end

function RoundMetronome.read(self: any, now: number): Reading?
    local period: number? = self._periodSec
    local strike: number? = self._strikeAt
    if period == nil or strike == nil then
        return nil
    end
    local target: number = self._targetStrikeAt or strike
    if target ~= strike then
        local dt = math.max(0, now - (self._lastNow or now))
        local maxStep = SLEW_RATE * dt
        local step = math.clamp(target - strike, -maxStep, maxStep)
        strike += step
        self._strikeAt = strike
    end
    self._lastNow = now
    local omega = 2 * math.pi / period
    local k = math.floor((now - strike) / period)
    local prevStrikeAt = strike + k * period -- last instant <= now
    local nextStrikeAt = prevStrikeAt + period
    local camAngle = omega * (now - prevStrikeAt) -- == 0 (mod 2pi) at every strike
    -- the round containing `now`: starts active+tally before its own strike
    local anchorStart = strike - (self._activeSec + self._tallySec)
    local roundStart = anchorStart + math.floor((now - anchorStart) / period) * period
    local drawP = math.clamp((now - roundStart) / period, 0, 1)
    return {
        drawP = drawP,
        camAngle = camAngle,
        omega = omega,
        periodSec = period,
        prevStrikeAt = prevStrikeAt,
        nextStrikeAt = nextStrikeAt,
    }
end

-- Number of strike instants in (t0, t1].
function RoundMetronome.strikesBetween(self: any, t0: number, t1: number): number
    local period: number? = self._periodSec
    local strike: number? = self._strikeAt
    if period == nil or strike == nil or t1 <= t0 then
        return 0
    end
    return math.floor((t1 - strike) / period) - math.floor((t0 - strike) / period)
end

return RoundMetronome
