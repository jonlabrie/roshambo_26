--!strict
-- Playable-loop UI (ZenDojo HUD). Layout:
--   • top-center  : persistent World-Throw HISTORY strip (last 10, newest left;
--                   gold glyph + personal WIN/LOSS/SAFE badge). Mirrors the PWA
--                   tape. Updated only once the drum settles (no spoiler).
--   • bottom-left : round R/P/S pick buttons in the LOGO triangle (○ rock top-
--                   left, ─ paper top-right, ∨ scissors bottom-center). Glyph
--                   only; the current pick is illuminated (gold ring).
--   • bottom-right: a slim status line (phase/countdown + PTS/POT/STREAK) over a
--                   scrolling prose ticker (~2/3 width). The status line HOLDS
--                   the prior round's throw and only switches to "Choose a
--                   throw!" under 10s left, so last round's result lingers.
-- The WIN/SAFE/LOSS headline lands in the status line after the drum stops
-- (drumRest cue), never before — the throw isn't spoiled while the wheel turns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent
local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent

local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- ZenDojo HUD palette
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local GOLD = Color3.fromRGB(212, 176, 102)
local WASHI = Color3.fromRGB(26, 24, 28)
local WIN_GREEN = Color3.fromRGB(86, 196, 120)
local LOSS_RED = Color3.fromRGB(206, 86, 86)
-- Ivory display-tile palette (pick buttons + history tiles)
local IVORY = Color3.fromRGB(244, 238, 222)
local IVORY_DIM = Color3.fromRGB(214, 208, 192)
local TAN_RIM = Color3.fromRGB(176, 164, 138)
local INK = Color3.fromRGB(60, 45, 28)
local HILITE = Color3.fromRGB(255, 252, 244)
local SEL_BLUE = Color3.fromRGB(74, 150, 255)

local THROWS = { "R", "P", "S" }
-- World-facing glyphs (history) match the drum/boards: scissors = caret ∧.
local GLYPH = { R = "○", P = "─", S = "∧" }
-- The player's own buttons use the LOGO arrangement + the caron ∨ (the mascot
-- smile) for scissors — the brand-facing variant of the happy/sad asymmetry.
local BTN_GLYPH = { R = "○", P = "─", S = "∨" }

-- ===== bottom-left: persistent World-Throw history strip (below the buttons) =====
local HIST_N = 10
local HIST_TILE = 34
local HIST_GAP = 4
local histStrip = Instance.new("Frame")
histStrip.Name = "History"
histStrip.AnchorPoint = Vector2.new(0, 1)
histStrip.Position = UDim2.new(0, 12, 1, -6)
histStrip.Size = UDim2.fromOffset(HIST_N * (HIST_TILE + HIST_GAP) - HIST_GAP, HIST_TILE + 14)
histStrip.BackgroundTransparency = 1
histStrip.Parent = gui

local histLabel = Instance.new("TextLabel")
histLabel.Name = "Caption"
histLabel.AnchorPoint = Vector2.new(0, 0)
histLabel.Position = UDim2.fromOffset(2, 0)
histLabel.Size = UDim2.new(1, 0, 0, 12)
histLabel.BackgroundTransparency = 1
histLabel.TextColor3 = GOLD
histLabel.TextTransparency = 0.25
histLabel.TextSize = 10
histLabel.Font = Enum.Font.GothamBold
histLabel.TextXAlignment = Enum.TextXAlignment.Left
histLabel.Text = "WORLD THROW HISTORY" -- (no CJK: Gotham renders 世界 as tofu)
histLabel.Parent = histStrip

