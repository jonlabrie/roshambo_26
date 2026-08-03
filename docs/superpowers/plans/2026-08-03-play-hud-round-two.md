# Play HUD Round Two Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a PWA-style circular round timer, turn results into a standalone splash, move round
detail into the ledger, and make the HUD smaller and easier to dismiss.

**Architecture:** One new pure module (`RingTimer`) and one new controller
(`SplashController`). `HudModel` gains a shared `ESCALATE_AT` so the ring and the escalation
prompt cannot disagree. Everything else is change to `HudController`, `LedgerController` and the
preference plumbing.

**Spec:** `docs/superpowers/specs/2026-08-03-play-hud-round-two-design.md` — read the relevant §
before each task.

## Global Constraints

- **TDD.** Failing test first, then implementation. Never write implementation before a test that
  fails without it.
- **`roblox/src/shared` modules are pure**: no Roblox globals (`game`, `workspace`, `task`,
  `Instance`, `UDim2`, `Vector2`, `os.clock`), never `require` each other, must run under Lune.
  Standard Lua (`math`, `table`) is fine.
- **`UIStroke` never goes on a `TextLabel`.** Contrast comes from an opaque backing.
- **Non-interactive elements leave `Active = false`.** The single exception this plan introduces
  is the escalation prompt (Task 6), because dismissing it is the point.
- **`main.client.luau` contains no `Instance.new`.**
- **`math.clamp` errors in Luau when min > max.** Guard every clamp with derived bounds.
- Gates from `roblox/`: `lune run tests/run`, `stylua --check src tests tools`, `selene src tools`
  (**selene fails on warnings**). From `server/`: `npm test`.
- Server tests live beside their subjects.
- Commit after every task.

## THE STANDING CHECK — every task that touches a `.client.luau` file

No gate can load those files. Lune never requires them, selene does not resolve cross-module
field types, stylua only formats. This branch has already shipped two non-loading controllers, a
tween that never ran, an overlay whose padding stacked its own labels, a card on the movement
thumbstick, and a panel leaking taps to live buttons. **Before committing, every such task must:**

```bash
cd roblox
grep -n "HudLayout\.[A-Za-z_]*" src/client/<file>          # left side
grep -n "^HudLayout\.[A-Za-z_]* =" src/shared/HudLayout.luau  # right side
```
Every field on the left must appear on the right. Do the same for every `view.X` / `aux.X` read
against `HudModel.View` and the `aux` table in `main.client.luau`'s `publish()`, and for any other
shared module. Confirm every local is declared before first use — a forward reference resolves to
a nil global. **Report both reconciliations.**

**Geometry changes stack in this plan.** Tasks 3–6 all move the same bottom band. Each states its
arithmetic at **both** size tiers rather than trusting the task before it.

---

### Task 1: `RingTimer` — the segmented sweep

**Files:** Create `roblox/src/shared/RingTimer.luau`, `roblox/tests/RingTimer.spec.luau`.

**Interfaces:**
- Produces: `RingTimer.SEGMENTS` (36), `RingTimer.lit(fraction, segments): number`,
  `RingTimer.angleAt(index, segments): number`, `RingTimer.isWarning(secondsLeft, escalateAt): boolean`,
  `RingTimer.segmentWidth(radius, segments): number`

- [ ] **Step 1: Write the failing tests**

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RingTimer = require("../src/shared/RingTimer")

local N = RingTimer.SEGMENTS

