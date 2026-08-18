--!strict
-- The result splash (spec: docs/superpowers/specs/2026-08-03-play-hud-round-two-design.md §2).
--
-- Today's toast said `🏆 WIN! World threw R — R 33% · P 33% · S 33%` — four facts in one breath,
-- celebrating none of them. This is the replacement: big, centred, and about the PLAYER. The
-- crowd split and player count it displaced stay elsewhere (main.client.luau still stashes them
-- for Task 9's ledger LAST ROUND band) — this file only ever names the player's own outcome.
--
-- ITS OWN ScreenGui, DisplayOrder 30 — above BOTH takeovers (the ledger/teahouse at 20) and the
-- minimal HUD (0), because a result that lands while the ledger is open must still be seen.
--
-- NOTHING HERE IS INTERACTIVE, deliberately. A large sinking element in the middle of the screen
-- is the failure this branch has already made twice — a card on the movement thumbstick, and a
-- panel leaking taps to live buttons beneath it. An accidental tap that dropped the player into
-- a movement-suspending takeover would be worse than the friction it saved. The round-timer ring
-- and the revealed plate are the doors.
--
-- GATED ON THE DRUM, entirely by the caller: main.client.luau fires EventBus.Splash from
-- `maybeShowReveal`, the SAME drum-rest gate (with the SAME REVEAL_SAFETY fallback) the tape tile
-- and the onboarding "win" beat already wait on. This file never reads RevealResult itself and
-- has no gate of its own for TIMING — firing early would spoil the wheel while it is still turning.
--
-- OPTIONAL (spec §2, "Optional"): a second HUD preference beside escalationPrompts, default ON.
-- Read from `EventBus.LedgerState`, the same channel LedgerController's footer switch reads —
-- main.client.luau fires it only on ProfileUpdate, so this is the authoritative, persisted value,
-- not a locally-invented default. When it is off, EventBus.Splash still fires (main.client.luau
-- does not know or care whether the splash is enabled) and this file simply does not show it.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local HudLayout =
    require(game:GetService("ReplicatedStorage"):WaitForChild("RoshamboShared"):WaitForChild("HudLayout"))

-- ⚠ OVER THE THROW CLUSTER, NOT MID-SCREEN (owner, 2026-08-18). This sat at 0.42 of screen height
-- and 0.8 of its width, directly over the avatar — and now directly over the FAMILIAR, whose whole
-- premise is that the space above a player's head is the one region never occluded. A win spiralled
-- up into the notice announcing it.
--
-- The throw cluster is the right home because that ground is dead in this exact moment: the round
-- has just resolved, nobody needs a throw button for several seconds, and the splash is gone well
-- before they do. Covering a live control would be unacceptable; covering a briefly inert one is
-- free. Registered off the same expressions the cluster itself uses, so it tracks it.
local BACKING_W = 320
local BACKING_MIN_W = 240

local TOUCH = game:GetService("UserInputService").TouchEnabled
local SPLASH_BTN_H = if TOUCH then HudLayout.BTN_H_TOUCH else HudLayout.BTN_H
local SPLASH_AREA_H = if TOUCH then HudLayout.AREA_H_TOUCH else HudLayout.AREA_H
local SPLASH_AREA_W = 3 * SPLASH_BTN_H + 2 * (if TOUCH then 8 else 10)
local SPLASH_EDGE_BOTTOM = 6

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The ZenDojo HUD palette, as in HudController/LedgerController/OnboardingController/
-- TeahouseController. Duplicated rather than shared: there is no palette module yet, and
-- inventing one for a fifth file is not worth a sixth require.
local WASHI = Color3.fromRGB(26, 24, 28)
local GOLD = Color3.fromRGB(212, 176, 102) -- WIN
local SAFE_BLUE = Color3.fromRGB(74, 150, 255) -- SAFE
local LOSS_RED = Color3.fromRGB(206, 86, 86) -- LOSS
local CARD_COPY = Color3.fromRGB(252, 249, 242) -- the consequence line's near-white

local HOLD_SECONDS = 2
local FADE_SECONDS = 0.4
local BACKING_TRANSPARENCY = 0 -- opaque: contrast comes from this, never a UIStroke on the text
local STROKE_TRANSPARENCY = 0.1

local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboSplash"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30 -- above both takeovers (20) and the minimal HUD (0)
gui.Parent = playerGui

-- One opaque backing, centred. Sized to its own content (AutomaticSize.Y) between a floor and a
-- ceiling so a long LOSS figure never runs edge to edge on a phone, and a short SAFE line never
-- looks like an empty box.
local backing = Instance.new("Frame")
backing.Name = "Backing"
backing.Active = false
backing.AnchorPoint = Vector2.new(1, 1)
backing.Position =
    UDim2.new(1 - HudLayout.JUMP_CLEARANCE, 0, 1, -(SPLASH_EDGE_BOTTOM + SPLASH_AREA_H - SPLASH_BTN_H)) -- the throw button row's own bottom edge; was fromScale(0.5, 0.42), which
-- stacked on the throw cluster below it
-- As wide as the throw cluster, but never narrower than the existing legibility floor: on touch
-- the cluster is only ~148px and a 36px headline in that is unreadable. Where the floor wins the
-- box simply overhangs the cluster to the LEFT, which is empty screen, not another control.
backing.Size = UDim2.fromOffset(math.max(SPLASH_AREA_W, BACKING_MIN_W), 0)
backing.AutomaticSize = Enum.AutomaticSize.Y
backing.BackgroundColor3 = WASHI
backing.BackgroundTransparency = 1 -- starts hidden; `showSplash` reveals it
backing.BorderSizePixel = 0
backing.Visible = false
backing.Parent = gui

do
    local sizeConstraint = Instance.new("UISizeConstraint")
    sizeConstraint.MinSize = Vector2.new(BACKING_MIN_W, 0)
    sizeConstraint.MaxSize = Vector2.new(BACKING_W, math.huge)
    sizeConstraint.Parent = backing

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = backing

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 24)
    pad.PaddingRight = UDim.new(0, 24)
    pad.PaddingTop = UDim.new(0, 20)
    pad.PaddingBottom = UDim.new(0, 20)
    pad.Parent = backing

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.Padding = UDim.new(0, 8)
    list.Parent = backing
