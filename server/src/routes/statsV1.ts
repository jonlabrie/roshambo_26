import { Router } from 'express';
import { Types } from 'mongoose';
import User from '../models/User';
import { longestStreaks, biggestBanks, biggestRounds, heatBoard, playerRates, nameUsers, qualifiedBoard, playerStanding, bankDepths, median, depthHistogram } from '../stats';
import { presentIn } from '../sessions';
import { rollingWindow, calendarDayUTC, calendarWeekUTC, HOUR_MS, DAY_MS, WEEK_MS, QUALIFY, Window } from '../windows';

const LIMIT = 10;

// HEAT and the RATE BOARD get ROLLING windows; RECORDS get CALENDAR ones (see windows.ts).
// Records are read as calendar periods because "the biggest bank of the day" names a day. The
// rate board was calendar too until the owner ruled otherwise (2026-08-18): a Monday boundary
// wipes a run that started Sunday evening, so rolling rewards dropping in at any hour.
//
// WHICH IS WHY THE WIRE CARRIES BOTH THE KIND AND THE BOUNDS. `window=day` means two
// different periods on the two endpoints — the UTC calendar day on /records, the last 24
// hours on /heat — and a label alone cannot tell them apart, so a display rendering "Today"
// from both would silently show two different periods under one heading. `windowKind` names
// which rule was applied and `from`/`to` are the resolved half-open bounds themselves, so a
// display can print the actual period rather than infer it.
export type WindowKind = 'calendar' | 'rolling';

interface ResolvedWindow {
    window: Window;
    kind: WindowKind;
}

function recordsWindow(name: string, now: Date): ResolvedWindow | null {
    if (name === 'day') return { window: calendarDayUTC(now), kind: 'calendar' };
    if (name === 'week') return { window: calendarWeekUTC(now), kind: 'calendar' };
    // 'all' is ROLLING, not calendar: its upper bound is derived from `now` rather than from
    // a period boundary players could name, so it moves with every request.
    if (name === 'all') {
        return { window: { from: new Date(0), to: new Date(now.getTime() + DAY_MS) }, kind: 'rolling' };
    }
    return null;
}

function heatWindow(name: string, now: Date): ResolvedWindow | null {
    if (name === 'hour') return { window: rollingWindow(now, HOUR_MS), kind: 'rolling' };
    if (name === 'day') return { window: rollingWindow(now, DAY_MS), kind: 'rolling' };
    if (name === 'week') return { window: rollingWindow(now, WEEK_MS), kind: 'rolling' };
    return null;
}

