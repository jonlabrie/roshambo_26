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

function finite(flag: string, raw: string): number {
    const n = Number(raw);
    if (raw.trim() === '' || !Number.isFinite(n)) throw new Error(`flag ${flag} needs a finite number, got "${raw}"`);
    return n;
}

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
            case '--rounds': a.rounds = finite(flag, next()); break;
            case '--crowd': a.crowd = finite(flag, next()); break;
            case '--mix': a.mix = parseMix(next()); break;
            case '--strength': a.strength = finite(flag, next()); break;
            case '--seed': a.seed = finite(flag, next()); break;
            case '--json': a.json = true; break;
            default: throw new Error(`unknown flag "${flag}"`);
        }
    }
    if (a.rounds < 1) throw new Error(`--rounds must be at least 1, got ${a.rounds}`);
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

// Each human is scored ALONE against the crowd — one runSimulation per spec, same seed. Running
// all six in one tally (as this did until 2026-09-04) let their votes shape the World Throw each
// was scored against: counter + oracle pushed the plurality forward, which is exactly the move
// `second` needs, and it scored 52% in company but 42% alone. The transitions line comes from
// the random-only run: the world a blind human plays in.
export function readability(a: CliArgs): ReadabilityOut {
    const runs = READABILITY_HUMANS.map(h => runSimulation({
        rounds: a.rounds, crowdSize: a.crowd, mix: a.mix, crowdStrength: a.strength, humans: [h], seed: a.seed,
    }));
    const { json: _json, ...args } = a;
    return {
        args,
        humans: READABILITY_HUMANS.map((h, i) => {
            const [rate] = winRates(runs[i], [h]);
            return { ...rate, banked: bankedTotals(runs[i])[0], maxPot: maxPots(runs[i])[0] };
        }),
        transitions: worldTransitions(runs[READABILITY_HUMANS.findIndex(h => h.policy === 'random')]),
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
