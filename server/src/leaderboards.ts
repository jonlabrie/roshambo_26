import User, { IUser } from './models/User';

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
