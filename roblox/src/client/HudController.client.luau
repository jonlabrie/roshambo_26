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
--   bottom-right, above the jump button : also claimed by Roblox for jump/camera drag, but a
--                  display with NO interactive elements can share it — see the PLATE below.
-- Hence: PLATE in the right margin, ABOVE the jump button (measured, not predicted — see
-- `placePlate`); THROW AREA bottom-right but INBOARD of the jump button, with the tape BELOW the
-- buttons (the buttons stay closest to where the thumb rests; the tape is read, never touched);
-- the round TIMER as a hairline along the bottom edge, competing with nothing.
--
-- Every information element MUST stay Active = false. Frames and labels default to false, but
-- setting it true anywhere here punches a permanent hole in the camera-drag surface, which is
-- the whole right side of the screen on touch. The whole interactive budget is: the three throw
-- buttons and the one bank button (see `setBank`) — the plate is a pure display now, not a door.
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

local PLATE_W = HudLayout.PLATE_W
local PLATE_ROW_H = HudLayout.PLATE_ROW_H
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

-- ===== Plate: the right margin, above the jump button =====
-- It left top-centre because that band is the middle of a phone's view. This is the strip
-- Roblox claims for jump and camera drag, and a display with NO interactive elements is the
-- one thing that can safely live in it: everything here is a Frame or a TextLabel at the
-- default Active = false, so every drag passes straight through to the camera.
--
-- The POT IS NOT HERE. It has its own button (see setBank). The streak is shown only when it
-- is non-zero — a "×0" is noise on a display whose whole job is to be ignorable.
local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(1, 1)
plate.Size = UDim2.fromOffset(PLATE_W, PLATE_ROW_H)
plate.BackgroundColor3 = WASHI
plate.BackgroundTransparency = 0.3
plate.BorderSizePixel = 0
plate.Parent = gui
corner(plate, 6)
stroke(plate, GOLD, 1, 0.35)

local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "Streak"
streakLabel.Size = UDim2.new(1, 0, 0, PLATE_ROW_H)
streakLabel.Position = UDim2.fromOffset(0, 0)
streakLabel.BackgroundTransparency = 1
streakLabel.TextColor3 = GOLD
streakLabel.TextSize = 14
streakLabel.Font = Enum.Font.GothamBold
streakLabel.Text = ""
streakLabel.Visible = false
streakLabel.Parent = plate

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.AnchorPoint = Vector2.new(0, 1)
pointsLabel.Position = UDim2.fromScale(0, 1)
pointsLabel.Size = UDim2.new(1, 0, 0, PLATE_ROW_H)
pointsLabel.BackgroundTransparency = 1
pointsLabel.TextColor3 = INK_CREAM
pointsLabel.TextSize = 15
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.Text = "0"
pointsLabel.Parent = plate

-- WHERE THE PLATE SITS IS MEASURED, NOT PREDICTED.
--
-- Roblox's default TouchJump sizes the jump button 70px on screens <=500px tall and 120px
-- above that, and positions it UDim2.new(1, -(size*1.5-10), 1, -size-20). Those are current
-- defaults, not a contract: they differ by screen size, they have changed before, and nothing
-- stops them changing again. So rather than encoding that arithmetic, the plate reads the real
-- button and sits PLATE_JUMP_GAP above its measured top edge.
--
-- The fallback is the bottom-right corner, which is where a desktop client — no TouchGui, no
-- jump button at all — should put it anyway.
local function jumpButton(): GuiObject?
    local touchGui = playerGui:FindFirstChild("TouchGui")
    local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
    return frame and frame:FindFirstChild("JumpButton") :: GuiObject?
end

-- This function MEASURES; HudLayout.plateBottomOffset decides. The arithmetic (the fallback,
-- and the clamp against a stale AbsolutePosition) lives there because it is pure and therefore
-- testable, and this file is not.
local function placePlate()
    local jump = jumpButton()
    local jumpTop: number? = if jump and jump.AbsoluteSize.Y > 0 then jump.AbsolutePosition.Y else nil
    local guiBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
    plate.Position = UDim2.new(1, -EDGE, 1, -HudLayout.plateBottomOffset(guiBottom, jumpTop))
end

-- The jump button is not there at require time on every client, it resizes when the viewport
-- crosses the small-screen threshold, and it disappears entirely if the player docks a
-- keyboard. Watch all three rather than measuring once.
local jumpWatch: { RBXScriptConnection } = {}
local function rewatchJump()
    for _, c in jumpWatch do
        c:Disconnect()
    end
    table.clear(jumpWatch)
    local jump = jumpButton()
    if jump then
        table.insert(jumpWatch, jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(placePlate))
        table.insert(jumpWatch, jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlate))
    end
    placePlate()
end

rewatchJump()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rewatchJump)
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "TouchGui" then
        -- TouchControlFrame is built a frame or two after TouchGui itself.
        task.defer(rewatchJump)
    end
end)
playerGui.ChildRemoved:Connect(function(child)
    if child.Name == "TouchGui" then
        task.defer(rewatchJump)
    end
end)

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
    -- the one bank button, and every sinking pixel is a permanent hole in the camera-drag surface.
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

bankButton.MouseButton1Click:Connect(function()
    EventBus.HudBank:Fire()
end)

-- The pulse says "this is unacknowledged", nothing more. `setBank` runs at 10Hz off `render`
-- (EventBus.HudState), so the tween is touched ONLY when the desired pulsing state actually
-- changes — cancelling and restarting a 0.9s tween every 100ms would give it 3% of its travel
-- and render as a static button with imperceptible jitter, not a pulse. This is why the code
-- this replaced (`setSlot`) guarded its tween the same way.
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
-- The plate has vacated top-centre for the right margin (Task 7), so there is no PLATE_H left
-- to offset against. Sits at EDGE for now; Task 9 owns making this opaque per the design's §3.
toast.Position = UDim2.new(0.5, 0, 0, EDGE)
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

    -- A "×0" is noise on a display whose whole job is to be ignorable, so the streak row only
    -- exists when there is a streak — and the plate shrinks to one row when it goes.
    local hasStreak = view.plate.streak > 0
    streakLabel.Visible = hasStreak
    streakLabel.Text = if hasStreak then `×{view.plate.streak}` else ""
    pointsLabel.Text = tostring(view.plate.points)
    plate.Size = UDim2.fromOffset(PLATE_W, if hasStreak then PLATE_ROW_H * 2 else PLATE_ROW_H)

    setBank(view.bankVisible, view.pot, view.potPulses)

    -- The authoritative pick wins the moment it lands; `view.selected` is next (stale field, kept
    -- readable pending Task 8's rewire onto `chosen`/`switchPrompt` — it degrades to nil, not an
    -- error); and until either has come back through main.client, a press keeps its own tile lit
    -- (`pressedSym`), so a held finger does not flicker the selection off on the next 10Hz repaint.
    if aux.pick or view.selected then
        pressedSym = nil
    end
    paintThrows(aux.pick or view.selected or pressedSym, view.throwsEnabled)

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
