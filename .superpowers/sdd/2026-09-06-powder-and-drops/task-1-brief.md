### Task 1: The powder-eligibility flag (fixture + `fireworks.ts`)

**Files:**
- Modify: `shared-fixtures/firework-shells.json`
- Modify: `server/src/fireworks.ts` (~L73-104)
- Test: `server/src/fireworks.test.ts`

**Interfaces:**
- Produces: `POWDER_INELIGIBLE: ReadonlySet<string>` (empty today); `isPowderEligible(shellId: string): boolean` (false for unknown ids); `ShellState = { count, launchable, reason, powderEligible: boolean }`.

- [ ] **Step 1: Extend the fixture**

Add two keys to `shared-fixtures/firework-shells.json`, after `mortars` (keep the file valid JSON; both Lune readers only consume `shells`/`mortars`, so this is additive):

```json
    "powderIneligibleComment": "Shells OUTSIDE the powder economy in both directions (spec 2026-09-05 §7): not buyable with powder, not meltable. Rare / secret / special shells go here when they exist. EMPTY today -- every shipped shell is a shop shell. server/src/fireworks.ts's POWDER_INELIGIBLE is asserted equal to this list.",
    "powderIneligible": []
```

- [ ] **Step 2: Write the failing tests**

Append to `server/src/fireworks.test.ts`:

```ts
describe('the fixture is the powder-eligibility contract too', () => {
    it('POWDER_INELIGIBLE equals the fixture list', () => {
        expect([...POWDER_INELIGIBLE].sort()).toEqual([...fixtures.powderIneligible].sort());
    });
    it('every ineligible id is a real shell', () => {
        for (const id of fixtures.powderIneligible) expect(fixtures.shells).toContain(id);
    });
    it('isPowderEligible: true for every shipped shell today, false for unknown ids', () => {
        for (const id of SHELL_IDS) expect(isPowderEligible(id)).toBe(!POWDER_INELIGIBLE.has(id));
        expect(isPowderEligible('moonshot')).toBe(false);
    });
    it('shellStates carries powderEligible per shell', () => {
        const states = shellStates({ firecracker: 2 }, noGear);
        expect(states.firecracker.powderEligible).toBe(true);
        expect(states.kamuro.powderEligible).toBe(true);
    });
});
```

Add `POWDER_INELIGIBLE, isPowderEligible` to the import list at the top of the test.

- [ ] **Step 3: Run to verify it fails** — `cd server && npx vitest run src/fireworks.test.ts` → FAIL (`POWDER_INELIGIBLE` not exported).

- [ ] **Step 4: Implement**

In `server/src/fireworks.ts`, after `REQUIREMENTS`:

```ts
// OUTSIDE THE POWDER ECONOMY IN BOTH DIRECTIONS (spec 2026-09-05 §7): not buyable with powder, not
// meltable. Prestige that converts to fungible value stops being prestige. Empty today — every
// shipped shell is a shop shell — and asserted equal to shared-fixtures/firework-shells.json's
// `powderIneligible` so the first rare shell is one line on each side.
export const POWDER_INELIGIBLE: ReadonlySet<string> = new Set<string>([]);

export function isPowderEligible(shellId: string): boolean {
    return (SHELL_IDS as readonly string[]).includes(shellId) && !POWDER_INELIGIBLE.has(shellId);
}
```

Change `ShellState` and every return in `evaluateShell` to carry the flag:

```ts
export type ShellState = { count: number; launchable: boolean; reason: string | null; powderEligible: boolean };
```

Simplest: rename the existing function body to `evaluateLaunchable(shellId, count, ctx): { count; launchable; reason }` and make `evaluateShell` wrap it: `return { ...evaluateLaunchable(shellId, count, ctx), powderEligible: isPowderEligible(shellId) };`.

- [ ] **Step 5: Run the suite and type-check** — `npm test && npx tsc --noEmit`. Any test that `toEqual`s a `ShellState` literal now needs `powderEligible` — update those assertions (search `launchable:` in tests).

- [ ] **Step 6: Commit**

```bash
git add shared-fixtures/firework-shells.json server/src/fireworks.ts server/src/fireworks.test.ts
git commit -m "feat(powder): powderEligible on every shell state; the ineligible list is a fixture contract (empty today)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

