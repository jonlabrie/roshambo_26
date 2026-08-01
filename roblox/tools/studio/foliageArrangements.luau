--!strict
-- foliageArrangements.luau — pre-composed multi-tree foliage "arrangements" + the site
-- grammar for intelligent first placement (spec 2026-07-25-square-canopy-foliage; extends
-- the hero survey toward the valley-wide pass). Run via MCP execute_luau (Edit).
--
-- SITE GRAMMAR (where arrangements belong):
--   waterEdge   pool/stream banks — golds+blush lean over water; scale steps DOWN toward
--               it; stay ≥8 studs off flowlines/falls VFX corridors.
--   pathEdge    beside paths/stairs — frame entries + turns; NEVER on the walking
--               footprint; don't crowd lantern poles.
--   deckCorner  teahouse decks — small accents at corners; NEVER inside the deck
--               footprint, the veranda-to-view axis, or door/portal approaches.
--   cliffShelf  wall benches — cedar/fir masses; biggest tree upslope.
--   promontory  ridge/perch points — solo talls that read from across the valley.
--   bridgeEnd   abutments — sentinel pairs (deploy split across the span).
--   tunnelMouth single marker tree beside the opening.
-- HARD KEEP-OUTS: reserved corridors (shopCorridor/eastCorridor), the karesansui garden
-- precinct, path footprints, water flowlines, deck footprints. The SQUARE's own heroes
-- are hand-placed via placeCanopyHeroes — arrangements serve everything beyond it.
-- COMPOSITION RULES: odd counts; one dominant + attendants (shu-shin/fukujin);
-- asymmetric triangles; jewel tones never touch dark conifer directly (green cushion);
-- per-tree ground raycast so groups drape over terrain.
--
-- MODE="display" stamps every arrangement in a labelled tuning row (SITES below).
-- MODE="place" stamps ONE arrangement (PLACE_NAME) at PLACE_AT — used for real deployment
-- once tuned. Clones land in CanyonWorld.Foliage.ArrangementsDraft with Species/BaseScale/
-- Arrangement attributes (bake-compatible with placeCanopyHeroes conventions).

local ServerStorage = game:GetService("ServerStorage")

local MODE = "display" -- "display" | "place"
local PLACE_NAME = "CliffTrio"
local PLACE_AT = { x = 0, z = 0 }

-- {species, dx, dz, scale, yawDeg?} — offsets relative to the arrangement anchor.
export type Tree = { species: string, dx: number, dz: number, scale: number, yawDeg: number? }
export type Arrangement = { name: string, site: string, trees: { Tree } }

