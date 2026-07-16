--!strict
-- B3 teahouse management panel. A persistent HUD button opens a panel that renders
-- TeahouseMenuModel over the echoed economy/preference/back-door state, and fires the
-- purchase/display/preference remotes. World prompts (claim, back-door, favorite-add) live on
-- their own controllers (EconomyController, BackDoorController, PerchPreferenceController); this
-- is the from-anywhere hub for upgrades + display + favorites.
--
-- First-deck rule: a fresh player's FIRST deck purchase stays a world buy-to-claim prompt
-- (EconomyController), not something this panel offers -- so when the player owns no deck yet,
-- both ladders render greyed (no click wired) with a "claim a free perch" pointer instead.
--
-- Display clicks: SetDisplay is a full-replace route server-side (an omitted field resets that
-- dimension to nil/"auto"), so every fire here sends BOTH deckDisplay and teahouseDisplay --
-- reading the one that didn't change off the live `econ` table at click time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local MenuModel = require(shared:WaitForChild("TeahouseMenuModel"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local SetDisplay = remotes:WaitForChild("SetDisplay") :: RemoteEvent
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent

-- latest merged state fed to MenuModel.viewModel
local econ = {
    totalPoints = 0,
    maxDeckSize = nil :: string?,
    teahouseSizes = {} :: { string },
    claimedPadId = nil :: string?,
    deckDisplay = nil :: string?,
    teahouseDisplay = nil :: string?,
    padPreferences = {} :: { string },
    catalog = { deck = {}, teahouse = {} } :: { deck: { [string]: number }, teahouse: { [string]: number } },
}
local backDoorIndex: number? = nil

-- catalog arrives async (first EconomyState echo); until then MenuModel.viewModel can't safely
-- price the next-tier rungs (nil price), so render() shows a loading line and skips the ladders.
local function catalogReady(): boolean
    return next(econ.catalog.deck) ~= nil
end

-- ===== palette (toast palette, per B1/B2 convention) =====
local BG = Color3.fromRGB(20, 18, 16)
local TEXT = Color3.fromRGB(240, 228, 205)
local GOLD = Color3.fromRGB(212, 176, 102) -- owned / affordable accent
local DIM = Color3.fromRGB(110, 102, 92) -- locked / disabled
local DANGER = Color3.fromRGB(206, 86, 86) -- remove-favorite

-- ===== Step 1: scaffold =====
local gui = Instance.new("ScreenGui")
gui.Name = "TeahousePanel"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "Toggle"
toggleButton.AnchorPoint = Vector2.new(1, 0)
toggleButton.Position = UDim2.new(1, -12, 0, 12)
toggleButton.Size = UDim2.fromOffset(140, 40)
toggleButton.BackgroundColor3 = BG
toggleButton.BackgroundTransparency = 0.1
toggleButton.TextColor3 = TEXT
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 16
toggleButton.Text = "Teahouse"
toggleButton.Parent = gui
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toggleButton
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 60)
panel.Size = UDim2.fromOffset(340, 520)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = gui
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = panel
end

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

-- ===== Step 2: widgets =====

local function sectionLabel(order: number, text: string): TextLabel
    local label = Instance.new("TextLabel")
    label.Name = "Section"
    label.LayoutOrder = order
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.TextColor3 = TEXT
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = panel
    return label
end

local headerLabel = Instance.new("TextLabel")
headerLabel.Name = "Header"
headerLabel.LayoutOrder = 1
headerLabel.Size = UDim2.new(1, 0, 0, 28)
headerLabel.BackgroundTransparency = 1
headerLabel.TextColor3 = TEXT
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextSize = 18
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Text = "Loading..."
headerLabel.Parent = panel

local claimNotice = Instance.new("TextLabel")
claimNotice.Name = "ClaimNotice"
claimNotice.LayoutOrder = 2
claimNotice.Size = UDim2.new(1, 0, 0, 18)
claimNotice.BackgroundTransparency = 1
claimNotice.TextColor3 = GOLD
claimNotice.Font = Enum.Font.Gotham
claimNotice.TextSize = 13
claimNotice.TextXAlignment = Enum.TextXAlignment.Left
claimNotice.Text = "Claim a free perch to begin"
claimNotice.Visible = false
claimNotice.Parent = panel

type RungWidget = { button: TextButton, pendingItem: string? }

