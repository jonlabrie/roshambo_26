--!strict
-- THE SHOP COUNTER. Opens when you step inside 花火屋, closes when you leave, and renders exactly
-- what the server sent — prices from EconomyState.catalog, counts from FireworkState.
--
-- IT EVALUATES NOTHING. Not affordability, not mortar tier order, not what a shell requires. Every
-- one of those is a server fact, and this codebase has a named, recurring defect where a number
-- authoritative on the server is re-derived client-side and goes stale. The one rule that lives
-- here is geometric — am I inside the box — and even that is in a tested module.
--
-- NOTHING HERE IS TESTED. No harness in this repo loads a `.client.luau`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local ShopThreshold = require(shared:WaitForChild("ShopThreshold"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent

local SHELL_ORDER = { "firecracker", "peony", "willow", "ishibana" }
local SHELL_NAME: { [string]: string } = {
    firecracker = "Firecracker",
    peony = "Peony",
    willow = "Willow",
    ishibana = "Ishibana",
}
local MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }
local MORTAR_NAME: { [string]: string } = {
    ["mortar:S"] = "Small mortar",
    ["mortar:M"] = "Medium mortar",
    ["mortar:L"] = "Large mortar",
}

local INK_CREAM = Color3.fromRGB(240, 234, 216)
local WASHI = Color3.fromRGB(26, 24, 28)
local GOLD = Color3.fromRGB(212, 176, 102)
local DIM = Color3.fromRGB(206, 199, 182)

-- ===== state, all of it the server's =====
local prices: { [string]: number } = {}
local mortarPrices: { [string]: number } = {}
local points = 0
local shells: any = nil
local ownedMortars: { [string]: boolean } = {}

-- ===== the panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "ShopPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- ZIndexBehavior defaults to Global, under which a child does NOT draw above its parent.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(340, 420)
panel.BackgroundColor3 = WASHI
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 34)
title.Position = UDim2.fromOffset(10, 8)
title.BackgroundTransparency = 1
title.TextColor3 = INK_CREAM
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "花火屋"
title.Parent = panel

local balance = Instance.new("TextLabel")
balance.Size = UDim2.new(1, -20, 0, 18)
balance.Position = UDim2.fromOffset(10, 40)
balance.BackgroundTransparency = 1
balance.TextColor3 = DIM
balance.Font = Enum.Font.Code
balance.TextSize = 13
balance.TextXAlignment = Enum.TextXAlignment.Left
balance.Parent = panel

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -20, 1, -70)
list.Position = UDim2.fromOffset(10, 64)
list.BackgroundTransparency = 1
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = list

type Row = { button: TextButton, title: TextLabel, sub: TextLabel, item: string }
local rows: { Row } = {}

local function makeRow(order: number, item: string, label: string): Row
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = WASHI
    b.BackgroundTransparency = 0.3
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = list
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -12, 0, 18)
    t.Position = UDim2.fromOffset(8, 3)
    t.BackgroundTransparency = 1
    t.TextColor3 = INK_CREAM
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = label
    t.Parent = b

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -12, 0, 14)
    s.Position = UDim2.fromOffset(8, 21)
    s.BackgroundTransparency = 1
    s.TextColor3 = DIM
    s.Font = Enum.Font.Code
    s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = b

    local row: Row = { button = b, title = t, sub = s, item = item }
    b.MouseButton1Click:Connect(function()
        EventBus.ShopPurchase:Fire(item)
    end)
    return row
end

do
    local order = 0
    for _, id in SHELL_ORDER do
        order += 1
        table.insert(rows, makeRow(order, "firework:" .. id, SHELL_NAME[id]))
    end
    for _, id in MORTAR_ORDER do
        order += 1
        table.insert(rows, makeRow(order, id, MORTAR_NAME[id]))
    end
end

local function paint()
    balance.Text = ("%d points"):format(points)
    for _, row in rows do
        local isShell = row.item:sub(1, 9) == "firework:"
        local key = if isShell then row.item:sub(10) else row.item
        local price = if isShell then prices[key] else mortarPrices[key]
        local afford = price ~= nil and points >= price
        local detail
        if price == nil then
            -- The catalog has not arrived yet. Say so rather than showing a confident zero.
            detail = "..."
        elseif isShell then
            local held = shells and shells[key] and shells[key].count or 0
            detail = ("%d pts   you hold %d"):format(price, held)
        elseif ownedMortars[key] then
            detail = "owned"
        else
            detail = ("%d pts"):format(price)
        end
        row.sub.Text = detail
        local live = price ~= nil and afford and not (not isShell and ownedMortars[key])
        row.button.BackgroundTransparency = if live then 0.3 else 0.65
        row.title.TextTransparency = if live then 0 else 0.4
    end
end

EconomyState.OnClientEvent:Connect(function(state)
    if typeof(state) ~= "table" then
        return
    end
    points = state.totalPoints or points
    local cat = state.catalog
    if typeof(cat) == "table" then
        prices = cat.fireworks or prices
        mortarPrices = cat.mortars or mortarPrices
    end
    paint()
end)

FireworkState.OnClientEvent:Connect(function(state)
    if typeof(state) ~= "table" then
        return
    end
    shells = state.shells
    ownedMortars = {}
    for _, id in state.mortars or {} do
        ownedMortars[id] = true
    end
    paint()
end)

EventBus.ShopPurchase.Event:Connect(function(item: string)
    RequestPurchase:FireServer({ item = item })
end)

-- ===== the threshold =====
-- Found by TAG, not by path: tags replicate, and a path would break the moment a second shop is
-- built. The added-signal handles the replication race — the model may arrive after this script.
local boxes: { { part: BasePart, box: any } } = {}

local function register(part: Instance)
    if not part:IsA("BasePart") then
        return
    end
    local p, s = part.Position, part.Size
    table.insert(boxes, {
        part = part,
        box = {
            x0 = p.X - s.X / 2,
            x1 = p.X + s.X / 2,
            y0 = p.Y - s.Y / 2,
            y1 = p.Y + s.Y / 2,
            z0 = p.Z - s.Z / 2,
            z1 = p.Z + s.Z / 2,
        },
    })
end

for _, part in CollectionService:GetTagged("ShopThreshold") do
    register(part)
end
CollectionService:GetInstanceAddedSignal("ShopThreshold"):Connect(register)

local inside = false
RunService.Heartbeat:Connect(function()
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local now = false
    if root then
        local p = root.Position
        local pos = { x = p.X, y = p.Y, z = p.Z }
        for _, entry in boxes do
            if ShopThreshold.isInside(pos, entry.box) then
                now = true
                break
            end
        end
    end
    if now ~= inside then
        inside = now
        gui.Enabled = now
        if now then
            paint()
        end
    end
end)
