--!strict
-- B3 teahouse management panel. The ledger's MY TEAHOUSE button (EventBus.OpenTeahouse) opens a
-- panel that renders TeahouseMenuModel over the echoed economy/preference/back-door state, and fires
-- the purchase/display/preference remotes. World prompts (claim, back-door, favorite-add) live on
-- their own controllers (EconomyController, BackDoorController, PerchPreferenceController); this
-- is the from-anywhere hub for upgrades + display + favorites.
--
-- First-deck rule: a fresh player's FIRST deck purchase stays a world buy-to-claim prompt
-- (EconomyController), not something this panel offers -- so when the player owns no deck yet,
-- both ladders render greyed (no click wired) with a "claim a free perch" pointer instead.
--
-- Claimless owner (B3 gate wave, item A): a RETURNING owner whose auto-claim failed at join
-- (every pad was occupied) has claimedPadId == nil even though they own a deck. The server
-- dead-drops both a purchase (misclassified as buy-to-claim, no padId) and SetDisplay (gated on
-- claim) for them, so MenuModel forces every rung/option unbuyable/disabled and sets
-- vm.needsClaim -- the panel shows one hint line instead of dead buttons.
--
-- Shown-smaller (item B): after buying a bigger size while a smaller Display cap is still set,
-- the world doesn't grow to match. MenuModel flags vm.deckShownSmaller / vm.teahouseShownSmaller
-- when the display is capping below the biggest owned; the panel surfaces one hint line.
--
-- Display clicks: SetDisplay is a full-replace route server-side (an omitted field resets that
-- dimension to nil/"auto"), so every fire here sends BOTH deckDisplay and teahouseDisplay. A
-- client-side `desired` pair (item G) -- not the live `econ` echo -- is the source for both
-- fields: reading off `econ` would let a click on one dimension re-send the OTHER dimension's
-- stale pre-click value if its own round trip hasn't echoed back yet, silently reverting it.
-- The no-op guard (item F) compares a click's value against `desired`, not the last echo, for
-- the same reason.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local MenuModel = require(shared:WaitForChild("TeahouseMenuModel"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))
local Takeover = require(script.Parent:WaitForChild("Takeover"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local SetDisplay = remotes:WaitForChild("SetDisplay") :: RemoteEvent
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent
local SetAccess = remotes:WaitForChild("SetAccess") :: RemoteEvent
local InviteUser = remotes:WaitForChild("InviteUser") :: RemoteEvent
local RevokeUser = remotes:WaitForChild("RevokeUser") :: RemoteEvent
local AccessState = remotes:WaitForChild("AccessState") :: RemoteEvent

-- latest merged state fed to MenuModel.viewModel
local econ = {
    totalPoints = 0,
    maxDeckSize = nil :: string?,
    teahouseSizes = {} :: { string },
    claimedPadId = nil :: string?,
    claimed = false, -- item A: econ.claimedPadId ~= nil, kept alongside it for MenuModel
    deckDisplay = nil :: string?,
    teahouseDisplay = nil :: string?,
    padPreferences = {} :: { string },
    catalog = { deck = {}, teahouse = {}, portal = 0, decoration = {} } :: {
        deck: { [string]: number },
        teahouse: { [string]: number },
        portal: number,
        decoration: { [string]: number },
    },
    portalOwned = false,
    deckDecorations = {} :: { any },
}
local backDoorIndex: number? = nil
local access = { mode = "public", invited = {} :: { { userId: number, name: string } } }
local accessNotice: string? = nil
local favoriteNames: { [string]: string } = {} -- item C: siteId -> real name, from PreferenceState
-- B4 Task 5: mirrors vm.canMove from the latest render(), read by the Move-teahouse click handler
-- (which fires after render() has moved on, so it can't read `vm` directly).
local currentCanMove = false
-- Task 5 (home portal): same mirror pattern, read by the portal-button click handler.
local currentPortalCanBuy = false

-- item G: the pair actually sent on the next SetDisplay fire. Reconciled from every
-- EconomyState echo (server is authoritative); a click updates only its own dimension here, so a
-- second click on the OTHER dimension before the first's round trip returns can't clobber it.
local desired = { deckDisplay = nil :: string?, teahouseDisplay = nil :: string? }

-- item E: true once the first EconomyState echo has arrived. render() also requires a populated
-- catalog (belt-and-braces: an echo can in principle carry an empty catalog if this player's
-- initial getEconomy call failed server-side before any catalog was ever fetched) so pricing
-- never indexes a missing entry.
local ready = false
local function catalogReady(): boolean
    return ready and next(econ.catalog.deck) ~= nil
end

-- ===== palette (toast palette, per B1/B2 convention) =====
local BG = Color3.fromRGB(20, 18, 16)
local TEXT = Color3.fromRGB(240, 228, 205)
local GOLD = Color3.fromRGB(212, 176, 102) -- owned / affordable accent
local DIM = Color3.fromRGB(110, 102, 92) -- locked / disabled
local DANGER = Color3.fromRGB(206, 86, 86) -- remove-favorite

-- ===== Step 1: scaffold =====
-- NO PERSISTENT TOGGLE. This panel used to carry its own 140x40 button pinned to the bottom-right
-- corner, and on a narrow viewport its left edge crossed under the HUD's scissors button (the throw
-- row is anchored at 1 - JUMP_CLEARANCE, which is a FRACTION of the width, so the two clear each
-- other on a desktop and collide on a phone). It also cost a permanent hole in the camera-drag
-- surface -- one that was up every second of every session for a panel opened rarely.
--
-- THE LEDGER IS THE DOOR NOW: its MY TEAHOUSE button fires EventBus.OpenTeahouse (see the bottom of
-- this file), having closed itself first. That follows the play-HUD design's own rule -- the
-- player-state plate is the ONE persistent interactive element, so nothing else needs a button.
local gui = Instance.new("ScreenGui")
gui.Name = "TeahousePanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20 -- a takeover, same layer as the ledger; only one is ever open at a time
gui.Parent = player:WaitForChild("PlayerGui")

-- A TAKEOVER, on the ledger's pattern -- which is the pattern that does not have the bug this
-- panel had. It was 520px tall at a fixed offset from the bottom, so on any viewport shorter
-- than 580px the close button sat ABOVE THE TOP OF THE SCREEN and the panel could not be
-- dismissed at all. Sizing against the viewport rather than in absolute pixels is what makes
-- that impossible rather than merely unlikely.
--
-- `panel` is now the outer card: viewport-relative, so it cannot exceed the screen at any size.
-- Its content used to live directly on a ScrollingFrame named `panel` with the close button
-- floating over it as a sibling positioned from the viewport edge. That close button now has to
-- live INSIDE the panel, anchored to the panel's own corner -- and a UIListLayout repositions
-- every GuiObject child it has, with no per-child exemption, so a close button parented
-- alongside the scrolling content would get dragged into the list instead of floating over it.
-- `scroll` is a second, inner ScrollingFrame that owns the list/canvas machinery and sits below
-- a HEADER_H-tall strip reserved for the close button.
local PANEL_MARGIN = 12
local HEADER_H = 44
local CLOSE_W = 34

-- Tap outside the panel closes -- the ledger's pattern (LedgerController:118-126). A TextButton
-- is the catcher, parented BEFORE `panel` so it sits behind it, and it blackens the world behind,
-- which is what a takeover is. Without this, the 12px margin around the panel (and, absent
-- panel.Active below, the whole panel) would leak taps through to whatever ScreenGui sits under
-- this one's DisplayOrder 20 -- the minimal HUD's live throw/bank/ledger buttons at DisplayOrder 0.
local scrim = Instance.new("TextButton")
scrim.Name = "Scrim"
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.35
scrim.BorderSizePixel = 0
scrim.AutoButtonColor = false
scrim.Text = ""
scrim.Visible = false
scrim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
-- Active = true, deliberately (LedgerController:131-132). A Frame that is not Active does not
-- consume input, so every tap inside the panel would fall through to the scrim behind it -- or,
-- since the scrim only covers the gap the panel leaves, straight through to the HUD buttons under
-- this GUI's DisplayOrder.
panel.Active = true
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -2 * PANEL_MARGIN, 1, -2 * PANEL_MARGIN)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = panel
end

-- INSIDE the panel's own header, positioned against the panel rather than against a fixed
-- offset from the viewport edge. That offset is what put it off-screen. The only way out, now
-- the toggle is gone: the header strip above `scroll` is never part of the scrolling canvas, so
-- a close control you have to scroll back up to find is not a close control.
local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -PANEL_MARGIN, 0, (HEADER_H - CLOSE_W) / 2)
closeButton.Size = UDim2.fromOffset(CLOSE_W, CLOSE_W)
closeButton.BackgroundColor3 = BG
closeButton.BackgroundTransparency = 0.1
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.TextColor3 = TEXT
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 20
closeButton.Text = "X"
closeButton.Visible = false
closeButton.ZIndex = 3 -- above the panel and the scroll content it sits over
closeButton.Parent = panel
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = closeButton
end

