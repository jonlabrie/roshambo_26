### Task 2: Archetype policies

**Files:**
- Create: `server/src/engine/CrowdPolicies.ts`
- Test: `server/src/engine/CrowdPolicies.test.ts`

**Interfaces:**
- Consumes: `Throw`, `RoundResult`, `calculateResult` from `./GameRules`; `Rng` from `./Prng`.
- Produces:
  - `type PolicyId = 'random' | 'wsls' | 'counter' | 'conform' | 'rocky' | 'second'`; `POLICY_IDS: PolicyId[]` in that order.
  - `type Dist = Record<Throw, number>` (probabilities summing to 1).
  - `interface Memory { lastThrow?: Throw; lastResult?: RoundResult; lastWorld?: Throw; repeatRun: number }`; `freshMemory(): Memory`.
  - `WHAT_BEATS: Record<Throw, Throw>` (`{R:'P', P:'S', S:'R'}`), `CLOCKWISE: Record<Throw, Throw>` (`{R:'S', S:'P', P:'R'}`), `UNIFORM: Dist`.
  - `policyDistribution(id: PolicyId, m: Memory, strength: number): Dist`
  - `sample(d: Dist, rng: Rng): Throw`
  - `advance(m: Memory, thrown: Throw, world: Throw): Memory` (pure, returns a new memory).

Policies are defined by their **distribution** given memory, and sampling is generic. That is what lets every archetype be tested exactly instead of statistically, and what lets the sim's `oracle` sum bot distributions (Task 9).

- [ ] **Step 1: Write the failing test**

