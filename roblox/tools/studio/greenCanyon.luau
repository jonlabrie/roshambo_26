-- ZenDojo CANYON GREENING: run via MCP execute_luau in EDIT mode.
-- The downcanyon gorge is HAND-CARVED bare grey Rock/Basalt; this pass dresses it
-- toward the mossy-gorge reference: a moss SKIN over exposed rock faces (thick up high,
-- thinning to bare wet rock near the waterline) + scattered CLINGING FOLIAGE, densest
-- by the overlook decks and thinning into the far mist.
--
-- REUSABLE canyon-wide: the moss material (LeafyGrass recoloured) + the scatter logic
-- apply upriver later by widening REGION. The downcanyon view is the first caller.
--
-- IDEMPOTENT: the moss skin only repaints Rock/Basalt (already-mossed LeafyGrass is
-- skipped), so re-runs don't creep; the foliage folder is destroyed + rebuilt each run.
-- The terrain SNAPSHOT is taken once (guarded) so a re-run never captures mossed terrain.
-- ROLLBACK: Terrain:PasteRegion(ServerStorage.GreenCanyonBackup, corner, TRUE) — the
-- `true` (pasteEmptyCells) is REQUIRED or added voxels won't clear.
--
-- World frame: clearing origin; East = +X = downstream; North = −Z.
local Terrain = workspace.Terrain
local ServerStorage = game:GetService("ServerStorage")
local RES = 4
local AIR, WATER, ROCK, BASALT, MOSS =
    Enum.Material.Air, Enum.Material.Water, Enum.Material.Rock, Enum.Material.Basalt, Enum.Material.LeafyGrass

-- ===== tunables =====
local MOSS_COLOR = Color3.fromRGB(54, 74, 41) -- deep moss (default LeafyGrass is 106,134,64)
local MOSS_TOP, MOSS_SIDE = 0.92, 0.78 -- moss coverage on up-facing vs side-facing rock
local FOLIAGE_DENSITY = 0.026 -- expected scatter points per square stud (real meshes are bigger)
local FOLIAGE_SEED = 6018

-- work region — full gorge walls (floor → rim), the northward swerve, and the far
-- mist end. West edge stops at the clearing's east cliff (x80) so the clearing interior
-- is untouched. Widen further to green upriver.
local REGION_MIN = Vector3.new(80, 8, -95)
local REGION_MAX = Vector3.new(250, 130, 45)

local region = Region3.new(REGION_MIN, REGION_MAX):ExpandToGrid(RES)
local size = region.Size
local nx, ny, nz = math.floor(size.X / RES), math.floor(size.Y / RES), math.floor(size.Z / RES)
local base = region.CFrame.Position - size / 2

-- ===== snapshot (guarded: only once, before any moss write) =====
local backup = ServerStorage:FindFirstChild("GreenCanyonBackup")
if not backup then
    local cx, cy, cz = base.X / RES, base.Y / RES, base.Z / RES
    local r16 = Region3int16.new(Vector3int16.new(cx, cy, cz), Vector3int16.new(cx + nx, cy + ny, cz + nz))
    backup = Terrain:CopyRegion(r16)
    backup.Name = "GreenCanyonBackup"
    backup:SetAttribute("cornerX", cx)
    backup:SetAttribute("cornerY", cy)
    backup:SetAttribute("cornerZ", cz)
    backup.Parent = ServerStorage
end

-- ===== moss material colour (global for LeafyGrass; unused elsewhere in the canyon) =====
Terrain:SetMaterialColor(MOSS, MOSS_COLOR)

-- ===== moss skin pass: repaint exposed Rock/Basalt faces toward moss =====
local mats, occ = Terrain:ReadVoxels(region, RES)

-- treat out-of-bounds and unoccupied cells as Air
local function mat(ix, iy, iz)
    if ix < 1 or ix > nx or iy < 1 or iy > ny or iz < 1 or iz > nz then
        return AIR
    end
    if occ[ix][iy][iz] <= 0.5 then
        return AIR
    end
    return mats[ix][iy][iz]
end
local function isAir(ix, iy, iz)
    return mat(ix, iy, iz) == AIR
end
-- keep bare wet rock within 1 voxel of water, plus 2 voxels straight down (splash zone)
local function nearWater(ix, iy, iz)
    for dx = -1, 1 do
        for dy = -2, 1 do
            for dz = -1, 1 do
                if mat(ix + dx, iy + dy, iz + dz) == WATER then
                    return true
                end
            end
        end
    end
    return false
end
-- deterministic patch hash (no math.random under Studio either, for reproducibility)
local function hash(a, b, c)
    local v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
    return v - math.floor(v)
end

-- Moss every EXPOSED rock face (any air neighbour), heavier on up-facing surfaces;
-- skip faces by the waterline so wet rock streaks read through. No floor-height gate —
-- the wall skin IS the surface voxels, found purely by air adjacency.
local painted = 0
for ix = 1, nx do
    for iz = 1, nz do
        for iy = 1, ny do
            local m = mats[ix][iy][iz]
            if (m == ROCK or m == BASALT) and occ[ix][iy][iz] > 0.5 then
                local top = isAir(ix, iy + 1, iz)
                local side = isAir(ix + 1, iy, iz)
                    or isAir(ix - 1, iy, iz)
                    or isAir(ix, iy, iz + 1)
                    or isAir(ix, iy, iz - 1)
                if (top or side) and not nearWater(ix, iy, iz) then
                    local p = top and MOSS_TOP or MOSS_SIDE
                    if hash(ix, iy, iz) < p then
                        mats[ix][iy][iz] = MOSS
                        painted += 1
                    end
                end
            end
        end
    end
