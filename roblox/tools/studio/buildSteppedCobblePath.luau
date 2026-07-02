--!nocheck
-- Reusable stepped-cobble path generator. Run in Studio (command bar / MCP execute_luau).
-- Routes a Catmull-Rom spline through a folder of draft markers, lays timber risers along it,
-- and builds FLAT per-tread cobbles + a flat cement-gravel bed (one published cobble mesh).
-- See docs/superpowers/references/zendojo-canyon-build-recipes.md §1.
--
-- WORKFLOW: drop a row of Marker_* balls in Workspace.PathDraft.<DRAFT>, let the user shape
-- them, then set CONFIG and run. Treads are FLAT, stepping at each timber (NOT sloped).
-- Sizing rule: timber 6.4 > bed BED_W > cobble (2*COBBLE_HW).

local CONFIG = {
    draft = "Descent", -- Workspace.PathDraft.<draft> holds Marker_0..N (sorted by index)
    outModel = "DescentPath", -- output Workspace model (timbers + bed + published cobbles)
    timberPrefix = "DescTimber",
    SPACING = 3.5, -- timber spacing along the spline arc
    COBBLE_HW = 2.6, -- cobble tread half-width (5.2 wide)
    BED_W = 5.8, -- bed width
    leadFromFirstMarker = true, -- treat marker[0] as a lead boundary (path starts at it)
}

-- ===== fixed recipe (recipe doc §1) =====
local TIMBER_COL = Color3.fromRGB(74, 52, 32)
local BED_COL = Color3.fromRGB(138, 142, 142)
local MINSEP, INSET, DOME, TIMBER_HALF = 0.55, 0.08, 0.42, 0.75

local ws = workspace
local AssetService = game:GetService("AssetService")

local function clip(poly, S, O)
    local dx, dv = S.u - O.u, S.v - O.v
    local mx, mv = (S.u + O.u) / 2, (S.v + O.v) / 2
    local function inside(p)
        return (p.u - mx) * dx + (p.v - mv) * dv >= 0
    end
    local function isect(a, b)
        local da, db = (a.u - mx) * dx + (a.v - mv) * dv, (b.u - mx) * dx + (b.v - mv) * dv
        local t = da / (da - db)
        return { u = a.u + (b.u - a.u) * t, v = a.v + (b.v - a.v) * t }
    end
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        local ina, inb = inside(a), inside(b)
        if ina then
            table.insert(out, a)
        end
        if ina ~= inb then
            table.insert(out, isect(a, b))
        end
    end
    return out
