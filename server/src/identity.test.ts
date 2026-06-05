import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import { resolveUser } from './identity';

describe('resolveUser', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('creates a guest for an unknown deviceId', async () => {
        const u = await resolveUser({ deviceId: 'devA' });
        expect(u?.deviceId).toBe('devA');
        expect(u?.identityTier).toBe('guest');
    });

    it('returns the same guest on repeat lookup', async () => {
        const first = await resolveUser({ deviceId: 'devA' });
        const second = await resolveUser({ deviceId: 'devA' });
        expect(second?._id.toString()).toBe(first?._id.toString());
    });

    it('prefers the authenticated user over deviceId', async () => {
        const auth = await User.create({ email: 'a@b.c', identityTier: 'email' });
        await User.create({ deviceId: 'devA' });
        const u = await resolveUser({ userId: auth._id.toString(), deviceId: 'devA' });
        expect(u?._id.toString()).toBe(auth._id.toString());
    });

    it('creates a roblox user with roblox tier for an unknown robloxUserId', async () => {
        const u = await resolveUser({ robloxUserId: '12345' });
        expect(u?.robloxId).toBe('12345');
        expect(u?.identityTier).toBe('roblox');
    });

    it('returns the same roblox user on repeat lookup', async () => {
        const first = await resolveUser({ robloxUserId: '12345' });
        const second = await resolveUser({ robloxUserId: '12345' });
        expect(second?._id.toString()).toBe(first?._id.toString());
        expect(await User.countDocuments({ robloxId: '12345' })).toBe(1);
    });
});