-- The scrolling body: a fixed viewport (the panel below the header strip) with an auto-growing
-- canvas -- as sections accumulate (sizes/display/move/portal/decorations/favorites/back-door/
-- access) the content exceeds the viewport and the user scrolls. Was a plain Frame, which
-- silently overflowed its bottom edge -> later sections (Access) rendered off-screen as
-- detached buttons.
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Scroll"
scroll.Position = UDim2.fromOffset(0, HEADER_H)
scroll.Size = UDim2.new(1, 0, 1, -HEADER_H)
scroll.CanvasSize = UDim2.new() -- AutomaticCanvasSize.Y grows the canvas to fit the UIListLayout
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ScrollBarThickness = 8
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = scroll

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
    label.Parent = scroll
    return label
end

local headerLabel = Instance.new("TextLabel")
headerLabel.Name = "Header"
headerLabel.LayoutOrder = 10
-- Full width now: the close button moved into its own header strip above `scroll` (see the
-- panel/closeButton/scroll scaffold above), so it no longer overlays this row and this label
-- no longer needs to leave room for it.
headerLabel.Size = UDim2.new(1, 0, 0, 28)
headerLabel.BackgroundTransparency = 1
headerLabel.TextColor3 = TEXT
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextSize = 18
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Text = "Loading..."
headerLabel.Parent = scroll

