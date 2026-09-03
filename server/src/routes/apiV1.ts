import express, { Router } from 'express';
import { gradeFor } from '../engine/Milestones';
import { throwsInWindow } from '../stats';
import { rollingWindow, WEEK_MS, QUALIFY } from '../windows';
import { RoundEngine } from '../engine/RoundEngine';
import { TAPE_LENGTH } from '../engine/ResultsStore';
import { ResultsStore } from '../engine/ResultsStore';
import { requireApiKey } from '../middleware/apiKey';
import { resolveUser } from '../identity';
import { bankPot } from '../wallet';
import User, { IUser } from '../models/User';
import { Throw } from '../engine/GameRules';
import { topByCareer } from '../leaderboards';
import { reconcilePresence } from '../sessions';
import { shellStates, SHELL_IDS, LaunchContext, SHELL_PRICES, MORTAR_PRICES } from '../fireworks';
import { validateLoadout, validateSizeClass, validatePadPreferences, validateDecorations, validateAccess, validateMortarPlacements } from '../loadout';
import {
    validatePurchase, validateDisplay, PRICES, DEFAULT_TEAHOUSE_LOADOUT,
    Size, EconomyState, appendDecoration, DEFAULT_ACCESS, below,
} from '../economy';

// The only values `auraVisibility` may take. Mirrored in roblox/src/shared/HudPrefs.luau and
// roblox/src/shared/StreakAura.luau; all three fail their own tests if one drifts.
const AURA_VISIBILITIES = ['HIDDEN', 'FRIENDS', 'PUBLIC'];

// Extracted so the shape is testable without a request. Every field is defaulted: no migration
// was run for the 2026-08-02 play-HUD fields, so documents written before them lack the keys.
export function buildProfilePayload(user: IUser) {
    return {
        totalPoints: user.totalPoints,
        pointsAtStake: user.pointsAtStake,
        currentStreak: user.currentStreak,
        stakingStreak: user.stakingStreak,
        bestStreak: user.bestStreak,
        unresolvedWin: user.unresolvedWin ?? false,
        escalationPrompts: user.escalationPrompts ?? true,
        resultSplash: user.resultSplash ?? true,
        statusBars: user.statusBars ?? true,
        auraVisibility: user.auraVisibility ?? 'PUBLIC',
        seenBeats: user.seenBeats ?? [],
        counters: {
            roundsPlayed: user.roundsPlayed ?? 0,
            wins: user.wins ?? 0,
            safes: user.safes ?? 0,
            losses: user.losses ?? 0,
            lifetimeBanked: user.lifetimeBanked ?? 0,
            bestPot: user.bestPot ?? 0,
            throwsR: user.throwsR ?? 0,
            throwsP: user.throwsP ?? 0,
            throwsS: user.throwsS ?? 0,
        },
    };
}

