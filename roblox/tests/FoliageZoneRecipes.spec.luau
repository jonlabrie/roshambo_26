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
        ReedClump = true,
        TallWeeds = true,
        WeedStalks = true,
        FernClump = true, -- drop this line if the Task 4 verdict was park
        IrisA = true,
        IrisB = true,
        XfHinokiT = true,
        XfHinokiMT = true,
        XfSpruceMT = true,
        XfFirMT = true,
        XfSugi25T = true,
        XfMapleA = true,
        XfMapleM = true,
        SugiHero_SugiSmart = true,
        SugiHero_SugiB = true,
        SugiHero_SugiC = true,
        SugiHero_SugiD = true,
        SugiHero_SugiE = true,
        SugiHero_SugiF = true,
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

-- 2026-07-30: PreserveCore runs a grove pre-pass instead of pure per-sample
-- scatter (the random-scatter gate rejected too much canopy to ever cluster).
describe("grove pre-pass", function()
    test("PreserveCore runs a grove with sane member/anchor bounds", function()
        local grove = Recipes.PreserveCore.grove
        expect(grove ~= nil).toBe(true)
        assert(grove ~= nil)
        expect(grove.spacing > 0).toBe(true)
        expect(grove.radiusMax >= grove.radiusMin).toBe(true)
        expect(grove.membersMax >= grove.membersMin).toBe(true)
        expect(grove.membersMin >= 2).toBe(true) -- elder + at least one attendant
        expect(grove.memberSpacing > 0).toBe(true)
        expect(grove.dominantScale > 1).toBe(true) -- the elder must read oversized
        expect(grove.anchorDarts > 0).toBe(true)
        expect(grove.maxGroves > 0).toBe(true)
    end)
    -- only PreserveCore should carry a grove; every other recipe still scatters
    -- per-sample, so an accidental grove elsewhere silently changes its planter.
    test("only the canopy recipes carry groves", function()
        local groved = { PreserveCore = true, SugiStand = true, MapleStand = true }
        for name, recipe in Recipes do
            if not groved[name] then
                expect(recipe.grove == nil).toBe(true)
            end
        end
    end)
    test("PreserveBrush thickens near grove anchors via groveAffinity", function()
        local aff = Recipes.PreserveBrush.groveAffinity
        expect(aff ~= nil).toBe(true)
        assert(aff ~= nil)
        expect(aff.radius > 0).toBe(true)
        expect(aff.inside > aff.outside).toBe(true)
    end)
    -- small tiers (2026-07-30 brush fix): discrete short-scale entries give the
    -- 2-5 stud band real height variety instead of a uniform ~4-stud carpet.
    test("PreserveBrush pool includes small-scale tiers", function()
        local small = 0
        for _, sp in Recipes.PreserveBrush.pool do
            if sp.scale ~= nil and sp.scale < 1 then
                small += 1
                expect(sp.weight > 0).toBe(true)
            end
        end
        expect(small).toBe(3)
    end)
    -- gate feedback (2026-07-31): bigger groves with youngsters among the
    -- elders sell the grove read. The sapling swap map must only key on real
    -- canopy pool species and only target real Yb sapling models.
    test("PreserveCore groves fit 10 members and swap saplings from real species", function()
        local grove = Recipes.PreserveCore.grove
        assert(grove ~= nil)
        expect(grove.membersMax).toBe(10)
        local saplings = grove.saplings
        expect(saplings ~= nil).toBe(true)
        assert(saplings ~= nil)
        expect(saplings.chance > 0 and saplings.chance < 1).toBe(true)
        local coreNames: { [string]: boolean } = {}
        for _, sp in Recipes.PreserveCore.pool do
            coreNames[sp.name] = true
        end
        local mapped = 0
        for from, to in saplings.map do
            mapped += 1
            expect(coreNames[from] == true).toBe(true) -- key must be a real canopy species
            expect(to:find("Yb") ~= nil).toBe(true) -- target must be a sapling model
        end
        expect(mapped > 0).toBe(true)
    end)
    -- gate feedback (2026-07-31, again): fewer, fuller stands; slots retry
    -- for ground instead of dying on the first rejected dart.
    test("PreserveCore reshaped to fewer, fuller groves with member retries", function()
        local grove = Recipes.PreserveCore.grove
        assert(grove ~= nil)
        expect(grove.maxGroves).toBe(12)
        expect(grove.membersMin).toBe(5)
        expect(grove.radiusMax).toBe(20)
        expect(grove.memberTries).toBe(6)
        expect(grove.memberTries ~= nil and grove.memberTries > 0).toBe(true)
    end)
    -- free-mix (2026-07-31): the sugi hero stand should read as genuinely
    -- mixed, so it opts OUT of the coherent dominant/attendant pairing that
    -- every other grove uses by default.
    test("SugiStand free-mixes; PreserveCore stays coherent", function()
        expect(Recipes.SugiStand.grove ~= nil).toBe(true)
        local sugiGrove = Recipes.SugiStand.grove
        assert(sugiGrove ~= nil)
        expect(sugiGrove.coherent).toBe(false)
        local coreGrove = Recipes.PreserveCore.grove
        assert(coreGrove ~= nil)
        expect(coreGrove.coherent == nil or coreGrove.coherent == true).toBe(true)
    end)
    -- gate feedback (2026-07-31): adult-heavy shrine stand centred on the
    -- user's mark — fewer young saplings, a taller minimum member count.
    test("SugiStand is adult-heavy and single-grove (centre-seeking)", function()
        local grove = Recipes.SugiStand.grove
        assert(grove ~= nil)
        expect(grove.maxGroves).toBe(1) -- triggers centre-seeking anchor selection
        expect(grove.membersMin).toBe(7)
        expect(grove.membersMax).toBe(10)
        local saplings = grove.saplings
        assert(saplings ~= nil)
        expect(saplings.chance).toBe(0.25)
    end)
end)

describe("waterline ecology", function()
    test("margin flora refuses steep hillsides", function()
        expect(Recipes.WaterMargin.maxSteep <= 0.4).toBe(true)
    end)
    test("reeds wade, muhly keeps damp feet only", function()
        expect(Recipes.WaterMargin.pool[1].name).toBe("ReedClump")
        expect(Recipes.WaterMargin.submergeMax ~= nil).toBe(true)
    end)
end)
