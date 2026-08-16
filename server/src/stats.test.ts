import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import { longestStreaks, biggestBanks, biggestRounds, throwsInWindow, forfeitsInWindow, playerRates, heatBoard, liveStreaks } from './stats';
import { settleRound } from './engine/Settlement';
import { ThrowEntry } from './engine/RoundEngine';

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

const at = (h: number) => new Date(Date.UTC(2026, 7, 16, h, 0, 0));
const W = { from: at(10), to: at(20) };

describe('records — longest streaks', () => {
    it('ranks by length, longest first', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await StreakEvent.create({ userId: a._id, length: 3, endedBy: 'LOSS', endedAt: at(12) });
        await StreakEvent.create({ userId: b._id, length: 9, endedBy: 'SAFE', endedAt: at(13) });
        const rows = await longestStreaks(W, 10);
        expect(rows.map(r => r.length)).toEqual([9, 3]);
    });

    it('counts streaks that ended in a LOSS, not just banked ones', async () => {
        const a = await User.create({ deviceId: 'a' });
        await StreakEvent.create({ userId: a._id, length: 7, endedBy: 'LOSS', endedAt: at(12) });
        const rows = await longestStreaks(W, 10);
        expect(rows).toHaveLength(1);
        expect(rows[0].endedBy).toBe('LOSS');
    });

    it('excludes streaks outside the window, and the boundary at `to` belongs to the next window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await StreakEvent.create({ userId: a._id, length: 5, endedBy: 'LOSS', endedAt: at(9) });
        await StreakEvent.create({ userId: a._id, length: 6, endedBy: 'LOSS', endedAt: at(20) });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'LOSS', endedAt: at(10) });
        const rows = await longestStreaks(W, 10);
        expect(rows.map(r => r.length)).toEqual([4]);
    });

    it('honours the limit', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const n of [1, 2, 3, 4, 5]) {
            await StreakEvent.create({ userId: a._id, length: n, endedBy: 'LOSS', endedAt: at(12) });
        }
        expect(await longestStreaks(W, 2)).toHaveLength(2);
    });
});

describe('records — biggest banks', () => {
    it('ranks by amount and carries the streak it was banked at', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 27, streakAtBank: 3, timestamp: at(12) });
        await BankEvent.create({ userId: a._id, amount: 243, streakAtBank: 5, timestamp: at(13) });
        const rows = await biggestBanks(W, 10);
        expect(rows.map(r => r.amount)).toEqual([243, 27]);
        expect(rows[0].streakAtBank).toBe(5);
    });

    it('excludes banks outside the window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 999, timestamp: at(9) });
        await BankEvent.create({ userId: a._id, amount: 9, timestamp: at(12) });
        expect((await biggestBanks(W, 10)).map(r => r.amount)).toEqual([9]);
    });

    it('excludes the bank at exactly `to`, which belongs to the next window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 999, timestamp: at(20) });
        await BankEvent.create({ userId: a._id, amount: 9, timestamp: at(12) });
        expect((await biggestBanks(W, 10)).map(r => r.amount)).toEqual([9]);
    });
});

describe('records — biggest rounds', () => {
    it('ranks WIN rows by pointsDelta, which on a WIN is the pot reached', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 9, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'r2', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 81, timestamp: at(13) });
        expect((await biggestRounds(W, 10)).map(r => r.pointsDelta)).toEqual([81, 9]);
    });

    it('NEVER returns a LOSS row, whose pointsDelta is a negative forfeit', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -81, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'r2', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 3, timestamp: at(13) });
        const rows = await biggestRounds(W, 10);
        expect(rows).toHaveLength(1);
        expect(rows[0].pointsDelta).toBe(3);
    });

    it('excludes the round at exactly `to`, which belongs to the next window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 999, timestamp: at(20) });
        await PlayerRound.create({ userId: a._id, roundId: 'r2', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 9, timestamp: at(12) });
        const rows = await biggestRounds(W, 10);
        expect(rows.map(r => r.pointsDelta)).toEqual([9]);
    });
});

describe('volume', () => {
    it('counts throws in the window, excluding the boundary at `to`', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const [h, id] of [[9, 'x'], [12, 'y'], [20, 'z']] as [number, string][]) {
            await PlayerRound.create({ userId: a._id, roundId: id, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(h) });
        }
        expect(await throwsInWindow(a._id, W)).toBe(1);
    });

    it('counts a guest\'s throws, which are keyed on the resolved user', async () => {
        const a = await User.create({ deviceId: 'guest' });
        await PlayerRound.create({ userId: a._id, roundId: 'g1', playerThrow: 'R', playerResult: 'SAFE', pointsDelta: 0, timestamp: at(12) });
        expect(await throwsInWindow(a._id, W)).toBe(1);
    });

    it('counts a throw written through settleRound for a guest identified only by deviceId', async () => {
        // Every other test in this file seeds PlayerRound rows directly with a userId, which
        // would pass even if Task 1's resolved-user fix had never landed. This one goes
        // through the real settlement path so a guest — no JWT, deviceId only — is resolved
        // to a User by resolveUser() inside settleRound, exactly as production does it.
        const guest = await User.create({ deviceId: 'settle-guest' });
        const entry: ThrowEntry = { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'settle-guest' };
        await settleRound({
            roundId: 'settle-r1',
            worldThrow: 'S',
            counts: { R: 1, P: 0, S: 0 },
            throws: new Map([['pwa:settle-guest', entry]]),
            timestamp: at(12),
        });
        expect(await throwsInWindow(guest._id, W)).toBe(1);
    });
});

