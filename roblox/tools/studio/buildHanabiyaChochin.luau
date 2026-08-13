--!strict
-- buildHanabiyaChochin — a hanging paper chōchin at each front corner of 花火屋, slung under
-- the shopfront eave. Output: CanyonWorld.Structures.Chochin_Hanabiya (PLACE-ONLY — save/publish
-- the place after running; Rojo owns only what default.project.json names, and the shop's own
-- model is one of those, so nothing may be hand-added under RoshamboStage).
--
-- THE SAME LANTERN AS THE PATH POLES, deliberately. Geometry, colours and scale are lifted from
-- tools/studio/buildChochinPole.luau (which the owner gate-tuned to LS 0.65/0.9 on 2026-08-13);
-- what is dropped is everything below the hang point — no pole, no crosspiece, no brace, because
-- this one hangs off a building. If the path lantern is retuned, retune it here too: these are
-- two copies of one design and there is no shared module, because Studio tools are pasted whole
-- into a Studio session and cannot require each other.
--
-- IT KEEPS THE GLYPH PLATES. That looks like decoration and is not: the plates carry the tag
-- "RoundLantern", which is how LanternController shows the last World Throw on every lantern in
-- the canyon AND how PaperLanternDayNight finds the barrel to ride up and down with nightFactor.
-- Drop the plates and this lantern silently burns at full brightness at noon and tells the player
-- nothing — the exact bug that script's header describes.
local CollectionService = game:GetService("CollectionService")
local ws = workspace

-- DESTRUCTIVE-BAKE GUARD. This tool destroys and rebuilds its own output, which is safe exactly
-- until someone nudges a lantern by hand in Studio — after that a re-run silently reverts their
-- work. Flip REBUILD only when you mean to discard whatever is there now.
local REBUILD = false
local OUT = "Chochin_Hanabiya"

-- ===== locked colours / materials, copied from buildChochinPole =====
local INK = Color3.fromRGB(46, 40, 30) -- ribs, caps
local METAL = Color3.fromRGB(120, 122, 128) -- hanging loop, hook
local PAPER = { 200, 170, 143 } -- warm-cream paper base, gradient-scaled per slice
local PAPER_T = 0.42
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder long axis is local X

local LS = 0.65 / 0.9 -- the owner's lantern scale: Rmax 0.9 -> 0.65
local Rmax, capR = 0.9 * LS, 0.30 * LS
local bodyH = 2.8 * LS
local ringR, tubeR = 0.22 * LS, 0.05 * LS
local HOOK_DROP = 0.22 -- the eye under the eave the loop hangs from

local function profile(tt: number): number
    local d = math.abs(2 * tt - 1)
    return capR + (Rmax - capR) * (1 - d ^ 6) ^ 0.5
end

local function cyl(
    parent: Instance,
    name: string,
    size: Vector3,
    cf: CFrame,
    colour: Color3,
    mat: Enum.Material,
    tr: number?
)
    local p = Instance.new("Part")
    p.Name = name
    p.Shape = Enum.PartType.Cylinder
    p.Size = size
    p.CFrame = cf
    p.Color = colour
    p.Material = mat
    p.Transparency = tr or 0
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Parent = parent
    return p
end

-- ===== where the shop is, measured rather than remembered =====
local shop = ws:FindFirstChild("RoshamboStage") and ws.RoshamboStage:FindFirstChild("Hanabiya")
assert(shop, "Hanabiya is not in RoshamboStage — is Rojo connected?")
local eave = shop:FindFirstChild("Eave") :: BasePart
local floorSlab = shop:FindFirstChild("FloorSlab") :: BasePart
assert(eave and floorSlab, "Hanabiya is missing Eave or FloorSlab")
local FLOOR = floorSlab.Position.Y + floorSlab.Size.Y / 2

