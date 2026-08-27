# Task 7 Report: `LedgerModel` — derived statistics for maximal

## Summary

Implemented `roblox/src/shared/LedgerModel.luau` and `roblox/tests/LedgerModel.spec.luau`
exactly as specified in the task brief. Neither file existed before this task (checked first,
per the task's explicit note that Task 1 found a pre-existing spec file with broader coverage
than expected — that was not the case here; both files were created fresh).

One pure function, no Roblox globals:
- `LedgerModel.view(counters: Counters, live: Live, rules: any): View`

`GameRules` is injected as the `rules` parameter (never `require`d) so `paysNext` always
tracks the real pot progression via `rules.nextPot(live.pot, "WIN")`. The result bar
(`bar.win/safe/loss`) and throw mix (`mix.R/P/S`) both go through a shared largest-remainder
apportionment helper (`shares`) so three independently-rounded percentages always sum to
exactly 100 — floors each share, then hands out the leftover (`100 - sum of floors`, always in
`{0,1,2}`) to the largest fractional remainders, tie-broken by ascending original index for
determinism.

## TDD Evidence

### RED — `lune run tests/run` (from `roblox/`), before `LedgerModel.luau` existed

Test file `roblox/tests/LedgerModel.spec.luau` was written first (verbatim from the brief).
Running the suite at that point:

```
error requiring module "../src/shared/LedgerModel": could not resolve child component "LedgerModel"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/LedgerModel.spec', Line 4
[Stack End]
```

Expected failure: the `require("../src/shared/LedgerModel")` at the top of the new spec file
fails because the module doesn't exist yet — exactly the "does not exist" failure the brief
predicted, not a logic bug in an already-present module.

### GREEN — `lune run tests/run` (from `roblox/`), after `LedgerModel.luau` was written

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

851 passed, 0 failed, 851 total
```

(The two `[WARN]` lines come from `tests/HandlerQueue.spec.luau`, a pre-existing, unrelated
test that deliberately exercises an error/backpressure path — not from `LedgerModel`.) All 851
tests across the suite pass (up from 843 before this task, +8 for the new
`LedgerModel.spec.luau` cases), including every one of the brief's `LedgerModel.view` cases:
pays-next tracks `GameRules.nextPot` (including the zero-pot case), win rate is a whole
percentage with no divide-by-zero, the result bar and throw mix each sum to exactly 100 across
all the brief's test cases, mix ordering is preserved, and live values pass through untouched.

### Gates

```
$ stylua --check src tests tools && selene src tools
```

First run failed on formatting in both new files — stylua wanted the brief's single-line
`Counters` type fields and several multi-argument `LedgerModel.view(...)` calls in the spec
reflowed one field/argument per line (the brief's literal source runs past stylua's
line-length/style rules). Ran `stylua src tests tools` to auto-format, re-ran `--check` clean,
then `selene src tools` reported `0 errors, 0 warnings, 0 parse errors`. Re-ran
`lune run tests/run` after the reformat to confirm the auto-format didn't change test
semantics: still `851 passed, 0 failed, 851 total`.

Additionally grepped the new module for Roblox globals (`Instance`, `game`, `Enum`, `task`):
no matches — the module is pure arithmetic as required.

## Files

- `roblox/src/shared/LedgerModel.luau` (new)
- `roblox/tests/LedgerModel.spec.luau` (new)

## Commit

`ac604c1` — `feat(roblox): LedgerModel — derived stats for the maximal panel`

## Self-Review

- **Purity**: confirmed no `Instance`, `game`, `Enum`, or `task` anywhere in the module. The
  only inputs are the `counters`/`live` tables and the injected `rules` — everything else is
  arithmetic and table construction.
- **GameRules injection honored**: `paysNext` is computed via `rules.nextPot(live.pot, "WIN")`
  — never a literal `* 3` or duplicated progression logic. `GameRules.luau` itself was not
  touched (confirmed via the diff in this commit: only the two new files).
- **Largest-remainder correctness**: hand-traced the `shares` helper — since each `exact_i`
  sums to exactly 100 across parts and `floor(exact_i) <= exact_i`, the sum of floors is always
  `<= 100`, and since each floor is short by less than 1, the leftover
  (`100 - sum of floors`) is always `< number of parts` (so `0`, `1`, or `2` for the 3-way
  bar/mix here) — safe to distribute across the remainders array without ever needing to bump
  more entries than exist. The zero-total case (`counters` all zero) short-circuits to all
  zeros rather than dividing by zero, matching the "never thrown" test.
- **Determinism**: the remainder sort ties-break on ascending original index, so equal
  fractional remainders never reorder between runs (matters for both the bar and the mix, which
  the brief calls out explicitly as a real-weight subtlety).
- **YAGNI**: exactly the one function and two exported types (`Counters`, `Live`) the brief
  names; no `View` type export, no speculative helpers, nothing built for Task 12's renderer
  beyond the shape the brief specifies. `shares` is local/unexported since nothing outside this
  module needs it.
- **Test honesty**: did not weaken, remove, or add assertions beyond the brief's test file; the
  RED run failed for the predicted reason (missing module, not a typo or scaffolding issue);
  the only post-transcription edit was mechanical (stylua's own reformat), verified with a full
  re-run before commit.
- **Shared-fixture boundary respected**: `shared-fixtures/game-rules.json` and both
  `GameRules` implementations (Luau and TypeScript) were not touched — the test imports the
  real `GameRules.luau` and asserts against its live `nextPot` output rather than a duplicated
  constant.
- **Gates**: `stylua --check`, `selene`, and `lune run tests/run` all clean at commit time.

No concerns to flag. Task 7 is complete as scoped.

---

## Fix Report — Round 1 (2026-08-02)

### The findings

**Finding 1 (Important)**: `winRatePct` was computed via `math.round(wins / roundsPlayed * 100)`
while `bar.win` was computed via largest-remainder apportionment across `{wins, safes, losses}`.
These are two different algorithms for the same underlying quantity (the share of rounds won)
and they can disagree at exact ties: for `{roundsPlayed=3, wins=1, safes=1, losses=1}`,
round-to-nearest gives `winRatePct=33` but largest-remainder's tie-break hands the leftover unit
to `wins`, giving `bar.win=34` — a visible one-point contradiction between the headline number
and the bar segment for the identical count. This reproduces for any exact three-way split, not
just the brief's fixture (the reviewer additionally cited 100/100/100 of 300). No existing test
caught it, because the only numeric `winRatePct` assertion used a non-tied fixture. Traced to the
brief's own Step 3 reference code, faithfully transcribed in the original implementation — not an
error introduced during the first pass.

**Finding 2 (Minor)**: `View` was not an exported type; the function returned an untyped table.
Task 12's renderer needs something to annotate against.

**Finding 3 (Minor)**: the `shares()` doc comment claimed "the total is always exactly 100"
without noting the all-zero short-circuit returns all zeros instead.

### The fix

Taken from the rewritten brief (re-read in full before starting), transcribed as given:

- `roblox/src/shared/LedgerModel.luau`:
  - Added `export type View = { paysNext: number, winRatePct: number, bar: {...}, mix: {...},
    lifetime: Counters, live: Live }` and annotated `LedgerModel.view(...): View`.
  - Replaced the independent `winRatePct` calculation with `winRatePct = bar[1]` — one number,
    defined once, for one quantity, instead of two calculations that can drift apart. Added a
    comment explaining why round-to-nearest and largest-remainder disagree at ties.
  - Corrected the `shares()` doc comment to state the all-zero exception rather than overclaiming
    an unconditional 100.
- `roblox/tests/LedgerModel.spec.luau`: added the brief's new test, `"win rate NEVER disagrees
  with the bar's win segment"`, which asserts `v.winRatePct == v.bar.win` across six count
  profiles including two exact-tie cases (`{1,1,1}` of 3, `{100,100,100}` of 300, plus the
  three-way tie `{3,3,3}` of 9). This is the regression guard; it was not weakened.