describe("RingTimer.lit — how much of the ring is still there", function()
    test("a full round lights every segment", function()
        expect(RingTimer.lit(1, N)).toBe(N)
    end)

    test("an empty round lights none — the ring is GONE, not one-segment-left", function()
        expect(RingTimer.lit(0, N)).toBe(0)
    end)

    test("any time remaining leaves at least one segment lit", function()
        -- A player with a sliver of a second must not see an empty ring: the round is still open
        -- and the throw buttons are still live.
        expect(RingTimer.lit(0.0001, N)).toBe(1)
    end)

    test("half a round lights half the ring", function()
        expect(RingTimer.lit(0.5, N)).toBe(N // 2)
    end)

    test("it is monotonic and never exceeds the count", function()
        local prev = -1
        for i = 0, 100 do
            local v = RingTimer.lit(i / 100, N)
            expect(v >= prev).toBe(true)
            expect(v <= N).toBe(true)
            expect(v >= 0).toBe(true)
            prev = v
        end
    end)

    test("a fraction outside [0,1] clamps rather than extrapolating", function()
        expect(RingTimer.lit(-3, N)).toBe(0)
        expect(RingTimer.lit(9, N)).toBe(N)
    end)
end)

describe("RingTimer.angleAt — segment 1 is at the top, sweeping clockwise", function()
    test("the first segment sits at 0 degrees", function()
        expect(RingTimer.angleAt(1, N)).toBe(0)
    end)

    test("segments are evenly spaced over a full turn", function()
        expect(RingTimer.angleAt(2, N)).toBe(360 / N)
        expect(RingTimer.angleAt(N, N)).toBe(360 - 360 / N)
    end)

    test("no segment reaches a full turn — that would overlap segment 1", function()
        for i = 1, N do
            expect(RingTimer.angleAt(i, N) < 360).toBe(true)
        end
    end)
end)

describe("RingTimer.isWarning", function()
    test("it warns at and below the threshold", function()
        expect(RingTimer.isWarning(5, 5)).toBe(true)
        expect(RingTimer.isWarning(1, 5)).toBe(true)
    end)

    test("it does not warn above the threshold", function()
        expect(RingTimer.isWarning(5.01, 5)).toBe(false)
        expect(RingTimer.isWarning(20, 5)).toBe(false)
    end)
end)

describe("RingTimer.segmentWidth — segments overlap so the ring reads solid", function()
    test("a segment is at least as wide as its share of the circumference", function()
        local pitch = 2 * math.pi * 23 / N
        expect(RingTimer.segmentWidth(23, N) >= pitch).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run from `roblox/`: `lune run tests/run` — expect FAIL, module missing.

- [ ] **Step 3: Implement**

```luau
--!strict
-- The round timer's ring, as arithmetic. Roblox has no SVG and no radial fill, so the PWA's
-- stroke-dash sweep (src/components/PieTimer.tsx) becomes a ring of discrete segments, lit from
-- the top clockwise. Which segments are lit is pure and lives here; HudController only paints
-- what it is told.
--
-- No Roblox globals — this runs under Lune like everything else in src/shared.
local RingTimer = {}

-- 36 segments = one every 10 degrees. Enough to read as a ring at 54px; few enough that the
-- controller builds 36 Frames once and only recolours them thereafter.
RingTimer.SEGMENTS = 36

-- How many segments are lit for `fraction` of the round remaining.
--
-- CEIL, not floor or round, and that matters at one end: any time at all leaves at least one
-- segment lit, because the round is still open and the throw buttons are still live. An empty
-- ring must mean the round is over, and nothing else.
function RingTimer.lit(fraction: number, segments: number): number
    local f = math.clamp(fraction, 0, 1)
    return math.clamp(math.ceil(f * segments), 0, segments)
end

-- Where segment `index` sits, in degrees clockwise from the top. Roblox's `Rotation` is already
-- clockwise-positive, so this feeds it directly.
function RingTimer.angleAt(index: number, segments: number): number
    return (index - 1) * (360 / segments)
end

-- Whether the ring should read as urgent. `escalateAt` is passed in rather than owned here so
-- the ring and the escalation prompt cannot drift apart — see HudModel.ESCALATE_AT.
--
-- Deliberately NOT gated on `secondsLeft > 0` the way HudModel's `escalate` is. That gate exists
-- because a prompt at zero would be pointless; a colour at zero is harmless, and at zero there
-- are no lit segments to colour anyway.
function RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean
    return secondsLeft <= escalateAt
end

-- A segment's width. Its share of the circumference would leave hairline gaps once each segment
-- is rotated about its own centre, so they are widened to overlap and the ring reads solid.
function RingTimer.segmentWidth(radius: number, segments: number): number
    return math.ceil(2 * math.pi * radius / segments) + 1
end

return RingTimer
```

- [ ] **Step 4: Run to verify pass, then verify the tests bite**

Run: `lune run tests/run` — expect PASS.

Then change `lit` to use `math.floor` instead of `math.ceil`, re-run, and confirm the
"any time remaining leaves at least one segment lit" test FAILS. Revert. **Report the count.**

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/RingTimer.luau roblox/tests/RingTimer.spec.luau
git commit -m "feat(roblox): the round's remaining time, as arithmetic"
```

---

### Task 2: `HudModel` — one threshold, a shorter fuse, and dismissal

**Files:** Modify `roblox/src/shared/HudModel.luau`, `roblox/tests/HudModel.spec.luau`.

**Interfaces:**
- Produces: `HudModel.ESCALATE_AT` (was a file-local, now exported — the ring reads it);
  `SWITCH_PROMPT_SECONDS` = 1.
- `declinedThisRound` gains a second meaning; no new field.

- [ ] **Step 1: Write the failing tests**

```luau
describe("HudModel.ESCALATE_AT is shared, not copied", function()
    test("it is exported so the ring can read the same threshold", function()
        -- The ring and the prompt must turn urgent at the SAME moment (spec §5). A second
        -- literal anywhere would be two alarms about one fact.
        expect(type(HudModel.ESCALATE_AT)).toBe("number")
    end)

    test("escalate fires exactly at the exported threshold and not above", function()
        local at = HudModel.ESCALATE_AT
        expect(HudModel.view(inputs({ secondsLeft = at }), session(0)).escalate).toBe(true)
        expect(HudModel.view(inputs({ secondsLeft = at + 0.01 }), session(0)).escalate).toBe(false)
    end)
end)

describe("HudModel.SWITCH_PROMPT_SECONDS — a one-second fuse", function()
    test("it is one second", function()
        expect(HudModel.SWITCH_PROMPT_SECONDS).toBe(1)
    end)

    test("the prompt survives just under and expires at the second", function()
        local t = 100
        expect(HudModel.switchPromptExpired(t, t + 0.99)).toBe(false)
        expect(HudModel.switchPromptExpired(t, t + 1)).toBe(true)
    end)
end)

describe("HudModel — dismissing the nag is not declining the round", function()
    test("a dismissal silences escalation for the round", function()
        local v = HudModel.view(inputs({ secondsLeft = 2, declinedThisRound = true }), session(0))
        expect(v.escalate).toBe(false)
    end)

    test("but it does NOT stop the player throwing", function()
        -- Dismissing means "stop shouting", not "I'm out". The buttons stay live.
        local v = HudModel.view(inputs({ secondsLeft = 2, declinedThisRound = true }), session(0))
        expect(v.throwsEnabled).toBe(true)
    end)

    test("and a throw after a dismissal still counts as played", function()
        local st = HudModel.applyTap({ chosen = nil, switchPrompt = nil }, "choose", "R")
        expect(st.chosen).toBe("R")
        expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 0.2, declinedThisRound = true }))).toBe("R")
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Expect FAIL — `HudModel.ESCALATE_AT` is nil and `SWITCH_PROMPT_SECONDS` is 4.

- [ ] **Step 3: Implement**

Change `local ESCALATE_AT = 5` to `HudModel.ESCALATE_AT = 5` and update its two uses in `view`.
Change `HudModel.SWITCH_PROMPT_SECONDS = 4` to `1`, and rewrite its comment:

```luau
-- ONE SECOND. Four was chosen when a prompt was the only thing on screen and in practice it
-- lingered. Both outcomes of expiry are safe — expiring restores exactly the state before the
-- stray tap, and answering only ever unlocks — so a short fuse costs nothing and a long one
-- leaves a question hanging over a live button.
HudModel.SWITCH_PROMPT_SECONDS = 1
```

Extend `declinedThisRound`'s comment in `Inputs`:

```luau
    -- Set by a back-out OR by dismissing the escalation prompt, cleared when ACTIVE reopens.
    -- One field, two gestures, because they mean the same thing to this rule: the player has
    -- answered the question the prompt asks. It silences the prompt and NOTHING else — throws
    -- stay live, and a throw after a dismissal is an ordinary throw.
    declinedThisRound: boolean,
```

- [ ] **Step 4: Verify pass, then verify the threshold is genuinely shared**

Run `lune run tests/run` — expect PASS. Then change `HudModel.ESCALATE_AT` to 9, re-run, and
confirm the escalate-boundary test FAILS. Revert. **Report the count.**

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "feat(roblox): one urgency threshold, and a prompt that does not linger"
```

---

### Task 3: `HudLayout` — the ring's slot, and the hairline's absence

**Files:** Modify `roblox/src/shared/HudLayout.luau`, `roblox/tests/HudLayout.spec.luau`.

**Interfaces:**
- Produces: `RING_D` (54), `RING_D_TOUCH`, `RING_THICKNESS` (4), `RING_GAP` (8).
  `CLUSTER_TOP_FROM_BOTTOM` re-derives with the bottom row's height now set by the ring rather
  than the tape, if the ring is taller.

- [ ] **Step 1: Write the failing test**

```luau
describe("HudLayout — the ring shares the bottom row with the tape", function()
    test("the ring is exported at both tiers and the touch one is smaller", function()
        expect(HudLayout.RING_D_TOUCH < HudLayout.RING_D).toBe(true)
        expect(HudLayout.RING_THICKNESS > 0).toBe(true)
    end)

    test("the bottom row is as tall as its tallest occupant", function()
        -- The tape and the ring sit side by side. A row derived from the tape alone would let a
        -- taller ring hang out of the cluster the onboarding band is clamped against.
        expect(HudLayout.BOTTOM_ROW_H).toBe(math.max(HudLayout.TILE, HudLayout.RING_D))
        expect(HudLayout.BOTTOM_ROW_H_TOUCH).toBe(math.max(HudLayout.TILE_TOUCH, HudLayout.RING_D_TOUCH))
    end)

    test("AREA_H is buttons + gap + the bottom row", function()
        expect(HudLayout.AREA_H).toBe(HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H)
        expect(HudLayout.AREA_H_TOUCH).toBe(
            HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H_TOUCH
        )
    end)

    test("the cluster still covers bank + throws + bottom row", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch throw target still clears the 44px floor", function()
        expect(HudLayout.BTN_H_TOUCH >= 44).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Expect FAIL — `RING_D` and `BOTTOM_ROW_H` are nil.

- [ ] **Step 3: Implement**

```luau
-- ===== The round-timer ring (spec §5) =====
-- A PWA-style circular timer replaces the bottom hairline. It shares the bottom row with the
-- tape, sitting between the tape and the wallet plate.
--
-- 54px is the PWA's own diameter (src/components/PieTimer.tsx). The touch tier scales it by the
-- same factor the tape uses — it is read, never touched, so no 44px target floor applies.
HudLayout.RING_D = 54
HudLayout.RING_D_TOUCH = math.round(HudLayout.RING_D * HudLayout.TAPE_TOUCH_SCALE)
HudLayout.RING_THICKNESS = 4
HudLayout.RING_GAP = 8 -- ring <-> tape, and ring <-> plate

-- The bottom row is as tall as its TALLEST occupant, not as tall as the tape. The ring is taller
-- than a tape tile at both tiers, and a row derived from the tape alone would let it hang below
-- the cluster the onboarding safe band is clamped against — putting a card over it.
HudLayout.BOTTOM_ROW_H = math.max(HudLayout.TILE, HudLayout.RING_D)
HudLayout.BOTTOM_ROW_H_TOUCH = math.max(HudLayout.TILE_TOUCH, HudLayout.RING_D_TOUCH)
```

Re-derive `AREA_H` / `AREA_H_TOUCH` from `BOTTOM_ROW_H` instead of `TILE`, and update their
comment: the bottom row now holds the plate, the ring and the tape.

Update the module header: the hairline is gone (the ring replaced it), so "the toast/timer sizes"
in the paragraph about file-local numbers should no longer mention a timer.

- [ ] **Step 4: Verify pass**

Run `lune run tests/run`. `HudController` is not compiled by Lune, so its stale reads do not fail
here — Tasks 4–6 fix them.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau
git commit -m "feat(roblox): the bottom row is as tall as the ring, not the tape"
```

---

### Task 4: The ring, built and driven

**Files:** Modify `roblox/src/client/HudController.client.luau`.

**Interfaces:** Consumes `RingTimer`, `HudModel.ESCALATE_AT`, `HudLayout.RING_*`, `Glyphs.render`,
`view.secondsLeft`, `aux.timerKnown`, and a new `aux.worldThrow` (see Step 4).

- [ ] **Step 1: Build the ring**

Between the plate and the tape in the bottom row. Require `RingTimer` beside the other shared
modules.

```luau
-- ===== The round-timer ring (spec §5) =====
-- The PWA's PieTimer, rebuilt. Roblox has no SVG and no radial fill, so the sweep is a ring of
-- discrete segments — RingTimer says how many are lit, this paints them. Green while there is
-- time, red at HudModel.ESCALATE_AT, which is the SAME constant the escalation prompt reads:
-- two signals about one fact must not turn urgent at different moments.
--
-- Everything here is Active = false. It is a readout.
local RING_D = if TOUCH then HudLayout.RING_D_TOUCH else HudLayout.RING_D
local RING_GAP = HudLayout.RING_GAP
local RING_THICKNESS = HudLayout.RING_THICKNESS
local RING_R = RING_D / 2 - RING_THICKNESS / 2
local SEG_W = RingTimer.segmentWidth(RING_R, RingTimer.SEGMENTS)

local ring = Instance.new("Frame")
ring.Name = "RoundRing"
ring.AnchorPoint = Vector2.new(1, 1)
ring.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + RING_GAP), 1, -EDGE)
ring.Size = UDim2.fromOffset(RING_D, RING_D)
ring.BackgroundTransparency = 1
ring.Parent = gui

local segments: { Frame } = {}
for i = 1, RingTimer.SEGMENTS do
    local a = math.rad(RingTimer.angleAt(i, RingTimer.SEGMENTS))
    local seg = Instance.new("Frame")
    seg.Name = `S{i}`
    seg.AnchorPoint = Vector2.new(0.5, 0.5)
    -- Screen space: +x right, +y DOWN, so the top of the circle is -y and the sweep runs
    -- clockwise as the angle grows.
    seg.Position = UDim2.fromOffset(
        RING_D / 2 + RING_R * math.sin(a),
        RING_D / 2 - RING_R * math.cos(a)
    )
    seg.Size = UDim2.fromOffset(SEG_W, RING_THICKNESS)
    seg.Rotation = RingTimer.angleAt(i, RingTimer.SEGMENTS)
    seg.BorderSizePixel = 0
    seg.Parent = ring
    segments[i] = seg
end
```

Add `RING_TRACK = Color3.fromRGB(38, 36, 42)`, `RING_LIVE = Color3.fromRGB(76, 187, 106)` and
`RING_HOT` (reuse `LOSS_RED`) to the palette.

- [ ] **Step 1b: Move the plate left in the SAME commit**

The ring's slot is where the plate sits today (`-(TAPE_W + LEDGER_GAP)`). Leaving the plate there
until Task 5 would stack the two on top of each other for a whole task. Move it now:

```luau
plate.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + RING_GAP + RING_D + RING_GAP), 1, -EDGE)
```

Task 5 changes its vertical anchor and makes it a button; only the horizontal moves here.

- [ ] **Step 2: The digits and the glyph**

A `TextLabel` centred in the ring for the seconds, and a glyph box for the world throw. Both
`Active = false`; **no `UIStroke` on the label** — the ring's centre is open canyon, so give the
digits their own small opaque disc backing rather than an outline.

```luau
local ringDisc = Instance.new("Frame") -- the backing the digits sit on
…
local ringCount = Instance.new("TextLabel")
…
local ringGlyph = Glyphs.render(glyphBox(ring, 0.52), "R", INK_CREAM)
```
Build one glyph box per symbol as `glyphSet` already does elsewhere in this file, so the reveal
can show whichever the world threw.

- [ ] **Step 3: Paint it in `render`**

```luau
    -- The ring, the hairline's replacement. `span` is already tracked for the old hairline;
    -- reuse it rather than deriving a second notion of the round's length.
    local known = inputs.phase == "ACTIVE" and aux.timerKnown ~= false and span > 0
    local frac = if known then math.clamp(view.secondsLeft / span, 0, 1) else 0
    local litCount = RingTimer.lit(frac, RingTimer.SEGMENTS)
    local hot = RingTimer.isWarning(view.secondsLeft, HudModel.ESCALATE_AT)
    for i, seg in segments do
        seg.BackgroundColor3 = if i <= litCount then (if hot then RING_HOT else RING_LIVE) else RING_TRACK
    end
    ringCount.Text = if known then tostring(math.ceil(view.secondsLeft)) else ""
    ringCount.TextColor3 = if hot then RING_HOT else INK_CREAM