local ARRANGEMENTS: { Arrangement } = {
    {
        name = "PathGate",
        site = "pathEdge",
        trees = {
            { species = "PineNiwakiA", dx = -5, dz = 0, scale = 1.0 },
            { species = "PineNiwakiC", dx = 5.5, dz = 1.5, scale = 0.85 },
            -- tall third set BACK off the gate axis: the dominant of the group
            { species = "PineNiwakiE", dx = -2, dz = 9, scale = 1.0, yawDeg = 215 },
        },
    },
    {
        name = "StreamBend",
        site = "waterEdge",
        trees = {
            { species = "MapleGold", dx = 0, dz = 0, scale = 1.0 },
            { species = "MapleGreen", dx = -7, dz = 4, scale = 0.8 },
            { species = "CedarS", dx = -13, dz = 9, scale = 0.9 },
        },
    },
    {
        name = "PoolMirror",
        site = "waterEdge",
        trees = {
            { species = "MapleGold", dx = 0, dz = 0, scale = 1.1 },
            { species = "BroadleafMid", dx = 6, dz = 5, scale = 0.65 },
        },
    },
    {
        name = "FallsFrame",
        site = "waterEdge",
        trees = {
            { species = "MapleRed", dx = -9, dz = 0, scale = 1.05 },
            { species = "MapleGold", dx = 9, dz = 2, scale = 0.9 },
            { species = "BroadleafMid", dx = 0, dz = 7, scale = 0.8 },
        },
    },
    {
        name = "StairCompanion",
        site = "pathEdge",
        trees = {
            { species = "BlushAccent", dx = 0, dz = 0, scale = 0.85 },
            { species = "CedarS", dx = 5, dz = 4, scale = 0.75 },
        },
    },
    {
        name = "DeckCorner",
        site = "deckCorner",
        trees = {
            { species = "BlushAccent", dx = 0, dz = 0, scale = 0.7 },
            { species = "BroadleafMid", dx = 4.5, dz = 3, scale = 0.5 },
        },
    },
    {
        name = "PerchCrown",
        site = "promontory",
        trees = {
            { species = "PineNiwakiE", dx = 0, dz = 0, scale = 1.0 },
        },
    },
    {
        name = "CliffTrio",
        site = "cliffShelf",
        trees = {
            { species = "FirM", dx = 0, dz = 0, scale = 1.15 },
            { species = "CedarM", dx = 8, dz = 6, scale = 0.8 },
            { species = "CedarS", dx = -7, dz = 5, scale = 0.8 },
        },
    },
    {
        name = "GroveFive",
        site = "cliffShelf",
        trees = {
            { species = "MapleGreen", dx = 0, dz = 0, scale = 1.0 },
            { species = "BroadleafMid", dx = 8, dz = -3, scale = 0.8 },
            { species = "CedarS", dx = 14, dz = 4, scale = 0.95 },
            { species = "MapleGreen", dx = -8, dz = 5, scale = 0.75 },
            { species = "BroadleafMid", dx = 4, dz = 9, scale = 0.6 },
        },
    },
    {
        name = "JewelIsland",
        site = "cliffShelf",
        trees = {
            { species = "MapleRed", dx = 0, dz = 0, scale = 1.0 },
            { species = "BroadleafMid", dx = 7, dz = 3, scale = 0.7 },
            { species = "MapleGreen", dx = -6, dz = 6, scale = 0.65 },
        },
    },
    {
        name = "SentinelPair",
        site = "bridgeEnd",
        trees = {
            { species = "CedarM", dx = 0, dz = 0, scale = 1.0 },
            { species = "CedarM", dx = 12, dz = 1, scale = 0.9 },
        },
    },
    {
        name = "TunnelMarker",
        site = "tunnelMouth",
        trees = {
            { species = "MapleRed", dx = 0, dz = 0, scale = 0.9 },
        },
    },
    {
        name = "ValleySeed",
        site = "cliffShelf",
        trees = {
            { species = "BlushAccent", dx = 0, dz = 0, scale = 1.0 },
            { species = "FirM", dx = 7, dz = 7, scale = 0.9 },
            { species = "BroadleafMid", dx = -6, dz = 4, scale = 0.6 },
        },
    },
}

-- Tuning-display anchors: spread 70-90 studs apart, alternating banks up the valley so
-- each arrangement can be browsed on its own (terrain-probed 2026-07-25; the x≈-240..-400
-- channel centre is water — anchors stay on the ±z benches). NOT deployment sites.
local SITES: { { number } } = {
    { -120, 34 },
    { -160, -34 },
    { -200, 36 },
    { -240, -36 },
    { -280, 40 },
    { -320, -40 },
    { -360, 42 },
    { -400, -44 },
    { -440, 46 },
    { -150, 62 },
    { -230, 66 },
    { -310, 70 },
    { -390, 74 },
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function groundAt(x: number, z: number): (number?, boolean)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { workspace.Terrain }
    local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -700, 0), params)
    if not hit then
        return nil, false
    end
    return hit.Position.Y, hit.Material == Enum.Material.Water
end

local function flagParts(root: Instance)
    for _, d in root:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CastShadow = false
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d:IsA("MeshPart") then
                d.RenderFidelity = Enum.RenderFidelity.Automatic
            end
        elseif d:IsA("BillboardGui") then
            d:Destroy()
        end
    end
end