end
local function centroid(poly)
    local cu, cv = 0, 0
    for _, p in poly do
        cu, cv = cu + p.u, cv + p.v
    end
    return { u = cu / #poly, v = cv / #poly }
end

-- ===== 1. read markers, route the spline =====
local folder = ws.PathDraft:FindFirstChild(CONFIG.draft)
assert(folder, "missing Workspace.PathDraft." .. CONFIG.draft)
local pts = {}
do
    local ms = {}
    for _, c in folder:GetChildren() do
        local i = tonumber((c.Name :: string):match("Marker_(%d+)"))
        if i then
            table.insert(ms, { i = i, p = c.Position })
        end
    end
    table.sort(ms, function(a, b)
        return a.i < b.i
    end)
    for _, m in ms do
        table.insert(pts, m.p)
    end
end
assert(#pts >= 2, "need >=2 markers")

local function cr(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5
        * (
            (2 * p1)
            + (-p0 + p2) * t
            + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        )
end
local function sampleSpline(arr, perSeg)
    local out = {}
    for s = 1, #arr - 1 do
        local p0 = arr[math.max(s - 1, 1)]
        local p1, p2 = arr[s], arr[s + 1]
        local p3 = arr[math.min(s + 2, #arr)]
        local lo = s == 1 and 0 or 1
        for k = lo, perSeg do
            table.insert(out, cr(p0, p1, p2, p3, k / perSeg))
        end
    end
    return out
end

local model = ws:FindFirstChild(CONFIG.outModel)
if model then
    model:Destroy()
end
model = Instance.new("Model")
model.Name = CONFIG.outModel
model.Parent = ws

-- ===== 2. timbers along the spline (center = grade - 0.6, top = grade + 0.2) =====
-- With leadFromFirstMarker, a lead timber (index 0) is placed AT the first marker so the path
-- STARTS on a riser instead of a bare bed/cobble tread.
local spline = sampleSpline(pts, 8)
local function placeTimber(idx, at, dirH)
    local cross = Vector3.new(dirH.Z, 0, -dirH.X)
    local tb = Instance.new("Part")
    tb.Name = string.format("%s_%d", CONFIG.timberPrefix, idx)
    tb.Size = Vector3.new(6.4, 1.6, 1.2)
    tb.CFrame = CFrame.fromMatrix(Vector3.new(at.X, at.Y - 0.6, at.Z), cross, Vector3.yAxis)
    tb.Anchored = true
    tb.Material = Enum.Material.Wood
    tb.Color = TIMBER_COL
    tb.Parent = model
end
do
    if CONFIG.leadFromFirstMarker then
        local a, b = spline[1], spline[2]
        placeTimber(0, pts[1], Vector3.new((b - a).X, 0, (b - a).Z).Unit)
    end
    local acc, ti = CONFIG.SPACING, 0
    for s = 1, #spline - 1 do
        local a, b = spline[s], spline[s + 1]
        acc = acc + (b - a).Magnitude
        if acc >= CONFIG.SPACING then
            acc = 0
            ti += 1
            placeTimber(ti, b, Vector3.new((b - a).X, 0, (b - a).Z).Unit)
        end
    end
end

-- ===== 3. boundaries (timbers, incl. lead Timber_0), then flat bed + flat cobbles per gap =====
local boundaries = {}
do
    local ts = {}
    for _, c in model:GetChildren() do
        local i = tonumber((c.Name :: string):match("^" .. CONFIG.timberPrefix .. "_(%d+)$"))
        if i then
            table.insert(ts, { i = i, part = c })
        end
    end
    table.sort(ts, function(a, b)
        return a.i < b.i
    end)
    for _, t in ts do
        table.insert(boundaries, { pos = t.part.Position, grade = t.part.Position.Y + 0.6 })
    end
end

local rng = Random.new(7710)
local em = AssetService:CreateEditableMesh()
local nUp = em:AddNormal(Vector3.yAxis)
local built = 0
for gi = 1, #boundaries - 1 do
    local A, B = boundaries[gi], boundaries[gi + 1]
    -- FLAT tread at the DOWNHILL (lower) timber's grade. The timber is the FRONT (downhill
    -- riser) of its step; the tread sits at its top and the UPHILL timber rises above it as
    -- the back riser to the next step. min() keeps this correct whichever way the markers run.
    local tread = math.min(A.grade, B.grade)
    local d = B.pos - A.pos
    local dirH = Vector3.new(d.X, 0, d.Z).Unit
    local cross = Vector3.new(dirH.Z, 0, -dirH.X)
    local L = Vector3.new(d.X, 0, d.Z).Magnitude
    local function worldXZ(u, v)
        local p = A.pos + dirH * u + cross * v
        return p.X, p.Z
    end
    -- flat bed (top ~0.05 below the downhill tread). Tuck the downhill end 0.3 behind the
    -- downhill timber so it never overshoots that timber's face (that overshoot showed as a grey
    -- cement block embedded in the timber). Keep a small 0.5 uphill overshoot that stays hidden
    -- under the next timber, so no seam/terrain gap opens between bed and riser.
    local uDown, uUp = 0.3, L + 0.5
    local bedCtr = A.pos + dirH * ((uDown + uUp) / 2)
    local bed = Instance.new("Part")
    bed.Name = string.format("DescBed_%d", gi)
    bed.Size = Vector3.new(uUp - uDown, 1.2, CONFIG.BED_W)
    bed.CFrame = CFrame.fromMatrix(Vector3.new(bedCtr.X, tread - 0.05 - 0.6, bedCtr.Z), dirH, Vector3.yAxis)
    bed.Anchored = true
    bed.Material = Enum.Material.Concrete
    bed.Color = BED_COL
    pcall(function()
        bed.MaterialVariant = "ZenCement2"
    end)
    bed.Parent = model
    -- flat cobbles
    local HW = CONFIG.COBBLE_HW
    local uLo = TIMBER_HALF
    local uHi = L - TIMBER_HALF
    if uHi - uLo > 0.6 then
        local ss = {}
        for _ = 1, rng:NextInteger(3, 4) do
            local su, sv = rng:NextNumber(uLo, uHi), rng:NextNumber(-HW, HW)
            local ok = true
            for _, e in ss do
                if (e.u - su) ^ 2 + (e.v - sv) ^ 2 < MINSEP * MINSEP then
                    ok = false
                    break
                end
            end
            if ok then
                table.insert(ss, { u = su, v = sv })
            end
        end
        local rect = { { u = uLo, v = -HW }, { u = uHi, v = -HW }, { u = uHi, v = HW }, { u = uLo, v = HW } }
        for _, S in ss do
            local poly = rect
            for _, O in ss do
                if O ~= S then
                    poly = clip(poly, S, O)
                end
                if #poly < 3 then
                    break
                end
            end
            if #poly >= 3 then
                local c = centroid(poly)
                local ins = {}
                for _, p in poly do
                    local du, dv = c.u - p.u, c.v - p.v
                    local m = math.sqrt(du * du + dv * dv)
                    if m > 1e-4 then
                        table.insert(ins, { u = p.u + du / m * INSET, v = p.v + dv / m * INSET })
                    end
                end
                if #ins >= 3 then
                    local ck = {}
                    for i = 1, #ins do
                        local a, b = ins[i], ins[(i % #ins) + 1]
                        table.insert(ck, { u = 0.75 * a.u + 0.25 * b.u, v = 0.75 * a.v + 0.25 * b.v })
                        table.insert(ck, { u = 0.25 * a.u + 0.75 * b.u, v = 0.25 * a.v + 0.75 * b.v })
                    end
                    if #ck >= 3 then
                        local domeH = DOME * rng:NextNumber(0.85, 1.25)
                        local apexY = tread + 0.25 -- proud of the bed, flush with the DOWNHILL timber top
                        local col = Color3.fromRGB(
                            122 + math.floor((rng:NextNumber() - 0.5) * 8),
                            127 + math.floor((rng:NextNumber() - 0.5) * 8),
                            117 + math.floor((rng:NextNumber() - 0.5) * 8)
                        )
                        local cid = em:AddColor(col, 1)
                        local function ring(scale, y)
                            local ids = {}
                            for _, p in ck do
                                local wx, wz = worldXZ(c.u + (p.u - c.u) * scale, c.v + (p.v - c.v) * scale)
                                ids[#ids + 1] = em:AddVertex(Vector3.new(wx, y, wz))
                            end
                            return ids
                        end
                        local outer = ring(1.0, apexY - domeH)
                        local mid2 = ring(0.55, apexY - domeH * 0.35)
                        local ax, az = worldXZ(c.u, c.v)
                        local apex = em:AddVertex(Vector3.new(ax, apexY, az))
                        local function tri(a, b, dd)
                            local f = em:AddTriangle(a, b, dd)
                            em:SetFaceNormals(f, { nUp, nUp, nUp })
                            em:SetFaceColors(f, { cid, cid, cid })
                        end
                        local n = #outer
                        for i = 1, n do
                            local j = (i % n) + 1
                            tri(outer[i], outer[j], mid2[j])
                            tri(outer[i], mid2[j], mid2[i])
                            tri(mid2[i], mid2[j], apex)
                        end
                        built += 1
                    end
                end
            end
        end
    end
end

-- ===== 4. publish the cobble mesh =====
local res, assetId = AssetService:CreateAssetAsync(
    em,
    Enum.AssetType.Mesh,
    { Name = "ZenPathCobbles", Description = CONFIG.outModel }
)
assert(res == Enum.CreateAssetResult.Success, tostring(res))
local mp = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId))
mp.Name = "DescCobbles"
mp.Material = Enum.Material.Rock
mp.Color = Color3.new(1, 1, 1)
mp.DoubleSided = true
mp.Anchored = true
mp.CanCollide = false
mp.CollisionFidelity = Enum.CollisionFidelity.Box
mp.CFrame = CFrame.new()
mp:SetAttribute("PublishedAsset", "rbxassetid://" .. assetId)
mp.Parent = model
return string.format(
    "%s: %d gaps, %d cobbles, published rbxassetid://%d",
    CONFIG.outModel,
    #boundaries - 1,
    built,
    assetId
)
