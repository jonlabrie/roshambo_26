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
type Species = { name: string, weight: number, scale: number? }
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

local function pickSpecies(pool: { Species }, r: number): (string, number)
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = r * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name, s.scale or 1
        end
    end
    local last = pool[#pool]
    return last.name, last.scale or 1
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
            table.insert(zoneAnchors, { anchor.x, anchor.z })

            local domSpecies, domScale, attSpecies, attScale
            local elderSpecies, elderScale
            if coherent then
                domSpecies, domScale = pickSpecies(recipe.pool, groveRoll(zone))
                local attPool: { Species } = {}
                for _, sp in recipe.pool do
                    if sp.name ~= domSpecies then
                        table.insert(attPool, sp)
                    end
                end
                if #attPool == 0 then
                    attPool = recipe.pool
                end
                attSpecies, attScale = pickSpecies(attPool, groveRoll(zone))
                elderSpecies, elderScale = domSpecies, domScale
            else
                elderSpecies, elderScale = pickSpecies(recipe.pool, groveRoll(zone))
            end

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

                local mSpecies, mScale
                if coherent then
                    if groveRoll(zone) < GROVE_ATTENDANT_THRESHOLD then
                        mSpecies, mScale = domSpecies, domScale
                    else
                        mSpecies, mScale = attSpecies, attScale
                    end
                else
                    mSpecies, mScale = pickSpecies(recipe.pool, groveRoll(zone))
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

    for _, s in ordered do
        local zone = resolveZone(zones, s.x, s.z, s.y, function(candidate)
            -- grove-recipe zones already planted in the pre-pass; excluding
            -- them here (rather than filtering `zones`) lets their samples
            -- fall through to whatever zone is layered beneath, exactly like
            -- a recipe that simply rejects the sample
            local crecipe = recipes[candidate.recipe]
            if crecipe ~= nil and crecipe.grove ~= nil then
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
        local species, speciesScale = pickSpecies(recipe.pool, roll(zone))
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

local function wanted(name: string): boolean
    if #ZONES == 0 then
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
            -- KeepOut zones always participate (they mask every bake)
            if recipe ~= "KeepOut" and not wanted(part.Name) then
                continue
            end
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

local function wipeZone(name: string)
    local existing = preserveFolder():FindFirstChild(name)
    if existing then
        existing:Destroy()
    end
end

-- Engine flags per the scatter standard. Mid/hero TRUNK parts keep CanCollide so
-- players cannot walk through the forest; foliage and blob fill never collide.
local function flagClone(model: Model, collidableTrunk: boolean)
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

local function bake(placements: { Placement }, mode: string)
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
    for _, p in placements do
        local template = kit:FindFirstChild(p.species)
        if not template or not template:IsA("Model") then
            missing[p.species] = (missing[p.species] or 0) + 1
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
    print(`[preserve] {mode}: stamped {placed} plants`)
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
return function(opts: {
    mode: string?,
    zones: { string }?,
    recipes: { [string]: { [string]: any } }?,
}): string
    local mode = opts.mode or MODE
    ZONES = opts.zones or ZONES

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
    end
    return summary
end
