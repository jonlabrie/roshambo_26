--!strict
-- Zone recipes for the forest preserve (spec 2026-07-27-forest-preserve-foliage-design).
-- Data only: the ZoneScatter planner interprets these. Tune values live at the gates.
-- submergeMax on a SPECIES overrides the recipe-level value for that species only:
-- reeds wade, ferns must keep dry feet, and one pool can hold both.
export type Species = { name: string, weight: number, scale: number?, submergeMax: number? }
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
    -- same mechanism keyed on the SHORE ROCKS instead of grove anchors: real bank
    -- plants gather at and between stones rather than scattering evenly, which is
    -- what makes the planting and the ishigumi read as one composed shoreline.
    rockAffinity: GroveAffinity?,
    -- terrain GRASS painting along the waterline (2026-08-01 user gate): the kit has
    -- nothing under 2.4 studs, so the 0-2 band can only come from Roblox's own terrain
    -- grass — free to render, and the reeds then stand IN it instead of on bare rock.
    -- `below` extends the paint INTO the shallows (the user's note: a bit of grass
    -- washing in the water sells the untended shoreline).
    -- `reach` is the grass band's own width (it used to borrow nearWater, which
    -- painted across the trail); `pathMargin` keeps it off built geometry.
    grassPaint: {
        below: number,
        above: number,
        maxSlope: number,
        reach: number?,
        pathMargin: number?,
    }?,
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
        -- gate-tuned 2026-07-31 (previously per-bake overrides): looser path
        -- standoff + footing tolerance let the canopy actually take the slopes
        pathMargin = 5,
        footingRadius = 2.5,
        footingMaxDrop = 6,
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
    -- THE WALL FRINGE: a continuous green mass backing onto the canyon walls.
    -- Rebuilt 2026-08-01 (user: "scattered by the previous non-grove logic ...
    -- looking pretty sparse"). It was the ONLY canopy recipe with no grove and
    -- clumpChance = 0, so it read as an even, thin scatter while every other
    -- wood in the canyon had learned to cluster.
    --
    -- IT IS DELIBERATELY NOT GROVED THE WAY THE WOODS ARE. A grove works by
    -- anchors separated by real MEADOW GAPS — and a gap in the fringe exposes
    -- the bare rock the fringe exists to hide. So the anchors are packed at 22
    -- studs (against PreserveCore's 45) so the clumps OVERLAP: coverage stays
    -- continuous, but density varies the way a real hillside forest does —
    -- thicker in the folds, thinner on the ribs, with emergent taller trees
    -- (dominantScale 1.35) breaking the canopy line.
    -- THE WALL FRINGE: a continuous green mass over the canyon walls and the
    -- plateau beyond. Rewritten TWICE on 2026-08-01, and the second rewrite is
    -- the instructive one:
    --
    -- It was first given a GROVE (clusters), reasoning that it "read as random
    -- scatter" like the woods had. Wrong diagnosis. A grove pre-pass caps output
    -- at maxGroves x members AND excludes the zone from per-sample resolution, so
    -- once the cap is spent the rest of the zone gets nothing however good the
    -- ground is. The user found an area where 163 of 441 samples passed every gate
    -- and only 18 trees stood: "perfectly plantable areas you're completely
    -- skipping." Cluster count is the wrong control for a mass whose job is
    -- COVERAGE.
    --
    -- Per-sample scatter considers every eligible sample, so coverage is complete
    -- by construction and `spacing` means trees-per-area. What the fringe always
    -- lacked was not groves but CLUMPING — the original had clumpChance = 0, the
    -- actual reason it read as an even carpet. 0.55/4 gives lumpy density inside
    -- full coverage: both properties at once, which a grove cannot do here.
    WallFringe = {
        pool = {
            -- the Xfrog untrimmed adults, foliated to the ground on purpose:
            -- the fringe backs onto the canyon wall, not a sightline a player
            -- walks through, so a full-height stand is correct here.
            { name = "XfHinokiM", weight = 26 },
            { name = "XfSpruceM", weight = 24 },
            { name = "XfFirM", weight = 22 },
            { name = "XfSugi40", weight = 12 },
            -- age variation: the fringe had none — every tree an identical adult
            { name = "XfHinokiYr", weight = 5 },
            { name = "XfFirYr", weight = 4 },
            -- a splash of colour (user): "not as much as the canyon, but something
            -- to catch the wandering eye." Both ride the LOD geometry (21.1k).
            { name = "XfMapleGold", weight = 4 },
            { name = "XfMapleRed", weight = 3 },
        },
        -- spacing IS the density dial now; 16-26 reads lighter than the grove
        -- version did ("a bit much" on the skyline) while covering everything
        spacingMin = 16,
        spacingMax = 26,
        -- the missing ingredient all along: clusters WITHIN full coverage
        clumpChance = 0.55,
        clumpSize = 4,
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
    -- THE WILD REACH (x -420..-90): the upper canyon, where care barely reaches.
    -- Lush, scraggly, reed-led — the register the user approved as "untended wild
    -- shoreline" (2026-08-01), whose real ingredient turned out to be terrain grass.
    WaterMargin = {
        pool = {
            { name = "ReedClump", weight = 30, submergeMax = 1.2 },
            { name = "TallWeeds", weight = 24, submergeMax = 0.8 },
            { name = "WeedStalks", weight = 18, submergeMax = 0.5 },
            -- ferns keep DRY FEET: 0 means they refuse any standing water
            { name = "FernClump", weight = 10, submergeMax = 0 },
            -- iris raised from 5+5: the user's favourite waterline asset, and the
            -- pink at the waterline is meant to be iris (the muhly is parked)
            { name = "IrisA", weight = 22, submergeMax = 0.6, nearWater = 4 },
            { name = "IrisB", weight = 22, submergeMax = 0.6, nearWater = 4 },
            -- LOW TIER: the same models at half scale read as marsh grass under the
            -- taller stems, breaking the uniform 2.4-4 stud carpet the gate flagged
            { name = "ReedClump", weight = 8, scale = 0.5, submergeMax = 1.2 },
            { name = "TallWeeds", weight = 8, scale = 0.55, submergeMax = 0.8 },
        },
        -- spacing here is INTRA-HANDFUL, not between stations (stationSpacing does
        -- that). It must stay well below `spread` or the first member of a handful
        -- vetoes its own companions — at 4 studs against a 4-stud spread every
        -- station came out with a single plant and nothing mixed.
        spacingMin = 2,
        spacingMax = 4,
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
        -- OUTER bound: the per-species values above do the real gating
        submergeMax = 1.2,
        -- the wild reach barely thins where tending reaches it
        careDensity = { GARDEN = 0.5, TENDED = 0.7 },
        rockAffinity = { radius = 5, inside = 1.4, outside = 0.9 },
        grassPaint = { below = 1, above = 4, maxSlope = 0.5, reach = 5, pathMargin = 3 },
        -- SHORELINE STATIONS (user gate 2026-08-01): "a line of shuffled mixes
        -- marching along the shore". Area-scatter spread plants across the whole
        -- bank with no sense of the water running through it, and its clumps were
        -- monospecific — three reeds or three ferns, never a handful. Stations walk
        -- the shore at a fixed spacing and each one plants a MIXED group whose
        -- members roll species independently. The per-species nearWater/submergeMax
        -- gates then sort each handful wet-to-dry on their own, so an iris and a
        -- fern can be co-located without either being fenced into its own band.
        shoreline = {
            -- 8/4-7, tuned live 2026-08-01: at 14/3-6 the shore carried 101 plants
            -- and only ~22 iris across 700 studs of bank, which clustered by chance
            -- into a 179-stud stretch of north shore with a single iris in it. The
            -- user read that as "no iris on the north shore" — it was small-number
            -- gapping, not a bias, and density is the cure.
            stationSpacing = 8,
            membersMin = 4,
            membersMax = 7,
            spread = 4,
            -- stations sit at the water's EDGE; members reach out from there.
            -- 5, not 2: the sample grid is 4 studs, so a band under ~3 matches NO
            -- sample and the zone plans to zero (caught by planning before baking).
            -- Anything in 3..6 selects the same set — the samples adjacent to a
            -- water cell — so 5 sits safely inside that plateau.
            stationBand = 5,
            -- 0, not 5: the inland push existed to stop a handful sitting entirely
            -- in the water, but the per-species wading limits already do that job
            -- properly. All the push did was drag every handful off the shore,
            -- which is what starved the iris.
            inland = 0,
        },
    },
    -- THE TENDED REACH (x -90..220, zone MarginTended): the arena end, where the care
    -- model's reach is at its widest (28 studs vs 8 at the head). Iris-led, sparser,
    -- deliberately composed AT the stones — a garden waterline, not a wild one.
    WaterMarginTended = {
        pool = {
            { name = "IrisA", weight = 38, submergeMax = 0.6, nearWater = 4 },
            { name = "IrisB", weight = 38, submergeMax = 0.6, nearWater = 4 },
            { name = "ReedClump", weight = 20, submergeMax = 1.2 },
            { name = "TallWeeds", weight = 12, submergeMax = 0.8 },
            { name = "FernClump", weight = 8, submergeMax = 0 },
            { name = "WeedStalks", weight = 8, submergeMax = 0.5 },
            { name = "ReedClump", weight = 6, scale = 0.5, submergeMax = 1.2 },
        },
        -- sparser and more deliberate than the wild reach
        -- see WaterMargin: intra-handful spacing, must stay below `spread`
        spacingMin = 2.5,
        spacingMax = 5,
        clumpChance = 0.4,
        clumpSize = 3,
        maxSteep = 0.35,
        waterMargin = 0,
        scaleJitter = 0.25,
        nearWater = 7,
        layer = "ground",
        footingRadius = 1,
        footingMaxDrop = 2,
        submergeMax = 1.2,
        -- thins HARD where tending reaches: a tended bank shows its stones and water
        careDensity = { GARDEN = 0.25, TENDED = 0.5 },
        -- stronger than wild: in a garden the planting gathers at the stones on purpose
        rockAffinity = { radius = 6, inside = 1.6, outside = 0.7 },
        -- narrower band than wild, so more shore reads as deliberate
        grassPaint = { below = 1, above = 3, maxSlope = 0.5, reach = 5, pathMargin = 3 },
        -- a tended shore: stations further apart and handfuls smaller, so the
        -- planting reads as placed rather than grown (see WaterMargin's note)
        shoreline = {
            -- the tended shore stays sparser than the wild one, but not empty
            stationSpacing = 12,
            membersMin = 3,
            membersMax = 5,
            spread = 4,
            stationBand = 5,
            inland = 0,
        },
    },
    -- ONE dense dark stand at a user-marked spot: sugi is the shrine-grove
    -- species and grows exactly this way. Zone: ServerStorage.FoliageZones.Grove_Sugi.
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
    -- ServerStorage.FoliageZones.Grove_Maple.
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
        -- gate-tuned 2026-07-31 (previously per-bake overrides)
        pathMargin = 4,
        footingMaxDrop = 6,
        innerClear = 0.5,
    },
}
return Recipes
