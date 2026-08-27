# Task 3 report — HudController draws the ring as a pie

Status: DONE. Commit: see bottom.

## What changed

### 1. `roblox/src/shared/HudLayout.luau` (Step 1)

`RING_THICKNESS` / `RING_THICKNESS_TOUCH` are no longer `math.max(3, math.round(RING_D * 0.075))`.
They are literals — 5 and 3 — with the brief's comment verbatim. Numbers-only; no Roblox globals
introduced, so `HudLayout.spec.luau`'s Lune load is unaffected.

Resulting geometry (worth recording, because nothing tests it):

| tier    | RING_D | RING_INSET | RING_OD | RING_THICKNESS | RING_DISC_D |
|---------|--------|-----------|---------|----------------|-------------|
| desktop | 76     | 3         | 70      | 5              | **60**      |
| touch   | 44     | 3         | 38      | 3              | **32**      |

Those are exactly the two diameters the brief's Step 3 comment cites ("Two digits at 20px clear a
32px disc; at 34px they clear a 60px one"), so the band retune and the readout retune agree.

### 2. `roblox/tests/HudLayout.spec.luau`

Assertions untouched and not weakened — `>= 3` for both tiers and desktop `>` touch all still hold
at 5 and 3. Only the test's *name* and a new comment changed, because the old name ("the stroke
scales with the ring and never vanishes") asserted a proportionality that is now false. It reads
"the band stays visible at both tiers, and the phone's is the narrower".

### 3. `roblox/src/client/HudController.client.luau`

**Construction (Step 2).** Deleted: `RING_R`, `SEG_W`, `local segments: { Frame } = {}` and its
`for i = 1, RingTimer.SEGMENTS` loop, `RING_DISC_GAP`, the old `RING_DISC_D` derivation, and the
hand-built `ringDisc` + `ringDiscCorner` pair. `RING_INSET` went 4 → 3.

Inserted the brief's code verbatim: `ringCircle(diameter, color, zIndex)`, `ringHalf(...)` returning
`(Frame, UIGradient)`, then the four layers at ZIndex 1/2/3/4 — track circle (return value
discarded), `ringHalfA`/`ringGradA` at RING_LIVE, `ringHalfB`/`ringGradB` at RING_TRACK, and the
centre disc at `BackgroundTransparency = 0`.

**Readout (Step 3).** `TextSize` 14/18 → 20/34, `Font` GothamBlack → GothamBold, `ZIndex = 5`, with
the brief's comment verbatim. The `glyphBox(ringDisc, 0.82)` call is unchanged; its box also gets
`ZIndex = 5`. I restored a two-line comment describing what the readout *is* (seconds, swapping to
the world-throw glyph on the drum-rest gate) — the brief's replacement block had removed it along
with the disc's own commentary, and that sentence is the only pointer from here to
`main.client.luau`'s spoiler gate.

**Paint (Step 4).** The `litCount` + segment loop is replaced by the brief's six lines verbatim:
`ringHot` → `ringLit` → `RingTimer.sweep(ringFrac)` → two gradient rotations and two background
colours. `ringKnown`, `ringFrac`, `ringCount.TextColor3`, the glyph swap and everything after are
byte-identical.

