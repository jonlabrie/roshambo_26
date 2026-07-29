--!strict
-- buildChochinPole — places hanging paper chōchin on bamboo posts along a path's UPHILL edge.
-- Studio runnable (command bar / MCP execute_luau); builds ad-hoc Parts into Workspace.PathLanterns
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
    -- offset 3.4 stands them ON the tread, 0.6 inboard of the 8.0-wide bed's edge: the
    -- south side has only 1.0 of clear ground between tread edge and the retaining wall
    -- face at 5.0, and the north side would otherwise foul the bamboo rail at 4.0.
    path = "RiverSquareStair",
    timberPrefix = "Step",
    placements = {
        { step = 2, side = "south", offset = 3.4 },
        { step = 20, side = "north", offset = 3.4 },
        { step = 39, side = "south", offset = 3.4 },
    },
    interval = 6, -- base timbers between poles (ignored when `placements` is set)
    posJitter = 0.35, -- ±fraction of a timber gap to stagger each pole along the path (~5-10% spacing)
    uphillOffset = 4.5, -- studs from the timber toward the cliff (uphill) edge
    uphillSign = 1, -- which RightVector end is uphill/cliff: +1 PathSteps; -1 DescentPath (prefix "DescTimber")
    downhillFrac = 0.30, -- up to this FRACTION of the placed poles may sit on the DOWNHILL side, terrain permitting
    dhMaxDrop = 8, -- downhill pole placed only if terrain is within this many studs below the path
    seed = 20260629, -- deterministic stagger (same place each run)
    outModel = "PathLanterns", -- Workspace output model (poles go in a per-path sub-model under it)
}

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
local Rmax, capR = 0.9, 0.30
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
    local poleH, poleDia = 12.8, 0.38
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
    local armFront, armBack, armDia = 2.38, poleR + 0.12, 0.225
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
        local poleP = Vector3.new(base.X, armY - 1.4, base.Z)
        local armP = base + -up * 1.1 + H
        local mid = (poleP + armP) / 2
        cyl(
            model,
            "Brace",
            Vector3.new((armP - poleP).Magnitude, 0.18, 0.18),
            CFrame.lookAt(mid, armP) * CFrame.Angles(0, math.rad(90), 0),
            WOOD,
            Enum.Material.Wood
        )
    end

    -- ----- metal loop draped over the crosspiece end (in Swing) -----
    local ringR, tubeR = 0.22, 0.05
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
    local bodyH = 2.8
    local ringBottom = armY - 2 * ringR
    local lc = Vector3.new(armEnd.X, ringBottom - 0.13 - bodyH / 2 + 0.05, armEnd.Z)
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
        local r = profile(tt) + 0.05
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
    local Rv = Rmax + 0.05
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
        Vector3.new(0.26, 0.66, 0.66),
        CFrame.new(lc + Vector3.new(0, bodyH / 2, 0)) * VERT,
        INK,
        Enum.Material.Wood
    )
    cyl(
        swing,
        "CapBot",
        Vector3.new(0.26, 0.66, 0.66),
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
    light.Brightness = 0.3 -- less spill (amount)
    light.Range = 9 -- less spill (distance)
    light.Shadows = false
    light.Parent = body

    -- two glyph plates, PERPENDICULAR to the crosspiece (universal), tagged for LanternController
    local function plate(pname: string, facing: Vector3)
        local p = Instance.new("Part")
        p.Name = pname
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(1.2, 1.6, 0.05)
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
local root = ws:FindFirstChild(CONFIG.outModel) or Instance.new("Model")
root.Name = CONFIG.outModel
root.Parent = ws
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
            local base = t.Position + dir * spec.offset
            buildOne(parent, ("ChochinPole_%d_%s"):format(spec.step, spec.side), base, dir)
            table.insert(placed, ("step %d %s at %.1f"):format(spec.step, spec.side, spec.offset))
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