-- One row of up-to-3 rung buttons (S/M/L) for a ladder ("deck" or "teahouse"). Returns a
-- size -> widget map so render() can update label/state per rung.
local function buildLadderRow(order: number, title: string, kind: string): { [string]: RungWidget }
    sectionLabel(order, title)
    local row = Instance.new("Frame")
    row.Name = kind .. "Row"
    row.LayoutOrder = order + 1
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.Parent = panel
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding = UDim.new(0, 6)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = row

    local widgets: { [string]: RungWidget } = {}
    for i, size in { "S", "M", "L" } do
        local button = Instance.new("TextButton")
        button.Name = size
        button.LayoutOrder = i
        button.Size = UDim2.fromOffset(102, 36)
        button.BackgroundColor3 = BG
        button.BackgroundTransparency = 0.1
        button.TextColor3 = TEXT
        button.Font = Enum.Font.Gotham
        button.TextSize = 13
        button.Text = size
        button.Active = false -- render() enables once the catalog/ladder state is known
        button.Parent = row
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button

        local widget: RungWidget = { button = button, pendingItem = nil }
        widgets[size] = widget
        button.MouseButton1Click:Connect(function()
            if button.Active and widget.pendingItem then
                RequestPurchase:FireServer({ item = widget.pendingItem })
            end
        end)
    end
    return widgets
end

local deckWidgets = buildLadderRow(3, "Deck", "deck")
local teaWidgets = buildLadderRow(5, "Teahouse", "teahouse")

type DisplayWidget = { button: TextButton, value: string }

