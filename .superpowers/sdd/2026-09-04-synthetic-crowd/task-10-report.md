# Task 10 report: The CLI and `npm run sim`

**Status: DONE_WITH_CONCERNS** (concerns are observations about the *model*, not defects in this task's code — see §5.)

Commit: `359797e` feat(sim): npm run sim -- readability, blind-spread and effective-n experiments, table or --json

## 1. What I implemented

Transcribed verbatim from the brief, no deviations:

- `server/src/sim/experiments.ts` — `CliArgs`, `parseArgs`, and the three experiments
  (`readability`, `blindSpread`, `effectiveN`) each returning a plain JSON-able object.
- `server/src/sim/cli.ts` — thin printer; table by default, `JSON.stringify(out, null, 2)`
  under `--json`. Calls `main(process.argv.slice(2))` at module load.
- `server/src/sim/experiments.test.ts` — the brief's test, transcribed exactly.
- `server/package.json` — added `"sim": "tsc && node dist/sim/cli.js"` after `"test:watch"`.

Verified before starting that every consumed symbol exists with the signature the brief assumes:
`runSimulation`/`HumanSpec`/`RoundRecord` (Simulation.ts), `winRates`/`worldTransitions`/
`bankedTotals`/`maxPots`/`spreadRatio`/`WinRateRow`/`Transitions` (reporters.ts), and
`Mix`/`parseMix`/`DEFAULT_MIX`/`DEFAULT_STRENGTH`/`formatMix` (SyntheticCrowd.ts).

## 2. TDD evidence

**RED** — test written first, `npx vitest run src/sim/experiments.test.ts`:

```
FAIL  src/sim/experiments.test.ts [ src/sim/experiments.test.ts ]
Error: Cannot find module './experiments' imported from .../server/src/sim/experiments.test.ts
 ❯ src/sim/experiments.test.ts:2:1
 Test Files  1 failed (1)
      Tests  no tests
```

**GREEN** — after writing `experiments.ts`, same command:

```
 Test Files  1 passed (1)
      Tests  6 passed (6)
```

**Full suite + typecheck** (`npm test && npx tsc --noEmit`):

```
 Test Files  28 passed (28)
      Tests  576 passed (576)
   Duration  8.85s
=== tsc ===
TSC OK
```

## 3. The real runs (Step 6)

### `npm run sim -- --rounds 2000`

```
# readability  rounds=2000 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:35,counter:20,conform:15,rocky:10

human     BEAT WORLD   ±95%    safe    loss    banked      max pot*
random         30.8%   2.0%   38.0%   31.2%      5103          729
counter         6.6%   1.1%   82.4%   11.1%       189           27
conform        11.0%   1.4%    6.6%   82.4%        15            3
wsls           31.9%   2.0%   54.6%   13.5%   1240029       177147
second         82.5%   1.7%   11.0%    6.6% 1.6412959550938187e+21 328256967394537100000
oracle         82.4%   1.7%   11.1%    6.6% 1.6412959550938187e+21 328256967394537100000
* max pot is measured AFTER each round's bank decision

world throw transitions (n=1999): same 6.6%  counter 82.4%  other 11.0%
(a blind world is 33/33/33; "counter" high means the crowd rotates the way everyone-counters predicts)
```

### `npm run sim -- --experiment blind-spread --rounds 360`

```
# blind-spread  rounds=360 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:35,counter:20,conform:15,rocky:10

20 blind players, bank at 9, 20 runs of 360 rounds
max ÷ median banked: mean 1.43  worst 1.64
per run: 1.47 1.47 1.31 1.38 1.29 1.48 1.40 1.35 1.55 1.29 1.44 1.33 1.50 1.50 1.64 1.50 1.61 1.39 1.31 1.31
```

### `npm run sim -- --experiment effective-n --rounds 2000`

```
# effective-n  rounds=2000 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:35,counter:20,conform:15,rocky:10

crowd   counter BEAT WORLD   ±95%
    5                13.2%   1.5%
    7                13.7%   1.5%
   10                 8.4%   1.2%
   15                10.7%   1.4%
   20                 9.7%   1.3%
   30                 5.1%   1.0%
   50                 3.6%   0.8%
  100                 1.4%   0.5%
(where the rate stops moving, the human's own throw has stopped moving the plurality)
```

### `npm run sim -- --rounds 500 --json | head -20`

```json
{
  "args": {
    "experiment": "readability",
    "rounds": 500,
    "crowd": 30,
    "mix": {
      "wsls": 35,
      "counter": 20,
      "conform": 15,
      "rocky": 10,
      "random": 20
    },
    "strength": 0.7,
    "seed": 1
  },
  "humans": [
    {
      "id": "random",
      "throws": 500,
      "wins": 144,
```

All four print without error.

## 4. Files changed

- `server/src/sim/experiments.ts` (new, 129 lines)
- `server/src/sim/experiments.test.ts` (new, 43 lines)
- `server/src/sim/cli.ts` (new, 41 lines)
- `server/package.json` (+1 script line)

Nothing else staged. `dist/` is git-ignored (`server/.gitignore:2`) and `git ls-files | grep -c '^dist/'` is 0.
The pre-existing dirty `.superpowers/sdd/.gitignore` was left untouched; no bare `git stash` used.

## 5. Self-review findings

Read the committed diff back. Four cosmetic notes and two substantive observations.

**Cosmetic / brief-verbatim, left as-is:**

1. `parseArgs` defaults `mix` to the *same object reference* as `DEFAULT_MIX` rather than a copy.
   No code path mutates `a.mix`, so it is currently harmless, but a future caller that mutated the
   returned args would corrupt the module-level default for the process.
2. Numeric flags use bare `Number(next())` with no NaN guard. `--rounds abc` yields `NaN`, which
   `runSimulation`'s loop treats as zero rounds and prints an all-`NaN%` table instead of an error.
3. `pct(h.safes / h.throws)` divides by zero when `throws === 0`, printing `NaN%`. Only reachable
   via #2 or `--rounds 0`.
4. `main()` runs at module load with no try/catch, so a bad flag exits with a raw stack trace
   rather than a one-line usage message. Acceptable for a dev-only tool.

All four are exactly as the brief specifies; I did not "improve" them, per the no-deviation rule.

**Substantive — sanity checks re-examined:**

5. **`oracle` was NOT strictly the highest row** at seed 1 (`second` 82.5% vs `oracle` 82.4%),
   contra the brief's Step 6 sanity note. I checked seeds 2/3/4 at 5000 rounds before concluding:
   they trade the top spot (82.0/82.1, 83.1/83.1, 82.0/82.0), always within 0.1% against a ±1.1%
   CI. This is a statistical tie, not a defect. The mechanism: the oracle predicts from
   `crowd.expected()` (the crowd's *expected* distribution) rather than the realized throws, so it
   is a probabilistic ceiling; and against this mix — 35% wsls + 20% counter, whose world rotates
   counter-wards 82.4% of the time — "counter the counter" (`second`) *is* the oracle's answer
   nearly every round, so the two converge by construction. The brief's sanity check should read
   "oracle is at the top, tied with second" for this mix.

6. **`random` sits consistently just below 33%**, not on it: 30.8% at seed 1, and 31.8 / 31.0 /
   30.3% at seeds 2–4 (5000 rounds, ±1.3%) — a small but repeatable shortfall outside the CI.
   The cause is visible in the same row: SAFE runs ~38% while LOSS runs ~31%, i.e. the blind
   player lands on the world throw more often than chance. `runSimulation` adds the modelled
   humans' own throws into `counts` *before* `deriveWorldThrow`, so with six humans against a
   crowd of 30 a blind human has a slightly raised chance of being inside the plurality it is then
   judged against — and matching is SAFE, which costs WINs. This is a property of Task 8's
   simulator (and arguably of the real game, where a player's throw likewise counts toward the
   world), not of this task's code. Flagging it so nobody later reads 30.8% as a broken RNG.

## 6. Concerns for the reviewer

- Neither observation above changes any code in this task; both are about `Simulation.ts` /
  the brief's expectations. No action taken, no files outside the four touched.
- `npm run sim` runs a full `tsc` first (~seconds) because `server/` has no TS runner installed.
  That is by design per the task context, but it means every sim invocation pays a build.
- The readability table prints `banked`/`max pot` in exponential notation once the ratio-banking
  oracle compounds past ~1e21 (visible above). Legible enough, but the column alignment breaks.

---

## Fix pass (review findings, 2026-09-04)

Commit: `c33d17a` — `fix(sim): refuse non-finite numeric flags and rounds < 1 -- a typo no longer prints a believable table`
Files touched: `server/src/sim/experiments.ts`, `server/src/sim/experiments.test.ts` only (`cli.ts` and `package.json` untouched).

### What changed

**Finding 1 — numeric flags had no finiteness guard (`experiments.ts:36-40`).** `Number(next())` was
unguarded for `--rounds`, `--crowd`, `--strength`, `--seed`. `--strength abc` produced `NaN`, which
reached `blend()` and made every crowd bot's distribution `NaN`, so `sample()` fell through to its
`return 'S'` guard — every bot threw scissors every round while the CLI printed a full, plausible
table. Added a `finite(flag, raw)` helper and routed all four `Number(...)` calls through it:

```ts
function finite(flag: string, raw: string): number {
    const n = Number(raw);
    if (raw.trim() === '' || !Number.isFinite(n)) throw new Error(`flag ${flag} needs a finite number, got "${raw}"`);
    return n;
}
```

It rejects the empty string too (`Number('')` is `0`, not `NaN`), and `Infinity`/`-Infinity` along
with `NaN`.

**Finding 2 — empty log left `banked`/`maxPot` `undefined` while typed `number` (`experiments.ts:70-71, 75`).**
`--rounds 0` printed `NaN%` and the literal string `undefined`. `parseArgs` now refuses it after the
flag loop, before `return a`:

```ts
    if (a.rounds < 1) throw new Error(`--rounds must be at least 1, got ${a.rounds}`);
```

No existing message string was changed.

### Covering tests

Two new cases in the `parseArgs` describe of `src/sim/experiments.test.ts`:

- `refuses a non-numeric or empty numeric flag` — `--strength abc`, `--rounds ''`, `--seed NaN`
- `refuses fewer than one round` — `--rounds 0`

All six pre-existing tests were left unchanged.

### Command and output

`npx vitest run src/sim/experiments.test.ts`

**RED** (tests written first, before the `experiments.ts` edit):

```
 FAIL  src/sim/experiments.test.ts > parseArgs > refuses a non-numeric or empty numeric flag
AssertionError: expected [Function] to throw an error
- Expected:  null
+ Received:  undefined
 ❯ src/sim/experiments.test.ts:22:56

 FAIL  src/sim/experiments.test.ts > parseArgs > refuses fewer than one round
AssertionError: expected [Function] to throw an error
- Expected:  null
+ Received:  undefined
 ❯ src/sim/experiments.test.ts:27:52

 Test Files  1 failed (1)
      Tests  2 failed | 6 passed (8)
```

**GREEN** (after the fix):

```
 Test Files  1 passed (1)
      Tests  8 passed (8)
```

Full gates from `server/`:

```
$ npm test
 Test Files  28 passed (28)
      Tests  578 passed (578)

$ npx tsc --noEmit
(clean, no output)
```
