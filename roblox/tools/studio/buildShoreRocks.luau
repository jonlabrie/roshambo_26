--!strict
-- buildShoreRocks.luau — the pool-waterline rock collector + bake (user-approved
-- 2026-07-31 insertion before the moss-transition bake: pools need rock feet at their
-- waterlines before moss transitions mean anything there). Run via MCP execute_luau in
-- Edit mode.
--
-- MODE="plan"  prints edge/anchor/placement counts, stamps nothing.
-- MODE="bake"  wipes then stamps CanyonWorld.Foliage.ShoreRocks.
-- MODE="wipe"  removes CanyonWorld.Foliage.ShoreRocks.
--
-- ⚠️ SYNC WARNING: the planner below (types, lcg, indexes, plan) is a VERBATIM MIRROR
-- of tools/builders/ShoreRocks.luau — Studio cannot require from disk, so keep the two
-- in sync by hand, and fix planner bugs THERE first.
--
-- REGISTER (why the numbers are what they are): ishigumi, not a necklace — one big
-- ANCHOR stone, a few mid ATTENDANTS, sometimes a small WADER half in the water, then
-- long deliberately bare bank. Density peaks at inflow/outfall lips.
--
-- SPECIES: role -> a footprint tier of ServerStorage.RockLibrary (anchor 8-15 studs,
-- attendant 3-8, wader 2-5; the 15+ monsters stay hand-place-only). The specific rock
-- within a tier is picked at BAKE time from ONE continuous deterministic LCG stream
-- walked in placement order (same pattern as buildMossTransitions' family stream).
--
-- SEATING: FRESH terrain raycast (IgnoreWater = true, so waders measure the BED, not
-- the surface) at each placement; the rock's bottom sits at ground minus a FRACTION of
-- its scaled height (rocks bury, unlike moss's absolute sink): anchors/attendants 25%,
-- waders 15% (the water covers them the rest of the way). A placement whose ground
-- diverges more than GROUND_TOL from its cluster's water y is refused (it drifted onto
-- a cliff shelf).
--
-- KEEP-OUTS: karesansui sand rectangle (CanyonKeepOuts mirror), the COMPOSED falls-pool
-- site (dock + hero iris — hands off, per the standing water-margin rule), and every
-- Sandbox.FoliageZones part whose Recipe attribute is "KeepOut" (pads etc.), checked in
-- the part's object space so rotated pads mask correctly.
local ServerStorage = game:GetService("ServerStorage")

local MODE = "plan" -- default mode; override per call via opts.mode

-- ── planner (VERBATIM MIRROR of tools/builders/ShoreRocks.luau) ─────────────────────
export type WaterCell = { x: number, z: number, y: number }
export type Params = {
    seed: number,
    cell: number, -- water-map grid pitch
    sheetTol: number, -- |dy| <= sheetTol => same water sheet
    lipRadius: number, -- radius scanned for elevation jumps
    lipMinDrop: number, -- min |dy| within lipRadius to count as a lip
    lipSpacing: number, -- min distance between lip-cluster anchors
    quietSpacing: number, -- min distance between quiet-bank anchors AND from lip anchors
    memberRadiusMin: number, -- attendant polar offset from anchor
    memberRadiusMax: number,
    memberSpacing: number, -- min distance between any two placements in the plan
    attendantsMin: number,
    attendantsMax: number,
    wadersMax: number, -- 0..wadersMax waders per cluster, rolled uniformly
    waderReach: number, -- max wader step toward open water (floor is memberSpacing)
    scaleMin: number,
    scaleMax: number,
}
export type RockPlacement = {
    x: number,
    z: number,
    role: string, -- "anchor" | "attendant" | "wader"
    yaw: number, -- radians
    scale: number,
    lip: boolean, -- true if this cluster was seeded by lip score
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function key(cx: number, cz: number): string
    return `{cx},{cz}`
end

-- same rounding as the water map
local function cellKey(x: number, z: number, cell: number): string
    return key(math.floor(x / cell + 0.5), math.floor(z / cell + 0.5))
end

-- fixed order: east/west/south/north = (+x, -x, +z, -z)
local DIRS = {
    { dx = 1, dz = 0 },
    { dx = -1, dz = 0 },
    { dx = 0, dz = 1 },
    { dx = 0, dz = -1 },
}

type Index = { [string]: { WaterCell } }

local function buildIndex(cells: { WaterCell }, cell: number): Index
    local index: Index = {}
    for _, c in cells do
        local k = cellKey(c.x, c.z, cell)
        local bucket = index[k]
        if bucket == nil then
            bucket = {}
            index[k] = bucket
        end
        table.insert(bucket, c)
    end
    return index
end

local function sheetPresent(index: Index, cx: number, cz: number, y: number, sheetTol: number): boolean
    local bucket = index[key(cx, cz)]
    if bucket == nil then
        return false
    end
    for _, c in bucket do
        if math.abs(c.y - y) <= sheetTol then
            return true
        end
    end
    return false
end

type EdgeCell = {
    cell: WaterCell,
    landDx: number,
    landDz: number,
}

local function findEdgeCells(
    cells: { WaterCell },
    index: Index,
    cellSize: number,
    sheetTol: number
): { EdgeCell }
    local edges: { EdgeCell } = {}
    for _, c in cells do
        local cx = math.floor(c.x / cellSize + 0.5)
        local cz = math.floor(c.z / cellSize + 0.5)
        local landDx: number? = nil
        local landDz: number? = nil
        for _, d in DIRS do
            if not sheetPresent(index, cx + d.dx, cz + d.dz, c.y, sheetTol) then
                landDx, landDz = d.dx, d.dz
                break
            end
        end
        if landDx ~= nil and landDz ~= nil then
            table.insert(edges, { cell = c, landDx = landDx, landDz = landDz })
        end
    end
    return edges
end

-- max |dy| between c and any cell within lipRadius (XZ euclidean)
local function lipScore(index: Index, cellSize: number, c: WaterCell, lipRadius: number): number
    local kr = math.ceil(lipRadius / cellSize)
    local cx = math.floor(c.x / cellSize + 0.5)
    local cz = math.floor(c.z / cellSize + 0.5)
    local best = 0
    for gx = cx - kr, cx + kr do
        for gz = cz - kr, cz + kr do
            local bucket = index[key(gx, gz)]
            if bucket ~= nil then
                for _, other in bucket do
                    local dx, dz = other.x - c.x, other.z - c.z
                    if dx * dx + dz * dz <= lipRadius * lipRadius then
                        local dy = math.abs(other.y - c.y)
                        if dy > best then
                            best = dy
                        end
                    end
                end
            end
        end
    end
    return best
end

local function withinBand(edgeIndex: Index, cellSize: number, x: number, z: number, band: number): boolean
    local kr = math.ceil(band / cellSize)
    local cx = math.floor(x / cellSize + 0.5)
    local cz = math.floor(z / cellSize + 0.5)
    for gx = cx - kr, cx + kr do
        for gz = cz - kr, cz + kr do
            local bucket = edgeIndex[key(gx, gz)]
            if bucket ~= nil then
                for _, e in bucket do
                    local dx, dz = x - e.x, z - e.z
                    if dx * dx + dz * dz <= band * band then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function nearExisting(existing: { { x: number, z: number } }?, x: number, z: number): boolean
    if existing == nil then
        return false
    end
    for _, e in existing :: { { x: number, z: number } } do
        local dx, dz = x - e.x, z - e.z
        if dx * dx + dz * dz <= 100 then
            return true
        end
    end
    return false
end

type Candidate = {
    x: number,
    z: number,
    landDx: number,
    landDz: number,
    score: number,
    lip: boolean,
}

local function plan(
    cells: { WaterCell },
    params: Params,
    keepOut: ((number, number) -> boolean)?,
    existing: { { x: number, z: number } }?
): { RockPlacement }
    local index = buildIndex(cells, params.cell)
    local edges = findEdgeCells(cells, index, params.cell, params.sheetTol)

    local edgeIndex: Index = {}
    for _, e in edges do
        local k = cellKey(e.cell.x, e.cell.z, params.cell)
        local bucket = edgeIndex[k]
        if bucket == nil then
            bucket = {}
            edgeIndex[k] = bucket
        end
        table.insert(bucket, e.cell)
    end

    -- candidate filter (step 4) + lip/quiet split
    local lipCandidates: { Candidate } = {}
    local quietCandidates: { Candidate } = {}
    for _, e in edges do
        local c = e.cell
        if keepOut ~= nil and keepOut(c.x, c.z) then
            continue
        end
        if nearExisting(existing, c.x, c.z) then
            continue
        end
        local score = lipScore(index, params.cell, c, params.lipRadius)
        local cand: Candidate = {
            x = c.x,
            z = c.z,
            landDx = e.landDx,
            landDz = e.landDz,
            score = score,
            lip = score >= params.lipMinDrop,
        }
        if cand.lip then
            table.insert(lipCandidates, cand)
        else
            table.insert(quietCandidates, cand)
        end
    end

    table.sort(lipCandidates, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)
    table.sort(quietCandidates, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        return a.z < b.z
    end)

    local anchors: { Candidate } = {}
    local function farFromAnchors(cand: Candidate, minDist: number): boolean
        for _, a in anchors do
            local dx, dz = cand.x - a.x, cand.z - a.z
            if dx * dx + dz * dz < minDist * minDist then
                return false
            end
        end
        return true
    end

    for _, cand in lipCandidates do
        if farFromAnchors(cand, params.lipSpacing) then
            table.insert(anchors, cand)
        end
    end
    for _, cand in quietCandidates do
        if farFromAnchors(cand, params.quietSpacing) then
            table.insert(anchors, cand)
        end
    end

    -- cluster growth: one continuous roll stream, anchors in acceptance order
    local state = (params.seed * 2654435761) % 2147483648 + 1
    local function roll(): number
        local r
        state, r = lcg(state)
        return r
    end

    local out: { RockPlacement } = {}
    local function farFromOutput(x: number, z: number, minDist: number): boolean
        for _, p in out do
            local dx, dz = x - p.x, z - p.z
            if dx * dx + dz * dz < minDist * minDist then
                return false
            end
        end
        return true
    end

    for _, a in anchors do
        local anchorYaw = roll() * 2 * math.pi
        local anchorScale = params.scaleMin + roll() * (params.scaleMax - params.scaleMin)
        table.insert(out, {
            x = a.x,
            z = a.z,
            role = "anchor",
            yaw = anchorYaw,
            scale = anchorScale,
            lip = a.lip,
        })

        local attendantCount = params.attendantsMin
            + math.floor(roll() * (params.attendantsMax - params.attendantsMin + 1))
        for _ = 1, attendantCount do
            local placed = false
            for _try = 1, 4 do
                if placed then
                    break
                end
                local ang = roll() * 2 * math.pi
                local radius = params.memberRadiusMin
                    + roll() * (params.memberRadiusMax - params.memberRadiusMin)
                local yaw = roll() * 2 * math.pi
                local scale = params.scaleMin + roll() * (params.scaleMax - params.scaleMin)
                local x = a.x + math.cos(ang) * radius
                local z = a.z + math.sin(ang) * radius
                if
                    (keepOut == nil or not keepOut(x, z))
                    and withinBand(edgeIndex, params.cell, x, z, params.cell * 1.5)
                    and farFromOutput(x, z, params.memberSpacing)
                then
                    table.insert(out, {
                        x = x,
                        z = z,
                        role = "attendant",
                        yaw = yaw,
                        scale = scale,
                        lip = a.lip,
                    })
                    placed = true
                end
            end
        end

        local waderCount = math.floor(roll() * (params.wadersMax + 1))
        for _ = 1, waderCount do
            local stepRoll = roll()
            local jitterRoll = roll()
            local yaw = roll() * 2 * math.pi
            local scaleRoll = roll()
            -- the step FLOOR is memberSpacing: a shorter step lands the wader inside
            -- its own anchor's spacing bubble and farFromOutput rejects it every time
            -- (the original 0-based roll silently zeroed waders out of whole plans)
            local step = params.memberSpacing
                + stepRoll * math.max(params.waderReach - params.memberSpacing, 0)
            local jitter = (jitterRoll * 2 - 1) * 2
            -- water-inward direction is the opposite of the land direction;
            -- both are axis-aligned unit vectors, so the perpendicular is too
            local dx, dz = -a.landDx, -a.landDz
            local px, pz = -dz, dx
            local x = a.x + dx * step + px * jitter
            local z = a.z + dz * step + pz * jitter
            local scale = (params.scaleMin + scaleRoll * (params.scaleMax - params.scaleMin)) * 0.6
            if (keepOut == nil or not keepOut(x, z)) and farFromOutput(x, z, params.memberSpacing) then
                table.insert(out, {
                    x = x,
                    z = z,
                    role = "wader",
                    yaw = yaw,
                    scale = scale,
                    lip = a.lip,
                })
            end
        end
    end

    return out
end

-- ── params (brief defaults; seed follows the project's dated-seed convention) ────────
local PARAMS: Params = {
    seed = 20260731,
    cell = 4,
    sheetTol = 3,
    lipRadius = 10,
    lipMinDrop = 1.5,
    lipSpacing = 35,
    quietSpacing = 55,
    memberRadiusMin = 3,
    memberRadiusMax = 8,
    memberSpacing = 2.5,
    attendantsMin = 2,
    attendantsMax = 4,
    wadersMax = 2,
    -- 6, not the planner-test 4: the step floor is memberSpacing (2.5), so reach 4
    -- left waders barely off the bank — 6 puts them visibly out in the water
    waderReach = 6,
    scaleMin = 0.85,
    scaleMax = 1.25,
}

local BAKE_SEED_OFFSET = 800000 -- keeps the bake-time rock-within-tier stream distinct
local GROUND_TOL = 6 -- refuse a placement whose ground strays this far from its water y
local SINK_FRACTION = { anchor = 0.25, attendant = 0.25, wader = 0.15 }

-- role -> RockLibrary footprint tier (max of X/Z size, unscaled)
local TIERS = {
    anchor = { min = 8, max = 15 },
    attendant = { min = 3, max = 8 },
    wader = { min = 2, max = 5 },
}

-- ── keep-outs ────────────────────────────────────────────────────────────────────────
-- karesansui mirror (CanyonKeepOuts) + the COMPOSED falls-pool site (dock + hero iris)
local KEEPOUT_RECTS = {
    { name = "Karesansui", x0 = -25, x1 = 38, z0 = -16, z1 = 22 },
    { name = "FallsPoolComposed", x0 = -385, x1 = -325, z0 = -35, z1 = 25 },
}

local function keepOutParts(): { BasePart }
    local parts: { BasePart } = {}
    local sandbox = workspace:FindFirstChild("Sandbox")
    local fz = sandbox and sandbox:FindFirstChild("FoliageZones")
    if fz then
        for _, p in fz:GetChildren() do
            if p:IsA("BasePart") and p:GetAttribute("Recipe") == "KeepOut" then
                table.insert(parts, p)
            end
        end
    end
    return parts
end

local function makeKeepOut(): (number, number) -> boolean
    local parts = keepOutParts()
    return function(x: number, z: number): boolean
        for _, r in KEEPOUT_RECTS do
            if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
                return true
            end
        end
        for _, p in parts do
            -- object-space test so rotated pads mask correctly; Y ignored
            local lp = p.CFrame:PointToObjectSpace(Vector3.new(x, p.Position.Y, z))
            if math.abs(lp.X) <= p.Size.X / 2 and math.abs(lp.Z) <= p.Size.Z / 2 then
                return true
            end
        end
        return false
    end
end

-- ── collectors ───────────────────────────────────────────────────────────────────────
local function collectWaterCells(): { WaterCell }
    local cells: { WaterCell } = {}
    local sandbox = workspace:FindFirstChild("Sandbox")
    local map = sandbox and sandbox:FindFirstChild("WaterMap")
    local markers = map and map:FindFirstChild("WaterMarkers")
    if not markers then
        warn("[shoreRocks] no Sandbox.WaterMap.WaterMarkers — nothing to plan")
        return cells
    end
    for _, m in markers:GetChildren() do
        if m:IsA("BasePart") then
            table.insert(cells, { x = m.Position.X, y = m.Position.Y, z = m.Position.Z })
        end
    end
    -- GetChildren order is not stable across sessions; sort so the plan is too
    table.sort(cells, function(a, b)
        if a.x ~= b.x then
            return a.x < b.x
        end
        if a.z ~= b.z then
            return a.z < b.z
        end
        return a.y < b.y
    end)
    return cells
end

-- every already-placed rock: Stone_ trail stones + each child BasePart of any
-- rock-named Model (the W##_*_Rocks falls/run groups, Reach/Channel rocks) — the
-- INDIVIDUAL parts, never a container bbox (a container spans a whole falls run)
local function collectExistingRocks(): { { x: number, z: number } }
    local rocks: { { x: number, z: number } } = {}
    local cw = workspace:FindFirstChild("CanyonWorld")
    if not cw then
        return rocks
    end
    for _, d in cw:GetDescendants() do
        if d:IsA("BasePart") then
            local isStone = d.Name:match("^Stone_") ~= nil
            local parent = d.Parent
            local inRockModel = parent ~= nil
                and parent:IsA("Model")
                and parent.Name:lower():find("rock") ~= nil
            if isStone or inRockModel then
                table.insert(rocks, { x = d.Position.X, z = d.Position.Z })
            end
        end
    end
    return rocks
end

-- ── rock tiers (RockLibrary + the Moss Kit trail stones) ─────────────────────────────
-- dress=true marks raw RockLibrary imports (Plastic + store TextureID -> ZenCanyonRock
-- recipe at clone time); the TrailStoneLibrary Moss Kit stones carry their own
-- SurfaceAppearance PBR and must keep it. Kit stones are inserted TWICE so five of
-- them still earn a real share of the small-tier picks against 49 library rocks.
type TierEntry = { mesh: MeshPart, dress: boolean }

local function tiersFromLibrary(): { [string]: { TierEntry } }
    local tiers: { [string]: { TierEntry } } = { anchor = {}, attendant = {}, wader = {} }
    local sorted: { TierEntry } = {}
    local sources = {
        { name = "RockLibrary", dress = true, copies = 1 },
        { name = "TrailStoneLibrary", dress = false, copies = 2 },
    }
    for _, src in sources do
        local lib = ServerStorage:FindFirstChild(src.name)
        if not lib then
            warn(`[shoreRocks] no ServerStorage.{src.name}`)
            continue
        end
        for _, m in lib:GetChildren() do
            if m:IsA("MeshPart") then
                for _ = 1, src.copies do
                    table.insert(sorted, { mesh = m, dress = src.dress })
                end
            end
        end
    end
    table.sort(sorted, function(a, b)
        return a.mesh.Name < b.mesh.Name
    end)
    for _, e in sorted do
        local long = math.max(e.mesh.Size.X, e.mesh.Size.Z)
        for role, band in TIERS do
            if long >= band.min and long <= band.max then
                table.insert(tiers[role], e)
            end
        end
    end
    return tiers
end

-- ── folder + flags ───────────────────────────────────────────────────────────────────
local function rockFolder(): Folder
    local cw = workspace:FindFirstChild("CanyonWorld") :: Instance
    local foliage = cw:FindFirstChild("Foliage")
    if not foliage then
        foliage = Instance.new("Folder")
        foliage.Name = "Foliage"
        foliage.Parent = cw
    end
    local folder = (foliage :: Instance):FindFirstChild("ShoreRocks")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "ShoreRocks"
        folder.Parent = foliage
    end
    return folder :: Folder
end

local function wipeRockFolder()
    local cw = workspace:FindFirstChild("CanyonWorld")
    local foliage = cw and cw:FindFirstChild("Foliage")
    local existing = foliage and foliage:FindFirstChild("ShoreRocks")
    if existing then
        existing:Destroy()
    end
end

-- real solid rocks, per the existing W## falls-rock convention: collidable, shadowed.
-- dress=true (RockLibrary raw imports): clear the store's baked TextureID and apply
-- the canonical river-rock look — the base-Rock ZenCanyonRock MaterialVariant
-- (ColorMap rbxassetid://132831870698274; its Basalt-based namesake was retired
-- 2026-07-31 as ZenCanyonRock_RETIRED, 0 users). dress=false (Moss Kit trail
-- stones): they carry their own SurfaceAppearance PBR — leave the look alone.
local function flagRockClone(part: BasePart, dress: boolean)
    part.Anchored = true
    part.CanCollide = true
    part.CastShadow = true
    part.CanQuery = true
    part.CanTouch = false
    if dress then
        part.Material = Enum.Material.Rock
        part.MaterialVariant = "ZenCanyonRock"
    end
    if part:IsA("MeshPart") then
        part.RenderFidelity = Enum.RenderFidelity.Automatic
        if dress then
            part.TextureID = ""
        end
    end
end

-- ── bake ─────────────────────────────────────────────────────────────────────────────
local function bake(
    placements: { RockPlacement },
    cells: { WaterCell },
    params: Params
): (number, number, { [string]: number })
    local terrain = workspace.Terrain
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { terrain }
    rp.IgnoreWater = true -- waders measure the BED, not the surface
    local folder = rockFolder()
    local tiers = tiersFromLibrary()
    local waterIndex = buildIndex(cells, params.cell)

    -- water y nearest to (x, z) within ~2 cells, or nil if none (shouldn't happen for
    -- planner output, which stays within the edge band)
    local function nearbyWaterY(x: number, z: number): number?
        local cx = math.floor(x / params.cell + 0.5)
        local cz = math.floor(z / params.cell + 0.5)
        local bestDist, bestY = math.huge, nil :: number?
        for gx = cx - 2, cx + 2 do
            for gz = cz - 2, cz + 2 do
                local bucket = waterIndex[key(gx, gz)]
                if bucket ~= nil then
                    for _, c in bucket do
                        local dx, dz = x - c.x, z - c.z
                        local d = dx * dx + dz * dz
                        if d < bestDist then
                            bestDist, bestY = d, c.y
                        end
                    end
                end
            end
        end
        return bestY
    end

    local state = ((params.seed + BAKE_SEED_OFFSET) * 2654435761) % 2147483648 + 1
    local placed = 0
    local refused = 0
    local perRole: { [string]: number } = {}

    for i, p in placements do
        local pool = tiers[p.role]
        if pool == nil or #pool == 0 then
            refused += 1
            continue
        end
        local r
        state, r = lcg(state)
        local entry = pool[math.floor(r * #pool) + 1]
        local template = entry.mesh

        local hit = workspace:Raycast(Vector3.new(p.x, 400, p.z), Vector3.new(0, -900, 0), rp)
        if not hit then
            refused += 1
            continue
        end
        -- drifted onto a shelf/cliff above (or a hole below) the pool it belongs to
        local waterY = nearbyWaterY(p.x, p.z)
        if waterY ~= nil and math.abs(hit.Position.Y - waterY) > GROUND_TOL then
            refused += 1
            continue
        end

        local clone = template:Clone()
        clone.Name = `Stone_Shore_{i}`
        if p.scale ~= 1 then
            clone.Size = template.Size * p.scale
        end
        local sink = clone.Size.Y * (SINK_FRACTION[p.role] or 0.25)
        clone.CFrame = CFrame.new(p.x, hit.Position.Y - sink + clone.Size.Y / 2, p.z)
            * CFrame.Angles(0, p.yaw, 0)
        flagRockClone(clone, entry.dress)
        clone.Parent = folder
        placed += 1
        perRole[p.role] = (perRole[p.role] or 0) + 1
    end

    return placed, refused, perRole
end

-- ── Studio shell ─────────────────────────────────────────────────────────────────────
-- Load ONCE into ServerStorage.ShoreRocksTool (ModuleScript), then:
--   local run = require(game.ServerStorage.ShoreRocksTool)
--   return run({ mode = "plan" })
--   return run({ mode = "bake" })
--   return run({ mode = "plan", overrides = { lipSpacing = 25 } })  -- gate tuning
return function(opts: { mode: string?, overrides: { [string]: number }? }?): string
    local mode = (opts and opts.mode) or MODE
    local params = table.clone(PARAMS)
    if opts and opts.overrides then
        for k, v in opts.overrides do
            if (PARAMS :: { [string]: number })[k] == nil then
                return `[shoreRocks] unknown override "{k}" — check the Params fields`
            end
            (params :: { [string]: number })[k] = v
        end
    end

    if mode == "wipe" then
        wipeRockFolder()
        return "[shoreRocks] wiped CanyonWorld.Foliage.ShoreRocks"
    end

    local cells = collectWaterCells()
    local existing = collectExistingRocks()
    local keepOut = makeKeepOut()
    local placements = plan(cells, params, keepOut, existing)

    local anchors = 0
    local lipAnchors = 0
    local perRole: { [string]: number } = {}
    for _, p in placements do
        perRole[p.role] = (perRole[p.role] or 0) + 1
        if p.role == "anchor" then
            anchors += 1
            if p.lip then
                lipAnchors += 1
            end
        end
    end
    local summary = `[shoreRocks] {mode}: cells={#cells} existingRocks={#existing} `
        .. `clusters={anchors} (lip={lipAnchors} quiet={anchors - lipAnchors}) `
        .. `placements={#placements} (anchor={perRole.anchor or 0} `
        .. `attendant={perRole.attendant or 0} wader={perRole.wader or 0})`
    print(summary)

    if mode == "bake" then
        wipeRockFolder()
        local placed, refused, baked = bake(placements, cells, params)
        local lines = {
            `stamped {placed} rocks into CanyonWorld.Foliage.ShoreRocks `
                .. `(anchor={baked.anchor or 0} attendant={baked.attendant or 0} wader={baked.wader or 0})`,
        }
        if refused > 0 then
            table.insert(lines, `refused {refused} (no ground hit or empty tier)`)
        end
        return summary .. "\n" .. table.concat(lines, "\n")
    end

    return summary .. "\nplan only -- nothing stamped"
end
