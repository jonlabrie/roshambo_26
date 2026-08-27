import mongoose, { Schema, Document, Types } from 'mongoose';

// ONE ROW PER BANK. The wallet's own counters (totalPoints, lifetimeBanked) are running
// totals with no timestamps, so without this collection "points earned last week" cannot be
// answered at all. PlayerRound cannot substitute: on a WIN its pointsDelta records the NEW
// POT rather than the gain, so summing that column overstates earnings badly
// (0->1->3->9 writes 1,3,9 for a pot worth 9).
export interface IBankEvent extends Document {
    userId: Types.ObjectId;
    amount: number;
    streakAtBank: number;
    partial: boolean;
    platform: 'pwa' | 'roblox';
    timestamp: Date;
}

const BankEventSchema: Schema = new Schema({
    // No standalone index here: the { userId: 1, timestamp: -1 } compound below has userId as
    // its prefix and serves every userId-only lookup, so a second index would be write cost
    // for nothing.
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true },
    // How long the streak was when they chose to stop. The whole bank-vs-stake story lives
    // in the distribution of this number.
    streakAtBank: { type: Number, default: 0 },
    // ⚠ A PARTIAL BANK IS A DIFFERENT DECISION FROM A FULL ONE, and both write streakAtBank.
    // Without this flag `bankDepths` (the NERVE histogram) blends "when do players stop" with
    // "when do players hedge" — no error, no failing test, just a stat about something else.
    // Cheap now, impossible to reconstruct later: the rows would already be mixed.
    //
    // ⚠ THE FILTER FOLLOWS THE COLUMN, NOT THE COLLECTION -- do not "fix" the inconsistency.
    // `amount` is earnings and every consumer counts partial banks (biggestBanks, heatBoard,
    // qualifiedBoard, earningsInWindow): hedged points are real points. `streakAtBank` is a
    // decision, and only bankDepths reads it, so only bankDepths filters.
    partial: { type: Boolean, default: false },
    platform: { type: String, enum: ['pwa', 'roblox'], default: 'pwa' },
    timestamp: { type: Date, default: Date.now },
});

// Windowed earnings for one player, and global "who earned most this week".
BankEventSchema.index({ userId: 1, timestamp: -1 });
BankEventSchema.index({ timestamp: -1 });

export default mongoose.model<IBankEvent>('BankEvent', BankEventSchema);
