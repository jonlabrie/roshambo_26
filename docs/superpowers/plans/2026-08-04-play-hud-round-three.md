# Play HUD Round Three Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reclaim 6px of phone screen from the bank row, rename the throw-prompt mechanic to `UNDO?` on a full-size overlay with a two-second fuse, and redraw the round-timer ring as a smooth swept pie instead of 36 rotated rectangles.

**Architecture:** Four independent changes over the existing HUD. The arithmetic moves into `src/shared` (`HudLayout`, `RingTimer`, `HudModel`) where Lune can test it; the painting stays in `HudController.client.luau`, which no gate can load. Tasks are ordered so the two mechanical renames land before the visual change that depends on the new names.

**Tech Stack:** Luau, Rojo, Lune test harness (`lune run tests/run`), stylua, selene.

**Spec:** `docs/superpowers/specs/2026-08-04-play-hud-round-three-design.md`

## Global Constraints

- **`Active` discipline.** `TextButton`/`ImageButton` always sink touch. `Frame`/`TextLabel` sink only when `Active = true`. Task 6 grows an overlay to cover an entire live button; it **must stay `Active = false`** or the throw button beneath stops receiving taps and the mechanic breaks outright. No test can see this.
- **Never put a `UIStroke` on a `TextLabel`.** Contrast comes from an opaque backing. A stroke on a label outlines every glyph and fills the counters.
- **`src/shared` modules hold no Roblox globals.** No `Instance`, `Color3`, `UDim2`, `Enum`, `task`, `os`. They are dependency-injected and must run under Lune. `HudLayout.spec.luau` enforces this for `HudLayout` with a `typeof(value) == "number"` sweep over every export.
- **No gate can see the client files.** `lune run tests/run` never loads a `.client.luau` or `.server.luau`; `selene` does not resolve cross-module field types; `stylua` only formats. Before finishing any task touching a client file: reconcile every `HudLayout.X` / `view.X` / `aux.X` read against what those modules actually export, and confirm every local is declared **before** its first use — a forward reference resolves to a nil global, not an error.
- **selene fails on warnings.** Deleting the last *code* use of a local makes it an unused-variable warning and breaks CI. Comments do not count as uses.
- **Every task ends green:** `lune run tests/run`, `stylua --check src tests tools`, `selene src tools` — all from `roblox/`.
- **Absolute paths in Bash calls.** The working directory persists between calls in this environment; a bare `cd roblox` in one call has previously broken relative paths in later ones.

---

### Task 1: The bank row gives back 6px

**Files:**
- Modify: `roblox/src/shared/HudLayout.luau:70-74`, `roblox/src/shared/HudLayout.luau:88-92`
- Modify: `roblox/src/client/HudController.client.luau:113` (locals), `:805` (bank position)
- Modify: `roblox/src/client/OnboardingController.client.luau:68-75`, `:203-215`, `:240-242`
- Test: `roblox/tests/HudLayout.spec.luau`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `HudLayout.BANK_H = 36`, `HudLayout.BANK_GAP = 8` as the *actual* gap above the throw cluster, and `CLUSTER_TOP_FROM_BOTTOM` / `CLUSTER_TOP_FROM_BOTTOM_TOUCH` derived with `BANK_GAP` instead of `ROW_GAP`. No other task reads these.

**Context:** The HUD already sits 6px off the screen's bottom edge (`EDGE_BOTTOM = 6` in `HudController`, and the `ScreenGui` leaves `IgnoreGuiInset` default so its bottom edge *is* the screen's). The only slack in the 134px phone stack is the bank button. Separately, `HudLayout.BANK_GAP = 8` was declared for the gap above the throw cluster but only `OnboardingController` ever read it — `HudController` and `CLUSTER_TOP_FROM_BOTTOM` both used `ROW_GAP` (10). This task makes the constant mean its name, which is worth 2 of the 6 pixels.

- [ ] **Step 1: Update the failing tests first**

In `roblox/tests/HudLayout.spec.luau`, three assertions derive the cluster with `ROW_GAP`. Change all three to `BANK_GAP`:

```lua
    test("the cluster is bank + throws + tape, and nothing else", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH).toBe(
            HudLayout.EDGE + HudLayout.AREA_H_TOUCH + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
    end)
```

and in the later `describe("HudLayout — the ring beside the throw buttons", ...)` block:

```lua
    test("the cluster still covers bank + throws + tape", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
    end)
```

Then add a new test to the first `describe` block:

```lua
    test("BANK_GAP is the gap above the cluster, not a number nobody uses", function()
        -- It was declared for this gap and then only OnboardingController read it, while
        -- HudController and CLUSTER_TOP_FROM_BOTTOM both positioned the row with ROW_GAP. The
        -- two are different numbers, so the derivation above is what pins the repair: if a
        -- later edit puts ROW_GAP back, this fails.
        expect(HudLayout.BANK_GAP ~= HudLayout.ROW_GAP).toBe(true)
    end)

    test("the bank button stays comfortably hittable", function()
        -- The owner's ruling (spec §3): 36, not 32. Banking is the one irreversible action on
        -- this surface and a mis-tap costs real points. The throw buttons' 44px floor does not
        -- bind here — that floor is for the three targets hit every round under time pressure.
        expect(HudLayout.BANK_H).toBe(36)
    end)
```

The harness offers only `toBe`, `toBeCloseTo`, `toBeTruthy` and `toBeNil` — there is no `.never`
modifier, which is why the inequality is written out.

