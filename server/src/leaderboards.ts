import { Types } from 'mongoose';
import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';

// RANK ON CAREER EARNINGS, NEVER ON THE WALLET. `totalPoints` is spendable and is
// decremented by every purchase (routes/store.ts, routes/apiV1.ts), so ranking on it means a
// player who spends on fireworks or a teahouse FALLS DOWN THE BOARD — the leaderboard would
// punish exactly the economy engagement the game wants. `lifetimeBanked` is monotonic.
export const LEADERBOARD_FIELDS =
    'deviceId displayName lifetimeBanked totalPoints robloxId identityTier currentStreak bestStreak';

// THE SAME BOARD, MINUS deviceId, for /api/v1. On the socket path a deviceId is a bearer
// credential — `sync-player { deviceId }` grants that account with no further auth — so it
// must not travel to a caller that has no business holding one. The two projections are
// deliberately separate constants rather than one shared list: sharing would mean the next
// field added for the PWA silently appears on the API too, which is exactly how deviceId
// got here.
export const API_LEADERBOARD_FIELDS =
    'displayName lifetimeBanked totalPoints robloxId identityTier currentStreak bestStreak';

export async function topByCareer(
    filter: Record<string, unknown>,
    limit: number,
    fields: string = LEADERBOARD_FIELDS
): Promise<IUser[]> {
    return User.find(filter)
        .sort({ lifetimeBanked: -1 })
        .limit(limit)
        .select(fields);
}

// EARNINGS COME FROM BANK EVENTS, NEVER FROM PlayerRound.pointsDelta. On a WIN that column
// records the NEW POT rather than the gain, so a 0->1->3->9 run writes 1,3,9 for a pot worth
// 9 and summing it overstates earnings by a growing multiple.
//
// The window is HALF-OPEN, [from, to): a bank exactly at `to` belongs to the next window,
// never to both. Same convention as sessions.ts.
export async function earningsInWindow(userId: Types.ObjectId, from: Date, to: Date): Promise<number> {
    const [row] = await BankEvent.aggregate([
        { $match: { userId, timestamp: { $gte: from, $lt: to } } },
        { $group: { _id: null, earned: { $sum: '$amount' } } },
    ]);
    return row?.earned ?? 0;
}
