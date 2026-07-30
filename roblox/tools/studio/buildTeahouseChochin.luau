--!strict
-- buildTeahouseChochin — swaps each teahouse's old block lamp for the latest hanging chōchin
-- (the locked buildChochinPole barrel), hung from a small metal HOOK up at the beam (no rod/cord).
-- Studio runnable; PLACE-ONLY — SAVE THE PLACE after.
--
-- Per teahouse it reads the OLD `Lantern` block + `Cord` to place itself, so it adapts to each
-- teahouse's position, rotation, AND left/right mirror with no special-casing:
--   * lamp XZ      = the old Lantern's position
--   * hang/beam Y  = the Cord top (loop hangs here; the barrel drops below)
--   * glyph facing = the old Lantern's horizontal LookVector (the teahouse "front" axis)
-- Then it removes the old Lantern/LanRib/LanCap/Cord. Idempotent: teahouses already converted
-- (no Lantern) are skipped. Everything is CanCollide=false so players pass through cleanly.
local CollectionService = game:GetService("CollectionService")
local ws = workspace

local CONTAINERS = { "CanyonTeahouses" } -- Workspace folders/models holding the teahouse models

-- ===== locked chōchin recipe (mirrors buildChochinPole) =====
local INK = Color3.fromRGB(46, 40, 30)
local METAL = Color3.fromRGB(120, 122, 128)
local PAPER = { 200, 170, 143 }
local PAPER_T = 0.42
local VERT = CFrame.Angles(0, 0, math.rad(90))
local Rmax, capR = 0.9, 0.30
local GLOW = "rbxassetid://135490760661320"

local function profile(tt: number): number
    local d = math.abs(2 * tt - 1)
    return capR + (Rmax - capR) * (1 - d ^ 6) ^ 0.5
end

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

-- the hanging barrel (the "Swing" model): metal loop + paper barrel + ribs + caps + glow + light +
-- two RoundLantern glyph plates (perpendicular to `perp`). `armY` = the loop top (the hook point).
local function buildSwing(model: Instance, hangX: number, hangZ: number, armY: number, perp: Vector3)
    local swing = Instance.new("Model")
    swing.Name = "ChochinSwing"
    swing.Parent = model
    local perpAngle = math.atan2(perp.Z, perp.X)
    local armEnd = Vector3.new(hangX, armY, hangZ)

    -- metal loop
    local ringR, tubeR = 0.22, 0.05
    local ringCenter = Vector3.new(armEnd.X, armY - ringR, armEnd.Z)
    local e1 = Vector3.new(0, 1, 0)
    local e2 = Vector3.new(perp.X, 0, perp.Z).Unit -- loop in the up×perp plane
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

    -- paper barrel (18-slice superellipse stack, vertical gradient)
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
        local fcol = math.clamp(1 - 0.22 * d - (tt > 0.5 and 0.15 * (2 * tt - 1) or 0), 0.4, 1)
        local part = cyl(
            swing,
            (i == centerIdx) and "ChochinBody" or ("Slice_" .. i),
            Vector3.new(bodyH / N * 1.15, 2 * r, 2 * r),
            CFrame.new(lc.X, y, lc.Z) * VERT,
            Color3.fromRGB(PAPER[1] * fcol, PAPER[2] * fcol, PAPER[3] * fcol),
            Enum.Material.Neon,
            PAPER_T
        )
        if i == centerIdx then
            body = part
        end
    end
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
    local tt4, tt13 = (4 - 0.5) / 16, (13 - 0.5) / 16
    local y4, y13 = lc.Y + (tt4 - 0.5) * bodyH, lc.Y + (tt13 - 0.5) * bodyH
    local Rv = Rmax + 0.05
    for k = 0, 5 do
        local a = perpAngle + math.rad(30 + k * 60)
        cyl(
            swing,
            "VRib_" .. k,
            Vector3.new(y13 - y4, 0.03, 0.03),
            CFrame.new(Vector3.new(lc.X + Rv * math.cos(a), (y4 + y13) / 2, lc.Z + Rv * math.sin(a))) * VERT,
            INK,
            Enum.Material.Wood
        )
    end
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

    -- glow sprite + warm light
    local bb = Instance.new("BillboardGui")
    bb.Name = "LanternGlow"
    bb.Adornee = body
    bb.Size = UDim2.fromScale(3.2, 3.2)
    bb.LightInfluence = 0
    bb.Parent = body
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromScale(1, 1)
    img.Image = GLOW
    img.ImageColor3 = Color3.fromRGB(255, 208, 155)
    img.ImageTransparency = 0.2
    img.Parent = bb
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 168, 96)
    light.Brightness = 1.1
    light.Range = 10
    light.Shadows = false
    light.Parent = body

    -- two glyph plates (perpendicular to the crosspiece axis = facing ±perp), tagged for LanternController
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

    swing.WorldPivot = CFrame.new(armEnd.X, armY, armEnd.Z) -- swing from the hook
    CollectionService:AddTag(swing, "ChochinSwing")
