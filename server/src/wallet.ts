import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';
import { isValidKeep } from './engine/GameRules';

// Bank = move part or all of the at-stake pot into totalPoints. `keep` is what stays riding and
// must be a LOWER RUNG of the 3^n ladder (GameRules.keepOptions); 0 is the full bank, which is
// why every existing caller is correct unchanged.
//
// currentStreak (win streak) is NEVER reset by banking.
//
// ⚠ stakingStreak is zeroed only when the POT REACHES ZERO, not merely because a bank happened
// (owner ruling, 2026-08-26). A player who hedges down a rung still has money on the same run.
//
// Atomic: the filter guards against double-banking races.
export async function bankPot(
    userId: string,
    platform: 'pwa' | 'roblox',
    keep: number = 0
): Promise<IUser | null> {
    const user = await User.findById(userId);
    // null return is overloaded: nothing staked, an invalid keep, OR a lost concurrent-update
    // race; benign in single-process deployment.
    if (!user || user.pointsAtStake <= 0) return null;
    if (!isValidKeep(user.pointsAtStake, keep)) return null;

    const amount = user.pointsAtStake - keep;
    const streakAtBank = user.stakingStreak || 0;
    const partial = keep > 0;

    const updated = await User.findOneAndUpdate(
        { _id: user._id, pointsAtStake: user.pointsAtStake },
        {
            $inc: { totalPoints: amount, lifetimeBanked: amount },
            $set: {
                pointsAtStake: keep,
                stakingStreak: partial ? streakAtBank : 0,
                // "the last scored round was a WIN and the player has not banked since" — a
                // partial bank is a decision, so it resolves the win either way.
                unresolvedWin: false,
            },
        },
        { new: true }
    );

    // AFTER the atomic update, and only if it won the race — a bank that did not happen must
    // not leave an event behind. The reverse ordering would overstate earnings on every lost
    // race. A crash in this gap loses one event, which is the acceptable direction to fail.
    if (updated) {
        await BankEvent.create({ userId: user._id, amount, streakAtBank, platform, partial })
            .catch(err => console.error('Error writing BankEvent:', (err as Error).message));
    }

    return updated;
}
