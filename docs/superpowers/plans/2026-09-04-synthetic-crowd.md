# Synthetic Crowd Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A structured, seeded bot crowd the server can merge into each round's tally behind env config, plus an offline simulator that runs the same crowd through thousands of rounds with no database, so the World Throw rule can be played and measured for the first time.

**Architecture:** A pure `SyntheticCrowd` (bots = archetype policy + small memory, seeded PRNG) is handed to `RoundEngine` through one optional `crowd` config field; the engine merges bot counts into the tally *before* `pickWorldThrow` and emits them on `roundClosed`, so the reveal's distribution and the World Throw always agree. Bots never enter the per-participant `throws` map, so settlement, presence and every board stay human-only by construction. `Round` gains a `synthetic` count; `totalPlayers` becomes the size of the world. The simulator (`server/src/sim/`) reuses the same policies for both bots and modelled humans and reports win rates, world-throw transitions, pot outcomes and the blind-field spread.

**Tech Stack:** TypeScript (CommonJS, `strict`), Vitest 4, Mongoose (one schema field), no new runtime dependencies. The sim runs via `tsc && node dist/sim/cli.js` because `server/` has no TS runner in `node_modules` (`ts-node` is not installed locally).

**Spec:** `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md` — read it first; every task cites its section.

## Global Constraints

- **TDD, every task**: failing test → run it → minimal code → run it → commit. Server suite: `cd server && npm test` (Vitest, `src/**/*.test.ts`; DB tests use `mongodb-memory-server`, first boot can be slow).
- **No new packages.** The PRNG is in-repo (spec §2). The sim is plain TS compiled by the existing `tsc`.
- **Bots never reach settlement, presence, sessions, `PlayerRound`, `BankEvent`, or any board** (spec §1, §4). The mechanism is data shape (`throws` map is human-only), not a filter — do not add a filter.
- **`totalPlayers` = humans + synthetic; `Round.synthetic` records the bot count** (spec §3, owner decision 1).
- **`CROWD_SIZE > 0` with `TEST_MODE=true` disables the crowd with a warning** (spec §5).
- **Env vars are exactly `CROWD_SIZE`, `CROWD_MIX`, `CROWD_SEED`** (spec §5). Archetype strength is the constant `DEFAULT_STRENGTH = 0.7`; the sim varies it by flag, the server does not.
- **Archetype ids are exactly** `random | wsls | counter | conform | rocky | second` (spec §2 + §6). `second` is a sim-side human policy but lives in the same module so the mix parser and the sim share one vocabulary.
- **No client change** in this plan (spec §3, §10). The Roblox and PWA clients ignore the new `synthetic` field.
- **No shared-fixture change** (spec §9).
- **Do NOT flip the dev App Runner service yourself.** Task 12 documents the procedure; the flip is owner-run or owner-approved, announced first, because it bounces the backend under any live Studio session (spec §5, [[deploy]]).
- Commit messages follow the repo's `type(scope): summary` style and end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Working directory for every command below is `server/` unless a path says otherwise. The repo has unrelated dirty files (`art/`, `.superpowers/sdd/.gitignore`); **stage only the files each task names.**

---

## File map

| file | responsibility |
|---|---|
| `server/src/engine/Prng.ts` (new) | `mulberry32(seed)` seeded PRNG, `randomSeed()` |
| `server/src/engine/CrowdPolicies.ts` (new) | archetype vocabulary: `PolicyId`, `Memory`, `policyDistribution`, `sample`, `advance` — pure |
| `server/src/engine/SyntheticCrowd.ts` (new) | `parseMix`, `allocate`, `createCrowd` — a bag of bots with memory |
| `server/src/crowdConfig.ts` (new) | `readCrowdConfig(env, …)`: the three env vars + TEST_MODE guard |
| `server/src/engine/RoundEngine.ts` | `EngineConfig.crowd`, merge at LOCK→REVEAL, `crowdCounts` on `roundClosed` |
| `server/src/engine/Settlement.ts` | `GlobalResult.synthetic`, `RoundToSettle.crowdCounts`, `totalPlayers` = sum(counts) |
| `server/src/models/Round.ts` | `synthetic` field, default 0 |
| `server/src/index.ts` | wire config → crowd → engine; per-round `[CROWD]` log; tape seed carries `synthetic` |
| `server/src/sim/Simulation.ts` (new) | `runSimulation`, `applyBank` — humans as policies with pots |
| `server/src/sim/reporters.ts` (new) | `winRates`, `worldTransitions`, `bankedTotals`, `spreadRatio` |
| `server/src/sim/cli.ts` (new) | `npm run sim` — the three experiments, table or `--json` |
| `docs/wiki/world/world-throw.md`, `docs/wiki/systems/deploy.md`, `CLAUDE.md`, `docs/wiki/log.md` | as-built, env vars, flip procedure, ship entry |

---

### Task 1: Seeded PRNG

**Files:**
- Create: `server/src/engine/Prng.ts`
- Test: `server/src/engine/Prng.test.ts`

**Interfaces:**
- Produces: `type Rng = () => number`; `mulberry32(seed: number): Rng` (uniform in [0,1)); `randomSeed(): number` (a 32-bit unsigned integer).

- [ ] **Step 1: Write the failing test**

```ts
// server/src/engine/Prng.test.ts
import { describe, it, expect } from 'vitest';
import { mulberry32, randomSeed } from './Prng';

describe('mulberry32', () => {
    it('is a known-answer sequence for a fixed seed', () => {
        const r = mulberry32(1);
        expect([r(), r(), r()].map(x => x.toFixed(6))).toEqual(['0.627074', '0.002736', '0.527447']);
        const s = mulberry32(42);
        expect([s(), s(), s()].map(x => x.toFixed(6))).toEqual(['0.601104', '0.448291', '0.852466']);
    });

    it('stays in [0, 1) over many draws', () => {
        const r = mulberry32(7);
        for (let i = 0; i < 10_000; i++) {
            const x = r();
            expect(x).toBeGreaterThanOrEqual(0);
            expect(x).toBeLessThan(1);
        }
    });

    it('two generators with the same seed agree; different seeds diverge', () => {
        const a = mulberry32(99), b = mulberry32(99), c = mulberry32(100);
        expect(a()).toBe(b());
        expect(a()).not.toBe(c());
    });
});

describe('randomSeed', () => {
    it('returns a 32-bit unsigned integer', () => {
        const s = randomSeed();
        expect(Number.isInteger(s)).toBe(true);
        expect(s).toBeGreaterThanOrEqual(0);
        expect(s).toBeLessThan(2 ** 32);
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/Prng.test.ts`
Expected: FAIL — `Cannot find module './Prng'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/engine/Prng.ts
// Seeded PRNG for the synthetic crowd (spec §2: "mulberry32 or equivalent, ~10 lines — no
// package"). Same seed + same call sequence → same numbers, which is what makes a crowd run
// reproducible and the zero-human demo deterministic. Not cryptographic; not meant to be.
export type Rng = () => number;

export function mulberry32(seed: number): Rng {
    let a = seed >>> 0;
    return () => {
        a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// For CROWD_SEED unset: a seed that is logged so the run can still be reproduced.
export function randomSeed(): number {
    return (Math.random() * 0x100000000) >>> 0;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/engine/Prng.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add src/engine/Prng.ts src/engine/Prng.test.ts
git commit -m "feat(crowd): seeded mulberry32 PRNG -- the reproducibility the synthetic crowd needs

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

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

### Task 4: Env config — the three variables and the TEST_MODE guard

**Files:**
- Create: `server/src/crowdConfig.ts`
- Test: `server/src/crowdConfig.test.ts`

**Interfaces:**
- Consumes: Task 3's `parseMix`, `DEFAULT_MIX`, `formatMix`, `Mix`.
- Produces: `interface CrowdConfig { size: number; mix: Mix; seed: number }`; `readCrowdConfig(env: Record<string, string | undefined>, opts: { testMode: boolean; log: (msg: string) => void; randomSeed: () => number }): CrowdConfig | null`. `null` means "no crowd". Malformed values **throw** (boot refuses — same posture as a missing `MONGODB_URI`).

- [ ] **Step 1: Write the failing test**

```ts
// server/src/crowdConfig.test.ts
import { describe, it, expect, vi } from 'vitest';
import { readCrowdConfig } from './crowdConfig';
import { DEFAULT_MIX } from './engine/SyntheticCrowd';

