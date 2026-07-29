-- MCP/Edit: build a benched dirt TRAIL -- the register introduced for the river path's
-- Mid climb (spec section 5a). Parents under Workspace.CanyonWorld.Paths (NEVER
-- Workspace root -- the sweep convention).
--
-- A TRAIL IS NOT A PATH WITH THE STONEWORK REMOVED. buildIshidanStairs lays a bed per
-- riser and lets the terrain be whatever it is underneath. A trail has no bed: THE
-- TERRAIN IS THE WALKING SURFACE. So this script's real output is a terrain edit, and
-- the parts it makes are only two things --
--
--   Step_<i>  invisible ANCHORS carrying the downstream contract every dressing builder
--             reads (RightVector = cross-stream, top = tread surface, Size.X = width).
--             buildBambooRailing, buildChochinPole and buildTimberRetainingWall all
--             find a path by its Step_ parts; without these a trail is undressable.
--   Stone_<i> the sparse half-buried TRACE that makes the route legible. A trace, not a
--             kerb and not a bed -- they sit at irregular arc positions and do not
--             strictly alternate sides, because a strict alternation reads as a planted
--             avenue rather than as something walked into being.
--
-- Geometry MIRRORS tools/builders/TrailProfile.luau and control points MIRROR
-- tools/builders/RiverPathChapters.luau (Studio cannot require repo modules) -- keep all
-- three in sync. TrailProfile is Lune-tested; this copy is not, so fix bugs THERE first.
--
-- Recipe section 5: fill boxes must be >= 4 studs in EVERY dimension or the voxel
-- resolution (4 studs) edits nothing at all. boxLen 6 at spacing 2 means each box
-- overlaps its neighbours threefold, which is intentional -- it is what makes the bench
-- continuous instead of scalloped.
--
-- Terrain:CopyRegion takes a Region3int16 in VOXEL coordinates (1 unit = 4 studs), not a
-- Region3. The corner is stored as attributes so PasteRegion can restore it.
--
-- Set ACTIVE and run. probeOnly = true reports and changes nothing. The backup guard
-- refuses a second run; delete ServerStorage.TrailBench_<name>_Backup to rebuild.

local PRESETS = {
    RiverTraverse = {
        outModel = "RiverTraverse",
        seed = 20260729,
        control = {
            { -89.8, 139.9, 27.9 }, -- head of RiverSquareStair (built tread, not ground)
            { -106.0, 142.7, 22.0 },
            { -121.9, 145.8, 8.7 },
            { -140.0, 151.5, 12.0 },
            { -160.0, 155.9, 4.8 },
            { -174.0, 158.6, 17.0 },
            { -188.0, 161.4, 23.0 },
            { -197.0, 163.3, 30.0 },
            { -205.0, 164.5, 34.0 },
        },
    },
    RiverPoolShore = {
        outModel = "RiverPoolShore",
        seed = 20260731,
        control = {
            { -234.0, 175.0, 36.0 },
            { -246.0, 177.8, 36.0 },
            { -259.3, 179.2, 29.4 },
            { -291.7, 178.6, 10.8 },
        },
    },
}

local ACTIVE = "RiverTraverse"

local CONFIG = {
    outModel = PRESETS[ACTIVE].outModel,
    control = PRESETS[ACTIVE].control,
    seed = PRESETS[ACTIVE].seed,

    width = 7.0, -- the tread; narrower than the 8.0 Square stair, wider than the 5.8 network
    spacing = 2.0, -- resample step
    smoothRadius = 3, -- +/- 3 samples = +/- 6 studs of benching window

    cutHeight = 10, -- how far above the tread to clear
    fillDepth = 5, -- how far below the tread to fill
    boxLen = 6, -- along-trail length of each terrain box (>= 4, and overlapping)
    treadMaterial = Enum.Material.Ground,

    anchorSpacing = 3.0, -- Step_<i> anchors, for the dressing builders

    stone = {
        spacing = 9.0,
        jitter = 0.35,
        lateralFrac = 0.85,
        minScale = 0.5,
        maxScale = 1.2,
        sinkMin = 0.35,
        sinkMax = 0.65,
    },
    -- small, flat-ish entries from ServerStorage.RockLibrary (2.5 - 5.4 studs before
    -- scaling). The big slabs read as boulders, not as trail stones.
    stoneModels = { "Rock_03", "Rock_05", "Rock_08", "Rock_10", "Rock_11", "Rock_19" },

    probeOnly = true,
}