-- One row of display-option buttons ("deck": S/M/L; "teahouse": none/S/M/L). `onPick(value)`
-- fires SetDisplay with both fields -- the caller supplies the other (unchanged) dimension.
local function buildDisplayRow(
    order: number,
    title: string,
    values: { string },
    onPick: (string) -> ()
): (Frame, { [string]: DisplayWidget })
    sectionLabel(order, title)
    local row = Instance.new("Frame")
    row.Name = title .. "DisplayRow"
    row.LayoutOrder = order + 1
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent = panel
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding = UDim.new(0, 6)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = row

    local widgets: { [string]: DisplayWidget } = {}
    for i, value in values do
        local button = Instance.new("TextButton")
        button.Name = value
        button.LayoutOrder = i
        button.Size = UDim2.fromOffset(76, 30)
        button.BackgroundColor3 = BG
        button.BackgroundTransparency = 0.1
        button.TextColor3 = TEXT
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.Text = if value == "none" then "None" else value
        button.Active = false -- render() enables once ownsTeahouse + option state are known
        button.Parent = row
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button

        widgets[value] = { button = button, value = value }
        button.MouseButton1Click:Connect(function()
            if button.Active then
                onPick(value)
            end
        end)
    end
    -- container row is returned so render() can hide the whole thing when the player owns no
    -- teahouse yet (display only makes sense once there's something to display).
    return row, widgets
end

local deckDisplayRow, deckDisplayWidgets = buildDisplayRow(7, "Deck shown", { "S", "M", "L" }, function(value)
    SetDisplay:FireServer({ deckDisplay = value, teahouseDisplay = econ.teahouseDisplay })
end)
local teaDisplayRow, teaDisplayWidgets = buildDisplayRow(
    9,
    "Teahouse shown",
    { "none", "S", "M", "L" },
    function(value)
        SetDisplay:FireServer({ deckDisplay = econ.deckDisplay, teahouseDisplay = value })
    end
)
-- hidden until the first successful render() confirms ownsTeahouse (also covers the brief
-- loading window before the first EconomyState echo carries a populated catalog)
deckDisplayRow.Visible = false
teaDisplayRow.Visible = false

sectionLabel(11, "Favorites")
local favoritesContainer = Instance.new("Frame")
favoritesContainer.Name = "Favorites"
favoritesContainer.LayoutOrder = 12
favoritesContainer.AutomaticSize = Enum.AutomaticSize.Y
favoritesContainer.Size = UDim2.fromScale(1, 0)
favoritesContainer.BackgroundTransparency = 1
favoritesContainer.Parent = panel
local favoritesLayout = Instance.new("UIListLayout")
favoritesLayout.FillDirection = Enum.FillDirection.Vertical
favoritesLayout.Padding = UDim.new(0, 4)
favoritesLayout.SortOrder = Enum.SortOrder.LayoutOrder
favoritesLayout.Parent = favoritesContainer

local backDoorLabel = Instance.new("TextLabel")
backDoorLabel.Name = "BackDoor"
backDoorLabel.LayoutOrder = 13
backDoorLabel.Size = UDim2.new(1, 0, 0, 16)
backDoorLabel.BackgroundTransparency = 1
backDoorLabel.TextColor3 = DIM
backDoorLabel.Font = Enum.Font.Gotham
backDoorLabel.TextSize = 12
backDoorLabel.TextXAlignment = Enum.TextXAlignment.Left
backDoorLabel.Text = "Back door: none set"
backDoorLabel.Parent = panel

-- ===== Step 3: render() =====

local function styleOwned(w: RungWidget, size: string)
    w.button.Text = `{size}  ✓`
    w.button.TextColor3 = GOLD
    w.button.Active = false
end

local function styleLocked(w: RungWidget, size: string)
    w.button.Text = `{size} — locked`
    w.button.TextColor3 = DIM
    w.button.Active = false
end

local function styleBuyable(w: RungWidget, size: string, price: number, affordable: boolean)
    w.button.Text = `{size} — {price} pts`
    w.button.TextColor3 = if affordable then GOLD else DIM
    w.button.Active = affordable
end

-- Renders one ladder's rungs. `forceLock`, set only for the deck ladder when the player owns
-- no deck yet, overrides the model's "isNext" S rung so the panel never offers a first-deck
-- purchase (that stays a world buy-to-claim prompt).
local function renderLadder(
    widgets: { [string]: RungWidget },
    ladder: { any },
    kind: string,
    forceLock: boolean
)
    for _, rung in ladder do
        local w = widgets[rung.size]
        w.pendingItem = nil
        if not forceLock and rung.owned then
            styleOwned(w, rung.size)
        elseif not forceLock and rung.isNext then
            styleBuyable(w, rung.size, rung.price, rung.affordable == true)
            w.pendingItem = `{kind}:{rung.size}`
        else
            styleLocked(w, rung.size)
        end
    end
end

local function renderDisplayOptions(widgets: { [string]: DisplayWidget }, options: { any })
    for _, opt in options do
        local w = widgets[opt.value]
        if w == nil then
            continue
        end
        w.button.Active = opt.enabled == true
        if opt.selected then
            w.button.TextColor3 = GOLD
            w.button.BackgroundTransparency = 0
        elseif opt.enabled then
            w.button.TextColor3 = TEXT
            w.button.BackgroundTransparency = 0.1
        else
            w.button.TextColor3 = DIM
            w.button.BackgroundTransparency = 0.1
        end
    end
end

local function renderFavorites(favorites: { string })
    for _, child in favoritesContainer:GetChildren() do
        if child ~= favoritesLayout then
            child:Destroy()
        end
    end

    if #favorites == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 18)
        empty.BackgroundTransparency = 1
        empty.TextColor3 = DIM
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.Text = "No favorites yet"
        empty.Parent = favoritesContainer
        return
    end

    for i, siteId in favorites do
        local row = Instance.new("Frame")
        row.Name = "Fav_" .. siteId
        row.LayoutOrder = i
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Parent = favoritesContainer

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -28, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = TEXT
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Perch " .. siteId
        label.Parent = row

        local remove = Instance.new("TextButton")
        remove.AnchorPoint = Vector2.new(1, 0)
        remove.Position = UDim2.fromScale(1, 0)
        remove.Size = UDim2.fromOffset(22, 22)
        remove.BackgroundColor3 = BG
        remove.BackgroundTransparency = 0.1
        remove.TextColor3 = DANGER
        remove.Font = Enum.Font.GothamBold
        remove.TextSize = 14
        remove.Text = "x"
        remove.Parent = row
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = remove

        remove.MouseButton1Click:Connect(function()
            SetPadPreference:FireServer(siteId)
        end)
    end
end

local function render()
    if not catalogReady() then
        headerLabel.Text = "Loading..."
        return
    end

    local vm = MenuModel.viewModel(econ)

    local perchText = if econ.claimedPadId ~= nil
        then `Perch: {econ.claimedPadId}`
        else "No perch claimed yet"
    headerLabel.Text = `{vm.points} pts  ·  {perchText}`

    claimNotice.Visible = not vm.ownsDeck
    renderLadder(deckWidgets, vm.deckLadder, "deck", not vm.ownsDeck)
    renderLadder(teaWidgets, vm.teahouseLadder, "teahouse", false)

    deckDisplayRow.Visible = vm.ownsTeahouse
    teaDisplayRow.Visible = vm.ownsTeahouse
    if vm.ownsTeahouse then
        renderDisplayOptions(deckDisplayWidgets, vm.deckDisplayOptions)
        renderDisplayOptions(teaDisplayWidgets, vm.teahouseDisplayOptions)
    end

    renderFavorites(vm.favorites)

    backDoorLabel.Text = if backDoorIndex ~= nil
        then `Back door: bay {backDoorIndex}`
        else "Back door: none set"
end

-- ===== Step 4: echo wiring =====

EconomyState.OnClientEvent:Connect(function(p)
    econ.totalPoints = p.totalPoints
    econ.maxDeckSize = p.maxDeckSize
    econ.teahouseSizes = p.teahouseSizes or {}
    econ.claimedPadId = p.claimedPadId
    econ.deckDisplay = p.deckDisplay
    econ.teahouseDisplay = p.teahouseDisplay
    if p.catalog then
        econ.catalog = p.catalog
    end
    render()
end)

PreferenceState.OnClientEvent:Connect(function(p)
    econ.padPreferences = p.padPreferences or {}
    render()
end)

BackDoorState.OnClientEvent:Connect(function(p)
    backDoorIndex = p.backDoorIndex
    render()
end)

-- ===== Step 5: toggle =====

local open = false
local function setOpen(shouldOpen: boolean)
    open = shouldOpen
    panel.Visible = open
    if open then
        render()
    end
end

toggleButton.MouseButton1Click:Connect(function()
    setOpen(not open)
end)
