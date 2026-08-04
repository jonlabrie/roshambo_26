--!strict
-- Minimal play HUD — the hangout default (spec: docs/superpowers/specs/2026-08-02-play-hud-design.md).
--
-- WHY THE LAYOUT IS WHAT IT IS. Roblox has already carved up this screen:
--   bottom-left  : the movement thumbstick. Untouchable.
--   bottom-right : the jump button, roughly the right 3-13% of the screen. Untouchable.
--   top-left     : the unibar, and the CHAT WINDOW expanding down beneath it. In a hangout chat is
--                  open most of the time, so this is the worst corner on the screen, not a safe one.
--   top-right    : the player list, expanding down. (The old pick cluster lived here — the furthest
--                  reach from either thumb AND the corner the player list grows into.)
--   top-centre   : free. Roblox claims nothing there, and nothing lives there any more either.
-- Hence: THROW AREA bottom-right but INBOARD of the jump button, with the tape BELOW the buttons
-- (the buttons stay closest to where the thumb rests; the tape is read, never touched) and the
-- PLATE as one line at the bottom of that same cluster, left of the tape (see "Plate: one line
-- at the bottom of the cluster" below); the round-timer RING beside the buttons, in the
-- hamburger's old slot, competing with nothing (spec §5-§7; the bottom-edge hairline it replaced
-- is gone, and with it the reason for the cluster's old clearance from the bottom edge — see
-- EDGE_BOTTOM).
--
-- The plate briefly lived in the right margin above the jump button, measured at runtime — the
-- owner superseded that mid-implementation for the bottom row instead. Nothing in this HUD is
-- positioned against geometry Roblox owns any more.
--
-- Every information element MUST stay Active = false. Frames and labels default to false, but
-- setting it true anywhere here punches a permanent hole in the camera-drag surface, which is
-- the whole right side of the screen on touch. The whole interactive budget is: the three throw
-- buttons, the one bank button (see `setBank`), and the ledger's two doors — the ring and the
-- plate whenever it is showing (see "The round-timer ring" and the plate's own
-- `MouseButton1Click`, below).
--
-- This file RENDERS HudModel; it never re-derives it. main.client.luau owns the wiring and fires
-- EventBus.HudState(inputs, aux):
--   inputs : a HudModel.Inputs
--   aux    : { session = HudModel.Session, tape = { { worldThrow, result? } }, timerKnown = boolean,
--              worldThrow = string?, profileSeen = boolean }
--            `tape` is already spoiler-gated by the wiring — paint it as given. `worldThrow` is
--            the world's throw for the round the drum has FINISHED revealing, or nil — see
--            `render`'s glyph-swap, below. `profileSeen` is whether the wallet in `inputs` is the
--            server's answer or main.client's placeholder zeros — see `seedCounter`.
-- Picks travel back the other way on EventBus.HudPick, banking on EventBus.HudBank.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HudModel = require(shared:WaitForChild("HudModel"))
local HudLayout = require(shared:WaitForChild("HudLayout"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local RollingNumber = require(shared:WaitForChild("RollingNumber"))
local RingTimer = require(shared:WaitForChild("RingTimer"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ZenDojo HUD palette (moved here from main.client.luau, which no longer builds UI).
local INK = Color3.fromRGB(60, 45, 28)
local INK_CREAM = Color3.fromRGB(240, 234, 216)
local IVORY = Color3.fromRGB(244, 238, 222)
local IVORY_DIM = Color3.fromRGB(206, 199, 182)
local AGED_IVORY = Color3.fromRGB(146, 112, 64) -- ivory patinas warm + dark with age
local TAN_RIM = Color3.fromRGB(176, 164, 138)
local GOLD = Color3.fromRGB(212, 176, 102)
local WASHI = Color3.fromRGB(26, 24, 28)
local WIN_GREEN = Color3.fromRGB(86, 196, 120)
local LOSS_RED = Color3.fromRGB(206, 86, 86)
local SEL_BLUE = Color3.fromRGB(74, 150, 255)
local POT_RED = Color3.fromRGB(190, 58, 52) -- the pot disc; deeper than LOSS_RED so it reads as a seal

-- SELECTION PALETTE (gate 2026-08-02). The owner asked for two things that pull against each other:
-- the unchosen throws should "almost disappear", AND they should carry orange/yellow. The synthesis
-- is a WARM/COOL SPLIT: the chosen tile goes cool and LIT (a pale blue wash, a SEL_BLUE glyph, a
-- thick blue rim and a soft halo behind it), the two unchosen go warm and FAINT (a dark amber tile
-- at 0.55 transparency with an amber glyph). They recede as asked, and the hue split is what makes
-- the choice legible in one glance at arm's length on a phone — without lighting three things up.
local SEL_WASH = Color3.fromRGB(226, 238, 255) -- the chosen tile's face: ivory pulled cool
local SEL_INK = Color3.fromRGB(16, 44, 92) -- keyline under the blue glyph, so it still has an edge
local SEL_HALO = Color3.fromRGB(120, 186, 255) -- the glow behind the chosen tile
local WARM_FACE = Color3.fromRGB(104, 76, 40) -- the unchosen tiles' face: dark amber, nearly gone
local WARM_GLYPH = Color3.fromRGB(226, 158, 62) -- their glyph: orange, dim
local WARM_RIM = Color3.fromRGB(150, 108, 52)
local GLYPH_OUTLINE = Color3.new(1, 1, 1) -- the resting keyline, as Glyphs.render defaults it

local THROWS = { "R", "P", "S" }

-- The touch tier. `TouchEnabled and not KeyboardEnabled` is the Roblox convention for "a phone or
-- tablet, not a laptop with a touchscreen", and it is what Studio's device emulator sets — so the
-- shrunken cluster can be checked in Studio without a handset. The BOOLEAN is decided here; the
-- NUMBERS come from HudLayout, which OnboardingController reads from the same switch so its safe
-- band shrinks with the cluster instead of hovering over the old footprint.
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- The skeleton — every number OnboardingController also has to know, so that it can place a card
-- beside this HUD without covering a live button — lives in shared/HudLayout. SCALE, not pixels, for
-- the jump-button clearance: the jump button occupies roughly the right 3-13% of the screen, and a
-- pixel offset guessed against a desktop viewport is wrong on every phone. Numbers only this file
-- uses stay here.
local JUMP_CLEARANCE = HudLayout.JUMP_CLEARANCE
local EDGE = HudLayout.EDGE
-- The cluster's own bottom margin — deliberately a SEPARATE constant from EDGE, not a smaller
-- EDGE, even though EDGE's only other surviving read in this file is the toast's TOP offset (the
-- throw cluster/bank button/ring/plate all register horizontally off `1 - JUMP_CLEARANCE`, never
-- off EDGE — this file has no live horizontal use of EDGE to disturb). The real reason to keep
-- them separate: `HudLayout.CLUSTER_TOP_FROM_BOTTOM` and OnboardingController's static-anchor
-- band both still add `HudLayout.EDGE`, not this. Shrinking EDGE itself would drag BOTH of those
-- down TOWARD the live buttons — the unsafe direction — where this constant only ever moves the
-- cluster itself. The gap that results (`EDGE - EDGE_BOTTOM`) is a deliberate over-reservation:
-- the onboarding safe band erring high keeps cards further from live buttons, never closer.
local EDGE_BOTTOM = 6
-- The gap the ring registers off the throw cluster's edge, and (since Task 5) the gap the plate
-- registers off the tape's edge too — the hamburger's old gap constant and this were always the
-- same value (8); one constant now that only one door remains.
local RING_GAP = HudLayout.RING_GAP
local BANK_GAP = HudLayout.BANK_GAP

-- BTN_W tracks BTN_H (the buttons are square) off the SAME shared scale, so "50% smaller" shrinks
-- the cluster in both axes rather than leaving three squat letterboxes.
local BTN_H = if TOUCH then HudLayout.BTN_H_TOUCH else HudLayout.BTN_H
local BTN_W = BTN_H
local BTN_GAP = if TOUCH then 8 else 10
local TAPE_N = 5
local TILE = if TOUCH then HudLayout.TILE_TOUCH else HudLayout.TILE
local TILE_GAP = if TOUCH then 4 else 6
-- The tape row's own width — the plate (below) registers off its left edge, and the tape's own
-- Size uses it too, so it is pulled out here rather than left as a repeated inline expression.
local TAPE_W = TAPE_N * (TILE + TILE_GAP) - TILE_GAP
local BADGE = if TOUCH then 7 else 9
local ROW_GAP = HudLayout.ROW_GAP
local AREA_W = 3 * BTN_W + 2 * BTN_GAP
local AREA_H = if TOUCH then HudLayout.AREA_H_TOUCH else HudLayout.AREA_H
-- How far the bank+throws+tape cluster's own TOP edge sits from the screen bottom, at this tier —
-- the escalation overlay (below) clamps against this so it can never sit on top of the bank
-- button on a short viewport.
local CLUSTER_TOP_FROM_BOTTOM = if TOUCH
    then HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH
    else HudLayout.CLUSTER_TOP_FROM_BOTTOM
local TOAST_SECONDS = 4
local TOAST_MAX = 6

-- The bank button, directly above the throw row.
local BANK_W = 150

local gui = Instance.new("ScreenGui")
gui.Name = "RoshamboHud"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function corner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number): UIStroke
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency
    s.Parent = parent
    return s
end

-- A centred, inset box to hang a glyph in. Glyphs.render fills its parent (aspect-locked), so
-- without this the symbol would run edge to edge on the tile.
local function glyphBox(parent: Instance, inset: number): Frame
    local box = Instance.new("Frame")
    box.Name = "GlyphBox"
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.Size = UDim2.fromScale(inset, inset)
    box.BackgroundTransparency = 1
    box.Parent = parent
    return box
end

-- All three symbols built ONCE per tape tile and toggled by Visible. A tile's symbol changes every
-- round; rebuilding two ImageLabels per tile per publish would churn instances for no reason.
local function glyphSet(parent: Instance, inset: number): { [string]: Frame }
    local box = glyphBox(parent, inset)
    local set: { [string]: Frame } = {}
    for _, sym in THROWS do
        local g = Glyphs.render(box, sym, INK)
        g.Visible = false
        set[sym] = g
    end
    return set
end

local function fadeGlyph(g: Frame, transparency: number)
    for _, child in g:GetChildren() do
        if child:IsA("ImageLabel") then
            child.ImageTransparency = transparency
        end
    end
end

-- Recolour a rendered glyph in place. `Glyphs.render` builds two named ImageLabels — an "Outline"
-- behind and a "Core" in front — so this addresses them by NAME rather than by child order. A glyph
-- for a symbol the module has no image for simply has neither child, and this no-ops.
local function tintGlyph(g: Frame, core: Color3, outline: Color3)
    local c = g:FindFirstChild("Core")
    if c and c:IsA("ImageLabel") then
        c.ImageColor3 = core
    end
    local o = g:FindFirstChild("Outline")
    if o and o:IsA("ImageLabel") then
        o.ImageColor3 = outline
    end
end

-- ===== Counting: wallet figures animate rather than snap =====
-- Every figure the HUD shows for the wallet — the points and streak in the plate's line, and
-- the pot on the bank button — animates to its new value instead of snapping (spec: "Numbers
-- count rather than jump"). This is what makes banking read as a TRANSFER: press BANK 27 POINTS
-- and the button's figure runs down to zero while the balance below runs up by the same amount,
-- both driven off the SAME ProfileUpdate, with no special case for "this one's a bank" — see
-- `paintCounters`, below, where all three counters are ticked from the one set of targets.
--
-- `RollingNumber` is the pure arithmetic of one count; `Counter` is the small bit of STATE this
-- file wraps around it — what's currently displayed, what it's counting toward, when the current
-- leg began and how long that leg lasts. `tickCounter` is the driver, and it is keyed on the
-- TARGET changing, not on how often it gets called: it is invoked at 10Hz from `render` AND at
-- frame rate from the RenderStepped driver below, and restarting the count on every call would
-- pin every number at its first frame forever — precisely how the bank pulse (`setBank`, below)
-- failed earlier in this branch by cancelling and restarting its tween on every repaint.
type Counter = {
    -- What `tickCounter` returned last time. Also the next `from` if the target changes again
    -- mid-count, so a second change continues from where the number visibly IS rather than
    -- snapping back to whatever it was counting from before.
    displayed: number,
    target: number,
    from: number,
    startedAt: number?, -- os.clock() the current leg began, or nil once it has settled
    -- The duration of the CURRENT leg, fixed when the target changed. Recomputed per leg rather
    -- than read per frame so a count that is interrupted mid-flight finishes on the curve it
    -- started on instead of jumping to a new one.
    duration: number,
}

local function newCounter(initial: number): Counter
    return {
        displayed = initial,
        target = initial,
        from = initial,
        startedAt = nil,
        duration = RollingNumber.MIN_DURATION,
    }
end

local function tickCounter(c: Counter, target: number): number
    if target ~= c.target then
        c.from = c.displayed
        c.target = target
        c.startedAt = os.clock()
        c.duration = RollingNumber.durationFor(target - c.from)
    end
    if c.startedAt then
        local t = (os.clock() - c.startedAt) / c.duration
        c.displayed = RollingNumber.valueAt(c.from, c.target, t)
        if t >= 1 then
            c.startedAt = nil -- settled; further calls at the same target are free until it moves
        end
    else
        c.displayed = c.target
    end
    return c.displayed
end

-- ARRIVING AT A VALUE WITHOUT COUNTING TO IT. Every counter starts at 0 because there is nothing
-- else to start at — the profile has not arrived when this file runs. Re-keying 0 -> the real
-- balance when it lands would run a full count of up to 2.5s, with the plate revealed, its gold
-- rim lifted and the figure gold, celebrating a payoff that never happened — seconds after
-- spawning, before the player has done anything. A player's first look at their own wallet is
-- the one place a count is meaningless: nothing moved, they simply arrived. So that first look
-- SEEDS the counters instead — they arrive at the value rather than counting to it.
--
-- WHICH RENDER THAT IS, is the whole of the problem. It is NOT the first one: main.client
-- publishes on a 10Hz heartbeat from script load, while its `wallet` is still the placeholder
-- `{ 0, 0, 0 }`, and the real profile cannot land until the server's join fetch returns from an
-- HTTP round trip this controller is always listening well before. Seeding on the first render
-- captured 0 and left the real balance to arrive as a rising count — the exact celebration this
-- is meant to prevent. `aux.profileSeen` is main.client's own "the profile has answered" flag
-- (the one gating its onboarding beats), carried through on the HudState path; `render` seeds on
-- the first render where it is true. If the join fetch never succeeds it stays false and nothing
-- is ever seeded — which is correct rather than stuck: the wallet is then genuinely zero (the
-- server's fetch is what fills it), so every later move IS a real move and SHOULD count.
local function seedCounter(c: Counter, value: number)
    c.displayed = value
    c.target = value
    c.from = value
    c.startedAt = nil -- not counting; `tickCounter`'s next call finds the target unchanged
end

local pointsCounter = newCounter(0)
local streakCounter = newCounter(0)
local potCounter = newCounter(0)

-- ===== Plate: one line at the bottom of the cluster, normally hidden =====
-- Superseded the right-margin placement (owner, mid-implementation): the jump-button measurement
-- is gone entirely. The plate is now a single line at the bottom of the throw cluster, exactly
-- as tall as a tape tile and right-aligned RING_GAP left of the tape's own left edge, so the
-- bottom row reads as one band. AutomaticSize = X: it reserves no dead space when the line is
-- short (no streak riding).
--
-- NORMALLY HIDDEN. Points are not a thing you need at a glance — a riding pot already has its
-- own always-visible bank button. The plate reveals on the ring's first tap and on any change to
-- the figures it shows (see `revealPlate` and the change-guard in `render`), holds for at least
-- PLATE_HOLD — longer if a points count is still running, see `plateHoldSeconds` — then fades
-- over PLATE_FADE.
--
-- TAPPABLE (spec §6, Task 5). It went inert only because it had moved into the strip Roblox uses
-- for camera drag; it is in the bottom row now, so it is safe to make a `TextButton` again — the
-- ledger's second door, alongside the ring, whenever it is showing. See its `MouseButton1Click`
-- handler below.
--
-- Two consequences of being a live button that a plain Frame never had to worry about:
--   1. AutomaticSize.X now folds the BUTTON's own `Text` into the content width too, not just
--      `plateLabel`'s — benign here because `plate.Text` stays `""` (see below), but worth
--      knowing if this ever grows a second label.
--   2. `GuiButton.Selectable` defaults to `true`, which would put the plate into gamepad focus
--      navigation alongside the throw/bank buttons. Forced off below — nothing about "one line
--      that only sometimes exists" belongs in a d-pad tab order.
-- A FLOOR on the hold, not the whole of it: `plateHoldSeconds` extends it to outlast a points
-- count that runs longer than this. Every count was half a second when this number was chosen.
local PLATE_HOLD = 2
local PLATE_FADE = 0.35
-- A CAP on how far AutomaticSize.X may grow the plate leftward. It was never a problem for a
-- Frame — nothing sank a touch — but it is a live button now, and it is unbounded: a long-riding
-- streak plus a large pot ("×12  9999999") can push its content past 100px, and the plate's right
-- edge already sits close enough to the screen's own left edge at the narrowest supported width
-- that unbounded growth can creep toward the movement thumbstick (`HudController.client.luau:5`
-- — "bottom-left: the movement thumbstick. Untouchable."). 100px keeps ordinary play (a one- or
-- two-digit streak, a three- to five-digit pot) entirely unclipped and puts a hard ceiling on the
-- pathological case instead of leaving it to grow with the number. See the task report for the
-- resulting worst-case left edge at 568px and 320px.
local PLATE_MAX_W = 100
-- The plate's GOLD rim AT REST. The plate's own stroke is never day/night-adjusted (only the tape
-- tile rims and the backing are — see `applyContrast`), so its resting weight is a plain pair of
-- constants rather than a live variable.
--
-- DECLARED HERE so the CONSTRUCTION CALL below can use them. `revealPlate` restores this pair and
-- `setCelebrating` tweens back to it after a payoff, so the value the plate is built at and the
-- value it settles to have to be the same value, not two literals that happen to agree today.
local PLATE_STROKE_REST_TRANSPARENCY = 0.35
local PLATE_STROKE_REST_THICKNESS = 1

local plate = Instance.new("TextButton")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(1, 1)
plate.AutomaticSize = Enum.AutomaticSize.X
plate.Size = UDim2.fromOffset(0, TILE)
plate.Selectable = false -- see the button-consequences note above; this is not a d-pad target
-- Fixed off the SAME shared right reference (1 - JUMP_CLEARANCE) the throw cluster and the bank
-- button register to — RING_GAP left of the tape's own left edge (offset -TAPE_W from that
-- reference), bottom-aligned with the tape at EDGE_BOTTOM from the gui's bottom (the cluster's
-- new floor now the hairline is gone — see EDGE_BOTTOM, above). AutomaticSize grows the frame
-- LEFTWARD from this anchored right edge, so a longer line (a streak riding) never creeps toward
-- the tape. It does NOT move horizontally here — only the vertical anchor changed from EDGE.
-- See the task report for the overlap arithmetic against the tape and the ring.
plate.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + RING_GAP), 1, -EDGE_BOTTOM)
plate.BackgroundColor3 = WASHI
plate.BackgroundTransparency = 0.3
plate.BorderSizePixel = 0
plate.AutoButtonColor = false
plate.Text = ""
plate.Visible = false
plate.Parent = gui
corner(plate, 6)
local plateStroke = stroke(plate, GOLD, PLATE_STROKE_REST_THICKNESS, PLATE_STROKE_REST_TRANSPARENCY)
do
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(PLATE_MAX_W, math.huge) -- height is fixed (TILE), never automatic
    constraint.Parent = plate
end
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = plate
end

-- ONE label for the whole line: `900`, or `×3  900` when a streak rides (see `render`). No
-- stroke on it — contrast comes from the Frame's opaque backing, never an outline on text.
local plateLabel = Instance.new("TextLabel")
plateLabel.Name = "Line"
plateLabel.AutomaticSize = Enum.AutomaticSize.X
plateLabel.Size = UDim2.fromScale(0, 1)
plateLabel.BackgroundTransparency = 1
plateLabel.TextColor3 = INK_CREAM
plateLabel.TextSize = 15
plateLabel.Font = Enum.Font.GothamBold
plateLabel.Text = "0"
plateLabel.Parent = plate

-- A six-digit balance with a two-digit streak ("×12  999999") measures wider than PLATE_MAX_W's
-- own padded interior (100 - 16 = 84px). AutomaticSize.X alone measures the label's UNCAPPED
-- natural text width — it has no idea the plate above it is about to clamp — so without this the
-- label rendered past the plate's right/left edge and over the tape's first tile for every
-- reveal that had one. A UISizeConstraint mirroring the plate's own cap gives the label the same
-- hard ceiling `plate` already enforces on itself (the same AutomaticSize + UISizeConstraint
-- combination, one level down); TextScaled + a MaxTextSize constraint — the pattern `bankButton`
-- and `undoLabel` use for exactly this — then shrinks the font to fit inside that clamp instead
-- of clipping the tail digits, which ClipsDescendants would have done.
do
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(PLATE_MAX_W - 16, math.huge)
    constraint.Parent = plateLabel
end
plateLabel.TextScaled = true
do
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 15
    constraint.Parent = plateLabel
end

-- The BACKING's rest transparency, unlike the rim's pair above, is NOT a constant: `applyContrast`
-- keeps it in sync with the current day/night lerp, and `revealPlate` reads it rather than a
-- hardcoded literal, so a reveal in full daylight does not sit at the authored-for-night value
-- until the next ambient tick corrects it.
local plateRestTransparency = 0.3

-- ===== The payoff draws the eye =====
-- WHILE THE BALANCE CLIMBS, the plate lifts: its existing GOLD rim comes up from a hairline to a
-- real edge, and the figure itself goes gold. It settles back as the count lands.
--
-- THE PLATE ONLY. The bank button's figure is DRAINING to zero over the same seconds, and a
-- number counting down to nothing should not celebrate — the destination gets the emphasis, the
-- source just empties.
--
-- LATCHED, and that is not optional: this is called every frame while a count runs (from
-- `paintCounters`, which the RenderStepped driver invokes at frame rate), and a tween cancelled
-- and restarted at frame rate gets a few percent of its travel and renders static. That is
-- exactly how the bank button's pulse failed earlier in this branch.
--
-- DECLARED HERE, beside the plate's other visual state rather than beside `paintCounters` where
-- it is called: `revealPlate`, below, writes `plateStroke.Transparency` directly, and a re-reveal
-- can land mid-count. It has to know whether the rim is currently lit, or the second bank of a
-- streak would drop the rim back to a hairline for the rest of its own count with no tween left
-- running to bring it up again.
local CELEBRATE_SECONDS = 0.15
-- The LIT pair. Its rest counterpart is `PLATE_STROKE_REST_*`, declared above the construction
-- call so the weight the plate is built at and the weight this settles back to are one value.
local PLATE_STROKE_LIT_TRANSPARENCY = 0
local PLATE_STROKE_LIT_THICKNESS = 2
local celebrating = false
-- A HANDLE on the rim's tween, for `revealPlate` alone. A reveal writes `plateStroke.Transparency`
-- directly, and whether that write is right or wrong depends on whether this tween is mid-flight:
-- a tween interpolates from the value it captured at `Play()`, so a direct write lands for one
-- frame and is then overwritten. See the read of it in `revealPlate`.
local celebrateRim: Tween? = nil

local function setCelebrating(active: boolean)
    if active == celebrating then
        return
    end
    celebrating = active
    local info = TweenInfo.new(CELEBRATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    -- The stroke is on the PLATE, a Frame. Never on plateLabel — an outline on text fills the
    -- counters of every glyph.
    local rim = if active
        then { Transparency = PLATE_STROKE_LIT_TRANSPARENCY, Thickness = PLATE_STROKE_LIT_THICKNESS }
        else { Transparency = PLATE_STROKE_REST_TRANSPARENCY, Thickness = PLATE_STROKE_REST_THICKNESS }
    local rimTween = TweenService:Create(plateStroke, info, rim)
    celebrateRim = rimTween
    rimTween:Play()
    TweenService:Create(plateLabel, info, {
        TextColor3 = if active then GOLD else INK_CREAM,
    }):Play()
end

-- Reveal/hide state. A GENERATION counter — the same pattern as `pressSeq`/`potPulse` above —
-- so a fade cancelled by a newer reveal cannot let its own stale `Completed` callback fire late
-- and hide a plate the newer reveal just showed.
local plateGen = 0
-- True from the instant a reveal starts until the fade has ACTUALLY finished (hold + fade both
-- count). The ledger door's two-stage test below reads exactly this, never a timer: a control
-- that is still visible must still be answerable, whether that visibility is the hold or the
-- tail of the fade.
local plateVisible = false
local plateFadeTweens: { Tween } = {}

local function cancelPlateFade()
    for _, t in plateFadeTweens do
        t:Cancel()
    end
    table.clear(plateFadeTweens)
end

local function startPlateFade(gen: number)
    if gen ~= plateGen then
        return -- superseded by a newer reveal; this fade no longer applies
    end
    local info = TweenInfo.new(PLATE_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    -- The fade takes the backing AND the stroke with the text — a washi panel that stays put
    -- while its number dissolves is worse than either alone.
    local bgTween = TweenService:Create(plate, info, { BackgroundTransparency = 1 })
    local textTween = TweenService:Create(plateLabel, info, { TextTransparency = 1 })
    local strokeTween = TweenService:Create(plateStroke, info, { Transparency = 1 })
    plateFadeTweens = { bgTween, textTween, strokeTween }
    bgTween.Completed:Connect(function()
        if gen == plateGen then
            plateVisible = false
            plate.Visible = false
        end
    end)
    bgTween:Play()
    textTween:Play()
    strokeTween:Play()
end

-- HOW LONG THE PLATE HOLDS DEPENDS ON WHAT IT IS HOLDING. PLATE_HOLD was chosen when every count
-- took a flat half second. Counts now scale with the amount, up to RollingNumber.MAX_DURATION, so
-- any bank above roughly 1120 points already counts for longer than the plate stays up — and at
-- 6561, eight straight wins and the biggest payoff in the game, the total landed on the very frame
-- the plate reached full transparency. The number the whole feature exists to show was never
-- legible, and it failed worst in its best case.
--
-- So the hold is at LEAST PLATE_HOLD, and at least however much of the points count is still to
-- run plus PLATE_READ_BEAT to actually read the figure it lands on. Small moves are untouched: a
-- 1-point change counts for 0.56s and a streak ticking does not move the points counter at all,
-- both of which stay under PLATE_HOLD and hold exactly as they did before.
--
-- It reads `pointsCounter`'s own `duration` — the value `tickCounter` fixed for this leg — rather
-- than recomputing the delta, so the hold and the count cannot drift apart. That is also why
-- `render` arms the reveal AFTER `paintCounters` rather than before: until the paint has run,
-- `startedAt` and `duration` still describe the PREVIOUS leg.
--
-- NOTHING POLLS. The hold is a finite number decided once, at arm time, and handed to the same
-- `task.delay` as before, so a count that is interrupted or never completes cannot strand the
-- plate visible — the delay is wall-clock and fires regardless. A second bank landing mid-count
-- re-arms the reveal, which measures the remaining time against the NEW leg and supersedes the
-- pending fade by generation: the hold extends, it never truncates.
local PLATE_READ_BEAT = 0.6

local function plateHoldSeconds(): number
    local startedAt = pointsCounter.startedAt
    if startedAt == nil then
        return PLATE_HOLD -- nothing counting: a streak tick, or a figure that has already settled
    end
    local remaining = math.max(pointsCounter.duration - (os.clock() - startedAt), 0)
    return math.max(PLATE_HOLD, remaining + PLATE_READ_BEAT)
end

-- Reveal on the ledger door's first tap, and on any change to the figures (the change-guard
-- lives in `render`, not here — this function only knows how to show). Re-revealing mid-hold or
-- mid-fade CANCELS the fade and restores full opacity instead of stacking: the plate is either
-- fully there or on its way out, never two competing states at once.
local function revealPlate()
    plateGen += 1
    local gen = plateGen
    cancelPlateFade()
    plate.Visible = true
    plate.BackgroundTransparency = plateRestTransparency -- Cancel leaves properties mid-tween
    plateLabel.TextTransparency = 0
    -- THE RIM IS RESTORED ONLY WHEN NOTHING IS ANIMATING IT, and it is restored to the LATCHED
    -- state rather than unconditionally to rest. Three cases, and each needs a different answer:
    --   * No celebrate tween running, not celebrating — the ordinary reveal. Write rest.
    --   * No celebrate tween running, celebrating — a RE-reveal mid-count (the second bank of a
    --     streak; the 0.15s lift finished seconds ago). Writing rest here would drop the rim to a
    --     hairline for the remainder of the count with nothing left running to raise it.
    --   * A celebrate tween IS running — the FIRST bank, where `paintCounters` started the lift
    --     microseconds ago in this same `render`. A tween interpolates from the value it captured
    --     at `Play()`, so any write here survives exactly one frame before the tween overrides it:
    --     writing lit would flash the rim bright and then drop it back to swell in again. Leave it
    --     alone — the tween is already travelling to the right value, including from wherever a
    --     just-cancelled fade left the property.
    local rimTween = celebrateRim
    if rimTween == nil or rimTween.PlaybackState ~= Enum.PlaybackState.Playing then
        plateStroke.Transparency = if celebrating
            then PLATE_STROKE_LIT_TRANSPARENCY
            else PLATE_STROKE_REST_TRANSPARENCY
    end
    plateVisible = true
    task.delay(plateHoldSeconds(), function()
        startPlateFade(gen)
    end)
end

-- TAPPABLE AGAIN, and it is safe now in a way it was not before. The plate went inert because it
-- had moved into the strip Roblox uses for camera drag, where a sinking element is a permanent
-- hole. It is in the bottom row now. So the ledger has two doors — the ring and the plate
-- whenever it is showing — and tapping the ring then the plate is the same two taps as
-- double-tapping the ring.
--
-- Guarded on `plateVisible`, not `plate.Visible`: a hidden button cannot be clicked, so the
-- guard's real job is covering the FADE, where the plate is still technically `Visible = true`
-- on its way out (`plateVisible` stays true through hold AND fade — see its own declaration,
-- above).
plate.MouseButton1Click:Connect(function()
    if plateVisible then
        EventBus.OpenLedger:Fire()
    end
end)

-- ===== Throw area: bottom-right, inboard of the jump button =====
local throwArea = Instance.new("Frame")
throwArea.Name = "ThrowArea"
throwArea.AnchorPoint = Vector2.new(1, 1)
throwArea.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -EDGE_BOTTOM)
throwArea.Size = UDim2.fromOffset(AREA_W, AREA_H)
throwArea.BackgroundTransparency = 1
throwArea.Parent = gui

-- Tape BELOW the buttons (owner's ruling): five square tiles, newest LEFT, ageing ivory ->
-- amber, with a corner dot for the personal WIN/SAFE/LOSS result. It is read, never touched,
-- so it takes the outermost edge and the buttons take the reachable one.
local tapeRow = Instance.new("Frame")
tapeRow.Name = "Tape"
tapeRow.AnchorPoint = Vector2.new(1, 1)
tapeRow.Position = UDim2.fromScale(1, 1)
tapeRow.Size = UDim2.fromOffset(TAPE_W, TILE)
tapeRow.BackgroundTransparency = 1
tapeRow.Parent = throwArea

type TapeTile = { frame: Frame, glyphs: { [string]: Frame }, badge: Frame, rim: UIStroke }
local tapeTiles: { TapeTile } = {}
for i = 1, TAPE_N do
    local tile = Instance.new("Frame")
    tile.Name = `T{i}`
    tile.Position = UDim2.fromOffset((i - 1) * (TILE + TILE_GAP), 0)
    tile.Size = UDim2.fromOffset(TILE, TILE)
    tile.BackgroundColor3 = IVORY
    tile.BackgroundTransparency = 0.1
    tile.BorderSizePixel = 0
    tile.Visible = false
    tile.Parent = tapeRow
    corner(tile, 4)
    local tileRim = stroke(tile, TAN_RIM, 1, 0.3)

    local badge = Instance.new("Frame")
    badge.Name = "Badge"
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Position = UDim2.fromScale(0.88, 0.12)
    badge.Size = UDim2.fromOffset(BADGE, BADGE)
    badge.BackgroundColor3 = WIN_GREEN
    badge.BorderSizePixel = 0
    badge.ZIndex = 3
    badge.Visible = false
    badge.Parent = tile
    corner(badge, 5)

    tapeTiles[i] = { frame = tile, glyphs = glyphSet(tile, 0.66), badge = badge, rim = tileRim }
end

-- Mirrors the last rendered `view.throwsEnabled` so a tap can be refused without re-deriving the
-- rule. Advisory only: the server is what actually refuses a pick.
local canThrow = false

-- Mirrors the last rendered `view.chosen`, so the press handler below can tell a "choose" tap
-- (nothing chosen yet) from a tap that would only raise an UNDO? prompt (something already is).
-- Advisory, same as `canThrow` above.
local chosenSym: string? = nil

-- The tile the player just PRESSED, lit before any round trip and cleared by the next render (which
-- runs at 10Hz, and immediately on the pick's own publish). See the press handlers below.
local pressedSym: string? = nil

local HALO_BLEED = 7 -- how far the chosen tile's glow spills past its edge
local PRESS_SCALE = 0.93 -- how far a press depresses the tile
local PRESS_DOWN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_UP = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type ThrowTile = { button: TextButton, glyph: Frame, rim: UIStroke, halo: Frame, scale: UIScale }
local throwTiles: { [string]: ThrowTile } = {}
for i, sym in THROWS do
    -- The chosen tile's glow. A SIBLING of the button at ZIndex 0, not a child: under the default
    -- Sibling ZIndexBehavior a child always draws ABOVE its parent, so a halo parented to the button
    -- would sit on top of the glyph instead of behind the tile. A Frame, and left at its default
    -- Active = false — the interactive budget on this surface is the three buttons, the one bank
    -- button and the ledger door, and every sinking pixel is a permanent hole in the camera-drag
    -- surface.
    local halo = Instance.new("Frame")
    halo.Name = sym .. "Halo"
    halo.AnchorPoint = Vector2.new(0, 0)
    halo.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP) - HALO_BLEED, -HALO_BLEED)
    halo.Size = UDim2.fromOffset(BTN_W + 2 * HALO_BLEED, BTN_H + 2 * HALO_BLEED)
    halo.BackgroundColor3 = SEL_HALO
    halo.BackgroundTransparency = 0.55
    halo.BorderSizePixel = 0
    halo.ZIndex = 0
    halo.Visible = false
    halo.Parent = throwArea
    corner(halo, 12)

    local b = Instance.new("TextButton")
    b.Name = sym
    b.AnchorPoint = Vector2.new(0, 0)
    b.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP), 0)
    b.Size = UDim2.fromOffset(BTN_W, BTN_H)
    b.BackgroundColor3 = IVORY_DIM -- starts disabled; the first HudState paints the real state
    b.BackgroundTransparency = 0.25
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = throwArea
    corner(b, 8)
    local rim = stroke(b, TAN_RIM, 2, 0.1)

    -- A UIScale, deliberately, for the press depress: it is the one property `render` never writes,
    -- so the 10Hz repaint cannot fight the tween half-way through it.
    local scale = Instance.new("UIScale")
    scale.Parent = b

    throwTiles[sym] = {
        button = b,
        glyph = Glyphs.render(glyphBox(b, 0.62), sym, INK),
        rim = rim,
        halo = halo,
        scale = scale,
    }
