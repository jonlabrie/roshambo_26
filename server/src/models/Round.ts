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

export default mongoose.model<IRound>('Round', RoundSchema);