```

**Where the countdown is unknown** (the unsynced-clock path, where `secondsLeft` is a constant),
`frac` is 0 so no segment is lit and the digits are blank — the ring shows the track only. A full
ring that never moved would read as "plenty of time" and be a lie, which is exactly why the
hairline hid itself in that case.

- [ ] **Step 4: The glyph swap, on the drum-rest gate**

The world throw appears in the ring's centre **only once the drum has settled**. `main.client.luau`
already gates the tape tile and the headline on the `drumRest` cue with a `REVEAL_SAFETY`
fallback; add the world throw to the same `aux` payload it publishes so this controller inherits
that gate rather than building a second one.

In `main.client.luau`'s `publish()`, add to `aux`:

```luau
        -- The world's throw for the round the drum has FINISHED revealing, or nil. Gated by the
        -- same `revealedRoundId` the tape is, so the ring cannot spoil the wheel mid-spin.
        worldThrow = revealedWorldThrow,
```
with `local revealedWorldThrow: string? = nil` set in `maybeShowReveal` alongside `revealedRoundId`,
and cleared when ACTIVE reopens.

In `render`, show the glyph and hide the digits when `aux.worldThrow` is set, and vice versa.

- [ ] **Step 5: Verify and commit**

Run the standing check. Additionally confirm: at `secondsLeft = span` every segment is lit; at 0
none is; and the bottom row's three occupants — plate, ring, tape — do not overlap. **State the
full horizontal arithmetic at both tiers**, since the plate moved in this same commit.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the round's clock is a ring, not a hairline"
```

