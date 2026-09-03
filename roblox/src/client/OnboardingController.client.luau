--!strict
-- Onboarding beats — bones, not a tutorial (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md
-- § Onboarding). The owner narrates in person when new players first join; these four cards exist
-- only for what a live narrator cannot always cover.
--
-- Each beat is fired by the EVENT IT EXPLAINS, never queued at join — main.client.luau fires
-- `EventBus.Onboard:Fire(event, seenBeats)` the first time join/throwsUnlocked/win/bank actually
-- happens, and `seenBeats` is the profile's current list (piggybacked on the same channel rather
-- than adding a second one just to seed this file). This module RENDERS `OnboardingBeats`; it
-- never decides which beat fires — `OnboardingBeats.next(seenLocal, event)` does.
--
-- ONE CARD AT A TIME. If a second event fires while a card is up, it is DROPPED, not queued —
-- `currentBeat ~= nil` is the only guard this needs, because a stack of cards is a tutorial.
--
-- Dismissal marks the beat seen LOCALLY first (`table.insert(seenLocal, beat.id)`), then fires
-- the write on `EventBus.HudPreference` → the same `SetHudPreference` remote Task 12's preference
-- switch uses — never a second remote. Marking locally before the round trip lands is what stops
-- a re-fire of the same beat if another qualifying event arrives in the same session.
--
-- WHETHER A CARD ACTUALLY RENDERED IS REPORTED BACK on `EventBus.OnboardShown:Fire(event, outcome)`,
-- outcome one of "shown" | "alreadySeen" | "dropped". main.client.luau does not decide for itself
-- whether the beat "happened" — it fires Onboard on every natural occurrence of the event and only
-- stops once told "shown" or "alreadySeen". A round-1 review caught the bug this exists to prevent:
-- latching on FIRE rather than on SHOWN meant a beat dropped for stacking (e.g. the player banks
-- their first pot without dismissing the still-up "win" card) was marked consumed forever, and the
-- player was told nothing — the toast had already been suppressed on the assumption the card would
-- cover it. "dropped" is the one outcome that must NOT be latched: the caller is expected to retry
-- on the next natural occurrence of that event (next round's throwsUnlocked, the next win, etc).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local OnboardingBeats = require(shared:WaitForChild("OnboardingBeats"))
local TourGuide = require(shared:WaitForChild("TourGuide"))
local HudLayout = require(shared:WaitForChild("HudLayout"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The ZenDojo HUD palette, as in HudController/LedgerController. Duplicated rather than shared:
-- there is no palette module yet, and inventing one for a third file is not worth a fourth require.
local WASHI = Color3.fromRGB(26, 24, 28)
local GOLD = Color3.fromRGB(212, 176, 102)
-- Gate 2026-08-02: "the onboarding messages are too dark to read." The card was 8% transparent over
-- a dusk canyon, its copy sat on INK_CREAM (240, 234, 216) and its hint on GOLD at 20% text
-- transparency at 11px. The fix is CONTRAST, not size: an opaque backing, near-white copy carrying
-- its own washi keyline (so it survives whatever the card happens to be sitting over), and a hint
-- that is still smaller and still gold — visibly a hint — but fully opaque and a point larger.
local CARD_COPY = Color3.fromRGB(252, 249, 242)
local CARD_HINT = Color3.fromRGB(238, 208, 142)

-- Layout constants come from shared/HudLayout, the SAME module HudController lays itself out from.
-- A card's whole job is to sit beside what HudController placed, so it has to agree with those
-- numbers exactly, not approximate them — these used to be hand-copied here (including a
-- hand-computed `AREA_H = 120`), which meant a tweak to BTN_H would move the cluster while this
-- file's safe band went on believing the old height.
--
-- THE TIER MUST MATCH HudController'S. It shrinks the throw cluster on touch (gate 2026-08-02), and
-- the safe band below is the only thing standing between a card and BANK THESE — so the SAME
-- `TouchEnabled and not KeyboardEnabled` switch picks the SAME variant here. Detection lives in the
-- controllers because HudLayout holds no Roblox globals; the numbers live there because these two
-- files have to agree on them exactly.
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local JUMP_CLEARANCE = HudLayout.JUMP_CLEARANCE
-- The bank button's row, directly above the throw cluster — the same numbers HudController's own
-- bank button reads. Declared here, above STATIC_ANCHORS, because that table reads them.
local BANK_GAP = HudLayout.BANK_GAP

-- `CLUSTER_TOP_FROM_BOTTOM` is where the bank+throws+tape cluster's footprint begins, measured up
-- from the screen's bottom edge (mirrors HudController's own EDGE / AREA_H / BANK_H numbers, now
-- shared). Round-2 review caught that this band was built but never actually applied to the
-- NOT-YET-TRACKED fallback — only to a live projection — leaving the exact same "card covers
-- BANK n POINTS" failure mode reachable through a slower path (join fires on the first
-- RoundUpdate, which can beat the drum's replication).
local CLUSTER_TOP_FROM_BOTTOM = if TOUCH
    then HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH
    else HudLayout.CLUSTER_TOP_FROM_BOTTOM

local CARD_W = 220
local DRUM_CARD_W = 220

-- ===== Card: one TextButton (the dismiss target) + two non-Active labels =====
-- The ONLY interactive element in this file. Everything else inside it stays non-Active (labels
-- default to false; never set true) so the one button is the whole interactive budget this
-- surface spends — consistent with HudController's "every sinking pixel is a permanent hole in
-- the camera-drag surface" discipline.
-- ONE COORDINATE SPACE, and it is this ScreenGui's own. Like HudController's, this gui leaves
-- IgnoreGuiInset at its default FALSE, so its (0, 0) sits BELOW the topbar inset (~36px) — which is
-- what lets the static anchors below reuse HudController's numbers directly. Camera:ViewportSize and
-- Camera:WorldToViewportPoint, by contrast, are RAW full-screen values that include the inset band.
-- Mixing the two (round-3 review) put the drum bubble ~36px low AND made the safe band's maxY ~36px
-- too permissive, so a card could still overlap the top of the throw/slot cluster despite
-- SAFE_MARGIN. Everything below is in GUI SPACE: `guiCanvas()` converts, and nothing here reads the
-- camera's viewport directly.
local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboOnboarding"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10 -- above the minimal HUD (0), below the ledger takeover (20)
-- ⚠ EXPLICIT, NEVER DEFAULTED (parked defect (d)'s true cause, found 2026-09-05): this place's
-- ScreenGuis come up ZIndexBehavior.GLOBAL, where `card.ZIndex = 5` ranked the card's OPAQUE
-- washi background above its own default-ZIndex labels -- every onboarding card rendered as an
-- empty box, and the round-2 opacity fix is what completed the burial (at 8% transparency the
-- entombed text still ghosted through, which is the "unreadable" that round tried to cure).
-- Sibling renders children above their parent, which is the only sane semantics here.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local card = Instance.new("TextButton")
card.Name = "Card"
card.BackgroundColor3 = WASHI
-- OPAQUE. A card is read once and dismissed; it does not need to show the canyon through itself,
-- and 8% of a dusk gorge behind 16px text is what made it unreadable.
card.BackgroundTransparency = 0
card.BorderSizePixel = 0
card.AutoButtonColor = false
card.Text = ""
card.Size = UDim2.fromOffset(CARD_W, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.Visible = false
card.ZIndex = 5
card.Parent = gui
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = card
    local s = Instance.new("UIStroke")
    s.Color = GOLD
    s.Thickness = 2
    s.Transparency = 0.1 -- a crisper edge: the card has to read as an object, not a smudge
    s.Parent = card
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = card
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.Parent = card
end

local copyLabel = Instance.new("TextLabel")
copyLabel.Name = "Copy"
copyLabel.Active = false
copyLabel.LayoutOrder = 1
copyLabel.BackgroundTransparency = 1
copyLabel.Size = UDim2.fromScale(1, 0)
copyLabel.AutomaticSize = Enum.AutomaticSize.Y
copyLabel.TextWrapped = true
copyLabel.TextColor3 = CARD_COPY
copyLabel.TextSize = 17
copyLabel.Font = Enum.Font.GothamBold
copyLabel.TextXAlignment = Enum.TextXAlignment.Left
copyLabel.Text = ""
copyLabel.Parent = card
-- NO UIStroke ON THE COPY. A stroke parented to a TextLabel outlines every GLYPH: at 2px on
-- 17px type the outline approaches the stem width, the counters in a/e/o fill in, and adjacent
-- glyphs merge into a smear. That is what made these cards unreadable. The card's backing is
-- already opaque WASHI under near-white copy (~16.7:1) and needs no help.

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Active = false
hintLabel.LayoutOrder = 2
hintLabel.BackgroundTransparency = 1
hintLabel.Size = UDim2.new(1, 0, 0, 16)
hintLabel.TextColor3 = CARD_HINT
hintLabel.TextTransparency = 0 -- a hint is SMALLER, not fainter; 11px gold at 20% faded was neither
hintLabel.TextSize = 12
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Text = "TAP TO DISMISS"
hintLabel.Parent = card

-- ===== Anchors =====
-- `OnboardingBeats` names four anchors: `drum`, `throwArea`, `potIndicator`, `wallet`. Three are
-- static offsets from a screen edge, matching where HudController actually put the thing they
-- point at. `drum` is the one exception — the drum is a real object in the world
-- (`Workspace.RoshamboStage.ThrowDrum.Drum`, see DrumController), so it is tracked live via
-- `WorldToViewportPoint` rather than guessed at a fixed screen fraction.
--
-- Nothing here ever covers the throw buttons, the bank button, the ring or the tape —
-- ALL THREE sit ABOVE the whole bank+throws+tape cluster (offset clears its full footprint via
-- CLUSTER_TOP_FROM_BOTTOM + BANK_GAP, the same derivation HudController's own stack is built from).
--
-- `wallet` does NOT try to hug the actual plate (right-anchored, immediately left of the tape,
-- `HudController.client.luau:264`): the plate is hidden by default, so pointing at it precisely
-- buys nothing, and every attempt to get closer moves the card toward a control. round-3 review
-- caught a worse bug from the same instinct — a first draft anchored `wallet` bottom-LEFT to sit
-- "level with" the plate's row, reasoning that the cluster's own column was clear over there. It
-- was: `Workspace`'s throw cluster never reaches the left side of the screen. But
-- `HudController.client.luau:5` claims that corner for something this file never checks against —
-- "bottom-left: the movement thumbstick. Untouchable." — so the card sat on top of it for as long
-- as it was up, on touch, on the near-universal first-bank beat. THE RULE THAT WAS MISSING: a card
-- must clear the corners ROBLOX owns, not just the ones this HUD uses. `wallet` gets the exact
-- same placement as `throwArea`/`potIndicator` instead — proven safe at any card height and both
-- tiers, because `AutomaticSize.Y` grows the card upward, away from everything below it.
local STATIC_ANCHORS: { [string]: { point: Vector2, offset: UDim2, width: number } } = {
    -- All three sit above the WHOLE bottom-right cluster — tape+buttons AND the bank row above
    -- them — not just above the tape. The bank row is reserved whether or not its button is
    -- currently Visible (HudController never repositions it, only toggles it), so a card that only
    -- cleared the tape would sit inside the bank row's footprint. That is harmless while there is
    -- no pot, but a card can outlive its dismiss window into a WIN (the bank button can turn on
    -- WHILE this card is still up — beats do not queue, but a real, un-dismissed card does not
    -- disappear just because a later event was dropped) and BANK n POINTS is a live button
    -- underneath: an overlap there would both hide it and steal its taps, being ZIndex 5 above the
    -- HUD's default. All three share one offset on purpose — none are ever shown at once, so
    -- sharing the spot is a non-issue, and it is one fewer number to keep in step.
    throwArea = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
        width = CARD_W,
    },
    potIndicator = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
        width = CARD_W,
    },
    wallet = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
        width = CARD_W,
    },
    tour = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
        width = CARD_W,
    },
}
-- Last-resort ONLY: used when there is no `workspace.CurrentCamera` at all to clamp against
-- (should not happen in a live game — Roblox always has a camera once a character exists — but a
-- card that cannot find one must still show SOMEWHERE rather than nowhere). Every other path
-- below runs through the same safe band, including the fallback while the drum has never been
-- tracked, so this literal is never reachable in ordinary play.
local DRUM_LAST_RESORT = { point = Vector2.new(0.5, 0), offset = UDim2.new(0.5, 0, 0, 140) }

-- The band the minimal HUD does NOT own, in GUI SPACE (this ScreenGui's own; Y grows downward, and
-- the topbar inset is already excluded — see `guiCanvas`). Round-1 review caught that clamping only
-- to the viewport edges was not enough: the join card is the first thing a new player sees, stays
-- up until tapped, and the camera is theirs to swing for as long as it's up — so the drum can
-- project anywhere, including straight over the throw buttons or the toast. `TOAST_BAND` is a
-- reservation for the toast (spec §2, 2026-08-03: the plate left the top of the screen entirely,
-- so the toast — which sits at `EDGE` and grows downward with `AutomaticSize` — is the only thing
-- left up there for a card to clear); it is a reservation, not a measurement, because a card
-- landing on a transient notice would hide exactly the line explaining what just happened.
local TOAST_BAND = 64
local SAFE_MARGIN = 24 -- round-2: was 16, widened to also give the toast strip more clearance
local DRUM_BUBBLE_LIFT = 36 -- vertical gap between the projected point and the card's bottom edge
local MIN_CARD_H = 90 -- floor for AbsoluteSize.Y before AutomaticSize has laid out even once —
-- round-2: was 60, under the card's real ~80-90px, so the very first place() under-clamped by a
-- frame or two

-- The card's canvas, in GUI SPACE: the size of the area this ScreenGui actually lays out in, and
-- the offset that converts a raw viewport point into it. With IgnoreGuiInset false the gui's canvas
-- is the viewport MINUS the topbar inset at the top, so the two differ by exactly that inset — the
-- ~36px that used to be unaccounted for on both the projection and the bottom bound.
--
-- `gui.AbsoluteSize` is the canvas by definition, so it is preferred; it can read (0, 0) before the
-- first layout pass, in which case the viewport minus the inset is the same number computed the
-- long way.
local function guiCanvas(): (Vector2, Vector2)
    -- GetGuiInset returns (topLeft, bottomRight); only the topLeft one is wanted here. The
    -- bottom-right inset is 0 on every platform this ships to, and the fallback below is a
    -- one-frame stand-in for AbsoluteSize rather than a layout anyone measures against.
    local inset = GuiService:GetGuiInset()
    local size = gui.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then
        local cam = workspace.CurrentCamera
        local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
        size = Vector2.new(vp.X - inset.X, vp.Y - inset.Y)
    end
    return size, inset
end

-- The same clamp band `place()` uses for a live projection, factored out so the NOT-YET-TRACKED
-- fallback (drum unresolved, or off-camera and never once seen) runs through it too rather than
-- reusing an unclamped fixed position. `canvas` is GUI SPACE (see `guiCanvas`), never the raw
-- viewport: measuring maxY against the taller viewport made it a topbar-inset too permissive, which
-- is enough for a card to sit on top of the throw/slot cluster despite SAFE_MARGIN.
local function safeYBounds(canvas: Vector2): (number, number)
    local cardH = math.max(card.AbsoluteSize.Y, MIN_CARD_H)
    -- PRIORITY: when the band cannot fit the card, the cluster wins and the toast loses. `maxY`
    -- is pinned to the cluster's top edge unconditionally; `minY` yields toward it (never past it,
    -- via math.min) rather than the old shape (`maxY` yielding toward `minY` via math.max), which
    -- kept `math.clamp` from erroring but let the card's bottom edge sink into the cluster's own
    -- footprint once `cardH` grew past what the band could hold — covering a transient toast is
    -- recoverable, covering a live button is not. `minY` is now derived FROM `maxY`, so it can
    -- never exceed it and `math.clamp(_, minY, maxY)` below still cannot invert.
    local maxY = canvas.Y - CLUSTER_TOP_FROM_BOTTOM - SAFE_MARGIN
    local minY = math.min(maxY, TOAST_BAND + SAFE_MARGIN + cardH)
    return minY, maxY
