import { describe, it, expect } from 'vitest';
import { applyBank, runSimulation, HumanSpec } from './Simulation';

describe('applyBank', () => {
    it('ride never banks', () => {
        expect(applyBank({ kind: 'ride' }, 27, 0)).toEqual({ pot: 27, banked: 0 });
    });
    it('rung banks the whole pot once it reaches the rung', () => {
        expect(applyBank({ kind: 'rung', at: 9 }, 3, 0)).toEqual({ pot: 3, banked: 0 });
        expect(applyBank({ kind: 'rung', at: 9 }, 9, 5)).toEqual({ pot: 0, banked: 14 });
    });
    it('ratio keeps the largest rung at or below f*·pot, f* = (bank÷pot + 1)/4 (partial-banking spec)', () => {
        // bank 0, pot 27: f* = 0.25 -> target 6.75 -> keep 3, bank 24
        expect(applyBank({ kind: 'ratio' }, 27, 0)).toEqual({ pot: 3, banked: 24 });
        // bank 27, pot 27: b = 1 -> f* = 0.5 -> target 13.5 -> keep 9, bank 18
        expect(applyBank({ kind: 'ratio' }, 27, 27)).toEqual({ pot: 9, banked: 45 });
        // bank 81, pot 27: b = 3 -> ride everything
        expect(applyBank({ kind: 'ratio' }, 27, 81)).toEqual({ pot: 27, banked: 81 });
        // pot 1, bank 0: f* = 0.25 -> target 0.25 -> keep 0, bank 1
        expect(applyBank({ kind: 'ratio' }, 1, 0)).toEqual({ pot: 0, banked: 1 });
        // empty pot: nothing to decide
        expect(applyBank({ kind: 'ratio' }, 0, 10)).toEqual({ pot: 0, banked: 10 });
    });
});

describe('runSimulation', () => {
    const counter: HumanSpec = { id: 'h', policy: 'counter', strength: 1, bank: { kind: 'ride' } };

    it('produces one record per round with one human record per human', () => {
        const log = runSimulation({ rounds: 5, crowdSize: 6, humans: [counter], seed: 1 });
        expect(log).toHaveLength(5);
        for (const r of log) {
            expect(['R', 'P', 'S']).toContain(r.world);
            expect(r.counts.R + r.counts.P + r.counts.S).toBe(7);
            expect(r.humans).toHaveLength(1);
        }
    });

    it('is deterministic for a seed', () => {
        const a = runSimulation({ rounds: 50, crowdSize: 20, humans: [counter], seed: 9 });
        const b = runSimulation({ rounds: 50, crowdSize: 20, humans: [counter], seed: 9 });
        expect(a).toEqual(b);
    });

    it('a strength-1 counter against an all-conform strength-1 crowd wins every round after the first', () => {
        // Conform bots repeat the last world; the plurality is therefore the last world; the
        // counter throws what beats it. The one human cannot outvote 10 bots, so world = last world.
        const log = runSimulation({
            rounds: 20, crowdSize: 10, mix: { conform: 1 }, crowdStrength: 1, humans: [counter], seed: 3,
        });
        expect(log.slice(1).every(r => r.humans[0].result === 'WIN')).toBe(true);
        // Round 0 has no history on either side, so its result is whatever the seed gives;
        // the ladder after it is exact either way.
        const round0Won = log[0].humans[0].result === 'WIN';
        expect(log[19].humans[0].potAfter).toBe(round0Won ? 3 ** 19 : 3 ** 18);
    });

    it('the pot follows the rules: a WIN triples, banking at the rung moves the whole pot out', () => {
        const banker: HumanSpec = { id: 'b', policy: 'counter', strength: 1, bank: { kind: 'rung', at: 9 } };
        const log = runSimulation({
            rounds: 12, crowdSize: 10, mix: { conform: 1 }, crowdStrength: 1, humans: [banker], seed: 3,
        });
        // Every round after the first is a WIN (see the test above). Walk the ladder from
        // whatever round 0 left: 0->1->3->9 (bank 9, pot 0) -> 1 -> 3 -> 9 (bank) ...
        let pot = log[0].humans[0].potAfter;
        for (const r of log.slice(1)) {
            const h = r.humans[0];
            expect(h.result).toBe('WIN');
            const grown = pot === 0 ? 1 : pot * 3;
            if (grown >= 9) {
                expect(h.banked).toBe(grown);
                expect(h.potAfter).toBe(0);
            } else {
                expect(h.banked).toBe(0);
                expect(h.potAfter).toBe(grown);
            }
            pot = h.potAfter;
        }
        expect(log.filter(r => r.humans[0].banked === 9).length).toBeGreaterThanOrEqual(3);
    });

    it('oracle throws what beats the crowd\'s expected plurality', () => {
        const oracle: HumanSpec = { id: 'o', policy: 'oracle', strength: 1, bank: { kind: 'ride' } };
        const log = runSimulation({
            rounds: 10, crowdSize: 10, mix: { counter: 1 }, crowdStrength: 1, humans: [oracle], seed: 5,
        });
        expect(log.slice(1).every(r => r.humans[0].result === 'WIN')).toBe(true);
    });
});