**Two comment corrections outside the replaced blocks.** The ring's section header still said "the
sweep is a ring of discrete segments — RingTimer says how many are lit, this paints them", and the
`Active` note said "Its segments and the centred readout". Both are now false statements about the
code directly beneath them, so I corrected the two phrases (header now: "a track circle and two
gradient-cut half-discs — RingTimer owns the angles, this owns the instances and paints what it is
told"; the other: "Its pie layers"). No behaviour, no values, no structure changed by either.

Nothing else in the ring was touched: slot/`Position`, `RING_D` size, the `WASHI`-at-0.3 backing,
`corner(ring, 8)`, the ledger-door role, the two-stage tap, `ringScale`, `HudModel.ESCALATE_AT`,
and the drum-rest spoiler gate are all as they were.

## Step 5 — the standing check, item by item

**1. Every `RingTimer.X` read resolves to a Task-2 export.**

```
$ grep -n "RingTimer\." roblox/src/client/HudController.client.luau
1373:    local ringHot = RingTimer.isWarning(view.secondsLeft, HudModel.ESCALATE_AT)
1375:    local sweep = RingTimer.sweep(ringFrac)
```

Two reads, both exported. The five broken sites (old `:919`, `:952`, `:953`, `:962`, `:1354`) are
gone. Repo-wide proof that no deleted member survives anywhere:

```
$ grep -rn "RingTimer\.lit\|RingTimer\.SEGMENTS\|RingTimer\.angleAt\|RingTimer\.segmentWidth" roblox/src roblox/tests
(none)
```

Note `RingTimer.MIN_SWEEP_DEGREES` and `RingTimer.sweepDegrees` are *not* read by HudController —
that is correct, not an oversight: `sweep()` applies the floor internally and returns the pair, which
is precisely why Task 2 returns `rotationA` rather than exporting a bare 180.

**2. Every `HudLayout.X` read resolves.** All 17 distinct reads in the file
(`JUMP_CLEARANCE, EDGE, TILE, TILE_TOUCH, ROW_GAP, BTN_H, BTN_H_TOUCH, RING_D, RING_D_TOUCH,
RING_THICKNESS, RING_THICKNESS_TOUCH, RING_GAP, BANK_H, BANK_GAP, AREA_H, AREA_H_TOUCH,
CLUSTER_TOP_FROM_BOTTOM, CLUSTER_TOP_FROM_BOTTOM_TOUCH`) are assigned in `HudLayout.luau`. The two
this task touched (`RING_THICKNESS`, `RING_THICKNESS_TOUCH`) still exist under the same names.

**3. Every local declared above its first use.** Verified in file order:
`WASHI`:64, `LOSS_RED`:66, `THROWS`:84, `glyphBox`:165, `RING_D`:912, `RING_THICKNESS`:913,
`RING_INSET`:916, `RING_OD`:917, `RING_DISC_D`:918, `RING_TRACK`:920, `RING_LIVE`:921,
`RING_HOT`:922, `ring`:924. First use of any of them in new code is `ringCircle` at :953, and the
three layer constructions at :989-991. `ringHalfA/ringGradA/ringHalfB/ringGradB` are declared at
:990-991 and first read at :1376-1379 inside `render`, which is defined far below. No forward
reference, so nothing silently resolves to a nil global.

**4. `segments` gone.**

```
$ grep -n "segments\|SEG_W\|RING_R\b\|RING_DISC_GAP" roblox/src/client/HudController.client.luau
1000:-- RING_DISC_GAP is deleted, because it existed only to hold the disc clear of the segments'
```

The single hit is inside the brief's own comment explaining the deletion. No live code.

**5. Nothing inside the ring is `Active = true`.**

```
$ grep -n "Active = true" roblox/src/client/HudController.client.luau
(none)
```

Not one `Active = true` in the whole file. `ringCircle` sets `Active = false` explicitly, so all four
layers are non-sinking; `ringCount` keeps its existing `Active = false`; `glyphBox` creates a plain
Frame (default `Active = false`). The `ring` `TextButton` is the only sinking pixel, exactly as
before — the surface's camera-drag hole is unchanged in size.

**Additional checks I ran beyond the five, since no gate can see this file:**

- *No `UIStroke` on a `TextLabel`* — none added; the readout's contrast comes from the disc, which
  this task made fully opaque.
- *ZIndex ordering is total, not partial* — 1 (track) < 2 (half A) < 3 (half B) < 4 (disc) < 5
  (digits, glyph box). No layer left at the default. The `ScreenGui` does not set `ZIndexBehavior`,
  so it is `Sibling` (the file already relies on this at :521 for the throw-tile halo): children draw
  above their parent regardless, and siblings order by ZIndex — which is exactly what the four
  same-parent layers need.
- *Gradient endpoint sanity, by hand against RingTimer's derivation* —
  `frac 0` → A=180/B=180, bLit false: half B (track, ZIndex 3) covers the same [0,180] as half A and
  paints it out; the rest is the track circle. Ring reads empty. Correct — an empty ring means the
  round is over.
  `frac 0.5` → A=180/B=360, bLit false: A lit [0,180], B track [180,360]. Half the circle.
  `frac 1` → A=180/B=360, bLit true: rotation 360 is a=180, so B is lit over [180,360] and the union
  with A is the full circle. No seam.
- *`UIGradient` tinting* — only `Transparency` is set; `Color` stays the default white sequence, so
  it does not tint `BackgroundColor3`. The green/red swap on the halves survives the gradient.

## Gate output (verbatim)

```
$ cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
$ lune run tests/run
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: .../roblox/tests/HandlerQueue.spec:80: boom

970 passed, 0 failed, 970 total
$ stylua --check src tests tools
(clean)
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

(The two `[WARN]` lines are `HandlerQueue.spec`'s own deliberate-failure fixtures printing, present
before this task.)

## Concerns

1. **The real gate is a human in Studio, and it has not happened.** Nothing here proves the ring
   *renders*. `lune run tests/run` never loads a `.client.luau`; selene does not resolve
   cross-module field types; stylua only formats. The pie's correctness rests on RingTimer's
   fixture-tested angles plus the hand-walk above. The owner should look at a live round —
   specifically at (a) the seam where half B meets half A at the 180° boundary, (b) the digits at
   34px on desktop against the new opaque disc, and (c) the final second, where the
   `MIN_SWEEP_DEGREES = 6` floor should show a small but present arc rather than nothing.

2. **The 0.4999→0.5 gradient step is a sub-pixel ramp, not a true hard edge.** At a 70px outer
   diameter that ramp is well under a pixel, so it should read as clean. If the owner sees a soft
   edge on the sweep, that keypoint pair is the lever — narrowing it further (0.49999) is safe, but
   collapsing it to a single keypoint is not, because NumberSequence interpolates.

3. **I edited two comments outside the blocks the brief scoped.** Flagged above rather than buried:
   both were sentences asserting that the ring is built from discrete segments, sitting immediately
   above code that no longer is. Prose only.
