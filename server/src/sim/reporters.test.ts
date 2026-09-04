import { describe, it, expect } from 'vitest';
import { winRates, worldTransitions, bankedTotals, maxPots, spreadRatio } from './reporters';
import { RoundRecord, HumanSpec } from './Simulation';

const humans: HumanSpec[] = [
    { id: 'a', policy: 'counter', strength: 1, bank: { kind: 'ride' } },
    { id: 'b', policy: 'random', strength: 1, bank: { kind: 'rung', at: 9 } },
];

// Five rounds, two humans. World: R P P S R.
const log: RoundRecord[] = [
    { world: 'R', counts: { R: 5, P: 1, S: 0 }, humans: [
        { throw: 'P', result: 'WIN', potAfter: 1, banked: 0 }, { throw: 'R', result: 'SAFE', potAfter: 0, banked: 0 }] },
    { world: 'P', counts: { R: 1, P: 5, S: 0 }, humans: [
        { throw: 'P', result: 'SAFE', potAfter: 1, banked: 0 }, { throw: 'S', result: 'WIN', potAfter: 1, banked: 0 }] },
    { world: 'P', counts: { R: 0, P: 4, S: 2 }, humans: [
        { throw: 'S', result: 'WIN', potAfter: 3, banked: 0 }, { throw: 'S', result: 'WIN', potAfter: 3, banked: 0 }] },
    { world: 'S', counts: { R: 2, P: 0, S: 4 }, humans: [
        { throw: 'S', result: 'SAFE', potAfter: 3, banked: 0 }, { throw: 'R', result: 'WIN', potAfter: 0, banked: 9 }] },
    { world: 'R', counts: { R: 4, P: 1, S: 1 }, humans: [
        { throw: 'R', result: 'SAFE', potAfter: 3, banked: 0 }, { throw: 'S', result: 'LOSS', potAfter: 0, banked: 0 }] },
];

describe('winRates', () => {
    it('counts each result and reports rate with a 95% interval', () => {
        const rows = winRates(log, humans);
        expect(rows[0]).toMatchObject({ id: 'a', throws: 5, wins: 2, safes: 3, losses: 0, rate: 0.4 });
        expect(rows[0].ci95).toBeCloseTo(1.96 * Math.sqrt(0.4 * 0.6 / 5), 6);
        expect(rows[1]).toMatchObject({ id: 'b', throws: 5, wins: 3, safes: 1, losses: 1, rate: 0.6 });
    });
});

describe('worldTransitions', () => {
    it('classifies each consecutive pair as same / counter (what beats the last) / other', () => {
        // pairs: R->P counter, P->P same, P->S counter, S->R counter
        expect(worldTransitions(log)).toEqual({ same: 0.25, counter: 0.75, other: 0, n: 4 });
    });
    it('is all zeros with fewer than two rounds', () => {
        expect(worldTransitions(log.slice(0, 1))).toEqual({ same: 0, counter: 0, other: 0, n: 0 });
    });
});

describe('bankedTotals / maxPots / spreadRatio', () => {
    it('sums banked points and tracks the largest pot per human', () => {
        expect(bankedTotals(log)).toEqual([0, 9]);
        expect(maxPots(log)).toEqual([3, 3]);
    });
    it('spreadRatio is max over median, null when the median is zero', () => {
        expect(spreadRatio([1, 2, 3, 4, 10])).toBe(10 / 3);
        expect(spreadRatio([1, 2, 3, 4])).toBe(4 / 2.5);
        expect(spreadRatio([0, 0, 0, 5])).toBeNull();
        expect(spreadRatio([])).toBeNull();
    });
});
