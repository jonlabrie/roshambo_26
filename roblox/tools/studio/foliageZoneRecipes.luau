--!strict
-- Zone recipes for the forest preserve (spec 2026-07-27-forest-preserve-foliage-design).
-- Data only: the ZoneScatter planner interprets these. Tune values live at the gates.
export type Species = { name: string, weight: number }
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
        -- 10-15 gates the "walk among the trees" density the user approved
        -- 2026-07-27 (104 trees per 120x120 patch; 14-22 read too open).
        spacingMin = 10,
        spacingMax = 15,
        clumpChance = 0.18,
        clumpSize = 3,
        maxSteep = 0.55,
        waterMargin = 4,
        scaleJitter = 0.15,
    },
    WallFringe = {
        pool = {
            { name = "ConiferA", weight = 30 },
            { name = "ConiferB", weight = 30 },
            { name = "ConiferC", weight = 25 },
            { name = "CedarM", weight = 15 },
        },
        spacingMin = 10,
        spacingMax = 16,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.9,
        waterMargin = 4,
        scaleJitter = 0.2,
        heightScale = 1.15,
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
        -- rather than carpeting the zone; 12 studs of bank either side.
        nearWater = 12,
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
