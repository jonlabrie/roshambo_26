--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local M = require("../src/shared/ShojiSlideMath")

describe("ShojiSlideMath.slideKey", function()
    test("is uid, pad, side, index joined by \1 -- unique per bay per player", function()
        expect(M.slideKey("77", "T01", "front", 2)).toBe("77\1T01\1front\0012")
        expect(M.slideKey("77", "T01", "front", 2) == M.slideKey("77", "T01", "front", 3)).toBe(false)
        expect(M.slideKey("77", "T01", "front", 2) == M.slideKey("77", "T01", "back", 2)).toBe(false)
        expect(M.slideKey("77", "T01", "front", 2) == M.slideKey("77", "T02", "front", 2)).toBe(false)
        expect(M.slideKey("77", "T01", "front", 2) == M.slideKey("78", "T01", "front", 2)).toBe(false)
    end)
end)

describe("ShojiSlideMath.collectRun", function()
    test("orders bays by index and returns the same shape collectShojiRun did", function()
        local run = M.collectRun({
            { bayIndex = 3, bay = "c" },
            { bayIndex = 1, bay = "a" },
            { bayIndex = 2, bay = "b" },
        })
        expect(#run).toBe(3)
        expect(run[1].bayIndex).toBe(1)
        expect(run[3].bay).toBe("c")
    end)
    test("an empty list is an empty run", function()
        expect(#M.collectRun({})).toBe(0)
    end)
    test("bay numbers need not be contiguous -- only their ORDER is the ordinal", function()
        -- collectShojiRun sorts by the raw Bay_<side>_<n> number; the ordinal is the position
        -- in the sorted list, which is why ShojiRun.ordinalOf exists at all.
        local run = M.collectRun({ { bayIndex = 7, bay = "g" }, { bayIndex = 2, bay = "b" } })
        expect(run[1].bayIndex).toBe(2)
        expect(run[2].bayIndex).toBe(7)
    end)
end)

describe("ShojiSlideMath.withinReach", function()
    -- ⚠ FULL 3-D distance, not horizontal-only: withinShojiReach measured
    -- `(root.Position - pos).Magnitude`, and this move is verbatim. Height counts.
    test("3-D distance, inclusive at the reach", function()
        expect(M.withinReach({ x = 0, y = 0, z = 0 }, { x = 3, y = 0, z = 4 }, 5)).toBe(true)
        expect(M.withinReach({ x = 0, y = 0, z = 0 }, { x = 3, y = 0, z = 4.01 }, 5)).toBe(false)
    end)
    test("height is part of the distance -- a bay 40 studs up is out of reach", function()
        expect(M.withinReach({ x = 0, y = 0, z = 0 }, { x = 3, y = 40, z = 4 }, 5)).toBe(false)
    end)
end)
