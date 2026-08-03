--!strict
-- Onboarding beats — bones, not a tutorial (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md
-- § Onboarding). The owner narrates in person when new players first join; these four cards exist
-- only for what a live narrator cannot always cover.
--
-- Each beat is fired by the EVENT IT EXPLAINS, never queued at join — main.client.luau fires
-- `EventBus.Onboard:Fire(event, seenBeats)` the first time join/throwsUnlocked/win/bank actually
-- happens, and `seenBeats` is the profile's current list (piggybacked on the same channel rather
-- than adding a second one just to seed this file). This module RENDERS `OnboardingBeats`; it
-- never decides which beat fires — `OnboardingBeats.next(seenLocal, event)` does.
--
-- ONE CARD AT A TIME. If a second event fires while a card is up, it is DROPPED, not queued —
-- `currentBeat ~= nil` is the only guard this needs, because a stack of cards is a tutorial.
--
-- Dismissal marks the beat seen LOCALLY first (`table.insert(seenLocal, beat.id)`), then fires
-- the write on `EventBus.HudPreference` → the same `SetHudPreference` remote Task 12's preference
-- switch uses — never a second remote. Marking locally before the round trip lands is what stops
-- a re-fire of the same beat if another qualifying event arrives in the same session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local OnboardingBeats = require(shared:WaitForChild("OnboardingBeats"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The ZenDojo HUD palette, as in HudController/LedgerController. Duplicated rather than shared:
-- there is no palette module yet, and inventing one for a third file is not worth a fourth require.
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local WASHI = Color3.fromRGB(26, 24, 28)
local GOLD = Color3.fromRGB(212, 176, 102)

-- Layout constants MIRROR HudController's own — not shared, because HudController's are file-local
-- too (see its "SCALE, not pixels" note). A card's whole job is to sit beside what HudController
-- placed, so it has to agree with those numbers exactly, not approximate them.
local EDGE = 12
local JUMP_CLEARANCE = 0.15
local PLATE_H = 46
local AREA_H = 120 -- TILE(34) + ROW_GAP(10) + BTN_H(76): the tape+buttons cluster's height
local ROW_GAP = 10
local SLOT_H = 40
local SLOT_GAP = 8

local CARD_W = 220
local PLATE_CARD_W = 260
local DRUM_CARD_W = 220

-- ===== Card: one TextButton (the dismiss target) + two non-Active labels =====
-- The ONLY interactive element in this file. Everything else inside it stays non-Active (labels
-- default to false; never set true) so the one button is the whole interactive budget this
-- surface spends — consistent with HudController's "every sinking pixel is a permanent hole in
-- the camera-drag surface" discipline.
local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboOnboarding"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10 -- above the minimal HUD (0), below the ledger takeover (20)
gui.Parent = playerGui

local card = Instance.new("TextButton")
card.Name = "Card"
card.BackgroundColor3 = WASHI
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.AutoButtonColor = false
card.Text = ""
card.Size = UDim2.fromOffset(CARD_W, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.Visible = false
card.ZIndex = 5
card.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = card
    local s = Instance.new("UIStroke")
    s.Color = GOLD
    s.Thickness = 1
    s.Transparency = 0.3
    s.Parent = card
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = card
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.Parent = card
end

local copyLabel = Instance.new("TextLabel")
copyLabel.Name = "Copy"
copyLabel.Active = false
copyLabel.LayoutOrder = 1
copyLabel.BackgroundTransparency = 1
copyLabel.Size = UDim2.fromScale(1, 0)
copyLabel.AutomaticSize = Enum.AutomaticSize.Y
copyLabel.TextWrapped = true
copyLabel.TextColor3 = INK_CREAM
copyLabel.TextSize = 16
copyLabel.Font = Enum.Font.GothamBold
copyLabel.TextXAlignment = Enum.TextXAlignment.Left
copyLabel.Text = ""
copyLabel.Parent = card

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Active = false
hintLabel.LayoutOrder = 2
hintLabel.BackgroundTransparency = 1
hintLabel.Size = UDim2.new(1, 0, 0, 14)
hintLabel.TextColor3 = GOLD
hintLabel.TextTransparency = 0.2
hintLabel.TextSize = 11
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = "TAP TO DISMISS"
hintLabel.Parent = card

-- ===== Anchors =====
-- `OnboardingBeats` names four anchors: `drum`, `throwArea`, `potIndicator`, `plate`. Three are
-- static offsets from a screen edge, matching where HudController actually put the thing they
-- point at. `drum` is the one exception — the drum is a real object in the world
-- (`Workspace.RoshamboStage.ThrowDrum.Drum`, see DrumController), so it is tracked live via
-- `WorldToViewportPoint` rather than guessed at a fixed screen fraction.
--
-- Nothing here ever covers the throw buttons: `throwArea` and `potIndicator` sit ABOVE the whole
-- tape+buttons+slot stack (offset clears the slot's full footprint even when the slot itself is
-- empty), and `plate` sits BELOW the plate, clear of both the plate button and the toast that
-- shares that same strip of screen.
local STATIC_ANCHORS: { [string]: { point: Vector2, offset: UDim2, width: number } } = {
    plate = {
        point = Vector2.new(0.5, 0),
        offset = UDim2.new(0.5, 0, 0, EDGE + PLATE_H + 60),
        width = PLATE_CARD_W,
    },
    -- Both sit above the WHOLE bottom-right cluster — tape+buttons AND the slot above them —
    -- not just above the tape. The slot's Frame occupies that space whether or not its pot/fate
    -- tenant is currently Visible (HudController never repositions it, only toggles children), so
    -- a card that only cleared the tape would sit inside the slot's footprint. That is harmless
    -- while the slot is empty, but `throwArea`'s card can outlive its dismiss window into a WIN
    -- (the slot can turn on WHILE this card is still up — beats do not queue, but a real, un-
    -- dismissed card does not disappear just because a later event was dropped) and BANK THESE is
    -- a live button underneath: an overlap there would both hide it and steal its taps, being
    -- ZIndex 5 above the slot's default. Same offset as `potIndicator` on purpose — they are never
    -- shown at once, so sharing the spot is a non-issue, and it is one fewer number to keep in step.
    throwArea = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + SLOT_H + SLOT_GAP)),
        width = CARD_W,
    },
    potIndicator = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + SLOT_H + SLOT_GAP)),
        width = CARD_W,
    },
}
local DRUM_FALLBACK = { point = Vector2.new(0.5, 0), offset = UDim2.new(0.5, 0, 0, 140) }

