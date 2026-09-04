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
