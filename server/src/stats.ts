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
    pointsPerThrow: number | null;
    captureRate: number | null;
    participationRate: number | null;
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
    const [earned, forfeited, present] = await Promise.all([
        earningsInWindow(userId, w.from, w.to),
        forfeitsInWindow(userId, w),
        roundsPresent(userId, w.from, w.to),
    ]);

    const built = earned + forfeited;
    return {
        throws,
        qualified,
        minThrows,
        pointsPerThrow: qualified && throws > 0 ? earned / throws : null,
        captureRate: built > 0 ? earned / built : null,
        participationRate: present > 0 ? throws / present : null,
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
export async function liveStreaks(
    limit: number,
    userIds?: Types.ObjectId[]
): Promise<{ userId: Types.ObjectId; length: number }[]> {
    if (userIds && userIds.length === 0) return [];
    const filter: Record<string, unknown> = { currentStreak: { $gt: 0 } };
    if (userIds) filter._id = { $in: userIds };

    const rows = await User.find(filter).sort({ currentStreak: -1 }).limit(limit).select('currentStreak');
    return rows.map(u => ({ userId: u._id as Types.ObjectId, length: u.currentStreak }));
}
