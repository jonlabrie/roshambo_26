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
--   top-centre   : free. Roblox claims nothing there, and nothing lives there any more either.
-- Hence: THROW AREA bottom-right but INBOARD of the jump button, with the tape BELOW the buttons
-- (the buttons stay closest to where the thumb rests; the tape is read, never touched) and the
-- PLATE as one line at the bottom of that same cluster, left of the tape (see "Plate: one line
-- at the bottom of the cluster" below); the round TIMER as a hairline along the bottom edge,
-- competing with nothing.
--
-- The plate briefly lived in the right margin above the jump button, measured at runtime — the
-- owner superseded that mid-implementation for the bottom row instead. Nothing in this HUD is
-- positioned against geometry Roblox owns any more.
--
-- Every information element MUST stay Active = false. Frames and labels default to false, but
-- setting it true anywhere here punches a permanent hole in the camera-drag surface, which is
-- the whole right side of the screen on touch. The whole interactive budget is: the three throw
-- buttons, the one bank button (see `setBank`), and the ledger door (see "The ledger door")
-- — the plate is a pure display, not a door; that job belongs to the ledger door alone.
--
-- This file RENDERS HudModel; it never re-derives it. main.client.luau owns the wiring and fires
-- EventBus.HudState(inputs, aux):
--   inputs : a HudModel.Inputs
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, timerKnown = boolean }
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
local RollingNumber = require(shared:WaitForChild("RollingNumber"))
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

-- BTN_W tracks BTN_H (the buttons are square) off the SAME shared scale, so "50% smaller" shrinks
-- the cluster in both axes rather than leaving three squat letterboxes.
local BTN_H = if TOUCH then HudLayout.BTN_H_TOUCH else HudLayout.BTN_H
local BTN_W = BTN_H
local BTN_GAP = if TOUCH then 8 else 10
local TAPE_N = 5
local TILE = if TOUCH then HudLayout.TILE_TOUCH else HudLayout.TILE
local TILE_GAP = if TOUCH then 4 else 6
-- The tape row's own width — the plate (below) registers off its left edge, and the tape's own
-- Size uses it too, so it is pulled out here rather than left as a repeated inline expression.
local TAPE_W = TAPE_N * (TILE + TILE_GAP) - TILE_GAP
local BADGE = if TOUCH then 7 else 9
local ROW_GAP = HudLayout.ROW_GAP
local AREA_W = 3 * BTN_W + 2 * BTN_GAP
local AREA_H = if TOUCH then HudLayout.AREA_H_TOUCH else HudLayout.AREA_H
-- How far the bank+throws+tape cluster's own TOP edge sits from the screen bottom, at this tier —
-- the escalation overlay (below) clamps against this so it can never sit on top of the bank
-- button on a short viewport.
local CLUSTER_TOP_FROM_BOTTOM = if TOUCH
    then HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH
    else HudLayout.CLUSTER_TOP_FROM_BOTTOM
local TIMER_H = 3
local TIMER_H_HOT = 7 -- the escalation thickens the hairline as well as reddening it
local TOAST_SECONDS = 4
local TOAST_MAX = 6
-- The gap between the throw cluster and the two things registered against its edges: the ledger
-- door (left of the buttons) and the plate (left of the tape). One constant, two uses.
local LEDGER_GAP = 8

-- The bank button, directly above the throw row.
local BANK_W = 150

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

