--!strict
-- Minimal play HUD — the hangout default (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md).
--
-- WHY THE LAYOUT IS WHAT IT IS. Roblox has already carved up this screen:
--   bottom-left  : the movement thumbstick. Untouchable.
--   bottom-right : the jump button, roughly the right 3-13% of the screen. Untouchable.
--   top-left     : the unibar, and the CHAT WINDOW expanding down beneath it. In a hangout chat is
--                  open most of the time, so this is the worst corner on the screen, not a safe one.
--   top-right    : the player list, expanding down. (The old pick cluster lived here — the furthest
--                  reach from either thumb AND the corner the player list grows into.)
--   top-centre   : free. Roblox claims nothing there.
-- Hence: PLATE top-centre; THROW AREA bottom-right but INBOARD of the jump button, with the tape
-- ABOVE the buttons (the buttons stay closest to where the thumb rests; the tape is read, never
-- touched); the round TIMER as a hairline along the bottom edge, competing with nothing.
--
-- Every information element MUST stay Active = false. Frames and labels default to false, but
-- setting it true anywhere here punches a permanent hole in the camera-drag surface, which is
-- the whole right side of the screen on touch. The whole interactive budget is: the three throw
-- buttons, the plate, and EXACTLY ONE slot button (see `setSlot`). The pot disc is a Frame and
-- must stay a Frame — it carries no action, only the figure.
--
-- This file RENDERS HudModel; it never re-derives it. main.client.luau owns the wiring and fires
-- EventBus.HudState(inputs, aux):
--   inputs : a HudModel.Inputs
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, pick = string?,
--             timerKnown = boolean }
--            `tape` is already spoiler-gated by the wiring — paint it as given.
-- Picks travel back the other way on EventBus.HudPick, banking on EventBus.HudBank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HudModel = require(shared:WaitForChild("HudModel"))
local HudLayout = require(shared:WaitForChild("HudLayout"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ZenDojo HUD palette (moved here from main.client.luau, which no longer builds UI).
local INK = Color3.fromRGB(60, 45, 28)
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local IVORY = Color3.fromRGB(244, 238, 222)
local IVORY_DIM = Color3.fromRGB(206, 199, 182)
local AGED_IVORY = Color3.fromRGB(146, 112, 64) -- ivory patinas warm + dark with age
local TAN_RIM = Color3.fromRGB(176, 164, 138)
local GOLD = Color3.fromRGB(212, 176, 102)
local WASHI = Color3.fromRGB(26, 24, 28)
local WIN_GREEN = Color3.fromRGB(86, 196, 120)
local LOSS_RED = Color3.fromRGB(206, 86, 86)
local SEL_BLUE = Color3.fromRGB(74, 150, 255)
local POT_RED = Color3.fromRGB(190, 58, 52) -- the pot disc; deeper than LOSS_RED so it reads as a seal

-- SELECTION PALETTE (gate 2026-08-02). The owner asked for two things that pull against each other:
-- the unchosen throws should "almost disappear", AND they should carry orange/yellow. The synthesis
-- is a WARM/COOL SPLIT: the chosen tile goes cool and LIT (a pale blue wash, a SEL_BLUE glyph, a
-- thick blue rim and a soft halo behind it), the two unchosen go warm and FAINT (a dark amber tile
-- at 0.55 transparency with an amber glyph). They recede as asked, and the hue split is what makes
-- the choice legible in one glance at arm's length on a phone — without lighting three things up.
local SEL_WASH = Color3.fromRGB(226, 238, 255) -- the chosen tile's face: ivory pulled cool
local SEL_INK = Color3.fromRGB(16, 44, 92) -- keyline under the blue glyph, so it still has an edge
local SEL_HALO = Color3.fromRGB(120, 186, 255) -- the glow behind the chosen tile
local WARM_FACE = Color3.fromRGB(104, 76, 40) -- the unchosen tiles' face: dark amber, nearly gone
local WARM_GLYPH = Color3.fromRGB(226, 158, 62) -- their glyph: orange, dim
local WARM_RIM = Color3.fromRGB(150, 108, 52)
local GLYPH_OUTLINE = Color3.new(1, 1, 1) -- the resting keyline, as Glyphs.render defaults it

local THROWS = { "R", "P", "S" }

-- The touch tier. `TouchEnabled and not KeyboardEnabled` is the Roblox convention for "a phone or
-- tablet, not a laptop with a touchscreen", and it is what Studio's device emulator sets — so the
-- shrunken cluster can be checked in Studio without a handset. The BOOLEAN is decided here; the
-- NUMBERS come from HudLayout, which OnboardingController reads from the same switch so its safe
-- band shrinks with the cluster instead of hovering over the old footprint.
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- The skeleton — every number OnboardingController also has to know, so that it can place a card
-- beside this HUD without covering a live button — lives in shared/HudLayout. SCALE, not pixels, for
-- the jump-button clearance: the jump button occupies roughly the right 3-13% of the screen, and a
-- pixel offset guessed against a desktop viewport is wrong on every phone. Numbers only this file
-- uses stay here.
local JUMP_CLEARANCE = HudLayout.JUMP_CLEARANCE
local EDGE = HudLayout.EDGE

local PLATE_W, PLATE_H = 300, HudLayout.PLATE_H
-- BTN_W tracks BTN_H (the buttons are square) off the SAME shared scale, so "50% smaller" shrinks
-- the cluster in both axes rather than leaving three squat letterboxes.
local BTN_H = if TOUCH then HudLayout.BTN_H_TOUCH else HudLayout.BTN_H
local BTN_W = BTN_H
local BTN_GAP = if TOUCH then 8 else 10
local TAPE_N = 5
local TILE = if TOUCH then HudLayout.TILE_TOUCH else HudLayout.TILE
local TILE_GAP = if TOUCH then 4 else 6
local BADGE = if TOUCH then 7 else 9
local ROW_GAP = HudLayout.ROW_GAP
local AREA_W = 3 * BTN_W + 2 * BTN_GAP
local AREA_H = if TOUCH then HudLayout.AREA_H_TOUCH else HudLayout.AREA_H
local TIMER_H = 3
local TIMER_H_HOT = 7 -- the escalation thickens the hairline as well as reddening it
local TOAST_SECONDS = 4
local TOAST_MAX = 6

-- The one slot above the throw row: the pot indicator, or the fate prompt, or nothing.
local SLOT_H = HudLayout.SLOT_H
local SLOT_GAP = HudLayout.SLOT_GAP
local DISC = SLOT_H
local BANK_W = 128
local FATE_W = 190

local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboHud"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency
    s.Parent = parent
    return s
end

-- A centred, inset box to hang a glyph in. Glyphs.render fills its parent (aspect-locked), so
-- without this the symbol would run edge to edge on the tile.
local function glyphBox(parent: Instance, inset: number): Frame
    local box = Instance.new("Frame")
    box.Name = "GlyphBox"
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromScale(inset, inset)
    box.BackgroundTransparency = 1
    box.Parent = parent
    return box
end

-- All three symbols built ONCE per tape tile and toggled by Visible. A tile's symbol changes every
-- round; rebuilding two ImageLabels per tile per publish would churn instances for no reason.
local function glyphSet(parent: Instance, inset: number): { [string]: Frame }
    local box = glyphBox(parent, inset)
    local set: { [string]: Frame } = {}
    for _, sym in THROWS do
        local g = Glyphs.render(box, sym, INK)
        g.Visible = false
        set[sym] = g
    end
    return set
end

local function fadeGlyph(g: Frame, transparency: number)
    for _, child in g:GetChildren() do
        if child:IsA("ImageLabel") then
            child.ImageTransparency = transparency
        end
    end
end

-- Recolour a rendered glyph in place. `Glyphs.render` builds two named ImageLabels — an "Outline"
-- behind and a "Core" in front — so this addresses them by NAME rather than by child order. A glyph
-- for a symbol the module has no image for simply has neither child, and this no-ops.
local function tintGlyph(g: Frame, core: Color3, outline: Color3)
    local c = g:FindFirstChild("Core")
    if c and c:IsA("ImageLabel") then
        c.ImageColor3 = core
    end
    local o = g:FindFirstChild("Outline")
    if o and o:IsA("ImageLabel") then
        o.ImageColor3 = outline
    end
end

-- ===== Plate: top-centre, the one band Roblox does not claim =====
-- The ONLY interactive information element: it is the door to the maximal ledger, so maximal costs
-- no new persistent button anywhere on screen.
local plate = Instance.new("TextButton")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(0.5, 0)
plate.Position = UDim2.new(0.5, 0, 0, EDGE)
plate.Size = UDim2.fromOffset(PLATE_W, PLATE_H)
plate.BackgroundColor3 = WASHI
plate.BackgroundTransparency = 0.3
plate.BorderSizePixel = 0
plate.AutoButtonColor = false
plate.Text = ""
plate.Parent = gui
corner(plate, 6)
stroke(plate, GOLD, 1, 0.35)
plate.MouseButton1Click:Connect(function()
    EventBus.OpenLedger:Fire()
end)

local CELLS = {
    { key = "streak", caption = "STREAK" },
    { key = "pot", caption = "POT" },
    { key = "points", caption = "POINTS" },
}
local cellValue: { [string]: TextLabel } = {}
for i, cell in CELLS do
    local holder = Instance.new("Frame")
    holder.Name = cell.caption
    holder.Position = UDim2.fromScale((i - 1) / 3, 0)
    holder.Size = UDim2.fromScale(1 / 3, 1)
    holder.BackgroundTransparency = 1
    holder.Parent = plate

    local caption = Instance.new("TextLabel")
    caption.Name = "Caption"
    caption.Position = UDim2.fromOffset(0, 5)
    caption.Size = UDim2.new(1, 0, 0, 11)
    caption.BackgroundTransparency = 1
    caption.TextColor3 = GOLD
    caption.TextTransparency = 0.25
    caption.TextSize = 10
    caption.Font = Enum.Font.GothamBold
    caption.Text = cell.caption
    caption.Parent = holder

    local value = Instance.new("TextLabel")
    value.Name = "Value"
    value.AnchorPoint = Vector2.new(0, 1)
    value.Position = UDim2.new(0, 0, 1, -5)
    value.Size = UDim2.new(1, 0, 0, 22)
    value.BackgroundTransparency = 1
    value.TextColor3 = INK_CREAM
    value.TextSize = 20
    value.Font = Enum.Font.GothamBold
    value.Text = "0"
    value.Parent = holder

    cellValue[cell.key] = value
end

-- ===== Throw area: bottom-right, inboard of the jump button =====
local throwArea = Instance.new("Frame")
throwArea.Name = "ThrowArea"
throwArea.AnchorPoint = Vector2.new(1, 1)
throwArea.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -EDGE)
throwArea.Size = UDim2.fromOffset(AREA_W, AREA_H)
throwArea.BackgroundTransparency = 1
throwArea.Parent = gui

-- Tape ABOVE the buttons: five square tiles, newest LEFT, ageing ivory -> amber, with a corner dot
-- for the personal WIN/SAFE/LOSS result.
local tapeRow = Instance.new("Frame")
tapeRow.Name = "Tape"
tapeRow.AnchorPoint = Vector2.new(1, 0)
tapeRow.Position = UDim2.fromScale(1, 0)
tapeRow.Size = UDim2.fromOffset(TAPE_N * (TILE + TILE_GAP) - TILE_GAP, TILE)
tapeRow.BackgroundTransparency = 1
tapeRow.Parent = throwArea

type TapeTile = { frame: Frame, glyphs: { [string]: Frame }, badge: Frame, rim: UIStroke }
local tapeTiles: { TapeTile } = {}
for i = 1, TAPE_N do
    local tile = Instance.new("Frame")
    tile.Name = `T{i}`
    tile.Position = UDim2.fromOffset((i - 1) * (TILE + TILE_GAP), 0)
    tile.Size = UDim2.fromOffset(TILE, TILE)
    tile.BackgroundColor3 = IVORY
    tile.BackgroundTransparency = 0.1
    tile.BorderSizePixel = 0
    tile.Visible = false
    tile.Parent = tapeRow
    corner(tile, 4)
    local tileRim = stroke(tile, TAN_RIM, 1, 0.3)

    local badge = Instance.new("Frame")
    badge.Name = "Badge"
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Position = UDim2.fromScale(0.88, 0.12)
    badge.Size = UDim2.fromOffset(BADGE, BADGE)
    badge.BackgroundColor3 = WIN_GREEN
    badge.BorderSizePixel = 0
    badge.ZIndex = 3
    badge.Visible = false
    badge.Parent = tile
    corner(badge, 5)

    tapeTiles[i] = { frame = tile, glyphs = glyphSet(tile, 0.66), badge = badge, rim = tileRim }
end

-- Mirrors the last rendered `view.throwsEnabled` so a tap can be refused without re-deriving the
-- rule. Advisory only: the server is what actually refuses a pick.
local canThrow = false

-- The tile the player just PRESSED, lit before any round trip and cleared by the next render (which
-- runs at 10Hz, and immediately on the pick's own publish). See the press handlers below.
local pressedSym: string? = nil

local HALO_BLEED = 7 -- how far the chosen tile's glow spills past its edge
local PRESS_SCALE = 0.93 -- how far a press depresses the tile
local PRESS_DOWN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_UP = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type ThrowTile = { button: TextButton, glyph: Frame, rim: UIStroke, halo: Frame, scale: UIScale }
local throwTiles: { [string]: ThrowTile } = {}
for i, sym in THROWS do
    -- The chosen tile's glow. A SIBLING of the button at ZIndex 0, not a child: under the default
    -- Sibling ZIndexBehavior a child always draws ABOVE its parent, so a halo parented to the button
    -- would sit on top of the glyph instead of behind the tile. A Frame, and left at its default
    -- Active = false — the interactive budget on this surface is the three buttons, the plate and
    -- the one slot button, and every sinking pixel is a permanent hole in the camera-drag surface.
    local halo = Instance.new("Frame")
    halo.Name = sym .. "Halo"
    halo.AnchorPoint = Vector2.new(0, 1)
    halo.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP) - HALO_BLEED, 1, HALO_BLEED)
    halo.Size = UDim2.fromOffset(BTN_W + 2 * HALO_BLEED, BTN_H + 2 * HALO_BLEED)
    halo.BackgroundColor3 = SEL_HALO
    halo.BackgroundTransparency = 0.55
    halo.BorderSizePixel = 0
    halo.ZIndex = 0
    halo.Visible = false
    halo.Parent = throwArea
    corner(halo, 12)

    local b = Instance.new("TextButton")
    b.Name = sym
    b.AnchorPoint = Vector2.new(0, 1)
    b.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP), 1, 0)
    b.Size = UDim2.fromOffset(BTN_W, BTN_H)
    b.BackgroundColor3 = IVORY_DIM -- starts disabled; the first HudState paints the real state
    b.BackgroundTransparency = 0.25
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = throwArea
    corner(b, 8)
    local rim = stroke(b, TAN_RIM, 2, 0.1)

    -- A UIScale, deliberately, for the press depress: it is the one property `render` never writes,
    -- so the 10Hz repaint cannot fight the tween half-way through it.
    local scale = Instance.new("UIScale")
    scale.Parent = b

    throwTiles[sym] = {
        button = b,
        glyph = Glyphs.render(glyphBox(b, 0.62), sym, INK),
        rim = rim,
        halo = halo,
        scale = scale,
    }
