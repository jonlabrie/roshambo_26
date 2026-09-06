import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import PlayerRound from '../models/PlayerRound';
import Session from '../models/Session';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { settleRound } from '../engine/Settlement';
import { createApiV1, buildProfilePayload } from './apiV1';
import { SHELL_IDS } from '../fireworks';

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
        it('carries the grade, so other clients can render plumage', async () => {
            await User.create({ robloxId: '12345', identityTier: 'roblox', milestones: ['first.win', 'pot.9'] });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/12345').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.grade).toBe(2);
            expect(res.body.gradeName).toBe('9th kyu');
            expect(res.body.band).toBe(1);
        });

        it('awards the one WINDOWED milestone here, where the user is already loaded', async () => {
            const u = await User.create({ robloxId: '12345', identityTier: 'roblox' });
            for (let i = 0; i < 360; i++) {
                await PlayerRound.create({
                    userId: u._id, roundId: `r${i}`, playerThrow: 'R',
                    playerResult: 'LOSS', pointsDelta: 0, timestamp: new Date(),
                });
            }
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).get('/api/v1/players/12345').set('X-API-Key', API_KEY).expect(200);
            expect((await User.findById(u._id))?.milestones).toContain('presence.qualified');
        });

        it('records the Roblox display name, so boards can stop saying Anonymous', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app)
                .get('/api/v1/players/12345?name=Ayaka').set('X-API-Key', API_KEY).expect(200);
            const u = await User.findOne({ robloxId: '12345' });
            expect(u?.displayName).toBe('Ayaka');
        });

        it('updates a name that has changed', async () => {
            await User.create({ robloxId: '12345', identityTier: 'roblox', displayName: 'Old' });
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app)
                .get('/api/v1/players/12345?name=New').set('X-API-Key', API_KEY).expect(200);
            expect((await User.findOne({ robloxId: '12345' }))?.displayName).toBe('New');
        });

        it('never clears a stored name when the query omits it', async () => {
            await User.create({ robloxId: '12345', identityTier: 'roblox', displayName: 'Ayaka' });
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app)
                .get('/api/v1/players/12345').set('X-API-Key', API_KEY).expect(200);
            expect((await User.findOne({ robloxId: '12345' }))?.displayName).toBe('Ayaka');
        });

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
            await User.create({ robloxId: '971201', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/971201/preferences-hud')
                .set('X-API-Key', API_KEY).send({ escalationPrompts: false }).expect(200);
            expect(res.body).toEqual({ escalationPrompts: false, resultSplash: true, seenBeats: [] });
            const u = await User.findOne({ robloxId: '971201' });
            expect(u?.escalationPrompts).toBe(false);
        });

        it('sets auraVisibility to a recognised value', async () => {
            await User.create({ robloxId: '971101', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            for (const v of ['HIDDEN', 'FRIENDS', 'PUBLIC']) {
                await request(app)
                    .put('/api/v1/players/971101/preferences-hud')
                    .set('X-API-Key', API_KEY).send({ auraVisibility: v }).expect(200);
                const u = await User.findOne({ robloxId: '971101' });
                expect(u?.auraVisibility).toBe(v);
            }
        });

        it('REFUSES an unrecognised auraVisibility rather than defaulting it', async () => {
            // A privacy setting must never be knocked back to a permissive default by a malformed
            // body or a caller's typo. Storing HIDDEN and then sending junk must leave HIDDEN.
            await User.create({ robloxId: '971102', identityTier: 'roblox', auraVisibility: 'HIDDEN' });
            const app = makeApp(makeEngine(), new ResultsStore());
            for (const bad of ['hidden', '', 'PUBLICK', 3, true, null]) {
                await request(app)
                    .put('/api/v1/players/971102/preferences-hud')
                    .set('X-API-Key', API_KEY).send({ auraVisibility: bad, statusBars: false });
                const u = await User.findOne({ robloxId: '971102' });
                expect(u?.auraVisibility).toBe('HIDDEN');
            }
        });

        it('defaults auraVisibility to PUBLIC and returns it on GET', async () => {
            // No migration was run, so a row written before this field existed must read as PUBLIC
            // rather than as silently hidden.
            await User.create({ robloxId: '971103', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/971103').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.auraVisibility).toBe('PUBLIC');
        });

        it('sets resultSplash independently of escalationPrompts', async () => {
            await User.create({ robloxId: '971205', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/971205/preferences-hud')
                .set('X-API-Key', API_KEY).send({ resultSplash: false }).expect(200);
            expect(res.body).toEqual({ escalationPrompts: true, resultSplash: false, seenBeats: [] });
            const u = await User.findOne({ robloxId: '971205' });
            expect(u?.resultSplash).toBe(false);
            // the other preference is untouched — one remote carries both, so a write of one must
            // never be a silent write of the other
            expect(u?.escalationPrompts).toBe(true);
        });

        it('adds a seenBeat without duplicating it, and never removes one', async () => {
            await User.create({ robloxId: '971202', identityTier: 'roblox', seenBeats: ['drum'] });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/971202/preferences-hud')
                .set('X-API-Key', API_KEY).send({ seenBeat: 'drum' }).expect(200);
            expect(res.body.seenBeats).toEqual(['drum']);

            const res2 = await request(app)
                .put('/api/v1/players/971202/preferences-hud')
                .set('X-API-Key', API_KEY).send({ seenBeat: 'gong' }).expect(200);
            expect(res2.body.seenBeats.sort()).toEqual(['drum', 'gong']);
        });

        it('400 when the body has neither field', async () => {
            await User.create({ robloxId: '971203', identityTier: 'roblox' });
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/971203/preferences-hud')
                .set('X-API-Key', API_KEY).send({}).expect(400);
        });

        it('401 without the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/971204/preferences-hud').send({ escalationPrompts: true }).expect(401);
        });
    });

    describe('PUT /players/:robloxUserId/preferences-hud — confirmThrows is retired', () => {
        it('ignores a confirmThrows key rather than persisting it', async () => {
            await User.create({ robloxId: '971206', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .put('/api/v1/players/971206/preferences-hud')
                .set('X-API-Key', API_KEY).send({ confirmThrows: false, escalationPrompts: false }).expect(200);
            expect(res.body).not.toHaveProperty('confirmThrows');
            expect(res.body.escalationPrompts).toBe(false);
            const u = await User.findOne({ robloxId: '971206' });
            expect(u?.confirmThrows).toBe(true); // schema default; the write of `false` was ignored
        });

        it('does not ship confirmThrows in the profile payload', async () => {
            await User.create({ robloxId: '971207', identityTier: 'roblox' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .get('/api/v1/players/971207').set('X-API-Key', API_KEY).expect(200);
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

        it('banks down to a rung and keeps the rest riding', async () => {
            await User.create({
                robloxId: '78', identityTier: 'roblox', pointsAtStake: 27,
                stakingStreak: 3, currentStreak: 3,
            });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/bank').set('X-API-Key', API_KEY)
                .send({ robloxUserId: '78', keep: 9 }).expect(200);

            expect(res.body).toMatchObject({
                totalPoints: 18, pointsAtStake: 9, stakingStreak: 3, currentStreak: 3,
            });
        });

        it('refuses an invalid keep with 409 and changes nothing', async () => {
            const u = await User.create({
                robloxId: '79', identityTier: 'roblox', pointsAtStake: 27, stakingStreak: 3,
            });
            await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/bank').set('X-API-Key', API_KEY)
                .send({ robloxUserId: '79', keep: 5 }).expect(409);

            const after = await User.findById(u._id);
            expect(after!.pointsAtStake).toBe(27);
        });
    });

    describe('POST /instances/:instanceId/presence', () => {
        it('opens one session per rostered player', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/instances/inst1/presence').set('X-API-Key', API_KEY)
                .send({ robloxUserIds: ['77', 88] }).expect(200);
            expect(res.body).toMatchObject({ opened: 2, touched: 0, closed: 0 });
            expect(await Session.countDocuments({ instanceId: 'inst1' })).toBe(2);
        });

        it('400s when robloxUserIds is not an array', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/instances/inst1/presence').set('X-API-Key', API_KEY)
                .send({ robloxUserIds: 'nope' }).expect(400);
        });

        it('drops junk ids rather than minting a User for them', async () => {
            // resolveUser UPSERTS. A blanket String() coercion turns null into the truthy
            // string "null" and writes a permanent User with robloxId: "null" into the
            // collection the leaderboards read from, indistinguishable afterwards from a
            // real player.
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/instances/inst1/presence').set('X-API-Key', API_KEY)
                .send({ robloxUserIds: [null, '', '   ', {}, true, '77'] }).expect(200);
            expect(res.body.opened).toBe(1);
            expect(await User.countDocuments({})).toBe(1);
            expect(await User.findOne({ robloxId: '77' })).not.toBeNull();
        });

        it('dedupes a roster that names the same player twice', async () => {
            // reconcilePresence snapshots the open sessions before its loop, so a duplicate
            // would open a SECOND session for one player and double their rounds-present.
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/instances/inst1/presence').set('X-API-Key', API_KEY)
                .send({ robloxUserIds: ['77', '77', 77] }).expect(200);
            expect(res.body.opened).toBe(1);
            expect(await Session.countDocuments({ instanceId: 'inst1' })).toBe(1);
        });
    });

    describe('GET /leaderboards', () => {
        it('world scope ranks by career earnings, not the spendable wallet, cacheable 30s', async () => {
            // lifetimeBanked runs OPPOSITE to totalPoints here: BloxKid banked more over their
            // career and then spent it, WebChamp is sitting on a bigger wallet having earned
            // less. Sorting on totalPoints would invert this list, so the assertion fails if
            // the ordering basis ever regresses to the wallet.
            await User.create({ deviceId: 'devA', displayName: 'WebChamp', totalPoints: 100, lifetimeBanked: 120 });
            await User.create({ robloxId: '77', identityTier: 'roblox', displayName: 'BloxKid', totalPoints: 50, lifetimeBanked: 9_000 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/leaderboards?scope=world').set('X-API-Key', API_KEY).expect(200);
            expect(res.headers['cache-control']).toBe('public, max-age=30');
            expect(res.body.scope).toBe('world');
            expect(res.body.leaders[0]).toMatchObject({ displayName: 'BloxKid', robloxId: '77', lifetimeBanked: 9_000 });
            expect(res.body.leaders[1]).toMatchObject({ displayName: 'WebChamp', totalPoints: 100, identityTier: 'guest' });
        });

        it('never puts a deviceId on the wire — it is a bearer credential on the socket path', async () => {
            await User.create({ deviceId: 'secret-device-id', displayName: 'WebChamp', lifetimeBanked: 120 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/leaderboards?scope=world').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.leaders[0].deviceId).toBeUndefined();
            expect(JSON.stringify(res.body)).not.toContain('secret-device-id');
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
                .get('/api/v1/players/971301/teahouses').set('X-API-Key', API_KEY).expect(200);
            expect(res.body).toEqual({ teahouses: {}, padPreferences: [] });
            expect(res.headers['cache-control']).toBe('no-store');
        });

        it('PUT then GET round-trips a loadout', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const loadout = { baseStyle: 'teahouse-1story', colorScheme: 'scheme.vermilion' };
            await request(app).put('/api/v1/players/971301/teahouses/M')
                .set('X-API-Key', API_KEY).send({ loadout }).expect(200);
            const res = await request(app).get('/api/v1/players/971301/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.teahouses.M).toEqual(loadout);
        });

        it('stores multiple sizes and overwrites a size', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const put = (sc: string, cs: string) => request(app)
                .put(`/api/v1/players/971301/teahouses/${sc}`).set('X-API-Key', API_KEY)
                .send({ loadout: { baseStyle: 'teahouse-1story', colorScheme: cs } }).expect(200);
            await put('S', 'scheme.ink'); await put('L', 'scheme.vermilion'); await put('S', 'scheme.dormant');
            const res = await request(app).get('/api/v1/players/971301/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.teahouses.S.colorScheme).toBe('scheme.dormant');
            expect(res.body.teahouses.L.colorScheme).toBe('scheme.vermilion');
        });

        it('rejects invalid loadouts with 400', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const put = (body: unknown) => request(app)
                .put('/api/v1/players/971301/teahouses/M').set('X-API-Key', API_KEY).send(body as object);
            await put({ loadout: 'nope' }).expect(400);
            await put({ loadout: { colorScheme: 'x' } }).expect(400);
            await put({ loadout: { baseStyle: 't', bogus: 1 } }).expect(400);
        });

        it('requires the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/971301/teahouses').expect(401);
        });
    });

    describe('preferences persistence', () => {
        it('PUT then GET teahouses returns padPreferences', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).put('/api/v1/players/971301/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: ['T06', 'T02'] }).expect(200);
            const res = await request(app).get('/api/v1/players/971301/teahouses')
                .set('X-API-Key', API_KEY).expect(200);
            expect(res.body.padPreferences).toEqual(['T06', 'T02']);
        });

        it('PUT echoes the stored preferences', async () => {
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/971301/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: ['T04'] }).expect(200);
            expect(res.body).toEqual({ padPreferences: ['T04'] });
        });

        it('400 on a non-array / oversize / non-string body', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            await request(app).put('/api/v1/players/971301/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: 'T06' }).expect(400);
            await request(app).put('/api/v1/players/971301/preferences')
                .set('X-API-Key', API_KEY).send({ padPreferences: [42] }).expect(400);
            await request(app).put('/api/v1/players/971301/preferences')
                .set('X-API-Key', API_KEY)
                .send({ padPreferences: Array.from({ length: 33 }, (_, i) => `T${i}`) }).expect(400);
        });

        it('401 without the API key', async () => {
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/971301/preferences').send({ padPreferences: [] }).expect(401);
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

        it('two concurrent purchases on one item\'s balance resolve to exactly one sale', async () => {
            // Parked defect (a): the read-modify-write purchase let both racers read the
            // pre-purchase balance and both save -- two items for one item's points.
            await User.create({ robloxId: '900050', totalPoints: 3 }); // exactly one peony
            const app = makeApp(makeEngine(), new ResultsStore());
            const fire = () => request(app)
                .post('/api/v1/players/900050/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'firework:peony' });
            const [a, b] = await Promise.all([fire(), fire()]);
            const statuses = [a.status, b.status].sort();
            expect(statuses[0]).toBe(200);
            expect(statuses[1]).toBeGreaterThanOrEqual(400); // the loser is refused, not granted
            const after = await User.findOne({ robloxId: '900050' });
            expect(after!.totalPoints).toBe(0); // never negative, never double-deducted
            expect(after!.fireworks.get('peony') ?? 0).toBe(1); // exactly one shell granted
        });

        it('two concurrent portal purchases with money for both still sell exactly one portal', async () => {
            // The unique-item variant: both racers read portalOwned=false; without the
            // uniqueness in the atomic filter the player pays twice for one portal.
            await User.create({ robloxId: '900051', totalPoints: 100000, maxDeckSize: 'S' });
            const app = makeApp(makeEngine(), new ResultsStore());
            const fire = () => request(app)
                .post('/api/v1/players/900051/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'portal' });
            const [a, b] = await Promise.all([fire(), fire()]);
            const statuses = [a.status, b.status].sort();
            expect(statuses[0]).toBe(200);
            expect(statuses[1]).toBeGreaterThanOrEqual(400);
            const after = await User.findOne({ robloxId: '900051' });
            expect(after!.portalOwned).toBe(true);
            const winner = a.status === 200 ? a : b;
            expect(after!.totalPoints).toBe(winner.body.totalPoints); // deducted exactly once
        });

        it('PUT decorations rejects instances the player never bought', async () => {
            // Parked defect (b): the PUT validated shape but never ownership.
            await User.create({
                robloxId: '900052', totalPoints: 0, maxDeckSize: 'S',
                deckDecorations: [{ id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N' }],
            });
            const app = makeApp(makeEngine(), new ResultsStore());
            const put = (decorations: unknown) => request(app)
                .put('/api/v1/players/900052/decorations').set('X-API-Key', API_KEY)
                .send({ decorations });
            // rearranging the owned instance: fine
            await put([{ id: 1, propId: 'bonsai', offset: [2, 3], facing: 'E' }]).expect(200);
            // minting an unowned instance: refused
            const minted = await put([
                { id: 1, propId: 'bonsai', offset: [2, 3], facing: 'E' },
                { id: 2, propId: 'tsukubai', offset: [0, 0], facing: 'N' },
            ]).expect(400);
            expect(minted.body.error).toBe('DECORATION_NOT_OWNED');
        });

        it('a garbage path id is refused with 400 and mints NO user (parked defect (o))', async () => {
            const app = makeApp(makeEngine(), new ResultsStore());
            const before = await User.countDocuments({});
            const blank = await request(app)
                .get('/api/v1/players/%20/economy').set('X-API-Key', API_KEY);
            expect(blank.status).toBe(400);
            expect(blank.body.error).toBe('BAD_PLAYER_ID');
            const alpha = await request(app)
                .post('/api/v1/players/not-a-number/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'deck:S' });
            expect(alpha.status).toBe(400);
            expect(await User.countDocuments({})).toBe(before); // the upsert never ran
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
            await User.create({ robloxId: '971401', totalPoints: 0, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/971401/economy').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.portalOwned).toBe(false);
            expect(res.body.catalog.portal).toBe(500);
        });

        it('POST purchase portal persists portalOwned and echoes it', async () => {
            await User.create({ robloxId: '971402', totalPoints: 1000, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/971402/purchase').set('X-API-Key', API_KEY)
                .send({ item: 'portal' }).expect(200);
            expect(res.body.portalOwned).toBe(true);
            const u = await User.findOne({ robloxId: '971402' });
            expect(u?.portalOwned).toBe(true);
        });

        it('POST purchase starter grants deck S + teahouse S and deducts 20', async () => {
            await User.create({ robloxId: '900060', totalPoints: 25 });
            const app = makeApp(makeEngine(), new ResultsStore());
            const res = await request(app)
                .post('/api/v1/players/900060/purchase').set('X-API-Key', API_KEY).send({ item: 'starter' }).expect(200);
            expect(res.body.maxDeckSize).toBe('S');
            expect(res.body.teahouseSizes).toEqual(['S']);
            expect(res.body.totalPoints).toBe(5);
        });

        it('POST purchase starter rejects an existing owner with ALREADY_OWNED', async () => {
            await User.create({ robloxId: '900061', totalPoints: 1000, maxDeckSize: 'S' });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/players/900061/purchase').set('X-API-Key', API_KEY).send({ item: 'starter' }).expect(400);
            expect(res.body.error).toBe('ALREADY_OWNED');
        });

        it('two concurrent starter purchases resolve to exactly one sale', async () => {
            await User.create({ robloxId: '900062', totalPoints: 40 });
            const app = makeApp(makeEngine(), new ResultsStore());
            const fire = () => request(app)
                .post('/api/v1/players/900062/purchase').set('X-API-Key', API_KEY).send({ item: 'starter' });
            const [a, b] = await Promise.all([fire(), fire()]);
            const statuses = [a.status, b.status].sort();
            expect(statuses[0]).toBe(200);
            expect(statuses[1]).toBeGreaterThanOrEqual(400);
            const after = await User.findOne({ robloxId: '900062' });
            expect(after!.totalPoints).toBe(20); // one deduction, never two
            expect(after!.maxDeckSize).toBe('S');
        });

        it('GET economy catalog carries the starter price', async () => {
            await User.create({ robloxId: '900063', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/900063/economy').set('X-API-Key', API_KEY).expect(200);
            expect(res.body.catalog.starter).toBe(20);
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
                powderEligible: true,
            });
            expect(res.body.shells.peony).toEqual({
                count: 0,
                launchable: false,
                reason: 'NONE_HELD',
                powderEligible: true,
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

        it('the economy catalog carries shell and mortar prices', async () => {
            // Without this the shop panel has to hardcode prices, which is the defect class
            // this project has already hit three times: a number authoritative on the server,
            // re-derived client-side, going stale.
            await User.create({ robloxId: '907', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/907/economy')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(res.body.catalog.fireworks).toEqual({
                firecracker: 1,
                peony: 3,
                willow: 4,
                ishibana: 6,
                kiku: 4,
                wa: 5,
                yashi: 10,
                kamuro: 10,
                hotaru: 8,
                janken: 12,
                rai: 4,
                banrai: 7,
            });
            expect(res.body.catalog.mortars).toEqual({
                'mortar:S': 10,
                'mortar:M': 50,
                'mortar:L': 100,
            });
        });

        it('every sellable shell has a catalogued price', async () => {
            // The gate that matters: a shell added to SHELL_IDS but not to the payload would
            // render in the shop with a blank price.
            await User.create({ robloxId: '908', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/908/economy')
                .set('X-API-Key', API_KEY)
                .expect(200);
            for (const id of SHELL_IDS) {
                expect(typeof res.body.catalog.fireworks[id]).toBe('number');
            }
        });

        it('mortar placements round-trip and ride the fireworks GET', async () => {
            await User.create({ robloxId: '911', totalPoints: 0, mortars: ['mortar:S'] });
            const app = makeApp(makeEngine(), new ResultsStore());
            const put = await request(app)
                .put('/api/v1/players/911/mortar-placements')
                .set('X-API-Key', API_KEY)
                .send({ placements: { 'mortar:S': { offset: [2, -3], facing: 'E' } } })
                .expect(200);
            expect(put.body.mortarPlacements['mortar:S']).toEqual({ offset: [2, -3], facing: 'E' });
            const get = await request(app)
                .get('/api/v1/players/911/fireworks')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(get.body.mortarPlacements['mortar:S']).toEqual({ offset: [2, -3], facing: 'E' });
        });
        it('rejects placements for unowned mortars', async () => {
            await User.create({ robloxId: '912', totalPoints: 0, mortars: [] });
            await request(makeApp(makeEngine(), new ResultsStore()))
                .put('/api/v1/players/912/mortar-placements')
                .set('X-API-Key', API_KEY)
                .send({ placements: { 'mortar:S': { offset: [0, 0], facing: 'N' } } })
                .expect(400);
        });

        describe('powder (spec §7): points and shells flow IN, nothing flows out but fireworks', () => {
            it('economy and fireworks reads carry powder (default 0)', async () => {
                await User.create({ robloxId: '920' });
                const app = makeApp(makeEngine(), new ResultsStore());
                expect((await request(app).get('/api/v1/players/920/economy').set('X-API-Key', API_KEY).expect(200)).body.powder).toBe(0);
                expect((await request(app).get('/api/v1/players/920/fireworks').set('X-API-Key', API_KEY).expect(200)).body.powder).toBe(0);
            });

            it('topup moves points into powder, one way, atomically', async () => {
                await User.create({ robloxId: '921', totalPoints: 10 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/921/powder/topup').set('X-API-Key', API_KEY).send({ points: 4 }).expect(200);
                expect(res.body).toEqual({ powder: 4, totalPoints: 6 });
                const after = await User.findOne({ robloxId: '921' });
                expect(after!.totalPoints).toBe(6);
                expect(after!.powder).toBe(4);
                expect(after!.lifetimeBanked ?? 0).toBe(0); // career earnings untouched
            });

            it('topup refuses more than the wallet holds, and moves nothing', async () => {
                await User.create({ robloxId: '922', totalPoints: 3 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/922/powder/topup').set('X-API-Key', API_KEY).send({ points: 4 }).expect(409);
                expect(res.body).toEqual({ error: 'INSUFFICIENT_POINTS', held: 3 });
                const after = await User.findOne({ robloxId: '922' });
                expect([after!.totalPoints, after!.powder]).toEqual([3, 0]);
            });

            it('topup is ONE WAY: zero, negative, fractional and non-numeric amounts are refused', async () => {
                await User.create({ robloxId: '923', totalPoints: 10, powder: 10 });
                const app = makeApp(makeEngine(), new ResultsStore());
                for (const points of [0, -4, 2.5, 'lots', undefined]) {
                    const res = await request(app).post('/api/v1/players/923/powder/topup').set('X-API-Key', API_KEY).send({ points }).expect(400);
                    expect(res.body.error).toBe('BAD_AMOUNT');
                }
                const after = await User.findOne({ robloxId: '923' });
                expect([after!.totalPoints, after!.powder]).toEqual([10, 10]);
            });

            it('melt turns held shells into powder at list price, atomically', async () => {
                await User.create({ robloxId: '924', fireworks: { peony: 3 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/924/fireworks/melt').set('X-API-Key', API_KEY).send({ shellId: 'peony', count: 2 }).expect(200);
                expect(res.body).toEqual({ shellId: 'peony', count: 1, powder: 6, credited: 6 }); // peony is 3
                const after = await User.findOne({ robloxId: '924' });
                expect(after!.fireworks.get('peony')).toBe(1);
                expect(after!.powder).toBe(6);
                expect(after!.totalPoints).toBe(0); // never points
            });

            it('melt refuses more than held, bad counts, unknown shells — and moves nothing', async () => {
                await User.create({ robloxId: '925', fireworks: { peony: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (body: object) => request(app).post('/api/v1/players/925/fireworks/melt').set('X-API-Key', API_KEY).send(body);
                expect((await post({ shellId: 'peony', count: 2 }).expect(409)).body).toEqual({ error: 'NONE_HELD', held: 1 });
                expect((await post({ shellId: 'peony', count: 0 }).expect(400)).body.error).toBe('BAD_COUNT');
                expect((await post({ shellId: 'peony', count: 1.5 }).expect(400)).body.error).toBe('BAD_COUNT');
                expect((await post({ shellId: 'moonshot', count: 1 }).expect(400)).body.error).toBe('BAD_SHELL');
                const after = await User.findOne({ robloxId: '925' });
                expect([after!.fireworks.get('peony'), after!.powder]).toEqual([1, 0]);
            });

            // un-skip when the first ineligible shell exists — POWDER_INELIGIBLE is unreachable
            // while shared-fixtures/firework-shells.json's `powderIneligible` list is empty.
            it.skip('melt refuses a powder-ineligible shell', async () => {
                await User.create({ robloxId: '927', fireworks: { peony: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/927/fireworks/melt').set('X-API-Key', API_KEY).send({ shellId: 'peony', count: 1 }).expect(400);
                expect(res.body.error).toBe('POWDER_INELIGIBLE');
            });

            it('CONCURRENT MELTS CANNOT OVER-CREDIT — one conditional update per melt', async () => {
                await User.create({ robloxId: '926', fireworks: { wa: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { shellId: 'wa', count: 1 };
                const [a, b] = await Promise.all([
                    request(app).post('/api/v1/players/926/fireworks/melt').set('X-API-Key', API_KEY).send(body),
                    request(app).post('/api/v1/players/926/fireworks/melt').set('X-API-Key', API_KEY).send(body),
                ]);
                expect([a.status, b.status].sort()).toEqual([200, 409]);
                const after = await User.findOne({ robloxId: '926' });
                expect([after!.fireworks.get('wa'), after!.powder]).toEqual([0, 5]); // wa is 5
            });
        });
        describe('POST /players/:id/shows/reserve — a show debits everything up front, or nothing', () => {
            const show = (cues: object[], extra: object = {}) => ({
                show: { stageId: 'deck:910', fuel: 'inventory', cues, ...extra },
            });

            it('debits every shell a valid show needs in one step and reports what is left', async () => {
                await User.create({ robloxId: '910', mortars: ['mortar:S', 'mortar:M'], fireworks: { firecracker: 3, peony: 2, wa: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/910/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send(show([
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },
                        { t_ms: 1000, slot: 'mortar:M', shellId: 'wa' },
                        { t_ms: 2000, slot: 'hand', shellId: 'firecracker' },
                    ]))
                    .expect(200);
                expect(res.body.reservationId).toMatch(/^[a-z0-9]{6,}$/);
                expect(res.body.stageId).toBe('deck:910');
                expect(res.body.debited).toEqual({ firecracker: 2, peony: 1, wa: 1 });
                expect(res.body.remaining).toEqual({ firecracker: 1, peony: 1, wa: 0 });
                const after = await User.findOne({ robloxId: '910' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
                expect(after!.fireworks.get('wa')).toBe(0);
            });

            it('INSUFFICIENT debits nothing — all or nothing', async () => {
                await User.create({ robloxId: '911', mortars: ['mortar:S'], fireworks: { firecracker: 5, peony: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/911/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:911', fuel: 'inventory', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 500, slot: 'mortar:S', shellId: 'peony' },
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },
                    ] } })
                    .expect(409);
                expect(res.body).toEqual({ error: 'INSUFFICIENT', needed: { firecracker: 1, peony: 2 }, held: { firecracker: 5, peony: 1 } });
                const after = await User.findOne({ robloxId: '911' });
                expect(after!.fireworks.get('firecracker')).toBe(5); // the firecracker was NOT taken
                expect(after!.fireworks.get('peony')).toBe(1);
            });

            it('refuses a mortar slot for a tier the player does not own, before debiting', async () => {
                await User.create({ robloxId: '912', mortars: ['mortar:S'], fireworks: { firecracker: 1, willow: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/912/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:912', fuel: 'inventory', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 500, slot: 'mortar:M', shellId: 'willow' },
                    ] } })
                    .expect(409);
                expect(res.body).toEqual({ error: 'MORTAR_MISSING', slot: 'mortar:M' });
                const after = await User.findOne({ robloxId: '912' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
            });

            it('refuses powder fuel, other stages, malformed shows and invalid cues with the validator code', async () => {
                await User.create({ robloxId: '913', fireworks: { firecracker: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (body: object) => request(app).post('/api/v1/players/913/shows/reserve').set('X-API-Key', API_KEY).send(body);
                expect((await post({ show: { stageId: 'deck:913', fuel: 'powder', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('FUEL_UNSUPPORTED');
                expect((await post({ show: { stageId: 'rooftop', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('BAD_STAGE');
                expect((await post({ show: { stageId: 'deck:999', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('BAD_STAGE');
                expect((await post({}).expect(400)).body.error).toBe('BAD_SHOW');
                const bad = (await post({ show: { stageId: 'deck:913', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'peony' }] } }).expect(400)).body;
                expect(bad).toEqual({ error: 'TIER_MISMATCH', cue: 0 });
                const after = await User.findOne({ robloxId: '913' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
            });

            it('CONCURRENT RESERVES CANNOT OVERSPEND — one conditional update per reservation', async () => {
                await User.create({ robloxId: '914', fireworks: { firecracker: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { show: { stageId: 'deck:914', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } };
                const [a, b] = await Promise.all([
                    request(app).post('/api/v1/players/914/shows/reserve').set('X-API-Key', API_KEY).send(body),
                    request(app).post('/api/v1/players/914/shows/reserve').set('X-API-Key', API_KEY).send(body),
                ]);
                expect([a.status, b.status].sort()).toEqual([200, 409]);
                const after = await User.findOne({ robloxId: '914' });
                expect(after!.fireworks.get('firecracker')).toBe(0);
            });
        });
    });
});
