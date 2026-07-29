-- ZenDojo DOWNCANYON water + VFX: run via MCP execute_luau in EDIT mode.
-- The downcanyon GORGE itself is HAND-CARVED by the user (not scripted) — this script
-- only dresses the existing groove with WATER: a chain of stepped pools, a rock SILL
-- damming each pool's downstream edge, and the cascade + mist VFX that connect them.
--
-- River path (hand-painted with sand, then hand-grooved): the clearing's east pool
-- spills a fall into the downcanyon head pool, which drops SE → runs E → turns sharply
-- North and plunges into the lower pool. Coordinates below were tuned live at the gate
-- (cascade endpoints were hand-placed in Studio).
--
-- IDEMPOTENT: water/sills are added only into AIR (never carve rock), so re-runs are
-- safe; the VFX folder is destroyed + rebuilt each run.
--
-- World frame: clearing origin; East = +X = downstream; North = −Z.
local Terrain = workspace.Terrain
local RES = 4
local AIR, WATER, BASALT = Enum.Material.Air, Enum.Material.Water, Enum.Material.Basalt

-- stepped pools along the line: {cx, cz, r, surf}
local POOLS = {
    { 105, -24, 9, 80 }, -- Bow-Tie / head pool
    { 155, 3, 12, 59 }, -- run pool
    { 186, 10, 10, 47 }, -- lip pool (top of the plunge)
    { 197, -16, 12, 19 }, -- lower pool
}
-- downstream sill on each pool's outflow edge: {cx, cz, r, surf, fdx, fdz}
local SILLS = {
    { 105, -24, 9, 80, 0.71, 0.71 },
    { 155, 3, 12, 59, 0.97, 0.22 },
    { 186, 10, 10, 47, 0.39, -0.92 },
    { 197, -16, 12, 19, 0.20, -0.98 },
}
-- cascades (hand-placed endpoints): {name, topX,topY,topZ, botX,botY,botZ, w0,w1, c0,c1}
local CASCADES = {
    { "W13_SquareFall", 73, 106, -35, 99, 86, -20, 6, 9, 2.0, -1.0 }, -- clearing east pool → head pool
    { "W14_BowtieCascade", 124, 84, -15, 148, 61, 6, 5, 8, 0.5, -1.0 }, -- head → run pool (SE)
    { "W15_RunCascade", 173, 59, 8, 184, 47, 9, 4, 6, 4.0, -2.0 }, -- run → lip pool (E)
    { "W16_PlungeCascade", 192, 47, -3, 197, 21, -14, 6, 9, 4.0, -2.0 }, -- lip → lower pool (N plunge)
}
-- mist banks at the fall bases: {name, x,y,z, size, rate}
local MISTS = {
    { "W13_SquareFallMist", 99, 88, -20, 9, 16 },
    { "BowtieMist", 150, 60, 2, 6, 9 },
    { "PlungeMist", 197, 20, -15, 12, 22 },
}

local function occFor(wy, surf)
    local d = surf - (wy - RES / 2)
    if d >= RES then
        return 1
    elseif d <= 0 then
        return 0
    else
        return d / RES
    end
end

-- ===== terrain pass: fill pools + dam sills (single read-modify-write) =====
local region = Region3.new(Vector3.new(88, 8, -42), Vector3.new(216, 92, 30)):ExpandToGrid(RES)
local size = region.Size
local nx, ny, nz = math.floor(size.X / RES), math.floor(size.Y / RES), math.floor(size.Z / RES)
local base = region.CFrame.Position - size / 2
local mats, occ = Terrain:ReadVoxels(region, RES)

local floor = {}
for ix = 1, nx do
    floor[ix] = {}
    for iz = 1, nz do
        local f = base.Y - 999
        for iy = ny, 1, -1 do
            local m = mats[ix][iy][iz]
            if m ~= AIR and m ~= WATER and occ[ix][iy][iz] > 0.5 then
                f = base.Y + (iy - 0.5) * RES
                break
            end
        end
        floor[ix][iz] = f
    end
end