end

-- ===== UNDO?: the question raised over a glyph the player has just tapped =====
-- It sits ON the button rather than beside it, because the button is no longer offering an
-- option — it is asking a question, and covering the glyph is the clearest way to say so.
-- Answering it UNLOCKS all three; it does not select this one. That is what makes backing out
-- of a round possible at all.
--
-- IT COVERS THE GLYPH, ON PURPOSE. Confirming an undo UNLOCKS; it never selects the button
-- that was tapped. So the glyph underneath is not a destination — both unchosen buttons are
-- proxies for undo-and-cancel, and either does the same thing. Revealing it would advertise
-- a destination that does not exist.
--
-- No UIStroke on the label. Contrast comes from the opaque backing behind it (see the spec's
-- §3): an outline on TextScaled type this size fills the counters in and reads as a smear.
local undoPill = Instance.new("Frame")
undoPill.Name = "UndoPrompt"
undoPill.AnchorPoint = Vector2.new(0.5, 0.5)
-- EXACTLY THE BUTTON, both dimensions, both tiers (owner's gate 2026-08-04). It anchors at
-- (0.5, 0.5) on the button's centre, so it covers it precisely.
--
-- IT MUST STAY Active = false. It is a Frame, and the tap that answers it is delivered to the
-- TextButton underneath — a full-size overlay that sank would swallow the very tap that
-- resolves it, and the mechanic would break outright with every gate green.
undoPill.Size = UDim2.fromOffset(BTN_W, BTN_H)
-- IVORY, not WASHI (owner's gate 2026-08-04). At 24px the near-black pill read as an accent; at
-- full button size and fully opaque it read as a hole punched in the HUD. Cream-on-ink under a
-- cool rim is this HUD's own washi idiom, and the SEL_BLUE stroke is what keeps a light tile
-- from reading as an ordinary available throw.
undoPill.BackgroundColor3 = IVORY
undoPill.BackgroundTransparency = 0
undoPill.BorderSizePixel = 0
undoPill.ZIndex = 4
undoPill.Visible = false
undoPill.Parent = throwArea
corner(undoPill, 8)
stroke(undoPill, SEL_BLUE, 2, 0)

local undoLabel = Instance.new("TextLabel")
undoLabel.Name = "Copy"
undoLabel.Size = UDim2.fromScale(1, 1)
undoLabel.BackgroundTransparency = 1
undoLabel.TextColor3 = INK
undoLabel.TextSize = 13
undoLabel.Font = Enum.Font.GothamBold
undoLabel.Text = "UNDO?"
undoLabel.ZIndex = 5
undoLabel.Parent = undoPill

-- TextScaled + a MaxTextSize constraint, same pattern as `bankButton`. The pill is BTN_W x BTN_H
-- with no padding, so the content box is the full button: 44px on the touch tier, 76px on
-- desktop. "UNDO?" fills the touch tier's 44px box comfortably. The constraint caps growth on
-- the wide tier — at desktop's 76px content box, five characters of GothamBold cap out near
-- 22px, and higher would clip the word on the wide tier instead of the narrow one. If MaxTextSize
-- ever needs to move, compute it from these box widths, not from the old 24px pill's numbers.
undoLabel.TextScaled = true
do
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 22
    constraint.Parent = undoLabel
end

local THROW_INDEX: { [string]: number } = {}
for i, sym in THROWS do
    THROW_INDEX[sym] = i
end

-- The buttons are anchored to the TOP of throwArea (the tape moved below them since Task 6), so
-- the pill's y is measured from that top edge — BTN_H / 2, not from the bottom.
local function setUndoPrompt(symbol: string?)
    undoPill.Visible = symbol ~= nil
    if symbol then
        local i = THROW_INDEX[symbol]
        undoPill.Position = UDim2.fromOffset((i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, BTN_H / 2)
    end
end

-- THE SELECTION TREATMENT, in one place so the optimistic press paint and the authoritative render
-- can never disagree about what "chosen" looks like. Five states, not two:
--   chosen        : cool and LIT — pale wash, blue glyph, thick blue rim, halo behind.
--   prompted      : lifted OUT of the dimmed treatment — this button is carrying a question, and
--                   a question on a greyed-out control reads as unanswerable.
--   not chosen    : warm and FAINT — dark amber, nearly gone, amber glyph. They "almost
--                   disappear" (owner's words); the warm/cool split against the blue is what
--                   makes the choice unmistakable without lighting three tiles up at once.
--   throwable     : the resting ivory tile.
--   not throwable : ivory dimmed, as before — a whole round is closed, not one option among three.
local function paintThrows(pick: string?, enabled: boolean, prompted: string?)
    for _, sym in THROWS do
        local t = throwTiles[sym]
        if pick == sym then
            t.button.BackgroundColor3 = SEL_WASH
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, SEL_BLUE, SEL_INK)
            fadeGlyph(t.glyph, 0)
            t.rim.Color = SEL_BLUE
            t.rim.Thickness = 4
            t.rim.Transparency = 0
            t.halo.Visible = true
        elseif sym == prompted then
            -- Lifted OUT of the dimmed state: this button is carrying a question, and a
            -- question on a greyed-out control reads as unanswerable.
            --
            -- CURRENTLY INVISIBLE. `undoPill` is opaque IVORY at this exact rect and ZIndex, with
            -- its own SEL_BLUE stroke standing in for the rim below — and `paintThrows` and
            -- `setUndoPrompt` are always driven by the same value in the same `render` pass, so
            -- this branch is fully occluded every time it runs. It stays as the fallback for a
            -- smaller or translucent pill: if `undoPill` is ever shrunk or given transparency,
            -- this paint is what shows through, and nobody has laid eyes on it since 2026-08-02.
            -- Anyone changing the pill's size or opacity should look at this branch first — and
            -- should re-pick this branch's fill before doing so: the pill and this branch's
            -- lifted treatment are now the SAME colour (IVORY), so what showed through used to
            -- contrast against the pill and no longer does.
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0.2)
            t.rim.Color = SEL_BLUE
            t.rim.Thickness = 2
            t.rim.Transparency = 0.2
            t.halo.Visible = false
        elseif pick then
            t.button.BackgroundColor3 = WARM_FACE
            t.button.BackgroundTransparency = 0.75
            tintGlyph(t.glyph, WARM_GLYPH, WARM_FACE)
            fadeGlyph(t.glyph, 0.7)
            t.rim.Color = WARM_RIM
            t.rim.Thickness = 1
            t.rim.Transparency = 0.55
            t.halo.Visible = false
        elseif enabled then
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0)
            t.rim.Color = TAN_RIM
            t.rim.Thickness = 2
            t.rim.Transparency = 0.1
            t.halo.Visible = false
        else
            t.button.BackgroundColor3 = IVORY_DIM
            t.button.BackgroundTransparency = 0.25
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0.45)
            t.rim.Color = TAN_RIM
            t.rim.Thickness = 2
            t.rim.Transparency = 0.1
            t.halo.Visible = false
        end
    end
