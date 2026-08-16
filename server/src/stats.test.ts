import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import { longestStreaks, biggestBanks, biggestRounds } from './stats';

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
