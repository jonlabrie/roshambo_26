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

