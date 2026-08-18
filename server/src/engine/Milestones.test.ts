import { describe, it, expect } from 'vitest';
import { earnedFor, gradeFor, CATALOG } from './Milestones';

const NOTHING = { bestPot: 0, lifetimeBanked: 0, bestStreak: 0, weekThrows: 0, hasBanked: false, hasWon: false };

describe('milestones — powers generate the ladder without hand-authoring it', () => {
    it('awards every pot threshold at or below what was reached', () => {
        const ids = earnedFor({ ...NOTHING, bestPot: 27 });
        expect(ids).toContain('pot.9');
        expect(ids).toContain('pot.27');
        expect(ids).not.toContain('pot.81');
    });

    it('awards every career threshold at or below what was banked', () => {
        const ids = earnedFor({ ...NOTHING, lifetimeBanked: 1500 });
        expect(ids).toContain('career.100');
        expect(ids).toContain('career.1000');
        expect(ids).not.toContain('career.10000');
    });

    it('awards streak milestones from the BEST streak, which never decreases', () => {
        expect(earnedFor({ ...NOTHING, bestStreak: 5 })).toEqual(
            expect.arrayContaining(['run.3', 'run.5'])
        );
    });

    it('a brand new player has earned nothing at all', () => {
        expect(earnedFor(NOTHING)).toEqual([]);
    });

    it('every id in the catalog is unique — a duplicate would double-count a grade', () => {
        const ids = CATALOG.map(m => m.id);
        expect(new Set(ids).size).toBe(ids.length);
    });

    it('is never built on totalPoints — a wallet milestone would be revoked by shopping', () => {
        expect(JSON.stringify(CATALOG.map(m => m.id))).not.toContain('totalPoints');
    });
});

describe('the grade ladder', () => {
    it('starts at 10th kyu and reaches it on the first milestone', () => {
        expect(gradeFor(0).name).toBe('unranked');
        expect(gradeFor(1).name).toBe('10th kyu');
    });

    it('counts kyu DOWN then dan UP, fifteen grades, never past 5th dan', () => {
        const names = Array.from({ length: 400 }, (_, i) => gradeFor(i).name);
        expect(names).toContain('1st kyu');
        expect(names).toContain('1st dan');
        expect(names[names.length - 1]).toBe('5th dan');
        expect(new Set(names).size).toBe(16);
    });

    it('never goes backwards as milestones accumulate', () => {
        let last = -1;
        for (let n = 0; n < 400; n++) {
            const i = gradeFor(n).index;
            expect(i).toBeGreaterThanOrEqual(last);
            last = i;
        }
    });

    it('maps fifteen grades onto five plumage bands, because fifteen birds cannot be told apart', () => {
        const bands = new Set(Array.from({ length: 400 }, (_, i) => gradeFor(i).band));
        expect(bands.size).toBeLessThanOrEqual(6); // five bands plus 0 for unranked
        expect(Math.max(...bands)).toBe(5);
    });
});
