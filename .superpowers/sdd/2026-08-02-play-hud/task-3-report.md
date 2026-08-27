# Task 3 Report: Settlement increments the counters and sets the win gate

## Summary

Added `buildCounterUpdate(thrown, result, newPot)` to `server/src/engine/Settlement.ts`, a pure
function producing the `$inc`/`$set`/`$max` deltas for one settled participant (round/win/safe/loss
counters, per-throw counter, the `unresolvedWin` gate, and a `bestPot` candidate for Mongo's `$max`
to arbitrate). Wired it into `settleRound`'s existing single `User.findByIdAndUpdate` call — no
second write was added.

Rule encoded: WIN sets `unresolvedWin: true` (binds the player pending RISK/BANK). LOSS explicitly
sets `unresolvedWin: false` (pot is forfeited, nothing left to decide, gate must not be left
standing). SAFE also sets `unresolvedWin: false` (no gate to begin with).

## Files changed

- `server/src/engine/Settlement.ts` — added `buildCounterUpdate` (exported, above `settleRound`);
  replaced the `$set`-only `findByIdAndUpdate` call with one that spreads in `counters.$set` and
  adds `$inc`/`$max` from the builder's output.
- `server/src/engine/Settlement.test.ts` — added `buildCounterUpdate` to the existing `./Settlement`
  import; added a new `describe('buildCounterUpdate', ...)` block with the 5 brief-specified cases
  (no DB needed, pure function).

## TDD evidence

### RED

Command: `npm test -- Settlement` (run from `server/`), after adding only the test block and the
import (`buildCounterUpdate` not yet added to `Settlement.ts`).

```
 FAIL  src/engine/Settlement.test.ts > buildCounterUpdate > counts a win, sets the gate, and tracks the biggest pot
TypeError: buildCounterUpdate is not a function
 ❯ src/engine/Settlement.test.ts:105:19
    103|     it('counts a win, sets the gate, and tracks the biggest pot', () => {
    104|         const u = buildCounterUpdate('R', 'WIN', 81);
       |                   ^
...
 Test Files  1 failed (1)
      Tests  5 failed | 4 passed (9)
```

Expected failure: `buildCounterUpdate` was imported but not exported from `Settlement.ts` yet, so
all 5 new cases threw `TypeError: buildCounterUpdate is not a function`. The 4 pre-existing
`settleRound` tests still passed, confirming the import addition didn't break anything else.

### GREEN

Command: `npm test -- Settlement` (run from `server/`), after adding `buildCounterUpdate` and
wiring it into `settleRound`.

```
 Test Files  1 passed (1)
      Tests  9 passed (9)
```

Then the full suite gate:

Command: `npm test` (run from `server/`)

```
 Test Files  13 passed (13)
      Tests  198 passed (198)
```

And `npm run build` (`tsc`) — clean, no output, exit 0.

## Self-review

- **Key overlap check** (brief's explicit warning): `$set` carries `pointsAtStake`, `currentStreak`,
  `stakingStreak`, `bestStreak`, `unresolvedWin`. `$inc` carries `roundsPlayed`, `wins`, `safes`,
  `losses`, and exactly one of `throwsR`/`throwsP`/`throwsS`. `$max` carries only `bestPot`. No
  field appears in more than one operator — verified by reading the assembled update object.
- **History-write ordering**: confirmed `PlayerRound.create` still runs before the
  `User.findByIdAndUpdate` call; only the update's shape changed, not its position.
- **Pre-existing documents**: `$inc` and `$max` on a field absent from an old document behave as
  Mongo documents (treated as 0 / as unset respectively), so no migration is needed for the new
  counters — consistent with the "must keep working for documents written before they existed"
  constraint.
- **YAGNI**: `buildCounterUpdate` does exactly what the brief specifies — no extra fields, no
  speculative options. `SettledPlayer`/the function's return contract were left untouched, matching
  "Produces: nothing new in SettledPlayer."
- **Test honesty**: the 5 new `buildCounterUpdate` cases are pure-function assertions with no
  `beforeAll(connectTestDb)` dependency (they run inside their own `describe` block, sibling to the
  DB-backed `settleRound` block, not nested inside it) — genuinely DB-free as the brief required.
- No `.rbxl`/`.rbxlx` touched; `shared-fixtures/game-rules.json` and both `GameRules` implementations
  untouched.

## Commit

`ff907bb` — `feat(server): settlement increments ledger counters and sets the win gate`
