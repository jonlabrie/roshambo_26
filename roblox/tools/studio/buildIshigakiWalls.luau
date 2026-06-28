--!nocheck
-- Reusable ishigaki (dry-stone) retaining-wall generator. Run in Studio (paste into the
-- command bar or via the MCP execute_luau). Finds the contiguous spans of a path whose
-- DOWNHILL edge floats above grade, and builds a battered fitted-stone face per span,
-- published into Workspace.RetainingWalls. See docs/superpowers/references/
-- zendojo-canyon-build-recipes.md §3 for the why; params below are the approved v4 recipe.
--
-- USAGE: set CONFIG.paths to the path model(s) to wall, then run. Each path -> the floating
-- spans (>THRESH), padded +/-1 timber, each a published Wall_<model>_<first>_<last> MeshPart.

local CONFIG = {
    paths = { -- { model = WorkspaceModelName, prefix = timberNamePrefix }
        { model = "PathSteps", prefix = "Timber" },
        { model = "PathExtension", prefix = "ExtTimber" },
        { model = "DescentPath", prefix = "DescTimber" },
    },
    HW = 3.2, -- path half-width (bed edge); top edge of the wall
    THRESH = 2.5, -- only wall spans whose downhill float exceeds this
    PAD = 1, -- pad each span by this many timbers per side (so singles taper, not nub)
}

-- ===== locked v4 wall recipe (see recipe doc §3) =====
local HW_TOP, HW_BASE, BASEEMBED = 3.2, 3.7, 0.4
local TOP_BELOW, SY, MS = 0.6, 2.0, 1.15 -- top at bed underside; vertical stretch; min-sep
local INSET, RELIEF, TAPER = 0.12, 0.22, 2.0
local COL_STONE, COL_JOINT = Color3.fromRGB(96, 98, 94), Color3.fromRGB(46, 47, 45)

local ws = workspace
local AssetService = game:GetService("AssetService")

local function terr(x, z)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { ws.Terrain }
    local r = ws:Raycast(Vector3.new(x, 360, z), Vector3.new(0, -460, 0), rp)
    return r and r.Position.Y or nil
end
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

-- index range of a model's timbers
local function range(model, prefix)
    local lo, hi = math.huge, -math.huge
    for _, c in ws[model]:GetChildren() do
        local i = tonumber((c.Name :: string):match("^" .. prefix .. "_(%d+)$"))
        if i then
            lo, hi = math.min(lo, i), math.max(hi, i)
        end
    end
    return lo, hi
end

-- contiguous floating spans (downhill float > THRESH); sign = -1 (-Right) or +1 (+Right)
local function findSpans(model, prefix)
    local ts = {}
    for _, c in ws[model]:GetChildren() do
        local i = tonumber((c.Name :: string):match("^" .. prefix .. "_(%d+)$"))
        if i then
            table.insert(ts, { i = i, part = c })
        end
    end
    table.sort(ts, function(a, b)
        return a.i < b.i
    end)
    local spans, cur = {}, nil
    for _, t in ts do
        local p, r = t.part.Position, t.part.CFrame.RightVector
        r = Vector3.new(r.X, 0, r.Z).Unit
        local yp, ym =
            terr(p.X + r.X * CONFIG.HW, p.Z + r.Z * CONFIG.HW),
            terr(p.X - r.X * CONFIG.HW, p.Z - r.Z * CONFIG.HW)
        local fp, fm = yp and (p.Y - yp) or 0, ym and (p.Y - ym) or 0
        local sign = (fm >= fp) and -1 or 1
        if math.max(fp, fm) > CONFIG.THRESH then
            if cur and cur.sign == sign and t.i == cur.last + 1 then
                cur.last = t.i
            else
                cur = { model = model, prefix = prefix, first = t.i, last = t.i, sign = sign }
                table.insert(spans, cur)
            end
        else
            cur = nil
        end
    end
    return spans
end