end

-- THE SELECTION TREATMENT, in one place so the optimistic press paint and the authoritative render
-- can never disagree about what "chosen" looks like. Four states, not two:
--   chosen        : cool and LIT — pale wash, blue glyph, thick blue rim, halo behind.
--   not chosen    : warm and FAINT — dark amber at 0.55, amber glyph. They recede as asked; the
--                   warm/cool split against the blue is what makes the choice unmistakable without
--                   lighting three tiles up at once.
--   throwable     : the resting ivory tile.
--   not throwable : ivory dimmed, as before — a whole round is closed, not one option among three.
local function paintThrows(pick: string?, enabled: boolean)
    for _, sym in THROWS do
        local t = throwTiles[sym]
        if pick == sym then
            t.button.BackgroundColor3 = SEL_WASH
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, SEL_BLUE, SEL_INK)
            fadeGlyph(t.glyph, 0)
            t.rim.Color = SEL_BLUE
            t.rim.Thickness = 4
            t.rim.Transparency = 0
            t.halo.Visible = true
        elseif pick then
            t.button.BackgroundColor3 = WARM_FACE
            t.button.BackgroundTransparency = 0.55
            tintGlyph(t.glyph, WARM_GLYPH, WARM_FACE)
            fadeGlyph(t.glyph, 0.5)
            t.rim.Color = WARM_RIM
            t.rim.Thickness = 1
            t.rim.Transparency = 0.55
            t.halo.Visible = false
        elseif enabled then
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0)
            t.rim.Color = TAN_RIM
            t.rim.Thickness = 2
            t.rim.Transparency = 0.1
            t.halo.Visible = false
        else
            t.button.BackgroundColor3 = IVORY_DIM
            t.button.BackgroundTransparency = 0.25
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0.45)
            t.rim.Color = TAN_RIM
            t.rim.Thickness = 2
            t.rim.Transparency = 0.1
            t.halo.Visible = false
        end
    end
