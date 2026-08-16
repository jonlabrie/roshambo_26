import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import Round from './models/Round';
import Session from './models/Session';
import { openSession, closeSession, touchSession, touchSessions, roundsPresent, reconcilePresence, closeStaleSessions, presentIn } from './sessions';

// Module scope: Task 5 appends a second `describe` to this file and reuses this helper.
const at = (min: number) => new Date(Date.UTC(2026, 7, 16, 12, min, 0));

// File scope, declared exactly once: connectTestDb is NOT idempotent (it spins up a fresh
// MongoMemoryServer and overwrites a module-level handle), so a second describe declaring
// its own beforeAll/afterAll would start a second server and let one afterAll stop the
// other's. Task 5 appends its describe below this block rather than duplicating hooks.
beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

describe('sessions', () => {
    it('opens a session that is not yet ended', async () => {
        const user = await User.create({ deviceId: 'devS1' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        expect(session.endedAt).toBeUndefined();
        expect(await Session.countDocuments({})).toBe(1);
    });

    it('closes a session with an end time', async () => {
        const user = await User.create({ deviceId: 'devS2' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await closeSession(session._id.toString(), at(30));
        const stored = await Session.findById(session._id);
        expect(stored?.endedAt?.toISOString()).toBe(at(30).toISOString());
    });

    it('counts only the rounds that fall inside a session', async () => {
        const user = await User.create({ deviceId: 'devS3' });
        // present 12:00 -> 12:10
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await Session.findByIdAndUpdate(session._id, { $set: { startedAt: at(0) } });
        await closeSession(session._id.toString(), at(10));

        await Round.create({ id: 'r-start', worldThrow: 'R', timestamp: at(0) });   // exactly at open, inside
        await Round.create({ id: 'r-inside', worldThrow: 'P', timestamp: at(5) });      // inside
        await Round.create({ id: 'r-after', worldThrow: 'S', timestamp: at(20) });      // outside

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(2);
    });

    it('counts an OPEN session as running up to the window end', async () => {
        const user = await User.create({ deviceId: 'devS4' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await Session.findByIdAndUpdate(session._id, { $set: { startedAt: at(0) } });

        await Round.create({ id: 'r1', worldThrow: 'R', timestamp: at(5) });
        await Round.create({ id: 'r2', worldThrow: 'P', timestamp: at(50) });

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(2);
    });

    it('does not double-count a round covered by two overlapping sessions', async () => {
        const user = await User.create({ deviceId: 'devS5' });
        for (const _ of [1, 2]) {
            const s = await openSession({ userId: user._id, platform: 'pwa' });
            await Session.findByIdAndUpdate(s._id, { $set: { startedAt: at(0) } });
            await closeSession(s._id.toString(), at(10));
        }
        await Round.create({ id: 'r1', worldThrow: 'R', timestamp: at(5) });

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(1);
    });

    it('touch moves lastSeenAt without ending the session', async () => {
        const user = await User.create({ deviceId: 'devS6' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await touchSession(session._id.toString(), at(45));
        const stored = await Session.findById(session._id);
        expect(stored?.lastSeenAt?.toISOString()).toBe(at(45).toISOString());
        expect(stored?.endedAt).toBeUndefined();
    });

    it('excludes a round landing exactly on the window end', async () => {
        // [from, to) — the round at `to` belongs to the NEXT window. Inclusive at both ends
        // would count it in both, and every windowed number would overlap its neighbour.
        const user = await User.create({ deviceId: 'devS8' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await Session.findByIdAndUpdate(session._id, { $set: { startedAt: at(0) } });

        await Round.create({ id: 'r-at-from', worldThrow: 'R', timestamp: at(0) });  // included
        await Round.create({ id: 'r-at-to', worldThrow: 'P', timestamp: at(60) });   // excluded

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(1);
    });

    it('touches many sessions in one write', async () => {
        const user = await User.create({ deviceId: 'devS9' });
        const a = await openSession({ userId: user._id, platform: 'pwa' });
        const b = await openSession({ userId: user._id, platform: 'pwa' });
        await touchSessions([a._id.toString(), b._id.toString()], at(45));
        const stored = await Session.find({ userId: user._id });
        expect(stored.map(x => x.lastSeenAt.toISOString())).toEqual([at(45).toISOString(), at(45).toISOString()]);
        expect(stored.every(x => x.endedAt === undefined)).toBe(true);
    });

    it('opens a session with an explicit startedAt/lastSeenAt for a known-time roster path', async () => {
        const user = await User.create({ deviceId: 'devS7' });
        const session = await openSession({
            userId: user._id,
            platform: 'roblox',
            startedAt: at(10),
            lastSeenAt: at(10),
        });
        expect(session.startedAt.toISOString()).toBe(at(10).toISOString());
        expect(session.lastSeenAt.toISOString()).toBe(at(10).toISOString());
    });
});

describe('presence reconciliation', () => {
    it('opens sessions for players newly present', async () => {
        const a = await User.create({ deviceId: 'ra' });
        const result = await reconcilePresence('inst1', [a._id], at(0));
        expect(result.opened).toBe(1);
        expect(await Session.countDocuments({ instanceId: 'inst1', endedAt: { $exists: false } })).toBe(1);
    });

    it('touches players still present rather than opening a second session', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('inst1', [a._id], at(0));
        const result = await reconcilePresence('inst1', [a._id], at(5));
        expect(result.opened).toBe(0);
        expect(result.touched).toBe(1);
        expect(await Session.countDocuments({ instanceId: 'inst1' })).toBe(1);
    });

    it('closes sessions for players who have left', async () => {
        const a = await User.create({ deviceId: 'ra' });
        const b = await User.create({ deviceId: 'rb' });
        await reconcilePresence('inst1', [a._id, b._id], at(0));
        const result = await reconcilePresence('inst1', [a._id], at(5));
        expect(result.closed).toBe(1);
        const bSession = await Session.findOne({ userId: b._id });
        expect(bSession?.endedAt?.toISOString()).toBe(at(5).toISOString());
    });

    it('does not touch sessions belonging to another instance', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('inst1', [a._id], at(0));
        await reconcilePresence('inst2', [], at(5));
        expect(await Session.countDocuments({ instanceId: 'inst1', endedAt: { $exists: false } })).toBe(1);
    });

    it('closes sessions whose instance stopped reporting, at their lastSeenAt', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('deadInstance', [a._id], at(0));
        await Session.updateMany({}, { $set: { lastSeenAt: at(0) } });

        const closed = await closeStaleSessions(at(10));
        expect(closed).toBe(1);
        const stored = await Session.findOne({ userId: a._id });
        // closed at lastSeenAt, NOT at sweep time — the player was not present for those 30 minutes
        expect(stored?.endedAt?.toISOString()).toBe(at(0).toISOString());
    });

    it('NEVER closes a PWA session, however silent — the sweep is for reporting instances', async () => {
        // A PWA session is closed by its socket disconnecting, not by silence. Before this
        // filter the sweep truncated every live PWA session ~2 minutes in, setting endedAt to
        // its startedAt and zeroing that player's rounds-present while they were still playing.
        const a = await User.create({ deviceId: 'pwaPlayer' });
        const session = await openSession({ userId: a._id, platform: 'pwa' });
        await Session.updateMany({}, { $set: { startedAt: at(0), lastSeenAt: at(0) } });

        expect(await closeStaleSessions(at(10))).toBe(0);
        const stored = await Session.findById(session._id);
        expect(stored?.endedAt).toBeUndefined();
    });

    it('closes the stale instance session and leaves the silent PWA one open, in the same sweep', async () => {
        const a = await User.create({ deviceId: 'pwaPlayer' });
        const b = await User.create({ deviceId: 'bloxPlayer' });
        const pwa = await openSession({ userId: a._id, platform: 'pwa' });
        await reconcilePresence('deadInstance', [b._id], at(0));
        await Session.updateMany({}, { $set: { lastSeenAt: at(0) } });

        expect(await closeStaleSessions(at(10))).toBe(1);
        expect((await Session.findById(pwa._id))?.endedAt).toBeUndefined();
        expect((await Session.findOne({ userId: b._id }))?.endedAt?.toISOString()).toBe(at(0).toISOString());
    });

    it('leaves fresh sessions alone', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('liveInstance', [a._id], at(20));
        await Session.updateMany({}, { $set: { lastSeenAt: at(20) } });
        expect(await closeStaleSessions(at(10))).toBe(0);
    });
});

describe('presentIn', () => {
    it('returns the players whose session in that instance is still open', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await reconcilePresence('inst-A', [a._id, b._id], at(0));
        const ids = await presentIn('inst-A');
        expect(ids.map(String).sort()).toEqual([a._id.toString(), b._id.toString()].sort());
    });

    it('omits players who have left', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await reconcilePresence('inst-A', [a._id, b._id], at(0));
        await reconcilePresence('inst-A', [a._id], at(5));
        expect((await presentIn('inst-A')).map(String)).toEqual([a._id.toString()]);
    });

    it('does not leak players from another instance', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await reconcilePresence('inst-A', [a._id], at(0));
        await reconcilePresence('inst-B', [b._id], at(0));
        expect((await presentIn('inst-A')).map(String)).toEqual([a._id.toString()]);
    });

    it('returns an empty list for an unknown instance', async () => {
        expect(await presentIn('nobody-here')).toEqual([]);
    });
});
