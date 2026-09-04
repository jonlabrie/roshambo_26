### Task 1: Backend — persistence, validation, routes

**Files:**
- Modify: `server/src/models/User.ts` (interface ~line 64-66 block; schema ~line 114-119 block)
- Modify: `server/src/loadout.ts` (new validator beside `validateDecorations`, ~line 80)
- Modify: `server/src/routes/apiV1.ts` (new PUT beside the decorations PUT ~line 454; fireworks GET ~line 339)
- Test: `server/src/loadout.test.ts`, `server/src/routes/apiV1.test.ts` (extend both)

**Interfaces:**
- Consumes: `MORTAR_IDS` from `./fireworks` (`['mortar:S','mortar:M','mortar:L']`), existing `resolveUser`, `Check` type in loadout.ts.
- Produces: `User.mortarPlacements: Record<string, { offset: [number, number]; facing: 'N'|'E'|'S'|'W' }>` (Mongo `Schema.Types.Mixed`, default `{}`); `validateMortarPlacements(value: unknown, owned: string[]): Check`; `PUT /players/:robloxUserId/mortar-placements` accepting `{ placements }` (full-object replace) and returning `{ mortarPlacements }`; fireworks GET response gains `mortarPlacements`.

- [ ] **Step 1: Failing validator tests** — append to `loadout.test.ts` (import `validateMortarPlacements`):

```ts
describe('validateMortarPlacements', () => {
    const owned = ['mortar:S', 'mortar:M'];
    const ok = () => ({ 'mortar:S': { offset: [2, -3], facing: 'N' } });
    it('accepts a well-formed owned placement map', () => {
        expect(validateMortarPlacements(ok(), owned)).toEqual({ ok: true });
    });
    it('accepts an empty object (all defaults)', () => {
        expect(validateMortarPlacements({}, owned)).toEqual({ ok: true });
    });
    it('rejects non-objects, unknown ids, unowned mortars, bad offsets, bad facing', () => {
        expect(validateMortarPlacements(null, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:X': { offset: [0, 0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:L': { offset: [0, 0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0, NaN], facing: 'N' } }, owned).ok).toBe(false);
        expect(validateMortarPlacements({ 'mortar:S': { offset: [0, 0], facing: 'Q' } }, owned).ok).toBe(false);
    });
});
```

- [ ] **Step 2: Run to verify failure** — `npm test` (from `server/`): FAIL, `validateMortarPlacements` not exported.
- [ ] **Step 3: Implement the validator** in `loadout.ts` (beside `validateDecorations`, same `Check` idiom):

```ts
const MORTAR_FACINGS = new Set(['N', 'E', 'S', 'W']);
export function validateMortarPlacements(value: unknown, owned: string[]): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'MORTAR_PLACEMENTS_NOT_OBJECT' };
    }
    const ownedSet = new Set(owned);
    for (const [id, p] of Object.entries(value as Record<string, unknown>)) {
        if (!ownedSet.has(id)) return { ok: false, error: 'MORTAR_NOT_OWNED' };
        if (typeof p !== 'object' || p === null) return { ok: false, error: 'PLACEMENT_NOT_OBJECT' };
        const { offset, facing } = p as { offset?: unknown; facing?: unknown };
        if (!Array.isArray(offset) || offset.length !== 2) return { ok: false, error: 'BAD_OFFSET' };
        if (!offset.every((n) => typeof n === 'number' && Number.isFinite(n))) {
            return { ok: false, error: 'BAD_OFFSET' };
        }
        if (typeof facing !== 'string' || !MORTAR_FACINGS.has(facing)) {
            return { ok: false, error: 'BAD_FACING' };
        }
    }
    return { ok: true };
}
```

Note: unknown ids fail via `MORTAR_NOT_OWNED` (an unowned OR unknown id is equally unplaceable); `owned` is the caller's `user.mortars` — ids are validated against ownership, not just `MORTAR_IDS`.

- [ ] **Step 4: Model field** — `User.ts`: interface gains `mortarPlacements: Record<string, { offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' }>;` beside `mortars`; schema gains `mortarPlacements: { type: Schema.Types.Mixed, default: {} },` beside `mortars`.
- [ ] **Step 5: Failing route tests** — append to `apiV1.test.ts`'s fireworks describe:

```ts
it('mortar placements round-trip and ride the fireworks GET', async () => {
    await User.create({ robloxId: '911', totalPoints: 0, mortars: ['mortar:S'] });
    const app = makeApp(makeEngine(), new ResultsStore());
    const put = await request(app)
        .put('/api/v1/players/911/mortar-placements')
        .set('X-API-Key', API_KEY)
        .send({ placements: { 'mortar:S': { offset: [2, -3], facing: 'E' } } })
        .expect(200);
    expect(put.body.mortarPlacements['mortar:S']).toEqual({ offset: [2, -3], facing: 'E' });
    const get = await request(app)
        .get('/api/v1/players/911/fireworks')
        .set('X-API-Key', API_KEY)
        .expect(200);
    expect(get.body.mortarPlacements['mortar:S']).toEqual({ offset: [2, -3], facing: 'E' });
});
it('rejects placements for unowned mortars', async () => {
    await User.create({ robloxId: '912', totalPoints: 0, mortars: [] });
    await request(makeApp(makeEngine(), new ResultsStore()))
        .put('/api/v1/players/912/mortar-placements')
        .set('X-API-Key', API_KEY)
        .send({ placements: { 'mortar:S': { offset: [0, 0], facing: 'N' } } })
        .expect(400);
});
```

(Match the file's existing `User.create`/`makeApp` idioms exactly — read a neighboring fireworks test first.)

- [ ] **Step 6: Implement routes** — in `apiV1.ts`: a PUT mirroring the decorations route verbatim in shape (resolveUser → validate with `user.mortars ?? []` → assign → `user.markModified('mortarPlacements')` → save → echo); the fireworks GET's `res.json` gains `mortarPlacements: user.mortarPlacements ?? {}`. ⚠ `markModified` is REQUIRED for a Mixed-type object field — a mutated Mixed saves silently as a no-op without it.
- [ ] **Step 7: Green + commit**

```bash
npm test
git add src/models/User.ts src/loadout.ts src/routes/apiV1.ts src/loadout.test.ts src/routes/apiV1.test.ts
git commit -m "feat(mortars): backend persistence -- mortarPlacements field, validator, PUT route, GET carriage"
```

---