-- ===== Counting: wallet figures animate rather than snap =====
-- Every figure the HUD shows for the wallet — the points and streak in the plate's line, and
-- the pot on the bank button — animates to its new value instead of snapping (spec: "Numbers
-- count rather than jump"). This is what makes banking read as a TRANSFER: press BANK 27 POINTS
-- and the button's figure runs down to zero while the balance below runs up by the same amount,
-- both driven off the SAME ProfileUpdate, with no special case for "this one's a bank" — see
-- `render`, below, where all three counters are ticked from the one `view`.
--
-- `RollingNumber` is the pure arithmetic of one count; `Counter` is the small bit of STATE this
-- file wraps around it — what's currently displayed, what it's counting toward, and when the
-- current leg began. `tickCounter` is the driver, and it is keyed on the TARGET changing, not on
-- how often it gets called: `render` runs at 10Hz, and restarting the count on every call would
-- pin every number at its first frame forever — precisely how the bank pulse (`setBank`, below)
-- failed earlier in this branch by cancelling and restarting its tween on every repaint.
type Counter = {
    -- What `tickCounter` returned last time. Also the next `from` if the target changes again
    -- mid-count, so a second change continues from where the number visibly IS rather than
    -- snapping back to whatever it was counting from before.
    displayed: number,
    target: number,
    from: number,
    startedAt: number?, -- os.clock() the current leg began, or nil once it has settled
}

local function newCounter(initial: number): Counter
    return { displayed = initial, target = initial, from = initial, startedAt = nil }
end

local function tickCounter(c: Counter, target: number): number
    if target ~= c.target then
        c.from = c.displayed
        c.target = target
        c.startedAt = os.clock()
    end
    if c.startedAt then
        local t = (os.clock() - c.startedAt) / RollingNumber.DURATION
        c.displayed = RollingNumber.valueAt(c.from, c.target, t)
        if t >= 1 then
            c.startedAt = nil -- settled; further calls at the same target are free until it moves
        end
    else
        c.displayed = c.target
    end
    return c.displayed
end

local pointsCounter = newCounter(0)
local streakCounter = newCounter(0)
local potCounter = newCounter(0)

-- ===== Plate: one line at the bottom of the cluster, normally hidden =====
-- Superseded the right-margin placement (owner, mid-implementation): the jump-button measurement
-- is gone entirely. The plate is now a single line at the bottom of the throw cluster, exactly
-- as tall as a tape tile and right-aligned LEDGER_GAP left of the tape's own left edge, so the
-- bottom row reads as one band. AutomaticSize = X: it reserves no dead space when the line is
-- short (no streak riding).
--
-- NORMALLY HIDDEN. Points are not a thing you need at a glance — a riding pot already has its
-- own always-visible bank button. The plate reveals on the ledger door's first tap and on any
-- change to the figures it shows (see `revealPlate` and the change-guard in `render`), holds for
-- PLATE_HOLD, then fades over PLATE_FADE. It stays genuinely inert throughout — Active is false
-- on the Frame and the label both; the ledger door (below) is the only door.
local PLATE_HOLD = 2
local PLATE_FADE = 0.35

local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(1, 1)
plate.AutomaticSize = Enum.AutomaticSize.X
plate.Size = UDim2.fromOffset(0, TILE)
-- Fixed off the SAME shared right reference (1 - JUMP_CLEARANCE) the throw cluster, the bank
-- button and the ledger door all register to — LEDGER_GAP left of the tape's own left edge
-- (offset -TAPE_W from that reference), bottom-aligned with the tape (D = EDGE from the gui's
-- bottom, same as the tape). AutomaticSize grows the frame LEFTWARD from this anchored right
-- edge, so a longer line (a streak riding) never creeps toward the tape. See the task report for
-- the overlap arithmetic against the tape, the ledger door and the timer hairline.
plate.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + LEDGER_GAP), 1, -EDGE)
plate.BackgroundColor3 = WASHI
plate.BackgroundTransparency = 0.3
plate.BorderSizePixel = 0
plate.Visible = false
plate.Parent = gui
corner(plate, 6)
local plateStroke = stroke(plate, GOLD, 1, 0.35)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = plate
end

-- ONE label for the whole line: `900`, or `×3  900` when a streak rides (see `render`). No
-- stroke on it — contrast comes from the Frame's opaque backing, never an outline on text.
local plateLabel = Instance.new("TextLabel")
plateLabel.Name = "Line"
plateLabel.AutomaticSize = Enum.AutomaticSize.X
plateLabel.Size = UDim2.fromScale(0, 1)
plateLabel.BackgroundTransparency = 1
plateLabel.TextColor3 = INK_CREAM
plateLabel.TextSize = 15
plateLabel.Font = Enum.Font.GothamBold
plateLabel.Text = "0"
plateLabel.Parent = plate

-- The plate's own stroke is never day/night-adjusted (only the tape tile rims and the backing
-- are — see `applyContrast`), so its "fully revealed" transparency is a plain constant.
-- `plateRestTransparency` is NOT a constant: `applyContrast` keeps it in sync with the current
-- day/night lerp, and `revealPlate` reads it rather than a hardcoded literal, so a reveal in full
-- daylight does not sit at the authored-for-night value until the next ambient tick corrects it.
local PLATE_STROKE_REST_TRANSPARENCY = 0.35
local plateRestTransparency = 0.3

-- Reveal/hide state. A GENERATION counter — the same pattern as `pressSeq`/`potPulse` above —
-- so a fade cancelled by a newer reveal cannot let its own stale `Completed` callback fire late
-- and hide a plate the newer reveal just showed.
local plateGen = 0
-- True from the instant a reveal starts until the fade has ACTUALLY finished (hold + fade both
-- count). The ledger door's two-stage test below reads exactly this, never a timer: a control
-- that is still visible must still be answerable, whether that visibility is the hold or the
-- tail of the fade.
local plateVisible = false
local plateFadeTweens: { Tween } = {}

local function cancelPlateFade()
    for _, t in plateFadeTweens do
        t:Cancel()
    end
    table.clear(plateFadeTweens)
