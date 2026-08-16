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

// THE PRESENCE HEARTBEAT PERIOD, shared by every transport that keeps a session alive: the
// Roblox roster endpoint and the PWA socket's own heartbeat (transports/socketAdapter.ts).
// The stale sweep's grace period is expressed as a multiple of THIS (index.ts), so the two
// cannot drift into a sweep that fires before the first heartbeat lands.
export const SESSION_HEARTBEAT_MS = 30 * 1000;

// Bulk form of touchSession, for the PWA heartbeat: one write per heartbeat period for the
// whole server rather than one per connected socket, which is what makes riding the 1s sync
// broadcast affordable at all.
export async function touchSessions(sessionIds: string[], at: Date): Promise<void> {
    if (sessionIds.length === 0) return;
    await Session.updateMany({ _id: { $in: sessionIds } }, { $set: { lastSeenAt: at } });
}

// How many rounds ran while this player was present, over the HALF-OPEN window [from, to):
// `from` counts, `to` does not. Every windowed query in the codebase uses the same
// convention (see leaderboards.ts) so that adjacent windows tile without a round or a bank
// landing on the shared boundary being counted in both.
//
// An OPEN session is treated as running to `to`, so a player currently online counts.
// Overlapping sessions must NOT double-count — the same player can be connected on two
// devices. What actually guarantees that today is the SINGLE combined $or query below:
// Mongo returns each matching document once no matter how many $or branches it satisfies.
// The Set is therefore inert as written; it is kept because it is the property that must
// hold, and it would start doing real work the moment anyone splits this into one query
// per range.
export async function roundsPresent(userId: Types.ObjectId, from: Date, to: Date): Promise<number> {
    const sessions = await Session.find({
        userId,
        startedAt: { $lt: to },
        $or: [{ endedAt: { $exists: false } }, { endedAt: { $gte: from } }],
    }).select('startedAt endedAt');

    if (sessions.length === 0) return 0;

    const ranges = sessions.map(s => ({
        start: s.startedAt > from ? s.startedAt : from,
        end: s.endedAt && s.endedAt < to ? s.endedAt : to,
    }));

    const rounds = await Round.find({
        $or: ranges.map(r => ({ timestamp: { $gte: r.start, $lt: r.end } })),
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
    // openByUser is snapshotted BEFORE the loop, so a roster containing the same player
    // twice would open two sessions for them. The route dedupes its roster before calling
    // here (routes/apiV1.ts) — that is where the guarantee lives.
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
//
// SCOPED TO SESSIONS A GAME SERVER REPORTS (instanceId set). A silent session is only
// evidence of a dead reporter for a transport whose liveness IS the report; for anything
// else, silence means "nobody has told us otherwise" and truncating on it invents an
// absence. The PWA does heartbeat now (transports/socketAdapter.ts), but this filter is
// what makes the sweep structurally unable to truncate a live session on a transport that
// stops heartbeating — a regression there must not become a data-corruption bug.
export async function closeStaleSessions(olderThan: Date): Promise<number> {
    const stale = await Session.find({
        instanceId: { $exists: true },
        endedAt: { $exists: false },
        lastSeenAt: { $lt: olderThan },
    }).select('lastSeenAt');

    for (const session of stale) {
        await closeSession(session._id.toString(), session.lastSeenAt);
    }
    return stale.length;
}

// WHO IS IN THIS INSTANCE RIGHT NOW. An open session in the instance IS presence — this is the
// same state reconcilePresence maintains, read rather than written.
export async function presentIn(instanceId: string): Promise<Types.ObjectId[]> {
    const rows = await Session.find({ instanceId, endedAt: { $exists: false } }).select('userId');
    return [...new Set(rows.map(r => r.userId.toString()))].map(id => new Types.ObjectId(id));
}
