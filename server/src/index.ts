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

const TEST_MODE = process.env.TEST_MODE === 'true';
console.log(`[SYS] Roshambo Server Init. TEST_MODE: ${TEST_MODE}`);

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

async function resolveUser(identifier: { userId?: string, deviceId?: string }) {
    if (!dbConnected) return null;

    let user = null;

    // 1. Try Authenticated User First
    if (identifier.userId) {
        user = await User.findById(identifier.userId);
        if (user) {
            // Greedy Cleanup: If we also have a deviceId, ensure it's not tied to some other stale guest record
            if (identifier.deviceId) {
                const collisions = await User.find({
                    deviceId: identifier.deviceId,
                    _id: { $ne: user._id }
                });
                if (collisions.length > 0) {
                    console.log(`[SYNC-CLEANUP] Removing deviceId ${identifier.deviceId} from ${collisions.length} stale records to favor Auth User ${user._id}`);
                    await User.updateMany(
                        { deviceId: identifier.deviceId, _id: { $ne: user._id } },
                        { $unset: { deviceId: 1 } }
                    );
                }
            }
            return user;
        }
    }

    // 2. Fallback to Device ID (Guest)
    if (identifier.deviceId) {
        // Find all records claiming this deviceId, sorted by most recently updated
        const records = await User.find({ deviceId: identifier.deviceId }).sort({ updatedAt: -1 });

        if (records.length > 0) {
            user = records[0];
            // If there are multiple guest records, keep the most recent one as the device owner 
            // and unset the others to avoid "past state" confusion.
            if (records.length > 1) {
                console.warn(`[SYNC-COLLISION] Found ${records.length} records for device ${identifier.deviceId}. Picking most recent (${user._id}).`);
                await User.updateMany(
                    { deviceId: identifier.deviceId, _id: { $ne: user._id } },
                    { $unset: { deviceId: 1 } }
                );
            }
            return user;
        }

        // 3. Create new Guest if none exist
        user = await User.findOneAndUpdate(
            { deviceId: identifier.deviceId },
            { $setOnInsert: { deviceId: identifier.deviceId } },
            { upsert: true, new: true, setDefaultsOnInsert: true }
        );
        return user;
    }

    return null;
}

function calculateResult(player: 'R' | 'P' | 'S', world: string): string {
    if (player === world) return 'SAFE';
    if (
        (player === 'R' && world === 'S') ||
        (player === 'P' && world === 'R') ||
        (player === 'S' && world === 'P')
    ) return 'WIN';
    return 'LOSS';
}

