--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Recipes = require("../tools/studio/foliageZoneRecipes")

describe("FoliageZoneRecipes", function()
    test("all four recipes exist with positive spacing bands", function()
        for _, key in { "PreserveCore", "WallFringe", "WaterMargin", "FutureClearing" } do
            local r = Recipes[key]
            expect(r ~= nil).toBe(true)
            assert(r ~= nil)
            expect(r.spacingMin > 0).toBe(true)
            expect(r.spacingMax >= r.spacingMin).toBe(true)
            expect(#r.pool > 0).toBe(true)
            for _, s in r.pool do
                expect(s.weight > 0).toBe(true)
            end
        end
    end)
    test("PreserveCore is sugi-dominant and clump-capable", function()
        local core = Recipes.PreserveCore
        local sugi = 0
        local total = 0
        for _, s in core.pool do
            total += s.weight
            if s.name:find("SugiMid") then
                sugi += s.weight
            end
        end
        expect(sugi / total >= 0.7).toBe(true)
        expect(core.clumpChance > 0).toBe(true)
        expect(core.clumpSize >= 2).toBe(true)
    end)
    test("FutureClearing reserves its inner half", function()
        expect(Recipes.FutureClearing.innerClear).toBe(0.5)
    end)
end)
