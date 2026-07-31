--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Recipes = require("../tools/studio/foliageZoneRecipes")

describe("FoliageZoneRecipes", function()
    test("all four recipes exist with positive spacing bands", function()
        for _, key in { "PreserveCore", "PreserveBrush", "WallFringe", "WaterMargin", "FutureClearing" } do
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
    -- The brush band is what makes the forest dense where players walk. It must
    -- pack tighter than the canopy AND sit on its own spacing layer, or the two
    -- layers veto each other's placements.
    test("PreserveBrush packs tighter than the canopy, on its own layer", function()
        local under, core = Recipes.PreserveBrush, Recipes.PreserveCore
        expect(under.spacingMax < core.spacingMin).toBe(true)
        expect(under.layer).toBe("understory")
        expect(#under.pool > 0).toBe(true)
        for _, s in under.pool do
            expect(s.name:find("Yb") ~= nil).toBe(true)
        end
    end)
    -- THE BAND STRUCTURE (user's words): ground 0-2 grass, young 2-5 below the
    -- eyeline, 5-7 DELIBERATELY EMPTY as the sightline band, canopy above 7.
    -- The brush band exists to fill 2-5 and must not grow into the empty band,
    -- so its species are the 4-stud Yb models and jitter must not push them past 5.
    test("PreserveBrush stays below the 5-stud eyeline", function()
        local brush = Recipes.PreserveBrush
        -- 4.2-stud models; the tallest possible draw is height * (1 + scaleJitter)
        expect(4.3 * (1 + brush.scaleJitter) <= 5.0).toBe(true)
    end)
    -- The canopy pool is drawn from the trimmed models only. An untrimmed tree
    -- here is foliated to the ground and destroys the sightline band outright.
    test("PreserveCore draws only trimmed canopy models", function()
        for _, s in Recipes.PreserveCore.pool do
            local trimmed = s.name:find("T$") ~= nil or s.name:find("T_NR$") ~= nil
            expect(trimmed).toBe(true)
        end
    end)
    test("FutureClearing reserves its inner half", function()
        expect(Recipes.FutureClearing.innerClear).toBe(0.5)
    end)
end)

describe("recipes name only species that exist", function()
    -- the kit as of Task 1-3 + the reed/weed exemplars Task 11 clones in
    local KNOWN = {
        MuhlyGrass = true,
        ReedClump = true,
        WeedStalks = true,
        FernClump = true, -- drop this line if the Task 4 verdict was park
        XfHinokiT = true,
        XfHinokiMT = true,
        XfSpruceMT = true,
        XfFirMT = true,
        XfSugi25T = true,
        XfHinokiYb = true,
        XfSpruceYb = true,
        XfFirYb = true,
        XfSugiYb = true,
        XfHinokiM = true,
        XfSpruceM = true,
        XfFirM = true,
        XfSugi40 = true,
    }
    for name, recipe in Recipes do
        test(name .. " pool is real", function()
            for _, sp in recipe.pool do
                expect(KNOWN[sp.name] == true).toBe(true)
            end
        end)
    end
end)

describe("waterline ecology", function()
    test("margin flora refuses steep hillsides", function()
        expect(Recipes.WaterMargin.maxSteep <= 0.4).toBe(true)
    end)
    test("reeds wade, muhly keeps damp feet only", function()
        expect(Recipes.WaterMargin.pool[1].name).toBe("MuhlyGrass")
        expect(Recipes.WaterMargin.submergeMax ~= nil).toBe(true)
    end)
end)