end

local function startPlateFade(gen: number)
    if gen ~= plateGen then
        return -- superseded by a newer reveal; this fade no longer applies
    end
    local info = TweenInfo.new(PLATE_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    -- The fade takes the backing AND the stroke with the text — a washi panel that stays put
    -- while its number dissolves is worse than either alone.
    local bgTween = TweenService:Create(plate, info, { BackgroundTransparency = 1 })
    local textTween = TweenService:Create(plateLabel, info, { TextTransparency = 1 })
    local strokeTween = TweenService:Create(plateStroke, info, { Transparency = 1 })
    plateFadeTweens = { bgTween, textTween, strokeTween }
    bgTween.Completed:Connect(function()
        if gen == plateGen then
            plateVisible = false
            plate.Visible = false
        end
    end)
    bgTween:Play()
    textTween:Play()
    strokeTween:Play()
end

-- Reveal on the ledger door's first tap, and on any change to the figures (the change-guard
-- lives in `render`, not here — this function only knows how to show). Re-revealing mid-hold or
-- mid-fade CANCELS the fade and restores full opacity instead of stacking: the plate is either
-- fully there or on its way out, never two competing states at once.
local function revealPlate()
    plateGen += 1
    local gen = plateGen
    cancelPlateFade()
    plate.Visible = true
    plate.BackgroundTransparency = plateRestTransparency -- Cancel leaves properties mid-tween
    plateLabel.TextTransparency = 0
    plateStroke.Transparency = PLATE_STROKE_REST_TRANSPARENCY
    plateVisible = true
    task.delay(PLATE_HOLD, function()
        startPlateFade(gen)
    end)
end

-- ===== Throw area: bottom-right, inboard of the jump button =====
local throwArea = Instance.new("Frame")
throwArea.Name = "ThrowArea"
throwArea.AnchorPoint = Vector2.new(1, 1)
throwArea.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -EDGE)
throwArea.Size = UDim2.fromOffset(AREA_W, AREA_H)
throwArea.BackgroundTransparency = 1
throwArea.Parent = gui

-- Tape BELOW the buttons (owner's ruling): five square tiles, newest LEFT, ageing ivory ->
-- amber, with a corner dot for the personal WIN/SAFE/LOSS result. It is read, never touched,
-- so it takes the outermost edge and the buttons take the reachable one.
local tapeRow = Instance.new("Frame")
tapeRow.Name = "Tape"
tapeRow.AnchorPoint = Vector2.new(1, 1)
tapeRow.Position = UDim2.fromScale(1, 1)
tapeRow.Size = UDim2.fromOffset(TAPE_W, TILE)
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

-- Mirrors the last rendered `view.chosen`, so the press handler below can tell a "choose" tap
-- (nothing chosen yet) from a tap that would only raise a SWITCH? prompt (something already is).
-- Advisory, same as `canThrow` above.
local chosenSym: string? = nil

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
    -- Active = false — the interactive budget on this surface is the three buttons, the one bank
    -- button and the ledger door, and every sinking pixel is a permanent hole in the camera-drag
    -- surface.
    local halo = Instance.new("Frame")
    halo.Name = sym .. "Halo"
    halo.AnchorPoint = Vector2.new(0, 0)
    halo.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP) - HALO_BLEED, -HALO_BLEED)
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
    b.AnchorPoint = Vector2.new(0, 0)
    b.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP), 0)
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

-- ===== SWITCH?: the question raised over a glyph the player has just tapped =====
-- It sits ON the button rather than beside it, because the button is no longer offering an
-- option — it is asking a question, and covering the glyph is the clearest way to say so.
-- Answering it UNLOCKS all three; it does not select this one. That is what makes backing out
-- of a round possible at all.
--
-- No UIStroke on the label. Contrast comes from the opaque backing behind it (see the spec's
-- §3): an outline on 13px type fills the counters in and reads as a smear.
local switchPill = Instance.new("Frame")
switchPill.Name = "SwitchPrompt"
switchPill.AnchorPoint = Vector2.new(0.5, 0.5)
-- Flush with the button's own width, not inset 8px off it: at the old BTN_W - 8 the touch pill
-- was only 36px wide (BTN_W = BTN_H_TOUCH = 44) and TextScaled alone drives "SWITCH?" (13px
-- GothamBold measures ~57-64px unscaled) down to ~8px there — below the ~9px legibility floor.
-- At the full BTN_W the touch pill is 44px, which lands the scaled text at ~9-10px, still
-- flush with (never wider than) the button beneath it.
switchPill.Size = UDim2.fromOffset(BTN_W, 24)
switchPill.BackgroundColor3 = WASHI
switchPill.BackgroundTransparency = 0
switchPill.BorderSizePixel = 0
switchPill.ZIndex = 4
switchPill.Visible = false
switchPill.Parent = throwArea
corner(switchPill, 6)
stroke(switchPill, SEL_BLUE, 2, 0)