local histTiles: { { frame: Frame, glyph: TextLabel, badge: Frame } } = {}
for i = 1, HIST_N do
    local tile = Instance.new("Frame")
    tile.Name = `H{i}`
    tile.AnchorPoint = Vector2.new(0, 1)
    tile.Position = UDim2.new(0, (i - 1) * (HIST_TILE + HIST_GAP), 1, 0)
    tile.Size = UDim2.fromOffset(HIST_TILE, HIST_TILE)
    tile.BackgroundColor3 = IVORY
    tile.BackgroundTransparency = 0.1
    tile.BorderSizePixel = 0
    tile.Visible = false
    tile.Parent = histStrip
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = tile
    local stroke = Instance.new("UIStroke")
    stroke.Color = TAN_RIM
    stroke.Thickness = 1
    stroke.Transparency = 0.3
    stroke.Parent = tile

    local glyph = Instance.new("TextLabel")
    glyph.Size = UDim2.fromScale(1, 1)
    glyph.BackgroundTransparency = 1
    glyph.TextColor3 = INK
    glyph.TextSize = 22
    glyph.Font = Enum.Font.GothamBlack
    glyph.Text = ""
    glyph.Parent = tile

    local badge = Instance.new("Frame")
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, 2, 0, -2)
    badge.Size = UDim2.fromOffset(9, 9)
    badge.BackgroundColor3 = WIN_GREEN
    badge.BorderSizePixel = 0
    badge.Visible = false
    badge.Parent = tile
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = badge

    histTiles[i] = { frame = tile, glyph = glyph, badge = badge }
end

local history: { { worldThrow: string, result: string? } } = {} -- newest first

local function renderHistory()
    for i = 1, HIST_N do
        local slot = histTiles[i]
        local entry = history[i]
        if entry then
            slot.frame.Visible = true
            slot.glyph.Text = GLYPH[entry.worldThrow] or "?"
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
        else
            slot.frame.Visible = false
        end
    end
end

-- Seed the strip from the authoritative World-Throw tape on join. The server
-- caches the tape (polled ~once/round, shared by everyone on the instance) and
-- pushes it via BoardData on PlayerAdded — so this costs the external server
-- nothing per player. Seed once: the tape only holds SETTLED rounds, so it can't
-- spoil the live round, and the gated reveal flow owns updates afterward. Any
-- entries already accumulated (badged) are kept; older throws backfill behind.
local BoardData = remotes:WaitForChild("BoardData") :: RemoteEvent
local seeded = false
BoardData.OnClientEvent:Connect(function(d)
    if seeded then
        return
    end
    local tape = d and d.tape
    if not tape or #tape == 0 then
        return -- fresh instance with no tape yet; wait for the next push
    end
    seeded = true
    for i = #history + 1, math.min(#tape, HIST_N) do
        table.insert(history, { worldThrow = tape[i].worldThrow, result = nil })
    end
    renderHistory()
end)

-- ===== bottom-center: status line (phase/countdown + wallet) =====
-- The status line and the ticker are the two stacked feedback lines below the
-- player: identical width (½ screen), centered.
local FEED_W = 0.5 -- scale
local TICKER_H = 30
local GAP = 6
local statusBar = Instance.new("Frame")
statusBar.Name = "StatusBar"
statusBar.AnchorPoint = Vector2.new(0.5, 1)
statusBar.Position = UDim2.new(0.5, 0, 1, -(8 + TICKER_H + GAP))
statusBar.Size = UDim2.new(FEED_W, 0, 0, 30)
statusBar.BackgroundColor3 = WASHI
statusBar.BackgroundTransparency = 0.35
statusBar.BorderSizePixel = 0
statusBar.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = statusBar
    local s = Instance.new("UIStroke")
    s.Color = GOLD
    s.Thickness = 1
    s.Transparency = 0.3
    s.Parent = statusBar
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 12)
    p.PaddingRight = UDim.new(0, 12)
    p.Parent = statusBar
end

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.AnchorPoint = Vector2.new(0, 0.5)
statusLabel.Position = UDim2.fromScale(0, 0.5)
statusLabel.Size = UDim2.fromScale(0.6, 1)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = INK_CREAM
statusLabel.TextSize = 16
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "…"
statusLabel.Parent = statusBar

local walletLabel = Instance.new("TextLabel")
walletLabel.Name = "Wallet"
walletLabel.AnchorPoint = Vector2.new(1, 0.5)
walletLabel.Position = UDim2.fromScale(1, 0.5)
walletLabel.Size = UDim2.fromScale(0.4, 1)
walletLabel.BackgroundTransparency = 1
walletLabel.TextColor3 = GOLD
walletLabel.TextSize = 16
walletLabel.Font = Enum.Font.GothamBold
walletLabel.TextXAlignment = Enum.TextXAlignment.Right
walletLabel.Text = "PTS 0 · POT 0 · STREAK 0"
walletLabel.Parent = statusBar

