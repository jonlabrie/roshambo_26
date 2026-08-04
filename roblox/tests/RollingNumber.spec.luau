--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RollingNumber = require("../src/shared/RollingNumber")

describe("RollingNumber.valueAt — endpoints pinned exactly", function()
    -- An off-by-one here leaves a wrong total sitting on screen permanently once the animation
    -- finishes — this is the one failure mode that outlives the count itself, so both ends are
    -- asserted with toBe, not toBeCloseTo.
    test("t = 0 returns exactly `from`", function()
        expect(RollingNumber.valueAt(10, 900, 0)).toBe(10)
        expect(RollingNumber.valueAt(0, 3, 0)).toBe(0)
    end)

    test("t = 1 returns exactly `to`, never one short", function()
        expect(RollingNumber.valueAt(10, 900, 1)).toBe(900)
        expect(RollingNumber.valueAt(0, 3, 1)).toBe(3)
    end)

    test("t beyond 1 still returns exactly `to` — clamped, not extrapolated", function()
        expect(RollingNumber.valueAt(10, 900, 1.5)).toBe(900)
        expect(RollingNumber.valueAt(10, 900, 50)).toBe(900)
    end)

    test("t below 0 still returns exactly `from` — clamped, not extrapolated", function()
        expect(RollingNumber.valueAt(10, 900, -0.5)).toBe(10)
        expect(RollingNumber.valueAt(10, 900, -50)).toBe(10)
    end)
end)

describe("RollingNumber.valueAt — never overshoots", function()
    test("ascending: every sampled value stays within [from, to]", function()
        local from, to = 0, 100
        for i = 0, 20 do
            local t = i / 20
            local v = RollingNumber.valueAt(from, to, t)
            expect(v >= from and v <= to).toBe(true)
        end
    end)

    -- Counts DOWN as correctly as up, tested explicitly rather than assumed symmetric with the
    -- ascending case above — a naive `from + (to - from) * eased(t)` is direction-agnostic in
    -- principle, but the rounding and clamping around it is exactly the kind of thing that can
    -- quietly only get exercised in one direction otherwise.
    test("descending: every sampled value stays within [to, from]", function()
        local from, to = 900, 0
        for i = 0, 20 do
            local t = i / 20
            local v = RollingNumber.valueAt(from, to, t)
            expect(v <= from and v >= to).toBe(true)
        end
    end)

    test("descending endpoints are pinned exactly too", function()
        expect(RollingNumber.valueAt(27, 0, 0)).toBe(27)
        expect(RollingNumber.valueAt(27, 0, 1)).toBe(0)
    end)
end)

describe("RollingNumber.valueAt — monotonic between the endpoints", function()
    test("ascending: each sample is never less than the one before it", function()
        local from, to = 5, 205
        local prev = RollingNumber.valueAt(from, to, 0)
        for i = 1, 40 do
            local t = i / 40
            local v = RollingNumber.valueAt(from, to, t)
            expect(v >= prev).toBe(true)
            prev = v
        end
    end)

    test("descending: each sample is never more than the one before it", function()
        local from, to = 205, 5
        local prev = RollingNumber.valueAt(from, to, 0)
        for i = 1, 40 do
            local t = i / 40
            local v = RollingNumber.valueAt(from, to, t)
            expect(v <= prev).toBe(true)
            prev = v
        end
    end)
end)

describe("RollingNumber.valueAt — from == to", function()
    test("constant across every t, including out-of-range t", function()
        for _, t in { -1, 0, 0.25, 0.5, 0.99, 1, 5 } do
            expect(RollingNumber.valueAt(42, 42, t)).toBe(42)
        end
    end)
end)

describe("RollingNumber.valueAt — always an integer", function()
    -- What actually lands in a TextLabel.Text is this return value; a fractional wallet figure
    -- on screen would be its own bug, not a rounding nuance.
    test("every sample is a whole number, ascending and descending", function()
        for _, pair in { { 0, 7 }, { 7, 0 } } do
            local from, to = pair[1], pair[2]
            for i = 0, 10 do
                local t = i / 10
                local v = RollingNumber.valueAt(from, to, t)
                expect(v).toBe(math.floor(v))
            end
        end
    end)
end)

