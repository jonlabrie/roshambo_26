# Play HUD Round Four Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seat the ring's digits correctly, bring the UNDO overlay into the palette, turn banking into a payoff that scales with the amount, and land the result splash with the drum instead of after it.

**Architecture:** Five tasks over the existing HUD. The arithmetic goes into `src/shared` (`RollingNumber`, `DrumStep`) where Lune can test it; the painting and the cue plumbing stay in client files that no gate can load. Ordered so `RollingNumber`'s new surface exists before the controller consumes it, and the counters leave the 10Hz heartbeat before the festive treatment hooks into them.

**Tech Stack:** Luau, Rojo, Lune test harness (`lune run tests/run`), stylua, selene.

**Spec:** `docs/superpowers/specs/2026-08-04-play-hud-round-four-design.md`

## Global Constraints

- **`Active` discipline.** `TextButton`/`ImageButton` always sink touch; `Frame`/`TextLabel` only when `Active = true`. `undoPill` is a `Frame` covering a live `TextButton` and **must stay `Active = false`** — the tap that answers the prompt is delivered to the button underneath. Task 1 repaints it and must not touch that.
- **Never put a `UIStroke` on a `TextLabel`.** It outlines every glyph and fills the counters. Task 4's stroke goes on `plate` (a Frame), never on `plateLabel`.
- **`src/shared` modules hold no Roblox globals.** No `Instance`, `Color3`, `UDim2`, `Enum`, `task`, `os`, `TweenService`, `RunService`. They must run under Lune.
- **No gate can see any client file.** `lune run tests/run` never loads a `.client.luau` or `.server.luau`; `selene` does not resolve cross-module field types; `stylua` only formats. Before finishing any task touching a client file: reconcile every cross-module read against what that module actually exports, and confirm every local is declared **before** its first use — a forward reference resolves to a nil global, not an error.
- **Never restart a tween every frame.** `setBank`'s pulse failed exactly this way earlier in this branch: cancel-and-restart at repaint rate got ~3% of its travel and rendered static. Any repeated call into a tween needs a state latch that returns early when nothing changed.
- **selene fails on warnings.** Deleting the last *code* use of a local breaks CI. Comments do not count.
- **The drum's choreography is signed off.** `DrumStep.STRIKE_SWING_SECONDS`, `SPIN_SECONDS`, `GLIDE_SECONDS` and `SETTLE_SECONDS` keep their values. Task 5 changes when a client *reacts*, never how long the drum takes.
- **Every task ends green:** from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox` run `lune run tests/run`, `stylua --check src tests tools`, `selene src tools`.
- **Absolute paths in Bash calls.** The working directory persists between calls in this environment.

---

### Task 1: The ring's digits sit up, and UNDO becomes a card

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — the `ringCount` construction, and the `undoPill`/`undoLabel` construction

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** Two small, independent repaints, both from the owner's Studio gate. No logic changes anywhere.

- [ ] **Step 1: Seat the digits**

`ringCount` fills `ringDisc` and Roblox centres the **line box**, which reserves descender space. Digits have no descenders, so a vertically centred box always seats them low by roughly half a descender. Every countdown this HUD shows is digits, so the correction is unconditional.

Find `ringCount`'s construction (it currently sets `Size = UDim2.fromScale(1, 1)` and no `AnchorPoint`/`Position`). Add, after `TextSize` is assigned so the nudge can derive from it:

```lua
-- OPTICAL CENTRING, not a fudge. Roblox centres the LINE BOX, which reserves room for
-- descenders; digits have none, so a vertically centred box seats them low by roughly half a
-- descender. Every value this label ever shows is digits, so the correction is unconditional.
-- Derived from TextSize rather than a literal pair, so a future size change carries its own
-- correction: 2px at 34 (desktop), 1px at 20 (touch).
local COUNT_NUDGE = math.max(1, math.round(ringCount.TextSize * 0.06))
ringCount.AnchorPoint = Vector2.new(0.5, 0.5)
ringCount.Position = UDim2.new(0.5, 0, 0.5, -COUNT_NUDGE)
```

**Do not touch the world-throw glyph.** `glyphBox(ringDisc, 0.82)` holds geometric artwork that is already centred correctly; nudging it would introduce the defect this fixes. Verify the glyph box construction is unchanged when you are done.

- [ ] **Step 2: Repaint the UNDO overlay**

`WASHI` (26, 24, 28) is the HUD's dark, but opaque at full-button size over a cream throw button it reads as a hole punched in the HUD rather than a card laid on it. Change exactly two colours:

```lua
undoPill.BackgroundColor3 = IVORY
```

```lua
undoLabel.TextColor3 = INK
```

Replace the comment above `undoPill.BackgroundColor3` (or add one) with:

```lua
-- IVORY, not WASHI (owner's gate 2026-08-04). At 24px the near-black pill read as an accent; at
-- full button size and fully opaque it read as a hole punched in the HUD. Cream-on-ink under a
-- cool rim is this HUD's own washi idiom, and the SEL_BLUE stroke is what keeps a light tile
-- from reading as an ordinary available throw.
```

**Everything else about the pill is unchanged**: `Size`, corner radius 8, `ZIndex` 4/5, the `SEL_BLUE` 2px stroke, `TextScaled`, `MaxTextSize = 22`, `GothamBold`, and — critically — `Active` is still never assigned on it.

Confirm `IVORY` and `INK` are declared above this point in the file (they are in the palette block near the top).

- [ ] **Step 3: The standing check for client files**

1. `ringCount.TextSize` is assigned **above** the `COUNT_NUDGE` line that reads it. A forward read gives nil and `math.round(nil * 0.06)` errors at load.
2. `IVORY`, `INK`, `Vector2`, `UDim2` all resolve.
3. `grep -n "undoPill" roblox/src/client/HudController.client.luau` — `Active` still never assigned.
4. The glyph box construction is untouched.

- [ ] **Step 4: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "fix(roblox): seat the ring's digits, and lay UNDO on the HUD rather than through it"
```

---

### Task 2: RollingNumber scales with the distance, and turns its easing over

**Files:**
- Modify: `roblox/src/shared/RollingNumber.luau`
- Test: `roblox/tests/RollingNumber.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Task 3:
  - `RollingNumber.MIN_DURATION`, `RollingNumber.MAX_DURATION`, `RollingNumber.SCALE_CAP`
  - `RollingNumber.durationFor(delta: number): number`
  - `RollingNumber.valueAt(from, to, t)` — signature unchanged, **easing changed**
- Deleted: `RollingNumber.DURATION`. Task 3 must stop reading it.

**Context:** Banking 2000 points transferred almost instantly because the duration is a flat 0.5s regardless of amount, and the quadratic ease-out puts three quarters of the count in the first half. Both change here; the third defect (10Hz repaint) is Task 3.

- [ ] **Step 1: Write the failing tests**

In `roblox/tests/RollingNumber.spec.luau`, replace the `describe("RollingNumber.DURATION", ...)` block entirely with:

```lua
describe("RollingNumber.durationFor — a big bank should feel like a payoff", function()
    test("the flat DURATION is gone", function()
        -- One constant for every amount is what made 2000 points transfer in the same half
        -- second as 1. Every caller derives its own now; leaving the old one behind would let
        -- two counters that must finish together run on different curves.
        expect((RollingNumber :: any).DURATION).toBe(nil)
    end)

    test("a zero move still returns a usable, positive duration", function()
        -- Callers divide by this. A zero would be a divide-by-zero on the one path where
        -- nothing actually moves.
        expect(RollingNumber.durationFor(0)).toBe(RollingNumber.MIN_DURATION)
        expect(RollingNumber.durationFor(0) > 0).toBe(true)
    end)

    test("direction does not matter — only distance", function()
        -- The bank button drains while the balance fills. They are one event and must finish
        -- together, so the count DOWN has to take exactly as long as the count up.
        for _, d in { 1, 7, 250, 3000, 99999 } do
            expect(RollingNumber.durationFor(-d)).toBe(RollingNumber.durationFor(d))
        end
    end)

    test("it never leaves [MIN_DURATION, MAX_DURATION]", function()
        for _, d in { 0, 1, 5, 60, 400, 3000, 10000, 250000 } do
            local v = RollingNumber.durationFor(d)
            expect(v >= RollingNumber.MIN_DURATION).toBe(true)
            expect(v <= RollingNumber.MAX_DURATION).toBe(true)
        end
    end)

    test("it is monotonic in distance", function()
        local prev = -1
        for i = 0, 200 do
            local v = RollingNumber.durationFor(i * 60)
            expect(v >= prev).toBe(true)
            prev = v
        end
    end)

    test("beyond the cap it is exactly MAX_DURATION — no pot runs away with the screen", function()
        expect(RollingNumber.durationFor(RollingNumber.SCALE_CAP)).toBe(RollingNumber.MAX_DURATION)
        expect(RollingNumber.durationFor(RollingNumber.SCALE_CAP * 100)).toBe(RollingNumber.MAX_DURATION)
    end)

    test("the curve's shape: a big bank takes seconds, a small one does not", function()
        -- Pins the FEEL the owner asked for without over-pinning the exact function. A linear
        -- ramp would put 30 points at ~0.4s and 3000 at ~1.0s and fail both bounds.
        expect(RollingNumber.durationFor(30) > 0.9).toBe(true)
        expect(RollingNumber.durationFor(30) < 1.5).toBe(true)
        expect(RollingNumber.durationFor(3000) > 2.0).toBe(true)
        expect(RollingNumber.durationFor(3000) < 2.45).toBe(true)
        expect(RollingNumber.durationFor(3000) > RollingNumber.durationFor(30) + 0.8).toBe(true)
    end)
end)

describe("RollingNumber.valueAt — the easing is a payoff, not a decay", function()
    test("the midpoint is the midpoint", function()
        -- THE test that pins the change. Smoothstep is symmetric: half the time, half the
        -- points. The quadratic ease-out this replaces returned 75 here — three quarters of a
        -- 2-second count landing in the first second and the rest crawling.
        expect(RollingNumber.valueAt(0, 100, 0.5)).toBe(50)
    end)

    test("it winds up rather than bolting", function()
        -- A quarter of the way through, well under a quarter of the way there. The old
        -- ease-out was at 44 by this point.
        expect(RollingNumber.valueAt(0, 100, 0.25) < 25).toBe(true)
        expect(RollingNumber.valueAt(0, 100, 0.25) > 5).toBe(true)
    end)

    test("and settles rather than stopping dead", function()
        -- Symmetric with the wind-up: the last quarter of the time covers well under a quarter
        -- of the distance.
        expect(RollingNumber.valueAt(0, 100, 0.75) > 75).toBe(true)
        expect(RollingNumber.valueAt(0, 100, 0.75) < 95).toBe(true)
    end)
end)
```

Every other test in the file — endpoints, clamping, monotonicity, integer results, the constant case — stays exactly as it is. Smoothstep satisfies all of them, and they are what stops this change from introducing an overshoot.

- [ ] **Step 2: Run the tests and watch them fail**

Run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`: `lune run tests/run`
Expected: FAIL — `durationFor` does not exist, `DURATION` still does, and `valueAt(0, 100, 0.5)` returns 75.

- [ ] **Step 3: Implement**

In `roblox/src/shared/RollingNumber.luau`, replace the `RollingNumber.DURATION` declaration with:

```lua
-- HOW LONG A COUNT TAKES IS A FUNCTION OF HOW FAR IT GOES (spec §3a). A flat duration meant
-- banking 2000 points took the same half second as banking 1, and the owner's word for it was
-- that it "transferred" rather than paid out.
--
-- LOGARITHMIC, so it flattens on its own: no pot however large can run away with the screen,
-- and the ceiling is reached rather than approached. Values it produces:
--   1 -> 0.56s   30 -> 1.18s   300 -> 1.70s   3000 -> 2.23s   10000+ -> 2.50s
RollingNumber.MIN_DURATION = 0.4
RollingNumber.MAX_DURATION = 2.5
RollingNumber.SCALE_CAP = 10000

-- `delta` is signed; only its MAGNITUDE matters. The bank button drains to zero while the
-- balance fills, and those are one event — a count down that finished before the count up would
-- show the points arriving from nowhere.
function RollingNumber.durationFor(delta: number): number
    local magnitude = math.min(math.abs(delta), RollingNumber.SCALE_CAP)
    local span = RollingNumber.MAX_DURATION - RollingNumber.MIN_DURATION
    local fraction = math.log(1 + magnitude) / math.log(1 + RollingNumber.SCALE_CAP)
    return RollingNumber.MIN_DURATION + span * fraction
end
```

Replace the `easeOut` function with:

```lua
-- SMOOTHSTEP, not the quadratic ease-out this replaces. A payoff winds up, races, then settles;
-- ease-out did the opposite — fastest at the start, so three quarters of a two-second count
-- landed in the first second and the last quarter crawled. Smoothstep keeps every guarantee the
-- tests below assert: monotonic on [0,1], bounded to exactly [0,1], and exact at both endpoints
-- (0 -> 0, 1 -> 1*(3-2) = 1), so the interpolated value still cannot overshoot `to`.
local function smoothstep(t: number): number
    return t * t * (3 - 2 * t)
end
```

and update `valueAt`'s single call site from `easeOut(clamped)` to `smoothstep(clamped)`. Update `valueAt`'s own comment if it names the old easing.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS. `HudController.client.luau` still reads `RollingNumber.DURATION` at this point — that is expected, invisible to the harness, and Task 3 repairs it. **Do not patch HudController here.**

- [ ] **Step 5: Verify the two new invariants are not vacuous**

No gate can see a counter animate, so prove these tests bite:

1. Change `smoothstep` back to `1 - (1 - t) * (1 - t)` and re-run. Expected: the three easing tests fail. Restore.
2. Change `durationFor` to `return RollingNumber.MIN_DURATION` and re-run. Expected: the curve-shape and cap tests fail. Restore.
3. Change `math.abs(delta)` to `delta` and re-run. Expected: the direction test fails. Restore.

Quote the actual failure output in your report. **If any mutation does not cause a failure, that is a finding** — say so rather than moving on.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RollingNumber.luau roblox/tests/RollingNumber.spec.luau
git commit -m "feat(roblox): a count's length is how far it travels, and it pays out rather than decays"
```

---

### Task 3: The counters leave the heartbeat

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — the `Counter` type, `newCounter`, `tickCounter`, a new `paintCounters`, and `render`'s plate/bank block

**Interfaces:**
- Consumes: `RollingNumber.durationFor` and `RollingNumber.MIN_DURATION` from Task 2.
- Produces, for Task 4: a `paintCounters()` function that is the single place the plate line and the bank figure are painted, and which knows whether the points counter is mid-count.

**Context:** **This task is what decides whether Task 2 was worth doing.** `render` is driven by `main.client.luau`'s 10Hz heartbeat. Today's 0.5s count is 5 frames — coarse, but over too quickly to read as anything. A 2.2s count at 10Hz is ~22 visible steps: a number lurching, not counting. Shipping Task 2 without this makes the exact thing the owner reported *worse*.

- [ ] **Step 1: Give each counter its own duration**

`RollingNumber.DURATION` no longer exists. Each leg of a count now has a duration computed when its target changes.

Add `duration: number` to the `Counter` type, with a comment:

```lua
    -- The duration of the CURRENT leg, fixed when the target changed. Recomputed per leg rather
    -- than read per frame so a count that is interrupted mid-flight finishes on the curve it
    -- started on instead of jumping to a new one.
    duration: number,
```

In `newCounter`, initialise it to `RollingNumber.MIN_DURATION`.

In `tickCounter`, inside the `if target ~= c.target then` block, after `c.startedAt = os.clock()`:

```lua
        c.duration = RollingNumber.durationFor(target - c.from)
```

and change the elapsed-fraction line from `RollingNumber.DURATION` to `c.duration`.

- [ ] **Step 2: Extract the paint**

`render` currently ticks all three counters and paints inline. That work moves into a function that a per-frame driver can also call.

Add, **after `setBank` is declared** (it is called from here) and before `render`:

```lua
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
    -- display still reads 0 for that one frame.
    local displayedPot = tickCounter(potCounter, counterPot)
    setBank(counterPot > 0 or displayedPot > 0, displayedPot, counterPulses)
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
```

`HudController` does **not** currently require `RunService` (it has `Players`, `ReplicatedStorage`, `TweenService`, `UserInputService`). Add it with those, keeping their alphabetical order:

```lua
local RunService = game:GetService("RunService")
```

- [ ] **Step 3: Rewire render**

Replace `render`'s inline counter block — the `tickCounter` calls, the `plateLabel.Text` assignment and the `setBank` call — with:

```lua
    counterPoints = view.plate.points
    counterStreak = view.plate.streak
    counterPot = view.pot
    counterPulses = view.potPulses
    paintCounters()
```

Leave `bankArmed = view.pot > 0` exactly where it is, and leave its comment: arming follows the MODEL's pot, not the displayed one, so a tap during the drain cannot send a `BankRequest` for a pot that no longer exists.

Move any comment that explained the inline block up to `paintCounters` rather than deleting it.

- [ ] **Step 4: The standing check for client files**

1. `paintCounters` is declared **after** `setBank`, `plateLabel`, `tickCounter`, `pointsCounter`, `streakCounter` and `potCounter`, and **before** `render` calls it. Give actual line numbers.
2. `counterPoints`/`counterStreak`/`counterPot`/`counterPulses` are declared above `paintCounters`.
3. `RunService` is required.
4. No remaining reference to `RollingNumber.DURATION`: `grep -rn "RollingNumber\." roblox/src roblox/tests` — only `valueAt`, `durationFor`, `MIN_DURATION`, `MAX_DURATION`, `SCALE_CAP` may appear.
5. `render` no longer paints `plateLabel.Text` or calls `setBank` directly.

- [ ] **Step 5: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "fix(roblox): a count that lasts two seconds cannot be painted ten times a second"
```

---

### Task 4: The payoff draws the eye

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — a new `setCelebrating`, called from `paintCounters`

**Interfaces:**
- Consumes: `paintCounters` and the counters' `startedAt` from Task 3.
- Produces: nothing.

**Context:** The owner: *"as point balances rise… we want the player to feel the satisfaction of a long points transfer, just like a slot machine paying off a big win. Maybe even change the color in the points display to something more festive/brighter while the balance is incrementing, draw a box around it or something."* The plate already has a `GOLD` `UIStroke` at 0.35 transparency (`plateStroke`) — the box exists; it gets brought up while counting rather than added.

- [ ] **Step 1: Add the treatment**

Add, immediately above `paintCounters`:

```lua
-- WHILE THE BALANCE CLIMBS, the plate lifts: its existing GOLD rim comes up from a hairline to a
-- real edge, and the figure itself goes gold. It settles back as the count lands.
--
-- THE PLATE ONLY. The bank button's figure is DRAINING to zero over the same seconds, and a
-- number counting down to nothing should not celebrate — the destination gets the emphasis, the
-- source just empties.
--
-- LATCHED, and that is not optional: this is called every frame while a count runs, and a tween
-- cancelled and restarted at frame rate gets a few percent of its travel and renders static.
-- That is exactly how the bank button's pulse failed earlier in this branch.
local CELEBRATE_SECONDS = 0.15
local celebrating = false

local function setCelebrating(active: boolean)
    if active == celebrating then
        return
    end
    celebrating = active
    local info = TweenInfo.new(CELEBRATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    -- The stroke is on the PLATE, a Frame. Never on plateLabel — an outline on text fills the
    -- counters of every glyph.
    TweenService:Create(plateStroke, info, {
        Transparency = if active then 0 else 0.35,
        Thickness = if active then 2 else 1,
    }):Play()
    TweenService:Create(plateLabel, info, {
        TextColor3 = if active then GOLD else INK_CREAM,
    }):Play()
end
```

`TweenService`, `plateLabel`, `GOLD` and `INK_CREAM` are all declared near the top of the file, and `plateStroke` is already captured as `local plateStroke = stroke(plate, GOLD, 1, 0.35)` — the box the owner asked for exists, at 0.35 transparency and 1px. This brings it up rather than adding a second one. Confirm all five resolve above your insertion point.

- [ ] **Step 2: Drive it from the paint**

At the end of `paintCounters`, add:

```lua
    -- Keyed on the POINTS counter alone. The pot draining and the streak resetting are not
    -- payoffs, and lighting the plate for them would spend the effect on nothing.
    setCelebrating(pointsCounter.startedAt ~= nil)
```

This is why Task 3's driver checks `countersAnimating()` **before** painting rather than after: the frame on which the count reaches its target still runs `paintCounters`, `tickCounter` clears `startedAt` inside it, and this line then releases the decoration in the same invocation. Were the check the other way round, the gold would stick permanently.

- [ ] **Step 3: Verify the release paths by reading**

No gate can see this. Walk each exit and confirm the decoration is released:

1. **A count completes.** `tickCounter` sets `startedAt = nil` at `t >= 1`; `setCelebrating(false)` runs in the same `paintCounters` call. ✔ by the ordering above — confirm that ordering is actually what Task 3 wrote.
2. **A second bank interrupts one already running.** `tickCounter` re-keys, `startedAt` is non-nil throughout, `setCelebrating(true)` returns early on the latch. No tween restart. The count continues from the displayed value.
3. **The plate fades out while a count is running.** The plate's own reveal/fade is independent; confirm the fade does not fight the stroke tween, and that when the count later settles the release still runs (it does — `paintCounters` is driven by the counter, not by the plate's visibility).
4. **A loss.** Points do not move on a loss, so the plate must not celebrate. Confirm `pointsCounter.startedAt` stays nil.