```ts
// server/src/engine/CrowdPolicies.test.ts
import { describe, it, expect } from 'vitest';
import {
    POLICY_IDS, UNIFORM, WHAT_BEATS, CLOCKWISE, freshMemory,
    policyDistribution, sample, advance, Memory,
} from './CrowdPolicies';
import { mulberry32 } from './Prng';

const close = (d: Record<string, number>, want: Record<string, number>) => {
    for (const k of ['R', 'P', 'S']) expect(d[k]).toBeCloseTo(want[k], 6);
};

describe('vocabulary', () => {
    it('lists the six archetypes in a fixed order', () => {
        expect(POLICY_IDS).toEqual(['random', 'wsls', 'counter', 'conform', 'rocky', 'second']);
    });
    it('WHAT_BEATS and CLOCKWISE are the two rotations the archetypes use', () => {
        expect(WHAT_BEATS).toEqual({ R: 'P', P: 'S', S: 'R' });
        expect(CLOCKWISE).toEqual({ R: 'S', S: 'P', P: 'R' });
    });
});

describe('policyDistribution', () => {
    const p = 0.7;
    const noMemory = freshMemory();
    const afterWorldR: Memory = { lastThrow: 'S', lastResult: 'LOSS', lastWorld: 'R', repeatRun: 1 };

    it('every archetype is uniform with no memory, except rocky which leans rock', () => {
        for (const id of ['random', 'wsls', 'counter', 'conform', 'second'] as const) {
            close(policyDistribution(id, noMemory, p), UNIFORM);
        }
        // rocky: 0.7 * {0.5, 0.25, 0.25} + 0.3 * uniform
        close(policyDistribution('rocky', noMemory, p), { R: 0.45, P: 0.275, S: 0.275 });
    });

    it('random ignores memory', () => {
        close(policyDistribution('random', afterWorldR, p), UNIFORM);
    });

    it('counter throws what beats the last World Throw', () => {
        // world R -> P beats it: 0.7 + 0.3/3 = 0.8 on P, 0.1 each elsewhere
        close(policyDistribution('counter', afterWorldR, p), { R: 0.1, P: 0.8, S: 0.1 });
    });

    it('conform throws the last World Throw', () => {
        close(policyDistribution('conform', afterWorldR, p), { R: 0.8, P: 0.1, S: 0.1 });
    });

    it('second throws what beats the counter of the last World Throw', () => {
        // world R -> counter throws P -> S beats P
        close(policyDistribution('second', afterWorldR, p), { R: 0.1, P: 0.1, S: 0.8 });
    });

    it('wsls: win-stay at full strength', () => {
        const m: Memory = { lastThrow: 'P', lastResult: 'WIN', lastWorld: 'R', repeatRun: 1 };
        close(policyDistribution('wsls', m, p), { R: 0.1, P: 0.8, S: 0.1 });
    });

    it('wsls: lose-shift clockwise (R->S->P->R) at full strength', () => {
        const m: Memory = { lastThrow: 'R', lastResult: 'LOSS', lastWorld: 'P', repeatRun: 1 };
        close(policyDistribution('wsls', m, p), { R: 0.1, P: 0.1, S: 0.8 });
    });

    it('wsls: after SAFE, shifts clockwise at half strength', () => {
        const m: Memory = { lastThrow: 'R', lastResult: 'SAFE', lastWorld: 'R', repeatRun: 1 };
        // strength 0.35 on S, 0.65 uniform -> S: 0.35 + 0.65/3
        close(policyDistribution('wsls', m, p), { R: 0.65 / 3, P: 0.65 / 3, S: 0.35 + 0.65 / 3 });
    });

    it('rocky leans rock after the first throw and never throws a third repeat', () => {
        const lean: Memory = { lastThrow: 'P', lastResult: 'LOSS', lastWorld: 'S', repeatRun: 1 };
        close(policyDistribution('rocky', lean, p), { R: 0.7 * 0.4 + 0.1, P: 0.7 * 0.3 + 0.1, S: 0.7 * 0.3 + 0.1 });
        const twoRocks: Memory = { lastThrow: 'R', lastResult: 'SAFE', lastWorld: 'R', repeatRun: 2 };
        // R zeroed, {P: .3, S: .3} renormalised to {P: .5, S: .5}, then blended
        close(policyDistribution('rocky', twoRocks, p), { R: 0.1, P: 0.45, S: 0.45 });
    });

    it('strength 1 is a point mass; strength 0 is uniform', () => {
        close(policyDistribution('counter', afterWorldR, 1), { R: 0, P: 1, S: 0 });
        close(policyDistribution('counter', afterWorldR, 0), UNIFORM);
    });
});

describe('sample', () => {
    it('maps the unit interval onto R, P, S in that order', () => {
        const d = { R: 0.2, P: 0.5, S: 0.3 };
        expect(sample(d, () => 0.1)).toBe('R');
        expect(sample(d, () => 0.2)).toBe('P');
        expect(sample(d, () => 0.69)).toBe('P');
        expect(sample(d, () => 0.7)).toBe('S');
        expect(sample(d, () => 0.999999)).toBe('S');
    });
    it('is deterministic under a seeded rng', () => {
        const a = mulberry32(3), b = mulberry32(3);
        for (let i = 0; i < 50; i++) expect(sample(UNIFORM, a)).toBe(sample(UNIFORM, b));
    });
});

describe('advance', () => {
    it('records the throw, the result against the world, the world, and the repeat run', () => {
        const m1 = advance(freshMemory(), 'R', 'S');
        expect(m1).toEqual({ lastThrow: 'R', lastResult: 'WIN', lastWorld: 'S', repeatRun: 1 });
        const m2 = advance(m1, 'R', 'R');
        expect(m2).toEqual({ lastThrow: 'R', lastResult: 'SAFE', lastWorld: 'R', repeatRun: 2 });
        const m3 = advance(m2, 'P', 'S');
        expect(m3).toEqual({ lastThrow: 'P', lastResult: 'LOSS', lastWorld: 'S', repeatRun: 1 });
    });
    it('does not mutate its input', () => {
        const m = freshMemory();
        advance(m, 'R', 'S');
        expect(m).toEqual({ repeatRun: 0 });
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/CrowdPolicies.test.ts`
Expected: FAIL — `Cannot find module './CrowdPolicies'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/engine/CrowdPolicies.ts
// The synthetic crowd's archetypes (spec §2). A policy is a DISTRIBUTION over R/P/S given a
// small memory; sampling is generic. Defining them by distribution rather than by a sampled
// throw is what makes each archetype testable exactly, and what lets the simulator's oracle sum
// them to predict the plurality.
//
// Basis: Wang, Xu & Zhou, "Social cycling and conditional responses in the Rock-Paper-Scissors
// game", Sci. Rep. 4:5830 (2014) — win-stay / lose-shift-CLOCKWISE (R->S->P->R) and the
// population-level cycling it produces. `counter`/`conform` are the two readings of the HUD's
// last-five tape; `rocky` is the folk novice. All of this is a HYPOTHESIS about a Roblox crowd,
// to be recalibrated from real Round.distribution rows once there are any (spec §8).
import { Throw, RoundResult, calculateResult } from './GameRules';
import { Rng } from './Prng';

export type PolicyId = 'random' | 'wsls' | 'counter' | 'conform' | 'rocky' | 'second';
export const POLICY_IDS: PolicyId[] = ['random', 'wsls', 'counter', 'conform', 'rocky', 'second'];

export type Dist = Record<Throw, number>;

export interface Memory {
    lastThrow?: Throw;
    lastResult?: RoundResult;
    lastWorld?: Throw;
    repeatRun: number; // consecutive rounds the bot has thrown lastThrow
}

export const freshMemory = (): Memory => ({ repeatRun: 0 });

const THROWS: Throw[] = ['R', 'P', 'S'];
export const WHAT_BEATS: Record<Throw, Throw> = { R: 'P', P: 'S', S: 'R' };
export const CLOCKWISE: Record<Throw, Throw> = { R: 'S', S: 'P', P: 'R' };
export const UNIFORM: Dist = { R: 1 / 3, P: 1 / 3, S: 1 / 3 };

export function pointMass(t: Throw): Dist {
    return { R: t === 'R' ? 1 : 0, P: t === 'P' ? 1 : 0, S: t === 'S' ? 1 : 0 };
}

// strength * focused + (1 - strength) * uniform. `strength` is the readability dial WITHIN an
// archetype; the mix (SyntheticCrowd) is the dial ACROSS them.
export function blend(focused: Dist, strength: number): Dist {
    const s = Math.min(1, Math.max(0, strength));
    return {
        R: s * focused.R + (1 - s) / 3,
        P: s * focused.P + (1 - s) / 3,
        S: s * focused.S + (1 - s) / 3,
    };
}

function normalised(d: Dist): Dist {
    const total = d.R + d.P + d.S;
    return total === 0 ? UNIFORM : { R: d.R / total, P: d.P / total, S: d.S / total };
}

export function policyDistribution(id: PolicyId, m: Memory, strength: number): Dist {
    switch (id) {
        case 'random':
            return UNIFORM;
        case 'wsls': {
            if (!m.lastThrow || !m.lastResult) return UNIFORM;
            if (m.lastResult === 'WIN') return blend(pointMass(m.lastThrow), strength);
            const shifted = pointMass(CLOCKWISE[m.lastThrow]);
            return blend(shifted, m.lastResult === 'LOSS' ? strength : strength / 2);
        }
        case 'counter':
            return m.lastWorld ? blend(pointMass(WHAT_BEATS[m.lastWorld]), strength) : UNIFORM;
        case 'conform':
            return m.lastWorld ? blend(pointMass(m.lastWorld), strength) : UNIFORM;
        case 'second':
            return m.lastWorld ? blend(pointMass(WHAT_BEATS[WHAT_BEATS[m.lastWorld]]), strength) : UNIFORM;
        case 'rocky': {
            if (!m.lastThrow) return blend({ R: 0.5, P: 0.25, S: 0.25 }, strength);
            const lean: Dist = { R: 0.4, P: 0.3, S: 0.3 };
            if (m.repeatRun >= 2) lean[m.lastThrow] = 0; // never a third repeat
            return blend(normalised(lean), strength);
        }
    }
}

export function sample(d: Dist, rng: Rng): Throw {
    const x = rng();
    let acc = 0;
    for (const t of THROWS) {
        acc += d[t];
        if (x < acc) return t;
    }
    return 'S'; // rounding guard: x landed within epsilon of 1
}

// Pure: the memory after a round in which the bot threw `thrown` against `world`.
export function advance(m: Memory, thrown: Throw, world: Throw): Memory {
    return {
        lastThrow: thrown,
        lastResult: calculateResult(thrown, world),
        lastWorld: world,
        repeatRun: thrown === m.lastThrow ? m.repeatRun + 1 : 1,
    };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/engine/CrowdPolicies.test.ts`
Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add src/engine/CrowdPolicies.ts src/engine/CrowdPolicies.test.ts
git commit -m "feat(crowd): six archetype policies as distributions over R/P/S -- wsls, counter, conform, rocky, second, random

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

