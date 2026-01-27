import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import Round from './models/Round';
import User from './models/User';
import PlayerRound from './models/PlayerRound';
import authRouter from './routes/auth';
import storeRouter from './routes/store';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());
app.use('/auth', authRouter);
app.use('/store', storeRouter);

const httpServer = createServer(app);
const io = new Server(httpServer, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const PORT = process.env.PORT || 3001;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/roshambo';
const JWT_SECRET = process.env.JWT_SECRET || 'roshambo_super_secret_1337';

// Socket Middleware for Authentication
io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (token) {
        try {
            const decoded = jwt.verify(token, JWT_SECRET) as any;
            (socket as any).userId = decoded.id;
            (socket as any).isAuthenticated = true;
        } catch (err) {
            console.log('Socket Auth failed: Invalid token');
        }
    }
    next();
});

let dbConnected = false;

// Connect to MongoDB with timeout
mongoose.connect(MONGODB_URI, {
    serverSelectionTimeoutMS: 5000,
})
    .then(() => {
        console.log('Connected to MongoDB');
        dbConnected = true;
        initializeState();
    })
    .catch(err => {
        console.error('MongoDB connection error (running in memory mode):', (err as Error).message);
    });

// Constants
const ROUND_TIME = 20;

// Game State
type Throw = 'R' | 'P' | 'S' | null;

let timeLeft = ROUND_TIME;
let roundCount = 0;
let lastWorldThrow: Throw = null;
let history: any[] = [];
const activeRoundThrows = new Map<string, { throw: 'R' | 'P' | 'S', userId?: string }>();

// Initialize state from DB
async function initializeState() {
    if (!dbConnected) return;
    try {
        const lastRounds = await Round.find().sort({ timestamp: -1 }).limit(10);
        history = lastRounds.map(r => ({
            id: r.id,
            worldThrow: r.worldThrow,
            distribution: r.distribution,
            totalPlayers: r.totalPlayers,
            timestamp: r.timestamp
        }));

        const totalRounds = await Round.countDocuments();
        roundCount = totalRounds;
        console.log(`State initialized from DB. History: ${history.length}, Total rounds: ${roundCount}`);
    } catch (err) {
        console.error('Error initializing state:', (err as Error).message);
    }
}

function calculateResult(player: 'R' | 'P' | 'S', world: string): string {
    if (player === world) return 'LOSS';
    if (
        (player === 'R' && world === 'S') ||
        (player === 'P' && world === 'R') ||
        (player === 'S' && world === 'P')
    ) return 'WIN';
    return 'SAFE';
}

function startLoop() {
    console.log('Starting game loop...');
    setInterval(async () => {
        if (timeLeft > 0) {
            timeLeft--;
        } else {
            // Transition point: End of round
            const throws: ('R' | 'P' | 'S')[] = ['R', 'P', 'S'];
            lastWorldThrow = throws[roundCount % throws.length];
            roundCount++;

            // Calculate real distribution
            const counts = { R: 0, P: 0, S: 0 };
            const participants = Array.from(activeRoundThrows.entries());
            participants.forEach(([_, data]) => {
                counts[data.throw]++;
            });

            const totalParticipants = participants.length;
            const distribution = totalParticipants > 0 ? {
                R: Math.round((counts.R / totalParticipants) * 100),
                P: Math.round((counts.P / totalParticipants) * 100),
                S: Math.round((counts.S / totalParticipants) * 100)
            } : { R: 33, P: 33, S: 33 };

            const roundId = Math.random().toString(36).substring(2, 9);
            const roundData = {
                id: roundId,
                worldThrow: lastWorldThrow as string,
                distribution,
                totalPlayers: totalParticipants,
                timestamp: new Date()
            };

            // Persist round metadata
            if (dbConnected) {
                Round.create(roundData).catch(err => console.error('Error saving round:', (err as Error).message));

                // Persist individual player results
                for (const [deviceId, data] of participants) {
                    const result = calculateResult(data.throw, roundData.worldThrow);

                    PlayerRound.create({
                        deviceId,
                        userId: data.userId,
                        roundId,
                        playerThrow: data.throw,
                        playerResult: result,
                        timestamp: roundData.timestamp
                    }).catch(err => console.error('Error saving player round:', (err as Error).message));
                }
            }

            activeRoundThrows.clear();
            history = [roundData, ...history].slice(0, 10);
            io.emit('reveal', roundData);

            // Immediately reset for next round
            timeLeft = ROUND_TIME;
        }

        // Continuous heartbeat for all clients
        io.emit('sync', {
            phase: 'ACTIVE',
            timeLeft,
            roundCount,
            playerCount: io.engine.clientsCount
        });
    }, 1000);
}

