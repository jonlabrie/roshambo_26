--!strict
-- buildChochinPole — places hanging paper chōchin on bamboo posts along a path's UPHILL edge.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into
-- CanyonWorld.Paths.PathLanterns (Workspace root only if CanyonWorld is absent)
-- and tags them so the committed controllers drive them:
--   * each barrel's two GlyphPlates are tagged "RoundLantern" -> LanternController paints the
--     World-Throw glyph (world-space SurfaceGui, perpendicular to the crosspiece, 20% transparent).
--   * each hanging "Swing" sub-model is tagged "ChochinSwing" -> ChochinSway rocks it gently.
-- Geometry is PLACE-ONLY (not Rojo) — SAVE THE PLACE after running. The lantern look is the locked
-- prototype recipe (see specs/2026-06-27-zendojo-path-railings-lanterns-design.md "As-built").
local CollectionService = game:GetService("CollectionService")
local ws = workspace

local CONFIG = {
    -- River path chapter 1: three composed lanterns rather than a rhythm — bottom south,
    -- middle north, top south, alternating up the flight (user-gated 2026-07-29). The
    -- contract part on an ishidan stair is Step_<i>, not Timber_<i>.
    -- Offsets come from `standoff` (added to the bed's own half-width), not absolutes.
    -- The two south poles take the network's 1.6 -> 5.6 on this 8.0-wide bed. The middle
    -- one stands OUTSIDE the bamboo rail, which needs 2.0 -> 6.0: at 5.6 it clears the
    -- rail by only 0.16 against its own 0.19 radius, so it would graze.
    path = "RiverSquareStair",
    timberPrefix = "Step",
    placements = {
        { step = 2, side = "south" },
        { step = 20, side = "north", standoff = 2.0 },
        { step = 39, side = "south" },
    },
    interval = 6, -- base timbers between poles (ignored when `placements` is set)
    posJitter = 0.35, -- ±fraction of a timber gap to stagger each pole along the path (~5-10% spacing)
    uphillOffset = 4.5, -- studs from the timber toward the cliff (uphill) edge
    -- ⚠️ uphillOffset above is an ABSOLUTE and only correct for the network's 5.8-wide
    -- beds, where it works out as half-width 2.9 + 1.6 of standoff. On a wider path it
    -- silently pulls the lanterns inboard. `placements` uses STANDOFF instead, added to
    -- each bed's measured half-width, which is width-independent.
    uphillSign = 1, -- which RightVector end is uphill/cliff: +1 PathSteps; -1 DescentPath (prefix "DescTimber")
    downhillFrac = 0.30, -- up to this FRACTION of the placed poles may sit on the DOWNHILL side, terrain permitting
    dhMaxDrop = 8, -- downhill pole placed only if terrain is within this many studs below the path
    seed = 20260629, -- deterministic stagger (same place each run)
    outModel = "PathLanterns", -- output model under CanyonWorld.Paths (per-path sub-model beneath it)
}

-- The network's lantern standoff, measured OUTBOARD FROM THE TREAD EDGE rather than from
-- the centreline: CONFIG.uphillOffset 4.5 minus a 5.8-wide bed's 2.9 half-width. Stated
-- this way it holds on any path width; stated as 4.5 it silently fails on wider ones.
local STANDOFF = 1.6

-- ===== locked colours / materials =====
local WOOD = Color3.fromRGB(70, 55, 32) -- dark bamboo post/arm/brace
local INK = Color3.fromRGB(46, 40, 30) -- ribs, caps
local METAL = Color3.fromRGB(120, 122, 128) -- hanging loop
local PAPER = { 200, 170, 143 } -- desaturated warm-cream paper base (gradient-scaled per slice)
local PAPER_T = 0.42
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder long axis is local X; vertical needs this

local function cyl(
    parent: Instance,
    name: string,
    size: Vector3,
    cf: CFrame,
    color: Color3,
    mat: Enum.Material,
    trans: number?
)
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = Enum.PartType.Cylinder
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.Color = color
    p.Material = mat
    p.Transparency = trans or 0
    p.Parent = parent
    return p
end

-- straight cylindrical middle, sharp-rounded shoulders to small caps (continuous → no brightness step)
-- ===== SCALE (owner-gated 2026-08-13) =====
-- The first deployment stood 12.8 studs with a 2.8 x 1.8 lantern. Against the shōrō and the
-- buildings it read as street furniture, not garden lighting: the lantern's underside sat ~9 studs
-- up, nearly two avatar-heights overhead. Rescaled to pole 9.4 with a 2.02 x 1.30 lantern, which
-- puts the underside at base + 6.49 — overhead, but lighting the path rather than the sky.
--
-- LS scales the LANTERN, PS the POLE AND ITS IRONMONGERY. They are separate on purpose, and
-- ARM_FRONT is scaled by NEITHER: the arm's reach exists to carry the lantern out over the path
-- and answers to STANDOFF (1.6), not to how tall the pole happens to be. Scaling it with the pole
-- once left the lanterns hanging beside the path instead of above it.
local LS = 0.65 / 0.9 -- lantern: Rmax 0.9 -> 0.65
local PS = 9.4 / 12.8 -- pole: 12.8 -> 9.4
local ARM_FRONT = 2.38 -- INVARIANT. Set by the path standoff. Do not scale.

local Rmax, capR = 0.9 * LS, 0.30 * LS
local function profile(tt: number): number
    local d = math.abs(2 * tt - 1)
    return capR + (Rmax - capR) * (1 - d ^ 6) ^ 0.5
end

-- Build ONE chōchin-on-pole at `base` (pole foot, ~path level) with `up` = uphill horizontal unit.
local function buildOne(parent: Instance, name: string, base: Vector3, up: Vector3)
    local model = Instance.new("Model")
    model.Name = name
    model.Parent = parent
    local swing = Instance.new("Model")
    swing.Name = "Swing"
    swing.Parent = model

    local perp = Vector3.new(-up.Z, 0, up.X).Unit -- horizontal, PERPENDICULAR to the crosspiece
    local perpAngle = math.atan2(perp.Z, perp.X)

    -- ----- bamboo frame (static) -----
    local poleH, poleDia = 12.8 * PS, 0.38 * PS
    local poleR = poleDia / 2
    cyl(
        model,
        "Pole",
        Vector3.new(poleH, poleDia, poleDia),
        CFrame.new(base + Vector3.new(0, poleH / 2, 0)) * VERT,
        WOOD,
        Enum.Material.Wood
    )
    local armY = base.Y + poleH - 0.5
    local H = Vector3.new(0, poleH - 0.5, 0)
    local armFront, armBack, armDia = ARM_FRONT, poleR + 0.12, 0.225 * PS
    local armEnd = base + -up * armFront + H
    local nearEnd = base + up * armBack + H
    local armMid = (armEnd + nearEnd) / 2
    cyl(
        model,
        "CrossArm",
        Vector3.new(armFront + armBack, armDia, armDia),
        CFrame.lookAt(armMid, armMid + -up) * CFrame.Angles(0, math.rad(90), 0),
        WOOD,
        Enum.Material.Wood
    )
    do -- diagonal knee brace
        local poleP = Vector3.new(base.X, armY - 1.4 * PS, base.Z)
        local armP = base + -up * 1.1 + H
        local mid = (poleP + armP) / 2
        cyl(
            model,
            "Brace",
            Vector3.new((armP - poleP).Magnitude, 0.18 * PS, 0.18 * PS),
            CFrame.lookAt(mid, armP) * CFrame.Angles(0, math.rad(90), 0),
            WOOD,
            Enum.Material.Wood
        )
    end

    -- ----- metal loop draped over the crosspiece end (in Swing) -----
    local ringR, tubeR = 0.22 * LS, 0.05 * LS
    local ringCenter = Vector3.new(armEnd.X, armY - ringR, armEnd.Z)
    local e1 = Vector3.new(0, 1, 0)
    local e2 = (-up):Cross(e1).Unit
    for i = 0, 13 do
        local a0, a1 = 2 * math.pi * i / 14, 2 * math.pi * (i + 1) / 14
        local p0 = ringCenter + ringR * (math.cos(a0) * e1 + math.sin(a0) * e2)
        local p1 = ringCenter + ringR * (math.cos(a1) * e1 + math.sin(a1) * e2)
        cyl(
            swing,
            "LoopSeg_" .. i,
            Vector3.new((p1 - p0).Magnitude + 0.02, 2 * tubeR, 2 * tubeR),
            CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0),
            METAL,
            Enum.Material.Metal
        )
    end

    -- ----- paper barrel (in Swing): 18-slice stack, vertical gradient (centre bright, top dimmer) -----
    local bodyH = 2.8 * LS
    local ringBottom = armY - 2 * ringR
    local lc = Vector3.new(armEnd.X, ringBottom - 0.13 * LS - bodyH / 2 + 0.05 * LS, armEnd.Z)
    local N = 18
    local centerIdx = math.floor(N / 2)
    local body
    for i = 0, N - 1 do
        local tt = (i + 0.5) / N
        local r = profile(tt)
        local y = lc.Y + (tt - 0.5) * bodyH
        local d = math.abs(2 * tt - 1)
        local f = math.clamp(1 - 0.22 * d - (tt > 0.5 and 0.15 * (2 * tt - 1) or 0), 0.4, 1) -- top dimmer
        local nm = (i == centerIdx) and "ChochinBody" or ("Slice_" .. i)
        local part = cyl(
            swing,
            nm,
            Vector3.new(bodyH / N * 1.15, 2 * r, 2 * r),
            CFrame.new(lc.X, y, lc.Z) * VERT,
            Color3.fromRGB(PAPER[1] * f, PAPER[2] * f, PAPER[3] * f),
            Enum.Material.Neon,
            PAPER_T
        )
        if i == centerIdx then
            body = part
        end
    end
    -- horizontal ribs (thin)
    for j = 1, 16 do
        local tt = (j - 0.5) / 16
        local r = profile(tt) + 0.05 * LS
        local y = lc.Y + (tt - 0.5) * bodyH
        cyl(
            swing,
            "Rib_" .. j,
            Vector3.new(0.025, 2 * r, 2 * r),
            CFrame.new(lc.X, y, lc.Z) * VERT,
            INK,
            Enum.Material.Wood
        )
    end
    -- 6 vertical ribs (thin struts), offset 30° so the glyph faces sit centred between them,
    -- spanning the straight zone (horizontal ribs j4..j13) so the ends don't poke past the curve
    local tt4, tt13 = (4 - 0.5) / 16, (13 - 0.5) / 16
    local y4, y13 = lc.Y + (tt4 - 0.5) * bodyH, lc.Y + (tt13 - 0.5) * bodyH
    local Rv = Rmax + 0.05 * LS
    for k = 0, 5 do
        local a = perpAngle + math.rad(30 + k * 60)
        local pos = Vector3.new(lc.X + Rv * math.cos(a), (y4 + y13) / 2, lc.Z + Rv * math.sin(a))
        cyl(
            swing,
            "VRib_" .. k,
            Vector3.new(y13 - y4, 0.03, 0.03),
            CFrame.new(pos) * VERT,
            INK,
            Enum.Material.Wood
        )
    end
    -- small dark caps (-40% dia)
    cyl(
        swing,
        "CapTop",
        Vector3.new(0.26 * LS, 0.66 * LS, 0.66 * LS),
        CFrame.new(lc + Vector3.new(0, bodyH / 2, 0)) * VERT,
        INK,
        Enum.Material.Wood
    )
    cyl(
        swing,
        "CapBot",
        Vector3.new(0.26 * LS, 0.66 * LS, 0.66 * LS),
        CFrame.new(lc - Vector3.new(0, bodyH / 2, 0)) * VERT,
        INK,
        Enum.Material.Wood
    )

    -- soft warm glow sprite (replaces the Neon balls): a feathered radial bloom that reads as
    -- lamplight rather than a sphere; one camera-facing quad → lighter than two translucent balls
    do
        local bb = Instance.new("BillboardGui")
        bb.Name = "LanternGlow"
        bb.Adornee = body
        bb.Size = UDim2.fromScale(3.2, 3.2) -- sized to the barrel; soft halo extends past it
        bb.LightInfluence = 0
        bb.Parent = body
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = "rbxassetid://135490760661320"
        img.ImageColor3 = Color3.fromRGB(255, 208, 155)
        img.ImageTransparency = 0.2 -- a touch fainter than the deck (the gradient paper already glows)
        img.Parent = bb
    end
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 168, 96)
    light.Brightness = 1.1 -- raised 2026-07-30: 0.3 was invisible against the ambient floor
    light.Range = 10
    light.Shadows = false
    light.Parent = body

    -- two glyph plates, PERPENDICULAR to the crosspiece (universal), tagged for LanternController
    --
    -- SIZED IN LS, like everything else here. This was a flat 1.2 x 1.6 and stayed flat when the
    -- lantern was scaled down on 2026-08-13 — so the glyph went from under half the barrel's width
    -- to two thirds of it and its corners hung outside the paper. The plate is the only lever:
    -- LanternController builds the SurfaceGui from it at PixelsPerStud and fills 0.7, so glyph
    -- size IS plate size. buildTeahouseChochin keeps the bare 1.2 x 1.6 and is CORRECT to — that
    -- lantern was never scaled (Rmax 0.9). Check the barrel before copying a number between them.
    local function plate(pname: string, facing: Vector3)
        local p = Instance.new("Part")
        p.Name = pname
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(1.2 * LS, 1.6 * LS, 0.05)
        local pos = lc + facing * (Rmax + 0.04)
        p.CFrame = CFrame.lookAt(pos, pos + facing)
        p.Parent = swing
        CollectionService:AddTag(p, "RoundLantern")
    end
    plate("GlyphPlateA", perp)
    plate("GlyphPlateB", -perp)

    swing.WorldPivot = CFrame.new(armEnd.X, armY, armEnd.Z) -- pivot at the hang point on the crosspiece
    CollectionService:AddTag(swing, "ChochinSwing")
    return model
