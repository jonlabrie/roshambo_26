import mongoose, { Schema, Document } from 'mongoose';

export interface IRound extends Document {
    id: string;
    worldThrow: string;
    distribution: {
        R: number;
        P: number;
        S: number;
    };
    totalPlayers: number;
    timestamp: Date;
}

const RoundSchema: Schema = new Schema({
    id: { type: String, required: true, unique: true },
    worldThrow: { type: String, required: true },
    distribution: {
        R: { type: Number, default: 0 },
        P: { type: Number, default: 0 },
        S: { type: Number, default: 0 }
    },
    totalPlayers: { type: Number, default: 0 },
    timestamp: { type: Date, default: Date.now }
});

// Rounds accrue about one a minute (~525k a year) and sessions.roundsPresent queries them by
// an $or of timestamp ranges. Without this that is a collection scan, per player.
RoundSchema.index({ timestamp: 1 });

export default mongoose.model<IRound>('Round', RoundSchema);
