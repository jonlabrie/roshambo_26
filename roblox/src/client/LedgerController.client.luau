--!strict
-- Maximal — "the ledger" (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md § Maximal).
--
-- Explicitly NOT social and NOT ambient. This is a MODE, not a HUD state: it takes over the screen
-- and it is allowed to. Everything else in the play UI is the quiet hangout HUD; this is the half a
-- player opens on purpose to study their own numbers.
--
-- ENTRY is a tap on the round-timer RING, bottom row of the minimal HUD (HudController fires
-- EventBus.OpenLedger from the ring's click handler) — the ring's SECOND tap, the first only
-- reveals the wallet plate; see HudController's own header for the two-stage gesture. The plate
-- is a SECOND door onto the same event whenever it is showing (its own `MouseButton1Click`,
-- guarded on `plateVisible`), so the ledger has two doors, never a third.
--
-- Both doors carry a gesture that used to live on a single `≡` hamburger button — deleted (spec
-- §6): Roblox's own unibar already owns that glyph top-left, so a second one bottom-right read as
-- either the same menu or a broken copy of it. The ring inherited the gesture instead, and the
-- plate — once inert display-only chrome — became tappable again once it left the strip Roblox
-- uses for camera drag.
--
-- AND THE LEDGER IS ITSELF A DOOR. The teahouse panel's own persistent bottom-right toggle collided
-- with the throw row on a narrow viewport, so it is gone and MY TEAHOUSE in this header replaces it
-- (EventBus.OpenTeahouse) — the same principle applied once more: one persistent entry point, and
-- everything else reached through it.
--
-- ACTIVE DISCIPLINE, the takeover carve-out. The minimal HUD's rule is that no information element
-- may be Active, because every sinking pixel is a permanent hole in the camera-drag surface. A
-- takeover mode is the exception: the scrim and the panel SINK INPUT ON PURPOSE (see `panel.Active`
-- below — without it a tap on the panel would fall through to the scrim and close the thing the
-- player is reading). Inside the panel, pure labels stay non-Active, which is their default.
--
-- WHAT MATTERS INSTEAD is that maximal is never left open by accident, because MOVEMENT IS
-- SUSPENDED WHILE IT IS OPEN. See `close()`: every exit path routes through one function.
--
-- This file RENDERS LedgerModel; it computes nothing the model already gives it. main.client.luau
-- owns the wiring and fires EventBus.LedgerState{ counters, live, bestStreak, escalationPrompts,
-- resultSplash }. The preference switches travel back on EventBus.HudPreference, banking on
-- EventBus.HudBank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("RoshamboShared")
local LedgerModel = require(sharedFolder:WaitForChild("LedgerModel"))
local GameRules = require(sharedFolder:WaitForChild("GameRules"))
local Glyphs = require(sharedFolder:WaitForChild("Glyphs"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))
local Takeover = require(script.Parent:WaitForChild("Takeover"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The ZenDojo HUD palette, as in HudController. Duplicated rather than shared: there is no palette
-- module yet, and inventing one for two files is not worth a third require.
local INK = Color3.fromRGB(60, 45, 28)
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local TAN_RIM = Color3.fromRGB(176, 164, 138)
local GOLD = Color3.fromRGB(212, 176, 102)
local WASHI = Color3.fromRGB(26, 24, 28)
local WASHI_CARD = Color3.fromRGB(36, 33, 38)
local WIN_GREEN = Color3.fromRGB(86, 196, 120)
local LOSS_RED = Color3.fromRGB(206, 86, 86)
local POT_RED = Color3.fromRGB(190, 58, 52)
local TRACK = Color3.fromRGB(56, 52, 58)

local THROWS = { "R", "P", "S" }

local PAD = 14
local GAP = 12
local HEADER_H = 52
local HERO_H = 96
local FOOTER_H = 46 -- two switches; the row was sized for more than one from the start
local TABS_H = 30
local BAR_H = 14
local FEED_MAX = 60

-- Three columns is a LANDSCAPE-TABLET layout. On a landscape phone the columns get too narrow to
-- read, so the feed collapses to a tab and the two statistic cards share the width. This threshold
-- is a placeholder on purpose: Task 15's device-emulator sweep settles the real number, and
-- hand-tuning it against a desktop viewport now would only bake in a wrong one.
local NARROW_PX = 900

-- ===== Movement suspension =====
-- Extracted to Takeover.luau (a reference-counted module shared with the teahouse panel) so a
-- second copy of the hardened suspend/restore logic can't diverge from this one, and so the two
-- takeovers can't restore a freeze the other applied. See that module for the mechanism.
local isOpen = false

-- ===== Panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboLedger"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20 -- above RoshamboHud: a takeover sits on top of what it takes over
gui.Enabled = false
gui.Parent = playerGui

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency
    s.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font): TextLabel
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.fromScale(1, 1)
    l.TextColor3 = color
    l.TextSize = size
    l.Font = font
    l.Text = text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- Tap outside the panel closes. A TextButton is the catcher, and it blackens the world behind —
-- which is what a takeover is.
local scrim = Instance.new("TextButton")
scrim.Name = "Scrim"
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrim.BackgroundTransparency = 0.35
scrim.BorderSizePixel = 0
scrim.AutoButtonColor = false
scrim.Text = ""
scrim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
-- Active = true, deliberately. A Frame that is not Active does not consume input, so every tap
-- inside the panel would fall through to the scrim behind it and close the panel.
panel.Active = true
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.94, 0.94)
panel.BackgroundColor3 = WASHI
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
-- NOTHING LEAVES THE PANEL. The body's height is whatever is left after the header, hero, tabs and
-- preferences footer have taken theirs, and on a short landscape phone that is a few dozen pixels —
-- less than the cards' content. Without this the overflow drew straight through the footer and out
-- past the panel's own outline, over the scrim and the world behind it. The cards scroll their
-- content (see makeCard); this is the backstop that makes the panel's edge mean something.
panel.ClipsDescendants = true
panel.Parent = gui
corner(panel, 10)
stroke(panel, GOLD, 1, 0.4)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, PAD)
    pad.PaddingRight = UDim.new(0, PAD)
    pad.PaddingTop = UDim.new(0, PAD)
    pad.PaddingBottom = UDim.new(0, PAD)
    pad.Parent = panel
