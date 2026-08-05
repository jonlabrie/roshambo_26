import { describe, it, expect, vi } from 'vitest';
import { RoundEngine, Phase } from './RoundEngine';

function makeEngine(overrides: Partial<ConstructorParameters<typeof RoundEngine>[0]> = {}) {
    let n = 0;
    return new RoundEngine({
        openSeconds: 3,
        lockSeconds: 2,
        revealSeconds: 2,
        pickWorldThrow: () => 'R',
        makeRoundId: () => `round-${++n}`,
        ...overrides,
    });
}

function tickTo(engine: RoundEngine, phase: Phase, maxTicks = 50): void {
    for (let i = 0; i < maxTicks; i++) {
        if (engine.snapshot().phase === phase) return;
        engine.tick();
    }
    throw new Error(`never reached ${phase}`);
}

describe('the phase structure', () => {
    it('reports durations as openMs/lockMs/revealMs', () => {
        expect(makeEngine().durationsMs()).toEqual({ openMs: 3000, lockMs: 2000, revealMs: 2000 });
    });
});

describe('throw acceptance by phase', () => {
    const entry = () => ({ throw: 'R' as const, seq: 1, platform: 'pwa' as const, deviceId: 'd1' });

    it('accepts during OPEN', () => {
        expect(makeEngine().submitThrow('k', entry())).toEqual({ accepted: true });
    });

    it('accepts during LOCK — game servers are still flushing', () => {
        const e = makeEngine();
        tickTo(e, 'LOCK');
        expect(e.submitThrow('k', entry())).toEqual({ accepted: true });
    });

    it('rejects during REVEAL', () => {
        const e = makeEngine();
        tickTo(e, 'REVEAL');
        expect(e.submitThrow('k', entry())).toEqual({ accepted: false, reason: 'PICKS_CLOSED' });
    });
});

describe('the world throw is decided at the end of LOCK', () => {
    it('does not emit roundClosed at the end of OPEN', () => {
        const e = makeEngine();
        const closed: unknown[] = [];
        e.on('roundClosed', ev => closed.push(ev));
        tickTo(e, 'LOCK');
        expect(closed).toHaveLength(0);
    });

    it('emits roundClosed then revealStarted on the same transition', () => {
        const e = makeEngine();
        const order: string[] = [];
        e.on('roundClosed', () => order.push('roundClosed'));
        e.on('revealStarted', () => order.push('revealStarted'));
        tickTo(e, 'REVEAL');
        expect(order).toEqual(['roundClosed', 'revealStarted']);
    });

    it('counts a throw submitted during LOCK', () => {
        const e = makeEngine();
        tickTo(e, 'LOCK');
        e.submitThrow('late', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '7' });
        let counts: Record<string, number> | undefined;
        e.on('roundClosed', ev => { counts = ev.counts; });
        tickTo(e, 'REVEAL');
        expect(counts).toEqual({ R: 0, P: 0, S: 1 });
    });
});

