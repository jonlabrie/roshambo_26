--!strict
-- Lantern telegraph: drives the canyon lanterns as one synchronized display of the last
-- World Throw. Each lantern face carries a SurfaceGui (thin kumiko frame + the shrine
-- double-line motif + a glyph). On reveal every lantern smoothly fades to the new throw;
-- ~10s before the next reveal they fade blank (the lull before the next strike). All
-- lanterns read the same round events, so they pulse in unison up both gorge walls.
-- Both lantern kinds are discovered by CollectionService tag, workspace-wide and folder-agnostic:
-- "BlockLantern" (square deck/newel lanterns — 4-face SurfaceGui) and "RoundLantern" (chōchin — one
-- face on the paper barrel's glyph plate). A lantern displays because it is TAGGED, never because of
-- its name or folder. Glyphs/events mirror BoardController.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local GLYPH = { R = "○", P = "─", S = "∧" }
local INK = Color3.fromRGB(36, 30, 24) -- dark silhouette on the glowing warm paper
local LATTICE = Color3.fromRGB(40, 32, 24)
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLANK_LEAD = 10 -- blank this many seconds before the next reveal

local glyphLabels: { TextLabel } = {}
local current: string? = nil -- the throw currently displayed (nil = blanked)

-- one face: a thin kumiko frame + shrine double-line + a fading glyph label
local function buildFace(part: BasePart, face: Enum.NormalId)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LanternFace"
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    -- match the canvas aspect to the face so glyphs aren't stretched on a non-square box
    -- (a 1×1.5 lantern face with a square canvas squashes the ○ into a vertical oval)
    local sz = part.Size
    local fw, fh
    if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
        fw, fh = sz.Z, sz.Y
    elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
        fw, fh = sz.X, sz.Z
    else -- Front / Back
        fw, fh = sz.X, sz.Y
    end
    gui.CanvasSize = Vector2.new(100, math.round(100 * fh / fw))
    gui.LightInfluence = 0 -- the paper reads at full warmth regardless of world light
    gui.Parent = part

    local function bar(px: number, py: number, sx: number, sy: number)
        local f = Instance.new("Frame")
        f.BackgroundColor3 = LATTICE
        f.BorderSizePixel = 0
        f.Position = UDim2.fromScale(px, py)
        f.Size = UDim2.fromScale(sx, sy)
        f.Parent = gui
    end
    -- two verticals (full height), tops at y0.05 → they rise 0.10 above the top horizontal
    bar(0.21, 0.05, 0.03, 0.9)
    bar(0.76, 0.05, 0.03, 0.9)
    -- shrine double-line near the top; the horizontals overhang the verticals by 0.10 each
    -- side (= how far the verticals rise above the top line), spanning x0.11..0.89
    bar(0.11, 0.15, 0.78, 0.028)
    bar(0.11, 0.205, 0.78, 0.028)

    -- glyph (a touch shorter) centered in the clear field below the double-line
    local g = Instance.new("TextLabel")
    g.Name = "Glyph"
    g.BackgroundTransparency = 1
    g.Position = UDim2.fromScale(0.22, 0.34)
    g.Size = UDim2.fromScale(0.56, 0.52)
    g.Font = Enum.Font.GothamBlack
    g.TextColor3 = INK
    g.TextScaled = false
    g.TextSize = 44
    -- late-arriving lanterns (streamed in) pick up whatever throw is currently shown
    if current then
        g.Text = GLYPH[current] or ""
        g.TextTransparency = 0
    else
        g.Text = ""
        g.TextTransparency = 1
    end
    g.Parent = gui
    table.insert(glyphLabels, g)
end

-- soft warm "lit-from-within" glow on the block lantern body — a feathered radial sprite that
-- reads as lamplight (a Neon ball reads as a hard sphere on the small box). Custom glow image.
local GLOW_TEXTURE = "rbxassetid://135490760661320"
local function buildGlow(part: BasePart)
    local bb = Instance.new("BillboardGui")
    bb.Name = "LanternGlow"
    bb.Adornee = part
    bb.Size = UDim2.fromScale(2.1, 2.1) -- larger than the box so the soft halo extends past the silhouette
    bb.LightInfluence = 0
    bb.Parent = part
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromScale(1, 1)
    img.Image = GLOW_TEXTURE
    img.ImageColor3 = Color3.fromRGB(255, 208, 155)
    img.ImageTransparency = 0.1
    img.Parent = bb
end

-- Block lanterns are discovered by the "BlockLantern" CollectionService tag, workspace-wide and
-- folder-agnostic (symmetric with the round chōchin's "RoundLantern" tag) — so a lantern displays
-- because it is TAGGED, never because of its name or which folder it happens to sit in. The tag is
-- baked into the Rojo decks (Overlook/SwitchbackDeck via their builders) and set on place-only deck
-- lanterns (FallsLanding, JunctionLanding, …). GetInstanceAddedSignal covers streamed/late arrivals.
local built: { [Instance]: boolean } = {}
local function buildBlockFace(d: Instance)
    if d:IsA("BasePart") and not built[d] then
        built[d] = true
        for _, face in FACES do
            buildFace(d, face)
        end
        buildGlow(d)
    end
end
for _, p in CollectionService:GetTagged("BlockLantern") do
    buildBlockFace(p)
end
CollectionService:GetInstanceAddedSignal("BlockLantern"):Connect(buildBlockFace)

-- round lanterns (chōchin): the glyph is printed on the paper, not floating in front. The
-- geometry supplies a thin transparent "GlyphPlate" sitting just proud of the barrel's front,
-- tagged "RoundLantern" and oriented so its Front face points outward toward the path; we put a
-- world-space SurfaceGui on it. Being real surface geometry, it's occluded normally and scales
-- with distance — so it reads as ink on the paper rather than a billboard label.
local function buildRoundFace(part: Instance)
    if not part:IsA("BasePart") or built[part] then
        return
    end
    built[part] = true
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LanternFace"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 50
    gui.LightInfluence = 0
    gui.Parent = part
    local g = Instance.new("TextLabel")
    g.Name = "Glyph"
    g.BackgroundTransparency = 1
    g.AnchorPoint = Vector2.new(0.5, 0.5)
    g.Position = UDim2.fromScale(0.5, 0.5)
    g.Size = UDim2.fromScale(0.7, 0.7)
    g.Font = Enum.Font.GothamBlack
    g.TextColor3 = INK
    g.TextScaled = true
    g:SetAttribute("ShownT", 0.2) -- round glyphs rest at 20% transparency (softer ink on the paper)
    -- late-arriving lanterns pick up whatever throw is currently shown
    if current then
        g.Text = GLYPH[current] or ""
        g.TextTransparency = 0.2
    else
        g.Text = ""
        g.TextTransparency = 1
    end
    g.Parent = gui
    table.insert(glyphLabels, g)
end
for _, p in CollectionService:GetTagged("RoundLantern") do
    buildRoundFace(p)
end
CollectionService:GetInstanceAddedSignal("RoundLantern"):Connect(buildRoundFace)

-- ===== telegraph state =====
local pending: string? = nil -- the throw revealed but not yet shown (waiting for the drum to settle)
local lastRevealAt = 0
local period = 25 -- measured reveal→reveal; default a touch over a round
local shownAt: number? = nil -- when the current glyph went up (for the blank lead)

local function fadeBlank()
    for _, g in glyphLabels do
        TweenService:Create(g, FADE, { TextTransparency = 1 }):Play()
    end
end

local function fadeShown()
    -- each label rises to its own resting transparency (block faces 0, round chōchin 0.2)
    for _, g in glyphLabels do
        local st = (g:GetAttribute("ShownT") :: number?) or 0
        TweenService:Create(g, FADE, { TextTransparency = st }):Play()
    end
end

local function showThrow(throw: string)
    local glyph = GLYPH[throw]
    if not glyph then
        return
    end
    fadeBlank() -- fade the old symbol down…
    task.delay(0.4, function() -- swap after the (slower) fade-out completes
        for _, g in glyphLabels do
            g.Text = glyph
        end
        fadeShown() -- …swap, then fade the new one up
    end)
end

-- The reveal arrives ~3s before the throw drum settles; hold the new throw as `pending`
-- and only swap the lanterns when the drum REST cue fires (so they change in time with it).
RevealTheater.OnClientEvent:Connect(function(r)
    local now = os.clock()
    if lastRevealAt > 0 then
        local p = now - lastRevealAt
        if p > 5 and p < 120 then
            period = p
        end
    end
    lastRevealAt = now
    pending = r.worldThrow
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" and pending then
        current = pending
        pending = nil
        shownAt = os.clock()
        showThrow(current)
    end
end)

-- blank ~BLANK_LEAD seconds before the next reveal (period − lead after this one)
RunService.Heartbeat:Connect(function()
    if shownAt and current and os.clock() - shownAt >= math.max(4, period - BLANK_LEAD) then
        fadeBlank()
        current = nil
        shownAt = nil
    end
end)
