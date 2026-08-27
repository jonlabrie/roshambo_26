import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, vi } from 'vitest';
import { createServer, Server as HttpServer } from 'http';
import { Server } from 'socket.io';
import { io as clientIo, Socket as ClientSocket } from 'socket.io-client';
import { AddressInfo } from 'net';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { attachSocketAdapter } from './socketAdapter';
import Session from '../models/Session';
import User from '../models/User';
import BankEvent from '../models/BankEvent';
import StreakEvent from '../models/StreakEvent';
import PlayerRound from '../models/PlayerRound';
import { SESSION_HEARTBEAT_MS } from '../sessions';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'roshambo_super_secret_1337';

let httpServer: HttpServer;
let engine: RoundEngine;
let client: ClientSocket;
let initPromise: Promise<any>;

function waitFor<T>(socket: ClientSocket, event: string): Promise<T> {
    return new Promise(resolve => socket.once(event, resolve));
}

// A guest, the way the wire now works: the SERVER names the device and signs a token for it,
// and the socket carries that identity from then on. Tests that used to open with
// `sync-player { deviceId: 'devA' }` were asserting the hole this closed, so they claim here
// and read back the id the server chose.
async function claimDevice(sock: ClientSocket): Promise<string> {
    const claimed = waitFor<any>(sock, 'device-claimed');
    sock.emit('claim-device');
    return (await claimed).deviceId;
}

