# Task 4 report — Env config: the three variables and the TEST_MODE guard

**Status:** DONE_WITH_CONCERNS (concerns are observations about brief-specified behaviour, not defects)
**Commit:** `88de2c0` feat(crowd): CROWD_SIZE / CROWD_MIX / CROWD_SEED, refused when malformed, disabled under TEST_MODE
**Branch:** `thread/crowd`

## What I implemented

`server/src/crowdConfig.ts` — the crowd's env surface, verbatim from the brief:

- `interface CrowdConfig { size: number; mix: Mix; seed: number }`
- `readCrowdConfig(env, opts: { testMode, log, randomSeed }): CrowdConfig | null` — the exact
  name and shape Task 7 will wire into the composition root.
- `null` means "no crowd": `CROWD_SIZE` unset, empty, or `0`, silently.
- Malformed values **throw** (boot refuses, same posture as a missing `MONGODB_URI`):
  `CROWD_SIZE="-3" must be a non-negative integer`, likewise `CROWD_SEED`; a bad `CROWD_MIX`
  propagates Task 3's `CROWD_MIX: …` message unchanged.
- `TEST_MODE=true` with `CROWD_SIZE>0` returns `null` after logging the exact warning string —
  a cycled World Throw beside a disagreeing plurality would lie on the reveal card.
- `CROWD_SEED` unset → `opts.randomSeed()` plus the exact log line naming the seed, so any run
  can be reproduced.

Placed beside `testModeCycle.ts` at `src/` level (not under `engine/`), per the house pattern
for testable env logic extracted from `index.ts`.

## TDD evidence

**RED** — `npx vitest run src/crowdConfig.test.ts` (from `server/`), test file written first:

```
 FAIL  src/crowdConfig.test.ts [ src/crowdConfig.test.ts ]
Error: Cannot find module './crowdConfig' imported from .../server/src/crowdConfig.test.ts
 ❯ src/crowdConfig.test.ts:2:1
      2| import { readCrowdConfig } from './crowdConfig';
 Test Files  1 failed (1)
      Tests  no tests
```

Exactly the failure the brief predicted.

**GREEN** — same command after writing `src/crowdConfig.ts`:

```
 Test Files  1 passed (1)
      Tests  5 passed (5)
   Duration  142ms
```

**Full suite** — `npm test` from `server/`:

```
 Test Files  25 passed (25)
      Tests  546 passed (546)
   Duration  7.78s
```

**Typecheck** — `npx tsc --noEmit`: clean, exit 0.

Note on the suite: the first `npm test` run showed `1 failed | 545 passed`, in
`src/transports/socketAdapter.test.ts` (the `CLAIM_LIMIT` concurrent-claim assertion), a file my
change does not touch and does not import. Two subsequent runs were fully green (546/546). It is
a pre-existing flaky socket/DB-timing test, not a regression from this task.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/crowdConfig.ts` (new, 44 lines)
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/crowdConfig.test.ts` (new, 41 lines)

Only these two were staged. The pre-existing dirty `.superpowers/sdd/.gitignore` was left
untouched and uncommitted; no `git stash` was used.

## Self-review findings

Read the committed diff back in full.

- Names and strings match the brief character-for-character: both `[CROWD]` log lines, both
  `must be a non-negative integer` messages, `CrowdConfig`, `readCrowdConfig`, and the
  `{ testMode, log, randomSeed }` opts shape Task 7 depends on.
- Verified against Task 3's actual source rather than assuming: `Mix`, `parseMix`, `DEFAULT_MIX`
  are exported as expected, and `parseMix`'s unknown-archetype error does begin
  `CROWD_MIX: unknown archetype "ninja"` (vitest `toThrow` substring-matches the longer message,
  which also lists the known ids).
- Did not import `formatMix` — the brief's implementation does not use it, and an unused import
  would be dead weight. No overbuilding: no strength variable, no extra exports, no helpers
  beyond `nonNegativeInt`.
- `nonNegativeInt` uses `Number(raw)`, so it accepts `'1e3'`, `'0x10'` and surrounding
  whitespace, and rejects `'abc'`, `'-3'`, `'2.5'`, `'Infinity'`, `'NaN'`. Empty string never
  reaches it — both call sites short-circuit on `''` first. Behaviour is correct for the spec.
- Test output is pristine: no console noise, no unhandled rejections, no skipped tests.

## Concerns

Both are properties of the brief-specified code, kept deliberately rather than "fixed" on my own
initiative. Flagging for the controller in case Task 7 or a later task wants them addressed:

1. **`DEFAULT_MIX` is returned by reference.** With `CROWD_MIX` unset, `config.mix` *is* the
   module-level `DEFAULT_MIX` object from `SyntheticCrowd.ts`. Nothing mutates it today
   (`allocate`/`createCrowd` only read), so this is latent, not live — but a future consumer that
   normalised weights in place would silently corrupt the default for the process.