local switchLabel = Instance.new("TextLabel")
switchLabel.Name = "Copy"
switchLabel.Size = UDim2.fromScale(1, 1)
switchLabel.BackgroundTransparency = 1
switchLabel.TextColor3 = INK_CREAM
switchLabel.TextSize = 13
switchLabel.Font = Enum.Font.GothamBold
switchLabel.Text = "SWITCH?"
switchLabel.ZIndex = 5
switchLabel.Parent = switchPill

-- TextScaled + a MaxTextSize constraint, same pattern as `bankButton` above: at BTN_W-8 the pill
-- is only 36px wide on touch (BTN_W = BTN_H_TOUCH = 44) while "SWITCH?" at 13px GothamBold runs
-- ~57-64px unscaled — it clipped to roughly "WITC". Scaling down still reads at this width; the
-- constraint just stops it growing past 13px on the wider desktop pill.
switchLabel.TextScaled = true
do
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 13
    constraint.Parent = switchLabel
end

local THROW_INDEX: { [string]: number } = {}
for i, sym in THROWS do
    THROW_INDEX[sym] = i
end

-- The buttons are anchored to the TOP of throwArea (the tape moved below them since Task 6), so
-- the pill's y is measured from that top edge — BTN_H / 2, not from the bottom.
local function setSwitchPrompt(symbol: string?)
    switchPill.Visible = symbol ~= nil
    if symbol then
        local i = THROW_INDEX[symbol]
        switchPill.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, BTN_H / 2)
    end
end

-- THE SELECTION TREATMENT, in one place so the optimistic press paint and the authoritative render
-- can never disagree about what "chosen" looks like. Five states, not two:
--   chosen        : cool and LIT — pale wash, blue glyph, thick blue rim, halo behind.
--   prompted      : lifted OUT of the dimmed treatment — this button is carrying a question, and
--                   a question on a greyed-out control reads as unanswerable.
--   not chosen    : warm and FAINT — dark amber, nearly gone, amber glyph. They "almost
--                   disappear" (owner's words); the warm/cool split against the blue is what
--                   makes the choice unmistakable without lighting three tiles up at once.
--   throwable     : the resting ivory tile.
--   not throwable : ivory dimmed, as before — a whole round is closed, not one option among three.
local function paintThrows(pick: string?, enabled: boolean, prompted: string?)
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
        elseif sym == prompted then
            -- Lifted OUT of the dimmed state: this button is carrying a question, and a
            -- question on a greyed-out control reads as unanswerable.
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0.2)
            t.rim.Color = SEL_BLUE
            t.rim.Thickness = 2
            t.rim.Transparency = 0.2
            t.halo.Visible = false
        elseif pick then
            t.button.BackgroundColor3 = WARM_FACE
            t.button.BackgroundTransparency = 0.75
            tintGlyph(t.glyph, WARM_GLYPH, WARM_FACE)
            fadeGlyph(t.glyph, 0.7)
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

-- The chosen glyph PULSES. A static light says "this is selected"; a pulse says "this is what
-- is going in", which is the thing the player is being asked to be sure about.
--
-- Guarded on the symbol actually changing, same as `setBank`'s pot pulse: `render` runs at 10Hz,
-- and cancelling/restarting a 1.1s tween on every repaint would give it 3% of its travel and
-- render as a static element, not a pulse — this exact bug already shipped once on this branch
-- in `setBank` and had to be fixed.
local chosenPulse: Tween? = nil
local pulsingSym: string? = nil
local function setChosenPulse(symbol: string?)
    if pulsingSym == symbol then
        return
    end
    pulsingSym = symbol
    if chosenPulse then
        chosenPulse:Cancel()
        chosenPulse = nil
    end
    for _, sym in THROWS do
        throwTiles[sym].halo.BackgroundTransparency = 0.55
    end
    if symbol then
        -- Assign-then-Play, not a cast chained straight off `Create(...)`: a `)` at the start of
        -- a line followed by `(` parses in Lua/Luau as a CALL on the previous expression's
        -- result, not a new statement — `Create(...)\n(x):Play()` silently becomes
        -- `Create(...)(x):Play()`, calling the Tween as if it were a function. This is the same
        -- pattern `setBank`'s pot pulse already uses.
        local t = TweenService:Create(
            throwTiles[symbol].halo,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.15 }
        )
        t:Play()
        chosenPulse = t
    end
end

