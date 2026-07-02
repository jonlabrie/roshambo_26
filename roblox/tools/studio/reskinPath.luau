--!nocheck
-- reskinPath.luau — convert an old stepped-cobble path to the canonical §1a ishidan
-- recipe ("worn dark timber backed by worn flagstone"). Template approved on
-- NW1211Path 2026-07-02. Run in Studio (command bar / MCP execute_luau, Edit).
--
-- WHAT IT DOES (per CONFIG):
--   1. Surveys the old timbers (<oldPrefix>_<i>) -> centerline control points + foot/head treads.
--   2. Catmull-Rom RESAMPLES the line (NEVER run layout on the raw polyline — per-segment
--      direction snapping kinks the rail offsets; bit us on the NW1211 redo).
--   3. Uniform-riser layout (target 0.6), foot/head treads PRESERVED exactly so the path
--      still meets its neighbours. relayout=false keeps the old gap/tread geometry instead
--      (pure re-skin — only for paths whose old risers are already <= ~0.8).
--   4. Cut-only carve per step (floor tread-1.4; boxes >= 4 in every dim). VERIFY in a
--      SEPARATE call afterwards (same-call terrain reads are stale).
--   5. Demolishes the old dressing (timbers, beds, cobble/ribbon meshes by name patterns).
--   6. Builds §1a: Riser_<i> worn beams, Step_<i> ZenGravel1 beds (riser-to-riser span),
--      Flags_<n> published meshes chunked by FLAG COUNT (chunkFlags — Studio triangle limit;
--      deep treads pack 8-14 flags/step, so never chunk by step count).
-- AFTERWARDS (separate runs): rebuild the path's bamboo railing v2.1 (buildBambooRailing —
-- add a RUNS entry; stitch contiguous paths into ONE run) and re-check ishigaki spans.
-- Chochin poles are static — leave them unless spacing now reads wrong.
-- Geometry is PLACE-ONLY — SAVE THE PLACE after running.
local CONFIG = {
    path = "PathSteps", -- Workspace model to convert
    oldPrefix = "Timber", -- old timber name prefix
    oldPatterns = { "^Timber_", "^Bed_", "^Flagstones$" }, -- children to demolish after build
    relayout = true, -- false = keep old treads/gaps (only if old risers <= ~0.8)
    riserTarget = 0.6,
    carve = true,
    seed = 20260718,
    -- publish a flag mesh every N FLAGS (NOT steps — deep treads pack 8-14 flags each and a
    -- step-count chunk blows Studio's triangle limit)
    chunkFlags = 40,
}

local AssetService = game:GetService("AssetService")
local ws = workspace
local m = ws[CONFIG.path]

-- ===== survey =====
local ts = {}
for _, q in m:GetChildren() do
    local i = tonumber(q.Name:match("^" .. CONFIG.oldPrefix .. "_(%d+)$"))
    if i then
        ts[#ts + 1] = { i = i, top = q.Position.Y + q.Size.Y / 2, pos = q.Position }
    end
end
table.sort(ts, function(a, b)
    return a.i < b.i
end)
assert(#ts >= 2, "need >= 2 old timbers")
if ts[1].top > ts[#ts].top then -- foot-first
    local rev = {}
    for k = #ts, 1, -1 do
        rev[#rev + 1] = ts[k]
    end
    ts = rev
end
local ctrl = {}
for _, t in ts do
    ctrl[#ctrl + 1] = { t.pos.X, t.top, t.pos.Z }
end
local footY, headY = ts[1].top, ts[#ts].top

-- ===== smooth centerline =====
local function hyp(dx, dz)
    return math.sqrt(dx * dx + dz * dz)
end
local function resample(control, spacing)
    local n = #control
    local function P(i)
        return control[math.clamp(i, 1, n)]
    end
    local out = { { control[1][1], control[1][2], control[1][3] } }
    for seg = 1, n - 1 do
        local p0, p1, p2, p3 = P(seg - 1), P(seg), P(seg + 1), P(seg + 2)
        local segRun = hyp(p2[1] - p1[1], p2[3] - p1[3])
        local samples = math.max(1, math.ceil(segRun / spacing))
        for k = 1, samples do
            local t = k / samples
            local q = {}
            for a = 1, 3 do
                local t2, t3 = t * t, t * t * t
                q[a] = 0.5
                    * (
                        (2 * p1[a])
                        + (-p0[a] + p2[a]) * t
                        + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t2
                        + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t3
                    )
            end
            table.insert(out, q)
        end
    end
    return out
end
local poly = resample(ctrl, 1.2)
local cum = { 0 }
for k = 2, #poly do
    cum[k] = cum[k - 1] + hyp(poly[k][1] - poly[k - 1][1], poly[k][3] - poly[k - 1][3])
end
local total = cum[#cum]
local function at(d)
    d = math.clamp(d, 0, total)
    for k = 2, #poly do
        if d <= cum[k] + 1e-9 then
            local a, b = poly[k - 1], poly[k]
            local seg = cum[k] - cum[k - 1]
            local t = seg > 1e-9 and (d - cum[k - 1]) / seg or 0
            local run = hyp(b[1] - a[1], b[3] - a[3])
            local dir = run > 1e-9 and Vector3.new((b[1] - a[1]) / run, 0, (b[3] - a[3]) / run)
                or Vector3.new(1, 0, 0)
            return Vector3.new(a[1] + (b[1] - a[1]) * t, 0, a[3] + (b[3] - a[3]) * t), dir
        end
    end
    local l = poly[#poly]
    return Vector3.new(l[1], 0, l[3]), Vector3.new(1, 0, 0)
end

-- ===== steps (relayout or preserved) =====
local steps = {} -- { center, dir, tread, pitch }
if CONFIG.relayout then
    local n = math.max(1, math.floor((headY - footY) / CONFIG.riserTarget + 0.5))
    local riser, pitch = (headY - footY) / n, total / n
    for i = 1, n do
        local c, d = at((i - 0.5) * pitch)
        steps[#steps + 1] = { center = c, dir = d, tread = footY + i * riser, pitch = pitch }
    end
else
    -- one step per old gap, tread = lower timber top, positions on the SMOOTH line
    local arc = 0
    for k = 1, #ts - 1 do
        local gap = hyp(ts[k + 1].pos.X - ts[k].pos.X, ts[k + 1].pos.Z - ts[k].pos.Z)
        local c, d = at(arc + gap / 2)
        steps[#steps + 1] = { center = c, dir = d, tread = math.min(ts[k].top, ts[k + 1].top), pitch = gap }
        arc += gap
    end
end

-- ===== carve (cut-only) =====
if CONFIG.carve then
    local T = ws.Terrain
    for _, s in steps do
        local cross = Vector3.new(-s.dir.Z, 0, s.dir.X)
        T:FillBlock(
            CFrame.fromMatrix(Vector3.new(s.center.X, (s.tread - 1.4) + 3, s.center.Z), cross, Vector3.yAxis),
            Vector3.new(9.4, 6, math.max(4, s.pitch + 1)),
            Enum.Material.Air
        )
    end
end

-- ===== demolish old dressing =====
for _, q in m:GetChildren() do
    for _, pat in CONFIG.oldPatterns do
        if q.Name:match(pat) then
            q:Destroy()
            break
        end
    end
end

-- ===== §1a dress build =====
local rngState = CONFIG.seed
local function rng()
    rngState = (1664525 * rngState + 1013904223) % 2 ^ 32
    return rngState / 2 ^ 32
end
local function clip(poly2, S, O)
    local dx, dv = S.u - O.u, S.v - O.v
    local mx, mv = (S.u + O.u) / 2, (S.v + O.v) / 2
    local function inside(p)
        return (p.u - mx) * dx + (p.v - mv) * dv >= 0
    end
    local function isect(a, b)
        local da = (a.u - mx) * dx + (a.v - mv) * dv
        local db = (b.u - mx) * dx + (b.v - mv) * dv
        local t = da / (da - db)
        return { u = a.u + (b.u - a.u) * t, v = a.v + (b.v - a.v) * t }
    end
    local out = {}
    for i = 1, #poly2 do
        local a, b = poly2[i], poly2[(i % #poly2) + 1]
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
local function chaikin(poly2)
    local out = {}
    for i = 1, #poly2 do
        local a, b = poly2[i], poly2[(i % #poly2) + 1]
        table.insert(out, { u = 0.75 * a.u + 0.25 * b.u, v = 0.75 * a.v + 0.25 * b.v })
        table.insert(out, { u = 0.25 * a.u + 0.75 * b.u, v = 0.25 * a.v + 0.75 * b.v })
    end
    return out
end
local function subdivide(poly2, maxSeg)
    local out = {}
    for i = 1, #poly2 do
        local a, b = poly2[i], poly2[(i % #poly2) + 1]
        table.insert(out, a)
        local d = math.sqrt((b.u - a.u) ^ 2 + (b.v - a.v) ^ 2)
        local nSub = math.floor(d / maxSeg)
        for k2 = 1, nSub do
            table.insert(out, {
                u = a.u + (b.u - a.u) * (k2 / (nSub + 1)),
                v = a.v + (b.v - a.v) * (k2 / (nSub + 1)),
            })
        end
    end
    return out
end
local report = {}
local em = AssetService:CreateEditableMesh()
local emFlags, chunkIdx = 0, 1
local function publishChunk()
    if emFlags == 0 then
        return
    end
    local res, assetId = AssetService:CreateAssetAsync(
        em,
        Enum.AssetType.Mesh,
        { Name = "ZenFlagTreads", Description = CONFIG.path .. " flags chunk " .. chunkIdx }
    )
    assert(res == Enum.CreateAssetResult.Success, "flag publish failed: " .. tostring(res))
    local mp = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId))
    mp.Name = "Flags_" .. chunkIdx
    mp.Material = Enum.Material.Slate
    mp.Color = Color3.new(1, 1, 1)
    mp.DoubleSided = true
    mp.Anchored = true
    mp.CanCollide = false
    mp.CollisionFidelity = Enum.CollisionFidelity.Box
    mp.CFrame = CFrame.new()
    mp:SetAttribute("PublishedAsset", "rbxassetid://" .. assetId)
    mp.Parent = m
    report[#report + 1] = string.format("Flags_%d: %d flags, asset %d", chunkIdx, emFlags, assetId)
    chunkIdx += 1
    emFlags = 0
    em = AssetService:CreateEditableMesh()
end
for si, s in steps do
    local i = si - 1
    local perp = Vector3.new(-s.dir.Z, 0, s.dir.X)
    local front = s.center - s.dir * (s.pitch / 2)
    -- beam(s)
    local split = rng() < 0.35
    local widths = split and { 6.4 * (0.35 + 0.3 * rng()) - 0.03 } or { 6.4 }
    if split then
        widths[2] = 6.4 - widths[1] - 0.06
    end
    local edge = -3.2
    for pi, wd in widths do
        local h = 0.6 + 0.12 * rng()
        local cCross = edge + wd / 2
        edge += wd + 0.06
        local q = Instance.new("Part")
        q.Name = "Riser_" .. i .. (split and string.char(96 + pi) or "")
        q.Anchored = true
        q.Material = Enum.Material.Wood
        local tint = math.floor((rng() * 2 - 1) * 7 + 0.5)
        q.Color = Color3.fromRGB(72 + tint, 60 + tint, 48 + tint)
        q.Size = Vector3.new(wd - 0.05 * rng(), h, 0.45)
        local pp = front + s.dir * 0.225 + perp * (cCross + (rng() * 2 - 1) * 0.06)
        q.CFrame = CFrame.fromMatrix(Vector3.new(pp.X, s.tread - h / 2, pp.Z), perp, Vector3.yAxis)
            * CFrame.Angles(0, math.rad((rng() * 2 - 1) * 1.5), 0)
        q.TopSurface = Enum.SurfaceType.Smooth
        q.BottomSurface = Enum.SurfaceType.Smooth
        q.Parent = m
    end
    -- bed
    local bedLen = s.pitch + 0.1
    local bed = Instance.new("Part")
    bed.Name = "Step_" .. i
    bed.Anchored = true
    bed.Material = Enum.Material.Concrete
    bed.MaterialVariant = "ZenGravel1"
    bed.Color = Color3.fromRGB(150, 146, 138)
    bed.Size = Vector3.new(5.8, 1.2, bedLen)
    local bc = front + s.dir * (0.2 + bedLen / 2)
    bed.CFrame = CFrame.fromMatrix(Vector3.new(bc.X, s.tread - 0.05 - 0.6, bc.Z), perp, Vector3.yAxis)
    bed.TopSurface = Enum.SurfaceType.Smooth
    bed.BottomSurface = Enum.SurfaceType.Smooth
    bed.Parent = m
    -- flags
    local V0, V1 = 0.55, s.pitch - 0.08
    if V1 - V0 >= 0.4 then
        local seeds = {}
        for _ = 1, ((V1 - V0) > 1.4 and 14 or 8) do
            local su, sv = -2.7 + 5.4 * rng(), V0 + (V1 - V0) * rng()
            local ok = true
            for _, s2 in seeds do
                if (s2.u - su) ^ 2 + (s2.v - sv) ^ 2 < 1.44 then
                    ok = false
                    break
                end
            end
            if ok then
                table.insert(seeds, { u = su, v = sv })
            end
        end
        local R0 = { { u = -2.7, v = V0 }, { u = 2.7, v = V0 }, { u = 2.7, v = V1 }, { u = -2.7, v = V1 } }
        for _, S in seeds do
            local cell = R0
            for _, O in seeds do
                if O ~= S then
                    cell = clip(cell, S, O)
                end
                if #cell < 3 then
                    break
                end
            end
            if #cell >= 3 then
                local cu, cv = 0, 0
                for _, p in cell do
                    cu, cv = cu + p.u, cv + p.v
                end
                cu, cv = cu / #cell, cv / #cell
                local ins = {}
                for _, p in subdivide(cell, 0.45) do
                    local du, dv = cu - p.u, cv - p.v
                    local ml = math.sqrt(du * du + dv * dv)
                    if ml > 1e-4 then
                        local amt = 0.05 + rng() * 0.09
                        local roll = rng()
                        if roll < 0.12 then
                            amt = amt + 0.15 + rng() * 0.18
                        elseif roll > 0.92 then
                            amt = amt - 0.06
                        end
                        table.insert(ins, { u = p.u + du / ml * amt, v = p.v + dv / ml * amt })
                    end
                end
                if #ins >= 3 then
                    ins = chaikin(ins)
                    local topY = s.tread + (rng() * 2 - 1) * 0.02
                    local warm = rng() < 0.35
                    local g = math.floor(78 + rng() * 38)
                    local col = warm and Color3.fromRGB(g + 8, g, g - 12) or Color3.fromRGB(g, g + 1, g - 3)
                    local cTop = em:AddColor(col, 1)
                    local cSide = em:AddColor(Color3.fromRGB(52, 52, 49), 1)
                    local function world(p)
                        return front + perp * p.u + s.dir * p.v
                    end
                    local cW = world({ u = cu, v = cv })
                    local bevIds, crownIds, botIds, vNormB, vNormC = {}, {}, {}, {}, {}
                    for _, p in ins do
                        local wp = world(p)
                        local outN = (wp - cW).Unit
                        bevIds[#bevIds + 1] = em:AddVertex(Vector3.new(wp.X, topY - 0.07, wp.Z))
                        vNormB[#vNormB + 1] = em:AddNormal((outN + Vector3.new(0, 1.2, 0)).Unit)
                        local cp = wp:Lerp(cW, 0.22)
                        crownIds[#crownIds + 1] = em:AddVertex(Vector3.new(cp.X, topY, cp.Z))
                        vNormC[#vNormC + 1] = em:AddNormal((outN * 0.25 + Vector3.new(0, 1, 0)).Unit)
                        botIds[#botIds + 1] = em:AddVertex(Vector3.new(wp.X, topY - 0.32, wp.Z))
                    end
                    local apex = em:AddVertex(Vector3.new(cW.X, topY + 0.012, cW.Z))
                    local apexN = em:AddNormal(Vector3.new(0, 1, 0))
                    local nn = #bevIds
                    for i2 = 1, nn do
                        local j = (i2 % nn) + 1
                        local f = em:AddTriangle(crownIds[i2], crownIds[j], apex)
                        em:SetFaceNormals(f, { vNormC[i2], vNormC[j], apexN })
                        em:SetFaceColors(f, { cTop, cTop, cTop })
                        local b1 = em:AddTriangle(bevIds[i2], bevIds[j], crownIds[j])
                        em:SetFaceNormals(b1, { vNormB[i2], vNormB[j], vNormC[j] })
                        em:SetFaceColors(b1, { cTop, cTop, cTop })
                        local b2 = em:AddTriangle(bevIds[i2], crownIds[j], crownIds[i2])
                        em:SetFaceNormals(b2, { vNormB[i2], vNormC[j], vNormC[i2] })
                        em:SetFaceColors(b2, { cTop, cTop, cTop })
                        local s1 = em:AddTriangle(botIds[i2], botIds[j], bevIds[j])
                        em:SetFaceNormals(s1, { vNormB[i2], vNormB[j], vNormB[j] })
                        em:SetFaceColors(s1, { cSide, cSide, cTop })
                        local s2 = em:AddTriangle(botIds[i2], bevIds[j], bevIds[i2])
                        em:SetFaceNormals(s2, { vNormB[i2], vNormB[j], vNormB[i2] })
                        em:SetFaceColors(s2, { cSide, cTop, cTop })
                    end
                    emFlags += 1
                end
            end
        end
    end
    if emFlags >= CONFIG.chunkFlags then
        publishChunk()
    end
end
publishChunk()
print(
    string.format(
        "%s reskinned: %d steps (%s); %s",
        CONFIG.path,
        #steps,
        CONFIG.relayout and "re-layout" or "geometry preserved",
        table.concat(report, "; ")
    )
)
