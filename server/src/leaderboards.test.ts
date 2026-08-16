import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import { topByCareer, earningsInWindow } from './leaderboards';

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

describe('topByCareer', () => {
    it('ranks by career earnings, NOT by the spendable wallet', async () => {
        // The spender earned more but bought a teahouse; they must still outrank the hoarder.
        // Identified by displayName, not deviceId: the board deliberately does not carry a
        // deviceId on any transport, because it is a bearer credential (see leaderboards.ts).
        await User.create({ deviceId: 'd1', displayName: 'spender', lifetimeBanked: 900, totalPoints: 10 });
        await User.create({ deviceId: 'd2', displayName: 'hoarder', lifetimeBanked: 100, totalPoints: 100 });

        const leaders = await topByCareer({}, 50);
        expect(leaders.map(u => u.displayName)).toEqual(['spender', 'hoarder']);
    });

    it('never returns a deviceId — it is a bearer credential, not a label', async () => {
        await User.create({ deviceId: 'SECRET-DEVICE', displayName: 'Ayaka', lifetimeBanked: 10 });
        const leaders = await topByCareer({}, 50);
        expect(leaders).toHaveLength(1);
        expect(JSON.stringify(leaders)).not.toContain('SECRET-DEVICE');
        expect(leaders[0].deviceId).toBeUndefined();
    });

    it('honours the limit', async () => {
        for (let i = 0; i < 5; i++) {
            await User.create({ deviceId: `dev${i}`, lifetimeBanked: i * 10 });
        }
        expect(await topByCareer({}, 3)).toHaveLength(3);
    });

    it('filters, so a country board only contains that country', async () => {
        await User.create({ deviceId: 'd1', displayName: 'us1', country: 'US', lifetimeBanked: 50 });
        await User.create({ deviceId: 'd2', displayName: 'jp1', country: 'JP', lifetimeBanked: 500 });

        const leaders = await topByCareer({ country: 'US' }, 50);
        expect(leaders.map(u => u.displayName)).toEqual(['us1']);
    });

    it('treats a player who never banked as zero rather than omitting them', async () => {
        await User.create({ deviceId: 'd1', displayName: 'never' });
        const leaders = await topByCareer({}, 50);
        expect(leaders.map(u => u.displayName)).toContain('never');
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

    it('excludes a bank landing exactly on the window end, and includes one on the start', async () => {
        // [from, to). Adjacent windows tile; a bank on the shared boundary belongs to exactly
        // one of them, or every weekly total would overlap the next.
        const user = await User.create({ deviceId: 'w-edge' });
        await BankEvent.create({ userId: user._id, amount: 5, timestamp: at(3) });   // == from
        await BankEvent.create({ userId: user._id, amount: 100, timestamp: at(7) }); // == to

        expect(await earningsInWindow(user._id, at(3), at(7))).toBe(5);
    });

    it('is zero for a player who banked nothing in the window', async () => {
        const user = await User.create({ deviceId: 'w2' });
        await BankEvent.create({ userId: user._id, amount: 10, timestamp: at(1) });
        expect(await earningsInWindow(user._id, at(3), at(7))).toBe(0);
    });
});