local Terrain = workspace.Terrain
local SS = game:GetService("ServerStorage")

--------------------------------------------------------------------------------
-- MIRROR of tools/builders/TrailProfile.luau -- see the header. Fix bugs there first.
--------------------------------------------------------------------------------

local function lcg(state)
    local n = (state * 16807) % 2147483647
    return n, (n - 1) / 2147483646
end

local function horizDist(a, b)
    return math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
end

-- Every control point survives, and each segment divides into whole EQUAL steps. A
-- single global arc phase chords corners off; restarting the phase per vertex without
-- rounding leaves runt steps that corrupt the index-window smoothing.
local function resample(control, spacing)
    local out = {}
    local walked = 0
    table.insert(out, { x = control[1][1], y = control[1][2], z = control[1][3], s = 0 })
    for i = 2, #control do
        local a, b = control[i - 1], control[i]
        local segLen = horizDist(a, b)
        if segLen > 1e-6 then
            local n = math.max(1, math.floor(segLen / spacing + 0.5))
            for k = 1, n - 1 do
                local t = k / n
                table.insert(out, {
                    x = a[1] + (b[1] - a[1]) * t,
                    y = a[2] + (b[2] - a[2]) * t,
                    z = a[3] + (b[3] - a[3]) * t,
                    s = walked + segLen * t,
                })
            end
            walked += segLen
            table.insert(out, { x = b[1], y = b[2], z = b[3], s = walked })
        end
    end
    return out
end

-- Symmetric SHRINKING window: at sample i the radius is min(r, i-1, n-i), so both
-- endpoints survive exactly and the trail still meets the built stair head at 139.9.
local function smooth(samples, radius)
    local n = #samples
    local out = {}
    for i = 1, n do
        local ri = math.min(math.floor(radius), i - 1, n - i)
        local sum, count = 0, 0
        for j = i - ri, i + ri do
            sum += samples[j].y
            count += 1
        end
        table.insert(out, { x = samples[i].x, y = sum / count, z = samples[i].z, s = samples[i].s })
    end
    return out
end

local function frames(samples)
    local n = #samples
    local out = {}
    for i = 1, n do
        local a = samples[math.max(1, i - 1)]
        local b = samples[math.min(n, i + 1)]
        local dx, dz = b.x - a.x, b.z - a.z
        local len = math.sqrt(dx * dx + dz * dz)
        if len < 1e-9 then
            dx, dz, len = 1, 0, 1
        end
        local fx, fz = dx / len, dz / len
        table.insert(out, { fx = fx, fz = fz, rx = -fz, rz = fx })
    end
    return out
end

local function at(samples, s)
    local n = #samples
    if s <= samples[1].s then
        return samples[1], 1
    end
    if s >= samples[n].s then
        return samples[n], n
    end
    local lo, hi = 1, n
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if samples[mid].s <= s then
            lo = mid
        else
            hi = mid
        end
    end
    local a, b = samples[lo], samples[hi]
    local span = b.s - a.s
    local t = span > 1e-9 and (s - a.s) / span or 0
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z + (b.z - a.z) * t,
        s = s,
    },
        lo
end

local function stoneSites(totalLength, opts, seed)
    local out = {}
    local state = (math.floor(seed) % 2147483646) + 1
    local r
    local s = opts.spacing * 0.5
    local side = 1
    while s < totalLength do
        state, r = lcg(state)
        local ds = (r * 2 - 1) * opts.jitter * opts.spacing
        local site = s + ds
        if site > 0 and site < totalLength then
            state, r = lcg(state)
            local lateral = side * (0.25 + 0.75 * r) * opts.lateralFrac * (CONFIG.width / 2)
            state, r = lcg(state)
            local scale = opts.minScale + (opts.maxScale - opts.minScale) * r
            state, r = lcg(state)
            local yaw = r * math.pi * 2
            state, r = lcg(state)
            local sink = opts.sinkMin + (opts.sinkMax - opts.sinkMin) * r
            table.insert(out, { s = site, lateral = lateral, scale = scale, yaw = yaw, sink = sink })
        end
        state, r = lcg(state)
        if r < 0.72 then
            side = -side
        end
        s += opts.spacing
    end
    return out
