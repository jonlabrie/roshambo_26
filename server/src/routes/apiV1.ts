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
        res.set('Cache-Control', 'public, max-age=1');
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

    return router;
}