---

### Task 5: The hairline goes, the cluster moves down, the plate becomes a door

**Files:** Modify `roblox/src/client/HudController.client.luau`.

- [ ] **Step 1: Delete the hairline**

Remove the `timer` Frame, `TIMER_H`, `TIMER_H_HOT`, and the whole block in `render` that sizes and
colours it. `span` **stays** — the ring uses it.

- [ ] **Step 2: Move the cluster down**

With the hairline gone the cluster no longer needs to clear it. This is one constant: everything
below already derives from `HudLayout.EDGE`. Introduce a **bottom** margin distinct from the
side margin, and use it for the cluster's vertical anchor only:

```luau
-- The hairline used to occupy the bottom edge and everything was held above it. It is gone (the
-- ring replaced it), so the cluster drops into the space it left. Deliberately a SEPARATE
-- constant from EDGE rather than a smaller EDGE: the side margins are unchanged, and a shared
-- constant would move them too.
local EDGE_BOTTOM = 6
```

Apply it to the plate, the ring, the tape/throw area and the bank button's vertical positions.
`HudLayout.CLUSTER_TOP_FROM_BOTTOM` still uses `EDGE`, which now over-reserves by
`EDGE - EDGE_BOTTOM` — that is **fine and deliberate**: the onboarding band erring high keeps
cards further from live buttons. Note it in a comment so it does not read as a bug.