-- A tap must ALWAYS visibly do something. The buttons carry AutoButtonColor = false (the palette is
-- hand-painted), so before this a press produced no feedback whatsoever — and roughly a fifth of
-- every round sits in TALLY/REVEAL where `canThrow` is legitimately false, so a perfectly good tap
-- landing in that window vanished without a trace. That is the "I have to click the throw button
-- twice, but there's nothing indicating that" report. The depress fires on EVERY press, accepted or
-- refused; the blue light only on an accepted one.
-- The tween itself, factored out from `depress` so the ledger door (below) gets the same
-- press feedback without needing a full ThrowTile — every AutoButtonColor = false button in
-- this file goes through one of these two, never silent on press.
local function pressDepress(scale: UIScale)
    scale.Scale = 1
    local down = TweenService:Create(scale, PRESS_DOWN, { Scale = PRESS_SCALE })
    down.Completed:Connect(function()
        TweenService:Create(scale, PRESS_UP, { Scale = 1 }):Play()
    end)
    down:Play()
end

local function depress(t: ThrowTile)
    pressDepress(t.scale)
end

-- How long the optimistic light survives without the pick coming back on HudState. In the normal
-- case it is superseded within a frame (main.client sets `chosen` and publishes on HudPick, all
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
        -- The optimistic chosen-paint is only honest when the tap is a "choose" — nothing chosen
        -- yet. When something already is, the tap only raises a SWITCH? prompt (see `paintThrows`'s
        -- `prompted` branch), and lighting a third glyph fully chosen here would assert something
        -- false for up to PRESS_HOLD_SECONDS, until `render` corrects it. `chosenSym` mirrors
        -- `view.chosen` for exactly this check — deliberately not `HudModel.tapAction`, which needs
        -- a full `Inputs` this controller does not hold.
        if chosenSym ~= nil then
            return
        end
        pressedSym = sym
        pressSeq += 1
        local seq = pressSeq
        paintThrows(sym, canThrow, nil) -- lit on the PRESS, ahead of any round trip
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

-- ===== The bank button: directly above the throw row =====
-- ONE control, not a readout plus a button. The figure belongs IN the thing that acts on it —
-- a separate red disc saying "27" beside a generic BANK THESE made the player join two
-- elements to read one fact. Throwing again IS riding, so there is no counterpart button and
-- nothing to resolve.
local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.AnchorPoint = Vector2.new(1, 1)
bankButton.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP))
bankButton.Size = UDim2.fromOffset(BANK_W, HudLayout.BANK_H)
bankButton.BackgroundColor3 = POT_RED
bankButton.BackgroundTransparency = 0.15
bankButton.BorderSizePixel = 0
bankButton.AutoButtonColor = false
bankButton.TextColor3 = INK_CREAM
bankButton.TextSize = 15
bankButton.Font = Enum.Font.GothamBold
bankButton.Text = ""
bankButton.Visible = false
bankButton.Parent = gui
corner(bankButton, 8)
stroke(bankButton, GOLD, 1, 0.3)