2. **Under `TEST_MODE`, `CROWD_MIX` and `CROWD_SEED` are never validated.** The guard returns
   early, so a typo like `CROWD_MIX=ninja:1` boots fine on dev/prod (both run TEST_MODE) and only
   throws the day someone turns TEST_MODE off. `CROWD_SIZE` itself *is* still validated before the
   guard, so size typos are caught in every mode. Whether the mix/seed should also be validated
   eagerly is a design call above my task's pay grade.

---

# Task 4 fix report — validation moved ahead of the TEST_MODE guard

**Status:** DONE
**Commit:** `1d23924` fix(crowd): validate CROWD_MIX and CROWD_SEED before the TEST_MODE guard -- a typo refuses to boot in every mode
**Branch:** `thread/crowd`
**Ruling implemented:** concern 2 above — under `TEST_MODE` the early return meant `CROWD_MIX`
and `CROWD_SEED` were never parsed, so a typo booted fine on dev/prod (both run TEST_MODE) and
only threw the day someone turned TEST_MODE off. The spec says malformed values refuse at boot.

## What changed

`server/src/crowdConfig.ts` — a reorder inside `readCrowdConfig`, no new env vars, no message
string touched:

1. `CROWD_SIZE` parsed as before (unset/empty/`0` → `null` silently; malformed → throw).
2. **New position:** `CROWD_MIX` parsed (or `DEFAULT_MIX`) and `CROWD_SEED`, when set and
   non-empty, validated with `nonNegativeInt` — both now *before* the guard, so they throw in
   every mode. The validated seed is held in `configuredSeed: number | null` rather than being
   applied immediately.
3. The `TEST_MODE` guard then logs the same warning verbatim and returns `null`.
4. Only past the guard, when `configuredSeed === null`, is `opts.randomSeed()` called and the
   "CROWD_SEED unset; using N …" line logged — so a TEST_MODE-disabled crowd still draws no seed
   and prints exactly one line.

Concern 1 (`DEFAULT_MIX` returned by reference) was not in the ruling and is untouched.

## Covering tests

Three added to `server/src/crowdConfig.test.ts` (the five existing ones are unchanged):

- `still refuses a malformed CROWD_MIX under TEST_MODE, so a typo cannot lie in wait` —
  `readCrowdConfig({ CROWD_SIZE: '5', CROWD_MIX: 'ninja:1' }, opts(true))` throws
  `CROWD_MIX: unknown archetype "ninja"`.
- `still refuses a malformed CROWD_SEED under TEST_MODE` — `{ CROWD_SIZE: '5', CROWD_SEED: 'abc' }`
  throws `CROWD_SEED="abc" must be a non-negative integer`.
- `does not draw or announce a seed for a crowd TEST_MODE has disabled` — with
  `randomSeed: vi.fn(() => 4242)`, asserts `randomSeed` was never called and `log` was called
  exactly once (the ignored-warning line only).

## TDD evidence

**RED** — `npx vitest run src/crowdConfig.test.ts` from `server/`, tests written before the reorder:

```
 FAIL  src/crowdConfig.test.ts > readCrowdConfig > still refuses a malformed CROWD_MIX under TEST_MODE, so a typo cannot lie in wait
AssertionError: expected [Function] to throw an error
 ❯ src/crowdConfig.test.ts:44:14

 FAIL  src/crowdConfig.test.ts > readCrowdConfig > still refuses a malformed CROWD_SEED under TEST_MODE
AssertionError: expected [Function] to throw an error
 ❯ src/crowdConfig.test.ts:49:14

 Test Files  1 failed (1)
      Tests  2 failed | 6 passed (8)
```

Both new throw-tests failed for exactly the predicted reason: no throw happened, because the
guard returned first. **Honest note on the third test:** the brief predicted it would also fail
("randomSeed/log are called"), and it did **not** — under the old order the guard already
returned before any seed was drawn, so `randomSeed` was never called. It passed in RED. It is a
regression guard for the reorder, not a driver of it: it is the test that would have caught me
if I had moved the `randomSeed()` draw ahead of the guard along with the validation. It still
passes after the change, which is the point.

**GREEN** — same command after the reorder:

```
 Test Files  1 passed (1)
      Tests  8 passed (8)
   Duration  148ms
```

**Full suite** — `npm test` from `server/`:

```
 Test Files  25 passed (25)
      Tests  549 passed (549)
   Duration  9.51s
```

546 before, 549 now — the three new tests, no regressions. No flake this time (the
`socketAdapter.test.ts` `CLAIM_LIMIT` test noted above passed on the single run).

**Typecheck** — `npx tsc --noEmit` from `server/`: clean, exit 0.

## Files changed

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/crowdConfig.ts`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/crowdConfig.test.ts`

Only these two were staged. The pre-existing dirty `.superpowers/sdd/.gitignore` is still
untouched and uncommitted; no `git stash` was used.

## Process note

During the first attempt to append the new tests, a shell chain whose `mv` sat outside the `&&`
guard ran after a failed BSD `head -n -1` and overwrote `src/crowdConfig.test.ts` with an empty
file. It was recovered intact with `git checkout -- src/crowdConfig.test.ts` (the file was
committed at `88de2c0`), and the append was redone with a Python script that asserts on the
existing content first. Nothing was lost and the five original tests in the committed file are
byte-identical to before.
