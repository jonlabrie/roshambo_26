# Task 2 report — HudModel: view, escalation, and the lockout send

## Status: DONE

## What changed

`roblox/src/shared/HudModel.luau`:
- `Inputs` lost `fateBound`, `pickedThisRound`, `confirmThrows`, `selectedThrow`.
- `View` lost `slot`/`potPulses`-on-slot/`selected`; gained `bankVisible`, `pot`, `chosen`,
  `switchPrompt`. `plate` is now `{ streak, points }` — no `pot`.
- `HudModel.autoCommit` and `AUTO_COMMIT_AT` deleted; replaced by `HudModel.sendAtLockout`
  (`SEND_AT = 0.5`), gated on `inputs.chosen`/`inputs.sent` instead of
  `selectedThrow`/`pickedThisRound`/`fateBound`.
- `HudModel.view`'s `armed` now keys off `inputs.chosen == nil` and `not
  inputs.declinedThisRound` instead of `not pickedThisRound` / `not fateBound`.
- Header comment: the backoff paragraph gained a sentence on the back-out counting as an
  answer, not a miss; the miss-counting paragraph's "fate-bound" wording was genericized to
  "prevented from throwing" (this module no longer models fate at all).

## Deviations from the brief (and why)

The brief's Step 1 explicitly named four describe blocks to delete
(`fateBound`/`pickedThisRound`/`confirmThrows`/`selectedThrow`, "the slot above the throw
row", `autoCommit`, "the confirm affordance", "pickedThisRound after a release"). The last
two no longer existed — Task 1 (commit 5a699dd) had already removed them. That left two
conflicts the brief didn't anticipate, both of which I had to resolve to reach a green,
*meaningful* suite (not just a passing one):

1. **`HudModel.view — plate and throws`** (pre-existing, not listed for deletion) had a test
   asserting `v.plate.pot == 27`. Per ambiguity resolution #3 (`plate` must never carry
   `pot`), I deleted that one assertion/test rather than the whole block — the rest of the
   block (throwsEnabled coverage) is untouched and still valid.
2. **`HudModel.view — escalation`** (pre-existing, not listed for deletion) had two tests
   asserting the OLD `fateBound`/`pickedThisRound`-gated escalate behavior ("it never fires
   once a pick is in", "it never fires at a player who cannot throw"). These test concepts
   this task explicitly removes from `Inputs`. I deleted only those two tests; the block's
   other 6 tests (5s threshold, preference-off, uniform 3-miss backoff) are unrelated to the
   removed fields, still pass under the new logic, and I kept them rather than duplicating
   backoff coverage in the new "escalation keys off the CHOICE" block (which the brief's
   verbatim text doesn't cover either).

Both changes were necessary — leaving either in place would have left a genuinely
contradictory/stale test in the suite (testing behavior the code no longer has), not a
"passes trivially" situation.

## Verification

- `lune run tests/run`: 903 passed, 0 failed (both before-and-after full-suite runs; the
  `[WARN] QUEUE ... boom` lines are pre-existing fault-injection noise from
  `HandlerQueue.spec`, unrelated to this change).
- `grep -rn "fateBound|pickedThisRound|confirmThrows|selectedThrow" roblox/src/shared/`:
  no matches.
- `stylua --check src tests tools` / `selene src tools`: 0 errors, 0 warnings (stylua was
  run non-check to apply formatting, then reverified clean).
- Confirmed remaining references to `autoCommit` / `view.selected` are all in
  `src/client/main.client.luau` and `src/client/HudController.client.luau` — out of scope,
  explicitly Task 4's job per the brief.

### Mutation checks

1. Made `sendAtLockout` ignore `inputs.sent` (removed `or inputs.sent` from the nil-guard).
   Result: **1 test failed** — `HudModel.sendAtLockout ... NEVER TWICE — once sent, it stays
   sent` (`expected R to be nil`). Reverted.
2. Made `armed` ignore `declinedThisRound` (removed the `not inputs.declinedThisRound` term).
   Result: **1 test failed** — `HudModel.view — escalation keys off the CHOICE ... BACKING
   OUT SILENCES IT for the rest of the round` (`expected true to be false`). Reverted.

Both mutations were caught by exactly one test each, and the suite was confirmed green again
after each revert.

## Commit

`git commit` on `roblox/src/shared/HudModel.luau` and `roblox/tests/HudModel.spec.luau` only.