end

-- Resolved defensively (10s timeout, never yields the whole script) — the physical prop is
-- Rojo-managed map content and should already exist, but a card that cannot find it must fall
-- back rather than error the whole controller.
local drumPart: BasePart? = nil
task.spawn(function()
    local stage = workspace:WaitForChild("RoshamboStage", 10)
    if not stage then
        return
    end
    local rig = stage:WaitForChild("ThrowDrum", 10)
    if not rig then
        return
    end
    drumPart = rig:WaitForChild("Drum", 10) :: BasePart?
end)

local drumHeartbeat: RBXScriptConnection? = nil
-- Set true the first time `place()` gets a real on-screen projection. Kept ACROSS calls (not
-- reset when tracking stops) so a card shown a second time in the same session — should
-- OnboardingBeats ever return more than one "drum"-anchored beat — does not replay the
-- never-tracked-yet fallback.
local drumEverTracked = false

local function stopTrackingDrum()
    if drumHeartbeat then
        drumHeartbeat:Disconnect()
        drumHeartbeat = nil
    end
end

-- Live-tracks the drum's screen position as a speech-bubble sitting just above it. Two rules on
-- top of "stay inside the viewport", both added after round-1 review:
--   1. The clamp band is the HUD's DEAD ZONE, not the raw viewport — below the toast's reserved
--      band and above the bank+throws+tape cluster's — and it accounts for the CARD'S OWN measured
--      height (AnchorPoint is (0.5, 1), so `y` is the card's BOTTOM edge; the card's top is
--      `y - height`, and that is the edge that must clear the toast). A card that only avoided
--      screen edges could still land squarely on a live button.
--   2. Off-screen (or not-yet-resolved) does not teleport to the fixed fallback every frame while
--      the drum happens to be behind the camera — it HOLDS the last good clamped position. Only
--      before the very first successful projection does it show the fallback at all, so the card
--      is never simply missing; once it has a real position, it never snaps away from one.
--
-- Round-2 review found a third case the first two hadn't covered: NOT-YET-TRACKED is reachable in
-- ordinary play — `join` fires on the very first RoundUpdate, which can beat the
-- RoshamboStage → ThrowDrum → Drum replication chain `drumPart` waits on — and until round-1's
-- fix, that path used `DRUM_LAST_RESORT` UNCLAMPED, so the exact failure Important 2 named (the
-- card covering BANK THESE / the fate prompt) was still reachable through a slower door. There is
-- now exactly one place a card can appear un-safe-banded: no camera at all, which does not happen
-- in a live game.
local function place()
    local cam = workspace.CurrentCamera
    if not cam then
        if not drumEverTracked then
            card.AnchorPoint = DRUM_LAST_RESORT.point
            card.Position = DRUM_LAST_RESORT.offset
        end
        return
    end
    local canvas, inset = guiCanvas()
    local at = drumPart
    if at then
        local screen, onScreen = cam:WorldToViewportPoint(at.Position)
        if onScreen then
            -- Raw viewport -> gui space. WorldToViewportPoint knows nothing about the topbar; this
            -- card's Position is interpreted inside a gui that does. Subtracting the inset is what
            -- makes the bubble land ON the drum rather than an inset below it.
            local px, py = screen.X - inset.X, screen.Y - inset.Y
            local minY, maxY = safeYBounds(canvas)
            local half = DRUM_CARD_W * 0.5 + 8
            local x = math.clamp(px, half, math.max(half, canvas.X - half))
            local y = math.clamp(py - DRUM_BUBBLE_LIFT, minY, maxY)
            card.AnchorPoint = Vector2.new(0.5, 1) -- bubble ABOVE the projected point
            card.Position = UDim2.fromOffset(x, y)
            drumEverTracked = true
            return
        end
    end
    if not drumEverTracked then
        -- Not yet resolved, or resolved but off-camera and never once seen: still safe-banded and
        -- horizontally centred, sitting at the TOP of the band (closest to the toast, since that is
        -- the more natural resting spot for "the arena is live" than hugging the throw cluster).
        local minY = safeYBounds(canvas)
        card.AnchorPoint = Vector2.new(0.5, 1)
        card.Position = UDim2.fromOffset(canvas.X * 0.5, minY)
    end
    -- else: hold whatever position was last set — do not teleport to the fallback and back as the
    -- camera swings the drum in and out of view.
