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
