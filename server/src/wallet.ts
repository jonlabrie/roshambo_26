import User, { IUser } from './models/User';

// Bank = move the at-stake pot into totalPoints. currentStreak (win streak) is
// NOT reset by banking — only stakingStreak is. Atomic: the filter guards
// against double-banking races.
export async function bankPot(userId: string): Promise<IUser | null> {
    const user = await User.findById(userId);
    if (!user || user.pointsAtStake <= 0) return null;
    return User.findOneAndUpdate(
        { _id: user._id, pointsAtStake: user.pointsAtStake },
        { $inc: { totalPoints: user.pointsAtStake }, $set: { pointsAtStake: 0, stakingStreak: 0 } },
        { new: true }
    );
}
