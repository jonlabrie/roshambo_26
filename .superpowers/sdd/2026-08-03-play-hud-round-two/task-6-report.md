# Task 6 report

**Status:** Complete.
**Commit:** `f6ba5bfa1c95aad1e07e470cea787df28146976c` (original), then a coordinator-review fix at
`9ec917983ad4dfaefef8af090b370484c6576af2` — see "Follow-up fix" below.

## Gates
- `stylua --check src tests tools` — clean
- `selene src tools` — 0 errors, 0 warnings
- `lune run tests/run` — 949 passed, 0 failed (matches baseline; no test-visible logic changed)

## Padding arithmetic
Naive halving (154→77) does NOT close: content = 77-24 = 53px, but count(46)+prompt(20) = 66 > 53
even with zero gap. Re-derived instead:
- content box = ESCALATION_H − 24 (12px UIPadding top + bottom)
- `escalationCount` span: **[0, 46]** (TextSize 42, height 46)
- gap: **[46, 54]** (8px, unchanged from before)
- `escalationPrompt` span: **[54, 74]** (TextSize 16, height 20)
- content needed = 74 → **`ESCALATION_H = 98`** (not 77)

## Clamp check (TOUCH is device-detected, not height-based; checked both tiers)
Formula: `center = min(0.42h, h − CLUSTER_TOP_FROM_BOTTOM − ROW_GAP(10) − ESCALATION_H/2(49))`.
The clamp is a hard `min()`, so overlap is structurally impossible whenever `clamped ≥ 0`; verified
both reference heights land on the non-degenerate branch:
- **H=354, touch tier** (`CLUSTER_TOP_FROM_BOTTOM_TOUCH=140`): clamped=155, resting=148.68 → resting
  wins. Escalation bottom edge = 197.68; cluster top = 214. **16.32px clear.**
- **H=1044, desktop tier** (`CLUSTER_TOP_FROM_BOTTOM=182`): clamped=803, resting=438.48 → resting
  wins. Escalation bottom edge = 487.48; cluster top = 862. **374.5px clear.**
No overlap at either height/tier.

## EventBus.DismissEscalation
Added to `EventBus.luau` NAMES. Exactly one firer (`HudController.client.luau`, escalation's
`MouseButton1Click`) and one listener (`main.client.luau`, sets `declinedThisRound = true` then
`publish()` — no new field added, per Task 2's widened meaning).

## Other steps
- `escalation` converted `Frame`→`TextButton` (`AutoButtonColor=false`, `Text=""`,
  `Selectable=false`); its two labels stay `Active=false`. Press feedback via a dedicated
  `escalationScale` UIScale + the existing `pressDepress` helper.
- `switchPill` was already `UDim2.fromOffset(BTN_W, 24)` with `TextScaled` + `UITextSizeConstraint`
  — no fix needed, only the required "covers the glyph on purpose" comment added.

## Concerns
None from the original pass. Mandatory verification confirmed `view.escalate`/`view.secondsLeft`
are unchanged HudModel exports, `pressDepress`/`EventBus` are declared before first use, and no
gate covers these two files directly (client controllers), consistent with the brief.

## Follow-up fix (coordinator review)

The original pass only halved `ESCALATION_H` (154→98, −36%) and left `escalation.Size`'s width at
`0.8` scale — untouched, since the brief scoped "halve" to height only. The owner's ask was the
whole footprint down 50%; width was the bigger offender (80% of screen for ~130px of content).

**Fix:** `escalation.Size` is now `UDim2.fromOffset(ESCALATION_W, ESCALATION_H)`,
`ESCALATION_W = 210`. Verified:
- **Copy fits:** content box = 210−24 = 186px. "CHOOSE A THROW" (14 chars) at 16px GothamBold
  estimates ~126-146px (using switchLabel's own measured ~8-9px/char at 13px, scaled), 40-60px of
  margin. Added `TextScaled` + `UITextSizeConstraint(MaxTextSize=16)` to `escalationPrompt` as a
  belt-and-braces floor anyway (same pattern as `switchLabel`), since no Roblox `TextService` is
  reachable outside Studio to measure exactly — it shrinks on a surprise, never truncates, and
  never grows past 16px.
- **Count fits:** 42px GothamBlack, ≤3 digits, comfortably inside 186px — no constraint needed.
- **Still centred:** frame keeps `AnchorPoint(0.5,0.5)` and X stays `Scale 0.5, Offset 0` (only Y
  is offset-driven, via `updateEscalationPosition`) — a fixed width self-centres identically to a
  scale width. Grepped every `escalation.` reference; nothing else assumed scale width.
- **Clamp still holds:** the clamp is purely a function of `ESCALATION_H` (unchanged, 98) and
  `CLUSTER_TOP_FROM_BOTTOM`; width plays no part. Re-confirmed both reference heights land on the
  non-degenerate `min()` branch exactly as before (16.3px / 374.5px clearance).
- **Footprint, area, before ESCALATION_H=154/width=0.8·screen → after ESCALATION_H=98/width=210:**
  - 390px phone: before 312×154 = 48,048 px² → after 210×98 = 20,580 px² — **−57.2%**
  - 844px landscape: before 675.2×154 = 103,981 px² → after 20,580 px² — **−80.2%**
  Both exceed the owner's "reduce it by 50%"; the larger screen (where width dominated) sees the
  bigger win, which is the point.

Gates re-run clean after the fix: stylua clean, selene 0/0/0, lune 949/0/949 (unchanged).