end

-- A tap must ALWAYS visibly do something. The buttons carry AutoButtonColor = false (the palette is
-- hand-painted), so before this a press produced no feedback whatsoever — and roughly a fifth of
-- every round sits in TALLY/REVEAL where `canThrow` is legitimately false, so a perfectly good tap
-- landing in that window vanished without a trace. That is the "I have to click the throw button
-- twice, but there's nothing indicating that" report. The depress fires on EVERY press, accepted or
-- refused; the blue light only on an accepted one.
local function depress(t: ThrowTile)
    t.scale.Scale = 1
    local down = TweenService:Create(t.scale, PRESS_DOWN, { Scale = PRESS_SCALE })
    down.Completed:Connect(function()
        TweenService:Create(t.scale, PRESS_UP, { Scale = 1 }):Play()
    end)
    down:Play()
end

-- How long the optimistic light survives without the pick coming back on HudState. In the normal
-- case it is superseded within a frame (main.client sets `myPick` and publishes on HudPick, all
-- client-local — the server round trip is not in this path). This only has to catch a press that
-- never became a click, e.g. the finger slid off the button.
local PRESS_HOLD_SECONDS = 0.5
local pressSeq = 0

for _, sym in THROWS do
    local tile = throwTiles[sym]
    tile.button.MouseButton1Down:Connect(function()
        depress(tile)
        if not canThrow then
            return
        end
        pressedSym = sym
        pressSeq += 1
        local seq = pressSeq
        paintThrows(sym, canThrow) -- lit on the PRESS, ahead of any round trip
        task.delay(PRESS_HOLD_SECONDS, function()
            if pressSeq == seq and pressedSym == sym then
                pressedSym = nil -- let the next render tell the truth
            end
        end)
    end)
    tile.button.MouseButton1Click:Connect(function()
        if canThrow then
            EventBus.HudPick:Fire(sym)
        end
    end)
