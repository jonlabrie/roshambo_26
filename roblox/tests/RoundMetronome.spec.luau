--!strict
local harness = require("./harness")
local RoundMetronome = require("../src/shared/RoundMetronome")
local describe, test, expect = harness.describe, harness.test, harness.expect

local TAU = 2 * math.pi
local function sched(strikeAt: number)
    return { roundId = "r", strikeAt = strikeAt, periodSec = 25, openSec = 20, lockSec = 2, revealSec = 3 }
end

describe("RoundMetronome", function()
    test("read is nil before any schedule", function()
        expect(RoundMetronome.new():read(100)).toBeNil()
    end)

    test("maps the timeline: cam hits 0 at the strike, draw ramps over the round", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        local atStrike = m:read(122)
        expect(atStrike.camAngle % TAU).toBeCloseTo(0, 0.0001)
        expect(atStrike.drawP).toBeCloseTo(22 / 25, 0.0001) -- (open+lock)/period
        local mid = m:read(105) -- round started at 100
        expect(mid.drawP).toBeCloseTo(5 / 25, 0.0001)
        expect(mid.omega).toBeCloseTo(TAU / 25, 0.0001)
        expect(mid.nextStrikeAt).toBeCloseTo(122, 0.0001)
        expect(mid.prevStrikeAt).toBeCloseTo(97, 0.0001)
    end)

    test("free-runs: strikes recur every period with no further schedule", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        expect(m:strikesBetween(121, 123)).toBe(1)
        expect(m:strikesBetween(123, 146)).toBe(0)
        expect(m:strikesBetween(123, 148)).toBe(1) -- 147
        expect(m:strikesBetween(100, 1100)).toBe(40)
        expect(m:read(122 + 40 * 25).camAngle % TAU).toBeCloseTo(0, 0.001)
    end)

    test("racing-wheel regression: a mid-round join still yields omega = 2pi/period", function()
        -- the old measured clock read 2pi/7.4 when joining 17.6s into a 25s round
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 114.6) -- joined with 7.4s to the strike
        expect(m:read(114.6).omega).toBeCloseTo(TAU / 25, 0.0001)
        expect(m:read(114.6).drawP).toBeCloseTo(14.6 / 25, 0.0001)
    end)

    test("small refinements slew (bounded, converging), never step", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        m:read(100)
        m:setSchedule(sched(122.4), 101)
        local prev = m:read(101).nextStrikeAt
        expect(prev < 122.4).toBe(true) -- not adopted instantly
        for t = 102, 115 do
            local cur = m:read(t).nextStrikeAt
            expect(cur - prev <= 0.05 * 1 + 0.0001).toBe(true) -- rate-capped
            expect(cur + 0.0001 >= prev).toBe(true) -- monotone toward target
            prev = cur
        end
        expect(prev).toBeCloseTo(122.4, 0.001) -- converged
    end)

    test("big shifts snap (restart) and period changes adopt cleanly (20->60 launch)", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        m:read(100)
        m:setSchedule(sched(126), 101) -- 4s > tolerance: hard re-anchor
        expect(m:read(101).nextStrikeAt).toBeCloseTo(126, 0.0001)
        m:setSchedule(
            { roundId = "r2", strikeAt = 200, periodSec = 65, openSec = 60, lockSec = 2, revealSec = 3 },
            140
        )
        local r = m:read(150)
        expect(r.omega).toBeCloseTo(TAU / 65, 0.0001)
        expect(r.nextStrikeAt).toBeCloseTo(200, 0.0001)
    end)

    test("next-round schedules land in the same congruence class (no phantom shift)", function()
        local m = RoundMetronome.new()
        m:setSchedule(sched(122), 100)
        m:read(100)
        m:setSchedule(sched(147), 123) -- next round, exactly one period on
        expect(m:read(123).nextStrikeAt).toBeCloseTo(147, 0.0001)
        expect(m:read(123).camAngle).toBeCloseTo(TAU * 1 / 25, 0.0001)
    end)
end)

-- A 60s round: OPEN 51 / LOCK 2 / REVEAL 7. The strike is reveal-start, so putting
-- it at t=53 anchors round start at t=0 and every offset below reads directly.
local function launchRound()
    local m = RoundMetronome.new()
    m:setSchedule({
        roundId = "r",
        strikeAt = 53,
        periodSec = 60,
        openSec = 51,
        lockSec = 2,
        revealSec = 7,
    }, 0)
    return m
end