State what you found for each in your report.

- [ ] **Step 4: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the plate lifts while the balance climbs"
```

---

### Task 5: The splash lands with the drum

**Files:**
- Modify: `roblox/src/shared/DrumStep.luau`
- Modify: `roblox/src/client/DrumController.client.luau` — the glide branch
- Modify: `roblox/src/client/main.client.luau` — the reveal gate
- Test: `roblox/tests/DrumStep.spec.luau`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a new `EventBus.Cue` kind, `"drumSettling"`.

**Context:** The splash is not slow — it fires the instant `drumRest` lands. The wait is the drum's own 3.45s (0.45 swing + 1.0 spin + 2.0 glide), gated so the result is not announced before the drum has shown the world's throw. The glide is a smoothstep decelerating onto the detent, so by 65% through it the drum has covered ~88% of its travel and the face is effectively in the window. The splash fires there: **2.75s instead of 3.45s.**

**The tape tile does NOT move.** It stays on `drumRest`. The tape is the record of the *world's* throw — the actual spoiler — and it has no urgency. The resulting order is better than moving both: your outcome first, then the world's mark goes onto the tape as the drum stops.

- [ ] **Step 1: Write the failing test**

In `roblox/tests/DrumStep.spec.luau`, add:

```lua
describe("DrumStep.SPLASH_LEAD_SECONDS — how early the personal result may land", function()
    test("it is a real lead, but strictly inside the glide", function()
        -- At or beyond the glide's whole length the cue would fire the moment the glide STARTS,
        -- while the drum is still visibly travelling — which is the spoiler the drum-rest gate
        -- exists to prevent. At zero it buys nothing.
        expect(DrumStep.SPLASH_LEAD_SECONDS > 0).toBe(true)
        expect(DrumStep.SPLASH_LEAD_SECONDS < DrumStep.GLIDE_SECONDS).toBe(true)
    end)

    test("it leaves the drum most of the way home before the result shows", function()
        -- The glide is a smoothstep (3s^2 - 2s^3). Whatever the lead is, the drum must have
        -- covered a large majority of its travel by the time the splash fires, or the face is
        -- not yet readable in the window.
        local s = (DrumStep.GLIDE_SECONDS - DrumStep.SPLASH_LEAD_SECONDS) / DrumStep.GLIDE_SECONDS
        local travelled = 3 * s * s - 2 * s * s * s
        expect(travelled > 0.8).toBe(true)
    end)

    test("the drum's own timings are unchanged", function()
        -- The bell/drum choreography is signed off. This round changes when a CLIENT reacts,
        -- never how long the drum takes — and the server reads SETTLE_SECONDS to time round
        -- scheduling.
        expect(DrumStep.SETTLE_SECONDS).toBe(
            DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS
        )
    end)
end)
```

The file already requires `DrumStep` and the harness at its head — append the new `describe` block; do not touch the existing `describe("DrumStep (12 faces)", ...)`.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `lune run tests/run`
Expected: FAIL — `SPLASH_LEAD_SECONDS` is nil, so the comparison errors or fails.

- [ ] **Step 3: Add the constant**

In `roblox/src/shared/DrumStep.luau`, after `SETTLE_SECONDS`:

```lua
-- HOW EARLY THE PERSONAL RESULT MAY LAND, measured back from drumRest (spec §2).
--
-- The whole 3.45s of swing + spin + glide sat between a round closing and the player being told
-- what happened, and the owner's word for it was "a long time". But the wait is not padding —
-- it is what stops the result being announced before the drum has shown the world's throw.
--
-- The glide is a smoothstep, so it is nearly home long before it stops: at 0.7s from rest the
-- drum has covered ~88% of its travel and the face is effectively in the window. The remaining
-- beat is settling, not suspense. So the SPLASH fires here and the TAPE TILE does not — the tape
-- is the record of the WORLD's throw, the real spoiler, and it has no urgency.
DrumStep.SPLASH_LEAD_SECONDS = 0.7
```

Run `lune run tests/run` — expected: PASS.

- [ ] **Step 4: Fire the cue from the drum**

In `roblox/src/client/DrumController.client.luau`, near the existing `SPIN_SEC`/`GLIDE_SEC` locals (which already come from `DrumStep` — confirm this):

```lua
-- The fraction of the glide at which the personal result may show. Clamped: a lead longer than
-- the glide itself would fire at glide start, while the drum is still visibly travelling.
local SETTLING_S = math.clamp((GLIDE_SEC - DrumStep.SPLASH_LEAD_SECONDS) / GLIDE_SEC, 0, 1)
local settlingFired = false
```

In the glide branch, in the `else` arm (the one that is still travelling), **before** the `theta = ...` assignment:

```lua
            -- ONCE per glide. `drumSettling` says the drum is committed to its detent — near
            -- enough home that the face is readable — which is all the splash needs to know.
            if not settlingFired and s >= SETTLING_S then
                settlingFired = true
                EventBus.Cue:Fire({ kind = "drumSettling" })
            end