end

-- ===== deploy along the path =====
-- Paths live under CanyonWorld.Paths since the 2026-07-08 reorg; fall back to the ws root
-- for anything legacy. This tool predated the move and only ever looked at the root.
local pathsRoot = ws:FindFirstChild("CanyonWorld") and ws.CanyonWorld:FindFirstChild("Paths")
local pathModel = (pathsRoot and pathsRoot:FindFirstChild(CONFIG.path)) or ws:FindFirstChild(CONFIG.path)
assert(pathModel, "missing path model " .. CONFIG.path .. " (looked in CanyonWorld.Paths and Workspace)")
-- ⚠️ OUTPUT GOES INTO CanyonWorld.Paths, not Workspace root. This tool predated the
-- 2026-07-08 reorg: it already looked for the PATH in CanyonWorld.Paths but still parented
-- its OUTPUT to the root, which is how a stray Workspace.PathLanterns holding
-- Chochin_RiverSquareStair came to exist and sit there unnoticed until 2026-07-30.
local lanternParent = pathsRoot or ws
local root = lanternParent:FindFirstChild(CONFIG.outModel) or ws:FindFirstChild(CONFIG.outModel)
if not root then
    root = Instance.new("Model")
    root.Name = CONFIG.outModel
end
root.Parent = lanternParent
-- one sub-model per path so re-running one path never disturbs another path's lanterns (idempotent).
-- (NOTE: PathSteps' first deploy predates this and lives loose under the root; a future PathSteps
--  re-run lands in Chochin_PathSteps — sweep the loose ChochinPole_* then.)
local parent = root:FindFirstChild("Chochin_" .. CONFIG.path)
if parent then
    parent:Destroy()
