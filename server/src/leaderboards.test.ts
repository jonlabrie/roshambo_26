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

    it('excludes banks that fall outside the window', async () => {
        const grinder = await User.create({ deviceId: 'grinder', lifetimeBanked: 10_000 });
        const hot = await User.create({ deviceId: 'hot', lifetimeBanked: 10 });
        // the career leader banked long ago, outside the queried window; only the hot
        // player's in-window bank should show up here
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

    it('sorts by in-window earnings, inverting career order when the week demands it', async () => {
        // Six players, ALL banking INSIDE the queried window with distinct in-window totals,
        // so this is a genuine sort contest — unlike "excludes banks that fall outside the
        // window" above, where the career leader's only event fell outside the window and the
        // pipeline had only one document to return, so a broken $sort couldn't have been
        // caught at all. A smaller contestant pool isn't enough either: empirically, Mongo's
        // unsorted $group output for 4 groups matched the fully-sorted order by pure chance in
        // roughly 1 of every 7-8 runs in this environment (well above the naive 1-in-24 you'd
        // expect from a uniform-random permutation) — apparently there is a systematic bias in
        // how unsorted $group emits small result sets here, not true randomness. Six distinct
        // groups, created in an order that is neither ascending nor descending by their
        // in-window earnings (so neither "creation order" nor "value order" coincides with the
        // target), was verified empirically to fail 20/20 mutation trials.
        // lifetimeBanked deliberately runs OPPOSITE to in-window earnings below: p1 has the
        // deepest career total but banks worst this window; p4 has almost no career total but
        // banks best — the exact inversion the feature exists to surface.
        const p1 = await User.create({ deviceId: 'p1', lifetimeBanked: 50_000 }); // career leader, worst week
        const p2 = await User.create({ deviceId: 'p2', lifetimeBanked: 5_000 });
        const p3 = await User.create({ deviceId: 'p3', lifetimeBanked: 900 });
        const p4 = await User.create({ deviceId: 'p4', lifetimeBanked: 10 }); // week leader, worst career
        const p5 = await User.create({ deviceId: 'p5', lifetimeBanked: 300 });
        const p6 = await User.create({ deviceId: 'p6', lifetimeBanked: 50 });
        // insertion order (50, 320, 80, 500, 130, 200) is neither ascending nor descending —
        // the target order below is 500, 320, 200, 130, 80, 50
        await BankEvent.create({ userId: p1._id, amount: 50, timestamp: at(4) });
        await BankEvent.create({ userId: p2._id, amount: 320, timestamp: at(5) });
        await BankEvent.create({ userId: p3._id, amount: 80, timestamp: at(6) });
        await BankEvent.create({ userId: p4._id, amount: 500, timestamp: at(4) });
        await BankEvent.create({ userId: p5._id, amount: 130, timestamp: at(6) });
        await BankEvent.create({ userId: p6._id, amount: 200, timestamp: at(5) });

        const top = await topEarnersInWindow(at(3), at(7), 10);
        expect(top).toHaveLength(6);
        expect(top.map(t => t.earned)).toEqual([500, 320, 200, 130, 80, 50]);
        // ties the career inversion to specific players, not just the numbers
        expect(top[0].userId.toString()).toBe(p4._id.toString());
        expect(top[5].userId.toString()).toBe(p1._id.toString());
    });

    it('honours the limit', async () => {
        for (let i = 0; i < 5; i++) {
            const earner = await User.create({ deviceId: `earner${i}` });
            await BankEvent.create({ userId: earner._id, amount: (i + 1) * 10, timestamp: at(5) });
        }
        expect(await topEarnersInWindow(at(3), at(7), 3)).toHaveLength(3);
    });
});
