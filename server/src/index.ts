import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Round from './models/Round';
import authRouter from './routes/auth';
import storeRouter from './routes/store';
import { createApiV1 } from './routes/apiV1';
import { RoundEngine } from './engine/RoundEngine';
import { ResultsStore } from './engine/ResultsStore';
import { attachSocketAdapter } from './transports/socketAdapter';
import { Throw } from './engine/GameRules';

dotenv.config();

const TEST_MODE = process.env.TEST_MODE === 'true';
const PORT = process.env.PORT || 3001;
const MONGODB_URI = process.env.MONGODB_URI;

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

function makeEngine(initialRoundCount: number): RoundEngine {
    return new RoundEngine({
        activeSeconds: 20,
        tallySeconds: 2,
        revealSeconds: 3,
        pickWorldThrow: roundCount =>
            TEST_MODE ? THROWS[roundCount % 3] : THROWS[Math.floor(Math.random() * 3)],
        makeRoundId: () => Math.random().toString(36).substring(2, 9),
        nowMs: () => Date.now(),
    }, initialRoundCount);
}

const store = new ResultsStore(5);

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
        const engine = makeEngine(totalRounds); // legacy roundCount continuity
        app.use('/api/v1', createApiV1(engine, store));
        attachSocketAdapter(io, engine, store);
        httpServer.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
            setInterval(() => engine.tick(), 1000);
        });
    })
    .catch(err => {
        console.error('[FATAL] MongoDB connection failed:', (err as Error).message);
        process.exit(1);
    });