const opts = (testMode = false) => ({ testMode, log: vi.fn(), randomSeed: () => 4242 });

describe('readCrowdConfig', () => {
    it('is off when CROWD_SIZE is unset or 0, silently', () => {
        const o = opts();
        expect(readCrowdConfig({}, o)).toBeNull();
        expect(readCrowdConfig({ CROWD_SIZE: '0' }, o)).toBeNull();
        expect(o.log).not.toHaveBeenCalled();
    });

    it('reads size, default mix, and a random seed that it logs so the run is reproducible', () => {
        const o = opts();
        expect(readCrowdConfig({ CROWD_SIZE: '30' }, o)).toEqual({ size: 30, mix: DEFAULT_MIX, seed: 4242 });
        expect(o.log).toHaveBeenCalledWith('[CROWD] CROWD_SEED unset; using 4242 (set CROWD_SEED=4242 to reproduce this run)');
    });

    it('honours CROWD_MIX and CROWD_SEED', () => {
        const o = opts();
        expect(readCrowdConfig({ CROWD_SIZE: '5', CROWD_MIX: 'counter:1', CROWD_SEED: '7' }, o))
            .toEqual({ size: 5, mix: { counter: 1 }, seed: 7 });
        expect(o.log).not.toHaveBeenCalled();
    });

    it('TEST_MODE disables the crowd with a warning instead of lying on the reveal card', () => {
        const o = opts(true);
        expect(readCrowdConfig({ CROWD_SIZE: '30' }, o)).toBeNull();
        expect(o.log).toHaveBeenCalledWith(
            '[CROWD] CROWD_SIZE=30 ignored: TEST_MODE cycles the World Throw, and a crowd whose plurality disagrees with it would lie on the reveal card');
    });

    it('refuses malformed values at boot', () => {
        expect(() => readCrowdConfig({ CROWD_SIZE: '-3' }, opts())).toThrow('CROWD_SIZE="-3" must be a non-negative integer');
        expect(() => readCrowdConfig({ CROWD_SIZE: '2.5' }, opts())).toThrow('CROWD_SIZE="2.5" must be a non-negative integer');
        expect(() => readCrowdConfig({ CROWD_SIZE: '5', CROWD_MIX: 'ninja:1' }, opts())).toThrow('CROWD_MIX: unknown archetype "ninja"');
        expect(() => readCrowdConfig({ CROWD_SIZE: '5', CROWD_SEED: 'abc' }, opts())).toThrow('CROWD_SEED="abc" must be a non-negative integer');
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/crowdConfig.test.ts`
Expected: FAIL — `Cannot find module './crowdConfig'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/crowdConfig.ts
// The synthetic crowd's env surface (spec §5): CROWD_SIZE, CROWD_MIX, CROWD_SEED. House pattern
// is config over commits (round durations, WORLD_THROW_MIN_PARTICIPANTS), so the crowd is a
// service setting, not a deploy. Extracted from index.ts like testModeCycle.ts so it is testable.
import { Mix, parseMix, DEFAULT_MIX } from './engine/SyntheticCrowd';

export interface CrowdConfig {
    size: number;
    mix: Mix;
    seed: number;
}

function nonNegativeInt(name: string, raw: string): number {
    const n = Number(raw);
    if (!Number.isInteger(n) || n < 0) throw new Error(`${name}="${raw}" must be a non-negative integer`);
    return n;
}

export function readCrowdConfig(
    env: Record<string, string | undefined>,
    opts: { testMode: boolean; log: (msg: string) => void; randomSeed: () => number },
): CrowdConfig | null {
    const rawSize = env.CROWD_SIZE;
    if (rawSize === undefined || rawSize === '') return null;
    const size = nonNegativeInt('CROWD_SIZE', rawSize);
    if (size === 0) return null;

    // A cycled World Throw beside a plurality distribution that disagrees with it is exactly
    // the lie the engine-side merge exists to prevent (spec §1, §5).
    if (opts.testMode) {
        opts.log(`[CROWD] CROWD_SIZE=${size} ignored: TEST_MODE cycles the World Throw, and a crowd whose plurality disagrees with it would lie on the reveal card`);
        return null;
    }

    const mix = env.CROWD_MIX !== undefined && env.CROWD_MIX !== '' ? parseMix(env.CROWD_MIX) : DEFAULT_MIX;

    let seed: number;
    if (env.CROWD_SEED !== undefined && env.CROWD_SEED !== '') {
        seed = nonNegativeInt('CROWD_SEED', env.CROWD_SEED);
    } else {
        seed = opts.randomSeed();
        opts.log(`[CROWD] CROWD_SEED unset; using ${seed} (set CROWD_SEED=${seed} to reproduce this run)`);
    }
    return { size, mix, seed };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/crowdConfig.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add src/crowdConfig.ts src/crowdConfig.test.ts
git commit -m "feat(crowd): CROWD_SIZE / CROWD_MIX / CROWD_SEED, refused when malformed, disabled under TEST_MODE

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: The engine merge

**Files:**
- Modify: `server/src/engine/RoundEngine.ts` (`EngineConfig` ~line 22-37, `RoundClosedEvent` ~line 47-52, the LOCK→REVEAL branch ~line 125-139)
- Test: `server/src/engine/RoundEngine.test.ts` (append a `describe`)

**Interfaces:**
- Consumes: nothing from the crowd module directly — the engine takes a structural `CrowdSource` so it stays free of the crowd's internals.
- Produces:
  - `export interface CrowdSource { throws(roundCount: number): Record<Throw, number>; observe(worldThrow: Throw): void }` (Task 3's `Crowd` satisfies it).
  - `EngineConfig.crowd?: CrowdSource`.
  - `RoundClosedEvent.crowdCounts: Record<Throw, number>` (zeros when no crowd). `counts` now = human + crowd.

- [ ] **Step 1: Write the failing test**

Append to `server/src/engine/RoundEngine.test.ts`:

```ts
describe('the synthetic crowd merges into the tally at round close (spec §1)', () => {
    const human = (t: 'R' | 'P' | 'S') => ({ throw: t, seq: 1, platform: 'pwa' as const, deviceId: `d-${t}` });

    function fakeCrowd(counts: { R: number; P: number; S: number }) {
        const throws = vi.fn(() => counts);
        const observe = vi.fn();
        return { throws, observe };
    }

    it('pickWorldThrow sees human + crowd counts, and roundClosed carries both', () => {
        const crowd = fakeCrowd({ R: 10, P: 3, S: 0 });
        const picker = vi.fn(() => 'R' as const);
        const e = makeEngine({ pickWorldThrow: picker, crowd });
        const closed: any[] = [];
        e.on('roundClosed', ev => closed.push(ev));

        e.submitThrow('pwa:a', human('P'));
        e.submitThrow('pwa:b', human('S'));
        for (let i = 0; i < 5; i++) e.tick();

        expect(crowd.throws).toHaveBeenCalledWith(0);
        expect(picker).toHaveBeenCalledWith(0, { R: 10, P: 4, S: 1 });
        expect(closed).toHaveLength(1);
        expect(closed[0].counts).toEqual({ R: 10, P: 4, S: 1 });
        expect(closed[0].crowdCounts).toEqual({ R: 10, P: 3, S: 0 });
    });

    it('the throws map stays human-only — bots never reach settlement', () => {
        const e = makeEngine({ crowd: fakeCrowd({ R: 10, P: 3, S: 0 }) });
        const closed: any[] = [];
        e.on('roundClosed', ev => closed.push(ev));
        e.submitThrow('pwa:a', human('P'));
        for (let i = 0; i < 5; i++) e.tick();
        expect(closed[0].throws.size).toBe(1);
        expect([...closed[0].throws.keys()]).toEqual(['pwa:a']);
    });

    it('observe() receives the DECIDED World Throw, after the picker ran', () => {
        const crowd = fakeCrowd({ R: 0, P: 5, S: 0 });
        const e = makeEngine({ pickWorldThrow: () => 'S', crowd });
        for (let i = 0; i < 5; i++) e.tick();
        expect(crowd.observe).toHaveBeenCalledExactlyOnceWith('S');
        expect(crowd.throws.mock.invocationCallOrder[0]).toBeLessThan(crowd.observe.mock.invocationCallOrder[0]);
    });

    it('without a crowd, crowdCounts is zeros and counts are the humans alone', () => {
        const e = makeEngine();
        const closed: any[] = [];
        e.on('roundClosed', ev => closed.push(ev));
        e.submitThrow('pwa:a', human('R'));
        for (let i = 0; i < 5; i++) e.tick();
        expect(closed[0].counts).toEqual({ R: 1, P: 0, S: 0 });
        expect(closed[0].crowdCounts).toEqual({ R: 0, P: 0, S: 0 });
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/RoundEngine.test.ts`
Expected: the four new tests FAIL (picker sees `{R:0,P:1,S:1}`; `crowdCounts` undefined). The existing tests still pass.

- [ ] **Step 3: Write minimal implementation**

In `server/src/engine/RoundEngine.ts`, add after the `ThrowEntry` interface:

```ts
// The synthetic crowd (spec §1). Structural on purpose: the engine needs "give me this round's
// bot tally" and "here is what the world did", nothing about archetypes or seeds.
export interface CrowdSource {
    throws(roundCount: number): Record<Throw, number>;
    observe(worldThrow: Throw): void;
}
```

Add to `EngineConfig`, after `pickWorldThrow`:

```ts
    // Optional bot crowd merged into the tally BEFORE pickWorldThrow, so the distribution the
    // player sees and the World Throw it produced always agree. Absent → today's behaviour.
    crowd?: CrowdSource;
```

Change `RoundClosedEvent`:

```ts
export interface RoundClosedEvent {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;       // human + crowd: the world the player faced
    crowdCounts: Record<Throw, number>;  // the synthetic part of it, zeros when no crowd
    throws: Map<string, ThrowEntry>;     // humans only — the only thing settlement iterates
}
```

Replace the LOCK→REVEAL branch body (currently `const counts = this.countThrows(); const worldThrow = ...` through the `roundClosed` emit) with:

```ts
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
```

- [ ] **Step 4: Run the whole suite**

Run: `npm test`
Expected: PASS. (`RoundToSettle` does not yet know `crowdCounts`, but `settleRound({ ...data, timestamp })` in `socketAdapter` passes an object with an extra property through a spread, which TypeScript allows. Task 6 adds the field.)

- [ ] **Step 5: Commit**

```bash
git add src/engine/RoundEngine.ts src/engine/RoundEngine.test.ts
git commit -m "feat(engine): merge the synthetic crowd into the tally at LOCK->REVEAL, before the World Throw is picked

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Settlement, the Round document, and everything that carries a round

**Files:**
- Modify: `server/src/engine/Settlement.ts` (`GlobalResult` ~line 10-16, `RoundToSettle` ~line 32-38, top of `settleRound` ~line 75-83)
- Modify: `server/src/models/Round.ts`
- Modify: `server/src/engine/ResultsStore.test.ts:6` (helper literal)
- Modify: `server/src/index.ts` (~line 110-113, the tape seed)
- Test: `server/src/engine/Settlement.test.ts` (append to the `settleRound` describe)

**Interfaces:**
- Consumes: Task 5's `RoundClosedEvent.crowdCounts`.
- Produces: `GlobalResult.synthetic: number` (required — every producer must say); `RoundToSettle.crowdCounts?: Record<Throw, number>`; `IRound.synthetic: number` with schema `default: 0`.

- [ ] **Step 1: Write the failing test**

Append inside `describe('settleRound', …)` in `server/src/engine/Settlement.test.ts`:

```ts
    describe('the synthetic crowd is part of the world, never a participant (spec §3, §4)', () => {
        it('totalPlayers counts humans + bots, synthetic records the bots, and only humans settle', async () => {
            await User.create({ deviceId: 'devA' });
            const { round, players } = await settleRound({
                roundId: 'r-crowd',
                worldThrow: 'R',
                counts: { R: 21, P: 6, S: 4 },          // 1 human (P) + 30 bots
                crowdCounts: { R: 21, P: 5, S: 4 },
                throws: throwsMap([
                    ['pwa:devA', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'devA' }],
                ]),
                timestamp: new Date(),
            });
            expect(round).toMatchObject({ totalPlayers: 31, synthetic: 30, distribution: { R: 68, P: 19, S: 13 } });
            expect(players).toHaveLength(1);
            expect(players[0]).toMatchObject({ key: 'pwa:devA', result: 'WIN' });
            expect(await PlayerRound.countDocuments({ roundId: 'r-crowd' })).toBe(1);
            expect(await User.countDocuments()).toBe(1);
            const saved = await Round.findOne({ id: 'r-crowd' }).lean();
            expect(saved).toMatchObject({ totalPlayers: 31, synthetic: 30 });
        });

        it('without crowdCounts, synthetic is 0 and totalPlayers is the humans, as before', async () => {
            const { round } = await settleRound({
                roundId: 'r-plain',
                worldThrow: 'R',
                counts: { R: 0, P: 2, S: 0 },
                throws: throwsMap([
                    ['pwa:x', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'x' }],
                    ['pwa:y', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'y' }],
                ]),
                timestamp: new Date(),
            });
            expect(round).toMatchObject({ totalPlayers: 2, synthetic: 0 });
        });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/Settlement.test.ts`
Expected: the two new tests FAIL (`totalPlayers: 1`, `synthetic` undefined). TypeScript may also complain about `crowdCounts` — that is the same failure.

- [ ] **Step 3: Write minimal implementation**

`server/src/engine/Settlement.ts` — `GlobalResult`:

```ts
export interface GlobalResult {
    id: string;
    worldThrow: Throw;
    distribution: { R: number; P: number; S: number };
    totalPlayers: number; // the size of the WORLD the player faced: humans + synthetic (spec §3)
    synthetic: number;    // how many of those were bots; humans = totalPlayers - synthetic
    timestamp: Date;
}
```

`RoundToSettle`:

```ts
export interface RoundToSettle {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;        // human + crowd
    crowdCounts?: Record<Throw, number>;  // the crowd's share; absent/zeros when there is none
    throws: Map<string, ThrowEntry>;      // humans only
    timestamp: Date;
}
```

Top of `settleRound`:

```ts
export async function settleRound(data: RoundToSettle): Promise<{ round: GlobalResult; players: SettledPlayer[] }> {
    // sum(counts), not throws.size: the two were equal until the crowd existed. The
    // distribution and the player count must describe the same world (spec §3).
    const totalPlayers = data.counts.R + data.counts.P + data.counts.S;
    const crowd = data.crowdCounts ?? { R: 0, P: 0, S: 0 };
    const synthetic = crowd.R + crowd.P + crowd.S;
    const round: GlobalResult = {
        id: data.roundId,
        worldThrow: data.worldThrow,
        distribution: buildDistribution(data.counts, totalPlayers),
        totalPlayers,
        synthetic,
        timestamp: data.timestamp,
    };
```

`server/src/models/Round.ts` — interface and schema:

```ts
    totalPlayers: number; // humans + synthetic
    synthetic: number;    // bot count; default 0 keeps every historical row honest
```

```ts
    totalPlayers: { type: Number, default: 0 },
    synthetic: { type: Number, default: 0 },
```

`server/src/engine/ResultsStore.test.ts:6` helper — add the field:

```ts
    return { id, worldThrow: 'R', distribution: { R: 100, P: 0, S: 0 }, totalPlayers: 1, synthetic: 0, timestamp: new Date() };
```

`server/src/index.ts` tape seed (~line 110):

```ts
        store.seed(lastRounds.map(r => ({
            id: r.id, worldThrow: r.worldThrow as Throw, distribution: r.distribution,
            totalPlayers: r.totalPlayers, synthetic: r.synthetic ?? 0, timestamp: r.timestamp,
        })));
```

- [ ] **Step 4: Run the whole suite and the type-check**

Run: `npm test && npx tsc --noEmit`
Expected: PASS, no type errors. If `tsc` reports another `GlobalResult` literal missing `synthetic`, add `synthetic: 0` there — the field is required precisely so producers cannot forget it.

- [ ] **Step 5: Commit**

```bash
git add src/engine/Settlement.ts src/engine/Settlement.test.ts src/models/Round.ts src/engine/ResultsStore.test.ts src/index.ts
git commit -m "feat(settlement): totalPlayers is the size of the world; Round.synthetic records the bots in it

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Composition root — wire config → crowd → engine, and the per-round log

**Files:**
- Modify: `server/src/index.ts` (imports; `makeEngine` ~line 66-95; the `.then` block ~line 119-124)

**Interfaces:**
- Consumes: Task 4 `readCrowdConfig`; Task 3 `createCrowd`, `formatMix`; Task 1 `mulberry32`, `randomSeed`; Task 5 `CrowdSource`, `RoundClosedEvent`.
- Produces: nothing new; behaviour only.

There is no test harness for `index.ts` (it connects to Mongo on import); the pieces it composes are all tested in Tasks 1–6. Verification here is the boot log.

- [ ] **Step 1: Add the imports**

```ts
import { RoundEngine, CrowdSource, RoundClosedEvent } from './engine/RoundEngine';
import { readCrowdConfig } from './crowdConfig';
import { createCrowd, formatMix } from './engine/SyntheticCrowd';
import { mulberry32, randomSeed } from './engine/Prng';
```

(Replace the existing `import { RoundEngine } from './engine/RoundEngine';` line.)

- [ ] **Step 2: Build the crowd from env, right after `const TEST_MODE = …`**

```ts
// The synthetic crowd (spec §5). Refuses to boot on a malformed value, like MONGODB_URI does:
// a crowd that silently fell back to defaults would run an experiment nobody configured.
const crowdConfig = readCrowdConfig(process.env, {
    testMode: TEST_MODE,
    log: msg => console.warn(msg),
    randomSeed,
});
const crowd: CrowdSource | undefined = crowdConfig
    ? createCrowd({ size: crowdConfig.size, mix: crowdConfig.mix, rng: mulberry32(crowdConfig.seed) })
    : undefined;
console.log(crowdConfig
    ? `[CROWD] on: size ${crowdConfig.size}, seed ${crowdConfig.seed}, mix ${formatMix(crowdConfig.mix)}`
    : '[CROWD] off');
```

- [ ] **Step 3: Pass it into the engine**

In `makeEngine`, add `crowd,` to the `new RoundEngine({ … })` config object, after `pickWorldThrow`. The function closes over the module-level `crowd`; its signature is unchanged.

- [ ] **Step 4: Log each round the crowd took part in**

Immediately after `const engine = makeEngine(totalRounds, cycleShift);`:

```ts
        if (crowd) {
            // One line per round so a Studio session can read what the world did (spec §5).
            engine.on('roundClosed', (e: RoundClosedEvent) => {
                const bots = e.crowdCounts.R + e.crowdCounts.P + e.crowdCounts.S;
                console.log(`[CROWD] round ${e.roundId} humans ${e.throws.size} crowd ${bots} | R ${e.counts.R} P ${e.counts.P} S ${e.counts.S} → ${e.worldThrow}`);
            });
        }
```

- [ ] **Step 5: Type-check and run the suite**

Run: `npx tsc --noEmit && npm test`
Expected: clean, PASS.

- [ ] **Step 6: Boot-log check without a database**

The server exits before listening when `MONGODB_URI` is empty, but the crowd lines print first (the config is read before the fatal check, and `dotenv` does not override a variable that is already set, even to the empty string). Run:

```bash
npx tsc && (MONGODB_URI= TEST_MODE=false CROWD_SIZE=30 CROWD_SEED=1 node dist/index.js; true)
```

Expected output includes `[CROWD] on: size 30, seed 1, mix wsls:35,counter:20,conform:15,rocky:10,random:20` then `[FATAL] MONGODB_URI is not defined`. Then:

```bash
(MONGODB_URI= TEST_MODE=true CROWD_SIZE=30 node dist/index.js; true)
```

Expected: the `TEST_MODE cycles the World Throw` warning and `[CROWD] off`. And:

```bash
(MONGODB_URI= TEST_MODE=false CROWD_SIZE=5 CROWD_MIX=ninja:1 node dist/index.js; true)
```

Expected: the process throws `CROWD_MIX: unknown archetype "ninja" …` and exits non-zero.

- [ ] **Step 7: Commit**

```bash
git add src/index.ts
git commit -m "feat(server): wire the synthetic crowd from env into the engine; one [CROWD] line per round

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

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

### Task 9: Reporters

**Files:**
- Create: `server/src/sim/reporters.ts`
- Test: `server/src/sim/reporters.test.ts`

**Interfaces:**
- Consumes: Task 8's `RoundRecord`, `HumanSpec`; Task 2's `WHAT_BEATS`.
- Produces:
  - `interface WinRateRow { id: string; throws: number; wins: number; safes: number; losses: number; rate: number; ci95: number }`
  - `winRates(log: RoundRecord[], humans: HumanSpec[]): WinRateRow[]`
  - `interface Transitions { same: number; counter: number; other: number; n: number }` (fractions of consecutive world-throw pairs)
  - `worldTransitions(log: RoundRecord[]): Transitions`
  - `bankedTotals(log: RoundRecord[]): number[]` (per human, summed)
  - `maxPots(log: RoundRecord[]): number[]` (per human, the largest `potAfter` seen — note this is after banking, so a `rung` banker's max is one rung below the bank point; document in the table header)
  - `spreadRatio(totals: number[]): number | null` (max ÷ median; `null` when the median is 0)

- [ ] **Step 1: Write the failing test**

```ts
// server/src/sim/reporters.test.ts
import { describe, it, expect } from 'vitest';
import { winRates, worldTransitions, bankedTotals, maxPots, spreadRatio } from './reporters';
import { RoundRecord, HumanSpec } from './Simulation';

const humans: HumanSpec[] = [
    { id: 'a', policy: 'counter', strength: 1, bank: { kind: 'ride' } },
    { id: 'b', policy: 'random', strength: 1, bank: { kind: 'rung', at: 9 } },
];

// Five rounds, two humans. World: R P P S R.
const log: RoundRecord[] = [
    { world: 'R', counts: { R: 5, P: 1, S: 0 }, humans: [
        { throw: 'P', result: 'WIN', potAfter: 1, banked: 0 }, { throw: 'R', result: 'SAFE', potAfter: 0, banked: 0 }] },
    { world: 'P', counts: { R: 1, P: 5, S: 0 }, humans: [
        { throw: 'P', result: 'SAFE', potAfter: 1, banked: 0 }, { throw: 'S', result: 'WIN', potAfter: 1, banked: 0 }] },
    { world: 'P', counts: { R: 0, P: 4, S: 2 }, humans: [
        { throw: 'S', result: 'WIN', potAfter: 3, banked: 0 }, { throw: 'S', result: 'WIN', potAfter: 3, banked: 0 }] },
    { world: 'S', counts: { R: 2, P: 0, S: 4 }, humans: [
        { throw: 'S', result: 'SAFE', potAfter: 3, banked: 0 }, { throw: 'R', result: 'WIN', potAfter: 0, banked: 9 }] },
    { world: 'R', counts: { R: 4, P: 1, S: 1 }, humans: [
        { throw: 'R', result: 'SAFE', potAfter: 3, banked: 0 }, { throw: 'S', result: 'LOSS', potAfter: 0, banked: 0 }] },
];

describe('winRates', () => {
    it('counts each result and reports rate with a 95% interval', () => {
        const rows = winRates(log, humans);
        expect(rows[0]).toMatchObject({ id: 'a', throws: 5, wins: 2, safes: 3, losses: 0, rate: 0.4 });
        expect(rows[0].ci95).toBeCloseTo(1.96 * Math.sqrt(0.4 * 0.6 / 5), 6);
        expect(rows[1]).toMatchObject({ id: 'b', throws: 5, wins: 3, safes: 1, losses: 1, rate: 0.6 });
    });
});

describe('worldTransitions', () => {
    it('classifies each consecutive pair as same / counter (what beats the last) / other', () => {
        // pairs: R->P counter, P->P same, P->S counter, S->R counter
        expect(worldTransitions(log)).toEqual({ same: 0.25, counter: 0.75, other: 0, n: 4 });
    });
    it('is all zeros with fewer than two rounds', () => {
        expect(worldTransitions(log.slice(0, 1))).toEqual({ same: 0, counter: 0, other: 0, n: 0 });
    });
});

describe('bankedTotals / maxPots / spreadRatio', () => {
    it('sums banked points and tracks the largest pot per human', () => {
        expect(bankedTotals(log)).toEqual([0, 9]);
        expect(maxPots(log)).toEqual([3, 3]);
    });
    it('spreadRatio is max over median, null when the median is zero', () => {
        expect(spreadRatio([1, 2, 3, 4, 10])).toBe(10 / 3);
        expect(spreadRatio([1, 2, 3, 4])).toBe(4 / 2.5);
        expect(spreadRatio([0, 0, 0, 5])).toBeNull();
        expect(spreadRatio([])).toBeNull();
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/sim/reporters.test.ts`
Expected: FAIL — `Cannot find module './reporters'`.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/sim/reporters.ts
// Pure summaries over a simulation log (spec §6). Each answers one of the spec's §7 questions
// and nothing else; the CLI composes them.
import { WHAT_BEATS } from '../engine/CrowdPolicies';
import { RoundRecord, HumanSpec } from './Simulation';

export interface WinRateRow {
    id: string;
    throws: number;
    wins: number;
    safes: number;
    losses: number;
    rate: number; // wins ÷ throws — the stats room's BEAT WORLD; a blind player scores 1/3
    ci95: number; // normal-approximation half-width
}

export function winRates(log: RoundRecord[], humans: HumanSpec[]): WinRateRow[] {
    return humans.map((h, i) => {
        let wins = 0, safes = 0, losses = 0;
        for (const r of log) {
            const res = r.humans[i].result;
            if (res === 'WIN') wins++; else if (res === 'SAFE') safes++; else losses++;
        }
        const throws = log.length;
        const rate = throws === 0 ? 0 : wins / throws;
        const ci95 = throws === 0 ? 0 : 1.96 * Math.sqrt((rate * (1 - rate)) / throws);
        return { id: h.id, throws, wins, safes, losses, rate, ci95 };
    });
}

export interface Transitions {
    same: number;    // world repeated
    counter: number; // world became what beats the last world — the "everyone counters" rotation
    other: number;   // world became what the last world beats
    n: number;       // pairs counted
}

export function worldTransitions(log: RoundRecord[]): Transitions {
    let same = 0, counter = 0, other = 0;
    for (let i = 1; i < log.length; i++) {
        const prev = log[i - 1].world, cur = log[i].world;
        if (cur === prev) same++;
        else if (cur === WHAT_BEATS[prev]) counter++;
        else other++;
    }
    const n = Math.max(0, log.length - 1);
    if (n === 0) return { same: 0, counter: 0, other: 0, n: 0 };
    return { same: same / n, counter: counter / n, other: other / n, n };
}

export function bankedTotals(log: RoundRecord[]): number[] {
    if (log.length === 0) return [];
    const totals = log[0].humans.map(() => 0);
    for (const r of log) r.humans.forEach((h, i) => { totals[i] += h.banked; });
    return totals;
}

// Largest potAfter seen. potAfter is AFTER the round's bank decision, so a rung banker's max
// sits one rung below its bank point; the CLI labels the column accordingly.
export function maxPots(log: RoundRecord[]): number[] {
    if (log.length === 0) return [];
    const maxes = log[0].humans.map(() => 0);
    for (const r of log) r.humans.forEach((h, i) => { maxes[i] = Math.max(maxes[i], h.potAfter); });
    return maxes;
}

// The backlog's "twenty identical blind players... 2.5× the median by chance alone" concern,
// as a number. max ÷ median; null when the median is zero (nobody banked).
export function spreadRatio(totals: number[]): number | null {
    if (totals.length === 0) return null;
    const sorted = [...totals].sort((a, b) => a - b);
    const mid = sorted.length / 2;
    const median = sorted.length % 2 === 1 ? sorted[Math.floor(mid)] : (sorted[mid - 1] + sorted[mid]) / 2;
    if (median === 0) return null;
    return sorted[sorted.length - 1] / median;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/sim/reporters.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/sim/reporters.ts src/sim/reporters.test.ts
git commit -m "feat(sim): reporters -- win rates with CI, world-throw transitions, banked totals, blind-field spread

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: The CLI and `npm run sim`

**Files:**
- Create: `server/src/sim/cli.ts`
- Create: `server/src/sim/experiments.ts`
- Test: `server/src/sim/experiments.test.ts`
- Modify: `server/package.json` (scripts)

**Interfaces:**
- Consumes: Tasks 8–9; Task 3's `parseMix`, `DEFAULT_MIX`, `DEFAULT_STRENGTH`, `formatMix`.
- Produces:
  - `interface CliArgs { experiment: 'readability' | 'blind-spread' | 'effective-n'; rounds: number; crowd: number; mix: Mix; strength: number; seed: number; json: boolean }`
  - `parseArgs(argv: string[]): CliArgs`
  - `readability(a: CliArgs)`, `blindSpread(a: CliArgs)`, `effectiveN(a: CliArgs)` — each returns a plain JSON-able object; `cli.ts` prints it as a table or JSON.

The experiments module is tested; `cli.ts` is a thin printer.

- [ ] **Step 1: Write the failing test**

```ts
// server/src/sim/experiments.test.ts
import { describe, it, expect } from 'vitest';
import { parseArgs, readability, blindSpread, effectiveN } from './experiments';
import { DEFAULT_MIX } from '../engine/SyntheticCrowd';

describe('parseArgs', () => {
    it('has sensible defaults', () => {
        expect(parseArgs([])).toEqual({
            experiment: 'readability', rounds: 20000, crowd: 30, mix: DEFAULT_MIX, strength: 0.7, seed: 1, json: false,
        });
    });
    it('reads every flag', () => {
        expect(parseArgs(['--experiment', 'blind-spread', '--rounds', '360', '--crowd', '10', '--mix', 'counter:1',
            '--strength', '0.9', '--seed', '5', '--json'])).toEqual({
            experiment: 'blind-spread', rounds: 360, crowd: 10, mix: { counter: 1 }, strength: 0.9, seed: 5, json: true,
        });
    });
    it('refuses an unknown experiment or flag', () => {
        expect(() => parseArgs(['--experiment', 'vibes'])).toThrow('unknown experiment "vibes"');
        expect(() => parseArgs(['--bogus', '1'])).toThrow('unknown flag "--bogus"');
    });
});

describe('experiments (small, deterministic)', () => {
    it('readability reports one row per modelled human plus transitions', () => {
        const out = readability(parseArgs(['--rounds', '200', '--crowd', '10']));
        expect(out.humans.map(h => h.id)).toEqual(['random', 'counter', 'conform', 'wsls', 'second', 'oracle']);
        expect(out.transitions.n).toBe(199);
        for (const h of out.humans) {
            expect(h.rate).toBeGreaterThanOrEqual(0);
            expect(h.rate).toBeLessThanOrEqual(1);
        }
    });
    it('blindSpread runs twenty blind players over the requested rounds across twenty seeds', () => {
        const out = blindSpread(parseArgs(['--rounds', '100', '--crowd', '10']));
        expect(out.runs).toBe(20);
        expect(out.players).toBe(20);
        expect(out.ratios.length).toBeLessThanOrEqual(20);
    });
    it('effectiveN reports the counter\'s win rate at each crowd size', () => {
        const out = effectiveN(parseArgs(['--rounds', '100']));
        expect(out.rows.map(r => r.crowd)).toEqual([5, 7, 10, 15, 20, 30, 50, 100]);
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/sim/experiments.test.ts`
Expected: FAIL — `Cannot find module './experiments'`.

- [ ] **Step 3: Write the experiments module**

```ts
// server/src/sim/experiments.ts
// The three named experiments from spec §7, as functions returning plain data. cli.ts prints.
import { Mix, parseMix, DEFAULT_MIX, DEFAULT_STRENGTH } from '../engine/SyntheticCrowd';
import { runSimulation, HumanSpec } from './Simulation';
import { winRates, worldTransitions, bankedTotals, maxPots, spreadRatio, WinRateRow, Transitions } from './reporters';

export interface CliArgs {
    experiment: 'readability' | 'blind-spread' | 'effective-n';
    rounds: number;
    crowd: number;
    mix: Mix;
    strength: number;
    seed: number;
    json: boolean;
}

const EXPERIMENTS = ['readability', 'blind-spread', 'effective-n'] as const;

export function parseArgs(argv: string[]): CliArgs {
    const a: CliArgs = {
        experiment: 'readability', rounds: 20000, crowd: 30, mix: DEFAULT_MIX, strength: DEFAULT_STRENGTH, seed: 1, json: false,
    };
    for (let i = 0; i < argv.length; i++) {
        const flag = argv[i];
        const next = () => {
            const v = argv[++i];
            if (v === undefined) throw new Error(`flag ${flag} needs a value`);
            return v;
        };
        switch (flag) {
            case '--experiment': {
                const e = next();
                if (!(EXPERIMENTS as readonly string[]).includes(e)) throw new Error(`unknown experiment "${e}" (known: ${EXPERIMENTS.join(', ')})`);
                a.experiment = e as CliArgs['experiment'];
                break;
            }
            case '--rounds': a.rounds = Number(next()); break;
            case '--crowd': a.crowd = Number(next()); break;
            case '--mix': a.mix = parseMix(next()); break;
            case '--strength': a.strength = Number(next()); break;
            case '--seed': a.seed = Number(next()); break;
            case '--json': a.json = true; break;
            default: throw new Error(`unknown flag "${flag}"`);
        }
    }
    return a;
}

// Q0/Q1/Q3/Q5: one modelled human per teachable rule, each following it exactly (strength 1),
// each banking by the partial-banking spec's ratio rule; plus the oracle ceiling.
const READABILITY_HUMANS: HumanSpec[] = [
    { id: 'random', policy: 'random', strength: 1, bank: { kind: 'ratio' } },
    { id: 'counter', policy: 'counter', strength: 1, bank: { kind: 'ratio' } },
    { id: 'conform', policy: 'conform', strength: 1, bank: { kind: 'ratio' } },
    { id: 'wsls', policy: 'wsls', strength: 1, bank: { kind: 'ratio' } },
    { id: 'second', policy: 'second', strength: 1, bank: { kind: 'ratio' } },
    { id: 'oracle', policy: 'oracle', strength: 1, bank: { kind: 'ratio' } },
];

export interface ReadabilityOut {
    args: Omit<CliArgs, 'json'>;
    humans: (WinRateRow & { banked: number; maxPot: number })[];
    transitions: Transitions;
}

export function readability(a: CliArgs): ReadabilityOut {
    const log = runSimulation({
        rounds: a.rounds, crowdSize: a.crowd, mix: a.mix, crowdStrength: a.strength, humans: READABILITY_HUMANS, seed: a.seed,
    });
    const rates = winRates(log, READABILITY_HUMANS);
    const banked = bankedTotals(log);
    const pots = maxPots(log);
    const { json: _json, ...args } = a;
    return {
        args,
        humans: rates.map((r, i) => ({ ...r, banked: banked[i], maxPot: pots[i] })),
        transitions: worldTransitions(log),
    };
}

// Q4: twenty identical blind players, banking at 9, over `rounds` (360 = the stats room's
// qualification floor), repeated over twenty seeds. Reports max ÷ median per run.
export interface BlindSpreadOut {
    args: Omit<CliArgs, 'json'>;
    players: number;
    runs: number;
    ratios: number[];
    meanRatio: number | null;
    maxRatio: number | null;
}

export function blindSpread(a: CliArgs): BlindSpreadOut {
    const players = 20, runs = 20;
    const humans: HumanSpec[] = Array.from({ length: players }, (_, i) => ({
        id: `blind-${i}`, policy: 'random', strength: 1, bank: { kind: 'rung', at: 9 },
    }));
    const ratios: number[] = [];
    for (let k = 0; k < runs; k++) {
        const log = runSimulation({
            rounds: a.rounds, crowdSize: a.crowd, mix: a.mix, crowdStrength: a.strength, humans, seed: a.seed + k,
        });
        const ratio = spreadRatio(bankedTotals(log));
        if (ratio !== null) ratios.push(ratio);
    }
    const { json: _json, ...args } = a;
    const meanRatio = ratios.length ? ratios.reduce((s, x) => s + x, 0) / ratios.length : null;
    const maxRatio = ratios.length ? Math.max(...ratios) : null;
    return { args, players, runs, ratios, meanRatio, maxRatio };
}

// Q2: one exact counter against crowds of increasing size. Where its win rate stops moving is
// where the human's own throw stops moving the plurality.
export interface EffectiveNOut {
    args: Omit<CliArgs, 'json' | 'crowd'>;
    rows: { crowd: number; rate: number; ci95: number }[];
}

export function effectiveN(a: CliArgs): EffectiveNOut {
    const sizes = [5, 7, 10, 15, 20, 30, 50, 100];
    const human: HumanSpec = { id: 'counter', policy: 'counter', strength: 1, bank: { kind: 'ride' } };
    const rows = sizes.map(crowd => {
        const log = runSimulation({
            rounds: a.rounds, crowdSize: crowd, mix: a.mix, crowdStrength: a.strength, humans: [human], seed: a.seed,
        });
        const [row] = winRates(log, [human]);
        return { crowd, rate: row.rate, ci95: row.ci95 };
    });
    const { json: _json, crowd: _crowd, ...args } = a;
    return { args, rows };
}
```

- [ ] **Step 4: Write the CLI printer**

```ts
// server/src/sim/cli.ts
// npm run sim -- [--experiment readability|blind-spread|effective-n] [--rounds N] [--crowd N]
//                [--mix id:w,...] [--strength p] [--seed N] [--json]
import { formatMix } from '../engine/SyntheticCrowd';
import { parseArgs, readability, blindSpread, effectiveN } from './experiments';

const pct = (x: number) => `${(100 * x).toFixed(1)}%`;

function main(argv: string[]): void {
    const a = parseArgs(argv);
    const out = a.experiment === 'readability' ? readability(a)
        : a.experiment === 'blind-spread' ? blindSpread(a)
        : effectiveN(a);

    if (a.json) {
        console.log(JSON.stringify(out, null, 2));
        return;
    }

    console.log(`# ${a.experiment}  rounds=${a.rounds} crowd=${a.crowd} strength=${a.strength} seed=${a.seed}`);
    console.log(`# mix ${formatMix(a.mix)}`);
    if ('transitions' in out) {
        console.log('\nhuman     BEAT WORLD   ±95%    safe    loss    banked      max pot*');
        for (const h of out.humans) {
            console.log(`${h.id.padEnd(9)} ${pct(h.rate).padStart(10)} ${pct(h.ci95).padStart(6)} ${pct(h.safes / h.throws).padStart(7)} ${pct(h.losses / h.throws).padStart(7)} ${String(h.banked).padStart(9)} ${String(h.maxPot).padStart(12)}`);
        }
        console.log('* max pot is measured AFTER each round\'s bank decision');
        const t = out.transitions;
        console.log(`\nworld throw transitions (n=${t.n}): same ${pct(t.same)}  counter ${pct(t.counter)}  other ${pct(t.other)}`);
        console.log('(a blind world is 33/33/33; "counter" high means the crowd rotates the way everyone-counters predicts)');
    } else if ('ratios' in out) {
        console.log(`\n${out.players} blind players, bank at 9, ${out.runs} runs of ${a.rounds} rounds`);
        console.log(`max ÷ median banked: mean ${out.meanRatio?.toFixed(2) ?? 'n/a'}  worst ${out.maxRatio?.toFixed(2) ?? 'n/a'}`);
        console.log(`per run: ${out.ratios.map(r => r.toFixed(2)).join(' ')}`);
    } else {
        console.log('\ncrowd   counter BEAT WORLD   ±95%');
        for (const r of out.rows) console.log(`${String(r.crowd).padStart(5)} ${pct(r.rate).padStart(20)} ${pct(r.ci95).padStart(6)}`);
        console.log('(where the rate stops moving, the human\'s own throw has stopped moving the plurality)');
    }
}

main(process.argv.slice(2));
```

- [ ] **Step 5: Add the script**

In `server/package.json` `scripts`, add after `"test:watch"`:

```json
    "sim": "tsc && node dist/sim/cli.js"
```

`tsc` already excludes tests and writes to `dist/`, which `server/.gitignore` ignores.

- [ ] **Step 6: Run the tests, then the real thing**

Run: `npx vitest run src/sim/experiments.test.ts && npm test`
Expected: PASS.

Run: `npm run sim -- --rounds 2000`
Expected: a readability table with six rows and the transitions line. Then:

```bash
npm run sim -- --experiment blind-spread --rounds 360
npm run sim -- --experiment effective-n --rounds 2000
npm run sim -- --rounds 500 --json | head -20
```

Expected: each prints without error. Sanity: the `random` row sits near 33%; `oracle` is the highest row.

- [ ] **Step 7: Commit**

```bash
git add src/sim/cli.ts src/sim/experiments.ts src/sim/experiments.test.ts package.json
git commit -m "feat(sim): npm run sim -- readability, blind-spread and effective-n experiments, table or --json

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Q0 — tune the default mix, record the result

**Files:**
- Modify (maybe): `server/src/engine/SyntheticCrowd.ts` (`DEFAULT_MIX`, `DEFAULT_STRENGTH`) and the two tests that pin them (`SyntheticCrowd.test.ts` "defaults to…", `experiments.test.ts` "has sensible defaults" — the latter reads `DEFAULT_MIX` so only the strength literal `0.7` may need editing)
- Modify: `docs/wiki/world/world-throw.md` (new section, see Task 12 for the full text — this task supplies its numbers)

This is a judgement step with pre-registered targets (spec §2): at the default mix, **some teachable rule (`counter`, `conform`, `wsls` or `second`) reaches BEAT WORLD ≥ 45%**, **`random` stays within 33% ± 1.5**, and **no non-oracle rule exceeds ~60%**.

- [ ] **Step 1: Run the readability experiment at three seeds**

```bash
npm run sim -- --rounds 20000 --seed 1
npm run sim -- --rounds 20000 --seed 2
npm run sim -- --rounds 20000 --seed 3
```

- [ ] **Step 2: Judge against the targets**

If all three hold across seeds, go to Step 4. If not, adjust in this order, one change at a time, re-running after each: (a) raise `counter`'s weight toward 30 (makes the world rotate, which `second` reads); (b) raise `DEFAULT_STRENGTH` toward 0.8; (c) lower `random` toward 10. Stop at the first mix that meets all three targets. Do not exceed strength 0.85 — beyond that the crowd is a metronome, not a crowd.

- [ ] **Step 3: If anything changed, update the pinned constants and their tests**

Edit `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts`; update the `expect(DEFAULT_MIX).toEqual(…)` and `expect(DEFAULT_STRENGTH).toBe(…)` lines in `SyntheticCrowd.test.ts`; update the `strength: 0.7` literal in `experiments.test.ts` if strength moved; re-derive the `allocate(10, DEFAULT_MIX)` expectation by hand (largest remainder, `POLICY_IDS` order) and update it. Run `npm test`.

- [ ] **Step 4: Run the other two experiments at the settled mix and keep the outputs**

```bash
npm run sim -- --rounds 20000 --seed 1 > /tmp/readability.txt
npm run sim -- --experiment blind-spread --rounds 360 --seed 1 > /tmp/blind.txt
npm run sim -- --experiment effective-n --rounds 5000 --seed 1 > /tmp/effn.txt
```

These three outputs are pasted into the wiki in Task 12.

- [ ] **Step 5: Commit (only if constants changed)**

```bash
git add src/engine/SyntheticCrowd.ts src/engine/SyntheticCrowd.test.ts src/sim/experiments.test.ts
git commit -m "tune(crowd): default mix settled by the readability experiment -- <state the three rates>

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: Documentation — as-built, env vars, the flip procedure, the log

**Files:**
- Modify: `docs/wiki/world/world-throw.md` (append a section; update the ⚠ "Not active in any deployed environment" paragraph)
- Modify: `docs/wiki/systems/deploy.md` (the "Both environments run TEST_MODE=true" bullet; append the flip procedure)
- Modify: `CLAUDE.md` (the server env paragraph under "## Commands")
- Modify: `docs/wiki/log.md` (append a `ship` entry)

Per `docs/wiki/schema.md`: supersede text, don't append contradictions; never transcribe a measurable fact without saying how to re-measure it.

- [ ] **Step 1: `docs/wiki/world/world-throw.md`**

Replace the final ⚠ paragraph ("⚠ **Not active in any deployed environment.** …") with:

```markdown
⚠ **Not active in any deployed environment as of the date at the top of this page** — both
services run `TEST_MODE=true`, which keeps the deterministic R→P→S cycle. Since 2026-09-04 the
rule no longer needs a human crowd to be exercised: see § Synthetic crowd below. Whether dev
has been flipped is a live fact — query the service ([[deploy]]), do not trust this line.
```

Append:

```markdown
## Synthetic crowd (built 2026-09-04)

Spec `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md`; plan
`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`.

**What it is.** A tally crowd — bot throws that count toward the World Throw and appear in the
reveal's distribution, with no avatars. `RoundEngine` merges the bots' counts into the tally at
LOCK→REVEAL **before** `pickWorldThrow`, so the distribution on the card and the throw it
produced always agree; the per-participant `throws` map stays human-only, which is why bots
never reach settlement, `PlayerRound`, presence or any board. `Round.synthetic` records the
bot count; **`totalPlayers` is the size of the world (humans + bots)** — owner decision
2026-09-04, and the PLAYERS figure on the ledger and the stats board now means exactly that.

**Archetypes** (`server/src/engine/CrowdPolicies.ts`): `wsls` (win-stay / lose-shift-clockwise,
Wang–Xu–Zhou 2014), `counter`, `conform`, `rocky`, `random`, and the sim-only `second`. Each
is a distribution given a small memory, blended with uniform at a strength; the mix across
archetypes is the other dial. ⚠ **A hypothesis about a Roblox crowd, not a measurement.** The
recalibration path is the persisted `Round.distribution` minus the synthetic share (spec §8).

**Config** — `CROWD_SIZE` (0 = off), `CROWD_MIX` (`id:weight,…`), `CROWD_SEED`. Malformed
values refuse to boot. `CROWD_SIZE` under `TEST_MODE=true` is ignored with a warning. Read the
defaults from `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts`
rather than from here.

**The simulator** — `cd server && npm run sim -- --experiment readability|blind-spread|effective-n`.
Re-run it rather than quoting the numbers below; they are one seed on one day.

Readability at the settled default mix (`--rounds 20000 --seed 1`):

<paste /tmp/readability.txt here>

Blind-field spread (`--experiment blind-spread --rounds 360 --seed 1`):

<paste /tmp/blind.txt here>

Effective N (`--experiment effective-n --rounds 5000 --seed 1`):

<paste /tmp/effn.txt here>

**Pre-registered Q1** (owner decision 2026-09-04): one person, ~20 rounds on dev against the
default crowd with the last-five HUD; **≥ 45% BEAT WORLD** reads as "crowd-reading is a skill
here", ≈33% means the crowd is too noisy or the HUD shows the wrong thing. Result: not yet run.
```

(Replace each `<paste …>` with the actual output from Task 11 Step 4 inside a fenced code block.)

- [ ] **Step 2: `docs/wiki/systems/deploy.md`**

Replace the bullet beginning "**Both environments run `TEST_MODE=true`**" with:

```markdown
- **Both environments ran `TEST_MODE=true` as of 2026-08-16** (dev verified against the live
  service config, prod set in `apprunner.yaml`). Since 2026-09-04 the crowd-plurality rule can
  run without humans: the synthetic crowd ([[world-throw]] § Synthetic crowd) is three env vars
  on the service. **Whether dev has been flipped is a live fact — run the query below.**
```

Append a section:

```markdown
## Flipping dev to the real World Throw with a synthetic crowd

⚠ Owner-run or owner-approved, announced first: it bounces the dev backend under any live
Studio session. Prod is not touched by this procedure.

1. Read the current config and keep every field — `update-service` replaces
   `SourceConfiguration` wholesale (see the secrets warning above):
   ```bash
   ARN=$(aws apprunner list-services --region us-east-1 \
     --query "ServiceSummaryList[?ServiceName=='roshambo_server_dev'].ServiceArn" --output text)
   aws apprunner describe-service --region us-east-1 --service-arn "$ARN" \
     --query 'Service.SourceConfiguration' > /tmp/dev-source.json
   ```
2. ⚠ First check `CodeRepository.CodeConfiguration.ConfigurationSource` in that file. If it is
   `REPOSITORY`, the service takes its env from `apprunner.yaml` in the tracked branch and this
   procedure does not apply — stop and raise it with the owner (a yaml edit would also change
   prod's template). If it is `API`, edit `/tmp/dev-source.json`: under
   `CodeRepository.CodeConfiguration.CodeConfigurationValues.RuntimeEnvironmentVariables`
   set `TEST_MODE` to `"false"` and add `CROWD_SIZE: "30"`. Add `CROWD_SEED` only for a
   reproducible demo. Leave `RuntimeEnvironmentSecrets` exactly as read.
3. Apply, round-tripping the whole object:
   ```bash
   aws apprunner update-service --region us-east-1 --service-arn "$ARN" \
     --source-configuration file:///tmp/dev-source.json
   ```
4. Verify from the service logs (CloudWatch, application log group for the service): the boot
   prints `[CROWD] on: size 30, seed …, mix …` and `world throw: crowd plurality, min 5
   participants`, then one `[CROWD] round …` line per minute.
5. Record the flip on [[log]] and update the "live fact" lines on this page and on
   [[world-throw]].

To turn it back off, set `CROWD_SIZE` to `"0"` (and `TEST_MODE` back to `"true"` if the
deterministic demo is wanted) by the same round-trip.
```

- [ ] **Step 3: `CLAUDE.md`**

In the "## Commands" section, after the sentence ending "Set `TEST_MODE=true` on the server for a deterministic World Throw cycle (R→P→S) instead of random.", add:

```markdown
With `TEST_MODE` off, `CROWD_SIZE=<n>` adds a synthetic bot crowd to every round's tally (`CROWD_MIX`, `CROWD_SEED` optional; see `docs/wiki/world/world-throw.md` § Synthetic crowd). `cd server && npm run sim` runs the offline simulator over the same crowd.
```

- [ ] **Step 4: `docs/wiki/log.md`** — append:

```markdown
## [2026-09-04] ship | Synthetic crowd -- the World Throw rule can be played without a human crowd

Spec `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md`, plan
`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`. `RoundEngine` merges a seeded,
archetyped bot crowd into the tally at LOCK→REVEAL before `pickWorldThrow`; bots never enter
the throws map, so settlement and presence stay human-only by construction. `Round.synthetic`
added; `totalPlayers` now counts the world. Three env vars, refused when malformed, ignored
under TEST_MODE. `npm run sim` runs readability / blind-spread / effective-n over the same
module. Default mix settled by the readability experiment (numbers on [[world-throw]]).
Dev NOT yet flipped — procedure on [[deploy]], owner-gated. Q1 (is crowd-reading fun?) not
yet run.
```

- [ ] **Step 5: Wiki lint, if the repo has one**

Run from the repo root: `ls tools/wiki* docs/wiki/*.sh 2>/dev/null; grep -rl "wiki" .github/workflows/ | head`. If a lint exists, run it and fix what it reports.

- [ ] **Step 6: Commit**

From the repo root:

```bash
git add docs/wiki/world/world-throw.md docs/wiki/systems/deploy.md CLAUDE.md docs/wiki/log.md
git commit -m "docs(wiki): synthetic crowd as-built, env vars, the dev flip procedure, ship entry

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: Full verification and the handoff to the owner

**Files:** none new.

- [ ] **Step 1: Everything green**

From `server/`: `npm test && npx tsc --noEmit && npm run sim -- --rounds 1000`
Expected: PASS, clean, a table.

- [ ] **Step 2: Push and watch CI**

`git push` from the repo root, then confirm the `server-ci` run is green (the repo's standing rule: a push is not done until its CI run is seen green — [[rojo-and-place]]). If `gh` is too old to `gh run watch`, open the Actions tab.

- [ ] **Step 3: STOP — the flip is the owner's**

Report to the owner: the readability table, whether the three Q0 targets held and at what mix, the blind-spread and effective-N results in one line each, and the flip procedure's location. Do not run the App Runner update. Q1 is the owner's twenty minutes on dev after the flip.

---

## Self-review against the spec

- §0 tally-vs-visible: Task 12 wiki text names it; no avatar work anywhere. ✔
- §1 seam in the engine, `crowdCounts` on `roundClosed`, `throws` human-only, `CrowdSource` shape: Task 5. ✔
- §2 module, archetypes, strength blend, default mix, determinism, exact allocation: Tasks 1–3; tuning Task 11. ✔
- §3 `totalPlayers` = world, `Round.synthetic` default 0, additive on `GlobalResult`/reveal/store/API/tape seed: Task 6 (the `reveal` payload and `/rounds/:id/result` both serialize `GlobalResult`, so they carry it without edits). ✔
- §4 settlement humans-only, READ gate opens: Task 6 test asserts `User.countDocuments() === 1` and one `PlayerRound`. ✔
- §5 three env vars, boot refusal, TEST_MODE guard, per-round log, environments: Tasks 4, 7, 12. ✔
- §6 simulator, humans as policies, `second` + `oracle`, three bank rules, five reporters: Tasks 8–10 (effective-N is an experiment over `winRates`, not a separate reporter). ✔
- §7 six questions: Q0 Task 11; Q1/Q2/Q6 live after the owner's flip (Task 12 procedure, Task 13 stop); Q3 readability's banked/maxPot columns; Q4 blind-spread; Q5 transitions. ✔
- §8 fitter: out of scope, named in the wiki text. ✔
- §9 tests: every bullet has a task; no fixture change. ✔
- §10 out of scope respected: no client edits, prod untouched, no bot persistence. ✔
- Type consistency: `CrowdSource` (engine) vs `Crowd` (module) — `Crowd` has the extra `size` and `expected()`, structurally assignable. `RoundRecord.humans[i]` indexes match `HumanSpec[]` order in `winRates`. `applyBank` signature identical in Task 8 test and impl. `parseArgs` defaults match `DEFAULT_MIX`/`DEFAULT_STRENGTH` until Task 11 moves them, at which point Task 11 Step 3 updates both tests.
