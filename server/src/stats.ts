import { Types } from 'mongoose';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import User from './models/User';
import { Window } from './windows';
import { earningsInWindow } from './leaderboards';
import { roundsPresent } from './sessions';

// RECORDS — discrete, verifiable events with no sample-size problem, so short windows are
// legitimate and exciting (spec §4.1). These are the boards that work on launch day with
// fifty players, unlike any rate.

export interface StreakRow {
    userId: Types.ObjectId;
    length: number;
    endedBy: 'SAFE' | 'LOSS';
    endedAt: Date;
}

export async function longestStreaks(w: Window, limit: number): Promise<StreakRow[]> {
    const rows = await StreakEvent.find({ endedAt: { $gte: w.from, $lt: w.to } })
        .sort({ length: -1, endedAt: 1 })
        .limit(limit)
        .select('userId length endedBy endedAt');
    return rows.map(r => ({ userId: r.userId, length: r.length, endedBy: r.endedBy, endedAt: r.endedAt }));
}

export interface BankRow {
    userId: Types.ObjectId;
    amount: number;
    streakAtBank: number;
    timestamp: Date;
}

export async function biggestBanks(w: Window, limit: number): Promise<BankRow[]> {
    const rows = await BankEvent.find({ timestamp: { $gte: w.from, $lt: w.to } })
        .sort({ amount: -1, timestamp: 1 })
        .limit(limit)
        .select('userId amount streakAtBank timestamp');
    return rows.map(r => ({ userId: r.userId, amount: r.amount, streakAtBank: r.streakAtBank, timestamp: r.timestamp }));
}

export interface RoundRow {
    userId: Types.ObjectId;
    pointsDelta: number;
    timestamp: Date;
}

// WIN ROWS ONLY. On a WIN, `pointsDelta` is the pot REACHED that round, which is exactly the
// "biggest single round" figure. On a LOSS it is a negative forfeit and on a SAFE it is zero —
// neither belongs on a records board, and including LOSS rows would put the worst round in the
// game at the bottom of a list titled "biggest".
export async function biggestRounds(w: Window, limit: number): Promise<RoundRow[]> {
    const rows = await PlayerRound.find({
        playerResult: 'WIN',
        timestamp: { $gte: w.from, $lt: w.to },
    })
        .sort({ pointsDelta: -1, timestamp: 1 })
        .limit(limit)
        .select('userId pointsDelta timestamp');
    return rows.map(r => ({ userId: r.userId, pointsDelta: r.pointsDelta, timestamp: r.timestamp }));
}

// VOLUME — rewards commitment rather than skill, needs no qualification, and must be labelled
// as commitment wherever it is shown (spec §4.3).

export async function throwsInWindow(userId: Types.ObjectId, w: Window): Promise<number> {
    return PlayerRound.countDocuments({ userId, timestamp: { $gte: w.from, $lt: w.to } });
}

// READ — the one clean measure of crowd-reading, and the figure QUALIFY was derived for.
// A blind player wins exactly 1/3 of rounds, so anything above 0.333 is edge, and the crowd
// cannot all be above it: the winners in a round are precisely those who threw the counter to
// the plurality, which is by definition not the plurality.
export async function winsInWindow(userId: Types.ObjectId, w: Window): Promise<number> {
    return PlayerRound.countDocuments({
        userId,
        playerResult: 'WIN',
        timestamp: { $gte: w.from, $lt: w.to },
    });
}

// THE ONE PLACE `pointsDelta` MAY BE SUMMED. The column is poisonous for earnings because on a
// WIN it records the new POT rather than the gain — but on a LOSS it is exactly the pot that
// was forfeited, negated. Filtering to LOSS rows is what makes the sum meaningful, so the
// filter is not an optimisation and must never be relaxed.
export async function forfeitsInWindow(userId: Types.ObjectId, w: Window): Promise<number> {
    const [row] = await PlayerRound.aggregate([
        { $match: { userId, playerResult: 'LOSS', timestamp: { $gte: w.from, $lt: w.to } } },
        { $group: { _id: null, lost: { $sum: '$pointsDelta' } } },
    ]);
    return row ? Math.abs(row.lost) : 0;
}

