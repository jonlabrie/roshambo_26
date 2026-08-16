import mongoose, { Schema, Document, Types } from 'mongoose';

// PRESENCE, RECORDED AS INTERVALS. Abstention is normal play — a player may watch for a
// readable pattern and throw in a third of rounds — so "rounds present" is a different
// number from "rounds thrown", and every participation stat needs both.
//
// DELIBERATELY NOT a row per player per round: at a thousand concurrents that is ~1.4M
// writes a day to record mostly nothing. One row per session is exact and cheap, because
// rounds-present falls out of counting Round timestamps inside the interval.
export interface ISession extends Document {
    userId: Types.ObjectId;
    platform: 'pwa' | 'roblox';
    instanceId?: string;
    startedAt: Date;
    lastSeenAt: Date;
    endedAt?: Date;
}

const SessionSchema: Schema = new Schema({
    // Neither userId nor instanceId carries a standalone index: each is the PREFIX of a
    // compound index below, which serves the single-field lookups too. A standalone index on
    // a prefix is pure write cost.
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    platform: { type: String, enum: ['pwa', 'roblox'], default: 'pwa' },
    instanceId: { type: String },
    startedAt: { type: Date, default: Date.now },
    // Advanced by heartbeats. A session whose process died is closed at its lastSeenAt by the
    // stale sweep, so an interval never runs to infinity.
    lastSeenAt: { type: Date, default: Date.now },
    endedAt: { type: Date },
});

SessionSchema.index({ userId: 1, startedAt: -1 });
SessionSchema.index({ endedAt: 1, lastSeenAt: 1 });
// reconcilePresence's roster diff: the open sessions of one instance.
SessionSchema.index({ instanceId: 1, endedAt: 1 });

export default mongoose.model<ISession>('Session', SessionSchema);