- [ ] **Step 3: The plate becomes a door**

Change `plate` from a `Frame` to a `TextButton` (`AutoButtonColor = false`, `Text = ""`), sitting
left of the ring:

```luau
plate.Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + RING_GAP + RING_D + RING_GAP), 1, -EDGE_BOTTOM)
```

```luau
-- TAPPABLE AGAIN, and it is safe now in a way it was not before. The plate went inert because it
-- had moved into the strip Roblox uses for camera drag, where a sinking element is a permanent
-- hole. It is in the bottom row now. So the ledger has two doors — the hamburger and the plate
-- whenever it is showing — and tapping the hamburger then the plate is the same two taps as
-- double-tapping the hamburger.
plate.MouseButton1Click:Connect(function()
    if plateVisible then
        EventBus.OpenLedger:Fire()
    end
end)
```

The `plateVisible` guard matters: the plate is `Visible = false` most of the time, and a hidden
button cannot be clicked — but the guard also covers the fade, where it is still technically
visible while on its way out.

- [ ] **Step 4: Verify and commit**

Run the standing check. State the bottom row's full horizontal arithmetic at both tiers —
plate, ring, tape — and confirm no overlap and nothing pushed off the left edge on a 320px-wide
viewport. Confirm `EventBus.OpenLedger:Fire` now occurs **twice** in `src/client/` (the hamburger
and the plate) and that both are guarded.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the wallet is a door again, and the bar is gone"
```

---

### Task 6: The escalation halves and learns to be dismissed; `SWITCH?` fills its button

**Files:** Modify `roblox/src/client/HudController.client.luau`.

- [ ] **Step 1: Halve the escalation**

`ESCALATION_H` 154 → 77. `escalationCount.TextSize` 84 → 42 and its height 92 → 46.
`escalationPrompt.TextSize` 24 → **16, not 12** — the point of the change is the footprint, not
the type, and halving a 24px label makes it unreadable. Its height 30 → 20.

**Re-check the padding arithmetic.** The frame carries 12px of `UIPadding` on all four sides and
its height must absorb that: content = `ESCALATION_H - 24`, and the two labels plus their gap must
fit inside it. Task 9 of the previous branch shipped exactly this bug — padding added to a
fixed-height frame stacked its own labels. **State the arithmetic in your report.**

Then **re-check the clamp against the bank button.** The overlay is clamped so its bottom edge
never passes `CLUSTER_TOP_FROM_BOTTOM + margin`; halving its height changes where its centre
lands. Confirm no overlap at `H = 354` and `H = 1044`.

- [ ] **Step 2: Make it dismissable**

`escalation` becomes a `TextButton` (`AutoButtonColor = false`, `Text = ""`), and its click fires
a new `EventBus.DismissEscalation`. Add that name to `EventBus.luau`'s list.

```luau
-- THE ONE SINKING ELEMENT that is not a control. Everything else on this surface stays
-- Active = false, because every sinking pixel is a permanent hole in the camera-drag surface.
-- This is the exception the owner asked for: "the worst thing that could happen is it gets
-- thrown into a user's view in the middle of watching fireworks." It is small, it exists only in
-- the last few seconds of a round and only when armed, and dismissing it is the entire point.
```

In `main.client.luau`, listen and set `declinedThisRound = true`, then `publish()`. **Do not add
a new field** — dismissing and backing out mean the same thing to the escalation rule, and the
spec says so.

- [ ] **Step 3: `SWITCH?` fills its button**

`switchPill.Size` is already `UDim2.fromOffset(BTN_W, 24)` — confirm it, and confirm the label
carries `TextScaled` plus a `UITextSizeConstraint`. If the pill is still `BTN_W - 8` anywhere,
fix it. **Do not move the pill above the button.** Add:

```luau
-- IT COVERS THE GLYPH, ON PURPOSE. Confirming a switch UNLOCKS; it never selects the button that
-- was tapped. So the glyph underneath is not a destination — both unchosen buttons are proxies
-- for switch-and-cancel, and either does the same thing. Revealing it would advertise a
-- destination that does not exist.
```

- [ ] **Step 4: Verify and commit**

Run the standing check. Report the escalation's padding arithmetic and its clearance from the
bank button at both viewport heights.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the nag gets smaller and takes an answer"
```

