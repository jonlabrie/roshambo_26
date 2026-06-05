import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IPlayerRound extends Document {
    deviceId?: string;
    robloxUserId?: string;
    platform: 'pwa' | 'roblox';
    userId?: any;
    roundId: string;
    playerThrow: string;
    playerResult: string;
    pointsDelta: number;
    timestamp: Date;
}

const PlayerRoundSchema: Schema = new Schema({
    deviceId: { type: String, index: true },
    robloxUserId: { type: String, index: true },
    platform: { type: String, enum: ['pwa', 'roblox'], default: 'pwa' },
    userId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    roundId: { type: String, required: true },
    playerThrow: { type: String, required: true },
    playerResult: { type: String, required: true },
    pointsDelta: { type: Number, default: 0 },
    timestamp: { type: Date, default: Date.now }
});

// Compound index for fast lookup of a player's recent rounds
PlayerRoundSchema.index({ deviceId: 1, timestamp: -1 });
PlayerRoundSchema.index({ userId: 1, timestamp: -1 });

export default mongoose.model<IPlayerRound>('PlayerRound', PlayerRoundSchema);
