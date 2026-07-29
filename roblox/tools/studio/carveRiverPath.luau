-- MCP/Edit: rough-carve a walkable grade along one river-path chapter's centerline,
-- backing the region up first. The user finish-smooths afterwards (recipe section 0.4c).
--
-- ⚠️ READ THE PROBE BEFORE TRUSTING THE CARVE. The probe reports what each sample
-- lands on, and names any PART it hits. A line that passes through built geometry is a
-- ROUTING error, not something to carve around: on 2026-07-29 the first chapter's line
-- ran through the karesansui field and under the Shoro roof, and the probe naming
-- RoofPanel2 / FieldMain is what caught it. Terrain height alone will not tell you --
-- the Square is flat ground precisely because something is standing on it.
--
-- Recipe section 5: fill boxes must be >= 4 studs in EVERY dimension or the voxel
-- resolution carves nothing at all. Note also that FillBlock(Air) only cuts UPWARD from
-- the line, so where the line already sits at or above grade the carve is a no-op and
-- the path will float instead -- that is a job for the retaining walls, not the carve.
--
-- Terrain:CopyRegion takes a Region3int16 in VOXEL coordinates (1 unit = 4 studs), not
-- a Region3. The corner is stored as attributes so PasteRegion can restore it.
--
-- Control points MIRROR tools/builders/RiverPathChapters.luau -- keep in sync.
-- Set CONFIG to the chapter you are carving and run. The backup guard refuses a second
-- run against the same chapter; delete ServerStorage.RiverCarve_<name>_Backup to re-carve.
local CONFIG = {
    name = "RiverFirstRiser",
    control = {
        { -56.3, 116.8, 16.6 },
        { -83.8, 139.9, 11.8 },
    },
    width = 10, -- carve wider than the 5.8 bed so the shoulders are workable
    depth = 5,
    spacing = 4,
    probeOnly = true, -- run the probe and STOP; flip to false once the line is cleared
}

local Terrain = workspace.Terrain
local SS = game:GetService("ServerStorage")

local backupName = ("RiverCarve_%s_Backup"):format(CONFIG.name)
if SS:FindFirstChild(backupName) then
    return ("backup %s already exists -- carve already run; delete it to re-carve"):format(backupName)
end

-- probe the line against everything, naming any Part it meets
local probe = {}
local parts = {}
for i = 2, #CONFIG.control do
    local a, b = CONFIG.control[i - 1], CONFIG.control[i]
    for s = 0, 8 do
        local t = s / 8
        local p = Vector3.new(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
        local hit = workspace:Raycast(Vector3.new(p.X, p.Y + 80, p.Z), Vector3.new(0, -300, 0))
        if hit then
            local what
            if hit.Instance == Terrain then
                what = hit.Material.Name
            else
                what = "PART: " .. hit.Instance:GetFullName()
                parts[hit.Instance:GetFullName()] = true
            end
            table.insert(
                probe,
                ("    x %7.1f  line %6.1f  hit %6.1f  %+6.1f  %s"):format(
                    p.X,
                    p.Y,
                    hit.Position.Y,
                    p.Y - hit.Position.Y,
                    what
                )
            )
        end
    end
end

local partList = {}
for name in parts do
    table.insert(partList, name)
end

if #partList > 0 then
    table.sort(partList)
    return ("%s: *** LINE CROSSES BUILT GEOMETRY -- NOT CARVING ***\n%s\n\nprobe:\n%s"):format(
        CONFIG.name,
        "  " .. table.concat(partList, "\n  "),
        table.concat(probe, "\n")
    )
end

if CONFIG.probeOnly then
    return ("%s: probe only, no parts in the way. Set probeOnly = false to carve.\n%s"):format(
        CONFIG.name,
        table.concat(probe, "\n")
    )
end

local minv, maxv = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
for _, p in ipairs(CONFIG.control) do
    local v = Vector3.new(p[1], p[2], p[3])
    minv = Vector3.new(math.min(minv.X, v.X), math.min(minv.Y, v.Y), math.min(minv.Z, v.Z))
    maxv = Vector3.new(math.max(maxv.X, v.X), math.max(maxv.Y, v.Y), math.max(maxv.Z, v.Z))
end
local pad = Vector3.new(CONFIG.width + 8, CONFIG.depth + 24, CONFIG.width + 8)
local lo, hi = minv - pad, maxv + pad
local corner = Vector3int16.new(math.floor(lo.X / 4), math.floor(lo.Y / 4), math.floor(lo.Z / 4))
local far = Vector3int16.new(math.ceil(hi.X / 4), math.ceil(hi.Y / 4), math.ceil(hi.Z / 4))

local backup = Terrain:CopyRegion(Region3int16.new(corner, far))
backup.Name = backupName
backup:SetAttribute("CornerX", corner.X)
backup:SetAttribute("CornerY", corner.Y)
backup:SetAttribute("CornerZ", corner.Z)
backup.Parent = SS

local carved = 0
for i = 2, #CONFIG.control do
    local a, b = CONFIG.control[i - 1], CONFIG.control[i]
    local d = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
    local n = math.max(1, math.floor(d / CONFIG.spacing))
    for s = 0, n do
        local t = s / n
        local p = Vector3.new(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
        Terrain:FillBlock(
            CFrame.new(p + Vector3.new(0, CONFIG.depth / 2, 0)),
            Vector3.new(CONFIG.width, CONFIG.depth, CONFIG.width),
            Enum.Material.Air
        )
        carved += 1
    end
end

return ("%s: backup ServerStorage.%s (corner %d,%d,%d), carved %d blocks\n%s"):format(
    CONFIG.name,
    backupName,
    corner.X,
    corner.Y,
    corner.Z,
    carved,
    table.concat(probe, "\n")
)
