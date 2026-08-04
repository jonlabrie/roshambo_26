# Play HUD — round three design

**Date:** 2026-08-04
**Supersedes nothing.** Amends `2026-08-03-play-hud-round-two-design.md` in four places.
**Gate:** owner's Studio session, 2026-08-04 morning.

Four items, from the owner's punch list:

1. Is the HUD as low as it can go on a phone? (Answer: yes — but the *stack* can lose height.)
2. `SWITCH?` becomes `UNDO?`, on a full-size button overlay, with a 2-second fuse.
3. The bank button loses vertical space.
4. The ring is redrawn — it is currently 36 rotated rectangles and the facets show.

---

## §0 Invariants this round must not break

Carried from earlier rounds; every task inherits them.

- **`Active` discipline.** `TextButton`/`ImageButton` always sink touch. `Frame`/`TextLabel` sink
  only when `Active = true`. Every sinking pixel is a permanent hole in the camera-drag surface.
  §2 grows an overlay to cover an entire live button — **it must stay `Active = false`** or the
  throw button beneath it stops receiving taps and the mechanic breaks outright.
- **No `UIStroke` on a `TextLabel`.** Contrast comes from an opaque backing. A stroke on a label
  outlines every glyph and fills the counters.
- **Pure `src/shared` modules** hold the arithmetic: dependency-injected, no Roblox globals,
  Lune-testable. `RingTimer` keeps that property through §4 — the sweep is arithmetic, the
  painting is not.
- **One source for shared numbers.** `HudLayout` exists because `OnboardingController` derives its
  safe band from the same skeleton `HudController` builds the stack from. Hand-copied arithmetic in
  either file is the defect, not the convenience.
- **No gate can see this.** `lune run tests/run` never loads a `.client.luau`; `selene` does not
  resolve cross-module field types. Reconcile every `HudLayout.X` / `view.X` / `aux.X` read against
  what those modules actually export, and confirm every local is declared before first use.

---

## §1 Vertical space: the HUD is already at the floor

**Finding.** `EDGE_BOTTOM = 6`, and the HUD's `ScreenGui` leaves `IgnoreGuiInset` at its default —
the topbar inset is taken off the *top* only, so the gui's bottom edge is the screen's bottom edge.
The cluster sits 6px off the physical bottom. Removing the timing hairline in round two did buy the
space and the cluster did take it.

What remains is not position but **stack height**. Bottom-up, on a phone:

| element | height |
| --- | --- |
| tape | 24 |
| gap (`ROW_GAP`) | 10 |
| throw buttons | 44 |
| gap | 10 |
| bank button | 40 |
| bottom margin (`EDGE_BOTTOM`) | 6 |
| **total** | **134** (94 with no pot riding) |

The throw buttons are pinned at 44 by the touch-target floor adopted in round one. The tape is
already at 0.7 scale. The bank button is 30% of the stack and is the only element with slack —
hence §3.

**Decision: `EDGE_BOTTOM` stays 6.** It is documented here so it is not re-litigated. Going lower
buys single-digit pixels and risks the home-indicator band on modern phones.

**Net effect of this round:** phone 134 → 128, desktop 176 → 170.

---

## §2 `UNDO?` replaces `SWITCH?`

### The rename is a correctness fix, not a copy tweak

Tapping an unchosen glyph has never switched the player to it. Confirming the prompt **clears the
choice entirely** — that is the back-out, and it is why both unchosen buttons work as proxies. The
word `SWITCH?` described something the button does not do. `UNDO?` describes what it does.

It is also two characters shorter, which is what makes the legibility fix possible: at 44px wide
with 4px padding, 7 characters land near 9px of type and 5 characters land near 13px.

### The rename runs all the way down

Half-renaming is worse than either end. This codebase has twice been bitten by a stale name or
comment outliving the behaviour it described. So:

- `HudModel.SWITCH_PROMPT_SECONDS` → `HudModel.UNDO_PROMPT_SECONDS`
- `HudModel.switchPromptExpired` → `HudModel.undoPromptExpired`
- `Inputs.switchPrompt` / `View.switchPrompt` / `TapState.switchPrompt` → `undoPrompt`
- `main.client.luau`'s `switchPrompt` / `switchPromptAt` locals → `undoPrompt` / `undoPromptAt`
- `HudController`'s `switchPill` / `switchLabel` / `setSwitchPrompt` → `undoPill` / `undoLabel` /
  `setUndoPrompt`
- the `"prompt"` action string returned by `HudModel.tapAction` is unchanged — it already names the
  act, not the word

Test names and descriptions follow the rename.

### The fuse doubles

