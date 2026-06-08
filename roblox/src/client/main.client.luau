--!strict
-- Playable-loop UI. ZenDojo HUD pass (4b, T24): the persistent status + wallet
-- live in a slim washi panel at the BOTTOM (above the R/P/S pick buttons), and
-- all streaming prose — round prompts, the TOO-LATE toast, announcements —
-- scrolls across a ticker strip on the very bottom edge (fed by
-- EventBus.TickerMessage). The top of the screen stays clear so the bonshō bell
-- and the World-Throw drum read unobstructed. The WIN/SAFE/LOSS headline lands in
-- the status bar — and only after the drum stops turning (drumRest cue), so the
-- text never spoils the throw before the wheel settles on it.
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

-- ZenDojo HUD palette: washi-dark panels, gold hairlines, ink-cream text.
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local GOLD = Color3.fromRGB(212, 176, 102)
local WASHI = Color3.fromRGB(26, 24, 28)

-- bottom-cluster vertical budget (px, stacked from the screen's bottom edge up):
-- ticker → pick/bank/accept row → status bar.
local TICKER_H = 26
local GAP = 8
local BTN_H = 56
local STATUS_H = 30
local BTN_Y = TICKER_H + GAP -- pick/bank/accept baseline sits above the ticker
local STATUS_Y = BTN_Y + BTN_H + GAP -- status bar sits above the buttons

local THROWS = { "R", "P", "S" }
-- The approved ZenDojo R/P/S glyphs (gold), matching the drum faces and boards.
local GLYPH = { R = "○", P = "─", S = "∧" }
local NAMES = { R = "Rock", P = "Paper", S = "Scissors" }
-- The WIN/SAFE/LOSS reveal is no longer a center toast — it lands in the status
-- bar (see RevealResult / showReveal), and only after the drum stops turning.

-- ===== slim bottom status bar: phase + countdown (left), PTS/POT/STREAK (right) =====
local statusBar = Instance.new("Frame")
statusBar.Name = "StatusBar"
statusBar.AnchorPoint = Vector2.new(0.5, 1)
statusBar.Position = UDim2.new(0.5, 0, 1, -STATUS_Y)
statusBar.Size = UDim2.fromOffset(540, STATUS_H)
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

-- ===== bottom-edge ticker strip: the streaming-prose home =====
local ticker = Instance.new("Frame")
ticker.Name = "Ticker"
ticker.AnchorPoint = Vector2.new(0.5, 1)
ticker.Position = UDim2.fromScale(0.5, 1)
ticker.Size = UDim2.new(1, 0, 0, TICKER_H)
ticker.BackgroundColor3 = WASHI
ticker.BackgroundTransparency = 0.25
ticker.BorderSizePixel = 0
ticker.ClipsDescendants = true
ticker.Parent = gui

local tickerLine = Instance.new("Frame") -- gold hairline along the strip's top edge
tickerLine.Name = "Hairline"
tickerLine.AnchorPoint = Vector2.new(0, 0)
tickerLine.Position = UDim2.fromScale(0, 0)
tickerLine.Size = UDim2.new(1, 0, 0, 1)
tickerLine.BackgroundColor3 = GOLD
tickerLine.BackgroundTransparency = 0.2
tickerLine.BorderSizePixel = 0
tickerLine.Parent = ticker

local tickerText = Instance.new("TextLabel")
tickerText.Name = "Scroll"
tickerText.AutomaticSize = Enum.AutomaticSize.X -- width tracks the message length
tickerText.AnchorPoint = Vector2.new(0, 0.5)
tickerText.Position = UDim2.fromScale(1, 0.5)
tickerText.Size = UDim2.fromScale(0, 1)
tickerText.BackgroundTransparency = 1
tickerText.TextColor3 = INK_CREAM
tickerText.TextSize = 16
tickerText.Font = Enum.Font.Gotham
tickerText.TextXAlignment = Enum.TextXAlignment.Left
tickerText.Text = ""
tickerText.Parent = ticker

local IDLE_LINE = "世界 · BEAT THE WORLD THROW — bank your pot or stake it and ride the streak ×3"
local TICKER_SPEED = 120 -- px/sec marquee scroll
local tickerQueue: { string } = {}
local tickerX = 0 -- live left-edge x of the scrolling label, in px

local function tickerNext(): string
    if #tickerQueue > 0 then
        return table.remove(tickerQueue, 1)
    end
    return IDLE_LINE -- nothing queued: keep the house line crawling
end

local function tickerLoad(line: string)
    tickerText.Text = line
    tickerX = ticker.AbsoluteSize.X -- (re)enter from the right edge
    tickerText.Position = UDim2.new(0, tickerX, 0.5, 0)
end

RunService.RenderStepped:Connect(function(dt)
    tickerX -= TICKER_SPEED * dt
    tickerText.Position = UDim2.new(0, tickerX, 0.5, 0)
    if tickerX + tickerText.AbsoluteSize.X < 0 then
        tickerLoad(tickerNext()) -- fully off the left: pull the next line
    end
end)
tickerLoad(IDLE_LINE)

local function tickerSay(line: string)
    EventBus.TickerMessage:Fire(line) -- shared contract (BoardController also listens)
end

EventBus.TickerMessage.Event:Connect(function(line: string)
    table.insert(tickerQueue, line)
end)

-- ===== pick buttons (R/P/S), bank, accept-fate =====
local buttons: { [string]: TextButton } = {}
local myPick: string? = nil
local canPick = false
local lockoutAt: number? = nil -- os.clock() deadline

local function refreshButtons()
    for value, b in buttons do
        if value == myPick then
            b.BackgroundColor3 = Color3.fromRGB(40, 110, 255)
        elseif canPick then
            b.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        else
            b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        end
        b.AutoButtonColor = canPick
    end
end

for i, value in THROWS do
    local b = Instance.new("TextButton")
    b.Name = value
    b.Size = UDim2.fromOffset(130, BTN_H)
    b.AnchorPoint = Vector2.new(0.5, 1)
    b.Position = UDim2.new(0.5, (i - 2) * 145, 1, -BTN_Y)
    b.RichText = true
    b.Text = `<font color="#D4B066">{GLYPH[value]}</font>  {NAMES[value]}`
    b.TextSize = 20
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Parent = gui
    b.MouseButton1Click:Connect(function()
        if canPick then
            myPick = value
            refreshButtons()
            SubmitPick:FireServer(value)
        end
    end)
    buttons[value] = b
end

local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.Size = UDim2.fromOffset(160, 44)
bankButton.AnchorPoint = Vector2.new(1, 1)
bankButton.Position = UDim2.new(1, -16, 1, -BTN_Y)
bankButton.Text = "BANK"
bankButton.TextSize = 18
bankButton.Font = Enum.Font.GothamBold
bankButton.TextColor3 = Color3.fromRGB(20, 20, 20)
bankButton.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
bankButton.Visible = false
bankButton.Parent = gui
bankButton.MouseButton1Click:Connect(function()
    BankRequest:FireServer()
end)

local acceptButton = Instance.new("TextButton")
acceptButton.Name = "AcceptFate"
acceptButton.Size = UDim2.fromOffset(180, 44)
acceptButton.AnchorPoint = Vector2.new(0, 1)
acceptButton.Position = UDim2.new(0, 16, 1, -BTN_Y)
acceptButton.Text = "ACCEPT YOUR FATE"
acceptButton.TextSize = 16
acceptButton.Font = Enum.Font.GothamBold
acceptButton.TextColor3 = Color3.fromRGB(240, 234, 216)
acceptButton.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
acceptButton.Visible = false
acceptButton.Parent = gui

local fateBound = false

-- The World-Throw reveal headline waits in the status bar until the drum has
-- stopped turning. RevealResult arrives independently of the drum's glide-to-
-- rest, so we stash the headline and only paint it once BOTH have happened.
local pendingHeadline: string? = nil
local drumAtRest = false

local function maybeShowReveal()
    if pendingHeadline and drumAtRest then
        statusLabel.Text = pendingHeadline
        pendingHeadline = nil
    end
end

acceptButton.MouseButton1Click:Connect(function()
    EventBus.Cue:Fire({ kind = "acceptFate" })
end)

-- DrumController fires this once its landing decel reaches rest on the throw.
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
        pendingHeadline = nil -- clear last round's reveal; the drum will respin
        drumAtRest = false
        if not fateBound then
            tickerSay("New round — pick now and beat the World Throw!")
        end
    else
        canPick = false
        lockoutAt = nil
        statusLabel.Text = `Round {info.roundCount} — {info.phase}…`
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
    pendingHeadline = headline
    maybeShowReveal() -- shows now only if the drum already came to rest
    -- Safety: if the drum never reports rest (e.g. a dropped strike cue), don't
    -- strand the result — force it out shortly after.
    task.delay(3, function()
        if pendingHeadline == headline then
            drumAtRest = true
            maybeShowReveal()
        end
    end)
    -- the throw distribution is prose — it rides the ticker, not the status bar.
    tickerSay(
        `World threw {r.worldThrow} — R {r.distribution.R}% · P {r.distribution.P}% · S {r.distribution.S}%`
    )
end)

ProfileUpdate.OnClientEvent:Connect(function(p)
    walletLabel.Text = `PTS {p.totalPoints} · POT {p.pointsAtStake} · STREAK {p.currentStreak}`
    bankButton.Visible = p.pointsAtStake > 0
    bankButton.Text = `BANK {p.pointsAtStake}`
end)

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
            else
                statusLabel.Text = `Pick now! Locks in {math.ceil(left)}s`
            end
        end
        task.wait(0.25)
    end
end)
