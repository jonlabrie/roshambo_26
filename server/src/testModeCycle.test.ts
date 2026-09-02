import { describe, it, expect } from 'vitest';
import { testModePhaseShift } from './testModeCycle';

const THROWS = ['R', 'P', 'S'] as const;
const pick = (roundCount: number, shift: number) => THROWS[(roundCount + shift) % 3];

describe('testModePhaseShift', () => {
    it('a fresh database starts the cycle at R', () => {
        expect(pick(0, testModePhaseShift(undefined, 0))).toBe('R');
    });

    it('continues from the last persisted face regardless of the boot round count', () => {
        // The defect: the phase depended on countDocuments, which drifts from the cycle.
        // Whatever count the engine seeds with, the next face is the successor of the last
        // face a player actually saw.
        for (const bootCount of [0, 1, 2, 3, 7, 141_592]) {
            expect(pick(bootCount, testModePhaseShift('R', bootCount))).toBe('P');
            expect(pick(bootCount, testModePhaseShift('P', bootCount))).toBe('S');
            expect(pick(bootCount, testModePhaseShift('S', bootCount))).toBe('R');
        }
    });

    it('an unrecognized persisted face restarts at R rather than throwing', () => {
        expect(pick(5, testModePhaseShift('X', 5))).toBe('R');
    });

    it('the cycle then advances normally from the seeded phase', () => {
        const shift = testModePhaseShift('P', 10);
        expect(pick(10, shift)).toBe('S');
        expect(pick(11, shift)).toBe('R');
        expect(pick(12, shift)).toBe('P');
    });
});
