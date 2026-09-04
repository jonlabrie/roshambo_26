### Task 10: The CLI and `npm run sim`

**Files:**
- Create: `server/src/sim/cli.ts`
- Create: `server/src/sim/experiments.ts`
- Test: `server/src/sim/experiments.test.ts`
- Modify: `server/package.json` (scripts)

**Interfaces:**
- Consumes: Tasks 8–9; Task 3's `parseMix`, `DEFAULT_MIX`, `DEFAULT_STRENGTH`, `formatMix`.
- Produces:
  - `interface CliArgs { experiment: 'readability' | 'blind-spread' | 'effective-n'; rounds: number; crowd: number; mix: Mix; strength: number; seed: number; json: boolean }`
  - `parseArgs(argv: string[]): CliArgs`
  - `readability(a: CliArgs)`, `blindSpread(a: CliArgs)`, `effectiveN(a: CliArgs)` — each returns a plain JSON-able object; `cli.ts` prints it as a table or JSON.

The experiments module is tested; `cli.ts` is a thin printer.

- [ ] **Step 1: Write the failing test**

```ts
// server/src/sim/experiments.test.ts
import { describe, it, expect } from 'vitest';
import { parseArgs, readability, blindSpread, effectiveN } from './experiments';
import { DEFAULT_MIX } from '../engine/SyntheticCrowd';

describe('parseArgs', () => {
    it('has sensible defaults', () => {
        expect(parseArgs([])).toEqual({
            experiment: 'readability', rounds: 20000, crowd: 30, mix: DEFAULT_MIX, strength: 0.7, seed: 1, json: false,
        });
    });
    it('reads every flag', () => {
        expect(parseArgs(['--experiment', 'blind-spread', '--rounds', '360', '--crowd', '10', '--mix', 'counter:1',
            '--strength', '0.9', '--seed', '5', '--json'])).toEqual({
            experiment: 'blind-spread', rounds: 360, crowd: 10, mix: { counter: 1 }, strength: 0.9, seed: 5, json: true,
        });
    });
    it('refuses an unknown experiment or flag', () => {
        expect(() => parseArgs(['--experiment', 'vibes'])).toThrow('unknown experiment "vibes"');
        expect(() => parseArgs(['--bogus', '1'])).toThrow('unknown flag "--bogus"');
    });
});

describe('experiments (small, deterministic)', () => {
    it('readability reports one row per modelled human plus transitions', () => {
        const out = readability(parseArgs(['--rounds', '200', '--crowd', '10']));
        expect(out.humans.map(h => h.id)).toEqual(['random', 'counter', 'conform', 'wsls', 'second', 'oracle']);
        expect(out.transitions.n).toBe(199);
        for (const h of out.humans) {
            expect(h.rate).toBeGreaterThanOrEqual(0);
            expect(h.rate).toBeLessThanOrEqual(1);
        }
    });
    it('blindSpread runs twenty blind players over the requested rounds across twenty seeds', () => {
        const out = blindSpread(parseArgs(['--rounds', '100', '--crowd', '10']));
        expect(out.runs).toBe(20);
        expect(out.players).toBe(20);
        expect(out.ratios.length).toBeLessThanOrEqual(20);
    });
    it('effectiveN reports the counter\'s win rate at each crowd size', () => {
        const out = effectiveN(parseArgs(['--rounds', '100']));
        expect(out.rows.map(r => r.crowd)).toEqual([5, 7, 10, 15, 20, 30, 50, 100]);
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/sim/experiments.test.ts`
Expected: FAIL — `Cannot find module './experiments'`.

- [ ] **Step 3: Write the experiments module**