end

-- The chosen glyph PULSES. A static light says "this is selected"; a pulse says "this is what
-- is going in", which is the thing the player is being asked to be sure about.
--
-- Guarded on the symbol actually changing, same as `setBank`'s pot pulse: `render` runs at 10Hz,
-- and cancelling/restarting a 1.1s tween on every repaint would give it 3% of its travel and
-- render as a static element, not a pulse — this exact bug already shipped once on this branch
-- in `setBank` and had to be fixed.
local chosenPulse: Tween? = nil
local pulsingSym: string? = nil
local function setChosenPulse(symbol: string?)
    if pulsingSym == symbol then
        return
    end
    pulsingSym = symbol
    if chosenPulse then
        chosenPulse:Cancel()
        chosenPulse = nil
    end
    for _, sym in THROWS do
        throwTiles[sym].halo.BackgroundTransparency = 0.55
    end
    if symbol then
        -- Assign-then-Play, not a cast chained straight off `Create(...)`: a `)` at the start of
        -- a line followed by `(` parses in Lua/Luau as a CALL on the previous expression's
        -- result, not a new statement — `Create(...)\n(x):Play()` silently becomes
        -- `Create(...)(x):Play()`, calling the Tween as if it were a function. This is the same
        -- pattern `setBank`'s pot pulse already uses.
        local t = TweenService:Create(
            throwTiles[symbol].halo,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.15 }
        )
        t:Play()
        chosenPulse = t
    end