end

-- The backing's own keyline. On the FRAME, never the labels — a UIStroke on a TextLabel outlines
-- every glyph, and that is the exact defect that made this HUD's messages unreadable earlier in
-- this branch (see OnboardingController's copyLabel comment).
local backingStroke = Instance.new("UIStroke")
backingStroke.Color = GOLD
backingStroke.Thickness = 2
backingStroke.Transparency = 1 -- starts hidden alongside the backing
backingStroke.Parent = backing

-- The headline: big, coloured per result. NO UIStroke — contrast comes from `backing` alone.
local headlineLabel = Instance.new("TextLabel")
headlineLabel.Name = "Headline"
headlineLabel.Active = false
headlineLabel.LayoutOrder = 1
headlineLabel.BackgroundTransparency = 1
headlineLabel.Size = UDim2.fromScale(1, 0)
headlineLabel.AutomaticSize = Enum.AutomaticSize.Y
headlineLabel.Font = Enum.Font.GothamBlack
headlineLabel.TextSize = 36
headlineLabel.TextTransparency = 1
headlineLabel.TextXAlignment = Enum.TextXAlignment.Center
headlineLabel.Text = ""
headlineLabel.Parent = backing

-- The consequence line: teaches the rule. Also no UIStroke, for the same reason.
local consequenceLabel = Instance.new("TextLabel")
consequenceLabel.Name = "Consequence"
consequenceLabel.Active = false
consequenceLabel.LayoutOrder = 2
consequenceLabel.BackgroundTransparency = 1
consequenceLabel.Size = UDim2.fromScale(1, 0)
consequenceLabel.AutomaticSize = Enum.AutomaticSize.Y
consequenceLabel.TextColor3 = CARD_COPY
consequenceLabel.Font = Enum.Font.GothamBold
consequenceLabel.TextSize = 18
consequenceLabel.TextTransparency = 1
consequenceLabel.TextWrapped = true
consequenceLabel.TextXAlignment = Enum.TextXAlignment.Center
consequenceLabel.Text = ""
consequenceLabel.Parent = backing

-- ===== Hold then fade, on HudController's plate-reveal pattern =====
-- A GENERATION counter, incremented BEFORE cancelling: a fade a newer splash superseded cannot
-- let its own stale `Completed` callback fire late and hide a splash the newer one just showed.
-- See HudController.client.luau's `plateGen`/`cancelPlateFade`/`startPlateFade` — mirrored here
-- rather than a second, slightly different mechanism.
local splashGen = 0
local splashFadeTweens: { Tween } = {}

local function cancelSplashFade()
    for _, t in splashFadeTweens do
        t:Cancel()
    end
    table.clear(splashFadeTweens)
end

local function startSplashFade(gen: number)
    if gen ~= splashGen then
        return -- superseded by a newer result; this fade no longer applies
    end
    local info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local bgTween = TweenService:Create(backing, info, { BackgroundTransparency = 1 })
    local strokeTween = TweenService:Create(backingStroke, info, { Transparency = 1 })
    local headlineTween = TweenService:Create(headlineLabel, info, { TextTransparency = 1 })
    local consequenceTween = TweenService:Create(consequenceLabel, info, { TextTransparency = 1 })
    splashFadeTweens = { bgTween, strokeTween, headlineTween, consequenceTween }
    bgTween.Completed:Connect(function()
        if gen == splashGen then
            backing.Visible = false
        end
    end)
    bgTween:Play()
    strokeTween:Play()
    headlineTween:Play()
    consequenceTween:Play()
end

local function showSplash(headline: string, consequence: string, color: Color3)
    splashGen += 1
    local gen = splashGen
    cancelSplashFade()
    backing.Visible = true
    backing.BackgroundTransparency = BACKING_TRANSPARENCY -- Cancel leaves properties mid-tween
    backingStroke.Color = color
    backingStroke.Transparency = STROKE_TRANSPARENCY
    headlineLabel.TextColor3 = color
    headlineLabel.Text = headline
    headlineLabel.TextTransparency = 0
    consequenceLabel.Text = consequence
    consequenceLabel.TextTransparency = 0
    task.delay(HOLD_SECONDS, function()
        startSplashFade(gen)
    end)
end

-- ===== Copy, driven by result (spec §2's table) =====
-- `forfeited` may be nil even for a LOSS — see main.client.luau's ProfileUpdate handler for how
-- it is captured, and the comment there on why it should always be present in practice. If it is
-- ever missing, this shows LOSS without a number rather than guessing one: a wrong figure is
-- worse than a missing one.
--
-- ZERO is its own case, kept distinct from "missing" on purpose: `forfeited == 0` is a KNOWN
-- fact (no pot was riding), whereas `forfeited == nil` is the degenerate drum-stall path saying
-- "unknown". `0 points forfeited` is the single most common loss (any loss immediately after a
-- bank, or a new player's very first loss) and is accurate but teaches nothing — there is no
-- rule in "0". `> 0` says the number; `== 0` says the fact it stands for instead.
local function copyFor(body: any): (string?, string?, Color3?)
    local result = body.result
    if result == "WIN" then
        return "YOU WIN!", `streak ×{body.streak} — pot is now {body.pot}`, GOLD
    elseif result == "SAFE" then
        return "SAFE", "your pot survives, streak resets", SAFE_BLUE
    elseif result == "LOSS" then
        local consequence
        if type(body.forfeited) == "number" and body.forfeited > 0 then
            consequence = `{body.forfeited} points forfeited`
        elseif body.forfeited == 0 then
            consequence = "nothing was riding on that one"
        else
            consequence = "your pot is forfeited"
        end
        return "YOU LOSE", consequence, LOSS_RED
    end
    return nil, nil, nil
end

-- ON until the first EventBus.LedgerState lands, mirroring every other HUD preference's default —
-- see main.client.luau's `resultSplash` and the profile route's `resultSplash ?? true`.
local resultSplash = true

EventBus.LedgerState.Event:Connect(function(state)
    if type(state.resultSplash) == "boolean" then
        resultSplash = state.resultSplash
    end
end)

EventBus.Splash.Event:Connect(function(body)
    if not resultSplash then
        return
    end
    local headline, consequence, color = copyFor(body)
    if headline and consequence and color then
        showSplash(headline, consequence, color)
    end
end)