end

-- ===== The slot: directly above the throw row, one tenant at a time =====
-- POT: the figure in a red disc with BANK THESE beside it. Throwing again IS riding, so there is
-- no counterpart button and nothing to "resolve" — the pot indicator is a standing statement of
-- what is unbanked, not a wager prompt.
-- FATE: after a LOSS, ACCEPT YOUR FATE. A LOSS forfeits the pot, so pointsAtStake is always 0
-- while fate-bound and the two can never want the slot at once (HudModel decides; this only paints).
local slotRow = Instance.new("Frame")
slotRow.Name = "Slot"
slotRow.Active = false
slotRow.AnchorPoint = Vector2.new(1, 1)
slotRow.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP))
slotRow.Size = UDim2.fromOffset(AREA_W, SLOT_H)
slotRow.BackgroundTransparency = 1
slotRow.Parent = gui

local potGroup = Instance.new("Frame")
potGroup.Name = "Pot"
potGroup.Active = false
potGroup.Size = UDim2.fromScale(1, 1)
potGroup.BackgroundTransparency = 1
potGroup.Visible = false
potGroup.Parent = slotRow

local bankButton = Instance.new("TextButton")
bankButton.Name = "BankThese"
bankButton.AnchorPoint = Vector2.new(1, 0.5)
bankButton.Position = UDim2.fromScale(1, 0.5)
bankButton.Size = UDim2.fromOffset(BANK_W, SLOT_H)
bankButton.BackgroundColor3 = WASHI
bankButton.BackgroundTransparency = 0.15
bankButton.BorderSizePixel = 0
bankButton.AutoButtonColor = false
bankButton.TextColor3 = INK_CREAM
bankButton.TextSize = 15
bankButton.Font = Enum.Font.GothamBold
bankButton.Text = "BANK THESE"
bankButton.Parent = potGroup
corner(bankButton, 6)
stroke(bankButton, GOLD, 1, 0.3)

