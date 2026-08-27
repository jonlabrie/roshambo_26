# Task 10 report — OnboardingController safe band re-derive

## What changed

- `roblox/src/shared/OnboardingBeats.luau`: the `bank` beat's anchor renamed `plate` → `wallet`
  (comment explains why: the plate moved into the bottom row and is normally hidden, so a card
  can no longer point at where it used to sit — `wallet` names what the beat explains, not a
  screen position).
- `roblox/tests/OnboardingBeats.spec.luau`: added the two tests from the brief (no beat anchors
  to `plate`; every anchor is one of `drum`/`throwArea`/`potIndicator`/`wallet`).
- `roblox/src/client/OnboardingController.client.luau`: removed the Task 6→10 temporary bridge;
  re-derived the safe band's top edge around a `TOAST_BAND` reservation instead of `PLATE_BOTTOM`;
  rebuilt `STATIC_ANCHORS` for the current bottom-row-plate layout; fixed the unknown-anchor
  fallback.

## The bridge is gone

`grep -n "PLATE_BOTTOM\|SLOT_H\|SLOT_GAP\|STATIC_ANCHORS\.plate\|TEMPORARY BRIDGE"
src/client/OnboardingController.client.luau` returns nothing. `SLOT_H`/`SLOT_GAP` are now local
aliases `BANK_H`/`BANK_GAP` (`= HudLayout.BANK_H` / `HudLayout.BANK_GAP`), declared once, above
`STATIC_ANCHORS`, and used in it. `PLATE_BOTTOM` is deleted outright; `TOAST_BAND = 64` (a
reservation, not a measurement) takes its place in `safeYBounds`'s `minY`.

## HudLayout field reconciliation

Every `HudLayout.X` this file reads — `EDGE`, `JUMP_CLEARANCE`, `AREA_H`, `AREA_H_TOUCH`,
`ROW_GAP`, `BANK_H`, `BANK_GAP`, `CLUSTER_TOP_FROM_BOTTOM`, `CLUSTER_TOP_FROM_BOTTOM_TOUCH` —
matches a field `HudLayout.luau` actually declares (`grep -n "^HudLayout\.[A-Za-z_]* ="
src/shared/HudLayout.luau`). No stale names.

## Declaration order

`BANK_H`, `BANK_GAP`, `EDGE`, `JUMP_CLEARANCE`, `AREA_H`, `ROW_GAP`, `CARD_W`, `WALLET_CARD_W` are
all declared before `STATIC_ANCHORS` reads them. `TOAST_BAND` and `CLUSTER_TOP_FROM_BOTTOM` are
declared before `safeYBounds`, their only reader. Confirmed by `selene` reporting 0 warnings (an
unused or undeclared local would have been flagged).

## The four anchors, where they land

Non-touch tier numbers: `EDGE=12, AREA_H=120, ROW_GAP=10, BANK_H=40, BANK_GAP=8`,
`CLUSTER_TOP_FROM_BOTTOM=182`. Touch tier: `AREA_H_TOUCH=78`, `CLUSTER_TOP_FROM_BOTTOM_TOUCH=140`
(same `EDGE/ROW_GAP/BANK_H/BANK_GAP`).

1. **`drum`** — live-tracked speech bubble above `Workspace.RoshamboStage.ThrowDrum.Drum`'s
   projected screen position, horizontally clamped to `[DRUM_CARD_W/2+8, canvas.X -
   (DRUM_CARD_W/2+8)]` and vertically clamped by `safeYBounds`: `minY = TOAST_BAND(64) +
   SAFE_MARGIN(24) + cardH`, `maxY = max(minY, canvas.Y - CLUSTER_TOP_FROM_BOTTOM -
   SAFE_MARGIN(24))`. At `cardH = MIN_CARD_H(90)`, `minY = 178` at both tiers. By construction the
   card's bottom edge never sits below `TOAST_BAND` (never covers the toast) and never above
   `CLUSTER_TOP_FROM_BOTTOM - SAFE_MARGIN` (never covers the cluster).

2. **`throwArea`** / **`potIndicator`** — identical: `AnchorPoint (1,1)`, `offset = UDim2.new(1 -
   JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP))`. Bottom edge sits
   `EDGE+AREA_H+ROW_GAP+BANK_H+BANK_GAP` up from the screen bottom — **190px** non-touch, **148px**
   touch — which is exactly `CLUSTER_TOP_FROM_BOTTOM + BANK_GAP` at each tier (182+8 and 140+8):
   8px of daylight above the bank button's top edge, in the same right-anchored column
   (`1 - JUMP_CLEARANCE`) the whole cluster registers to. Never overlaps the bank button, throw
   row, `≡` door or tape, all of which live at `D ≤ CLUSTER_TOP_FROM_BOTTOM`.

3. **`wallet`** — `AnchorPoint (0,1)`, `offset = UDim2.new(0, EDGE, 1, -EDGE)`: bottom-left corner
   at `(12, canvas.Y - 12)`, width `WALLET_CARD_W(260)`, so it spans `X ∈ [12, 272]`. This is
   level with the tape/wallet-plate row (`D = EDGE`, same as the actual plate) but on the
   **opposite side of the screen** from the cluster, which is held inboard of `1 -
   JUMP_CLEARANCE` (≈85% across) on the right. Because the card's X range never enters the
   cluster's X range on any realistic landscape viewport (cluster right-column start is hundreds
   of px right of 272 on anything ≥ ~500px wide), the card cannot climb into the cluster above it
   no matter how tall multi-line text makes it — it is off to the side, not underneath.

## Clamp audit

Two `math.clamp` calls in the file, both pre-existing and both guarded, unchanged by this task
except for what feeds their bounds:

- `math.clamp(px, half, math.max(half, canvas.X - half))` — upper bound is itself
  `math.max`-guarded against the lower bound, so `half > canvas.X - half` (a viewport narrower
  than the drum card) still produces a valid `min ≤ max`.
- `math.clamp(py - DRUM_BUBBLE_LIFT, minY, maxY)` — `minY`/`maxY` come from `safeYBounds`, whose
  `maxY = math.max(minY, …)` guarantees `maxY ≥ minY` unconditionally. On a short viewport (e.g.
  a 390px-tall landscape phone) `canvas.Y - CLUSTER_TOP_FROM_BOTTOM - SAFE_MARGIN` can fall below
  `minY` (140 vs `390-140-24=226` is fine; a hypothetically shorter canvas is not), in which case
  `maxY` collapses to `minY` — the band becomes a single point rather than inverting, so
  `math.clamp` never errors.

No new `math.clamp` call was introduced by this task; `safeYBounds`'s `maxY` already used
`math.max`, and that guard's shape is unchanged — only its `minY` input source moved from
`PLATE_BOTTOM` to `TOAST_BAND`.

## Concerns / follow-ups

- `wallet`'s 260px card, anchored from the left edge, has no explicit clamp against a *narrow*
  canvas the way the drum path does — on an extremely narrow-but-wide-cluster viewport it could
  theoretically approach the cluster's left edge. This mirrors the pre-existing precedent for the
  other static anchors (none of them re-clamp against `canvas.X` either), and realistic landscape
  phone widths (≥ ~600px) leave hundreds of px of margin, so this was not treated as a regression
  worth a new clamp in this task.
