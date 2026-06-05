import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import Round from '../models/Round';
import PlayerRound from '../models/PlayerRound';
import { settleRound } from './Settlement';
import { ThrowEntry } from './RoundEngine';

function throwsMap(entries: [string, ThrowEntry][]) { return new Map(entries); }

describe('settleRound', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('persists the round, scores each participant, returns settled players', async () => {
        await User.create({ deviceId: 'devA', pointsAtStake: 9, currentStreak: 2, stakingStreak: 2, bestStreak: 2 });
        const { round, players } = await settleRound({
            roundId: 'r1',
            worldThrow: 'S', // R beats S -> devA (R) WINs; roblox 77 (S) SAFE; roblox 88 (P) LOSS
            counts: { R: 1, P: 1, S: 1 },
            throws: throwsMap([
                ['pwa:devA', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'devA' }],
                ['roblox:77', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '77', instanceId: 'job-1' }],
                ['roblox:88', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '88', instanceId: 'job-1' }],
            ]),
            timestamp: new Date(),
        });

        expect(round).toMatchObject({ id: 'r1', worldThrow: 'S', totalPlayers: 3, distribution: { R: 33, P: 33, S: 33 } });
        expect(await Round.countDocuments({ id: 'r1' })).toBe(1);
        expect(await PlayerRound.countDocuments({ roundId: 'r1' })).toBe(3);

        const win = players.find(p => p.key === 'pwa:devA')!;
        expect(win).toMatchObject({ result: 'WIN', delta: 27, pot: 27, streak: 3, platform: 'pwa' });

        const safe = players.find(p => p.key === 'roblox:77')!;
        expect(safe).toMatchObject({ result: 'SAFE', delta: 0, pot: 0, streak: 0, instanceId: 'job-1' });

        const loss = players.find(p => p.key === 'roblox:88')!;
        expect(loss).toMatchObject({ result: 'LOSS', delta: 0, pot: 0, streak: 0 });
    });

    it('updates bestStreak on new highs and persists user wallets', async () => {
        await settleRound({
            roundId: 'r2', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
            throws: throwsMap([['roblox:77', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '77' }]]),
            timestamp: new Date(),
        });
        const u = await User.findOne({ robloxId: '77' });
        expect(u).toMatchObject({ pointsAtStake: 1, currentStreak: 1, stakingStreak: 1, bestStreak: 1 });
    });

    it('uses 33/33/33 distribution when nobody played', async () => {
        const { round } = await settleRound({
            roundId: 'r3', worldThrow: 'R', counts: { R: 0, P: 0, S: 0 }, throws: new Map(), timestamp: new Date(),
        });
        expect(round.distribution).toEqual({ R: 33, P: 33, S: 33 });
    });
});