-- A Frame, deliberately. It says how many points are unbanked; it is not a button, and making it
-- one would both add a second live control to this slot and punch another hole in the drag surface.
local potDisc = Instance.new("Frame")
potDisc.Name = "Disc"
potDisc.Active = false
potDisc.AnchorPoint = Vector2.new(1, 0.5)
potDisc.Position = UDim2.new(1, -(BANK_W + SLOT_GAP), 0.5, 0)
potDisc.Size = UDim2.fromOffset(DISC, DISC)
potDisc.BackgroundColor3 = POT_RED
potDisc.BackgroundTransparency = 0
potDisc.BorderSizePixel = 0
potDisc.Parent = potGroup
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0) -- a disc, not a rounded box
    c.Parent = potDisc
end

local potFigure = Instance.new("TextLabel")
potFigure.Name = "Figure"
potFigure.Active = false
potFigure.AnchorPoint = Vector2.new(0.5, 0.5)
potFigure.Position = UDim2.fromScale(0.5, 0.5)
potFigure.Size = UDim2.fromScale(0.76, 0.52) -- 3^n runs long fast; let the figure shrink to fit
potFigure.BackgroundTransparency = 1
potFigure.TextColor3 = INK_CREAM
potFigure.TextScaled = true
potFigure.Font = Enum.Font.GothamBlack
potFigure.Text = "0"
potFigure.Parent = potDisc