local function buildWall(span)
    local m = ws[span.model]
    local rng = Random.new(span.first * 1000 + span.last)
    local nodes, u, prevTop = {}, 0, nil
    for i = span.first, span.last do
        local t = m:FindFirstChild(span.prefix .. "_" .. i)
        if t then
            local p, r = t.Position, t.CFrame.RightVector
            r = Vector3.new(r.X, 0, r.Z).Unit
            local outward = r * span.sign
            local topY = p.Y - TOP_BELOW
            local topP = Vector3.new(p.X + outward.X * HW_TOP, topY, p.Z + outward.Z * HW_TOP)
            local bx, bz = p.X + outward.X * HW_BASE, p.Z + outward.Z * HW_BASE
            local baseP = Vector3.new(bx, (terr(bx, bz) or (topY - 4)) - BASEEMBED, bz)
            if prevTop then
                u = u + (Vector3.new(topP.X, 0, topP.Z) - Vector3.new(prevTop.X, 0, prevTop.Z)).Magnitude
            end
            prevTop = topP
            table.insert(
                nodes,
                { top = topP, base = baseP, N = Vector3.new(outward.X, 0, outward.Z).Unit, u = u }
            )
        end
    end
    if #nodes < 2 then
        return nil, "too few nodes"
    end
    local L = nodes[#nodes].u
    local function sample(uu)
        uu = math.clamp(uu, 0, L)
        for k = 1, #nodes - 1 do
            local a, b = nodes[k], nodes[k + 1]
            if uu <= b.u or k == #nodes - 1 then
                local f = (b.u > a.u) and (uu - a.u) / (b.u - a.u) or 0
                local top, base, N = a.top:Lerp(b.top, f), a.base:Lerp(b.base, f), a.N:Lerp(b.N, f).Unit
                local tn = math.noise(uu * 0.6, 2.3) * 0.4 + math.noise(uu * 1.5, 8.1) * 0.18
                local bn = math.noise(uu * 0.55, 7.1) * 0.3
                top = Vector3.new(top.X, top.Y + tn, top.Z)
                base = Vector3.new(base.X, base.Y + bn, base.Z)
                local edge = math.min(uu, L - uu)
                base = base:Lerp(top, 1 - math.clamp(edge / TAPER, 0.12, 1))
                return top, base, N
            end
        end
        return nil
    end
    local Hsum = 0
    for _, nd in nodes do
        Hsum = Hsum + (nd.top - nd.base).Magnitude
    end
    local Hs = math.max(Hsum / #nodes, 0.5) * SY
    local em = AssetService:CreateEditableMesh()
    local function face3(uu, vs, push)
        local top, base, N = sample(uu)
        return base:Lerp(top, math.clamp(vs / Hs, 0, 1)) + N * push, N
    end
    do -- recessed dark backing over the whole face
        local steps, prevB, prevT = math.max(2, math.floor(L / 0.5)), nil, nil
        for s = 0, steps do
            local uu = L * s / steps
            local bp, nb = face3(uu, 0, 0)
            local tp = select(1, face3(uu, Hs, 0))
            local vb, vt = em:AddVertex(bp), em:AddVertex(tp)
            local nid, cj = em:AddNormal(nb), em:AddColor(COL_JOINT, 1)
            if prevB then
                local f1 = em:AddTriangle(prevB, prevT, vt)
                em:SetFaceNormals(f1, { nid, nid, nid })
                em:SetFaceColors(f1, { cj, cj, cj })
                local f2 = em:AddTriangle(prevB, vt, vb)
                em:SetFaceNormals(f2, { nid, nid, nid })
                em:SetFaceColors(f2, { cj, cj, cj })
            end
            prevB, prevT = vb, vt
        end
    end
    local PAD, seeds = 1.0, {}
    for _ = 1, math.ceil((L + 2 * PAD) * (Hs + 2 * PAD) / (MS * MS) * 1.4) do
        local su, sv = rng:NextNumber(-PAD, L + PAD), rng:NextNumber(-PAD, Hs + PAD)
        local ok = true
        for _, s in seeds do
            if (s.u - su) ^ 2 + (s.v - sv) ^ 2 < MS * MS then
                ok = false
                break
            end
        end
        if ok then
            table.insert(seeds, { u = su, v = sv })
        end
    end
    local R0 = {
        { u = -PAD, v = -PAD },
        { u = L + PAD, v = -PAD },
        { u = L + PAD, v = Hs + PAD },
        { u = -PAD, v = Hs + PAD },
    }
    local built = 0
    for _, S in seeds do
        local poly = R0
        for _, O in seeds do
            if O ~= S and (S.u - O.u) ^ 2 + (S.v - O.v) ^ 2 < (3 * MS) ^ 2 then
                poly = clip(poly, S, O)
            end
            if #poly < 3 then
                break
            end
        end
        local c = #poly >= 3 and centroid(poly) or nil
        if c and c.u >= 0 and c.u <= L and c.v >= 0 and c.v <= Hs then
            local ins = {}
            for _, p in poly do
                local du, dv = c.u - p.u, c.v - p.v
                local ml = math.sqrt(du * du + dv * dv)
                if ml > 1e-4 then
                    table.insert(ins, { u = p.u + du / ml * INSET, v = p.v + dv / ml * INSET })
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
                    local jit = (rng:NextNumber() - 0.5) * 6 / 255
                    local col = Color3.new(
                        math.clamp(COL_STONE.R + jit, 0, 1),
                        math.clamp(COL_STONE.G + jit, 0, 1),
                        math.clamp(COL_STONE.B + jit, 0, 1)
                    )
                    local cs, cj = em:AddColor(col, 1), em:AddColor(COL_JOINT, 1)
                    local faceRing, skirtRing = {}, {}
                    for _, p in ck do
                        local fp, N = face3(p.u, p.v, RELIEF)
                        local sp = select(1, face3(p.u, p.v, 0.03))
                        local nid = em:AddNormal(N)
                        faceRing[#faceRing + 1] = { id = em:AddVertex(fp), n = nid }
                        skirtRing[#skirtRing + 1] = { id = em:AddVertex(sp), n = nid }
                    end
                    local apexPos, apexN = face3(c.u, c.v, RELIEF)
                    local apex, apexNid = em:AddVertex(apexPos), em:AddNormal(apexN)
                    local n = #faceRing
                    for i = 1, n do
                        local j = (i % n) + 1
                        local f = em:AddTriangle(faceRing[i].id, faceRing[j].id, apex)
                        em:SetFaceNormals(f, { faceRing[i].n, faceRing[j].n, apexNid })
                        em:SetFaceColors(f, { cs, cs, cs })
                        local s1 = em:AddTriangle(skirtRing[i].id, skirtRing[j].id, faceRing[j].id)
                        em:SetFaceNormals(s1, { skirtRing[i].n, skirtRing[j].n, faceRing[j].n })
                        em:SetFaceColors(s1, { cj, cj, cs })
                        local s2 = em:AddTriangle(skirtRing[i].id, faceRing[j].id, faceRing[i].id)
                        em:SetFaceNormals(s2, { skirtRing[i].n, faceRing[j].n, faceRing[i].n })
                        em:SetFaceColors(s2, { cj, cs, cs })
                    end
                    built += 1
                end
            end
        end
    end
    local res, assetId = AssetService:CreateAssetAsync(
        em,
        Enum.AssetType.Mesh,
        { Name = "ZenIshigaki", Description = "retaining wall " .. span.model }
    )
    if res ~= Enum.CreateAssetResult.Success then
        return nil, "publish failed " .. tostring(res)
    end
    local parent = ws:FindFirstChild("RetainingWalls") or Instance.new("Model")
    parent.Name = "RetainingWalls"
    parent.Parent = ws
    local nm = string.format("Wall_%s_%d_%d", span.model, span.first, span.last)
    local ex = parent:FindFirstChild(nm)
    if ex then
        ex:Destroy()
    end
    local mp = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId))
    mp.Name = nm
    mp.Material = Enum.Material.Rock
    mp.Color = Color3.new(1, 1, 1)
    mp.DoubleSided = true
    mp.Anchored = true
    mp.CanCollide = false
    mp.CollisionFidelity = Enum.CollisionFidelity.Box
    mp.CFrame = CFrame.new()
    mp:SetAttribute("PublishedAsset", "rbxassetid://" .. assetId)
    mp.Parent = parent
    return string.format("%s: %d stones id=%d", nm, built, assetId)
end

-- ===== run =====
local out = {}
for _, path in CONFIG.paths do
    if ws:FindFirstChild(path.model) then
        local lo, hi = range(path.model, path.prefix)
        for _, span in findSpans(path.model, path.prefix) do
            span.first = math.max(lo, span.first - CONFIG.PAD)
            span.last = math.min(hi, span.last + CONFIG.PAD)
            local r, err = buildWall(span)
            out[#out + 1] = r
                or string.format("Wall_%s_%d_%d FAIL: %s", span.model, span.first, span.last, tostring(err))
        end
    end
end
return table.concat(out, "\n")
