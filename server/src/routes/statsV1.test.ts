import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import BankEvent from '../models/BankEvent';
import StreakEvent from '../models/StreakEvent';
import { createStatsV1 } from './statsV1';

const app = express();
app.use(express.json());
app.use('/api/v1/stats', createStatsV1());

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

describe('GET /api/v1/stats/records', () => {
    it('returns the three records boards for a window', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 7, endedBy: 'LOSS', endedAt: new Date() });
        await BankEvent.create({ userId: a._id, amount: 81, timestamp: new Date() });

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
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'SAFE', endedAt: new Date() });
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(res.body.longestStreaks[0].displayName).toBe('Ayaka');
    });

    it('never returns a deviceId', async () => {
        const a = await User.create({ deviceId: 'secret-device', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'SAFE', endedAt: new Date() });
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(JSON.stringify(res.body)).not.toContain('secret-device');
    });
});

describe('GET /api/v1/stats/heat', () => {
    it('ranks by window earnings and labels itself as form', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: new Date() });
        const res = await request(app).get('/api/v1/stats/heat?window=hour');
        expect(res.status).toBe(200);
        expect(res.body.kind).toBe('heat');
        expect(res.body.qualified).toBe(false);
        expect(res.body.leaders[0].earned).toBe(40);
    });

    it('scopes to an instance when one is given', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: new Date() });
        const res = await request(app).get('/api/v1/stats/heat?window=hour&instanceId=empty-room');
        expect(res.status).toBe(200);
        expect(res.body.leaders).toEqual([]);
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
