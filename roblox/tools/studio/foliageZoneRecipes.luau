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
    pathMargin: number?,
    footingRadius: number?,
    footingMaxDrop: number?,
    submergeMax: number?,
    careDensity: { [string]: number }?,
    -- if set, this recipe's zone runs a grove PRE-PASS instead of the ordinary
    -- per-sample scatter (ZoneScatter.luau): the random-scatter gate rejected
    -- too much of the canopy on its own (footing/steep/spacing all compound
    -- against any single sample), so canopy reads sparse everywhere instead of
    -- clustering the way a real stand of trees does. Groves dart-throw anchors
    -- and grow a species-coherent clump (oversized elder + attendants) around
    -- each one, with real meadow gaps between groves.
    grove: GroveConfig?,
    -- if set (on a DIFFERENT recipe, typically an understory layer), the
    -- effective density near any grove anchor is multiplied by `inside`
    -- instead of `outside`, so ground cover thickens around the groves.
    groveAffinity: GroveAffinity?,
}
export type GroveConfig = {
    spacing: number, -- min distance between grove ANCHORS (meadows live between)
    radiusMin: number,
    radiusMax: number, -- member distance from the anchor
    membersMin: number,
    membersMax: number, -- trees per grove INCLUDING the elder
    memberSpacing: number, -- min distance between members of the same layer
    dominantScale: number, -- the elder's extra scale multiplier
    anchorDarts: number, -- dart-throw attempts per zone
    maxGroves: number,
    -- optional: a MEMBER (never the elder) whose rolled species has a map
    -- entry may be swapped for a young/sapling model name, chance-gated.
    -- Scale/jitter/heightScale are unchanged — young models are naturally
    -- small, this only substitutes the placed name.
    saplings: { chance: number, map: { [string]: string } }?,
    -- optional: attempts per member SLOT before it's abandoned (default 1,
    -- the old single-shot behavior). Real terrain rejects a lot of single
    -- darts; retries let a slot fight for open ground instead of just dying.
    memberTries: number?,
    -- optional: false = FREE-MIX. Every placement (elder included) draws its
    -- species independently from the full pool instead of the dominant/
    -- attendant pair, for a "hero stand" that's genuinely mixed. Default/nil
    -- = true = the ordinary coherent dominant/attendant grove.
    coherent: boolean?,
}
export type GroveAffinity = { radius: number, inside: number, outside: number }
-- THE FOUR BANDS (the user's structure, and the point of the whole system):
--   0-2 studs   ground cover — grass and weeds. DOES NOT EXIST YET; the same gap
--               leaves the waterline bare. See the WaterMargin pool below.
--   2-5 studs   young growth below the eyeline — PreserveBrush.
--   5-7 studs   DELIBERATELY EMPTY. This is the sightline band; a player's eye is
--               at ~5. Nothing may be planted whose foliage occupies it.
--   7+ studs    canopy — PreserveCore, drawn only from SKIRT-trimmed models.
-- "A forest that feels heavy, but has decent sightlines through the trees."
--
-- Deciduous accents and bamboo appear in NO recipe pool in this file: they are
-- a hand-placed composition layer, not scattered by ZoneScatter.
local Recipes: { [string]: Recipe } = {
    -- CANOPY layer: the tall structure. Baked SEPARATELY from PreserveBrush
    -- (the planner assigns one zone per sample, so co-located layers need their
    -- own bake) — hence the loose spacing here and the tight spacing there.
    -- ONLY trimmed models (…T / …MT) belong here: an untrimmed XfrogPlants tree is
    -- foliated to the ground and wipes out the sightline band on its own.
    PreserveCore = {
        pool = {
            { name = "XfHinokiT", weight = 15 }, -- authentic backbone, adult 26
            { name = "XfHinokiMT", weight = 25 },
            { name = "XfSpruceMT", weight = 25 }, -- density workhorse
            { name = "XfFirMT", weight = 25 },
            { name = "XfSugi25T", weight = 10 }, -- signature species, hero cost (~39k tris)
        },
        spacingMin = 14,
        spacingMax = 20,
        clumpChance = 0.18,
        clumpSize = 3,
        maxSteep = 0.55,
        waterMargin = 3,
        scaleJitter = 0.15,
        pathMargin = 7,
        footingRadius = 2.5,
        footingMaxDrop = 4,
        -- grove pre-pass fix (2026-07-30): the per-sample gate (steep/footing/
        -- spacing) was rejecting canopy so uniformly that the forest read as a
        -- thin, even scatter instead of a wood — real trees cluster. Anchors
        -- dart-thrown at 55-stud spacing each grow a 5-10 member clump.
        -- gate feedback (2026-07-31): bigger groves with youngsters among the
        -- elders sell the grove read. gate feedback (2026-07-31, again):
        -- fewer, fuller stands; slots retry for ground.
        grove = {
            spacing = 45,
            radiusMin = 8,
            radiusMax = 20,
            membersMin = 5,
            membersMax = 10,
            memberSpacing = 7,
            dominantScale = 1.25,
            anchorDarts = 300,
            maxGroves = 12,
            memberTries = 6,
            saplings = {
                chance = 0.25,
                map = {
                    XfHinokiT = "XfHinokiYb",
                    XfHinokiMT = "XfHinokiYb",
                    XfSpruceMT = "XfSpruceYb",
                    XfFirMT = "XfFirYb",
                    XfSugi25T = "XfSugiYb",
                },
            },
        },
    },
    -- BRUSH band (2-5 studs): young growth at knee-to-chest height. This is what
    -- makes the forest read heavy where players actually walk, WITHOUT intruding
    -- on the sightline band — the trimmed canopy above is bare at head height by
    -- design. Cheap: 2.6-7k tris each against 17-39k for the canopy.
    -- The pool is the 4-stud …Yb models; scaleJitter is capped so the tallest
    -- possible draw (4.3 x 1.15 = 4.9) still clears the 5-stud eyeline.
    PreserveBrush = {
        pool = {
            { name = "XfHinokiYb", weight = 30 },
            { name = "XfSpruceYb", weight = 30 },
            { name = "XfFirYb", weight = 25 },
            { name = "XfSugiYb", weight = 15 },
            -- small tiers (2026-07-30): the brush band read uniformly ~4 studs
            -- tall (same models, jitter alone) — flat and unconvincing height
            -- variety. Discrete small-scale entries at 0.65x give a real short
            -- tier within the 2-5 stud band instead of widening jitter (which
            -- would risk poking through the 5-stud sightline).
            { name = "XfHinokiYb", weight = 15, scale = 0.65 },
            { name = "XfSpruceYb", weight = 15, scale = 0.65 },
            { name = "XfFirYb", weight = 10, scale = 0.65 },
        },
        spacingMin = 6,
        spacingMax = 10,
        clumpChance = 0.35,
        clumpSize = 3,
        maxSteep = 0.6,
        waterMargin = 3,
        scaleJitter = 0.15,
        layer = "understory",
        pathMargin = 4,
        footingRadius = 1.5,
        footingMaxDrop = 3,
        -- clearing the floor is most of what tending a wood actually is:
        -- understory thins hard in tended yards, less so in a plain garden
        careDensity = { GARDEN = 0.25, TENDED = 0.6 },
        -- groveAffinity (2026-07-30): thickens brush around PreserveCore's
        -- grove clumps (real understory grows densest under a stand) instead
        -- of scattering uniformly across the whole zone.
        groveAffinity = { radius = 22, inside = 1, outside = 0.25 },
    },
    WallFringe = {
        pool = {
            -- the Xfrog untrimmed adults, foliated to the ground on purpose:
            -- the fringe backs onto the canyon wall, not a sightline a player
            -- walks through, so a full-height stand is correct here.
            { name = "XfHinokiM", weight = 30 },
            { name = "XfSpruceM", weight = 30 },
            { name = "XfFirM", weight = 25 },
            { name = "XfSugi40", weight = 15 },
        },
        spacingMin = 10,
        spacingMax = 16,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.9,
        waterMargin = 4,
        scaleJitter = 0.35,
        pathMargin = 5,
        -- halved 2026-07-27: the fringe conifers still read far too big
        -- against the canyon (placed heights were 30/66/93 min/median/max)
        heightScale = 0.5,
        -- walls are steep; sparser footing is accepted here
        footingRadius = 3,
        footingMaxDrop = 6,
    },
    WaterMargin = {
        pool = {
            { name = "ReedClump", weight = 28 },
            { name = "TallWeeds", weight = 27 },
            { name = "WeedStalks", weight = 20 },
            { name = "FernClump", weight = 15 },
            -- sparse iris = the waterline's jewel accent; the hand-composed
            -- falls-pool planting remains separate and untouched.
            { name = "IrisA", weight = 5 },
            { name = "IrisB", weight = 5 },
        },
        spacingMin = 4,
        spacingMax = 8,
        clumpChance = 0.3,
        clumpSize = 3,
        -- weeds on steep hillsides just look bad (user)
        maxSteep = 0.35,
        waterMargin = 0,
        scaleJitter = 0.25,
        -- hug the real (meandering) shoreline from Sandbox.WaterMap.WaterMarkers
        -- rather than carpeting the zone; 8 studs of bank either side.
        nearWater = 8,
        -- ground cover spaces against other ground cover only, never against trees
        layer = "ground",
        footingRadius = 1,
        footingMaxDrop = 2,
        -- partial submersion is a feature: reeds and grass can wade
        submergeMax = 1.0,
    },
    -- ONE dense dark stand at a user-marked spot: sugi is the shrine-grove
    -- species and grows exactly this way. Zone: Sandbox.FoliageZones.Grove_Sugi.
    SugiStand = {
        pool = {
            -- the TurboSquid hero set: open, wind-formed, scrub-pine vertical
            -- character (user's pick over Xfrog's plantation-conical JA06)
            { name = "SugiHero_SugiSmart", weight = 20 },
            { name = "SugiHero_SugiB", weight = 16 },
            { name = "SugiHero_SugiC", weight = 16 },
            { name = "SugiHero_SugiD", weight = 16 },
            { name = "SugiHero_SugiE", weight = 16 },
            { name = "SugiHero_SugiF", weight = 16 },
        },
        spacingMin = 5,
        spacingMax = 8,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.55,
        waterMargin = 3,
        scaleJitter = 0.15,
        pathMargin = 4,
        footingRadius = 2.5,
        footingMaxDrop = 6,
        -- gate feedback (2026-07-31): adult-heavy shrine stand centred on the
        -- user's mark.
        grove = {
            spacing = 30,
            radiusMin = 4,
            radiusMax = 16,
            membersMin = 7,
            membersMax = 10,
            memberSpacing = 4.5,
            dominantScale = 1.2,
            anchorDarts = 200,
            maxGroves = 1,
            memberTries = 16,
            -- free-mix: hero stand draws all six sculpted variants
            coherent = false,
            saplings = {
                chance = 0.25,
                map = {
                    SugiHero_SugiSmart = "XfSugiYb",
                    SugiHero_SugiB = "XfSugiYb",
                    SugiHero_SugiC = "XfSugiYb",
                    SugiHero_SugiD = "XfSugiYb",
                    SugiHero_SugiE = "XfSugiYb",
                    SugiHero_SugiF = "XfSugiYb",
                },
            },
        },
    },
    -- User-placed maple grove (2026-07-31 mark at -351, -48): jewel accent as a
    -- deliberate composed moment, free-mix over both maple sizes. Zone:
    -- Sandbox.FoliageZones.Grove_Maple.
    MapleStand = {
        pool = {
            { name = "XfMapleA", weight = 40 },
            { name = "XfMapleM", weight = 60 },
        },
        spacingMin = 5,
        spacingMax = 8,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.55,
        waterMargin = 3,
        scaleJitter = 0.15,
        pathMargin = 4,
        footingRadius = 2.5,
        footingMaxDrop = 6,
        grove = {
            spacing = 30,
            radiusMin = 4,
            radiusMax = 16,
            membersMin = 5,
            membersMax = 8,
            memberSpacing = 5.5,
            dominantScale = 1.2,
            anchorDarts = 200,
            maxGroves = 1,
            memberTries = 16,
            coherent = false,
        },
    },
    FutureClearing = {
        pool = {
            { name = "XfHinokiMT", weight = 35 },
            { name = "XfFirMT", weight = 35 },
            { name = "XfHinokiYb", weight = 30 },
        },
        spacingMin = 20,
        spacingMax = 30,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.55,
        waterMargin = 4,
        scaleJitter = 0.15,
        pathMargin = 6,
        innerClear = 0.5,
    },
}
return Recipes
