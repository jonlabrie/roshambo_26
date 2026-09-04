# Task 3 report — The crowd: mix parsing, allocation, bots with memory

**Status:** DONE
**Commit:** `4e2ea80` feat(crowd): SyntheticCrowd -- exact archetype allocation, per-bot memory, observe() teaches the world throw

## What I implemented

`server/src/engine/SyntheticCrowd.ts`, exactly as the brief's code specifies:

- `type Mix = Partial<Record<PolicyId, number>>`
- `DEFAULT_MIX = { wsls: 35, counter: 20, conform: 15, rocky: 10, random: 20 }`, `DEFAULT_STRENGTH = 0.7`
- `parseMix(spec)` — comma/colon pairs, whitespace-tolerant; verbatim error strings for empty spec,
  unknown archetype (naming all six known ids), non-positive/non-numeric weight, repeated id
- `formatMix(mix)` — emits in `POLICY_IDS` order, skipping non-positive weights; round-trips through `parseMix`
- `allocate(size, mix)` — largest-remainder in `POLICY_IDS` order, fractional ties to the earlier id (`|| a - b`)
- `interface Crowd` + `createCrowd({ size, mix?, strength?, rng })` — a bot is an archetype plus a
  `Memory`; `throws()` samples and stashes each bot's `pending` throw, `observe(world)` advances every
  bot's memory (or, with no pending throw, teaches it only `lastWorld`), `expected()` sums distributions.

## TDD evidence

**RED** — `npx vitest run src/engine/SyntheticCrowd.test.ts` (test file written first, no implementation):

```
 FAIL  src/engine/SyntheticCrowd.test.ts [ src/engine/SyntheticCrowd.test.ts ]
Error: Cannot find module './SyntheticCrowd' imported from
  .../server/src/engine/SyntheticCrowd.test.ts
 Test Files  1 failed (1)
      Tests  no tests
```

**GREEN** — same command after writing `SyntheticCrowd.ts`:

```
 Test Files  1 passed (1)
      Tests  14 passed (14)
   Duration  153ms
```

**Full suite** — `npm test`:

```
 Test Files  24 passed (24)
      Tests  541 passed (541)
   Duration  11.99s
```

**Typecheck** — `npx tsc --noEmit`: clean, no output.

The hand-derived `allocate(10, DEFAULT_MIX)` expectation passed as written; the tie-break did not
need adjusting.

## Files changed

- `server/src/engine/SyntheticCrowd.ts` (new, 112 lines)
- `server/src/engine/SyntheticCrowd.test.ts` (new, 91 lines)

Nothing else staged. The pre-existing dirty `.superpowers/sdd/.gitignore` was left untouched and
unstaged.

## Self-review findings

- `expected()` accumulates into a fresh `{ R: 0, P: 0, S: 0 }`, never into a distribution returned by
  `policyDistribution` — so the shared `UNIFORM` object from CrowdPolicies is never mutated. This was
  the Task 2 review pointer; confirmed correct in the committed code.
- Error strings compared character-by-character against the brief and against the test assertions.
  All four match verbatim, including the `(known: random, wsls, counter, conform, rocky, second)`
  suffix, which is produced by `POLICY_IDS.join(', ')` rather than hardcoded.
- `Crowd.size` is `bots.length`, not `opts.size`. For any valid mix `allocate` is exact so the two are
  equal; where they could differ (an empty or all-non-positive mix) reporting the real bot count is
  the safer value.
- No overbuild: no exports beyond the eight names under "Produces", no extra options, no logging.
- `server/` has no lint script (`build`, `start`, `dev`, `test`, `test:watch` only), so `tsc --noEmit`
  is the static gate here and it is clean.

## Concerns

1. `throws(roundCount: number)` declares the parameter on the `Crowd` interface but the implementation
   ignores it — this is exactly what the brief's code specifies, and TypeScript permits the shorter
   implementation signature. Flagging it only so a later task that wants a round-dependent behaviour
   (a warm-up ramp, say) knows the hook is declared but currently inert.
2. `parseMix` tolerates malformed extras after a second colon (`wsls:1:2` parses as weight 1) and an
   id given with no colon at all yields the weight error with `got ""` rather than a distinct message.
   Neither is asserted by the brief's tests; noted in case Task 4 wants stricter shapes.