`UNDO_PROMPT_SECONDS = 2` (was 1). One second was too quick to notice, read and answer.

### The overlay is exactly the button

`Size = UDim2.fromOffset(BTN_W, BTN_H)` — the same square as the throw button beneath it, both
dimensions, both tiers. It already anchors at `(0.5, 0.5)` on the button's centre, so it covers
exactly. Corner radius rises 6 → 8 to match a throw button's.

**It stays `Active = false`.** It is a `Frame`; the tap it answers is delivered to the `TextButton`
underneath. A full-size overlay that sank would swallow the very tap that resolves it.

Covering the glyph remains deliberate: the button has stopped offering an option and is asking a
question.

### Type

The owner's ruling: *size fixes it* — the problem was that the word was tiny and clipped, not the
typeface. Keep `Enum.Font.GothamBold` and the existing `TextScaled` + `UITextSizeConstraint`
pattern, with `MaxTextSize = 22` (at desktop's 68px of content box, 5 characters of GothamBold at
~0.6em cap out near 22px; higher and the word would clip on the wide tier instead of the narrow
one). No font-family change anywhere in the HUD.

---

## §3 The bank button loses 6px

- `HudLayout.BANK_H`: 40 → **36**.
- The gap above the throw cluster: 10 → **8**.

That second change also repairs an inconsistency. `HudLayout.BANK_GAP = 8` exists and is read only
by `OnboardingController`; `HudController` positions the bank button with `ROW_GAP` (10), and
`HudLayout.CLUSTER_TOP_FROM_BOTTOM` derives with `ROW_GAP` too. So the constant named for this gap
has never *been* this gap. After this round `BANK_GAP` is the gap, used by all three:

- `HudController`: `bankButton.Position` y-offset becomes `-(EDGE_BOTTOM + AREA_H + BANK_GAP)`
- `HudLayout.CLUSTER_TOP_FROM_BOTTOM` (both tiers): `EDGE + AREA_H + BANK_GAP + BANK_H`
- `OnboardingController`: its three card offsets currently re-derive the whole stack by hand
  (`EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP`). They become
  `HudLayout.CLUSTER_TOP_FROM_BOTTOM + HudLayout.BANK_GAP` — the clearance above the bank button,
  expressed once. This is the hand-copied arithmetic `HudLayout`'s own header was written to
  prevent.

**Why 36 and not 32.** The owner's call. Banking is the one irreversible action on this surface and
a mis-tap costs real points; 36 stays comfortably hittable while 32 does not. The throw buttons'
44px floor does not bind here — that floor was set for the three targets a player hits every round
under time pressure.

---

## §4 The ring is redrawn as a swept pie

### The defect

`RingTimer` currently returns *how many of 36 segments are lit*, and `HudController` builds 36
`Frame`s, each rotated about its own centre and widened by `segmentWidth` to overlap its
neighbours. The result is a polygon, not a circle. The owner: *"I can see the pixels; it's
particularly egregious on larger screens"* — correct, and it is worse at 76px than at 44px because
the facets scale with the radius.

### The technique

Roblox has no arc primitive and no radial fill. The obvious approach — clip a rotated half-circle
with `ClipsDescendants` — carries a documented caveat about clipping rotated descendants, so it was
not adopted on faith.

**A `UIGradient` whose `Transparency` is a `NumberSequence` with a hard step at offset 0.5 turns a
circular `Frame` into a half-disc, and `UIGradient.Rotation` sweeps the cut.** No clipping, no image
asset, no rotation of the element itself.

This was prototyped in Studio before being specified, at 44px, 76px and 200px, and is smooth at all
three (`ScreenCapture_2`, 2026-08-04).

Four layers, inside the existing ring `TextButton`, all concentric, all `Active = false`:

1. **track** — a full circle in `RING_TRACK`, diameter `od`
2. **half A** — a half-disc, diameter `od`
3. **half B** — a half-disc, diameter `od`
4. **disc** — the opaque centre, diameter `od - 2 * thickness`, carrying the digits and glyphs

A half-disc's visible half is the clockwise arc `[a, a + 180]` measured from the top. Because the
gradient's visible side is the one *before* the step, and `Rotation = 0` points the gradient axis
to the right (90° clockwise from the top), the mapping is:

```
UIGradient.Rotation = a + 180
```

To light the clockwise arc `[0, θ]`:

- **θ ≤ 180**: half A lit at `a = 0` (covers 0–180), half B in **track** colour at `a = θ`
  (covers θ–θ+180) painting back over the excess. Net: lit 0–θ.
- **θ > 180**: half A lit at `a = 0`, half B **also lit** at `a = θ - 180` (covers θ−180–θ).
  Union: lit 0–θ.