end

-- ===== Header =====
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundTransparency = 1
header.Parent = panel

-- The header's right end is the navigation end: the ✕ out, and beside it the one door onward.
local CLOSE_W = 44
local TEA_W = 160
local NAV_W = CLOSE_W + 8 + TEA_W + 8 -- what the title/note must keep clear of

local title = label(header, "THE LEDGER", 24, INK_CREAM, Enum.Font.GothamBlack)
title.Size = UDim2.new(1, -NAV_W, 0, 26)

local suspendNote = label(header, "MOVEMENT SUSPENDED WHILE OPEN", 13, GOLD, Enum.Font.GothamBold)
suspendNote.Position = UDim2.fromOffset(0, 28)
suspendNote.Size = UDim2.new(1, -NAV_W, 0, 16)
suspendNote.TextTransparency = 0.15

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.fromScale(1, 0)
closeButton.Size = UDim2.fromOffset(CLOSE_W, CLOSE_W)
closeButton.BackgroundColor3 = WASHI_CARD
closeButton.BackgroundTransparency = 0.1
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = false
closeButton.TextColor3 = INK_CREAM
closeButton.TextSize = 26
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.Parent = header
corner(closeButton, 8)
stroke(closeButton, TAN_RIM, 1, 0.4)

-- ===== MY TEAHOUSE: the door that used to be a persistent corner toggle =====
-- The teahouse panel carried its own 140x40 button pinned to the bottom-right corner. On a narrow
-- viewport its left edge crossed under the HUD's scissors button (the throw row is held inboard by a
-- FRACTION of the width, so the two clear each other on a desktop and collide on a phone), and it
-- cost a permanent hole in the camera-drag surface every second of every session for a panel opened
-- rarely. The ledger is its door now — the design's own rule, applied once more: one persistent
-- entry point, everything else reached through it.
--
-- WHY THE HEADER AND NOT THE PREFERENCES FOOTER. The footer's two switches already span
-- 2 x PREF_COL_W = 472px, which leaves no third column at phone width, so the alternative was a
-- second footer row — and that costs the BODY 48px. The body is the squeezed dimension on exactly
-- the tier this design targets: on a landscape phone it is 68-83px today, and a second row takes it
-- to 20-35px, a window smaller than one statistic. The header is free at every size, cannot crowd
-- the switches at all, and puts "go somewhere else" beside the ✕ where navigation belongs.
local teahouseButton = Instance.new("TextButton")
teahouseButton.Name = "MyTeahouse"
teahouseButton.AnchorPoint = Vector2.new(1, 0)
teahouseButton.Position = UDim2.new(1, -(CLOSE_W + 8), 0, 0)
teahouseButton.Size = UDim2.fromOffset(TEA_W, CLOSE_W) -- square with the ✕: one touch-target height
teahouseButton.BackgroundColor3 = WASHI_CARD
teahouseButton.BackgroundTransparency = 0.1
teahouseButton.BorderSizePixel = 0
teahouseButton.AutoButtonColor = false
teahouseButton.TextColor3 = INK_CREAM
teahouseButton.TextSize = 15
teahouseButton.Font = Enum.Font.GothamBold
teahouseButton.Text = "MY TEAHOUSE"
teahouseButton.Parent = header
corner(teahouseButton, 8)
stroke(teahouseButton, GOLD, 1, 0.35)