describe('socket adapter wire format', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);

    beforeEach(async () => {
        await clearTestDb();
        let n = 0;
        engine = new RoundEngine({
            openSeconds: 2, lockSeconds: 1, revealSeconds: 1,
            pickWorldThrow: () => 'S',
            makeRoundId: () => `round-${++n}`,
            // MIRRORS PRODUCTION (index.ts). Without nowMs the engine never sets
            // phaseEndsAtMs, so this harness was building an engine shaped unlike the one
            // that actually runs — and any test of the absolute phase boundary would have
            // been asserting against a field production populates and the harness did not.
            nowMs: () => Date.now(),
        });
        httpServer = createServer();
        const io = new Server(httpServer);
        attachSocketAdapter(io, engine, new ResultsStore());
        await new Promise<void>(r => httpServer.listen(0, r));
        const port = (httpServer.address() as AddressInfo).port;
        client = clientIo(`http://localhost:${port}`, { auth: {} });
        initPromise = new Promise<any>(resolve => client.once('init', resolve));
        await waitFor(client, 'connect');
    });

    afterEach(async () => {
        client.disconnect();
        // The server's 'disconnect' handler does an async closeSession() write that this
        // teardown doesn't otherwise wait for. Without waiting here, disconnectTestDb() in
        // afterAll can tear down the connection while that write is still in flight,
        // surfacing as an unhandled MongoNotConnectedError after the suite reports green.
        //
        // Poll for the actual side effect (every open Session getting endedAt set) rather
        // than sleeping a guessed duration: a fixed delay either wastes time when the write
        // is fast, or — under CI load / a busier MongoMemoryServer — is too short and lets
        // the race back in intermittently, which is worse than the original failure because
        // it reads as flake. Tests that never opened a session (no sync-player) have no open
        // Session documents, so this resolves immediately for them.
        await vi.waitFor(async () => {
            const stillOpen = await Session.countDocuments({ endedAt: { $exists: false } });
            expect(stillOpen).toBe(0);
        }, { timeout: 1000, interval: 10 });
        httpServer.close();
    });

    // THE PWA AND THE ROBLOX CLIENT MUST READ THE SAME CLOCK (owner, 2026-08-17). The Roblox
    // path has always received an ABSOLUTE strike time and slews against it; the PWA got only
    // `timeLeft`, an integer decremented once per server tick, with nothing to correct client
    // drift against and no countdown at all outside OPEN. Pointed at one backend the two still
    // disagreed by up to a second. These fields are what close that gap.
    it('puts an absolute phase boundary and a server timestamp on init', async () => {
        const init = await initPromise;
        expect(typeof init.phaseEndsAtMs).toBe('number');
        expect(typeof init.serverTimeMs).toBe('number');
        // The boundary must be in the FUTURE relative to the stamp that accompanies it, or a
        // client subtracting one from the other starts life with a negative countdown.
        expect(init.phaseEndsAtMs).toBeGreaterThan(init.serverTimeMs);
        expect(init.durations).toMatchObject({ openMs: 2000, lockMs: 1000, revealMs: 1000 });
    });

    it('puts the same absolute boundary on every sync tick', async () => {
        await initPromise;
        const next = waitFor(client, 'sync');
        engine.tick();
        const sync = await next;
        expect(typeof sync.phaseEndsAtMs).toBe('number');
        expect(typeof sync.serverTimeMs).toBe('number');
        expect(sync.durations).toMatchObject({ openMs: 2000, lockMs: 1000, revealMs: 1000 });
    });

    // The old field stays on the wire. A client that has not been rebuilt still reads it, and
    // the deployed PWA and the server do not ship together.
    it('keeps timeLeft alongside the new fields', async () => {
        const init = await initPromise;
        expect(typeof init.timeLeft).toBe('number');
    });

    // LOCK and REVEAL used to publish timeLeft 0, so the PWA went blind for the last third of
    // every round while the Roblox client kept counting. The boundary is published in every
    // phase, so a client can show a real countdown throughout.
    it('publishes a live boundary during LOCK and REVEAL, not a zeroed clock', async () => {
        await initPromise;
        // COLLECT rather than race a single listener: socket.io delivery is async, so a
        // listener attached after a tick still catches that tick's event and the phase read
        // comes out one step stale.
        const syncs: any[] = [];
        client.on('sync', d => syncs.push(d));
        for (let i = 0; i < 3; i++) {
            engine.tick();
            await new Promise(r => setTimeout(r, 20));
        }
        const offOpen = syncs.filter(d => d.phase !== 'OPEN');
        expect(offOpen.length).toBeGreaterThan(0);
        for (const d of offOpen) {
            // The old wire sent timeLeft 0 here, so the PWA went blind for the last third of
            // every round while the Roblox client kept counting.
            expect(d.timeLeft).toBe(0);
            expect(d.phaseEndsAtMs).toBeGreaterThan(d.serverTimeMs);
        }
    });

    it('emits legacy-shaped init on connect', async () => {
        const init = await initPromise;
        expect(init).toMatchObject({ phase: 'OPEN', roundCount: 0 });
        expect(init.history).toEqual([]);
        expect(typeof init.timeLeft).toBe('number');
    });

    it('sends revealMs on init so the client need not hardcode the reveal length', async () => {
        const init = await initPromise;
        expect(init.revealMs).toBe(1000); // revealSeconds: 1 in beforeEach
    });

    it('sends openMs on init so the client can calibrate the pie timer to OPEN\'s actual length', async () => {
        const init = await initPromise;
        expect(init.openMs).toBe(2000); // openSeconds: 2 in beforeEach
    });

    it('emits sync heartbeats on tick with timeLeft and playerCount', async () => {
        await initPromise;
        const sync = waitFor<any>(client, 'sync');
        engine.tick();
        expect(await sync).toMatchObject({ phase: 'OPEN', timeLeft: 1, roundCount: 0, playerCount: 1 });
    });

    it('zeroes timeLeft once OPEN has closed', async () => {
        await initPromise;
        const sync1 = waitFor<any>(client, 'sync');
        engine.tick(); // 2 -> 1, still OPEN
        await sync1; // let the first sync land before arming the next listener
        const sync2 = waitFor<any>(client, 'sync');
        engine.tick(); // OPEN expires -> LOCK
        expect(await sync2).toMatchObject({ phase: 'LOCK', timeLeft: 0 });
    });

    it('full round: submit-throw -> reveal with distribution -> player-data with lastResult', async () => {
        await initPromise;
        await claimDevice(client);
        client.emit('sync-player');
        await waitFor(client, 'player-data');

        client.emit('submit-throw', { throw: 'R' }); // R beats S -> WIN
        await new Promise(r => setTimeout(r, 50)); // let the emit land

        const revealP = waitFor<any>(client, 'reveal');
        const playerDataP = waitFor<any>(client, 'player-data');
        for (let i = 0; i < 3; i++) { engine.tick(); await new Promise(r => setTimeout(r, 20)); }
        // ticks: OPEN 2->1, OPEN 1->0 enters LOCK, LOCK 1->0 closes the round and starts
        // REVEAL (settlement completes and the reveal broadcasts on the same transition)

        const reveal = await revealP;
        expect(reveal).toMatchObject({ worldThrow: 'S', totalPlayers: 1, distribution: { R: 100, P: 0, S: 0 } });
        expect(typeof reveal.id).toBe('string');

        const pd = await playerDataP;
        expect(pd.lastResult).toEqual({ result: 'WIN', delta: 1 });
        expect(pd.user).toMatchObject({ pointsAtStake: 1, currentStreak: 1 });
        expect(Array.isArray(pd.history)).toBe(true);
    });

    it('emits player-data before reveal for the same round (CLAUDE.md emit order)', async () => {
        // Regression for a bug where the two fired in reverse order: settleRound's
        // first `await` let revealStarted run before the player-data loop, so
        // reveal always beat player-data to the PWA and the client showed the
        // previous round's result. Unlike the "full round" test above — which
        // awaits both promises CONCURRENTLY and can't observe which landed
        // first — this records arrival order via listeners registered up front.
        await initPromise;
        await claimDevice(client);
        client.emit('sync-player');
        await waitFor(client, 'player-data'); // initial sync-player reply, not part of the round broadcast

        client.emit('submit-throw', { throw: 'R' }); // R beats S -> WIN
        await new Promise(r => setTimeout(r, 50)); // let the emit land

        const order: string[] = [];
        const bothArrived = new Promise<void>(resolve => {
            let count = 0;
            const mark = (name: string) => () => {
                order.push(name);
                if (++count === 2) resolve();
            };
            client.once('player-data', mark('player-data'));
            client.once('reveal', mark('reveal'));
        });

        for (let i = 0; i < 3; i++) { engine.tick(); await new Promise(r => setTimeout(r, 20)); }

        await bothArrived;
        expect(order).toEqual(['player-data', 'reveal']);
    });

    it('buffers a throw submitted during REVEAL and enters it next round', async () => {
        await initPromise;
        await claimDevice(client);
        client.emit('sync-player');
        await waitFor(client, 'player-data');

        // OPEN and LOCK both accept submissions now — only REVEAL rejects (and buffers).
        for (let i = 0; i < 3; i++) engine.tick(); // OPEN -> LOCK -> REVEAL
        client.emit('submit-throw', { throw: 'P' });
        await new Promise(r => setTimeout(r, 50));

        engine.tick(); // REVEAL -> next OPEN (replay drains the buffer)
        const playerDataP = waitFor<any>(client, 'player-data');
        for (let i = 0; i < 3; i++) { engine.tick(); await new Promise(r => setTimeout(r, 20)); } // close round 2
        const pd = await playerDataP;
        expect(pd.lastResult.result).toBe('LOSS'); // round 2 world is S; P loses to S
    });

    it('heartbeats the PWA session so the stale sweep cannot mistake a live player for a dead one', async () => {
        // sync-player fires ONCE per connection. Without a heartbeat a PWA session sits at
        // its opening lastSeenAt forever, and the sweep used to close it — mid-game — at that
        // timestamp, collapsing the interval to zero width and zeroing rounds-present for a
        // player who was still throwing.
        await initPromise;
        await claimDevice(client);
        client.emit('sync-player');
        await waitFor(client, 'player-data');
        const opened = await Session.findOne({});
        expect(opened).not.toBeNull();
        const before = opened!.lastSeenAt.getTime();

        // Inside the throttle window a tick must write NOTHING: the sync broadcast is once a
        // second, and a presence write per player per second would cost far more than the
        // data is worth.
        engine.tick();
        await new Promise(r => setTimeout(r, 50));
        expect((await Session.findById(opened!._id))!.lastSeenAt.getTime()).toBe(before);

        // Past the window it writes. Date.now is faked only across the synchronous tick emit,
        // so socket.io's own ping timers never see the jump.
        const heartbeatAt = before + SESSION_HEARTBEAT_MS + 1_000;
        const clock = vi.spyOn(Date, 'now').mockReturnValue(heartbeatAt);
        engine.tick();
        clock.mockRestore();
        await vi.waitFor(async () => {
            const stored = await Session.findById(opened!._id);
            expect(stored!.lastSeenAt.getTime()).toBe(heartbeatAt);
        }, { timeout: 1000, interval: 10 });
        expect((await Session.findById(opened!._id))!.endedAt).toBeUndefined();
    });

    it('bank moves pot to totalPoints over the socket', async () => {
        await initPromise;
        const User = (await import('../models/User')).default;
        const devA = await claimDevice(client);
        await User.findOneAndUpdate({ deviceId: devA }, { $set: { totalPoints: 1, pointsAtStake: 9 } });
        client.emit('sync-player');
        await waitFor(client, 'player-data');

        const updated = waitFor<any>(client, 'player-data');
        client.emit('bank');
        expect((await updated).user).toMatchObject({ totalPoints: 10, pointsAtStake: 0 });
    });

    it('bank with a keep drops the pot to that rung over the socket', async () => {
        await initPromise;
        const devA = await claimDevice(client);
        await User.findOneAndUpdate({ deviceId: devA }, {
            $set: { totalPoints: 0, pointsAtStake: 27, stakingStreak: 3, currentStreak: 3 },
        });
        client.emit('sync-player');
        await waitFor(client, 'player-data');

        const updated = waitFor<any>(client, 'player-data');
        client.emit('bank', { keep: 9 });
        expect((await updated).user).toMatchObject({
            totalPoints: 18, pointsAtStake: 9, stakingStreak: 3, currentStreak: 3,
        });
    });

    it('bank with an invalid keep changes nothing', async () => {
        await initPromise;
        const devA = await claimDevice(client);
        await User.findOneAndUpdate({ deviceId: devA }, {
            $set: { totalPoints: 0, pointsAtStake: 27, stakingStreak: 3 },
        });

        client.emit('bank', { keep: 5 });
        // No player-data is emitted for a refused bank, so there is no event to await.
        await new Promise(r => setTimeout(r, 150));

        const after = await User.findOne({ deviceId: devA });
        expect(after!.pointsAtStake).toBe(27);
        expect(after!.totalPoints).toBe(0);
    });

    // ===== identity comes from the CONNECTION, never from a payload =====
    // Until 2026-08-18 every mutating handler resolved an account straight out of
    // `data.deviceId`, so anyone who learned one string owned that account: they could read
    // it, throw as it, rename it and cash out its pot. The deviceId was an identifier being
    // used as a password. It now identifies and a signed token authenticates, and the token
    // rides the handshake so a handler cannot be handed an account name at all.
    describe('device identity', () => {
        function connect(auth: Record<string, unknown>): ClientSocket {
            const port = (httpServer.address() as AddressInfo).port;
            return clientIo(`http://localhost:${port}`, { auth, forceNew: true });
        }

        async function claim(sock: ClientSocket): Promise<{ deviceId: string; deviceToken: string }> {
            const claimed = waitFor<any>(sock, 'device-claimed');
            sock.emit('claim-device');
            return claimed;
        }

        it('mints a device the SERVER named, with a token that verifies', async () => {
            const { deviceId, deviceToken } = await claim(client);
            expect(typeof deviceId).toBe('string');
            expect(deviceId.length).toBeGreaterThan(16); // not a client-chosen 'devA'
            const decoded = jwt.verify(deviceToken, JWT_SECRET) as any;
            expect(decoded.typ).toBe('device');
            expect(decoded.did).toBe(deviceId);
        });

        it('a payload deviceId names nobody', async () => {
            await initPromise;
            const victim = await User.create({ deviceId: 'victim-device', totalPoints: 500 });
            // No token on this socket at all: the old wire would have handed the account over.
            client.emit('sync-player', { deviceId: 'victim-device' });
            await new Promise(r => setTimeout(r, 120));
            const fresh = await User.findById(victim._id);
            expect(fresh!.totalPoints).toBe(500);
            const created = await User.countDocuments({});
            expect(created).toBe(1); // no guest conjured from the payload either
        });

        it('the token carries the account across a reconnect', async () => {
            const { deviceToken, deviceId } = await claim(client);
            const first = waitFor<any>(client, 'player-data');
            client.emit('sync-player');
            await first;
            await User.findOneAndUpdate({ deviceId }, { $set: { totalPoints: 42 } });

            const again = connect({ deviceToken });
            await waitFor(again, 'connect');
            const data = waitFor<any>(again, 'player-data');
            again.emit('sync-player');
            expect((await data).user.totalPoints).toBe(42);
            again.disconnect();
        });

        it('refuses a token this server did not sign', async () => {
            await initPromise;
            const forged = jwt.sign({ typ: 'device', did: 'someone-elses-device' }, 'not-the-secret');
            const sock = connect({ deviceToken: forged });
            await waitFor(sock, 'connect');
            sock.emit('sync-player');
            await new Promise(r => setTimeout(r, 120));
            expect(await User.countDocuments({})).toBe(0);
            sock.disconnect();
        });

        it('banks the socket\'s own pot, whatever the payload asks for', async () => {
            const { deviceId } = await claim(client);
            const mine = waitFor<any>(client, 'player-data');
            client.emit('sync-player');
            await mine;
            await User.findOneAndUpdate({ deviceId }, { $set: { pointsAtStake: 10, totalPoints: 0 } });
            const victim = await User.create({ deviceId: 'victim-device', pointsAtStake: 900, totalPoints: 0 });

            client.emit('bank', { deviceId: 'victim-device' });
            await new Promise(r => setTimeout(r, 150));

            const theirs = await User.findById(victim._id);
            expect(theirs!.pointsAtStake).toBe(900); // untouched
            expect(theirs!.totalPoints).toBe(0);
            const ours = await User.findOne({ deviceId });
            expect(ours!.totalPoints).toBe(10); // our own pot, banked
        });

        it('tells a socket with no device that it needs one', async () => {
            await initPromise;
            const needed = waitFor<any>(client, 'device-required');
            client.emit('sync-player');
            await needed; // the client's cue to claim, rather than a silent no-op
        });
    });

    describe('get-stats', () => {
        // deviceId is a BEARER CREDENTIAL on this transport: sync-player, submit-throw, bank and
        // update-progress all resolve an account straight from a client-supplied deviceId. This
        // handler is unauthenticated and returns 50 users plus 50 rounds, so leaking the field
        // here hands any connected socket full control of ~100 other accounts.
        it('never emits a deviceId, on either list', async () => {
            await initPromise;
            const a = await User.create({ deviceId: 'SECRET-DEVICE-A', displayName: 'Ayaka', lifetimeBanked: 900 });
            await PlayerRound.create({
                userId: a._id, deviceId: 'SECRET-DEVICE-A', roundId: 'r1',
                playerThrow: 'R', playerResult: 'WIN', pointsDelta: 81, timestamp: new Date(),
            });

            const statsP = waitFor<any>(client, 'stats-data');
            client.emit('get-stats', { timeframe: 'all' });
            const stats = await statsP;

            expect(stats.topPoints.length).toBeGreaterThan(0);
            expect(stats.biggestWins.length).toBeGreaterThan(0);
            expect(JSON.stringify(stats)).not.toContain('SECRET-DEVICE-A');
            expect(JSON.stringify(stats)).not.toContain('deviceId');
        });

        it('names the players instead, so a display needs no second lookup', async () => {
            await initPromise;
            const a = await User.create({ deviceId: 'devA', displayName: 'Ayaka', lifetimeBanked: 900 });
            await PlayerRound.create({
                userId: a._id, roundId: 'r1', playerThrow: 'R',
                playerResult: 'WIN', pointsDelta: 81, timestamp: new Date(),
            });

            const statsP = waitFor<any>(client, 'stats-data');
            client.emit('get-stats', { timeframe: 'all' });
            const stats = await statsP;

            expect(stats.topPoints[0]).toMatchObject({ displayName: 'Ayaka', lifetimeBanked: 900 });
            expect(stats.biggestWins[0]).toMatchObject({ displayName: 'Ayaka', pointsDelta: 81 });
        });
    });

    describe('get-stats-surface', () => {
        // FROZEN CLOCK, scoped to this describe only — the outer file's own
        // 'heartbeats the PWA session' test (above) already does its own
        // vi.spyOn(Date, 'now').mockRestore() dance around engine.tick(), and nesting a
        // second, differently-scoped fake-timer regime around that would be a needless way
        // to reintroduce exactly the kind of clock interaction this fix removes.
        //
        // Only Date is faked ('toFake: [\'Date\']'): socket.io's own ping/reconnect timers,
        // this file's `waitFor` helper, and the outer file's `vi.waitFor` teardown poll all
        // keep running on REAL timers, so only "what time is it" is under test control, not
        // "how much wall-clock time has passed".
        //
        // WHY THIS WAS NEEDED: the handler's rolling heat window is [now-1h, now) computed
        // from `new Date()` INSIDE the handler at request time (socketAdapter.ts), and `to`
        // in that window IS that `now` — `$lt: to` excludes a row whose timestamp equals it.
        // A BankEvent/StreakEvent seeded with a real `new Date()` a moment before the emit is
        // one millisecond collision away from landing outside that window. Freezing the clock
        // and seeding at a fixed offset removes the race instead of just making it rarer.
        beforeEach(() => {
            vi.useFakeTimers({ toFake: ['Date'] });
            vi.setSystemTime(new Date('2026-08-16T12:00:00Z'));
        });
        afterEach(() => vi.useRealTimers());
        // 30 minutes before the frozen "now": inside the rolling hour window ([11:00, 12:00))
        // and inside the calendar day window (all of 2026-08-16 UTC) at once.
        const IN_WINDOW = new Date('2026-08-16T11:30:00Z');

        it('emits the day records and the hour heat board, same queries as /api/v1/stats', async () => {
            await initPromise;
            const a = await User.create({ deviceId: 'devA', displayName: 'Ayaka' });
            await StreakEvent.create({ userId: a._id, length: 5, endedBy: 'LOSS', endedAt: IN_WINDOW });
            await BankEvent.create({ userId: a._id, amount: 30, timestamp: IN_WINDOW });

            const surfaceP = waitFor<any>(client, 'stats-surface');
            client.emit('get-stats-surface');
            const surface = await surfaceP;

            expect(surface.day.longestStreaks[0]).toMatchObject({ length: 5, endedBy: 'LOSS' });
            expect(surface.day.biggestBanks[0]).toMatchObject({ amount: 30 });
            expect(surface.heat).toMatchObject({ kind: 'heat', qualified: false });
            expect(surface.heat.leaders[0]).toMatchObject({ earned: 30 });
        });

        // The handler ignores whatever is emitted alongside the event (a caller passing
        // { window: 'week' } gets exactly the same fixed day/hour surface) — this pins that
        // the signature does not pretend otherwise by silently accepting and discarding it.
        it('ignores any payload — the surface is fixed, not caller-selected', async () => {
            await initPromise;
            const surfaceP = waitFor<any>(client, 'stats-surface');
            client.emit('get-stats-surface', { window: 'week' });
            const surface = await surfaceP;
            expect(surface.day).toBeDefined();
            expect(surface.heat.kind).toBe('heat');
        });

        it('never returns a deviceId', async () => {
            const a = await User.create({ deviceId: 'secret-device', displayName: 'Ayaka' });
            await StreakEvent.create({ userId: a._id, length: 5, endedBy: 'LOSS', endedAt: IN_WINDOW });
            await BankEvent.create({ userId: a._id, amount: 30, timestamp: IN_WINDOW });

            const surfaceP = waitFor<any>(client, 'stats-surface');
            client.emit('get-stats-surface');
            const surface = await surfaceP;
            expect(JSON.stringify(surface)).not.toContain('secret-device');
        });
    });
});
