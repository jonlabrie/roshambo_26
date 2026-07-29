--!strict
-- buildBambooRailing — runs a continuous bamboo railing along a path's open-air edge.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into
-- Workspace.CanyonWorld.Paths.PathRailings (one sub-Model "Rail_<name>" per run) and is idempotent
-- (clears that sub-Model first). Paths are read from CanyonWorld.Paths (ws-root fallback for legacy).
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
    -- NW1211: 11 steps (foot step added 2026-07-04), drop side -Right, NARROWED path (-25% width)
    -- so hw=2.25 (default 3.0) keeps the rail at the new riser edge.
    {
        name = "NW1211",
        paths = { { path = "NW1211Path", i0 = 0, i1 = 10 } },
        edgeSign = -1,
        hw = 2.25,
        postEnds = true,
    },
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
    -- River path chapter 1: the Square stairway. Wider than the rest of the network
    -- (bed 8.0, not 5.8), so hw = 4.0 rather than the 3.0 default -- otherwise the rail
    -- floats a stud inboard of the tread edge. +Right is NORTH here, which is the side
    -- the ground falls away on (-1.5 to -2.5 below tread); the -Right south side is the
    -- cut bank (+4.2 to +8.2 above) and takes the timber retaining wall, not a rail.
    {
        name = "RiverSquareStair",
        paths = { { path = "RiverSquareStair", i0 = 0, i1 = 41 } },
        edgeSign = 1,
        hw = 4.0,
    },
    -- Far-Wall flat-shelf promenades (buildFlatShelfPath.luau): near-level curved shelves whose short
    -- ~6-stud treads swing the RightVector fast through the bend. The v2.1 Laplacian relax BOWS the
    -- line off that curve and floats posts over the drop, so these use noRelax (line runs straight
    -- through the tread-edge points) + clampEnds (start/stop flush with the tread ends) + hw = bedW/2
    -- (2.9 for the 5.8-wide beds). Drop/open edge is -Right on both; chochins go on the +Right wall.
    {
        name = "FarWall7282",
        paths = { { path = "FarWall7282Path", i0 = 0, i1 = 11 } },
        edgeSign = -1,
        hw = 2.9,
        noRelax = true,
        clampEnds = true,
    },
    {
        name = "FarWallBridge2",
        paths = { { path = "FarWallBridge2Path", i0 = 0, i1 = 9 } },
        edgeSign = -1,
        hw = 2.9,
        noRelax = true,
        clampEnds = true,
    },
    -- FarWall5063 shelf promenade (6 gentle ishidan steps; top Step_6 removed for the junction).
    -- Open/drop edge = -Right (the +Right cut face holds TimberWall_FarWall5063Path_0_3). Chōchin on
    -- the +Right wall side at Step_4 (past the wall) — see buildChochinPole/recipe.
    {
        name = "FarWall5063",
        paths = { { path = "FarWall5063Path", i0 = 0, i1 = 5 } },
        edgeSign = -1,
        hw = 2.9,
        noRelax = true,
        clampEnds = true,
    },
    -- T11 spur off the junction (short 6-step spur to Teahouse_11): open/drop edge = +Right
    -- (the -4..-6 side); the -Right wall side stays clear. Rail-only (no chōchin — too short).
    {
        name = "FarWall_T11Spur",
        paths = { { path = "FarWall_T11Spur", i0 = 0, i1 = 5 } },
        edgeSign = 1,
        hw = 2.9,
        noRelax = true,
        clampEnds = true,
    },
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
    -- run.hw overrides the default edge offset for narrowed paths (NW1211 at -25% width, 2026-07-04)
    local hw = run.hw or HW
    -- paths live under CanyonWorld.Paths (post-2026-07-08 reorg); fall back to ws root for any legacy.
    local pathsRoot = ws.CanyonWorld.Paths
    local base: { Vector3 } = {}
    local firstT: BasePart?, lastT: BasePart? = nil, nil
    for _, seg in run.paths do
        local model = pathsRoot:FindFirstChild(seg.path) or ws:FindFirstChild(seg.path)
        -- Skip, do not assert. RUNS is a growing ledger of every railed stretch, and a
        -- model that has been renamed or retired (NW1211Path, 2026-07-29) would otherwise
        -- abort the whole deploy and silently drop every run listed after it.
        if not model then
            return ("%s: SKIPPED — path model %q is not in this place"):format(run.name, seg.path)
        end
        for i = seg.i0, seg.i1 do
            local t = model:FindFirstChild("Step_" .. i) :: BasePart?
            if t then
                local r = t.CFrame.RightVector
                local rh = Vector3.new(r.X, 0, r.Z).Unit
                base[#base + 1] = Vector3.new(t.Position.X, t.Position.Y + t.Size.Y / 2, t.Position.Z)
                    + rh * (hw * run.edgeSign)
                firstT = firstT or t
                lastT = t
            end
        end
    end
    assert(#base >= 2, "need >= 2 steps for " .. run.name)
    -- clampEnds (flat-shelf variant): extend the line half a tread past the first/last step CENTRE
    -- along that step's travel, so the rail starts/stops flush with the tread ends (no overshoot).
    if run.clampEnds and firstT and lastT then
        local lk0 = firstT.CFrame.LookVector
        lk0 = Vector3.new(lk0.X, 0, lk0.Z).Unit
        local lkN = lastT.CFrame.LookVector
        lkN = Vector3.new(lkN.X, 0, lkN.Z).Unit
        table.insert(base, 1, base[1] - lk0 * (firstT.Size.Z / 2))
        base[#base + 1] = base[#base] + lkN * (lastT.Size.Z / 2)
    end
    -- noRelax (flat-shelf variant): run the line straight through the tread-edge points. The Laplacian
    -- relax BOWS the line off a tight curve and floats posts over the drop — the short-tread shelves
    -- need the true edge. Long ishidan runs keep the relax (clean at seams, no overshoot).
    local pts = run.noRelax and linResample(base, RESAMPLE)
        or relax(linResample(base, RESAMPLE), RELAX_PASSES)

    local parent = pathsRoot:FindFirstChild("PathRailings") or Instance.new("Model")
    parent.Name = "PathRailings"
    parent.Parent = pathsRoot
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

    -- post arc positions. Default: every POST_SPACING from 0.5 (open-ended, fine for long runs).
    -- run.postEnds = true: evenly spaced with a post AT EACH END — short runs otherwise leave the
    -- cap cantilevering past the last post into space and float the foot post (bit us on NW1211,
    -- 2026-07-04). n = round(arc/POST_SPACING)+1, so interior spacing stays near POST_SPACING.
    local totalArc = 0
    for i = 1, #pts - 1 do
        totalArc += (pts[i + 1] - pts[i]).Magnitude
    end
    local postArcs = {}
    if run.postEnds then
        local n = math.max(2, math.floor(totalArc / POST_SPACING + 0.5) + 1)
        for k = 0, n - 1 do
            postArcs[#postArcs + 1] = totalArc * k / (n - 1)
        end
    else
        local a = 0.5
        while a < totalArc do
            postArcs[#postArcs + 1] = a
            a += POST_SPACING
        end
    end
    local posts = 0
    local acc, pi = 0, 1
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local seg = (b - a).Magnitude
        while pi <= #postArcs and postArcs[pi] <= acc + seg + 1e-6 do
            local p = a:Lerp(b, seg > 1e-9 and math.clamp((postArcs[pi] - acc) / seg, 0, 1) or 0)
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
            pi += 1
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