-- ===== Hero band =====
local hero = Instance.new("Frame")
hero.Name = "Hero"
hero.Position = UDim2.fromOffset(0, HEADER_H)
hero.Size = UDim2.new(1, 0, 0, HERO_H)
hero.BackgroundColor3 = WASHI_CARD
hero.BackgroundTransparency = 0.15
hero.BorderSizePixel = 0
hero.Parent = panel
corner(hero, 8)
stroke(hero, TAN_RIM, 1, 0.55)

local HERO_CELLS = {
    { key = "streak", caption = "STREAK" },
    { key = "pot", caption = "POT" },
    { key = "points", caption = "POINTS" },
}
local heroValue: { [string]: TextLabel } = {}
for i, cell in HERO_CELLS do
    local holder = Instance.new("Frame")
    holder.Name = cell.caption
    holder.Position = UDim2.fromOffset(PAD + (i - 1) * 118, 12)
    holder.Size = UDim2.fromOffset(110, 56)
    holder.BackgroundTransparency = 1
    holder.Parent = hero

    local caption = label(holder, cell.caption, 11, GOLD, Enum.Font.GothamBold)
    caption.Size = UDim2.new(1, 0, 0, 13)
    caption.TextTransparency = 0.2

    local value = label(holder, "0", 30, INK_CREAM, Enum.Font.GothamBlack)
    value.Position = UDim2.fromOffset(0, 15)
    value.Size = UDim2.new(1, 0, 0, 34)
    heroValue[cell.key] = value
end

-- The number minimal cannot afford: the whole bank-or-ride decision as one figure. It comes from
-- LedgerModel, which is handed the real GameRules — a hardcoded x3 here would lie the day the pot
-- progression changes.
local paysLine = label(hero, "A WIN HERE PAYS 1", 17, INK_CREAM, Enum.Font.GothamBold)
paysLine.AnchorPoint = Vector2.new(0, 1)
paysLine.Position = UDim2.new(0, PAD, 1, -10)
paysLine.Size = UDim2.new(1, -(2 * PAD + 160), 0, 20)

-- BANK THESE lives here too, so a player who opened the ledger to THINK about the decision is not
-- forced to close it to MAKE it. There is no RISK counterpart anywhere in this design: riding is
-- throwing again, and no button needs to say so.
local bankButton = Instance.new("TextButton")
bankButton.Name = "BankThese"
bankButton.AnchorPoint = Vector2.new(1, 0.5)
bankButton.Position = UDim2.new(1, -PAD, 0.5, 0)
bankButton.Size = UDim2.fromOffset(150, 44)
bankButton.BackgroundColor3 = POT_RED
bankButton.BackgroundTransparency = 0.05
bankButton.BorderSizePixel = 0
bankButton.AutoButtonColor = false
bankButton.TextColor3 = INK_CREAM
bankButton.TextSize = 16
bankButton.Font = Enum.Font.GothamBold
bankButton.Text = "BANK THESE"
bankButton.Visible = false
bankButton.Parent = hero
corner(bankButton, 6)
stroke(bankButton, GOLD, 1, 0.3)

