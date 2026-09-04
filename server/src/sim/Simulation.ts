// The offline simulator (spec §6): the same SyntheticCrowd the server runs, plus modelled humans
// who are just policies with a pot and a bank rule. No database, no timers, no engine — it calls
// deriveWorldThrow directly with an injected rng, so a run is reproducible from its seed.
import { Throw, RoundResult, deriveWorldThrow, calculateResult, nextPot, keepOptions } from '../engine/GameRules';
import {
    PolicyId, Memory, freshMemory, policyDistribution, sample, advance, WHAT_BEATS, Dist,
} from '../engine/CrowdPolicies';
import { createCrowd, Mix, DEFAULT_STRENGTH } from '../engine/SyntheticCrowd';
import { mulberry32 } from '../engine/Prng';

export type BankRule = { kind: 'ride' } | { kind: 'rung'; at: number } | { kind: 'ratio' };
export type HumanPolicy = PolicyId | 'oracle';

export interface HumanSpec {
    id: string;
    policy: HumanPolicy;
    strength: number;
    bank: BankRule;
}

export interface HumanRoundRecord {
    throw: Throw;
    result: RoundResult;
    potAfter: number; // after this round's result AND this round's bank decision
    banked: number;   // points moved to the wallet this round
}

export interface RoundRecord {
    world: Throw;
    counts: Record<Throw, number>;
    humans: HumanRoundRecord[];
}

export interface SimOptions {
    rounds: number;
    crowdSize: number;
    mix?: Mix;
    crowdStrength?: number;
    humans: HumanSpec[];
    seed: number;
    minParticipants?: number;
}

// Pure. `banked` is the human's cumulative wallet — the ratio rule needs it.
export function applyBank(rule: BankRule, pot: number, banked: number): { pot: number; banked: number } {
    if (pot <= 0) return { pot, banked };
    switch (rule.kind) {
        case 'ride':
            return { pot, banked };
        case 'rung':
            return pot >= rule.at ? { pot: 0, banked: banked + pot } : { pot, banked };
        case 'ratio': {
            // docs/superpowers/specs/2026-08-26-partial-banking-design.md: f* = (b + 1) / 4 with
            // b = bank ÷ pot, and riding the whole pot is optimal once b ≥ 3.
            const b = banked / pot;
            if (b >= 3) return { pot, banked };
            const target = ((b + 1) / 4) * pot;
            const keep = keepOptions(pot).filter(k => k <= target).pop() ?? 0;
            return { pot: keep, banked: banked + (pot - keep) };
        }
    }
}

function argmax(d: Dist): Throw {
    let best: Throw = 'R';
    for (const t of ['P', 'S'] as Throw[]) if (d[t] > d[best]) best = t;
    return best;
}

export function runSimulation(o: SimOptions): RoundRecord[] {
    const rng = mulberry32(o.seed);
    const crowd = createCrowd({
        size: o.crowdSize, mix: o.mix, strength: o.crowdStrength ?? DEFAULT_STRENGTH, rng,
    });
    const state = o.humans.map(() => ({ memory: freshMemory() as Memory, pot: 0, banked: 0 }));
    const log: RoundRecord[] = [];

    for (let round = 0; round < o.rounds; round++) {
        const humanThrows: Throw[] = o.humans.map((h, i) => {
            if (h.policy === 'oracle') return WHAT_BEATS[argmax(crowd.expected())];
            return sample(policyDistribution(h.policy, state[i].memory, h.strength), rng);
        });
        const counts = crowd.throws(round);
        for (const t of humanThrows) counts[t]++;
        const world = deriveWorldThrow(counts, { minParticipants: o.minParticipants ?? 5, random: rng });
        crowd.observe(world);

        const humans: HumanRoundRecord[] = o.humans.map((h, i) => {
            const s = state[i];
            const result = calculateResult(humanThrows[i], world);
            const potAfterResult = nextPot(s.pot, result);
            const after = applyBank(h.bank, potAfterResult, s.banked);
            const bankedNow = after.banked - s.banked;
            s.pot = after.pot;
            s.banked = after.banked;
            s.memory = advance(s.memory, humanThrows[i], world);
            return { throw: humanThrows[i], result, potAfter: s.pot, banked: bankedNow };
        });
        log.push({ world, counts, humans });
    }
    return log;
}
