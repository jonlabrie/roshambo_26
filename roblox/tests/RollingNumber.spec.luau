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

describe("RollingNumber.DURATION", function()
    test("is a positive number, roughly half a second per spec", function()
        expect(typeof(RollingNumber.DURATION)).toBe("number")
        expect(RollingNumber.DURATION > 0).toBe(true)
    end)
end)
