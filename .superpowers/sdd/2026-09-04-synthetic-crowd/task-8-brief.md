### Task 8: Simulator core — humans as policies with pots, and the bank rules

**Files:**
- Create: `server/src/sim/Simulation.ts`
- Test: `server/src/sim/Simulation.test.ts`

**Interfaces:**
- Consumes: `deriveWorldThrow`, `calculateResult`, `nextPot`, `keepOptions`, `Throw`, `RoundResult` from `../engine/GameRules`; Task 2's `PolicyId`, `Memory`, `freshMemory`, `policyDistribution`, `sample`, `advance`, `WHAT_BEATS`; Task 3's `createCrowd`, `Mix`, `DEFAULT_STRENGTH`; Task 1's `mulberry32`.
- Produces:
  - `type BankRule = { kind: 'ride' } | { kind: 'rung'; at: number } | { kind: 'ratio' }`
  - `type HumanPolicy = PolicyId | 'oracle'`
  - `interface HumanSpec { id: string; policy: HumanPolicy; strength: number; bank: BankRule }`
  - `interface HumanRoundRecord { throw: Throw; result: RoundResult; potAfter: number; banked: number }`
  - `interface RoundRecord { world: Throw; counts: Record<Throw, number>; humans: HumanRoundRecord[] }`
  - `interface SimOptions { rounds: number; crowdSize: number; mix?: Mix; crowdStrength?: number; humans: HumanSpec[]; seed: number; minParticipants?: number }`
  - `applyBank(rule: BankRule, pot: number, banked: number): { pot: number; banked: number }` (pure)
  - `runSimulation(o: SimOptions): RoundRecord[]`

- [ ] **Step 1: Write the failing test**

```ts
// server/src/sim/Simulation.test.ts
import { describe, it, expect } from 'vitest';
import { applyBank, runSimulation, HumanSpec } from './Simulation';

describe('applyBank', () => {
    it('ride never banks', () => {
        expect(applyBank({ kind: 'ride' }, 27, 0)).toEqual({ pot: 27, banked: 0 });
    });
    it('rung banks the whole pot once it reaches the rung', () => {
        expect(applyBank({ kind: 'rung', at: 9 }, 3, 0)).toEqual({ pot: 3, banked: 0 });
        expect(applyBank({ kind: 'rung', at: 9 }, 9, 5)).toEqual({ pot: 0, banked: 14 });
    });
    it('ratio keeps the largest rung at or below f*·pot, f* = (bank÷pot + 1)/4 (partial-banking spec)', () => {
        // bank 0, pot 27: f* = 0.25 -> target 6.75 -> keep 3, bank 24
        expect(applyBank({ kind: 'ratio' }, 27, 0)).toEqual({ pot: 3, banked: 24 });
        // bank 27, pot 27: b = 1 -> f* = 0.5 -> target 13.5 -> keep 9, bank 18
        expect(applyBank({ kind: 'ratio' }, 27, 27)).toEqual({ pot: 9, banked: 45 });
        // bank 81, pot 27: b = 3 -> ride everything
        expect(applyBank({ kind: 'ratio' }, 27, 81)).toEqual({ pot: 27, banked: 81 });
        // pot 1, bank 0: f* = 0.25 -> target 0.25 -> keep 0, bank 1
        expect(applyBank({ kind: 'ratio' }, 1, 0)).toEqual({ pot: 0, banked: 1 });
        // empty pot: nothing to decide
        expect(applyBank({ kind: 'ratio' }, 0, 10)).toEqual({ pot: 0, banked: 10 });
    });
});

describe('runSimulation', () => {
    const counter: HumanSpec = { id: 'h', policy: 'counter', strength: 1, bank: { kind: 'ride' } };

    it('produces one record per round with one human record per human', () => {
        const log = runSimulation({ rounds: 5, crowdSize: 6, humans: [counter], seed: 1 });
        expect(log).toHaveLength(5);
        for (const r of log) {
            expect(['R', 'P', 'S']).toContain(r.world);
            expect(r.counts.R + r.counts.P + r.counts.S).toBe(7);
            expect(r.humans).toHaveLength(1);
        }
    });

    it('is deterministic for a seed', () => {
        const a = runSimulation({ rounds: 50, crowdSize: 20, humans: [counter], seed: 9 });
        const b = runSimulation({ rounds: 50, crowdSize: 20, humans: [counter], seed: 9 });
        expect(a).toEqual(b);
    });

    it('a strength-1 counter against an all-conform strength-1 crowd wins every round after the first', () => {
        // Conform bots repeat the last world; the plurality is therefore the last world; the
        // counter throws what beats it. The one human cannot outvote 10 bots, so world = last world.
        const log = runSimulation({
            rounds: 20, crowdSize: 10, mix: { conform: 1 }, crowdStrength: 1, humans: [counter], seed: 3,
        });
        expect(log.slice(1).every(r => r.humans[0].result === 'WIN')).toBe(true);
        // Round 0 has no history on either side, so its result is whatever the seed gives;
        // the ladder after it is exact either way.
        const round0Won = log[0].humans[0].result === 'WIN';
        expect(log[19].humans[0].potAfter).toBe(round0Won ? 3 ** 19 : 3 ** 18);
    });

    it('the pot follows the rules: a WIN triples, banking at the rung moves the whole pot out', () => {
        const banker: HumanSpec = { id: 'b', policy: 'counter', strength: 1, bank: { kind: 'rung', at: 9 } };
        const log = runSimulation({
            rounds: 12, crowdSize: 10, mix: { conform: 1 }, crowdStrength: 1, humans: [banker], seed: 3,
        });
        // Every round after the first is a WIN (see the test above). Walk the ladder from
        // whatever round 0 left: 0->1->3->9 (bank 9, pot 0) -> 1 -> 3 -> 9 (bank) ...
        let pot = log[0].humans[0].potAfter;
        for (const r of log.slice(1)) {
            const h = r.humans[0];
            expect(h.result).toBe('WIN');
            const grown = pot === 0 ? 1 : pot * 3;
            if (grown >= 9) {
                expect(h.banked).toBe(grown);
                expect(h.potAfter).toBe(0);
            } else {
                expect(h.banked).toBe(0);
                expect(h.potAfter).toBe(grown);
            }
            pot = h.potAfter;
        }
        expect(log.filter(r => r.humans[0].banked === 9).length).toBeGreaterThanOrEqual(3);
    });

    it('oracle throws what beats the crowd\'s expected plurality', () => {
        const oracle: HumanSpec = { id: 'o', policy: 'oracle', strength: 1, bank: { kind: 'ride' } };
        const log = runSimulation({
            rounds: 10, crowdSize: 10, mix: { counter: 1 }, crowdStrength: 1, humans: [oracle], seed: 5,
        });
        expect(log.slice(1).every(r => r.humans[0].result === 'WIN')).toBe(true);
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/sim/Simulation.test.ts`
Expected: FAIL — `Cannot find module './Simulation'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/sim/Simulation.ts
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/sim/Simulation.test.ts`
Expected: PASS. Note on the all-conform test: round 0 has no history, so bots and human throw from their no-memory distributions and the outcome is whatever the seed gives; from round 1 the invariant holds, which is why the assertions start at `slice(1)`.

- [ ] **Step 5: Commit**

```bash
git add src/sim/Simulation.ts src/sim/Simulation.test.ts
git commit -m "feat(sim): runSimulation -- humans as policies with pots, three bank rules, the oracle ceiling

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

