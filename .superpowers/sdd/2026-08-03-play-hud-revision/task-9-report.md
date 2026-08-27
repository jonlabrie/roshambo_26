# Task 9 report: contrast — strokes off text, and the toast

## Summary

Fixed the reported defect (transient text unreadable/blank) per design spec §3: text contrast
comes from an opaque backing behind the text, never from a `UIStroke` on the `TextLabel` itself.

## Changes

**`roblox/src/client/HudController.client.luau`**
1. `toast.Position` — verified already `UDim2.new(0.5, 0, 0, EDGE)` (fixed in Task 7, referenced
   the since-deleted plate-anchored constant). No change needed; confirmed correct and left the
   comment updated to drop the stale "Task 9 owns making this opaque" note.
2. `toast.BackgroundTransparency` 0.3 → 0.05 (was the one outstanding piece of the toast fix).
3. Escalation overlay (`escalation` Frame): added `BackgroundColor3 = WASHI`,
   `BackgroundTransparency = 0.1`, `corner(escalation, 10)`, and a `UIPadding` of 12 on all four
   sides. It previously had `BackgroundTransparency = 1` (fully invisible) — the strokes on its
   two child labels were standing in for a backing it never had.
4. Deleted `stroke(escalationCount, WASHI, 3, 0.15)` and `stroke(escalationPrompt, WASHI, 2, 0.2)`,
   replaced with one-line comments pointing at the new backing on `escalation`.

**`roblox/src/client/OnboardingController.client.luau`**
5. Deleted the `do … end` block parenting a `UIStroke` to `copyLabel` (2px WASHI stroke at 0.35
   transparency on 17px `GothamBold` text), replaced with a comment explaining the card's own
   opaque `WASHI` backing (~18:1 contrast under near-white copy) needs no help, and that a stroke
   on a TextLabel outlines every glyph rather than adding contrast.

## Branch-wide `UIStroke` audit (`src/client/`)

| File:line | Parented to | Instance type | Verdict |
|---|---|---|---|
| HudController.client.luau:131 (`stroke()` helper def) | n/a (function) | n/a | not an instance — helper only |
| HudController.client.luau:271 `plateStroke = stroke(plate, …)` | `plate` | Frame | OK — container |
| HudController.client.luau:391 `tileRim = stroke(tile, …)` | `tile` | Frame | OK — container |
| HudController.client.luau:455 `rim = stroke(b, …)` | `b` | TextButton | OK — container |
| HudController.client.luau:490 `stroke(switchPill, …)` | `switchPill` | Frame | OK — container |
| HudController.client.luau:693 `stroke(bankButton, …)` | `bankButton` | TextButton | OK — container |
| HudController.client.luau:800 `stroke(ledgerButton, …)` | `ledgerButton` | TextButton | OK — container |
| HudController.client.luau:881 `stroke(escalationCount, …)` | `escalationCount` | **TextLabel** | **FIXED** — deleted, backing added to parent `escalation` |
| HudController.client.luau:895 `stroke(escalationPrompt, …)` | `escalationPrompt` | **TextLabel** | **FIXED** — deleted, backing added to parent `escalation` |
| LedgerController.client.luau:215 (`stroke()` helper def) | n/a (function) | n/a | not an instance — helper only |
| LedgerController.client.luau:267 `stroke(panel, …)` | `panel` | Frame | OK — container |
| LedgerController.client.luau:312 `stroke(closeButton, …)` | `closeButton` | TextButton | OK — container |
| LedgerController.client.luau:343 `stroke(teahouseButton, …)` | `teahouseButton` | TextButton | OK — container |
| LedgerController.client.luau:355 `stroke(hero, …)` | `hero` | Frame | OK — container |
| LedgerController.client.luau:408 `stroke(bankButton, …)` | `bankButton` | TextButton | OK — container |
| LedgerController.client.luau:454 `stroke(card, …)` | `card` | Frame | OK — container |
| LedgerController.client.luau:709 `stroke(switch, …)` | `switch` | TextButton | OK — container |
| OnboardingController.client.luau:129 raw `UIStroke` on `card` | `card` | TextButton | OK — container (already opaque WASHI backing) |
| OnboardingController.client.luau:160-169 (was) raw `UIStroke` on `copyLabel` | `copyLabel` | **TextLabel** | **FIXED** — deleted, comment added |

Post-fix: **zero** `UIStroke` instances parented to a `TextLabel` anywhere in `src/client/`.
3 strokes were on TextLabels before this task (2 in HudController, 1 in OnboardingController);
all 3 removed and replaced with opaque backings on their container/parent.

## Verification

- `grep -n "stroke(.*Label\|stroke(.*Count\|stroke(.*Prompt\|stroke(.*Hint\|stroke(.*Copy\|stroke(.*Text" src/client/*.luau` → no matches.
- `grep -n -B4 "UIStroke" src/client/OnboardingController.client.luau` → only match is the stroke parented to `card`.
- `HudLayout.X` reconciliation: only `JUMP_CLEARANCE`, `EDGE`, `ROW_GAP` are read in
  `HudController.client.luau` (lines 91, 92, 106); all three are exported by
  `src/shared/HudLayout.luau` (lines 26, 28, 30). This task introduced no new `HudLayout` reads.
- Locals: `WASHI` (line 57) and `corner()` (line 125) both predate this task's edits and are
  already in scope at the escalation block (line ~861); no forward references introduced.
- Escalation overlap check: `escalation`'s Position (`fromScale(0.5, 0.42)`, `AnchorPoint (0.5,
  0.5)`) and Size (`0.8` scale × `130px`, fixed, not TOUCH-conditional) are unchanged by this
  task — only its background/corner/padding changed. Every other child of `gui` (`plate`,
  `throwArea`, `bankButton`, `ledgerButton`, `timer`) is bottom-anchored (`Position` uses `1,
  -EDGE` or `1, 1`); `toast` is top-anchored at `EDGE`. None occupies the vertical-middle band
  the escalation frame sits in, at either TOUCH or non-TOUCH tiers (TOUCH only changes
  `AREA_H`/`BTN_H`, both bottom-row measurements). The escalation frame is also only `Visible`
  when `view.escalate` is true, so its new opaque plate never covers other HUD chrome — only the
  canyon behind it, which is the intended effect.

## Gates

- `lune run tests/run` → 919 passed, 0 failed, 919 total.
- `stylua --check src tests tools` → clean.
- `selene src tools` → 0 errors, 0 warnings, 0 parse errors.
