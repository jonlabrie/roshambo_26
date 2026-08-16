import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { RoundEngine, ThrowEntry } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { settleRound, SettledPlayer } from '../engine/Settlement';
import { resolveUser } from '../identity';
import { bankPot } from '../wallet';
import User from '../models/User';
import Round from '../models/Round';
import PlayerRound from '../models/PlayerRound';
import { Throw } from '../engine/GameRules';
import { topByCareer } from '../leaderboards';
import { openSession, closeSession } from '../sessions';

const JWT_SECRET = process.env.JWT_SECRET || 'roshambo_super_secret_1337';

async function personalHistory(user: { _id: unknown; deviceId?: string }) {
    return PlayerRound.find({
        $or: [{ userId: user._id }, { deviceId: user.deviceId }],
    }).sort({ timestamp: -1 }).limit(30);
}

export function attachSocketAdapter(io: Server, engine: RoundEngine, store: ResultsStore): void {
    let seqCounter = 0;
    // PWA submits arriving during REVEAL are held for the next round
    // (the legacy server accepted submits at any time; this preserves intent).
    const pendingNextRound = new Map<string, ThrowEntry>();
    // roundClosed is async (DB writes); revealStarted now fires on the SAME
    // transition, synchronously after it — the gap that used to be a full TALLY
    // tick is zero. That is safe, and always was: these guards make whichever of
    // the two finishes last perform the emit, which is why the two seconds could
    // be deleted without anything else moving.
    let revealPending: string | null = null; // roundId awaiting reveal broadcast
    const settledRounds = new Set<string>();

    function broadcastReveal(roundId: string): void {
        const round = store.getGlobal(roundId);
        if (round) io.emit('reveal', round);
    }

    // --- auth middleware (moved verbatim from index.ts:52-64) ---
    io.use((socket, next) => {
        const token = socket.handshake.auth.token;
        if (token) {
            try {
                const decoded = jwt.verify(token, JWT_SECRET) as { id: string };
                (socket as any).userId = decoded.id;
                (socket as any).isAuthenticated = true;
            } catch {
                console.log('Socket Auth failed: Invalid token');
            }
        }
        next();
    });

    // --- engine wiring ---
    engine.on('tick', snap => {
        io.emit('sync', {
            phase: snap.phase,
            timeLeft: snap.phase === 'OPEN' ? snap.secondsLeft : 0,
            roundCount: snap.roundCount,
            playerCount: io.engine.clientsCount,
        });
    });

    engine.on('roundClosed', async data => {
        try {
            const { round, players } = await settleRound({ ...data, timestamp: new Date() });
            store.storeRound(round, players);
            settledRounds.add(round.id);
            if (settledRounds.size > 50) {
                // bound the dedup set — only the in-flight round matters
                settledRounds.delete(settledRounds.values().next().value!);
            }
            await Promise.all(players.filter(p => p.platform === 'pwa').map(async (p: SettledPlayer) => {
                const history = await personalHistory(p.user);
                io.to(p.deviceId!).emit('player-data', {
                    user: p.user,
                    history,
                    lastResult: { result: p.result, delta: p.delta },
                });
            }));
            // player-data must reach each device BEFORE the arena-wide reveal broadcast
            // (CLAUDE.md's documented emit order) — emit it only after the loop above.
            if (revealPending === round.id) {
                revealPending = null;
                broadcastReveal(round.id);
            }
        } catch (err) {
            console.error('[SETTLE] round settlement failed:', (err as Error).message);
        }
    });

    engine.on('revealStarted', ({ roundId }: { roundId: string }) => {
        if (settledRounds.has(roundId)) {
            broadcastReveal(roundId); // settlement already stored the round — emit now
        } else {
            revealPending = roundId; // settlement still in flight — emit when it lands
        }
    });

    engine.on('roundStarted', () => {
        for (const [key, entry] of pendingNextRound) engine.submitThrow(key, entry);
        pendingNextRound.clear();
    });

    // --- per-connection handlers ---
    io.on('connection', (socket: Socket) => {
        let sessionId: string | null = null;

        // The PWA attaches its 'init' listener BEFORE connecting, so this single
        // synchronous emit preserves the production wire contract exactly.
        const snap = engine.snapshot();
        socket.emit('init', {
            phase: snap.phase,
            timeLeft: snap.phase === 'OPEN' ? snap.secondsLeft : 0,
            roundCount: snap.roundCount,
            history: store.tape(10),
            // The reveal's length, so the client's result overlay can hold for exactly
            // as long as the phase lasts. It used to be a literal in useGameLoop.ts and
            // silently went stale when the server changed (3s -> 5s -> 7s).
            revealMs: engine.durationsMs().revealMs,
            // OPEN's length, so the PieTimer's countdown ring is calibrated to the
            // actual phase duration instead of a stale literal (same reasoning as revealMs).
            openMs: engine.durationsMs().openMs,
        });

        // Player Persistence Sync (ported verbatim from index.ts:364-401)
        socket.on('sync-player', async (data: { deviceId: string }) => {
            const userId = (socket as any).userId;
            const isAuthenticated = (socket as any).isAuthenticated;

            if (!data.deviceId && !userId) return;
            socket.join(data.deviceId); // Join a room for this device to allow targeted emits

            try {
                const user = await resolveUser({ userId, deviceId: data.deviceId });

                if (!user) {
                    console.log(`[SYNC-ERROR] No user found/created for device ${data.deviceId} or userId ${userId}`);
                    return;
                }

                // One session per connection. sync-player is the first point at which the socket
                // is attached to a resolved user, so it is where presence starts.
                if (!sessionId && user) {
                    sessionId = (await openSession({ userId: user._id, platform: 'pwa' }))._id.toString();
                }

                // Get last 30 rounds for this player
                const history = await personalHistory(user);

                console.log(`[SYNC-DATA] ${data.deviceId} (ID: ${user._id}): Pts=${user.totalPoints}, Pot=${user.pointsAtStake}, Streak=${user.stakingStreak}`);
                socket.emit('player-data', { user, history });
            } catch (err) {
                console.error('[SYNC-CRITICAL] Error syncing player:', (err as Error).message);
                // Resilience fallback: keep the client unblocked even if the DB read fails.
                socket.emit('player-data', {
                    user: { deviceId: data.deviceId, totalPoints: 0, bestStreak: 0, currentStreak: 0, stakingStreak: 0 },
                    history: []
                });
            }
        });

        socket.on('submit-throw', (data: { deviceId: string; throw: Throw }) => {
            if (!data?.deviceId || !['R', 'P', 'S'].includes(data.throw)) return;
            const entry: ThrowEntry = {
                throw: data.throw, seq: ++seqCounter, platform: 'pwa',
                deviceId: data.deviceId, userId: (socket as any).userId,
            };
            const key = `pwa:${data.deviceId}`;
            const r = engine.submitThrow(key, entry);
            if (!r.accepted && r.reason === 'PICKS_CLOSED') pendingNextRound.set(key, entry);
        });

        // Statistics & Leaderboards (ported verbatim from index.ts:413-461)
        socket.on('get-stats', async (data: { timeframe: 'hour' | 'day' | 'week' | 'all' }) => {
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

                // 2. Highest CAREER earnings (Top 50 - All Time). Was totalPoints, which is a
                // spendable wallet — see leaderboards.ts.
                const topPoints = await topByCareer({}, 50);

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

        socket.on('bank', async (data: { deviceId: string }) => {
            const userId = (socket as any).userId;
            if (!data?.deviceId && !userId) return;
            try {
                const user = await resolveUser({ userId, deviceId: data.deviceId });
                if (!user) return;
                const updated = await bankPot(user._id.toString(), 'pwa');
                if (updated) {
                    socket.emit('player-data', { user: updated, history: await personalHistory(updated) });
                }
            } catch (err) {
                console.error('Error banking points:', (err as Error).message);
            }
        });

        // Update Player Progress (Restricted) (ported verbatim from index.ts:510-531)
        socket.on('update-progress', async (data: { deviceId: string; displayName?: string }) => {
            const userId = (socket as any).userId;
            const isAuthenticated = (socket as any).isAuthenticated;

            if (!data.deviceId && !userId) return;

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

        socket.on('disconnect', async () => {
            if (sessionId) {
                await closeSession(sessionId, new Date());
                sessionId = null;
            }
        });
    });
}