end

local function trackDrum()
    place()
    drumHeartbeat = RunService.Heartbeat:Connect(place)
end

local function positionCard(beat: any)
    if beat.anchor == "drum" then
        card.Size = UDim2.fromOffset(DRUM_CARD_W, 0)
        trackDrum()
        return
    end
    -- An anchor OnboardingBeats names that this file does not recognise still deserves a visible,
    -- dismissable card rather than one silently mispositioned at (0, 0) — fall back to `throwArea`,
    -- which sits above the whole cluster and is always a safe, on-screen, non-covering spot.
    local a = STATIC_ANCHORS[beat.anchor] or STATIC_ANCHORS.throwArea
    card.Size = UDim2.fromOffset(a.width, 0)
    card.AnchorPoint = a.point
    card.Position = a.offset
end

-- ===== Show / dismiss =====
local currentBeat: any = nil

-- Union of the profile's server-known seenBeats (refreshed with every Onboard fire — see below)
-- and this session's own optimistic dismissals. Never shrinks.
local seenLocal: { string } = {}

local function broadcastTourStep()
    EventBus.TourStep:Fire(TourGuide.step(seenLocal))
end

local function adoptServerSeen(list: { string }?)
    if type(list) ~= "table" then
        return
    end
    for _, id in list do
        local already = false
        for _, have in seenLocal do
            if have == id then
                already = true
                break
            end
        end
        if not already then
            -- seenLocal is the re-fire guard `OnboardingBeats.next` reads, so an unbounded
            -- duplicate here is not just clutter: it grows every session for as long as the
            -- player stays connected, for no benefit (membership, not count, is all `next` uses).
            table.insert(seenLocal, id)
        end
    end
    broadcastTourStep()
