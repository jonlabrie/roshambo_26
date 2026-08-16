import { Types } from 'mongoose';
import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';

// RANK ON CAREER EARNINGS, NEVER ON THE WALLET. `totalPoints` is spendable and is
// decremented by every purchase (routes/store.ts, routes/apiV1.ts), so ranking on it means a
// player who spends on fireworks or a teahouse FALLS DOWN THE BOARD — the leaderboard would
// punish exactly the economy engagement the game wants. `lifetimeBanked` is monotonic.
//
// NO `deviceId`, ON ANY TRANSPORT. A deviceId is a BEARER CREDENTIAL: `sync-player`,
// `submit-throw`, `bank` and `update-progress` each resolve an account from a client-supplied
// one, with no further auth. It used to travel on the socket board so the PWA could label rows
// with its first eight characters — i.e. it rendered other players' credentials as their
// pseudonyms, and any connected socket could harvest ~100 of them from `get-stats`. The board
// carries `displayName` instead.
//
// There is ONE constant because no consumer may have it. Adding a field for one transport means
// deliberately adding a second projection, not widening this one — quietly widening a shared
// list is exactly how deviceId got here.
export const LEADERBOARD_FIELDS =
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
