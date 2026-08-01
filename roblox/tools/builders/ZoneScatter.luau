--!strict
-- Deterministic zone-painted scatter for the forest preserve (spec
-- 2026-07-27-forest-preserve-foliage-design). Pure: zones + terrain samples +
-- recipes → placement + mist-anchor lists. Recipes are dependency-injected (no
-- require of foliageZoneRecipes) so synthetic recipes test the planner. LCG
-- (no math.random) so re-runs reproduce the identical forest — same constants
-- and Sample shape as CanopyScatter.
local ZoneScatter = {}

export type Sample = { x: number, z: number, y: number, steep: number, depth: number?, material: string? }
export type Zone = {
    name: string, -- bake folder name
    shape: "rect" | "circle",
    bounds: { number }, -- rect: {x1,z1,x2,z2}; circle: {cx,cz,r}
    recipe: string, -- key into recipes table, or "KeepOut"
    densityScale: number,
    seed: number,
    mist: boolean?,
    still: boolean?,
    -- optional height band. Zones are 2D by default; a banded zone only claims
    -- samples whose ground sits inside it vertically, so a cliff-perch keep-out
    -- protects its deck without sterilising the valley floor 25 studs below.
    yMin: number?,
    yMax: number?,
}
-- per-species `scale` normalises source assets of wildly different native
-- size (the toolbox redwoods import at ~100 studs against 22-30-stud sugi).
-- `submergeMax` narrows the recipe-level submergence gate (below) to THIS
-- species only — a fern shouldn't wade as deep as a reed sharing its pool.
-- nil = defer to the recipe's submergeMax, exactly as if the field didn't
-- exist.
export type Species = { name: string, weight: number, scale: number?, submergeMax: number? }
export type Recipe = {
    pool: { Species },
    spacingMin: number,
    spacingMax: number,
    clumpChance: number,
    clumpSize: number,
    -- keep this far AWAY from water (trees off the shore)
    maxSteep: number,
    waterMargin: number,
    scaleJitter: number,
    heightScale: number?,
    innerClear: number?,
    -- if set, the plant must be WITHIN this distance of water (shore-hugging
    -- margin flora); nil = plant regardless of distance from water
    nearWater: number?,
    -- how far to stand off built geometry (paths, structures). Tested against the
    -- real geometry, NOT a bounding box: a curving path's bbox covers six times
    -- the ground the path occupies, which sterilises whole hillsides.
    pathMargin: number?,
    -- spacing only applies BETWEEN plants of the same layer, so knee-high ground
    -- cover at 4-stud spacing does not veto a tree 12 studs away. Default
    -- "canopy"; margin flora sets "ground".
    layer: string?,
    -- footing: reject sites whose ground drops away underfoot (a trunk seated
    -- over a cliff lip). radius = how far out to probe; nil = no footing check.
    footingRadius: number?,
    footingMaxDrop: number?,
    -- submersion: nil rejects any wet sample outright; a number accepts
    -- 0 < depth <= submergeMax (studs of water over the ground point). Most
    -- flora is dry-only; shore reeds and the like opt in. This is the OUTER
    -- bound for the whole pool, checked before any species is drawn — a
    -- species' own (optional) submergeMax can only narrow it further, never
    -- widen it (see pickWadingSpecies below).
    submergeMax: number?,
    -- per-band multiplier on the zone's densityScale (e.g. GARDEN = 0 clears a
    -- tended front yard of wild growth). Applied only when the caller supplies
    -- PlanOptions.careBand; a recipe with no careDensity is unaffected.
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
    -- generalises groveAffinity to an arbitrary injected point set
    -- (PlanOptions.rocks): effective density is multiplied by `inside` when
    -- the sample lies within `radius` of any rock, else `outside`. COMPOUNDS
    -- with careDensity — both multiply the same density slot. With
    -- opts.rocks nil/empty, every sample is treated as `outside`.
    rockAffinity: GroveAffinity?,
}
export type GroveConfig = {
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
export type GroveAffinity = { radius: number, inside: number, outside: number }
export type Placement = {
    x: number,
    z: number,
    y: number,
    species: string,
    yaw: number,
    scale: number,
    zone: string,
    layer: string,
}
export type MistAnchor = { x: number, z: number, y: number, zone: string }

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

-- KeepOut excludes outright. Otherwise zones are tried LAST-first, and the first
-- one whose recipe actually accepts the sample wins — so a zone layered over a
-- base zone claims only the ground its recipe wants (e.g. a shore-hugging margin
-- over the forest body: the margin takes bank samples, the forest keeps the
-- rest) instead of shadowing the base everywhere it overlaps.
local function resolveZone(
    zones: { Zone },
    x: number,
    z: number,
    y: number?,
    accepts: ((Zone) -> boolean)?
): Zone?
    -- keep-outs veto regardless of layer order, so they are checked first
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

-- Inside the reserved inner fraction of the zone (future dock/clearing floor).
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

local function pickSpecies(pool: { Species }, roll: number): (string, number, number?)
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = roll * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name, s.scale or 1, s.submergeMax
        end
    end
    local last = pool[#pool]
    return last.name, last.scale or 1, last.submergeMax
end

-- a wet sample has already cleared the recipe-level submergeMax gate in
-- `accepts` (the OUTER bound) before any species is drawn. This re-rolls a
-- fresh pickSpecies draw — same stream, not a separate one — up to 4 times
-- if the species it lands on can't personally tolerate this depth, and
-- gives up (no species) rather than forcing a shallow-water species into
-- deep water just because it won the weight roll. A dry sample (depth 0)
-- always clears on the FIRST draw, so a recipe with no per-species
-- submergeMax overrides costs exactly the one roll it always has — this is
-- a no-op wrapper until a recipe opts in.
local MAX_SUBMERGE_ATTEMPTS = 4

local function pickWadingSpecies(
    pool: { Species },
    depth: number,
    recipeSubmergeMax: number?,
    rollFn: () -> number
): (string?, number, number?)
    for _ = 1, MAX_SUBMERGE_ATTEMPTS do
        local name, scale, speciesMax = pickSpecies(pool, rollFn())
        local limit = if speciesMax ~= nil then speciesMax else recipeSubmergeMax
        if depth <= (limit or 0) then
            return name, scale, speciesMax
        end
    end
    return nil, 1, nil
end

-- grove COHERENT members choose between the already-rolled dominant/attendant
-- species (a threshold roll, not a fresh pickSpecies draw) — the wading
-- equivalent re-rolls that SAME threshold up to 4 times against the member's
-- own depth (which can differ from the elder's), reusing whichever of the two
-- species' submergence limits applies. No override on either species = the
-- limit is always the recipe's outer bound, already cleared by `accepts`, so
-- this costs exactly the one threshold roll it always has.
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
    local bestD = math.huge
    local bestY = 0
    for _, s in samples do
        local dx, dz = s.x - x, s.z - z
        local d = dx * dx + dz * dz
        if d < bestD then
            bestD = d
            bestY = s.y
        end
    end
    return bestY
end

-- Water proximity. The place carries a real water map (Sandbox.WaterMap.
-- WaterMarkers — grid-4 raycast-true water cells), so shorelines meander
-- correctly instead of being approximated by a straight ribbon. Cells are
-- bucketed on a coarse grid: a per-sample scan of every cell is O(samples x
-- cells) and the preserve has hundreds of each.
local WATER_BUCKET = 16

export type WaterIndex = { [string]: { { number } } }

function ZoneScatter.indexWater(cells: { { number } }): WaterIndex
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

export type SampleIndex = { [string]: Sample }
export type PlanOptions = {
    pitch: number?,
    keepOut: ((number, number, string?) -> boolean)?,
    careBand: ((number, number) -> string)?,
    -- injected point set for rockAffinity (e.g. the ShoreRocks pass' placed
    -- rocks); nil/empty = every recipe.rockAffinity sample is "outside"
    rocks: { { x: number, z: number } }?,
}

local function sampleKey(x: number, z: number, pitch: number): string
    return `{math.floor(x / pitch + 0.5)},{math.floor(z / pitch + 0.5)}`
end

function ZoneScatter.indexSamples(samples: { Sample }, pitch: number): SampleIndex
    local index: SampleIndex = {}
    for _, s in samples do
        index[sampleKey(s.x, s.z, pitch)] = s
    end
    return index
end

-- Max drop in studs from (x,z,y) to the ground at 8 compass probes `radius` out.
-- nil = a probe found NO sample (void: water, off-grid, past a lip) — callers
-- treat that as the WORST footing, never as level ground.
function ZoneScatter.footingDrop(
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

function ZoneScatter.plan(
    zones: { Zone },
    samples: { Sample },
    recipes: { [string]: Recipe },
    water: WaterIndex?,
    built: WaterIndex?,
    opts: PlanOptions?
): ({ Placement }, { MistAnchor })
    local o: PlanOptions = opts or {}
    local pitch = o.pitch or 4
    local sampleIndex = ZoneScatter.indexSamples(samples, pitch)

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
            local drop = ZoneScatter.footingDrop(sampleIndex, pitch, s.x, s.z, s.y, fr)
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

            -- species submergence (see pickWadingSpecies): the elder plants
            -- exactly at the anchor, so the anchor's own depth is the known
            -- depth to check. If a submergeMax-bearing pool can't find
            -- anything that tolerates it after 4 attempts, this candidate
            -- can't seat a grove at all — the anchor is already spent (never
            -- retried elsewhere) but no elder, no members, no zoneAnchors
            -- entry: an empty grove is not a placement.
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

                -- a member stands on ITS OWN candidate, not the anchor's, so
                -- its depth (and therefore its wading gate) is checked
                -- against `best`, never `anchor` — a member can be wetter or
                -- drier than the elder it clusters around
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
                    -- no species (dom/att, or the free-mix pool) tolerates
                    -- this candidate's depth: the ground is spent — it's
                    -- already removed from `candidates` above — but nothing
                    -- is placed on it, same as the per-sample skip
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
    local groveIndex = ZoneScatter.indexWater(groveAnchors)

    -- rockAffinity's lookup, built exactly like the grove-anchor index above
    -- but from the caller-injected point set rather than this pass' own
    -- output; indexWater takes positional {x, z} cells, so translate
    -- opts.rocks' named fields once here rather than at every query site
    local rockCells: { { number } } = {}
    for _, r in o.rocks or {} do
        table.insert(rockCells, { r.x, r.z })
    end
    local rockIndex = ZoneScatter.indexWater(rockCells)

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
        -- rockAffinity COMPOUNDS with careDensity and groveAffinity above —
        -- it's the same multiplicative `density` slot, not a separate gate
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

        -- greedy min-spacing against every accepted placement
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
            end
        )
        if species == nil then
            -- every attempt drew a species that can't tolerate this depth:
            -- skip the sample entirely, no placement (never a fallback)
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

    -- mist: independent dart-throw pass per mist zone, wide fixed spacing
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
                    table.insert(anchors, {
                        x = x,
                        z = z,
                        y = nearestY(ordered, x, z),
                        zone = zone.name,
                    })
                end
            end
        end
    end

    return out, anchors
end

return ZoneScatter