export function createStatsV1(): Router {
    const router = Router();

    router.get('/records', async (req, res) => {
        try {
            const resolved = recordsWindow(String(req.query.window ?? ''), new Date());
            if (!resolved) {
                res.status(400).json({ error: 'BAD_WINDOW', accepts: ['day', 'week', 'all'] });
                return;
            }
            const w = resolved.window;
            const [streaks, banks, rounds] = await Promise.all([
                longestStreaks(w, LIMIT),
                biggestBanks(w, LIMIT),
                biggestRounds(w, LIMIT),
            ]);
            const names = await nameUsers([
                ...streaks.map(r => r.userId),
                ...banks.map(r => r.userId),
                ...rounds.map(r => r.userId),
            ]);
            const name = (id: Types.ObjectId) => names.get(id.toString()) ?? 'Anonymous';
            res.set('Cache-Control', 'public, max-age=30');
            res.json({
                window: String(req.query.window),
                windowKind: resolved.kind,
                from: w.from.toISOString(),
                to: w.to.toISOString(),
                longestStreaks: streaks.map(r => ({ displayName: name(r.userId), length: r.length, endedBy: r.endedBy })),
                biggestBanks: banks.map(r => ({ displayName: name(r.userId), amount: r.amount, streakAtBank: r.streakAtBank })),
                biggestRounds: rounds.map(r => ({ displayName: name(r.userId), points: r.pointsDelta })),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.get('/heat', async (req, res) => {
        try {
            const resolved = heatWindow(String(req.query.window ?? ''), new Date());
            if (!resolved) {
                res.status(400).json({ error: 'BAD_WINDOW', accepts: ['hour', 'day', 'week'] });
                return;
            }
            const w = resolved.window;
            const instanceId = String(req.query.instanceId ?? '').trim();
            const scope = instanceId ? await presentIn(instanceId) : undefined;
            const rows = await heatBoard(w, LIMIT, scope);
            const names = await nameUsers(rows.map(r => r.userId));
            res.set('Cache-Control', 'public, max-age=15');
            res.json({
                // FORM, NOT STANDING. The wire says so, so a display cannot quietly present a
                // lucky hour as a ranking (spec §3).
                kind: 'heat',
                qualified: false,
                window: String(req.query.window),
                windowKind: resolved.kind,
                from: w.from.toISOString(),
                to: w.to.toISOString(),
                scope: instanceId || 'global',
                leaders: rows.map(r => ({ displayName: names.get(r.userId.toString()) ?? 'Anonymous', earned: r.earned })),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    // PERSONAL-FIRST. The room reads the viewer before it reads the world (spec §6), so this
    // is the endpoint the entry slips use. It returns the qualification threshold alongside
    // the figures, so a display can honestly show "142 / 350 throws" rather than a blank.
    // THE READ GATE, AND WHY IT IS OPERATIONAL RATHER THAN PER-ROUND. Under TEST_MODE the World
    // Throw is a fixed R->P->S cycle, so a win rate measures who spotted the pattern and nothing
    // else — actively misleading, not merely imprecise. The honest version records per-round
    // whether the throw was derived from the crowd or fell back, and that needs a `Round` schema
    // field plus a per-row join; it belongs to the "make the world real" work, which is out of
    // scope for this plan. Until then this one flag withholds the column wholesale.
    //
    // Read per REQUEST, not at module load: a deploy that flips TEST_MODE must not need a second
    // one to make the column appear.
    const worldIsCrowd = () => process.env.TEST_MODE !== 'true';

    router.get('/board', async (req, res) => {
        try {
            // ROLLING seven days, matching /player below. If these two ever disagree a player
            // qualifies on the wall and not on their own slip, or the reverse.
            const w = rollingWindow(new Date(), WEEK_MS);
            const minThrows = Number(req.query.minThrows) || QUALIFY.week;
            const rows = await qualifiedBoard(w, minThrows, LIMIT);
            const names = await nameUsers(rows.map(r => r.userId));
            const open = worldIsCrowd();
            res.set('Cache-Control', 'public, max-age=30');
            res.json({
                window: { from: w.from, to: w.to },
                windowKind: 'rolling' as WindowKind,
                // The REAL floor, never the `minThrows` override a caller passed: this is the
                // number printed on the board as the rule, and a test override must not become
                // a promise to players.
                minThrows: QUALIFY.week,
                worldIsCrowd: open,
                // Projected field by field. `BoardRow` carries a userId and a raw name lookup;
                // neither belongs on a client, and a spread here would put both there the day
                // someone adds a field to BoardRow.
                rows: rows.map(r => ({
                    displayName: names.get(String(r.userId)) ?? 'Anonymous',
                    pointsPerThrow: r.pointsPerThrow,
                    winRate: open ? r.winRate : null,
                    throws: r.throws,
                })),
                // FIVE buckets, because the board that shows them is six rows and the last row is the
                // title. Folding at 5+ is honest: a blind player who rides past 7 banks nothing at
                // all, so the deep tail is thin by construction rather than by cropping.
                depths: depthHistogram(await bankDepths(w), 5),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.get('/player/:robloxUserId', async (req, res) => {
        try {
            const w = rollingWindow(new Date(), WEEK_MS);
            const user = await User.findOne({ robloxId: String(req.params.robloxUserId) }).select('_id displayName currentStreak bestStreak lifetimeBanked');
            if (!user) {
                res.status(404).json({ error: 'NOT_FOUND' });
                return;
            }
            const rates = await playerRates(user._id, w, QUALIFY.week);
            const [nerve, standing] = await Promise.all([
                bankDepths(w, user._id).then(median),
                playerStanding(user._id, w, QUALIFY.week),
            ]);
            res.set('Cache-Control', 'private, max-age=15');
            res.json({
                displayName: user.displayName || 'Anonymous',
                career: {
                    banked: user.lifetimeBanked ?? 0,
                    bestStreak: user.bestStreak ?? 0,
                },
                currentStreak: user.currentStreak ?? 0,
                week: { ...rates, winRate: worldIsCrowd() ? rates.winRate : null, nerve, standing },
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    return router;
}