export function createApiV1(engine: RoundEngine, store: ResultsStore): Router {
    const router = express.Router();
    router.use(requireApiKey);

    // Parked defect (o), fixed 2026-09-05: resolveUser UPSERTS on any truthy robloxUserId, so
    // an unvalidated path segment ('%20', a typo, "null") permanently mints a junk User --
    // identity-root pollution the presence route already guards against by hand. One param
    // guard covers every /players/:robloxUserId route: Roblox ids are digits, nothing else
    // reaches a resolver.
    router.param('robloxUserId', (req, res, next, id) => {
        if (typeof id === 'string' && /^\d+$/.test(id)) { next(); return; }
        res.status(400).json({ error: 'BAD_PLAYER_ID' });
    });

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
            tape: store.tape(TAPE_LENGTH),
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
        // REVEAL only. Submissions during LOCK are the whole point of LOCK: player
        // input has closed, but game servers are flushing picks already taken.
        if (snap.phase === 'REVEAL') {
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

    // A game server reports its roster. Called on the same cadence as the throw flush.
    //
    // Cost: unlike every other route here, this does N `resolveUser` identity upserts per
    // request (one per roster entry) rather than one — accepted only because a Roblox
    // instance roster is bounded well under 100 players. Inside reconcilePresence, the
    // open/touch loop is also sequentially awaited, so per-heartbeat latency compounds with
    // roster size. Revisit both if roster caps ever grow.
    router.post('/instances/:instanceId/presence', async (req, res) => {
        try {
            const ids = req.body?.robloxUserIds;
            if (!Array.isArray(ids)) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            // VALIDATE BEFORE resolveUser, which UPSERTS. A blanket String() coercion turns
            // null into the truthy string "null" and mints a User with robloxId: "null" —
            // permanent pollution of the identity root the leaderboards read from, with
            // nothing afterwards able to tell that row apart from a real player. Same shape
            // of guard as POST /bank below. Roblox sends the id as a number, so both forms
            // are accepted; nothing else is.
            //
            // DEDUPED because reconcilePresence snapshots the open sessions before its loop:
            // the same id twice in one roster would open two sessions for one player.
            const seen = new Set<string>();
            for (const raw of ids) {
                if (typeof raw === 'number' && Number.isFinite(raw)) seen.add(String(raw));
                else if (typeof raw === 'string' && raw.trim()) seen.add(raw.trim());
            }
            const users = await Promise.all(
                [...seen].map((robloxUserId: string) => resolveUser({ robloxUserId }))
            );
            const userIds = users.filter((u): u is NonNullable<typeof u> => !!u).map(u => u._id);
            const result = await reconcilePresence(req.params.instanceId, userIds, new Date());
            res.json(result);
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.get('/players/:robloxUserId', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const country = typeof req.query.country === 'string' ? req.query.country : undefined;
            // THE ONLY PLACE A ROBLOX PLAYER'S NAME IS RECORDED. Nothing else on the Roblox path
            // ever wrote `displayName` — it was written by PWA registration and the PWA's
            // update-progress and nowhere else — so every Roblox player's User row had no name
            // and every board naming them fell through to 'Anonymous': the banzuke, records,
            // heat, and the player's own slip. Found 2026-08-18 by the owner reading their own
            // fuda. This is the join-time call every Roblox player already makes, and the name
            // rides it exactly as `country` does.
            //
            // Roblox has already moderated a DisplayName, and the room's broadcast path filters
            // it again through `cachedFilterName` before it reaches a wall, so storing it raw is
            // safe on both counts.
            // THE ONE WINDOWED MILESTONE, awarded here rather than at settlement because it needs a
            // 7-day throw count and settling a round must not run a per-player aggregation for
            // every participant. Checked once per session instead of sixty times an hour. Once
            // earned it is permanent like every other one: a player who qualifies one week and
            // then plays less does not lose it.
            if (!(user.milestones || []).includes('presence.qualified')) {
                const thrown = await throwsInWindow(user._id, rollingWindow(new Date(), WEEK_MS));
                if (thrown >= QUALIFY.week) {
                    await User.findByIdAndUpdate(user._id, { $addToSet: { milestones: 'presence.qualified' } });
                    user.milestones = [...(user.milestones || []), 'presence.qualified'];
                }
            }
            const grade = gradeFor((user.milestones || []).length);

            const name = typeof req.query.name === 'string' ? req.query.name.slice(0, 64) : undefined;
            const set: Record<string, unknown> = {};
            if (country && user.country !== country) set.country = country;
            // Guarded on a NON-EMPTY name: an absent or blank query must never blank a stored
            // one, or a single request without it wipes the board.
            if (name && user.displayName !== name) set.displayName = name;
            if (Object.keys(set).length > 0) {
                await User.findByIdAndUpdate(user._id, { $set: set });
                Object.assign(user, set);
            }
            res.set('Cache-Control', 'no-store');
            res.json({
                robloxUserId: req.params.robloxUserId,
                displayName: user.displayName,
                grade: grade.index,
                gradeName: grade.name,
                band: grade.band,
                milestones: user.milestones || [],
                identityTier: user.identityTier,
                ...buildProfilePayload(user),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/preferences-hud', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: String(req.params.robloxUserId) });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const set: Record<string, unknown> = {};
            if (typeof req.body?.escalationPrompts === 'boolean') {
                set.escalationPrompts = req.body.escalationPrompts;
            }
            if (typeof req.body?.statusBars === 'boolean') {
                set.statusBars = req.body.statusBars;
            }
            if (typeof req.body?.resultSplash === 'boolean') {
                set.resultSplash = req.body.resultSplash;
            }
            // ⚠ VALIDATED AGAINST THE SET, not merely type-checked. Every neighbour here is a
            // boolean, where `typeof` is the whole check; this is a string, and an unrecognised one
            // must be REFUSED rather than written or defaulted. A privacy setting knocked back to a
            // permissive default by a malformed body — or a caller's typo — is worse than a write
            // that does nothing.
            if (AURA_VISIBILITIES.includes(req.body?.auraVisibility)) {
                set.auraVisibility = req.body.auraVisibility;
            }
            // seenBeat is add-only: a beat can be marked seen but never un-seen from the client
            const addToSet = typeof req.body?.seenBeat === 'string'
                ? { seenBeats: req.body.seenBeat } : undefined;
            if (!Object.keys(set).length && !addToSet) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            const updated = await User.findByIdAndUpdate(
                user._id,
                { ...(Object.keys(set).length ? { $set: set } : {}), ...(addToSet ? { $addToSet: addToSet } : {}) },
                { new: true }
            );
            const s = updated ?? user;
            res.json({
                escalationPrompts: s.escalationPrompts ?? true,
                resultSplash: s.resultSplash ?? true,
                seenBeats: s.seenBeats ?? [],
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.get('/players/:robloxUserId/teahouses', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
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
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
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

    const readEconomy = (user: { totalPoints: number; maxDeckSize: Size | null; teahouses?: Map<string, unknown>; portalOwned?: boolean; deckDecorations?: unknown[]; mortars?: string[] }): EconomyState => ({
        totalPoints: user.totalPoints,
        maxDeckSize: user.maxDeckSize,
        teahouseSizes: (user.teahouses ? Array.from(user.teahouses.keys()) : []) as Size[],
        portalOwned: user.portalOwned ?? false,
        deckDecorationCount: user.deckDecorations?.length ?? 0,
        mortars: user.mortars ?? [],
    });

    router.get('/players/:robloxUserId/economy', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
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
                // The client is told PRICES, never requirements. Shells and mortars live in
                // fireworks.ts rather than economy.ts, so they have to be spliced in here — the
                // alternative is a second copy of every price in the Roblox client.
                catalog: { ...PRICES, fireworks: SHELL_PRICES, mortars: MORTAR_PRICES },
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

    router.get('/players/:robloxUserId/fireworks', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const raw = String(req.query.lastWorldThrow ?? '');
            // The CLIENT is never told a requirement — it is told the ANSWER. The Roblox server
            // passes the round it already has; anything else reads as "not Rock", which fails shut.
            const ctx: LaunchContext = {
                mortars: user.mortars ?? [],
                lastWorldThrow: (['R', 'P', 'S'].includes(raw) ? raw : null) as Throw | null,
            };
            const held: Record<string, number> = {};
            for (const id of SHELL_IDS) held[id] = user.fireworks?.get(id) ?? 0;
            res.set('Cache-Control', 'no-store');
            res.json({ shells: shellStates(held, ctx), mortars: ctx.mortars, mortarPlacements: user.mortarPlacements ?? {} });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/fireworks/spend', async (req, res) => {
        try {
            const shellId = req.body?.shellId;
            if (typeof shellId !== 'string' || !SHELL_IDS.includes(shellId as never)) {
                res.status(400).json({ error: 'BAD_SHELL' });
                return;
            }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            // CONDITIONAL $inc, NOT read-modify-write. Two launches racing on one held shell must
            // resolve to exactly one firing: the filter and the decrement are a single atomic
            // operation, so the loser matches no document and gets 409. The existing /purchase
            // route's read-then-save pattern would let both read 1 and both write 0.
            const updated = await User.findOneAndUpdate(
                { _id: user._id, [`fireworks.${shellId}`]: { $gte: 1 } },
                { $inc: { [`fireworks.${shellId}`]: -1 } },
                { new: true }
            );
            if (!updated) { res.status(409).json({ error: 'NONE_HELD' }); return; }
            res.json({ shellId, count: updated.fireworks.get(shellId) ?? 0 });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/purchase', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const item = req.body?.item;
            if (typeof item !== 'string') { res.status(400).json({ error: 'BAD_ITEM' }); return; }
            const before = readEconomy(user);
            const chk = validatePurchase(before, item);
            if (!chk.ok) { res.status(400).json({ error: chk.error }); return; }
            // ONE ATOMIC OP (parked defect (a), fixed 2026-09-05). validatePurchase above is the
            // fast, friendly 400; the FILTER below is the authority: it carries the balance
            // check AND the item's uniqueness (portal unowned, deck tier exactly below,
            // teahouse size absent, mortar unheld) while the update carries the deduction AND
            // the grant -- so two racing purchases resolve to exactly one sale, the loser
            // matching no document. The read-then-save it replaces let both racers read the
            // pre-purchase balance (this file's own /fireworks/spend comment indicted it).
            const filter: Record<string, unknown> = { _id: user._id, totalPoints: { $gte: chk.cost } };
            const inc: Record<string, number> = { totalPoints: -chk.cost };
            const update: Record<string, unknown> = { $inc: inc };
            let respond: (updated: InstanceType<typeof User>) => void;
            if (item.startsWith('firework:')) {
                const shellId = item.slice('firework:'.length);
                inc[`fireworks.${shellId}`] = 1;
                respond = (u) => res.json({ item, totalPoints: u.totalPoints, shellId, count: u.fireworks.get(shellId) ?? 0 });
            } else if (item.startsWith('decoration:')) {
                const { instance } = appendDecoration(user.deckDecorations ?? [], item.slice('decoration:'.length));
                update.$push = { deckDecorations: instance };
                respond = (u) => res.json({ item, totalPoints: u.totalPoints, decoration: instance, deckDecorations: u.deckDecorations });
            } else if (item.startsWith('mortar:')) {
                filter.mortars = { $ne: item };
                update.$push = { mortars: item };
                respond = (u) => {
                    const e = readEconomy(u);
                    res.json({ item, totalPoints: e.totalPoints, maxDeckSize: e.maxDeckSize, teahouseSizes: e.teahouseSizes, portalOwned: e.portalOwned ?? false });
                };
            } else if (item === 'portal') {
                filter.portalOwned = { $ne: true };
                update.$set = { portalOwned: true };
                respond = (u) => {
                    const e = readEconomy(u);
                    res.json({ item, totalPoints: e.totalPoints, maxDeckSize: e.maxDeckSize, teahouseSizes: e.teahouseSizes, portalOwned: true });
                };
            } else if (item === 'starter') {
                // First-property-only, atomically: {maxDeckSize: null} matches absent too, so a
                // racing second starter (or a racing deck:S) matches no document and 409s.
                filter.maxDeckSize = null;
                update.$set = { maxDeckSize: 'S', 'teahouses.S': { ...DEFAULT_TEAHOUSE_LOADOUT } };
                respond = (u) => {
                    const e = readEconomy(u);
                    res.json({ item, totalPoints: e.totalPoints, maxDeckSize: e.maxDeckSize, teahouseSizes: e.teahouseSizes, portalOwned: e.portalOwned ?? false });
                };
            } else {
                const [kind, size] = item.split(':') as [string, Size];
                if (kind === 'deck') {
                    filter.maxDeckSize = below(size); // exactly the tier below, atomically ({maxDeckSize: null} matches absent too)
                    update.$set = { maxDeckSize: size };
                } else {
                    filter[`teahouses.${size}`] = { $exists: false };
                    update.$set = { [`teahouses.${size}`]: { ...DEFAULT_TEAHOUSE_LOADOUT } };
                }
                respond = (u) => {
                    const e = readEconomy(u);
                    res.json({ item, totalPoints: e.totalPoints, maxDeckSize: e.maxDeckSize, teahouseSizes: e.teahouseSizes, portalOwned: e.portalOwned ?? false });
                };
            }
            const updated = await User.findOneAndUpdate(filter, update, { new: true });
            if (!updated) { res.status(409).json({ error: 'CONFLICT' }); return; }
            respond(updated);
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/display', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
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
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
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
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const decorations = req.body?.decorations;
            // Ownership against the STORED instances (parked defect (b)): rearrange/remove only,
            // never mint -- new instances enter through /purchase alone.
            const check = validateDecorations(decorations, user.deckDecorations ?? []);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.deckDecorations = decorations;
            await user.save();
            res.json({ deckDecorations: user.deckDecorations });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/mortar-placements', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const placements = req.body?.placements;
            const check = validateMortarPlacements(placements, user.mortars ?? []);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.mortarPlacements = placements;
            user.markModified('mortarPlacements');
            await user.save();
            res.json({ mortarPlacements: user.mortarPlacements });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/access', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
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
            // `keep` is what stays riding; absent means a full bank, which is what every client
            // shipped before partial banking sends. An invalid keep is rejected inside bankPot
            // and surfaces as the same 409 as "nothing staked" — from the caller's side both
            // mean "the bank you asked for did not happen".
            const keep = Number(req.body?.keep ?? 0);
            const user = await resolveUser({ robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await bankPot(user._id.toString(), 'roblox', keep);
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
            // One projection, and it carries no deviceId on any transport — see leaderboards.ts.
            // here. See leaderboards.ts.
            const leaders = await topByCareer(filter, 50);
            res.set('Cache-Control', 'public, max-age=30');
            res.json({ scope, leaders });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    return router;
}
