--!strict
-- scatterPreserve.luau — zone-painted forest-preserve planting (spec
-- 2026-07-27-forest-preserve-foliage-design). Run via MCP execute_luau (Edit).
--
-- MODE="plan"  prints per-zone placement counts, stamps nothing.
-- MODE="bake"  wipes then stamps the filtered zones' folders.
-- MODE="wipe"  removes the filtered zones' folders.
-- MODE="mist"  wipes + stamps ONLY Preserve.Mist (safe after trees are curated).
--
-- Zones are USER-EDITABLE parts in ServerStorage.FoliageZones: box or
-- cylinder, attributes Recipe (string), DensityScale (number?), Seed (number?),
-- Mist (bool?), Still (bool?). Drag/resize/duplicate/delete them freely; the
-- bake reads whatever is there. Bakes land in CanyonWorld.Foliage.Preserve.<Zone>
-- (PLACE-ONLY — save the place to keep them).
--
-- ⚠️ SYNC WARNING: Studio cannot require from disk, so FOUR sources are
-- mirrored inline below — KEEP ALL IN SYNC (same convention as
-- CanopyScatter/placeCanopyHeroes, and buildMossTransitions' own keep-out
-- mirror):
--   * the planner (types, lcg, gates, plan)     MIRRORS tools/builders/ZoneScatter.luau
--   * the recipe table (RECIPES)                MIRRORS tools/studio/foliageZoneRecipes.luau
--   * the keep-outs (KEEPOUT_MATERIALS/ZONES)   MIRROR  tools/builders/CanyonKeepOuts.luau
--   * the care model (careReach/careModelBand)  MIRRORS tools/builders/CareModel.luau
-- Determinism: integer LCG only, seeded per zone, so a re-bake reproduces the
-- identical forest and gate iteration is parameter edits, not lost state.
local ServerStorage = game:GetService("ServerStorage")

local MODE = "plan" -- default mode; override per call via opts.mode
local ZONES: { string } = {} -- default filter (empty = every zone); override via opts.zones
local SAMPLE_PITCH = 4 -- terrain probe grid, studs
local PROBE_TOP = 400

