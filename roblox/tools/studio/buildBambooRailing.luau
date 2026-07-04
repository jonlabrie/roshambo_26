--!strict
-- buildBambooRailing — runs a continuous bamboo railing along a path's open-air edge.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into Workspace.PathRailings
-- (one sub-Model "Rail_<name>" per run) and is idempotent (clears that sub-Model first).
--
-- The look (locked v2.1, user-approved 2026-07-02; deployed canyon-wide with the ishidan reskin):
--   * bamboo tan 118/95/52.
--   * LINE GENERATION (v2.1): the edge points are linearly resampled at an even 1.5 studs and
--     relaxed with 4 Laplacian passes (endpoints pinned), and the rails run straight through the
--     result. The old approach (Catmull-Rom through raw step points) OVERSHOT wherever control
--     spacing or grade changed — e.g. sagged across the PathExtension/PathSteps seam. The relax
--     method is identical on uniform runs and clean at seams, and it made `jitScale` obsolete.
--   * top rail   — dia 0.32 at +2.9 over the smoothed line.
--   * mid rail   — dia 0.22 at +1.25 with a seeded low-frequency WOBBLE (amp 0.154 lateral +
--                  0.7x vertical, ~7-stud wavelength) applied ON TOP of the smooth line — the
--                  hand-lashed look, independent of step density.
--   * node rings — rounded ellipsoid collars (sphere mesh: radial +0.022, swell 0.16, 96/76/40)
--                  every ~2.2-3.1 studs on both rails + 3 per post. Geometry, not texture:
--                  world-space materials can't band along the culm.
--   * posts      — vertical bamboo dia 0.36 x 3.25 (~2in proud of the top-rail crown) every
--                  ~7 STUDS of arc (postSpacing), collars at 0.95/2.0/3.12.
--   * barrier    — invisible CanCollide boxes (15 tall, 0.4 thick) along the line.
-- A run may span MULTIPLE contiguous path models (`paths` list) — rail them as ONE line; a
-- separate run per model + a straight Connector kinks at the seam (the lesson of 2026-07-02).
-- The edge line follows each Step bed's +/-RightVector end (HW studs from centre), baseline =
-- bed top. Geometry is PLACE-ONLY (not Rojo) — SAVE THE PLACE after running.
local ws = workspace

-- one entry per railing run. edgeSign: -1 = the -RightVector end, +1 = +RightVector (the side
-- facing the open-air drop; probe terrain if unsure). paths are stitched in walk order.
local RUNS = {
    -- PathExtension (4 preserved + 2 seam-bridge steps) flowing into PathSteps (47 steps): ONE line.
    {
        name = "PathSteps",
        paths = {
            { path = "PathExtension", i0 = 0, i1 = 5 },
            { path = "PathSteps", i0 = 0, i1 = 46 },
        },
        edgeSign = -1,
    },
    -- DescentPath: 26 relayout steps, downhill +Right.
    { name = "DescentPath", paths = { { path = "DescentPath", i0 = 0, i1 = 25 } }, edgeSign = 1 },
    -- NW1012 west traverse: downhill +Right (uphill holds the timber wall).
    { name = "NW1012West", paths = { { path = "NW1012West", i0 = 0, i1 = 56 } }, edgeSign = 1 },
    -- NW1211: 10 relayout steps, drop side -Right.
    { name = "NW1211", paths = { { path = "NW1211Path", i0 = 0, i1 = 9 } }, edgeSign = -1 },
    -- NW2040: 50 relayout steps, DOWNHILL (+Right) ONLY (uphill rail removed per user), THREE
    -- segments with two openings (as-built 2026-07-04, canonical v2.1 rebuild): steps 11-13 =
    -- Teahouse_02 access (below NearWall_30); steps 20-22 = Teahouse3Bridge landing at Step_21
    -- (see buildBridge.luau). Segment-end posts frame both openings. If you rebuild, keep BOTH
    -- gaps or you fence off a teahouse/the bridge.
    { name = "NW2040_S1", paths = { { path = "NW2040Path", i0 = 0, i1 = 10 } }, edgeSign = 1 },
    { name = "NW2040_S2", paths = { { path = "NW2040Path", i0 = 14, i1 = 19 } }, edgeSign = 1 },
    { name = "NW2040_S3", paths = { { path = "NW2040Path", i0 = 23, i1 = 49 } }, edgeSign = 1 },
    -- NW_40 flight (valley: two ishidan models meeting at the NW_52 bench; foot step of each removed
    -- for the BenchLanding). Downhill/canyon edge: descent = -Right, climb = +Right (climb's cliff
    -- -Right holds NWFallsWall). Continuous runs; the BenchLanding's open canyon edge = the T07 access.
    { name = "NW40Descent", paths = { { path = "NW40Descent", i0 = 1, i1 = 17 } }, edgeSign = -1 },
    { name = "NW80FallsStair", paths = { { path = "NW80FallsStair", i0 = 1, i1 = 76 } }, edgeSign = 1 },
}