local function draftFolder(): Folder
    local fol = workspace.CanyonWorld:FindFirstChild("Foliage") :: Folder?
    if not fol then
        local nf = Instance.new("Folder")
        nf.Name = "Foliage"
        nf.Parent = workspace.CanyonWorld
        fol = nf
    end
    local draft = (fol :: Folder):FindFirstChild("ArrangementsDraft") :: Folder?
    if not draft then
        local nd = Instance.new("Folder")
        nd.Name = "ArrangementsDraft"
        nd.Parent = fol
        draft = nd
    end
    return draft :: Folder
end

-- flatY: when set, every tree in the arrangement seats on that plane instead of
-- raycasting terrain — the gallery stands them on a built platform, where a terrain
-- ray would find the canyon hundreds of studs below (or nothing at all).
local function stamp(arr: Arrangement, ax: number, az: number, labelled: boolean, flatY: number?)
    local kit = ServerStorage:FindFirstChild("FoliageKit")
    assert(kit, "ServerStorage.FoliageKit missing")
    local draft = draftFolder()
    local group = Instance.new("Model")
    group.Name = "Arr_" .. arr.name
    group:SetAttribute("Arrangement", arr.name)
    group.Parent = draft
    local state = math.floor(math.abs(ax * 31 + az * 7)) + 1
    for _, t in arr.trees do
        local template = kit:FindFirstChild(t.species)
        if not template then
            warn(`[arr] no kit template {t.species}`)
            continue
        end
        local x, z = ax + t.dx, az + t.dz
        local y, isWater
        if flatY ~= nil then
            y, isWater = flatY, false
        else
            y, isWater = groundAt(x, z)
        end
        if not y or isWater then
            warn(
                `[arr] {arr.name}/{t.species} skipped at ({x}, {z}) — {isWater and "water" or "no ground"}`
            )
            continue
        end
        local yawRoll
        state, yawRoll = lcg(state)
        local clone = template:Clone()
        clone.Name = t.species
        flagParts(clone)
        clone:SetAttribute("Species", t.species)
        clone:SetAttribute("BaseScale", t.scale)
        clone:SetAttribute("Arrangement", arr.name)
        clone.Parent = group
        local yaw = if t.yawDeg then math.rad(t.yawDeg) else yawRoll * 2 * math.pi
        clone:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0))
        -- ScaleTo is ABSOLUTE, and the kit templates are already scaled (CedarM sits
        -- at 0.23, CedarS at 0.143) — so ScaleTo(1.0) did not mean "natural size", it
        -- RESET the model to its authored size and blew a 45-stud cedar up to 196.
        -- Every cedar/fir/blush arrangement has been rendering 2-9x oversized since
        -- this tool was written; multiply by the template's own scale as the plant
        -- scatter does. (2026-08-01)
        if clone:IsA("Model") and t.scale ~= 1 then
            clone:ScaleTo(clone:GetScale() * t.scale)
        end
    end
    if labelled then
        -- the label must sit on the SAME plane as its trees; raycasting here put the
        -- gallery's posts on the canyon floor 400 studs below their own arrangement
        local y = flatY or groundAt(ax, az) or 150
        local post = Instance.new("Part")
        post.Name = "Label_" .. arr.name
        post.Anchored = true
        post.CanCollide = false
        post.Size = Vector3.new(0.6, 8, 0.6)
        post.CFrame = CFrame.new(ax, y + 4, az)
        post.Color = Color3.fromRGB(0, 170, 255)
        post.Material = Enum.Material.Neon
        post.Parent = group
        local bb = Instance.new("BillboardGui")
        -- Scale (studs-relative), NOT Offset (pixels) — pixel labels never shrink with
        -- distance and clutter the valley view from the square.
        bb.Size = UDim2.fromScale(16, 2.6)
        bb.StudsOffset = Vector3.new(0, 6, 0)
        bb.MaxDistance = 120
        bb.Parent = post
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.fromScale(1, 1)
        txt.BackgroundTransparency = 0.4
        txt.BackgroundColor3 = Color3.new(0, 0, 0)
        txt.TextColor3 = Color3.new(1, 1, 1)
        txt.TextScaled = true
        txt.Text = arr.name .. " (" .. arr.site .. ")"
        txt.Parent = bb
    end