-- ── recipes (MIRROR of tools/studio/foliageZoneRecipes.luau) ────────────────
-- `submergeMax` narrows the recipe-level submergence gate to THIS species only —
-- a fern shouldn't wade as deep as a reed sharing its pool. nil = defer to the
-- recipe, exactly as if the field didn't exist.
type Species = {
    name: string,
    weight: number,
    scale: number?,
    submergeMax: number?,
    -- NARROWS the recipe's nearWater for THIS species only. Iris is a water's-edge
    -- plant: it belongs in the first few studs of bank, not across the whole margin
    -- a reed is happy in (user gate 2026-08-01).
    nearWater: number?,
}
type Recipe = {
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
    -- per-sample scatter: dart-thrown anchors each grow a small species-coherent
    -- clump (an oversized elder + dominant/attendant members), with real meadow
    -- gaps between groves. The zone is excluded from per-sample resolution.
    grove: GroveConfig?,
    -- if set (on a DIFFERENT recipe, typically an understory layer), the
    -- effective density near any grove anchor is multiplied by `inside`
    -- instead of `outside`, so ground cover thickens around the groves.
    groveAffinity: GroveAffinity?,
    -- same mechanism keyed on the SHORE ROCKS: real bank plants gather at and
    -- between stones, which is what makes the planting and the ishigumi read as
    -- one composed shoreline instead of two independent passes
    rockAffinity: GroveAffinity?,
    -- terrain GRASS painting along the waterline; `below` extends the paint INTO
    -- the shallows so a little grass washes in the water
    grassPaint: { below: number, above: number, maxSlope: number }?,
    -- 2026-08-01 user gate: "your approach is also either/or, never and ...
    -- I like the shuffled mix, but it should be a line of shuffled mixes
    -- marching along the shore." The old per-sample nearWater band read as a
    -- monospecific clump-scatter smeared across the whole margin, not a line
    -- following the water. If set, this recipe's zone runs a SHORELINE
    -- PRE-PASS instead of the ordinary per-sample scatter (modelled closely
    -- on `grove` above): stations are chosen by exhaustive greedy selection
    -- walking the shore, and each station's members independently roll
    -- their OWN species via pickWadingSpecies — one mixed handful sorts
    -- itself wet-to-dry instead of a clump inheriting a single parent
    -- species. The zone is excluded from per-sample resolution, exactly
    -- like a grove-recipe zone.
    shoreline: ShorelineConfig?,
}
type GroveConfig = {
    spacing: number, -- min distance between grove ANCHORS (meadows live between)
    -- DEPRECATED / unused by the exhaustive placer below: candidate-to-anchor
    -- proximity is now governed entirely by radiusMax (ceiling) and
    -- memberSpacing (floor between placed members), so a separate minimum
    -- radius from the anchor is redundant. Kept in the type so existing
    -- recipe literals don't need to drop the field; never read.
    radiusMin: number,
    -- member distance from the anchor. Also the support radius: a candidate's
    -- "support" is how many other candidates sit within radiusMax of it, the
    -- density measure anchors are chosen by.
    radiusMax: number,
    membersMin: number,
    membersMax: number, -- trees per grove INCLUDING the elder
    memberSpacing: number, -- min distance between members of the same layer
    dominantScale: number, -- the elder's extra scale multiplier
    -- DEPRECATED / unused: the grove pre-pass no longer dart-throws (a
    -- single-dart-per-slot design left legal ground unused while stands
    -- starved — confirmed in-world). Placement is now exhaustive: every
    -- terrain sample that clears the site gates is a placement CANDIDATE.
    -- Kept in the type so existing recipe literals don't need to drop the
    -- field; never read.
    anchorDarts: number,
    maxGroves: number,
    -- optional: a MEMBER (never the elder) whose rolled species has a map
    -- entry may be swapped for a young/sapling model name, chance-gated.
    -- Scale/jitter/heightScale are unchanged — young models are naturally
    -- small, this only substitutes the placed name.
    saplings: { chance: number, map: { [string]: string } }?,
    -- DEPRECATED / unused: retries existed to give a single dart another
    -- shot at hostile ground. The exhaustive placer has no darts to retry —
    -- it already considers every legal candidate. Kept in the type so
    -- existing recipe literals don't need to drop the field; never read.
    memberTries: number?,
    -- optional: false = FREE-MIX. Every placement (elder included) draws its
    -- species independently from the full pool instead of the dominant/
    -- attendant pair, for a "hero stand" that's genuinely mixed. Default/nil
    -- = true = the ordinary coherent dominant/attendant grove.
    coherent: boolean?,
}
type GroveAffinity = { radius: number, inside: number, outside: number }
-- 2026-08-01 user gate: "a line of shuffled mixes marching along the shore."
-- stationSpacing/spread/inland are studs; membersMin/Max bound how many
-- plants (independently-species'd, see the shoreline pre-pass below) sit at
-- one station.
type ShorelineConfig = {
    stationSpacing: number, -- min distance between stations ALONG the shore
    membersMin: number,
    membersMax: number, -- plants per station
    spread: number, -- max offset of a member from its station
    inland: number, -- how far a member may be pushed AWAY from water
}
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
-- a hand-placed composition layer, not scattered by the planner below.
local RECIPES: { [string]: Recipe } = {
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
    WaterMargin = {
        pool = {
            { name = "ReedClump", weight = 30, submergeMax = 1.2 },
            { name = "TallWeeds", weight = 24, submergeMax = 0.8 },
            { name = "WeedStalks", weight = 18, submergeMax = 0.5 },
            -- ferns keep DRY FEET: 0 means they refuse any standing water
            { name = "FernClump", weight = 10, submergeMax = 0 },
            -- iris raised from 5+5: the user's favourite waterline asset, and the
            -- pink at the waterline is meant to be iris (the muhly is parked)
            { name = "IrisA", weight = 9, submergeMax = 0.6, nearWater = 4 },
            { name = "IrisB", weight = 9, submergeMax = 0.6, nearWater = 4 },
            -- LOW TIER: the same models at half scale read as marsh grass under the
            -- taller stems, breaking the uniform 2.4-4 stud carpet the gate flagged
            { name = "ReedClump", weight = 8, scale = 0.5, submergeMax = 1.2 },
            { name = "TallWeeds", weight = 8, scale = 0.55, submergeMax = 0.8 },
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
        -- OUTER bound: the per-species values above do the real gating
        submergeMax = 1.2,
        -- the wild reach barely thins where tending reaches it
        careDensity = { GARDEN = 0.5, TENDED = 0.7 },
        rockAffinity = { radius = 5, inside = 1.4, outside = 0.9 },
        grassPaint = { below = 1, above = 4, maxSlope = 0.5 },
        -- SHORELINE STATIONS (user gate 2026-08-01): "a line of shuffled mixes
        -- marching along the shore". Area-scatter spread plants across the whole
        -- bank with no sense of the water running through it, and its clumps were
        -- monospecific — three reeds or three ferns, never a handful. Stations walk
        -- the shore at a fixed spacing and each one plants a MIXED group whose
        -- members roll species independently. The per-species nearWater/submergeMax
        -- gates then sort each handful wet-to-dry on their own, so an iris and a
        -- fern can be co-located without either being fenced into its own band.
        shoreline = {
            stationSpacing = 14,
            membersMin = 3,
            membersMax = 6,
            spread = 4,
            inland = 5,
        },
    },
    WaterMarginTended = {
        pool = {
            { name = "IrisA", weight = 26, submergeMax = 0.6, nearWater = 4 },
            { name = "IrisB", weight = 26, submergeMax = 0.6, nearWater = 4 },
            { name = "ReedClump", weight = 20, submergeMax = 1.2 },
            { name = "TallWeeds", weight = 12, submergeMax = 0.8 },
            { name = "FernClump", weight = 8, submergeMax = 0 },
            { name = "WeedStalks", weight = 8, submergeMax = 0.5 },
            { name = "ReedClump", weight = 6, scale = 0.5, submergeMax = 1.2 },
        },
        -- sparser and more deliberate than the wild reach
        spacingMin = 6,
        spacingMax = 11,
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
        grassPaint = { below = 1, above = 3, maxSlope = 0.5 },
        -- a tended shore: stations further apart and handfuls smaller, so the
        -- planting reads as placed rather than grown (see WaterMargin's note)
        shoreline = {
            stationSpacing = 20,
            membersMin = 2,
            membersMax = 4,
            spread = 3,
            inland = 4,
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

-- ── planner (MIRROR of tools/builders/ZoneScatter.luau) ─────────────────────
type Sample = { x: number, z: number, y: number, steep: number, depth: number?, material: string? }
type Zone = {
    name: string,
    shape: string,
    bounds: { number },
    recipe: string,
    densityScale: number,
    seed: number,
    mist: boolean?,
    still: boolean?,
    -- optional height band (zones are 2D unless the part sets Vertical=true)
    yMin: number?,
    yMax: number?,
}
type Placement = {
    x: number,
    z: number,
    y: number,
    species: string,
    yaw: number,
    scale: number,
    zone: string,
    layer: string,
}
type MistAnchor = { x: number, z: number, y: number, zone: string }

local MIST_SPACING = 30
local MIST_SEED_OFFSET = 500000
local MIST_DARTS = 128
local CLUMP_RADIUS_MIN = 4
local CLUMP_RADIUS_MAX = 7
local GROVE_SEED_OFFSET = 900000
-- member species: roll below this fraction plants the dominant, else the
-- attendant, so groves read as one species with a minority accent
local GROVE_ATTENDANT_THRESHOLD = 0.6
-- every grove placement (elder included) is a literal terrain grid point
-- until jittered by up to this many studs per axis, so a grove doesn't read
-- as trees standing on a lattice
local GROVE_JITTER_MAX = 1.2
local SHORE_SEED_OFFSET = 700000
-- the four cardinal directions probed (at `pitch` distance) to find which
-- way a shore station should push its members "inland"
local SHORE_PROBE_DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function seedState(seed: number): number
    return (seed * 2654435761) % 2147483648 + 1
end

local function containsXZ(zone: Zone, x: number, z: number): boolean
    local b = zone.bounds
    if zone.shape == "circle" then
        local dx, dz = x - b[1], z - b[2]
        return dx * dx + dz * dz <= b[3] * b[3]
    end
    return x >= b[1] and z >= b[2] and x <= b[3] and z <= b[4]
end

local function contains(zone: Zone, x: number, z: number, y: number?): boolean
    if not containsXZ(zone, x, z) then
        return false
    end
    if y ~= nil then
        if zone.yMin ~= nil and y < zone.yMin then
            return false
        end
        if zone.yMax ~= nil and y > zone.yMax then
            return false
        end
    end
    return true
end

-- true if any KeepOut zone claims (x, z, y) — regardless of layer order, a
-- pad is a pad. Shared by resolveZone (the per-sample path) and the grove
-- pre-pass, so a dart or a grove member is vetoed exactly like an ordinary
-- sample would be.
local function keepOutAt(zones: { Zone }, x: number, z: number, y: number?): boolean
    for _, zone in zones do
        if zone.recipe == "KeepOut" and contains(zone, x, z, y) then
            return true
        end
    end
    return false
end

-- KeepOut vetoes regardless of layer order; otherwise zones are tried LAST-first
-- and the first whose recipe accepts the sample wins, so a layered zone claims
-- only the ground its recipe wants (shore margin over forest body).
local function resolveZone(
    zones: { Zone },
    x: number,
    z: number,
    y: number?,
    accepts: ((Zone) -> boolean)?
): Zone?
    if keepOutAt(zones, x, z, y) then
        return nil
    end
    for i = #zones, 1, -1 do
        local zone = zones[i]
        if zone.recipe ~= "KeepOut" and contains(zone, x, z, y) then
            if accepts == nil or accepts(zone) then
                return zone
            end
        end
    end
    return nil
end

local function inInnerClear(zone: Zone, frac: number, x: number, z: number): boolean
    local b = zone.bounds
    if zone.shape == "circle" then
        local dx, dz = x - b[1], z - b[2]
        local r = frac * b[3]
        return dx * dx + dz * dz < r * r
    end
    local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
    local hw, hh = frac * (b[3] - b[1]) / 2, frac * (b[4] - b[2]) / 2
    return math.abs(x - cx) < hw and math.abs(z - cz) < hh
end

local function pickSpecies(pool: { Species }, r: number): (string, number, number?, number?)
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = r * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name, s.scale or 1, s.submergeMax, s.nearWater
        end
    end
    local last = pool[#pool]
    return last.name, last.scale or 1, last.submergeMax, last.nearWater
end

-- a wet sample already cleared the recipe-level submergeMax (the OUTER bound) in
-- `accepts` before any species is drawn. This re-rolls a fresh draw — same stream,
-- not a separate one — up to 4 times when the species it lands on can't personally
-- tolerate this depth, and gives up rather than forcing a dry-footed species into
-- water because it won the weight roll. A dry sample always clears on the FIRST
-- draw, so a pool with no overrides costs exactly the one roll it always did.
local MAX_SUBMERGE_ATTEMPTS = 4

local function pickWadingSpecies(
    pool: { Species },
    depth: number,
    recipeSubmergeMax: number?,
    rollFn: () -> number,
    waterOk: ((number) -> boolean)?
): (string?, number, number?)
    for _ = 1, MAX_SUBMERGE_ATTEMPTS do
        local name, scale, speciesMax, speciesNear = pickSpecies(pool, rollFn())
        local limit = if speciesMax ~= nil then speciesMax else recipeSubmergeMax
        local wet = depth <= (limit or 0)
        -- a species may only NARROW the recipe's bank width, never widen it
        local bankOk = true
        if wet and speciesNear ~= nil and waterOk ~= nil then
            bankOk = waterOk(speciesNear)
        end
        if wet and bankOk then
            return name, scale, speciesMax
        end
    end
    return nil, 1, nil
end

-- grove COHERENT members choose between the already-rolled dominant/attendant pair
-- (a threshold roll, not a fresh draw) — this re-rolls that SAME threshold against
-- the member's own depth, which can differ from the elder's.
local function pickWadingCoherentMember(
    domSpecies: string,
    domScale: number,
    domLimit: number?,
    attSpecies: string,
    attScale: number,
    attLimit: number?,
    depth: number,
    rollFn: () -> number
): (string?, number)
    for _ = 1, MAX_SUBMERGE_ATTEMPTS do
        local species, scale, limit
        if rollFn() < GROVE_ATTENDANT_THRESHOLD then
            species, scale, limit = domSpecies, domScale, domLimit
        else
            species, scale, limit = attSpecies, attScale, attLimit
        end
        if depth <= (limit or 0) then
            return species, scale
        end
    end
    return nil, 1
end

local function nearestSample(samples: { Sample }, x: number, z: number): Sample?
    local bestD, best = math.huge, nil
    for _, s in samples do
        local dx, dz = s.x - x, s.z - z
        local d = dx * dx + dz * dz
        if d < bestD then
            bestD, best = d, s
        end
    end
    return best
end

local function nearestY(samples: { Sample }, x: number, z: number): number
    local bestD, bestY = math.huge, 0
    for _, s in samples do
        local dx, dz = s.x - x, s.z - z
        local d = dx * dx + dz * dz
        if d < bestD then
            bestD, bestY = d, s.y
        end
    end
    return bestY
end

-- Water proximity (MIRROR of ZoneScatter). Cells come from the place's real
-- water map (Sandbox.WaterMap.WaterMarkers, grid-4 raycast-true water), bucketed
-- so per-sample lookups stay cheap. The care-distance index (below) reuses the
-- same bucket size and index shape.
local WATER_BUCKET = 16
type WaterIndex = { [string]: { { number } } }

local function indexWater(cells: { { number } }): WaterIndex
    local index: WaterIndex = {}
    for _, c in cells do
        local key = `{math.floor(c[1] / WATER_BUCKET)},{math.floor(c[2] / WATER_BUCKET)}`
        local bucket = index[key]
        if bucket == nil then
            bucket = {}
            index[key] = bucket
        end
        table.insert(bucket, c)
    end
    return index
end

local function waterWithin(index: WaterIndex?, x: number, z: number, dist: number): boolean
    if index == nil or dist <= 0 then
        return false
    end
    local reach = math.ceil(dist / WATER_BUCKET)
    local bx, bz = math.floor(x / WATER_BUCKET), math.floor(z / WATER_BUCKET)
    for gx = bx - reach, bx + reach do
        for gz = bz - reach, bz + reach do
            local bucket = index[`{gx},{gz}`]
            if bucket ~= nil then
                for _, c in bucket do
                    local dx, dz = x - c[1], z - c[2]
                    if dx * dx + dz * dz <= dist * dist then
                        return true
                    end
                end
            end
        end
    end
    return false
end

type SampleIndex = { [string]: Sample }
type PlanOptions = {
    pitch: number?,
    keepOut: ((number, number, string?) -> boolean)?,
    careBand: ((number, number) -> string)?,
}

local function sampleKey(x: number, z: number, pitch: number): string
    return `{math.floor(x / pitch + 0.5)},{math.floor(z / pitch + 0.5)}`
end

local function indexSamples(samples: { Sample }, pitch: number): SampleIndex
    local index: SampleIndex = {}
    for _, s in samples do
        index[sampleKey(s.x, s.z, pitch)] = s
    end
    return index
end

-- Max drop in studs from (x,z,y) to the ground at 8 compass probes `radius` out.
-- nil = a probe found NO sample (void: water, off-grid, past a lip) — callers
-- treat that as the WORST footing, never as level ground.
local function footingDrop(
    index: SampleIndex,
    pitch: number,
    x: number,
    z: number,
    y: number,
    radius: number
): number?
    local worst = 0
    for i = 0, 7 do
        local ang = i * math.pi / 4
        local probe = index[sampleKey(x + math.cos(ang) * radius, z + math.sin(ang) * radius, pitch)]
        if probe == nil then
            return nil
        end
        worst = math.max(worst, y - probe.y)
    end
    return worst
end

local function zoneBBox(zone: Zone): (number, number, number, number)
    local b = zone.bounds
    if zone.shape == "circle" then
        return b[1] - b[3], b[2] - b[3], b[1] + b[3], b[2] + b[3]
    end
    return b[1], b[2], b[3], b[4]
end

local function plan(
    zones: { Zone },
    samples: { Sample },
    recipes: { [string]: Recipe },
    water: WaterIndex?,
    built: WaterIndex?,
    opts: PlanOptions?
): ({ Placement }, { MistAnchor })
    local o: PlanOptions = opts or {}
    local pitch = o.pitch or 4
    local sampleIndex = indexSamples(samples, pitch)

    local ordered = table.clone(samples)
    table.sort(ordered, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)

    local states: { [Zone]: number } = {}
    for _, zone in zones do
        states[zone] = seedState(zone.seed)
    end
    local out: { Placement } = {}

    local function roll(zone: Zone): number
        local state, r = lcg(states[zone])
        states[zone] = state
        return r
    end

    -- separate LCG stream for the grove pre-pass, so adding/removing a grove
    -- recipe never perturbs the ordinary per-sample roll sequence of other zones
    local groveStates: { [Zone]: number } = {}
    local function groveRoll(zone: Zone): number
        local state, r = lcg(groveStates[zone])
        groveStates[zone] = state
        return r
    end

    -- separate LCG stream for the shoreline pre-pass, so adding/removing a
    -- shoreline recipe never perturbs the ordinary per-sample roll sequence
    -- of other zones (same reasoning as the grove stream above)
    local shoreStates: { [Zone]: number } = {}
    local function shoreRoll(zone: Zone): number
        local state, r = lcg(shoreStates[zone])
        shoreStates[zone] = state
        return r
    end

    -- site gates: everything that depends only on the sample and the recipe, so
    -- a layered zone that rejects a sample falls through to the zone beneath it
    local function accepts(zone: Zone, s: Sample): boolean
        if o.keepOut ~= nil and o.keepOut(s.x, s.z, s.material) then
            return false
        end
        local recipe = recipes[zone.recipe]
        if recipe == nil then
            return false
        end
        if s.steep > recipe.maxSteep then
            return false
        end
        local fr = recipe.footingRadius
        if fr ~= nil then
            local drop = footingDrop(sampleIndex, pitch, s.x, s.z, s.y, fr)
            if drop == nil or drop > (recipe.footingMaxDrop or 4) then
                return false
            end
        end
        local depth = s.depth or 0
        if depth > 0 then
            local submergeMax = recipe.submergeMax
            if submergeMax == nil or depth > submergeMax then
                return false
            end
        end
        local innerClear = recipe.innerClear
        if innerClear ~= nil and inInnerClear(zone, innerClear, s.x, s.z) then
            return false
        end
        -- water: trees stand back from the shore; margin flora must hug it
        if waterWithin(water, s.x, s.z, recipe.waterMargin) then
            return false
        end
        local nearWater = recipe.nearWater
        if nearWater ~= nil and not waterWithin(water, s.x, s.z, nearWater) then
            return false
        end
        local pathMargin = recipe.pathMargin
        if pathMargin ~= nil and waterWithin(built, s.x, s.z, pathMargin) then
            return false
        end
        return true
    end

    -- grove pre-pass: species-coherent clumps with real meadow gaps, for zones
    -- whose recipe requests them. Runs BEFORE the per-sample loop so grove
    -- placements are already in `out` and spacing-checked against by ordinary
    -- per-sample zones layered above or below (same array, same rules).
    --
    -- EXHAUSTIVE, not dart-thrown: a single-dart-per-slot design left legal
    -- ground unused while stands starved (confirmed in-world — a grove
    -- anchored at the zone edge because the centre's one dart happened to
    -- fail pathMargin). Every terrain sample that clears the site gates is a
    -- placement CANDIDATE; anchors and members are chosen from that pool by
    -- support/proximity, not by hoping a random throw lands well.
    local groveAnchors: { { number } } = {}
    for _, zone in zones do
        local recipe = recipes[zone.recipe]
        if recipe == nil or recipe.grove == nil then
            continue
        end
        local grove = recipe.grove :: GroveConfig
        local layer = recipe.layer or "canopy"
        local heightScale = recipe.heightScale or 1
        groveStates[zone] = seedState(zone.seed + GROVE_SEED_OFFSET)
        -- COHERENT (default: coherent ~= false): dominant + attendant species
        -- for this grove; excluding the dominant entry from the attendant
        -- roll degenerates to the same species when the pool only has one.
        -- FREE-MIX (coherent == false): every placement, elder included,
        -- draws independently from the full pool — a "hero stand" rather
        -- than a coherent clump. The dominant/attendant rolls never enter the
        -- stream in this mode: draw only what's used.
        local coherent = grove.coherent ~= false

        local x1, z1, x2, z2 = zoneBBox(zone)
        local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
        local zoneAnchors: { { number } } = {}

        -- CANDIDATES: every grid sample inside the zone (containsXZ + y-band,
        -- exactly what resolveZone checks) that clears the recipe's site
        -- gates and isn't vetoed by a KeepOut. `ordered` is already sorted
        -- (x then z), so this list — and every tie-break below that walks it
        -- in order — is deterministic.
        local candidates: { Sample } = {}
        for _, s in ordered do
            if contains(zone, s.x, s.z, s.y) and not keepOutAt(zones, s.x, s.z, s.y) and accepts(zone, s) then
                table.insert(candidates, s)
            end
        end

        -- support = how many OTHER remaining candidates sit within radiusMax
        -- of `c` — a live count against the CURRENT (shrinking) pool, so an
        -- already-claimed grove's ground doesn't inflate a later grove's odds
        local function supportOf(c: Sample): number
            local n = 0
            for _, other in candidates do
                if other ~= c then
                    local dx, dz = other.x - c.x, other.z - c.z
                    if dx * dx + dz * dz <= grove.radiusMax * grove.radiusMax then
                        n += 1
                    end
                end
            end
            return n
        end

        local function removeCandidate(target: Sample)
            for i, c in candidates do
                if c == target then
                    table.remove(candidates, i)
                    return
                end
            end
        end

        local function jitter(): number
            return (groveRoll(zone) * 2 - 1) * GROVE_JITTER_MAX
        end

        -- plants one grove (elder + members) at an anchor candidate that
        -- already cleared every site gate and (for multi-grove zones) the
        -- inter-anchor spacing check.
        local function placeGrove(anchor: Sample, memberTarget: number)
            removeCandidate(anchor)

            -- the elder plants exactly at the anchor, so the anchor's own depth is
            -- the depth to check; an empty grove is not a placement (no zoneAnchors
            -- entry) when nothing in the pool tolerates it
            local anchorDepth = anchor.depth or 0
            local domSpecies, domScale, domLimit, attSpecies, attScale, attLimit
            local elderSpecies, elderScale
            if coherent then
                domSpecies, domScale, domLimit = pickWadingSpecies(
                    recipe.pool,
                    anchorDepth,
                    recipe.submergeMax,
                    function()
                        return groveRoll(zone)
                    end
                )
                if domSpecies ~= nil then
                    local attPool: { Species } = {}
                    for _, sp in recipe.pool do
                        if sp.name ~= domSpecies then
                            table.insert(attPool, sp)
                        end
                    end
                    if #attPool == 0 then
                        attPool = recipe.pool
                    end
                    attSpecies, attScale, attLimit = pickSpecies(attPool, groveRoll(zone))
                    elderSpecies, elderScale = domSpecies, domScale
                end
            else
                elderSpecies, elderScale = pickWadingSpecies(
                    recipe.pool,
                    anchorDepth,
                    recipe.submergeMax,
                    function()
                        return groveRoll(zone)
                    end
                )
            end

            if elderSpecies == nil then
                return
            end
            table.insert(zoneAnchors, { anchor.x, anchor.z })

            -- every already-placed member of THIS grove (elder included),
            -- for the memberSpacing check below — scoped to the grove, not
            -- the whole `out` array, so a tight legal patch isn't sterilised
            -- by an unrelated grove's members standing nearby
            local groveMembers: { Sample } = { anchor }

            -- the elder plants at the anchor, oversized, jittered off the
            -- exact grid point like every other placement below
            local ejx, ejz = jitter(), jitter()
            table.insert(out, {
                x = anchor.x + ejx,
                z = anchor.z + ejz,
                y = anchor.y,
                species = elderSpecies,
                yaw = groveRoll(zone) * 2 * math.pi,
                scale = (1 + (groveRoll(zone) * 2 - 1) * recipe.scaleJitter)
                    * heightScale
                    * elderScale
                    * grove.dominantScale,
                zone = zone.name,
                layer = layer,
            })

            local placedCount = 1
            while placedCount < memberTarget do
                -- greedily take the unused candidate NEAREST the anchor
                -- (within radiusMax) that clears memberSpacing from every
                -- already-placed member of this grove
                local best: Sample? = nil
                local bestD = math.huge
                for _, c in candidates do
                    local dx, dz = c.x - anchor.x, c.z - anchor.z
                    local d = dx * dx + dz * dz
                    if d <= grove.radiusMax * grove.radiusMax and d < bestD then
                        local tooClose = false
                        for _, p in groveMembers do
                            local mdx, mdz = c.x - p.x, c.z - p.z
                            if mdx * mdx + mdz * mdz <= grove.memberSpacing * grove.memberSpacing then
                                tooClose = true
                                break
                            end
                        end
                        if not tooClose then
                            best, bestD = c, d
                        end
                    end
                end
                if best == nil then
                    -- no legal candidate left near this anchor: the grove
                    -- ends short of its target rather than fabricating ground
                    break
                end
                removeCandidate(best)
                table.insert(groveMembers, best)

                -- a member stands on ITS OWN candidate, so its wading gate checks
                -- `best`, never `anchor` — a member can be wetter than its elder
                local bestDepth = best.depth or 0
                local mSpecies, mScale
                if coherent then
                    mSpecies, mScale = pickWadingCoherentMember(
                        domSpecies,
                        domScale,
                        if domLimit ~= nil then domLimit else recipe.submergeMax,
                        attSpecies,
                        attScale,
                        if attLimit ~= nil then attLimit else recipe.submergeMax,
                        bestDepth,
                        function()
                            return groveRoll(zone)
                        end
                    )
                else
                    mSpecies, mScale = pickWadingSpecies(
                        recipe.pool,
                        bestDepth,
                        recipe.submergeMax,
                        function()
                            return groveRoll(zone)
                        end
                    )
                end
                if mSpecies == nil then
                    -- the ground is spent (already removed from candidates) but
                    -- nothing is placed on it, same as the per-sample skip
                    continue
                end
                -- sapling roll: always drawn, whether or not this recipe
                -- configures `saplings`, so the stream's shape never depends
                -- on an optional feature being toggled — only the
                -- INTERPRETATION of the draw does. Elders never roll this.
                local saplingRoll = groveRoll(zone)
                local saplings = grove.saplings
                if saplings ~= nil and saplingRoll < saplings.chance then
                    local young = saplings.map[mSpecies]
                    if young ~= nil then
                        mSpecies = young
                    end
                end
                local mjx, mjz = jitter(), jitter()
                table.insert(out, {
                    x = best.x + mjx,
                    z = best.z + mjz,
                    y = best.y,
                    species = mSpecies,
                    yaw = groveRoll(zone) * 2 * math.pi,
                    scale = (1 + (groveRoll(zone) * 2 - 1) * recipe.scaleJitter) * heightScale * mScale,
                    zone = zone.name,
                    layer = layer,
                })
                placedCount += 1
            end
        end

        while #zoneAnchors < grove.maxGroves and #candidates > 0 do
            -- TARGET: how many members (elder included) THIS grove wants.
            -- Rolled before the anchor is chosen, matching the brief's
            -- ordering — single-grove zones need it for anchor eligibility;
            -- multi-grove zones just carry it forward to the member pass.
            local memberTarget = grove.membersMin
                + math.floor(groveRoll(zone) * (grove.membersMax - grove.membersMin + 1))

            local anchor: Sample? = nil
            if grove.maxGroves == 1 then
                -- ANCHOR (single-grove): among candidates with enough support
                -- to reach the FULL target (support >= memberTarget - 1),
                -- take the one nearest the zone centroid — a user-placed
                -- stand should sit where it was drawn, not wherever a dart
                -- happened to land. No such candidate exists (legal ground is
                -- too sparse for a full grove anywhere) → fall back to
                -- whichever candidate has the most support.
                local bestEligible: Sample? = nil
                local bestEligibleD = math.huge
                local bestAny: Sample? = nil
                local bestAnySupport = -1
                for _, c in candidates do
                    local support = supportOf(c)
                    if support > bestAnySupport then
                        bestAny, bestAnySupport = c, support
                    end
                    if support >= memberTarget - 1 then
                        local dx, dz = c.x - cx, c.z - cz
                        local d = dx * dx + dz * dz
                        if d < bestEligibleD then
                            bestEligible, bestEligibleD = c, d
                        end
                    end
                end
                anchor = if bestEligible ~= nil then bestEligible else bestAny
            else
                -- ANCHOR (multi-grove): repeat greedily — among candidates
                -- that clear `grove.spacing` from every prior anchor, take
                -- the one with the most support. Stop (no anchor this round)
                -- once even the best candidate can't support a minimally
                -- viable grove (support < membersMin - 1); meadows are real
                -- gaps, not an accident of running out of darts.
                local best: Sample? = nil
                local bestSupport = -1
                for _, c in candidates do
                    local farEnough = true
                    for _, a in zoneAnchors do
                        local dx, dz = c.x - a[1], c.z - a[2]
                        if dx * dx + dz * dz <= grove.spacing * grove.spacing then
                            farEnough = false
                            break
                        end
                    end
                    if farEnough then
                        local support = supportOf(c)
                        if support > bestSupport then
                            best, bestSupport = c, support
                        end
                    end
                end
                if best == nil or bestSupport < grove.membersMin - 1 then
                    break
                end
                anchor = best
            end

            if anchor == nil then
                break
            end
            placeGrove(anchor, memberTarget)
        end

        for _, a in zoneAnchors do
            table.insert(groveAnchors, a)
        end
    end
    local groveIndex = indexWater(groveAnchors)

    -- shoreline pre-pass: mixed handfuls of plants at stations spaced along
    -- the shore, instead of a monospecific band scattered across the whole
    -- nearWater margin (2026-08-01 user gate — see ShorelineConfig above).
    -- Modelled closely on the grove pre-pass: its own LCG stream, exhaustive
    -- (not dart-thrown) candidate selection, and the same per-sample
    -- exclusion below. Runs after grove so grove placements already in
    -- `out` are respected by the members' spacing check, same as any other
    -- already-placed flora.
    for _, zone in zones do
        local recipe = recipes[zone.recipe]
        if recipe == nil or recipe.shoreline == nil then
            continue
        end
        local shoreline = recipe.shoreline :: ShorelineConfig
        local layer = recipe.layer or "canopy"
        local heightScale = recipe.heightScale or 1
        local shoreNearWater = recipe.nearWater or 0
        shoreStates[zone] = seedState(zone.seed + SHORE_SEED_OFFSET)

        -- SHORE SAMPLES: every grid sample that clears the recipe's ordinary
        -- site gates (accepts — maxSteep, footing, submergence, pathMargin,
        -- waterMargin, the recipe's own nearWater...) AND sits within the
        -- recipe's nearWater of open water. `ordered` is already sorted
        -- (x then z), so the station walk below is deterministic. KeepOut
        -- zones veto here too, same as a grove candidate — pads are sacred
        -- for a shoreline station exactly like they are for a grove anchor.
        local shoreSamples: { Sample } = {}
        for _, s in ordered do
            if
                contains(zone, s.x, s.z, s.y)
                and not keepOutAt(zones, s.x, s.z, s.y)
                and accepts(zone, s)
                and waterWithin(water, s.x, s.z, shoreNearWater)
            then
                table.insert(shoreSamples, s)
            end
        end

        -- STATIONS: exhaustive greedy selection (project standard — no
        -- darts). Walking the sorted shore samples and accepting one as a
        -- station whenever it clears `stationSpacing` from every
        -- already-accepted station walks the shoreline end to end, evenly
        -- spaced, deterministically.
        local stations: { Sample } = {}
        for _, s in shoreSamples do
            local farEnough = true
            for _, st in stations do
                local dx, dz = s.x - st.x, s.z - st.z
                if dx * dx + dz * dz < shoreline.stationSpacing * shoreline.stationSpacing then
                    farEnough = false
                    break
                end
            end
            if farEnough then
                table.insert(stations, s)
            end
        end

        for _, station in stations do
            -- WATER DIRECTION: probe the four cardinal offsets at `pitch`
            -- distance and sum the unit vectors toward whichever probes land
            -- in water (a probe "is water" when a water cell sits within
            -- half a pitch of it — the same grid-cell tolerance sampleKey
            -- uses elsewhere). None or all four water = no usable bias (a
            -- station mid-peninsula or mid-lake isn't meaningfully "toward"
            -- anything) — inland push is simply inert there, not a crash.
            local wx, wz, wetCount = 0, 0, 0
            for _, dir in SHORE_PROBE_DIRS do
                local px, pz = station.x + dir[1] * pitch, station.z + dir[2] * pitch
                if waterWithin(water, px, pz, pitch / 2) then
                    wx += dir[1]
                    wz += dir[2]
                    wetCount += 1
                end
            end
            local inlandX, inlandZ = 0, 0
            if wetCount > 0 and wetCount < 4 then
                local mag = math.sqrt(wx * wx + wz * wz)
                if mag > 0 then
                    inlandX, inlandZ = -wx / mag, -wz / mag
                end
            end

            local target = shoreline.membersMin
                + math.floor(shoreRoll(zone) * (shoreline.membersMax - shoreline.membersMin + 1))

            for _ = 1, target do
                -- up to 3 attempts; a station short on legal ground plants
                -- fewer members rather than fabricating a spot for one —
                -- the slot is simply abandoned when all 3 fail
                for _attempt = 1, 3 do
                    -- polar offset from the station, then an additional push
                    -- AWAY from water along the station's inland direction
                    local angle = shoreRoll(zone) * 2 * math.pi
                    local radius = shoreRoll(zone) * shoreline.spread
                    local push = shoreRoll(zone) * shoreline.inland
                    local mx = station.x + math.cos(angle) * radius + inlandX * push
                    local mz = station.z + math.sin(angle) * radius + inlandZ * push

                    local nearest = nearestSample(ordered, mx, mz)
                    if nearest == nil then
                        continue
                    end
                    local probe: Sample = {
                        x = mx,
                        z = mz,
                        y = nearest.y,
                        steep = nearest.steep,
                        depth = nearest.depth,
                        material = nearest.material,
                    }
                    if not accepts(zone, probe) then
                        continue
                    end
                    local tooClose = false
                    for _, p in out do
                        if p.layer == layer then
                            local dx, dz = mx - p.x, mz - p.z
                            if dx * dx + dz * dz < recipe.spacingMin * recipe.spacingMin then
                                tooClose = true
                                break
                            end
                        end
                    end
                    if tooClose then
                        continue
                    end

                    -- each member draws its OWN species independently — this
                    -- is what sorts a mixed handful wet-to-dry within one
                    -- station instead of every member inheriting one parent
                    -- species the way a clump child does
                    local species, speciesScale = pickWadingSpecies(
                        recipe.pool,
                        probe.depth or 0,
                        recipe.submergeMax,
                        function()
                            return shoreRoll(zone)
                        end,
                        function(bankRadius)
                            return waterWithin(water, mx, mz, bankRadius)
                        end
                    )
                    if species == nil then
                        continue
                    end

                    table.insert(out, {
                        x = mx,
                        z = mz,
                        y = nearest.y,
                        species = species,
                        yaw = shoreRoll(zone) * 2 * math.pi,
                        scale = (1 + (shoreRoll(zone) * 2 - 1) * recipe.scaleJitter)
                            * heightScale
                            * speciesScale,
                        zone = zone.name,
                        layer = layer,
                    })
                    break
                end
            end
        end
    end

    -- rockAffinity's lookup: the Studio side reads the ShoreRocks pass' output
    -- straight from the workspace rather than taking an injected point set
    local rockCells: { { number } } = {}
    local foliageFolder = workspace.CanyonWorld:FindFirstChild("Foliage")
    local shoreRocks = foliageFolder and foliageFolder:FindFirstChild("ShoreRocks")
    if shoreRocks then
        for _, r in shoreRocks:GetChildren() do
            if r:IsA("BasePart") then
                table.insert(rockCells, { r.Position.X, r.Position.Z })
            end
        end
    end
    local rockIndex = indexWater(rockCells)

    for _, s in ordered do
        local zone = resolveZone(zones, s.x, s.z, s.y, function(candidate)
            -- grove- and shoreline-recipe zones already planted in their own
            -- pre-passes; excluding them here (rather than filtering
            -- `zones`) lets their samples fall through to whatever zone is
            -- layered beneath, exactly like a recipe that simply rejects
            -- the sample
            local crecipe = recipes[candidate.recipe]
            if crecipe ~= nil and (crecipe.grove ~= nil or crecipe.shoreline ~= nil) then
                return false
            end
            return accepts(candidate, s)
        end)
        if zone == nil then
            continue
        end
        local recipe = recipes[zone.recipe]
        if recipe == nil then
            continue
        end

        -- density thinning before spacing so DensityScale thins uniformly;
        -- the care band scales it further where recipes opt in, and
        -- groveAffinity thickens (or clears) ground cover near grove anchors
        local density = zone.densityScale
        if o.careBand ~= nil and recipe.careDensity ~= nil then
            local mul = recipe.careDensity[o.careBand(s.x, s.z)]
            if mul ~= nil then
                density *= mul
            end
        end
        if recipe.groveAffinity ~= nil then
            local aff = recipe.groveAffinity :: GroveAffinity
            if waterWithin(groveIndex, s.x, s.z, aff.radius) then
                density *= aff.inside
            else
                density *= aff.outside
            end
        end
        -- rockAffinity COMPOUNDS with careDensity and groveAffinity — same
        -- multiplicative slot, not a separate gate
        if recipe.rockAffinity ~= nil then
            local aff = recipe.rockAffinity :: GroveAffinity
            if waterWithin(rockIndex, s.x, s.z, aff.radius) then
                density *= aff.inside
            else
                density *= aff.outside
            end
        end
        if roll(zone) >= density then
            continue
        end

        local layer = recipe.layer or "canopy"
        local minD = recipe.spacingMin + roll(zone) * (recipe.spacingMax - recipe.spacingMin)
        local tooClose = false
        for _, p in out do
            if p.layer == layer then
                local dx, dz = s.x - p.x, s.z - p.z
                if dx * dx + dz * dz <= minD * minD then
                    tooClose = true
                    break
                end
            end
        end
        if tooClose then
            continue
        end
        local heightScale = recipe.heightScale or 1
        local species, speciesScale = pickWadingSpecies(
            recipe.pool,
            s.depth or 0,
            recipe.submergeMax,
            function()
                return roll(zone)
            end,
            function(radius)
                return waterWithin(water, s.x, s.z, radius)
            end
        )
        if species == nil then
            -- every attempt drew a species that can't tolerate this depth: skip
            -- the sample entirely, never a fallback
            continue
        end
        table.insert(out, {
            x = s.x,
            z = s.z,
            y = s.y,
            species = species,
            yaw = roll(zone) * 2 * math.pi,
            scale = (1 + (roll(zone) * 2 - 1) * recipe.scaleJitter) * heightScale * speciesScale,
            zone = zone.name,
            layer = layer,
        })
        -- clump: extra same-species trees at 4-7 studs, spacing waived within
        -- the clump but zone membership and keep-outs still hold
        if roll(zone) < recipe.clumpChance and recipe.clumpSize >= 2 then
            for _ = 1, recipe.clumpSize - 1 do
                local ang = roll(zone) * 2 * math.pi
                local radius = CLUMP_RADIUS_MIN + roll(zone) * (CLUMP_RADIUS_MAX - CLUMP_RADIUS_MIN)
                local cx = s.x + math.cos(ang) * radius
                local cz = s.z + math.sin(ang) * radius
                -- clump children must pass the SAME site gates as any other
                -- placement, or they land on paths, in water margins and on
                -- steep ground that the parent's rules excluded
                local cs = nearestSample(ordered, cx, cz)
                local cy = if cs then cs.y else 0
                local probe: Sample = {
                    x = cx,
                    z = cz,
                    y = cy,
                    steep = if cs then cs.steep else 0,
                    depth = cs and cs.depth or nil,
                    material = cs and cs.material or nil,
                }
                local czone = resolveZone(zones, cx, cz, cy, function(candidate)
                    return accepts(candidate, probe)
                end)
                if czone == zone then
                    table.insert(out, {
                        x = cx,
                        z = cz,
                        y = cy,
                        species = species,
                        yaw = roll(zone) * 2 * math.pi,
                        scale = (1 + (roll(zone) * 2 - 1) * recipe.scaleJitter) * heightScale * speciesScale,
                        zone = zone.name,
                        layer = layer,
                    })
                end
            end
        end
    end

    local anchors: { MistAnchor } = {}
    for _, zone in zones do
        if zone.mist ~= true then
            continue
        end
        local state = seedState(zone.seed + MIST_SEED_OFFSET)
        local x1, z1, x2, z2 = zoneBBox(zone)
        for _ = 1, MIST_DARTS do
            local rx, rz
            state, rx = lcg(state)
            state, rz = lcg(state)
            local x = x1 + rx * (x2 - x1)
            local z = z1 + rz * (z2 - z1)
            if containsXZ(zone, x, z) then
                local tooClose = false
                for _, a in anchors do
                    local dx, dz = x - a.x, z - a.z
                    if dx * dx + dz * dz < MIST_SPACING * MIST_SPACING then
                        tooClose = true
                        break
                    end
                end
                if not tooClose then
                    table.insert(anchors, { x = x, z = z, y = nearestY(ordered, x, z), zone = zone.name })
                end
            end
        end
    end
    return out, anchors
end

-- ── keep-outs (MIRROR of tools/builders/CanyonKeepOuts.luau) ────────────────
-- Materials are NAMES (matching Sample.material, itself Enum.Material.Name),
-- same reason CanyonKeepOuts stores them that way: Studio maps the Enum, not
-- the pure module.
local KEEPOUT_MATERIALS = { "Sand" }
local KEEPOUT_ZONES = {
    -- RoshamboStage.Karesansui measures x -21..34 by z -12..18. The margin
    -- keeps a clump's SPREAD off the raked field, not merely its pivot.
    {
        name = "Karesansui",
        x0 = -25,
        x1 = 38,
        z0 = -16,
        z1 = 22,
        why = "the raked gravel field is the artwork",
    },
}

local function keepOutBlocks(x: number, z: number, materialName: string?): boolean
    if materialName ~= nil then
        for _, m in KEEPOUT_MATERIALS do
            if m == materialName then
                return true
            end
        end
    end
    for _, zn in KEEPOUT_ZONES do
        if x >= zn.x0 and x <= zn.x1 and z >= zn.z0 and z <= zn.z1 then
            return true
        end
    end
    return false
end

-- ── care model (MIRROR of tools/builders/CareModel.luau) ────────────────────
local CARE_GARDEN_FRACTION = 0.35

local function careReach(x: number): number
    return math.clamp(8 + 20 * (x + 430) / 470, 8, 28)
end

local function careModelBand(x: number, distToCare: number): string
    local r = careReach(x)
    if distToCare <= CARE_GARDEN_FRACTION * r then
        return "GARDEN"
    elseif distToCare <= r then
        return "TENDED"
    end
    return "PRESERVE"
end

-- ── Studio shell ───────────────────────────────────────────────────────────
local function nameSeed(name: string): number
    local acc = 7
    for i = 1, #name do
        acc = (acc * 31 + string.byte(name, i)) % 2147483647
    end
    return acc
end

-- Which zones this run may WIPE and STAMP. Never affects planning.
-- Destructive modes REQUIRE an explicit target: pass zones = { "Margin" } for one,
-- or zones = { "ALL" } to deliberately restamp everything. There is no implicit
-- "everything" — a bake meant for one zone must never be able to silently rewrite
-- the rest of the canyon, which is exactly how approved planting got destroyed.
local function wanted(name: string): boolean
    if #ZONES == 1 and ZONES[1] == "ALL" then
        return true
    end
    return table.find(ZONES, name) ~= nil
end

local function readZones(): { Zone }
    -- home is ServerStorage (moved 2026-07-31: zone parts in Workspace hover-
    -- highlighted in Edit — visual clutter); Sandbox fallback for older places
    local folder: Instance? = game:GetService("ServerStorage"):FindFirstChild("FoliageZones")
    if not folder then
        local sandbox = workspace:FindFirstChild("Sandbox")
        folder = sandbox and sandbox:FindFirstChild("FoliageZones")
    end
    local zones: { Zone } = {}
    if not folder then
        warn("[preserve] no ServerStorage.FoliageZones — nothing to do")
        return zones
    end
    for _, part in folder:GetChildren() do
        if part:IsA("BasePart") then
            local recipe = part:GetAttribute("Recipe")
            if typeof(recipe) ~= "string" then
                warn(`[preserve] {part.Name}: missing Recipe attribute — skipped`)
                continue
            end
            -- EVERY zone is always loaded, even when only one is being stamped.
            -- Planning is a WHOLE-WORLD computation: the sample grid spans the union
            -- of zone bounds, and spacing is checked across zones sharing a layer. Drop
            -- a zone here and the surviving zones plan against a different world, so a
            -- filtered bake produced DIFFERENT trees than a full one — the reason
            -- zone-filtered bakes were never isolation-safe. `wanted` now gates only
            -- what is WIPED and STAMPED (see the shell), never what is planned.
            local pos, size = part.Position, part.Size
            local shape = "rect"
            local bounds: { number }
            if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
                shape = "circle"
                -- cylinders are laid on their side in Roblox: radius from Y/Z extent
                bounds = { pos.X, pos.Z, math.max(size.Y, size.Z) / 2 }
            elseif part:IsA("Part") and part.Shape == Enum.PartType.Ball then
                shape = "circle"
                bounds = { pos.X, pos.Z, size.X / 2 }
            else
                bounds = {
                    pos.X - size.X / 2,
                    pos.Z - size.Z / 2,
                    pos.X + size.X / 2,
                    pos.Z + size.Z / 2,
                }
            end
            local density = part:GetAttribute("DensityScale")
            local seed = part:GetAttribute("Seed")
            local yMin, yMax = nil, nil
            if part:GetAttribute("Vertical") == true then
                yMin = pos.Y - size.Y / 2
                yMax = pos.Y + size.Y / 2
            end
            table.insert(zones, {
                name = part.Name,
                shape = shape,
                bounds = bounds,
                recipe = recipe,
                densityScale = typeof(density) == "number" and density or 1,
                seed = typeof(seed) == "number" and seed or nameSeed(part.Name),
                mist = part:GetAttribute("Mist") == true,
                still = part:GetAttribute("Still") == true,
                yMin = yMin,
                yMax = yMax,
            })
        end
    end
    -- Overlapping-zone priority is LAST-first in the planner, and GetChildren
    -- order reshuffles across Studio sessions (it silently flipped Margin vs
    -- CoreUnder bank claims between two identical bakes). Sort by name so
    -- priority is stable and intentional: alphabetically-last wins, which puts
    -- Margin above the Core/Fringe body — the spec's "margin takes the bank
    -- samples, the forest keeps the rest".
    table.sort(zones, function(a, b)
        return a.name < b.name
    end)
    return zones
end

-- Two raycasts per sample: an IgnoreWater ground pass (the real terrain, even
-- under water) and a water-surface pass, so a shallow-water cell becomes a
-- Sample with `depth` set instead of being skipped outright — WaterMargin
-- recipes need those cells to plant reeds that wade.
local function sampleTerrain(zones: { Zone }): { Sample }
    local rpGround = RaycastParams.new()
    rpGround.FilterType = Enum.RaycastFilterType.Include
    rpGround.FilterDescendantsInstances = { workspace.Terrain }
    rpGround.IgnoreWater = true
    local rpWater = RaycastParams.new()
    rpWater.FilterType = Enum.RaycastFilterType.Include
    rpWater.FilterDescendantsInstances = { workspace.Terrain }
    rpWater.IgnoreWater = false
    local x1, z1, x2, z2 = math.huge, math.huge, -math.huge, -math.huge
    for _, zone in zones do
        local a, b, c, d = zoneBBox(zone)
        x1, z1 = math.min(x1, a), math.min(z1, b)
        x2, z2 = math.max(x2, c), math.max(z2, d)
    end
    -- SNAP THE GRID TO A FIXED WORLD LATTICE (2026-08-01). Without this the grid
    -- starts at the min of the zone bounds, so editing ANY zone's extent moves the
    -- origin by a non-multiple of the pitch and shifts EVERY sample point in the
    -- canyon — which silently re-rolls every zone, including ones the user already
    -- approved and never touched. Extending the fringe west by 35 studs moved all
    -- samples 3 studs and rearranged the whole world. Snapped, a zone edit only
    -- ADDS or REMOVES samples at its own edges; existing sample positions never
    -- move, per-zone LCG streams stay aligned, and approved planting survives.
    x1 = math.floor(x1 / SAMPLE_PITCH) * SAMPLE_PITCH
    z1 = math.floor(z1 / SAMPLE_PITCH) * SAMPLE_PITCH
    local samples: { Sample } = {}
    if x1 > x2 then
        return samples
    end
    for x = x1, x2, SAMPLE_PITCH do
        for z = z1, z2, SAMPLE_PITCH do
            local origin = Vector3.new(x, PROBE_TOP, z)
            local ground = workspace:Raycast(origin, Vector3.new(0, -900, 0), rpGround)
            if ground then
                local surface = workspace:Raycast(origin, Vector3.new(0, -900, 0), rpWater)
                local depth = 0
                if surface and surface.Material == Enum.Material.Water then
                    depth = surface.Position.Y - ground.Position.Y
                end
                table.insert(samples, {
                    x = x,
                    z = z,
                    y = ground.Position.Y,
                    steep = 1 - math.clamp(ground.Normal.Y, 0, 1),
                    depth = depth,
                    material = ground.Material.Name,
                })
            end
        end
    end
    return samples
end

local function readWaterCells(): { { number } }
    local cells: { { number } } = {}
    local sandbox = workspace:FindFirstChild("Sandbox")
    local map = sandbox and sandbox:FindFirstChild("WaterMap")
    local markers = map and map:FindFirstChild("WaterMarkers")
    if not markers then
        warn("[preserve] no Sandbox.WaterMap.WaterMarkers — water rules inert")
        return cells
    end
    for _, m in markers:GetChildren() do
        if m:IsA("BasePart") then
            table.insert(cells, { m.Position.X, m.Position.Z })
        end
    end
    return cells
end

-- Point-sample the REAL built geometry (paths, stairs, decks, structures) so
-- planting stands off what is actually there. Bounding boxes are useless here:
-- a path that curves across a hillside has a bbox covering the whole hillside.
local function readBuiltCells(): { { number } }
    local cells: { { number } } = {}
    local roots = {}
    local cw = workspace:FindFirstChild("CanyonWorld")
    if cw then
        for _, n in { "Paths", "Structures" } do
            local f = cw:FindFirstChild(n)
            if f then
                table.insert(roots, f)
            end
        end
    end
    for _, root in roots do
        for _, d in root:GetDescendants() do
            if d:IsA("BasePart") then
                local cf, size = d.CFrame, d.Size
                -- a few points along the part's long axis, so long thin treads
                -- are represented by more than their centre
                local steps = math.clamp(math.floor(math.max(size.X, size.Z) / 6), 1, 8)
                for i = 0, steps do
                    local t = if steps == 0 then 0.5 else i / steps
                    local off = (t - 0.5) * (if size.X >= size.Z then size.X else size.Z)
                    local dir = if size.X >= size.Z then cf.RightVector else cf.LookVector
                    local pt = cf.Position + dir * off
                    table.insert(cells, { pt.X, pt.Z })
                end
            end
        end
    end
    return cells
end

-- Staged-site HARD override: the canyon-garden-floor spec (§2, "Staged sites
-- override longitude" — docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md:51-53)
-- grants FallsDock its own 15-stud garden radius "irrespective of" reach(x),
-- measured from its FOOTPRINT (not its pivot). This is NOT folded into the
-- generic care-cell index: at the dock's longitude (x≈-345) reach(x)≈11.6, so
-- routing it through the ordinary careModelBand formula would read the dock's
-- own interior as PRESERVE (15 studs from a ring exceeds reach) — the inverse
-- of the spec's intent. careBand checks this override FIRST and only falls
-- through to the generic formula when it doesn't apply.
local FALLS_DOCK_GARDEN_RADIUS = 15

-- FallsDock's footprint as an axis-aligned XZ box (x0, z0, x1, z1), or nil if
-- the model isn't in the place yet.
local function fallsDockFootprint(): { number }?
    local stage = workspace:FindFirstChild("RoshamboStage")
    local dock = stage and stage:FindFirstChild("FallsDock")
    if not dock or not dock:IsA("Model") then
        warn("[preserve] no RoshamboStage.FallsDock — care override inert")
        return nil
    end
    local cf, size = (dock :: Model):GetBoundingBox()
    local hx, hz = size.X / 2, size.Z / 2
    return { cf.Position.X - hx, cf.Position.Z - hz, cf.Position.X + hx, cf.Position.Z + hz }
end

-- Distance (studs) from (x,z) to the nearest point on an axis-aligned XZ box
-- footprint; 0 if (x,z) sits inside the box.
local function distToFootprint(box: { number }, x: number, z: number): number
    local dx = math.max(box[1] - x, 0, x - box[3])
    local dz = math.max(box[2] - z, 0, z - box[4])
    return math.sqrt(dx * dx + dz * dz)
end

-- Nearest distance (studs) from (x,z) to any care cell, by expanding ring over
-- the same WATER_BUCKET grid as waterWithin. Unlike waterWithin (a threshold
-- test), the care model needs the actual distance, so this walks buckets
-- outward ring by ring until it finds one, then checks one extra ring so a
-- closer point hiding in a diagonal-adjacent bucket can't be missed.
local function nearestCareDist(index: WaterIndex, x: number, z: number): number
    for ring = 0, 8 do -- 8 buckets * 16 studs = beyond any reach
        local best = math.huge
        local bx, bz = math.floor(x / WATER_BUCKET), math.floor(z / WATER_BUCKET)
        for gx = bx - ring, bx + ring do
            for gz = bz - ring, bz + ring do
                if math.max(math.abs(gx - bx), math.abs(gz - bz)) == ring then
                    local bucket = index[`{gx},{gz}`]
                    if bucket then
                        for _, c in bucket do
                            local dx, dz = x - c[1], z - c[2]
                            best = math.min(best, dx * dx + dz * dz)
                        end
                    end
                end
            end
        end
        if best < math.huge and ring >= 1 then -- one extra ring so a closer diagonal can't hide
            return math.sqrt(best)
        end
    end
    return math.huge
end

local function preserveFolder(): Folder
    local foliage = workspace.CanyonWorld:FindFirstChild("Foliage")
    if not foliage then
        foliage = Instance.new("Folder")
        foliage.Name = "Foliage"
        foliage.Parent = workspace.CanyonWorld
    end
    local preserve = foliage:FindFirstChild("Preserve")
    if not preserve then
        preserve = Instance.new("Folder")
        preserve.Name = "Preserve"
        preserve.Parent = foliage
    end
    return preserve :: Folder
end

-- HAND-TUNED RESCUE (2026-08-01): a bake owns its zone folders and rebuilds them
-- wholesale, so any hand-adjusted plant inside one is destroyed on the next run. Setting
-- the boolean attribute `HandTuned` on a placement exempts it: the wipe parks it, the
-- fresh bake spaces around it (see handTunedPlacements below), and it is restored
-- afterwards. Set the attribute on the MODEL, not its parts.
local HAND_TUNED = "HandTuned"
local rescued: { Instance } = {}

local function wipeZone(name: string)
    local existing = preserveFolder():FindFirstChild(name)
    if existing then
        for _, child in existing:GetChildren() do
            if child:GetAttribute(HAND_TUNED) == true then
                child.Parent = nil -- held off-tree; re-parented after the bake
                table.insert(rescued, child)
            end
        end
        existing:Destroy()
    end
end

-- the XZ positions of everything rescued, so fresh placements space around them instead
-- of growing through the arrangement the user just hand-made
local function handTunedPlacements(): { { x: number, z: number } }
    local out = {}
    for _, inst in rescued do
        if inst:IsA("PVInstance") then
            local p = (inst :: PVInstance):GetPivot().Position
            table.insert(out, { x = p.X, z = p.Z })
        end
    end
    return out
end

-- Engine flags per the scatter standard. Mid/hero TRUNK parts keep CanCollide so
-- players cannot walk through the forest; foliage and blob fill never collide.
local function flagClone(model: Model, collidableTrunk: boolean)
    -- stamped FALSE (not merely left unset) so the checkbox is visible in the
    -- Properties panel: an attribute that does not exist yet cannot be discovered
    -- or ticked without typing its name by hand. Set on the MODEL — the rescue
    -- reads it there, not on the parts.
    model:SetAttribute(HAND_TUNED, false)
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CastShadow = false
            d.CanQuery = false
            d.CanTouch = false
            local isTrunk = d.Name:lower():find("trunk") ~= nil
            d.CanCollide = collidableTrunk and isTrunk
            if d:IsA("MeshPart") then
                d.RenderFidelity = Enum.RenderFidelity.Automatic
            end
        end
    end
end

-- fresh placements must not grow through a hand-tuned arrangement; 5 studs is the
-- tightest spacing any recipe uses, so it never blocks more than one slot per plant
local HAND_TUNED_CLEARANCE = 5

local function bake(placements: { Placement }, mode: string)
    local reserved = handTunedPlacements()
    local kit = ServerStorage:FindFirstChild("FoliageKit")
    if not kit then
        warn("[preserve] no ServerStorage.FoliageKit")
        return
    end
    local preserve = preserveFolder()
    local folders: { [string]: Folder } = {}
    local missing: { [string]: number } = {}
    local placed = 0
    -- SLOPE-ADAPTIVE BED-IN (2026-07-31 gate feedback): a tree seated only by
    -- its calibrated PlantDepth still shows a naked, downhill root ball on a
    -- slope — the depth is right for flat ground but the uphill side of the
    -- root flare pokes out. Same raycast style as sampleTerrain
    -- (Include=Terrain, IgnoreWater=true). NOTE this makes bake() non-pure in
    -- the sense that it raycasts live terrain, but terrain doesn't change
    -- between bakes so a re-bake still reproduces the same result.
    local rpBed = RaycastParams.new()
    rpBed.FilterType = Enum.RaycastFilterType.Include
    rpBed.FilterDescendantsInstances = { workspace.Terrain }
    rpBed.IgnoreWater = true
    local yielded = 0
    for _, p in placements do
        local template = kit:FindFirstChild(p.species)
        if not template or not template:IsA("Model") then
            missing[p.species] = (missing[p.species] or 0) + 1
            continue
        end
        local blocked = false
        for _, r in reserved do
            local dx, dz = p.x - r.x, p.z - r.z
            if dx * dx + dz * dz < HAND_TUNED_CLEARANCE * HAND_TUNED_CLEARANCE then
                blocked = true
                break
            end
        end
        if blocked then
            yielded += 1
            continue
        end
        local folder = folders[p.zone]
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = p.zone
            folder.Parent = preserve
            folders[p.zone] = folder
        end
        local clone = template:Clone()
        clone.Name = p.species
        -- scale first (it moves geometry), then yaw about the pivot, then drop the
        -- bounding-box bottom onto the sampled ground with a 0.3 bed-in.
        if p.scale ~= 1 then
            clone:ScaleTo(clone:GetScale() * p.scale)
        end
        local pivot = clone:GetPivot()
        clone:PivotTo(CFrame.new(p.x, pivot.Position.Y, p.z) * CFrame.Angles(0, p.yaw, 0))
        -- PLANTING DEPTH: XfrogPlants model a root flare at the base, so seating
        -- the bounding box on the ground leaves roots splayed across the surface.
        -- Each template carries a PlantDepth attribute (studs at template scale,
        -- set by hand on the Sandbox.PlantDepthRig — cherries need ~15-20% of
        -- height, conifers ~8%, and a sapling with no flare needs none), scaled
        -- here by the clone's own scale.
        local depth = template:GetAttribute("PlantDepth")
        if typeof(depth) ~= "number" then
            depth = 0.3
        end
        depth *= clone:GetScale()
        -- slope-adaptive sink so downhill roots bury (2026-07-31 gate): probe
        -- 4 compass points 1.5 studs out and add half their vertical spread
        -- (capped at 2.5) as extra depth. Flat ground: extra ~= 0, calibrated
        -- depths untouched.
        local minY, maxY = math.huge, -math.huge
        for i = 0, 3 do
            local ang = i * math.pi / 2
            local origin = Vector3.new(p.x + math.cos(ang) * 1.5, p.y + 50, p.z + math.sin(ang) * 1.5)
            local hit = workspace:Raycast(origin, Vector3.new(0, -200, 0), rpBed)
            if hit then
                minY = math.min(minY, hit.Position.Y)
                maxY = math.max(maxY, hit.Position.Y)
            end
        end
        if maxY > -math.huge and minY < math.huge then
            depth += math.clamp((maxY - minY) / 2, 0, 2.5)
        end
        local box, size = clone:GetBoundingBox()
        clone:PivotTo(clone:GetPivot() + Vector3.new(0, p.y - depth - (box.Position.Y - size.Y / 2), 0))
        flagClone(clone, p.species:find("SugiMid") ~= nil)
        clone.Parent = folder
        placed += 1
    end
    for species, n in missing do
        warn(`[preserve] missing FoliageKit template "{species}" — skipped {n} placements`)
    end
    -- restore the hand-tuned plants the wipe parked (their zone folder may have been
    -- recreated above; if a zone produced no placements at all, recreate it for them)
    local restored = 0
    for _, inst in rescued do
        local zoneName = inst:GetAttribute("Zone")
        local target = if typeof(zoneName) == "string" then folders[zoneName] else nil
        if target == nil then
            target =
                preserve:FindFirstChild(typeof(zoneName) == "string" and zoneName or "HandTuned") :: Folder?
            if target == nil then
                local f = Instance.new("Folder")
                f.Name = if typeof(zoneName) == "string" then zoneName else "HandTuned"
                f.Parent = preserve
                target = f
            end
        end
        inst.Parent = target
        restored += 1
    end
    table.clear(rescued)
    local note = ""
    if restored > 0 then
        note = `, restored {restored} hand-tuned (yielded {yielded} placements to them)`
    end
    print(`[preserve] {mode}: stamped {placed} plants` .. note)
end

local function bakeMist(anchors: { MistAnchor })
    local preserve = preserveFolder()
    local old = preserve:FindFirstChild("Mist")
    if old then
        old:Destroy()
    end
    if #anchors == 0 then
        print("[preserve] mist: no mist-flagged zones")
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "Mist"
    folder.Parent = preserve
    for i, a in anchors do
        local part = Instance.new("Part")
        part.Name = `MistAnchor{i}`
        part.Size = Vector3.new(1, 1, 1)
        part.Position = Vector3.new(a.x, a.y + 1, a.z)
        part.Anchored = true
        part.Transparency = 1
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Parent = folder
    end
    print(`[preserve] mist: stamped {#anchors} anchors`)
end

-- Paste this file ONCE into Studio as ServerStorage.PreserveScatterTool
-- (ModuleScript), then drive it with small calls, e.g.
--   local run = require(game.ServerStorage.PreserveScatterTool)
--   return run({ mode = "bake", zones = { "Core" },
--                recipes = { PreserveCore = { spacingMin = 9, spacingMax = 14 } } })
-- `recipes` shallow-merges per key, so gate tuning is a two-line call; fold the
-- settled values back into RECIPES here AND into foliageZoneRecipes.luau.
-- ── terrain grass painting (mode="grass") ───────────────────────────────────
-- The 0-2 stud band has no asset: nothing in FoliageKit is shorter than a 2.4-stud
-- ReedClump, and the muhly card experiment failed its gate. Roblox's OWN terrain
-- grass renders that band for free, at zero instance cost, and the reeds then stand
-- IN it rather than on bare rock — which is what the user identified as the missing
-- ingredient in the shoreline that already read well (2026-08-01).
--
-- DESTRUCTIVE: this rewrites terrain voxels. Every tile is snapshotted to
-- ServerStorage.TerrainBackup_Grass BEFORE it is written, so the whole pass can be
-- reverted by re-pasting those regions. Delete that folder once satisfied.
local GRASS_TILE = 64 -- studs per read/write tile; keeps each region well inside limits
local VOXEL = 4

-- Painting is additive: a later pass with tighter rules cannot REMOVE grass an earlier
-- pass laid down. This sweeps every keep-out rect and puts Grass back to Sand, which is
-- what the karesansui is made of — run before each paint so the rules are enforced
-- retroactively rather than only on new work.
local function repairKeepOutGrass(): number
    local terrain = workspace.Terrain
    local restored = 0
    for _, zn in KEEPOUT_ZONES do
        local region = Region3.new(
            Vector3.new(zn.x0 - VOXEL, -20, zn.z0 - VOXEL),
            Vector3.new(zn.x1 + VOXEL, 320, zn.z1 + VOXEL)
        ):ExpandToGrid(VOXEL)
        local mats, occ = terrain:ReadVoxels(region, VOXEL)
        local touched = false
        local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
        for ix = 1, sx do
            for iy = 1, sy do
                for iz = 1, sz do
                    if mats[ix][iy][iz] == Enum.Material.Grass and occ[ix][iy][iz] > 0 then
                        mats[ix][iy][iz] = Enum.Material.Sand
                        restored += 1
                        touched = true
                    end
                end
            end
        end
        if touched then
            terrain:WriteVoxels(region, VOXEL, mats, occ)
        end
    end
    return restored
end

local function paintGrass(zones: { Zone }, recipes: { [string]: Recipe }): string
    local terrain = workspace.Terrain
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { terrain }
    rp.IgnoreWater = true

    -- readWaterCells drops Y (the planner never needs it); the paint band is defined
    -- RELATIVE to the local waterline, so read the markers again here with elevation
    local wet: { { x: number, y: number, z: number } } = {}
    local sandbox = workspace:FindFirstChild("Sandbox")
    local map = sandbox and sandbox:FindFirstChild("WaterMap")
    local markers = map and map:FindFirstChild("WaterMarkers")
    if not markers then
        return "[grass] no Sandbox.WaterMap.WaterMarkers — nothing to paint"
    end
    for _, m in markers:GetChildren() do
        if m:IsA("BasePart") then
            table.insert(wet, { x = m.Position.X, y = m.Position.Y, z = m.Position.Z })
        end
    end

    -- columns to consider: every 4-stud column within `nearWater` of a water cell
    -- that belongs to a zone whose recipe paints. Keyed so overlapping zones and
    -- neighbouring cells don't queue the same column twice.
    type Target = { x: number, z: number, surfaceY: number }
    local seen: { [string]: boolean } = {}
    local targets: { Target } = {}

    for _, zone in zones do
        local recipe = recipes[zone.recipe]
        local paint = recipe and recipe.grassPaint
        if paint == nil then
            continue
        end
        local reach = recipe.nearWater or 8
        for _, c in wet do
            local wx, wz, waterY = c.x, c.z, c.y
            if not containsXZ(zone, wx, wz) then
                continue
            end
            for dx = -reach, reach, VOXEL do
                for dz = -reach, reach, VOXEL do
                    if dx * dx + dz * dz > reach * reach then
                        continue
                    end
                    local x = math.floor((wx + dx) / VOXEL + 0.5) * VOXEL
                    local z = math.floor((wz + dz) / VOXEL + 0.5) * VOXEL
                    local key = `{x},{z}`
                    if seen[key] then
                        continue
                    end
                    seen[key] = true
                    local hit = workspace:Raycast(Vector3.new(x, PROBE_TOP, z), Vector3.new(0, -900, 0), rp)
                    if hit == nil then
                        continue
                    end
                    -- KEEP-OUTS BIND THE PAINT TOO (2026-08-01): the first pass
                    -- consulted them for plants but not for terrain, and grass crept
                    -- onto the karesansui. The raked sand is sacrosanct.
                    if keepOutBlocks(x, z, hit.Material.Name) then
                        continue
                    end
                    -- inside the vertical band (below = INTO the shallows), on
                    -- ground gentle enough to hold soil
                    local dy = hit.Position.Y - waterY
                    if dy < -paint.below or dy > paint.above then
                        continue
                    end
                    if 1 - hit.Normal.Y > paint.maxSlope then
                        continue
                    end
                    table.insert(targets, { x = x, z = z, surfaceY = hit.Position.Y })
                end
            end
        end
    end

    if #targets == 0 then
        return "[grass] no columns matched — nothing painted"
    end

    -- group into tiles so this is a handful of voxel reads, not one per column
    local tiles: { [string]: { Target } } = {}
    for _, t in targets do
        local key = `{math.floor(t.x / GRASS_TILE)},{math.floor(t.z / GRASS_TILE)}`
        local bucket = tiles[key]
        if bucket == nil then
            bucket = {}
            tiles[key] = bucket
        end
        table.insert(bucket, t)
    end

    local backup = ServerStorage:FindFirstChild("TerrainBackup_Grass")
    if backup then
        backup:Destroy()
    end
    backup = Instance.new("Folder")
    backup.Name = "TerrainBackup_Grass"
    backup.Parent = ServerStorage

    local painted, tileCount = 0, 0
    for _, bucket in tiles do
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        local lookup: { [string]: number } = {}
        for _, t in bucket do
            minX, maxX = math.min(minX, t.x), math.max(maxX, t.x)
            minZ, maxZ = math.min(minZ, t.z), math.max(maxZ, t.z)
            minY, maxY = math.min(minY, t.surfaceY), math.max(maxY, t.surfaceY)
            lookup[`{t.x},{t.z}`] = t.surfaceY
        end
        local region = Region3.new(
            Vector3.new(minX - VOXEL, minY - VOXEL * 2, minZ - VOXEL),
            Vector3.new(maxX + VOXEL, maxY + VOXEL * 2, maxZ + VOXEL)
        ):ExpandToGrid(VOXEL)

        -- CopyRegion takes Region3int16 in VOXEL coordinates (studs/4), not a Region3
        -- in studs — the cast error is silent about which unit it wanted
        local rmin = region.CFrame.Position - region.Size / 2
        local rmax = region.CFrame.Position + region.Size / 2
        local snapshot = terrain:CopyRegion(
            Region3int16.new(
                Vector3int16.new(rmin.X / VOXEL, rmin.Y / VOXEL, rmin.Z / VOXEL),
                Vector3int16.new(rmax.X / VOXEL, rmax.Y / VOXEL, rmax.Z / VOXEL)
            )
        )
        snapshot.Name = `tile_{tileCount}`
        -- a TerrainRegion does NOT remember where it came from, and PasteRegion needs
        -- the corner in voxel coords — without these the snapshot is unrestorable
        snapshot:SetAttribute("CornerX", rmin.X / VOXEL)
        snapshot:SetAttribute("CornerY", rmin.Y / VOXEL)
        snapshot:SetAttribute("CornerZ", rmin.Z / VOXEL)
        snapshot.Parent = backup

        local mats, occ = terrain:ReadVoxels(region, VOXEL)
        local origin = region.CFrame.Position - region.Size / 2
        local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
        for ix = 1, sx do
            for iz = 1, sz do
                local wx = origin.X + (ix - 0.5) * VOXEL
                local wz = origin.Z + (iz - 0.5) * VOXEL
                local surfaceY =
                    lookup[`{math.floor(wx / VOXEL + 0.5) * VOXEL},{math.floor(wz / VOXEL + 0.5) * VOXEL}`]
                if surfaceY == nil then
                    continue
                end
                for iy = 1, sy do
                    local wy = origin.Y + (iy - 0.5) * VOXEL
                    -- only the SURFACE skin: the voxel holding the ground point and
                    -- the one just under it. Deeper voxels keep their rock so a cut
                    -- bank still reads as stone under a grass lip.
                    if occ[ix][iy][iz] > 0.5 and mats[ix][iy][iz] ~= Enum.Material.Water then
                        if wy <= surfaceY + VOXEL and wy >= surfaceY - VOXEL then
                            mats[ix][iy][iz] = Enum.Material.Grass
                            painted += 1
                        end
                    end
                end
            end
        end
        terrain:WriteVoxels(region, VOXEL, mats, occ)
        tileCount += 1
    end

    local repaired = repairKeepOutGrass()
    return `[grass] painted {painted} voxels across {tileCount} tiles ({#targets} columns); `
        .. `restored {repaired} keep-out voxels to sand; snapshot in ServerStorage.TerrainBackup_Grass`
end

return function(opts: {
    mode: string?,
    zones: { string }?,
    recipes: { [string]: { [string]: any } }?,
}): string
    local mode = opts.mode or MODE
    ZONES = opts.zones or ZONES
    if (mode == "bake" or mode == "wipe") and #ZONES == 0 then
        return "[preserve] REFUSED: "
            .. mode
            .. " needs an explicit zones list, e.g. "
            .. 'zones = { "Margin" } for one zone or zones = { "ALL" } for the whole canyon. '
            .. "Planning is always whole-world; this only limits what gets rewritten."
    end

    local recipes: { [string]: Recipe } = {}
    for key, recipe in RECIPES do
        local merged: { [string]: any } = table.clone(recipe :: any)
        local override = opts.recipes and opts.recipes[key]
        if override then
            for field, value in override do
                merged[field] = value
            end
        end
        recipes[key] = merged :: any
    end

    local zones = readZones()
    if #zones == 0 then
        return "[preserve] no zones"
    end
    local samples = sampleTerrain(zones)
    local cells = readWaterCells()
    local builtCells = readBuiltCells()

    -- care distance: built geometry (paths/structures), indexed the same way
    -- as the water/built lookups; FallsDock is a HARD override checked first
    -- (see fallsDockFootprint's comment), never folded into this index
    local careIndex = indexWater(builtCells)
    local dockFootprint = fallsDockFootprint()
    local function careBand(x: number, z: number): string
        if dockFootprint ~= nil and distToFootprint(dockFootprint, x, z) <= FALLS_DOCK_GARDEN_RADIUS then
            return "GARDEN"
        end
        return careModelBand(x, nearestCareDist(careIndex, x, z))
    end

    local placements, anchors = plan(zones, samples, recipes, indexWater(cells), indexWater(builtCells), {
        pitch = SAMPLE_PITCH,
        keepOut = keepOutBlocks,
        careBand = careBand,
    })

    local perZone: { [string]: number } = {}
    for _, p in placements do
        perZone[p.zone] = (perZone[p.zone] or 0) + 1
    end
    local lines = {}
    for name, n in perZone do
        table.insert(lines, `{name}={n}`)
    end
    table.sort(lines)
    local summary =
        `[preserve] {mode}: zones={#zones} samples={#samples} water={#cells} built={#builtCells} placements={#placements} mist={#anchors} | {table.concat(
            lines,
            "  "
        )}`
    print(summary)

    if mode == "wipe" or mode == "bake" then
        for _, zone in zones do
            if zone.recipe ~= "KeepOut" and wanted(zone.name) then
                wipeZone(zone.name)
            end
        end
    end
    if mode == "bake" then
        local filtered: { Placement } = {}
        for _, p in placements do
            if wanted(p.zone) then
                table.insert(filtered, p)
            end
        end
        bake(filtered, "bake")
    elseif mode == "mist" then
        bakeMist(anchors)
    elseif mode == "grass" then
        return summary .. "\n" .. paintGrass(zones, recipes)
    end
    return summary
end