-- 3^n runs long fast (the old potFigure's note): BANK 19683 POINTS already measures ~150px at
-- 15px GothamBold, and the pot only grows from there. TextScaled + a MaxTextSize constraint lets
-- the label shrink to fit a long figure instead of clipping it.
bankButton.TextScaled = true
do
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 15
    constraint.Parent = bankButton
end

-- Mirrors `view.pot > 0` (the MODEL's pot, not the displayed one) so a tap can be refused once
-- the pot is actually gone — set in `render`, read here. Deliberately NOT tied to the button's
-- own visibility: the button stays visible for the full 0.5s drain because the drain IS the
-- point (see `render`'s call into `setBank`), but that visible window is an animation of
-- something that has ALREADY happened, not a live offer. This is the opposite asymmetry from
-- the `≡`, whose visible window IS its answerable window — here the armed window is the
-- SHORTER of the two, not the same one.
local bankArmed = false

bankButton.MouseButton1Click:Connect(function()
    if not bankArmed then
        return
    end
    EventBus.HudBank:Fire()
end)

-- The pulse says "this is unacknowledged", nothing more. `setBank` runs at 10Hz off `render`
-- (EventBus.HudState), so the tween is touched ONLY when the desired pulsing state actually
-- changes — cancelling and restarting a 0.9s tween every 100ms would give it 3% of its travel
-- and render as a static button with imperceptible jitter, not a pulse. This is why the code
-- this replaced (`setSlot`) guarded its tween the same way.
--
-- `visible` and `pot` are the caller's (`render`, below): `visible` follows the DISPLAYED pot
-- (the counter's current value), not the model's, and `pot` IS the displayed figure — this
-- function paints whatever it's handed and knows nothing about `RollingNumber` itself. `pulses`
-- is still model-driven (`view.potPulses`), and that is what keeps this guard correct without
-- any extra coordination: the model clears `potPulses` (it is gated on `pointsAtStake > 0`) the
-- INSTANT a bank or a loss lands, before the display has counted down at all, so `want = visible
-- and pulses` already goes false at that exact moment — a button lingering at a nonzero
-- DISPLAYED value during the count-down is never left pulsing, because `pulses` itself dropped
-- out from under it on the very same tick the model changed.
local potPulse: Tween? = nil
local pulsing = false
local function setBank(visible: boolean, pot: number, pulses: boolean)
    bankButton.Visible = visible
    if visible then
        bankButton.Text = `BANK {pot} POINTS`
    end
    local want = visible and pulses
    if want == pulsing then
        return
    end
    pulsing = want
    if potPulse then
        potPulse:Cancel()
        potPulse = nil
        bankButton.BackgroundTransparency = 0.15 -- Cancel leaves the property mid-tween
    end
    if want then
        local t = TweenService:Create(
            bankButton,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.6 }
        )
        t:Play()
        potPulse = t
    end
end

-- ===== The ledger door =====
-- The fourth and last interactive element in the minimal HUD, after the three throws and the
-- bank button. It exists because moving the plate off the jump/camera strip made the plate
-- inert, and a tap on the plate had been the ledger's ONLY entry point — deliberately, so that
-- maximal cost no persistent button. That trade is now spent: a display with no interactive
-- elements has nowhere it needs sinking touches any more, so the door becomes a button.
--
-- Placed AGAINST the cluster rather than into a corner. The teahouse toggle that used to live in
-- the bottom-right corner was deleted because it collided with the throw row on a narrow
-- viewport; anchoring to the cluster's own left edge means this moves with the cluster and
-- cannot repeat that.
--
-- TWO-STAGE (owner, mid-implementation): the first tap on an unrevealed plate reveals it; a
-- second tap while ANYTHING from that reveal is still on screen — the hold or the fade, see
-- `plateVisible` — opens the ledger instead. A tap that lands after the plate has fully faded
-- reveals again. A double-tap from cold therefore opens the ledger, so nobody has to learn the
-- two stages to reach it the obvious way.
local LEDGER_SIZE = if TOUCH then HudLayout.BTN_H_TOUCH else 40

local ledgerButton = Instance.new("TextButton")
ledgerButton.Name = "LedgerDoor"
ledgerButton.AnchorPoint = Vector2.new(1, 1)
-- Bottom-aligned with the throw button row, not the tape: `throwArea` spans
-- [EDGE, EDGE + AREA_H] from the gui's bottom edge, and since Task 6 the buttons sit at the
-- TOP of that frame — so the button row's own bottom edge is EDGE + AREA_H - BTN_H from the
-- bottom. Inboard of the throw cluster by its own width plus LEDGER_GAP, off the SAME right
-- edge (1 - JUMP_CLEARANCE) the cluster and the bank button both register to.
ledgerButton.Position = UDim2.new(1 - JUMP_CLEARANCE, -(AREA_W + LEDGER_GAP), 1, -(EDGE + AREA_H - BTN_H))
ledgerButton.Size = UDim2.fromOffset(LEDGER_SIZE, LEDGER_SIZE)
ledgerButton.BackgroundColor3 = WASHI
ledgerButton.BackgroundTransparency = 0.3
ledgerButton.BorderSizePixel = 0
ledgerButton.AutoButtonColor = false
ledgerButton.Text = ""
ledgerButton.Parent = gui
corner(ledgerButton, 8)
stroke(ledgerButton, GOLD, 1, 0.3)

-- The hamburger glyph is DRAWN, not typed: a "≡" (U+2261) in GothamBold depends on that font
-- actually carrying the codepoint, and this is the ONLY door to the ledger — a missing glyph
-- would read as a broken control with no recourse. Three thin Frames instead: font-independent,
-- unambiguous, and inert like everything else non-throw/non-bank in this file (`Active` stays
-- at its default `false` on every bar — they carry no input of their own, the button beneath
-- them does).
local LEDGER_BAR_H = if TOUCH then 3 else 2
local LEDGER_BAR_GAP = if TOUCH then 6 else 5
local LEDGER_BAR_INSET = 8 -- horizontal padding each side, inside the button
local LEDGER_BARS_H = 3 * LEDGER_BAR_H + 2 * LEDGER_BAR_GAP
for i = 1, 3 do
    local bar = Instance.new("Frame")
    bar.Name = `Bar{i}`
    bar.AnchorPoint = Vector2.new(0.5, 0.5)
    bar.Position = UDim2.new(
        0.5,
        0,
        0.5,
        -LEDGER_BARS_H / 2 + LEDGER_BAR_H / 2 + (i - 1) * (LEDGER_BAR_H + LEDGER_BAR_GAP)
    )
    bar.Size = UDim2.new(1, -2 * LEDGER_BAR_INSET, 0, LEDGER_BAR_H)
    bar.BackgroundColor3 = INK_CREAM
    bar.BorderSizePixel = 0
    bar.ZIndex = 2 -- above the button (ZIndex 1 by default), so the bars are never occluded
    bar.Parent = ledgerButton
end

local ledgerScale = Instance.new("UIScale")
ledgerScale.Parent = ledgerButton

ledgerButton.MouseButton1Down:Connect(function()
    pressDepress(ledgerScale)
end)
ledgerButton.MouseButton1Click:Connect(function()
    -- "Is anything on screen", not a 2s timer: `plateVisible` covers the hold AND the fade, so
    -- a tap while the line is mid-fade still lands on the ledger rather than doing nothing — a
    -- control that is still visible must still be answerable.
    if plateVisible then
        EventBus.OpenLedger:Fire()
    else
        revealPlate()
    end
end)

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
local ESCALATION_H = 154 -- kept as a named constant: updateEscalationPosition needs it too, below

local escalation = Instance.new("Frame")
escalation.Name = "Escalation"
escalation.Active = false
escalation.AnchorPoint = Vector2.new(0.5, 0.5)
-- Y is set by `updateEscalationPosition`, below, not a bare fromScale(0.5, 0.42): that fraction
-- is the resting position on a tall screen, but on a short landscape phone it collides with the
-- bank button. Task 9 grew this frame 130 -> 154 to stop its own two labels overlapping, and at
-- 130 it cleared the bank button by 0.3px on an 844x390 viewport — both constraints are real, so
-- this frame cannot simply shrink back. See `updateEscalationPosition` for the clamp.
escalation.Position = UDim2.fromScale(0.5, 0.42)
-- scale width: a fixed 460px overflows a small phone. Fixed height is 130px of CONTENT (count
-- [0,92] + an 8px gap + prompt [100,130]) plus 24px the UIPadding below eats (12 top + 12
-- bottom) — 154, not 130. If the padding ever changes, grow this to match or the two labels
-- overlap inside the unchanged content box.
escalation.Size = UDim2.new(0.8, 0, 0, ESCALATION_H)
-- Opaque backing, not a stroke on the text. The count and prompt used to float over open
-- canyon with strokes standing in for contrast (see the spec's §3) — a real backing plate
-- instead, same as every other readable surface in this HUD.
escalation.BackgroundColor3 = WASHI
escalation.BackgroundTransparency = 0.1
escalation.Visible = false
escalation.Parent = gui
corner(escalation, 10)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = escalation
end

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
-- No UIStroke on the label. Contrast comes from the opaque WASHI backing on `escalation` above
-- (see the spec's §3) — a stroke here would outline every glyph instead.

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
-- No UIStroke on the label — same rationale as escalationCount above.

-- Clamp the overlay's Y against the cluster instead of trusting the 0.42 scale fraction on every
-- viewport. `gui.AbsoluteSize.Y` already excludes the topbar inset (ScreenGui's default
-- IgnoresGuiInset = false), so it is the same H a hand check against a device's reported
-- viewport height would use. Resting position is 0.42 * H; the clamp keeps the overlay's own
-- BOTTOM edge at least ESCALATION_MARGIN above the cluster's top edge (CLUSTER_TOP_FROM_BOTTOM,
-- from the bottom of the screen), and the smaller of the two wins. On a tall screen the clamp
-- never binds, so this reduces to the original 0.42 fraction; on a short landscape phone it
-- lifts the overlay clear of the bank button instead of trusting a fraction that only ever held
-- at the reviewer's own reference height.
local ESCALATION_MARGIN = ROW_GAP -- the same "cluster row" gap used everywhere else in this file
local function updateEscalationPosition()
    local h = gui.AbsoluteSize.Y
    if h <= 0 then
        return -- not laid out yet; AbsoluteSize firing again once it is will re-run this
    end
    local resting = 0.42 * h
    local clamped = h - CLUSTER_TOP_FROM_BOTTOM - ESCALATION_MARGIN - ESCALATION_H / 2
    escalation.Position = UDim2.new(0.5, 0, 0, math.min(resting, clamped))
end
updateEscalationPosition()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateEscalationPosition)

-- ===== Toast: the transient notice that replaced the persistent prose ticker =====
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
-- The plate has vacated top-centre entirely (first for the right margin, then the bottom row),
-- so there is nothing left to offset against up here. Sits at EDGE, the band the plate vacated.
toast.Position = UDim2.new(0.5, 0, 0, EDGE)
toast.Size = UDim2.new(0.5, 0, 0, 26)
toast.AutomaticSize = Enum.AutomaticSize.Y -- a long notice wraps and grows rather than clipping
toast.BackgroundColor3 = WASHI
toast.BackgroundTransparency = 0.05
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

-- Start at nil, not 0/false: the very first render has nothing to compare against, and treating
-- "no prior value" as a change would auto-reveal the plate the instant the HUD loads, which is
-- exactly the "normally hidden" rule being broken on frame one.
local lastPlatePoints: number? = nil
local lastPlateStreak: number? = nil

local function render(inputs: any, aux: any)
    local view = HudModel.view(inputs, aux.session)
    canThrow = view.throwsEnabled
    chosenSym = view.chosen

    -- Reveal is keyed on the TARGET having changed, not on `render` running: `render` is a 10Hz
    -- repaint, and a reveal re-armed every tick would hold forever and never fade — precisely how
    -- the bank pulse (`setBank`, below) failed when it wasn't guarded this way.
    if
        lastPlatePoints ~= nil
        and (view.plate.points ~= lastPlatePoints or view.plate.streak ~= lastPlateStreak)
    then
        revealPlate()
    end
    lastPlatePoints = view.plate.points
    lastPlateStreak = view.plate.streak

    -- The label shows the DISPLAYED (animating) figures, not the model's — that is the entire
    -- point of `tickCounter`. The streak's own "×N" segment tracks the displayed count too, so a
    -- streak reset to 0 counts down in view rather than vanishing on the same tick it resets.
    local displayedPoints = tickCounter(pointsCounter, view.plate.points)
    local displayedStreak = tickCounter(streakCounter, view.plate.streak)
    plateLabel.Text = if displayedStreak > 0
        then `×{displayedStreak}  {displayedPoints}`
        else tostring(displayedPoints)

    -- The pot counts too, and the bank button's VISIBILITY follows the DISPLAYED figure, not
    -- `view.bankVisible`: the model's pot goes to zero the instant a bank or a loss lands, and a
    -- button that hid on THAT model transition would take the count-down off screen before
    -- anyone saw it — which is the whole transfer effect this task exists to deliver. `view.pot
    -- > 0` stays in the condition too, so the button appears on the very first tick a pot
    -- exists even though the display itself still reads 0 for that one frame
    -- (`RollingNumber.valueAt`'s exact-`from`-at-`t=0` guarantee).
    local displayedPot = tickCounter(potCounter, view.pot)
    setBank(view.pot > 0 or displayedPot > 0, displayedPot, view.potPulses)
    -- Armed follows the MODEL's pot, not the displayed one: the button stays VISIBLE through the
    -- drain (that's the animation), but a tap on it once the model has already emptied the pot
    -- must not send a live BankRequest for something that no longer exists.
    bankArmed = view.pot > 0

    -- The authoritative choice wins; until it has come back through main.client a press keeps
    -- its own tile lit (`pressedSym`), so a held finger does not flicker the light off on the
    -- next 10Hz repaint.
    if view.chosen then
        pressedSym = nil
    end
    local lit = view.chosen or pressedSym
    paintThrows(lit, view.throwsEnabled, view.switchPrompt)
    setChosenPulse(if view.throwsEnabled then lit else nil)
    setSwitchPrompt(view.switchPrompt)

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
    -- `plateRestTransparency`, not `plate.BackgroundTransparency`, is both the capture source and
    -- the write target here: the live property now spends most of its time either at 1 (hidden)
    -- or mid-fade, neither of which is the "authored" value this pass needs. `revealPlate` reads
    -- `plateRestTransparency` back when it shows the plate, so a reveal during full daylight uses
    -- the current day/night value rather than a stale one baked in at construction. The CAPTURE
    -- must stay unconditional and must keep reading `plateRestTransparency`, never the live
    -- property — a fade-driven `1` must never be captured as "authored".
    local plateAuthored = captureNumber(plate, AUTHORED_TRANSPARENCY, plateRestTransparency)
    plateRestTransparency = lerpNumber(PLATE_DAY_TRANSPARENCY, plateAuthored, nightFactor)
    -- The WRITE, unlike the capture, is guarded: `plateFadeTweens` is non-empty only between
    -- `startPlateFade` and the next `cancelPlateFade`, i.e. exactly while a fade owns this
    -- property. TweenService redrives `BackgroundTransparency` from ITS OWN stored start value
    -- every frame, so an unconditional write here would still let the fade finish — but it would
    -- also win for up to one frame, showing a flash of rest-transparency mid-fade while the text
    -- and stroke (which this pass never touches) kept fading smoothly. Skipping the write during
    -- a fade costs nothing: once the fade completes the plate is `Visible = false`, and the next
    -- `revealPlate` sets the property explicitly anyway.
    if #plateFadeTweens == 0 then
        plate.BackgroundTransparency = plateRestTransparency
    end

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