local claimNotice = Instance.new("TextLabel")
claimNotice.Name = "ClaimNotice"
claimNotice.LayoutOrder = 20
claimNotice.Size = UDim2.new(1, 0, 0, 18)
claimNotice.BackgroundTransparency = 1
claimNotice.TextColor3 = GOLD
claimNotice.Font = Enum.Font.Gotham
claimNotice.TextSize = 13
claimNotice.TextXAlignment = Enum.TextXAlignment.Left
claimNotice.Text = "Claim a free perch to begin"
claimNotice.Visible = false
claimNotice.Parent = scroll

-- item A: shown instead of claimNotice for an OWNER whose auto-claim failed (pad scarcity) --
-- see vm.needsClaim in TeahouseMenuModel.
local needsClaimHint = Instance.new("TextLabel")
needsClaimHint.Name = "NeedsClaimHint"
needsClaimHint.LayoutOrder = 30
needsClaimHint.Size = UDim2.new(1, 0, 0, 18)
needsClaimHint.BackgroundTransparency = 1
needsClaimHint.TextColor3 = GOLD
needsClaimHint.Font = Enum.Font.Gotham
needsClaimHint.TextSize = 13
needsClaimHint.TextXAlignment = Enum.TextXAlignment.Left
needsClaimHint.Text = "Claim a perch to build"
needsClaimHint.Visible = false
needsClaimHint.Parent = scroll

-- item E: the only thing shown pre-ready (see render()); hides the ladder rows below it rather
-- than letting their default-visible bare S/M/L buttons show inert before data arrives.
local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "LoadingLabel"
loadingLabel.LayoutOrder = 35
loadingLabel.Size = UDim2.new(1, 0, 0, 18)
loadingLabel.BackgroundTransparency = 1
loadingLabel.TextColor3 = DIM
loadingLabel.Font = Enum.Font.Gotham
loadingLabel.TextSize = 13
loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
loadingLabel.Text = "Loading…"
loadingLabel.Visible = false
loadingLabel.Parent = scroll

type RungWidget = { button: TextButton, pendingItem: string? }

-- One row of up-to-3 rung buttons (S/M/L) for a ladder ("deck" or "teahouse"). Returns a
-- size -> widget map, plus the section-label + row handles (item E hides both pre-ready) so
-- render() can update label/state per rung.
local function buildLadderRow(
    order: number,
    title: string,
    kind: string
): ({ [string]: RungWidget }, TextLabel, Frame)
    local section = sectionLabel(order, title)
    local row = Instance.new("Frame")
    row.Name = kind .. "Row"
    row.LayoutOrder = order + 1
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.Parent = scroll
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
    return widgets, section, row
