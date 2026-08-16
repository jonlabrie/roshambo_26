import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import Round from './models/Round';
import Session from './models/Session';
import { openSession, closeSession, touchSession, roundsPresent } from './sessions';

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