end
parent = Instance.new("Model")
parent.Name = "Chochin_" .. CONFIG.path
parent.Parent = root

-- sorted timbers
local timbers = {}
for _, c in pathModel:GetChildren() do
    local i = (c.Name :: string):match("^" .. CONFIG.timberPrefix .. "_(%d+)$")
    if i then
        table.insert(timbers, { i = tonumber(i), p = c })
    end
end
table.sort(timbers, function(a, b)
    return a.i < b.i
end)

math.randomseed(CONFIG.seed)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = { root } -- never raycast-hit any deployed lantern
local function horizUp(t: BasePart): Vector3
    local u = t.CFrame.RightVector
    return Vector3.new(u.X, 0, u.Z).Unit * CONFIG.uphillSign
end

-- EXPLICIT PLACEMENT MODE. When CONFIG.placements is set, the interval/stagger/downhill
-- machinery is bypassed entirely and only the listed poles are built. Used where the
-- lanterns are composed rather than rhythmic -- the Square stairway carries three,
-- alternating sides up the flight, which no interval rule would produce.
-- `side` is in canyon terms: +RightVector is NORTH on that stair, -RightVector SOUTH.
if CONFIG.placements then
    local byIndex = {}
    for _, e in ipairs(timbers) do
        byIndex[e.i] = e.p
    end
    local placed = {}
    for _, spec in ipairs(CONFIG.placements) do
        local t = byIndex[spec.step]
        if not t then
            table.insert(placed, ("step %d MISSING"):format(spec.step))
        else
            local r = t.CFrame.RightVector
            local north = Vector3.new(r.X, 0, r.Z).Unit
            local dir = spec.side == "north" and north or -north
            -- Offset is derived from the bed's OWN half-width plus a standoff, never
            -- hardcoded. CONFIG.uphillOffset of 4.5 is really 2.9 + 1.6 -- a 5.8-wide
            -- bed's half-width plus the network standoff -- so reusing 4.5 on a wider
            -- path silently moves the lanterns inboard. On this 8.0-wide stair it would
            -- put them 0.5 outboard instead of 1.6, which is how they ended up standing
            -- on the treads. Local X is cross-stream by the Step_ contract.
            local halfW = t.Size.X / 2
            local off = spec.offset or (halfW + (spec.standoff or STANDOFF))
            local base = t.Position + dir * off
            -- foot it on the ground it actually stands on, not at the bed's height
            local hit =
                workspace:Raycast(base + Vector3.new(0, 6, 0), Vector3.new(0, -(CONFIG.dhMaxDrop + 6), 0), rp)
            local footNote = ""
            if hit then
                base = Vector3.new(base.X, hit.Position.Y, base.Z)
                footNote = (", footed %+.1f vs bed"):format(hit.Position.Y - t.Position.Y)
            end
            buildOne(parent, ("ChochinPole_%d_%s"):format(spec.step, spec.side), base, dir)
            table.insert(placed, ("step %d %s at %.1f%s"):format(spec.step, spec.side, off, footNote))
        end
    end
    return ("placed %d chochin on %s (explicit): %s"):format(
        #CONFIG.placements,
        CONFIG.path,
        table.concat(placed, ", ")
    )