end

--------------------------------------------------------------------------------
-- Probe. A line through built geometry is a ROUTING error, not something to bench
-- around -- so refuse, and name what it hit.
--------------------------------------------------------------------------------

local raw = resample(CONFIG.control, CONFIG.spacing)
local tread = smooth(raw, CONFIG.smoothRadius)
local fr = frames(tread)
local total = tread[#tread].s

local parts, cut, fill = {}, 0, 0
local worstCut, worstFill = 0, 0
for _, p in ipairs(tread) do
    local hit = workspace:Raycast(Vector3.new(p.x, p.y + 60, p.z), Vector3.new(0, -260, 0))
    if hit then
        if hit.Instance ~= Terrain then
            parts[hit.Instance:GetFullName()] = true
        else
            local d = hit.Position.Y - p.y
            if d > 0.4 then
                cut += 1
                worstCut = math.max(worstCut, d)
            elseif d < -0.4 then
                fill += 1
                worstFill = math.max(worstFill, -d)
            end
        end
    end
end

local partList = {}
for name in parts do
    table.insert(partList, name)
end
if #partList > 0 then
    table.sort(partList)
    return ("%s: *** LINE CROSSES BUILT GEOMETRY -- NOT BENCHING ***\n  %s"):format(
        CONFIG.outModel,
        table.concat(partList, "\n  ")
    )
end

local maxGrade = 0
for i = 2, #tread do
    local run = tread[i].s - tread[i - 1].s
    if run > 1e-6 then
        maxGrade = math.max(maxGrade, math.abs((tread[i].y - tread[i - 1].y) / run))
    end
end

local report = ("%s: %d samples over %.1f studs, benched max grade %.3f\n"):format(
    CONFIG.outModel,
    #tread,
    total,
    maxGrade
) .. ("  cut at %d samples (worst %.1f studs), fill at %d samples (worst %.1f studs)"):format(
    cut,
    worstCut,
    fill,
    worstFill
)

if CONFIG.probeOnly then
    return report .. "\n  probeOnly -- nothing changed. Set probeOnly = false to build."
end

--------------------------------------------------------------------------------
-- Backup, then bench.
--------------------------------------------------------------------------------

local backupName = ("TrailBench_%s_Backup"):format(CONFIG.outModel)
if SS:FindFirstChild(backupName) then
    return ("backup %s already exists -- bench already run; delete it to rebuild"):format(backupName)
end

local minv = Vector3.new(1e9, 1e9, 1e9)
local maxv = Vector3.new(-1e9, -1e9, -1e9)
for _, p in ipairs(tread) do
    minv = Vector3.new(math.min(minv.X, p.x), math.min(minv.Y, p.y), math.min(minv.Z, p.z))
    maxv = Vector3.new(math.max(maxv.X, p.x), math.max(maxv.Y, p.y), math.max(maxv.Z, p.z))
end
local pad = Vector3.new(CONFIG.width + 12, CONFIG.cutHeight + 16, CONFIG.width + 12)
local lo, hi = minv - pad, maxv + pad
local corner = Vector3int16.new(math.floor(lo.X / 4), math.floor(lo.Y / 4), math.floor(lo.Z / 4))
local far = Vector3int16.new(math.ceil(hi.X / 4), math.ceil(hi.Y / 4), math.ceil(hi.Z / 4))

local backup = Terrain:CopyRegion(Region3int16.new(corner, far))
backup.Name = backupName
backup:SetAttribute("CornerX", corner.X)
backup:SetAttribute("CornerY", corner.Y)
backup:SetAttribute("CornerZ", corner.Z)
backup.Parent = SS

-- Cut first, then fill: the two boxes do not overlap (one sits entirely above the tread
-- plane, the other entirely below), so the order is not load-bearing -- but filling last
-- means the tread's top voxels finish as treadMaterial even where we cut into Slate.
local boxes = 0
for i, p in ipairs(tread) do
    local f = fr[i]
    local pos = Vector3.new(p.x, p.y, p.z)
    local cf = CFrame.fromMatrix(pos, Vector3.new(f.rx, 0, f.rz), Vector3.new(0, 1, 0))

    Terrain:FillBlock(
        cf + Vector3.new(0, CONFIG.cutHeight / 2, 0),
        Vector3.new(CONFIG.width, CONFIG.cutHeight, CONFIG.boxLen),
        Enum.Material.Air
    )
    Terrain:FillBlock(
        cf - Vector3.new(0, CONFIG.fillDepth / 2, 0),
        Vector3.new(CONFIG.width, CONFIG.fillDepth, CONFIG.boxLen),
        CONFIG.treadMaterial
    )
    boxes += 2
end

--------------------------------------------------------------------------------
-- Anchors and the stone trace.
--------------------------------------------------------------------------------

local paths = workspace.CanyonWorld.Paths
local old = paths:FindFirstChild(CONFIG.outModel)
if old then
    old:Destroy()
end
local model = Instance.new("Model")
model.Name = CONFIG.outModel

local anchors = 0
local nAnchor = math.max(1, math.floor(total / CONFIG.anchorSpacing))
for k = 0, nAnchor do
    local s = math.min(total, k * CONFIG.anchorSpacing)
    local p, idx = at(tread, s)
    local f = fr[math.min(#fr, math.max(1, idx))]
    local a = Instance.new("Part")
    a.Name = ("Step_%d"):format(k + 1)
    a.Anchored = true
    a.CanCollide = false
    a.CanQuery = false
    a.CanTouch = false
    a.Transparency = 1
    a.Size = Vector3.new(CONFIG.width, 0.4, CONFIG.anchorSpacing)
    -- top of the anchor sits ON the tread surface, matching the Step_ contract
    a.CFrame =
        CFrame.fromMatrix(Vector3.new(p.x, p.y - 0.2, p.z), Vector3.new(f.rx, 0, f.rz), Vector3.new(0, 1, 0))
    a.Parent = model
    anchors += 1
end

local lib = SS:FindFirstChild("RockLibrary")
local sources = {}
if lib then
    for _, name in ipairs(CONFIG.stoneModels) do
        local m = lib:FindFirstChild(name)
        if m then
            table.insert(sources, m)
        end
    end
end

local placed = 0
local skipped = 0
if #sources > 0 then
    local rpTerrain = RaycastParams.new()
    rpTerrain.FilterType = Enum.RaycastFilterType.Include
    rpTerrain.FilterDescendantsInstances = { Terrain }

    local sites = stoneSites(total, CONFIG.stone, CONFIG.seed)
    local state = (CONFIG.seed % 2147483646) + 1
    local r
    for i, site in ipairs(sites) do
        local p, idx = at(tread, site.s)
        local f = fr[math.min(#fr, math.max(1, idx))]
        local x = p.x + f.rx * site.lateral
        local z = p.z + f.rz * site.lateral
        -- seat on the BENCHED ground, not on the tread plane -- a stone at the edge of
        -- the cut sits lower than the centreline
        local hit = workspace:Raycast(Vector3.new(x, p.y + 30, z), Vector3.new(0, -70, 0), rpTerrain)
        if hit then
            state, r = lcg(state)
            local src = sources[math.floor(r * #sources) + 1]
            local stone = src:Clone()
            stone.Name = ("Stone_%d"):format(i)
            stone.Size = src.Size * site.scale
            stone.Anchored = true
            stone.CanCollide = false
            stone.CanQuery = false
            stone.CanTouch = false
            stone.RenderFidelity = Enum.RenderFidelity.Automatic
            stone.CFrame = CFrame.new(Vector3.new(x, hit.Position.Y - stone.Size.Y * site.sink, z))
                * CFrame.Angles(0, site.yaw, 0)
            stone.Parent = model
            placed += 1
        else
            skipped += 1
        end
    end
end

model.Parent = paths

return ("%s\n  backup ServerStorage.%s (corner %d,%d,%d)\n  %d terrain boxes, %d Step_ anchors, %d stones (%d skipped, no ground)"):format(
    report,
    backupName,
    corner.X,
    corner.Y,
    corner.Z,
    boxes,
    anchors,
    placed,
    skipped
)
