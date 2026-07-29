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
-- Terrain edits go through ReadVoxels/WriteVoxels with explicit per-voxel occupancy,
-- NOT FillBlock -- see the comment at the sculpt for why (two FillBlock attempts left
-- the tread 1-3 studs high).
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
        -- the trail STARTS on this stair's top tread; hitting it at the seam is the
        -- join working, not an obstruction
        seamAllow = { "RiverSquareStair" },
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
    RiverFallsSteps = {
        outModel = "RiverFallsSteps",
        seed = 20260730,
        seamAllow = { "RiverTraverse" },
        control = {
            { -205.0, 164.5, 34.0 },
            { -213.5, 167.4, 34.9 },
            { -218.1, 169.3, 35.1 },
            { -223.5, 172.3, 35.8 }, -- foot of the landing
            { -228.0, 173.0, 35.9 }, -- head of the landing
            { -234.0, 175.0, 36.0 },
        },
        -- Marutakaidan: half-buried log risers retaining an earth ramp. Stretched
        -- proportion (riser 0.9 vs the locked ishidan 0.6) is DELIBERATE and lives
        -- here on the preset, not in the recipe -- chunky log-and-earth steps read
        -- as mountain trailwork, not as a second formal flight (user-gated).
        -- The terrain itself stays a smooth ramp (4-stud voxels cannot hold a
        -- 0.9-stud step); the logs supply the stepping, exactly as real
        -- log-and-earth stairs do.
        -- radius 1: the default +/-6-stud window smears the 4.5-stud landing into
        -- uniform grade and the logs march straight across it -- measured 2.8-3.1
        -- gaps where the rest should be. The ground here already runs within 0.7
        -- of the line, so the tight window costs nothing.
        smoothRadius = 1,
        steps = {
            riser = 0.9,
            proud = 0.3, -- log top above the tread it retains
            logDiameter = 1.1,
            stakes = true, -- two pinning stakes on each log's downhill face
            -- world-space shift on logs+stakes only (terrain bench unmoved):
            -- 1 stud south, away from the water (user-gated 2026-07-30)
            offset = Vector3.new(0, 0, 1),
        },
    },
    RiverT07Spur = {
        -- The fork to teahouse pad T07 -- the one pad with no tunnel access. A
        -- NARROW trail (2.0 vs the main line's 3.5) from the bridge's south
        -- abutment up the platform's west flank to the rear (SW) corner, line
        -- user-dragged 2026-07-30. The first pitch measures 0.46 and takes 4
        -- grey-cypress log steps (steps.untilS); the rest is 0.12-0.26 trail.
        -- All six M-size pad posts clear this line by >= 6.2 studs (L by ~4.3),
        -- verified against SizeClasses.deckFootprint before building.
        outModel = "RiverT07Spur",
        seed = 20260801,
        width = 1.5, -- single-file (user-gated narrower twice: 2.0 -> 1.5)
        matRadius = 2.9, -- must stay above 2.83 or the ribbon drops voxels
        stoneSpacing = 12.0,
        -- as-built: stone 1 landed mid-flight between the fork logs; relocated by
        -- hand to (-291.5, 178.8, 12.6) and omitted here so a rebuild does not
        -- re-drop it in the steps (the hand-set copy is place-state, like all
        -- hand dressing)
        omitStones = { 1 },
        seamAllow = { "RiverPoolShore", "RiverCrossing" },
        -- Line v2 (user-relocated fork further EAST off the pool shore proper;
        -- the abutment start was rejected). The steep bite is a 6-stud shelf at
        -- x -287..-293 (local grade to 0.86) carrying most of the rise.
        control = {
            { -285.4, 179.5, 16.9 }, -- the fork, on the pool-shore bench edge
            { -300.1, 184.3, 17.7 },
            { -309.6, 185.5, 21.0 },
            { -312.1, 187.0, 27.9 },
            { -310.8, 188.1, 35.8 },
            { -305.0, 190.4, 42.6 }, -- the platform's rear (SW) corner
        },
        smoothRadius = 1,
        -- NO steps (user-gated): the 0.33 fork pitch walks fine at single-file
        -- width; the spur reads as a bare desire path end to end.
    },
    RiverUpperClimb = {
        -- The wild west end: bridge abutment to NW80FallsStair, re-registered
        -- stair -> trail (user-gated, chapter data in RiverPathChapters). A GAME
        -- TRAIL -- single-file, mostly Grass, the least-built thing on the route.
        -- Log steps only at its two bites (steps.ranges): the bridge-exit shelf
        -- and the final approach up to the falls stair.
        outModel = "RiverUpperClimb",
        seed = 20260802,
        width = 1.5,
        matRadius = 2.9,
        stoneSpacing = 14.0,
        seamAllow = { "RiverCrossing", "NW80FallsStair" },
        control = {
            { -297.9, 180.4, -11.6 },
            { -326.4, 188.0, -25.2 },
            { -362.0, 200.8, -40.2 },
            { -376.9, 205.8, -15.4 },
        },
        smoothRadius = 2,
        steps = {
            riser = 0.9,
            proud = 0.3,
            logDiameter = 1.0,
            stakes = true,
            -- arc windows (studs from the east end); total arc ~99
            ranges = { { 0, 11 }, { 88, 100 } },
        },
    },
    RiverPoolShore = {
        outModel = "RiverPoolShore",
        seed = 20260731,
        -- SuspensionBridge: the high fireworks bridge crosses 36 studs OVERHEAD at
        -- x -247 -- the probe's top-down raycast finds its deck before the ground,
        -- but walking beneath it is a feature of this stretch, not an obstruction.
        seamAllow = { "RiverFallsSteps", "SuspensionBridge" },
        control = {
            { -234.0, 175.0, 36.0 },
            { -246.0, 177.8, 36.0 },
            { -259.3, 179.2, 29.4 },
            { -291.7, 178.6, 10.8 },
        },
    },
}

