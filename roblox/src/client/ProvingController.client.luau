--!strict
-- THE PROVING RANGE PANEL. An owner-facing dev tool at FiringPost (see
-- tools/builders/ProvingGround.luau): step up, open the panel, fire any draft or shipped shell
-- from any rack, alone or in a ladder/sequence. It evaluates NOTHING about a shell's look — that
-- is FireworkDrafts/FireworkCatalog's recipe and FireworkController's job to render. This file
-- only turns a button press into a `RequestProvingFire:FireServer(id, rack)` call.
--
-- STUDIO-ONLY BY ITS FIRST STATEMENT. A published place must hold no prompt, no panel, nothing —
-- the guard below is the whole security model on the client side (the server's own IsStudio
-- check in main.server.luau's RequestProvingFire handler is the one that actually matters, but a
-- published client should not even offer the button).
--
-- NOTHING HERE IS TESTED. No harness in this repo loads a `.client.luau`; every decision this
-- panel acts on (which shells exist, what a ladder/sequence plan looks like) already lives in
-- FireworkDrafts/ProvingPlan, both pure and both covered. This file owns instances and wiring.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

if not RunService:IsStudio() then
    return
end

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local FireworkDrafts = require(shared:WaitForChild("FireworkDrafts"))
local ProvingPlan = require(shared:WaitForChild("ProvingPlan"))
local FireworkCatalog = require(shared:WaitForChild("FireworkCatalog"))

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RequestProvingFire = remotes:WaitForChild("RequestProvingFire") :: RemoteEvent

-- FiringPost may not have replicated yet (StreamingEnabled can delay it) -- wait, generously,
-- rather than assuming it is already there.
local stage = workspace:WaitForChild("RoshamboStage", 60)
if not stage then
    return
end
local ground = stage:WaitForChild("ProvingGround", 60)
if not ground then
    return
end
local firingPost = ground:WaitForChild("FiringPost", 60)
if not firingPost or not firingPost:IsA("BasePart") then
    return
end

local INK_CREAM = Color3.fromRGB(240, 234, 216)
local WASHI = Color3.fromRGB(26, 24, 28)
local GOLD = Color3.fromRGB(212, 176, 102)

-- ===== the prompt: client-created only, so a published place holds no prompt at all =====
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Open Panel"
prompt.ObjectText = "Proving Range"
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 12
prompt.Parent = firingPost

-- ===== the panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "ProvingPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- ===== the cursor grip: copied verbatim (idiom, not just behavior) from ShopController.client.luau
-- (~lines 102-130). Bound one render step after the camera so the write survives; `holding` guards
-- Unbind, which THROWS on a name that was never bound. =====
local CURSOR_BIND = "ProvingPanelCursor"
local CURSOR_PRIORITY = Enum.RenderPriority.Camera.Value + 1
local holding = false

local function gripCursor()
    if holding then
        return
    end
    holding = true
    RunService:BindToRenderStep(CURSOR_BIND, CURSOR_PRIORITY, function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
end

local function releaseCursor()
    if not holding then
        return
    end
    holding = false
    RunService:UnbindFromRenderStep(CURSOR_BIND)
end

-- ===== night toggle: local-only Lighting.ClockTime override, never a server write, so it cannot
-- fight the shipped day-night cycle. The saved value is captured once, on first enable, and reused
-- for every restore after that (a second enable while already-off would otherwise "save" 22). =====
local nightOn = false
local hasSavedClockTime = false
local savedClockTime = 0

local nightButton: TextButton

local function paintNightButton()
    nightButton.Text = if nightOn then "Night: ON" else "Night: OFF"
end

local function enableNight()
    if nightOn then
        return
    end
    if not hasSavedClockTime then
        savedClockTime = Lighting.ClockTime
        hasSavedClockTime = true
    end
    Lighting.ClockTime = 22
    nightOn = true
    paintNightButton()
end

local function disableNight()
    if not nightOn then
        return
    end
    if hasSavedClockTime then
        Lighting.ClockTime = savedClockTime
    end
    nightOn = false
    paintNightButton()
end

-- THE ONLY PLACE gui.Enabled IS WRITTEN. Cursor grip and the night override both have to be paired
-- with it exactly: closing without releasing the cursor leaves the camera stuck for the rest of
-- the session, and closing without restoring the clock leaves the range dark forever.
local function setOpen(open: boolean)
    if open then
        gripCursor()
    else
        releaseCursor()
        disableNight()
    end
    gui.Enabled = open
end

prompt.Triggered:Connect(function()
    setOpen(not gui.Enabled)
end)

-- ===== panel chrome =====
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(480, 440)
panel.BackgroundColor3 = WASHI
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GOLD
panelStroke.Thickness = 1
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 30)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.TextColor3 = INK_CREAM
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Proving Range"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -8, 0, 8)
closeButton.Size = UDim2.fromOffset(30, 30)
closeButton.BackgroundColor3 = WASHI
closeButton.BackgroundTransparency = 0.35
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.Text = "\u{2715}"
closeButton.TextColor3 = INK_CREAM
closeButton.Font = Enum.Font.Code
closeButton.TextSize = 16
closeButton.Parent = panel
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = closeButton
end
closeButton.MouseButton1Click:Connect(function()
    setOpen(false)
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -110)
scroll.Position = UDim2.fromOffset(10, 44)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel
local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0, 4)
scrollLayout.Parent = scroll

