import express, { Router } from 'express';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { requireApiKey } from '../middleware/apiKey';
import { resolveUser } from '../identity';
import { bankPot } from '../wallet';
import User from '../models/User';
import { Throw } from '../engine/GameRules';

export function createApiV1(engine: RoundEngine, store: ResultsStore): Router {
    const router = express.Router();
    router.use(requireApiKey);

    router.get('/state', (_req, res) => {
        const snap = engine.snapshot();
        const now = Date.now();
        // no-store, NOT public/max-age: this response carries per-request clock
        // fields (serverTime/phaseEndsAt) consumed by min-RTT clock sync. A shared
        // cache would serve stale clocks with near-zero RTT — which the min-RTT
        // selector would then PREFER. The herd-safe cacheable read is
        // /rounds/:id/result; /state is only polled ~1/round + drift checks.
        res.set('Cache-Control', 'no-store');
        res.json({
            roundId: snap.roundId,
            phase: snap.phase,
            phaseEndsAt: now + snap.secondsLeft * 1000,
            serverTime: now,
            roundCount: snap.roundCount,
            tape: store.tape(10),
        });
    });

    router.get('/rounds/:roundId/result', (req, res) => {
        const round = store.getGlobal(req.params.roundId);
        if (!round) { res.status(404).json({ error: 'RESULT_NOT_READY' }); return; }
        res.set('Cache-Control', 'public, max-age=10');
        res.json(round);
    });

    router.post('/throws', (req, res) => {
        const { instanceId, roundId, seq, throws } = req.body ?? {};
        if (!instanceId || !roundId || typeof seq !== 'number' || !Array.isArray(throws)) {
            res.status(400).json({ error: 'BAD_REQUEST' });
            return;
        }
        const snap = engine.snapshot();
        if (roundId !== snap.roundId) {
            res.status(409).json({ error: 'ROUND_MISMATCH', currentRoundId: snap.roundId });
            return;
        }
        if (snap.phase !== 'ACTIVE') {
            res.status(409).json({ error: 'PICKS_CLOSED' });
            return;
        }
        const rejected: { robloxUserId: string; reason: string }[] = [];
        let accepted = 0;
        for (const t of throws) {
            const robloxUserId = String(t?.robloxUserId ?? '');
            if (!robloxUserId || !['R', 'P', 'S'].includes(t?.throw)) {
                rejected.push({ robloxUserId: robloxUserId || 'unknown', reason: 'BAD_THROW' });
                continue;
            }
            const r = engine.submitThrow(`roblox:${robloxUserId}`, {
                throw: t.throw as Throw, seq, platform: 'roblox', robloxUserId, instanceId,
            });
            if (r.accepted) accepted++;
            else rejected.push({ robloxUserId, reason: r.reason! });
        }
        res.status(202).json({ accepted, rejected });
    });

    router.get('/instances/:instanceId/rounds/:roundId/results', (req, res) => {
        const results = store.getInstance(req.params.roundId, req.params.instanceId);
        if (!results) { res.status(404).json({ error: 'RESULTS_NOT_READY' }); return; }
        res.set('Cache-Control', 'no-store');
        res.json(results.map(({ user, ...rest }) => rest));
    });

    router.get('/players/:robloxUserId', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const country = typeof req.query.country === 'string' ? req.query.country : undefined;
            if (country && user.country !== country) {
                await User.findByIdAndUpdate(user._id, { $set: { country } });
            }
            res.set('Cache-Control', 'no-store');
            res.json({
                robloxUserId: req.params.robloxUserId,
                displayName: user.displayName,
                totalPoints: user.totalPoints,
                pointsAtStake: user.pointsAtStake,
                currentStreak: user.currentStreak,
                stakingStreak: user.stakingStreak,
                bestStreak: user.bestStreak,
                identityTier: user.identityTier,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/bank', async (req, res) => {
        try {
            const robloxUserId = String(req.body?.robloxUserId ?? '');
            if (!robloxUserId) { res.status(400).json({ error: 'BAD_REQUEST' }); return; }
            const user = await resolveUser({ robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await bankPot(user._id.toString());
            if (!updated) { res.status(409).json({ error: 'NOTHING_STAKED' }); return; }
            res.json({
                totalPoints: updated.totalPoints,
                pointsAtStake: updated.pointsAtStake,
                stakingStreak: updated.stakingStreak,
                currentStreak: updated.currentStreak,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.get('/leaderboards', async (req, res) => {
        try {
            const scope = req.query.scope;
            if (scope !== 'world' && scope !== 'country') {
                res.status(400).json({ error: 'BAD_SCOPE' });
                return;
            }
            if (scope === 'country' && !String(req.query.country ?? '').trim()) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            const filter = scope === 'country'
                ? { country: String(req.query.country) }
                : {};
            const leaders = await User.find(filter)
                .sort({ totalPoints: -1 })
                .limit(50)
                .select('displayName totalPoints robloxId identityTier currentStreak bestStreak');
            res.set('Cache-Control', 'public, max-age=30');
            res.json({ scope, leaders });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    return router;
}
