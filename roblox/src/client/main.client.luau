--!strict
-- Playable-loop UI: phase/countdown, R/P/S pick buttons, reveal text, bank button.
-- Placeholder visuals; arena theater arrives in milestone 4.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SubmitPick = remotes:WaitForChild("SubmitPick") :: RemoteEvent
local BankRequest = remotes:WaitForChild("BankRequest") :: RemoteEvent
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealResult = remotes:WaitForChild("RevealResult") :: RemoteEvent
local ProfileUpdate = remotes:WaitForChild("ProfileUpdate") :: RemoteEvent

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local THROWS = { "R", "P", "S" }
local LABELS = { R = "🪨 Rock", P = "📄 Paper", S = "✂️ Scissors" }

local function makeLabel(name: string, pos: UDim2, size: UDim2, textSize: number): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.Position = pos
    l.Size = size
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.BackgroundTransparency = 0.4
    l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextSize = textSize
    l.Font = Enum.Font.GothamBold
    l.Parent = gui
    return l
end

local statusLabel = makeLabel("Status", UDim2.new(0.5, 0, 0, 8), UDim2.fromOffset(420, 36), 20)
local resultLabel = makeLabel("Result", UDim2.fromScale(0.5, 0.35), UDim2.fromOffset(520, 48), 28)
resultLabel.Visible = false
local walletLabel = makeLabel("Wallet", UDim2.new(0.5, 0, 0, 48), UDim2.fromOffset(420, 26), 16)
walletLabel.Text = "Points 0 | Pot 0 | Streak 0"

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
    b.Size = UDim2.fromOffset(130, 56)
    b.AnchorPoint = Vector2.new(0.5, 1)
    b.Position = UDim2.new(0.5, (i - 2) * 145, 1, -24)
    b.Text = LABELS[value]
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
bankButton.Position = UDim2.new(1, -16, 1, -24)
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

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        canPick = true
        myPick = nil
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
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
    resultLabel.Text = `{headline}  (R {r.distribution.R}% P {r.distribution.P}% S {r.distribution.S}%)`
    resultLabel.Visible = true
    task.delay(4, function()
        resultLabel.Visible = false
    end)
end)

ProfileUpdate.OnClientEvent:Connect(function(p)
    walletLabel.Text = `Points {p.totalPoints} | Pot {p.pointsAtStake} | Streak {p.currentStreak}`
    bankButton.Visible = p.pointsAtStake > 0
    bankButton.Text = `BANK {p.pointsAtStake}`
end)

task.spawn(function()
    while true do
        if canPick and lockoutAt then
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
