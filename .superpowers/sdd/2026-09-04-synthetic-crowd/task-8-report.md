# Task 8 report — Simulator core (`runSimulation`, `applyBank`)

**Status:** DONE
**Commit:** `8ab146e` feat(sim): runSimulation -- humans as policies with pots, three bank rules, the oracle ceiling
**Branch:** `thread/crowd` (worktree `.worktrees/crowd`)

## What I implemented

`server/src/sim/Simulation.ts` — the offline simulator core, transcribed verbatim from the brief:

- Types `BankRule`, `HumanPolicy`, `HumanSpec`, `HumanRoundRecord`, `RoundRecord`, `SimOptions`
  exactly as the brief's "Produces" list names them (Task 9 consumes `RoundRecord`, `HumanSpec`,
  and `humans[i].result/potAfter/banked`).
- `applyBank(rule, pot, banked)` — pure. `ride` never banks; `rung` banks the whole pot once
  `pot >= at`; `ratio` implements the partial-banking spec's `f* = (bank÷pot + 1)/4`, rides
  everything once `b >= 3`, and otherwise keeps the largest `keepOptions(pot)` rung `<= f*·pot`.
  A pot of 0 short-circuits.
- `runSimulation(o)` — one `mulberry32(seed)` rng threaded through the crowd, the humans'
  `sample`, and `deriveWorldThrow`'s tie/small-N fallback, so a run is reproducible from its seed.
  Per round: humans decide from LAST round's memory, crowd throws, human throws are added to the
  tally, `deriveWorldThrow` picks the world, `crowd.observe(world)`, then each human's result /
  `nextPot` / `applyBank` / `advance`.
- The oracle: `WHAT_BEATS[argmax(crowd.expected())]`, `argmax` initialised to `'R'` and comparing
  strictly, so ties resolve to the first of R, P, S as the constraint requires.

No new packages; no I/O, no Mongo, no timers.

## TDD evidence

**RED** — wrote `src/sim/Simulation.test.ts` first (brief's test body verbatim), then
`npx vitest run src/sim/Simulation.test.ts`:

```
FAIL  src/sim/Simulation.test.ts [ src/sim/Simulation.test.ts ]
Error: Cannot find module './Simulation' imported from .../server/src/sim/Simulation.test.ts
Test Files  1 failed (1)
      Tests  no tests
```

**GREEN** — after writing `src/sim/Simulation.ts`, same command:

```
Test Files  1 passed (1)
      Tests  8 passed (8)
```

**Full suite + typecheck** (from `server/`, before committing):

```
npm test        -> Test Files  26 passed (26)   Tests  565 passed (565)
npx tsc --noEmit -> clean (Simulation.ts is under rootDir and compiled)
```

`tsconfig.json` excludes `src/**/*.test.ts`, so I typechecked the test file separately with the
same compiler flags — also clean.

## Files changed

- `server/src/sim/Simulation.ts` (new, 102 lines)
- `server/src/sim/Simulation.test.ts` (new, 89 lines)

Nothing else staged. The pre-existing dirty `.superpowers/sdd/.gitignore` was left untouched.

## Self-review findings (read my own diff)

1. **Rng ordering is fixed and load-bearing.** Humans sample before `crowd.throws()`, and
   `deriveWorldThrow` draws only on a tie or below `minParticipants`. Any future reordering
   changes every seeded expectation in this file and in Task 9's reporters. Determinism test
   passes (two runs of 50 rounds / 20 bots compare equal).
2. **No aliasing on `counts`.** `createCrowd().throws()` builds a fresh `{R,P,S}` object each
   call, so mutating it with the human throws and then storing it in the `RoundRecord` is safe.
3. **`crowd.throws(round)` ignores its argument.** The `Crowd` interface declares
   `throws(roundCount: number)` but `SyntheticCrowd`'s implementation takes none. Passing
   `round` is harmless and matches the brief; it is dead data today.
4. **Humans read last round's memory.** All human decisions for a round are computed before any
   state mutation, so no human sees its own in-round update. Verified by reading the loop order.
5. **Oracle memory is advanced but unused.** `advance` runs for oracle humans too; the oracle's
   decision ignores memory. Costs nothing and keeps the state shape uniform.
6. **Probe of the seeded assertions** (throwaway test, deleted): with seed 3 the all-conform
   run's round 0 is a `LOSS`, so the test takes its `3 ** 18` branch (`pot19 = 387420489`), and
   the brief's "whichever the seed gives" hedge is doing real work rather than papering over
   a wrong expectation.
7. **`Memory` cast is redundant.** `freshMemory() as Memory` — `freshMemory` already returns
   `Memory`. Left as briefed; no behavioural difference.

## Concerns

- **The ratio rule has a cliff at b = 3, by construction.** Probed directly:
  `applyBank({kind:'ratio'}, 27, 78.3)` -> `{pot: 9, banked: 96.3}` (banks 18), but
  `applyBank({kind:'ratio'}, 27, 81)` -> `{pot: 27, banked: 81}` (banks nothing). The jump from
  banking two thirds to banking zero across one step of the wallet ratio is what the
  partial-banking spec's rule says, and the brief's test pins both sides of it — but a Task 9
  report that plots ratio bankers' wallets will show that discontinuity, and it is the rule, not
  a bug in this code.
- **`applyBank` does not require integer inputs.** Fed a fractional wallet it returns a
  fractional wallet (see 78.3 above). In `runSimulation` the wallet is only ever a sum of ladder
  pots, so it stays integral; the function is simply not defensive about it.
- **`minParticipants` defaults to 5 here**, matching `deriveWorldThrow`'s own default. A tiny
  simulated crowd (crowdSize + humans < 5) therefore gets a random world every round — correct,
  but a simulator run configured that way is measuring noise, not the crowd.