```ts
// server/src/sim/experiments.ts
// The three named experiments from spec §7, as functions returning plain data. cli.ts prints.
import { Mix, parseMix, DEFAULT_MIX, DEFAULT_STRENGTH } from '../engine/SyntheticCrowd';
import { runSimulation, HumanSpec } from './Simulation';
import { winRates, worldTransitions, bankedTotals, maxPots, spreadRatio, WinRateRow, Transitions } from './reporters';

export interface CliArgs {
    experiment: 'readability' | 'blind-spread' | 'effective-n';
    rounds: number;
    crowd: number;
    mix: Mix;
    strength: number;
    seed: number;
    json: boolean;
}

const EXPERIMENTS = ['readability', 'blind-spread', 'effective-n'] as const;

export function parseArgs(argv: string[]): CliArgs {
    const a: CliArgs = {
        experiment: 'readability', rounds: 20000, crowd: 30, mix: DEFAULT_MIX, strength: DEFAULT_STRENGTH, seed: 1, json: false,
    };
    for (let i = 0; i < argv.length; i++) {
        const flag = argv[i];
        const next = () => {
            const v = argv[++i];
            if (v === undefined) throw new Error(`flag ${flag} needs a value`);
            return v;
        };
        switch (flag) {
            case '--experiment': {
                const e = next();
                if (!(EXPERIMENTS as readonly string[]).includes(e)) throw new Error(`unknown experiment "${e}" (known: ${EXPERIMENTS.join(', ')})`);
                a.experiment = e as CliArgs['experiment'];
                break;
            }
            case '--rounds': a.rounds = Number(next()); break;
            case '--crowd': a.crowd = Number(next()); break;
            case '--mix': a.mix = parseMix(next()); break;
            case '--strength': a.strength = Number(next()); break;
            case '--seed': a.seed = Number(next()); break;
            case '--json': a.json = true; break;
            default: throw new Error(`unknown flag "${flag}"`);
        }
    }
    return a;
}

// Q0/Q1/Q3/Q5: one modelled human per teachable rule, each following it exactly (strength 1),
// each banking by the partial-banking spec's ratio rule; plus the oracle ceiling.
const READABILITY_HUMANS: HumanSpec[] = [
    { id: 'random', policy: 'random', strength: 1, bank: { kind: 'ratio' } },
    { id: 'counter', policy: 'counter', strength: 1, bank: { kind: 'ratio' } },
    { id: 'conform', policy: 'conform', strength: 1, bank: { kind: 'ratio' } },
    { id: 'wsls', policy: 'wsls', strength: 1, bank: { kind: 'ratio' } },
    { id: 'second', policy: 'second', strength: 1, bank: { kind: 'ratio' } },
    { id: 'oracle', policy: 'oracle', strength: 1, bank: { kind: 'ratio' } },
];

export interface ReadabilityOut {
    args: Omit<CliArgs, 'json'>;
    humans: (WinRateRow & { banked: number; maxPot: number })[];
    transitions: Transitions;
}

export function readability(a: CliArgs): ReadabilityOut {
    const log = runSimulation({
        rounds: a.rounds, crowdSize: a.crowd, mix: a.mix, crowdStrength: a.strength, humans: READABILITY_HUMANS, seed: a.seed,
    });
    const rates = winRates(log, READABILITY_HUMANS);
    const banked = bankedTotals(log);
    const pots = maxPots(log);
    const { json: _json, ...args } = a;
    return {
        args,
        humans: rates.map((r, i) => ({ ...r, banked: banked[i], maxPot: pots[i] })),
        transitions: worldTransitions(log),
    };
}

// Q4: twenty identical blind players, banking at 9, over `rounds` (360 = the stats room's
// qualification floor), repeated over twenty seeds. Reports max ÷ median per run.
export interface BlindSpreadOut {
    args: Omit<CliArgs, 'json'>;
    players: number;
    runs: number;
    ratios: number[];
    meanRatio: number | null;
    maxRatio: number | null;
}

export function blindSpread(a: CliArgs): BlindSpreadOut {
    const players = 20, runs = 20;
    const humans: HumanSpec[] = Array.from({ length: players }, (_, i) => ({
        id: `blind-${i}`, policy: 'random', strength: 1, bank: { kind: 'rung', at: 9 },
    }));
    const ratios: number[] = [];
    for (let k = 0; k < runs; k++) {
        const log = runSimulation({
            rounds: a.rounds, crowdSize: a.crowd, mix: a.mix, crowdStrength: a.strength, humans, seed: a.seed + k,
        });
        const ratio = spreadRatio(bankedTotals(log));
        if (ratio !== null) ratios.push(ratio);
    }
    const { json: _json, ...args } = a;
    const meanRatio = ratios.length ? ratios.reduce((s, x) => s + x, 0) / ratios.length : null;
    const maxRatio = ratios.length ? Math.max(...ratios) : null;
    return { args, players, runs, ratios, meanRatio, maxRatio };
}

// Q2: one exact counter against crowds of increasing size. Where its win rate stops moving is
// where the human's own throw stops moving the plurality.
export interface EffectiveNOut {
    args: Omit<CliArgs, 'json' | 'crowd'>;
    rows: { crowd: number; rate: number; ci95: number }[];
}

export function effectiveN(a: CliArgs): EffectiveNOut {
    const sizes = [5, 7, 10, 15, 20, 30, 50, 100];
    const human: HumanSpec = { id: 'counter', policy: 'counter', strength: 1, bank: { kind: 'ride' } };
    const rows = sizes.map(crowd => {
        const log = runSimulation({
            rounds: a.rounds, crowdSize: crowd, mix: a.mix, crowdStrength: a.strength, humans: [human], seed: a.seed,
        });
        const [row] = winRates(log, [human]);
        return { crowd, rate: row.rate, ci95: row.ci95 };
    });
    const { json: _json, crowd: _crowd, ...args } = a;
    return { args, rows };
}
```

