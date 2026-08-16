import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import Round from './models/Round';
import { longestStreaks, biggestBanks, biggestRounds, throwsInWindow, forfeitsInWindow, playerRates, heatBoard, liveStreaks } from './stats';
import { openSession } from './sessions';
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

    it('reports a REAL earned figure for an UNQUALIFIED player, because Volume is never gated', async () => {
        // Points earned this window is the spec's headline Volume figure (§4.3) and Volume
        // explicitly requires no qualification. Only pointsPerThrow — the one a leaderboard
        // would rank on — is withheld below the threshold.
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: at(13) });

        const rates = await playerRates(a._id, W, 10);
        expect(rates.qualified).toBe(false);
        expect(rates.pointsPerThrow).toBeNull();
        expect(rates.earned).toBe(40);
    });

    it('counts only in-window banks toward earned', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 9, timestamp: at(9) });   // before `from`
        await BankEvent.create({ userId: a._id, amount: 5, timestamp: at(12) });
        await BankEvent.create({ userId: a._id, amount: 99, timestamp: at(20) }); // == `to`
        expect((await playerRates(a._id, W, 1)).earned).toBe(5);
    });
});

describe('participation', () => {
    // Presence is intervals, throws are rows, and the two are recorded by different paths, so
    // this ratio is the one figure here that can disagree with itself. See the comment on
    // PlayerRates.participationRate: it is deliberately NOT clamped.
    const seedRounds = async (hours: number[]) => {
        for (const h of hours) {
            await Round.create({ id: `round-${h}`, worldThrow: 'R', timestamp: at(h) });
        }
    };

    it('is throws over rounds-present, a fraction for a player who abstains', async () => {
        const a = await User.create({ deviceId: 'a' });
        await openSession({ userId: a._id, platform: 'roblox', instanceId: 'inst-A', startedAt: at(10), lastSeenAt: at(19) });
        await seedRounds([11, 12, 13, 14]);
        await PlayerRound.create({ userId: a._id, roundId: 'round-12', playerThrow: 'R', playerResult: 'SAFE', pointsDelta: 0, timestamp: at(12) });

        const rates = await playerRates(a._id, W, 1);
        expect(rates.roundsPresent).toBe(4);
        expect(rates.throws).toBe(1);
        expect(rates.participationRate).toBeCloseTo(0.25, 5);
    });

    it('is NULL, never Infinity or NaN, when the player was present for no rounds', async () => {
        // Throws with no session at all — exactly the divide-by-zero a lagging presence
        // reporter produces. A display can render "—"; it cannot render Infinity.
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'SAFE', pointsDelta: 0, timestamp: at(12) });

        const rates = await playerRates(a._id, W, 1);
        expect(rates.roundsPresent).toBe(0);
        expect(rates.throws).toBe(1);
        expect(rates.participationRate).toBeNull();
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

    // The four below moved here from leaderboards.test.ts when its duplicate windowed-earners
    // aggregation was deleted in favour of this one. They are the coverage that made that
    // aggregation trustworthy — the half-open boundary, the per-player sum, the limit and a
    // real sort contest — and they belong to whichever function still answers the question.
    it('leaves a bank landing exactly on the window end out of the board, and keeps one on the start', async () => {
        const early = await User.create({ deviceId: 'onFrom' });
        const late = await User.create({ deviceId: 'onTo' });
        await BankEvent.create({ userId: early._id, amount: 7, timestamp: at(10) });     // == from
        await BankEvent.create({ userId: late._id, amount: 5_000, timestamp: at(20) });  // == to
        const rows = await heatBoard(W, 10);
        expect(rows).toHaveLength(1);
        expect(rows[0].userId.toString()).toBe(early._id.toString());
    });

    it('adds up several banks by the same player', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 3, timestamp: at(11) });
        await BankEvent.create({ userId: a._id, amount: 9, timestamp: at(12) });
        await BankEvent.create({ userId: a._id, amount: 27, timestamp: at(13) });
        const rows = await heatBoard(W, 10);
        expect(rows[0].earned).toBe(39);
    });

    it('sorts by in-window earnings, inverting career order when the window demands it', async () => {
        // Six players, ALL banking INSIDE the window with distinct in-window totals, so this is
        // a genuine sort contest. A smaller pool is not enough: empirically Mongo's unsorted
        // $group output for 4 groups matched the fully-sorted order by chance in roughly 1 run
        // in 7-8 here, far above what a uniform-random permutation would give. Creation order
        // (50, 320, 80, 500, 130, 200) is neither ascending nor descending, so neither
        // 'creation order' nor 'value order' coincides with the target 500, 320, 200, 130, 80, 50.
        // lifetimeBanked runs OPPOSITE to in-window earnings: p1 has the deepest career total
        // and the worst window; p4 the shallowest career and the best — the exact inversion
        // Heat exists to surface.
        const p1 = await User.create({ deviceId: 'p1', lifetimeBanked: 50_000 });
        const p2 = await User.create({ deviceId: 'p2', lifetimeBanked: 5_000 });
        const p3 = await User.create({ deviceId: 'p3', lifetimeBanked: 900 });
        const p4 = await User.create({ deviceId: 'p4', lifetimeBanked: 10 });
        const p5 = await User.create({ deviceId: 'p5', lifetimeBanked: 300 });
        const p6 = await User.create({ deviceId: 'p6', lifetimeBanked: 50 });
        await BankEvent.create({ userId: p1._id, amount: 50, timestamp: at(11) });
        await BankEvent.create({ userId: p2._id, amount: 320, timestamp: at(12) });
        await BankEvent.create({ userId: p3._id, amount: 80, timestamp: at(13) });
        await BankEvent.create({ userId: p4._id, amount: 500, timestamp: at(11) });
        await BankEvent.create({ userId: p5._id, amount: 130, timestamp: at(13) });
        await BankEvent.create({ userId: p6._id, amount: 200, timestamp: at(12) });

        const rows = await heatBoard(W, 10);
        expect(rows).toHaveLength(6);
        expect(rows.map(r => r.earned)).toEqual([500, 320, 200, 130, 80, 50]);
        expect(rows[0].userId.toString()).toBe(p4._id.toString());
        expect(rows[5].userId.toString()).toBe(p1._id.toString());
    });

    it('honours the limit', async () => {
        for (let i = 0; i < 5; i++) {
            const earner = await User.create({ deviceId: `earner${i}` });
            await BankEvent.create({ userId: earner._id, amount: (i + 1) * 10, timestamp: at(12) });
        }
        expect(await heatBoard(W, 3)).toHaveLength(3);
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
