--!strict
-- Lantern telegraph: drives the canyon lanterns as one synchronized display of the last
-- World Throw. Each lantern face carries a SurfaceGui (thin kumiko frame + the shrine
-- double-line motif + a glyph). On reveal every lantern smoothly fades to the new throw;
-- ~10s before the next reveal they fade blank (the lull before the next strike). All
-- lanterns read the same round events, so they pulse in unison up both gorge walls.
-- Lanterns are found by name ("*Lantern") for now; a CollectionService tag will generalize
-- this canyon-wide. Glyphs/events mirror BoardController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local stage = workspace:WaitForChild("RoshamboStage")

local GLYPH = { R = "○", P = "─", S = "∧" }
local INK = Color3.fromRGB(36, 30, 24) -- dark silhouette on the glowing warm paper
local LATTICE = Color3.fromRGB(40, 32, 24)
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLANK_LEAD = 10 -- blank this many seconds before the next reveal

local glyphLabels: { TextLabel } = {}
local current: string? = nil -- the throw currently displayed (nil = blanked)

-- one face: a thin kumiko frame + shrine double-line + a fading glyph label
local function buildFace(part: BasePart, face: Enum.NormalId)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LanternFace"
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(100, 100)
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

-- build faces for every lantern, now and as they replicate/stream in (handles the
-- startup race where the Overlook model hasn't arrived when this script first runs).
local built: { [BasePart]: boolean } = {}
local function tryBuild(d: Instance)
    if d:IsA("BasePart") and (d.Name :: string):match("Lantern$") and not built[d] then
        built[d] = true
        for _, face in FACES do
            buildFace(d, face)
        end
    end
end
for _, d in stage:GetDescendants() do
    tryBuild(d)
end
stage.DescendantAdded:Connect(tryBuild)

-- ===== telegraph state =====
local pending: string? = nil -- the throw revealed but not yet shown (waiting for the drum to settle)
local lastRevealAt = 0
local period = 25 -- measured reveal→reveal; default a touch over a round
local shownAt: number? = nil -- when the current glyph went up (for the blank lead)

local function fadeAll(t: number)
    for _, g in glyphLabels do
        TweenService:Create(g, FADE, { TextTransparency = t }):Play()
    end
end

local function showThrow(throw: string)
    local glyph = GLYPH[throw]
    if not glyph then
        return
    end
    fadeAll(1) -- fade the old symbol down…
    task.delay(0.2, function()
        for _, g in glyphLabels do
            g.Text = glyph
        end
        fadeAll(0) -- …swap, then fade the new one up
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
        fadeAll(1)
        current = nil
        shownAt = nil
    end
end)
