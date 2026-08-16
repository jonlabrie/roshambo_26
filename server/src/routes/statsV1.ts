import { Router } from 'express';
import { Types } from 'mongoose';
import User from '../models/User';
import { longestStreaks, biggestBanks, biggestRounds, heatBoard, playerRates } from '../stats';
import { presentIn } from '../sessions';
import { rollingWindow, calendarDayUTC, calendarWeekUTC, HOUR_MS, DAY_MS, WEEK_MS, QUALIFY, Window } from '../windows';

const LIMIT = 10;

// HEAT gets ROLLING windows, RANK gets CALENDAR ones (see windows.ts). Records are read as
// calendar periods because they are a standing, not form.
function recordsWindow(name: string, now: Date): Window | null {
    if (name === 'day') return calendarDayUTC(now);
    if (name === 'week') return calendarWeekUTC(now);
    if (name === 'all') return { from: new Date(0), to: new Date(now.getTime() + DAY_MS) };
    return null;
}

function heatWindow(name: string, now: Date): Window | null {
    if (name === 'hour') return rollingWindow(now, HOUR_MS);
    if (name === 'day') return rollingWindow(now, DAY_MS);
    if (name === 'week') return rollingWindow(now, WEEK_MS);
    return null;
}

// NAME THE PLAYERS HERE. Every board returns user ids; resolving them once server-side saves
// the caller a second round trip, and — more importantly — keeps the projection in ONE place,
// so `deviceId` (a bearer credential on the socket path) cannot leak into an API response by
// someone adding a field to a shared list.
async function nameUsers(ids: Types.ObjectId[]): Promise<Map<string, string>> {
    if (ids.length === 0) return new Map();
    const users = await User.find({ _id: { $in: ids } }).select('displayName');
    return new Map(users.map(u => [u._id.toString(), u.displayName || 'Anonymous']));
}

export function createStatsV1(): Router {
    const router = Router();

    router.get('/records', async (req, res) => {
        try {
            const w = recordsWindow(String(req.query.window ?? ''), new Date());
            if (!w) {
                res.status(400).json({ error: 'BAD_WINDOW', accepts: ['day', 'week', 'all'] });
                return;
            }
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
            const w = heatWindow(String(req.query.window ?? ''), new Date());
            if (!w) {
                res.status(400).json({ error: 'BAD_WINDOW', accepts: ['hour', 'day', 'week'] });
                return;
            }
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
    router.get('/player/:robloxUserId', async (req, res) => {
        try {
            const w = calendarWeekUTC(new Date());
            const user = await User.findOne({ robloxId: String(req.params.robloxUserId) }).select('_id displayName currentStreak bestStreak lifetimeBanked');
            if (!user) {
                res.status(404).json({ error: 'NOT_FOUND' });
                return;
            }
            const rates = await playerRates(user._id, w, QUALIFY.week);
            res.set('Cache-Control', 'private, max-age=15');
            res.json({
                displayName: user.displayName || 'Anonymous',
                career: {
                    banked: user.lifetimeBanked ?? 0,
                    bestStreak: user.bestStreak ?? 0,
                },
                currentStreak: user.currentStreak ?? 0,
                week: rates,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    return router;
}