- [ ] **Step 4: Write the CLI printer**

```ts
// server/src/sim/cli.ts
// npm run sim -- [--experiment readability|blind-spread|effective-n] [--rounds N] [--crowd N]
//                [--mix id:w,...] [--strength p] [--seed N] [--json]
import { formatMix } from '../engine/SyntheticCrowd';
import { parseArgs, readability, blindSpread, effectiveN } from './experiments';

const pct = (x: number) => `${(100 * x).toFixed(1)}%`;

function main(argv: string[]): void {
    const a = parseArgs(argv);
    const out = a.experiment === 'readability' ? readability(a)
        : a.experiment === 'blind-spread' ? blindSpread(a)
        : effectiveN(a);

    if (a.json) {
        console.log(JSON.stringify(out, null, 2));
        return;
    }

    console.log(`# ${a.experiment}  rounds=${a.rounds} crowd=${a.crowd} strength=${a.strength} seed=${a.seed}`);
    console.log(`# mix ${formatMix(a.mix)}`);
    if ('transitions' in out) {
        console.log('\nhuman     BEAT WORLD   ±95%    safe    loss    banked      max pot*');
        for (const h of out.humans) {
            console.log(`${h.id.padEnd(9)} ${pct(h.rate).padStart(10)} ${pct(h.ci95).padStart(6)} ${pct(h.safes / h.throws).padStart(7)} ${pct(h.losses / h.throws).padStart(7)} ${String(h.banked).padStart(9)} ${String(h.maxPot).padStart(12)}`);
        }
        console.log('* max pot is measured AFTER each round\'s bank decision');
        const t = out.transitions;
        console.log(`\nworld throw transitions (n=${t.n}): same ${pct(t.same)}  counter ${pct(t.counter)}  other ${pct(t.other)}`);
        console.log('(a blind world is 33/33/33; "counter" high means the crowd rotates the way everyone-counters predicts)');
    } else if ('ratios' in out) {
        console.log(`\n${out.players} blind players, bank at 9, ${out.runs} runs of ${a.rounds} rounds`);
        console.log(`max ÷ median banked: mean ${out.meanRatio?.toFixed(2) ?? 'n/a'}  worst ${out.maxRatio?.toFixed(2) ?? 'n/a'}`);
        console.log(`per run: ${out.ratios.map(r => r.toFixed(2)).join(' ')}`);
    } else {
        console.log('\ncrowd   counter BEAT WORLD   ±95%');
        for (const r of out.rows) console.log(`${String(r.crowd).padStart(5)} ${pct(r.rate).padStart(20)} ${pct(r.ci95).padStart(6)}`);
        console.log('(where the rate stops moving, the human\'s own throw has stopped moving the plurality)');
    }
}

main(process.argv.slice(2));
```

- [ ] **Step 5: Add the script**

In `server/package.json` `scripts`, add after `"test:watch"`:

```json
    "sim": "tsc && node dist/sim/cli.js"
```

`tsc` already excludes tests and writes to `dist/`, which `server/.gitignore` ignores.

- [ ] **Step 6: Run the tests, then the real thing**

Run: `npx vitest run src/sim/experiments.test.ts && npm test`
Expected: PASS.

Run: `npm run sim -- --rounds 2000`
Expected: a readability table with six rows and the transitions line. Then:

```bash
npm run sim -- --experiment blind-spread --rounds 360
npm run sim -- --experiment effective-n --rounds 2000
npm run sim -- --rounds 500 --json | head -20
```

Expected: each prints without error. Sanity: the `random` row sits near 33%; `oracle` is the highest row.

- [ ] **Step 7: Commit**

```bash
git add src/sim/cli.ts src/sim/experiments.ts src/sim/experiments.test.ts package.json
git commit -m "feat(sim): npm run sim -- readability, blind-spread and effective-n experiments, table or --json

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

