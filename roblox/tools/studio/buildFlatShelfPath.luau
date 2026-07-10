-- buildFlatShelfPath.luau — flat/near-level curved shelf promenades, dressed with the
-- LOCKED ishidan recipe ("worn dark timber backed by worn flagstone", 2026-07-02).
-- The riser-driven buildIshidanStairs collapses a flat run to ~1 step (rise/riserTarget≈0),
-- so a level shelf needs a UNIFORM-TREAD layout instead: N equal treads along the arc,
-- tread Y interpolated from the (near-level) centerline. Dressing/flags/beds are IDENTICAL
-- to the ishidan builder — only the layout differs. A path may carry a gentle grade: the
-- tread tops follow the centerline Y as a smooth ramp (used by FarWallBridge2Path, +4.75 over 62).
--
-- Emits per step: Riser_<i>[a|b] worn-timber lip Parts (a low ishidan step even on the flat),
-- Step_<i> fine-gravel bed (RightVector = cross-stream, top = tread - 0.05 — the downstream
-- contract for railing/chochin builders), and flat flagstones published as Flags_<n> EditableMesh
-- chunks. Parents under Workspace.CanyonWorld.Paths (NEVER Workspace root — the sweep convention).
-- Run in Studio (Edit datamodel; command bar / MCP execute_luau). Idempotent per outModel.
--
-- Companion builders for the same paths: buildBambooRailing.luau (flat-shelf RUNS: noRelax +
-- clampEnds + hw = bedW/2) and buildChochinPole/inline lanterns. See the recipe doc §1c.
local CONFIG = {
    -- one entry per shelf path. nSteps overrides treadTarget; else nSteps = round(arc / treadTarget).
    -- control = BAKED {x,y,z} centerline points (survey the Sandbox.PathDraft markers once, bake).
    paths = {
        {
            -- North-face shelf promenade (markers FarWall_72/80/81/82); near-dead-level, curves in XZ.
            outModel = "FarWall7282Path",
            control = {
                { -308.47, 243.09, -99.99 },
                { -330.42, 243.59, -106.69 },
                { -354.94, 243.61, -106.90 },
                { -376.48, 243.71, -97.73 },
            },
            treadTarget = 6.0, -- ≈12 treads
        },
        {
            -- Final Far-Wall segment: the same 4 markers moved on to a new reach, terminating at the
            -- Bridge2_B abutment marker. Gentle ramp (+4.75 over ~62), carried by the centerline Y.
            outModel = "FarWallBridge2Path",
            control = {
                { -390.44, 242.03, -90.09 }, -- FarWall_72
                { -401.55, 242.62, -79.69 }, -- FarWall_80
                { -409.30, 243.92, -64.38 }, -- FarWall_81
                { -422.72, 245.32, -52.21 }, -- FarWall_82
                { -431.16, 246.78, -44.20 }, -- Bridge2_B (terminus; Bridge2 itself not yet built)
            },
            treadTarget = 6.0, -- ≈10 treads
        },
    },
    seed = 20260709,
    resampleSpacing = 2.0,
    chunkFlags = 40, -- publish a flag mesh every N FLAGS (not steps — triangle limit)
    -- style constants (the locked recipe — change only with a user gate):
    riserWidth = 6.4,
    riserDepth = 0.45,
    splitFrac = 0.35,
    flagHW = 2.7,
    flagMinDepth = 0.4,
    bedW = 5.8,
    bedH = 1.2,
    bedVariant = "ZenGravel1",
    bedColor = Color3.fromRGB(150, 146, 138),
    flagSideColor = Color3.fromRGB(52, 52, 49),
    flagProud = 0.08,
}

----------------------------------------------------------------------------
-- >>> MIRRORED from buildIshidanStairs.luau — KEEP IN SYNC <<<
----------------------------------------------------------------------------
local function hyp(dx, dz)
    return math.sqrt(dx * dx + dz * dz)
end

local function resample(control, spacing)
    local n = #control
    assert(n >= 2, "need at least 2 control points")
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