```

Set `settlingFired = false` at **both** points where a new glide can begin:
- where `mode = "glide"` is assigned (in the spin branch, alongside `glideT0 = os.clock()`)
- in the `gongHit` cue handler, where the drum respins (alongside `mode = "spin"` and `spinUntil = os.clock() + SPIN_SEC`)

A latch never reset fires the cue once per session and every later round's splash falls back to `drumRest` — which looks exactly like this task never landed.

`drumRest` continues to fire exactly as it does now, unchanged.

- [ ] **Step 5: Split the gate in main.client.luau**

Currently `maybeShowReveal` does everything behind one `drumAtRest` flag and consumes `pendingReveal` by setting it to nil. The splash needs to fire earlier without consuming the record.

Add beside `local drumAtRest = false`:

```lua
-- Two gates, not one. The SPLASH — the player's own result — releases on `drumSettling`, ~0.7s
-- before the drum stops. Everything else (the tape badge, the ledger's LAST ROUND band, the
-- first-win onboarding beat) stays on `drumRest`, because those name the WORLD's throw and
-- releasing them early is the spoiler this gate exists to prevent.
local drumSettling = false
local splashDone = false
```

Extract the splash into its own function, declared immediately above `maybeShowReveal` (it reads `wallet` and `pendingReveal`, so confirm both are declared above it):

```lua
local function maybeShowSplash()
    if not drumSettling or splashDone then
        return
    end
    local p = pendingReveal
    -- `p.result` is nil whenever this player had no throw counted this round (a spectator, or a
    -- whiff), so the splash cannot appear for a round the player did not throw in.
    if not p or not p.result then
        return
    end
    splashDone = true
    EventBus.Splash:Fire({
        result = p.result,
        streak = wallet.currentStreak,
        pot = wallet.pointsAtStake,
        forfeited = p.forfeited,
    })
