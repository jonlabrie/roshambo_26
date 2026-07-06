# Loadout Persistence (Sub-Project C, Increment 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist a per-player map of teahouse loadouts (keyed by size class) on the `User` doc, with `GET`/`PUT` `/api/v1` endpoints, light validation, Vitest-tested.

**Architecture:** A `teahouses: Map<string, Loadout>` field on the Mongoose `User` model; a pure `validateLoadout`/`validateSizeClass` helper; two `X-API-Key`-gated endpoints added to `createApiV1`, keyed via `resolveUser({robloxUserId})`. See spec: `docs/superpowers/specs/2026-07-05-roshambo-loadout-persistence-design.md`.

**Tech Stack:** TypeScript / Express / Mongoose; Vitest + supertest + `mongodb-memory-server` (`server/src/test/db.ts`). Work from `server/`; run `npm test`.

## Global Constraints

- **Caller is the trusted Roblox game server** (holds the API key) — validation is *light*, not ownership-gating.
- **Validation limits (exact):** `sizeClass` a non-empty string `<= 16` chars; a player's map holds at most **8** distinct classes (reject a PUT creating a 9th new key). `loadout` a plain object (not array/null), serialized `<= 4096` bytes, `loadout.baseStyle` a non-empty string, every top-level key in `{ baseStyle, colorScheme, shoji, tatami, flags, wallArt }` (reject unknown). No deep value validation.
- **Endpoints** (added to `server/src/routes/apiV1.ts`, reusing the router's `requireApiKey` + `resolveUser`):
  - `GET /players/:robloxUserId/teahouses` → `200 { teahouses }` (`{}` for a wanderer), `Cache-Control: no-store`.
  - `PUT /players/:robloxUserId/teahouses/:sizeClass` body `{ loadout }` → `200 { sizeClass, loadout }`; `400 { error }` on validation failure.
  - `500 RESOLVE_FAILED` if `resolveUser` returns null.
- **Do not modify** existing endpoints, models beyond the added field, or the economy.
- Test pattern: follow `server/src/routes/apiV1.test.ts` — `beforeAll(connectTestDb)`, `afterAll(disconnectTestDb)`, `beforeEach(clearTestDb)`, `process.env.API_KEY='test-key'`, `makeApp(engine, store)`.

---

### Task 1: validateLoadout + validateSizeClass helper

**Files:**
- Create: `server/src/loadout.ts`
- Test: `server/src/loadout.test.ts`

**Interfaces:**
- Produces: `validateLoadout(loadout: unknown) -> { ok: true } | { ok: false, error: string }` and `validateSizeClass(sizeClass: unknown, existingClasses: string[]) -> { ok: true } | { ok: false, error: string }`, plus exported constants `MAX_LOADOUT_BYTES=4096`, `MAX_SIZECLASS_LEN=16`, `MAX_CLASSES=8`.

- [ ] **Step 1: Write the failing test**

```ts
// server/src/loadout.test.ts
import { describe, it, expect } from 'vitest';
import { validateLoadout, validateSizeClass, MAX_CLASSES } from './loadout';

describe('validateLoadout', () => {
    it('accepts a well-formed loadout', () => {
        expect(validateLoadout({ baseStyle: 'teahouse-1story', colorScheme: 'scheme.ink' }).ok).toBe(true);
    });
    it('rejects non-objects', () => {
        expect(validateLoadout('nope').ok).toBe(false);
        expect(validateLoadout(null).ok).toBe(false);
        expect(validateLoadout([1, 2]).ok).toBe(false);
    });
    it('rejects a missing/empty baseStyle', () => {
        expect(validateLoadout({ colorScheme: 'x' }).ok).toBe(false);
        expect(validateLoadout({ baseStyle: '' }).ok).toBe(false);
    });
    it('rejects unknown top-level keys', () => {
        expect(validateLoadout({ baseStyle: 't', bogus: 1 }).ok).toBe(false);
    });
    it('rejects oversize loadouts', () => {
        expect(validateLoadout({ baseStyle: 't', wallArt: 'x'.repeat(5000) }).ok).toBe(false);
    });
});

describe('validateSizeClass', () => {
    it('accepts a short non-empty class within the cap', () => {
        expect(validateSizeClass('M', []).ok).toBe(true);
        expect(validateSizeClass('M', ['M', 'L']).ok).toBe(true); // existing key, no new-key cap
    });
    it('rejects empty/oversize class ids', () => {
        expect(validateSizeClass('', []).ok).toBe(false);
        expect(validateSizeClass('x'.repeat(17), []).ok).toBe(false);
        expect(validateSizeClass(42, []).ok).toBe(false);
    });
    it('rejects a new class beyond the cap', () => {
        const full = Array.from({ length: MAX_CLASSES }, (_, i) => `c${i}`);
        expect(validateSizeClass('new', full).ok).toBe(false); // 9th distinct
        expect(validateSizeClass('c0', full).ok).toBe(true);   // overwriting an existing one is fine
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npm test -- loadout`
Expected: FAIL — `./loadout` not found.

- [ ] **Step 3: Write minimal implementation**

```ts
// server/src/loadout.ts
export const MAX_LOADOUT_BYTES = 4096;
export const MAX_SIZECLASS_LEN = 16;
export const MAX_CLASSES = 8;

const LOADOUT_KEYS = new Set(['baseStyle', 'colorScheme', 'shoji', 'tatami', 'flags', 'wallArt']);

type Check = { ok: true } | { ok: false; error: string };

export function validateLoadout(loadout: unknown): Check {
    if (typeof loadout !== 'object' || loadout === null || Array.isArray(loadout)) {
        return { ok: false, error: 'LOADOUT_NOT_OBJECT' };
    }
    const obj = loadout as Record<string, unknown>;
    if (typeof obj.baseStyle !== 'string' || obj.baseStyle.length === 0) {
        return { ok: false, error: 'MISSING_BASESTYLE' };
    }
    for (const k of Object.keys(obj)) {
        if (!LOADOUT_KEYS.has(k)) return { ok: false, error: 'UNKNOWN_KEY' };
    }
    if (Buffer.byteLength(JSON.stringify(obj), 'utf8') > MAX_LOADOUT_BYTES) {
        return { ok: false, error: 'LOADOUT_TOO_LARGE' };
    }
    return { ok: true };
}

export function validateSizeClass(sizeClass: unknown, existingClasses: string[]): Check {
    if (typeof sizeClass !== 'string' || sizeClass.length === 0 || sizeClass.length > MAX_SIZECLASS_LEN) {
        return { ok: false, error: 'BAD_SIZECLASS' };
    }
    if (!existingClasses.includes(sizeClass) && existingClasses.length >= MAX_CLASSES) {
        return { ok: false, error: 'TOO_MANY_CLASSES' };
    }
    return { ok: true };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && npm test -- loadout`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/loadout.ts server/src/loadout.test.ts
git commit -m "feat(server): loadout + sizeClass validation helpers"
```

---

### Task 2: teahouses model field + GET/PUT endpoints

**Files:**
- Modify: `server/src/models/User.ts`
- Modify: `server/src/routes/apiV1.ts`
- Modify: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `validateLoadout`, `validateSizeClass` (Task 1); `resolveUser` (existing).
- Produces: the two endpoints (see Global Constraints) and `User.teahouses`.

- [ ] **Step 1: Add the model field**

In `server/src/models/User.ts`, add to `IUser`:

```ts
    teahouses: Map<string, unknown>;
```

and to `UserSchema` (before the closing `}, { timestamps: true }`):

```ts
    teahouses: { type: Map, of: Schema.Types.Mixed, default: {} },
