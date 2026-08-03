import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
    deviceId?: string;
    email?: string;
    password?: string;
    googleId?: string;
    appleId?: string;
    facebookId?: string;
    instagramId?: string;
    robloxId?: string;
    identityTier: 'guest' | 'email' | 'roblox';
    country?: string;
    displayName?: string;
    totalPoints: number;
    bestStreak: number;
    currentStreak: number;
    stakingStreak: number;
    pointsAtStake: number;
    // Play HUD (2026-08-02). "The last scored round was a WIN and nothing has been banked since."
    // It gates nothing — it makes the pot indicator pulse. NOT derivable from pointsAtStake: a pot
    // ridden through a SAFE is identical in figure to one just won.
    unresolvedWin: boolean;
    escalationPrompts: boolean;
    // "Ask me to confirm a throw when there is a pot riding on it." Default ON: the confirm guards a
    // mis-tap at exactly the moment one is expensive, and a player who does not want it turns it off
    // (ledger footer, or the strip's own "don't ask again").
    confirmThrows: boolean;
    seenBeats: string[];
    roundsPlayed: number;
    wins: number;
    safes: number;
    losses: number;
    lifetimeBanked: number;
    bestPot: number;
    throwsR: number;
    throwsP: number;
    throwsS: number;
    inventory: string[];
    equippedCharacterId: string;
    teahouses: Map<string, unknown>;
    padPreferences: string[];
    maxDeckSize: 'S' | 'M' | 'L' | null;
    deckDisplay: 'S' | 'M' | 'L' | null;
    teahouseDisplay: 'none' | 'S' | 'M' | 'L' | null;
    portalOwned: boolean;
    deckDecorations: { id: number; propId: string; offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' }[];
    teahouseAccess: { mode: 'public' | 'friends' | 'private'; invited: number[] };
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
    robloxId: { type: String, unique: true, sparse: true },
    identityTier: { type: String, enum: ['guest', 'email', 'roblox'], default: 'guest' },
    country: { type: String },
    displayName: { type: String },
    totalPoints: { type: Number, default: 0 },
    bestStreak: { type: Number, default: 0 },
    currentStreak: { type: Number, default: 0 },
    stakingStreak: { type: Number, default: 0 },
    pointsAtStake: { type: Number, default: 0 },
    unresolvedWin: { type: Boolean, default: false },
    escalationPrompts: { type: Boolean, default: true },
    confirmThrows: { type: Boolean, default: true },
    seenBeats: { type: [String], default: [] },
    roundsPlayed: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    safes: { type: Number, default: 0 },
    losses: { type: Number, default: 0 },
    lifetimeBanked: { type: Number, default: 0 },
    bestPot: { type: Number, default: 0 },
    throwsR: { type: Number, default: 0 },
    throwsP: { type: Number, default: 0 },
    throwsS: { type: Number, default: 0 },
    inventory: { type: [String], default: ['default'] },
    equippedCharacterId: { type: String, default: 'default' },
    teahouses: { type: Map, of: Schema.Types.Mixed, default: {} },
    padPreferences: { type: [String], default: [] },
    maxDeckSize: { type: String, enum: ['S', 'M', 'L', null], default: null },
    deckDisplay: { type: String, enum: ['S', 'M', 'L', null], default: null },
    teahouseDisplay: { type: String, enum: ['none', 'S', 'M', 'L', null], default: null },
    portalOwned: { type: Boolean, default: false },
    deckDecorations: { type: [Schema.Types.Mixed], default: [] },
    teahouseAccess: {
        type: { mode: { type: String, enum: ['public', 'friends', 'private'], default: 'public' }, invited: { type: [Number], default: [] } },
        default: () => ({ mode: 'public', invited: [] }),
    },
}, { timestamps: true });

export default mongoose.model<IUser>('User', UserSchema);
