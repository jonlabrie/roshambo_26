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

-- THE LOCKOUT IS NO LONGER A LEAD SUBTRACTED FROM ANYTHING. Picks close when OPEN closes,
-- which the server now publishes as a phase boundary rather than leaving the client to infer
-- it two seconds before the end of a longer phase. `lockoutIn` below is therefore just the
-- time remaining in OPEN, and there is no constant to keep in agreement with anyone.

export type Schedule = {
    roundId: string?,
    strikeAt: number,
    periodSec: number,
    openSec: number,
    lockSec: number,
    revealSec: number,
}

export type Reading = {
    drawP: number,
    camAngle: number,
    omega: number,
    periodSec: number,
    prevStrikeAt: number,
    nextStrikeAt: number,
    phase: string,
    secondsLeft: number,
    lockoutIn: number,
}

function RoundMetronome.new()
    return setmetatable({
        _strikeAt = nil :: number?,
        _targetStrikeAt = nil :: number?,
        _periodSec = nil :: number?,
        _openSec = 0,
        _lockSec = 0,
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
    self._openSec = sched.openSec
    self._lockSec = sched.lockSec
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
    -- the round containing `now`: starts open+lock before its own strike
    local anchorStart = strike - (self._openSec + self._lockSec)
    local roundStart = anchorStart + math.floor((now - anchorStart) / period) * period
    local drawP = math.clamp((now - roundStart) / period, 0, 1)

    -- THE PHASE, off the same timeline as the cam above — not a second source of
    -- truth. `elapsed` is where `now` sits inside the round that contains it, so
    -- the phase is that position measured against the three durations.
    --
    -- HALF-OPEN boundaries: a phase owns its start instant and not its end. Closed
    -- intervals would make the boundary belong to two phases at once, and whichever
    -- a caller sampled first would win.
    local elapsed = now - roundStart
    local openEnd = self._openSec
    local lockEnd = openEnd + self._lockSec
    local phase, phaseEndsAt
    if elapsed < openEnd then
        phase, phaseEndsAt = "OPEN", openEnd
    elseif elapsed < lockEnd then
        phase, phaseEndsAt = "LOCK", lockEnd
    else
        phase, phaseEndsAt = "REVEAL", period
    end

    -- The lockout instant, derived rather than delivered. It IS the end of OPEN, so inside
    -- OPEN this equals `secondsLeft`; everywhere else it is zero. Never negative, because
    -- the throw gate is `> 0` and a negative would read as time remaining.
    local lockoutIn = 0
    if phase == "OPEN" then
        lockoutIn = math.max(0, openEnd - elapsed)
    end

    return {
        drawP = drawP,
        camAngle = camAngle,
        omega = omega,
        periodSec = period,
        prevStrikeAt = prevStrikeAt,
        nextStrikeAt = nextStrikeAt,
        phase = phase,
        secondsLeft = math.max(0, phaseEndsAt - elapsed),
        lockoutIn = lockoutIn,
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
