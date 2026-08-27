# Task 1 Report: The metronome knows what phase it is

## What was added

`roblox/src/shared/RoundMetronome.luau`:
- `Reading` type gained two fields: `phase: string` and `secondsLeft: number`.
- In `read()`, after the existing `roundStart`/`drawP` computation (unchanged), added a phase derivation that reuses `roundStart`, `now`, and the already-in-scope `self._activeSec` / `self._tallySec` locals — no re-derivation of anything `read()` already computed:
  ```lua
  local elapsed = now - roundStart
  local activeEnd = self._activeSec
  local tallyEnd = activeEnd + self._tallySec
  local phase, phaseEndsAt
  if elapsed < activeEnd then
      phase, phaseEndsAt = "ACTIVE", activeEnd
  elseif elapsed < tallyEnd then
      phase, phaseEndsAt = "TALLY", tallyEnd
  else
      phase, phaseEndsAt = "REVEAL", period
  end
  ```
  Returned as `phase = phase, secondsLeft = math.max(0, phaseEndsAt - elapsed)`.
- All pre-existing return fields (`drawP`, `camAngle`, `omega`, `periodSec`, `prevStrikeAt`, `nextStrikeAt`) and their computations are byte-for-byte unchanged — verified via `git diff`, which shows a purely additive diff (only `+` lines, zero `-` lines) against both the module and the spec file.

`roblox/tests/RoundMetronome.spec.luau`: added the full `describe("RoundMetronome — the phase, read off the same timeline as the cam", ...)` block from the brief verbatim (6 tests: anchor/REVEAL-at-strike, walks-the-period, half-open boundaries, repeats-every-period, secondsLeft-counts-to-next-boundary, secondsLeft-bounds, no-schedule-no-phase). Nothing in the original 6 pre-existing tests in the file was touched — `git diff` shows only insertions, no deletions, for this file.

## Gate output

```
lune run tests/run
  → 993 passed, 0 failed, 993 total
  (the two [WARN] QUEUE lines are pre-existing, unrelated to HandlerQueue.spec:80, not RoundMetronome)

stylua --check src tests tools
  → clean (no output, exit 0)

selene src tools
  → Results: 0 errors, 0 warnings, 0 parse errors
```

Baseline before any change: `986 passed, 0 failed, 986 total` (confirmed prior to writing tests).
After adding failing tests (Step 2): `987 passed, 6 failed, 993 total` — the 6 new tests failed with `nil`/arithmetic-on-nil errors, exactly as expected since `phase`/`secondsLeft` didn't exist yet.
After implementation (Step 4 pass check): `993 passed, 0 failed, 993 total`.

## Mutation testing (Step 4)

All three mutations were applied one at a time, confirmed to fail, then reverted before the next.

**Mutation 1 — `elapsed < activeEnd` → `elapsed <= activeEnd`** (half-open boundary violation):
```
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > it walks the period in order
      .../RoundMetronome.spec:116: expected ACTIVE to be TALLY
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > boundaries are half-open — a phase owns its start, not its end
      .../RoundMetronome.spec:128: expected ACTIVE to be TALLY
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > secondsLeft counts down to the NEXT boundary, not the round's end
      .../RoundMetronome.spec:149: expected 0 to be within 0.001 of 2
990 passed, 3 failed, 993 total
```
Result: **FAILS as required.**

**Mutation 2 — `secondsLeft = math.max(0, period - elapsed)` in every branch** (round's-end instead of phase's-end):
```
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > secondsLeft counts down to the NEXT boundary, not the round's end
      .../RoundMetronome.spec:147: expected 27 to be within 0.001 of 20
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > secondsLeft is never negative and never exceeds its phase
      .../RoundMetronome.spec:159: expected false to be true
991 passed, 2 failed, 993 total
```
Result: **FAILS as required.**

**Mutation 3 — swap the ACTIVE and REVEAL labels**:
```
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > the strike instant is the first instant of REVEAL
      .../RoundMetronome.spec:108: expected ACTIVE to be REVEAL
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > it walks the period in order
      .../RoundMetronome.spec:114: expected REVEAL to be ACTIVE
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > boundaries are half-open — a phase owns its start, not its end
      .../RoundMetronome.spec:129: expected ACTIVE to be REVEAL
FAIL  RoundMetronome — the phase, read off the same timeline as the cam > it repeats every period, forwards and backwards
      .../RoundMetronome.spec:138: expected REVEAL to be ACTIVE
989 passed, 4 failed, 993 total
```
Result: **FAILS as required.**

All three mutations produced real test failures. None of the six new tests are decoration — every one of them is load-bearing against at least one mutation.

After each mutation, the file was restored to the implementation exactly as specified in the brief (verified by `git diff` showing the clean additive diff before committing).

## Regression confirmation (Step 5)

`HammerController`'s consumed fields (`drawP`, `camAngle`, `omega`, `prevStrikeAt`, `nextStrikeAt`) and their computations in `read()` are unchanged — the phase block was inserted after `drawP` is computed and before the `return` table, touching no existing line. The 6 pre-existing tests in `RoundMetronome.spec.luau` (nil-before-schedule, cam/drawP mapping, free-run strikes, racing-wheel regression, slew convergence, snap/period-change, congruence-class landing) all pass unmodified, confirmed by the 993/993 pass count and by `git diff` showing zero deleted lines in the spec file.

## Concerns

None. The implementation is a pure additive change to a pure, clock-agnostic module — no Roblox globals introduced, no existing computation altered, and all three prescribed mutations bit real tests.

## Commit

`5fab0c9` — "feat(roblox): the round's timeline can say what phase it is"
Files: `roblox/src/shared/RoundMetronome.luau`, `roblox/tests/RoundMetronome.spec.luau`
Not pushed.