end

-- A tap must ALWAYS visibly do something. The buttons carry AutoButtonColor = false (the palette is
-- hand-painted), so before this a press produced no feedback whatsoever — and roughly a fifth of
-- every round sits in TALLY/REVEAL where `canThrow` is legitimately false, so a perfectly good tap
-- landing in that window vanished without a trace. That is the "I have to click the throw button
-- twice, but there's nothing indicating that" report. The depress fires on EVERY press, accepted or
-- refused; the blue light only on an accepted one.
-- The tween itself, factored out from `depress` so the ledger door (below) gets the same
-- press feedback without needing a full ThrowTile — every AutoButtonColor = false button in
-- this file goes through one of these two, never silent on press.
local function pressDepress(scale: UIScale)
    scale.Scale = 1
    local down = TweenService:Create(scale, PRESS_DOWN, { Scale = PRESS_SCALE })
    down.Completed:Connect(function()
        TweenService:Create(scale, PRESS_UP, { Scale = 1 }):Play()
    end)
    down:Play()
end

local function depress(t: ThrowTile)
    pressDepress(t.scale)
end

-- How long the optimistic light survives without the pick coming back on HudState. In the normal
-- case it is superseded within a frame (main.client sets `chosen` and publishes on HudPick, all
-- client-local — the server round trip is not in this path). This only has to catch a press that
-- never became a click, e.g. the finger slid off the button.
local PRESS_HOLD_SECONDS = 0.5
local pressSeq = 0

