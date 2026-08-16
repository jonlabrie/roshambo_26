import { Types } from 'mongoose';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import { Window } from './windows';

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