describe("RoundMetronome — OPEN/LOCK/REVEAL and the lockout as a boundary", function()
    test("the phases tile the round: OPEN, LOCK, REVEAL, then OPEN again", function()
        local m = launchRound()
        expect(m:read(0).phase).toBe("OPEN")
        expect(m:read(50.9).phase).toBe("OPEN")
        expect(m:read(51).phase).toBe("LOCK")
        expect(m:read(52.9).phase).toBe("LOCK")
        expect(m:read(53).phase).toBe("REVEAL")
        expect(m:read(59.9).phase).toBe("REVEAL")
        expect(m:read(60).phase).toBe("OPEN")
    end)

    test("lockoutIn counts to the END of OPEN, with no lead subtracted", function()
        local m = launchRound()
        expect(m:read(0).lockoutIn).toBeCloseTo(51, 0.0001)
        expect(m:read(50).lockoutIn).toBeCloseTo(1, 0.0001)
    end)

    test("lockoutIn is zero once OPEN has closed", function()
        local m = launchRound()
        expect(m:read(51).lockoutIn).toBe(0)
        expect(m:read(55).lockoutIn).toBe(0)
    end)

    test("inside OPEN, secondsLeft and lockoutIn are the same number", function()
        local m = launchRound()
        local r = m:read(20)
        expect(r.secondsLeft).toBeCloseTo(r.lockoutIn, 0.0001)
    end)
end)

-- A 27s round: 20 open, 2 lock, 5 reveal, with the strike at the first
-- instant of REVEAL (openSec + lockSec into the period), which is how
-- RoundCoordinator publishes it. Shared by the phase block and the lockout block
-- below — one fixture, so the two cannot describe different rounds.
local function m27()
    local m = RoundMetronome.new()
    m:setSchedule({
        roundId = "r1",
        strikeAt = 1000,
        periodSec = 27,
        openSec = 20,
        lockSec = 2,
        revealSec = 5,
    }, 1000)
    return m
end

describe("RoundMetronome — the phase, read off the same timeline as the cam", function()
    test("the strike instant is the first instant of REVEAL", function()
        -- This is the anchor the whole timeline hangs off. If it drifts, every
        -- phase boundary drifts with it.
        expect(m27():read(1000).phase).toBe("REVEAL")
    end)

    test("it walks the period in order", function()
        local m = m27()
        local roundStart = 1000 - 22 -- strike less (open + lock)
        expect(m:read(roundStart).phase).toBe("OPEN")
        expect(m:read(roundStart + 19.9).phase).toBe("OPEN")
        expect(m:read(roundStart + 20).phase).toBe("LOCK")
        expect(m:read(roundStart + 21.9).phase).toBe("LOCK")
        expect(m:read(roundStart + 22).phase).toBe("REVEAL")
        expect(m:read(roundStart + 26.9).phase).toBe("REVEAL")
    end)

    test("boundaries are half-open — a phase owns its start, not its end", function()
        -- Closed-closed would make one instant belong to two phases, and whichever
        -- the caller sampled first would win. That is the kind of ambiguity that
        -- shows up once an hour and is never reproducible.
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart + 20).phase).toBe("LOCK")
        expect(m:read(roundStart + 22).phase).toBe("REVEAL")
        expect(m:read(roundStart + 27).phase).toBe("OPEN") -- the next round
    end)

    test("it repeats every period, forwards and backwards", function()
        local m = m27()
        local roundStart = 1000 - 22
        for _, k in { -3, -1, 0, 1, 5 } do
            local base = roundStart + k * 27
            expect(m:read(base + 1).phase).toBe("OPEN")
            expect(m:read(base + 21).phase).toBe("LOCK")
            expect(m:read(base + 23).phase).toBe("REVEAL")
        end
    end)

    test("secondsLeft counts down to the NEXT boundary, not the round's end", function()
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart).secondsLeft).toBeCloseTo(20, 0.001)
        expect(m:read(roundStart + 19).secondsLeft).toBeCloseTo(1, 0.001)
        expect(m:read(roundStart + 20).secondsLeft).toBeCloseTo(2, 0.001) -- LOCK's whole length
        expect(m:read(roundStart + 22).secondsLeft).toBeCloseTo(5, 0.001) -- REVEAL's
    end)

    test("secondsLeft is never negative and never exceeds its phase", function()
        local m = m27()
        local roundStart = 1000 - 22
        for i = 0, 270 do
            local r = m:read(roundStart + i / 10)
            expect(r.secondsLeft >= 0).toBe(true)
            expect(r.secondsLeft <= 20).toBe(true)
        end
    end)

    test("no schedule, no phase", function()
        -- read() already returns nil before a schedule lands; the new fields must
        -- not tempt a caller into treating an unsynced client as being mid-round.
        expect(RoundMetronome.new():read(100)).toBeNil()
    end)
end)

describe("RoundMetronome — the lockout, derived rather than delivered", function()
    test("it counts down to the end of OPEN, with no lead subtracted", function()
        local m = m27()
        local roundStart = 1000 - 22
        -- OPEN is 20s and there is no lead to subtract anymore.
        expect(m:read(roundStart).lockoutIn).toBeCloseTo(20, 0.001)
        expect(m:read(roundStart + 19).lockoutIn).toBeCloseTo(1, 0.001)
    end)

    test("it is zero outside OPEN", function()
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart + 20).lockoutIn).toBe(0) -- LOCK
        expect(m:read(roundStart + 23).lockoutIn).toBe(0) -- REVEAL
    end)
end)