end

-- cap downhill poles at `downhillFrac` of the total to be placed (up to 30% by default)
local totalPoles = 0
for i = 1, #timbers do
    if (i - 1) % CONFIG.interval == 0 then
        totalPoles += 1
    end
end
local maxDownhill = math.floor(CONFIG.downhillFrac * totalPoles)

local made, dh, count = 0, 0, 0
for idx, entry in timbers do
    if (idx - 1) % CONFIG.interval == 0 then
        local t = entry.p
        local up = horizUp(t)
        -- stagger the pole along the path (lerp toward a neighbour by ±posJitter of a gap)
        local jf = (math.random() - 0.5) * 2 * CONFIG.posJitter
        local nb = timbers[math.clamp(idx + (jf >= 0 and 1 or -1), 1, #timbers)].p
        local center = t.Position:Lerp(nb.Position, math.abs(jf))
        -- on alternating poles, try the DOWNHILL side if terrain is close enough below
        local side, footY = "up", 0
        if count % 2 == 1 and dh < maxDownhill then
            local dhBase = center - up * CONFIG.uphillOffset
            local hit = workspace:Raycast(
                dhBase + Vector3.new(0, 6, 0),
                Vector3.new(0, -(CONFIG.dhMaxDrop + 6), 0),
                rp
            )
            if hit and (center.Y - hit.Position.Y) <= CONFIG.dhMaxDrop then
                side, footY = "down", hit.Position.Y
                dh += 1
            end
        end
        if side == "up" then
            buildOne(parent, "ChochinPole_" .. entry.i, center + up * CONFIG.uphillOffset, up)
        else
            local base = Vector3.new(
                center.X - up.X * CONFIG.uphillOffset,
                footY,
                center.Z - up.Z * CONFIG.uphillOffset
            )
            buildOne(parent, "ChochinPole_" .. entry.i .. "_d", base, -up)
        end
        made += 1
        count += 1
    end
end
return string.format("placed %d chochin poles along %s (%d on the downhill side)", made, CONFIG.path, dh)
