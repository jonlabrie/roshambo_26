# Task 7 report — Composition root: config → crowd → engine, and the per-round log

**Commit:** `c35ce0d` feat(server): wire the synthetic crowd from env into the engine; one [CROWD] line per round

## What I implemented

### 1. `guardCrowd` (controller ruling extending the brief) — `server/src/crowdConfig.ts`
A `CrowdSource` decorator that keeps an exception in a bot policy from propagating out of the
engine's `setInterval` tick and killing the process. `throws()` failures return `{R:0,P:0,S:0}`
and log one line; `observe()` failures are swallowed with one line. Verbatim from the ruling.

### 2. `server/src/index.ts` wiring (brief Steps 1–4)
- Imports: `RoundEngine, CrowdSource, RoundClosedEvent`; `readCrowdConfig, guardCrowd`;
  `createCrowd, formatMix`; `mulberry32, randomSeed`.
- Crowd built from `process.env` immediately after the `TEST_MODE`/`PORT`/`MONGODB_URI` const
  group, so a malformed value throws before anything else boots. `createCrowd(...)` is wrapped
  in `guardCrowd(..., msg => console.error(msg))` per the ruling.
- `crowd,` added to `new RoundEngine({...})` after `pickWorldThrow`. `makeEngine`'s signature
  unchanged — it closes over the module-level `crowd`.
- `engine.on('roundClosed', ...)` listener added immediately after `const engine = makeEngine(...)`,
  guarded by `if (crowd)`, with the exact `[CROWD] round … → W` string (Unicode arrow).

## TDD evidence for guardCrowd

RED (tests written first, before the function existed):
```
 FAIL  src/crowdConfig.test.ts > guardCrowd > passes calls through when the crowd behaves
 FAIL  src/crowdConfig.test.ts > guardCrowd > a throwing crowd yields an empty tally and one log line, and observe() failures are swallowed
TypeError: guardCrowd is not a function
 Test Files  1 failed (1)
      Tests  2 failed | 8 passed (10)
```

GREEN (after adding `guardCrowd`):
```
 Test Files  1 passed (1)
      Tests  10 passed (10)
```

## Suite + typecheck

```
$ npm test
 Test Files  25 passed (25)
      Tests  557 passed (557)

$ npx tsc --noEmit
(clean)
```

## Boot-log checks (Step 6)

Built with `npx tsc`, then:

**Case 1 — `MONGODB_URI= TEST_MODE=false CROWD_SIZE=30 CROWD_SEED=1`**
```
[CROWD] on: size 30, seed 1, mix random:20,wsls:35,counter:20,conform:15,rocky:10
[SYS] Roshambo Server Init. TEST_MODE: false
[FATAL] MONGODB_URI is not defined in .env!
exit=1
```

**Case 2 — `MONGODB_URI= TEST_MODE=true CROWD_SIZE=30`**
```
[CROWD] CROWD_SIZE=30 ignored: TEST_MODE cycles the World Throw, and a crowd whose plurality disagrees with it would lie on the reveal card
[CROWD] off
[SYS] Roshambo Server Init. TEST_MODE: true
[FATAL] MONGODB_URI is not defined in .env!
exit=1
```

**Case 3 — `MONGODB_URI= TEST_MODE=false CROWD_SIZE=5 CROWD_MIX=ninja:1`**
```
Error: CROWD_MIX: unknown archetype "ninja" (known: random, wsls, counter, conform, rocky, second)
    at parseMix (dist/engine/SyntheticCrowd.js:21:19)
    at readCrowdConfig (dist/crowdConfig.js:24:101)
    at Object.<anonymous> (dist/index.js:31:55)
exit=1
```
Uncaught throw at import, non-zero exit — the "malformed values crash the boot" constraint holds.

`dist/` is git-ignored and was not committed.

## Files changed
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/index.ts`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/crowdConfig.ts`
- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/.worktrees/crowd/server/src/crowdConfig.test.ts`

## Self-review findings (read my own diff)
- Diff is exactly the three files; the pre-existing dirty `.superpowers/sdd/.gitignore` was left
  unstaged, as instructed.
- `makeEngine`'s signature is untouched; `crowd` reaches it by closure only.
- The `roundClosed` listener is registered before `mountRoutes`/`attachSocketAdapter` and before
  the ticker starts, so no round can close unlogged.
- `[CROWD] off` also prints in the TEST_MODE-suppressed case, after the warning explaining why —
  reads correctly (config returned null, so the crowd genuinely is off).
- The guard's log goes to `console.error` (a bot policy throwing is a defect), while the config's
  advisory log goes to `console.warn`. Deliberate, per the brief and the ruling.
- Order note: the `[CROWD]` lines print *before* `[SYS] Roshambo Server Init` because the config
  block sits above that log. Harmless; the brief placed it there deliberately so a bad value
  crashes as early as `MONGODB_URI` would.

## Concerns
1. **Cosmetic mismatch with the brief's expected mix string.** The brief predicted
   `mix wsls:35,counter:20,conform:15,rocky:10,random:20`; the actual output is
   `mix random:20,wsls:35,counter:20,conform:15,rocky:10`. Same content, different order —
   `formatMix` emits in `POLICY_IDS` order, which begins with `random` (Task 3, `CrowdPolicies.ts`).
   That is Task 3's behaviour, tested there; nothing in Task 7 should change it. Flagging only so
   the plan's expected-output line is not mistaken for a regression.
2. **`index.ts` remains untested**, by design (Mongo connect at import). The per-round log line's
   string is therefore verified only by reading, not by a test; every input it interpolates comes
   from `RoundClosedEvent`, which Task 5 tests.
