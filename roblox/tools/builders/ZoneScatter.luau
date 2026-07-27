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
}
export type Recipe = {
    pool: { { name: string, weight: number } },
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
export type Placement = {
    x: number,
    z: number,
    y: number,
    species: string,
    yaw: number,
    scale: number,
    zone: string,
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

local function contains(zone: Zone, x: number, z: number): boolean
    local b = zone.bounds
    if zone.shape == "circle" then
        local dx, dz = x - b[1], z - b[2]
        return dx * dx + dz * dz <= b[3] * b[3]
    end
    return x >= b[1] and z >= b[2] and x <= b[3] and z <= b[4]
end

-- KeepOut excludes outright; otherwise the LAST matching non-KeepOut zone wins
-- so users can layer small patches over big base zones.
local function resolveZone(zones: { Zone }, x: number, z: number): Zone?
    local chosen: Zone? = nil
    for _, zone in zones do
        if contains(zone, x, z) then
            if zone.recipe == "KeepOut" then
                return nil
            end
            chosen = zone
        end
    end
    return chosen
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

local function pickSpecies(pool: { { name: string, weight: number } }, roll: number): string
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = roll * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name
        end
    end
    return pool[#pool].name
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
    recipes: { [string]: Recipe }
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

    for _, s in ordered do
        local zone = resolveZone(zones, s.x, s.z)
        if zone == nil then
            continue
        end
        local recipe = recipes[zone.recipe]
        if recipe == nil then
            continue
        end
        if s.steep > recipe.maxSteep then
            continue
        end
        local innerClear = recipe.innerClear
        if innerClear ~= nil and inInnerClear(zone, innerClear, s.x, s.z) then
            continue
        end

        -- density thinning before spacing so DensityScale thins uniformly
        if roll(zone) >= zone.densityScale then
            continue
        end

        -- greedy min-spacing against every accepted placement
        local minD = recipe.spacingMin + roll(zone) * (recipe.spacingMax - recipe.spacingMin)
        local tooClose = false
        for _, p in out do
            local dx, dz = s.x - p.x, s.z - p.z
            if dx * dx + dz * dz <= minD * minD then
                tooClose = true
                break
            end
        end
        if tooClose then
            continue
        end

        local heightScale = recipe.heightScale or 1
        local species = pickSpecies(recipe.pool, roll(zone))
        table.insert(out, {
            x = s.x,
            z = s.z,
            y = s.y,
            species = species,
            yaw = roll(zone) * 2 * math.pi,
            scale = (1 + (roll(zone) * 2 - 1) * recipe.scaleJitter) * heightScale,
            zone = zone.name,
        })

        -- clump: extra same-species trees at 4-7 studs, spacing waived within
        -- the clump but zone membership and keep-outs still hold
        if roll(zone) < recipe.clumpChance and recipe.clumpSize >= 2 then
            for _ = 1, recipe.clumpSize - 1 do
                local ang = roll(zone) * 2 * math.pi
                local radius = CLUMP_RADIUS_MIN + roll(zone) * (CLUMP_RADIUS_MAX - CLUMP_RADIUS_MIN)
                local cx = s.x + math.cos(ang) * radius
                local cz = s.z + math.sin(ang) * radius
                if resolveZone(zones, cx, cz) == zone then
                    table.insert(out, {
                        x = cx,
                        z = cz,
                        y = nearestY(ordered, cx, cz),
                        species = species,
                        yaw = roll(zone) * 2 * math.pi,
                        scale = (1 + (roll(zone) * 2 - 1) * recipe.scaleJitter) * heightScale,
                        zone = zone.name,
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
            if contains(zone, x, z) then
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
