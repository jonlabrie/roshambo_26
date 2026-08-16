import { Types } from 'mongoose';
import Session, { ISession } from './models/Session';
import Round from './models/Round';

export interface OpenSessionInput {
    userId: Types.ObjectId;
    platform: 'pwa' | 'roblox';
    instanceId?: string;
    // Widened beyond the PWA path so a Roblox roster heartbeat (which genuinely knows the
    // time a player appeared) can create Sessions through this same function rather than a
    // second, separate path — one creation path, parameterised, or a required field quietly
    // gets set on one path and not the other. Both default to now when omitted.
    startedAt?: Date;
    lastSeenAt?: Date;
}

export async function openSession(input: OpenSessionInput): Promise<ISession> {
    const now = new Date();
    return Session.create({
        userId: input.userId,
        platform: input.platform,
        instanceId: input.instanceId,
        startedAt: input.startedAt ?? now,
        lastSeenAt: input.lastSeenAt ?? now,
    });
}

export async function closeSession(sessionId: string, at: Date): Promise<void> {
    await Session.findByIdAndUpdate(sessionId, { $set: { endedAt: at, lastSeenAt: at } });
}

export async function touchSession(sessionId: string, at: Date): Promise<void> {
    await Session.findByIdAndUpdate(sessionId, { $set: { lastSeenAt: at } });
}

// How many rounds ran while this player was present, in [from, to].
//
// An OPEN session is treated as running to `to`, so a player currently online counts.
// Overlapping sessions must NOT double-count — the same player can be connected on two
// devices — so rounds are collected into a Set of ids rather than summed per interval.
export async function roundsPresent(userId: Types.ObjectId, from: Date, to: Date): Promise<number> {
    const sessions = await Session.find({
        userId,
        startedAt: { $lte: to },
        $or: [{ endedAt: { $exists: false } }, { endedAt: { $gte: from } }],
    }).select('startedAt endedAt');

    if (sessions.length === 0) return 0;

    const ranges = sessions.map(s => ({
        start: s.startedAt > from ? s.startedAt : from,
        end: s.endedAt && s.endedAt < to ? s.endedAt : to,
    }));

    const rounds = await Round.find({
        $or: ranges.map(r => ({ timestamp: { $gte: r.start, $lte: r.end } })),
    }).select('id');

    return new Set(rounds.map(r => r.id)).size;
}

// A Roblox game server reports who is in it. There is no socket lifecycle here, so presence
// is a roster diff: open for the newly present, touch the still-present, close the departed.
export async function reconcilePresence(
    instanceId: string,
    userIds: Types.ObjectId[],
    at: Date
): Promise<{ opened: number; touched: number; closed: number }> {
    const open = await Session.find({ instanceId, endedAt: { $exists: false } }).select('userId');
    const openByUser = new Map(open.map(s => [s.userId.toString(), s]));
    const present = new Set(userIds.map(id => id.toString()));

    let opened = 0;
    let touched = 0;
    for (const id of userIds) {
        const existing = openByUser.get(id.toString());
        if (existing) {
            await touchSession(existing._id.toString(), at);
            touched++;
        } else {
            await openSession({ userId: id, platform: 'roblox', instanceId, startedAt: at, lastSeenAt: at });
            opened++;
        }
    }

    let closed = 0;
    for (const [userKey, session] of openByUser) {
        if (!present.has(userKey)) {
            await closeSession(session._id.toString(), at);
            closed++;
        }
    }

    return { opened, touched, closed };
}

// A game server that crashes stops reporting, leaving sessions open forever and inflating
// every player's rounds-present. Close them AT THEIR lastSeenAt, not at sweep time — the
// player was not present for the silent interval, and dating it now would invent presence.
export async function closeStaleSessions(olderThan: Date): Promise<number> {
    const stale = await Session.find({
        endedAt: { $exists: false },
        lastSeenAt: { $lt: olderThan },
    }).select('lastSeenAt');

    for (const session of stale) {
        await Session.findByIdAndUpdate(session._id, { $set: { endedAt: session.lastSeenAt } });
    }
    return stale.length;
}