for _, sym in THROWS do
    local tile = throwTiles[sym]
    tile.button.MouseButton1Down:Connect(function()
        depress(tile)
        if not canThrow then
            return
        end
        -- The optimistic chosen-paint is only honest when the tap is a "choose" — nothing chosen
        -- yet. When something already is, the tap only raises an UNDO? prompt (see `paintThrows`'s
        -- `prompted` branch), and lighting a third glyph fully chosen here would assert something
        -- false for up to PRESS_HOLD_SECONDS, until `render` corrects it. `chosenSym` mirrors
        -- `view.chosen` for exactly this check — deliberately not `HudModel.tapAction`, which needs
        -- a full `Inputs` this controller does not hold.
        if chosenSym ~= nil then
            return
        end
        pressedSym = sym
        pressSeq += 1
        local seq = pressSeq
        paintThrows(sym, canThrow, nil) -- lit on the PRESS, ahead of any round trip
        task.delay(PRESS_HOLD_SECONDS, function()
            if pressSeq == seq and pressedSym == sym then
                pressedSym = nil -- let the next render tell the truth
            end
        end)
    end)
    tile.button.MouseButton1Click:Connect(function()
        if canThrow then
            EventBus.HudPick:Fire(sym)
        end
    end)
end

-- ===== The bank button: directly above the throw row =====
-- ONE control, not a readout plus a button. The figure belongs IN the thing that acts on it —
-- a separate red disc saying "27" beside a generic BANK THESE made the player join two
-- elements to read one fact. Throwing again IS riding, so there is no counterpart button and
-- nothing to resolve.
local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.AnchorPoint = Vector2.new(1, 1)
bankButton.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE_BOTTOM + AREA_H + BANK_GAP))
bankButton.Size = UDim2.fromOffset(BANK_W, HudLayout.BANK_H)
bankButton.BackgroundColor3 = POT_RED
bankButton.BackgroundTransparency = 0.15
bankButton.BorderSizePixel = 0
bankButton.AutoButtonColor = false
bankButton.TextColor3 = INK_CREAM
bankButton.TextSize = 15
bankButton.Font = Enum.Font.GothamBold
bankButton.Text = ""
bankButton.Visible = false
bankButton.Parent = gui
corner(bankButton, 8)
stroke(bankButton, GOLD, 1, 0.3)

-- 3^n runs long fast (the old potFigure's note): BANK 19683 POINTS already measures ~150px at
-- 15px GothamBold, and the pot only grows from there. TextScaled + a MaxTextSize constraint lets
-- the label shrink to fit a long figure instead of clipping it.
bankButton.TextScaled = true
do
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 15
    constraint.Parent = bankButton
end

-- Mirrors `view.pot > 0` (the MODEL's pot, not the displayed one) so a tap can be refused once
-- the pot is actually gone — set in `render`, read here. Deliberately NOT tied to the button's
-- own visibility: the button stays visible for the full 0.5s drain because the drain IS the
-- point (see `render`'s call into `setBank`), but that visible window is an animation of
-- something that has ALREADY happened, not a live offer. This is the opposite asymmetry from
-- the ring/plate pair, whose visible window IS their answerable window (`plateVisible`) — here
-- the armed window is the SHORTER of the two, not the same one.
local bankArmed = false

bankButton.MouseButton1Click:Connect(function()
    if not bankArmed then
        return
    end
    EventBus.HudBank:Fire()
end)

-- The pulse says "this is unacknowledged", nothing more. `setBank` runs at 10Hz off `render`
-- (EventBus.HudState), so the tween is touched ONLY when the desired pulsing state actually
-- changes — cancelling and restarting a 0.9s tween every 100ms would give it 3% of its travel
-- and render as a static button with imperceptible jitter, not a pulse. This is why the code
-- this replaced (`setSlot`) guarded its tween the same way.
--
-- `visible` and `pot` are the caller's (`render`, below): `visible` follows the DISPLAYED pot
-- (the counter's current value), not the model's, and `pot` IS the displayed figure — this
-- function paints whatever it's handed and knows nothing about `RollingNumber` itself. `pulses`
-- is still model-driven (`view.potPulses`), and that is what keeps this guard correct without
-- any extra coordination: the model clears `potPulses` (it is gated on `pointsAtStake > 0`) the
-- INSTANT a bank or a loss lands, before the display has counted down at all, so `want = visible
-- and pulses` already goes false at that exact moment — a button lingering at a nonzero
-- DISPLAYED value during the count-down is never left pulsing, because `pulses` itself dropped
-- out from under it on the very same tick the model changed.
local potPulse: Tween? = nil
local pulsing = false
local function setBank(visible: boolean, pot: number, pulses: boolean)
    bankButton.Visible = visible
    if visible then
        bankButton.Text = `BANK {pot} POINTS`
    end
    local want = visible and pulses
    if want == pulsing then
        return
    end
    pulsing = want
    if potPulse then
        potPulse:Cancel()
        potPulse = nil
        bankButton.BackgroundTransparency = 0.15 -- Cancel leaves the property mid-tween
    end
    if want then
        local t = TweenService:Create(
            bankButton,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.6 }
        )
        t:Play()
        potPulse = t
    end
end

-- The targets `render` last handed the counters. The per-frame driver below re-ticks toward
-- these without needing a `view` — `render` keeps sole ownership of WHERE the numbers are going;
-- the driver only advances how far along they are.
local counterPoints, counterStreak, counterPot = 0, 0, 0
local counterPulses = false

local function countersAnimating(): boolean
    return pointsCounter.startedAt ~= nil or streakCounter.startedAt ~= nil or potCounter.startedAt ~= nil
end

-- The ONE place the plate's line and the bank button's figure are painted. Safe to call at any
-- rate: `tickCounter` is keyed on the target CHANGING, so re-invoking it with the target it
-- already has is a no-op re-key that only advances the clock.
--
-- The label shows the DISPLAYED (animating) figures, not the model's — that is the entire point
-- of `tickCounter`. The streak's own "×N" segment tracks the displayed count too, so a streak
-- reset to 0 counts down in view rather than vanishing on the same tick it resets.
local function paintCounters()
    local displayedPoints = tickCounter(pointsCounter, counterPoints)
    local displayedStreak = tickCounter(streakCounter, counterStreak)
    plateLabel.Text = if displayedStreak > 0
        then `×{displayedStreak}  {displayedPoints}`
        else tostring(displayedPoints)

    -- The bank button's VISIBILITY follows the DISPLAYED figure, not the model's: the model's
    -- pot goes to zero the instant a bank lands, and a button that hid on THAT transition would
    -- take the count-down off screen before anyone saw it. `counterPot > 0` stays in the
    -- condition so the button appears on the very first tick a pot exists, even though the
    -- display still reads 0 for that one frame (`RollingNumber.valueAt`'s exact-`from`-at-`t=0`
    -- guarantee).
    local displayedPot = tickCounter(potCounter, counterPot)
    setBank(counterPot > 0 or displayedPot > 0, displayedPot, counterPulses)

    -- Keyed on the POINTS counter alone. The pot draining and the streak resetting are not
    -- payoffs, and lighting the plate for them would spend the effect on nothing.
    --
    -- AND ON ITS DIRECTION. Points go DOWN as well as up: every purchase in the meta-game — a
    -- teahouse, a deck upgrade, a portal, a decoration — debits the balance, and it arrives here on
    -- the next reconciliation as an ordinary target change that re-keys the counter downward. Do
    -- not simplify this back to "the counter is moving": without the direction test, spending 500
    -- points lights the rim gold and turns the figure gold while the number counts DOWN by 500,
    -- which is the exact thing the header of `setCelebrating` forbids. The plate still REVEALS for
    -- a decrease and still holds long enough to read the new balance (`plateHoldSeconds` is
    -- deliberately direction-blind) — it just does not celebrate.
    local pointsRising = pointsCounter.target > pointsCounter.from
    setCelebrating(pointsCounter.startedAt ~= nil and pointsRising)
end

-- 10Hz IS NOT ENOUGH FRAMES TO COUNT WITH (spec §3c). `render` runs off main.client's 10Hz
-- heartbeat: a 0.5s count was 5 frames, brief enough that nobody read the steps, but a 2.2s
-- payoff at that rate is ~22 visible jumps — a number lurching, not counting. So while anything
-- is mid-count it repaints per frame instead.
--
-- The connection is permanent and does nothing once everything has settled, which is nearly all
-- the time. Note the ordering: the check runs BEFORE the paint, so the frame on which a count
-- reaches its target still paints — which is what lets that final paint land the exact value and
-- release any decoration hung on "still counting".
RunService.RenderStepped:Connect(function()
    if countersAnimating() then
        paintCounters()
    end
end)

-- The hamburger is gone (spec §6). Roblox's own unibar already owns that glyph top-left, so a
-- second one bottom-right read as either the same menu or a broken copy — ours was the fake
-- one. The ring inherited the gesture: it IS the round, and since the LAST ROUND band the
-- ledger is the round's detail.

-- ===== The round-timer ring: the ledger's door (spec §5, §6) =====
-- The PWA's PieTimer, rebuilt. Roblox has no SVG and no radial fill, so the sweep is a track
-- circle and two gradient-cut half-discs — RingTimer owns the angles, this owns the instances
-- and paints what it is told. Green while there is time, red at HudModel.ESCALATE_AT, which is
-- the SAME constant the escalation prompt reads: two signals about one fact must not turn
-- urgent at different moments.
--
-- It takes the HAMBURGER's old slot: inboard-left of the throw cluster, bottom-aligned with the
-- button row — `throwArea` spans [EDGE_BOTTOM, EDGE_BOTTOM + AREA_H] from the gui's bottom edge,
-- and the buttons sit at the TOP of that frame, so the button row's own bottom edge is
-- EDGE_BOTTOM + AREA_H - BTN_H from the bottom. Inboard of the throw cluster by AREA_W + RING_GAP,
-- off the SAME right edge (1 - JUMP_CLEARANCE) everything else in the cluster registers to. This
-- is now the ONLY door beside the plate — the hamburger it replaced is deleted.
--
-- A BUTTON, not a Frame: only the outer button sinks. Its pie layers and the centred readout all
-- stay Active = false (Frames/TextLabels already default there — see the file header), the same
-- interactive cost the hamburger carried in the same row.
local RING_D = if TOUCH then HudLayout.RING_D_TOUCH else HudLayout.RING_D
local RING_THICKNESS = if TOUCH then HudLayout.RING_THICKNESS_TOUCH else HudLayout.RING_THICKNESS
-- The pie pulls in from the backing square's edge by this much. 3, down from 4: with the
-- faceting gone the arc no longer needs the extra breathing room a ragged outer edge wanted.
local RING_INSET = 3
local RING_OD = RING_D - 2 * RING_INSET
local RING_DISC_D = RING_OD - 2 * RING_THICKNESS

local RING_TRACK = Color3.fromRGB(38, 36, 42)
local RING_LIVE = Color3.fromRGB(76, 187, 106)
local RING_HOT = LOSS_RED

local ring = Instance.new("TextButton")
ring.Name = "RoundRing"
ring.AutoButtonColor = false
ring.Text = ""
ring.AnchorPoint = Vector2.new(1, 1)
-- The hamburger's slot, exactly: inboard of the cluster by AREA_W + RING_GAP, off the SAME
-- right edge (1 - JUMP_CLEARANCE) everything else in the cluster registers to; bottom-aligned
-- with the throw BUTTON row's own bottom edge (EDGE_BOTTOM + AREA_H - BTN_H from the gui's
-- bottom), not the tape's.
ring.Position = UDim2.new(1 - JUMP_CLEARANCE, -(AREA_W + RING_GAP), 1, -(EDGE_BOTTOM + AREA_H - BTN_H))
ring.Size = UDim2.fromOffset(RING_D, RING_D)
-- The backing (owner's gate, design §5 "The ring sits on a backing"): a thin arc had nothing to
-- hold it against the moving canyon. WASHI at 0.3 — exactly the hamburger's own fill before Task
-- 5 deleted it (`ledgerButton.BackgroundColor3 = WASHI, BackgroundTransparency = 0.3`), and the
-- SAME fill the plate, the bank button and the escalation prompt all use. The ring replaced the
-- hamburger, so it inherits its treatment rather than borrowing IVORY_DIM — that colour is the
-- throw buttons' DISABLED state (see `-- starts disabled` below and `paintThrows`'s can't-throw
-- branch), and painting the ring with it would read as a permanently greyed-out button beside
-- three buttons that use that exact fill to mean "you can't press this". Same corner radius as a
-- throw button (`corner(b, 8)` below) so the row still reads as four elements of one family —
-- painted directly on the button itself, not a separate sibling frame.
ring.BackgroundColor3 = WASHI
ring.BackgroundTransparency = 0.3
ring.Parent = gui
corner(ring, 8)

-- A concentric circle inside the ring button. UICorner at scale 0.5 is a true, antialiased
-- circle at any diameter — which is the whole reason this construction replaces 36 rotated
-- rectangles. Active = false: the ring BUTTON sinks, nothing inside it does.
local function ringCircle(diameter: number, color: Color3, zIndex: number, name: string?): Frame
    local f = Instance.new("Frame")
    if name then
        f.Name = name
    end
    f.Active = false
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale(0.5, 0.5)
    f.Size = UDim2.fromOffset(diameter, diameter)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = zIndex
    f.Parent = ring
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0.5, 0)
    c.Parent = f
    return f
end

-- A half-disc: a full circle whose UIGradient.Transparency steps hard at offset 0.5, so only
-- half of it paints. Rotating the GRADIENT (never the Frame) sweeps the cut. See RingTimer's
-- header for the angle derivation: UIGradient.Rotation = arcStart + 180.
local function ringHalf(diameter: number, color: Color3, zIndex: number, name: string?): (Frame, UIGradient)
    local f = ringCircle(diameter, color, zIndex, name)
    local g = Instance.new("UIGradient")
    -- 0.4999 -> 0.5 rather than a single keypoint: NumberSequence interpolates between
    -- keypoints, so the step has to be narrow rather than instantaneous. At this width the
    -- ramp is well under a pixel.
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.4999, 0),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
    g.Parent = f
    return f, g
