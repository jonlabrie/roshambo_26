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
}
-- THE FOUR BANDS (the user's structure, and the point of the whole system):
--   0-2 studs   ground cover — grass and weeds. DOES NOT EXIST YET; the same gap
--               leaves the waterline bare. See the WaterMargin pool below.
--   2-5 studs   young growth below the eyeline — PreserveBrush.
--   5-7 studs   DELIBERATELY EMPTY. This is the sightline band; a player's eye is
--               at ~5. Nothing may be planted whose foliage occupies it.
--   7+ studs    canopy — PreserveCore, drawn only from SKIRT-trimmed models.
-- "A forest that feels heavy, but has decent sightlines through the trees."
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
        pathMargin = 7,
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
    },
    WallFringe = {
        pool = {
            -- per-species scale tames the toolbox giants (ConiferA 98 studs,
            -- ConiferB 107, ConiferC 71 native) toward the 45-70 band while
            -- CedarM keeps its own 45; scaleJitter 0.35 then spreads each
            -- species so the wall reads as a mixed-age stand, not a hedge.
            { name = "ConiferA", weight = 30, scale = 0.7 },
            { name = "ConiferB", weight = 30, scale = 0.62 },
            { name = "ConiferC", weight = 25, scale = 0.9 },
            { name = "CedarM", weight = 15, scale = 1.0 },
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
        -- hug the real (meandering) shoreline from Sandbox.WaterMap.WaterMarkers
        -- rather than carpeting the zone; 8 studs of bank either side.
        nearWater = 8,
        -- ground cover spaces against other ground cover only, never against trees
        layer = "ground",
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
        pathMargin = 6,
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
        if roll(zone) >= zone.densityScale then
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
    local placements, anchors = plan(zones, samples, recipes, indexWater(cells), indexWater(builtCells))

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
