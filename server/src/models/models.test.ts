import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from './User';
import PlayerRound from './PlayerRound';

describe('schema additions', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('User accepts robloxId, identityTier, country; tier defaults to guest', async () => {
        const u = await User.create({ robloxId: '12345', identityTier: 'roblox', country: 'US' });
        expect(u.robloxId).toBe('12345');
        expect(u.identityTier).toBe('roblox');
        const guest = await User.create({ deviceId: 'devA' });
        expect(guest.identityTier).toBe('guest');
    });

    it('robloxId is unique but sparse (many users without one)', async () => {
        await User.init(); // ensure indexes built before testing uniqueness
        await User.create({ deviceId: 'devA' });
        await User.create({ deviceId: 'devB' });
        await User.create({ robloxId: '777' });
        await expect(User.create({ robloxId: '777' })).rejects.toThrow();
    });

    it('PlayerRound accepts roblox rows without deviceId', async () => {
        const pr = await PlayerRound.create({
            robloxUserId: '12345', platform: 'roblox', roundId: 'r1',
            playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1,
        });
        expect(pr.platform).toBe('roblox');
        const legacy = await PlayerRound.create({
            deviceId: 'devA', roundId: 'r1', playerThrow: 'P', playerResult: 'LOSS', pointsDelta: 0,
        });
        expect(legacy.platform).toBe('pwa'); // default preserves existing rows' meaning
    });

    it('User.padPreferences defaults to an empty array and round-trips', async () => {
        const fresh = await User.create({ deviceId: 'devPrefs' });
        expect(fresh.padPreferences).toEqual([]);
        const set = await User.create({ deviceId: 'devPrefs2', padPreferences: ['T06', 'T02'] });
        expect(set.padPreferences).toEqual(['T06', 'T02']);
    });

    it('User.maxDeckSize defaults to null and round-trips a tier', async () => {
        const fresh = await User.create({ deviceId: 'devDeckA' });
        expect(fresh.maxDeckSize).toBeNull();
        const set = await User.create({ deviceId: 'devDeckB', maxDeckSize: 'M' });
        expect(set.maxDeckSize).toBe('M');
    });
});

describe('User defaults — play HUD fields', () => {
    it('defaults every new play-HUD field so existing docs need no migration', () => {
        const u = new User({ deviceId: 'd1' });
        expect(u.unresolvedWin).toBe(false);
        expect(u.escalationPrompts).toBe(true); // prompts are on until the player turns them off
        expect(u.confirmThrows).toBe(true); // so is confirming a throw with a pot riding on it
        expect(u.resultSplash).toBe(true); // so is the big centred result splash after a round
        expect(u.seenBeats).toEqual([]);
        for (const k of ['roundsPlayed', 'wins', 'safes', 'losses', 'lifetimeBanked', 'bestPot',
                         'throwsR', 'throwsP', 'throwsS'] as const) {
            expect(u[k]).toBe(0);
        }
    });

    it('unresolvedWin is independent of pointsAtStake', () => {
        // the whole reason it needs its own field: a pot rides on after a WIN and equally after a
        // SAFE, so pointsAtStake > 0 is true whether or not the last scored round was a win — only
        // this flag distinguishes them, and the pot indicator's pulse reads it
        const u = new User({ deviceId: 'd2', pointsAtStake: 27, unresolvedWin: false });
        expect(u.pointsAtStake).toBe(27);
        expect(u.unresolvedWin).toBe(false);
    });
});
