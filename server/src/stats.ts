import { Types } from 'mongoose';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
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