-- ===== Body: three cards, or two plus a tab when the screen is narrow =====
local BODY_TOP = HEADER_H + HERO_H + GAP

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.Position = UDim2.fromOffset(0, BODY_TOP)
tabs.Size = UDim2.new(1, 0, 0, TABS_H)
tabs.BackgroundTransparency = 1
tabs.Visible = false
tabs.Parent = panel

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Parent = panel

-- Height of a card's heading strip: the 14px label plus the gap under it. Content starts below.
local CARD_HEADING_H = 20

-- Every card is heading + a SCROLLING body. The bodies are fixed-offset stacks (the lifetime card's
-- rows, bar and legend run to ~200px), and the body band they sit in is whatever the panel has left
-- over — on a 375px-tall landscape phone, well under that. Clipping alone would silently truncate
-- the last rows, so the content scrolls: the figures are all still reachable, on the smallest screen
-- this design targets, without a breakpoint deciding which ones a player is allowed to see.
--
-- A ScrollingFrame is NOT given `.Active`. It drags to scroll on its own, and the minimal HUD's
-- interactive budget is already spent — the takeover's one carve-out is `panel.Active` above.
local function makeCard(name: string, heading: string): (Frame, Frame, ScrollingFrame)
    local holder = Instance.new("Frame")
    holder.Name = name .. "Holder"
    holder.BackgroundTransparency = 1
    holder.Parent = body

    local card = Instance.new("Frame")
    card.Name = name
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.new(1, -GAP, 1, 0)
    card.BackgroundColor3 = WASHI_CARD
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = holder
    corner(card, 8)
    stroke(card, TAN_RIM, 1, 0.55)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, PAD)
    pad.PaddingRight = UDim.new(0, PAD)
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = card

    local title2 = label(card, heading, 12, GOLD, Enum.Font.GothamBold)
    title2.Size = UDim2.new(1, 0, 0, 14)
    title2.TextTransparency = 0.15

    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Position = UDim2.fromOffset(0, CARD_HEADING_H)
    content.Size = UDim2.new(1, 0, 1, -CARD_HEADING_H)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageColor3 = TAN_RIM
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    -- Callers building fixed-offset content set this to the height they laid out; the feed sets
    -- AutomaticCanvasSize instead, because its content grows a line at a time.
    content.CanvasSize = UDim2.new()
    content.Parent = card

    return holder, card, content
end

-- --- Lifetime ---
local lifetimeHolder, _, lifetimeBody = makeCard("Lifetime", "LIFETIME")

-- All offsets below are relative to the card's SCROLLING BODY, not to the card.
local LIFETIME_TOP = 4
local LIFETIME_ROW_H = 30

local LIFETIME_ROWS = {
    { key = "banked", caption = "BANKED" },
    { key = "rounds", caption = "ROUNDS THROWN" },
    { key = "winRate", caption = "WIN RATE" },
    { key = "bestStreak", caption = "BEST STREAK" },
    { key = "bestPot", caption = "BIGGEST POT" },
}
local lifetimeValue: { [string]: TextLabel } = {}
for i, row in LIFETIME_ROWS do
    local holder = Instance.new("Frame")
    holder.Name = row.key
    holder.Position = UDim2.fromOffset(0, LIFETIME_TOP + (i - 1) * LIFETIME_ROW_H)
    holder.Size = UDim2.new(1, -6, 0, 26) -- -6: clear of the scrollbar
    holder.BackgroundTransparency = 1
    holder.Parent = lifetimeBody

    local caption = label(holder, row.caption, 12, INK_CREAM, Enum.Font.Gotham)
    caption.Size = UDim2.fromScale(0.6, 1)
    caption.TextTransparency = 0.35

    local value = label(holder, "0", 18, INK_CREAM, Enum.Font.GothamBold)
    value.Position = UDim2.fromScale(0.6, 0)
    value.Size = UDim2.fromScale(0.4, 1)
    value.TextXAlignment = Enum.TextXAlignment.Right
    lifetimeValue[row.key] = value
end

