--!strict
-- buildBambooRailing — runs a continuous bamboo railing along a path's open-air edge.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into Workspace.PathRailings
-- (one sub-Model "Rail_<name>" per run) and is idempotent (clears that sub-Model first).
--
-- The look (locked prototype, user-approved 2026-06-29):
--   * top rail   — SMOOTH continuous Catmull-Rom run (dia 0.32) at +2.9 over the edge baseline.
--   * mid rail   — the SAME run dia 0.22 at +1.25, but its 21 control points get low-frequency
--                  lateral+vertical JITTER before the spline, so it carries a gentle hand-built
--                  wobble (rustic / "lashed on site") while the top rail stays true.
--   * posts      — vertical bamboo (dia 0.45 × 3.0) every 2 timbers at the edge baseline.
--   * barrier    — an invisible CanCollide box per gap (10 tall, 0.4 thick) so players can't fall
--                  through the open rail. Transparency 1 → reads only the bamboo.
-- The edge line follows each timber's ±RightVector END (HW studs from centre), baseline = timber top.
-- Geometry is PLACE-ONLY (not Rojo) — SAVE THE PLACE after running.
local ws = workspace

-- one entry per path to rail. edgeSign: -1 = the -RightVector end, +1 = the +RightVector end (the
-- timber end facing the open-air drop; see the per-path terrain probe in the build-recipes doc).
local RUNS = {
    -- PathSteps: one continuous run, downhill side (-Right), the entire path.
    { name = "PathSteps", path = "PathSteps", prefix = "Timber", i0 = 0, i1 = 47, edgeSign = -1 },
    -- PathExtension: drop side (-Right), opposite the terrain side.
    { name = "PathExtension", path = "PathExtension", prefix = "ExtTimber", i0 = 1, i1 = 5, edgeSign = -1 },
    -- DescentPath: downhill side (+Right, the finite-drop edge; -Right is the cliff/wall), full length.
    -- Bottom stands alone; the top (DescTimber_2) will later meet a deck-style railing (built separately).
    { name = "DescentPath", path = "DescentPath", prefix = "DescTimber", i0 = 2, i1 = 20, edgeSign = 1 },
    -- NW1012 west traverse (ishidan steps, pitch 1.23 -> postEvery 5 ≈ the old 2-timber cadence).
    -- Downhill/open side is +Right (uphill -Right holds the timber wall). South flight is a walled
    -- cutting with no open edge — deliberately un-railed. The LandingDeck is bare by user decision.
    {
        name = "NW1012West",
        path = "NW1012West",
        prefix = "Step",
        i0 = 0,
        i1 = 56,
        edgeSign = 1,
        postEvery = 5,
    },
}