---

### Task 7: The result splash

**Files:** Create `roblox/src/client/SplashController.client.luau`; modify
`roblox/src/client/main.client.luau`, `roblox/src/client/EventBus.luau`.

- [ ] **Step 1: The controller**

Its own `ScreenGui`, `DisplayOrder = 30` — above both takeovers (20) and the minimal HUD (0),
because a result that lands while the ledger is open must still be seen. `ResetOnSpawn = false`.

Two labels on one opaque backing, centred: the headline and the consequence line. **No `UIStroke`
on either label.** Everything `Active = false`, no button — see the spec's Decision 1.

```luau
-- NOTHING HERE IS INTERACTIVE, deliberately. A large sinking element in the middle of the screen
-- is the failure this branch has already made twice — a card on the movement thumbstick, and a
-- panel leaking taps to live buttons beneath it. An accidental tap that dropped the player into
-- a movement-suspending takeover would be worse than the friction it saved. The hamburger and
-- the revealed plate are the doors.
```

Copy, driven by result:

| Result | Headline | Consequence |
| --- | --- | --- |
| `WIN` | `YOU WIN!` | `×{streak} — pot is now {pot}` |
| `SAFE` | `SAFE` | `your pot survives, streak resets` |
| `LOSS` | `YOU LOSE` | `{forfeited} points forfeited` |