for ix = 1, nx do
    local wx = base.X + (ix - 0.5) * RES
    for iz = 1, nz do
        local wz = base.Z + (iz - 0.5) * RES
        local fy = floor[ix][iz]
        -- pools: water on the groove floor up to each surface (air only)
        for _, p in POOLS do
            if math.sqrt((wx - p[1]) ^ 2 + (wz - p[2]) ^ 2) < p[3] and fy < p[4] then
                for iy = 1, ny do
                    local wy = base.Y + (iy - 0.5) * RES
                    if wy > fy and wy < p[4] and mats[ix][iy][iz] == AIR then
                        mats[ix][iy][iz] = WATER
                        occ[ix][iy][iz] = 1
                    end
                end
            end
        end
        -- sills: basalt dam across the downstream arc, capped at the pool surface (air only)
        for _, s in SILLS do
            local dx, dz = wx - s[1], wz - s[2]
            local d = math.sqrt(dx * dx + dz * dz)
            if d >= s[3] - 1 and d <= s[3] + 5 and d > 0 and (dx / d) * s[5] + (dz / d) * s[6] > 0.5 then
                for iy = 1, ny do
                    local wy = base.Y + (iy - 0.5) * RES
                    if wy > fy and wy <= s[4] and mats[ix][iy][iz] == AIR then
                        local o = occFor(wy, s[4])
                        if o > 0 then
                            mats[ix][iy][iz] = BASALT
                            occ[ix][iy][iz] = o
                        end
                    end
                end
            end
        end
    end
end
Terrain:WriteVoxels(region, RES, mats, occ)

-- ===== VFX pass: cascade beams (angled water sheets) + mist =====
local stage = workspace.RoshamboStage
local old = stage:FindFirstChild("DowncanyonVFX")
if old then
    old:Destroy()
end
-- A Model with Persistent streaming (NOT a Folder): each cascade Beam spans two parts
-- (_TOP + _BOT) ~20-30 studs apart. Under StreamingEnabled those parts stream by region
-- independently, so a beam often has only one endpoint loaded on the client and renders
-- nothing. Persistent keeps the whole VFX set replicated so the falls always draw.
local folder = Instance.new("Model")
folder.Name = "DowncanyonVFX"
folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
folder.Parent = stage
local WCOL = Color3.fromRGB(214, 230, 238)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function nodeAt(x, y, z)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(0.5, 0.5, 0.5)
    p.CFrame = CFrame.new(x, y, z)
    p.Parent = folder
    local a = Instance.new("Attachment")
    a.Parent = p
    return a
end
for _, c in CASCADES do
    local a0 = nodeAt(c[2], c[3], c[4])
    local a1 = nodeAt(c[5], c[6], c[7])
    a0.Parent.Name = c[1] .. "_TOP"
    a1.Parent.Name = c[1] .. "_BOT"
    local beam = Instance.new("Beam")
    beam.Name = c[1]
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Width0 = c[8]
    beam.Width1 = c[9]
    beam.CurveSize0 = c[10]
    beam.CurveSize1 = c[11]
    beam.FaceCamera = true
    beam.Segments = 14
    beam.Color = ColorSequence.new(WCOL)
    beam.Transparency =
        NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.5) })
    beam.LightEmission = 0.5
    beam.LightInfluence = 0
    beam.Texture = SMOKE
    beam.TextureMode = Enum.TextureMode.Stretch
    beam.TextureLength = 7
    beam.TextureSpeed = 3
    beam.Parent = a0.Parent
end
for _, m in MISTS do
    local p = Instance.new("Part")
    p.Name = m[1]
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(1, 1, 1)
    p.CFrame = CFrame.new(m[2], m[3], m[4])
    p.Parent = folder
    local a = Instance.new("Attachment")
    a.Parent = p
    local e = Instance.new("ParticleEmitter")
    e.Color = ColorSequence.new(Color3.fromRGB(225, 232, 236))
    e.Texture = SMOKE
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.4, 0.82),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Size = NumberSequence.new(m[5])
    e.Lifetime = NumberRange.new(2.5, 5)
    e.Rate = m[6]
    e.Speed = NumberRange.new(1, 3)
    e.SpreadAngle = Vector2.new(55, 55)
    e.Acceleration = Vector3.new(0, 2, 0)
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-10, 10)
    e.Parent = a
end

return ("downcanyon dressed: %d pools, %d sills, %d cascades, %d mist banks"):format(
    #POOLS,
    #SILLS,
    #CASCADES,
    #MISTS
)