local ACTIVE = "RiverUpperClimb"

local CONFIG = {
    outModel = PRESETS[ACTIVE].outModel,
    control = PRESETS[ACTIVE].control,
    seed = PRESETS[ACTIVE].seed,
    seamAllow = PRESETS[ACTIVE].seamAllow or {},
    steps = PRESETS[ACTIVE].steps, -- nil on plain trail chapters

    width = PRESETS[ACTIVE].width or 3.5, -- footpath (user-gated); spurs override narrower
    spacing = 2.0, -- resample step
    smoothRadius = PRESETS[ACTIVE].smoothRadius or 3, -- +/- N samples of benching window

    cutHeight = 10, -- how far above the tread to clear
    fillDepth = 5, -- how far below the tread to fill
    shoulder = 3.0, -- blend width from the tread edge back to the existing hillside
    treadMaterial = Enum.Material.Ground,
    -- The dirt ribbon is painted from its OWN radius, decoupled from the occupancy
    -- corridor. Painting only inside halfW left gaps: voxel centres sit up to
    -- half a diagonal (2.83) off the line, so any band under that drops voxels and
    -- the ribbon breaks up -- and Slate showed through at anchors where the surface
    -- rendered from a cell below the painted window. 3.2 covers every nearest
    -- voxel; the top two occupied cells of each in-band column get painted.
    matRadius = PRESETS[ACTIVE].matRadius or 3.2,

    anchorSpacing = 3.0, -- Step_<i> anchors, for the dressing builders

    stone = {
        spacing = PRESETS[ACTIVE].stoneSpacing or 9.0,
        jitter = 0.35,
        lateralFrac = 0.85,
        minScale = 0.5,
        maxScale = 1.2,
        sinkMin = 0.35,
        sinkMax = 0.65,
    },
    -- ServerStorage.TrailStoneLibrary: the Moss Kit's five Stone_?_LP meshes,
    -- normalized to 2.8 - 4.5 studs, carrying their own SurfaceAppearance
    -- (Color 114668285678660 / Normal 120822971297448 / Roughness 124428479825701).
    -- The first attempt used bare RockLibrary meshes and they read as plastic
    -- (Material=Plastic + a baked washed-out TextureID). Clones inherit the
    -- SurfaceAppearance, so the builder applies NO material overrides here.
    stoneLibrary = "TrailStoneLibrary",
    stoneModels = { "Stone_A_LP", "Stone_B_LP", "Stone_C_LP", "Stone_D_LP", "Stone_E_LP" },

    probeOnly = false,
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

-- One log per `riserHeight` of cumulative rise, plus a lead log at the foot (a flight
-- opens on timber). Levels key to the tread RETAINED BEHIND each log -- the timber is
-- the front, downhill riser of its step. Spacing follows the profile, so the natural
-- flat becomes a logless landing with no special-casing.
local function riserPositions(samples, riserHeight)
    local out = {}
    local footY = samples[1].y
    table.insert(out, { s = samples[1].s, level = footY })
    local nextLevel = footY + riserHeight
    for i = 2, #samples do
        local a, b = samples[i - 1], samples[i]
        while b.y >= nextLevel - 1e-9 do
            local span = b.y - a.y
            local t = span > 1e-9 and (nextLevel - a.y) / span or 0
            table.insert(out, {
                s = a.s + (b.s - a.s) * math.clamp(t, 0, 1),
                level = nextLevel,
            })
            nextLevel += riserHeight
        end
    end
    return out
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
            local allowed = false
            local node = hit.Instance
            while node and node ~= workspace do
                for _, name in ipairs(CONFIG.seamAllow) do
                    if node.Name == name then
                        allowed = true
                        break
                    end
                end
                if allowed then
                    break
                end
                node = node.Parent
            end
            if not allowed then
                parts[hit.Instance:GetFullName()] = true
            end
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

-- Foliage in the corridor. The centreline raycast cannot see a sapling standing a
-- stud off-centre -- on the traverse, four young sugi ended up planted in the tread
-- and had to be cleared by hand afterwards. Report-only: foliage NEAR a trail is
-- expected and wanted; foliage IN it is a per-instance user decision.
local folWarn = {}
local fol = workspace.CanyonWorld:FindFirstChild("Foliage")
if fol then
    local function nearestS(x, z)
        local best = 1e9
        for i = 2, #tread do
            local a, b = tread[i - 1], tread[i]
            local abx, abz = b.x - a.x, b.z - a.z
            local L2 = abx * abx + abz * abz
            local t = L2 > 1e-9 and math.clamp(((x - a.x) * abx + (z - a.z) * abz) / L2, 0, 1) or 0
            best = math.min(best, math.sqrt((x - a.x - abx * t) ^ 2 + (z - a.z - abz * t) ^ 2))
        end
        return best
    end
    for _, c in ipairs(fol:GetDescendants()) do
        local isInstance = (c:IsA("Model") and c:FindFirstChildWhichIsA("BasePart", true))
            or (c:IsA("MeshPart") and not (c.Parent and c.Parent:IsA("Model")))
        if isInstance then
            local pv = c:IsA("Model") and c:GetPivot().Position or c.Position
            local d = nearestS(pv.X, pv.Z)
            if d < CONFIG.width / 2 + 1 then
                table.insert(folWarn, ("    %s at (%.1f, %.1f)  d %.1f"):format(c.Name, pv.X, pv.Z, d))
            end
        end
    end
end
if #folWarn > 0 then
    report = report
        .. ("\n  FOLIAGE IN THE CORRIDOR (%d) -- clear or accept per instance:\n"):format(#folWarn)
        .. table.concat(folWarn, "\n")
end

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

-- VOXEL WRITE, NOT FillBlock. Two FillBlock attempts left the tread 1 to 3 studs HIGH:
-- overlapping horizontal boxes on a slope each put their floor at their own tread
-- height, and even pitched, two-passed boxes inherit FillBlock's sloppy partial-voxel
-- occupancy (+1.2 systematic bias, a 2-stud lip at the stair-head seam). The tunnel-bore
-- lesson applies -- the voxel grid is the reliable interface. So: ReadVoxels, sculpt the
-- columns, WriteVoxels.
--
-- Per column inside the corridor: surface = tread height at the nearest arc position.
-- In the shoulder (halfW..halfW+shoulder) the target blends smoothly back to the
-- EXISTING surface, so the bench sits in the hillside instead of on a plinth. Occupancy
-- is exact: 1 below, the fractional remainder in the surface voxel, 0 above (up to
-- cutHeight -- higher terrain such as the south bank's brow is out of scope).

local halfW = CONFIG.width / 2
local shoulder = CONFIG.shoulder

-- region: the tread's bounding box (minv/maxv from the backup pass) padded by the
-- corridor and the cut/fill depths
local padXZ = halfW + shoulder + 4
local region = Region3.new(
    Vector3.new(minv.X - padXZ, minv.Y - CONFIG.fillDepth - 8, minv.Z - padXZ),
    Vector3.new(maxv.X + padXZ, maxv.Y + CONFIG.cutHeight + 4, maxv.Z + padXZ)
):ExpandToGrid(4)

local materials, occupancies = Terrain:ReadVoxels(region, 4)
local size = materials.Size
local origin = region.CFrame.Position - region.Size / 2

-- nearest point on the tread polyline for a horizontal position; returns distance and
-- the tread height there
local function nearestTread(x, z)
    local bestD2, bestY = 1e18, nil
    for i = 2, #tread do
        local a, b = tread[i - 1], tread[i]
        local abx, abz = b.x - a.x, b.z - a.z
        local L2 = abx * abx + abz * abz
        local t = 0
        if L2 > 1e-9 then
            t = math.clamp(((x - a.x) * abx + (z - a.z) * abz) / L2, 0, 1)
        end
        local px, pz = a.x + abx * t, a.z + abz * t
        local d2 = (x - px) ^ 2 + (z - pz) ^ 2
        if d2 < bestD2 then
            bestD2 = d2
            bestY = a.y + (b.y - a.y) * t
        end
    end
    return math.sqrt(bestD2), bestY
end

-- existing surface height of a column, from its occupancy stack
local function columnSurface(cx, cz)
    for cy = size.Y, 1, -1 do
        local occ = occupancies[cx][cy][cz]
        if occ > 0 then
            return origin.Y + (cy - 1) * 4 + occ * 4
        end
    end
    return origin.Y
end

local columns = 0
for cx = 1, size.X do
    for cz = 1, size.Z do
        local wx = origin.X + (cx - 0.5) * 4
        local wz = origin.Z + (cz - 0.5) * 4
        local dist, treadY = nearestTread(wx, wz)
        local reach = math.max(halfW + shoulder, CONFIG.matRadius)
        if dist <= reach and treadY then
            -- occupancy: only inside the bench corridor
            if dist <= halfW + shoulder then
                local target
                if dist <= halfW then
                    target = treadY
                else
                    -- smoothstep back to the existing surface across the shoulder
                    local t = (dist - halfW) / shoulder
                    t = t * t * (3 - 2 * t)
                    target = treadY + (columnSurface(cx, cz) - treadY) * t
                end
                for cy = 1, size.Y do
                    local bottom = origin.Y + (cy - 1) * 4
                    -- SURFACE_K compensates smooth terrain's "puffiness": the mesher
                    -- renders the isosurface ~half a voxel ABOVE the linear
                    -- occupancy line (measured dead uniform at +1.88 across 44
                    -- anchors). Applied to the WHOLE column, not just the surface
                    -- cell, so the two cells straddling the target share the shift
                    -- and any target height stays reachable.
                    local SURFACE_K = 0.47
                    local frac = math.clamp((target - bottom) / 4 - SURFACE_K, 0, 1)
                    local above = bottom + 4 > treadY + CONFIG.cutHeight
                    local below = bottom < treadY - CONFIG.fillDepth
                    if not above and not below then
                        occupancies[cx][cy][cz] = frac
                        if frac > 0 then
                            if materials[cx][cy][cz] == Enum.Material.Air then
                                -- newly filled ground
                                materials[cx][cy][cz] = CONFIG.treadMaterial
                            end
                        else
                            materials[cx][cy][cz] = Enum.Material.Air
                        end
                    end
                end
            end
            -- the dirt ribbon: paint the top TWO occupied cells of every in-band
            -- column, AFTER the occupancy pass so the painted cells are the ones
            -- that actually render
            if dist <= CONFIG.matRadius then
                local painted = 0
                for cy = size.Y, 1, -1 do
                    if occupancies[cx][cy][cz] > 0.05 then
                        materials[cx][cy][cz] = CONFIG.treadMaterial
                        painted += 1
                        if painted >= 2 then
                            break
                        end
                    end
                end
            end
            columns += 1
        end
    end
end

Terrain:WriteVoxels(region, 4, materials, occupancies)

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

local lib = SS:FindFirstChild(CONFIG.stoneLibrary)
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
    local omitStones = {}
    for _, i in ipairs(PRESETS[ACTIVE].omitStones or {}) do
        omitStones[i] = true
    end
    local state = (CONFIG.seed % 2147483646) + 1
    local r
    for i, site in ipairs(sites) do
        if omitStones[i] then
            continue
        end
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

--------------------------------------------------------------------------------
-- Log risers, on a stepped chapter only.
--------------------------------------------------------------------------------

local logs = 0
if CONFIG.steps then
    local st = CONFIG.steps
    local risers = riserPositions(tread, st.riser)
    if st.untilS or st.ranges then
        local ranges = st.ranges or { { 0, st.untilS } }
        local kept = {}
        for _, rs in ipairs(risers) do
            for _, rg in ipairs(ranges) do
                if rs.s >= rg[1] and rs.s <= rg[2] then
                    table.insert(kept, rs)
                    break
                end
            end
        end
        risers = kept
    end
    local state = ((CONFIG.seed + 7) % 2147483646) + 1
    local r
    for i, rs in ipairs(risers) do
        local p, idx = at(tread, rs.s)
        local f = fr[math.min(#fr, math.max(1, idx))]
        state, r = lcg(state)
        local len = CONFIG.width + 0.6 + r * 0.5 -- slight overhang, jittered
        state, r = lcg(state)
        local yaw = (r * 2 - 1) * math.rad(4)
        state, r = lcg(state)
        -- weathered grey cypress, matching the dock (and the coming bridge) --
        -- user-gated away from the dark 74/52/32 path-timber family
        local tone = 0.94 + r * 0.12
        local log = Instance.new("Part")
        log.Name = ("Log_%d"):format(i)
        log.Shape = Enum.PartType.Cylinder -- cylinder axis is X = cross-trail
        log.Size = Vector3.new(len, st.logDiameter, st.logDiameter)
        log.Anchored = true
        log.CanCollide = true -- players step on the logs, like ishidan risers
        log.Material = Enum.Material.Wood
        log.MaterialVariant = "CypressWeathered"
        log.Color = Color3.fromRGB(math.floor(216 * tone), math.floor(214 * tone), math.floor(206 * tone))
        local off = st.offset or Vector3.zero
        local centre = Vector3.new(p.x, rs.level + st.proud - st.logDiameter / 2, p.z) + off
        log.CFrame = CFrame.fromMatrix(centre, Vector3.new(f.rx, 0, f.rz), Vector3.new(0, 1, 0))
            * CFrame.Angles(0, yaw, 0)
        log.Parent = model
        logs += 1

        if st.stakes then
            -- two pinning stakes against the downhill face; travel runs east->west
            -- uphill, so downhill is -forward
            for _, lat in ipairs({ -0.3, 0.3 }) do
                state, r = lcg(state)
                local sh = 1.1 + r * 0.4
                local stake = Instance.new("Part")
                stake.Name = ("Stake_%d%s"):format(i, lat < 0 and "a" or "b")
                stake.Shape = Enum.PartType.Cylinder
                stake.Size = Vector3.new(sh, 0.28, 0.28)
                stake.Anchored = true
                stake.CanCollide = false
                stake.CanQuery = false
                stake.CanTouch = false
                stake.Material = Enum.Material.Wood
                stake.MaterialVariant = "CypressWeathered"
                stake.Color = Color3.fromRGB(201, 199, 192)
                -- stake top just clears the CENTRELINE of the log it pins (user-gated
                -- down from log-top + 0.15, which read too tall)
                local stakeTop = rs.level + st.proud - st.logDiameter / 2 + 0.15
                local sp = Vector3.new(
                    p.x - f.fx * (st.logDiameter / 2 + 0.1) + f.rx * (lat * CONFIG.width),
                    stakeTop - sh / 2,
                    p.z - f.fz * (st.logDiameter / 2 + 0.1) + f.rz * (lat * CONFIG.width)
                ) + off
                -- cylinder axis X -> rotate to stand vertical
                stake.CFrame = CFrame.new(sp) * CFrame.Angles(0, 0, math.rad(90))
                stake.Parent = model
            end
        end
    end
end

model.Parent = paths

return ("%s\n  backup ServerStorage.%s (corner %d,%d,%d)\n  %d columns sculpted, %d Step_ anchors, %d logs, %d stones (%d skipped, no ground)"):format(
    report,
    backupName,
    corner.X,
    corner.Y,
    corner.Z,
    columns,
    anchors,
    logs,
    placed,
    skipped
)
