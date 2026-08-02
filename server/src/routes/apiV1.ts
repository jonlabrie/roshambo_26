import express, { Router } from 'express';
import { RoundEngine } from '../engine/RoundEngine';
import { ResultsStore } from '../engine/ResultsStore';
import { requireApiKey } from '../middleware/apiKey';
import { resolveUser } from '../identity';
import { bankPot, resolveWin } from '../wallet';
import User from '../models/User';
import { Throw } from '../engine/GameRules';
import { validateLoadout, validateSizeClass, validatePadPreferences, validateDecorations, validateAccess } from '../loadout';
import {
    validatePurchase, applyPurchase, validateDisplay, PRICES, DEFAULT_TEAHOUSE_LOADOUT,
    Size, EconomyState, appendDecoration, DEFAULT_ACCESS,
} from '../economy';

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
            phaseEndsAt: snap.phaseEndsAtMs ?? now + snap.secondsLeft * 1000,
            serverTime: now,
            durations: engine.durationsMs(),
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

    router.get('/players/:robloxUserId/teahouses', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            res.set('Cache-Control', 'no-store');
            const teahouses = user.teahouses ? Object.fromEntries(user.teahouses as Map<string, unknown>) : {};
            res.json({ teahouses, padPreferences: user.padPreferences ?? [] });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/teahouses/:sizeClass', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const sizeClass = req.params.sizeClass;
            const loadout = req.body?.loadout;
            const existing = user.teahouses ? Array.from((user.teahouses as Map<string, unknown>).keys()) : [];
            const sc = validateSizeClass(sizeClass, existing);
            if (!sc.ok) { res.status(400).json({ error: sc.error }); return; }
            const ld = validateLoadout(loadout);
            if (!ld.ok) { res.status(400).json({ error: ld.error }); return; }
            // teahouses is always a MongooseMap (schema default {} applies on insert + lazily on read),
            // so .set() tracks the mutation for save() — no fallback/markModified needed.
            (user.teahouses as Map<string, unknown>).set(sizeClass, loadout);
            await user.save();
            res.json({ sizeClass, loadout });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    const readEconomy = (user: { totalPoints: number; maxDeckSize: Size | null; teahouses?: Map<string, unknown>; portalOwned?: boolean; deckDecorations?: unknown[] }): EconomyState => ({
        totalPoints: user.totalPoints,
        maxDeckSize: user.maxDeckSize,
        teahouseSizes: (user.teahouses ? Array.from(user.teahouses.keys()) : []) as Size[],
        portalOwned: user.portalOwned ?? false,
        deckDecorationCount: user.deckDecorations?.length ?? 0,
    });

    router.get('/players/:robloxUserId/economy', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            res.set('Cache-Control', 'no-store');
            const st = readEconomy(user);
            const teahouses = user.teahouses ? Object.fromEntries(user.teahouses as Map<string, unknown>) : {};
            // superset: the single join fetch — balance + tiers + teahouse LOADOUTS (server needs
            // them to build) + preferences + the price catalog for the client.
            res.json({
                totalPoints: st.totalPoints,
                maxDeckSize: st.maxDeckSize,
                teahouses,
                teahouseSizes: st.teahouseSizes,
                padPreferences: user.padPreferences ?? [],
                catalog: PRICES,
                deckDisplay: user.deckDisplay ?? null,
                teahouseDisplay: user.teahouseDisplay ?? null,
                portalOwned: st.portalOwned ?? false,
                deckDecorations: user.deckDecorations ?? [],
                teahouseAccess: user.teahouseAccess ?? DEFAULT_ACCESS,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/purchase', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const item = req.body?.item;
            if (typeof item !== 'string') { res.status(400).json({ error: 'BAD_ITEM' }); return; }
            const before = readEconomy(user);
            const chk = validatePurchase(before, item);
            if (!chk.ok) { res.status(400).json({ error: chk.error }); return; }
            const after = applyPurchase(before, item);
            user.totalPoints = after.totalPoints;
            user.maxDeckSize = after.maxDeckSize;
            user.portalOwned = after.portalOwned ?? false;
            if (item.startsWith('decoration:')) {
                const propId = item.slice('decoration:'.length);
                const { list, instance } = appendDecoration(user.deckDecorations ?? [], propId);
                user.deckDecorations = list;
                await user.save();
                res.json({ item, totalPoints: after.totalPoints, decoration: instance, deckDecorations: list });
                return;
            }
            const [kind, size] = item.split(':') as [string, Size];
            if (kind === 'teahouse') {
                (user.teahouses as Map<string, unknown>).set(size, { ...DEFAULT_TEAHOUSE_LOADOUT });
            }
            await user.save();
            res.json({ item, totalPoints: after.totalPoints, maxDeckSize: after.maxDeckSize, teahouseSizes: after.teahouseSizes, portalOwned: after.portalOwned ?? false });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/display', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const chk = validateDisplay(readEconomy(user), req.body?.deckDisplay ?? null, req.body?.teahouseDisplay ?? null);
            if (!chk.ok) { res.status(400).json({ error: chk.error }); return; }
            user.deckDisplay = chk.deckDisplay;
            user.teahouseDisplay = chk.teahouseDisplay;
            await user.save();
            res.json({ deckDisplay: chk.deckDisplay, teahouseDisplay: chk.teahouseDisplay });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/preferences', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const padPreferences = req.body?.padPreferences;
            const check = validatePadPreferences(padPreferences);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.padPreferences = padPreferences as string[];
            await user.save();
            res.json({ padPreferences: user.padPreferences });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/decorations', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const decorations = req.body?.decorations;
            const check = validateDecorations(decorations);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.deckDecorations = decorations;
            await user.save();
            res.json({ deckDecorations: user.deckDecorations });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/access', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const access = req.body?.access;
            const check = validateAccess(access);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.teahouseAccess = access;
            await user.save();
            res.json({ teahouseAccess: user.teahouseAccess });
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

    router.post('/resolve-win', async (req, res) => {
        try {
            const robloxUserId = String(req.body?.robloxUserId ?? '');
            const choice = req.body?.choice;
            if (!robloxUserId || (choice !== 'risk' && choice !== 'bank')) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            const user = await resolveUser({ robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await resolveWin(user._id.toString(), choice);
            // A null here means the player was not bound — already resolved, or a duplicate tap.
            // That is not an error; echo current state so the client converges either way.
            const state = updated ?? user;
            res.json({
                totalPoints: state.totalPoints,
                pointsAtStake: state.pointsAtStake,
                stakingStreak: state.stakingStreak,
                currentStreak: state.currentStreak,
                unresolvedWin: state.unresolvedWin ?? false,
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