end

-- GALLERY (2026-08-01): the up-valley display row was judged unattractive, but it was
-- shown at full scale amid canyon clutter, which is not a fair test of a composition.
-- This lifts all 13 onto a neutral platform ABOVE the canyon, evenly spaced, so each
-- can be read on its own terms.
local GALLERY_CENTRE = Vector3.new(0, 520, 0)
local GALLERY_CELL = 60
local GALLERY_COLS = 5

local function galleryFolder(): Folder
    local sandbox = workspace:FindFirstChild("Sandbox")
    if not sandbox then
        local s = Instance.new("Folder")
        s.Name = "Sandbox"
        s.Parent = workspace
        sandbox = s
    end
    local old = (sandbox :: Instance):FindFirstChild("ArrangementGallery")
    if old then
        old:Destroy()
    end
    local f = Instance.new("Folder")
    f.Name = "ArrangementGallery"
    f.Parent = sandbox
    return f
end

local function buildGallery(): string
    local rows = math.ceil(#ARRANGEMENTS / GALLERY_COLS)
    local width = GALLERY_COLS * GALLERY_CELL
    local depth = rows * GALLERY_CELL
    local folder = galleryFolder()

    local slab = Instance.new("Part")
    slab.Name = "GalleryFloor"
    slab.Anchored = true
    slab.CanCollide = true
    -- never shadow the canyon below with a 300-stud slab hanging over it
    slab.CastShadow = false
    slab.Size = Vector3.new(width, 2, depth)
    slab.Position = GALLERY_CENTRE
    slab.Material = Enum.Material.Slate
    slab.Color = Color3.fromRGB(105, 105, 100)
    slab.Parent = folder

    local topY = GALLERY_CENTRE.Y + 1
    local x0 = GALLERY_CENTRE.X - width / 2 + GALLERY_CELL / 2
    local z0 = GALLERY_CENTRE.Z - depth / 2 + GALLERY_CELL / 2
    for i, arr in ARRANGEMENTS do
        local col = (i - 1) % GALLERY_COLS
        local row = math.floor((i - 1) / GALLERY_COLS)
        stamp(arr, x0 + col * GALLERY_CELL, z0 + row * GALLERY_CELL, true, topY)
    end
    -- the draft folder is where stamp() parents its groups; move them onto the gallery
    -- so the canyon's own ArrangementsDraft is not left holding floating trees
    local draft = draftFolder()
    for _, child in draft:GetChildren() do
        child.Parent = folder
    end
    return `[arr] gallery: {#ARRANGEMENTS} arrangements on a {width}x{depth} platform at `
        .. `({GALLERY_CENTRE.X}, {GALLERY_CENTRE.Y}, {GALLERY_CENTRE.Z}) — Sandbox.ArrangementGallery`
end

return function(opts: { mode: string?, name: string?, at: { x: number, z: number }? }?): string
    local mode = (opts and opts.mode) or MODE
    if mode == "gallery" then
        return buildGallery()
    end
    if mode == "gallery-off" then
        local sandbox = workspace:FindFirstChild("Sandbox")
        local g = sandbox and sandbox:FindFirstChild("ArrangementGallery")
        if g then
            g:Destroy()
            return "[arr] gallery removed"
        end
        return "[arr] no gallery to remove"
    end
    if mode == "display" then
        local draft = draftFolder()
        draft:ClearAllChildren()
        for i, arr in ARRANGEMENTS do
            local site = SITES[i]
            if site then
                stamp(arr, site[1], site[2], true)
            end
        end
        return `[arr] displayed {math.min(#ARRANGEMENTS, #SITES)} arrangements up-valley`
    end
    local wanted = (opts and opts.name) or PLACE_NAME
    local at = (opts and opts.at) or PLACE_AT
    local arr
    for _, a in ARRANGEMENTS do
        if a.name == wanted then
            arr = a
        end
    end
    assert(arr, "unknown arrangement " .. wanted)
    stamp(arr, at.x, at.z, false)
    return `[arr] placed {wanted} at ({at.x}, {at.z})`
end