describe('RoundEngine phases', () => {
    it('starts OPEN with a roundId and full countdown', () => {
        const e = makeEngine();
        expect(e.snapshot()).toMatchObject({
            phase: 'OPEN', secondsLeft: 3, roundCount: 0, roundId: 'round-1',
        });
    });

    it('counts down and walks OPEN -> LOCK -> REVEAL -> OPEN', () => {
        const e = makeEngine();
        const phases: Phase[] = [];
        for (let i = 0; i < 7; i++) { e.tick(); phases.push(e.snapshot().phase); }
        // 3 OPEN ticks (3->2->1->0 transitions on the 3rd), 2 LOCK, 2 REVEAL
        expect(phases).toEqual(['OPEN', 'OPEN', 'LOCK', 'LOCK', 'REVEAL', 'REVEAL', 'OPEN']);
    });

    it('increments roundCount and issues a fresh roundId on the new OPEN', () => {
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
        expect(tick).toHaveBeenCalledWith(expect.objectContaining({ phase: 'OPEN', secondsLeft: 2 }));
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

        // Drain to round-close (5 ticks: 3 OPEN + 2 LOCK — roundClosed now fires
        // at the end of LOCK, not the end of OPEN)
        for (let i = 0; i < 5; i++) {
            tickFires = 0;
            e.tick();
            phases.push(e.snapshot().phase);
            tickCount.push(tickFires);
        }

        // After 5 ticks: phases should be OPEN, OPEN, LOCK, LOCK, REVEAL
        // (the nested call from the listener must NOT push past REVEAL)
        expect(phases).toEqual(['OPEN', 'OPEN', 'LOCK', 'LOCK', 'REVEAL']);
        // The outer tick() on tick #5 emits exactly 1 'tick' event;
        // the nested call is swallowed so no extra 'tick' fires.
        expect(tickCount[4]).toBe(1);
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

        // Tick to round close (5 ticks: 3 OPEN + 2 LOCK — the world throw is
        // decided at the end of LOCK)
        for (let i = 0; i < 5; i++) e.tick();

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

        // Tick through a full OPEN+LOCK+REVEAL cycle to the next OPEN (7 total)
        for (let i = 0; i < 7; i++) e.tick();

        // Engine should now be in the next OPEN (internal throws cleared)
        expect(e.snapshot().phase).toBe('OPEN');
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
    it('accepts during OPEN and counts into the tally', () => {
        const e = makeEngine();
        expect(e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        expect(e.submitThrow('pwa:devA', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'devA' }).accepted).toBe(true);
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 5; i++) e.tick(); // through OPEN and LOCK to round close
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 1, P: 1, S: 0 });
    });

    it('last write wins for equal or newer seq (player changes pick)', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' });
        expect(e.submitThrow('roblox:1', { throw: 'P', seq: 2, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 5; i++) e.tick(); // through OPEN and LOCK to round close
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 0, P: 1, S: 0 });
    });

    it('rejects stale seq (delayed retransmit cannot clobber a newer pick)', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'P', seq: 5, platform: 'roblox', robloxUserId: '1' });
        const r = e.submitThrow('roblox:1', { throw: 'R', seq: 3, platform: 'roblox', robloxUserId: '1' });
        expect(r).toEqual({ accepted: false, reason: 'STALE_SEQ' });
    });

    it('rejects during REVEAL', () => {
        const e = makeEngine();
        for (let i = 0; i < 5; i++) e.tick(); // now REVEAL
        const r = e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' });
        expect(r).toEqual({ accepted: false, reason: 'PICKS_CLOSED' });
    });

    it('clears throws between rounds', () => {
        const e = makeEngine();
        e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' });
        for (let i = 0; i < 7; i++) e.tick(); // full cycle into next OPEN
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 5; i++) e.tick(); // through OPEN and LOCK to round close
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 0, P: 0, S: 0 });
    });

    it('accepts an equal-seq resubmit (idempotent retry) and the resubmitted value wins', () => {
        const e = makeEngine();
        expect(e.submitThrow('roblox:1', { throw: 'R', seq: 1, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        expect(e.submitThrow('roblox:1', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '1' }).accepted).toBe(true);
        const closed = vi.fn();
        e.on('roundClosed', closed);
        for (let i = 0; i < 5; i++) e.tick(); // through OPEN and LOCK to round close
        expect(closed.mock.calls[0][0].counts).toEqual({ R: 0, P: 1, S: 0 });
    });
});

describe('RoundEngine exact phase clock', () => {
    it('stamps phaseEndsAtMs from the injected clock at construction and each transition', () => {
        let t = 100_000;
        const engine = makeEngine({ nowMs: () => t });
        // construction: OPEN for 3s from t=100000
        expect(engine.snapshot().phaseEndsAtMs).toBe(103_000);
        t = 101_000; engine.tick();
        t = 102_000; engine.tick();
        t = 103_250; engine.tick(); // transition tick lands 250ms late (interval jitter)
        // LOCK stamped from the ACTUAL transition moment, not the quantized schedule
        expect(engine.snapshot().phase).toBe('LOCK');
        expect(engine.snapshot().phaseEndsAtMs).toBe(103_250 + 2_000);
    });
    it('omits phaseEndsAtMs without an injected clock (quantized fallback stays)', () => {
        expect(makeEngine().snapshot().phaseEndsAtMs).toBeUndefined();
    });
});
