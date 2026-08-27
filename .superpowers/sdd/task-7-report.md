# Task 7 Report: Server region backstop (teleport-back eviction)

## Status
DONE. Committed on branch `m4b-zendojo-art-pass`.

## Note on report file reuse
This file previously held a report for a differently-scoped "Task 7" (TreatmentApplier —
build visible decorations, commit `39da376`). It has been overwritten with this task's report
(server region backstop for teahouse access control) per the current brief's instruction to
write the report to this path.

## Commit
`5693f1ead5db8f71bc3e5f579bf593691948dfa9` — "feat(roblox): access region backstop (teleport-back eviction)"
(1 file changed, 59 insertions(+))

## Files changed
- `roblox/src/server/main.server.luau` — only file touched, as required. Backstop loop appended
  at the very end of the file (after the existing `coordinator:pollOnce()` poll loop, which
  itself follows `portalController:start()`).

## Anchor verification
Re-confirmed before editing: file was 1490 lines; `portalController:start()` at line 1482;
final block (1484–1490) was the existing `task.spawn` poll loop, matching the brief's
description exactly. Inserted the new backstop `task.spawn` loop after it (at file end), one
of the two brief-sanctioned positions.

## Live-signature reconciliation
Checked every consumed symbol against the live source before transcribing — all matched the
brief with no deviation needed:
- `deckCFForUid(uid: string): ({number}?, string?)` (main.server.luau:555) — returns
  `(deckCF12, deckSize)` in that order, exactly as assumed.
- `isFriend(viewer: Player, ownerId: number): boolean` (main.server.luau:578).
- `AccessGates.GATE_H = 12` and `AccessGates.evictionPoint(deckCF12, deckSize): {number}`
  (AccessGates.luau) — a 12-number CFrame-components array, confirmed.
- `SizeClasses.deckFootprint(deckSize: string): Footprint` (SizeClasses.luau:42) — same shape
  (`minX/maxX/minZ/maxZ`) used elsewhere in the file (e.g. `recomputeAllAccess`'s
  `gatesForPad`/`AccessGates.deckBackGate`, and `deckFP` at line 1272).
- `AccessPolicy.canEnter(mode, invited, viewerId, ownerId, friend)` — same 5-arg signature
  already used identically at line 642 in `recomputeAllAccess`.
- `playerEconomy[uid]` fields `claimedPadId` / `teahouseAccess` — same shape/usage as the
  existing `recomputeAllAccess` snapshot loop just above (lines 608–637).
- `Players` service var (line 5) matches.

No deviations from the brief's code were required. The one intentional non-substantive change:
`stylua` reformatted the ternary-friend line and the `canEnter` if-condition to satisfy its
line-length/style rules (wrapped `if...then...else` and multi-line `if not (...) then`) — logic
is byte-identical to the brief, just reflowed. This is expected/required since `stylua --check`
is a hard gate.

## Commands run (repo root `roblox/`)
1. `lune run tests/run` → **472 passed, 0 failed, 472 total** (two WARN lines from
   `HandlerQueue.spec` are pre-existing intentional-failure-path test noise, unrelated to this
   change).
2. `rojo build -o /tmp/ac-t7-check.rbxl` → **succeeded** ("Built project to ac-t7-check.rbxl").
3. `stylua --check src tests && selene src` → **clean** (stylua exit 0 after auto-formatting
   the new block once; selene: 0 errors, 0 warnings, 0 parse errors).

All three re-run together as a final check after the stylua pass — all green.

## Deviations
None from the brief's logic. Only cosmetic stylua reflow of two lines (see above).

## Concerns
- None functional. As with any O(occupied-decks × players) per-tick loop, cost scales with
  concurrent player count and occupied-deck count on a server; at 0.3s cadence with the
  documented ~50 players/server ceiling this is consistent with the brief's stated design intent
  (cheap backstop, not the primary UX gate) and was not flagged as a concern in the brief itself.
- `git status --porcelain` confirmed no other files were touched before committing.
