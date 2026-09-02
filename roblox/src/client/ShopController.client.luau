--!strict
-- THE SHOP COUNTER. Opens when you step inside 花火屋, closes when you leave, and renders exactly
-- what the server sent — prices from EconomyState.catalog, counts from FireworkState.
--
-- IT EVALUATES NO REQUIREMENT. What a shell needs in order to fire is the server's verdict, and it
-- arrives whole (`launchable` + `reason`); this file only turns the symbol into copy. The mortar
-- ladder is the one place a rule is not on the wire, and even there the only client knowledge is
-- MORTAR_ORDER — presentation order, AND (be honest about it) the one place this client does
-- duplicate a server rule: it dims a tier whose predecessor is unowned, which restates
-- economy.ts's linear-tier predicate. It is in sync today and it FAILS CLOSED — a drift dims a
-- purchase that would have worked, and the server re-validates every tap regardless. The clean
-- fix is a server-computed mortarStates on the wire, mirroring shellStates; until then this is a
-- known, bounded copy, not a rule the client invented. Do not let this comment read as innocent.
-- codebase has a named, recurring defect where a number authoritative on the server is re-derived
-- client-side and goes stale; nothing here re-derives one. The one rule that genuinely lives here
-- is geometric — am I inside the box — and even that is in a tested module.
--
-- NOTHING HERE IS TESTED. No harness in this repo loads a `.client.luau`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local ShopThreshold = require(shared:WaitForChild("ShopThreshold"))
local ShellDisplay = require(shared:WaitForChild("ShellDisplay"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local FireworkState = remotes:WaitForChild("FireworkState") :: RemoteEvent
local RequestSync = remotes:WaitForChild("RequestSync") :: RemoteEvent
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent

-- Display names/order moved to shared/ShellDisplay.luau (2026-09-04): the kiku shipped
-- server-side and silently missed this counter, because these tables were hardcoded here
-- with nothing holding them to the fixture. ShellDisplay's spec now does.
local SHELL_ORDER = ShellDisplay.ORDER
local SHELL_NAME = ShellDisplay.NAME
-- Presentation order, and the ONLY thing this file knows about mortars beyond their names. It is
-- not the tier rule — the rule (you must own the tier below) lives on the server. What the order
-- buys us is the ability to NAME the tier the server would have demanded, so a row the server would
-- reject says which mortar it is waiting on instead of failing mutely when tapped.
local MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }
local MORTAR_NAME: { [string]: string } = {
    ["mortar:S"] = "Small mortar",
    ["mortar:M"] = "Medium mortar",
    ["mortar:L"] = "Large mortar",
}
-- The tier immediately below each mortar, derived once from the order above.
local MORTAR_BELOW: { [string]: string } = {}
for i = 2, #MORTAR_ORDER do
    MORTAR_BELOW[MORTAR_ORDER[i]] = MORTAR_ORDER[i - 1]
end

-- Shell reasons arrive as symbols from the server (FireworkState.shells[id].reason) and are turned
-- into copy HERE — the same contract HudController's picker uses, and for the same reason: an
-- unmapped symbol falls back to itself, because a player who sees "NEEDS_MORTAR_XL" learns
-- something and a player who sees a blank row learns nothing.
local REASON_COPY: { [string]: string } = {
    NEEDS_MORTAR_S = "needs a small mortar",
    NEEDS_MORTAR_M = "needs a medium mortar",
    NEEDS_MORTAR_L = "needs a large mortar",
    WAITING_FOR_R = "fires after Rock",
    BAD_SHELL = "unavailable",
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
local sawFireworkState = false -- the pull loop at the bottom retries RequestSync until this flips
local ownedMortars: { [string]: boolean } = {}

-- ===== the panel =====
local gui = Instance.new("ScreenGui")
gui.Name = "ShopPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- ZIndexBehavior defaults to Global, under which a child does NOT draw above its parent.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- ===== the way out =====
-- The panel is centred, and a first-person player's cursor is PINNED to screen centre — on top of
-- it. The close button cannot be pressed and the scroll that would zoom back out is eaten by the
-- panel under the cursor, so walking out was the only escape. Shift-lock does the same thing in
-- third person, so zooming the player out would not have covered it either.
--
-- FREE THE CURSOR; LEAVE THE CAMERA ALONE. An earlier attempt also forced the player out to third
-- person by raising CameraMinZoomDistance. It worked, and it was wrong: it took the camera away
-- from someone who had chosen first person, to solve a problem that is not about the camera.
-- Measured with the camera PINNED in first person, the override alone gives MouseBehavior=Default,
-- MouseIconEnabled=true, and the close button topmost under the cursor — which is everything the
-- player needs. The camera is theirs; while the panel is open it simply stops turning.
--
-- The write has to be LATE. The camera module sets MouseBehavior during its own render step, so
-- anything written before that is overwritten before the engine reads it. Bound one priority
-- after the camera, the cursor stays free — and reverts the frame this unbinds.
--
-- Not `Player.DevEnableMouseLock`, which looks like the switch for the shift-lock half and IS NOT
-- SETTABLE FROM A LOCALSCRIPT: it throws "Insufficent permissions", and because it threw
-- mid-function it silently took the rest of the open path with it.
local CURSOR_BIND = "ShopPanelCursor"
local CURSOR_PRIORITY = Enum.RenderPriority.Camera.Value + 1

-- Not a nicety: BindToRenderStep on an already-bound name replaces it quietly, but Unbind on a
-- name that was never bound throws — and that throw would land in the middle of closing the panel.
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

-- THE ONLY PLACE gui.Enabled IS WRITTEN. The cursor grip has to be paired with it exactly, and a
-- second writer is how a pairing comes apart: a panel closed without releasing would leave the
-- camera unable to turn for the rest of the session, with nothing on screen to explain why.
local function setOpen(open: boolean)
    if open then
        gripCursor()
    else
        releaseCursor()
    end
    gui.Enabled = open
end

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

-- A WAY OUT. The panel opened on entering the shop and closed only on LEAVING it, so a player who
-- wanted to look around inside was stuck behind it — an interface with no dismiss reads as a bug
-- even when it is doing exactly what it was told. Walking out still closes it; this is the other
-- way, and it is the one you reach for while standing at the counter.
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
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.Parent = panel
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = closeButton
end

-- Dismissed for THIS visit only. Cleared on leaving the volume, so stepping back in re-opens the
-- shop rather than leaving a player who dismissed it once unable to buy anything ever again.
local dismissed = false
closeButton.MouseButton1Click:Connect(function()
    dismissed = true
    setOpen(false)
end)

local balance = Instance.new("TextLabel")
balance.Size = UDim2.new(1, -20, 0, 18)
balance.Position = UDim2.fromOffset(10, 40)
balance.BackgroundTransparency = 1
balance.TextColor3 = DIM
balance.Font = Enum.Font.Code
balance.TextSize = 13
balance.TextXAlignment = Enum.TextXAlignment.Left
balance.Parent = panel

-- A ScrollingFrame, because the shelf outgrew the panel at 8 shells + 3 mortars
-- (owner, 2026-09-06: "I can't get to the kamuro to select it") and the catalog is
-- DESIGNED to keep growing -- shell taxonomy is a first-class goal. The canvas sizes
-- itself; new rows just make it taller.
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -70)
list.Position = UDim2.fromOffset(10, 64)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
-- ⚠ THE CANVAS NEEDS ITS WIDTH STATED. Scale-sized children measure against the
-- CANVAS, not the frame — with CanvasSize zero and automatic sizing on Y only, the
-- canvas was 0 wide and every row rendered 0px (owner, 2026-09-06: "menus doesn't
-- show on entering the shop"). Width = the frame's own, minus scrollbar room.
list.CanvasSize = UDim2.new(1, -8, 0, 0)
-- selene: allow(incorrect_standard_library_use) -- selene 0.31's Roblox std predates AutomaticCanvasSize.Y; the enum is real
list.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = DIM
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = list

-- `live` and `priceKnown` are written by paint() and read by the click handler. They are the row's
-- rendered state, not a judgement made at click time — the button does exactly what it looks like
-- it will do.
type Row = {
    button: TextButton,
    title: TextLabel,
    sub: TextLabel,
    item: string,
    live: boolean,
    priceKnown: boolean,
}
local rows: { Row } = {}

local function makeRow(order: number, item: string, label: string): Row
    local b = Instance.new("TextButton")
    b.LayoutOrder = order
    b.Size = UDim2.new(1, 0, 0, 38) -- full canvas width; the canvas already clears the scrollbar
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

    local row: Row = { button = b, title = t, sub = s, item = item, live = false, priceKnown = false }
    b.MouseButton1Click:Connect(function()
        -- A row rendered dimmed must not spend points. Without this the dimming is decoration:
        -- the tap goes through, the server rejects it, and NOTHING on screen changes — the whole
        -- shop reads as broken. The row's own label already says why it is dim.
        if not row.live then
            return
        end
        -- And a row that cannot tell you the price must never spend your points. `prices` stays
        -- empty for the whole session if the server's catalog fetch failed at join, and the
        -- balance a purchase draws against is real either way.
        if not row.priceKnown then
            return
        end
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
        local live
        if price == nil then
            -- The catalog has not arrived yet. Say so rather than showing a confident zero.
            detail = "..."
            live = false
        elseif isShell then
            -- A shell is always buyable at price; what its state adds is whether the shell you own
            -- can actually FIRE. That is the server's verdict, arriving whole as launchable+reason —
            -- this file never works it out. NONE_HELD is dropped: "you hold 0" is right there.
            local st = shells and shells[key]
            local held = st and st.count or 0
            detail = ("%d pts   you hold %d"):format(price, held)
            if st ~= nil and st.launchable ~= true and st.reason ~= nil and st.reason ~= "NONE_HELD" then
                detail ..= "   " .. (REASON_COPY[st.reason] or st.reason)
            end
            live = afford
        elseif ownedMortars[key] then
            detail = "owned"
            live = false
        else
            local below = MORTAR_BELOW[key]
            if below ~= nil and not ownedMortars[below] then
                -- The server would reject this with BAD_TIER_ORDER. Say which mortar it wants
                -- instead of lighting the row up and swallowing the failure.
                detail = ("%d pts   needs the %s first"):format(price, string.lower(MORTAR_NAME[below]))
                live = false
            else
                detail = ("%d pts"):format(price)
                live = afford
            end
        end
        row.sub.Text = detail
        row.live = live
        row.priceKnown = price ~= nil
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
    sawFireworkState = true
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
    local char = player.Character
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
        if now then
            dismissed = false -- a fresh visit always opens
            paint()
        end
        setOpen(now)
    elseif inside and not dismissed and not gui.Enabled then
        setOpen(true)
    end
end)

-- PULL UNTIL FED (live-place find, 2026-09-05: the shop showed "you hold" zeros while the HUD
-- picker was accurate). The join's one-shot FireworkState push races each listener
-- independently -- this script connects later than main.client and missed it on a live server,
-- and an idle player gets no reveal-time re-push (that push is gated on having picked). Same
-- cure as DecorationController's: fire RequestSync (server debounces at 0.4s; it now re-echoes
-- FireworkState too) until OUR listener has seen a payload.
task.spawn(function()
    while not sawFireworkState do
        RequestSync:FireServer()
        task.wait(1 + math.random() * 0.5)
    end
end)