end

local function hideCard()
    stopTrackingDrum()
    card.Visible = false
    currentBeat = nil
end

local currentPage = 1

local function showCard(beat: any)
    currentBeat = beat
    currentPage = 1
    copyLabel.Text = if beat.pages then beat.pages[1] else beat.copy
    positionCard(beat)
    card.Visible = true
end

local function dismiss()
    local beat = currentBeat
    if not beat then
        return
    end
    -- The welcome's pages: a tap turns the page; only the LAST page's tap dismisses. seenLocal
    -- is marked once, after the last page, so a guest who quits mid-welcome sees it again.
    if beat.pages and currentPage < #beat.pages then
        currentPage += 1
        copyLabel.Text = beat.pages[currentPage]
        return
    end
    -- Optimistic: stops a re-fire before the round trip lands. The write rides the SAME remote
    -- Task 12's preference switch uses — SetHudPreference — never a second one.
    table.insert(seenLocal, beat.id)
    EventBus.HudPreference:Fire({ seenBeat = beat.id })
    hideCard()
    broadcastTourStep()
    if beat.id == "bank" then
        -- The tour's front door (spec §2): dismissing the bank card is the moment the guest
        -- stands there holding spendable points. BindableEvents are deferred, so this fires
        -- AFTER currentBeat is nil — the handler below can show shopDoor immediately.
        EventBus.Onboard:Fire("bankDismissed", nil)
    end
