import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Round from './models/Round';
import authRouter from './routes/auth';
import storeRouter from './routes/store';
import { mountRoutes } from './routes/mount';
import { RoundEngine } from './engine/RoundEngine';
import { ResultsStore } from './engine/ResultsStore';
import { attachSocketAdapter } from './transports/socketAdapter';
import { Throw, deriveWorldThrow } from './engine/GameRules';
import { closeStaleSessions, SESSION_HEARTBEAT_MS } from './sessions';
import { testModePhaseShift } from './testModeCycle';

dotenv.config();

const TEST_MODE = process.env.TEST_MODE === 'true';
const PORT = process.env.PORT || 3001;
const MONGODB_URI = process.env.MONGODB_URI;

// Presence heartbeats run at SESSION_HEARTBEAT_MS (sessions.ts) — a separate cadence from
// the Roblox throw flush, which is 5s / 10 picks. Four missed heartbeats is long enough to
// survive a hiccup, short enough that a crashed game server does not inflate presence for
// long. Derived from the heartbeat rather than written out, so changing one cannot leave a
// sweep that fires before the first heartbeat lands.
const STALE_SESSION_MS = 4 * SESSION_HEARTBEAT_MS;
// How often the sweep runs. Independent of the staleness window: this is the sweep's own
// polling cadence, not the grace period a session gets before being considered stale.
const STALE_SESSION_SWEEP_INTERVAL_MS = 60 * 1000;

console.log(`[SYS] Roshambo Server Init. TEST_MODE: ${TEST_MODE}`);

if (!MONGODB_URI) {
    console.error('[FATAL] MONGODB_URI is not defined in .env!');
    process.exit(1);
}
console.log(`[SYS] Target Database: ${MONGODB_URI.replace(/:([^@]+)@/, ':****@')}`);
if (!process.env.API_KEY) {
    console.warn('[SYS] API_KEY not set - /api/v1 will return 503 until configured.');
}

const app = express();
app.use(cors({ origin: true, credentials: true, allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key'] }));
app.use(express.json());

const THROWS: Throw[] = ['R', 'P', 'S'];

// Round durations, env-overridable so a short test round and the 60s launch round
// differ by config rather than by commit — a duration edit used to mean a push, and
// a push auto-deploys the dev App Runner service under any live Studio session.
//
// The DEFAULTS ARE THE LAUNCH VALUES: OPEN 51 + LOCK 2 + REVEAL 7 = a 60s round.
// REVEAL's 7 is derived (3.45s drum settle + 3.0s glyph hold + 0.4s fade = 6.85) and
// does not scale with round length; LOCK's 2 is an HTTP flush window, likewise fixed.
// Lengthening a round therefore means lengthening OPEN and nothing else.
function envPositiveNumber(name: string, fallback: number): number {
    const raw = process.env[name];
    if (raw === undefined) return fallback;
    const n = Number(raw);
    if (!Number.isFinite(n) || n <= 0) {
        console.warn(`[SYS] ${name}="${raw}" is not a positive number - using ${fallback}`);
        return fallback;
    }
    return n;
}

function makeEngine(initialRoundCount: number, testCycleShift = 0): RoundEngine {
    const openSeconds = envPositiveNumber('ROUND_OPEN_SECONDS', 51);
    const lockSeconds = envPositiveNumber('ROUND_LOCK_SECONDS', 2);
    const revealSeconds = envPositiveNumber('ROUND_REVEAL_SECONDS', 7);
    // Below this many throws the crowd is too small to be a "world" and the rule falls
    // back to random; tunable without a deploy because the right number depends on how
    // many players are actually online.
    const worldThrowMinParticipants = envPositiveNumber('WORLD_THROW_MIN_PARTICIPANTS', 5);
    console.log(`[SYS] round: OPEN ${openSeconds}s / LOCK ${lockSeconds}s / REVEAL ${revealSeconds}s`);
    console.log(`[SYS] world throw: ${TEST_MODE ? 'TEST_MODE cycle R->P->S' : `crowd plurality, min ${worldThrowMinParticipants} participants`}`);
    return new RoundEngine({
        openSeconds,
        lockSeconds,
        revealSeconds,
        // THE WORLD THROW IS THE CROWD (defect (h), 2026-08-16). TEST_MODE keeps the
        // deterministic R->P->S cycle so dev and the demo stay predictable; everywhere
        // else it is derived from the round's own tally. See GameRules.deriveWorldThrow.
        pickWorldThrow: (roundCount, counts) =>
            TEST_MODE
                ? THROWS[(roundCount + testCycleShift) % 3]
                : deriveWorldThrow(counts, { minParticipants: worldThrowMinParticipants }),
        makeRoundId: () => Math.random().toString(36).substring(2, 9),
        nowMs: () => Date.now(),
    }, initialRoundCount);
}

const store = new ResultsStore(); // see TAPE_LENGTH — must exceed what /state advertises

app.use('/auth', authRouter);
app.use('/store', storeRouter);

const httpServer = createServer(app);
const io = new Server(httpServer, {
    cors: { origin: true, methods: ['GET', 'POST'], credentials: true },
});

mongoose.connect(MONGODB_URI, { serverSelectionTimeoutMS: 5000 })
    .then(async () => {
        console.log(`[SYS] Connected to MongoDB: ${mongoose.connection.host}/${mongoose.connection.name}`);
        const lastRounds = await Round.find().sort({ timestamp: -1 }).limit(10);
        store.seed(lastRounds.map(r => ({
            id: r.id, worldThrow: r.worldThrow as Throw, distribution: r.distribution,
            totalPlayers: r.totalPlayers, timestamp: r.timestamp,
        })));
        const totalRounds = await Round.countDocuments();
        // Defect (e): the TEST_MODE cycle continues from the last face a player actually SAW
        // (the newest persisted round), not from the document count -- a deploy mid-session no
        // longer re-rolls the phase and lands the same face twice. lastRounds is already the
        // newest-first fetch the tape seeds from.
        const cycleShift = TEST_MODE ? testModePhaseShift(lastRounds[0]?.worldThrow, totalRounds) : 0;
        const engine = makeEngine(totalRounds, cycleShift); // legacy roundCount continuity
        // The '/api/v1' mounts, in the order they must be registered — see mountRoutes for
        // why that order is load-bearing. Extracted so the mount-order test binds to this
        // exact function instead of re-declaring the order alongside it.
        mountRoutes(app, engine, store);
        attachSocketAdapter(io, engine, store);
        httpServer.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
            setInterval(() => engine.tick(), 1000);
            // Close sessions whose reporter went silent. See STALE_SESSION_MS /
            // STALE_SESSION_SWEEP_INTERVAL_MS above for why these values.
            setInterval(() => {
                closeStaleSessions(new Date(Date.now() - STALE_SESSION_MS))
                    .catch(err => console.error('Stale session sweep failed:', (err as Error).message));
            }, STALE_SESSION_SWEEP_INTERVAL_MS);
        });
    })
    .catch(err => {
        console.error('[FATAL] MongoDB connection failed:', (err as Error).message);
        process.exit(1);
    });
