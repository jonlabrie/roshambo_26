--!strict
local harness = require("./harness")
local RoundMetronome = require("../src/shared/RoundMetronome")
local describe, test, expect = harness.describe, harness.test, harness.expect

local TAU = 2 * math.pi
local function sched(strikeAt: number)
    return { roundId = "r", strikeAt = strikeAt, periodSec = 25, activeSec = 20, tallySec = 2, revealSec = 3 }
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
        expect(atStrike.drawP).toBeCloseTo(22 / 25, 0.0001) -- (active+tally)/period
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
            { roundId = "r2", strikeAt = 200, periodSec = 65, activeSec = 60, tallySec = 2, revealSec = 3 },
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
