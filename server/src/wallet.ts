import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';

// Bank = move the at-stake pot into totalPoints. currentStreak (win streak) is
// NOT reset by banking — only stakingStreak is. Atomic: the filter guards
// against double-banking races.
export async function bankPot(userId: string, platform: 'pwa' | 'roblox'): Promise<IUser | null> {
    const user = await User.findById(userId);
    // null return is overloaded: nothing staked OR lost a concurrent-update race;
    // benign in single-process deployment.
    if (!user || user.pointsAtStake <= 0) return null;

    const amount = user.pointsAtStake;
    const streakAtBank = user.stakingStreak || 0;

    const updated = await User.findOneAndUpdate(
        { _id: user._id, pointsAtStake: user.pointsAtStake },
        {
            $inc: { totalPoints: amount, lifetimeBanked: amount },
            $set: { pointsAtStake: 0, stakingStreak: 0, unresolvedWin: false },
        },
        { new: true }
    );

    // AFTER the atomic update, and only if it won the race — a bank that did not happen must
    // not leave an event behind. The reverse ordering would overstate earnings on every lost
    // race. A crash in this gap loses one event, which is the acceptable direction to fail.
    if (updated) {
        await BankEvent.create({ userId: user._id, amount, streakAtBank, platform })
            .catch(err => console.error('Error writing BankEvent:', (err as Error).message));
    }

    return updated;
}
