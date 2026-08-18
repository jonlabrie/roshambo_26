import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, vi } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import BankEvent from '../models/BankEvent';
import PlayerRound from '../models/PlayerRound';
import StreakEvent from '../models/StreakEvent';
import { reconcilePresence } from '../sessions';
import { createStatsV1 } from './statsV1';
import { mountRoutes } from './mount';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';

const app = express();
app.use(express.json());
app.use('/api/v1/stats', createStatsV1());

// FROZEN CLOCK. Every window here (calendarDayUTC / rollingWindow-hour) resolves its upper
// bound from `new Date()` at request time; a row seeded with a real `new Date()` a moment
// earlier is one millisecond collision away from landing outside a rolling window whose `to`
// IS `now` (`$lt: to` excludes a row whose timestamp equals it), and a calendar-day window
// racing real UTC midnight is a second, rarer version of the same class of bug. Freezing Date
// and seeding events at a FIXED offset inside the window removes both: every boundary becomes
// a literal instead of a moving target. Scoped to this whole file (not per-describe) because
// every describe block here queries a window against seeded rows the same way.
const FROZEN_NOW = new Date('2026-08-16T12:00:00Z');
// 30 minutes before FROZEN_NOW: inside the rolling HOUR window ([11:00, 12:00)) and inside
// the calendar DAY window (all of 2026-08-16 UTC) at once, so one constant serves every test.
const IN_WINDOW = new Date('2026-08-16T11:30:00Z');

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(FROZEN_NOW);
});
afterEach(() => vi.useRealTimers());
beforeEach(clearTestDb);

describe('GET /api/v1/stats/records', () => {
    it('returns the three records boards for a window', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 7, endedBy: 'LOSS', endedAt: IN_WINDOW });
        await BankEvent.create({ userId: a._id, amount: 81, timestamp: IN_WINDOW });

        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(res.status).toBe(200);
        expect(res.body.window).toBe('day');
        expect(res.body.longestStreaks[0].length).toBe(7);
        expect(res.body.biggestBanks[0].amount).toBe(81);
        expect(Array.isArray(res.body.biggestRounds)).toBe(true);
    });

    it('rejects an unknown window rather than silently choosing one', async () => {
        const res = await request(app).get('/api/v1/stats/records?window=fortnight');
        expect(res.status).toBe(400);
    });

    // WHICH "day"? /records?window=day is the UTC CALENDAR day; /heat?window=day is the last
    // rolling 24 hours. Both echo the same label, so a display rendering "Today" from both
    // would show two different periods under one heading unless the wire says which rule was
    // applied and where the bounds actually fell.
    it('echoes CALENDAR bounds and names the rule that produced them', async () => {
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(res.body.windowKind).toBe('calendar');
        expect(res.body.from).toBe('2026-08-16T00:00:00.000Z');
        expect(res.body.to).toBe('2026-08-17T00:00:00.000Z');
    });

    it('echoes the calendar WEEK bounds, which start Monday UTC', async () => {
        const res = await request(app).get('/api/v1/stats/records?window=week');
        expect(res.body.windowKind).toBe('calendar');
        // 2026-08-16 is a Sunday; its ISO week began Monday the 10th.
        expect(res.body.from).toBe('2026-08-10T00:00:00.000Z');
        expect(res.body.to).toBe('2026-08-17T00:00:00.000Z');
    });

    it('calls `all` ROLLING, because its upper bound moves with now rather than with a period', async () => {
        const res = await request(app).get('/api/v1/stats/records?window=all');
        expect(res.body.windowKind).toBe('rolling');
        expect(res.body.from).toBe('1970-01-01T00:00:00.000Z');
        expect(res.body.to).toBe('2026-08-17T12:00:00.000Z');
    });

    it('names the players, so a caller does not need a second round trip', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'SAFE', endedAt: IN_WINDOW });
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(res.body.longestStreaks[0].displayName).toBe('Ayaka');
    });

    it('never returns a deviceId', async () => {
        const a = await User.create({ deviceId: 'secret-device', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'SAFE', endedAt: IN_WINDOW });
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(JSON.stringify(res.body)).not.toContain('secret-device');
    });
});

