--!strict
-- Zone recipes for the forest preserve (spec 2026-07-27-forest-preserve-foliage-design).
-- Data only: the ZoneScatter planner interprets these. Tune values live at the gates.
export type Species = { name: string, weight: number, scale: number? }
export type Recipe = {
    pool: { Species },
    spacingMin: number,
    spacingMax: number,
    clumpChance: number,
    clumpSize: number,
    maxSteep: number,
    waterMargin: number,
    scaleJitter: number,
    heightScale: number?,
    innerClear: number?,
    nearWater: number?,
    layer: string?,
}
local Recipes: { [string]: Recipe } = {
    -- CANOPY layer: the tall structure. Baked SEPARATELY from PreserveUnder
    -- (the planner assigns one zone per sample, so co-located layers need their
    -- own bake) — hence the loose spacing here and the tight spacing there.
    PreserveCore = {
        pool = {
            { name = "XfHinoki", weight = 20 }, -- authentic backbone, adult 26
            { name = "XfHinokiM", weight = 25 },
            { name = "XfSpruceM", weight = 25 }, -- density workhorse
            { name = "XfFirM", weight = 20 },
            { name = "XfSugi25", weight = 10 }, -- signature species, hero cost
        },
        spacingMin = 14,
        spacingMax = 20,
        clumpChance = 0.18,
        clumpSize = 3,
        maxSteep = 0.55,
        waterMargin = 3,
        scaleJitter = 0.15,
    },
    -- UNDERSTORY layer: young trees, dense at eye level. This is what makes the
    -- forest read "medium-heavy" where players actually walk — adults are bare
    -- at head height. Cheap: 4-12k tris each vs 22-41k for the canopy.
    PreserveUnder = {
        pool = {
            { name = "XfHinokiYr", weight = 30 },
            { name = "XfSpruceYr", weight = 30 },
            { name = "XfFirYr", weight = 25 },
            { name = "XfSugiYr", weight = 15 },
        },
        spacingMin = 6,
        spacingMax = 10,
        clumpChance = 0.35,
        clumpSize = 3,
        maxSteep = 0.6,
        waterMargin = 3,
        scaleJitter = 0.22,
        layer = "understory",
    },
    WallFringe = {
        pool = {
            -- per-species scale tames the toolbox giants (ConiferA 98 studs,
            -- ConiferB 107, ConiferC 71 native) toward the 45-70 band while
            -- CedarM keeps its own 45; scaleJitter 0.35 then spreads each
            -- species so the wall reads as a mixed-age stand, not a hedge.
            { name = "ConiferA", weight = 30, scale = 0.7 },
            { name = "ConiferB", weight = 30, scale = 0.62 },
            { name = "ConiferC", weight = 25, scale = 0.9 },
            { name = "CedarM", weight = 15, scale = 1.0 },
        },
        spacingMin = 10,
        spacingMax = 16,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.9,
        waterMargin = 4,
        scaleJitter = 0.35,
        heightScale = 1.0,
    },
    WaterMargin = {
        pool = {
            { name = "MuhlyGrass", weight = 50 },
            { name = "ReedClump", weight = 30 },
            { name = "FernClump", weight = 20 },
        },
        spacingMin = 4,
        spacingMax = 8,
        clumpChance = 0.3,
        clumpSize = 3,
        maxSteep = 0.7,
        waterMargin = 0,
        scaleJitter = 0.25,
        -- hug the real (meandering) shoreline from Sandbox.WaterMap.WaterMarkers
        -- rather than carpeting the zone; 8 studs of bank either side.
        nearWater = 8,
        -- ground cover spaces against other ground cover only, never against trees
        layer = "ground",
    },
    FutureClearing = {
        pool = {
            { name = "XfHinokiM", weight = 35 },
            { name = "XfFirM", weight = 35 },
            { name = "XfHinokiYr", weight = 30 },
        },
        spacingMin = 20,
        spacingMax = 30,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.55,
        waterMargin = 4,
        scaleJitter = 0.15,
        innerClear = 0.5,
    },
}
return Recipes