-- Connectors bridge a gap between two run endpoints with a straight top+mid rail (and barrier),
-- so adjacent path sections read as one continuous railing. Each side names the timber whose edge
-- the run terminates on (the run's i0 or i1) and that run's edgeSign.
local CONNECTORS = {
    { -- PathSteps T0 <-> PathExtension E1 (the ~4.4-stud seam where the two sections meet)
        a = { path = "PathSteps", prefix = "Timber", i = 0, edgeSign = -1 },
        b = { path = "PathExtension", prefix = "ExtTimber", i = 1, edgeSign = -1 },
    },
}

-- ===== locked constants =====
local HW = 3.0 -- studs from timber centre to its end (the edge line)
local TOPY, TOP_DIA = 2.9, 0.32 -- top rail height over baseline / diameter
local MIDY, MID_DIA = 1.25, 0.22 -- mid rail height / diameter
local POSTH, POST_DIA, POST_EVERY = 3.0, 0.45, 2 -- post height / diameter / timbers between posts
local S = 4 -- Catmull-Rom subdivisions per control segment
local JIT_LAT, JIT_VERT, SEED = 0.154, 0.112, 20260629 -- mid-rail control-point jitter + seed
local BARRIER_H, BARRIER_T = 15, 0.4 -- invisible fall-barrier box height / thickness (clears rail-cap + jump)
local WOOD = Color3.fromRGB(70, 55, 32) -- dark bamboo
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder long axis is local X; vertical needs this

local function cyl(parent: Instance, name: string, size: Vector3, cf: CFrame)
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

-- horizontal unit vector along a timber's +RightVector
local function horizRight(t: BasePart): Vector3
    local r = t.CFrame.RightVector
    return Vector3.new(r.X, 0, r.Z).Unit
end

local function cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
    local t2, t3 = t * t, t * t * t
    return 0.5
        * ((p1 * 2) + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3)
end

-- dense-sample a Catmull-Rom spline through `pts` (S subdivisions per segment, endpoints included)
local function densify(pts: { Vector3 }): { Vector3 }
    local dense = {}
    for i = 1, #pts - 1 do
        local p0 = pts[math.max(i - 1, 1)]
        local p1, p2 = pts[i], pts[i + 1]
        local p3 = pts[math.min(i + 2, #pts)]
        local last = (i == #pts - 1) and S or (S - 1)
        for s = 0, last do
            dense[#dense + 1] = cr(p0, p1, p2, p3, s / S)
        end
    end
    return dense
end

-- build a continuous rail (cylinder segments + ball joints) through dense points
local function buildRail(parent: Instance, dense: { Vector3 }, dia: number)
    for i = 1, #dense - 1 do
        local a, b = dense[i], dense[i + 1]
        local seg = cyl(
            parent,
            "Rail",
            Vector3.new((b - a).Magnitude + dia * 0.5, dia, dia),
            CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
        )
        seg.Name = "Rail"
    end
    for i = 1, #dense do
        local j = cyl(parent, "Joint", Vector3.new(dia, dia, dia), CFrame.new(dense[i]))
        j.Shape = Enum.PartType.Ball
        j.Name = "Joint"
    end
end

local function buildOne(run): string
    local model = ws:FindFirstChild(run.path)
    assert(model, "missing Workspace." .. run.path)

    -- edge control points (timber end on the chosen side, baseline = timber top)
    local base = {}
    for i = run.i0, run.i1 do
        local t = model:FindFirstChild(run.prefix .. "_" .. i) :: BasePart?
        if t then
            local rh = horizRight(t)
            local edge = Vector3.new(t.Position.X, t.Position.Y + t.Size.Y / 2, t.Position.Z)
                + rh * (HW * run.edgeSign)
            base[#base + 1] = edge
        end
    end
    assert(#base >= 2, "need >=2 timbers for " .. run.name)

    -- top rail: smooth (no jitter)
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

    local topPts = {}
    for _, p in base do
        topPts[#topPts + 1] = p + Vector3.new(0, TOPY, 0)
    end
    buildRail(sub, densify(topPts), TOP_DIA)

    -- mid rail: jitter the control points (low-frequency), then spline → rustic wobble
    math.randomseed(SEED)
    local midPts = {}
    for _, p in base do
        midPts[#midPts + 1] = p + Vector3.new(0, MIDY, 0)
    end
    for i = 2, #midPts - 1 do
        local tan = midPts[i + 1] - midPts[i - 1]
        tan = Vector3.new(tan.X, 0, tan.Z)
        tan = (tan.Magnitude > 0) and tan.Unit or Vector3.new(1, 0, 0)
        local perp = Vector3.new(tan.Z, 0, -tan.X)
        midPts[i] = midPts[i]
            + perp * ((math.random() * 2 - 1) * JIT_LAT)
            + Vector3.new(0, (math.random() * 2 - 1) * JIT_VERT, 0)
    end
    buildRail(sub, densify(midPts), MID_DIA)

    -- posts every postEvery timbers/steps (at the un-jittered baseline edge points)
    local posts = 0
    local postEvery = run.postEvery or POST_EVERY
    for k = 1, #base do
        if (k - 1) % postEvery == 0 then
            local p = base[k]
            cyl(
                sub,
                "Post_" .. (run.i0 + k - 1),
                Vector3.new(POSTH, POST_DIA, POST_DIA),
                CFrame.new(p + Vector3.new(0, POSTH / 2, 0)) * VERT
            )
            posts += 1
        end
    end

    -- invisible CanCollide fall-barrier per gap (rises BARRIER_H from the path edge)
    for i = 1, #base - 1 do
        local a, b = base[i], base[i + 1]
        local midXZ = (a + b) / 2
        local len = (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
        local cy = (a.Y + b.Y) / 2 + BARRIER_H / 2
        local bar = Instance.new("Part")
        bar.Name = "Barrier_" .. (run.i0 + i - 1)
        bar.Anchored = true
        bar.CanCollide = true
        bar.Transparency = 1
        bar.CastShadow = false -- invisible part still casts a shadow otherwise (15-stud shadow strip)
        bar.Size = Vector3.new(len + BARRIER_T, BARRIER_H, BARRIER_T)
        bar.CFrame = CFrame.lookAt(Vector3.new(midXZ.X, cy, midXZ.Z), Vector3.new(b.X, cy, b.Z))
            * CFrame.Angles(0, math.rad(90), 0)
        bar.Parent = sub
    end

    return string.format("%s: %d control pts, %d posts, %d barriers", run.name, #base, posts, #base - 1)
end

-- edge point (timber end, baseline = timber top) for a connector endpoint spec
local function edgeOf(spec): Vector3
    local model = ws:FindFirstChild(spec.path)
    assert(model, "missing Workspace." .. spec.path)
    local t = model:FindFirstChild(spec.prefix .. "_" .. spec.i) :: BasePart
    assert(t, "missing " .. spec.path .. "." .. spec.prefix .. "_" .. spec.i)
    local rh = horizRight(t)
    return Vector3.new(t.Position.X, t.Position.Y + t.Size.Y / 2, t.Position.Z) + rh * (HW * spec.edgeSign)
end

-- straight top+mid rail (and invisible barrier) bridging two run endpoints
local function buildConnector(parent: Instance, conn, n: number)
    local sub = Instance.new("Model")
    sub.Name = "Connector_" .. n
    sub.Parent = parent
    local a, b = edgeOf(conn.a), edgeOf(conn.b)
    for _, lvl in { { y = TOPY, dia = TOP_DIA }, { y = MIDY, dia = MID_DIA } } do
        local pa, pb = a + Vector3.new(0, lvl.y, 0), b + Vector3.new(0, lvl.y, 0)
        local seg = cyl(
            sub,
            "Rail",
            Vector3.new((pb - pa).Magnitude + lvl.dia * 0.5, lvl.dia, lvl.dia),
            CFrame.lookAt((pa + pb) / 2, pb) * CFrame.Angles(0, math.rad(90), 0)
        )
        seg.Name = "Rail"
        for _, p in { pa, pb } do
            local j = cyl(sub, "Joint", Vector3.new(lvl.dia, lvl.dia, lvl.dia), CFrame.new(p))
            j.Shape = Enum.PartType.Ball
            j.Name = "Joint"
        end
    end
    local midXZ = (a + b) / 2
    local len = (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
    local cy = (a.Y + b.Y) / 2 + BARRIER_H / 2
    local bar = Instance.new("Part")
    bar.Name = "Barrier"
    bar.Anchored = true
    bar.CanCollide = true
    bar.Transparency = 1
    bar.CastShadow = false -- invisible part still casts a shadow otherwise (15-stud shadow strip)
    bar.Size = Vector3.new(len + BARRIER_T, BARRIER_H, BARRIER_T)
    bar.CFrame = CFrame.lookAt(Vector3.new(midXZ.X, cy, midXZ.Z), Vector3.new(b.X, cy, b.Z))
        * CFrame.Angles(0, math.rad(90), 0)
    bar.Parent = sub
    return string.format("Connector_%d: %.1f-stud bridge", n, len)
end

-- ===== deploy =====
-- drop the old single-prototype model if present (superseded by per-run sub-models)
local pr = ws:FindFirstChild("PathRailings")
if pr then
    local old = pr:FindFirstChild("Rail_PROTO")
    if old then
        old:Destroy()
    end
    for _, c in pr:GetChildren() do
        if c.Name:match("^Connector_") then
            c:Destroy()
        end
    end
end

local report = {}
for _, run in RUNS do
    report[#report + 1] = buildOne(run)
end
local parent = ws:FindFirstChild("PathRailings")
for i, conn in CONNECTORS do
    report[#report + 1] = buildConnector(parent, conn, i)
end
return table.concat(report, "\n")
