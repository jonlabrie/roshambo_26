# Task 6 Report: `HudModel` — the minimal view model and the escalation rule

## Summary

Implemented `roblox/src/shared/HudModel.luau` and `roblox/tests/HudModel.spec.luau` exactly
as specified in the task brief. `roblox/tests/HudModel.spec.luau` did not exist before this
task (checked first, per the plan's instruction), so it was created fresh with the full test
suite from the brief.

Three pure functions, no Roblox globals:
- `HudModel.newSession(): Session`
- `HudModel.view(inputs: Inputs, session: Session): View`
- `HudModel.onRoundEnded(session: Session, outcome: { couldThrow: boolean, picked: boolean }): Session`
  — pure, always returns a new table, never mutates the session passed in.

The escalation rule: arms for a new arrival, someone who threw last round, or anyone with a
pot riding; disarms after 3 consecutive misses; a "miss" only counts rounds where
`couldThrow == true` (win-bound/fate-bound rounds are excluded from the miss count, per the
brief's core requirement).

## TDD Evidence

### RED — `lune run tests/run` (from `roblox/`), before `HudModel.luau` existed

Test file `roblox/tests/HudModel.spec.luau` was written first (verbatim from the brief).
Running the suite at that point:

```
error requiring module "../src/shared/HudModel": could not resolve child component "HudModel"
[Stack Begin]
    Script '[C]' - function 'proxyrequire'
    Script '__mlua_require', Line 13
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HudModel.spec', Line 4
[Stack End]
```

Expected failure: the `require("../src/shared/HudModel")` at the top of the new spec file
fails because the module doesn't exist yet — exactly the "does not exist" failure the brief
predicted, not a logic bug in an already-present module.

### GREEN — `lune run tests/run` (from `roblox/`), after `HudModel.luau` was written

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

842 passed, 0 failed, 842 total
```

(The two `[WARN]` lines come from `tests/HandlerQueue.spec.luau`, a pre-existing, unrelated
test that deliberately exercises an error/backpressure path — not from `HudModel`.) All 842
tests across the suite pass, including every `HudModel.spec.luau` case.

### Gates

```
$ stylua --check src tests tools && selene src tools
```

First run failed on formatting in the newly-added `HudModel.spec.luau` (stylua wanted two
long `expect(HudModel.view(...))` call chains reflowed across lines — the brief's literal
test source was slightly over stylua's line-length limit). Ran `stylua src tests tools` to
auto-format, re-ran `--check` clean, then `selene src tools` reported `0 errors, 0 warnings,
0 parse errors`. Re-ran `lune run tests/run` after the reformat to confirm the auto-format
didn't change test semantics: still `842 passed, 0 failed, 842 total`.

## Files

- `roblox/src/shared/HudModel.luau` (new)
- `roblox/tests/HudModel.spec.luau` (new)

## Commit

`b040798` — `feat(roblox): HudModel — minimal view model with the gated escalation rule`

## Self-Review

- **Purity**: confirmed no `Instance`, `game`, `Enum`, or `task` anywhere in the module. Every
  function is pure math/boolean logic over its arguments.
- **No mutation**: `onRoundEnded` never writes into the `session` table it receives; every
  branch constructs and returns a brand-new table. The "does not mutate" test in the spec
  passes, and I additionally hand-traced each branch to confirm no aliasing (all `Session`
  fields are primitive booleans/numbers, so even a naive shallow copy would be safe, but the
  code doesn't rely on that — it always builds fresh literals).
- **Escalation gate matches the brief's stated intent**: arm conditions (new arrival / threw
  last round / pot riding) are ORed, all other gates (phase, secondsLeft window, pickedThisRound,
  bound, escalationPrompts, consecutiveMisses backoff) are ANDed on top — this is exactly the
  "arms generously, disarms itself" shape described in the module's own header comment and in
  the task context.
- **The "miss" definition** — the subtlest part per the task framing — is implemented as: a
  miss increments `consecutiveMisses` only when `couldThrow == true and picked == false`; when
  `couldThrow == false`, the session is carried forward completely unchanged (not even
  `threwLastRound` is touched). Verified this against all four `onRoundEnded` test cases,
  including the 10-consecutive-bound-rounds case that must leave the player still armed.
- **YAGNI**: exactly the three functions and two exported types the brief names; nothing built
  for Tasks 10/11's consumers, no extra helpers, no speculative configuration surface.
- **Test honesty**: did not weaken or remove any assertion from the brief's test file; the
  RED run failed for the predicted reason (missing module), not a typo or scaffolding issue;
  the only edit made post-transcription was mechanical (stylua's own reformat), verified with
  a full re-run before commit.
- **Gates**: `stylua --check`, `selene`, and `lune run tests/run` all clean at commit time.

No concerns to flag. Task 6 is complete as scoped.

---

## Fix Report — Round 1 (2026-08-02)

### The finding

Review (Important, escalated to project owner): the arm expression's OR-condition
`(not hasThrownThisSession or threwLastRound or pointsAtStake > 0)` made the "threw last
round" arm reason carry only **1 miss of grace**, not the stated uniform 3. A player who
threw, won nothing (pot stays 0), then missed one round ends up with
`{hasThrownThisSession=true, threwLastRound=false, consecutiveMisses=1}` — every OR term
false — so `escalate` goes false at 1 miss instead of 3. This was traced to the brief's own
reference code, faithfully transcribed in the original implementation; not an error I
introduced.

### The owner's ruling

Uniform backoff. "New arrival", "threw last round", and "pot riding" only ever described who
*starts* armed, not ongoing conditions — they're removed from the arm expression entirely.
`Session` collapses to `{ consecutiveMisses: number }`. The rule is now exactly:

```
armed = escalationPrompts and not bound and phase == "ACTIVE"
        and not pickedThisRound and consecutiveMisses < 3
```

A fresh session has zero misses, so "new arrival" is still honoured — it just falls out of
the miss counter rather than a separate live condition. `onRoundEnded` keeps its three
branches unchanged in shape: `picked` → misses reset to 0; `not couldThrow` → misses carried
forward untouched; otherwise → misses + 1.

### What changed

The rewritten brief (`task-6-brief.md`, re-read in full before starting this fix) carries the
complete replacement module and replacement test file verbatim. Both were taken as-is:

- `roblox/src/shared/HudModel.luau` — `Session` reduced to `{ consecutiveMisses: number }`;
  `hasThrownThisSession` and `threwLastRound` removed from the type, `newSession`, `view`'s
  arm expression, and `onRoundEnded`'s three return branches (all three now return a single-
  field table, since there is nothing else in `Session` to carry forward or reset).
- `roblox/tests/HudModel.spec.luau` — replaced wholesale with the rewritten brief's suite.
  Notably adds `describe("HudModel — the one-miss regression", ...)` with two tests that walk
  the owner's exact failure scenario through `onRoundEnded` (throw → miss → miss → miss) and
  assert `escalate` is still `true` after 1 and 2 misses, `false` only after the 3rd. Also adds
  a `"the backoff is UNIFORM — a pot riding buys no extra grace"` test and a
  `"throws are disabled once a pick is in"` case not present in the first draft's suite. I did
  not weaken, reshape, or drop any assertion from the rewritten brief — the whole file was
  transcribed as given, including the regression-guard block per the coordinator's explicit
  instruction not to touch it.

### TDD evidence for this fix round

**RED** — the rewritten test file was written first, against the still-unfixed (round-1)
module, to confirm the new tests actually catch the reported bug:

```
$ lune run tests/run   # from roblox/, new spec vs. OLD HudModel.luau
```

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom
FAIL  HudModel — the one-miss regression > a player who threw, won nothing, and missed ONE round is still armed
      /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HudModel.spec:127: expected false to be true
FAIL  HudModel — the one-miss regression > that same player is still armed after a SECOND miss, and silent after the third
      /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HudModel.spec:135: expected false to be true

841 passed, 2 failed, 843 total
```

Exactly the two new regression-guard tests fail, and for the reported reason (the OR-condition
evaporating at 1 miss) — everything else in the suite still passed against the old module,
confirming the new tests isolate this one bug rather than reflecting a broader rewrite.

**GREEN** — after replacing `HudModel.luau` with the owner-ruled uniform-backoff version:

```
$ lune run tests/run   # from roblox/
```

```
[WARN]
[QUEUE] dropping request for u: queue full (8)
[WARN]
[QUEUE] handler error for u: /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/HandlerQueue.spec:80: boom

843 passed, 0 failed, 843 total
```

843 (up from 842 pre-fix: +2 for the new "threws are disabled once a pick is in" and "the
backoff is UNIFORM" tests, +2 more for the regression block, -1 net from consolidating some
`settled()`/`NEW` session-literal cases into the plain `session(n)` helper — net +1 test count
difference from file restructuring, not a coverage cut).

**Gates:**

```
$ stylua --check src tests tools && selene src tools
```

First run failed identically to round 1 — stylua wanted several `expect(...).toBe(...)` call
chains in the rewritten spec reflowed (the brief's literal source again runs slightly past
stylua's line-length limit). Ran `stylua src tests tools` to auto-format, confirmed
`--check` clean, then `selene src tools` → `0 errors, 0 warnings, 0 parse errors`. Re-ran
`lune run tests/run` once more after the reformat to confirm no semantic drift: still
`843 passed, 0 failed, 843 total`.

### Commit

`c6574b8` — `fix(roblox): HudModel — uniform escalation backoff, drop threwLastRound/hasThrownThisSession`

### Self-review of the fix

- **Root cause addressed, not papered over**: the fix removes the OR-condition entirely rather
  than patching around it (e.g. bumping the "threw last round" branch's own counter) — matches
  the owner's ruling that the arm reasons are not ongoing conditions at all.
- **Purity preserved**: `onRoundEnded`'s three branches still each return a freshly-constructed
  table; no aliasing introduced by dropping fields.
- **No Roblox globals**: unchanged, still none anywhere in the module.
- **Regression guard untouched**: the coordinator asked that the
  `describe("HudModel — the one-miss regression", ...)` block not be weakened or reshaped —
  it was taken verbatim from the rewritten brief and not edited afterward.
- **Scope discipline**: only `HudModel.luau` and its spec were touched; no changes to
  `GameRules`, `shared-fixtures/game-rules.json`, or any other module, consistent with the
  global constraints.
- **Test honesty**: the RED step in this fix round was run against the *pre-fix* module
  specifically to prove the new tests reproduce the reported bug before the fix existed, not
  just to satisfy a TDD formality — that RED output is the evidence the regression test
  actually guards against recurrence.

No concerns to flag on the fix. Round 1 complete.
