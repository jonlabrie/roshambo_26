import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import { topByCareer } from './leaderboards';

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

describe('topByCareer', () => {
    it('ranks by career earnings, NOT by the spendable wallet', async () => {
        // The spender earned more but bought a teahouse; they must still outrank the hoarder.
        await User.create({ deviceId: 'spender', lifetimeBanked: 900, totalPoints: 10 });
        await User.create({ deviceId: 'hoarder', lifetimeBanked: 100, totalPoints: 100 });

        const leaders = await topByCareer({}, 50);
        expect(leaders.map(u => u.deviceId)).toEqual(['spender', 'hoarder']);
    });

    it('honours the limit', async () => {
        for (let i = 0; i < 5; i++) {
            await User.create({ deviceId: `dev${i}`, lifetimeBanked: i * 10 });
        }
        expect(await topByCareer({}, 3)).toHaveLength(3);
    });

    it('filters, so a country board only contains that country', async () => {
        await User.create({ deviceId: 'us1', country: 'US', lifetimeBanked: 50 });
        await User.create({ deviceId: 'jp1', country: 'JP', lifetimeBanked: 500 });

        const leaders = await topByCareer({ country: 'US' }, 50);
        expect(leaders.map(u => u.deviceId)).toEqual(['us1']);
    });

    it('treats a player who never banked as zero rather than omitting them', async () => {
        await User.create({ deviceId: 'never' });
        const leaders = await topByCareer({}, 50);
        expect(leaders.map(u => u.deviceId)).toContain('never');
    });
});