-- ===== bottom-center: scrolling prose ticker (½ width, matches the status line) =====
local ticker = Instance.new("Frame")
ticker.Name = "Ticker"
ticker.AnchorPoint = Vector2.new(0.5, 1)
ticker.Position = UDim2.new(0.5, 0, 1, -8)
ticker.Size = UDim2.new(FEED_W, 0, 0, TICKER_H)
ticker.BackgroundColor3 = WASHI
ticker.BackgroundTransparency = 0.25
ticker.BorderSizePixel = 0
ticker.ClipsDescendants = true
ticker.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = ticker
end

local tickerLine = Instance.new("Frame") -- gold hairline along the strip's top edge
tickerLine.Name = "Hairline"
tickerLine.Position = UDim2.fromScale(0, 0)
tickerLine.Size = UDim2.new(1, 0, 0, 1)
tickerLine.BackgroundColor3 = GOLD
tickerLine.BackgroundTransparency = 0.2
tickerLine.BorderSizePixel = 0
tickerLine.Parent = ticker

local tickerText = Instance.new("TextLabel")
tickerText.Name = "Scroll"
tickerText.AutomaticSize = Enum.AutomaticSize.X
tickerText.AnchorPoint = Vector2.new(0, 0.5)
tickerText.Position = UDim2.fromScale(1, 0.5)
tickerText.Size = UDim2.fromScale(0, 1)
tickerText.BackgroundTransparency = 1
tickerText.TextColor3 = INK_CREAM
tickerText.TextSize = 19 -- bigger than the old 16
tickerText.Font = Enum.Font.Gotham
tickerText.TextXAlignment = Enum.TextXAlignment.Left
tickerText.Text = ""
tickerText.Parent = ticker

local IDLE_LINE = "BEAT THE WORLD THROW — bank your pot or stake it and ride the streak ×3"
local TICKER_SPEED = 120
local tickerQueue: { string } = {}
local tickerX = 0

local function tickerNext(): string
    if #tickerQueue > 0 then
        return table.remove(tickerQueue, 1)
    end
    return IDLE_LINE
end

local function tickerLoad(line: string)
    tickerText.Text = line
    tickerX = ticker.AbsoluteSize.X
    tickerText.Position = UDim2.new(0, tickerX, 0.5, 0)
end

RunService.RenderStepped:Connect(function(dt)
    tickerX -= TICKER_SPEED * dt
    tickerText.Position = UDim2.new(0, tickerX, 0.5, 0)
    if tickerX + tickerText.AbsoluteSize.X < 0 then
        tickerLoad(tickerNext())
    end
end)
tickerLoad(IDLE_LINE)

local function tickerSay(line: string)
    EventBus.TickerMessage:Fire(line)
end

EventBus.TickerMessage.Event:Connect(function(line: string)
    table.insert(tickerQueue, line)
end)

-- ===== bottom-left: round pick buttons in the logo triangle =====
-- Centers in px from the bottom-left corner: rock top-left, paper top-right,
-- scissors bottom-center (an inverted triangle, matching the brand logo).
local BTN_D = 62
-- Raised to leave room for the history strip beneath the triangle.
local BTN_SPOT = {
    R = { x = 58, y = 168 },
    P = { x = 132, y = 168 },
    S = { x = 95, y = 104 },
}
-- The ○ ring reads small at a shared size; give rock a bigger glyph.
local BTN_TEXT = { R = 58, P = 32, S = 34 }
local buttons: { [string]: TextButton } = {}
local glyphMain: { [string]: TextLabel } = {}
local glyphHi: { [string]: TextLabel } = {}
local glyphGlow: { [string]: UIStroke } = {}
local myPick: string? = nil
local canPick = false
local lockoutAt: number? = nil