end
Terrain:WriteVoxels(region, RES, mats, occ)

-- ===== foliage scatter (raycast-snapped, densest near the decks) =====
local stage = workspace.RoshamboStage
local old = stage:FindFirstChild("DowncanyonFoliage")
if old then
    old:Destroy()
end
local fol = Instance.new("Folder")
fol.Name = "DowncanyonFoliage"
fol.Parent = stage

-- ===== foliage scatter: clone curated REAL meshes from ServerStorage.FoliageKit =====
local kit = ServerStorage:FindFirstChild("FoliageKit")
assert(kit, "ServerStorage.FoliageKit missing — build the template library first")

-- surface-routed species: {templateName, weight, minScale, maxScale}
-- GREEN ONLY — the flowering "Plant" (pink) and "GrassPlants" (red) are intentionally
-- excluded to keep the gorge mossy green.
local GROUND = {
    { "Bush", 6, 0.7, 1.2 },
    { "Bush1", 6, 0.7, 1.2 },
    { "Bush2", 5, 0.7, 1.1 },
    { "Large Bush 5", 4, 0.7, 1.2 },
    { "Grass", 9, 0.8, 1.5 },
    { "Tall Grass Union", 8, 0.8, 1.6 },
    { "Short Unioned Grass", 7, 0.8, 1.4 },
    { "MeshPart Fern", 8, 0.9, 1.7 },
    { "Fern", 5, 0.9, 1.6 },
    { "Tree 2", 2, 0.6, 1.0 },
    { "Tree 4", 2, 0.6, 1.0 },
    { "Tree", 1, 0.6, 0.95 },
    { "MediumSpruce", 1, 0.45, 0.7 },
    { "ShortSpruce", 1, 0.45, 0.7 },
    { "Mid Rock 3", 2, 0.7, 1.4 },
    { "Mid Rock 4", 2, 0.7, 1.4 },
    { "Small Rock 5", 2, 0.7, 1.3 },
    { "Small Rock 6", 2, 0.7, 1.3 },
    { "Militia Rock 1", 1, 0.7, 1.3 },
}
local WALL = {
    { "MeshPart Fern", 8, 0.8, 1.5 },
    { "Fern", 5, 0.8, 1.4 },
}
local function wsum(t)
    local s = 0
    for _, e in t do
        s += e[2]
    end
    return s
end
local GW, WW = wsum(GROUND), wsum(WALL)
local function pickWeighted(t, total, r)
    local x = r * total
    for _, e in t do
        x -= e[2]
        if x <= 0 then
            return e
        end
    end
    return t[#t]
end

-- a CFrame whose up axis is the given vector (plant grows out of ground/wall)
local function frameAlong(pos, up)
    local ref = math.abs(up.Z) < 0.9 and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
    local right = up:Cross(ref)
    if right.Magnitude < 1e-3 then
        right = up:Cross(Vector3.new(1, 0, 0))
    end
    right = right.Unit
    local fwd = right:Cross(up).Unit
    return CFrame.fromMatrix(pos, right, up, -fwd)
end

local rcParams = RaycastParams.new()
rcParams.FilterType = Enum.RaycastFilterType.Include
rcParams.FilterDescendantsInstances = { Terrain }

-- deterministic LCG scatter (mirrors tools/builders/FoliageScatter.luau)
local function lcg(state)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end
local cell = 1 / math.sqrt(math.max(FOLIAGE_DENSITY, 1e-6))
local state = (FOLIAGE_SEED * 2654435761) % 2147483648 + 1
local planted, skipped = 0, 0
local fx = REGION_MIN.X
while fx < REGION_MAX.X do
    local fz = REGION_MIN.Z
    while fz < REGION_MAX.Z do
        local jx, jz
        state, jx = lcg(state)
        state, jz = lcg(state)
        local px = math.clamp(fx + jx * cell, REGION_MIN.X, REGION_MAX.X)
        local pz = math.clamp(fz + jz * cell, REGION_MIN.Z, REGION_MAX.Z)
        fz = fz + cell

        -- density gradient: thick by the decks (west), thinning into the far mist (east)
        local keepP = math.clamp(1.15 - (px - REGION_MIN.X) / 150, 0.16, 1)
        local r1
        state, r1 = lcg(state)
        if r1 > keepP then
            skipped += 1
            continue
        end

        local hit = workspace:Raycast(Vector3.new(px, 230, pz), Vector3.new(0, -320, 0), rcParams)
        if not hit or hit.Material == WATER or hit.Material == AIR then
            skipped += 1
            continue
        end
        local n = hit.Normal
        local ground = n.Y >= 0.5
        local r2, r3, r4
        state, r2 = lcg(state)
        state, r3 = lcg(state)
        state, r4 = lcg(state)

        local tbl = ground and GROUND or WALL
        local e = pickWeighted(tbl, ground and GW or WW, r2)
        local tmpl = kit:FindFirstChild(e[1])
        if not tmpl then
            skipped += 1
            continue
        end
        local s = e[3] + r3 * (e[4] - e[3])
        local clone = tmpl:Clone()
        clone:ScaleTo(s)
        local baseOff = (tmpl:GetAttribute("BaseOffset") or 0) * s
        local up = ground and Vector3.yAxis or n
        local orient = frameAlong(hit.Position, up) * CFrame.Angles(0, r4 * math.pi * 2, 0)
        clone:PivotTo(orient * CFrame.new(0, baseOff, 0))
        clone.Parent = fol
        planted += 1
    end
    fx = fx + cell
end

return ("greened: moss voxels %d; foliage planted %d (skipped %d); backup=%s"):format(
    painted,
    planted,
    skipped,
    backup and "yes" or "no"
)
