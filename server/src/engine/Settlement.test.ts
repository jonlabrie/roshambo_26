import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import Round from '../models/Round';
import PlayerRound from '../models/PlayerRound';
import { settleRound, buildCounterUpdate } from './Settlement';
import { ThrowEntry } from './RoundEngine';
import StreakEvent from '../models/StreakEvent';

function throwsMap(entries: [string, ThrowEntry][]) { return new Map(entries); }

describe('settleRound', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('persists the round, scores each participant, returns settled players', async () => {
        await User.create({ deviceId: 'devA', pointsAtStake: 9, currentStreak: 2, stakingStreak: 2, bestStreak: 2 });
        const { round, players } = await settleRound({
            roundId: 'r1',
            worldThrow: 'S', // R beats S -> devA (R) WINs; roblox 77 (S) SAFE; roblox 88 (P) LOSS
            counts: { R: 1, P: 1, S: 1 },
            throws: throwsMap([
                ['pwa:devA', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'devA' }],
                ['roblox:77', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '77', instanceId: 'job-1' }],
                ['roblox:88', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '88', instanceId: 'job-1' }],
            ]),
            timestamp: new Date(),
        });

        expect(round).toMatchObject({ id: 'r1', worldThrow: 'S', totalPlayers: 3, distribution: { R: 33, P: 33, S: 33 } });
        expect(await Round.countDocuments({ id: 'r1' })).toBe(1);
        expect(await PlayerRound.countDocuments({ roundId: 'r1' })).toBe(3);

        const win = players.find(p => p.key === 'pwa:devA')!;
        expect(win).toMatchObject({ result: 'WIN', delta: 27, pot: 27, streak: 3, platform: 'pwa' });

        const safe = players.find(p => p.key === 'roblox:77')!;
        expect(safe).toMatchObject({ result: 'SAFE', delta: 0, pot: 0, streak: 0, instanceId: 'job-1' });

        const loss = players.find(p => p.key === 'roblox:88')!;
        expect(loss).toMatchObject({ result: 'LOSS', delta: 0, pot: 0, streak: 0 });
    });

    it('updates bestStreak on new highs and persists user wallets', async () => {
        await settleRound({
            roundId: 'r2', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
            throws: throwsMap([['roblox:77', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '77' }]]),
            timestamp: new Date(),
        });
        const u = await User.findOne({ robloxId: '77' });
        expect(u).toMatchObject({ pointsAtStake: 1, currentStreak: 1, stakingStreak: 1, bestStreak: 1 });
    });

    it('a WIN grants one firecracker', async () => {
        // The grant pathway's first source. A new player should see their own firework within
        // minutes of joining, without buying anything.
        const user = await User.create({ deviceId: 'grantWin', pointsAtStake: 0 });
        await settleRound({
            roundId: 'rGrantWin',
            worldThrow: 'S', // R beats S -> WIN
            counts: { R: 1, P: 0, S: 0 },
            throws: throwsMap([
                ['pwa:grantWin', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'grantWin' }],
            ]),
            timestamp: new Date(),
        });
        const after = await User.findById(user._id);
        expect(after!.fireworks.get('firecracker')).toBe(1);
    });

    it('a LOSS grants nothing', async () => {
        const user = await User.create({ deviceId: 'grantLoss', pointsAtStake: 0 });
        await settleRound({
            roundId: 'rGrantLoss',
            worldThrow: 'P', // P beats R -> LOSS
            counts: { R: 1, P: 0, S: 0 },
            throws: throwsMap([
                ['pwa:grantLoss', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'grantLoss' }],
            ]),
            timestamp: new Date(),
        });
        const after = await User.findById(user._id);
        expect(after!.fireworks.get('firecracker') ?? 0).toBe(0);
    });

    it('a SAFE grants nothing either — the grant rides WIN alone', async () => {
        const user = await User.create({ deviceId: 'grantSafe', pointsAtStake: 0 });
        await settleRound({
            roundId: 'rGrantSafe',
            worldThrow: 'R', // matching the world is SAFE
            counts: { R: 1, P: 0, S: 0 },
            throws: throwsMap([
                ['pwa:grantSafe', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'grantSafe' }],
            ]),
            timestamp: new Date(),
        });
        const after = await User.findById(user._id);
        expect(after!.fireworks.get('firecracker') ?? 0).toBe(0);
    });

    it('uses 33/33/33 distribution when nobody played', async () => {
        const { round } = await settleRound({
            roundId: 'r3', worldThrow: 'R', counts: { R: 0, P: 0, S: 0 }, throws: new Map(), timestamp: new Date(),
        });
        expect(round.distribution).toEqual({ R: 33, P: 33, S: 33 });
    });

    it('leaves wallet untouched when PlayerRound.create fails; other participants still settle', async () => {
        // roblox:88 will LOSE (P vs worldThrow S) — with pointsAtStake:9 their pot would be zeroed.
        // We want to assert that mutation never happens if the history write fails first.
        await User.create({ robloxId: '88', identityTier: 'roblox', pointsAtStake: 9, currentStreak: 2 });

        const original = (PlayerRound.create as any).bind(PlayerRound);
        const spy = vi.spyOn(PlayerRound, 'create').mockImplementation(((doc: any) =>
            doc.robloxUserId === '88' ? Promise.reject(new Error('boom')) : original(doc)) as any);

        let result: Awaited<ReturnType<typeof settleRound>>;
        try {
            result = await settleRound({
                roundId: 'r4',
                worldThrow: 'S', // roblox:77 (S) SAFE; roblox:88 (P) LOSS
                counts: { R: 0, P: 1, S: 1 },
                throws: throwsMap([
                    ['roblox:77', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '77' }],
                    ['roblox:88', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '88' }],
                ]),
                timestamp: new Date(),
            });
        } finally {
            spy.mockRestore();
        }

        // (a) roblox:88's User doc must be unchanged — pot and streak untouched
        const user88 = await User.findOne({ robloxId: '88' });
        expect(user88!.pointsAtStake).toBe(9);
        expect(user88!.currentStreak).toBe(2);

        // (b) roblox:77 (SAFE, auto-created) still settles normally
        const safe = result!.players.find(p => p.key === 'roblox:77');
        expect(safe).toBeDefined();
        expect(safe!.result).toBe('SAFE');

        // (c) failed participant absent from returned players array
        const absent = result!.players.find(p => p.key === 'roblox:88');
        expect(absent).toBeUndefined();
    });

    describe('Settlement — capture for the stats surface', () => {
        it('records the RESOLVED user on PlayerRound, even for a guest with no JWT', async () => {
            const user = await User.create({ deviceId: 'guest-1' });
            await settleRound({
                roundId: 'r-guest', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
                throws: new Map([['guest-1', { deviceId: 'guest-1', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
                timestamp: new Date(),
            });
            const row = await PlayerRound.findOne({ roundId: 'r-guest' });
            expect(row?.userId?.toString()).toBe(user._id.toString());
        });

        it('records a completed streak when a run ends in a LOSS', async () => {
            const user = await User.create({ deviceId: 'streak-1', currentStreak: 4, pointsAtStake: 27 });
            await settleRound({
                roundId: 'r-loss', worldThrow: 'P', counts: { R: 1, P: 0, S: 0 },
                throws: new Map([['streak-1', { deviceId: 'streak-1', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
                timestamp: new Date(),
            });
            const events = await StreakEvent.find({ userId: user._id });
            expect(events).toHaveLength(1);
            expect(events[0].length).toBe(4);
            expect(events[0].endedBy).toBe('LOSS');
        });

        it('records a completed streak when a run ends in a SAFE', async () => {
            const user = await User.create({ deviceId: 'streak-2', currentStreak: 6 });
            await settleRound({
                roundId: 'r-safe', worldThrow: 'R', counts: { R: 1, P: 0, S: 0 },
                throws: new Map([['streak-2', { deviceId: 'streak-2', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
                timestamp: new Date(),
            });
            const event = await StreakEvent.findOne({ userId: user._id });
            expect(event?.length).toBe(6);
            expect(event?.endedBy).toBe('SAFE');
        });

        it('records NOTHING when a WIN extends a streak', async () => {
            const user = await User.create({ deviceId: 'streak-3', currentStreak: 2 });
            await settleRound({
                roundId: 'r-win', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
                throws: new Map([['streak-3', { deviceId: 'streak-3', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
                timestamp: new Date(),
            });
            expect(await StreakEvent.countDocuments({ userId: user._id })).toBe(0);
        });

        it('records NOTHING when a player with no streak loses', async () => {
            const user = await User.create({ deviceId: 'streak-4', currentStreak: 0 });
            await settleRound({
                roundId: 'r-nostreak', worldThrow: 'P', counts: { R: 1, P: 0, S: 0 },
                throws: new Map([['streak-4', { deviceId: 'streak-4', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
                timestamp: new Date(),
            });
            expect(await StreakEvent.countDocuments({ userId: user._id })).toBe(0);
        });
    });

    describe('milestones are earned at settlement', () => {
        // R beats S. Seeding pointsAtStake: 3 means this win takes the pot to 9 and earns `pot.9`
        // in the same round it is reached — which is what "from the post-write state" means.
        const winsToNine = (roundId: string) => settleRound({
            roundId,
            worldThrow: 'S',
            counts: { R: 1, P: 1, S: 1 },
            throws: throwsMap([
                ['pwa:devA', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'devA' }],
                ['roblox:77', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '77', instanceId: 'job-1' }],
                ['roblox:88', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '88', instanceId: 'job-1' }],
            ]),
            timestamp: new Date(),
        });

        it('awards milestones from the post-write state, so a pot earns its badge the round it is reached', async () => {
            const user = await User.create({ deviceId: 'devA', pointsAtStake: 3 });
            await winsToNine('r1');
            const after = await User.findById(user._id);
            expect(after?.milestones).toContain('first.win');
            expect(after?.milestones).toContain('pot.9');
        });

        it('never awards the same milestone twice, however many rounds settle', async () => {
            const user = await User.create({ deviceId: 'devA', pointsAtStake: 3 });
            await winsToNine('r1');
            await winsToNine('r2');
            const ids = (await User.findById(user._id))?.milestones ?? [];
            expect(new Set(ids).size).toBe(ids.length);
        });

        it('a player who only ever loses earns nothing', async () => {
            const user = await User.create({ deviceId: 'devB' });
            await settleRound({
                roundId: 'r1',
                worldThrow: 'R',
                counts: { R: 1, P: 0, S: 1 },
                throws: throwsMap([['pwa:devB', { throw: 'S', seq: 1, platform: 'pwa', deviceId: 'devB' }]]),
                timestamp: new Date(),
            });
            expect((await User.findById(user._id))?.milestones).toEqual([]);
        });
    });

    describe('the synthetic crowd is part of the world, never a participant (spec §3, §4)', () => {
        it('totalPlayers counts humans + bots, synthetic records the bots, and only humans settle', async () => {
            await User.create({ deviceId: 'devA' });
            const { round, players } = await settleRound({
                roundId: 'r-crowd',
                worldThrow: 'R',
                counts: { R: 21, P: 6, S: 4 },          // 1 human (P) + 30 bots
                crowdCounts: { R: 21, P: 5, S: 4 },
                throws: throwsMap([
                    ['pwa:devA', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'devA' }],
                ]),
                timestamp: new Date(),
            });
            expect(round).toMatchObject({ totalPlayers: 31, synthetic: 30, distribution: { R: 68, P: 19, S: 13 } });
            expect(players).toHaveLength(1);
            expect(players[0]).toMatchObject({ key: 'pwa:devA', result: 'WIN' });
            expect(await PlayerRound.countDocuments({ roundId: 'r-crowd' })).toBe(1);
            expect(await User.countDocuments()).toBe(1);
            const saved = await Round.findOne({ id: 'r-crowd' }).lean();
            expect(saved).toMatchObject({ totalPlayers: 31, synthetic: 30 });
        });

        it('without crowdCounts, synthetic is 0 and totalPlayers is the humans, as before', async () => {
            const { round } = await settleRound({
                roundId: 'r-plain',
                worldThrow: 'R',
                counts: { R: 0, P: 2, S: 0 },
                throws: throwsMap([
                    ['pwa:x', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'x' }],
                    ['pwa:y', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'y' }],
                ]),
                timestamp: new Date(),
            });
            expect(round).toMatchObject({ totalPlayers: 2, synthetic: 0 });
        });
    });
});

describe('buildCounterUpdate', () => {
    it('counts a win, sets the gate, and tracks the biggest pot', () => {
        const u = buildCounterUpdate('R', 'WIN', 81, 0);
        expect(u.$inc.roundsPlayed).toBe(1);
        expect(u.$inc.wins).toBe(1);
        expect(u.$inc.throwsR).toBe(1);
        expect(u.$set.unresolvedWin).toBe(true);
        expect(u.$max.bestPot).toBe(81);
    });

    it('a SAFE counts a round and a throw but sets no gate', () => {
        const u = buildCounterUpdate('P', 'SAFE', 27, 0);
        expect(u.$inc.safes).toBe(1);
        expect(u.$inc.throwsP).toBe(1);
        expect(u.$set.unresolvedWin).toBe(false);
    });

    it('a LOSS clears the gate — there is nothing left to decide', () => {
        // the pot is forfeited, so a player cannot be left bound on a decision about zero
        const u = buildCounterUpdate('S', 'LOSS', 0, 0);
        expect(u.$inc.losses).toBe(1);
        expect(u.$inc.throwsS).toBe(1);
        expect(u.$set.unresolvedWin).toBe(false);
    });

    it('proposes the new pot for bestPot and lets $max arbitrate', () => {
        // the builder never reads the stored best — it proposes, Mongo keeps the larger
        const u = buildCounterUpdate('R', 'WIN', 3, 0);
        expect(u.$max.bestPot).toBe(3);
    });

    it('every round counts exactly one throw', () => {
        for (const t of ['R', 'P', 'S'] as const) {
            const u = buildCounterUpdate(t, 'SAFE', 0, 0);
            const thrown = (u.$inc.throwsR ?? 0) + (u.$inc.throwsP ?? 0) + (u.$inc.throwsS ?? 0);
            expect(thrown).toBe(1);
        }
    });
});

describe('buildCounterUpdate — forfeited points', () => {
    it('records the forfeited pot on a LOSS', () => {
        const update = buildCounterUpdate('R', 'LOSS', 0, 27);
        expect(update.$inc.lifetimeForfeited).toBe(27);
    });

    it('forfeits nothing on a WIN', () => {
        expect(buildCounterUpdate('R', 'WIN', 3, 0).$inc.lifetimeForfeited).toBe(0);
    });

    it('forfeits nothing on a SAFE', () => {
        expect(buildCounterUpdate('R', 'SAFE', 9, 0).$inc.lifetimeForfeited).toBe(0);
    });

    it('a LOSS from an empty pot forfeits nothing', () => {
        expect(buildCounterUpdate('R', 'LOSS', 0, 0).$inc.lifetimeForfeited).toBe(0);
    });
});