-- WIN/SAFE/LOSS bar. The three segments come from LedgerModel's largest-remainder apportionment and
-- sum to exactly 100, so laying them end to end by scale leaves NO GAP and no overrun — which is
-- why the model does that arithmetic and this file does none of it.
local BAR_TOP = LIFETIME_TOP + #LIFETIME_ROWS * LIFETIME_ROW_H + 8

local barTrack = Instance.new("Frame")
barTrack.Name = "Bar"
barTrack.Position = UDim2.fromOffset(0, BAR_TOP)
barTrack.Size = UDim2.new(1, -6, 0, BAR_H)
barTrack.BackgroundColor3 = TRACK
barTrack.BorderSizePixel = 0
barTrack.ClipsDescendants = true
barTrack.Parent = lifetimeBody
corner(barTrack, 4)

local function barSegment(name: string, color: Color3): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.Size = UDim2.fromScale(0, 1)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.Parent = barTrack
    return f
end

local winSeg = barSegment("Win", WIN_GREEN)
local safeSeg = barSegment("Safe", GOLD)
local lossSeg = barSegment("Loss", LOSS_RED)

local LEGEND_TOP = BAR_TOP + BAR_H + 5
local LEGEND_H = 14

local barLegend = label(lifetimeBody, "", 11, INK_CREAM, Enum.Font.Gotham)
barLegend.Position = UDim2.fromOffset(0, LEGEND_TOP)
barLegend.Size = UDim2.new(1, -6, 0, LEGEND_H)
barLegend.TextTransparency = 0.3

-- The card's laid-out height, stated once rather than guessed: this is what makes the body scroll
-- instead of overflowing when the panel gives it less room than this.
lifetimeBody.CanvasSize = UDim2.fromOffset(0, LEGEND_TOP + LEGEND_H + 4)

-- --- Your throws ---
-- The only statistic that says something about the PLAYER rather than about their score. Glyphs,
-- never a text character: the real assets are what every other surface in the canyon renders.
local throwsHolder, _, throwsBody = makeCard("YourThrows", "YOUR THROWS")

local MIX_TOP = 8
local MIX_ROW_H = 46

type MixRow = { fill: Frame, pct: TextLabel, count: TextLabel }
local mixRows: { [string]: MixRow } = {}
for i, sym in THROWS do
    local row = Instance.new("Frame")
    row.Name = sym
    row.Position = UDim2.fromOffset(0, MIX_TOP + (i - 1) * MIX_ROW_H)
    row.Size = UDim2.new(1, -6, 0, 38) -- -6: clear of the scrollbar
    row.BackgroundTransparency = 1
    row.Parent = throwsBody

    local box = Instance.new("Frame")
    box.Name = "GlyphBox"
    box.Position = UDim2.fromOffset(0, 4)
    box.Size = UDim2.fromOffset(30, 30)
    box.BackgroundTransparency = 1
    box.Parent = row
    Glyphs.render(box, sym, GOLD, INK)

    local count = label(row, "0 thrown", 12, INK_CREAM, Enum.Font.Gotham)
    count.Position = UDim2.fromOffset(38, 2)
    count.Size = UDim2.new(1, -38, 0, 14)
    count.TextTransparency = 0.35

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Position = UDim2.fromOffset(38, 20)
    track.Size = UDim2.new(1, -84, 0, BAR_H)
    track.BackgroundColor3 = TRACK
    track.BorderSizePixel = 0
    track.ClipsDescendants = true
    track.Parent = row
    corner(track, 4)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = GOLD
    fill.BorderSizePixel = 0
    fill.Parent = track

    local pct = label(row, "0%", 14, INK_CREAM, Enum.Font.GothamBold)
    pct.AnchorPoint = Vector2.new(1, 0)
    pct.Position = UDim2.new(1, 0, 0, 18)
    pct.Size = UDim2.fromOffset(42, 18)
    pct.TextXAlignment = Enum.TextXAlignment.Right

    mixRows[sym] = { fill = fill, pct = pct, count = count }