local fateButton = Instance.new("TextButton")
fateButton.Name = "AcceptFate"
fateButton.AnchorPoint = Vector2.new(1, 0.5)
fateButton.Position = UDim2.fromScale(1, 0.5)
fateButton.Size = UDim2.fromOffset(FATE_W, SLOT_H)
fateButton.BackgroundColor3 = LOSS_RED
fateButton.BackgroundTransparency = 0.1
fateButton.BorderSizePixel = 0
fateButton.AutoButtonColor = false
fateButton.TextColor3 = INK_CREAM
fateButton.TextSize = 15
fateButton.Font = Enum.Font.GothamBold
fateButton.Text = "ACCEPT YOUR FATE"
fateButton.Visible = false
fateButton.Parent = slotRow
corner(fateButton, 6)
stroke(fateButton, GOLD, 1, 0.3)

bankButton.MouseButton1Click:Connect(function()
    EventBus.HudBank:Fire()
end)
fateButton.MouseButton1Click:Connect(function()
    EventBus.Cue:Fire({ kind = "acceptFate" })
end)

-- THE ONLY place either tenant's Visible is written, and both are written from the same `kind` on
-- every call. That is what makes "two slot buttons can never be live at once" true by
-- construction rather than by discipline: there is no assignment that can set one without
-- clearing the other, and a Visible = false GuiObject receives no input at all.
local pulse: Tween? = nil

local function setSlot(kind: string, pulses: boolean)
    potGroup.Visible = kind == "pot"
    fateButton.Visible = kind == "fate"

    if pulses and potGroup.Visible then
        if not pulse then
            local t = TweenService:Create(
                potDisc,
                TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { BackgroundTransparency = 0.55 }
            )
            t:Play()
            pulse = t
        end
    elseif pulse then
        local t = pulse :: Tween
        t:Cancel()
        pulse = nil
        potDisc.BackgroundTransparency = 0 -- Cancel leaves the property mid-tween; put it back
    end
end

-- ===== Round timer: a hairline along the bottom edge, depleting =====
local timer = Instance.new("Frame")
timer.Name = "RoundTimer"
timer.AnchorPoint = Vector2.new(0, 1)
timer.Position = UDim2.fromScale(0, 1)
timer.Size = UDim2.fromOffset(0, TIMER_H)
timer.BackgroundColor3 = GOLD
timer.BackgroundTransparency = 0.2
timer.BorderSizePixel = 0
timer.Parent = gui

-- ===== Escalation: a large centred count, shown only when HudModel says so =====
-- Active = false: this is a LABEL, not a button. It covers the centre of the screen, which is the
-- middle of the camera-drag surface — sinking input here would make the canyon unrotatable for the
-- seconds it is up. The arming rule lives in HudModel and is never second-guessed here.
local escalation = Instance.new("Frame")
escalation.Name = "Escalation"
escalation.Active = false
escalation.AnchorPoint = Vector2.new(0.5, 0.5)
escalation.Position = UDim2.fromScale(0.5, 0.42)
escalation.Size = UDim2.new(0.8, 0, 0, 130) -- scale width: a fixed 460px overflows a small phone
escalation.BackgroundTransparency = 1
escalation.Visible = false
escalation.Parent = gui

local escalationCount = Instance.new("TextLabel")
escalationCount.Name = "Count"
escalationCount.Active = false
escalationCount.Size = UDim2.new(1, 0, 0, 92)
escalationCount.BackgroundTransparency = 1
escalationCount.TextColor3 = INK_CREAM
escalationCount.TextSize = 84
escalationCount.Font = Enum.Font.GothamBlack
escalationCount.Text = ""
escalationCount.Parent = escalation
stroke(escalationCount, WASHI, 3, 0.15)

local escalationPrompt = Instance.new("TextLabel")
escalationPrompt.Name = "Prompt"
escalationPrompt.Active = false
escalationPrompt.AnchorPoint = Vector2.new(0.5, 1)
escalationPrompt.Position = UDim2.fromScale(0.5, 1)
escalationPrompt.Size = UDim2.new(1, 0, 0, 30)
escalationPrompt.BackgroundTransparency = 1
escalationPrompt.TextColor3 = INK_CREAM
escalationPrompt.TextSize = 24
escalationPrompt.Font = Enum.Font.GothamBold
escalationPrompt.Text = "CHOOSE A THROW"
escalationPrompt.Parent = escalation
stroke(escalationPrompt, WASHI, 2, 0.2)

