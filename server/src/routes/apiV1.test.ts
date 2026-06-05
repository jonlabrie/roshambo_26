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

    describe('POST /throws', () => {
        const body = (over: object = {}) => ({
            instanceId: 'job-1', roundId: 'round-1', seq: 1,
            throws: [{ robloxUserId: '77', throw: 'R' }, { robloxUserId: '88', throw: 'P' }],
            ...over,
        });

        it('202 accepts a valid batch into the engine', async () => {
            const engine = makeEngine();
            const res = await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body()).expect(202);
            expect(res.body).toEqual({ accepted: 2, rejected: [] });
        });

        it('409 ROUND_MISMATCH for a stale roundId, returning the current one', async () => {
            const engine = makeEngine();
            const res = await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body({ roundId: 'round-0' })).expect(409);
            expect(res.body).toEqual({ error: 'ROUND_MISMATCH', currentRoundId: 'round-1' });
        });

        it('409 PICKS_CLOSED outside ACTIVE', async () => {
            const engine = makeEngine();
            for (let i = 0; i < 20; i++) engine.tick(); // exhaust ACTIVE -> TALLY
            await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body()).expect(409);
        });

        it('reports per-player rejections (stale seq) without failing the batch', async () => {
            const engine = makeEngine();
            const app = makeApp(engine, new ResultsStore());
            await request(app).post('/api/v1/throws').set('X-API-Key', API_KEY)
                .send(body({ seq: 5, throws: [{ robloxUserId: '77', throw: 'P' }] })).expect(202);
            const res = await request(app).post('/api/v1/throws').set('X-API-Key', API_KEY)
                .send(body({ seq: 3 })).expect(202);
            expect(res.body.accepted).toBe(1); // 88 accepted, 77 stale
            expect(res.body.rejected).toEqual([{ robloxUserId: '77', reason: 'STALE_SEQ' }]);
        });

        it('400 on malformed body', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send({ nope: true }).expect(400);
        });
    });

    describe('GET /instances/:id/rounds/:rid/results', () => {
        it('returns per-player outcomes for the instance, no cache', async () => {
            const engine = makeEngine();
            const store = new ResultsStore();
            const { round, players } = await settleRound({
                roundId: 'round-1', worldThrow: 'S', counts: { R: 1, P: 1, S: 0 },
                throws: new Map([
                    ['roblox:77', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '77', instanceId: 'job-1' }],
                    ['roblox:88', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '88', instanceId: 'job-2' }],
                ]),
                timestamp: new Date(),
            });
            store.storeRound(round, players);
            const app = makeApp(engine, store);

            const res = await request(app)
                .get('/api/v1/instances/job-1/rounds/round-1/results').set('X-API-Key', API_KEY).expect(200);
            expect(res.headers['cache-control']).toBe('no-store');
            expect(res.body).toHaveLength(1);
            expect(res.body[0]).toMatchObject({ robloxUserId: '77', result: 'WIN', pot: 1, streak: 1 });
            expect(res.body[0].user).toBeUndefined(); // internal doc not exposed

            await request(app)
                .get('/api/v1/instances/job-x/rounds/round-1/results').set('X-API-Key', API_KEY).expect(404);
        });
    });

    describe('GET /players/:robloxUserId', () => {
        it('returns (and creates) the wallet, recording optional country', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/12345?country=US').set('X-API-Key', API_KEY).expect(200);
            expect(res.body).toMatchObject({
                robloxUserId: '12345', totalPoints: 0, pointsAtStake: 0,
                currentStreak: 0, stakingStreak: 0, bestStreak: 0, identityTier: 'roblox',
            });
            const u = await User.findOne({ robloxId: '12345' });
            expect(u?.country).toBe('US');
        });
    });

    describe('POST /bank', () => {
        it('banks a staked pot', async () => {
            await User.create({ robloxId: '77', identityTier: 'roblox', totalPoints: 5, pointsAtStake: 9, stakingStreak: 2 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/bank').set('X-API-Key', API_KEY).send({ robloxUserId: '77' }).expect(200);
            expect(res.body).toMatchObject({ totalPoints: 14, pointsAtStake: 0, stakingStreak: 0 });
        });

        it('409 when nothing staked', async () => {
            await User.create({ robloxId: '77', identityTier: 'roblox', pointsAtStake: 0 });
            await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/bank').set('X-API-Key', API_KEY).send({ robloxUserId: '77' }).expect(409);
        });
    });

    describe('GET /leaderboards', () => {
        it('world scope: top totalPoints, cacheable 30s', async () => {
            await User.create({ deviceId: 'devA', displayName: 'WebChamp', totalPoints: 100 });
            await User.create({ robloxId: '77', identityTier: 'roblox', displayName: 'BloxKid', totalPoints: 50 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/leaderboards?scope=world').set('X-API-Key', API_KEY).expect(200);
            expect(res.headers['cache-control']).toBe('public, max-age=30');
            expect(res.body.scope).toBe('world');
            expect(res.body.leaders[0]).toMatchObject({ displayName: 'WebChamp', totalPoints: 100, identityTier: 'guest' });
            expect(res.body.leaders[1]).toMatchObject({ displayName: 'BloxKid', robloxId: '77' });
        });

        it('country scope filters by country code', async () => {
            await User.create({ robloxId: '77', identityTier: 'roblox', country: 'US', totalPoints: 50 });
            await User.create({ robloxId: '88', identityTier: 'roblox', country: 'JP', totalPoints: 70 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/leaderboards?scope=country&country=US').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.leaders).toHaveLength(1);
            expect(res.body.leaders[0].robloxId).toBe('77');
        });

        it('400 on bad scope', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/leaderboards?scope=galaxy').set('X-API-Key', API_KEY).expect(400);
        });
    });
});
