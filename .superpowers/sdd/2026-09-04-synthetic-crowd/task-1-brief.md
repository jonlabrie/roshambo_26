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

