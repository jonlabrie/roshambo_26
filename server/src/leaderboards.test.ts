import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import { topByCareer, earningsInWindow, topEarnersInWindow } from './leaderboards';

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

describe('windowed earnings', () => {
    const at = (day: number) => new Date(Date.UTC(2026, 7, day, 12, 0, 0));

    it('sums only the banks inside the window', async () => {
        const user = await User.create({ deviceId: 'w1' });
        await BankEvent.create({ userId: user._id, amount: 10, timestamp: at(1) });
        await BankEvent.create({ userId: user._id, amount: 20, timestamp: at(5) });
        await BankEvent.create({ userId: user._id, amount: 40, timestamp: at(9) });

        expect(await earningsInWindow(user._id, at(3), at(7))).toBe(20);
    });

    it('is zero for a player who banked nothing in the window', async () => {
        const user = await User.create({ deviceId: 'w2' });
        await BankEvent.create({ userId: user._id, amount: 10, timestamp: at(1) });
        expect(await earningsInWindow(user._id, at(3), at(7))).toBe(0);
    });

    it('ranks earners within the window, not by career', async () => {
        const grinder = await User.create({ deviceId: 'grinder', lifetimeBanked: 10_000 });
        const hot = await User.create({ deviceId: 'hot', lifetimeBanked: 10 });
        // the career leader banked long ago; the hot player banked this week
        await BankEvent.create({ userId: grinder._id, amount: 9_000, timestamp: at(1) });
        await BankEvent.create({ userId: hot._id, amount: 300, timestamp: at(5) });

        const top = await topEarnersInWindow(at(3), at(7), 10);
        expect(top).toHaveLength(1);
        expect(top[0].userId.toString()).toBe(hot._id.toString());
        expect(top[0].earned).toBe(300);
    });

    it('adds up several banks by the same player', async () => {
        const user = await User.create({ deviceId: 'w3' });
        await BankEvent.create({ userId: user._id, amount: 3, timestamp: at(4) });
        await BankEvent.create({ userId: user._id, amount: 9, timestamp: at(5) });
        await BankEvent.create({ userId: user._id, amount: 27, timestamp: at(6) });

        const top = await topEarnersInWindow(at(3), at(7), 10);
        expect(top[0].earned).toBe(39);
    });
});