end
```

In `maybeShowReveal`, call `maybeShowSplash()` as the **first** line (drumRest implies settling, so a dropped `drumSettling` cue still releases the splash here), and **delete** the `EventBus.Splash:Fire` block from its body. Update the comment there — it currently says the splash "inherits this same gate", which will no longer be true; say instead that the splash releases on the earlier `drumSettling` gate and that this call is its fallback.

In the `EventBus.Cue` handler:

```lua
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumSettling" then
        drumSettling = true
        maybeShowSplash()
    elseif cue.kind == "drumRest" then
        drumSettling = true -- drumRest implies it, even if that cue was dropped
        drumAtRest = true
        maybeShowReveal()
    end
end)
```

In the `RevealResult` handler's `REVEAL_SAFETY` fallback, set **both** flags before calling, so a dropped cue strands neither part:

```lua
            drumSettling = true
            drumAtRest = true
            maybeShowReveal()
```

Wherever a new round resets `pendingReveal`/`drumAtRest` (the `RoundUpdate` handler), reset the two new flags alongside:

```lua
        drumSettling = false
        splashDone = false
```

`splashDone` is per-round, not per-reveal: without the reset the second round of a session would never splash.

- [ ] **Step 6: The standing check for client files**

Neither client file is loaded by any gate. Verify by reading:

1. `maybeShowSplash` is declared **above** `maybeShowReveal` and above the `EventBus.Cue` handler, and below `wallet` and `pendingReveal`.
2. `settlingFired` is reset on **every** path that starts a glide. Name them.
3. The `drumSettling` cue fires exactly once per round: trace glide → rest → respin.
4. `EventBus.Splash:Fire` appears exactly **once** in the file.
5. The tape badge, `lastRound`, `revealedWorldThrow` and the `EventBus.Onboard:Fire("win", ...)` beat are all still behind `drumAtRest` — none of them moved.
6. Every new local is declared before first use.

- [ ] **Step 7: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/DrumStep.luau roblox/tests/DrumStep.spec.luau \
        roblox/src/client/DrumController.client.luau roblox/src/client/main.client.luau
git commit -m "feat(roblox): your result lands with the drum, the world's throw when it stops"
```

---

## After the last task

Hand back for the owner's Studio gate. Nothing in this round is verifiable by any automated gate. What needs eyes:

- **the count itself** — does a big bank read as a payoff, or as a wait? Is the gold plate treatment festive or noisy? Does the bank button's drain finish together with the balance's climb?
- **the count's smoothness** — the whole point of Task 3. If it still steps visibly, the `RenderStepped` driver is not running or `render` is still fighting it.
- **the splash's new timing** — 2.75s. Does it land *with* the drum, or does it still feel late? And does it ever spoil the drum by arriving while it is visibly still turning?
- **the ring's digits** — seated, or now too high?
- **the UNDO card** — ivory over an unchosen throw button; does it read as a question, or as an ordinary available tile?

**Do not push without telling the owner first.** Every push to `m4b-zendojo-art-pass` auto-deploys the `roshambo_server_dev` App Runner service, which restarts the backend under any live Studio session.
