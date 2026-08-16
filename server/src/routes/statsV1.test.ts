import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, vi } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import BankEvent from '../models/BankEvent';
import StreakEvent from '../models/StreakEvent';
import { createStatsV1 } from './statsV1';
import { createApiV1 } from './apiV1';
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

    it('rejects an unknown window rather than silently choosing one', async () => {
        const res = await request(app).get('/api/v1/stats/heat?window=fortnight');
        expect(res.status).toBe(400);
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
// router. This test builds the app the way index.ts does (stats mounted first) and asserts a
// keyless 200, so that ordering regressing is a test failure, not a silent prod outage.
describe('mounted in the real app, in index.ts\'s registration order', () => {
    it('is reachable without an API key, because /api/v1/stats is mounted before the general /api/v1 router', async () => {
        const engine = new RoundEngine({
            openSeconds: 51, lockSeconds: 2, revealSeconds: 7,
            pickWorldThrow: () => 'R',
            makeRoundId: () => 'test-round',
        });
        const store = new ResultsStore();
        const mountedApp = express();
        mountedApp.use(express.json());
        // MUST MATCH index.ts EXACTLY: stats before the gated general router.
        mountedApp.use('/api/v1/stats', createStatsV1());
        mountedApp.use('/api/v1', createApiV1(engine, store));

        // No X-API-Key header, and process.env.API_KEY is unset in this test process — the
        // exact PWA-only-mode condition CLAUDE.md describes, under which requireApiKey would
        // 503 every /api/v1/* request if the stats router did not win the race.
        const res = await request(mountedApp).get('/api/v1/stats/records?window=day');
        expect(res.status).toBe(200);
        expect(res.body.window).toBe('day');
    });
});
