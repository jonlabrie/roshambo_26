import User, { IUser } from './models/User';

// Bank = move the at-stake pot into totalPoints. currentStreak (win streak) is
// NOT reset by banking — only stakingStreak is. Atomic: the filter guards
// against double-banking races.
export async function bankPot(userId: string): Promise<IUser | null> {
    const user = await User.findById(userId);
    // null return is overloaded: nothing staked OR lost a concurrent-update race;
    // benign in single-process deployment.
    if (!user || user.pointsAtStake <= 0) return null;
    return User.findOneAndUpdate(
        { _id: user._id, pointsAtStake: user.pointsAtStake },
        {
            $inc: { totalPoints: user.pointsAtStake, lifetimeBanked: user.pointsAtStake },
            $set: { pointsAtStake: 0, stakingStreak: 0, unresolvedWin: false },
        },
        { new: true }
    );
}

// Answer an outstanding WIN. RISK leaves the pot staked and only lifts the gate; BANK banks and
// lifts it. Both are conditional on unresolvedWin so a double-tap cannot double-bank.
export async function resolveWin(userId: string, choice: 'risk' | 'bank'): Promise<IUser | null> {
    if (choice === 'risk') {
        return User.findOneAndUpdate(
            { _id: userId, unresolvedWin: true },
            { $set: { unresolvedWin: false } },
            { new: true }
        );
    }
    const banked = await bankPot(userId);
    if (banked) return banked;
    // Nothing was staked (should be unreachable after a WIN). Clear the gate regardless —
    // leaving it set would lock the player out of throwing permanently.
    return User.findOneAndUpdate(
        { _id: userId, unresolvedWin: true },
        { $set: { unresolvedWin: false } },
        { new: true }
    );
}
