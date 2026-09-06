import mongoose, { Schema, Document, Types } from 'mongoose';

// ONE ROW PER EXTERNAL POWDER GRANT, and the idempotency key for all of them. A Robux receipt
// (ProcessReceipt retries until it is told Granted), an ops gift, a future return reward: each
// names a receiptId once, and the unique index below is what makes "credit at most once" true
// under retries and races — the row is inserted BEFORE the balance moves, so a duplicate insert
// fails before it can credit.
export interface IPowderGrant extends Document {
    receiptId: string;
    userId: Types.ObjectId;
    amount: number;
    source: 'robux' | 'gift' | 'ops';
    createdAt: Date;
}

const PowderGrantSchema: Schema = new Schema({
    receiptId: { type: String, required: true, unique: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true },
    source: { type: String, enum: ['robux', 'gift', 'ops'], required: true },
    createdAt: { type: Date, default: Date.now },
});

export default mongoose.model<IPowderGrant>('PowderGrant', PowderGrantSchema);