function startLoop() {
    console.log('Starting game loop...');
    setInterval(async () => {
        if (timeLeft > 0) {
            timeLeft--;
        } else {
            // Transition point: End of round
            const TEST_MODE = process.env.TEST_MODE === 'true';
            const counts = { R: 0, P: 0, S: 0 };
            const participants = Array.from(activeRoundThrows.entries());
            participants.forEach(([_, data]) => {
                counts[data.throw]++;
            });

            if (TEST_MODE) {
                const throws: ('R' | 'P' | 'S')[] = ['R', 'P', 'S'];
                lastWorldThrow = throws[roundCount % throws.length];
                console.log(`[TEST_MODE] Deterministic World Throw: ${lastWorldThrow}`);
            } else {
                // Plurality calculation
                if (participants.length > 0) {
                    const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
                    lastWorldThrow = sorted[0][0] as Throw;
                } else {
                    const throws: Throw[] = ['R', 'P', 'S'];
                    lastWorldThrow = throws[Math.floor(Math.random() * throws.length)];
                }
                console.log(`[LIVE_MODE] Plurality World Throw: ${lastWorldThrow} (R:${counts.R}, P:${counts.P}, S:${counts.S})`);
            }
            roundCount++;

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

                // Persist individual player results and update scores
                const playerUpdatePromises = participants.map(async ([deviceId, data]) => {
                    const result = calculateResult(data.throw, roundData.worldThrow);

                    try {
                        const user = await resolveUser({ userId: data.userId, deviceId });

                        if (user) {
                            const oldStake = user.stakingStreak > 0 ? Math.pow(3, user.stakingStreak - 1) : 0;
                            let delta = 0;
                            let update: any = {};

                            if (result === 'WIN') {
                                const nextCurrentStreak = (user.currentStreak || 0) + 1;
                                const nextStakingStreak = (user.stakingStreak || 0) + 1;
                                const nextBestStreak = Math.max(user.bestStreak || 0, nextCurrentStreak);
                                delta = Math.pow(3, nextStakingStreak - 1);

                                update = {
                                    $set: {
                                        currentStreak: nextCurrentStreak,
                                        bestStreak: nextBestStreak,
                                        stakingStreak: nextStakingStreak
                                    }
                                };
                            } else if (result === 'SAFE') {
                                // No state change for SAFE
                            } else if (result === 'LOSS') {
                                delta = -oldStake;
                                update = {
                                    $set: {
                                        currentStreak: 0,
                                        stakingStreak: 0
                                    }
                                };
                            }

                            // Use findByIdAndUpdate for atomic persistence on the specific ID resolved
                            let updatedUser = user;
                            if (Object.keys(update).length > 0) {
                                updatedUser = (await User.findByIdAndUpdate(user._id, update, { new: true })) || user;
                                console.log(`[REVEAL] ${deviceId}: Res=${result}, Points=${updatedUser.totalPoints}, Streak=${updatedUser.currentStreak}`);
                            }

                            console.log(`[REVEAL-RESULT] ${deviceId}: Points=${updatedUser.totalPoints}, Streak=${updatedUser.currentStreak}, Δ=${delta}`);
                            await PlayerRound.create({
                                deviceId,
                                userId: data.userId,
                                roundId,
                                playerThrow: data.throw,
                                playerResult: result,
                                pointsDelta: delta,
                                timestamp: roundData.timestamp
                            });

                            // Emit personalized data back to the socket for responsiveness
                            const personalHistory = await PlayerRound.find({
                                $or: [
                                    { userId: updatedUser._id },
                                    { deviceId: updatedUser.deviceId }
                                ]
                            })
                                .sort({ timestamp: -1 })
                                .limit(30);

                            io.to(deviceId).emit('player-data', { user: updatedUser, history: personalHistory });
                        }
                    } catch (err) {
                        console.error(`Error processing player ${deviceId}:`, (err as Error).message);
                    }
                });

                // Await all player updates before proceeding to broadcast reveal
                await Promise.all(playerUpdatePromises);
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
        socket.join(data.deviceId); // Join a room for this device to allow targeted emits

        if (!dbConnected) {
            socket.emit('player-data', {
                user: { deviceId: data.deviceId, totalPoints: 0, bestStreak: 0, currentStreak: 0, stakingStreak: 0 },
                history: []
            });
            return;
        }
        try {
            const user = await resolveUser({ userId, deviceId: data.deviceId });

            if (!user) {
                console.log(`[SYNC-ERROR] No user found/created for device ${data.deviceId} or userId ${userId}`);
                return;
            }

            // Get last 30 rounds for this player
            const personalHistory = await PlayerRound.find({
                $or: [
                    { userId: user._id },
                    { deviceId: user.deviceId }
                ]
            })
                .sort({ timestamp: -1 })
                .limit(30);

            console.log(`[SYNC-DATA] Sending data to ${data.deviceId}. Points: ${user.totalPoints}, StakeStreak: ${user.stakingStreak}`);
            socket.emit('player-data', { user, history: personalHistory });
        } catch (err) {
            console.error('[SYNC-CRITICAL] Error syncing player:', (err as Error).message);
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

    // Bank Potential Winnings
    socket.on('bank', async (data: { deviceId: string }) => {
        const userId = (socket as any).userId;
        const isAuthenticated = (socket as any).isAuthenticated;

        if (!data.deviceId && !userId) return;
        if (!dbConnected) return;

        try {
            const user = await resolveUser({ userId, deviceId: data.deviceId });

            if (user && user.stakingStreak > 0) {
                const earnings = Math.pow(3, user.stakingStreak - 1);

                // Atomic update for banking on the specific ID resolved
                const updatedUser = await User.findByIdAndUpdate(
                    user._id,
                    {
                        $inc: { totalPoints: earnings },
                        $set: { stakingStreak: 0, currentStreak: 0 }
                    },
                    { new: true }
                );

                if (updatedUser) {
                    // Get last 30 rounds for this player
                    const personalHistory = await PlayerRound.find({
                        $or: [
                            { userId: updatedUser._id },
                            { deviceId: updatedUser.deviceId }
                        ]
                    })
                        .sort({ timestamp: -1 })
                        .limit(30);

                    socket.emit('player-data', { user: updatedUser, history: personalHistory });
                    console.log(`[BANK] User ${data.deviceId} banked ${earnings} pts. Total: ${updatedUser.totalPoints}`);
                }
            }
        } catch (err) {
            console.error('Error banking points:', (err as Error).message);
        }
    });

    // Update Player Progress (Restricted)
    socket.on('update-progress', async (data: {
        deviceId: string,
        displayName?: string
    }) => {
        const userId = (socket as any).userId;
        const isAuthenticated = (socket as any).isAuthenticated;

        if (!data.deviceId && !userId) return;
        if (!dbConnected) return;

        try {
            const user = await resolveUser({ userId, deviceId: data.deviceId });
            const update: any = {};
            if (data.displayName) update.displayName = data.displayName;

            if (user && Object.keys(update).length > 0) {
                await User.findByIdAndUpdate(user._id, update);
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