end

local deckWidgets, deckSection, deckRow = buildLadderRow(40, "Deck", "deck")
local teaWidgets, teaSection, teaRow = buildLadderRow(50, "Teahouse", "teahouse")

type DisplayWidget = { button: TextButton, value: string }

-- One row of display-option buttons ("deck": S/M/L; "teahouse": none/S/M/L). `onPick(value)` is
-- called with the clicked value; the caller (pickDeckDisplay/pickTeahouseDisplay, item G) owns
-- reading/updating the other (unchanged) dimension via `desired` and firing SetDisplay.
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
    row.Parent = scroll
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

-- item G: click handlers fire off `desired`, not the live `econ` echo -- see the comment atop
-- this file. item F: each is a no-op when the clicked value already matches `desired` for that
-- dimension, so re-selecting the current option skips the round trip + world rebuild entirely.
local function pickDeckDisplay(value: string)
    if value == desired.deckDisplay then
        return
    end
    desired.deckDisplay = value
    SetDisplay:FireServer({ deckDisplay = desired.deckDisplay, teahouseDisplay = desired.teahouseDisplay })
end

local function pickTeahouseDisplay(value: string)
    if value == desired.teahouseDisplay then
        return
    end
    desired.teahouseDisplay = value
    SetDisplay:FireServer({ deckDisplay = desired.deckDisplay, teahouseDisplay = desired.teahouseDisplay })
end

local deckDisplayRow, deckDisplayWidgets =
    buildDisplayRow(60, "Deck shown", { "S", "M", "L" }, pickDeckDisplay)
local teaDisplayRow, teaDisplayWidgets =
    buildDisplayRow(70, "Teahouse shown", { "none", "S", "M", "L" }, pickTeahouseDisplay)
-- hidden until the first successful render() confirms ownsTeahouse (also covers the brief
-- loading window before the first EconomyState echo carries a populated catalog)
deckDisplayRow.Visible = false
teaDisplayRow.Visible = false

-- B4 Task 5: enters Move-teahouse mode for the claimed perch's standing building. Gated on
-- vm.canMove (claimed + owns a teahouse + not display-hidden); hidden alongside the display rows
-- above (same vm.ownsTeahouse group -- moving makes no sense before there's anything built, and
-- this stays hidden pre-ready the same way they do, via this construction-time default).
local moveButton = Instance.new("TextButton")
moveButton.Name = "MoveButton"
moveButton.LayoutOrder = 72
moveButton.Size = UDim2.new(1, 0, 0, 32)
moveButton.BackgroundColor3 = BG
moveButton.BackgroundTransparency = 0.1
moveButton.TextColor3 = DIM
moveButton.Font = Enum.Font.Gotham
moveButton.TextSize = 13
moveButton.Text = "Move teahouse"
moveButton.Active = false -- render() enables once vm.canMove is known
moveButton.Visible = false
moveButton.Parent = scroll
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = moveButton
end

-- Task 5: one-time buy for a claimed deck-owner who doesn't already own a home portal. Gated on
-- vm.ownsDeck (nothing to attach a portal to without a deck) -- same hidden-until-ready +
-- owner-only-row idiom as moveButton above.
local portalButton = Instance.new("TextButton")
portalButton.Name = "PortalButton"
portalButton.LayoutOrder = 73
portalButton.Size = UDim2.new(1, 0, 0, 32)
portalButton.BackgroundColor3 = BG
portalButton.BackgroundTransparency = 0.1
portalButton.TextColor3 = DIM
portalButton.Font = Enum.Font.Gotham
portalButton.TextSize = 13
portalButton.Text = "Home Portal"
portalButton.Active = false -- render() enables once vm.portal.canBuy is known
portalButton.Visible = false
portalButton.Parent = scroll
do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = portalButton
end

-- item B: one hint line when either display is quietly capping below the biggest owned size.
local shownSmallerHint = Instance.new("TextLabel")
shownSmallerHint.Name = "ShownSmallerHint"
shownSmallerHint.LayoutOrder = 75
shownSmallerHint.Size = UDim2.new(1, 0, 0, 18)
shownSmallerHint.BackgroundTransparency = 1
shownSmallerHint.TextColor3 = GOLD
shownSmallerHint.Font = Enum.Font.Gotham
shownSmallerHint.TextSize = 12
shownSmallerHint.TextXAlignment = Enum.TextXAlignment.Left
shownSmallerHint.TextWrapped = true
shownSmallerHint.Text = "Displaying smaller than owned — change Display to show your biggest"
shownSmallerHint.Visible = false
shownSmallerHint.Parent = scroll

