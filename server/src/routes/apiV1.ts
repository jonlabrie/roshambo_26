import express, { Router } from 'express';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { requireApiKey } from '../middleware/apiKey';
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

    return router;
}