end

-- ZIndex is load-bearing here, not decoration: half B paints back over half A, and the disc
-- punches the annulus out of both. Siblings at equal ZIndex have no defined order.
ringCircle(RING_OD, RING_TRACK, 1, "Track")
local ringHalfA, ringGradA = ringHalf(RING_OD, RING_LIVE, 2, "SweepA")
local ringHalfB, ringGradB = ringHalf(RING_OD, RING_TRACK, 3, "SweepB")

-- The centre. OPAQUE, and that is a requirement rather than a preference: the pie behind it is
-- solid, so at the old 0.15 the sweep bleeds through as a hard seam straight across the digits
-- (observed in the Studio prototype, 2026-08-04). It costs nothing — WASHI is near-black
-- (26, 24, 28), so INK_CREAM digits GAIN contrast against it.
--
-- Its diameter is what defines the band: RING_OD - 2 * RING_THICKNESS. The old 2px
-- RING_DISC_GAP is deleted, because it existed only to hold the disc clear of the segments'
-- ragged inner edge, and the pie's inner edge is exact.
local ringDisc = ringCircle(RING_DISC_D, WASHI, 4)
ringDisc.Name = "Disc"
ringDisc.BackgroundTransparency = 0

-- The centred readout: the remaining seconds, swapping to the world-throw glyph once the drum
-- has settled on it (see `render`'s `aux.worldThrow` branch, and `main.client.luau`'s drum-rest
-- gate).
local ringCount = Instance.new("TextLabel")
ringCount.Name = "Count"
ringCount.Active = false
ringCount.Size = UDim2.fromScale(1, 1)
ringCount.BackgroundTransparency = 1
ringCount.TextColor3 = INK_CREAM
ringCount.ZIndex = 5
-- FIXED TextSize, not TextScaled: the countdown runs 20 -> 1, and TextScaled would visibly jump
-- the digits' size at the two-to-one-character boundary every single round. Two digits at 20px
-- clear a 32px disc; at 34px they clear a 60px one.
--
-- GothamBold, down from GothamBlack (owner's gate 2026-08-04). Weight was the lever, not size —
-- a one-point reduction was indistinguishable at both tiers. Bold rather than Medium because at
-- 20px over moving canyon terrain the lighter face thins out, and the phone is the tier that
-- has to survive a busy background. The ring's readout only; nothing else in the HUD moves.
ringCount.TextSize = if TOUCH then 20 else 34
ringCount.Font = Enum.Font.GothamBold
ringCount.Text = ""
ringCount.Parent = ringDisc
-- No UIStroke on this label. Contrast comes from `ringDisc`'s opaque backing above.

-- OPTICAL CENTRING, not a fudge. Roblox centres the LINE BOX, which reserves room for
-- descenders; digits have none, so a vertically centred box seats them low by roughly half a
-- descender. Every value this label ever shows is digits, so the correction is unconditional.
-- Derived from TextSize rather than a literal pair, so a future size change carries its own
-- correction: 2px at 34 (desktop), 1px at 20 (touch).
local COUNT_NUDGE = math.max(1, math.round(ringCount.TextSize * 0.06))
ringCount.AnchorPoint = Vector2.new(0.5, 0.5)
ringCount.Position = UDim2.new(0.5, 0, 0.5, -COUNT_NUDGE)

-- One glyph box per symbol, built ONCE — same pattern `glyphSet` uses for the tape tiles — so
-- the reveal can show whichever the world threw without rebuilding an ImageLabel every round.
local ringGlyphs: { [string]: Frame } = {}
do
    local box = glyphBox(ringDisc, 0.82)
    box.ZIndex = 5 -- with the digits, above the disc
    for _, sym in THROWS do
        local g = Glyphs.render(box, sym, INK_CREAM)
        g.Visible = false
        ringGlyphs[sym] = g
    end
end

local ringScale = Instance.new("UIScale")
ringScale.Parent = ring

-- THE HAMBURGER'S TWO-STAGE GESTURE, inherited unchanged: the first tap reveals the plate, and a
-- tap while the plate is still on screen — the hold or the fade, `plateVisible` covers both —
-- fires EventBus.OpenLedger instead. A tap that lands after the plate has fully faded reveals
-- again, so a double-tap from cold opens the ledger without anyone having to learn the two
-- stages to reach it the obvious way. The plate (above) answers the SAME two taps once it is
-- showing, so the ledger has two doors, never a third.
ring.MouseButton1Down:Connect(function()
    pressDepress(ringScale)
end)
ring.MouseButton1Click:Connect(function()
    if plateVisible then
        EventBus.OpenLedger:Fire()
    else
        revealPlate()
    end
end)

-- The bottom-edge hairline is gone (spec §7): the ring is the round's clock now, and with the
-- hairline gone the cluster no longer needs to clear it — see EDGE_BOTTOM, above.

-- ===== Escalation: a large centred count, shown only when HudModel says so =====
-- THE ONE SINKING ELEMENT that is not a control. Everything else on this surface stays
-- Active = false, because every sinking pixel is a permanent hole in the camera-drag surface.
-- This is the exception the owner asked for: "the worst thing that could happen is it gets
-- thrown into a user's view in the middle of watching fireworks." It is small, it exists only in
-- the last few seconds of a round and only when armed, and dismissing it is the entire point.
-- The arming rule lives in HudModel and is never second-guessed here.
--
-- Halved from the previous branch's 154/92/30/84/24 (count/prompt heights and text sizes): the
-- footprint shrinks, not the prompt's legibility, so the prompt drops 24 -> 16 rather than 12.
-- Content box (ESCALATION_H minus the 24px the UIPadding below eats, 12 top + 12 bottom) must fit
-- escalationCount's height + escalationPrompt's height + a visible gap between them:
--   count  [0, 46]   (was TextSize 84/height 92, now 42/46)
--   gap    [46, 54]  (8px, unchanged from the previous branch)
--   prompt [54, 74]  (was TextSize 24/height 30, now 16/20)
-- Content box needed = 74, so ESCALATION_H = 74 + 24 = 98, not the naively-halved 77 (77 - 24 =
-- 53 content px, which doesn't even fit the two labels with zero gap: 46 + 20 = 66 > 53).
local ESCALATION_H = 98 -- kept as a named constant: updateEscalationPosition needs it too, below

-- WIDTH IS THE LEVER, not height. The height cannot halve: 42px of count plus a 16px prompt plus
-- 12px padding all round has a hard floor of 98. The width had no such floor — it was 80% of the
-- screen to hold ~130px of content, which on a landscape phone is a 675px panel for a two-line
-- message. A fixed width sized to the content is what actually makes this stop dominating the
-- view, which is what the owner asked for: "the worst thing that could happen is it gets thrown
-- into a user's view in the middle of watching fireworks."
-- 210 verified against its content box (210 - 24 = 186px): "CHOOSE A THROW" at 16px GothamBold is
-- ~126-146px (14 characters; c.f. undoLabel's own measured ~8-9px/char for GothamBold), which
-- clears with 40-60px to spare. escalationPrompt also carries TextScaled + a MaxTextSize
-- constraint below as a floor, not because 210 is expected to be tight — the same belt-and-braces
-- pattern undoLabel uses — so a font-metrics surprise shrinks the text instead of truncating it.
local ESCALATION_W = 210

local escalation = Instance.new("TextButton")
escalation.Name = "Escalation"
escalation.Text = ""
escalation.AutoButtonColor = false
escalation.Selectable = false
escalation.AnchorPoint = Vector2.new(0.5, 0.5)
-- Y is set by `updateEscalationPosition`, below, not a bare fromScale(0.5, 0.42): that fraction
-- is the resting position on a tall screen, but on a short landscape phone it collides with the
-- bank button. See `updateEscalationPosition` for the clamp.
escalation.Position = UDim2.fromScale(0.5, 0.42)
-- Fixed width (ESCALATION_W, above) sized to the content, not a screen fraction — see the
-- arithmetic there. Fixed height is ESCALATION_H, derived above from its two children's content
-- box. If either child's TextSize/height or the padding below changes, re-run that arithmetic or
-- the two labels overlap inside the unchanged content box. AnchorPoint (0.5, 0.5) plus a
-- Scale-0.5 X position (both offset components below are Y-only) keeps a fixed-width frame
-- centred exactly the same as a scale-width one.
escalation.Size = UDim2.fromOffset(ESCALATION_W, ESCALATION_H)
-- Opaque backing, not a stroke on the text. The count and prompt used to float over open
-- canyon with strokes standing in for contrast (see the spec's §3) — a real backing plate
-- instead, same as every other readable surface in this HUD.
escalation.BackgroundColor3 = WASHI
escalation.BackgroundTransparency = 0.1
escalation.Visible = false
escalation.Parent = gui
corner(escalation, 10)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = escalation
end

local escalationCount = Instance.new("TextLabel")
escalationCount.Name = "Count"
escalationCount.Active = false
escalationCount.Size = UDim2.new(1, 0, 0, 46)
escalationCount.BackgroundTransparency = 1
escalationCount.TextColor3 = INK_CREAM
escalationCount.TextSize = 42
escalationCount.Font = Enum.Font.GothamBlack
escalationCount.Text = ""
escalationCount.Parent = escalation
-- No UIStroke on the label. Contrast comes from the opaque WASHI backing on `escalation` above
-- (see the spec's §3) — a stroke here would outline every glyph instead.

local escalationPrompt = Instance.new("TextLabel")
escalationPrompt.Name = "Prompt"
escalationPrompt.Active = false
escalationPrompt.AnchorPoint = Vector2.new(0.5, 1)
escalationPrompt.Position = UDim2.fromScale(0.5, 1)
escalationPrompt.Size = UDim2.new(1, 0, 0, 20)
escalationPrompt.BackgroundTransparency = 1
escalationPrompt.TextColor3 = INK_CREAM
escalationPrompt.TextSize = 16
escalationPrompt.Font = Enum.Font.GothamBold
escalationPrompt.Text = "CHOOSE A THROW"
escalationPrompt.Parent = escalation
-- Belt-and-braces, same pattern as `undoLabel` above: 16px comfortably fits the 186px content
-- box by estimate (see ESCALATION_W above), but TextScaled + a MaxTextSize constraint means a
-- font-metrics surprise shrinks the text instead of truncating it, and never grows past 16px.
escalationPrompt.TextScaled = true
do
    local constraint = Instance.new("UITextSizeConstraint")
    constraint.MaxTextSize = 16
    constraint.Parent = escalationPrompt
end
-- No UIStroke on the label — same rationale as escalationCount above.

local escalationScale = Instance.new("UIScale")
escalationScale.Parent = escalation

-- Tapping dismisses it for the rest of the round. Dismissing and backing out mean the same thing
-- to the escalation rule (HudModel.applyTap already widened `declinedThisRound` to cover both), so
-- this does NOT introduce a new field — main.client.luau sets the existing one.
escalation.MouseButton1Down:Connect(function()
    pressDepress(escalationScale)
end)
escalation.MouseButton1Click:Connect(function()
    EventBus.DismissEscalation:Fire()
end)

-- Clamp the overlay's Y against the cluster instead of trusting the 0.42 scale fraction on every
-- viewport. `gui.AbsoluteSize.Y` already excludes the topbar inset (ScreenGui's default
-- IgnoresGuiInset = false), so it is the same H a hand check against a device's reported
-- viewport height would use. Resting position is 0.42 * H; the clamp keeps the overlay's own
-- BOTTOM edge at least ESCALATION_MARGIN above the cluster's top edge (CLUSTER_TOP_FROM_BOTTOM,
-- from the bottom of the screen), and the smaller of the two wins. On a tall screen the clamp
-- never binds, so this reduces to the original 0.42 fraction; on a short landscape phone it
-- lifts the overlay clear of the bank button instead of trusting a fraction that only ever held
-- at the reviewer's own reference height.
local ESCALATION_MARGIN = ROW_GAP -- the same "cluster row" gap used everywhere else in this file
local function updateEscalationPosition()
    local h = gui.AbsoluteSize.Y
    if h <= 0 then
        return -- not laid out yet; AbsoluteSize firing again once it is will re-run this
    end
    local resting = 0.42 * h
    local clamped = h - CLUSTER_TOP_FROM_BOTTOM - ESCALATION_MARGIN - ESCALATION_H / 2
    escalation.Position = UDim2.new(0.5, 0, 0, math.min(resting, clamped))
end
updateEscalationPosition()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateEscalationPosition)

-- ===== Toast: the transient notice that replaced the persistent prose ticker =====
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
-- The plate has vacated top-centre entirely (first for the right margin, then the bottom row),
-- so there is nothing left to offset against up here. Sits at EDGE, the band the plate vacated.
toast.Position = UDim2.new(0.5, 0, 0, EDGE)
toast.Size = UDim2.new(0.5, 0, 0, 26)
toast.AutomaticSize = Enum.AutomaticSize.Y -- a long notice wraps and grows rather than clipping
toast.BackgroundColor3 = WASHI
toast.BackgroundTransparency = 0.05
toast.BorderSizePixel = 0
toast.TextColor3 = INK_CREAM
toast.TextSize = 15
toast.TextWrapped = true
toast.Font = Enum.Font.Gotham
toast.Text = ""
toast.Visible = false
toast.Parent = gui
corner(toast, 6)
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = toast
end

local toastQueue: { string } = {}
local function enqueueToast(line: string)
    if typeof(line) ~= "string" or line == "" then
        return
    end
    if #toastQueue >= TOAST_MAX then
        table.remove(toastQueue, 1)
    end
    table.insert(toastQueue, line)
end

EventBus.Toast.Event:Connect(enqueueToast)
-- TickerMessage's last renderer was the prose ticker this HUD replaced (BoardController's
-- jumbotron no longer exists). EconomyController still fires it with real player-facing notices,
-- so route it here rather than dropping those on the floor.
EventBus.TickerMessage.Event:Connect(enqueueToast)

task.spawn(function()
    while true do
        if #toastQueue > 0 then
            toast.Text = table.remove(toastQueue, 1) :: string
            toast.Visible = true
            task.wait(TOAST_SECONDS)
            if #toastQueue == 0 then
                toast.Visible = false
            end
        else
            task.wait(0.2)
        end
    end
end)

-- ===== Render =====
-- The round's full span is not on the wire; take it from the largest countdown seen since ACTIVE
-- opened, so the ring depletes against the real round length whatever the server's phase
-- durations are.
local span = 0
local lastPhase = ""

-- Start at nil, not 0/false: the very first render has nothing to compare against, and treating
-- "no prior value" as a change would auto-reveal the plate the instant the HUD loads, which is
-- exactly the "normally hidden" rule being broken on frame one.
local lastPlatePoints: number? = nil
local lastPlateStreak: number? = nil

-- Latched the first time `aux.profileSeen` comes through true — see `seedCounter`. A flag rather
-- than re-reading `aux.profileSeen` each render because the seed must happen ONCE: it stays true
-- for every render afterwards, and re-seeding would pin the counters at their targets forever and
-- nothing would ever count again.
local countersSeeded = false

local function render(inputs: any, aux: any)
    local view = HudModel.view(inputs, aux.session)
    canThrow = view.throwsEnabled
    chosenSym = view.chosen

    counterPoints = view.plate.points
    counterStreak = view.plate.streak
    counterPot = view.pot
    counterPulses = view.potPulses
    -- THE PROFILE'S ARRIVAL SEEDS RATHER THAN COUNTS — see `seedCounter`. Keyed on
    -- `aux.profileSeen`, the wiring's own "the server has answered" fact, NOT on this being the
    -- first render: the 10Hz heartbeat starts publishing placeholder zeros long before the join
    -- fetch returns, so "first render" seeded 0 and turned the balance's arrival into a count.
    local seededNow = false
    if not countersSeeded and aux.profileSeen == true then
        countersSeeded = true
        seededNow = true
        seedCounter(pointsCounter, counterPoints)
        seedCounter(streakCounter, counterStreak)
        seedCounter(potCounter, counterPot)
    end
    paintCounters()

    -- Reveal is keyed on the TARGET having changed, not on `render` running: `render` is a 10Hz
    -- repaint, and a reveal re-armed every tick would hold forever and never fade — precisely how
    -- the bank pulse (`setBank`, below) failed when it wasn't guarded this way.
    --
    -- ARMED AFTER `paintCounters`, and that ordering is load-bearing: `revealPlate` sizes its hold
    -- from the points counter's CURRENT leg (`plateHoldSeconds`), and before the paint has re-keyed
    -- the counter, `startedAt` and `duration` still describe the previous one.
    --
    -- AND NOT ON THE SEEDING RENDER. That render is where the placeholder zeros are replaced by
    -- the balance the player already had, so `view.plate.points` legitimately differs from the
    -- last one — but nothing MOVED, and a plate that reveals itself unprompted on join is the
    -- "normally hidden" rule broken on arrival. `lastPlatePoints ~= nil` still covers the very
    -- first render; `seededNow` covers the one the profile lands on. If the profile never lands
    -- there is no seeding render, and every change reveals exactly as it does today.
    if
        not seededNow
        and lastPlatePoints ~= nil
        and (view.plate.points ~= lastPlatePoints or view.plate.streak ~= lastPlateStreak)
    then
        revealPlate()
    end
    lastPlatePoints = view.plate.points
    lastPlateStreak = view.plate.streak

    -- Armed follows the MODEL's pot, not the displayed one: the button stays VISIBLE through the
    -- drain (that's the animation), but a tap on it once the model has already emptied the pot
    -- must not send a live BankRequest for something that no longer exists.
    bankArmed = view.pot > 0

    -- The authoritative choice wins; until it has come back through main.client a press keeps
    -- its own tile lit (`pressedSym`), so a held finger does not flicker the light off on the
    -- next 10Hz repaint.
    if view.chosen then
        pressedSym = nil
    end
    local lit = view.chosen or pressedSym
    paintThrows(lit, view.throwsEnabled, view.undoPrompt)
    setChosenPulse(if view.throwsEnabled then lit else nil)
    setUndoPrompt(view.undoPrompt)

    local entries = aux.tape or {}
    local count = math.min(#entries, TAPE_N)
    for i = 1, TAPE_N do
        local slot = tapeTiles[i]
        local entry = entries[i]
        slot.frame.Visible = entry ~= nil
        if entry then
            -- Age across the VISIBLE count so the oldest shown always reaches full amber: a clear
            -- newest -> oldest gradient even when only a few rounds are in the tape.
            slot.frame.BackgroundColor3 = IVORY:Lerp(AGED_IVORY, (i - 1) / math.max(1, count - 1))
            for _, sym in THROWS do
                slot.glyphs[sym].Visible = sym == entry.worldThrow
            end
            if entry.result == "WIN" then
                slot.badge.BackgroundColor3 = WIN_GREEN
                slot.badge.Visible = true
            elseif entry.result == "LOSS" then
                slot.badge.BackgroundColor3 = LOSS_RED
                slot.badge.Visible = true
            elseif entry.result == "SAFE" then
                slot.badge.BackgroundColor3 = GOLD
                slot.badge.Visible = true
            else
                slot.badge.Visible = false
            end
        end
    end

    -- A round with no lockout on the wire has no span to deplete against. Showing a constant
    -- would pin the ring full and motionless while the real lockout came and went, which reads
    -- as "plenty of time" and is a lie. Track nothing new in that case; the ring below decides
    -- what to show from whatever `span` it already has.
    if lastPhase ~= inputs.phase then
        span = 0
    end
    if inputs.phase == "ACTIVE" and aux.timerKnown ~= false then
        span = math.max(span, view.secondsLeft)
    end
    lastPhase = inputs.phase

    -- The ring. Where the countdown is unknown (`aux.timerKnown == false`, or the phase isn't
    -- ACTIVE, or nothing has been tracked yet), light NOTHING and blank the digits — a full ring
    -- that never moves would read as "plenty of time" and be a lie.
    local ringKnown = inputs.phase == "ACTIVE" and aux.timerKnown ~= false and span > 0
    local ringFrac = if ringKnown then math.clamp(view.secondsLeft / span, 0, 1) else 0
    local ringHot = RingTimer.isWarning(view.secondsLeft, HudModel.ESCALATE_AT)
    local ringLit = if ringHot then RING_HOT else RING_LIVE
    local sweep = RingTimer.sweep(ringFrac)
    ringGradA.Rotation = sweep.rotationA
    ringGradB.Rotation = sweep.rotationB
    ringHalfA.BackgroundColor3 = ringLit
    ringHalfB.BackgroundColor3 = if sweep.bLit then ringLit else RING_TRACK
    ringCount.TextColor3 = if ringHot then RING_HOT else INK_CREAM

    -- The glyph swap: the world's throw appears in the ring's centre only once the drum has
    -- settled (main.client.luau's drum-rest gate, inherited via `aux.worldThrow` rather than a
    -- second spoiler gate here). Digits and glyph are mutually exclusive.
    local worldThrow = aux.worldThrow
    ringCount.Visible = worldThrow == nil
    ringCount.Text = if worldThrow == nil and ringKnown then tostring(math.ceil(view.secondsLeft)) else ""
    for _, sym in THROWS do
        ringGlyphs[sym].Visible = sym == worldThrow
    end

    escalation.Visible = view.escalate
    if view.escalate then
        escalationCount.Text = tostring(math.ceil(view.secondsLeft))
    end
end

EventBus.HudState.Event:Connect(render)

-- ===== Day/night contrast: authored against night, kept legible as day comes up =====
-- The ivory/washi palette above is authored against the dark canyon (DayNightLockT pins the
-- owner's dusk look at 0.40 — not ours to change here). As nightFactor falls toward day the
-- canyon goes pale and that palette loses contrast. This darkens the plate backing and deepens
-- the tape-tile rims to hold legibility across the cycle; it is a contrast pass, not a second
-- visual design, and nothing here moves geometry.
--
-- Scope is deliberately the two elements render() never writes: the plate's own backing, and
-- each tape tile's UIStroke. render() repaints the throw buttons' fill/rim and the tape tiles'
-- fill every call for game-state reasons (selection, ageing) unrelated to time of day — driving
-- those same properties here would just get overwritten on the next HudState event.
--
-- Dual subscription, same as WaterVfxDayNight/YamadoroDayNight/PaperLanternDayNight/
-- AmbientDayNight: EventBus.DayNight for live updates, plus the DayNightConfig
-- CurrentNightFactor attribute as a start-order-proof prime + backstop, since this controller
-- can build after the day/night controller's last fire.
--
-- Capture authored values ONCE, on an attribute, and always re-derive from that capture — same
-- rule as WaterVfxDayNight. Reading back a live property would read whatever the previous apply
-- just wrote, compounding a little further on every dusk. And always LERP toward the day target,
-- never scale: VfxNightDim's lesson is that an authored value of zero can never be moved by
-- multiplication, so lerp is the only operation that stays correct regardless of what gets
-- authored here later, even though today's authored numbers all happen to be non-zero.
local dayNightConfig = ReplicatedStorage:WaitForChild("DayNightConfig")

local PLATE_DAY_TRANSPARENCY = 0.05 -- authored (night) is 0.3; more opaque reads darker against a pale sky
local RIM_DAY_COLOR = INK -- authored (night) is TAN_RIM, too pale to hold a line at noon
local RIM_DAY_THICKNESS = 2 -- authored (night) is 1
local RIM_DAY_TRANSPARENCY = 0.05 -- authored (night) is 0.3

local AUTHORED_TRANSPARENCY = "AuthoredTransparency"
local AUTHORED_THICKNESS = "AuthoredThickness"
local AUTHORED_COLOR = "AuthoredColor"

local function captureNumber(inst: Instance, key: string, live: number): number
    local stored = inst:GetAttribute(key)
    if typeof(stored) == "number" then
        return stored
    end
    inst:SetAttribute(key, live)
    return live
end

local function captureColor(inst: Instance, key: string, live: Color3): Color3
    local stored = inst:GetAttribute(key)
    if typeof(stored) == "Color3" then
        return stored
    end
    inst:SetAttribute(key, live)
    return live
end

local function lerpNumber(a: number, b: number, t: number): number
    return a + (b - a) * t
end

local nightFactor: number = dayNightConfig:GetAttribute("CurrentNightFactor") or 0

local function applyContrast()
    -- `plateRestTransparency`, not `plate.BackgroundTransparency`, is both the capture source and
    -- the write target here: the live property now spends most of its time either at 1 (hidden)
    -- or mid-fade, neither of which is the "authored" value this pass needs. `revealPlate` reads
    -- `plateRestTransparency` back when it shows the plate, so a reveal during full daylight uses
    -- the current day/night value rather than a stale one baked in at construction. The CAPTURE
    -- must stay unconditional and must keep reading `plateRestTransparency`, never the live
    -- property — a fade-driven `1` must never be captured as "authored".
    local plateAuthored = captureNumber(plate, AUTHORED_TRANSPARENCY, plateRestTransparency)
    plateRestTransparency = lerpNumber(PLATE_DAY_TRANSPARENCY, plateAuthored, nightFactor)
    -- The WRITE, unlike the capture, is guarded: `plateFadeTweens` is non-empty only between
    -- `startPlateFade` and the next `cancelPlateFade`, i.e. exactly while a fade owns this
    -- property. TweenService redrives `BackgroundTransparency` from ITS OWN stored start value
    -- every frame, so an unconditional write here would still let the fade finish — but it would
    -- also win for up to one frame, showing a flash of rest-transparency mid-fade while the text
    -- and stroke (which this pass never touches) kept fading smoothly. Skipping the write during
    -- a fade costs nothing: once the fade completes the plate is `Visible = false`, and the next
    -- `revealPlate` sets the property explicitly anyway.
    if #plateFadeTweens == 0 then
        plate.BackgroundTransparency = plateRestTransparency
    end

    for _, tile in tapeTiles do
        local rim = tile.rim
        local authoredColor = captureColor(rim, AUTHORED_COLOR, rim.Color)
        local authoredThickness = captureNumber(rim, AUTHORED_THICKNESS, rim.Thickness)
        local authoredTransparency = captureNumber(rim, AUTHORED_TRANSPARENCY, rim.Transparency)

        rim.Color = RIM_DAY_COLOR:Lerp(authoredColor, nightFactor)
        rim.Thickness = lerpNumber(RIM_DAY_THICKNESS, authoredThickness, nightFactor)
        rim.Transparency = lerpNumber(RIM_DAY_TRANSPARENCY, authoredTransparency, nightFactor)
    end
end

applyContrast() -- prime before the first EventBus fire

EventBus.DayNight.Event:Connect(function(payload)
    nightFactor = payload.nightFactor
    applyContrast()
end)

dayNightConfig:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    nightFactor = dayNightConfig:GetAttribute("CurrentNightFactor") or nightFactor
    applyContrast()
end)
