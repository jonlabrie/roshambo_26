-- buildIshidanStairs.luau — canonical stair/path builder: uniform-riser layout
-- dressed as "worn dark timber backed by worn flagstone" (user-locked 2026-07-02).
-- MIRROR of tools/builders/IshidanStairs.luau (Lune-tested) — keep in sync.
-- Run in Studio (command bar / MCP execute_luau, Edit datamodel). Idempotent:
-- destroys and rebuilds Workspace.<CONFIG.outModel>.
--
-- Emits per step: Riser_<i>[a|b] worn-timber beam Parts (top = tread),
-- Step_<i> fine-gravel bed Part (the downstream contract for ishigaki/railing/
-- chochin builders: RightVector = cross-stream, top = tread - 0.05), and flat
-- flagstones on treads deep enough (>= 0.4 usable), published as Flags_<n>
-- EditableMesh chunks of <= CONFIG.chunkSteps steps (Studio triangle limit).
-- Flags are CanCollide false — players walk on beds/risers.
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local CONFIG = {
    outModel = "NW1012Stairs",
    -- BAKED {x,y,z} centerline control points, FOOT FIRST (survey once, bake,
    -- never read draft markers at build time):
    control = {},
    footY = 0,
    headY = 0,
    riserTarget = 0.6,
    landings = {}, -- { { frac = 0..1, len = studs } }
    seed = 20260711,
    buildRange = nil, -- {i0, i1} step indices; nil = all
    resampleSpacing = 2.0,
    -- publish a flag mesh every N FLAGS (NOT steps: deep treads pack 8-14 flags each and a
    -- step-count chunk blows Studio's triangle limit — bit us twice on 2026-07-02)
    chunkFlags = 40,
    -- style constants (the locked recipe — change only with a user gate):
    riserWidth = 6.4,
    riserDepth = 0.45,
    splitFrac = 0.35,
    flagHW = 2.7,
    flagMinDepth = 0.4,
    bedW = 5.8,
    bedH = 1.2,
    bedVariant = "ZenGravel1", -- fine decomposed-granite gravel (StudsPerTile 4)
    bedColor = Color3.fromRGB(150, 146, 138),
    flagSideColor = Color3.fromRGB(52, 52, 49),
}

----------------------------------------------------------------------------
-- >>> MIRRORED from tools/builders/IshidanStairs.luau — KEEP IN SYNC <<<
----------------------------------------------------------------------------
local function hyp(dx: number, dz: number): number
    return math.sqrt(dx * dx + dz * dz)
end

local function resample(control: { { number } }, spacing: number): { { number } }
    local n = #control
    assert(n >= 2, "need at least 2 control points")
    local function P(i: number): { number }
        return control[math.clamp(i, 1, n)]
    end
    local out: { { number } } = { { control[1][1], control[1][2], control[1][3] } }
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

type Landing = { frac: number, len: number }
type LayoutOpts = { riserTarget: number, footY: number, headY: number, landings: { Landing } }
type Step = {
    i: number,
    kind: string,
    pos: { number },
    dir: { number },
    tread: number,
    riser: number,
    pitch: number,
    len: number?,
}

local function arcTable(polyline: { { number } })
    local cum = { 0 }
    for k = 2, #polyline do
        local a, b = polyline[k - 1], polyline[k]
        cum[k] = cum[k - 1] + hyp(b[1] - a[1], b[3] - a[3])
    end
    local total = cum[#cum]
    local function at(d: number): ({ number }, { number })
        d = math.clamp(d, 0, total)
        for k = 2, #polyline do
            if d <= cum[k] + 1e-9 then
                local a, b = polyline[k - 1], polyline[k]
                local seg = cum[k] - cum[k - 1]
                local t = seg > 1e-9 and (d - cum[k - 1]) / seg or 0
                local run = hyp(b[1] - a[1], b[3] - a[3])
                local dir = run > 1e-9 and { (b[1] - a[1]) / run, (b[3] - a[3]) / run } or { 1, 0 }
                return {
                    a[1] + (b[1] - a[1]) * t,
                    a[2] + (b[2] - a[2]) * t,
                    a[3] + (b[3] - a[3]) * t,
                },
                    dir
            end
        end
        local last = polyline[#polyline]
        return { last[1], last[2], last[3] }, { 1, 0 }
    end
    return total, at
end

local function layout(polyline: { { number } }, opts: LayoutOpts)
    local total, at = arcTable(polyline)
    local marks: { { a0: number, a1: number, landing: Landing? } } = {}
    local cursor = 0
    local sorted = table.clone(opts.landings)
    table.sort(sorted, function(x, y)
        return x.frac < y.frac
    end)
    for _, l in sorted do
        local a = math.clamp(l.frac, 0.05, 0.95) * total
        table.insert(marks, { a0 = cursor, a1 = a, landing = l })
        cursor = a + l.len
    end
    table.insert(marks, { a0 = cursor, a1 = total })

    local steps: { Step } = {}
    local flights = {}
    local E0 = opts.footY
    local idx = 0
    for m, fl in marks do
        local isLast = (m == #marks)
        local posEnd = select(1, at(fl.a1))
        local E1 = if isLast then opts.headY else posEnd[2]
        local rise = E1 - E0
        local runArc = fl.a1 - fl.a0
        local n = math.max(1, math.floor(rise / opts.riserTarget + 0.5))
        local riser = rise / n
        local pitch = runArc / n
        table.insert(flights, { n = n, riser = riser, pitch = pitch })
        for i = 1, n do
            local d = fl.a0 + (i - 0.5) * pitch
            local pos, dir = at(d)
            local tread = E0 + i * riser
            idx += 1
            table.insert(steps, {
                i = idx - 1,
                kind = "step",
                pos = { pos[1], tread, pos[3] },
                dir = dir,
                tread = tread,
                riser = riser,
                pitch = pitch,
            })
        end
        E0 = E1
        if fl.landing then
            local d = fl.a1 + fl.landing.len / 2
            local pos, dir = at(d)
            idx += 1
            table.insert(steps, {
                i = idx - 1,
                kind = "landing",
                pos = { pos[1], E0, pos[3] },
                dir = dir,
                tread = E0,
                riser = 0,
                pitch = 0,
                len = fl.landing.len,
            })
        end
    end
    return { flights = flights, steps = steps }
end

local function makeRng(seed: number): () -> number
    local state = seed % 2 ^ 32
    return function(): number
        state = (1664525 * state + 1013904223) % 2 ^ 32
        return state / 2 ^ 32
    end
end

type Pt = { u: number, v: number }

local function subdivide(poly: { Pt }, maxSeg: number): { Pt }
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

local function chaikin(poly: { Pt }): { Pt }
    local out = {}
    for i = 1, #poly do
        local a, b = poly[i], poly[(i % #poly) + 1]
        table.insert(out, { u = 0.75 * a.u + 0.25 * b.u, v = 0.75 * a.v + 0.25 * b.v })
        table.insert(out, { u = 0.25 * a.u + 0.75 * b.u, v = 0.25 * a.v + 0.75 * b.v })
    end
    return out
end

local function clipCell(poly: { Pt }, S: Pt, O: Pt): { Pt }
    local dx, dv = S.u - O.u, S.v - O.v
    local mx, mv = (S.u + O.u) / 2, (S.v + O.v) / 2
    local function inside(p: Pt)
        return (p.u - mx) * dx + (p.v - mv) * dv >= 0
    end
    local function isect(a: Pt, b: Pt): Pt
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

local function dress(layoutR: any, opts: any)
    local rng = makeRng(opts.seed)
    local RW = opts.riserWidth or 6.4
    local RD = opts.riserDepth or 0.45
    local splitFrac = opts.splitFrac or 0.35
    local HW = opts.flagHW or 2.7
    local minDepth = opts.flagMinDepth or 0.4
    local bedW = opts.bedW or 5.8
    local bedH = opts.bedH or 1.2
    local out = {}
    for _, s in layoutR.steps :: { Step } do
        local isLanding = s.kind == "landing"
        local pitch = isLanding and (s.len :: number) or s.pitch
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

local AssetService = game:GetService("AssetService")

assert(#CONFIG.control >= 2, "CONFIG.control is empty — paste a baked centerline first")

local old = workspace:FindFirstChild(CONFIG.outModel)
if old then
    old:Destroy()
end
local model = Instance.new("Model")
model.Name = CONFIG.outModel
model.Parent = workspace

local polyline = resample(CONFIG.control, CONFIG.resampleSpacing)
local layoutR = layout(polyline, {
    riserTarget = CONFIG.riserTarget,
    footY = CONFIG.footY,
    headY = CONFIG.headY,
    landings = CONFIG.landings,
})
local dressed = dress(layoutR, CONFIG)

-- step frames for world conversion (front + axes per entry)
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
        { Name = "ZenFlagTreads", Description = CONFIG.outModel .. " flags chunk " .. chunkIdx }
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
    mp.Parent = model
    table.insert(report, string.format("Flags_%d: %d flags, asset %d", chunkIdx, emFlags, assetId))
    chunkIdx += 1
    emFlags = 0
    em = AssetService:CreateEditableMesh()
end

for _, e in dressed do
    if CONFIG.buildRange and (e.i < CONFIG.buildRange[1] or e.i > CONFIG.buildRange[2]) then
        continue
    end
    local s = stepByI[e.i]
    local pitch = (s.kind == "landing") and (s.len :: number) or s.pitch
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
    local bed = mkPart("Step_" .. e.i, e.bed, Enum.Material.Concrete, CONFIG.bedColor)
    if CONFIG.bedVariant ~= "" then
        bed.MaterialVariant = CONFIG.bedVariant
    end
    for _, f in e.flags do
        local topY = s.tread + f.topJitter
        local col = f.warm and Color3.fromRGB(f.g + 8, f.g, f.g - 12) or Color3.fromRGB(f.g, f.g + 1, f.g - 3)
        local cTop, cSide = em:AddColor(col, 1), em:AddColor(CONFIG.flagSideColor, 1)
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
    if emFlags >= CONFIG.chunkFlags then
        publishChunk()
    end
end
publishChunk()
print(("%s: %d steps dressed; %s"):format(CONFIG.outModel, made, table.concat(report, "; ")))