sectionLabel(80, "Favorites")
-- item D: favorites can reach the 32-preference cap. The panel itself now scrolls, so favorites
-- grows inline (AutomaticSize.Y) and the whole panel scrolls to reach it -- a nested ScrollingFrame
-- here would trap the scroll wheel over the list.
local favoritesContainer = Instance.new("Frame")
favoritesContainer.Name = "Favorites"
favoritesContainer.LayoutOrder = 81
favoritesContainer.Size = UDim2.fromScale(1, 0)
favoritesContainer.AutomaticSize = Enum.AutomaticSize.Y
favoritesContainer.BackgroundTransparency = 1
favoritesContainer.BorderSizePixel = 0
favoritesContainer.Parent = scroll
local favoritesLayout = Instance.new("UIListLayout")
favoritesLayout.FillDirection = Enum.FillDirection.Vertical
favoritesLayout.Padding = UDim.new(0, 4)
favoritesLayout.SortOrder = Enum.SortOrder.LayoutOrder
favoritesLayout.Parent = favoritesContainer

local backDoorLabel = Instance.new("TextLabel")
backDoorLabel.Name = "BackDoor"
backDoorLabel.LayoutOrder = 90
backDoorLabel.Size = UDim2.new(1, 0, 0, 16)
backDoorLabel.BackgroundTransparency = 1
backDoorLabel.TextColor3 = DIM
backDoorLabel.Font = Enum.Font.Gotham
backDoorLabel.TextSize = 12
backDoorLabel.TextXAlignment = Enum.TextXAlignment.Left
backDoorLabel.Text = "Back door: none set"
backDoorLabel.Parent = scroll

local DECOR_LABELS = {
    ishidoro = "Stone Lantern",
    tsukubai = "Water Basin",
    bonsai = "Potted Bonsai",
    bench = "Wooden Bench",
}

sectionLabel(76, "Decorations")
local decorContainer = Instance.new("Frame")
decorContainer.Name = "Decorations"
decorContainer.LayoutOrder = 77
decorContainer.Size = UDim2.fromScale(1, 0)
decorContainer.AutomaticSize = Enum.AutomaticSize.Y
decorContainer.BackgroundTransparency = 1
decorContainer.Parent = scroll
local decorLayout = Instance.new("UIListLayout")
decorLayout.FillDirection = Enum.FillDirection.Vertical
decorLayout.Padding = UDim.new(0, 4)
decorLayout.SortOrder = Enum.SortOrder.LayoutOrder
decorLayout.Parent = decorContainer

-- propId -> its buy button, created once (catalog is fixed); render() updates label/enabled.
local decorButtons: { [string]: TextButton } = {}

-- Because the panel's construction order runs before the first echo, create the buttons lazily
-- on the first render that has a catalog.
local function ensureDecorButtons(vm: any)
    if next(decorButtons) ~= nil then
        return
    end
    for i, d in vm.decorations do
        local button = Instance.new("TextButton")
        button.Name = "Decor_" .. d.propId
        button.LayoutOrder = i
        button.Size = UDim2.new(1, 0, 0, 30)
        button.BackgroundColor3 = BG
        button.BackgroundTransparency = 0.1
        button.TextColor3 = DIM
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Active = false
        button.Parent = decorContainer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
        local propId = d.propId
        button.MouseButton1Click:Connect(function()
            if button.Active then
                RequestPurchase:FireServer({ item = "decoration:" .. propId })
            end
        end)
        decorButtons[propId] = button
    end
end

sectionLabel(82, "Access")

