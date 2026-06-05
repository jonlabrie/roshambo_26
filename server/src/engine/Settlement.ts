import User, { IUser } from '../models/User';
import Round from '../models/Round';
import PlayerRound from '../models/PlayerRound';
import { calculateResult, nextPot, potDelta, nextStreak, Throw, RoundResult } from './GameRules';
import { ThrowEntry } from './RoundEngine';
import { resolveUser } from '../identity';

export interface GlobalResult {
    id: string;
    worldThrow: Throw;
    distribution: { R: number; P: number; S: number };
    totalPlayers: number;
    timestamp: Date;
}

export interface SettledPlayer {
    key: string;
    platform: 'pwa' | 'roblox';
    deviceId?: string;
    robloxUserId?: string;
    instanceId?: string;
    result: RoundResult;
    delta: number;
    totalPoints: number;
    pot: number;
    streak: number;
    user: IUser; // full updated doc, used by the socket adapter's player-data emit
}

export interface RoundToSettle {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;
    throws: Map<string, ThrowEntry>;
    timestamp: Date;
}

export function buildDistribution(counts: Record<Throw, number>, total: number) {
    if (total === 0) return { R: 33, P: 33, S: 33 };
    return {
        R: Math.round((counts.R / total) * 100),
        P: Math.round((counts.P / total) * 100),
        S: Math.round((counts.S / total) * 100),
    };
}

export async function settleRound(data: RoundToSettle): Promise<{ round: GlobalResult; players: SettledPlayer[] }> {
    const totalPlayers = data.throws.size;
    const round: GlobalResult = {
        id: data.roundId,
        worldThrow: data.worldThrow,
        distribution: buildDistribution(data.counts, totalPlayers),
        totalPlayers,
        timestamp: data.timestamp,
    };

    await Round.create(round).catch(err =>
        console.error('Error saving round:', (err as Error).message));

    const players = await Promise.all(
        Array.from(data.throws.entries()).map(async ([key, entry]): Promise<SettledPlayer | null> => {
            try {
                const user = await resolveUser({
                    userId: entry.userId, deviceId: entry.deviceId, robloxUserId: entry.robloxUserId,
                });
                if (!user) return null;

                const result = calculateResult(entry.throw, data.worldThrow);
                const pot = nextPot(user.pointsAtStake || 0, result);
                const delta = potDelta(user.pointsAtStake || 0, result); // WIN: new pot; LOSS: -old pot; SAFE: 0
                const streak = nextStreak(user.currentStreak || 0, result);
                const bestStreak = Math.max(user.bestStreak || 0, streak);

                const updated = (await User.findByIdAndUpdate(user._id, {
                    $set: {
                        pointsAtStake: pot,
                        currentStreak: streak,
                        stakingStreak: nextStreak(user.stakingStreak || 0, result),
                        bestStreak,
                    },
                }, { new: true })) || user;

                await PlayerRound.create({
                    deviceId: entry.deviceId,
                    userId: entry.userId,
                    robloxUserId: entry.robloxUserId,
                    platform: entry.platform,
                    roundId: data.roundId,
                    playerThrow: entry.throw,
                    playerResult: result,
                    pointsDelta: delta,
                    timestamp: data.timestamp,
                });

                return {
                    key,
                    platform: entry.platform,
                    deviceId: entry.deviceId,
                    robloxUserId: entry.robloxUserId,
                    instanceId: entry.instanceId,
                    result,
                    delta,
                    totalPoints: updated.totalPoints,
                    pot: updated.pointsAtStake,
                    streak: updated.currentStreak,
                    user: updated,
                };
            } catch (err) {
                console.error(`Error settling ${key}:`, (err as Error).message);
                return null;
            }
        })
    );

    return { round, players: players.filter((p): p is SettledPlayer => p !== null) };
}
