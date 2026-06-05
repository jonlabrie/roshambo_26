import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { settleRound } from '../engine/Settlement';
import { createApiV1 } from './apiV1';

const API_KEY = 'test-key';

function makeApp(engine: RoundEngine, store: ResultsStore) {
    const app = express();
    app.use(express.json());
    app.use('/api/v1', createApiV1(engine, store));
    return app;
}

function makeEngine() {
    let n = 0;
    return new RoundEngine({
        activeSeconds: 20, tallySeconds: 2, revealSeconds: 3,
        pickWorldThrow: () => 'S',
        makeRoundId: () => `round-${++n}`,
    });
}

describe('/api/v1', () => {
    beforeAll(async () => { process.env.API_KEY = API_KEY; await connectTestDb(); });
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    describe('auth', () => {
        it('rejects missing/wrong key with 401', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).get('/api/v1/state').expect(401);
            await request(app).get('/api/v1/state').set('X-API-Key', 'wrong').expect(401);
        });
    });

    describe('GET /state', () => {
        it('returns snapshot with timing and tape, cacheable 1s', async () => {
            const engine = makeEngine();
            const store = new ResultsStore();
            const res = await request(makeApp(engine, store))
                .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
            expect(res.headers['cache-control']).toBe('public, max-age=1');
            expect(res.body).toMatchObject({ roundId: 'round-1', phase: 'ACTIVE', roundCount: 0, tape: [] });
            expect(res.body.phaseEndsAt).toBeGreaterThan(res.body.serverTime);
            expect(res.body.phaseEndsAt - res.body.serverTime).toBe(20000);
        });
    });

    describe('GET /rounds/:id/result', () => {
        it('404 RESULT_NOT_READY before settlement, 200 after', async () => {
            const engine = makeEngine();
            const store = new ResultsStore();
            const app = makeApp(engine, store);
            await request(app).get('/api/v1/rounds/round-1/result').set('X-API-Key', API_KEY).expect(404);

            const { round, players } = await settleRound({
                roundId: 'round-1', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
                throws: new Map([['roblox:77', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '77', instanceId: 'job-1' }]]),
                timestamp: new Date(),
            });
            store.storeRound(round, players);

            const res = await request(app).get('/api/v1/rounds/round-1/result').set('X-API-Key', API_KEY).expect(200);
            expect(res.headers['cache-control']).toBe('public, max-age=10');
            expect(res.body).toMatchObject({ id: 'round-1', worldThrow: 'S', totalPlayers: 1 });
        });
    });
});