local function arcTable(polyline)
    local cum = { 0 }
    for k = 2, #polyline do
        local a, b = polyline[k - 1], polyline[k]
        cum[k] = cum[k - 1] + hyp(b[1] - a[1], b[3] - a[3])
    end
    local total = cum[#cum]
    local function at(d)
        d = math.clamp(d, 0, total)
        for k = 2, #polyline do
            if d <= cum[k] + 1e-9 then
                local a, b = polyline[k - 1], polyline[k]
                local seg = cum[k] - cum[k - 1]
                local t = seg > 1e-9 and (d - cum[k - 1]) / seg or 0
                local run = hyp(b[1] - a[1], b[3] - a[3])
                local dir = run > 1e-9 and { (b[1] - a[1]) / run, (b[3] - a[3]) / run } or { 1, 0 }
                return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }, dir
            end
        end
        local last = polyline[#polyline]
        return { last[1], last[2], last[3] }, { 1, 0 }
    end
    return total, at
end

local function makeRng(seed)
    local state = seed % 2 ^ 32
    return function()
        state = (1664525 * state + 1013904223) % 2 ^ 32
        return state / 2 ^ 32
    end
end

local function subdivide(poly, maxSeg)
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        table.insert(out, a)
        local d = math.sqrt((b.u - a.u) ^ 2 + (b.v - a.v) ^ 2)
        local nSub = math.floor(d / maxSeg)
        for k = 1, nSub do
            local t = k / (nSub + 1)
            table.insert(out, { u = a.u + (b.u - a.u) * t, v = a.v + (b.v - a.v) * t })
        end
    end
    return out
end

local function chaikin(poly)
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        table.insert(out, { u = 0.75 * a.u + 0.25 * b.u, v = 0.75 * a.v + 0.25 * b.v })
        table.insert(out, { u = 0.25 * a.u + 0.75 * b.u, v = 0.25 * a.v + 0.75 * b.v })
    end
    return out
end

local function clipCell(poly, S, O)
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

local function dress(layoutR, opts)
    local rng = makeRng(opts.seed)
    local RW = opts.riserWidth or 6.4
    local RD = opts.riserDepth or 0.45
    local splitFrac = opts.splitFrac or 0.35
    local HW = opts.flagHW or 2.7
    local minDepth = opts.flagMinDepth or 0.4
    local bedW = opts.bedW or 5.8
    local bedH = opts.bedH or 1.2
    local out = {}
    for _, s in layoutR.steps do
        local isLanding = s.kind == "landing"
        local pitch = isLanding and s.len or s.pitch
        local front = { s.pos[1] - s.dir[1] * pitch / 2, s.pos[3] - s.dir[2] * pitch / 2 }
        local entry = { i = s.i, kind = s.kind, risers = {}, flags = {}, bed = nil }
        if not isLanding then
            local split = rng() < splitFrac
            local pieces = split and 2 or 1
            local splitF = 0.35 + 0.3 * rng()
            local widths = pieces == 1 and { RW } or { RW * splitF - 0.03, RW * (1 - splitF) - 0.03 }
            local edge = -RW / 2
            for _, wd in widths do
                local h = 0.6 + 0.12 * rng()
                local cCross = edge + wd / 2
                edge += wd + 0.06
                local tint = math.floor((rng() * 2 - 1) * 7 + 0.5)
                local latJ = (rng() * 2 - 1) * 0.06
                local lenTrim = 0.05 * rng()
                local yaw = (rng() * 2 - 1) * 1.5
                local perp = { -s.dir[2], s.dir[1] }
                table.insert(entry.risers, {
                    pos = {
                        front[1] + s.dir[1] * (RD / 2) + perp[1] * (cCross + latJ),
                        s.tread - h / 2,
                        front[2] + s.dir[2] * (RD / 2) + perp[2] * (cCross + latJ),
                    },
                    dir = s.dir,
                    size = { wd - lenTrim, h, RD },
                    yawDeg = yaw,
                    color = { 72 + tint, 60 + tint, 48 + tint },
                })
            end
        end
        local bedLen = pitch + 0.1
        local bedCtrAlong = 0.2 + bedLen / 2
        entry.bed = {
            pos = {
                front[1] + s.dir[1] * bedCtrAlong,
                s.tread - 0.05 - bedH / 2,
                front[2] + s.dir[2] * bedCtrAlong,
            },
            dir = s.dir,
            size = { bedW, bedH, bedLen },
        }
        local V0 = isLanding and 0.3 or 0.55
        local V1 = isLanding and pitch + 0.7 or pitch - 0.08
        if V1 - V0 >= minDepth then
            local seeds = {}
            local tries = (V1 - V0) > 1.4 and 14 or 8
            for _ = 1, tries do
                local su, sv = -HW + 2 * HW * rng(), V0 + (V1 - V0) * rng()
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
            local R0 = { { u = -HW, v = V0 }, { u = HW, v = V0 }, { u = HW, v = V1 }, { u = -HW, v = V1 } }
            for _, S in seeds do
                local poly = R0
                for _, O in seeds do
                    if O ~= S then
                        poly = clipCell(poly, S, O)
                    end
                    if #poly < 3 then
                        break
                    end
                end
                if #poly >= 3 then
                    local cu, cv = 0, 0
                    for _, p in poly do
                        cu, cv = cu + p.u, cv + p.v
                    end
                    cu, cv = cu / #poly, cv / #poly
                    local ins = {}
                    for _, p in subdivide(poly, 0.45) do
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
                        local topJ = (rng() * 2 - 1) * 0.02
                        local warm = rng() < 0.35
                        local g = math.floor(78 + rng() * 38)
                        table.insert(entry.flags, {
                            outline = ins,
                            centroid = { u = cu, v = cv },
                            topJitter = topJ,
                            warm = warm,
                            g = g,
                        })
                    end
                end
            end
        end
        table.insert(out, entry)
    end
    return out
end
----------------------------------------------------------------------------
-- >>> END MIRROR <<<
----------------------------------------------------------------------------

-- uniform-tread layout for a flat/near-level shelf: N equal treads along the arc,
-- tread Y interpolated from the centerline (which carries any gentle end-to-end rise).
local function layoutFlat(polyline, nSteps)
    local total, at = arcTable(polyline)
    local pitch = total / nSteps
    local steps = {}
    for i = 1, nSteps do
        local d = (i - 0.5) * pitch
        local pos, dir = at(d)
        table.insert(steps, {
            i = i - 1,
            kind = "step",
            pos = { pos[1], pos[2], pos[3] },
            dir = dir,
            tread = pos[2],
            riser = 0,
            pitch = pitch,
        })
    end
    return { steps = steps, total = total, pitch = pitch }
end

local AssetService = game:GetService("AssetService")

local function buildPath(pcfg)
    assert(pcfg.control and #pcfg.control >= 2, "path needs >= 2 control points: " .. tostring(pcfg.outModel))
    local opts = table.clone(CONFIG)
    opts.paths = nil
    for k, v in pcfg do
        opts[k] = v
    end

    local paths = workspace.CanyonWorld.Paths
    local old = paths:FindFirstChild(pcfg.outModel)
    if old then
        old:Destroy()
    end
    local model = Instance.new("Model")
    model.Name = pcfg.outModel
    model.Parent = paths

    local polyline = resample(pcfg.control, opts.resampleSpacing)
    local total = select(1, arcTable(polyline))
    local nSteps = pcfg.nSteps or math.max(2, math.floor(total / (pcfg.treadTarget or 6.0) + 0.5))
    local layoutR = layoutFlat(polyline, nSteps)
    local dressed = dress(layoutR, opts)

    local stepByI = {}
    for _, s in layoutR.steps do
        stepByI[s.i] = s
    end

    local function mkPart(name, b, material, color, yawDeg)
        local q = Instance.new("Part")
        q.Name = name
        q.Anchored = true
        q.Material = material
        q.Color = color
        q.Size = Vector3.new(b.size[1], b.size[2], b.size[3])
        local cross = Vector3.new(-b.dir[2], 0, b.dir[1])
        local cf = CFrame.fromMatrix(Vector3.new(b.pos[1], b.pos[2], b.pos[3]), cross, Vector3.yAxis)
        if yawDeg and yawDeg ~= 0 then
            cf = cf * CFrame.Angles(0, math.rad(yawDeg), 0)
        end
        q.CFrame = cf
        q.TopSurface = Enum.SurfaceType.Smooth
        q.BottomSurface = Enum.SurfaceType.Smooth
        q.Parent = model
        return q
    end

    local made, chunkIdx = 0, 1
    local em = AssetService:CreateEditableMesh()
    local emFlags = 0
    local report = {}

    local function publishChunk()
        if emFlags == 0 then
            return
        end
        local res, assetId = AssetService:CreateAssetAsync(
            em,
            Enum.AssetType.Mesh,
            { Name = "ZenFlagTreads", Description = pcfg.outModel .. " flags chunk " .. chunkIdx }
        )
        assert(res == Enum.CreateAssetResult.Success, "flag publish failed: " .. tostring(res))
        local mp
        for _ = 1, 10 do
            local ok, r = pcall(function()
                return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. assetId))
            end)
            if ok and r then
                mp = r
                break
            else
                task.wait(1.5)
            end
        end
        assert(mp, "mesh load failed for asset " .. tostring(assetId))
        mp.Name = "Flags_" .. chunkIdx
        mp.Material = Enum.Material.Slate
        mp.Color = Color3.new(1, 1, 1)
        mp.DoubleSided = true
        mp.Anchored = true
        mp.CanCollide = false
        mp.CollisionFidelity = Enum.CollisionFidelity.Box
        mp.CFrame = CFrame.new()
        mp:SetAttribute("PublishedAsset", "rbxassetid://" .. assetId)
        mp.Parent = model
        table.insert(report, string.format("Flags_%d: %d flags, asset %d", chunkIdx, emFlags, assetId))
        chunkIdx += 1
        emFlags = 0
        em = AssetService:CreateEditableMesh()
    end

    for _, e in dressed do
        local s = stepByI[e.i]
        local pitch = s.pitch
        local front = { s.pos[1] - s.dir[1] * pitch / 2, s.pos[3] - s.dir[2] * pitch / 2 }
        local dirV = Vector3.new(s.dir[1], 0, s.dir[2])
        local crossV = Vector3.new(-s.dir[2], 0, s.dir[1])
        local frontV = Vector3.new(front[1], 0, front[2])
        for ri, r in e.risers do
            mkPart(
                "Riser_" .. e.i .. (#e.risers == 2 and string.char(96 + ri) or ""),
                r,
                Enum.Material.Wood,
                Color3.fromRGB(r.color[1], r.color[2], r.color[3]),
                r.yawDeg
            )
        end
        local bed = mkPart("Step_" .. e.i, e.bed, Enum.Material.Concrete, opts.bedColor)
        if opts.bedVariant ~= "" then
            bed.MaterialVariant = opts.bedVariant
        end
        for _, f in e.flags do
            local topY = s.tread + f.topJitter + (opts.flagProud or 0)
            local col = f.warm and Color3.fromRGB(f.g + 8, f.g, f.g - 12)
                or Color3.fromRGB(f.g, f.g + 1, f.g - 3)
            local cTop, cSide = em:AddColor(col, 1), em:AddColor(opts.flagSideColor, 1)
            local cW = frontV + crossV * f.centroid.u + dirV * f.centroid.v
            local bevIds, crownIds, botIds, vNormB, vNormC = {}, {}, {}, {}, {}
            for _, p in f.outline do
                local wp = frontV + crossV * p.u + dirV * p.v
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
            local n = #bevIds
            for i2 = 1, n do
                local j = (i2 % n) + 1
                local fq = em:AddTriangle(crownIds[i2], crownIds[j], apex)
                em:SetFaceNormals(fq, { vNormC[i2], vNormC[j], apexN })
                em:SetFaceColors(fq, { cTop, cTop, cTop })
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
        made += 1
        if emFlags >= opts.chunkFlags then
            publishChunk()
        end
    end
    publishChunk()
    return string.format(
        "%s: %d treads (pitch %.2f, run %.1f, rise %+.2f); %s",
        pcfg.outModel,
        made,
        layoutR.pitch,
        total,
        pcfg.control[#pcfg.control][2] - pcfg.control[1][2],
        table.concat(report, "; ")
    )
end

local out = {}
for _, pcfg in CONFIG.paths do
    out[#out + 1] = buildPath(pcfg)
end
return table.concat(out, "\n")