- [ ] **Step 2: Run the tests and watch them fail**

Run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`: `lune run tests/run`
Expected: FAIL — `CLUSTER_TOP_FROM_BOTTOM` is still derived with `ROW_GAP`, and `BANK_H` is 40.

- [ ] **Step 3: Change HudLayout**

Replace `roblox/src/shared/HudLayout.luau:70-74` with:

```lua
-- The bank button's row, directly above the throw cluster. Reserved whether or not a pot is
-- riding: an onboarding card clamped into a band that ignored it would land on the button the
-- moment a first win put one there.
--
-- 36, down from 40 (owner's gate 2026-08-04, spec §3). The HUD is already 6px off the bottom
-- edge — that is the floor, not a thing to re-litigate — so the only slack in the stack is
-- here. NOT below 36: banking is the one irreversible action on this surface. The throw
-- buttons' 44px floor does not bind, because that floor was set for the three targets a player
-- hits every round under time pressure.
HudLayout.BANK_H = 36

-- BANK_GAP is now actually the gap. It was declared for it and then only OnboardingController
-- read it, while HudController and CLUSTER_TOP_FROM_BOTTOM positioned the row with ROW_GAP (10)
-- — so the constant named for this gap had never been this gap. All three read it now, and the
-- correction is worth 2 of the 6 pixels this round reclaims.
HudLayout.BANK_GAP = 8
```

Replace `roblox/src/shared/HudLayout.luau:88-92` with:

```lua
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH = HudLayout.EDGE
    + HudLayout.AREA_H_TOUCH
    + HudLayout.BANK_GAP
    + HudLayout.BANK_H
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Move the bank button in HudController**

Near `roblox/src/client/HudController.client.luau:113` (where `local RING_GAP = HudLayout.RING_GAP` sits), add:

```lua
local BANK_GAP = HudLayout.BANK_GAP
```

At `:805`, change the bank button's position from `ROW_GAP` to `BANK_GAP`:

```lua
bankButton.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE_BOTTOM + AREA_H + BANK_GAP))
```

Confirm `ROW_GAP` still has at least one other code use in this file (it spaces the tape from the buttons). If it does not, delete the local — selene fails on unused variables.

- [ ] **Step 6: Route OnboardingController through CLUSTER_TOP_FROM_BOTTOM**

`OnboardingController` currently re-derives the whole stack by hand in three places — exactly the hand-copied arithmetic `HudLayout`'s own header (lines 5-10) was written to prevent.

**The declaration must move first.** `CLUSTER_TOP_FROM_BOTTOM` is declared at `:240-242`, *below* the `STATIC_ANCHORS` table at `:203-215` that will now read it. In Luau a forward reference resolves to a nil global rather than erroring, and `UDim2.new` on a nil would then fail at runtime in a file no test loads. Move the declaration (with its comment at `:233-239`) up to sit with the other layout locals after `:75`.

Then replace the three anchor offsets:

```lua
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
```

`CLUSTER_TOP_FROM_BOTTOM` is the top of the bank button; `+ BANK_GAP` is the clearance above it — the same total as the old hand-derived expression, expressed once.

- [ ] **Step 7: Delete the locals that just became unused**

After Step 6, `EDGE`, `AREA_H`, `ROW_GAP` and `BANK_H` in `OnboardingController` have no remaining **code** uses (they appear only in comments at `:176`, `:230`, `:234`). Delete all four declarations at `:68-74`. Keep `BANK_GAP` and `JUMP_CLEARANCE`.

Update the comment at `:176` so it names what the code now reads (`CLUSTER_TOP_FROM_BOTTOM` and `BANK_GAP`) rather than the five constants it used to hand-add. A stale comment describing a derivation that no longer exists is the exact failure mode that cost this project a round already.

Verify with: `grep -n "\bEDGE\b\|\bAREA_H\b\|\bROW_GAP\b\|\bBANK_H\b" roblox/src/client/OnboardingController.client.luau` — every remaining hit must be inside a comment.

- [ ] **Step 8: Run every gate**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run
stylua --check src tests tools
selene src tools
```
Expected: tests pass, stylua clean, selene 0 warnings.

- [ ] **Step 9: Commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau \
        roblox/src/client/HudController.client.luau roblox/src/client/OnboardingController.client.luau
git commit -m "fix(roblox): BANK_GAP finally is the gap, and the bank row gives back 6px"
```

---

### Task 2: RingTimer stops counting segments and starts measuring a sweep

**Files:**
- Modify: `roblox/src/shared/RingTimer.luau` (near-total rewrite)
- Test: `roblox/tests/RingTimer.spec.luau` (near-total rewrite)

**Interfaces:**
- Consumes: nothing.
- Produces, for Task 3:
  - `RingTimer.MIN_SWEEP_DEGREES: number`
  - `RingTimer.sweepDegrees(fraction: number): number`
  - `RingTimer.sweep(fraction: number): { rotationA: number, rotationB: number, bLit: boolean }`
  - `RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean` — unchanged
- Deleted, and Task 3 must stop calling them: `RingTimer.SEGMENTS`, `RingTimer.lit`, `RingTimer.angleAt`, `RingTimer.segmentWidth`.

**Context:** The ring is currently 36 `Frame`s, each rotated about its own centre and widened to overlap its neighbours. It draws a polygon, and the facets are visible — worse at 76px than 44px because they scale with the radius. The replacement draws a real pie from a track circle plus two half-discs, where a half-disc is a circular `Frame` whose `UIGradient.Transparency` steps hard at offset 0.5 and whose `UIGradient.Rotation` sweeps the cut. **This module owns only the angles; Task 3 owns the instances.**

The geometry, derived once so nobody has to re-derive it: a half-disc's visible half is the clockwise arc `[a, a + 180]` measured from the top. The gradient's visible side is the one *before* the step, and `Rotation = 0` points the gradient axis to the right, which is 90° clockwise from the top. Therefore **`UIGradient.Rotation = a + 180`**.

To light the clockwise arc `[0, θ]`:
- **θ ≤ 180** — half A lit at `a = 0` (covers 0–180); half B in the **track** colour at `a = θ` (covers θ–θ+180), painting back over the excess. Net lit: 0–θ.
- **θ > 180** — half A lit at `a = 0`; half B **also lit** at `a = θ - 180` (covers θ−180–θ). Union: 0–θ.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `roblox/tests/RingTimer.spec.luau` with:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RingTimer = require("../src/shared/RingTimer")

describe("RingTimer.sweepDegrees — how much of the circle is still there", function()
    test("a full round sweeps the whole circle", function()
        expect(RingTimer.sweepDegrees(1)).toBe(360)
    end)

    test("an empty round sweeps nothing — the ring is GONE", function()
        expect(RingTimer.sweepDegrees(0)).toBe(0)
    end)

    test("half a round sweeps half the circle", function()
        expect(RingTimer.sweepDegrees(0.5)).toBe(180)
    end)

    test("ANY time remaining sweeps at least MIN_SWEEP_DEGREES", function()
        -- The invariant the old segment count carried with math.ceil, restated for a continuous
        -- ring. A player with a sliver of a second must not see an EMPTY ring: the round is
        -- still open and the throw buttons are still live. 0.2s of a 20s round is 3.6 degrees,
        -- which at 44px is sub-pixel and renders as nothing at all.
        expect(RingTimer.sweepDegrees(0.0001)).toBe(RingTimer.MIN_SWEEP_DEGREES)
        expect(RingTimer.sweepDegrees(0.0001) > 0).toBe(true)
    end)

    test("the floor is big enough to actually see", function()
        -- A floor of, say, 0.5 degrees would satisfy "> 0" and still render as nothing. At 6
        -- degrees the arc is ~2px along a 38px-diameter phone ring: visible.
        expect(RingTimer.MIN_SWEEP_DEGREES >= 4).toBe(true)
    end)

    test("it is monotonic and never leaves the circle", function()
        local prev = -1
        for i = 0, 100 do
            local v = RingTimer.sweepDegrees(i / 100)
            expect(v >= prev).toBe(true)
            expect(v <= 360).toBe(true)
            expect(v >= 0).toBe(true)
            prev = v
        end
    end)

    test("a fraction outside [0,1] clamps rather than extrapolating", function()
        expect(RingTimer.sweepDegrees(-3)).toBe(0)
        expect(RingTimer.sweepDegrees(9)).toBe(360)
    end)
end)

describe("RingTimer.sweep — the two gradient rotations that draw that arc", function()
    test("half A never moves", function()
        -- It is the fixed half; only B moves and changes colour. Returned rather than exported
        -- as a bare constant so the pair that has to agree is produced in one place.
        for _, f in { 0, 0.1, 0.5, 0.7, 1 } do
            expect(RingTimer.sweep(f).rotationA).toBe(180)
        end
    end)

    test("under half a turn, B is the TRACK colour and paints back the excess", function()
        local s = RingTimer.sweep(0.25) -- 90 degrees
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(270) -- 90 + 180
    end)

    test("over half a turn, B is LIT and extends the arc", function()
        local s = RingTimer.sweep(0.75) -- 270 degrees
        expect(s.bLit).toBe(true)
        expect(s.rotationB).toBe(270)
    end)

    test("exactly half a turn is still the track branch", function()
        local s = RingTimer.sweep(0.5)
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(360)
    end)

    test("a full round lights the whole circle", function()
        local s = RingTimer.sweep(1)
        expect(s.bLit).toBe(true)
        expect(s.rotationB).toBe(360)
    end)

    test("an empty round lights nothing", function()
        local s = RingTimer.sweep(0)
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(180) -- B in track, exactly over A: nothing survives
    end)
end)

describe("RingTimer.sweep — what the two halves actually cover", function()
    -- The strongest test in this file: it reconstructs the painted arc from the rotations the
    -- way the renderer does, and checks it against sweepDegrees. A sign error, an off-by-180 or
    -- a flipped branch all fail here and nowhere else.
    local function litDegrees(fraction: number): number
        local s = RingTimer.sweep(fraction)
        -- A half-disc at UIGradient.Rotation R shows the clockwise arc [R - 180, R] from the top.
        local aStart = (s.rotationA - 180) % 360
        local bStart = (s.rotationB - 180) % 360
        local function covers(start: number, deg: number): boolean
            local d = (deg - start) % 360
            return d < 180
        end
        local count = 0
        for deg = 0, 359 do
            local inA = covers(aStart, deg + 0.5)
            local inB = covers(bStart, deg + 0.5)
            local lit
            if s.bLit then
                lit = inA or inB
            else
                lit = inA and not inB
            end
            if lit then
                count += 1
            end
        end
        return count
    end

    test("the painted arc matches the requested sweep, all the way round", function()
        for i = 0, 40 do
            local f = i / 40
            local want = RingTimer.sweepDegrees(f)
            local got = litDegrees(f)
            -- One degree of slack: the reconstruction samples whole degrees.
            expect(math.abs(got - want) <= 1).toBe(true)
        end
    end)

    test("the arc always starts at the top and runs clockwise", function()
        -- Degree 0 (the top) is lit for any live round and dark for a dead one.
        expect(litDegrees(0)).toBe(0)
        expect(litDegrees(0.02) > 0).toBe(true)
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

describe("RingTimer — the segmented ring is gone", function()
    test("nothing counts segments any more", function()
        -- The ring is drawn as a pie now (spec §4). These four were the segment API; leaving a
        -- stale one behind invites a caller that draws a polygon beside a circle.
        expect((RingTimer :: any).SEGMENTS).toBe(nil)
        expect((RingTimer :: any).lit).toBe(nil)
        expect((RingTimer :: any).angleAt).toBe(nil)
        expect((RingTimer :: any).segmentWidth).toBe(nil)
    end)
end)
```

- [ ] **Step 2: Run the tests and watch them fail**

Run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`: `lune run tests/run`
Expected: FAIL — `sweepDegrees` and `sweep` do not exist, and the four deleted names still do.

- [ ] **Step 3: Rewrite RingTimer**

Replace the whole of `roblox/src/shared/RingTimer.luau` with:

```lua
--!strict
-- The round timer's ring, as arithmetic. Roblox has no SVG, no arc primitive and no radial
-- fill, so the PWA's stroke-dash sweep (src/components/PieTimer.tsx) is rebuilt from a track
-- circle and two half-discs. A half-disc is a circular Frame whose UIGradient.Transparency
-- steps hard at offset 0.5; UIGradient.Rotation sweeps the cut. No clipping (Roblox's
-- ClipsDescendants carries a documented caveat about rotated descendants) and no image asset.
--
-- This module owns the ANGLES. HudController owns the instances and paints what it is told.
--
-- THE GEOMETRY, derived once so nobody re-derives it:
-- a half-disc's visible half is the clockwise arc [a, a + 180] measured from the top. The
-- gradient's visible side is the one BEFORE the step, and Rotation = 0 points the gradient axis
-- to the right — 90 degrees clockwise from the top. Hence:
--
--     UIGradient.Rotation = a + 180
--
-- To light the clockwise arc [0, theta]:
--   theta <= 180 : half A lit at a = 0 (covers 0-180); half B in TRACK at a = theta
--                  (covers theta..theta+180), painting back over the excess. Net: 0-theta.
--   theta >  180 : half A lit at a = 0; half B ALSO LIT at a = theta - 180. Union: 0-theta.
--
-- No Roblox globals — this runs under Lune like everything else in src/shared.
local RingTimer = {}

-- The smallest arc a live round may draw.
--
-- This is the old segment count's `math.ceil` restated for a continuous ring, and it is
-- load-bearing: an empty ring must mean the round is over and nothing else. A raw
-- fraction * 360 breaks that silently, because 0.2s of a 20s round is 3.6 degrees — sub-pixel
-- at 44px, and it renders as nothing while the throw buttons are still live. 6 degrees is
-- roughly 2px along a 38px-diameter phone ring: small, but visibly not gone.
RingTimer.MIN_SWEEP_DEGREES = 6

export type Sweep = { rotationA: number, rotationB: number, bLit: boolean }

-- Degrees of the clockwise sweep for `fraction` of the round remaining.
function RingTimer.sweepDegrees(fraction: number): number
    local f = math.clamp(fraction, 0, 1)
    if f <= 0 then
        return 0
    end
    return math.max(f * 360, RingTimer.MIN_SWEEP_DEGREES)
end

-- The two gradient rotations that draw that sweep, and whether half B is lit or track.
--
-- `rotationA` is always 180 and is RETURNED rather than exported as a bare constant, so the
-- pair that must agree is produced in one place and a renderer cannot pick up one without the
-- other.
function RingTimer.sweep(fraction: number): Sweep
    local theta = RingTimer.sweepDegrees(fraction)
    if theta <= 180 then
        return { rotationA = 180, rotationB = theta + 180, bLit = false }
    end
    return { rotationA = 180, rotationB = theta, bLit = true }
end

-- Whether the ring should read as urgent. `escalateAt` is passed in rather than owned here so
-- the ring and the escalation prompt cannot drift apart — see HudModel.ESCALATE_AT.
--
-- Deliberately NOT gated on `secondsLeft > 0` the way HudModel's `escalate` is. That gate exists
-- because a prompt at zero would be pointless; a colour at zero is harmless, and at zero there
-- is no arc to colour anyway.
function RingTimer.isWarning(secondsLeft: number, escalateAt: number): boolean
    return secondsLeft <= escalateAt
end

return RingTimer
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS. `HudController.client.luau` still calls `RingTimer.lit` and `RingTimer.SEGMENTS` at this point — that is fine and invisible to the harness, and Task 3 repairs it. **Do not partially patch `HudController` here**; the two live in separate commits on purpose.

- [ ] **Step 5: Verify the floor is real, by breaking it**

Temporarily change `MIN_SWEEP_DEGREES` to `0` and re-run. Expected: the "ANY time remaining" test and "the floor is big enough" test both fail. Then temporarily flip `sweep`'s branch to `theta < 180` and re-run: expected, "exactly half a turn is still the track branch" fails. Restore both. This is the only way to know the two tests that matter are not vacuous — no gate can see the ring itself.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RingTimer.luau roblox/tests/RingTimer.spec.luau
git commit -m "feat(roblox): the ring is a swept arc, not a count of segments"
```

---

### Task 3: HudController draws the ring as a pie

**Files:**
- Modify: `roblox/src/shared/HudLayout.luau:64-67` (the band's derivation)
- Modify: `roblox/src/client/HudController.client.luau:910-1021` (construction), `:1348-1358` (paint)
- Test: `roblox/tests/HudLayout.spec.luau` (the band's comment only — the existing assertions still hold)

**Interfaces:**
- Consumes: `RingTimer.sweep`, `RingTimer.sweepDegrees`, `RingTimer.isWarning`, `RingTimer.MIN_SWEEP_DEGREES` from Task 2.
- Produces: nothing other tasks read.

**Context:** This is the task no gate can see. Read the Global Constraints again before starting. The 36 segment `Frame`s and their `SEG_W` overlap arithmetic are deleted and replaced with four concentric layers inside the existing `ring` `TextButton`. Everything else about the ring — its slot, its size (`RING_D`), its `WASHI`-at-0.3 backing, its corner radius, its role as the ledger's door, the two-stage tap gesture, `ringScale`'s press feedback, the green/red threshold shared with `HudModel.ESCALATE_AT`, and the drum-rest spoiler gate on the glyph — is unchanged.

- [ ] **Step 1: Retune the band in HudLayout**

`RING_THICKNESS` is currently derived as 7.5% of `RING_D` because it described a stroke around a ragged segment ring. It is now the band width directly, and the centre disc's edge defines its inner boundary. Replace `roblox/src/shared/HudLayout.luau:64-67` with:

```lua
-- The ring's band width — the painted annulus between the pie's outer edge and the centre disc.
-- A literal per tier now, not a fraction of RING_D: the pie's inner edge is exact (the disc IS
-- that edge), so there is nothing left for a proportional stroke to approximate. Desktop steps
-- 6 -> 5 and the centre grows to match, per the owner's "the inner circle can grow to fill the
-- newly downsized ring" (spec §4).
HudLayout.RING_THICKNESS = 5
HudLayout.RING_THICKNESS_TOUCH = 3
```

The existing `HudLayout.spec.luau` assertions on these (`>= 3` for both, and desktop `>` touch) still hold at 5 and 3 — do not weaken them. Update the surrounding comment in the spec file if it describes a proportional stroke.

Run `lune run tests/run` — expected: PASS, unchanged.

- [ ] **Step 2: Replace the ring's construction**

In `roblox/src/client/HudController.client.luau`, the block from `local RING_INSET = 4` (`:916`) through the end of the `ringDisc` construction (`:997`) is replaced. Keep `RING_D`, `RING_THICKNESS`, the three colour constants, and the `ring` `TextButton` itself exactly as they are.

Delete: `RING_R`, `SEG_W`, the `local segments: { Frame } = {}` table and its `for i = 1, RingTimer.SEGMENTS` loop, `RING_DISC_GAP`, `RING_DISC_D`, and the hand-built `ringDisc` + `ringDiscCorner` pair.

Insert, in place of them:

```lua
-- The pie pulls in from the backing square's edge by this much. 3, down from 4: with the
-- faceting gone the arc no longer needs the extra breathing room a ragged outer edge wanted.
local RING_INSET = 3
local RING_OD = RING_D - 2 * RING_INSET
local RING_DISC_D = RING_OD - 2 * RING_THICKNESS

-- A concentric circle inside the ring button. UICorner at scale 0.5 is a true, antialiased
-- circle at any diameter — which is the whole reason this construction replaces 36 rotated
-- rectangles. Active = false: the ring BUTTON sinks, nothing inside it does.
local function ringCircle(diameter: number, color: Color3, zIndex: number): Frame
    local f = Instance.new("Frame")
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
local function ringHalf(diameter: number, color: Color3, zIndex: number): (Frame, UIGradient)
    local f = ringCircle(diameter, color, zIndex)
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
ringCircle(RING_OD, RING_TRACK, 1)
local ringHalfA, ringGradA = ringHalf(RING_OD, RING_LIVE, 2)
local ringHalfB, ringGradB = ringHalf(RING_OD, RING_TRACK, 3)

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
```

All four bindings are used by the paint step below (`ringHalfA` and `ringHalfB` take the colour, `ringGradA` and `ringGradB` take the rotation), so none of them will trip selene's unused-variable check. The track circle's return value is deliberately discarded — nothing ever repaints it.

- [ ] **Step 3: Raise the readout onto the bigger disc**

At `:1005-1006`, change the count's size and weight:

```lua
ringCount.TextSize = if TOUCH then 20 else 34
ringCount.Font = Enum.Font.GothamBold
```

Add above them:

```lua
-- FIXED TextSize, not TextScaled: the countdown runs 20 -> 1, and TextScaled would visibly jump
-- the digits' size at the two-to-one-character boundary every single round. Two digits at 20px
-- clear a 32px disc; at 34px they clear a 60px one.
--
-- GothamBold, down from GothamBlack (owner's gate 2026-08-04). Weight was the lever, not size —
-- a one-point reduction was indistinguishable at both tiers. Bold rather than Medium because at
-- 20px over moving canyon terrain the lighter face thins out, and the phone is the tier that
-- has to survive a busy background. The ring's readout only; nothing else in the HUD moves.
```

Set `ringCount.ZIndex = 5` and give the glyph box the same, so both sit above the disc.

The `glyphBox(ringDisc, 0.82)` call is unchanged — it is proportional and scales with the larger disc for free.

- [ ] **Step 4: Replace the paint**

At `:1352-1357`, replace the segment loop:

```lua
    local litCount = RingTimer.lit(ringFrac, RingTimer.SEGMENTS)
    local ringHot = RingTimer.isWarning(view.secondsLeft, HudModel.ESCALATE_AT)
    for i, seg in segments do
        seg.BackgroundColor3 = if i <= litCount then (if ringHot then RING_HOT else RING_LIVE) else RING_TRACK
    end
```

with:

```lua
    local ringHot = RingTimer.isWarning(view.secondsLeft, HudModel.ESCALATE_AT)
    local ringLit = if ringHot then RING_HOT else RING_LIVE
    local sweep = RingTimer.sweep(ringFrac)
    ringGradA.Rotation = sweep.rotationA
    ringGradB.Rotation = sweep.rotationB
    ringHalfA.BackgroundColor3 = ringLit
    ringHalfB.BackgroundColor3 = if sweep.bLit then ringLit else RING_TRACK
```

`ringKnown`, `ringFrac`, `ringCount.TextColor3`, the `worldThrow` glyph swap and everything after are unchanged.

- [ ] **Step 5: The standing check for client files**

No test loads this file, so read the changed region against reality before running anything:

1. Every `RingTimer.X` read resolves to something Task 2 exports — in particular **no remaining `RingTimer.lit`, `RingTimer.SEGMENTS`, `RingTimer.angleAt` or `RingTimer.segmentWidth` anywhere in the file.** Verify: `grep -n "RingTimer\." roblox/src/client/HudController.client.luau`
2. Every `HudLayout.X` read resolves to something `HudLayout` exports.
3. Every local used in the new code is **declared above its first use** — `ring`, `RING_D`, `RING_THICKNESS`, `WASHI`, `RING_TRACK`, `RING_LIVE`, `RING_HOT`, `glyphBox`, `THROWS`. A forward reference resolves to a nil global.
4. `segments` no longer appears anywhere: `grep -n "segments\|SEG_W\|RING_R\b\|RING_DISC_GAP" roblox/src/client/HudController.client.luau`
5. Nothing inside the ring is `Active = true`.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the round ring is drawn, not approximated"
```

---

### Task 4: The SWITCH → UNDO rename, in the shared model

**Files:**
- Modify: `roblox/src/shared/HudModel.luau:35-40`, `:64`, `:71`, `:82`, `:91-127`, `:133-135`, `:195`
- Test: `roblox/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Tasks 5 and 6:
  - `HudModel.UNDO_PROMPT_SECONDS` (was `SWITCH_PROMPT_SECONDS`) — **value unchanged at 1 in this task**; Task 6 changes it.
  - `HudModel.undoPromptExpired(setAt, now)` (was `switchPromptExpired`)
  - `Inputs.undoPrompt`, `View.undoPrompt`, `TapState.undoPrompt` (all were `switchPrompt`)
- Unchanged: the `"choose"` / `"prompt"` / `"clear"` / `"ignore"` action strings returned by `tapAction`. They already name the act, not the word.

**Context:** This is a **pure rename with no behaviour change**, kept in its own commit so its diff reads as one. The mechanic's copy is changing from `SWITCH?` to `UNDO?` because `SWITCH?` described something the button has never done: confirming that prompt clears the choice entirely — it does not switch the player to the glyph they tapped. That is why both unchosen buttons act as back-out proxies. Leaving the internal name as `switchPrompt` while the surface says `UNDO?` is exactly the stale-name trap that has cost this project a round already.

- [ ] **Step 1: Rename in the test file first**

In `roblox/tests/HudModel.spec.luau`, rename every occurrence of `switchPrompt` → `undoPrompt`, `switchPromptExpired` → `undoPromptExpired`, and `SWITCH_PROMPT_SECONDS` → `UNDO_PROMPT_SECONDS`. There are roughly 30, at lines 16, 73, 84-85, 90-93, 181-182, 301, 310, 314, 320, 326-370, 376, 384-392, 432, 466-467, 484.

Update the prose in test names and comments that says "switch" about this mechanic — e.g. `"switchPrompt does not survive a send"` becomes `"undoPrompt does not survive a send"`.

**Leave line 115 alone** (`"the preference switch silences it outright"`) — that "switch" means a settings toggle, not this mechanic.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `lune run tests/run`
Expected: FAIL — `HudModel.undoPromptExpired` is nil, and `undoPrompt` reads as nil throughout.

- [ ] **Step 3: Rename in HudModel**

Rename in `roblox/src/shared/HudModel.luau`:
- `Inputs.switchPrompt` → `Inputs.undoPrompt` (`:40`)
- `View.switchPrompt` → `View.undoPrompt` (`:64`, and the assignment at `:195`)
- `TapState.switchPrompt` → `TapState.undoPrompt` (`:82`, and all five returns in `applyTap` at `:121-127`)
- `inputs.switchPrompt` → `inputs.undoPrompt` in `tapAction` (`:107`)
- `HudModel.SWITCH_PROMPT_SECONDS` → `HudModel.UNDO_PROMPT_SECONDS` (`:71`, `:134`)
- `HudModel.switchPromptExpired` → `HudModel.undoPromptExpired` (`:133`)

Then update the comments that describe the mechanic by the old word:
- `:35-36` — "the glyph currently carrying a SWITCH? prompt" → "an UNDO? prompt"
- `:91-99` — the `tapAction` header block: `"prompt" — raise SWITCH? over `symbol`` → `raise UNDO? over `symbol``; "The switch path is the only way out" → "The undo path is the only way out"; "CONFIRMING A SWITCH UNLOCKS; IT DOES NOT SELECT" → "CONFIRMING AN UNDO UNLOCKS; IT DOES NOT SELECT".

Add to the `UNDO_PROMPT_SECONDS` comment block a line recording why the word changed:

```lua
-- The word changed from SWITCH? to UNDO? on 2026-08-04 because SWITCH? described something this
-- button has never done: answering it CLEARS the choice, it does not move the choice to the
-- glyph that was tapped. That is what makes either unchosen button a back-out proxy.
```

- [ ] **Step 4: Verify nothing was missed**

```bash
grep -n "switchPrompt\|SWITCH_PROMPT\|switchPromptExpired" roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
```
Expected: no output.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: FAIL still — `main.client.luau` and `HudController.client.luau` are not loaded by the harness, so they cannot break it, but **`HudModel.spec.luau` must now pass**. If anything else fails, it is a real miss. Task 5 repairs the two client files.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "refactor(roblox): the prompt is an UNDO, and now says so in the model"
```

---

### Task 5: The SWITCH → UNDO rename, in the client

**Files:**
- Modify: `roblox/src/client/main.client.luau:92-93`, `:231`, `:408-411`, `:494-495`, `:525-526`, `:663-665`
- Modify: `roblox/src/client/HudController.client.luau:566-630`, `:1304-1306`, and the comments at `:352`, `:1072`, `:1075`, `:1137`

**Interfaces:**
- Consumes: the renamed `HudModel` surface from Task 4.
- Produces: `undoPill` / `undoLabel` / `setUndoPrompt` in `HudController`, which Task 6 restyles.

**Context:** Mechanical rename, no behaviour change, no visual change. Task 6 does the look. Neither of these files is loaded by any gate, so the rename's completeness has to be verified by grep rather than by a green run.

- [ ] **Step 1: Rename in main.client.luau**

- `local switchPrompt` → `local undoPrompt`; `local switchPromptAt` → `local undoPromptAt` (`:92-93`)
- the `switchPrompt = switchPrompt` field in `publish()` → `undoPrompt = undoPrompt` (`:231`)
- `HudModel.applyTap({ chosen = chosen, switchPrompt = switchPrompt }, ...)` → `undoPrompt = undoPrompt` (`:408`), and `nextState.switchPrompt` → `nextState.undoPrompt` (`:410`)
- the clears at `:494-495` and `:525-526`
- `HudModel.switchPromptExpired(switchPromptAt, os.clock())` → `HudModel.undoPromptExpired(undoPromptAt, os.clock())` and the two clears beneath it (`:663-665`)

**Leave alone:** `:31` ("one remote for every preference, never one per switch"), `:267` ("the preference switch"), `:434` and `:436` ("there is deliberately not a second one per switch", "The switch's own paint is optimistic in LedgerController"). Those mean settings toggles, not this mechanic. Read each in context before deciding.

- [ ] **Step 2: Rename in HudController.client.luau**

- `switchPill` → `undoPill`, `switchLabel` → `undoLabel`, `setSwitchPrompt` → `setUndoPrompt` (`:579-630`)
- `switchPill.Name = "SwitchPrompt"` → `undoPill.Name = "UndoPrompt"`
- `view.switchPrompt` → `view.undoPrompt` at `:1304` and `:1306`
- the comment block at `:566-578`, which explains the mechanic in the old word throughout
- the cross-references in other comments at `:352`, `:1072`, `:1075`, `:1137` that cite `switchLabel` by name

**Leave alone:** `:89` ("the same switch so its safe band") — that is the touch-tier boolean.

- [ ] **Step 3: Verify nothing was missed, and nothing over-renamed**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
grep -rn "switchPrompt\|switchPill\|switchLabel\|setSwitchPrompt\|SWITCH_PROMPT\|SWITCH?" roblox/src roblox/tests
```
Expected: no output.

```bash
grep -rn "switch\|Switch" roblox/src/client/main.client.luau roblox/src/client/HudController.client.luau
```
Expected: only the settings-toggle and touch-tier senses listed in Steps 1 and 2. Read every hit.

- [ ] **Step 4: The standing check for client files**

Confirm every `view.X` read in `HudController`'s `render` resolves to a field `HudModel.view` actually returns — `undoPrompt` in particular, since it was just renamed on both sides and a mismatch here would silently disable the prompt with every gate green.

- [ ] **Step 5: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/main.client.luau roblox/src/client/HudController.client.luau
git commit -m "refactor(roblox): carry the UNDO rename into the client"
```

---

### Task 6: UNDO? covers the button, and lasts long enough to read

**Files:**
- Modify: `roblox/src/shared/HudModel.luau` (the `UNDO_PROMPT_SECONDS` value and its comment)
- Modify: `roblox/src/client/HudController.client.luau:579-617` (the pill's size, corner, copy and type)
- Test: `roblox/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: the renamed surface from Tasks 4 and 5.
- Produces: nothing.

**Context:** One second was too short to notice, read and answer. The overlay was also a 24px-tall pill holding 7 characters across 36px of content box on a phone, which clipped to roughly `WITC` — the shorter word plus the full-button box is what fixes that.

- [ ] **Step 1: Write the failing test**

In `roblox/tests/HudModel.spec.luau`, the describe block currently named for a one-second fuse (`:459`) becomes:

```lua
describe("HudModel.UNDO_PROMPT_SECONDS — a two-second fuse", function()
    test("it is two seconds", function()
        -- One second was too quick to notice, read and answer (owner's gate 2026-08-04). Both
        -- outcomes of expiry are still safe — expiring restores exactly the state before the
        -- stray tap, and answering only ever unlocks — so a longer fuse costs nothing but a
        -- question hanging over a live button, and two seconds is short enough for that.
        expect(HudModel.UNDO_PROMPT_SECONDS).toBe(2)
    end)

    test("the fuse burns for the whole two seconds", function()
        local t = 500
        expect(HudModel.undoPromptExpired(t, t + 1.99)).toBe(false)
        expect(HudModel.undoPromptExpired(t, t + 2)).toBe(true)
    end)
end)
```

The generic boundary test at `:389-393` reads `HudModel.UNDO_PROMPT_SECONDS` symbolically and needs no change — leave it, since it is what proves the predicate tracks the constant rather than a literal.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `lune run tests/run`
Expected: FAIL — the constant is still 1.

- [ ] **Step 3: Change the constant**

In `roblox/src/shared/HudModel.luau`, set `HudModel.UNDO_PROMPT_SECONDS = 2` and rewrite the comment above it, which currently argues for one second:

```lua
-- TWO SECONDS. Four was chosen when a prompt was the only thing on screen and in practice it
-- lingered; one replaced it and proved too quick to notice, read and answer (owner's gate
-- 2026-08-04). Both outcomes of expiry are safe — expiring restores exactly the state before
-- the stray tap, and answering only ever unlocks — so the cost of a longer fuse is only a
-- question hanging over a live button, and two seconds is short enough for that.
```

Keep the word-change note added in Task 4.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Grow the overlay to the button**

In `roblox/src/client/HudController.client.luau`, at the `undoPill` construction (`:587`, `:594`):

```lua
undoPill.Size = UDim2.fromOffset(BTN_W, BTN_H)
```

and change its corner radius from 6 to 8, matching a throw button's:

```lua
corner(undoPill, 8)
```

Replace the sizing comment above it with:

```lua
-- EXACTLY THE BUTTON, both dimensions, both tiers (owner's gate 2026-08-04). It anchors at
-- (0.5, 0.5) on the button's centre, so it covers it precisely.
--
-- IT MUST STAY Active = false. It is a Frame, and the tap that answers it is delivered to the
-- TextButton underneath — a full-size overlay that sank would swallow the very tap that
-- resolves it, and the mechanic would break outright with every gate green.
```

Do **not** set `Active` on it. Do not change its `ZIndex` (4), its `WASHI` fill, or its `SEL_BLUE` stroke — the stroke is on the Frame, which is correct; never move it to the label.

`setUndoPrompt`'s position arithmetic is unchanged: `((i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, BTN_H / 2)` already centres the pill on the button at any size.

- [ ] **Step 6: Set the copy and let it fill**

At the `undoLabel` construction (`:604`, `:614`):

```lua
undoLabel.Text = "UNDO?"
```

and raise the size constraint:

```lua
    constraint.MaxTextSize = 22
```

Replace the comment above the `TextScaled` block with:

```lua
-- TextScaled + a MaxTextSize constraint, same pattern as `bankButton`. The old copy was seven
-- characters in a 36px content box on a phone and clipped to roughly "WITC"; five characters in
-- the same box land near 13px, which reads. The constraint caps growth on the wide tier — at
-- desktop's 68px content box, five characters of GothamBold cap out near 22px, and higher would
-- clip the word on the wide tier instead of the narrow one.
```

Keep `Enum.Font.GothamBold`. The owner's ruling was that size, not the typeface, was the problem — no font-family change anywhere in the HUD.

- [ ] **Step 7: The standing check for client files**

1. `undoPill.Active` is never assigned anywhere in the file. Verify: `grep -n "undoPill" roblox/src/client/HudController.client.luau`
2. `BTN_W` and `BTN_H` are declared above the `undoPill` construction.
3. No `UIStroke` was added to `undoLabel`.
4. The `SWITCH?` string appears nowhere: `grep -rn "SWITCH" roblox/src roblox/tests`

- [ ] **Step 8: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): UNDO? covers the button it questions, and waits to be read"
```

---

## After the last task

The Studio prototype `RingProto` is still parented to `PlayerGui` in the owner's running session. Clear it before the owner's gate so it cannot be mistaken for the shipped ring:

```lua
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local proto = pg:FindFirstChild("RingProto")
if proto then proto:Destroy() end
```

Then hand back for the owner's Studio gate. Nothing in this round is verifiable by any automated gate: what needs eyes is the ring's smoothness at both tiers, whether the digits read at GothamBold 20 on a phone over moving terrain, whether `UNDO?` is legible on a 44px square, and that tapping an unchosen glyph still resolves — the `Active = false` requirement in Task 6 is the one change that could break the throw mechanic outright with every test green.

**Do not push without telling the owner first.** Every push to `m4b-zendojo-art-pass` auto-deploys the `roshambo_server_dev` App Runner service, which restarts the backend under any live Studio session.