```

- [ ] **Step 2: Write the failing endpoint tests** (append a `describe` block to `server/src/routes/apiV1.test.ts`)

```ts
describe('teahouses persistence', () => {
    it('GET returns {} for a wanderer, no-store', async () => {
        const res = await request(makeApp(makeEngine(), new ResultsStore()))
            .get('/api/v1/players/roblox-1/teahouses').set('X-API-Key', API_KEY).expect(200);
        expect(res.body).toEqual({ teahouses: {} });
        expect(res.headers['cache-control']).toBe('no-store');
    });

    it('PUT then GET round-trips a loadout', async () => {
        const app = makeApp(makeEngine(), new ResultsStore());
        const loadout = { baseStyle: 'teahouse-1story', colorScheme: 'scheme.vermilion' };
        await request(app).put('/api/v1/players/roblox-1/teahouses/M')
            .set('X-API-Key', API_KEY).send({ loadout }).expect(200);
        const res = await request(app).get('/api/v1/players/roblox-1/teahouses')
            .set('X-API-Key', API_KEY).expect(200);
        expect(res.body.teahouses.M).toEqual(loadout);
    });

    it('stores multiple sizes and overwrites a size', async () => {
        const app = makeApp(makeEngine(), new ResultsStore());
        const put = (sc: string, cs: string) => request(app)
            .put(`/api/v1/players/roblox-1/teahouses/${sc}`).set('X-API-Key', API_KEY)
            .send({ loadout: { baseStyle: 'teahouse-1story', colorScheme: cs } }).expect(200);
        await put('S', 'scheme.ink'); await put('L', 'scheme.vermilion'); await put('S', 'scheme.dormant');
        const res = await request(app).get('/api/v1/players/roblox-1/teahouses')
            .set('X-API-Key', API_KEY).expect(200);
        expect(res.body.teahouses.S.colorScheme).toBe('scheme.dormant');
        expect(res.body.teahouses.L.colorScheme).toBe('scheme.vermilion');
    });

    it('rejects invalid loadouts with 400', async () => {
        const app = makeApp(makeEngine(), new ResultsStore());
        const put = (body: unknown) => request(app)
            .put('/api/v1/players/roblox-1/teahouses/M').set('X-API-Key', API_KEY).send(body as object);
        await put({ loadout: 'nope' }).expect(400);
        await put({ loadout: { colorScheme: 'x' } }).expect(400);
        await put({ loadout: { baseStyle: 't', bogus: 1 } }).expect(400);
    });

    it('requires the API key', async () => {
        await request(makeApp(makeEngine(), new ResultsStore()))
            .get('/api/v1/players/roblox-1/teahouses').expect(401);
    });
});
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd server && npm test -- apiV1`
Expected: FAIL — the teahouse routes 404 (not yet added).

- [ ] **Step 4: Add the endpoints**

In `server/src/routes/apiV1.ts`, add the import at the top:

```ts
import { validateLoadout, validateSizeClass } from '../loadout';
```

and add both routes inside `createApiV1` (e.g. after the `/players/:robloxUserId` GET):

```ts
    router.get('/players/:robloxUserId/teahouses', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            res.set('Cache-Control', 'no-store');
            const teahouses = user.teahouses ? Object.fromEntries(user.teahouses as Map<string, unknown>) : {};
            res.json({ teahouses });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.put('/players/:robloxUserId/teahouses/:sizeClass', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const sizeClass = req.params.sizeClass;
            const loadout = req.body?.loadout;
            const existing = user.teahouses ? Array.from((user.teahouses as Map<string, unknown>).keys()) : [];
            const sc = validateSizeClass(sizeClass, existing);
            if (!sc.ok) { res.status(400).json({ error: sc.error }); return; }
            const ld = validateLoadout(loadout);
            if (!ld.ok) { res.status(400).json({ error: ld.error }); return; }
            if (!user.teahouses) { (user as { teahouses: Map<string, unknown> }).teahouses = new Map(); }
            (user.teahouses as Map<string, unknown>).set(sizeClass, loadout);
            await user.save();
            res.json({ sizeClass, loadout });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npm test -- apiV1`
Expected: PASS. Then run the whole server suite to confirm no regressions:

Run: `cd server && npm test`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add server/src/models/User.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): teahouse loadout persistence (User.teahouses + /api/v1 GET/PUT)"
```

---

## Self-review

- **Spec coverage:** `teahouses` map on User → Task 2 Step 1; `GET`/`PUT` endpoints (wanderer `{}`, round-trip, `no-store`, `resolveUser`, `500 RESOLVE_FAILED`) → Task 2 Steps 2/4 + tests; validation (object/size/baseStyle/whitelist/sizeClass/8-cap → `400`) → Task 1 helper + tests, wired at the route in Task 2; auth `401` reuses existing `requireApiKey` → Task 2 test. Non-goals (ownership, matching, class defs) absent.
- **Placeholder scan:** none — full TS in every step.
- **Type consistency:** `validateLoadout`/`validateSizeClass` signatures + `Check` return shape identical between Task 1 def and Task 2 usage; `MAX_CLASSES` used in both the helper and its test; the route reads/writes `user.teahouses` as `Map<string, unknown>` matching the `IUser` field and the Mongoose `Map` schema; endpoint paths match the test URLs exactly.
