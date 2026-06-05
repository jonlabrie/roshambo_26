import { describe, it, expect, vi } from 'vitest';
import { RoundEngine, Phase } from './RoundEngine';

function makeEngine(overrides: Partial<ConstructorParameters<typeof RoundEngine>[0]> = {}) {
    let n = 0;
    return new RoundEngine({
        activeSeconds: 3,
        tallySeconds: 2,
        revealSeconds: 2,
        pickWorldThrow: () => 'R',
        makeRoundId: () => `round-${++n}`,
        ...overrides,
    });
}

describe('RoundEngine phases', () => {
    it('starts ACTIVE with a roundId and full countdown', () => {
        const e = makeEngine();
        expect(e.snapshot()).toMatchObject({
            phase: 'ACTIVE', secondsLeft: 3, roundCount: 0, roundId: 'round-1',
        });
    });

    it('counts down and walks ACTIVE -> TALLY -> REVEAL -> ACTIVE', () => {
        const e = makeEngine();
        const phases: Phase[] = [];
        for (let i = 0; i < 7; i++) { e.tick(); phases.push(e.snapshot().phase); }
        // 3 ACTIVE ticks (3->2->1->0 transitions on the 3rd), 2 TALLY, 2 REVEAL
        expect(phases).toEqual(['ACTIVE', 'ACTIVE', 'TALLY', 'TALLY', 'REVEAL', 'REVEAL', 'ACTIVE']);
    });

    it('increments roundCount and issues a fresh roundId on the new ACTIVE', () => {
        const e = makeEngine();
        for (let i = 0; i < 7; i++) e.tick();
        expect(e.snapshot()).toMatchObject({ roundCount: 1, roundId: 'round-2', secondsLeft: 3 });
    });

    it('emits lifecycle events with payloads', () => {
        const e = makeEngine();
        const closed = vi.fn(); const reveal = vi.fn(); const started = vi.fn();
        e.on('roundClosed', closed); e.on('revealStarted', reveal); e.on('roundStarted', started);
        for (let i = 0; i < 7; i++) e.tick();
        expect(closed).toHaveBeenCalledOnce();
        expect(closed.mock.calls[0][0]).toMatchObject({ roundId: 'round-1', worldThrow: 'R', counts: { R: 0, P: 0, S: 0 } });
        expect(reveal).toHaveBeenCalledWith({ roundId: 'round-1' });
        expect(started).toHaveBeenCalledOnce();
    });

    it('emits a tick event with the snapshot on every tick', () => {
        const e = makeEngine();
        const tick = vi.fn();
        e.on('tick', tick);
        e.tick();
        expect(tick).toHaveBeenCalledWith(expect.objectContaining({ phase: 'ACTIVE', secondsLeft: 2 }));
    });
});

describe('RoundEngine re-entrancy guard', () => {
    it('ignores a synchronous tick() called from inside a roundClosed listener', () => {
        const e = makeEngine();
        const phases: Phase[] = [];
        const tickCount: number[] = [];
        let tickFires = 0;

        e.on('tick', () => { tickFires++; });

        // A re-entrant call from inside 'roundClosed'
        e.on('roundClosed', () => {
            e.tick(); // should be ignored (re-entrancy guard)
        });

        // Drain to round-close (3 ticks on activeSeconds=3)
        for (let i = 0; i < 3; i++) {
            tickFires = 0;
            e.tick();
            phases.push(e.snapshot().phase);
            tickCount.push(tickFires);
        }

        // After 3 ticks: phases should be ACTIVE, ACTIVE, TALLY
        // (the nested call from the listener must NOT push to REVEAL)
        expect(phases).toEqual(['ACTIVE', 'ACTIVE', 'TALLY']);
        // The outer tick() on tick #3 emits exactly 1 'tick' event;
        // the nested call is swallowed so no extra 'tick' fires.
        expect(tickCount[2]).toBe(1);
    });
});

