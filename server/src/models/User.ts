import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
    deviceId?: string;
    email?: string;
    password?: string;
    googleId?: string;
    appleId?: string;
    facebookId?: string;
    instagramId?: string;
    displayName?: string;
    totalPoints: number;
    bestStreak: number;
    currentStreak: number;
    stakingStreak: number;
    inventory: string[];
    equippedCharacterId: string;
    updatedAt: Date;
}

const UserSchema: Schema = new Schema({
    deviceId: { type: String, unique: true, sparse: true },
    email: { type: String, unique: true, sparse: true },
    password: { type: String, select: false },
    googleId: { type: String, unique: true, sparse: true },
    appleId: { type: String, unique: true, sparse: true },
    facebookId: { type: String, unique: true, sparse: true },
    instagramId: { type: String, unique: true, sparse: true },
    displayName: { type: String },
    totalPoints: { type: Number, default: 0 },
    bestStreak: { type: Number, default: 0 },
    currentStreak: { type: Number, default: 0 },
    stakingStreak: { type: Number, default: 0 },
    inventory: { type: [String], default: ['default'] },
    equippedCharacterId: { type: String, default: 'default' },
}, { timestamps: true });

export default mongoose.model<IUser>('User', UserSchema);
