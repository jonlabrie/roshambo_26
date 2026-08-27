# Task 5 report

**Status:** COMPLETE (implementation + review-fix pass)
**Commits:** `eb2a2e00c7ba4218f14f6745c49ef15fdbcde0fb` (implementation), `45513b05244d481d61a6e4cbf96604bd6eaed35e` (review fixes)

## Review-fix pass
1. Retired stale `≡`/`ledgerButton`/hairline headers left FALSE by the implementation commit:
   `LedgerController.client.luau:8-13` (the important one — this exact file's stale headers
   already caused the ledger-unreachable regression once on this branch), `main.client.luau:56,243`,
   `TeahouseController.client.luau:107-111`, `OnboardingController.client.luau:174`,
   `Takeover.luau:37-39`, and one more I found in the same sweep, `HudController.client.luau:783`.
2. Fixed `EDGE_BOTTOM`'s rationale comment: `EDGE` has no live horizontal read left in this file
   (only the toast's top offset) — the real reason to keep it separate is that shrinking `EDGE`
   would drag `HudLayout.CLUSTER_TOP_FROM_BOTTOM` and the onboarding static-anchor band DOWN
   toward the live buttons, the unsafe direction.
3. Added a `UISizeConstraint` (`PLATE_MAX_W = 100`) capping the plate's `AutomaticSize.X` growth,
   since it is a live, touch-sinking button now. Worst-case left edge (touch tier, from the
   screen's own left edge): **568px width → 238.8px**, **320px width → 28px**. Both comfortably
   positive/on-screen; commented with the reasoning and the 100px choice (covers ordinary
   streak+pot text with room, hard-ceilings the pathological case instead of leaving it unbounded).
4. Set `plate.Selectable = false` (a `TextButton` defaults `true`, joining gamepad focus nav) and
   commented the `AutomaticSize.X`-folds-in-own-`Text` interaction (benign at `Text = ""`).
5. Strengthened `OnboardingBeats.spec.luau`'s bank-beat test to assert the copy names the
   clock/ring AND describes the second tap reaching the ledger/everything — not just
   "tap...again" generically. Verified by temporarily swapping the copy back to the old
   "Banked. That's yours to keep." and re-running: **failed** (`expected false to be true`),
   confirming the strengthened assertion actually discriminates; restored and re-verified passing.

## Gates (after review-fix pass)
- `lune run tests/run` → 949 passed, 0 failed
- `stylua --check src tests tools` → clean
- `selene src tools` → 0 errors, 0 warnings, 0 parse errors

## Grep verification
- `grep -n "LEDGER_\|ledgerButton\|TIMER_H\|timer\." src/client/HudController.client.luau` → **empty** (exit 1)
- `EventBus.OpenLedger:Fire` in `src/client/` → **exactly 2**: `HudController.client.luau:397` (plate, guarded on `plateVisible`) and `:955` (ring, guarded on `plateVisible`)
- `span` confirmed live: still assigned in `render` and read by `ringKnown`/`ringFrac` just below

## Post-drop arithmetic (from `1 - JUMP_CLEARANCE` reference, X; screen bottom, Y)

**Desktop** (EDGE_BOTTOM=6, BTN_H=76, TILE=34, ROW_GAP=10, AREA_W=248, AREA_H=120, RING_D=76, RING_GAP=8, TAPE_W=194):
- tape: Y∈[6,40], X∈[-194,0]
- plate: Y∈[6,40] (bottom-aligned with tape), right edge X=-202 → 8px gap to tape
- throw buttons: Y∈[50,126], X∈[-248,0]
- ring: Y∈[50,126] (bottom-aligned with buttons), X∈[-332,-256] → 8px gap to throwArea
- bank button: Y∈[136,176] (10px gap above buttons)
- Plate/ring share no vertical band (tape row [6,40] vs button row [50,126], separated by ROW_GAP), so plate's leftward growth (streak riding) can never touch the ring even though their X columns overlap.

**Touch** (BTN_H_TOUCH=44, TILE_TOUCH=24, AREA_W=148, AREA_H_TOUCH=78, RING_D_TOUCH=44, TAPE_W=136):
- tape: Y∈[6,30], X∈[-136,0]
- plate: Y∈[6,30], right edge X=-144 → 8px gap
- throw buttons: Y∈[40,84], X∈[-148,0]
- ring: Y∈[40,84], X∈[-200,-156] → 8px gap
- bank button: Y∈[94,134]

**320px viewport, touch tier:** reference X = 0.85×320 = 272px from left. Ring's left edge = 272−200 = 72px from the screen's left edge — positive, comfortably clear of the thumbstick corner, nothing runs off-screen.

## Concerns
None outstanding. `HudLayout.CLUSTER_TOP_FROM_BOTTOM` still adds `EDGE` (not `EDGE_BOTTOM`) — deliberate over-reservation for the onboarding safe band, commented in place. The onboarding beat's anchor stayed `wallet` (not renamed to `ring`) since `OnboardingController.STATIC_ANCHORS` has no `ring` entry and the brief said fire-site/anchor should not change — only the copy, which now reads "Tap the clock for your points. Tap again for everything."