// NERVE — how deep a player rides before collecting. `BankEvent.streakAtBank` was written for
// exactly this: "the whole bank-vs-stake story lives in the distribution of this number".
//
// NOT A LEADERBOARD, deliberately: ranking "who rides deepest" crowns the player who rides past
// their own read and banks nothing, which is a losing strategy wearing a winner's hat. This
// feeds a personal figure and a room-wide histogram, and neither is ranked.
export async function bankDepths(w: Window, userId?: Types.ObjectId): Promise<number[]> {
    // ⚠ FULL BANKS ONLY. A partial bank is a hedge, not a decision to stop, and this stat is
    // about where players stop. `$ne: true` rather than `false` so rows written before the
    // field existed still count — they are all full banks by definition.
    const match: Record<string, unknown> = {
        timestamp: { $gte: w.from, $lt: w.to },
        partial: { $ne: true },
    };
    if (userId) match.userId = userId;
    const rows = await BankEvent.find(match).select('streakAtBank');
    return rows.map(r => r.streakAtBank ?? 0);
}

// Null, never 0, on an empty sample: a 0 here would render as "banks instantly", which is the
// opposite of "has never banked".
export function median(xs: number[]): number | null {
    if (xs.length === 0) return null;
    const s = [...xs].sort((a, b) => a - b);
    const m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

// Index 0 is depth 1. Everything at or beyond `maxDepth` folds into the last bucket, because the
// tail is long and thin and a board has a fixed number of rows. Depths below 1 are dropped
// rather than clamped — a bank at streak 0 should not exist, and inventing a bucket for it would
// hide the bug if it ever did.
export function depthHistogram(xs: number[], maxDepth: number): number[] {
    const out = new Array(maxDepth).fill(0);
    for (const x of xs) {
        if (x < 1) continue;
        out[Math.min(maxDepth, Math.floor(x)) - 1] += 1;
    }
    return out;
}

// RATES — need a minimum sample, so every result carries the threshold it was judged against
// and whether it met it. A rate board that silently drops unqualified players looks broken to
// the player who is missing from it; one that includes them ranks noise. Returning `qualified`
// plus `minThrows` lets the caller show "142 / 350 throws" instead of nothing.
//
// Denominator is THROWS, never rounds elapsed: abstention is normal play, and a patient player
// who throws in a fifth of rounds is playing well, not playing little.
export interface PlayerRates {
    throws: number;
    qualified: boolean;
    minThrows: number;
    // VOLUME, NOT A RATE, and therefore never gated on `qualified`. `earned` is the spec's
    // headline Volume figure ("points earned this week", §4.3) and it is obtainable from
    // nowhere else for the viewer themself — /heat carries it only for the top ten. Both it
    // and `roundsPresent` fall out of the queries the rates already need, so returning them
    // costs nothing and saves the caller a round trip. Earnings come from BankEvent; they are
    // never a sum of PlayerRound.pointsDelta.
    earned: number;
    roundsPresent: number;
    pointsPerThrow: number | null;
    captureRate: number | null;
    // MAY EXCEED 1.0, deliberately unclamped. `throws` counts PlayerRound rows; `roundsPresent`
    // counts rounds falling inside this player's session intervals. If presence reporting lags
    // — a Roblox instance whose roster heartbeat is late, or a session opened after the player
    // had already begun throwing — a player can have more throws than rounds-present and the
    // ratio goes above 1. Clamping would hide that, so the raw figure travels and a display
    // decides what to do with it (cap the bar, or say "presence data incomplete"). Null, never
    // Infinity or NaN, when roundsPresent is zero.
    participationRate: number | null;
    // GATED ON `qualified`, like pointsPerThrow and unlike the volume figures: this is the
    // number a board ranks on, and at 60 throws a BLIND player's observed rate lands anywhere
    // between 23% and 43%. Null rather than a small-sample figure, so a caller cannot print it
    // by accident.
    winRate: number | null;
}

export async function playerRates(
    userId: Types.ObjectId,
    w: Window,
    minThrows: number
): Promise<PlayerRates> {
    const throws = await throwsInWindow(userId, w);
    const qualified = throws >= minThrows;

    // Capture rate and participation are reported even when unqualified for the RATE board,
    // because they answer different questions and have their own denominators; only
    // pointsPerThrow is gated, since it is the one a leaderboard would rank on.
    const [earned, forfeited, present, wins] = await Promise.all([
        earningsInWindow(userId, w.from, w.to),
        forfeitsInWindow(userId, w),
        roundsPresent(userId, w.from, w.to),
        winsInWindow(userId, w),
    ]);

    const built = earned + forfeited;
    return {
        throws,
        qualified,
        minThrows,
        earned,
        roundsPresent: present,
        pointsPerThrow: qualified && throws > 0 ? earned / throws : null,
        captureRate: built > 0 ? earned / built : null,
        participationRate: present > 0 ? throws / present : null,
        winRate: qualified && throws > 0 ? wins / throws : null,
    };
}

// HEAT — "who is on a tear right now" (spec §3). Deliberately unqualified and deliberately
// independent of career standing: a newcomer must be able to top it while ranking nowhere
// all-time. It is FORM, not standing, and whatever shows it must say so.
//
// The optional `userIds` is how a board becomes LOCAL. BankEvent carries no instanceId, and
// adding one would need a Roblox client change — but it is not needed: presence already knows
// who is in an instance, so "the leader in this server" means ranking the people currently
// here by their own window figures. That is also the more honest reading: a player who earned
// elsewhere and then walked in is genuinely one of the hottest players in the room.
export async function heatBoard(
    w: Window,
    limit: number,
    userIds?: Types.ObjectId[]
): Promise<{ userId: Types.ObjectId; earned: number }[]> {
    // Explicit on purpose, even though Mongo's own `$in: []` below already matches nothing:
    // this line is what keeps that behaviour true if the query shape ever changes underneath it.
    if (userIds && userIds.length === 0) return [];
    const match: Record<string, unknown> = { timestamp: { $gte: w.from, $lt: w.to } };
    if (userIds) match.userId = { $in: userIds };

    const rows = await BankEvent.aggregate([
        { $match: match },
        { $group: { _id: '$userId', earned: { $sum: '$amount' } } },
        { $sort: { earned: -1 } },
        { $limit: limit },
    ]);
    return rows.map(r => ({ userId: r._id as Types.ObjectId, earned: r.earned as number }));
}

// THE LIVE BOARD. StreakEvent holds only COMPLETED runs, so a streak in progress — the most
// exciting number in the game while it lasts — appears in none of the above. This reads the
// running counter instead. `currentStreak` survives banking (wallet.ts resets only
// stakingStreak), so a cautious banker riding a long run still shows here.
//
// Restricted by `userIds` the same way heatBoard is, so a server can ask "who is on the
// longest run in THIS room right now".
// FORM, AND WHY IT NEEDS NO FLOOR AT ALL. Every rate on this page is an INFERENCE — "is this
// player better than chance?" — and inference needs sample, which is where the 360-throw floor
// comes from and why a rate board is empty for a week. A live pot is not an inference. It is an
// EVENT: someone is holding 243 points right now and has to decide. It is exactly true the moment
// it happens, it needs no qualification, and it works on the first evening with three players in
// the room. Owner, 2026-08-18: "winning is something that happens in the moment, not as a summary
// at the end of a week."
//
// This is the counterpart to `liveStreaks` and deliberately the louder of the two: a streak says
// how far someone has come, a pot says what they stand to lose, and the second is the one with a
// decision attached.
export async function livePots(
    limit: number,
    userIds?: Types.ObjectId[]
): Promise<{ userId: Types.ObjectId; pot: number }[]> {
    // Explicit, like liveStreaks: Mongo's `$in: []` already matches nothing, and this line keeps
    // that true if the query shape changes underneath it.
    if (userIds && userIds.length === 0) return [];
    const filter: Record<string, unknown> = { pointsAtStake: { $gt: 0 } };
    if (userIds) filter._id = { $in: userIds };

    const rows = await User.find(filter).sort({ pointsAtStake: -1 }).limit(limit).select('pointsAtStake');
    return rows.map(u => ({ userId: u._id as Types.ObjectId, pot: u.pointsAtStake }));
}

export async function liveStreaks(
    limit: number,
    userIds?: Types.ObjectId[]
): Promise<{ userId: Types.ObjectId; length: number }[]> {
    // Explicit on purpose, even though Mongo's own `$in: []` below already matches nothing:
    // this line is what keeps that behaviour true if the query shape ever changes underneath it.
    if (userIds && userIds.length === 0) return [];
    const filter: Record<string, unknown> = { currentStreak: { $gt: 0 } };
    if (userIds) filter._id = { $in: userIds };

    const rows = await User.find(filter).sort({ currentStreak: -1 }).limit(limit).select('currentStreak');
    return rows.map(u => ({ userId: u._id as Types.ObjectId, length: u.currentStreak }));
}

// NAME THE PLAYERS HERE. Every board returns user ids; resolving them once server-side saves
// the caller a second round trip, and — more importantly — keeps the projection in ONE place.
// It lives in this module rather than in a route so BOTH transports use the same one: the
// socket path duplicating a projection is precisely how `deviceId` — a bearer credential —
// ended up on a public board.
export async function nameUsers(ids: Types.ObjectId[]): Promise<Map<string, string>> {
    if (ids.length === 0) return new Map();
    const users = await User.find({ _id: { $in: ids } }).select('displayName');
    return new Map(users.map(u => [u._id.toString(), u.displayName || 'Anonymous']));
}

export interface BoardRow {
    userId: Types.ObjectId;
    throws: number;
    wins: number;
    banked: number;
    pointsPerThrow: number;
    winRate: number;
}

// THE BANZUKE. Two aggregations and an in-memory join rather than a $lookup: the qualified set
// is small by construction (360 throws is six hours of play), so the join is over tens of rows.
//
// Ranked on POINTS PER THROW, with WIN RATE carried beside it rather than blended in. Yield is
// the only figure that captures the compounding — a +10 player riding deep earns 37.5/throw
// where a blind player riding to 7 earns 2.1, a gap win rate renders as 43% against 33% — and
// the read column is what tells a reader whether someone is up there on skill or on nerve.
// Blending them into one score would destroy exactly that.
//
// Split from `qualifiedBoard` so `playerStanding` shares the ORDERING. A standing computed from
// its own sort would eventually disagree with the board, in front of the one player guaranteed
// to be checking.
async function rankedField(w: Window, minThrows: number): Promise<BoardRow[]> {
    const counts = await PlayerRound.aggregate([
        { $match: { timestamp: { $gte: w.from, $lt: w.to } } },
        {
            $group: {
                _id: '$userId',
                throws: { $sum: 1 },
                wins: { $sum: { $cond: [{ $eq: ['$playerResult', 'WIN'] }, 1, 0] } },
            },
        },
        { $match: { throws: { $gte: minThrows } } },
    ]);
    if (counts.length === 0) return [];

    const banks = await BankEvent.aggregate([
        { $match: { userId: { $in: counts.map(c => c._id) }, timestamp: { $gte: w.from, $lt: w.to } } },
        { $group: { _id: '$userId', banked: { $sum: '$amount' } } },
    ]);
    const bankedBy = new Map<string, number>(banks.map(b => [String(b._id), b.banked as number]));

    return counts
        .map(c => {
            // A qualified player who banked nothing belongs on the board at zero, not missing
            // from it: they threw the hours, and a board that silently drops them looks broken
            // to the one person guaranteed to be looking for their own name.
            const banked = bankedBy.get(String(c._id)) ?? 0;
            return {
                userId: c._id,
                throws: c.throws,
                wins: c.wins,
                banked,
                pointsPerThrow: banked / c.throws,
                winRate: c.wins / c.throws,
            };
        })
        .sort((a, b) => b.pointsPerThrow - a.pointsPerThrow || b.winRate - a.winRate);
}

export async function qualifiedBoard(w: Window, minThrows: number, limit: number): Promise<BoardRow[]> {
    return (await rankedField(w, minThrows)).slice(0, limit);
}

// WHERE ONE PLAYER STANDS, which is not answerable from the board: the board is ten rows and the
// player who most wants to know is the one in eleventh. Null rather than a rank of 0 for an
// unqualified player — a 0 would sort and render as a position, and "you are 0th" is worse than
// no answer. `of` counts the qualified field only, so it means what the ranking means.
export async function playerStanding(
    userId: Types.ObjectId,
    w: Window,
    minThrows: number
): Promise<{ rank: number; of: number } | null> {
    const field = await rankedField(w, minThrows);
    const i = field.findIndex(r => String(r.userId) === String(userId));
    return i === -1 ? null : { rank: i + 1, of: field.length };
}
