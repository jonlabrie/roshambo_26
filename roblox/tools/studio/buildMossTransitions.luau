--!strict
-- buildMossTransitions.luau — the moss TRANSITION-DWELLER collector + bake (spec
-- 2026-07-30-foliage-finish, Task 14). Run via MCP execute_luau in Edit mode.
--
-- MODE="plan"  prints per-kind seed counts + total placements, stamps nothing.
-- MODE="bake"  wipes then stamps CanyonWorld.Foliage.MossTransitions.
-- MODE="wipe"  removes CanyonWorld.Foliage.MossTransitions.
--
-- Parking the OLD CanyonWorld.Foliage.MossScatter is NOT this script's job — the
-- controller does that explicitly (Task 14 Step 3) before baking this one.
--
-- ⚠️ SYNC WARNING: the planner below (types, lcg, pickSpecies, plan) is a VERBATIM
-- MIRROR of tools/builders/MossTransitions.luau — Studio cannot require from disk, so
-- keep the two in sync by hand, and fix planner bugs THERE first. Original header:
--
--   Moss as a TRANSITION-DWELLER: clumps generated around adjacency seeds (rock feet,
--   timber-meets-stone, the splash band, crevices), density falling off with distance
--   from the seed. Pure, deterministic (integer LCG). The collector re-raycasts ground
--   for Y at bake.
--
-- SEATING (mirrors buildMossScatter's lessons): a FRESH ground raycast at each
-- placement's (x, z) at bake time — the seed's own y is planning-time only and may be
-- stale after terrain edits — then the BOTTOM of the clone's bounding box (here: its own
-- Size.Y, since MossLibrary entries are single MeshParts, same convention as
-- buildMossScatter) sits at ground minus an ABSOLUTE sink of 0.15 studs, never a
-- fraction of size (a fraction buries tall upright tufts far deeper than flat mats).
--
-- SPECIES: the pool below picks a FAMILY (Moss_A / Moos_C — the kit's own typo /
-- Moss_D / Moss_E / Moss_B), weighted toward the flat mats per the brief. The pure
-- planner has no notion of ServerStorage, so the specific mesh within a family is
-- picked at BAKE time from ONE continuous deterministic LCG stream walked in placement
-- order (same idea as buildMossScatter's single sequential `state`), seeded off
-- PARAMS.seed so a re-bake reproduces the identical mix.
--
-- KEEP-OUTS: mirrors tools/builders/CanyonKeepOuts.luau (raked karesansui sand). Not
-- called out explicitly in the Task 14 brief, but buildMossScatter documents 90 clumps
-- landing on the Square's raked sand before this existed, and the crevice/footing/stone
-- corridor below overlaps that ground — carrying the same guard forward is cheap
-- insurance against repeating a known bug, not a change of scope.
local ServerStorage = game:GetService("ServerStorage")

local MODE = "plan" -- default mode; override per call via opts.mode

-- ── keep-outs (MIRROR of tools/builders/CanyonKeepOuts.luau) ────────────────────────
local KEEPOUT_MATERIALS = { [Enum.Material.Sand] = true }
local KEEPOUT_ZONES = {
    { name = "Karesansui", x0 = -25, x1 = 38, z0 = -16, z1 = 22 },
}
local function keptOut(x: number, z: number, material: Enum.Material?): boolean
    if material and KEEPOUT_MATERIALS[material] then
        return true
    end
    for _, zn in KEEPOUT_ZONES do
        if x >= zn.x0 and x <= zn.x1 and z >= zn.z0 and z <= zn.z1 then
            return true
        end
    end
    return false
end

-- ── planner (VERBATIM MIRROR of tools/builders/MossTransitions.luau) ────────────────
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

local function mossLcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function seedState(seed: number): number
    return (seed * 2654435761) % 2147483648 + 1
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

local function planMoss(seeds: { Seed }, params: Params): { MossPlacement }
    local state = seedState(params.seed)
    local function roll(): number
        local r
        state, r = mossLcg(state)
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

-- ── params (defaults from the Task 14 brief) ─────────────────────────────────────────
-- seed, scaleMin, scaleMax are NOT specified by the brief; seed follows the project's
-- dated-seed convention (buildMossScatter used 20260802), scaleMin/scaleMax mirror the
-- modest jitter used by MossTransitions.spec.luau's own test params. Tune alongside
-- kindDensity/maxDist at the USER GATE if the mix reads wrong.
local PARAMS: Params = {
    seed = 20260730,
    spacing = 1.5,
    maxDist = 5,
    dartsPerSeed = 16,
    kindDensity = { stone = 0.9, footing = 0.7, waterline = 0.8, crevice = 0.5 },
    pool = {
        { name = "Moss_A", weight = 3 },
        { name = "Moos_C", weight = 2 }, -- kit's own typo, real family name
        { name = "Moss_D", weight = 2 },
        { name = "Moss_E", weight = 1 },
        { name = "Moss_B", weight = 1 }, -- sporophyte accent stays rare
    },
    scaleMin = 0.8,
    scaleMax = 1.3,
}

local SINK = 0.15 -- ABSOLUTE studs, never multiplied by size
local BAKE_SEED_OFFSET = 700000 -- keeps the bake-time species-within-family stream
-- distinct from the planner's own seed state, same pattern as scatterPreserve's
-- MIST_SEED_OFFSET

-- ── seed generation: one function per kind ───────────────────────────────────────────

local function pvFooting(pv: PVInstance): (number, number, number, number)
    local cf, size = pv:GetBoundingBox()
    local radius = math.max(size.X, size.Z) / 2
    return cf.Position.X, cf.Position.Z, cf.Position.Y - size.Y / 2, radius
end

-- perimeter points around a base footprint, count scaling gently with footprint size
-- (small stones get the 6-point floor, big rocks/models climb toward the 10-point cap)
local function perimeterSeeds(x: number, z: number, y: number, radius: number, kind: string, out: { Seed })
    local count = math.clamp(6 + math.floor(radius), 6, 10)
    for i = 0, count - 1 do
        local ang = (i / count) * 2 * math.pi
        table.insert(out, {
            x = x + math.cos(ang) * radius,
            z = z + math.sin(ang) * radius,
            y = y,
            kind = kind,
        })
    end
end

-- stone: the 35 ^Stone_ trail-stone BaseParts, plus any Model whose name reads as a
-- rock (covers CanyonWorld.Arena's rock models and any RockLibrary-sourced clones,
-- wherever under CanyonWorld they were scattered — e.g. greenCanyon's "Mid Rock 3" /
-- "Militia Rock 1" style names).
local function collectStoneSeeds(): { Seed }
    local seeds: { Seed } = {}
    local cw = workspace:FindFirstChild("CanyonWorld")
    if not cw then
        warn("[mossTransitions] no Workspace.CanyonWorld — stone seeds empty")
        return seeds
    end
    for _, d in cw:GetDescendants() do
        local isStonePart = d:IsA("BasePart") and d.Name:match("^Stone_") ~= nil
        local isRockModel = d:IsA("Model") and d.Name:lower():find("rock") ~= nil
        if isStonePart or isRockModel then
            local x, z, y, radius = pvFooting(d :: PVInstance)
            perimeterSeeds(x, z, y, radius, "stone", seeds)
        end
    end
    return seeds
end

-- footing: BaseParts under CanyonWorld.Paths / CanyonWorld.Structures sitting within
-- 0.75 studs of the terrain, seeded along the two long bottom edges stepped every ~4
-- studs (reuses scatterPreserve.readBuiltCells' stepping formula, spacing swapped 6->4).
local FOOTING_TERRAIN_TOL = 0.75
local FOOTING_STEP = 4

-- True world-space AABB bottom Y for an oriented box: cf.Position.Y - size.Y/2 is only
-- correct at zero pitch/roll. This is the standard OBB->AABB projection (sum of the
-- absolute rotation-matrix column entries times each half-size) so a pitched ramp or
-- angled stair tread — plausible under CanyonWorld.Paths/Structures — measures its real
-- bottom, not a rotation-naive guess.
local function worldAabbBottomY(cf: CFrame, size: Vector3): number
    local halfY = math.abs(cf.RightVector.Y) * size.X / 2
        + math.abs(cf.UpVector.Y) * size.Y / 2
        + math.abs(cf.LookVector.Y) * size.Z / 2
    return cf.Position.Y - halfY
end

local function collectFootingSeeds(): { Seed }
    local seeds: { Seed } = {}
    local cw = workspace:FindFirstChild("CanyonWorld")
    if not cw then
        return seeds
    end
    local terrain = workspace.Terrain
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { terrain }

    local roots = {}
    for _, n in { "Paths", "Structures" } do
        local f = cw:FindFirstChild(n)
        if f then
            table.insert(roots, f)
        end
    end
    for _, root in roots do
        for _, d in root:GetDescendants() do
            if d:IsA("BasePart") then
                local cf, size = d.CFrame, d.Size
                local hit = workspace:Raycast(
                    Vector3.new(cf.Position.X, 400, cf.Position.Z),
                    Vector3.new(0, -900, 0),
                    rp
                )
                if hit then
                    local bottomY = worldAabbBottomY(cf, size)
                    if math.abs(bottomY - hit.Position.Y) <= FOOTING_TERRAIN_TOL then
                        local long = math.max(size.X, size.Z)
                        local short = math.min(size.X, size.Z)
                        local steps = math.clamp(math.floor(long / FOOTING_STEP), 1, 8)
                        local longDir = if size.X >= size.Z then cf.RightVector else cf.LookVector
                        local shortDir = if size.X >= size.Z then cf.LookVector else cf.RightVector
                        for edgeSign = -1, 1, 2 do
                            for i = 0, steps do
                                local t = if steps == 0 then 0.5 else i / steps
                                local off = (t - 0.5) * long
                                local pt = cf.Position + longDir * off + shortDir * (edgeSign * short / 2)
                                table.insert(seeds, { x = pt.X, z = pt.Z, y = bottomY, kind = "footing" })
                            end
                        end
                    end
                end
            end
        end
    end
    return seeds
end

-- waterline: WaterMap cells with at least one missing 4-stud cardinal neighbour (the
-- splash band is the water's own edge, not its interior).
local WATER_CELL = 4

local function collectWaterlineSeeds(): { Seed }
    local seeds: { Seed } = {}
    local sandbox = workspace:FindFirstChild("Sandbox")
    local map = sandbox and sandbox:FindFirstChild("WaterMap")
    local markers = map and map:FindFirstChild("WaterMarkers")
    if not markers then
        warn("[mossTransitions] no Sandbox.WaterMap.WaterMarkers — waterline seeds empty")
        return seeds
    end

    type Cell = { x: number, y: number, z: number, cx: number, cz: number }
    local cells: { Cell } = {}
    local index: { [string]: boolean } = {}
    for _, m in markers:GetChildren() do
        if m:IsA("BasePart") then
            local cx = math.floor(m.Position.X / WATER_CELL + 0.5)
            local cz = math.floor(m.Position.Z / WATER_CELL + 0.5)
            index[`{cx},{cz}`] = true
            table.insert(cells, { x = m.Position.X, y = m.Position.Y, z = m.Position.Z, cx = cx, cz = cz })
        end
    end

    local NEIGHBORS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for _, c in cells do
        local edge = false
        for _, off in NEIGHBORS do
            if not index[`{c.cx + off[1]},{c.cz + off[2]}`] then
                edge = true
                break
            end
        end
        if edge then
            table.insert(seeds, { x = c.x, z = c.z, y = c.y, kind = "waterline" })
        end
    end
    return seeds
end

-- crevice: terrain raycast grid (pitch 4) over the canyon corridor, keeping samples
-- whose steepness (1 - normal.Y) sits in the fold band [0.35, 0.65] — steep enough to
-- be a fold, not a cliff face. Corridor bounds mirror buildMossScatter's CONFIG.bounds,
-- the established canyon-wide moss corridor.
local CREVICE_BOUNDS = { x0 = -440, x1 = 230, z0 = -95, z1 = 95 }
local CREVICE_PITCH = 4
local CREVICE_BAND = { 0.35, 0.65 }

local function collectCreviceSeeds(): { Seed }
    local seeds: { Seed } = {}
    local terrain = workspace.Terrain
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { terrain }
    local b = CREVICE_BOUNDS
    for x = b.x0, b.x1, CREVICE_PITCH do
        for z = b.z0, b.z1, CREVICE_PITCH do
            local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -900, 0), rp)
            if hit and hit.Material ~= Enum.Material.Water then
                local steep = 1 - hit.Normal.Y
                if steep >= CREVICE_BAND[1] and steep <= CREVICE_BAND[2] then
                    table.insert(seeds, { x = x, z = z, y = hit.Position.Y, kind = "crevice" })
                end
            end
        end
    end
    return seeds
end

-- ── MossLibrary families (MIRROR of buildMossScatter's bucket-by-prefix) ────────────
local function familiesFromLibrary(): { [string]: { MeshPart } }
    local families: { [string]: { MeshPart } } = {}
    local lib = ServerStorage:FindFirstChild("MossLibrary")
    if not lib then
        warn("[mossTransitions] no ServerStorage.MossLibrary — build it via buildMossScatter first")
        return families
    end
    for _, m in lib:GetChildren() do
        if m:IsA("MeshPart") then
            local fam = m.Name:match("^(Mo[os]+_[A-E])")
            if fam then
                families[fam] = families[fam] or {}
                table.insert(families[fam], m)
            end
        end
    end
    return families
end

-- ── folder + engine flags ─────────────────────────────────────────────────────────────
local function mossFolder(): Folder
    local cw = workspace:FindFirstChild("CanyonWorld") :: Instance
    local foliage = cw:FindFirstChild("Foliage")
    if not foliage then
        foliage = Instance.new("Folder")
        foliage.Name = "Foliage"
        foliage.Parent = cw
    end
    local folder = (foliage :: Instance):FindFirstChild("MossTransitions")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "MossTransitions"
        folder.Parent = foliage
    end
    return folder :: Folder
end

local function wipeMossFolder()
    local cw = workspace:FindFirstChild("CanyonWorld")
    local foliage = cw and cw:FindFirstChild("Foliage")
    local existing = foliage and foliage:FindFirstChild("MossTransitions")
    if existing then
        existing:Destroy()
    end
end

-- moss never collides, per the brief — no collidable-trunk exception like scatterPreserve
local function flagMossClone(part: BasePart)
    part.Anchored = true
    part.CastShadow = false
    part.CanQuery = false
    part.CanTouch = false
    part.CanCollide = false
    if part:IsA("MeshPart") then
        part.RenderFidelity = Enum.RenderFidelity.Automatic
    end
end

-- ── bake ──────────────────────────────────────────────────────────────────────────────
local function bake(
    placements: { MossPlacement },
    families: { [string]: { MeshPart } }
): (number, number, { [string]: number })
    local terrain = workspace.Terrain
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { terrain }
    local folder = mossFolder()

    local state = seedState(PARAMS.seed + BAKE_SEED_OFFSET)
    local placed = 0
    local refused = 0
    local missing: { [string]: number } = {}

    for i, p in placements do
        local pool = families[p.species]
        if not pool or #pool == 0 then
            missing[p.species] = (missing[p.species] or 0) + 1
            continue
        end
        local r
        state, r = mossLcg(state)
        local template = pool[math.floor(r * #pool) + 1]

        -- FRESH raycast at bake time — the seed's own y is planning-time only
        local hit = workspace:Raycast(Vector3.new(p.x, 400, p.z), Vector3.new(0, -900, 0), rp)
        if not hit or keptOut(p.x, p.z, hit.Material) then
            refused += 1
            continue
        end

        local clone = template:Clone()
        clone.Name = `Moss_{p.kind}_{i}`
        if p.scale ~= 1 then
            clone.Size = template.Size * p.scale
        end
        -- bottom of the clone's box (its own Size.Y for a single MeshPart, same
        -- convention as buildMossScatter) sits at ground minus the ABSOLUTE sink
        clone.CFrame = CFrame.new(p.x, hit.Position.Y - SINK + clone.Size.Y / 2, p.z)
            * CFrame.Angles(0, p.yaw, 0)
        flagMossClone(clone)
        clone.Parent = folder
        placed += 1
    end

    return placed, refused, missing
end

-- ── Studio shell ──────────────────────────────────────────────────────────────────────
-- Paste this file ONCE into Studio as ServerStorage.MossTransitionsTool (ModuleScript),
-- then drive it with small calls, e.g.
--   local run = require(game.ServerStorage.MossTransitionsTool)
--   return run({ mode = "plan" })
--   return run({ mode = "bake" })
return function(opts: { mode: string? }?): string
    local mode = (opts and opts.mode) or MODE

    local seeds: { Seed } = {}
    for _, s in collectStoneSeeds() do
        table.insert(seeds, s)
    end
    for _, s in collectFootingSeeds() do
        table.insert(seeds, s)
    end
    for _, s in collectWaterlineSeeds() do
        table.insert(seeds, s)
    end
    for _, s in collectCreviceSeeds() do
        table.insert(seeds, s)
    end

    -- sort by (x, z) so collection order can never change the bake
    table.sort(seeds, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)

    local perKind: { [string]: number } = {}
    for _, s in seeds do
        perKind[s.kind] = (perKind[s.kind] or 0) + 1
    end

    local placements = planMoss(seeds, PARAMS)

    local kindLines = {}
    for _, kind in { "stone", "footing", "waterline", "crevice" } do
        table.insert(kindLines, `{kind}={perKind[kind] or 0}`)
    end
    local summary =
        `[mossTransitions] {mode}: seeds={#seeds} ({table.concat(kindLines, " ")}) placements={#placements}`
    print(summary)

    if mode == "wipe" then
        wipeMossFolder()
        return summary .. "\nwiped CanyonWorld.Foliage.MossTransitions"
    end

    if mode == "bake" then
        wipeMossFolder()
        local families = familiesFromLibrary()
        local placed, refused, missing = bake(placements, families)
        local lines = { `stamped {placed} clumps into CanyonWorld.Foliage.MossTransitions` }
        if refused > 0 then
            table.insert(lines, `refused {refused} (keep-out or no ground hit)`)
        end
        local missingLines = {}
        for species, n in missing do
            table.insert(missingLines, `{species} x{n}`)
        end
        table.sort(missingLines)
        if #missingLines > 0 then
            table.insert(lines, `missing MossLibrary families: {table.concat(missingLines, ", ")}`)
        end
        return summary .. "\n" .. table.concat(lines, "\n")
    end

    return summary .. "\nplan only -- nothing stamped"
end
