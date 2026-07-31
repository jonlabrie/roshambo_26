--!strict
-- Moss as a TRANSITION-DWELLER (spec 2026-07-30-foliage-finish-design §Part 3):
-- clumps generated around adjacency seeds (rock feet, timber-meets-stone, the
-- splash band, crevices), density falling off with distance from the seed. Pure,
-- deterministic (integer LCG). The collector re-raycasts ground for Y at bake.
local MossTransitions = {}

export type Seed = { x: number, z: number, y: number, kind: string }
export type Params = {
    seed: number,
    spacing: number,
    maxDist: number,
    dartsPerSeed: number,
    kindDensity: { [string]: number },
    pool: { { name: string, weight: number } },
    scaleMin: number,
    scaleMax: number,
}
export type MossPlacement = {
    x: number,
    z: number,
    species: string,
    yaw: number,
    scale: number,
    kind: string,
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
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

function MossTransitions.plan(seeds: { Seed }, params: Params): { MossPlacement }
    local state = (params.seed * 2654435761) % 2147483648 + 1
    local function roll(): number
        local r
        state, r = lcg(state)
        return r
    end

    local out: { MossPlacement } = {}
    for _, seed in seeds do
        local density = params.kindDensity[seed.kind]
        if density == nil then
            continue
        end
        for _ = 1, params.dartsPerSeed do
            local ang = roll() * 2 * math.pi
            local dist = roll() * params.maxDist
            -- linear falloff: acceptance shrinks as the dart lands further out
            local accept = roll()
            if accept >= density * (1 - dist / params.maxDist) then
                continue
            end
            local x = seed.x + math.cos(ang) * dist
            local z = seed.z + math.sin(ang) * dist
            local tooClose = false
            for _, p in out do
                local dx, dz = x - p.x, z - p.z
                if dx * dx + dz * dz < params.spacing * params.spacing then
                    tooClose = true
                    break
                end
            end
            if tooClose then
                continue
            end
            table.insert(out, {
                x = x,
                z = z,
                species = pickSpecies(params.pool, roll()),
                yaw = roll() * 2 * math.pi,
                scale = params.scaleMin + roll() * (params.scaleMax - params.scaleMin),
                kind = seed.kind,
            })
        end
    end
    return out
end

return MossTransitions
