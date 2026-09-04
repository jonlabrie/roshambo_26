# Final whole-branch review — fix wave

Branch `thread/crowd`, worktree `.worktrees/crowd`. Two commits:

- `1f93533` fix(crowd): seed the live tie-break from CROWD_SEED -- a zero-human crowd now replays exactly; [FATAL] on a malformed CROWD_*; UNIFORM frozen
- `47635af` docs(wiki): synthetic crowd -- float caveat on the readability table, the counter-vs-second reading of Q1, the boot-refusal rule under TEST_MODE

## #1 (Important) — the live World Throw tie-break was `Math.random`

`server/src/index.ts:48` now builds ONE rng for the whole crowd:

```ts
const crowdRng = crowdConfig ? mulberry32(crowdConfig.seed) : undefined;
```

That same instance is passed to `createCrowd({ …, rng: crowdRng! })` (`server/src/index.ts:51`)
and as `random` to the plurality tie-break in the non-TEST_MODE branch of `pickWorldThrow`
(`server/src/index.ts:127`):

```ts
: deriveWorldThrow(counts, { minParticipants: worldThrowMinParticipants, ...(crowdRng ? { random: crowdRng } : {}) }),
```

When `crowdRng` is undefined (no crowd configured) the `random` key is omitted entirely, so
`deriveWorldThrow`'s `Math.random` default stands — behaviour unchanged from before for every
no-crowd deployment. The comment at `server/src/index.ts:44-47` says why the sharing is the
whole property: a tie broken unseeded forks the crowd's future the first time two throws tie,
and the live sequence stops matching `runSimulation({ humans: [] })` on the same seed.

## #3 (Minor) — tests

Both new tests are in `server/src/engine/RoundEngine.test.ts` (new `describe`, "a seeded crowd
with no humans replays exactly (spec §5)"). `createCrowd`, `deriveWorldThrow` and `mulberry32`
are imported by the TEST ONLY (`server/src/engine/RoundEngine.test.ts:3-5`); `RoundEngine.ts`
itself imports none of them.

1. `two engines on seed %i produce an identical world-throw sequence` — two engines, each with a
   real `createCrowd({ size: 30, rng })` and a `pickWorldThrow` that shares that ONE
   `mulberry32(seed)` with the tie-break, no human throws, ticked through 20 rounds; asserts the
   two `roundClosed` sequences (worldThrow + counts) are identical.

   **The dispatched seed 7 is not sufficient on its own.** Probed seeds 1–24 at crowd 30 for
   tied pluralities in the first 20 rounds: seed 7 draws **zero** ties, so the assertion is
   vacuous there — it passes whether or not the tie-break is seeded. Seed 3 ties on round 0 and
   six more times in 20 rounds. The test is therefore `it.each([7, 3])`: seed 7 as dispatched,
   seed 3 so the assertion is actually load-bearing. Reasoning is in a comment above the test.

   RED (the `random: rng` argument removed from the test's picker, i.e. today's index.ts
   reproduced in the harness):

   ```
   × two engines on seed 3 produce an identical world-throw sequence 8ms
   Tests  1 failed | 29 passed (30)
   ```

   (seed 7 passed in the RED state — the vacuity above, demonstrated.)

   GREEN (shared rng restored): `Test Files 1 passed (1) / Tests 30 passed (30)`.

2. `a crowd of 30 alone clears the participant floor — the picker never sees an empty round` —
   `vi.fn` picker, `createCrowd({ size: 30, rng: mulberry32(7) })`, no humans; asserts the picker
   was called once and its `counts` sum to 30, so the `minParticipants: 5` floor is met by bots
   alone. (The `size: 0` half was dropped per the dispatch.)

## #2 (Minor) — `[FATAL]` on a malformed `CROWD_*`

`server/src/index.ts:29-43`: `readCrowdConfig` is wrapped in `readCrowdConfigOrDie()`, which on
throw prints `[FATAL] <message>` and `process.exit(1)` — the same shape the `MONGODB_URI` path
uses, instead of an uncaught stack trace.

Boot check, from `server/`:

```
$ npx tsc && (MONGODB_URI= TEST_MODE=false CROWD_SIZE=5 CROWD_MIX=ninja:1 node dist/index.js; echo "exit $?")
[dotenv@17.2.3] injecting env (0) from .env -- tip: 🔄 add secrets lifecycle management: https://dotenvx.com/ops
[FATAL] CROWD_MIX: unknown archetype "ninja" (known: random, wsls, counter, conform, rocky, second)
exit 1
```

## #5 (Minor) — `UNIFORM` returned by reference

`server/src/engine/CrowdPolicies.ts:31-34`: now
`export const UNIFORM: Dist = Object.freeze({ R: 1 / 3, P: 1 / 3, S: 1 / 3 })`, with a comment
saying `random` and the zero-total fallback both hand it out by reference. Type stays `Dist`; no
write site was touched — all of them build fresh literals.

```
$ npx vitest run src/engine/CrowdPolicies.test.ts src/engine/SyntheticCrowd.test.ts
Test Files  2 passed (2)
Tests  31 passed (31)
```

Nothing mutated it (a frozen object would have thrown in the module's strict-mode ESM).

## #4 (Minor, docs) — float caveat on the readability table

`docs/wiki/world/world-throw.md`, three lines directly under the readability fenced block:
the `banked` / `max pot` figures for `second` and `oracle` are past 2^53 and are float
approximations printed as digits, not exact counts — the ride-forever pot compounds without
bound in the sim, so those two rows read as an order of magnitude and nothing finer.

## #6 (Minor, docs) — the counter-vs-second reading of Q1

`docs/wiki/world/world-throw.md`, a new paragraph under "Pre-registered Q1": read a ~42% result
as progress. The naive HUD reading (`counter`) scores ~42.2%, under the 45% line; the rule that
clears it is `second` (counter the counter). A first-time human tries `counter` first, so ~42%
means they found the first rule and not the second, and Q1 is really asking whether the second
one is findable.

## Rulings note (docs) — boot refusal under TEST_MODE

`docs/wiki/world/world-throw.md`, § Synthetic crowd, "Config" paragraph: a malformed `CROWD_MIX`
or `CROWD_SEED` refuses to boot in every mode, `TEST_MODE` included, except when the crowd is
switched off outright (`CROWD_SIZE` of zero), which skips parsing entirely — ruling 2026-09-04.

⚠ The first phrasing of that sentence wrote the off-switch as `` `CROWD_SIZE` is `0` ``, which
the wiki lint's constant check read as a claim about `CROWD_SIZE`'s value and failed against the
code's 30 (36 errors). Rephrased to "`CROWD_SIZE` of zero" — no numeral, no false match.

## Verification

| check | result |
|---|---|
| `cd server && npm test` | 28 files, **582 tests passed** |
| `cd server && npx tsc --noEmit` | clean |
| boot check (#2) | `[FATAL] CROWD_MIX: unknown archetype "ninja" …` / `exit 1` |
| `node tools/wiki/lint.mjs` | **35 error(s), 1 warning(s) across 58 pages** — unchanged from baseline, nothing on `world/world-throw.md` |

Nothing outside the six listed files was staged; `.superpowers/sdd/.gitignore` remains modified
and uncommitted, as before this wave.
