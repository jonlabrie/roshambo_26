### Task 2: The drop table (`drops.ts` + fixture)

**Files:**
- Create: `shared-fixtures/firework-drops.json`
- Create: `server/src/drops.ts`
- Test: `server/src/drops.test.ts`

**Interfaces:**
- Produces: `DROP_TABLE = { default: 'firecracker', tiers: { 3: 'peony', 5: 'wa' }, ticketAtStreak: 6 }`; `dropForStreak(streak: number): { shellId: string; ticket: boolean }` — streak is the POST-win streak (1 on the first win of a run). `shellId` is `tiers[streak]` if present else `default`; `ticket` is `streak === ticketAtStreak`. Non-positive or non-integer streak → `{ shellId: default, ticket: false }`.

These tiers are the spec's STARTING VALUES, not rulings: a ticket at six follows from the roof's capacity math (spec §5). Changing a tier is a fixture edit plus the literal.

- [ ] **Step 1: Write the fixture**

```json
{
    "comment": "What a WIN drops, keyed to the streak AFTER the win (spec 2026-09-05 §7 'Drops by streak tier'). Awarded on the WIN event so it is neutral to Bank vs Stake. Drops are ITEMS, never powder amounts. Every shell here must be in firework-shells.json and must NOT be in its powderIneligible list (a drop you cannot fire yet must at least melt). server/src/drops.ts's DROP_TABLE is asserted equal to this.",
    "default": "firecracker",
    "tiers": { "3": "peony", "5": "wa" },
    "ticketAtStreak": 6,
    "cases": [
        { "streak": 1, "shellId": "firecracker", "ticket": false, "why": "first win of a run" },
        { "streak": 2, "shellId": "firecracker", "ticket": false },
        { "streak": 3, "shellId": "peony", "ticket": false, "why": "the first tier" },
        { "streak": 4, "shellId": "firecracker", "ticket": false, "why": "between tiers falls back to the default" },
        { "streak": 5, "shellId": "wa", "ticket": false },
        { "streak": 6, "shellId": "firecracker", "ticket": true, "why": "the golden ticket, with the default shell beside it" },
        { "streak": 7, "shellId": "firecracker", "ticket": false, "why": "one ticket per crossing, not per round above it" },
        { "streak": 12, "shellId": "firecracker", "ticket": false },
        { "streak": 0, "shellId": "firecracker", "ticket": false, "why": "defensive: never called on a non-win, but must not throw" },
        { "streak": -3, "shellId": "firecracker", "ticket": false },
        { "streak": 2.5, "shellId": "firecracker", "ticket": false }
    ]
}
```

- [ ] **Step 2: Write the failing test**

```ts
// server/src/drops.test.ts
import { describe, it, expect } from 'vitest';
import fixture from '../../shared-fixtures/firework-drops.json';
import shells from '../../shared-fixtures/firework-shells.json';
import { DROP_TABLE, dropForStreak } from './drops';

describe('the fixture is the contract', () => {
    it('DROP_TABLE equals the fixture', () => {
        expect(DROP_TABLE).toEqual({ default: fixture.default, tiers: fixture.tiers, ticketAtStreak: fixture.ticketAtStreak });
    });
    it('every drop shell is a real, powder-eligible shell', () => {
        const all = [fixture.default, ...Object.values(fixture.tiers)];
        for (const id of all) {
            expect(shells.shells).toContain(id);
            expect(shells.powderIneligible).not.toContain(id);
        }
    });
});

describe('dropForStreak — every fixture case', () => {
    for (const c of fixture.cases) {
        it(`streak ${c.streak} → ${c.shellId}${c.ticket ? ' + ticket' : ''}`, () => {
            expect(dropForStreak(c.streak)).toEqual({ shellId: c.shellId, ticket: c.ticket });
        });
    }
});
```

- [ ] **Step 3: Run to verify it fails** — `npx vitest run src/drops.test.ts` → `Cannot find module './drops'`.

- [ ] **Step 4: Implement**

```ts
// server/src/drops.ts
// WHAT A WIN DROPS (spec 2026-09-05 §7). Keyed to the streak AFTER the win and awarded on the WIN
// event, so it never leans on Bank vs Stake — banking does not reset currentStreak. Drops are
// ITEMS: "you got a peony" is legible to an eight-year-old; a number ticking up is not. A dropped
// gear shell a player cannot fire yet is not a dead item — it melts (Task 4).
//
// LITERALS, asserted equal to shared-fixtures/firework-drops.json by drops.test.ts. The tiers are
// starting values: the ticket at six follows from the rooftop's capacity (spec §5), and every
// tier is one fixture edit plus this table.
export const DROP_TABLE = {
    default: 'firecracker',
    tiers: { 3: 'peony', 5: 'wa' } as Record<number, string>,
    ticketAtStreak: 6,
};

export type Drop = { shellId: string; ticket: boolean };

export function dropForStreak(streak: number): Drop {
    if (!Number.isInteger(streak) || streak < 1) return { shellId: DROP_TABLE.default, ticket: false };
    return {
        shellId: DROP_TABLE.tiers[streak] ?? DROP_TABLE.default,
        ticket: streak === DROP_TABLE.ticketAtStreak,
    };
}
```

(`toEqual` compares `{ "3": "peony" }` from JSON against `{ 3: 'peony' }` — object keys are strings in both; fine.)

- [ ] **Step 5: Run** — `npx vitest run src/drops.test.ts && npx tsc --noEmit` → PASS.

- [ ] **Step 6: Commit**

```bash
git add shared-fixtures/firework-drops.json server/src/drops.ts server/src/drops.test.ts
git commit -m "feat(powder): the drop table -- streak tiers as a fixture contract; a golden ticket at the ticket streak

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