-- ===== bottom bar: night toggle + close is already above, so this row is night only =====
local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(1, -20, 0, 30)
bottomBar.Position = UDim2.new(0, 10, 1, -40)
bottomBar.BackgroundTransparency = 1
bottomBar.Parent = panel

nightButton = Instance.new("TextButton")
nightButton.Size = UDim2.fromOffset(110, 28)
nightButton.Position = UDim2.fromOffset(0, 0)
nightButton.BackgroundColor3 = WASHI
nightButton.BackgroundTransparency = 0.3
nightButton.BorderSizePixel = 0
nightButton.AutoButtonColor = false
nightButton.TextColor3 = INK_CREAM
nightButton.Font = Enum.Font.Code
nightButton.TextSize = 13
nightButton.Parent = bottomBar
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = nightButton
end
paintNightButton()
nightButton.MouseButton1Click:Connect(function()
    if nightOn then
        disableNight()
    else
        enableNight()
    end
end)

-- ===== small helpers for building rows/buttons, shared by both sections =====
local function makeButton(parentRow: Instance, text: string, width: number, x: number): TextButton
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width, 26)
    b.Position = UDim2.fromOffset(x, 2)
    b.BackgroundColor3 = WASHI
    b.BackgroundTransparency = 0.3
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = text
    b.TextColor3 = INK_CREAM
    b.Font = Enum.Font.Code
    b.TextSize = 12
    b.Parent = parentRow
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b
    return b
end

local function makeRow(order: number): Frame
    local row = Instance.new("Frame")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = scroll
    return row
end

local function fireSingle(id: string, rack: string)
    RequestProvingFire:FireServer(id, rack)
end

-- ===== section header =====
local function makeHeader(order: number, text: string): Frame
    local row = makeRow(order)
    row.Size = UDim2.new(1, 0, 0, 20)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = GOLD
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = row
    return row
end

-- ===== Drafts section: one row per family, ladder/seq buttons, then one button per variant =====
local order = 0
order += 1
makeHeader(order, "-- Drafts --")

for _, family in FireworkDrafts.familyNames() do
    local variants = FireworkDrafts.variantsOf(family)
    order += 1
    local row = makeRow(order)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.fromOffset(90, 26)
    nameLabel.Position = UDim2.fromOffset(0, 2)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = INK_CREAM
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = family
    nameLabel.Parent = row

    local ladderButton = makeButton(row, "Ladder", 60, 92)
    ladderButton.MouseButton1Click:Connect(function()
        for _, entry in ProvingPlan.ladder(family, variants) do
            fireSingle(entry.id, entry.rack)
        end
    end)

    local seqButton = makeButton(row, "Seq", 44, 156)
    seqButton.MouseButton1Click:Connect(function()
        for _, entry in ProvingPlan.sequence(family, variants) do
            task.delay(entry.delaySeconds, function()
                fireSingle(entry.id, ProvingPlan.SEQUENCE_RACK)
            end)
        end
    end)

    local variantX = 204
    for _, variant in variants do
        local vButton = makeButton(row, variant, 40, variantX)
        local id = ("draft:%s/%s"):format(family, variant)
        vButton.MouseButton1Click:Connect(function()
            fireSingle(id, ProvingPlan.SEQUENCE_RACK)
        end)
        variantX += 44
    end
end

-- ===== Shipped section: one row per catalog id (sorted), a single Fire button =====
order += 1
makeHeader(order, "-- Shipped --")

local shippedIds: { string } = {}
for id in FireworkCatalog.RECIPES do
    table.insert(shippedIds, id)
end
table.sort(shippedIds)

for _, id in shippedIds do
    order += 1
    local row = makeRow(order)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.fromOffset(150, 26)
    nameLabel.Position = UDim2.fromOffset(0, 2)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = INK_CREAM
    nameLabel.Font = Enum.Font.Code
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = id
    nameLabel.Parent = row

    local fireButton = makeButton(row, "Fire", 50, 154)
    fireButton.MouseButton1Click:Connect(function()
        fireSingle(id, ProvingPlan.SEQUENCE_RACK)
    end)
end
