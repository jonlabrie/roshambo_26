--!strict
-- Per-player perch favoriting. Puts a ProximityPrompt on every materialized teahouse
-- (workspace.TeahouseSites.MaterializedSite_<siteId>), labeled from this player's
-- padPreferences (pushed via PreferenceState). Triggering toggles the favorite:
-- SetPadPreference -> server persists -> PreferenceState echo -> label flip + toast.
-- Favoriting affects the NEXT join's assignment, not the current session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent

local FAV_LABEL = "♥ Favorited ✓"
local UNFAV_LABEL = "♡ Favorite this perch"

local favored: { [string]: boolean } = {} -- siteId -> favorited
local prompts: { [string]: ProximityPrompt } = {} -- siteId -> its prompt

local function labelFor(siteId: string): string
    return if favored[siteId] then FAV_LABEL else UNFAV_LABEL
end

local function refreshPrompts()
    for siteId, prompt in prompts do
        prompt.ActionText = labelFor(siteId)
    end
end

-- Transient toast banner.
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "PerchToast"
toastGui.ResetOnSpawn = false
toastGui.IgnoreGuiInset = true
toastGui.Parent = player:WaitForChild("PlayerGui")

local function showToast(text: string)
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.fromScale(0.5, 0.08)
    label.Size = UDim2.fromOffset(520, 44)
    label.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
    label.BackgroundTransparency = 0.15
    label.TextColor3 = Color3.fromRGB(240, 228, 205)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Text = text
    label.Parent = toastGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label
    task.spawn(function()
        task.wait(2.5)
        local fade = TweenService:Create(
            label,
            TweenInfo.new(0.5),
            { BackgroundTransparency = 1, TextTransparency = 1 }
        )
        fade:Play()
        fade.Completed:Wait()
        label:Destroy()
    end)
end

local function anchorPart(structure: Instance): BasePart?
    if structure:IsA("Model") and structure.PrimaryPart then
        return structure.PrimaryPart
    end
    local deck = structure:FindFirstChild("Deck", true)
    if deck and deck:IsA("BasePart") then
        return deck
    end
    return structure:FindFirstChildWhichIsA("BasePart", true)
end

local function ensurePrompt(folder: Instance)
    local siteId = folder.Name:match("^MaterializedSite_(.+)$")
    if not siteId or prompts[siteId] then
        return
    end
    task.spawn(function()
        local structure = folder:WaitForChild("Structure", 15)
        if not structure then
            return
        end
        local anchor = anchorPart(structure)
        if not anchor then
            return
        end
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = labelFor(siteId)
        prompt.ObjectText = "Perch"
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.MaxActivationDistance = 16
        prompt.RequiresLineOfSight = false
        prompt.Parent = anchor
        prompt.Triggered:Connect(function()
            SetPadPreference:FireServer(siteId)
        end)
        prompts[siteId] = prompt
    end)
end

local sitesFolder = workspace:WaitForChild("TeahouseSites")
for _, f in sitesFolder:GetChildren() do
    ensurePrompt(f)
end
sitesFolder.ChildAdded:Connect(ensurePrompt)

PreferenceState.OnClientEvent:Connect(function(payload)
    favored = {}
    for _, id in payload.padPreferences do
        favored[id] = true
    end
    refreshPrompts()
    if payload.changed then
        local name = payload.name or payload.changed
        if payload.favorited then
            showToast(`★ {name} favorited — you'll spawn here next time it's free`)
        else
            showToast(`{name} removed from favorites`)
        end
    end
end)
