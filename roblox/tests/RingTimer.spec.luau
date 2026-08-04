--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RingTimer = require("../src/shared/RingTimer")

local N = RingTimer.SEGMENTS

describe("RingTimer.lit — how much of the ring is still there", function()
    test("a full round lights every segment", function()
        expect(RingTimer.lit(1, N)).toBe(N)
    end)

    test("an empty round lights none — the ring is GONE, not one-segment-left", function()
        expect(RingTimer.lit(0, N)).toBe(0)
    end)

    test("any time remaining leaves at least one segment lit", function()
        -- A player with a sliver of a second must not see an empty ring: the round is still open
        -- and the throw buttons are still live.
        expect(RingTimer.lit(0.0001, N)).toBe(1)
    end)

    test("half a round lights half the ring", function()
        expect(RingTimer.lit(0.5, N)).toBe(N // 2)
    end)

    test("it is monotonic and never exceeds the count", function()
        local prev = -1
        for i = 0, 100 do
            local v = RingTimer.lit(i / 100, N)
            expect(v >= prev).toBe(true)
            expect(v <= N).toBe(true)
            expect(v >= 0).toBe(true)
            prev = v
        end
    end)

    test("a fraction outside [0,1] clamps rather than extrapolating", function()
        expect(RingTimer.lit(-3, N)).toBe(0)
        expect(RingTimer.lit(9, N)).toBe(N)
    end)
end)

describe("RingTimer.angleAt — segment 1 is at the top, sweeping clockwise", function()
    test("the first segment sits at 0 degrees", function()
        expect(RingTimer.angleAt(1, N)).toBe(0)
    end)

    test("segments are evenly spaced over a full turn", function()
        expect(RingTimer.angleAt(2, N)).toBe(360 / N)
        expect(RingTimer.angleAt(N, N)).toBe(360 - 360 / N)
    end)

    test("no segment reaches a full turn — that would overlap segment 1", function()
        for i = 1, N do
            expect(RingTimer.angleAt(i, N) < 360).toBe(true)
        end
    end)
end)

describe("RingTimer.isWarning", function()
    test("it warns at and below the threshold", function()
        expect(RingTimer.isWarning(5, 5)).toBe(true)
        expect(RingTimer.isWarning(1, 5)).toBe(true)
    end)

    test("it does not warn above the threshold", function()
        expect(RingTimer.isWarning(5.01, 5)).toBe(false)
        expect(RingTimer.isWarning(20, 5)).toBe(false)
    end)
end)

describe("RingTimer.segmentWidth — segments overlap so the ring reads solid", function()
    test("a segment is at least as wide as its share of the circumference", function()
        local pitch = 2 * math.pi * 23 / N
        expect(RingTimer.segmentWidth(23, N) >= pitch).toBe(true)
    end)
end)
