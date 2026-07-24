import { EventEmitter } from 'events';
import { Throw } from './GameRules';

export type Phase = 'ACTIVE' | 'TALLY' | 'REVEAL';

export interface ThrowEntry {
    throw: Throw;
    seq: number;
    platform: 'pwa' | 'roblox';
    deviceId?: string;
    userId?: string;
    robloxUserId?: string;
    instanceId?: string;
}

export interface EngineConfig {
    activeSeconds: number;
    tallySeconds: number;
    revealSeconds: number;
    pickWorldThrow: (roundCount: number, counts: Record<Throw, number>) => Throw;
    makeRoundId: () => string;
}

export interface EngineSnapshot {
    roundId: string;
    phase: Phase;
    secondsLeft: number;
    roundCount: number;
}

export interface RoundClosedEvent {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;
    throws: Map<string, ThrowEntry>;
}

export class RoundEngine extends EventEmitter {
    private phase: Phase = 'ACTIVE';
    private secondsLeft: number;
    private roundCount: number;
    private roundId: string;
    private throws = new Map<string, ThrowEntry>();
    private ticking = false;

    constructor(private cfg: EngineConfig, initialRoundCount = 0) {
        super();
        this.secondsLeft = cfg.activeSeconds;
        this.roundCount = initialRoundCount;
        this.roundId = cfg.makeRoundId();
    }

    snapshot(): EngineSnapshot {
        return {
            roundId: this.roundId,
            phase: this.phase,
            secondsLeft: this.secondsLeft,
            roundCount: this.roundCount,
        };
    }

    durationsMs(): { activeMs: number; tallyMs: number; revealMs: number } {
        return {
            activeMs: this.cfg.activeSeconds * 1000,
            tallyMs: this.cfg.tallySeconds * 1000,
            revealMs: this.cfg.revealSeconds * 1000,
        };
    }

    submitThrow(key: string, entry: ThrowEntry): { accepted: boolean; reason?: string } {
        if (this.phase !== 'ACTIVE') return { accepted: false, reason: 'PICKS_CLOSED' };
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
            if (this.phase === 'ACTIVE') {
                const counts = this.countThrows();
                const worldThrow = this.cfg.pickWorldThrow(this.roundCount, counts);
                this.phase = 'TALLY';
                this.secondsLeft = this.cfg.tallySeconds;
                const event: RoundClosedEvent = {
                    roundId: this.roundId, worldThrow, counts, throws: new Map(this.throws),
                };
                this.emit('roundClosed', event);
            } else if (this.phase === 'TALLY') {
                this.phase = 'REVEAL';
                this.secondsLeft = this.cfg.revealSeconds;
                this.emit('revealStarted', { roundId: this.roundId });
            } else {
                this.roundCount++;
                this.roundId = this.cfg.makeRoundId();
                this.throws.clear();
                this.phase = 'ACTIVE';
                this.secondsLeft = this.cfg.activeSeconds;
                this.emit('roundStarted', this.snapshot());
            }
        }
        this.emit('tick', this.snapshot());
        } finally {
            this.ticking = false;
        }
    }
}