Colour the headline per result (gold / blue / red) using the palette constants already in
`HudController` — duplicate them locally with a comment, exactly as `OnboardingController` does,
rather than inventing a palette module for a fourth file.

Hold ~2s then fade, on the same generation-guard pattern `HudController`'s plate reveal uses:
increment a generation before cancelling, and have the fade's `Completed` refuse a stale one.

- [ ] **Step 2: Wire it**

Add `Splash` to `EventBus.luau`. In `main.client.luau`'s `maybeShowReveal` — which already holds
the `drumRest` gate and the `REVEAL_SAFETY` fallback — fire it alongside the existing toast:

```luau
        EventBus.Splash:Fire({
            result = p.result,
            streak = wallet.currentStreak,
            pot = wallet.pointsAtStake,
            forfeited = p.forfeited,
        })
```

`forfeited` is the pot as it stood **before** the loss cleared it. Read it the way the bank toast
reads `bankedNow` — capture before the wallet is overwritten. If that value is not available at
this point in the file, say so in your report rather than guessing; do not print a wrong number.

**Remove the result from the toast.** The toast keeps whiffs and bank confirmations; the splash
owns results. Both firing would say the same thing twice in two places.

- [ ] **Step 3: Verify and commit**

Confirm by reading: the splash fires only on the `drumRest` gate (never directly from
`RevealResult`); it cannot appear for a round the player did not throw in; `DisplayOrder` is 30;
nothing in the file is a button or `Active`.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the round ends with your name on it"
```

---

### Task 8: `resultSplash`, the second preference

**Files:** Modify `server/src/models/User.ts`, `server/src/routes/apiV1.ts`,
`server/src/routes/apiV1.test.ts`, `roblox/src/server/main.server.luau`,
`roblox/src/client/main.client.luau`, `roblox/src/client/LedgerController.client.luau`,
`roblox/src/client/SplashController.client.luau`.

**This is the mirror of Task 14 on the previous branch, which retired `confirmThrows`.** Read that
task's diff (`git log --oneline --all -- server/src/routes/apiV1.ts`) and follow the same seams —
they are the same five files plus the Roblox server's `HudPrefs`, which that task's brief missed
and its implementer had to find.

- [ ] **Step 1: Failing server test**

In `server/src/routes/apiV1.test.ts`, reusing the file's existing scaffolding: `PUT
/players/:id/preferences-hud` accepts and persists `resultSplash`, and `buildProfilePayload`
ships it, defaulting **true**.

- [ ] **Step 2: Run, confirm failure, implement**

`User.ts` gains `resultSplash: { type: Boolean, default: true }`. `apiV1.ts` accepts it in the PUT
and emits it from `buildProfilePayload`.

- [ ] **Step 3: The Roblox server**

`HudPrefs`, `prefsFor`, `prefsFromProfile`, the `fireProfile` payload and the `SetHudPreference`
handler all carry `resultSplash` beside `escalationPrompts`. **Every producer must emit both keys
and every consumer read both** — a partial preferences object is how one switch ends up
resetting the other.

- [ ] **Step 4: The client**

`main.client.luau` holds `resultSplash`, applies it locally on `EventBus.HudPreference` and from
`ProfileUpdate`, and includes it in `publishLedger`. `LedgerController` gains the second switch —
the footer's two-column layout was built for exactly this, so restore the `column` argument that
Task 14 removed when it dropped to one occupant. `SplashController` reads it from the same
`LedgerState` channel and simply does not show when it is off.

- [ ] **Step 5: Verify and commit**

Both suites. Confirm both switches round-trip independently: toggle one, confirm the other's value
survives the echo. Trace it and say so.

```bash
git commit -am "feat: the result splash is a preference, not a fixture"
```

---

### Task 9: The ledger's LAST ROUND band

**Files:** Modify `roblox/src/client/LedgerController.client.luau`,
`roblox/src/client/main.client.luau`.

- [ ] **Step 1: Send the round detail**

`main.client.luau` already receives `worldThrow`, `pick`, `result`, `distribution` and
`totalPlayers` on `RevealResult`. Stash them and include them in `publishLedger`'s payload as
`lastRound`. It must be **nil until a round has been revealed**, so the band can hide rather than
show zeros to someone who just joined.

- [ ] **Step 2: The band**

Above the hero band, below the header — `HERO_H` currently starts at `HEADER_H`, so the band goes
in between and everything below shifts by its height plus a gap. `BODY_TOP` re-derives.

Contents: the world's throw and the player's throw as glyphs, the result, the crowd split as a
three-way bar, and the player count. Reuse the ledger's existing `stroke`/`corner` helpers and its
card treatment.

**The three-way bar must sum to exactly 100%.** Use largest-remainder apportionment — the same
rule the ledger's existing win-rate bar uses; read it and reuse it rather than writing a second.

Hide the whole band when `lastRound` is nil.

- [ ] **Step 3: Verify and commit**

Confirm the band hides for a fresh join; confirm `BODY_TOP` and the scroll canvas re-derive
rather than carrying the old literal; confirm the bar sums to 100 for a 1/1/1 split (the case
naive rounding gets wrong).

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the ledger remembers the round you just played"
```

---

## Final verification

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools
cd ../server && npm test
cd .. && git status --porcelain
```

## The owner's Studio gate

Nothing here can verify: whether the ring reads as a ring at 36 segments; whether the splash is
big enough to celebrate and short enough not to intrude; whether the halved escalation still
commands attention; whether the ring's digits are legible at the touch tier; and whether the
bottom row still breathes now that it holds a plate, a ring and a tape.
