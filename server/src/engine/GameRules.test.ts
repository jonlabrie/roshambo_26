import { describe, it, expect } from 'vitest';
import fixtures from '../../../shared-fixtures/game-rules.json';
import { calculateResult, nextPot, potDelta, nextStreak, deriveWorldThrow, Throw, RoundResult } from './GameRules';

describe('GameRules (shared fixtures)', () => {
    it.each(fixtures.matchups)('$player vs world $world -> $result', ({ player, world, result }) => {
        expect(calculateResult(player as Throw, world as Throw)).toBe(result);
    });

    it.each(fixtures.potProgression)(
        'pot $currentPot + $result -> pot $nextPot, delta $delta',
        ({ currentPot, result, nextPot: expectedPot, delta }) => {
            expect(nextPot(currentPot, result as RoundResult)).toBe(expectedPot);
            expect(potDelta(currentPot, result as RoundResult)).toBe(delta);
        }
    );

    it.each(fixtures.streakRules)(
        'streak $currentStreak + $result -> $nextStreak',
        ({ result, currentStreak, nextStreak: expected }) => {
            expect(nextStreak(currentStreak, result as RoundResult)).toBe(expected);
        }
    );
});

describe('deriveWorldThrow (shared fixtures)', () => {
    const deterministic = fixtures.worldThrowDerivation.filter(r => 'expect' in r);
    const stochastic = fixtures.worldThrowDerivation.filter(r => 'expectOneOf' in r);

    it.each(deterministic)('$why -> $expect', row => {
        const r = row as { counts: Record<Throw, number>; minParticipants: number; expect: Throw };
        expect(deriveWorldThrow(r.counts, { minParticipants: r.minParticipants })).toBe(r.expect);
    });

    it.each(stochastic)('$why', row => {
        const r = row as { counts: Record<Throw, number>; minParticipants: number; expectOneOf: Throw[] };
        // sweep the whole unit interval: every outcome must be in the allowed set, and
        // every member of that set must be reachable — a tie-break that always returns
        // the first tied throw would pass a single-sample test.
        const seen = new Set<Throw>();
        for (let i = 0; i < 100; i++) {
            const got = deriveWorldThrow(r.counts, {
                minParticipants: r.minParticipants,
                random: () => i / 100,
            });
            expect(r.expectOneOf).toContain(got);
            seen.add(got);
        }
        expect([...seen].sort()).toEqual([...r.expectOneOf].sort());
    });

    it('never returns a throw nobody made, once above the threshold', () => {
        for (let i = 0; i < 100; i++) {
            const got = deriveWorldThrow({ R: 3, P: 3, S: 0 }, { minParticipants: 5, random: () => i / 100 });
            expect(got).not.toBe('S');
        }
    });

    it('defaults to a minimum of 5 participants', () => {
        expect(deriveWorldThrow({ R: 4, P: 0, S: 0 }, { random: () => 0.99 })).toBe('S');
        expect(deriveWorldThrow({ R: 5, P: 0, S: 0 }, { random: () => 0.99 })).toBe('R');
    });
});
