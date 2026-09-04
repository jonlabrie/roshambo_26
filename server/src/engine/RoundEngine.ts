import { EventEmitter } from 'events';
import { Throw } from './GameRules';

// OPEN: throws accepted and changeable — the round as a player experiences it.
// LOCK: player input closed, game servers flush their buffers, the API STILL ACCEPTS.
//       The world throw is decided at the END of LOCK.
// REVEAL: the ceremony. The only phase that rejects throws.
// Named for what happens in them, 2026-08-05. The previous names (ACTIVE/TALLY/REVEAL)
// were offset by one from the events: ACTIVE's last 2s were the lockout, and TALLY
// tallied nothing — the count is a synchronous loop that finishes in microseconds.
export type Phase = 'OPEN' | 'LOCK' | 'REVEAL';

export interface ThrowEntry {
    throw: Throw;
    seq: number;
    platform: 'pwa' | 'roblox';
    deviceId?: string;
    userId?: string;
    robloxUserId?: string;
    instanceId?: string;
}

// The synthetic crowd (spec §1). Structural on purpose: the engine needs "give me this round's
// bot tally" and "here is what the world did", nothing about archetypes or seeds.
export interface CrowdSource {
    throws(roundCount: number): Record<Throw, number>;
    observe(worldThrow: Throw): void;
}

export interface EngineConfig {
    openSeconds: number;
    lockSeconds: number;
    // Derived, not chosen: 3.45s drum settle + 3.0s glyph hold + 0.4s fade = 6.85.
    // It does not scale with round length — the drum takes 3.45s at any period.
    revealSeconds: number;
    pickWorldThrow: (roundCount: number, counts: Record<Throw, number>) => Throw;
    // Optional bot crowd merged into the tally BEFORE pickWorldThrow, so the distribution the
    // player sees and the World Throw it produced always agree. Absent → today's behaviour.
    crowd?: CrowdSource;
    makeRoundId: () => string;
    // Optional wall clock. When provided, each phase transition is stamped so
    // /state can report an EXACT phaseEndsAt: the integer-second countdown
    // otherwise quantizes it with a 0-1s sawtooth that made the published
    // round schedule wander (clients slewed after it every round).
    nowMs?: () => number;
}

export interface EngineSnapshot {
    roundId: string;
    phase: Phase;
    secondsLeft: number;
    roundCount: number;
    phaseEndsAtMs?: number;
}

export interface RoundClosedEvent {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;       // human + crowd: the world the player faced
    crowdCounts: Record<Throw, number>;  // the synthetic part of it, zeros when no crowd
    throws: Map<string, ThrowEntry>;     // humans only — the only thing settlement iterates
}

export class RoundEngine extends EventEmitter {
    private phase: Phase = 'OPEN';
    private secondsLeft: number;
    private roundCount: number;
    private roundId: string;
    private throws = new Map<string, ThrowEntry>();
    private ticking = false;

    private phaseEndsAtMs?: number;

    constructor(private cfg: EngineConfig, initialRoundCount = 0) {
        super();
        this.secondsLeft = cfg.openSeconds;
        this.roundCount = initialRoundCount;
        this.roundId = cfg.makeRoundId();
        this.stampPhaseEnd(cfg.openSeconds);
    }

    private stampPhaseEnd(durationSeconds: number): void {
        if (this.cfg.nowMs) this.phaseEndsAtMs = this.cfg.nowMs() + durationSeconds * 1000;
    }

    snapshot(): EngineSnapshot {
        return {
            roundId: this.roundId,
            phase: this.phase,
            secondsLeft: this.secondsLeft,
            roundCount: this.roundCount,
            phaseEndsAtMs: this.phaseEndsAtMs,
        };
    }

    durationsMs(): { openMs: number; lockMs: number; revealMs: number } {
        return {
            openMs: this.cfg.openSeconds * 1000,
            lockMs: this.cfg.lockSeconds * 1000,
            revealMs: this.cfg.revealSeconds * 1000,
        };
    }

    submitThrow(key: string, entry: ThrowEntry): { accepted: boolean; reason?: string } {
        // OPEN *and* LOCK. LOCK exists precisely so game servers can flush picks that
        // were already taken before player input closed — rejecting here would discard
        // every held pick in the arena.
        if (this.phase === 'REVEAL') return { accepted: false, reason: 'PICKS_CLOSED' };
        const existing = this.throws.get(key);
        if (existing && entry.seq < existing.seq) return { accepted: false, reason: 'STALE_SEQ' };
        this.throws.set(key, entry);
        return { accepted: true };
    }

    private countThrows(): Record<Throw, number> {
        const counts: Record<Throw, number> = { R: 0, P: 0, S: 0 };
        for (const entry of this.throws.values()) counts[entry.throw]++;
        return counts;
    }

    tick(): void {
        if (this.ticking) {
            console.warn('[ENGINE] re-entrant tick() ignored');
            return;
        }
        this.ticking = true;
        try {
        this.secondsLeft--;
        if (this.secondsLeft <= 0) {
            if (this.phase === 'OPEN') {
                // Player input closes; the API stays open so game servers can flush.
                // Nothing is decided here.
                this.phase = 'LOCK';
                this.secondsLeft = this.cfg.lockSeconds;
                this.stampPhaseEnd(this.cfg.lockSeconds);
            } else if (this.phase === 'LOCK') {
                // THE ANSWER IS DECIDED HERE, at round close, and REVEAL begins on the
                // same transition. roundClosed is async (settlement); revealStarted is
                // synchronous. socketAdapter's revealPending guard makes whichever
                // finishes last perform the broadcast, so the zero gap is safe.
                //
                // The crowd merges here and NOT inside pickWorldThrow: settlement builds the
                // persisted distribution from `counts`, so bots added in the picker would decide
                // the World Throw and then vanish from the card that explains it (spec §1).
                const humanCounts = this.countThrows();
                const crowdCounts = this.cfg.crowd ? this.cfg.crowd.throws(this.roundCount) : { R: 0, P: 0, S: 0 };
                const counts: Record<Throw, number> = {
                    R: humanCounts.R + crowdCounts.R,
                    P: humanCounts.P + crowdCounts.P,
                    S: humanCounts.S + crowdCounts.S,
                };
                const worldThrow = this.cfg.pickWorldThrow(this.roundCount, counts);
                this.cfg.crowd?.observe(worldThrow);
                this.phase = 'REVEAL';
                this.secondsLeft = this.cfg.revealSeconds;
                this.stampPhaseEnd(this.cfg.revealSeconds);
                const event: RoundClosedEvent = {
                    roundId: this.roundId, worldThrow, counts, crowdCounts, throws: new Map(this.throws),
                };
                this.emit('roundClosed', event);
                this.emit('revealStarted', { roundId: this.roundId });
            } else {
                this.roundCount++;
                this.roundId = this.cfg.makeRoundId();
                this.throws.clear();
                this.phase = 'OPEN';
                this.secondsLeft = this.cfg.openSeconds;
                this.stampPhaseEnd(this.cfg.openSeconds);
                this.emit('roundStarted', this.snapshot());
            }
        }
        this.emit('tick', this.snapshot());
        } finally {
            this.ticking = false;
        }
    }
}