end

-- a small metal hook curl fixed up at the beam (no rod), opening downward, in the up×perp plane
local function buildHook(model: Instance, hangX: number, hangZ: number, curlY: number, perp: Vector3)
    local hook = Instance.new("Model")
    hook.Name = "ChochinHook"
    hook.Parent = model
    local C = Vector3.new(hangX, curlY, hangZ)
    local R, tube = 0.13, 0.045
    local eH = Vector3.new(perp.X, 0, perp.Z).Unit
    local eV = Vector3.new(0, 1, 0)
    local segs, sweep, start = 7, math.rad(300), math.rad(120) -- gap at the bottom
    for i = 0, segs - 1 do
        local a0 = start + sweep * (i / segs)
        local a1 = start + sweep * ((i + 1) / segs)
        local p0 = C + R * (math.cos(a0) * eH + math.sin(a0) * eV)
        local p1 = C + R * (math.cos(a1) * eH + math.sin(a1) * eV)
        cyl(
            hook,
            "HookCurl_" .. i,
            Vector3.new((p1 - p0).Magnitude + 0.02, 2 * tube, 2 * tube),
            CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0),
            METAL,
            Enum.Material.Metal
        )
    end
end

local function convert(model: Instance): boolean
    local lant = model:FindFirstChild("Lantern") :: BasePart?
    if not lant then
        return false -- already converted (or no lamp)
    end
    local cord = model:FindFirstChild("Cord") :: BasePart?
    local hangX, hangZ = lant.Position.X, lant.Position.Z
    local cordTop = cord and (cord.Position.Y + cord.Size.Y / 2) or (lant.Position.Y + lant.Size.Y / 2 + 2)
    local lookH = Vector3.new(lant.CFrame.LookVector.X, 0, lant.CFrame.LookVector.Z)
    local perp = (lookH.Magnitude > 0.01) and lookH.Unit or Vector3.new(0, 0, 1)

    -- clear the old lamp + any prior conversion
    for _, c in model:GetChildren() do
        if c.Name == "Lantern" or c.Name == "Cord" or c.Name == "LanCap" or c.Name:match("^LanRib") then
            c:Destroy()
        end
    end
    local oldS = model:FindFirstChild("ChochinSwing")
    if oldS then
        oldS:Destroy()
    end
    local oldH = model:FindFirstChild("ChochinHook")
    if oldH then
        oldH:Destroy()
    end

    buildSwing(model, hangX, hangZ, cordTop, perp) -- loop top at the cord/beam line
    buildHook(model, hangX, hangZ, cordTop + 0.13, perp) -- curl just above the loop
    return true
end

local done = 0
for _, cname in CONTAINERS do
    local container = ws:FindFirstChild(cname)
    if container then
        for _, m in container:GetChildren() do
            if m:IsA("Model") and convert(m) then
                done += 1
            end
        end
    end
end
return "converted " .. done .. " teahouse lamps to the latest chōchin"
