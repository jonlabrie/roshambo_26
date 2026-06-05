import { describe, it, expect } from 'vitest';
import { ResultsStore } from './ResultsStore';
import { GlobalResult, SettledPlayer } from './Settlement';

function round(id: string): GlobalResult {
    return { id, worldThrow: 'R', distribution: { R: 100, P: 0, S: 0 }, totalPlayers: 1, timestamp: new Date() };
}
function player(key: string, instanceId?: string): SettledPlayer {
    return { key, platform: 'roblox', robloxUserId: key, instanceId, result: 'WIN', delta: 1, totalPoints: 1, pot: 1, streak: 1, user: {} as any };
}

describe('ResultsStore', () => {
    it('stores and retrieves global results by roundId', () => {
        const s = new ResultsStore(3);
        s.storeRound(round('r1'), []);
        expect(s.getGlobal('r1')?.id).toBe('r1');
        expect(s.getGlobal('nope')).toBeUndefined();
    });

    it('groups per-instance results', () => {
        const s = new ResultsStore(3);
        s.storeRound(round('r1'), [player('77', 'job-1'), player('88', 'job-1'), player('99', 'job-2')]);
        expect(s.getInstance('r1', 'job-1')).toHaveLength(2);
        expect(s.getInstance('r1', 'job-2')).toHaveLength(1);
        expect(s.getInstance('r1', 'job-x')).toBeUndefined();
    });

    it('evicts beyond capacity, oldest first', () => {
        const s = new ResultsStore(2);
        s.storeRound(round('r1'), []); s.storeRound(round('r2'), []); s.storeRound(round('r3'), []);
        expect(s.getGlobal('r1')).toBeUndefined();
        expect(s.getGlobal('r3')?.id).toBe('r3');
    });

    it('tape returns newest-first capped history', () => {
        const s = new ResultsStore(20);
        for (let i = 1; i <= 12; i++) s.storeRound(round(`r${i}`), []);
        const tape = s.tape(10);
        expect(tape).toHaveLength(10);
        expect(tape[0].id).toBe('r12');
    });

    it('can be seeded with historical rounds (DB warm start)', () => {
        const s = new ResultsStore(20);
        s.seed([round('old2'), round('old1')]); // newest first, as loaded from DB
        expect(s.tape(10).map(r => r.id)).toEqual(['old2', 'old1']);
    });
});
