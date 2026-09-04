### Task 3: The crowd — mix parsing, allocation, bots with memory

**Files:**
- Create: `server/src/engine/SyntheticCrowd.ts`
- Test: `server/src/engine/SyntheticCrowd.test.ts`

**Interfaces:**
- Consumes: Task 2's `PolicyId`, `POLICY_IDS`, `Memory`, `freshMemory`, `policyDistribution`, `sample`, `advance`, `Dist`; Task 1's `Rng`.
- Produces:
  - `type Mix = Partial<Record<PolicyId, number>>` (positive weights, any scale).
  - `DEFAULT_MIX: Mix = { wsls: 35, counter: 20, conform: 15, rocky: 10, random: 20 }`; `DEFAULT_STRENGTH = 0.7`.
  - `parseMix(spec: string): Mix` — throws `Error` with a boot-log-ready message on bad input.
  - `formatMix(mix: Mix): string` — the inverse, for logging.
  - `allocate(size: number, mix: Mix): PolicyId[]` — exact largest-remainder allocation in `POLICY_IDS` order.
  - `interface Crowd { readonly size: number; throws(roundCount: number): Record<Throw, number>; observe(worldThrow: Throw): void; expected(): Dist }`
  - `createCrowd(opts: { size: number; mix?: Mix; strength?: number; rng: Rng }): Crowd`

- [ ] **Step 1: Write the failing test**