-- Ivory pressed-tile buttons. The glyph is embossed (a light highlight peeking
-- down-right behind an ink glyph); the current pick glows blue.
local function refreshButtons()
    for value, b in buttons do
        local main, hi, glow = glyphMain[value], glyphHi[value], glyphGlow[value]
        if value == myPick then
            b.BackgroundColor3 = IVORY
            main.TextColor3 = SEL_BLUE
            glow.Transparency = 0.1
            hi.TextTransparency = 1
        elseif canPick then
            b.BackgroundColor3 = IVORY
            main.TextColor3 = INK
            glow.Transparency = 1
            hi.TextTransparency = 0
        else
            b.BackgroundColor3 = IVORY_DIM
            main.TextColor3 = INK
            glow.Transparency = 1
            hi.TextTransparency = 0.3
        end
        b.AutoButtonColor = canPick
    end
end

for _, value in THROWS do
    local spot = BTN_SPOT[value]
    local b = Instance.new("TextButton")
    b.Name = value
    b.AnchorPoint = Vector2.new(0.5, 0.5)
    b.Position = UDim2.new(0, spot.x, 1, -spot.y)
    b.Size = UDim2.fromOffset(BTN_D, BTN_D)
    b.BackgroundColor3 = IVORY
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0) -- circle
    corner.Parent = b
    local rim = Instance.new("UIStroke") -- tan edge so it reads as a raised tile
    rim.Color = TAN_RIM
    rim.Thickness = 2
    rim.Transparency = 0.1
    rim.Parent = b
    local sheen = Instance.new("UIGradient") -- subtle top-lit 3D button feel
    sheen.Color = ColorSequence.new(Color3.fromRGB(255, 253, 247), Color3.fromRGB(226, 219, 201))
    sheen.Rotation = 90
    sheen.Parent = b

    -- emboss: a light highlight offset down-right, behind the ink glyph
    local hi = Instance.new("TextLabel")
    hi.Name = "Hi"
    hi.Size = UDim2.fromScale(1, 1)
    hi.Position = UDim2.fromOffset(1, 2)
    hi.BackgroundTransparency = 1
    hi.Text = BTN_GLYPH[value]
    hi.TextColor3 = HILITE
    hi.TextSize = BTN_TEXT[value]
    hi.Font = Enum.Font.GothamBlack
    hi.ZIndex = 2
    hi.Parent = b

    local main = Instance.new("TextLabel")
    main.Name = "Glyph"
    main.Size = UDim2.fromScale(1, 1)
    main.BackgroundTransparency = 1
    main.Text = BTN_GLYPH[value]
    main.TextColor3 = INK
    main.TextSize = BTN_TEXT[value]
    main.Font = Enum.Font.GothamBlack
    main.ZIndex = 3
    main.Parent = b
    local glow = Instance.new("UIStroke") -- blue halo around the glyph when picked
    glow.Color = SEL_BLUE
    glow.Thickness = 2.5
    glow.Transparency = 1
    glow.Parent = main

    b.MouseButton1Click:Connect(function()
        if canPick then
            myPick = value
            refreshButtons()
            SubmitPick:FireServer(value)
        end
    end)
    buttons[value] = b
    glyphMain[value] = main
    glyphHi[value] = hi
    glyphGlow[value] = glow
end

-- ===== bank sits right beside the wallet (same row + height as the status line) =====
local STATUS_Y = 8 + TICKER_H + GAP -- bottom offset shared with the status bar
local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.Size = UDim2.fromOffset(98, 30)
bankButton.AnchorPoint = Vector2.new(0, 1)
bankButton.Position = UDim2.new(0.75, 8, 1, -STATUS_Y) -- just right of the ½-width status bar
bankButton.Text = "BANK"
bankButton.TextSize = 16
bankButton.Font = Enum.Font.GothamBold
bankButton.TextColor3 = Color3.fromRGB(20, 20, 20)
bankButton.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
bankButton.Visible = false
bankButton.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = bankButton
end
bankButton.MouseButton1Click:Connect(function()
    BankRequest:FireServer()
end)

local acceptButton = Instance.new("TextButton")
acceptButton.Name = "AcceptFate"
acceptButton.Size = UDim2.fromOffset(176, 30)
acceptButton.AnchorPoint = Vector2.new(1, 1)
acceptButton.Position = UDim2.new(0.25, -8, 1, -STATUS_Y) -- left of the status bar, same row
acceptButton.Text = "ACCEPT YOUR FATE"
acceptButton.TextSize = 14
acceptButton.Font = Enum.Font.GothamBold
acceptButton.TextColor3 = Color3.fromRGB(240, 234, 216)
acceptButton.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
acceptButton.Visible = false
acceptButton.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = acceptButton
end