describe('RoundEngine authority lock-in', () => {
    it('passes correct roundCount and throw counts to pickWorldThrow', () => {
        const picker = vi.fn(() => 'R' as const);
        const e = makeEngine({ pickWorldThrow: picker });

        // Submit: 'roblox:1' R seq 1, 'roblox:2' R seq 1, 'pwa:devA' S seq 1
        e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox' });
        e.submitThrow('roblox:2', { throw: 'R', seq: 1, platform: 'roblox' });
        e.submitThrow('pwa:devA', { throw: 'S', seq: 1, platform: 'pwa' });

        // Tick to round close (3 ticks for activeSeconds=3)
        for (let i = 0; i < 3; i++) e.tick();

        expect(picker).toHaveBeenCalledOnce();
        expect(picker).toHaveBeenCalledWith(0, { R: 2, P: 0, S: 1 });
    });

    it('roundClosed throws map is isolated — captured payload survives the next round', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox' });
        e.submitThrow('roblox:2', { throw: 'R', seq: 1, platform: 'roblox' });
        e.submitThrow('pwa:devA', { throw: 'S', seq: 1, platform: 'pwa' });

        let capturedThrows: Map<string, unknown> | null = null;
        e.on('roundClosed', (evt) => { capturedThrows = evt.throws; });

        // Tick through to close (3) then full tally+reveal cycle to next ACTIVE (4 more = 7 total)
        for (let i = 0; i < 7; i++) e.tick();

        // Engine should now be in the next ACTIVE (internal throws cleared)
        expect(e.snapshot().phase).toBe('ACTIVE');
        expect(e.snapshot().roundCount).toBe(1);

        // But the captured map must still hold the original entries
        expect(capturedThrows).not.toBeNull();
        expect((capturedThrows as unknown as Map<string, unknown>).size).toBe(3);
        expect((capturedThrows as unknown as Map<string, unknown>).has('roblox:1')).toBe(true);
        expect((capturedThrows as unknown as Map<string, unknown>).has('roblox:2')).toBe(true);
        expect((capturedThrows as unknown as Map<string, unknown>).has('pwa:devA')).toBe(true);
    });
});

describe('RoundEngine.submitThrow', () => {
    it('accepts during ACTIVE and counts into the tally', () => {
        const e = makeEngine();
        expect(e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        expect(e.submitThrow('pwa:devA', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'devA' }).accepted).toBe(true);
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 3; i++) e.tick();
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 1, P: 1, S: 0 });
    });

    it('last write wins for equal or newer seq (player changes pick)', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' });
        expect(e.submitThrow('roblox:1', { throw: 'P', seq: 2, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 3; i++) e.tick();
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 0, P: 1, S: 0 });
    });

    it('rejects stale seq (delayed retransmit cannot clobber a newer pick)', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'P', seq: 5, platform: 'roblox', robloxUserId: '1' });
        const r = e.submitThrow('roblox:1', { throw: 'R', seq: 3, platform: 'roblox', robloxUserId: '1' });
        expect(r).toEqual({ accepted: false, reason: 'STALE_SEQ' });
    });

    it('rejects outside ACTIVE', () => {
        const e = makeEngine();
        for (let i = 0; i < 3; i++) e.tick(); // now TALLY
        const r = e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' });
        expect(r).toEqual({ accepted: false, reason: 'PICKS_CLOSED' });
    });

    it('clears throws between rounds', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' });
        for (let i = 0; i < 7; i++) e.tick(); // full cycle into next ACTIVE
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 3; i++) e.tick();
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 0, P: 0, S: 0 });
    });

    it('accepts an equal-seq resubmit (idempotent retry) and the resubmitted value wins', () => {
        const e = makeEngine();
        expect(e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        expect(e.submitThrow('roblox:1', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 3; i++) e.tick();
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 0, P: 1, S: 0 });
    });
});