-- mode toggle row (public / friends / private)
local accessModeRow = Instance.new("Frame")
accessModeRow.Name = "AccessModeRow"
accessModeRow.LayoutOrder = 83
accessModeRow.Size = UDim2.new(1, 0, 0, 30)
accessModeRow.BackgroundTransparency = 1
accessModeRow.Parent = scroll
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = accessModeRow
end
local accessModeButtons: { [string]: TextButton } = {}
for i, mode in { "public", "friends", "private" } do
    local button = Instance.new("TextButton")
    button.Name = mode
    button.LayoutOrder = i
    button.Size = UDim2.fromOffset(100, 30)
    button.BackgroundColor3 = BG
    button.BackgroundTransparency = 0.1
    button.TextColor3 = TEXT
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.Text = mode:sub(1, 1):upper() .. mode:sub(2)
    button.Parent = accessModeRow
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    button.MouseButton1Click:Connect(function()
        SetAccess:FireServer({ mode = mode })
    end)
    accessModeButtons[mode] = button
end

-- invite field + button (shown only in private mode)
local inviteRow = Instance.new("Frame")
inviteRow.Name = "InviteRow"
inviteRow.LayoutOrder = 84
inviteRow.Size = UDim2.new(1, 0, 0, 30)
inviteRow.BackgroundTransparency = 1
inviteRow.Visible = false
inviteRow.Parent = scroll
local inviteBox = Instance.new("TextBox")
inviteBox.Name = "InviteBox"
inviteBox.Size = UDim2.new(1, -70, 1, 0)
inviteBox.BackgroundColor3 = BG
inviteBox.BackgroundTransparency = 0.1
inviteBox.TextColor3 = TEXT
inviteBox.PlaceholderText = "username"
inviteBox.Font = Enum.Font.Gotham
inviteBox.TextSize = 12
inviteBox.ClearTextOnFocus = false
inviteBox.Text = ""
inviteBox.Parent = inviteRow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inviteBox
end
local inviteButton = Instance.new("TextButton")
inviteButton.Name = "InviteButton"
inviteButton.AnchorPoint = Vector2.new(1, 0)
inviteButton.Position = UDim2.fromScale(1, 0)
inviteButton.Size = UDim2.fromOffset(64, 30)
inviteButton.BackgroundColor3 = BG
inviteButton.BackgroundTransparency = 0.1
inviteButton.TextColor3 = GOLD
inviteButton.Font = Enum.Font.GothamBold
inviteButton.TextSize = 12
inviteButton.Text = "Invite"
inviteButton.Parent = inviteRow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inviteButton
end
inviteButton.MouseButton1Click:Connect(function()
    local name = inviteBox.Text
    if #name > 0 then
        InviteUser:FireServer({ username = name })
        inviteBox.Text = ""
    end
end)

local noticeLabel = Instance.new("TextLabel")
noticeLabel.Name = "AccessNotice"
noticeLabel.LayoutOrder = 85
noticeLabel.Size = UDim2.new(1, 0, 0, 16)
noticeLabel.BackgroundTransparency = 1
noticeLabel.TextColor3 = GOLD
noticeLabel.Font = Enum.Font.Gotham
noticeLabel.TextSize = 11
noticeLabel.TextXAlignment = Enum.TextXAlignment.Left
noticeLabel.Text = ""
noticeLabel.Visible = false
noticeLabel.Parent = scroll

-- invitee list (shown only in private mode)
local inviteeContainer = Instance.new("Frame")
inviteeContainer.Name = "Invitees"
inviteeContainer.LayoutOrder = 86
inviteeContainer.Size = UDim2.fromScale(1, 0)
inviteeContainer.AutomaticSize = Enum.AutomaticSize.Y
inviteeContainer.BackgroundTransparency = 1
inviteeContainer.BorderSizePixel = 0
inviteeContainer.Visible = false
inviteeContainer.Parent = scroll
local inviteeLayout = Instance.new("UIListLayout")
inviteeLayout.FillDirection = Enum.FillDirection.Vertical
inviteeLayout.Padding = UDim.new(0, 4)
inviteeLayout.SortOrder = Enum.SortOrder.LayoutOrder
inviteeLayout.Parent = inviteeContainer

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

local function renderFavorites(favorites: { string }, names: { [string]: string })
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
        label.Text = names[siteId] or siteId -- item C: real displayName, echoed from the server
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

