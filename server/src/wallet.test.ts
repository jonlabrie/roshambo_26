import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import { bankPot, resolveWin } from './wallet';

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

describe('resolveWin', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('RISK clears the gate and leaves the pot riding', async () => {
        const u = await User.create({ deviceId: 'devR', totalPoints: 0, pointsAtStake: 27,
            stakingStreak: 3, currentStreak: 3, unresolvedWin: true });
        const after = await resolveWin(u._id.toString(), 'risk');
        expect(after).toMatchObject({ unresolvedWin: false, pointsAtStake: 27, totalPoints: 0 });
    });

    it('BANK clears the gate and moves the pot into the wallet', async () => {
        const u = await User.create({ deviceId: 'devB', totalPoints: 0, pointsAtStake: 27,
            stakingStreak: 3, currentStreak: 3, unresolvedWin: true });
        const after = await resolveWin(u._id.toString(), 'bank');
        expect(after).toMatchObject({ unresolvedWin: false, pointsAtStake: 0, totalPoints: 27 });
    });

    it('BANK also records lifetimeBanked', async () => {
        const u = await User.create({ deviceId: 'devL', pointsAtStake: 27, unresolvedWin: true,
            lifetimeBanked: 100 });
        const after = await resolveWin(u._id.toString(), 'bank');
        expect(after!.lifetimeBanked).toBe(127);
    });

    it('BANK with nothing staked still clears the gate', async () => {
        // Should be unreachable (a WIN always leaves a pot >= 1), but if it ever happened the
        // player would be bound forever with no way to throw again. Never strand them.
        const u = await User.create({ deviceId: 'devZ', pointsAtStake: 0, unresolvedWin: true });
        const after = await resolveWin(u._id.toString(), 'bank');
        expect(after!.unresolvedWin).toBe(false);
    });

    it('is idempotent — a double-tap does not bank twice', async () => {
        const u = await User.create({ deviceId: 'devD', totalPoints: 0, pointsAtStake: 27,
            unresolvedWin: true });
        await resolveWin(u._id.toString(), 'bank');
        await resolveWin(u._id.toString(), 'bank');
        const after = await User.findById(u._id);
        expect(after!.totalPoints).toBe(27); // not 54
        expect(after!.unresolvedWin).toBe(false);
    });

    it('RISK when not bound is a no-op, not an error', async () => {
        const u = await User.create({ deviceId: 'devN', pointsAtStake: 9, unresolvedWin: false });
        await resolveWin(u._id.toString(), 'risk');
        const after = await User.findById(u._id);
        expect(after!.pointsAtStake).toBe(9);
    });
});
