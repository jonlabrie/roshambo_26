# Task 6 Report: gongStrike removal + drum spins-until-data

## Status
DONE

## Commit
`a77fe4f79aa0ce1a16696155f924ef49e6d06c00` — feat(roblox): strike self-timed — choreography drops gongStrike; drum spins until the reveal lands (branch `m4b-zendojo-art-pass`)

## What changed

### 1. `roblox/tests/ChoreographyMachine.spec.luau` (TDD step 1)
Scanned the entire file for `gongStrike` references — found exactly one, at the
"base cues fire at t=0" test (line 50). Updated the expectation from
`{ "drumrollStop", "gongStrike", "basinErupt", "heroTileLand" }` to
`{ "drumrollStop", "basinErupt", "heroTileLand" }`. No other occurrences existed
anywhere else in the spec (no counts/orderings elsewhere assumed 4 seed cues).

Ran `lune run tests/run` against the unmodified module first to confirm the test
failed as expected: 537 passed, 1 failed, 538 total, before touching the module.

### 2. `roblox/src/shared/ChoreographyMachine.luau` (TDD step 2)
Removed the `gongStrike` entry from the `revealCues` seed list and renumbered the
`idx` fields (1/2/3 instead of 1/2/3/4), matching the brief exactly. The comment
above already correctly attributed self-timing to HammerController since Task 5.
Re-ran the suite: green, 538/538.

### 3. `roblox/src/client/DrumController.client.luau` (step 3)
- Added `local lastLandedThrow: string? = nil` and
  `local STALL_MAX = 6 -- s past min spin to wait for the reveal before settling anyway`
  immediately after `latestWorldThrow`'s declaration.
- Replaced the spin-branch glide gate in the Heartbeat handler: now checks
  `haveThrow = latestWorldThrow ~= nil` and only glides once `spinUntil` has passed
  AND (`haveThrow` OR `STALL_MAX` seconds past `spinUntil` have elapsed). Lands
  `latestWorldThrow or lastLandedThrow or "R"`, stores it into `lastLandedThrow`,
  and clears `latestWorldThrow` to `nil` (consume-on-use).
- Removed the gongHit handler's early-return bail (`if not throw then return end`)
  and the now-redundant `latestWorldThrow = throw` no-op — the drum now always
  spins on every `gongHit` regardless of whether reveal data has arrived yet.

Left untouched, exactly as instructed: the kick/paddle choreography state machine,
the `RevealTheater.OnClientEvent` handler, and the `RoundUpdate` stuck-guard
backstop.

## Verification
```
lune run tests/run              → 538 passed, 0 failed, 538 total
stylua --check src tests tools  → clean (no diff)
selene src tools                → 0 errors, 0 warnings, 0 parse errors
```
(The two `[WARN] [QUEUE] ...` lines in the Lune output are pre-existing, expected
noise from the `HandlerQueue.spec` fault-injection test — not new failures.)

Confirmed no stray `gongStrike` references remain anywhere under `roblox/`
(`grep -rn "gongStrike" roblox --include="*.luau"` → no matches post-change).

`git status --short` before committing showed only the three intended files
modified (plus a pre-existing untracked `roshambo_reference` entry unrelated to
this task, left alone). Only those three files were `git add`ed and committed.

## Note on this report file
This file previously held a stale report from an earlier, differently-scoped
"Task 6" (SetAccess/InviteUser/RevokeUser handlers) — task numbering was reused
across planning rounds. Overwritten in place with this task's report.

## Concerns
None. Implementation matches the brief's code blocks verbatim; only the three
named files changed; suite, stylua, and selene are all green; commit trailer
matches the required format exactly. Not pushed.

---

## Final-review fix (2026-07-23)

**Status:** FIXED

**Commit:** `95fa7cc` — fix(roblox): drum stuck-guard respects the stall wait (4s -> 10s) + consumes its throw

**Changes:**
- Updated `RoundUpdate.OnClientEvent` stuck-guard threshold from `SPIN_SEC + GLIDE_SEC + 1` (4s) to `SPIN_SEC + STALL_MAX + GLIDE_SEC + 1` (10s), accounting for the legitimate stall-wait window.
- Added `latestWorldThrow = nil` (consume-on-use) after the guard uses the throw value, preventing stale-throw leakage into the next round.
- Updated comment to clarify the guard only fires beyond the worst legitimate spin+stall+glide.

**Verification:** `lune run tests/run` → **538 passed, 0 failed**; `stylua --check` and `selene` clean.
