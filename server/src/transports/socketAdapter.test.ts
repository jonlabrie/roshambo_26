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
import { SESSION_HEARTBEAT_MS } from '../sessions';

let httpServer: HttpServer;
let engine: RoundEngine;
let client: ClientSocket;
let initPromise: Promise<any>;

function waitFor<T>(socket: ClientSocket, event: string): Promise<T> {
    return new Promise(resolve => socket.once(event, resolve));
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
        client.emit('sync-player', { deviceId: 'devA' });
        await waitFor(client, 'player-data');

        client.emit('submit-throw', { deviceId: 'devA', throw: 'R' }); // R beats S -> WIN
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
        client.emit('sync-player', { deviceId: 'devA' });
        await waitFor(client, 'player-data'); // initial sync-player reply, not part of the round broadcast

        client.emit('submit-throw', { deviceId: 'devA', throw: 'R' }); // R beats S -> WIN
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
        client.emit('sync-player', { deviceId: 'devA' });
        await waitFor(client, 'player-data');

        // OPEN and LOCK both accept submissions now — only REVEAL rejects (and buffers).
        for (let i = 0; i < 3; i++) engine.tick(); // OPEN -> LOCK -> REVEAL
        client.emit('submit-throw', { deviceId: 'devA', throw: 'P' });
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
        client.emit('sync-player', { deviceId: 'devA' });
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
        await User.create({ deviceId: 'devA', totalPoints: 1, pointsAtStake: 9 });
        client.emit('sync-player', { deviceId: 'devA' });
        await waitFor(client, 'player-data');

        const updated = waitFor<any>(client, 'player-data');
        client.emit('bank', { deviceId: 'devA' });
        expect((await updated).user).toMatchObject({ totalPoints: 10, pointsAtStake: 0 });
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