θ = 0 leaves half B painting track over the whole of half A — nothing lit, which is correct.
θ = 360 leaves the two lit halves covering the full circle.

### The centre must be opaque

Today `ringDisc` is `BackgroundTransparency = 0.15` over a 0.3 backing, because the old segments
left the centre open and nothing was behind it. A pie is solid, so at 0.15 the sweep **bleeds
through the centre as a hard seam across the digits** — the prototype showed exactly this. The disc
becomes `BackgroundTransparency = 0`.

This costs nothing: `WASHI` is near-black (26, 24, 28), so `INK_CREAM` digits gain contrast rather
than losing it.

### The minimum-sweep floor

`RingTimer.lit` used `math.ceil` deliberately: *any time at all leaves at least one segment lit,
because an empty ring must mean the round is over and nothing else.* A continuous sweep destroys
that guarantee silently — 0.2s of a 20s round is 3.6°, which at 44px is sub-pixel and renders as
nothing.

**`RingTimer.MIN_SWEEP_DEGREES = 6`.** Any fraction strictly greater than zero sweeps at least this
much. Zero sweeps zero. This is the `math.ceil` invariant restated for a continuous ring, and it
must have its own test.

### `RingTimer`'s new surface

Removed: `SEGMENTS`, `lit`, `angleAt`, `segmentWidth` — and their tests, which have no meaning
under the new construction.

Kept unchanged: `isWarning(secondsLeft, escalateAt)`. `escalateAt` is still passed in rather than
owned, so the ring and the escalation prompt cannot turn urgent at different moments.

Added:

```luau
RingTimer.MIN_SWEEP_DEGREES = 6

-- Degrees of the clockwise sweep for `fraction` of the round remaining.
function RingTimer.sweepDegrees(fraction: number): number

-- The two gradient rotations that draw that sweep, and whether half B is lit or track.
-- Returns { rotationA: number, rotationB: number, bLit: boolean }.
function RingTimer.sweep(fraction: number): Sweep
```

`rotationA` is always 180 and is returned rather than exported as a bare constant, so the pair that
must agree is produced in one place.

### Geometry

The band thins slightly and the centre grows, per the owner's *"the inner black circle … can grow
to fill the newly downsized ring"*:

| | today | this round |
| --- | --- | --- |
| `RING_INSET` | 4 | **3** |
| band, touch | 3 | 3 |
| band, desktop | 6 | **5** |
| `od` (pie outer), touch | 38 | **38** |
| `od`, desktop | 68 | **70** |
| centre disc, touch | 32 (with a 2px gap) | **32** |
| centre disc, desktop | 52 (with a 2px gap) | **60** |

`RING_DISC_GAP` is deleted. It existed because the segments' inner edge was ragged; the pie's inner
edge is exact, and the disc's own edge now *defines* the band's inner boundary. `RING_THICKNESS` is
no longer derived as a fraction of `RING_D` — it is the band width directly, and the disc is
`od - 2 * thickness`.

### Digits

Fixed `TextSize` per tier, raised to suit the larger disc: **20** touch (was 14), **34** desktop
(was 18). Fixed rather than `TextScaled`, deliberately: the countdown runs 20 → 1, and `TextScaled`
would visibly jump the digits' size at the two-to-one-character boundary every round. Two digits at
20px on a 32px disc, and at 34px on a 60px disc, both clear their box.

The world-throw glyph box (`glyphBox(ringDisc, 0.82)`) is unchanged and scales with the disc for
free.

### What does not change

The ring's slot, size (`RING_D`), backing (`WASHI` at 0.3, corner 8), its role as the ledger's door,
the two-stage tap gesture, `ringScale`'s press feedback, the green/red threshold shared with
`HudModel.ESCALATE_AT`, and the drum-rest spoiler gate on the glyph.

---

## §5 Risks

- **The rename is broad and mechanical.** It touches `HudModel`, `HudController`,
  `main.client.luau` and roughly fifteen tests. Its own task, so its diff can be reviewed as a
  rename and nothing else.
- **`Active = false` on the grown overlay** is the single change in this round that could break the
  throw mechanic outright, and no test can see it. Called out in §0 and §2.
- **`RingTimer`'s removed functions** delete real test coverage. The minimum-sweep floor is the
  invariant that must survive the swap, and it needs a test that fails if the floor is removed.
- **The onboarding safe band** moves with `BANK_H` and `BANK_GAP`. If the band and the stack drift,
  a card lands on the bank button — which is why §3 routes all three call sites through
  `CLUSTER_TOP_FROM_BOTTOM` instead of leaving the arithmetic hand-copied.
