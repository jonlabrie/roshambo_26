import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import { bankPot } from './wallet';

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

describe('bankPot', () => {
    it('moves the pot into totalPoints and resets stakingStreak', async () => {
        const u = await User.create({ deviceId: 'devA', totalPoints: 10, pointsAtStake: 27, stakingStreak: 3, currentStreak: 3 });
        const updated = await bankPot(u._id.toString(), 'pwa');
        expect(updated).toMatchObject({ totalPoints: 37, pointsAtStake: 0, stakingStreak: 0, currentStreak: 3 });
    });

    it('returns null when nothing is staked', async () => {
        const u = await User.create({ deviceId: 'devA', pointsAtStake: 0 });
        expect(await bankPot(u._id.toString(), 'pwa')).toBeNull();
    });

    // The three below moved here when resolveWin was withdrawn (the RISK/BANK gate: see the play
    // HUD spec, "The pot indicator"). They were always assertions about bankPot — banking is now
    // the only client-driven path that clears unresolvedWin, so keep them under it.
    it('clears unresolvedWin — banking is what acknowledges the win', async () => {
        const u = await User.create({ deviceId: 'devB', totalPoints: 0, pointsAtStake: 27,
            stakingStreak: 3, currentStreak: 3, unresolvedWin: true });
        const after = await bankPot(u._id.toString(), 'pwa');
        expect(after).toMatchObject({ unresolvedWin: false, pointsAtStake: 0, totalPoints: 27 });
    });

    it('records lifetimeBanked', async () => {
        const u = await User.create({ deviceId: 'devL', pointsAtStake: 27, unresolvedWin: true,
            lifetimeBanked: 100 });
        const after = await bankPot(u._id.toString(), 'pwa');
        expect(after!.lifetimeBanked).toBe(127);
    });

    it('is idempotent — a double-tap does not bank twice', async () => {
        const u = await User.create({ deviceId: 'devD', totalPoints: 0, pointsAtStake: 27,
            unresolvedWin: true });
        await bankPot(u._id.toString(), 'pwa');
        await bankPot(u._id.toString(), 'pwa');
        const after = await User.findById(u._id);
        expect(after!.totalPoints).toBe(27); // not 54
        expect(after!.unresolvedWin).toBe(false);
    });
});

describe('bankPot — event log', () => {
    it('writes one BankEvent recording the amount and the streak', async () => {
        const user = await User.create({
            deviceId: 'devBank1', pointsAtStake: 27, stakingStreak: 3, currentStreak: 3,
        });
        await bankPot(user._id.toString(), 'pwa');

        const events = await BankEvent.find({ userId: user._id });
        expect(events).toHaveLength(1);
        expect(events[0].amount).toBe(27);
        expect(events[0].streakAtBank).toBe(3);
        expect(events[0].platform).toBe('pwa');
    });

    it('writes NO event when there is nothing staked', async () => {
        const user = await User.create({ deviceId: 'devBank2', pointsAtStake: 0 });
        await bankPot(user._id.toString(), 'pwa');
        expect(await BankEvent.countDocuments({ userId: user._id })).toBe(0);
    });

    it('records the platform it was banked from', async () => {
        const user = await User.create({ deviceId: 'devBank3', pointsAtStake: 9, stakingStreak: 2 });
        await bankPot(user._id.toString(), 'roblox');
        const event = await BankEvent.findOne({ userId: user._id });
        expect(event?.platform).toBe('roblox');
    });

    it('the event amount matches the wallet increase', async () => {
        const user = await User.create({ deviceId: 'devBank4', pointsAtStake: 81, totalPoints: 100 });
        const updated = await bankPot(user._id.toString(), 'pwa');
        const event = await BankEvent.findOne({ userId: user._id });
        expect(updated?.totalPoints).toBe(181);
        expect(event?.amount).toBe(81);
    });
});