-- ===== locked constants (v2.1, 2026-07-02) =====
local HW = 3.0 -- studs from bed centre to its end (the edge line)
local TOPY, TOP_DIA = 2.9, 0.32
local MIDY, MID_DIA = 1.25, 0.22
local POSTH, POST_DIA, POST_SPACING = 3.25, 0.36, 7
local RESAMPLE, RELAX_PASSES = 1.5, 4
local WOB_AMP, WOB_WAVE, WOB_SEED = 0.154, 7, 20260629
local BARRIER_H, BARRIER_T = 15, 0.4
local WOOD = Color3.fromRGB(118, 95, 52)
local NODE_COL = Color3.fromRGB(96, 76, 40)
local NODE_BULGE, NODE_SWELL, NODE_SEED = 0.022, 0.16, 20260715
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder long axis is local X

local function cyl(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = Enum.PartType.Cylinder
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.Color = WOOD
    p.Material = Enum.Material.Wood
    p.Parent = parent
    return p
end

local function nodeRing(parent: Instance, pos: Vector3, axis: Vector3, dia: number)
    local p = Instance.new("Part")
    p.Name = "Node"
    p.Anchored = true
    p.CanCollide = false
    p.Color = NODE_COL
    p.Material = Enum.Material.Wood
    p.Size = Vector3.new(dia + NODE_BULGE, dia + NODE_BULGE, NODE_SWELL)
    p.CFrame = CFrame.lookAt(pos, pos + axis)
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = p
    p.Parent = parent
end

local function makeRng(seed: number): () -> number
    local state = seed % 2 ^ 32
    return function(): number
        state = (1664525 * state + 1013904223) % 2 ^ 32
        return state / 2 ^ 32
    end
end

local function linResample(pts: { Vector3 }, spacing: number): { Vector3 }
    local out = { pts[1] }
    local carry = 0
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local seg = (b - a).Magnitude
        local d = spacing - carry
        while d <= seg do
            out[#out + 1] = a:Lerp(b, d / seg)
            d += spacing
        end
        carry = seg - (d - spacing)
    end
    out[#out + 1] = pts[#pts]
    return out
end

local function relax(pts: { Vector3 }, passes: number): { Vector3 }
    for _ = 1, passes do
        local nxt = { pts[1] }
        for i = 2, #pts - 1 do
            nxt[i] = pts[i] * 0.5 + (pts[i - 1] + pts[i + 1]) * 0.25
        end
        nxt[#pts] = pts[#pts]
        pts = nxt
    end
    return pts
end

local function railThrough(parent: Instance, dense: { Vector3 }, dia: number)
    for i = 1, #dense - 1 do
        local a, b = dense[i], dense[i + 1]
        cyl(
            parent,
            "Rail",
            Vector3.new((b - a).Magnitude + dia * 0.5, dia, dia),
            CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
        )
    end
    for i = 1, #dense do
        local j = cyl(parent, "Joint", Vector3.new(dia, dia, dia), CFrame.new(dense[i]))
        j.Shape = Enum.PartType.Ball
    end
end

local function nodesAlong(parent: Instance, dense: { Vector3 }, dia: number)
    local rng = makeRng(NODE_SEED)
    local nextAt = 1.6 + rng()
    local acc = 0
    for i = 1, #dense - 1 do
        local a, b = dense[i], dense[i + 1]
        local seg = (b - a).Magnitude
        while acc + seg >= nextAt do
            nodeRing(parent, a:Lerp(b, (nextAt - acc) / seg), b - a, dia)
            nextAt = nextAt + 2.2 + rng() * 0.9
        end
        acc += seg
    end
end

local function buildOne(run): string
    -- ordered edge points across the run's stitched paths
    local base: { Vector3 } = {}
    for _, seg in run.paths do
        local model = ws:FindFirstChild(seg.path)
        assert(model, "missing Workspace." .. seg.path)
        for i = seg.i0, seg.i1 do
            local t = model:FindFirstChild("Step_" .. i) :: BasePart?
            if t then
                local r = t.CFrame.RightVector
                local rh = Vector3.new(r.X, 0, r.Z).Unit
                base[#base + 1] = Vector3.new(t.Position.X, t.Position.Y + t.Size.Y / 2, t.Position.Z)
                    + rh * (HW * run.edgeSign)
            end
        end
    end
    assert(#base >= 2, "need >= 2 steps for " .. run.name)
    local pts = relax(linResample(base, RESAMPLE), RELAX_PASSES)

    local parent = ws:FindFirstChild("PathRailings") or Instance.new("Model")
    parent.Name = "PathRailings"
    parent.Parent = ws
    local sub = parent:FindFirstChild("Rail_" .. run.name)
    if sub then
        sub:Destroy()
    end
    sub = Instance.new("Model")
    sub.Name = "Rail_" .. run.name
    sub.Parent = parent

    -- top rail
    local topLine = {}
    for _, p in pts do
        topLine[#topLine + 1] = p + Vector3.new(0, TOPY, 0)
    end
    railThrough(sub, topLine, TOP_DIA)
    nodesAlong(sub, topLine, TOP_DIA)

    -- mid rail: low-frequency wobble over the smooth line
    local jr = makeRng(WOB_SEED)
    local wobA, wobB, tacc = (jr() * 2 - 1) * WOB_AMP, (jr() * 2 - 1) * WOB_AMP, 0
    local midLine = {}
    for i, p in pts do
        if i > 1 then
            tacc += (pts[i] - pts[i - 1]).Magnitude
        end
        if tacc > WOB_WAVE then
            wobA, wobB = wobB, (jr() * 2 - 1) * WOB_AMP
            tacc -= WOB_WAVE
        end
        local f = tacc / WOB_WAVE
        local w = wobA * (1 - f) + wobB * f
        local dirN = pts[math.min(i + 1, #pts)] - pts[math.max(i - 1, 1)]
        dirN = Vector3.new(dirN.X, 0, dirN.Z)
        dirN = dirN.Magnitude > 0 and dirN.Unit or Vector3.new(1, 0, 0)
        local perp = Vector3.new(dirN.Z, 0, -dirN.X)
        midLine[#midLine + 1] = p + Vector3.new(0, MIDY + w * 0.7, 0) + perp * w
    end
    railThrough(sub, midLine, MID_DIA)
    nodesAlong(sub, midLine, MID_DIA)

    -- posts every POST_SPACING studs of arc
    local posts = 0
    local acc, nextPost = 0, 0.5
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local seg = (b - a).Magnitude
        while acc + seg >= nextPost do
            local p = a:Lerp(b, (nextPost - acc) / seg)
            cyl(
                sub,
                "Post_" .. posts,
                Vector3.new(POSTH, POST_DIA, POST_DIA),
                CFrame.new(p + Vector3.new(0, POSTH / 2, 0)) * VERT
            )
            for _, hy in { 0.95, 2.0, 3.12 } do
                nodeRing(sub, p + Vector3.new(0, hy, 0), Vector3.yAxis, POST_DIA)
            end
            posts += 1
            nextPost += POST_SPACING
        end
        acc += seg
    end

    -- invisible fall barriers along the line
    for i = 1, #pts - 1, 2 do
        local a, b = pts[i], pts[math.min(i + 2, #pts)]
        local midXZ = (a + b) / 2
        local len = (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
        local cy = (a.Y + b.Y) / 2 + BARRIER_H / 2
        local bar = Instance.new("Part")
        bar.Name = "Barrier_" .. i
        bar.Anchored = true
        bar.CanCollide = true
        bar.Transparency = 1
        bar.CastShadow = false
        bar.Size = Vector3.new(len + BARRIER_T, BARRIER_H, BARRIER_T)
        bar.CFrame = CFrame.lookAt(Vector3.new(midXZ.X, cy, midXZ.Z), Vector3.new(b.X, cy, b.Z))
            * CFrame.Angles(0, math.rad(90), 0)
        bar.Parent = sub
    end
    return string.format("%s: %d line pts, %d posts", run.name, #pts, posts)
end

-- ===== deploy =====
local report = {}
for _, run in RUNS do
    report[#report + 1] = buildOne(run)
end
return table.concat(report, "\n")