-- Resolved defensively (10s timeout, never yields the whole script) — the physical prop is
-- Rojo-managed map content and should already exist, but a card that cannot find it must fall
-- back rather than error the whole controller.
local drumPart: BasePart? = nil
task.spawn(function()
    local stage = workspace:WaitForChild("RoshamboStage", 10)
    if not stage then
        return
    end
    local rig = stage:WaitForChild("ThrowDrum", 10)
    if not rig then
        return
    end
    drumPart = rig:WaitForChild("Drum", 10) :: BasePart?
end)

local drumHeartbeat: RBXScriptConnection? = nil

local function stopTrackingDrum()
    if drumHeartbeat then
        drumHeartbeat:Disconnect()
        drumHeartbeat = nil
    end
end

-- Live-tracks the drum's screen position as a speech-bubble sitting just above it, clamped inside
-- the viewport so it can never drift off-screen. Falls back to a fixed top-centre position if the
-- drum has not resolved yet or is off-camera (behind the player, not yet loaded, etc).
local function trackDrum()
    local function place()
        local cam = workspace.CurrentCamera
        local at = drumPart
        if cam and at then
            local screen, onScreen = cam:WorldToViewportPoint(at.Position)
            if onScreen then
                local vp = cam.ViewportSize
                local half = DRUM_CARD_W * 0.5 + 8
                local x = math.clamp(screen.X, half, math.max(half, vp.X - half))
                local y = math.clamp(screen.Y - 36, 40, math.max(40, vp.Y - 40))
                card.AnchorPoint = Vector2.new(0.5, 1) -- bubble ABOVE the projected point
                card.Position = UDim2.fromOffset(x, y)
                return
            end
        end
        card.AnchorPoint = DRUM_FALLBACK.point
        card.Position = DRUM_FALLBACK.offset
    end
    place()
    drumHeartbeat = RunService.Heartbeat:Connect(place)
end

local function positionCard(beat: any)
    if beat.anchor == "drum" then
        card.Size = UDim2.fromOffset(DRUM_CARD_W, 0)
        trackDrum()
        return
    end
    -- An anchor OnboardingBeats names that this file does not recognise still deserves a visible,
    -- dismissable card rather than one silently mispositioned at (0, 0) — fall back to the plate
    -- slot, which is always a safe, on-screen, non-covering spot.
    local a = STATIC_ANCHORS[beat.anchor] or STATIC_ANCHORS.plate
    card.Size = UDim2.fromOffset(a.width, 0)
    card.AnchorPoint = a.point
    card.Position = a.offset
end

-- ===== Show / dismiss =====
local currentBeat: any = nil

-- Union of the profile's server-known seenBeats (refreshed with every Onboard fire — see below)
-- and this session's own optimistic dismissals. Never shrinks.
local seenLocal: { string } = {}

local function adoptServerSeen(list: { string }?)
    if type(list) ~= "table" then
        return
    end
    for _, id in list do
        table.insert(seenLocal, id)
    end
end

local function hideCard()
    stopTrackingDrum()
    card.Visible = false
    currentBeat = nil
end

local function showCard(beat: any)
    currentBeat = beat
    copyLabel.Text = beat.copy
    positionCard(beat)
    card.Visible = true
end

local function dismiss()
    local beat = currentBeat
    if not beat then
        return
    end
    -- Optimistic: stops a re-fire before the round trip lands. The write rides the SAME remote
    -- Task 12's preference switch uses — SetHudPreference — never a second one.
    table.insert(seenLocal, beat.id)
    EventBus.HudPreference:Fire({ seenBeat = beat.id })
    hideCard()
end

card.MouseButton1Click:Connect(dismiss)

EventBus.Onboard.Event:Connect(function(event: string, serverSeenBeats: { string }?)
    adoptServerSeen(serverSeenBeats)
    if currentBeat then
        -- NEVER STACK. A second event while a card is up is dropped, not queued — these are
        -- bones, and a stack of cards is a tutorial.
        return
    end
    local beat = OnboardingBeats.next(seenLocal, event)
    if beat then
        showCard(beat)
    end
end)
