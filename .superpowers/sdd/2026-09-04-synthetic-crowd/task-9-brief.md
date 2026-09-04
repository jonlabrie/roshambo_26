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