local fateBound = false

-- The reveal headline AND the new history tile wait for the drum to stop turning
-- (drumRest), so the throw isn't spoiled mid-spin. `lastReveal` persists in the
-- status line across the next round until <10s forces the pick prompt.
local pendingReveal: { headline: string, worldThrow: string, result: string? }? = nil
local drumAtRest = false
local lastReveal: string? = nil

local function maybeShowReveal()
    if pendingReveal and drumAtRest then
        local p = pendingReveal
        pendingReveal = nil
        lastReveal = p.headline
        statusLabel.Text = p.headline
        table.insert(history, 1, { worldThrow = p.worldThrow, result = p.result })
        while #history > HIST_N do
            table.remove(history)
        end
        renderHistory()
    end
end

acceptButton.MouseButton1Click:Connect(function()
    EventBus.Cue:Fire({ kind = "acceptFate" })
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        drumAtRest = true
        maybeShowReveal()
    end
end)

RevealTheater.OnClientEvent:Connect(function(r)
    local myId = tostring(player.UserId)
    local mine = r.results and r.results[myId]
    if mine and mine.result == "LOSS" then
        fateBound = true
        acceptButton.Visible = true
    end
    if r.whiffed and r.whiffed[myId] then
        tickerSay("⏳ TOO LATE — your throw didn't count this round")
    end
end)

FateResolvedEvt.OnClientEvent:Connect(function(userId)
    if userId == tostring(player.UserId) then
        fateBound = false
        acceptButton.Visible = false
    end
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        canPick = not fateBound
        myPick = nil
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        pendingReveal = nil -- the drum respins; last round's headline stays in view
        drumAtRest = false
    else
        canPick = false
        lockoutAt = nil
    end
    refreshButtons()
end)

RevealResult.OnClientEvent:Connect(function(r)
    canPick = false
    refreshButtons()
    local headline: string
    if r.result == "WIN" then
        headline = `🏆 WIN! World threw {r.worldThrow}`
    elseif r.result == "SAFE" then
        headline = `🛡 SAFE — world matched your {r.pick}`
    elseif r.result == "LOSS" then
        headline = `💥 LOSS — world threw {r.worldThrow}`
    else
        headline = `World threw {r.worldThrow}`
    end
    pendingReveal = { headline = headline, worldThrow = r.worldThrow, result = r.result }
    maybeShowReveal() -- only paints if the drum is already at rest
    task.delay(3, function()
        if pendingReveal and pendingReveal.headline == headline then
            drumAtRest = true -- safety: never strand a result if the cue dropped
            maybeShowReveal()
        end
    end)
    tickerSay(
        `World threw {r.worldThrow} — R {r.distribution.R}% · P {r.distribution.P}% · S {r.distribution.S}%`
    )
end)

ProfileUpdate.OnClientEvent:Connect(function(p)
    walletLabel.Text = `PTS {p.totalPoints} · POT {p.pointsAtStake} · STREAK {p.currentStreak}`
    bankButton.Visible = p.pointsAtStake > 0
    bankButton.Text = `BANK {p.pointsAtStake}`
end)

-- Status-line text each tick. The prior round's result LINGERS until under 10s
-- remain, when it yields to the pick prompt.
task.spawn(function()
    while true do
        if fateBound then
            statusLabel.Text = "FACE YOUR FATE — accept it or be caught"
        elseif canPick and lockoutAt then
            local left = lockoutAt - os.clock()
            if left <= 0 then
                canPick = false
                refreshButtons()
                statusLabel.Text = "Locked — waiting for the world…"
            elseif left < 10 then
                statusLabel.Text = `Choose a throw! Locks in {math.ceil(left)}s`
            else
                statusLabel.Text = lastReveal or "New round — beat the World Throw"
            end
        elseif lastReveal then
            statusLabel.Text = lastReveal -- TALLY/REVEAL: hold the prior throw
        end
        task.wait(0.25)
    end
end)