end
throwsBody.CanvasSize = UDim2.fromOffset(0, MIX_TOP + #THROWS * MIX_ROW_H)

-- --- Feed ---
-- PERSONAL ONLY in v1: the player's own results and banks, which is data this client already
-- receives. Social lines ("kaz_9 banked 243") need a server-side event stream and belong to a later
-- item — inventing one here would be inventing data.
local feedHolder, _, feed = makeCard("Feed", "FEED")

-- The one card whose content is not a fixed layout: it grows a line at a time, so its canvas is
-- measured rather than stated.
feed.AutomaticCanvasSize = Enum.AutomaticSize.Y
do
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.Parent = feed
end

local feedSeq = 0
local feedEntries: { Instance } = {}

local function pushFeed(line: string)
    if typeof(line) ~= "string" or line == "" then
        return
    end
    feedSeq += 1

    local entry = Instance.new("TextLabel")
    entry.Name = `E{feedSeq}`
    entry.LayoutOrder = -feedSeq -- newest first, without renumbering the whole list
    entry.Size = UDim2.new(1, -8, 0, 16)
    entry.AutomaticSize = Enum.AutomaticSize.Y
    entry.BackgroundTransparency = 1
    entry.TextColor3 = INK_CREAM
    entry.TextSize = 13
    entry.TextWrapped = true
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.Font = Enum.Font.Gotham
    entry.Text = `{os.date("%H:%M")}  {line}`
    entry.Parent = feed

    table.insert(feedEntries, entry)
    if #feedEntries > FEED_MAX then
        local oldest = table.remove(feedEntries, 1)
        if oldest then
            oldest:Destroy()
        end
    end
end

-- The spec's "where the ticker went": transient toasts in minimal, full scrollback in maximal. The
-- scrollback IS the toast stream, recorded whether or not the panel is open.
EventBus.Toast.Event:Connect(pushFeed)
EventBus.TickerMessage.Event:Connect(pushFeed)

-- ===== Preferences footer =====
-- One row, now TWO switches — the row was built and sized for exactly this, and the result-splash
-- preference is the second one the design was waiting for. Both are built by the same factory rather
-- than copied, so a third cannot drift into looking or behaving differently from the first two.
local footer = Instance.new("Frame")
footer.Name = "Preferences"
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.fromScale(0, 1)
footer.Size = UDim2.new(1, 0, 0, FOOTER_H)
footer.BackgroundTransparency = 1
footer.Parent = panel

local SWITCH_W, SWITCH_H = 58, 28
local SWITCH_KNOB = 22
local PREF_LABEL_W = 140
local PREF_COL_W = PREF_LABEL_W + 10 + SWITCH_W + 28 -- label + gap + switch + breathing room

type PrefSwitch = { button: TextButton, knob: Frame }

local function makePrefSwitch(name: string, caption: string, column: number): PrefSwitch
    local x = column * PREF_COL_W

    local prefLabel = label(footer, caption, 14, INK_CREAM, Enum.Font.Gotham)
    prefLabel.Name = name .. "Label"
    prefLabel.AnchorPoint = Vector2.new(0, 0.5)
    prefLabel.Position = UDim2.new(0, x, 0.5, 0)
    prefLabel.Size = UDim2.fromOffset(PREF_LABEL_W, 18)

    local switch = Instance.new("TextButton")
    switch.Name = name
    switch.AnchorPoint = Vector2.new(0, 0.5)
    switch.Position = UDim2.new(0, x + PREF_LABEL_W + 10, 0.5, 0)
    switch.Size = UDim2.fromOffset(SWITCH_W, SWITCH_H)
    switch.BackgroundColor3 = TRACK
    switch.BorderSizePixel = 0
    switch.AutoButtonColor = false
    switch.Text = ""
    switch.Parent = footer
    corner(switch, SWITCH_H // 2)
    stroke(switch, TAN_RIM, 1, 0.5)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.Size = UDim2.fromOffset(SWITCH_KNOB, SWITCH_KNOB)
    knob.BackgroundColor3 = INK_CREAM
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, SWITCH_KNOB // 2)

    return { button = switch, knob = knob }
end

local escalationSwitch = makePrefSwitch("EscalationPrompts", "Escalation prompts", 0)
local resultSplashSwitch = makePrefSwitch("ResultSplash", "Result splash", 1)

-- ===== Layout =====
local feedTabOpen = false

local function place(holder: Frame, xScale: number, wScale: number)
    holder.Position = UDim2.fromScale(xScale, 0)
    holder.Size = UDim2.fromScale(wScale, 1)
end

local function makeTab(name: string): TextButton
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -4, 1, 0)
    b.BackgroundColor3 = WASHI_CARD
    b.BackgroundTransparency = 0.15
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.TextColor3 = INK_CREAM
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.Name = name
    b.Text = name
    b.Parent = tabs
    corner(b, 6)
    return b
end

local statsTab = makeTab("STATS")
local feedTab = makeTab("FEED")
feedTab.Position = UDim2.new(0.5, 4, 0, 0)

-- The camera's viewport, not the panel's AbsoluteSize: a disabled ScreenGui has not laid out yet, so
-- AbsoluteSize is 0 until the frame after the first open and would read as the narrowest tier.
local function viewportWidth(): number
    local cam = workspace.CurrentCamera
    return if cam then cam.ViewportSize.X else NARROW_PX
end

local function applyLayout()
    local narrow = viewportWidth() < NARROW_PX
    tabs.Visible = narrow

    local top = BODY_TOP + (if narrow then TABS_H + 8 else 0)
    body.Position = UDim2.fromOffset(0, top)
    body.Size = UDim2.new(1, 0, 1, -(top + FOOTER_H + GAP))

    if narrow then
        -- The feed becomes a tab rather than a third column: at phone width three columns are too
        -- narrow to read, and the feed is the one block that is scrollback rather than figures.
        lifetimeHolder.Visible = not feedTabOpen
        throwsHolder.Visible = not feedTabOpen
        feedHolder.Visible = feedTabOpen
        place(lifetimeHolder, 0, 0.5)
        place(throwsHolder, 0.5, 0.5)
        place(feedHolder, 0, 1)
        statsTab.BackgroundTransparency = if feedTabOpen then 0.6 else 0.15
        feedTab.BackgroundTransparency = if feedTabOpen then 0.15 else 0.6
    else
        lifetimeHolder.Visible = true
        throwsHolder.Visible = true
        feedHolder.Visible = true
        place(lifetimeHolder, 0, 1 / 3)
        place(throwsHolder, 1 / 3, 1 / 3)
        place(feedHolder, 2 / 3, 1 / 3)
    end
end

statsTab.MouseButton1Click:Connect(function()
    feedTabOpen = false
    applyLayout()
end)
feedTab.MouseButton1Click:Connect(function()
    feedTabOpen = true
    applyLayout()
end)
do
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
    end
end
applyLayout()

-- ===== State =====
local counters = {
    roundsPlayed = 0,
    wins = 0,
    safes = 0,
    losses = 0,
    lifetimeBanked = 0,
    bestPot = 0,
    throwsR = 0,
    throwsP = 0,
    throwsS = 0,
}
local live = { pot = 0, streak = 0, points = 0 }
local bestStreak = 0
local escalationPrompts = true
local resultSplash = true

local function paintOne(sw: PrefSwitch, on: boolean)
    sw.button.BackgroundColor3 = if on then GOLD else TRACK
    sw.knob.Position = if on then UDim2.new(1, -(SWITCH_KNOB + 3), 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
end

local function paintSwitch()
    paintOne(escalationSwitch, escalationPrompts)
    paintOne(resultSplashSwitch, resultSplash)
end

local function render()
    local view = LedgerModel.view(counters, live, GameRules)

    heroValue.streak.Text = tostring(view.live.streak)
    heroValue.pot.Text = tostring(view.live.pot)
    heroValue.points.Text = tostring(view.live.points)
    paysLine.Text = `A WIN HERE PAYS {view.paysNext}`
    bankButton.Visible = view.live.pot > 0

    lifetimeValue.banked.Text = tostring(view.lifetime.lifetimeBanked)
    lifetimeValue.rounds.Text = tostring(view.lifetime.roundsPlayed)
    lifetimeValue.winRate.Text = `{view.winRatePct}%`
    lifetimeValue.bestStreak.Text = tostring(bestStreak)
    lifetimeValue.bestPot.Text = tostring(view.lifetime.bestPot)

    winSeg.Position = UDim2.fromScale(0, 0)
    winSeg.Size = UDim2.fromScale(view.bar.win / 100, 1)
    safeSeg.Position = UDim2.fromScale(view.bar.win / 100, 0)
    safeSeg.Size = UDim2.fromScale(view.bar.safe / 100, 1)
    lossSeg.Position = UDim2.fromScale((view.bar.win + view.bar.safe) / 100, 0)
    lossSeg.Size = UDim2.fromScale(view.bar.loss / 100, 1)
    barLegend.Text = `WIN {view.bar.win}%  ·  SAFE {view.bar.safe}%  ·  LOSS {view.bar.loss}%`

    mixRows.R.fill.Size = UDim2.fromScale(view.mix.R / 100, 1)
    mixRows.P.fill.Size = UDim2.fromScale(view.mix.P / 100, 1)
    mixRows.S.fill.Size = UDim2.fromScale(view.mix.S / 100, 1)
    mixRows.R.pct.Text = `{view.mix.R}%`
    mixRows.P.pct.Text = `{view.mix.P}%`
    mixRows.S.pct.Text = `{view.mix.S}%`
    mixRows.R.count.Text = `{view.lifetime.throwsR} thrown`
    mixRows.P.count.Text = `{view.lifetime.throwsP} thrown`
    mixRows.S.count.Text = `{view.lifetime.throwsS} thrown`

    paintSwitch()
end

-- ===== Open / close =====
-- ORDER MATTERS. Paint first, show second, freeze LAST. If anything in the render threw, an
-- open() that had already suspended would leave a frozen player looking at no panel — no ✕ to
-- press, and on touch no Escape either. Freezing only once the panel is on screen means the way
-- out always exists by the time the legs are gone.
local function open()
    if isOpen then
        return
    end
    applyLayout()
    render()
    gui.Enabled = true
    isOpen = true
    Takeover.acquire()
end

-- THE ONLY WAY OUT. The X, a tap on the scrim and Escape all route here, so a fourth exit path added
-- later cannot forget to give the player their legs back. A ledger that leaves someone frozen on a
-- canyon ledge is worse than no ledger at all.
local function close()
    if not isOpen then
        return
    end
    isOpen = false -- before the release, so a respawn mid-release cannot re-freeze behind us
    gui.Enabled = false
    Takeover.release()
end

EventBus.OpenLedger.Event:Connect(open)
closeButton.MouseButton1Click:Connect(close)
scrim.MouseButton1Click:Connect(close)
UserInputService.InputBegan:Connect(function(input)
    -- gameProcessedEvent is deliberately NOT consulted. Escape is claimed by the Roblox menu, and a
    -- panel that only closes when Roblox does not want the key is a panel that strands people.
    if isOpen and input.KeyCode == Enum.KeyCode.Escape then
        close()
    end
end)

bankButton.MouseButton1Click:Connect(function()
    EventBus.HudBank:Fire()
end)

-- THE LEDGER CLOSES FIRST, AND IT CLOSES THROUGH close(). Two takeover surfaces at once is bad on
-- its own, but the reason this is not merely tidy is that the ledger SUSPENDS MOVEMENT: opening the
-- teahouse panel over a still-open ledger would leave a player reading it with no legs and no ✕ in
-- reach. Routing through the one exit is what hands them back.
teahouseButton.MouseButton1Click:Connect(function()
    close()
    EventBus.OpenTeahouse:Fire()
end)

-- Optimistic: the switch moves on the tap. The next ProfileUpdate echo reconciles it, so a write
-- that does not land flips back rather than leaving the player poking a dead control.
escalationSwitch.button.MouseButton1Click:Connect(function()
    escalationPrompts = not escalationPrompts
    paintSwitch()
    EventBus.HudPreference:Fire({ escalationPrompts = escalationPrompts })
end)

resultSplashSwitch.button.MouseButton1Click:Connect(function()
    resultSplash = not resultSplash
    paintSwitch()
    EventBus.HudPreference:Fire({ resultSplash = resultSplash })
end)

EventBus.LedgerState.Event:Connect(function(state)
    if state.counters then
        counters = state.counters
    end
    if state.live then
        live = state.live
    end
    bestStreak = state.bestStreak or bestStreak
    if type(state.escalationPrompts) == "boolean" then
        escalationPrompts = state.escalationPrompts
    end
    if type(state.resultSplash) == "boolean" then
        resultSplash = state.resultSplash
    end
    if isOpen then
        render()
    end
end)