The apportionment (`shares()`'s core algorithm) was explicitly cleared by the review and left
untouched: all-zero short-circuit, `leftover` provably in `[0, n-1]`, and the strict-total-order
tie-break comparator are all unchanged.

### TDD evidence for this fix round

**RED** — the new regression test was run against the **pre-fix** module (temporarily restored
via `git show HEAD:roblox/src/shared/LedgerModel.luau`, with the new test already added) to
confirm it actually reproduces the reported bug before the fix existed:

```
$ lune run tests/run   # from roblox/, new test vs. OLD (round-to-nearest) LedgerModel.luau
```

```
FAIL  LedgerModel.view > win rate NEVER disagrees with the bar's win segment
      /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/LedgerModel.spec:61: expected 33 to be 34
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

851 passed, 1 failed, 852 total
```

Exactly the new test fails, and for exactly the reported reason (`33` from round-to-nearest vs.
`34` from the bar's largest-remainder tie-break on the first fixture case) — every other test in
the suite, including the pre-existing `winRatePct == 34` non-tied case, still passed against the
old module, confirming the new test isolates this one bug rather than reflecting a broader
rewrite.

**GREEN** — after restoring the fixed module (`winRatePct = bar[1]`, `View` export, corrected
comment):

```
$ lune run tests/run   # from roblox/
```

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

852 passed, 0 failed, 852 total
```

852 (up from 851 pre-fix: +1 for the new regression test — no other tests were added, removed,
or reshaped).

**Gates:**

```
$ stylua --check src tests tools && selene src tools
```

Both commands exited `0` on the first try this round (the brief's rewritten Step 3/Step 1 source
was already stylua-clean when transcribed) — `stylua --check` reported no diff, `selene`
reported `0 errors, 0 warnings, 0 parse errors`.

### Commit

`765f16c` — `fix(roblox): LedgerModel — winRatePct is the bar's win share, not a second calc`

### Self-review of the fix

- **Root cause addressed, not papered over**: the fix removes the second calculation entirely
  (`winRatePct = bar[1]`) rather than patching the rounding function to special-case ties —
  matches the brief's framing that two numbers for one quantity is the bug, independent of how
  either number is individually computed.
- **Apportionment untouched**: `shares()`'s algorithm, all-zero short-circuit, `leftover` bound,
  and tie-break comparator are byte-identical to the version the review explicitly cleared —
  confirmed via `git diff`, which shows only the doc-comment line changing in that function.
- **Purity preserved**: still no `Instance`, `game`, `Enum`, or `task` anywhere in the module.
- **Regression guard untouched after being added**: the new test was transcribed verbatim from
  the rewritten brief and not edited afterward; it was proven to fail against the pre-fix module
  (RED) before being proven to pass against the fix (GREEN), which is the actual guarantee that
  it guards against recurrence rather than just asserting a formality.
- **Scope discipline**: only `LedgerModel.luau` and its spec were touched; `GameRules.luau` and
  `shared-fixtures/game-rules.json` were not touched, consistent with the global constraints.
- **Test honesty**: no assertion from either the original or rewritten brief was weakened,
  removed, or skipped; the `winRatePct == 34` non-tied case from the first pass still exists and
  still passes (`bar[1]` gives the same `34` there since that fixture has no tie).

No concerns to flag on the fix. Round 1 complete.