local function renderAccess()
    for mode, button in accessModeButtons do
        local selected = access.mode == mode
        button.TextColor3 = if selected then GOLD else TEXT
        button.BackgroundTransparency = if selected then 0 else 0.1
    end
    local isPrivate = access.mode == "private"
    inviteRow.Visible = isPrivate
    inviteeContainer.Visible = isPrivate
    noticeLabel.Visible = accessNotice ~= nil
    noticeLabel.Text = accessNotice or ""

    for _, child in inviteeContainer:GetChildren() do
        if child ~= inviteeLayout then
            child:Destroy()
        end
    end
    if isPrivate then
        for i, entry in access.invited do
            local row = Instance.new("Frame")
            row.Name = "Invitee_" .. tostring(entry.userId)
            row.LayoutOrder = i
            row.Size = UDim2.new(1, 0, 0, 22)
            row.BackgroundTransparency = 1
            row.Parent = inviteeContainer
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -28, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = TEXT
            label.Font = Enum.Font.Gotham
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = entry.name
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
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 4)
            c.Parent = remove
            local uid = entry.userId
            remove.MouseButton1Click:Connect(function()
                RevokeUser:FireServer({ userId = uid })
            end)
        end
    end
end

local function render()
    -- item E: nothing to render safely until the first EconomyState echo lands; show one
    -- loading line and hide the ladder rows instead of their default-visible bare S/M/L buttons.
    if not catalogReady() then
        headerLabel.Text = "Loading..."
        loadingLabel.Visible = true
        deckSection.Visible = false
        deckRow.Visible = false
        teaSection.Visible = false
        teaRow.Visible = false
        return
    end
    loadingLabel.Visible = false
    deckSection.Visible = true
    deckRow.Visible = true
    teaSection.Visible = true
    teaRow.Visible = true

    local vm = MenuModel.viewModel(econ)

    local perchText = if econ.claimedPadId ~= nil
        then `Perch: {econ.claimedPadId}`
        else "No perch claimed yet"
    headerLabel.Text = `{vm.points} pts  ·  {perchText}`

    claimNotice.Visible = not vm.ownsDeck
    needsClaimHint.Visible = vm.needsClaim
    renderLadder(deckWidgets, vm.deckLadder, "deck", not vm.ownsDeck)
    renderLadder(teaWidgets, vm.teahouseLadder, "teahouse", false)

    deckDisplayRow.Visible = vm.ownsTeahouse
    teaDisplayRow.Visible = vm.ownsTeahouse
    if vm.ownsTeahouse then
        renderDisplayOptions(deckDisplayWidgets, vm.deckDisplayOptions)
        renderDisplayOptions(teaDisplayWidgets, vm.teahouseDisplayOptions)
    end
    shownSmallerHint.Visible = vm.deckShownSmaller or vm.teahouseShownSmaller

    -- B4 Task 5: same enabled/disabled coloring as renderDisplayOptions' enabled/disabled branches.
    currentCanMove = vm.canMove
    moveButton.Visible = vm.ownsTeahouse
    moveButton.Active = vm.canMove
    moveButton.TextColor3 = if vm.canMove then TEXT else DIM

    -- Task 5: same enabled/disabled coloring idiom as moveButton above.
    currentPortalCanBuy = vm.portal.canBuy
    portalButton.Visible = vm.ownsDeck
    portalButton.Active = vm.portal.canBuy
    portalButton.Text = if vm.portal.owned then "Home Portal ✓" else `Home Portal — {vm.portal.price} pts`
    portalButton.TextColor3 = if vm.portal.canBuy then TEXT else DIM

    ensureDecorButtons(vm)
    for _, d in vm.decorations do
        local button = decorButtons[d.propId]
        if button then
            local label = DECOR_LABELS[d.propId] or d.propId
            local priceText = if d.price ~= nil then `{d.price} pts` else "—"
            button.Text = `  {label} — {priceText}`
            button.Active = d.canBuy
            button.TextColor3 = if d.canBuy then TEXT else DIM
        end
    end
    decorContainer.Visible = vm.ownsDeck

    renderAccess()
    accessModeRow.Visible = vm.ownsDeck
    if not vm.ownsDeck then
        inviteRow.Visible = false
        inviteeContainer.Visible = false
        noticeLabel.Visible = false
    end

    renderFavorites(vm.favorites, favoriteNames)

    backDoorLabel.Text = if backDoorIndex ~= nil
        then `Back door: bay {backDoorIndex}`
        else "Back door: none set"
end

-- ===== Step 4: echo wiring =====

