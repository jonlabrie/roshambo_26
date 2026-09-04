### Task 1: Backend validator — mount and aim

**Files:**
- Modify: `server/src/loadout.ts` (`validateMortarPlacements`, ~line 170)
- Test: `server/src/loadout.test.ts` (extend the `validateMortarPlacements` describe)

**Interfaces:**
- Consumes: existing `Check`, `MAX_PLACEMENT_OFFSET`, `PLACEMENT_FACINGS`.
- Produces: the validator accepts `{ offset, mount?, aim?, facing? }` per entry — `mount ∈ {'floor','rail'}` and `aim ∈ {'L','C','R'}` when present, `facing` legacy-optional (valid cardinal when present), allowed-key set now `offset|facing|mount|aim`, everything else rejected as today. Routes/model unchanged (Mixed field already carries arbitrary keys; PUT/GET shapes identical).

- [ ] **Step 1: Failing tests** — append inside the existing `describe('validateMortarPlacements', ...)`:

```ts
it('accepts the rail-mounts record shape (mount + aim, no facing)', () => {
    const v = { 'mortar:S': { offset: [2, -3], mount: 'rail', aim: 'L' } };
    expect(validateMortarPlacements(v, owned)).toEqual({ ok: true });
});
it('still accepts legacy records (facing, no mount/aim)', () => {
    const v = { 'mortar:S': { offset: [2, -3], facing: 'E' } };
    expect(validateMortarPlacements(v, owned)).toEqual({ ok: true });
});
it('rejects unknown mount, unknown aim, and still rejects unknown keys', () => {
    expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], mount: 'roof', aim: 'C' } }, owned).ok).toBe(false);
    expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], mount: 'rail', aim: 'X' } }, owned).ok).toBe(false);
    expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], aim: 'C', evil: 1 } }, owned).ok).toBe(false);
});
```

- [ ] **Step 2: Verify failure** — `npm test` from `server/`: FAIL (mount/aim rejected as unknown keys).
- [ ] **Step 3: Implement** — in `validateMortarPlacements`, beside the existing checks (mirror the file's idiom exactly):

```ts
const MORTAR_MOUNTS = new Set(['floor', 'rail']);
const MORTAR_AIMS = new Set(['L', 'C', 'R']);
```

Extend the per-entry allowed-key check to `offset|facing|mount|aim`. Make `facing` OPTIONAL: validate against `PLACEMENT_FACINGS` only when present. Add: `mount`, when present, must be in `MORTAR_MOUNTS` (else `{ ok: false, error: 'BAD_MOUNT' }`); `aim`, when present, must be in `MORTAR_AIMS` (else `{ ok: false, error: 'BAD_AIM' }`). Offset rules unchanged.

- [ ] **Step 4: Green + commit**

```bash
npm test
git add src/loadout.ts src/loadout.test.ts
git commit -m "feat(mortars): validator learns mount and aim -- facing goes legacy-optional"
```

---