```ts
// server/src/engine/SyntheticCrowd.test.ts
import { describe, it, expect } from 'vitest';
import { parseMix, formatMix, allocate, createCrowd, DEFAULT_MIX, DEFAULT_STRENGTH } from './SyntheticCrowd';
import { mulberry32 } from './Prng';

describe('parseMix', () => {
    it('parses id:weight pairs, tolerating whitespace', () => {
        expect(parseMix('wsls:35, counter:20 ,conform:15')).toEqual({ wsls: 35, counter: 20, conform: 15 });
    });
    it('refuses an unknown archetype with a message naming the known ones', () => {
        expect(() => parseMix('wsls:1,ninja:2')).toThrow(
            'CROWD_MIX: unknown archetype "ninja" (known: random, wsls, counter, conform, rocky, second)');
    });
    it('refuses a non-positive or non-numeric weight', () => {
        expect(() => parseMix('wsls:0')).toThrow('CROWD_MIX: weight for "wsls" must be a positive number, got "0"');
        expect(() => parseMix('wsls:lots')).toThrow('CROWD_MIX: weight for "wsls" must be a positive number, got "lots"');
    });
    it('refuses an empty spec and a repeated id', () => {
        expect(() => parseMix('')).toThrow('CROWD_MIX: empty');
        expect(() => parseMix('wsls:1,wsls:2')).toThrow('CROWD_MIX: "wsls" listed twice');
    });
    it('round-trips through formatMix', () => {
        expect(parseMix(formatMix(DEFAULT_MIX))).toEqual(DEFAULT_MIX);
    });
});

describe('allocate', () => {
    it('splits a size across the mix exactly, largest remainder, in POLICY_IDS order', () => {
        // 10 bots over wsls:35 counter:20 conform:15 rocky:10 random:20 -> quotas 3.5,2,1.5,1,2
        // floors 3,2,1,1,2 = 9; one remainder -> largest fraction tie (wsls .5, conform .5) -> wsls first
        expect(allocate(10, DEFAULT_MIX)).toEqual([
            'random', 'random', 'wsls', 'wsls', 'wsls', 'wsls', 'counter', 'counter', 'conform', 'rocky',
        ]);
    });
    it('a single archetype gets everything; zero size gets nothing', () => {
        expect(allocate(3, { counter: 1 })).toEqual(['counter', 'counter', 'counter']);
        expect(allocate(0, DEFAULT_MIX)).toEqual([]);
    });
});

describe('createCrowd', () => {
    it('tallies exactly `size` throws every round', () => {
        const crowd = createCrowd({ size: 30, rng: mulberry32(1) });
        const c = crowd.throws(0);
        expect(c.R + c.P + c.S).toBe(30);
        expect(crowd.size).toBe(30);
    });

    it('is deterministic: same seed and same observed world throws give the same tallies', () => {
        const a = createCrowd({ size: 25, rng: mulberry32(11) });
        const b = createCrowd({ size: 25, rng: mulberry32(11) });
        const worlds = ['R', 'P', 'P', 'S', 'R'] as const;
        for (const w of worlds) {
            expect(a.throws(0)).toEqual(b.throws(0));
            a.observe(w); b.observe(w);
        }
        expect(a.throws(0)).toEqual(b.throws(0));
    });

    it('bots learn from observe(): an all-counter crowd at strength 1 throws what beats the last world', () => {
        const crowd = createCrowd({ size: 5, mix: { counter: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.throws(0);
        crowd.observe('R');
        expect(crowd.throws(1)).toEqual({ R: 0, P: 5, S: 0 });
        crowd.observe('P');
        expect(crowd.throws(2)).toEqual({ R: 0, P: 0, S: 5 });
    });

    it('an all-conform crowd at strength 1 repeats the last world', () => {
        const crowd = createCrowd({ size: 4, mix: { conform: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.throws(0);
        crowd.observe('S');
        expect(crowd.throws(1)).toEqual({ R: 0, P: 0, S: 4 });
    });

    it('observe() without a preceding throws() still teaches the bots the world throw', () => {
        const crowd = createCrowd({ size: 3, mix: { conform: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.observe('P');
        expect(crowd.throws(0)).toEqual({ R: 0, P: 3, S: 0 });
    });

    it('expected() sums the bots\' current distributions', () => {
        const crowd = createCrowd({ size: 4, mix: { counter: 1 }, strength: 1, rng: mulberry32(2) });
        crowd.observe('R');
        expect(crowd.expected()).toEqual({ R: 0, P: 4, S: 0 });
    });

    it('defaults to DEFAULT_MIX and DEFAULT_STRENGTH', () => {
        expect(DEFAULT_STRENGTH).toBe(0.7);
        expect(DEFAULT_MIX).toEqual({ wsls: 35, counter: 20, conform: 15, rocky: 10, random: 20 });
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/SyntheticCrowd.test.ts`
Expected: FAIL — `Cannot find module './SyntheticCrowd'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/engine/SyntheticCrowd.ts
// A crowd is a bag of policies (spec §2). Each bot is one archetype plus a small memory; the
// crowd tallies their throws and, once the World Throw is decided, tells every bot what
// happened so it can react next round. Bots have no pot and never bank: a bot's "result" is
// only the input to its next decision.
//
// Composition is EXACT, not sampled: `allocate` gives a 30-bot crowd the same archetype split
// every boot, so CROWD_SEED reproduces a run rather than a distribution of runs.
import { Throw } from './GameRules';
import { Rng } from './Prng';
import {
    PolicyId, POLICY_IDS, Memory, Dist, freshMemory, policyDistribution, sample, advance,
} from './CrowdPolicies';

export type Mix = Partial<Record<PolicyId, number>>;

// A hypothesis (spec §2), tuned by the simulator's readability experiment before it is trusted.
export const DEFAULT_MIX: Mix = { wsls: 35, counter: 20, conform: 15, rocky: 10, random: 20 };
export const DEFAULT_STRENGTH = 0.7;

export function parseMix(spec: string): Mix {
    const parts = spec.split(',').map(s => s.trim()).filter(s => s.length > 0);
    if (parts.length === 0) throw new Error('CROWD_MIX: empty');
    const mix: Mix = {};
    for (const part of parts) {
        const [rawId, rawWeight] = part.split(':').map(s => s.trim());
        const id = rawId as PolicyId;
        if (!POLICY_IDS.includes(id)) {
            throw new Error(`CROWD_MIX: unknown archetype "${rawId}" (known: ${POLICY_IDS.join(', ')})`);
        }
        const weight = Number(rawWeight);
        if (rawWeight === undefined || rawWeight === '' || !Number.isFinite(weight) || weight <= 0) {
            throw new Error(`CROWD_MIX: weight for "${id}" must be a positive number, got "${rawWeight ?? ''}"`);
        }
        if (mix[id] !== undefined) throw new Error(`CROWD_MIX: "${id}" listed twice`);
        mix[id] = weight;
    }
    return mix;
}

export function formatMix(mix: Mix): string {
    return POLICY_IDS.filter(id => (mix[id] ?? 0) > 0).map(id => `${id}:${mix[id]}`).join(',');
}

// Largest-remainder allocation in POLICY_IDS order; ties on the fractional part go to the
// earlier id. Deterministic by construction.
export function allocate(size: number, mix: Mix): PolicyId[] {
    const ids = POLICY_IDS.filter(id => (mix[id] ?? 0) > 0);
    const total = ids.reduce((s, id) => s + (mix[id] as number), 0);
    if (size <= 0 || ids.length === 0 || total <= 0) return [];
    const quotas = ids.map(id => (size * (mix[id] as number)) / total);
    const counts = quotas.map(q => Math.floor(q));
    let remainder = size - counts.reduce((s, c) => s + c, 0);
    const byFraction = ids
        .map((_, i) => i)
        .sort((a, b) => (quotas[b] - counts[b]) - (quotas[a] - counts[a]) || a - b);
    for (const i of byFraction) {
        if (remainder === 0) break;
        counts[i]++;
        remainder--;
    }
    const out: PolicyId[] = [];
    ids.forEach((id, i) => { for (let k = 0; k < counts[i]; k++) out.push(id); });
    return out;
}

export interface Crowd {
    readonly size: number;
    throws(roundCount: number): Record<Throw, number>;
    observe(worldThrow: Throw): void;
    expected(): Dist; // sum of every bot's current distribution — the oracle's input
}

interface Bot {
    id: PolicyId;
    memory: Memory;
    pending?: Throw; // this round's throw, awaiting the World Throw
}

export function createCrowd(opts: { size: number; mix?: Mix; strength?: number; rng: Rng }): Crowd {
    const strength = opts.strength ?? DEFAULT_STRENGTH;
    const bots: Bot[] = allocate(opts.size, opts.mix ?? DEFAULT_MIX).map(id => ({ id, memory: freshMemory() }));
    return {
        size: bots.length,
        throws() {
            const counts: Record<Throw, number> = { R: 0, P: 0, S: 0 };
            for (const bot of bots) {
                const t = sample(policyDistribution(bot.id, bot.memory, strength), opts.rng);
                bot.pending = t;
                counts[t]++;
            }
            return counts;
        },
        observe(worldThrow) {
            for (const bot of bots) {
                if (bot.pending) {
                    bot.memory = advance(bot.memory, bot.pending, worldThrow);
                    bot.pending = undefined;
                } else {
                    bot.memory = { ...bot.memory, lastWorld: worldThrow };
                }
            }
        },
        expected() {
            const sum: Dist = { R: 0, P: 0, S: 0 };
            for (const bot of bots) {
                const d = policyDistribution(bot.id, bot.memory, strength);
                sum.R += d.R; sum.P += d.P; sum.S += d.S;
            }
            return sum;
        },
    };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/engine/SyntheticCrowd.test.ts`
Expected: PASS. If the `allocate(10, DEFAULT_MIX)` expectation fails on order, the bug is in the tie-break (`|| a - b`), not the test: the spec fixes `POLICY_IDS` order.

- [ ] **Step 5: Commit**

```bash
git add src/engine/SyntheticCrowd.ts src/engine/SyntheticCrowd.test.ts
git commit -m "feat(crowd): SyntheticCrowd -- exact archetype allocation, per-bot memory, observe() teaches the world throw

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

