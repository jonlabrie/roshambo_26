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
-- the whole right side of the screen on touch. Only the three throw buttons, the two choice
-- buttons and the plate may sink input.
--
-- This file RENDERS HudModel; it never re-derives it. main.client.luau owns the wiring and fires
-- EventBus.HudState(inputs, aux):
--   inputs : a HudModel.Inputs
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, pick = string? }
--            `tape` is already spoiler-gated by the wiring — paint it as given.
-- Picks travel back the other way on EventBus.HudPick.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HudModel = require(shared:WaitForChild("HudModel"))
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

local THROWS = { "R", "P", "S" }

-- SCALE, not pixels. The jump button occupies roughly the right 3-13% of the screen, and a pixel
-- offset guessed against a desktop viewport is wrong on every phone. Hold the throw area inboard
-- by a generous fraction of the width; the device-emulator pass settles the real number.
local JUMP_CLEARANCE = 0.15
local EDGE = 12

local PLATE_W, PLATE_H = 300, 46
local BTN_W, BTN_H, BTN_GAP = 76, 76, 10
local TAPE_N = 5
local TILE, TILE_GAP = 34, 6
local ROW_GAP = 10
local AREA_W = 3 * BTN_W + 2 * BTN_GAP
local AREA_H = TILE + ROW_GAP + BTN_H
local TIMER_H = 3
local TOAST_SECONDS = 4
local TOAST_MAX = 6

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

type TapeTile = { frame: Frame, glyphs: { [string]: Frame }, badge: Frame }
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
    stroke(tile, TAN_RIM, 1, 0.3)

    local badge = Instance.new("Frame")
    badge.Name = "Badge"
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Position = UDim2.fromScale(0.88, 0.12)
    badge.Size = UDim2.fromOffset(9, 9)
    badge.BackgroundColor3 = WIN_GREEN
    badge.BorderSizePixel = 0
    badge.ZIndex = 3
    badge.Visible = false
    badge.Parent = tile
    corner(badge, 5)

    tapeTiles[i] = { frame = tile, glyphs = glyphSet(tile, 0.66), badge = badge }
end

-- Mirrors the last rendered `view.throwsEnabled` so a tap can be refused without re-deriving the
-- rule. Advisory only: the server is what actually refuses a pick.
local canThrow = false

type ThrowTile = { button: TextButton, glyph: Frame, rim: UIStroke }
local throwTiles: { [string]: ThrowTile } = {}
for i, sym in THROWS do
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

    b.MouseButton1Click:Connect(function()
        if canThrow then
            EventBus.HudPick:Fire(sym)
        end
    end)

    throwTiles[sym] = { button = b, glyph = Glyphs.render(glyphBox(b, 0.62), sym, INK), rim = rim }
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
local escalation = Instance.new("TextLabel")
escalation.Name = "Escalation"
escalation.Active = false
escalation.AnchorPoint = Vector2.new(0.5, 0.5)
escalation.Position = UDim2.fromScale(0.5, 0.42)
escalation.Size = UDim2.new(0.8, 0, 0, 108) -- scale width: a fixed 460px overflows a small phone
escalation.BackgroundTransparency = 1
escalation.TextColor3 = INK_CREAM
escalation.TextSize = 38
escalation.Font = Enum.Font.GothamBlack
escalation.Text = ""
escalation.Visible = false
escalation.Parent = gui
stroke(escalation, WASHI, 2, 0.2)

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

    for _, sym in THROWS do
        local t = throwTiles[sym]
        local selected = aux.pick == sym
        -- Picking disables the throws (HudModel: pickedThisRound), so the chosen tile staying lit
        -- while the other two dim IS the "this is your throw" illumination.
        if selected or view.throwsEnabled then
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            fadeGlyph(t.glyph, 0)
        else
            t.button.BackgroundColor3 = IVORY_DIM
            t.button.BackgroundTransparency = 0.25
            fadeGlyph(t.glyph, 0.45)
        end
        t.rim.Color = if selected then SEL_BLUE else TAN_RIM
        t.rim.Transparency = if selected then 0 else 0.1
    end

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

    if inputs.phase == "ACTIVE" then
        if lastPhase ~= "ACTIVE" then
            span = 0
        end
        span = math.max(span, view.secondsLeft)
        local frac = if span > 0 then math.clamp(view.secondsLeft / span, 0, 1) else 0
        timer.Size = UDim2.new(frac, 0, 0, TIMER_H)
    else
        timer.Size = UDim2.fromOffset(0, TIMER_H)
    end
    lastPhase = inputs.phase

    escalation.Visible = view.escalate
    if view.escalate then
        escalation.Text = `{math.ceil(view.secondsLeft)}\nCHOOSE A THROW`
    end
end

EventBus.HudState.Event:Connect(render)
