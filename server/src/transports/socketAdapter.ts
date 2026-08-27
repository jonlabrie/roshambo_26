import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';
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
import { openSession, closeSession, touchSessions, SESSION_HEARTBEAT_MS } from '../sessions';
import { longestStreaks, biggestBanks, heatBoard, nameUsers } from '../stats';
import { calendarDayUTC, rollingWindow, HOUR_MS } from '../windows';

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
    // PWA PRESENCE HEARTBEAT. A Roblox session has its lastSeenAt advanced by the roster
    // endpoint; a PWA socket has no equivalent — `sync-player` fires ONCE per connection — so
    // without this every PWA session sits at its opening lastSeenAt and looks dead. Keyed by
    // socket id, drained on the 1s sync tick below: one bulk write per period for the whole
    // server rather than a timer and a write per connected socket.
    const heartbeats = new Map<string, { sessionId: string; lastTouchedMs: number }>();

    function broadcastReveal(roundId: string): void {
        const round = store.getGlobal(roundId);
        if (round) io.emit('reveal', round);
    }

    // --- auth middleware (moved verbatim from index.ts:52-64) ---
    //
    // IDENTITY COMES FROM THE CONNECTION, NEVER FROM A PAYLOAD (2026-08-18).
    //
    // Until this landed, four handlers resolved an account straight out of `data.deviceId`:
    // sync-player read it, submit-throw threw as it, update-progress renamed it, and bank
    // CASHED OUT ITS POT. A deviceId is an identifier — it lives in localStorage, travels in
    // support screenshots and over shoulders — and it was being used as a password, so anyone
    // who learned one string owned that account outright. The JWT path beside it was already
    // done correctly, and that asymmetry was the whole bug.
    //
    // A device now proves itself the same way a user does: a signed token on the handshake.
    // Putting it on the CONNECTION rather than in each message is the part that closes the
    // class rather than four instances of it — a future handler cannot be handed an account
    // name, because messages no longer carry one.
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
        const deviceToken = socket.handshake.auth.deviceToken;
        if (deviceToken) {
            try {
                // `typ` is checked explicitly so a USER token — same secret, different claim
                // set — can never be replayed as a device, and vice versa.
                const d = jwt.verify(deviceToken, JWT_SECRET) as { typ?: string; did?: string };
                if (d.typ === 'device' && d.did) (socket as any).deviceId = d.did;
            } catch {
                console.log('Socket Auth failed: Invalid device token');
            }
        }
        next();
    });

    // --- engine wiring ---
    // ONE CLOCK FOR BOTH CLIENTS (owner, 2026-08-17). The Roblox path has always been handed an
    // ABSOLUTE phase boundary and slews against it (RoundScheduleConfig -> RoundMetronome). The
    // PWA got only `timeLeft`: an integer decremented once per server tick, with no timestamp to
    // correct client drift against, and forced to 0 outside OPEN so the countdown went blind for
    // the last third of every round. Pointed at the same backend the two still disagreed.
    //
    // `phaseEndsAtMs` and `serverTimeMs` travel TOGETHER on purpose: a client cannot use an
    // absolute deadline without knowing the server's idea of now, because its own clock may be
    // minutes off. The pair gives it an offset it can hold and a deadline to subtract from.
    // `timeLeft` stays on the wire -- the deployed PWA and this server do not ship together.
    const clockFields = (snap: ReturnType<typeof engine.snapshot>) => {
        const now = Date.now();
        return {
            // Same fallback apiV1 uses: the engine only populates phaseEndsAtMs when it was
            // given a `nowMs`, and an engine built without one must still publish a usable
            // deadline rather than an undefined the client would render as NaN.
            phaseEndsAtMs: snap.phaseEndsAtMs ?? now + snap.secondsLeft * 1000,
            serverTimeMs: now,
            durations: engine.durationsMs(),
        };
    };

    engine.on('tick', snap => {
        io.emit('sync', {
            phase: snap.phase,
            timeLeft: snap.phase === 'OPEN' ? snap.secondsLeft : 0,
            roundCount: snap.roundCount,
            playerCount: io.engine.clientsCount,
            ...clockFields(snap),
        });

        // Piggybacked on the sync broadcast, but throttled to SESSION_HEARTBEAT_MS per
        // session — a write a second per player would cost far more than the presence data
        // is worth.
        const nowMs = Date.now();
        const due: string[] = [];
        for (const entry of heartbeats.values()) {
            if (nowMs - entry.lastTouchedMs >= SESSION_HEARTBEAT_MS) {
                entry.lastTouchedMs = nowMs;
                due.push(entry.sessionId);
            }
        }
        if (due.length > 0) {
            touchSessions(due, new Date(nowMs))
                .catch(err => console.error('Session heartbeat failed:', (err as Error).message));
        }
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
            // revealMs/openMs above are the same numbers `durations` carries; they predate it
            // and stay because the deployed client reads them by those names.
            ...clockFields(snap),
        });

        // A NEW GUEST, NAMED BY THE SERVER. The client used to invent its own deviceId and
        // the server took it on faith, so an "identity" was whatever string arrived. Here the
        // id is minted with the token that authenticates it, and the pair goes back once.
        //
        // Deliberately NOT a migration path: an existing deviceId cannot be presented for
        // adoption, because a stolen one would be adopted just as readily. The owner ruled a
        // hard cut on 2026-08-18 — guest points and streaks from before this change are
        // orphaned rather than handed to whoever asks for them first.
        socket.on('claim-device', async () => {
            try {
                const deviceId = randomUUID();
                const user = await resolveUser({ deviceId });
                if (!user) return;
                (socket as any).deviceId = deviceId;
                socket.join(deviceId);
                const deviceToken = jwt.sign({ typ: 'device', did: deviceId }, JWT_SECRET);
                socket.emit('device-claimed', { deviceId, deviceToken });
            } catch (err) {
                console.error('[CLAIM-ERROR]', (err as Error).message);
            }
        });

        // Player Persistence Sync (ported verbatim from index.ts:364-401)
        socket.on('sync-player', async () => {
            const userId = (socket as any).userId;
            const deviceId = (socket as any).deviceId;

            if (!deviceId && !userId) {
                // Not a silent no-op: the client's cue to claim a device and try again.
                socket.emit('device-required');
                return;
            }
            if (deviceId) socket.join(deviceId); // targeted emits land here

            try {
                const user = await resolveUser({ userId, deviceId });

                if (!user) {
                    console.log(`[SYNC-ERROR] No user found/created for device ${deviceId} or userId ${userId}`);
                    return;
                }

                // One session per connection. sync-player is the first point at which the socket
                // is attached to a resolved user, so it is where presence starts.
                if (!sessionId && user) {
                    sessionId = (await openSession({ userId: user._id, platform: 'pwa' }))._id.toString();
                    heartbeats.set(socket.id, { sessionId, lastTouchedMs: Date.now() });
                }

                // Get last 30 rounds for this player
                const history = await personalHistory(user);

                console.log(`[SYNC-DATA] ${deviceId ?? userId} (ID: ${user._id}): Pts=${user.totalPoints}, Pot=${user.pointsAtStake}, Streak=${user.stakingStreak}`);
                socket.emit('player-data', { user, history });
            } catch (err) {
                console.error('[SYNC-CRITICAL] Error syncing player:', (err as Error).message);
                // Resilience fallback: keep the client unblocked even if the DB read fails.
                socket.emit('player-data', {
                    user: { deviceId, totalPoints: 0, bestStreak: 0, currentStreak: 0, stakingStreak: 0 },
                    history: []
                });
            }
        });

        // The payload carries the THROW and nothing else. Any `deviceId` a client still sends
        // (an older build, mid-rollout) is ignored rather than trusted.
        socket.on('submit-throw', (data: { throw: Throw }) => {
            const deviceId = (socket as any).deviceId;
            const userId = (socket as any).userId;
            if ((!deviceId && !userId) || !['R', 'P', 'S'].includes(data?.throw)) return;
            const entry: ThrowEntry = {
                throw: data.throw, seq: ++seqCounter, platform: 'pwa',
                deviceId, userId,
            };
            const key = `pwa:${deviceId ?? userId}`;
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

                // 3. Biggest Single Wins for timeframe (Only >= 3 points, Top 50).
                // PROJECTED EXPLICITLY. This used to emit whole PlayerRound documents, which
                // carry `deviceId` — a bearer credential on this transport — to any connected
                // socket. Selecting fields by name means a column added to PlayerRound later
                // cannot silently join a public payload.
                const winRows = await PlayerRound.find({
                    ...(data.timeframe === 'all' ? {} : { timestamp: { $gte: cutoff } }),
                    pointsDelta: { $gte: 3 }
                })
                    .sort({ pointsDelta: -1 })
                    .limit(50)
                    .select('userId pointsDelta timestamp');

                // Resolve names server-side so the client has something to label a row with now
                // that it no longer receives a deviceId to truncate.
                const winNames = await nameUsers(
                    winRows.map(r => r.userId).filter((id): id is NonNullable<typeof id> => !!id)
                );
                const biggestWins = winRows.map(r => ({
                    _id: r._id,
                    userId: r.userId,
                    displayName: r.userId ? winNames.get(r.userId.toString()) ?? 'Anonymous' : 'Anonymous',
                    pointsDelta: r.pointsDelta,
                    timestamp: r.timestamp,
                }));

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

        // The Stats room's surface, for the PWA. Same queries as /api/v1/stats — the wire
        // shapes differ because the transports do, but the numbers come from one place.
        //
        // Takes no argument: the surface is a fixed day-records + hour-heat bundle, not
        // caller-selected by window, so a signature that accepted and silently discarded a
        // `{ window }` payload would lie about what it honours (a caller passing
        // { window: 'week' } would silently get the day board back).
        socket.on('get-stats-surface', async () => {
            try {
                const now = new Date();
                const w = calendarDayUTC(now);
                const heat = rollingWindow(now, HOUR_MS);
                const [streaks, banks, hot] = await Promise.all([
                    longestStreaks(w, 10),
                    biggestBanks(w, 10),
                    heatBoard(heat, 10),
                ]);
                socket.emit('stats-surface', {
                    day: { longestStreaks: streaks, biggestBanks: banks },
                    heat: { kind: 'heat', qualified: false, leaders: hot },
                });
            } catch (err) {
                console.error('Error fetching stats surface:', (err as Error).message);
            }
        });

        // ⚠ THE PAYLOAD IS NOT A CREDENTIAL. deviceId is a bearer credential on this transport,
        // so identity comes from the SOCKET and `keep` is the only field read from the wire.
        // An invalid keep is rejected inside bankPot, which returns null and emits nothing.
        socket.on('bank', async (data?: { keep?: number }) => {
            const userId = (socket as any).userId;
            const deviceId = (socket as any).deviceId;
            if (!deviceId && !userId) return;
            try {
                const user = await resolveUser({ userId, deviceId });
                if (!user) return;
                const keep = Number(data?.keep ?? 0);
                const updated = await bankPot(user._id.toString(), 'pwa', keep);
                if (updated) {
                    socket.emit('player-data', { user: updated, history: await personalHistory(updated) });
                }
            } catch (err) {
                console.error('Error banking points:', (err as Error).message);
            }
        });

        // Update Player Progress (Restricted) (ported verbatim from index.ts:510-531)
        socket.on('update-progress', async (data: { displayName?: string }) => {
            const userId = (socket as any).userId;
            const deviceId = (socket as any).deviceId;

            if (!deviceId && !userId) return;

            try {
                const user = await resolveUser({ userId, deviceId });
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
            heartbeats.delete(socket.id);
            if (!sessionId) return;
            const closing = sessionId;
            sessionId = null;
            try {
                await closeSession(closing, new Date());
            } catch (err) {
                // Unhandled here would be fatal: node terminates the process on an unhandled
                // rejection, so a transient Mongo blip at socket close would take the game
                // server down. The session is left open instead and the sweep is not scoped to
                // it, so it is repaired by hand or not at all — still the cheaper failure.
                console.error('Error closing session:', (err as Error).message);
            }
        });
    });
}
