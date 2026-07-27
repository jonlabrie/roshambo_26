--!strict
-- scatterPreserve.luau — zone-painted forest-preserve planting (spec
-- 2026-07-27-forest-preserve-foliage-design). Run via MCP execute_luau (Edit).
--
-- MODE="plan"  prints per-zone placement counts, stamps nothing.
-- MODE="bake"  wipes then stamps the filtered zones' folders.
-- MODE="wipe"  removes the filtered zones' folders.
-- MODE="mist"  wipes + stamps ONLY Preserve.Mist (safe after trees are curated).
--
-- Zones are USER-EDITABLE parts in Workspace.Sandbox.FoliageZones: box or
-- cylinder, attributes Recipe (string), DensityScale (number?), Seed (number?),
-- Mist (bool?), Still (bool?). Drag/resize/duplicate/delete them freely; the
-- bake reads whatever is there. Bakes land in CanyonWorld.Foliage.Preserve.<Zone>
-- (PLACE-ONLY — save the place to keep them).
--
-- The planner below MIRRORS tools/builders/ZoneScatter.luau and the recipe table
-- MIRRORS tools/studio/foliageZoneRecipes.luau — Studio cannot require from disk,
-- so KEEP ALL THREE IN SYNC (same convention as CanopyScatter/placeCanopyHeroes).
-- Determinism: integer LCG only, seeded per zone, so a re-bake reproduces the
-- identical forest and gate iteration is parameter edits, not lost state.
local ServerStorage = game:GetService("ServerStorage")

local MODE = "plan" -- default mode; override per call via opts.mode
local ZONES: { string } = {} -- default filter (empty = every zone); override via opts.zones
local SAMPLE_PITCH = 4 -- terrain probe grid, studs
local PROBE_TOP = 400

-- ── recipes (MIRROR of tools/studio/foliageZoneRecipes.luau) ────────────────
type Species = { name: string, weight: number }
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
}
local RECIPES: { [string]: Recipe } = {
    PreserveCore = {
        pool = {
            { name = "SugiMidA", weight = 25 },
            { name = "SugiMidB", weight = 25 },
            { name = "SugiMidC", weight = 25 },
            { name = "FirM", weight = 15 },
            { name = "CedarS", weight = 10 },
        },
        -- 10-15 gates the approved walk-among density (2026-07-27 gate)
        spacingMin = 10,
        spacingMax = 15,
        clumpChance = 0.18,
        clumpSize = 3,
        maxSteep = 0.55,
        waterMargin = 4,
        scaleJitter = 0.15,
    },
    WallFringe = {
        pool = {
            { name = "ConiferA", weight = 30 },
            { name = "ConiferB", weight = 30 },
            { name = "ConiferC", weight = 25 },
            { name = "CedarM", weight = 15 },
        },
        spacingMin = 10,
        spacingMax = 16,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.9,
        waterMargin = 4,
        scaleJitter = 0.2,
        heightScale = 1.15,
    },
    WaterMargin = {
        pool = {
            { name = "MuhlyGrass", weight = 50 },
            { name = "ReedClump", weight = 30 },
            { name = "FernClump", weight = 20 },
        },
        spacingMin = 4,
        spacingMax = 8,
        clumpChance = 0.3,
        clumpSize = 3,
        maxSteep = 0.7,
        waterMargin = 0,
        scaleJitter = 0.25,
        -- hug the real shoreline from Sandbox.WaterMap.WaterMarkers
        nearWater = 12,
    },
    FutureClearing = {
        pool = {
            { name = "SugiMidA", weight = 25 },
            { name = "SugiMidB", weight = 25 },
            { name = "SugiMidC", weight = 25 },
            { name = "FirM", weight = 15 },
            { name = "CedarS", weight = 10 },
        },
        spacingMin = 20,
        spacingMax = 30,
        clumpChance = 0,
        clumpSize = 0,
        maxSteep = 0.55,
        waterMargin = 4,
        scaleJitter = 0.15,
        innerClear = 0.5,
    },
}

-- ── planner (MIRROR of tools/builders/ZoneScatter.luau) ─────────────────────
type Sample = { x: number, z: number, y: number, steep: number }
type Zone = {
    name: string,
    shape: string,
    bounds: { number },
    recipe: string,
    densityScale: number,
    seed: number,
    mist: boolean?,
    still: boolean?,
}
type Placement = {
    x: number,
    z: number,
    y: number,
    species: string,
    yaw: number,
    scale: number,
    zone: string,
}
type MistAnchor = { x: number, z: number, y: number, zone: string }

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

local function pickSpecies(pool: { Species }, r: number): string
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = r * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name
        end
    end
    return pool[#pool].name
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
-- so per-sample lookups stay cheap.
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
    water: WaterIndex?
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
        if waterWithin(water, s.x, s.z, recipe.waterMargin) then
            continue
        end
        local nearWater = recipe.nearWater
        if nearWater ~= nil and not waterWithin(water, s.x, s.z, nearWater) then
            continue
        end
        if roll(zone) >= zone.densityScale then
            continue
        end
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
                    table.insert(anchors, { x = x, z = z, y = nearestY(ordered, x, z), zone = zone.name })
                end
            end
        end
    end
    return out, anchors
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
    local sandbox = workspace:FindFirstChild("Sandbox")
    local folder = sandbox and sandbox:FindFirstChild("FoliageZones")
    local zones: { Zone } = {}
    if not folder then
        warn("[preserve] no Workspace.Sandbox.FoliageZones — nothing to do")
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
            table.insert(zones, {
                name = part.Name,
                shape = shape,
                bounds = bounds,
                recipe = recipe,
                densityScale = typeof(density) == "number" and density or 1,
                seed = typeof(seed) == "number" and seed or nameSeed(part.Name),
                mist = part:GetAttribute("Mist") == true,
                still = part:GetAttribute("Still") == true,
            })
        end
    end
    return zones
end

local function sampleTerrain(zones: { Zone }): { Sample }
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { workspace.Terrain }
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
            local hit = workspace:Raycast(Vector3.new(x, PROBE_TOP, z), Vector3.new(0, -900, 0), rp)
            if hit and hit.Material ~= Enum.Material.Water then
                table.insert(samples, {
                    x = x,
                    z = z,
                    y = hit.Position.Y,
                    steep = 1 - math.clamp(hit.Normal.Y, 0, 1),
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
        local box, size = clone:GetBoundingBox()
        clone:PivotTo(clone:GetPivot() + Vector3.new(0, p.y - 0.3 - (box.Position.Y - size.Y / 2), 0))
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
    local placements, anchors = plan(zones, samples, recipes, indexWater(cells))

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
        `[preserve] {mode}: zones={#zones} samples={#samples} water={#cells} placements={#placements} mist={#anchors} | {table.concat(
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
