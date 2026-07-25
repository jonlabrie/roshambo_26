--!strict
-- Deterministic canopy placement for the square-viewshed foliage pass (spec
-- 2026-07-25-square-canopy-foliage-design). Pure: terrain samples + config +
-- seed → placement list. The Studio shell (tools/studio/scatterCanopy.luau)
-- MIRRORS this file — keep in sync. LCG (no math.random) so re-runs reproduce
-- the identical forest and gate iteration is parameter edits, not lost state.
local CanopyScatter = {}

export type Sample = { x: number, z: number, y: number, steep: number }
export type Placement = {
    x: number,
    z: number,
    y: number,
    species: string,
    yaw: number,
    scale: number,
    tint: number,
}
export type Config = {
    yMin: number,
    yMax: number,
    maxSteep: number,
    spacing: number,
    spacingJitter: number,
    rects: { { number } },
    circles: { { number } },
    waterCells: { { number } },
    waterMargin: number,
    conifers: { { name: string, weight: number } },
    broadleaf: { name: string, weight: number }?,
    heroMix: { { number } },
    heroMixRadius: number,
    keepLowY: number?,
    scaleJitter: number,
    tintJitter: number,
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function inRect(x: number, z: number, r: { number }): boolean
    return x >= r[1] and z >= r[2] and x <= r[3] and z <= r[4]
end

local function nearPoint(x: number, z: number, px: number, pz: number, d: number): boolean
    local dx, dz = x - px, z - pz
    return dx * dx + dz * dz <= d * d
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

function CanopyScatter.plan(samples: { Sample }, cfg: Config, seed: number): { Placement }
    local ordered = table.clone(samples)
    table.sort(ordered, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)

    local state = (seed * 2654435761) % 2147483648 + 1
    local out: { Placement } = {}

    for _, s in ordered do
        if s.y < cfg.yMin or s.y > cfg.yMax then
            continue
        end
        if s.steep > cfg.maxSteep then
            continue
        end
        local excluded = false
        for _, r in cfg.rects do
            if inRect(s.x, s.z, r) then
                excluded = true
                break
            end
        end
        if not excluded then
            for _, c in cfg.circles do
                if nearPoint(s.x, s.z, c[1], c[2], c[3]) then
                    excluded = true
                    break
                end
            end
        end
        if not excluded then
            for _, w in cfg.waterCells do
                if nearPoint(s.x, s.z, w[1], w[2], cfg.waterMargin) then
                    excluded = true
                    break
                end
            end
        end
        if excluded then
            continue
        end

        -- altitude density ramp: keep probability lerps keepLowY → 1 across the band
        if cfg.keepLowY ~= nil then
            local t = (s.y - cfg.yMin) / math.max(cfg.yMax - cfg.yMin, 1e-6)
            local keep = cfg.keepLowY + (1 - cfg.keepLowY) * t
            local roll
            state, roll = lcg(state)
            if roll > keep then
                continue
            end
        end

        -- greedy min-spacing against accepted placements
        local spacingRoll
        state, spacingRoll = lcg(state)
        local minD = cfg.spacing + spacingRoll * cfg.spacingJitter
        local tooClose = false
        for _, p in out do
            if nearPoint(s.x, s.z, p.x, p.z, minD) then
                tooClose = true
                break
            end
        end
        if tooClose then
            continue
        end

        -- species: broadleaf joins the pool near hero centres
        local pool = cfg.conifers
        local broadleaf = cfg.broadleaf
        if broadleaf ~= nil then
            for _, h in cfg.heroMix do
                if nearPoint(s.x, s.z, h[1], h[2], cfg.heroMixRadius) then
                    pool = table.clone(cfg.conifers)
                    table.insert(pool, broadleaf)
                    break
                end
            end
        end
        local speciesRoll, yawRoll, scaleRoll, tintRoll
        state, speciesRoll = lcg(state)
        state, yawRoll = lcg(state)
        state, scaleRoll = lcg(state)
        state, tintRoll = lcg(state)
        table.insert(out, {
            x = s.x,
            z = s.z,
            y = s.y,
            species = pickSpecies(pool, speciesRoll),
            yaw = yawRoll * 2 * math.pi,
            scale = 1 + (scaleRoll * 2 - 1) * cfg.scaleJitter,
            tint = 1 + (tintRoll * 2 - 1) * cfg.tintJitter,
        })
    end
    return out
end

return CanopyScatter
