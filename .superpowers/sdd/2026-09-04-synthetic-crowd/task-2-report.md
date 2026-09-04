# Task 2 report: Archetype policies

## What I implemented

`server/src/engine/CrowdPolicies.ts` — the archetype vocabulary the synthetic crowd is built
from, transcribed verbatim from the brief:

- `type PolicyId` and `POLICY_IDS` in the fixed order `random | wsls | counter | conform | rocky | second`
- `type Dist = Record<Throw, number>`, `UNIFORM`, `WHAT_BEATS`, `CLOCKWISE`
- `interface Memory` + `freshMemory()`
- `pointMass(t)`, `blend(focused, strength)` (clamped), private `normalised(d)`
- `policyDistribution(id, m, strength)` — one exhaustive switch, each archetype a distribution
- `sample(d, rng)` — cumulative walk over R, P, S with an `'S'` rounding guard
- `advance(m, thrown, world)` — pure, returns a fresh Memory, `repeatRun` counted off `m.lastThrow`

`server/src/engine/CrowdPolicies.test.ts` — the brief's test file, transcribed verbatim (16 tests).

## TDD evidence

### RED

Command: `npx vitest run src/engine/CrowdPolicies.test.ts` (from `server/`)

```
 FAIL  src/engine/CrowdPolicies.test.ts [ src/engine/CrowdPolicies.test.ts ]
Error: Cannot find module './CrowdPolicies' imported from
  /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/engine/CrowdPolicies.test.ts
 ❯ src/engine/CrowdPolicies.test.ts:2:1

 Test Files  1 failed (1)
      Tests  no tests
```

Exactly the failure the brief predicted.

### GREEN

Command: `npx vitest run src/engine/CrowdPolicies.test.ts`

```
 Test Files  1 passed (1)
      Tests  16 passed (16)
   Duration  145ms
```

### Full suite + typecheck

`npx tsc --noEmit` → clean (exit 0).

`npm test`:

```
 Test Files  23 passed (23)
      Tests  527 passed (527)
   Duration  8.65s
```

No warnings, no stderr noise — pristine output.

## Files changed

- `server/src/engine/CrowdPolicies.ts` (new, 96 lines)
- `server/src/engine/CrowdPolicies.test.ts` (new, 112 lines)

Commit `54f5864` — `feat(crowd): six archetype policies as distributions over R/P/S -- wsls, counter, conform, rocky, second, random`.
Only those two files staged; the pre-existing dirty `.superpowers/sdd/.gitignore` was left alone.

## Self-review

Read the committed diff against the brief line by line.

- Every name in the brief's "Produces" list is exported with the exact spelling and order.
  `POLICY_IDS` matches character for character; the next task can build bots on it.
- Independently re-derived the hand-computed expectations before running anything, to be sure a
  pass was a real pass and not a coincidence: rocky-no-memory `0.7*0.5 + 0.1 = 0.45`;
  rocky-two-rocks (R zeroed, `{P:.3,S:.3}` → `{P:.5,S:.5}`, blended → `0.45`); wsls-SAFE
  `0.35 + 0.65/3` on `CLOCKWISE['R'] = 'S'`; second = `WHAT_BEATS[WHAT_BEATS['R']] = 'S'`;
  `sample` at `x = 0.2` landing on `P` because the R bucket test is strict `<`. All consistent
  with the brief's implementation — no discrepancy between brief text and brief tests.
- `tsconfig.json` excludes `src/**/*.test.ts`, so the test file's non-`type` import of `Memory`
  is not a `verbatimModuleSyntax` hazard for `npm run build`; esbuild elides it under Vitest.
  `tsc --noEmit` over `src/` is clean.
- No overbuilding: nothing beyond the brief's code, no extra exports, no extra tests, no
  barrel/index wiring, no touching of `GameRules.ts` or `Prng.ts`.

## Concerns

None blocking. Two notes for the tasks downstream:

1. `UNIFORM` is exported as a shared mutable object literal, and `policyDistribution` returns
   that same reference for `random` and for the no-memory cases (as the brief specifies). Any
   later consumer that mutates a returned `Dist` in place would corrupt `UNIFORM` for everyone.
   Nothing in this task mutates one; worth remembering in Task 9's oracle, which sums
   distributions — accumulate into a fresh object rather than into the first one returned.
2. `blend` clamps `strength` into `[0, 1]`, so an out-of-range mix knob degrades silently rather
   than throwing. That is the brief's intent, not a defect, but it means a miscalibrated
   `strength` will not announce itself.
