import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import { bankPot } from './wallet';

describe('bankPot', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('moves the pot into totalPoints and resets stakingStreak', async () => {
        const u = await User.create({ deviceId: 'devA', totalPoints: 10, pointsAtStake: 27, stakingStreak: 3, currentStreak: 3 });
        const updated = await bankPot(u._id.toString());
        expect(updated).toMatchObject({ totalPoints: 37, pointsAtStake: 0, stakingStreak: 0, currentStreak: 3 });
    });

    it('returns null when nothing is staked', async () => {
        const u = await User.create({ deviceId: 'devA', pointsAtStake: 0 });
        expect(await bankPot(u._id.toString())).toBeNull();
    });
});
