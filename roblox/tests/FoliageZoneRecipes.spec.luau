--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Recipes = require("../tools/studio/foliageZoneRecipes")

describe("FoliageZoneRecipes", function()
    test("all four recipes exist with positive spacing bands", function()
        for _, key in { "PreserveCore", "PreserveUnder", "WallFringe", "WaterMargin", "FutureClearing" } do
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
    -- Sugi was the backbone until 2026-07-27; it is now a hero-cost accent
    -- (~41k tris) and hinoki/spruce/fir carry the forest. What must hold is that
    -- the expensive species stays a minority of the canopy pool.
    test("PreserveCore keeps the hero-cost sugi a minority, and clumps", function()
        local core = Recipes.PreserveCore
        local sugi, total = 0, 0
        for _, s in core.pool do
            total += s.weight
            if s.name:find("Sugi") then
                sugi += s.weight
            end
        end
        expect(sugi > 0).toBe(true)
        expect(sugi / total <= 0.2).toBe(true)
        expect(core.clumpChance > 0).toBe(true)
        expect(core.clumpSize >= 2).toBe(true)
    end)
    -- The understory is what makes the forest dense where players walk. It must
    -- pack tighter than the canopy AND sit on its own spacing layer, or the two
    -- layers veto each other's placements.
    test("PreserveUnder packs tighter than the canopy, on its own layer", function()
        local under, core = Recipes.PreserveUnder, Recipes.PreserveCore
        expect(under.spacingMax < core.spacingMin).toBe(true)
        expect(under.layer).toBe("understory")
        expect(#under.pool > 0).toBe(true)
        for _, s in under.pool do
            expect(s.name:find("Yr") ~= nil).toBe(true)
        end
    end)
    test("FutureClearing reserves its inner half", function()
        expect(Recipes.FutureClearing.innerClear).toBe(0.5)
    end)
end)
