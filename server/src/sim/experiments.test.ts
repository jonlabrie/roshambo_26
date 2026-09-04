import { describe, it, expect } from 'vitest';
import { parseArgs, readability, blindSpread, effectiveN } from './experiments';
import { DEFAULT_MIX } from '../engine/SyntheticCrowd';
import { runSimulation, HumanSpec } from './Simulation';
import { winRates, worldTransitions } from './reporters';

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
    it('refuses a non-numeric or empty numeric flag', () => {
        expect(() => parseArgs(['--strength', 'abc'])).toThrow('flag --strength needs a finite number, got "abc"');
        expect(() => parseArgs(['--rounds', ''])).toThrow('flag --rounds needs a finite number, got ""');
        expect(() => parseArgs(['--seed', 'NaN'])).toThrow('flag --seed needs a finite number, got "NaN"');
    });
    it('refuses fewer than one round', () => {
        expect(() => parseArgs(['--rounds', '0'])).toThrow('--rounds must be at least 1, got 0');
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
    it('readability scores each modelled human ALONE against the crowd, not in a shared tally', () => {
        // 2026-09-04 defect: six humans in one runSimulation call all voted in the same tally, so
        // counter + oracle pushed the plurality forward and `second` scored 52% instead of 42%.
        // Each row must match the same human run by itself with the same seed.
        const a = parseArgs(['--rounds', '200', '--crowd', '10']);
        const out = readability(a);
        const alone = (id: string) => {
            const spec: HumanSpec = { id, policy: id as HumanSpec['policy'], strength: 1, bank: { kind: 'ratio' } };
            return runSimulation({
                rounds: a.rounds, crowdSize: a.crowd, mix: a.mix, crowdStrength: a.strength, humans: [spec], seed: a.seed,
            });
        };
        for (const row of out.humans) {
            const log = alone(row.id);
            const [expected] = winRates(log, [{ id: row.id, policy: row.id as HumanSpec['policy'], strength: 1, bank: { kind: 'ratio' } }]);
            expect({ id: row.id, wins: row.wins, safes: row.safes, losses: row.losses })
                .toEqual({ id: row.id, wins: expected.wins, safes: expected.safes, losses: expected.losses });
        }
        // The transitions line describes the world a blind human plays in: the random-only run.
        expect(out.transitions).toEqual(worldTransitions(alone('random')));
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