-- ===== Toast: the transient notice that replaced the persistent prose ticker =====
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, EDGE + PLATE_H + 8)
toast.Size = UDim2.new(0.5, 0, 0, 26)
toast.AutomaticSize = Enum.AutomaticSize.Y -- a long notice wraps and grows rather than clipping
toast.BackgroundColor3 = WASHI
toast.BackgroundTransparency = 0.3
toast.BorderSizePixel = 0
toast.TextColor3 = INK_CREAM
toast.TextSize = 15
toast.TextWrapped = true
toast.Font = Enum.Font.Gotham
toast.Text = ""
toast.Visible = false
toast.Parent = gui
corner(toast, 6)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = toast
end

local toastQueue: { string } = {}
local function enqueueToast(line: string)
    if typeof(line) ~= "string" or line == "" then
        return
    end
    if #toastQueue >= TOAST_MAX then
        table.remove(toastQueue, 1)
    end
    table.insert(toastQueue, line)
end

EventBus.Toast.Event:Connect(enqueueToast)
-- TickerMessage's last renderer was the prose ticker this HUD replaced (BoardController's
-- jumbotron no longer exists). EconomyController still fires it with real player-facing notices,
-- so route it here rather than dropping those on the floor.
EventBus.TickerMessage.Event:Connect(enqueueToast)

task.spawn(function()
    while true do
        if #toastQueue > 0 then
            toast.Text = table.remove(toastQueue, 1) :: string
            toast.Visible = true
            task.wait(TOAST_SECONDS)
            if #toastQueue == 0 then
                toast.Visible = false
            end
        else
            task.wait(0.2)
        end
    end
end)

-- ===== Render =====
-- The round's full span is not on the wire; take it from the largest countdown seen since ACTIVE
-- opened, so the hairline depletes against the real round length whatever the server's phase
-- durations are.
local span = 0
local lastPhase = ""