io.on('connection', (socket) => {
    // Initial sync
    socket.emit('init', {
        phase: 'ACTIVE',
        timeLeft,
        roundCount,
        history
    });

    // Player Persistence Sync
    socket.on('sync-player', async (data: { deviceId: string }) => {
        const userId = (socket as any).userId;
        const isAuthenticated = (socket as any).isAuthenticated;

        if (!data.deviceId && !userId) return;
        if (!dbConnected) {
            socket.emit('player-data', {
                user: { deviceId: data.deviceId, totalPoints: 0, bestStreak: 0, currentStreak: 0, stakingStreak: 0 },
                history: []
            });
            return;
        }
        try {
            let user;
            if (isAuthenticated && userId) {
                user = await User.findById(userId);
            } else {
                user = await User.findOne({ deviceId: data.deviceId });
                if (!user && data.deviceId) {
                    user = await User.create({ deviceId: data.deviceId });
                    console.log('Created new user for device:', data.deviceId);
                }
            }

            if (!user) return;

            // Get last 30 rounds for this player
            const personalHistory = await PlayerRound.find({
                $or: [
                    { userId: user._id },
                    { deviceId: user.deviceId }
                ]
            })
                .sort({ timestamp: -1 })
                .limit(30);

            socket.emit('player-data', { user, history: personalHistory });
        } catch (err) {
            console.error('Error syncing player:', (err as Error).message);
        }
    });

    // Record Throw
    socket.on('submit-throw', (data: { deviceId: string, throw: 'R' | 'P' | 'S' }) => {
        if (!data.deviceId || !data.throw) return;
        activeRoundThrows.set(data.deviceId, {
            throw: data.throw,
            userId: (socket as any).userId
        });
    });

    // Statistics & Leaderboards
    socket.on('get-stats', async (data: { timeframe: 'hour' | 'day' | 'week' | 'all' }) => {
        if (!dbConnected) return;
        const timeframeMs = {
            hour: 60 * 60 * 1000,
            day: 24 * 60 * 60 * 1000,
            week: 7 * 24 * 60 * 60 * 1000,
            all: Date.now() // irrelevant for $match
        };
        const cutoff = new Date(Date.now() - timeframeMs[data.timeframe]);

        try {
            // 1. Global Distribution for timeframe
            const distribution = await Round.aggregate([
                { $match: data.timeframe === 'all' ? {} : { timestamp: { $gte: cutoff } } },
                {
                    $group: {
                        _id: null,
                        avgR: { $avg: "$distribution.R" },
                        avgP: { $avg: "$distribution.P" },
                        avgS: { $avg: "$distribution.S" },
                        totalRounds: { $sum: 1 }
                    }
                }
            ]);

            // 2. Highest Point Totals (Top 50 - All Time)
            const topPoints = await User.find()
                .sort({ totalPoints: -1 })
                .limit(50)
                .select('deviceId displayName totalPoints currentStreak bestStreak');

            // 3. Biggest Single Wins for timeframe (Only >= 3 points, Top 50)
            const biggestWins = await PlayerRound.find({
                ...(data.timeframe === 'all' ? {} : { timestamp: { $gte: cutoff } }),
                pointsDelta: { $gte: 3 }
            })
                .sort({ pointsDelta: -1 })
                .limit(50);

            socket.emit('stats-data', {
                timeframe: data.timeframe,
                globalDistribution: distribution[0] || { avgR: 33, avgP: 33, avgS: 33, totalRounds: 0 },
                topPoints,
                biggestWins
            });
        } catch (err) {
            console.error('Error fetching stats:', (err as Error).message);
        }
    });

    // Update Player Progress
    socket.on('update-progress', async (data: {
        deviceId: string,
        totalPoints: number,
        bestStreak: number,
        currentStreak: number,
        stakingStreak: number,
        lastRoundId?: string,
        lastPointsDelta?: number
    }) => {
        const userId = (socket as any).userId;
        const isAuthenticated = (socket as any).isAuthenticated;

        if (!data.deviceId && !userId) return;
        if (!dbConnected) return;

        try {
            const query = (isAuthenticated && userId) ? { _id: userId } : { deviceId: data.deviceId };
            await User.findOneAndUpdate(
                query,
                {
                    totalPoints: data.totalPoints,
                    bestStreak: data.bestStreak,
                    currentStreak: data.currentStreak,
                    stakingStreak: data.stakingStreak
                }
            );

            // If we have round result info, update or delete the history record
            if (data.lastRoundId && data.lastPointsDelta !== undefined) {
                if (data.lastPointsDelta < 3) {
                    // Stop persisting small payouts/losses to save space
                    await PlayerRound.deleteOne({
                        deviceId: data.deviceId,
                        roundId: data.lastRoundId
                    });
                } else {
                    await PlayerRound.findOneAndUpdate(
                        { deviceId: data.deviceId, roundId: data.lastRoundId },
                        { pointsDelta: data.lastPointsDelta }
                    );
                }
            }
        } catch (err) {
            console.error('Error updating progress:', (err as Error).message);
        }
    });
});

httpServer.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    initializeState().then(() => startLoop());
});
