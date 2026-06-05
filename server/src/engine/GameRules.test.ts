import { describe, it, expect } from 'vitest';
import fixtures from '../../../shared-fixtures/game-rules.json';
import { calculateResult, nextPot, potDelta, nextStreak, Throw, RoundResult } from './GameRules';

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
