# Task 1: Seeded PRNG — Report

**Status:** DONE
**Commit:** `9f9c79f` feat(crowd): seeded mulberry32 PRNG -- the reproducibility the synthetic crowd needs
**Branch:** `thread/crowd` (worktree `.worktrees/crowd`)

## What I implemented

Transcribed the brief exactly. `server/src/engine/Prng.ts` exports:

- `type Rng = () => number`
- `mulberry32(seed: number): Rng` — uniform in [0,1), seeded, no dependencies
- `randomSeed(): number` — a 32-bit unsigned integer, for when `CROWD_SEED` is unset

No deviation from the brief's code, no added helpers, no new packages.

## TDD evidence

### RED

Command (from `server/`): `npx vitest run src/engine/Prng.test.ts`

```
 ❯ src/engine/Prng.test.ts (0 test)

⎯⎯⎯⎯⎯⎯ Failed Suites 1 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  src/engine/Prng.test.ts [ src/engine/Prng.test.ts ]
Error: Cannot find module './Prng' imported from .../server/src/engine/Prng.test.ts
 ❯ src/engine/Prng.test.ts:2:1
      1| import { describe, it, expect } from 'vitest';
      2| import { mulberry32, randomSeed } from './Prng';
       | ^

 Test Files  1 failed (1)
      Tests  no tests
```

Matches the brief's expected failure (`Cannot find module './Prng'`).

### GREEN

Command: `npx vitest run src/engine/Prng.test.ts`

```
 RUN  v4.1.8 .../server

 Test Files  1 passed (1)
      Tests  4 passed (4)
   Duration  225ms
```

4 tests, as the brief predicted. The known-answer vectors for seeds 1 and 42 passed on the
first implementation run — the transcribed algorithm reproduces the brief's expected
sequences exactly, which is the real check that this is mulberry32 and not a lookalike.

### Full suite

Command: `npm test`

```
 Test Files  22 passed (22)
      Tests  511 passed (511)
   Duration  8.21s
```

No failures, no stray warnings, no unhandled errors.

### Typecheck

`npx tsc --noEmit` → exit 0, no output.

## Files changed

- `server/src/engine/Prng.ts` (new, 19 lines)
- `server/src/engine/Prng.test.ts` (new, 35 lines)

Nothing else staged. The worktree's pre-existing dirty file
(`.superpowers/sdd/.gitignore`) was deliberately left unstaged and is untouched.

## Self-review findings

Read the committed diff (`git show HEAD`). Checks:

- **Names match the brief exactly** — `Rng`, `mulberry32`, `randomSeed`, all exported, so
  later tasks' imports (`import { Rng, mulberry32, randomSeed } from './Prng'`) resolve.
- **Completeness** — all three interface items the brief names are present; both files the
  brief names exist; commit message is the brief's, verbatim, with the required trailer.
- **No overbuild** — no seed-sequence helpers, no `Rng`-consuming utilities, no exported
  constants beyond what the brief specifies. Later tasks own that.
- **`randomSeed` range is genuinely correct, not just test-passing** — `>>> 0` performs
  ToUint32, truncating toward zero, so the result of `Math.random() * 2**32` lands in
  [0, 2**32) as integers. The test only samples one draw, so I reasoned about the bound
  rather than trusting the single sample.
- **Style consistent with the directory** — 4-space indent matches the other `engine/`
  modules; CommonJS/ESM interop is a non-issue since the file has no imports.

No issues found.

## Concerns

None blocking. Two notes for whoever picks up the later tasks:

1. `randomSeed()` draws from `Math.random()`, so it is only as good as V8's seeding — fine
   for "pick a seed and log it", not for anything security-adjacent. The file comment says
   as much.
2. `mulberry32` carries mutable closure state, so a single `Rng` instance shared across
   concurrent consumers interleaves their draws and destroys per-consumer reproducibility.
   If a later task wants a reproducible per-bot or per-round stream, it should derive a
   child generator (e.g. `mulberry32(seed ^ roundNumber)`) rather than share one `Rng`.
