--!strict
-- Deterministic zone-painted scatter for the forest preserve (spec
-- 2026-07-27-forest-preserve-foliage-design). Pure: zones + terrain samples +
-- recipes → placement + mist-anchor lists. Recipes are dependency-injected (no
-- require of foliageZoneRecipes) so synthetic recipes test the planner. LCG
-- (no math.random) so re-runs reproduce the identical forest — same constants
-- and Sample shape as CanopyScatter.
local ZoneScatter = {}

export type Sample = { x: number, z: number, y: number, steep: number }
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
export type Recipe = {
    -- per-species `scale` normalises source assets of wildly different native
    -- size (the toolbox redwoods import at ~100 studs against 22-30-stud sugi)
    pool: { { name: string, weight: number, scale: number? } },
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
}
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
    for _, zone in zones do
        if zone.recipe == "KeepOut" and contains(zone, x, z, y) then
            return nil
        end
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

local function pickSpecies(
    pool: { { name: string, weight: number, scale: number? } },
    roll: number
): (string, number)
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = roll * total
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
    built: WaterIndex?
): ({ Placement }, { MistAnchor })
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

    -- site gates: everything that depends only on the sample and the recipe, so
    -- a layered zone that rejects a sample falls through to the zone beneath it
    local function accepts(zone: Zone, s: Sample): boolean
        local recipe = recipes[zone.recipe]
        if recipe == nil then
            return false
        end
        if s.steep > recipe.maxSteep then
            return false
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

    for _, s in ordered do
        local zone = resolveZone(zones, s.x, s.z, s.y, function(candidate)
            return accepts(candidate, s)
        end)
        if zone == nil then
            continue
        end
        local recipe = recipes[zone.recipe]
        if recipe == nil then
            continue
        end

        -- density thinning before spacing so DensityScale thins uniformly
        if roll(zone) >= zone.densityScale then
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
                local probe: Sample = { x = cx, z = cz, y = cy, steep = if cs then cs.steep else 0 }
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
