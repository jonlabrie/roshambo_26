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