describe("RollingNumber.durationFor — a big bank should feel like a payoff", function()
    test("the flat DURATION is gone", function()
        -- One constant for every amount is what made 2000 points transfer in the same half
        -- second as 1. Every caller derives its own now; leaving the old one behind would let
        -- two counters that must finish together run on different curves.
        expect((RollingNumber :: any).DURATION).toBe(nil)
    end)

    test("a zero move still returns a usable, positive duration", function()
        -- Callers divide by this. A zero would be a divide-by-zero on the one path where
        -- nothing actually moves.
        expect(RollingNumber.durationFor(0)).toBe(RollingNumber.MIN_DURATION)
        expect(RollingNumber.durationFor(0) > 0).toBe(true)
    end)

    test("direction does not matter — only distance", function()
        -- The bank button drains while the balance fills. They are one event and must finish
        -- together, so the count DOWN has to take exactly as long as the count up.
        for _, d in { 1, 7, 250, 3000, 99999 } do
            expect(RollingNumber.durationFor(-d)).toBe(RollingNumber.durationFor(d))
        end
    end)

    test("it never leaves [MIN_DURATION, MAX_DURATION]", function()
        for _, d in { 0, 1, 5, 60, 400, 3000, 10000, 250000 } do
            local v = RollingNumber.durationFor(d)
            expect(v >= RollingNumber.MIN_DURATION).toBe(true)
            expect(v <= RollingNumber.MAX_DURATION).toBe(true)
        end
    end)

    test("it is monotonic in distance", function()
        local prev = -1
        for i = 0, 200 do
            local v = RollingNumber.durationFor(i * 60)
            expect(v >= prev).toBe(true)
            prev = v
        end
    end)

    test("beyond the cap it is exactly MAX_DURATION — no pot runs away with the screen", function()
        expect(RollingNumber.durationFor(RollingNumber.SCALE_CAP)).toBe(RollingNumber.MAX_DURATION)
        expect(RollingNumber.durationFor(RollingNumber.SCALE_CAP * 100)).toBe(RollingNumber.MAX_DURATION)
    end)

    test("the curve's shape: a big bank takes seconds, a small one does not", function()
        -- Pins the FEEL the owner asked for without over-pinning the exact function. A linear
        -- ramp would put 30 points at ~0.4s and 3000 at ~1.0s and fail both bounds.
        expect(RollingNumber.durationFor(30) > 0.9).toBe(true)
        expect(RollingNumber.durationFor(30) < 1.5).toBe(true)
        expect(RollingNumber.durationFor(3000) > 2.0).toBe(true)
        expect(RollingNumber.durationFor(3000) < 2.45).toBe(true)
        expect(RollingNumber.durationFor(3000) > RollingNumber.durationFor(30) + 0.8).toBe(true)
    end)
end)

describe("RollingNumber.valueAt — the easing is a payoff, not a decay", function()
    test("the midpoint is the midpoint", function()
        -- THE test that pins the change. Smoothstep is symmetric: half the time, half the
        -- points. The quadratic ease-out this replaces returned 75 here — three quarters of a
        -- 2-second count landing in the first second and the rest crawling.
        expect(RollingNumber.valueAt(0, 100, 0.5)).toBe(50)
    end)

    test("it winds up rather than bolting", function()
        -- A quarter of the way through, well under a quarter of the way there. The old
        -- ease-out was at 44 by this point.
        expect(RollingNumber.valueAt(0, 100, 0.25) < 25).toBe(true)
        expect(RollingNumber.valueAt(0, 100, 0.25) > 5).toBe(true)
    end)

    test("and settles rather than stopping dead", function()
        -- Symmetric with the wind-up: the last quarter of the time covers well under a quarter
        -- of the distance. Upper bound is 90, not just "under 100": smoothstep(0.75) = 84 but the
        -- old ease-out this replaces gives 94 here, so a loose bound (e.g. < 95) would admit both
        -- curves and never catch a regression back to ease-out. 90 sits between the two with a
        -- real margin on both sides.
        expect(RollingNumber.valueAt(0, 100, 0.75) > 75).toBe(true)
        expect(RollingNumber.valueAt(0, 100, 0.75) < 90).toBe(true)
    end)
end)
