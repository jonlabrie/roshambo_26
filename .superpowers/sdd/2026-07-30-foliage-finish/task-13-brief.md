### Task 13: MossTransitions planner (pure)

**Files:**
- Create: `roblox/tools/builders/MossTransitions.luau`
- Test: `roblox/tests/MossTransitions.spec.luau`

**Interfaces:**
- Produces (Task 14's collector consumes exactly these):

```luau
export type Seed = { x: number, z: number, y: number, kind: string }
export type Params = {
    seed: number,
    spacing: number,          -- min distance between clumps (studs)
    maxDist: number,          -- how far moss wanders from its seed
    dartsPerSeed: number,
    kindDensity: { [string]: number }, -- 0..1 acceptance scale per seed kind
    pool: { { name: string, weight: number } },
    scaleMin: number,
    scaleMax: number,
}
export type MossPlacement = { x: number, z: number, species: string, yaw: number, scale: number, kind: string }
MossTransitions.plan(seeds: { Seed }, params: Params): { MossPlacement }
```

Note: placements carry NO y — the collector re-raycasts the ground at the final (x, z) and seats the BOTTOM of the bounding box (the moss-bug lessons: never reuse a height measured elsewhere, never seat the centre).

- [ ] **Step 1: Write the failing tests:**

```luau
--!strict
local harness = require("./harness")
local MossTransitions = require("../tools/builders/MossTransitions")
local describe, test, expect = harness.describe, harness.test, harness.expect

local PARAMS: MossTransitions.Params = {
    seed = 11,
    spacing = 1.5,
    maxDist = 6,
    dartsPerSeed = 24,
    kindDensity = { stone = 1.0, waterline = 0.8 },
    pool = { { name = "Moss_A", weight = 3 }, { name = "Moss_B", weight = 1 } },
    scaleMin = 0.8,
    scaleMax = 1.3,
}

describe("MossTransitions.plan", function()
    test("deterministic: same input twice = identical output", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "stone" } }
        local a = MossTransitions.plan(seeds, PARAMS)
        local b = MossTransitions.plan(seeds, PARAMS)
        expect(#a).toBe(#b)
        for i, p in a do
            expect(p.x).toBe(b[i].x)
            expect(p.species).toBe(b[i].species)
        end
    end)

    test("moss hugs the transition: density falls with distance", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "stone" } }
        local near, far = 0, 0
        for _, p in MossTransitions.plan(seeds, PARAMS) do
            local d = math.sqrt(p.x * p.x + p.z * p.z)
            expect(d <= PARAMS.maxDist).toBe(true)
            if d <= PARAMS.maxDist / 2 then
                near += 1
            else
                far += 1
            end
        end
        expect(near > far).toBe(true)
    end)

    test("spacing holds across neighbouring seeds", function()
        local seeds = {
            { x = 0, z = 0, y = 10, kind = "stone" },
            { x = 3, z = 0, y = 10, kind = "stone" },
        }
        local placements = MossTransitions.plan(seeds, PARAMS)
        for i, p in placements do
            for j = i + 1, #placements do
                local q = placements[j]
                local dx, dz = p.x - q.x, p.z - q.z
                expect(dx * dx + dz * dz >= PARAMS.spacing * PARAMS.spacing).toBe(true)
            end
        end
    end)

    test("an unknown kind places nothing", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "confetti" } }
        expect(#MossTransitions.plan(seeds, PARAMS)).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement:**

```luau
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
```

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): MossTransitions - moss lives in the crevices, not the confetti"`