describe('forfeits', () => {
    it('sums LOSS deltas as a POSITIVE forfeited total', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'l1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -27, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'l2', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -9, timestamp: at(13) });
        expect(await forfeitsInWindow(a._id, W)).toBe(36);
    });

    it('IGNORES WIN rows, whose delta is the new pot and not a gain', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'w1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 81, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'l1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -3, timestamp: at(13) });
        expect(await forfeitsInWindow(a._id, W)).toBe(3);
    });

    it('is zero when nothing was lost', async () => {
        const a = await User.create({ deviceId: 'a' });
        expect(await forfeitsInWindow(a._id, W)).toBe(0);
    });
});

describe('rates and qualification', () => {
    it('reports NOT qualified and null rates below the minimum', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        const rates = await playerRates(a._id, W, 10);
        expect(rates.qualified).toBe(false);
        expect(rates.pointsPerThrow).toBeNull();
        expect(rates.minThrows).toBe(10);
        expect(rates.throws).toBe(1);
    });

    it('computes points per THROW once qualified', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (let i = 0; i < 4; i++) {
            await PlayerRound.create({ userId: a._id, roundId: `r${i}`, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        }
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: at(13) });
        const rates = await playerRates(a._id, W, 4);
        expect(rates.qualified).toBe(true);
        expect(rates.pointsPerThrow).toBe(10);
    });

    it('computes capture rate as banked over banked-plus-forfeited', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (let i = 0; i < 2; i++) {
            await PlayerRound.create({ userId: a._id, roundId: `t${i}`, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        }
        await BankEvent.create({ userId: a._id, amount: 30, timestamp: at(13) });
        await PlayerRound.create({ userId: a._id, roundId: 'l1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -10, timestamp: at(14) });
        const rates = await playerRates(a._id, W, 1);
        expect(rates.captureRate).toBeCloseTo(0.75, 5);
    });

    it('leaves capture rate null when nothing was built', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'SAFE', pointsDelta: 0, timestamp: at(12) });
        const rates = await playerRates(a._id, W, 1);
        expect(rates.captureRate).toBeNull();
    });
});

describe('heat', () => {
    it('ranks by window earnings, ignoring career standing', async () => {
        const veteran = await User.create({ deviceId: 'veteran', lifetimeBanked: 90_000 });
        const newcomer = await User.create({ deviceId: 'newcomer', lifetimeBanked: 3 });
        await BankEvent.create({ userId: veteran._id, amount: 10, timestamp: at(12) });
        await BankEvent.create({ userId: newcomer._id, amount: 400, timestamp: at(12) });
        const rows = await heatBoard(W, 10);
        expect(rows.map(r => r.userId.toString())).toEqual([newcomer._id.toString(), veteran._id.toString()]);
    });

    it('restricted to a set of players, ranks only those players', async () => {
        const here = await User.create({ deviceId: 'here' });
        const elsewhere = await User.create({ deviceId: 'elsewhere' });
        await BankEvent.create({ userId: elsewhere._id, amount: 5000, timestamp: at(12) });
        await BankEvent.create({ userId: here._id, amount: 5, timestamp: at(12) });
        const rows = await heatBoard(W, 10, [here._id]);
        expect(rows).toHaveLength(1);
        expect(rows[0].userId.toString()).toBe(here._id.toString());
    });

    it('is empty when the restricted set has banked nothing in the window', async () => {
        const here = await User.create({ deviceId: 'here' });
        expect(await heatBoard(W, 10, [here._id])).toEqual([]);
    });

    it('an empty restriction means NOBODY, not everybody', async () => {
        const here = await User.create({ deviceId: 'here' });
        await BankEvent.create({ userId: here._id, amount: 5000, timestamp: at(12) });
        expect(await heatBoard(W, 10, [])).toEqual([]);
    });
});

describe('live streaks', () => {
    it('ranks players by their running streak, longest first', async () => {
        await User.create({ deviceId: 'a', currentStreak: 2 });
        await User.create({ deviceId: 'b', currentStreak: 9 });
        expect((await liveStreaks(10)).map(r => r.length)).toEqual([9, 2]);
    });

    it('omits players who are not on a streak', async () => {
        await User.create({ deviceId: 'a', currentStreak: 0 });
        await User.create({ deviceId: 'b', currentStreak: 4 });
        const rows = await liveStreaks(10);
        expect(rows).toHaveLength(1);
        expect(rows[0].length).toBe(4);
    });

    it('restricted to a set of players, ranks only those players', async () => {
        const here = await User.create({ deviceId: 'here', currentStreak: 3 });
        await User.create({ deviceId: 'elsewhere', currentStreak: 30 });
        const rows = await liveStreaks(10, [here._id]);
        expect(rows).toHaveLength(1);
        expect(rows[0].length).toBe(3);
    });

    it('an empty restriction means NOBODY, not everybody', async () => {
        await User.create({ deviceId: 'here', currentStreak: 30 });
        expect(await liveStreaks(10, [])).toEqual([]);
    });
});
