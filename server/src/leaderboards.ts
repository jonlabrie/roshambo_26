import { Types } from 'mongoose';
import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';

// RANK ON CAREER EARNINGS, NEVER ON THE WALLET. `totalPoints` is spendable and is
// decremented by every purchase (routes/store.ts, routes/apiV1.ts), so ranking on it means a
// player who spends on fireworks or a teahouse FALLS DOWN THE BOARD — the leaderboard would
// punish exactly the economy engagement the game wants. `lifetimeBanked` is monotonic.
export const LEADERBOARD_FIELDS =
    'deviceId displayName lifetimeBanked totalPoints robloxId identityTier currentStreak bestStreak';

export async function topByCareer(filter: Record<string, unknown>, limit: number): Promise<IUser[]> {
    return User.find(filter)
        .sort({ lifetimeBanked: -1 })
        .limit(limit)
        .select(LEADERBOARD_FIELDS);
}

// EARNINGS COME FROM BANK EVENTS, NEVER FROM PlayerRound.pointsDelta. On a WIN that column
// records the NEW POT rather than the gain, so a 0->1->3->9 run writes 1,3,9 for a pot worth
// 9 and summing it overstates earnings by a growing multiple.
export async function earningsInWindow(userId: Types.ObjectId, from: Date, to: Date): Promise<number> {
    const [row] = await BankEvent.aggregate([
        { $match: { userId, timestamp: { $gte: from, $lte: to } } },
        { $group: { _id: null, earned: { $sum: '$amount' } } },
    ]);
    return row?.earned ?? 0;
}

// "Who is having the best week" — Heat, in the spec's terms. Deliberately independent of
// career standing: a newcomer on a tear must be able to top this while ranking nowhere.
export async function topEarnersInWindow(
    from: Date,
    to: Date,
    limit: number
): Promise<{ userId: Types.ObjectId; earned: number }[]> {
    const rows = await BankEvent.aggregate([
        { $match: { timestamp: { $gte: from, $lte: to } } },
        { $group: { _id: '$userId', earned: { $sum: '$amount' } } },
        { $sort: { earned: -1 } },
        { $limit: limit },
    ]);
    return rows.map(r => ({ userId: r._id as Types.ObjectId, earned: r.earned as number }));
}