-- The eave is a TILTED slab, so its underside is a plane, not a number. Take the plane off the
-- part's own CFrame and evaluate it where each lantern hangs.
local nY, nZ = eave.CFrame.YVector.Y, eave.CFrame.YVector.Z
local pY = eave.Position.Y - (eave.Size.Y / 2) * nY
local pZ = eave.Position.Z - (eave.Size.Y / 2) * nZ
local function eaveUndersideAt(z: number): number
    return pY - (nZ / nY) * (z - pZ)
end

-- THE EAVE'S OUTSIDE CORNERS, not the building's (owner's gate). They first hung tucked against
-- the shopfront, which reads as lanterns stored under the overhang rather than hung at it — a
-- shopfront chōchin belongs out at the corner of the roof, where the street sees it side-on and
-- it marks the building from up and down the promenade. Taken off the EAVE's own extents, so they
-- follow the overhang rather than the wall.
local CORNER_INSET = 0.35 -- back from the eave's edge, so they hang under it rather than off it
local eaveHalfX = eave.Size.X / 2
local eaveZext = math.abs(eave.CFrame.YVector.Z) * eave.Size.Y / 2
    + math.abs(eave.CFrame.ZVector.Z) * eave.Size.Z / 2
local HANG_Z = (eave.Position.Z - eaveZext) + CORNER_INSET
local CORNERS = {
    { name = "West", x = eave.Position.X - eaveHalfX + CORNER_INSET },
    { name = "East", x = eave.Position.X + eaveHalfX - CORNER_INSET },
}

-- CLEARANCE, CHECKED NOT ASSUMED. The eave SHEDS toward the street, so moving the lanterns out to
-- its corners necessarily hangs them LOWER — the underside drops about a fifth of a stud for every
-- stud north. The owner has ruled that acceptable here ("it's okay if they're low"), so the floor
-- below is a duck-under rather than the 6.0 a player walks under upright. It stays an assert
-- because something has to catch a lantern hung at chest height; it is not enforcing headroom.
local MIN_HEM_CLEAR = 5.0
local armY = eaveUndersideAt(HANG_Z) - HOOK_DROP
local hemY = armY - 2 * ringR - 0.13 * LS - bodyH - 0.13 * LS
local clearance = hemY - FLOOR
assert(
    clearance >= MIN_HEM_CLEAR,
    ("the lantern hem would sit %.2f above the floor — below the %.1f a player can duck under"):format(
        clearance,
        MIN_HEM_CLEAR
    )
)

-- ===== output =====
local canyon = ws:FindFirstChild("CanyonWorld")
assert(canyon, "CanyonWorld is missing — this places into CanyonWorld.Structures")
local structures = canyon:FindFirstChild("Structures")
assert(structures, "CanyonWorld.Structures is missing")
local existing = structures:FindFirstChild(OUT)
if existing and not REBUILD then
    return ("%s already exists — refusing to rebuild over it. Set REBUILD = true if you mean to discard it."):format(
        OUT
    )
end
if existing then
    existing:Destroy()
end
local root = Instance.new("Model")
root.Name = OUT
root.Parent = structures

local function buildOne(name: string, x: number)
    local model = Instance.new("Model")
    model.Name = "Chochin" .. name
    model.Parent = root

    -- The eye under the eave. NOT in Swing: it is fixed to the building, and the lantern rocks
    -- beneath it.
    local hook = Instance.new("Part")
    hook.Name = "Hook"
    hook.Size = Vector3.new(2 * tubeR, HOOK_DROP, 2 * tubeR)
    hook.CFrame = CFrame.new(x, armY + HOOK_DROP / 2, HANG_Z)
    hook.Color = METAL
    hook.Material = Enum.Material.Metal
    hook.Anchored = true
    hook.CanCollide = false
    hook.CanQuery = false
    hook.CanTouch = false
    hook.CastShadow = false
    hook.Parent = model

    local swing = Instance.new("Model")
    swing.Name = "Swing"
    swing.Parent = model

    -- the metal loop draped over the hook
    local ringCenter = Vector3.new(x, armY - ringR, HANG_Z)
    local e1, e2 = Vector3.new(0, 1, 0), Vector3.new(1, 0, 0)
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

    -- paper barrel: an 18-slice stack with a vertical gradient, centre brightest
    local ringBottom = armY - 2 * ringR
    local lc = Vector3.new(x, ringBottom - 0.13 * LS - bodyH / 2 + 0.05 * LS, HANG_Z)
    local N, centerIdx = 18, 9
    local body: BasePart
    for i = 0, N - 1 do
        local tt = (i + 0.5) / N
        local r = profile(tt)
        local y = lc.Y + (tt - 0.5) * bodyH
        local d = math.abs(2 * tt - 1)
        local f = math.clamp(1 - 0.22 * d - (tt > 0.5 and 0.15 * (2 * tt - 1) or 0), 0.4, 1)
        local part = cyl(
            swing,
            (i == centerIdx) and "ChochinBody" or ("Slice_" .. i),
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

    -- horizontal ribs
    for j = 1, 16 do
        local tt = (j - 0.5) / 16
        local r = profile(tt) + 0.05 * LS
        cyl(
            swing,
            "Rib_" .. j,
            Vector3.new(0.035 * LS, 2 * r, 2 * r),
            CFrame.new(lc.X, lc.Y + (tt - 0.5) * bodyH, lc.Z) * VERT,
            INK,
            Enum.Material.Wood
        )
    end

    -- top and bottom caps
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
        "CapBottom",
        Vector3.new(0.26 * LS, 0.66 * LS, 0.66 * LS),
        CFrame.new(lc - Vector3.new(0, bodyH / 2, 0)) * VERT,
        INK,
        Enum.Material.Wood
    )

    -- soft warm halo + a ground pool. Neon lights only itself, so these are separate channels.
    local bb = Instance.new("BillboardGui")
    bb.Name = "LanternGlow"
    bb.Adornee = body
    bb.Size = UDim2.fromScale(3.2, 3.2)
    bb.LightInfluence = 0
    bb.Parent = body
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromScale(1, 1)
    img.Image = "rbxassetid://135490760661320"
    img.ImageColor3 = Color3.fromRGB(255, 208, 155)
    img.ImageTransparency = 0.2
    img.Parent = bb

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 168, 96)
    light.Brightness = 1.1
    light.Range = 10
    light.Shadows = false
    light.Parent = body

    -- Glyph plates face the STREET and the shop interior — the two directions a shopfront
    -- lantern is read from, where the path poles face across their path instead.
    local function plate(pname: string, facing: Vector3)
        local p = Instance.new("Part")
        p.Name = pname
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.Transparency = 1
        p.Size = Vector3.new(1.2, 1.6, 0.05)
        local pos = lc + facing * (Rmax + 0.04)
        p.CFrame = CFrame.lookAt(pos, pos + facing)
        p.Parent = swing
        CollectionService:AddTag(p, "RoundLantern")
    end
    plate("GlyphPlateA", Vector3.new(0, 0, -1))
    plate("GlyphPlateB", Vector3.new(0, 0, 1))

    -- The pivot IS the hang point. ChochinSway rocks the model about its own pivot, and a model's
    -- default pivot is its bounding-box centre — leave it and the lantern swings about its waist.
    swing.WorldPivot = CFrame.new(x, armY, HANG_Z)
    CollectionService:AddTag(swing, "ChochinSwing")
end

for _, c in CORNERS do
    buildOne(c.name, c.x)
end

return ("built %s: 2 chōchin at x %.2f / %.2f, z %.2f, hung from y %.2f — hem %.2f, clearing the floor by %.2f (avatar needs 6.0)"):format(
    OUT,
    CORNERS[1].x,
    CORNERS[2].x,
    HANG_Z,
    armY,
    hemY,
    clearance
)