describe('GET /api/v1/stats/heat', () => {
    it('ranks by window earnings and labels itself as form', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: IN_WINDOW });
        const res = await request(app).get('/api/v1/stats/heat?window=hour');
        expect(res.status).toBe(200);
        expect(res.body.kind).toBe('heat');
        expect(res.body.qualified).toBe(false);
        expect(res.body.leaders[0].earned).toBe(40);
    });

    it('scopes to an instance when one is given', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: IN_WINDOW });
        const res = await request(app).get('/api/v1/stats/heat?window=hour&instanceId=empty-room');
        expect(res.status).toBe(200);
        expect(res.body.leaders).toEqual([]);
    });

    // THE POPULATED CASE. The test above queries an EMPTY room and asserts `leaders: []` —
    // which is also exactly what a BROKEN composition returns. presentIn reconstructs
    // ObjectIds from strings and hands them to heatBoard's `$in`; if that shape were wrong, or
    // if it returned strings, every instance in the game would return an empty board and the
    // empty-room test would still pass. This one opens a real session, banks inside the
    // window, and asserts the player comes back with the right figure — and that a player who
    // is NOT in the instance does not, so it proves SCOPING rather than mere non-emptiness.
    it('returns the players actually present in the instance, with their window earnings', async () => {
        const here = await User.create({ deviceId: 'here', displayName: 'Ayaka' });
        const elsewhere = await User.create({ deviceId: 'elsewhere', displayName: 'Kenshin' });
        await reconcilePresence('inst-A', [here._id], IN_WINDOW);
        await reconcilePresence('inst-B', [elsewhere._id], IN_WINDOW);
        await BankEvent.create({ userId: here._id, amount: 40, timestamp: IN_WINDOW });
        // Deliberately the BIGGER bank: if scoping failed open, this player would top the board.
        await BankEvent.create({ userId: elsewhere._id, amount: 5_000, timestamp: IN_WINDOW });

        const res = await request(app).get('/api/v1/stats/heat?window=hour&instanceId=inst-A');
        expect(res.status).toBe(200);
        expect(res.body.scope).toBe('inst-A');
        expect(res.body.leaders).toEqual([{ displayName: 'Ayaka', earned: 40 }]);
    });

    it('drops a player from the instance board once they have left it', async () => {
        const gone = await User.create({ deviceId: 'gone', displayName: 'Ayaka' });
        await reconcilePresence('inst-A', [gone._id], IN_WINDOW);
        await BankEvent.create({ userId: gone._id, amount: 40, timestamp: IN_WINDOW });
        await reconcilePresence('inst-A', [], IN_WINDOW);

        const res = await request(app).get('/api/v1/stats/heat?window=hour&instanceId=inst-A');
        expect(res.body.leaders).toEqual([]);
    });

    it('rejects an unknown window rather than silently choosing one', async () => {
        const res = await request(app).get('/api/v1/stats/heat?window=fortnight');
        expect(res.status).toBe(400);
    });

    it('echoes ROLLING bounds, so "day" here cannot be mistaken for the calendar day', async () => {
        const res = await request(app).get('/api/v1/stats/heat?window=day');
        expect(res.body.windowKind).toBe('rolling');
        // The last 24 hours from the frozen now, NOT 2026-08-16T00:00Z onward.
        expect(res.body.from).toBe('2026-08-15T12:00:00.000Z');
        expect(res.body.to).toBe('2026-08-16T12:00:00.000Z');
    });

    it('echoes the rolling hour bounds', async () => {
        const res = await request(app).get('/api/v1/stats/heat?window=hour');
        expect(res.body.windowKind).toBe('rolling');
        expect(res.body.from).toBe('2026-08-16T11:00:00.000Z');
        expect(res.body.to).toBe('2026-08-16T12:00:00.000Z');
    });
});

describe('GET /api/v1/stats/player/:robloxUserId', () => {
    it('returns career figures and the weekly rates', async () => {
        await User.create({ robloxId: '4242', displayName: 'Ayaka', lifetimeBanked: 900, bestStreak: 6, currentStreak: 2 });
        const res = await request(app).get('/api/v1/stats/player/4242');
        expect(res.status).toBe(200);
        expect(res.body.displayName).toBe('Ayaka');
        expect(res.body.career.banked).toBe(900);
        expect(res.body.currentStreak).toBe(2);
    });

    it('reports the qualification threshold even when unqualified, so a display can show progress', async () => {
        await User.create({ robloxId: '4243', displayName: 'Kenshin' });
        const res = await request(app).get('/api/v1/stats/player/4243');
        expect(res.body.week.qualified).toBe(false);
        expect(res.body.week.minThrows).toBeGreaterThan(0);
        expect(res.body.week.throws).toBe(0);
        expect(res.body.week.pointsPerThrow).toBeNull();
    });

    it('404s for an unknown player rather than inventing an empty one', async () => {
        const res = await request(app).get('/api/v1/stats/player/nobody');
        expect(res.status).toBe(404);
    });

    it('never returns a deviceId', async () => {
        await User.create({ robloxId: '4244', deviceId: 'secret-device', displayName: 'Ayaka' });
        const res = await request(app).get('/api/v1/stats/player/4244');
        expect(JSON.stringify(res.body)).not.toContain('secret-device');
    });
});