end

card.MouseButton1Click:Connect(dismiss)

EventBus.Onboard.Event:Connect(function(event: string, serverSeenBeats: { string }?)
    adoptServerSeen(serverSeenBeats)
    if currentBeat then
        if currentBeat.advanceOn == event then
            -- A tour event arriving while its predecessor's card is still up: the guest has
            -- plainly DONE the thing the card was asking, so the card's job is over. Dismiss it
            -- (marking it seen, exactly as a tap would) and fall through to show this event's
            -- own beat. Without this, the event would report "dropped" and — for one-shot
            -- events like the only shell's launch — never come again, stranding the tour.
            table.insert(seenLocal, currentBeat.id)
            EventBus.HudPreference:Fire({ seenBeat = currentBeat.id })
            hideCard()
            broadcastTourStep()
        else
            -- NEVER STACK. A second event while a card is up is dropped, not queued — these
            -- are bones, and a stack of cards is a tutorial.
            EventBus.OnboardShown:Fire(event, "dropped")
            return
        end
    end
    local beat = OnboardingBeats.next(seenLocal, event)
    if beat then
        showCard(beat)
        EventBus.OnboardShown:Fire(event, "shown")
        -- F5: the beam must not lag the card it goes with. Seen ids are marked at DISMISSAL, so
        -- deriving the step from `seenLocal` alone would still point the beam at the PREVIOUS
        -- stop for as long as this card is up (load-bearing on the MODEL leg: modelArrival can't
        -- fire until modelDoor is dismissed, so a guest who just walks there without tapping the
        -- card would never see the beam move and never get beat 8). Broadcast the step as though
        -- the showing card were already seen — a throwaway copy, never mutating `seenLocal` — so
        -- the card's words and the beam agree while the card is up; dismissal (broadcastTourStep
        -- above, in `dismiss`/advance-through) then makes the same derivation permanent.
        local seenWithShown = table.clone(seenLocal)
        table.insert(seenWithShown, beat.id)
        EventBus.TourStep:Fire(TourGuide.step(seenWithShown))
    else
        -- Nothing to show — not because of stacking, but because this beat is already in
        -- seenLocal (a prior session, or an earlier occurrence this one). Also NOT a reason to
        -- retry: it will never show again.
        EventBus.OnboardShown:Fire(event, "alreadySeen")
    end
end)

-- Fired once at startup so TourBeamController hears an initial step even before the first
-- Onboard fire (e.g. a returning player rejoining mid-tour).
broadcastTourStep()
