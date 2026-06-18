--!strict
local harness = require("./harness")
local FoliageScatter = require("../tools/builders/FoliageScatter")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("FoliageScatter", function()
    local region = { xMin = 100, xMax = 200, zMin = -80, zMax = 0 }
    test("is deterministic for a given seed", function()
        local a = FoliageScatter.points(region, 0.01, 42)
        local b = FoliageScatter.points(region, 0.01, 42)
        expect(#a).toBe(#b)
        expect(a[1][1]).toBe(b[1][1])
        expect(a[1][2]).toBe(b[1][2])
    end)
    test("different seeds differ", function()
        local a = FoliageScatter.points(region, 0.01, 1)
        local b = FoliageScatter.points(region, 0.01, 2)
        expect(a[1][1] ~= b[1][1] or a[1][2] ~= b[1][2]).toBe(true)
    end)
    test("density scales the count", function()
        local sparse = FoliageScatter.points(region, 0.005, 7)
        local dense = FoliageScatter.points(region, 0.02, 7)
        expect(#dense > #sparse).toBe(true)
    end)
    test("all points fall within the region", function()
        for _, p in FoliageScatter.points(region, 0.01, 3) do
            expect(p[1] >= region.xMin and p[1] <= region.xMax).toBe(true)
            expect(p[2] >= region.zMin and p[2] <= region.zMax).toBe(true)
        end
    end)
end)
