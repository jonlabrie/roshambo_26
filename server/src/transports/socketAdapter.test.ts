import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach } from 'vitest';
import { createServer, Server as HttpServer } from 'http';
import { Server } from 'socket.io';
import { io as clientIo, Socket as ClientSocket } from 'socket.io-client';
import { AddressInfo } from 'net';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { attachSocketAdapter } from './socketAdapter';

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

    afterEach(() => { client.disconnect(); httpServer.close(); });

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
        // ticks: 2->1, 1->0 closes round (settlement), TALLY 1->0 starts REVEAL (broadcast)

        const reveal = await revealP;
        expect(reveal).toMatchObject({ worldThrow: 'S', totalPlayers: 1, distribution: { R: 100, P: 0, S: 0 } });
        expect(typeof reveal.id).toBe('string');

        const pd = await playerDataP;
        expect(pd.lastResult).toEqual({ result: 'WIN', delta: 1 });
        expect(pd.user).toMatchObject({ pointsAtStake: 1, currentStreak: 1 });
        expect(Array.isArray(pd.history)).toBe(true);
    });

    it('buffers a throw submitted during REVEAL and enters it next round', async () => {
        await initPromise;
        client.emit('sync-player', { deviceId: 'devA' });
        await waitFor(client, 'player-data');

        // OPEN and LOCK both accept submissions now — only REVEAL rejects (and buffers).
        for (let i = 0; i < 3; i++) engine.tick(); // OPEN -> LOCK -> REVEAL
        client.emit('submit-throw', { deviceId: 'devA', throw: 'P' });
        await new Promise(r => setTimeout(r, 50));

        for (let i = 0; i < 1; i++) engine.tick(); // REVEAL -> next OPEN (replay drains the buffer)
        const playerDataP = waitFor<any>(client, 'player-data');
        for (let i = 0; i < 3; i++) { engine.tick(); await new Promise(r => setTimeout(r, 20)); } // close round 2
        const pd = await playerDataP;
        expect(pd.lastResult.result).toBe('LOSS'); // round 2 world is S; P loses to S
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
});
