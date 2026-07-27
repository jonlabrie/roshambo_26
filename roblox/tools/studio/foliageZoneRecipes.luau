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
    PreserveCore = {
        pool = {
            { name = "SugiMidA", weight = 25 },
            { name = "SugiMidB", weight = 25 },
            { name = "SugiMidC", weight = 25 },
            { name = "FirM", weight = 15 },
            { name = "CedarS", weight = 10 },
        },
        -- 5-8: the teahouse-pad keep-outs cost the floor a lot of ground, so
        -- the user asked for 2x again on top of the 10-15 gate (Core 68 -> 150).
        spacingMin = 5,
        spacingMax = 8,
        clumpChance = 0.18,
        clumpSize = 3,
        maxSteep = 0.55,
        waterMargin = 3,
        scaleJitter = 0.15,
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
            { name = "SugiMidA", weight = 25 },
            { name = "SugiMidB", weight = 25 },
            { name = "SugiMidC", weight = 25 },
            { name = "FirM", weight = 15 },
            { name = "CedarS", weight = 10 },
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