local function render(inputs: any, aux: any)
    local view = HudModel.view(inputs, aux.session)
    canThrow = view.throwsEnabled

    cellValue.streak.Text = tostring(view.plate.streak)
    cellValue.pot.Text = tostring(view.plate.pot)
    cellValue.points.Text = tostring(view.plate.points)

    potFigure.Text = tostring(view.plate.pot)
    setSlot(view.slot, view.potPulses)

    -- The authoritative pick wins the moment it lands; until then a press that has not yet come
    -- back through main.client keeps its own tile lit (`pressedSym`), so a held finger does not
    -- flicker the selection off on the next 10Hz repaint.
    if aux.pick then
        pressedSym = nil
    end
    paintThrows(aux.pick or pressedSym, view.throwsEnabled)

    local entries = aux.tape or {}
    local count = math.min(#entries, TAPE_N)
    for i = 1, TAPE_N do
        local slot = tapeTiles[i]
        local entry = entries[i]
        slot.frame.Visible = entry ~= nil
        if entry then
            -- Age across the VISIBLE count so the oldest shown always reaches full amber: a clear
            -- newest -> oldest gradient even when only a few rounds are in the tape.
            slot.frame.BackgroundColor3 = IVORY:Lerp(AGED_IVORY, (i - 1) / math.max(1, count - 1))
            for _, sym in THROWS do
                slot.glyphs[sym].Visible = sym == entry.worldThrow
            end
            if entry.result == "WIN" then
                slot.badge.BackgroundColor3 = WIN_GREEN
                slot.badge.Visible = true
            elseif entry.result == "LOSS" then
                slot.badge.BackgroundColor3 = LOSS_RED
                slot.badge.Visible = true
            elseif entry.result == "SAFE" then
                slot.badge.BackgroundColor3 = GOLD
                slot.badge.Visible = true
            else
                slot.badge.Visible = false
            end
        end
    end

    -- The hairline thickens and reddens under the escalation threshold — the ambient half of the
    -- same signal the centred count carries.
    local height = if view.escalate then TIMER_H_HOT else TIMER_H
    timer.BackgroundColor3 = if view.escalate then LOSS_RED else GOLD
    -- A round with no lockout on the wire has no span to deplete against. Showing a constant
    -- would pin the hairline full and motionless while the real lockout came and went, which
    -- reads as "plenty of time" and is a lie. Show nothing instead; throws stay enabled.
    if lastPhase ~= inputs.phase then
        span = 0
    end
    if inputs.phase == "ACTIVE" and aux.timerKnown ~= false then
        span = math.max(span, view.secondsLeft)
        local frac = if span > 0 then math.clamp(view.secondsLeft / span, 0, 1) else 0
        timer.Size = UDim2.new(frac, 0, 0, height)
    else
        timer.Size = UDim2.fromOffset(0, height)
    end
    lastPhase = inputs.phase

    escalation.Visible = view.escalate
    if view.escalate then
        escalationCount.Text = tostring(math.ceil(view.secondsLeft))
    end
end

EventBus.HudState.Event:Connect(render)

-- ===== Day/night contrast: authored against night, kept legible as day comes up =====
-- The ivory/washi palette above is authored against the dark canyon (DayNightLockT pins the
-- owner's dusk look at 0.40 — not ours to change here). As nightFactor falls toward day the
-- canyon goes pale and that palette loses contrast. This darkens the plate backing and deepens
-- the tape-tile rims to hold legibility across the cycle; it is a contrast pass, not a second
-- visual design, and nothing here moves geometry.
--
-- Scope is deliberately the two elements render() never writes: the plate's own backing, and
-- each tape tile's UIStroke. render() repaints the throw buttons' fill/rim and the tape tiles'
-- fill every call for game-state reasons (selection, ageing) unrelated to time of day — driving
-- those same properties here would just get overwritten on the next HudState event.
--
-- Dual subscription, same as WaterVfxDayNight/YamadoroDayNight/PaperLanternDayNight/
-- AmbientDayNight: EventBus.DayNight for live updates, plus the DayNightConfig
-- CurrentNightFactor attribute as a start-order-proof prime + backstop, since this controller
-- can build after the day/night controller's last fire.
--
-- Capture authored values ONCE, on an attribute, and always re-derive from that capture — same
-- rule as WaterVfxDayNight. Reading back a live property would read whatever the previous apply
-- just wrote, compounding a little further on every dusk. And always LERP toward the day target,
-- never scale: VfxNightDim's lesson is that an authored value of zero can never be moved by
-- multiplication, so lerp is the only operation that stays correct regardless of what gets
-- authored here later, even though today's authored numbers all happen to be non-zero.
local dayNightConfig = ReplicatedStorage:WaitForChild("DayNightConfig")

local PLATE_DAY_TRANSPARENCY = 0.05 -- authored (night) is 0.3; more opaque reads darker against a pale sky
local RIM_DAY_COLOR = INK -- authored (night) is TAN_RIM, too pale to hold a line at noon
local RIM_DAY_THICKNESS = 2 -- authored (night) is 1
local RIM_DAY_TRANSPARENCY = 0.05 -- authored (night) is 0.3

local AUTHORED_TRANSPARENCY = "AuthoredTransparency"
local AUTHORED_THICKNESS = "AuthoredThickness"
local AUTHORED_COLOR = "AuthoredColor"

local function captureNumber(inst: Instance, key: string, live: number): number
    local stored = inst:GetAttribute(key)
    if typeof(stored) == "number" then
        return stored
    end
    inst:SetAttribute(key, live)
    return live
end

local function captureColor(inst: Instance, key: string, live: Color3): Color3
    local stored = inst:GetAttribute(key)
    if typeof(stored) == "Color3" then
        return stored
    end
    inst:SetAttribute(key, live)
    return live
end

local function lerpNumber(a: number, b: number, t: number): number
    return a + (b - a) * t
end

local nightFactor: number = dayNightConfig:GetAttribute("CurrentNightFactor") or 0

local function applyContrast()
    local plateAuthored = captureNumber(plate, AUTHORED_TRANSPARENCY, plate.BackgroundTransparency)
    plate.BackgroundTransparency = lerpNumber(PLATE_DAY_TRANSPARENCY, plateAuthored, nightFactor)

    for _, tile in tapeTiles do
        local rim = tile.rim
        local authoredColor = captureColor(rim, AUTHORED_COLOR, rim.Color)
        local authoredThickness = captureNumber(rim, AUTHORED_THICKNESS, rim.Thickness)
        local authoredTransparency = captureNumber(rim, AUTHORED_TRANSPARENCY, rim.Transparency)

        rim.Color = RIM_DAY_COLOR:Lerp(authoredColor, nightFactor)
        rim.Thickness = lerpNumber(RIM_DAY_THICKNESS, authoredThickness, nightFactor)
        rim.Transparency = lerpNumber(RIM_DAY_TRANSPARENCY, authoredTransparency, nightFactor)
    end
end

applyContrast() -- prime before the first EventBus fire

EventBus.DayNight.Event:Connect(function(payload)
    nightFactor = payload.nightFactor
    applyContrast()
end)

dayNightConfig:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    nightFactor = dayNightConfig:GetAttribute("CurrentNightFactor") or nightFactor
    applyContrast()
end)
