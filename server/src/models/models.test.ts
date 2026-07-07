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
});
