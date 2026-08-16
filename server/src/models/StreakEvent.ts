import mongoose, { Schema, Document, Types } from 'mongoose';

// ONE ROW PER COMPLETED STREAK. `User.bestStreak` is an all-time maximum with no date, so
// "longest streak this week" is unanswerable without this. `BankEvent.streakAtBank` is not a
// substitute: it only sees streaks that were BANKED, and the spec wants cautious bankers and
// reckless riders to compete equally on the streak board — a rider whose run ends in a LOSS
// must still appear.
//
// Written only when a run actually ENDS, so this collection is far smaller than PlayerRound:
// one row per streak, not one per round. Banking does NOT end a streak (wallet.ts resets
// stakingStreak, never currentStreak), so the only terminators are SAFE and LOSS.
export interface IStreakEvent extends Document {
    userId: Types.ObjectId;
    length: number;
    endedBy: 'SAFE' | 'LOSS';
    endedAt: Date;
}

const StreakEventSchema: Schema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    length: { type: Number, required: true },
    endedBy: { type: String, enum: ['SAFE', 'LOSS'], required: true },
    endedAt: { type: Date, default: Date.now },
});

// "longest streak in this window", globally and per player.
StreakEventSchema.index({ endedAt: -1, length: -1 });
StreakEventSchema.index({ userId: 1, endedAt: -1 });

export default mongoose.model<IStreakEvent>('StreakEvent', StreakEventSchema);