// REGISTRATION ORDER, not a bare mount. Every test above mounts createStatsV1() alone on a
// bare express app, so nothing exercises the composed application the way index.ts actually
// builds it — which is exactly how a real bug shipped: createApiV1's router.use(requireApiKey)
// (apiV1.ts) runs unconditionally for every path under the '/api/v1' prefix, matched route or
// not, and Express matches middleware by REGISTRATION order rather than path specificity. If
// '/api/v1' were mounted before '/api/v1/stats', every stats request — being itself prefixed
// by '/api/v1' — would hit requireApiKey and get a keyed 401/503 before ever reaching this
// router.
//
// This test calls mountRoutes — THE SAME FUNCTION index.ts calls — rather than re-declaring
// the order here. Re-declaring proved only that the property was achievable; the coupling to
// production was a comment, and comments do not fail CI. index.ts itself cannot be imported
// (it connects to Mongo and listens at import time), which is why the order lives in
// routes/mount.ts where both callers can share one definition.
describe('mounted through mountRoutes, the function index.ts calls', () => {
    it('is reachable without an API key, because /api/v1/stats is mounted before the general /api/v1 router', async () => {
        const engine = new RoundEngine({
            openSeconds: 51, lockSeconds: 2, revealSeconds: 7,
            pickWorldThrow: () => 'R',
            makeRoundId: () => 'test-round',
        });
        const store = new ResultsStore();
        const mountedApp = express();
        mountedApp.use(express.json());
        mountRoutes(mountedApp, engine, store);

        // No X-API-Key header, and process.env.API_KEY is unset in this test process — the
        // exact PWA-only-mode condition CLAUDE.md describes, under which requireApiKey would
        // 503 every /api/v1/* request if the stats router did not win the race.
        const res = await request(mountedApp).get('/api/v1/stats/records?window=day');
        expect(res.status).toBe(200);
        expect(res.body.window).toBe('day');
    });
});

describe('GET /stats/board', () => {
    const TEST_MODE_WAS = process.env.TEST_MODE;
    afterEach(() => {
        if (TEST_MODE_WAS === undefined) delete process.env.TEST_MODE;
        else process.env.TEST_MODE = TEST_MODE_WAS;
    });

    const throwsFor = async (u: any, n: number, wins: number) => {
        for (let i = 0; i < n; i++) {
            await PlayerRound.create({
                userId: u._id, roundId: `r${i}`, playerThrow: 'R',
                playerResult: i < wins ? 'WIN' : 'LOSS',
                pointsDelta: 0, timestamp: IN_WINDOW,
            });
        }
    };

    it('names users, withholds the read while the world is a test cycle, and carries the floor', async () => {
        process.env.TEST_MODE = 'true';
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka', robloxId: '1' });
        await throwsFor(a, 10, 10);
        await BankEvent.create({ userId: a._id, amount: 30, streakAtBank: 3, timestamp: IN_WINDOW });
        const res = await request(app).get('/api/v1/stats/board?minThrows=10');
        expect(res.status).toBe(200);
        expect(res.body.worldIsCrowd).toBe(false);
        expect(res.body.rows[0].displayName).toBe('Ayaka');
        expect(res.body.rows[0].pointsPerThrow).toBeCloseTo(3.0);
        expect(res.body.rows[0].winRate).toBeNull();
        expect(res.body.minThrows).toBe(360);
    });

    it('sends the read once the world is the crowd', async () => {
        process.env.TEST_MODE = 'false';
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka', robloxId: '1' });
        await throwsFor(a, 10, 4);
        const res = await request(app).get('/api/v1/stats/board?minThrows=10');
        expect(res.body.worldIsCrowd).toBe(true);
        expect(res.body.rows[0].winRate).toBeCloseTo(0.4);
    });

    it('carries the room-wide bank-depth histogram', async () => {
        process.env.TEST_MODE = 'false';
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka', robloxId: '1' });
        await BankEvent.create({ userId: a._id, amount: 1, streakAtBank: 1, timestamp: IN_WINDOW });
        await BankEvent.create({ userId: a._id, amount: 9, streakAtBank: 3, timestamp: IN_WINDOW });
        const res = await request(app).get('/api/v1/stats/board');
        expect(res.body.depths).toEqual([1, 0, 1, 0, 0, 0, 0, 0]);
    });

    it('never emits a raw userId', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka', robloxId: '1' });
        await throwsFor(a, 10, 4);
        const res = await request(app).get('/api/v1/stats/board?minThrows=10');
        expect(JSON.stringify(res.body)).not.toContain(String(a._id));
    });
});
