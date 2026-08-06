import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { settleRound } from '../engine/Settlement';
import { createApiV1, buildProfilePayload } from './apiV1';

const API_KEY = 'test-key';

function makeApp(engine: RoundEngine, store: ResultsStore) {
    const app = express();
    app.use(express.json());
    app.use('/api/v1', createApiV1(engine, store));
    return app;
}

function makeEngine(overrides: Partial<ConstructorParameters<typeof RoundEngine>[0]> = {}) {
    let n = 0;
    return new RoundEngine({
        openSeconds: 20, lockSeconds: 2, revealSeconds: 3,
        pickWorldThrow: () => 'S',
        makeRoundId: () => `round-${++n}`,
        ...overrides,
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
        it('returns snapshot with timing and tape, no-store (clock-sync safety)', async () => {
            const engine = makeEngine();
            const store = new ResultsStore();
            const res = await request(makeApp(engine, store))
                .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
            expect(res.headers['cache-control']).toBe('no-store');
            expect(res.body).toMatchObject({ roundId: 'round-1', phase: 'OPEN', roundCount: 0, tape: [] });
            expect(res.body.phaseEndsAt).toBeGreaterThan(res.body.serverTime);
            expect(res.body.phaseEndsAt - res.body.serverTime).toBe(20000);
        });

        it('states its phase durations (round-metronome schedule source)', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.durations).toEqual({ openMs: 20000, lockMs: 2000, revealMs: 3000 });
        });

        it('names the durations openMs/lockMs/revealMs', async () => {
            const engine = makeEngine({ openSeconds: 51, lockSeconds: 2, revealSeconds: 7 });
            const res = await request(makeApp(engine, new ResultsStore()))
                .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.durations).toEqual({ openMs: 51000, lockMs: 2000, revealMs: 7000 });
            expect(res.body.phase).toBe('OPEN');
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

        it('202 accepts a batch during LOCK — game servers are still flushing', async () => {
            const engine = makeEngine({ openSeconds: 1, lockSeconds: 5 });
            engine.tick(); // OPEN (1s) expires -> LOCK
            expect(engine.snapshot().phase).toBe('LOCK');
            const res = await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body()).expect(202);
            expect(res.body).toEqual({ accepted: 2, rejected: [] });
        });

        it('409 PICKS_CLOSED during REVEAL', async () => {
            const engine = makeEngine({ openSeconds: 1, lockSeconds: 1, revealSeconds: 5 });
            engine.tick(); // -> LOCK
            engine.tick(); // -> REVEAL
            expect(engine.snapshot().phase).toBe('REVEAL');
            const res = await request(makeApp(engine, new ResultsStore()))
                .post('/api/v1/throws').set('X-API-Key', API_KEY).send(body()).expect(409);
            expect(res.body).toEqual({ error: 'PICKS_CLOSED' });
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

        it('carries the ledger: gate, preference and counters', async () => {
            await User.create({
                robloxId: '55501', identityTier: 'roblox', totalPoints: 1240, pointsAtStake: 27,
                currentStreak: 3, stakingStreak: 3, bestStreak: 6,
                unresolvedWin: true, escalationPrompts: false, resultSplash: false, seenBeats: ['drum'],
                roundsPlayed: 386, wins: 131, safes: 92, losses: 163,
                lifetimeBanked: 1240, bestPot: 243, throwsR: 181, throwsP: 120, throwsS: 85,
            });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/55501').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.unresolvedWin).toBe(true);
            expect(res.body.escalationPrompts).toBe(false);
            expect(res.body.resultSplash).toBe(false);
            expect(res.body).not.toHaveProperty('confirmThrows'); // retired: no longer shipped
            expect(res.body.seenBeats).toEqual(['drum']);
            expect(res.body.counters).toEqual({
                roundsPlayed: 386, wins: 131, safes: 92, losses: 163,
                lifetimeBanked: 1240, bestPot: 243, throwsR: 181, throwsP: 120, throwsS: 85,
            });
            // pre-existing fields must still be present alongside the new ones
            expect(res.body).toMatchObject({ robloxUserId: '55501', identityTier: 'roblox' });
        });
    });

    describe('buildProfilePayload', () => {
        it('carries the gate, the preference and every counter', () => {
            const p = buildProfilePayload({
                totalPoints: 1240, pointsAtStake: 27, currentStreak: 3, stakingStreak: 3, bestStreak: 6,
                unresolvedWin: true, escalationPrompts: false, resultSplash: false, seenBeats: ['drum'],
                roundsPlayed: 386, wins: 131, safes: 92, losses: 163,
                lifetimeBanked: 1240, bestPot: 243, throwsR: 181, throwsP: 120, throwsS: 85,
            } as never);
            expect(p.unresolvedWin).toBe(true);
            expect(p.escalationPrompts).toBe(false);
            expect(p.resultSplash).toBe(false);
            expect(p.seenBeats).toEqual(['drum']);
            expect(p.counters.roundsPlayed).toBe(386);
            expect(p.counters.throwsS).toBe(85);
        });

        it('tolerates a document written before these fields existed', () => {
            // no migration was run, so old docs simply lack the keys
            const p = buildProfilePayload({ totalPoints: 5, pointsAtStake: 0, currentStreak: 0,
                stakingStreak: 0, bestStreak: 0 } as never);
            expect(p.unresolvedWin).toBe(false);
            expect(p.escalationPrompts).toBe(true);
            expect(p.resultSplash).toBe(true);
            expect(p).not.toHaveProperty('confirmThrows'); // retired: no longer shipped
            expect(p.seenBeats).toEqual([]);
            expect(p.counters.roundsPlayed).toBe(0);
        });
    });

    describe('PUT /players/:robloxUserId/preferences-hud', () => {
        it('sets escalationPrompts', async () => {
            await User.create({ robloxId: 'hud-1', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/hud-1/preferences-hud')
                .set('X-API-Key', API_KEY).send({ escalationPrompts: false }).expect(200);
            expect(res.body).toEqual({ escalationPrompts: false, resultSplash: true, seenBeats: [] });
            const u = await User.findOne({ robloxId: 'hud-1' });
            expect(u?.escalationPrompts).toBe(false);
        });

        it('sets resultSplash independently of escalationPrompts', async () => {
            await User.create({ robloxId: 'hud-5', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/hud-5/preferences-hud')
                .set('X-API-Key', API_KEY).send({ resultSplash: false }).expect(200);
            expect(res.body).toEqual({ escalationPrompts: true, resultSplash: false, seenBeats: [] });
            const u = await User.findOne({ robloxId: 'hud-5' });
            expect(u?.resultSplash).toBe(false);
            // the other preference is untouched — one remote carries both, so a write of one must
            // never be a silent write of the other
            expect(u?.escalationPrompts).toBe(true);
        });

        it('adds a seenBeat without duplicating it, and never removes one', async () => {
            await User.create({ robloxId: 'hud-2', identityTier: 'roblox', seenBeats: ['drum'] });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/hud-2/preferences-hud')
                .set('X-API-Key', API_KEY).send({ seenBeat: 'drum' }).expect(200);
            expect(res.body.seenBeats).toEqual(['drum']);

            const res2 = await request(app)
                .put('/api/v1/players/hud-2/preferences-hud')
                .set('X-API-Key', API_KEY).send({ seenBeat: 'gong' }).expect(200);
            expect(res2.body.seenBeats.sort()).toEqual(['drum', 'gong']);
        });

        it('400 when the body has neither field', async () => {
            await User.create({ robloxId: 'hud-3', identityTier: 'roblox' });
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/hud-3/preferences-hud')
                .set('X-API-Key', API_KEY).send({}).expect(400);
        });

        it('401 without the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/hud-4/preferences-hud').send({ escalationPrompts: true }).expect(401);
        });
    });

    describe('PUT /players/:robloxUserId/preferences-hud — confirmThrows is retired', () => {
        it('ignores a confirmThrows key rather than persisting it', async () => {
            await User.create({ robloxId: 'hud-6', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/hud-6/preferences-hud')
                .set('X-API-Key', API_KEY).send({ confirmThrows: false, escalationPrompts: false }).expect(200);
            expect(res.body).not.toHaveProperty('confirmThrows');
            expect(res.body.escalationPrompts).toBe(false);
            const u = await User.findOne({ robloxId: 'hud-6' });
            expect(u?.confirmThrows).toBe(true); // schema default; the write of `false` was ignored
        });

        it('does not ship confirmThrows in the profile payload', async () => {
            await User.create({ robloxId: 'hud-7', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/hud-7').set('X-API-Key', API_KEY).expect(200);
            expect(res.body).not.toHaveProperty('confirmThrows');
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

        it('400 when scope=country but country param is missing', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/leaderboards?scope=country').set('X-API-Key', API_KEY).expect(400);
            expect(res.body).toEqual({ error: 'BAD_REQUEST' });
        });
    });

    describe('auth misconfig', () => {
        it('503 API_NOT_CONFIGURED when API_KEY env is unset', async () => {
            const saved = process.env.API_KEY;
            try {
                delete process.env.API_KEY;
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .get('/api/v1/state').set('X-API-Key', API_KEY).expect(503);
                expect(res.body).toEqual({ error: 'API_NOT_CONFIGURED' });
            } finally {
                process.env.API_KEY = saved;
            }
        });
    });

    describe('teahouses persistence', () => {
        it('GET returns {} for a wanderer, no-store', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/roblox-1/teahouses').set('X-API-Key', API_KEY).expect(200);
            expect(res.body).toEqual({ teahouses: {}, padPreferences: [] });
            expect(res.headers['cache-control']).toBe('no-store');
        });

        it('PUT then GET round-trips a loadout', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const loadout = { baseStyle: 'teahouse-1story', colorScheme: 'scheme.vermilion' };
            await request(app).put('/api/v1/players/roblox-1/teahouses/M')
                .set('X-API-Key', API_KEY).send({ loadout }).expect(200);
            const res = await request(app).get('/api/v1/players/roblox-1/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.teahouses.M).toEqual(loadout);
        });

        it('stores multiple sizes and overwrites a size', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const put = (sc: string, cs: string) => request(app)
                .put(`/api/v1/players/roblox-1/teahouses/${sc}`).set('X-API-Key', API_KEY)
                .send({ loadout: { baseStyle: 'teahouse-1story', colorScheme: cs } }).expect(200);
            await put('S', 'scheme.ink'); await put('L', 'scheme.vermilion'); await put('S', 'scheme.dormant');
            const res = await request(app).get('/api/v1/players/roblox-1/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.teahouses.S.colorScheme).toBe('scheme.dormant');
            expect(res.body.teahouses.L.colorScheme).toBe('scheme.vermilion');
        });

        it('rejects invalid loadouts with 400', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const put = (body: unknown) => request(app)
                .put('/api/v1/players/roblox-1/teahouses/M').set('X-API-Key', API_KEY).send(body as object);
            await put({ loadout: 'nope' }).expect(400);
            await put({ loadout: { colorScheme: 'x' } }).expect(400);
            await put({ loadout: { baseStyle: 't', bogus: 1 } }).expect(400);
        });

        it('requires the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/roblox-1/teahouses').expect(401);
        });
    });

    describe('preferences persistence', () => {
        it('PUT then GET teahouses returns padPreferences', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: ['T06', 'T02'] }).expect(200);
            const res = await request(app).get('/api/v1/players/roblox-1/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.padPreferences).toEqual(['T06', 'T02']);
        });

        it('PUT echoes the stored preferences', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: ['T04'] }).expect(200);
            expect(res.body).toEqual({ padPreferences: ['T04'] });
        });

        it('400 on a non-array / oversize / non-string body', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: 'T06' }).expect(400);
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: [42] }).expect(400);
            await request(app).put('/api/v1/players/roblox-1/preferences')
                .set('X-API-Key', API_KEY)
                .send({ padPreferences: Array.from({ length: 33 }, (_, i) => `T${i}`) }).expect(400);
        });

        it('401 without the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/roblox-1/preferences').send({ padPreferences: [] }).expect(401);
        });
    });

    describe('/api/v1 economy + purchase', () => {
        it('GET economy returns balance, tiers, and the catalog', async () => {
            await User.create({ robloxId: '900001', totalPoints: 120, maxDeckSize: 'S', teahouses: { S: { baseStyle: 'teahouse-1story' } } });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/900001/economy').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.totalPoints).toBe(120);
            expect(res.body.maxDeckSize).toBe('S');
            expect(res.body.teahouseSizes).toEqual(['S']);
            expect(res.body.catalog.deck.M).toBe(500);
        });

        it('POST purchase deck:S grants the tier and deducts points', async () => {
            await User.create({ robloxId: '900002', totalPoints: 60 });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .post('/api/v1/players/900002/purchase').set('X-API-Key', API_KEY).send({ item: 'deck:S' }).expect(200);
            expect(res.body.maxDeckSize).toBe('S');
            expect(res.body.totalPoints).toBe(10);
            const reread = await request(app)
                .get('/api/v1/players/900002/economy').set('X-API-Key', API_KEY).expect(200);
            expect(reread.body.maxDeckSize).toBe('S');
        });

        it('POST purchase teahouse:S grants the size key in the teahouses map', async () => {
            await User.create({ robloxId: '900003', totalPoints: 100, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/900003/purchase').set('X-API-Key', API_KEY).send({ item: 'teahouse:S' }).expect(200);
            expect(res.body.teahouseSizes).toEqual(['S']);
        });

        it('POST purchase rejects unaffordable / bad tier / bad item with 400', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await User.create({ robloxId: '900004', totalPoints: 0 });
            await request(app)
                .post('/api/v1/players/900004/purchase').set('X-API-Key', API_KEY).send({ item: 'deck:S' }).expect(400);
            await User.create({ robloxId: '900005', totalPoints: 100000 });
            const badTier = await request(app)
                .post('/api/v1/players/900005/purchase').set('X-API-Key', API_KEY).send({ item: 'deck:M' }).expect(400);
            expect(badTier.body.error).toBe('BAD_TIER_ORDER');
            const badItem = await request(app)
                .post('/api/v1/players/900005/purchase').set('X-API-Key', API_KEY).send({ item: 'nope:S' }).expect(400);
            expect(badItem.body.error).toBe('BAD_ITEM');
        });

        it('GET economy returns display fields (null by default)', async () => {
            await User.create({ robloxId: '900006', totalPoints: 0, maxDeckSize: 'L', teahouses: { S: {}, M: {}, L: {} } });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/900006/economy').set('X-API-Key', API_KEY).expect(200);
            expect(res.body).toMatchObject({ deckDisplay: null, teahouseDisplay: null });
        });

        it('POST display persists valid caps and echoes them', async () => {
            await User.create({ robloxId: '900007', totalPoints: 0, maxDeckSize: 'L', teahouses: { S: {}, M: {}, L: {} } });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/900007/display').set('X-API-Key', API_KEY)
                .send({ deckDisplay: 'M', teahouseDisplay: 'none' }).expect(200);
            expect(res.body).toEqual({ deckDisplay: 'M', teahouseDisplay: 'none' });
            const u = await User.findOne({ robloxId: '900007' });
            expect(u?.deckDisplay).toBe('M');
            expect(u?.teahouseDisplay).toBe('none');
        });

        it('POST display rejects an unowned size', async () => {
            await User.create({ robloxId: '900008', totalPoints: 0, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/900008/display').set('X-API-Key', API_KEY)
                .send({ deckDisplay: 'L' }).expect(400);
            expect(res.body.error).toBe('DISPLAY_UNOWNED');
        });

        it('GET economy returns portalOwned (false by default)', async () => {
            await User.create({ robloxId: 'p_portal1', totalPoints: 0, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/p_portal1/economy').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.portalOwned).toBe(false);
            expect(res.body.catalog.portal).toBe(500);
        });

        it('POST purchase portal persists portalOwned and echoes it', async () => {
            await User.create({ robloxId: 'p_portal2', totalPoints: 1000, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/p_portal2/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'portal' }).expect(200);
            expect(res.body.portalOwned).toBe(true);
            const u = await User.findOne({ robloxId: 'p_portal2' });
            expect(u?.portalOwned).toBe(true);
        });
    });

    describe('fireworks', () => {
        // NB: the identity field is `robloxId`; `resolveUser({ robloxUserId })` looks it up and
        // UPSERTS. Seeding with `robloxUserId` would leave an orphan and let the route mint a
        // second, empty user — the counts would silently read zero.
        it('reports every shell with counts and reasons', async () => {
            const u = await User.create({ robloxId: '900', fireworks: { firecracker: 2 } });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/900/fireworks')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(res.body.shells.firecracker).toEqual({
                count: 2,
                launchable: true,
                reason: null,
            });
            expect(res.body.shells.peony).toEqual({
                count: 0,
                launchable: false,
                reason: 'NONE_HELD',
            });
            expect(res.body.mortars).toEqual([]);
            await User.deleteOne({ _id: u._id });
        });

        it('honours lastWorldThrow for the condition shell', async () => {
            await User.create({ robloxId: '901', fireworks: { ishibana: 1 } });
            const app = makeApp(makeEngine(), new ResultsStore());
            const waiting = await request(app)
                .get('/api/v1/players/901/fireworks?lastWorldThrow=P')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(waiting.body.shells.ishibana.reason).toBe('WAITING_FOR_R');
            const open = await request(app)
                .get('/api/v1/players/901/fireworks?lastWorldThrow=R')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(open.body.shells.ishibana.launchable).toBe(true);
        });

        it('spend decrements and returns the new count', async () => {
            await User.create({ robloxId: '902', fireworks: { firecracker: 2 } });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/902/fireworks/spend')
                .set('X-API-Key', API_KEY)
                .send({ shellId: 'firecracker' })
                .expect(200);
            expect(res.body).toEqual({ shellId: 'firecracker', count: 1 });
        });

        it('spend refuses when none are held, and does not go negative', async () => {
            await User.create({ robloxId: '903', fireworks: { firecracker: 0 } });
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app)
                .post('/api/v1/players/903/fireworks/spend')
                .set('X-API-Key', API_KEY)
                .send({ shellId: 'firecracker' })
                .expect(409);
            const after = await User.findOne({ robloxId: '903' });
            expect(after!.fireworks.get('firecracker') ?? 0).toBe(0);
        });

        it('CONCURRENT SPENDS CANNOT OVERSPEND — the conditional $inc is the whole point', async () => {
            // Two launches racing on a single held shell. A read-modify-write would let both read
            // count=1 and both write count=0, firing two shells for one. Exactly one must win.
            await User.create({ robloxId: '904', fireworks: { firecracker: 1 } });
            const app = makeApp(makeEngine(), new ResultsStore());
            const fire = () =>
                request(app)
                    .post('/api/v1/players/904/fireworks/spend')
                    .set('X-API-Key', API_KEY)
                    .send({ shellId: 'firecracker' });
            const [a, b] = await Promise.all([fire(), fire()]);
            const codes = [a.status, b.status].sort();
            expect(codes).toEqual([200, 409]);
            const after = await User.findOne({ robloxId: '904' });
            expect(after!.fireworks.get('firecracker')).toBe(0);
        });

        it('buys a shell through the existing purchase route', async () => {
            await User.create({ robloxId: '905', totalPoints: 10 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/905/purchase')
                .set('X-API-Key', API_KEY)
                .send({ item: 'firework:peony' })
                .expect(200);
            expect(res.body.totalPoints).toBe(7);
            const after = await User.findOne({ robloxId: '905' });
            expect(after!.fireworks.get('peony')).toBe(1);
        });

        it('buys a mortar tube, and tubes are linear', async () => {
            await User.create({ robloxId: '906', totalPoints: 5000 });
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app)
                .post('/api/v1/players/906/purchase')
                .set('X-API-Key', API_KEY)
                .send({ item: 'mortar:M' })
                .expect(400); // no S yet
            await request(app)
                .post('/api/v1/players/906/purchase')
                .set('X-API-Key', API_KEY)
                .send({ item: 'mortar:S' })
                .expect(200);
            await request(app)
                .post('/api/v1/players/906/purchase')
                .set('X-API-Key', API_KEY)
                .send({ item: 'mortar:M' })
                .expect(200);
            const after = await User.findOne({ robloxId: '906' });
            expect(after!.mortars.sort()).toEqual(['mortar:M', 'mortar:S']);
        });
    });
});