EconomyState.OnClientEvent:Connect(function(p)
    ready = true
    econ.totalPoints = p.totalPoints
    econ.maxDeckSize = p.maxDeckSize
    econ.teahouseSizes = p.teahouseSizes or {}
    econ.claimedPadId = p.claimedPadId
    econ.claimed = p.claimedPadId ~= nil
    econ.deckDisplay = p.deckDisplay
    econ.teahouseDisplay = p.teahouseDisplay
    -- item G: the server is authoritative -- every echo (including the post-SetDisplay one)
    -- reconciles `desired` back to what actually landed.
    desired.deckDisplay = p.deckDisplay
    desired.teahouseDisplay = p.teahouseDisplay
    if p.catalog then
        econ.catalog = p.catalog
    end
    econ.portalOwned = p.portalOwned == true
    econ.deckDecorations = p.deckDecorations or {}
    render()
end)

PreferenceState.OnClientEvent:Connect(function(p)
    econ.padPreferences = p.padPreferences or {}
    favoriteNames = p.names or {} -- item C
    render()
end)

BackDoorState.OnClientEvent:Connect(function(p)
    backDoorIndex = p.backDoorIndex
    render()
end)

AccessState.OnClientEvent:Connect(function(p)
    if typeof(p) ~= "table" then
        return
    end
    access.mode = p.mode or "public"
    access.invited = p.invited or {}
    accessNotice = p.notice
    render()
end)

-- ===== Step 5: open / close =====

-- A flag again, now that this panel is a takeover: `Takeover.acquire`/`release` are
-- reference-counted, so a double open must not double-acquire and a double close must not drive
-- the count negative (which would leave the OTHER takeover holder's release hand back control it
-- never suspended). Guarding on the current state makes every remaining caller's `setOpen(false)`
-- a no-op when the panel is already closed, rather than a spurious release.
local isOpen = false
local function setOpen(shouldOpen: boolean)
    if shouldOpen == isOpen then
        return -- idempotent: a double open must not double-acquire, a double close must not double-release
    end
    if shouldOpen then
        -- ORDER MATTERS, the same as LedgerController's open(): paint first, flag and show
        -- second, freeze LAST. render() runs inside a Bindable connection, so a throw in there
        -- is swallowed to a warn -- flagging isOpen before it returns would leave the panel
        -- visible with isOpen = true and no matching acquire, so a later close() would perform
        -- an unmatched release.
        render()
        isOpen = true
        panel.Visible = true
        closeButton.Visible = true
        scrim.Visible = true
        Takeover.acquire()
    else
        -- isOpen flips false BEFORE the release, so a respawn mid-release cannot re-freeze
        -- behind us (the same ordering as LedgerController's close()).
        isOpen = false
        panel.Visible = false
        closeButton.Visible = false
        scrim.Visible = false
        Takeover.release()
    end
end

-- The ledger's MY TEAHOUSE button. It closes ITSELF before firing this (see LedgerController), so
-- the two takeover surfaces are never up together and the ledger's movement suspension is always
-- lifted on the way through. Nothing else opens this panel: the world prompts (claim, back-door,
-- favourite-add) belong to EconomyController/BackDoorController/PerchPreferenceController and put up
-- their own UI, never this one.
EventBus.OpenTeahouse.Event:Connect(function()
    setOpen(true)
end)

-- Three doors sharing one path, same as the ledger: the ✕, a tap on the scrim, and Escape. A
-- takeover that suspends movement needs more than one way out.
closeButton.MouseButton1Click:Connect(function()
    setOpen(false)
end)

scrim.MouseButton1Click:Connect(function()
    setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input)
    -- gameProcessedEvent is deliberately NOT consulted -- see LedgerController's identical
    -- handler. Escape is claimed by the Roblox menu, and a panel that only closes when Roblox
    -- does not want the key is a panel that strands people.
    if isOpen and input.KeyCode == Enum.KeyCode.Escape then
        setOpen(false)
    end
end)

-- B4 Task 5: Task 6 (not yet built) consumes EventBus.MoveTeahouse.Event to start move mode.
moveButton.MouseButton1Click:Connect(function()
    if not currentCanMove or econ.claimedPadId == nil then
        return
    end
    setOpen(false) -- reuse the panel's existing open/close mechanism
    EventBus.MoveTeahouse:Fire({ padId = econ.claimedPadId })
end)

portalButton.MouseButton1Click:Connect(function()
    if currentPortalCanBuy then
        RequestPurchase:FireServer({ item = "portal" })
    end
end)
