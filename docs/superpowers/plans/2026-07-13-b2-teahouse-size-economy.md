# B2 Teahouse Size Economy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make deck and teahouse **size** earned items — a player buys deck tiers and teahouse tiers (linear S→M→L) with `totalPoints`, and the perch they claim materializes at the sizes they own.

**Architecture:** A pure Node `economy` module owns the catalog/prices and purchase validation; `/api/v1` gains `GET /economy` + `POST /purchase`. On the Roblox side, `SizeClasses` gains a pure `resolveBuilt` (biggest-owned capped by perch), `SiteCoordinator` claims off `maxDeckSize` (a deck-only owner gets a bare deck), and a client `EconomyController` drives walk-up buy/upgrade prompts through a server handler that live-rebuilds via the existing `TreatmentApplier`.

**Tech Stack:** TypeScript/Express/Vitest (Node server); Luau/Rojo/Lune (Roblox); ProximityPrompt + RemoteEvents.

## Global Constraints

- **Commit footer (verbatim on every commit):**
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ
  ```
- **Sizes** are exactly `'S' | 'M' | 'L'` with order `S < M < L`. `maxDeckSize` may also be `null` (owns no deck).
- **Item ids** are exactly `deck:S deck:M deck:L teahouse:S teahouse:M teahouse:L`.
- **Linear ladders:** buying a deck tier requires owning exactly the tier below (`deck:S` requires `maxDeckSize == null`); buying a teahouse tier requires owning the teahouse tier below **and** a deck `≥` that size (`teahouse ≤ deck`).
- **Currency:** spend the existing shared `totalPoints`. Spending is server-authoritative; the client never computes balances or prices (it fetches them).
- **Default teahouse loadout** granted on a teahouse purchase is `{ baseStyle: 'teahouse-1story' }` (matches `VacantState`'s `VACANT_BASE` and the B1 seed).
- **Prices are placeholder + tunable** (one source of truth in `economy.ts`): `deck {S:50, M:500, L:3000}`, `teahouse {S:30, M:300, L:2000}`.
- **F2/F4 non-fatal:** a rejected purchase (unaffordable / bad tier order / deck too small / unknown item / pad occupied) returns a specific error and changes nothing; runtime handlers warn-and-continue, never throwing out of the join/round loop.
- **Auto-build biggest:** at a claimed perch, `builtDeck = min(maxDeckSize, perch.maxSize)`, `builtTeahouse = min(maxTeahouse, builtDeck)` or none (bare deck).
- Do not commit secrets (`SecretsLocal.luau`, `server/.env`, API keys). Never insert/require asset id 139590959377658.

---

## File Structure

- **Create** `server/src/economy.ts` — pure catalog/prices + `validatePurchase`/`applyPurchase` + `DEFAULT_TEAHOUSE_LOADOUT`.
- **Create** `server/src/economy.test.ts` — Vitest for the pure economy logic.
- **Modify** `server/src/models/User.ts` — add `maxDeckSize`.
- **Modify** `server/src/routes/apiV1.ts` — `GET …/economy`, `POST …/purchase`.
- **Modify** `server/src/routes/apiV1.test.ts` — tests for the two routes.
- **Modify** `roblox/src/shared/SizeClasses.luau` — `minSize`, `nextTier`, `resolveBuilt`.
- **Modify** `roblox/tests/SizeClasses.spec.luau` — tests for the new helpers.
- **Modify** `roblox/src/shared/SiteCoordinator.luau` — claim off `economy {maxDeckSize, teahouses}`.
- **Modify** `roblox/tests/SiteCoordinator.spec.luau` — deck-only claim + inventory-sourced sizes.
- **Modify** `roblox/src/server/NetworkClient.luau` — `getEconomy`, `postPurchase`.
- **Modify** `roblox/tests/NetworkClient.spec.luau` — tests for both.
- **Modify** `roblox/src/server/TreatmentApplier.luau` — set an `Occupied` attribute on each materialized site.
- **Modify** `roblox/default.project.json` — `RequestPurchase` + `EconomyState` remotes.
- **Modify** `roblox/src/server/main.server.luau` — switch join fetch to `getEconomy`, economy stash, purchase handler (+ live rebuild + buy-to-claim), echo `EconomyState`.
- **Create** `roblox/src/client/EconomyController.client.luau` — walk-up buy/upgrade prompts.

Task order: 1 `economy.ts` → 2 `User.maxDeckSize` → 3 routes → 4 `SizeClasses` helpers → 5 `SiteCoordinator` → 6 `NetworkClient` → 7 server wiring (attr + remotes + handler) → 8 client controller + visual gate. Tasks 1–6 are unit-tested; 7–8 are runtime glue proven by lint + the visual gate.

---

### Task 1: `economy.ts` — pure catalog + purchase validation

**Files:**
- Create: `server/src/economy.ts`
- Test: `server/src/economy.test.ts`

**Interfaces:**
- Produces: `type Size = 'S'|'M'|'L'`; `SIZE_RANK`; `PRICES`; `DEFAULT_TEAHOUSE_LOADOUT`; `type EconomyState = { totalPoints: number; maxDeckSize: Size|null; teahouseSizes: Size[] }`; `validatePurchase(state, item): {ok:true;cost:number}|{ok:false;error:string}`; `applyPurchase(state, item): EconomyState` (assumes validated).

- [ ] **Step 1: Write the failing tests**

Create `server/src/economy.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { validatePurchase, applyPurchase, PRICES, EconomyState } from './economy';

const fresh = (over: Partial<EconomyState> = {}): EconomyState =>
    ({ totalPoints: 100000, maxDeckSize: null, teahouseSizes: [], ...over });

describe('validatePurchase — decks (linear ladder)', () => {
    it('gateway deck:S needs no deck and deducts its price', () => {
        expect(validatePurchase(fresh(), 'deck:S')).toEqual({ ok: true, cost: PRICES.deck.S });
    });
    it('rejects deck:S when a deck is already owned', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:S')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
    });
    it('rejects deck:M without S, accepts deck:M with S', () => {
        expect(validatePurchase(fresh(), 'deck:M').ok).toBe(false);
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:M')).toEqual({ ok: true, cost: PRICES.deck.M });
    });
    it('rejects deck:L skipping M', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'deck:L')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
    });
});

describe('validatePurchase — teahouses (linear + deck gate)', () => {
    it('teahouse:S needs an S+ deck', () => {
        expect(validatePurchase(fresh(), 'teahouse:S')).toEqual({ ok: false, error: 'DECK_TOO_SMALL' });
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'teahouse:S')).toEqual({ ok: true, cost: PRICES.teahouse.S });
    });
    it('teahouse:M needs teahouse:S AND an M+ deck', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'M', teahouseSizes: [] }), 'teahouse:M')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
        expect(validatePurchase(fresh({ maxDeckSize: 'S', teahouseSizes: ['S'] }), 'teahouse:M')).toEqual({ ok: false, error: 'DECK_TOO_SMALL' });
        expect(validatePurchase(fresh({ maxDeckSize: 'M', teahouseSizes: ['S'] }), 'teahouse:M')).toEqual({ ok: true, cost: PRICES.teahouse.M });
    });
    it('rejects re-buying an owned teahouse size', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'M', teahouseSizes: ['S', 'M'] }), 'teahouse:M')).toEqual({ ok: false, error: 'BAD_TIER_ORDER' });
    });
});

describe('validatePurchase — money + bad input', () => {
    it('rejects when unaffordable', () => {
        expect(validatePurchase(fresh({ totalPoints: 0 }), 'deck:S')).toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
    });
    it('rejects an unknown item id', () => {
        expect(validatePurchase(fresh(), 'deck:XL')).toEqual({ ok: false, error: 'BAD_ITEM' });
        expect(validatePurchase(fresh(), 'garden:S')).toEqual({ ok: false, error: 'BAD_ITEM' });
    });
});

describe('applyPurchase', () => {
    it('grants a deck tier and deducts points', () => {
        const s = applyPurchase(fresh({ totalPoints: 1000, maxDeckSize: 'S' }), 'deck:M');
        expect(s.maxDeckSize).toBe('M');
        expect(s.totalPoints).toBe(1000 - PRICES.deck.M);
    });
    it('grants a teahouse size (appended) and deducts points', () => {
        const s = applyPurchase(fresh({ totalPoints: 1000, maxDeckSize: 'M', teahouseSizes: ['S'] }), 'teahouse:M');
        expect(s.teahouseSizes).toEqual(['S', 'M']);
        expect(s.totalPoints).toBe(1000 - PRICES.teahouse.M);
    });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: FAIL — `./economy` cannot be imported (module missing).

- [ ] **Step 3: Implement**

Create `server/src/economy.ts`:

```ts
export type Size = 'S' | 'M' | 'L';
export const SIZE_RANK: Record<Size, number> = { S: 1, M: 2, L: 3 };
export const PRICES = {
    deck: { S: 50, M: 500, L: 3000 },
    teahouse: { S: 30, M: 300, L: 2000 },
} as const;
export const DEFAULT_TEAHOUSE_LOADOUT = { baseStyle: 'teahouse-1story' };

export type EconomyState = { totalPoints: number; maxDeckSize: Size | null; teahouseSizes: Size[] };
type Check = { ok: true; cost: number } | { ok: false; error: string };

// the tier that must be owned before buying `size` (null = nothing below S)
const below = (size: Size): Size | null => (size === 'S' ? null : size === 'M' ? 'S' : 'M');

export function validatePurchase(state: EconomyState, item: string): Check {
    const [kind, size] = item.split(':') as [string, Size];
    if ((kind !== 'deck' && kind !== 'teahouse') || (size !== 'S' && size !== 'M' && size !== 'L')) {
        return { ok: false, error: 'BAD_ITEM' };
    }
    const cost = PRICES[kind][size];
    if (kind === 'deck') {
        // linear: current max deck must be exactly the tier below
        if (state.maxDeckSize !== below(size)) return { ok: false, error: 'BAD_TIER_ORDER' };
    } else {
        // linear: must own the teahouse tier below (and not already own this one)
        const prev = below(size);
        const owns = (s: Size) => state.teahouseSizes.includes(s);
        if (owns(size) || (prev !== null && !owns(prev))) return { ok: false, error: 'BAD_TIER_ORDER' };
        // gate: a deck at least this size
        if (state.maxDeckSize === null || SIZE_RANK[state.maxDeckSize] < SIZE_RANK[size]) {
            return { ok: false, error: 'DECK_TOO_SMALL' };
        }
    }
    if (state.totalPoints < cost) return { ok: false, error: 'INSUFFICIENT_POINTS' };
    return { ok: true, cost };
}

export function applyPurchase(state: EconomyState, item: string): EconomyState {
    const chk = validatePurchase(state, item);
    if (!chk.ok) throw new Error(`applyPurchase on invalid item: ${chk.error}`);
    const [kind, size] = item.split(':') as [string, Size];
    const next: EconomyState = {
        totalPoints: state.totalPoints - chk.cost,
        maxDeckSize: state.maxDeckSize,
        teahouseSizes: [...state.teahouseSizes],
    };
    if (kind === 'deck') next.maxDeckSize = size;
    else next.teahouseSizes.push(size);
    return next;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: PASS (all cases green).

- [ ] **Step 5: Commit**

```bash
git add server/src/economy.ts server/src/economy.test.ts
git commit -m "feat(server): pure teahouse-size purchase economy (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 2: `User.maxDeckSize`

**Files:**
- Modify: `server/src/models/User.ts:22-24,46-48`
- Test: `server/src/models/models.test.ts`

**Interfaces:**
- Produces: `IUser.maxDeckSize: 'S'|'M'|'L'|null` (schema default `null`).

- [ ] **Step 1: Write the failing test**

Append to `server/src/models/models.test.ts` (inside the existing top-level `describe`, mirroring the `padPreferences` test):

```ts
    it('User.maxDeckSize defaults to null and round-trips a tier', async () => {
        const fresh = await User.create({ deviceId: 'devDeckA' });
        expect(fresh.maxDeckSize).toBeNull();
        const set = await User.create({ deviceId: 'devDeckB', maxDeckSize: 'M' });
        expect(set.maxDeckSize).toBe('M');
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd server && npx vitest run src/models/models.test.ts`
Expected: FAIL — `maxDeckSize` is `undefined` (not `null`) / not persisted.

- [ ] **Step 3: Implement**

In `server/src/models/User.ts`, add to the `IUser` interface (after line 23 `padPreferences`):

```ts
    maxDeckSize: 'S' | 'M' | 'L' | null;
```

and to the schema (after the `padPreferences` schema line 47):

```ts
    maxDeckSize: { type: String, enum: ['S', 'M', 'L', null], default: null },
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd server && npx vitest run src/models/models.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/User.ts server/src/models/models.test.ts
git commit -m "feat(server): User.maxDeckSize deck-tier ownership field (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 3: `/api/v1` economy + purchase routes

**Files:**
- Modify: `server/src/routes/apiV1.ts` (add two routes near the teahouses routes)
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `economy.ts` (`validatePurchase`, `applyPurchase`, `PRICES`, `DEFAULT_TEAHOUSE_LOADOUT`, `Size`, `EconomyState`); `resolveUser`; `User`.
- Produces:
  - `GET /players/:robloxUserId/economy` → `{ totalPoints, maxDeckSize, teahouseSizes, catalog: PRICES }`.
  - `POST /players/:robloxUserId/purchase` body `{ item }` → 200 `{ item, totalPoints, maxDeckSize, teahouseSizes }` on success; 400 `{ error }` on a rejected purchase.

- [ ] **Step 1: Write the failing tests**

Add to `server/src/routes/apiV1.test.ts` (follow the file's existing supertest + DB-harness setup; use the same app/agent it already builds). Insert a new describe:

```ts
describe('/api/v1 economy + purchase', () => {
    it('GET economy returns balance, tiers, and the catalog', async () => {
        await User.create({ robloxId: '900001', totalPoints: 120, maxDeckSize: 'S', teahouses: { S: { baseStyle: 'teahouse-1story' } } });
        const res = await agent.get('/api/v1/players/900001/economy').set('X-API-Key', API_KEY);
        expect(res.status).toBe(200);
        expect(res.body.totalPoints).toBe(120);
        expect(res.body.maxDeckSize).toBe('S');
        expect(res.body.teahouseSizes).toEqual(['S']);
        expect(res.body.catalog.deck.M).toBe(500);
    });

    it('POST purchase deck:S grants the tier and deducts points', async () => {
        await User.create({ robloxId: '900002', totalPoints: 60 });
        const res = await agent.post('/api/v1/players/900002/purchase').set('X-API-Key', API_KEY).send({ item: 'deck:S' });
        expect(res.status).toBe(200);
        expect(res.body.maxDeckSize).toBe('S');
        expect(res.body.totalPoints).toBe(10);
        const reread = await agent.get('/api/v1/players/900002/economy').set('X-API-Key', API_KEY);
        expect(reread.body.maxDeckSize).toBe('S');
    });

    it('POST purchase teahouse:S grants the size key in the teahouses map', async () => {
        await User.create({ robloxId: '900003', totalPoints: 100, maxDeckSize: 'S' });
        const res = await agent.post('/api/v1/players/900003/purchase').set('X-API-Key', API_KEY).send({ item: 'teahouse:S' });
        expect(res.status).toBe(200);
        expect(res.body.teahouseSizes).toEqual(['S']);
    });

    it('POST purchase rejects unaffordable / bad tier / bad item with 400', async () => {
        await User.create({ robloxId: '900004', totalPoints: 0 });
        expect((await agent.post('/api/v1/players/900004/purchase').set('X-API-Key', API_KEY).send({ item: 'deck:S' })).status).toBe(400);
        await User.create({ robloxId: '900005', totalPoints: 100000 });
        expect((await agent.post('/api/v1/players/900005/purchase').set('X-API-Key', API_KEY).send({ item: 'deck:M' })).body.error).toBe('BAD_TIER_ORDER');
        expect((await agent.post('/api/v1/players/900005/purchase').set('X-API-Key', API_KEY).send({ item: 'nope:S' })).body.error).toBe('BAD_ITEM');
    });
});
```

(If `API_KEY`/`agent` are named differently in the file, use the file's existing names — read the top of `apiV1.test.ts` first.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: FAIL — the routes 404 (not defined).

- [ ] **Step 3: Implement**

In `server/src/routes/apiV1.ts`, add the import at the top with the other imports:

```ts
import { validatePurchase, applyPurchase, PRICES, Size, EconomyState } from '../economy';
```

Add both routes next to the teahouses routes (after the teahouses PUT handler). A small local helper reads a user's economy state:

```ts
    const readEconomy = (user: { totalPoints: number; maxDeckSize: Size | null; teahouses?: Map<string, unknown> }): EconomyState => ({
        totalPoints: user.totalPoints,
        maxDeckSize: user.maxDeckSize,
        teahouseSizes: (user.teahouses ? Array.from(user.teahouses.keys()) : []) as Size[],
    });

    router.get('/players/:robloxUserId/economy', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            res.set('Cache-Control', 'no-store');
            const st = readEconomy(user);
            const teahouses = user.teahouses ? Object.fromEntries(user.teahouses as Map<string, unknown>) : {};
            // superset: the single join fetch — balance + tiers + teahouse LOADOUTS (server needs
            // them to build) + preferences + the price catalog for the client.
            res.json({
                totalPoints: st.totalPoints,
                maxDeckSize: st.maxDeckSize,
                teahouses,
                teahouseSizes: st.teahouseSizes,
                padPreferences: user.padPreferences ?? [],
                catalog: PRICES,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.post('/players/:robloxUserId/purchase', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const item = req.body?.item;
            if (typeof item !== 'string') { res.status(400).json({ error: 'BAD_ITEM' }); return; }
            const before = readEconomy(user);
            const chk = validatePurchase(before, item);
            if (!chk.ok) { res.status(400).json({ error: chk.error }); return; }
            const after = applyPurchase(before, item);
            user.totalPoints = after.totalPoints;
            user.maxDeckSize = after.maxDeckSize;
            const [kind, size] = item.split(':') as [string, Size];
            if (kind === 'teahouse') {
                (user.teahouses as Map<string, unknown>).set(size, { ...DEFAULT_TEAHOUSE_LOADOUT });
            }
            await user.save();
            res.json({ item, totalPoints: after.totalPoints, maxDeckSize: after.maxDeckSize, teahouseSizes: after.teahouseSizes });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): /api/v1 economy + purchase routes (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 4: `SizeClasses` ladder helpers

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau` (add before `return SizeClasses`)
- Test: `roblox/tests/SizeClasses.spec.luau`

**Interfaces:**
- Consumes: existing `SizeClasses.rank` (`{S=1,M=2,L=3}`), `SizeClasses.order`.
- Produces:
  - `SizeClasses.minSize(a: string, b: string): string` — the lower-ranked of two sizes.
  - `SizeClasses.nextTier(size: string?): string?` — `S→M→L→nil`; `nil→"S"` (nothing owned → next is S).
  - `SizeClasses.resolveBuilt(maxDeckSize: string?, teahouseSizes: { string }, perchMax: string): { deckSize: string, teahouseSize: string? }?` — `nil` when `maxDeckSize == nil` (not an owner); else deck capped by perch, teahouse = biggest owned capped by deck (or nil for a bare deck).

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/SizeClasses.spec.luau` (inside the existing describe or a new one):

```lua
describe("SizeClasses ladder helpers", function()
    test("minSize returns the lower-ranked size", function()
        expect(SizeClasses.minSize("S", "L")).toBe("S")
        expect(SizeClasses.minSize("L", "M")).toBe("M")
        expect(SizeClasses.minSize("M", "M")).toBe("M")
    end)

    test("nextTier walks S->M->L->nil, and nil->S", function()
        expect(SizeClasses.nextTier(nil)).toBe("S")
        expect(SizeClasses.nextTier("S")).toBe("M")
        expect(SizeClasses.nextTier("M")).toBe("L")
        expect(SizeClasses.nextTier("L") == nil).toBe(true)
    end)

    test("resolveBuilt: nil deck -> not an owner", function()
        expect(SizeClasses.resolveBuilt(nil, {}, "L") == nil).toBe(true)
    end)

    test("resolveBuilt: deck capped by perch; teahouse capped by deck", function()
        local r = SizeClasses.resolveBuilt("L", { "S", "M", "L" }, "M") -- perch caps at M
        expect(r.deckSize).toBe("M")
        expect(r.teahouseSize).toBe("M") -- own L teahouse but deck is M
    end)

    test("resolveBuilt: no teahouses -> bare deck (teahouseSize nil)", function()
        local r = SizeClasses.resolveBuilt("S", {}, "L")
        expect(r.deckSize).toBe("S")
        expect(r.teahouseSize == nil).toBe(true)
    end)

    test("resolveBuilt: biggest owned teahouse within the deck", function()
        local r = SizeClasses.resolveBuilt("L", { "S", "M" }, "L")
        expect(r.deckSize).toBe("L")
        expect(r.teahouseSize).toBe("M")
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `SizeClasses.minSize`/`nextTier`/`resolveBuilt` are nil.

- [ ] **Step 3: Implement**

In `roblox/src/shared/SizeClasses.luau`, add before `return SizeClasses`:

```lua
-- the lower-ranked of two sizes (S < M < L)
function SizeClasses.minSize(a: string, b: string): string
    return if SizeClasses.rank[a] <= SizeClasses.rank[b] then a else b
end

-- next tier up: nil -> "S", S -> "M", M -> "L", L -> nil
function SizeClasses.nextTier(size: string?): string?
    if size == nil then
        return "S"
    elseif size == "S" then
        return "M"
    elseif size == "M" then
        return "L"
    end
    return nil
end

-- what materializes at a perch: deck capped by the perch, teahouse = biggest owned capped by
-- the deck (nil = bare deck). Returns nil when the player owns no deck (not an owner).
function SizeClasses.resolveBuilt(
    maxDeckSize: string?,
    teahouseSizes: { string },
    perchMax: string
): { deckSize: string, teahouseSize: string? }?
    if maxDeckSize == nil then
        return nil
    end
    local deckSize = SizeClasses.minSize(maxDeckSize, perchMax)
    local maxTea: string? = nil
    for _, s in teahouseSizes do
        if maxTea == nil or SizeClasses.rank[s] > SizeClasses.rank[maxTea] then
            maxTea = s
        end
    end
    local teahouseSize: string? = if maxTea ~= nil then SizeClasses.minSize(maxTea, deckSize) else nil
    return { deckSize = deckSize, teahouseSize = teahouseSize }
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean (else `stylua src tests` then re-check).

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): SizeClasses ladder helpers (minSize/nextTier/resolveBuilt) (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 5: `SiteCoordinator` claims off deck ownership

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau` (`onJoin`, and its `Teahouse`/`onJoin` types)
- Test: `roblox/tests/SiteCoordinator.spec.luau`

**Interfaces:**
- Consumes: `SizeClasses.resolveBuilt` (Task 4); existing `VacantState.resolve` (nil loadout = bare deck), `PadRegistry`, the `CENTERED` local.
- Produces: `SiteCoordinator:onJoin(playerId: string, economy: { maxDeckSize: string?, teahouses: { [string]: any } }?, preferences: { string }?): Action?` — claims the first vacant (preference-first) perch when the player owns a deck; builds `deckSize` + optional teahouse from `SizeClasses.resolveBuilt`. A deck-only owner (empty `teahouses`) claims a bare deck.

- [ ] **Step 1: Write the failing test**

Replace the body of the existing size-cap test and add cases in `roblox/tests/SiteCoordinator.spec.luau`. Use the file's existing fake registry/site setup; the new `onJoin` takes an `economy` table. Add:

```lua
    test("deck-only owner claims a bare deck (no teahouse)", function()
        local sc = makeCoordinatorWithSites({ { id = "P1", maxSize = "L" } }) -- helper in this file
        local action = sc:onJoin("u1", { maxDeckSize = "S", teahouses = {} }, nil)
        expect(action.deckSize).toBe("S")
        expect(action.teahouse == nil).toBe(true)
    end)

    test("sizes come from inventory (maxDeckSize), not the pad default", function()
        local sc = makeCoordinatorWithSites({ { id = "P1", maxSize = "L" } })
        local action = sc:onJoin("u1", { maxDeckSize = "M", teahouses = { S = { baseStyle = "teahouse-1story" } } }, nil)
        expect(action.deckSize).toBe("M")
        expect(action.teahouse.size).toBe("S") -- biggest owned teahouse (S) within the M deck
    end)

    test("a player who owns no deck does not claim", function()
        local sc = makeCoordinatorWithSites({ { id = "P1", maxSize = "L" } })
        expect(sc:onJoin("u1", { maxDeckSize = nil, teahouses = {} }, nil) == nil).toBe(true)
        expect(sc:onJoin("u1", nil, nil) == nil).toBe(true)
    end)
```

(If the spec file has no `makeCoordinatorWithSites` helper, add a small one mirroring the existing test setup — register one pad with `spec = { maxSize, deckPlacements = {...}, vacantForm = "dormant-structure", displayName = "P1" }` on the fake registry the file already uses.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `onJoin` still expects `ownedTeahouses` and ignores `maxDeckSize`.

- [ ] **Step 3: Implement**

In `roblox/src/shared/SiteCoordinator.luau`, add the require at the top with the others:

```lua
local SizeClasses = require("./SizeClasses")
```
(if already required, skip). Replace `onJoin` with:

```lua
function SiteCoordinator:onJoin(
    playerId: string,
    economy: { maxDeckSize: string?, teahouses: { [string]: any } }?,
    preferences: { string }?
): Action?
    if self._held[playerId] ~= nil then
        return nil
    end
    if economy == nil or economy.maxDeckSize == nil then
        return nil -- not an owner (owns no deck) -> no auto-claim
    end
    local teahouses = economy.teahouses or {}
    local teaSizes: { string } = {}
    for size in teahouses do
        table.insert(teaSizes, size)
    end
    local order = self:_orderedSiteIds(preferences)
    for _, id in order do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            local built = SizeClasses.resolveBuilt(economy.maxDeckSize, teaSizes, rec.spec.maxSize)
            if built ~= nil then
                self._registry:claim(id, playerId)
                self._held[playerId] = id
                local teaLoadout = if built.teahouseSize ~= nil then teahouses[built.teahouseSize] else nil
                local teahouse = if built.teahouseSize ~= nil
                    then { size = built.teahouseSize, loadout = teaLoadout, placement = CENTERED }
                    else nil
                return {
                    padId = id,
                    spec = rec.spec,
                    treatment = VacantState.resolve(playerId, teaLoadout, rec.spec.vacantForm),
                    deckSize = built.deckSize,
                    teahouse = teahouse,
                }
            end
        end
    end
    return nil
end
```

Also update the `Teahouse` type comment / any `onJoin` type annotation to reflect the new `economy` param (the `Action` type is unchanged — `teahouse` was already optional).

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS — new cases green, existing SiteCoordinator tests updated to the new signature still green.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau
git commit -m "feat(roblox): SiteCoordinator claims off deck ownership + resolveBuilt sizes (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 6: `NetworkClient.getEconomy` + `postPurchase`

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau` (after `setTeahouse`)
- Test: `roblox/tests/NetworkClient.spec.luau`

**Interfaces:**
- Consumes: `NetworkClient._request`.
- Produces: `getEconomy(self, robloxUserId): Result` (`GET /api/v1/players/{id}/economy`); `postPurchase(self, robloxUserId, item): Result` (`POST /api/v1/players/{id}/purchase` body `{ item = item }`).

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/NetworkClient.spec.luau`:

```lua
describe("NetworkClient.getEconomy + postPurchase", function()
    test("getEconomy GETs the economy path and decodes it", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"totalPoints":120,"maxDeckSize":"S","teahouseSizes":["S"],"catalog":{"deck":{"S":50}}}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getEconomy("9")
        expect(res.ok).toBe(true)
        expect(res.data.maxDeckSize).toBe("S")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/economy")
        expect(f.calls[1].method).toBe("GET")
    end)

    test("postPurchase POSTs the item and returns the new state", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"item":"deck:M","totalPoints":500,"maxDeckSize":"M","teahouseSizes":["S"]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postPurchase("9", "deck:M")
        expect(res.ok).toBe(true)
        expect(res.data.maxDeckSize).toBe("M")
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/purchase")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.item).toBe("deck:M")
    end)

    test("postPurchase surfaces a 400 fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"INSUFFICIENT_POINTS"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postPurchase("9", "deck:M")
        expect(res.ok).toBe(false)
        expect(res.error).toBe("INSUFFICIENT_POINTS")
        expect(#f.calls).toBe(1)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `getEconomy`/`postPurchase` are nil.

- [ ] **Step 3: Implement**

In `roblox/src/server/NetworkClient.luau`, add after `setTeahouse` (before `return NetworkClient`):

```lua
function NetworkClient.getEconomy(self: any, robloxUserId: string): Result
    return self:_request("GET", `/api/v1/players/{robloxUserId}/economy`)
end

function NetworkClient.postPurchase(self: any, robloxUserId: string, item: string): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/purchase`, { item = item })
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(roblox): NetworkClient getEconomy + postPurchase (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 7: Server wiring — occupancy attribute, remotes, economy stash + purchase handler

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau` (set an `Occupied` attribute on the site folder)
- Modify: `roblox/default.project.json` (two RemoteEvents)
- Modify: `roblox/src/server/main.server.luau` (join fetch → `getEconomy`; economy stash; `RequestPurchase` handler; `EconomyState` echo)

Roblox-runtime glue (no Lune test, matching `SetPadPreference`/`SetBackDoor`). Verification: `stylua`/`selene` clean + Lune suite unchanged + the Task 8 visual gate.

**Interfaces:**
- Consumes: `SiteCoordinator:onJoin(playerId, economy, preferences)` (Task 5); `net:getEconomy`/`net:postPurchase` (Task 6); `SizeClasses.resolveBuilt`; `applier:apply`; existing `playerPrefs` stash pattern.
- Produces: `RequestPurchase` (C→S `{ item: string, padId: string? }`), `EconomyState` (S→C `{ totalPoints, maxDeckSize, teahouseSizes, claimedPadId, catalog }`), and a `MaterializedSite_<id>` `Occupied` boolean attribute.

- [ ] **Step 1: Occupancy attribute on materialized sites**

In `roblox/src/server/TreatmentApplier.luau`, in `apply` after the commit swap (after the staged children are parented into `folder`), set the attribute from the treatment:

```lua
    folder:SetAttribute("Occupied", treatment.lit == true)
```
(place it just before `apply` returns, after the `staging:Destroy()`). `treatment.lit` is `true` for a claimed owner, `false`/absent for dormant vacant sites.

- [ ] **Step 2: Declare the remotes**

In `roblox/default.project.json`, add to `RoshamboRemotes` (comma after the prior last entry):

```json
                "RequestPurchase": { "$className": "RemoteEvent" },
                "EconomyState": { "$className": "RemoteEvent" }
```

- [ ] **Step 3: Require + grab the modules/remotes**

In `roblox/src/server/main.server.luau`, ensure `SizeClasses` is required (it is used by the applier deps; if not already a local, add `local SizeClasses = require(shared:WaitForChild("SizeClasses"))`). After the other `remotes:WaitForChild` lines add:

```lua
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
```

- [ ] **Step 4: Economy stash + switch the join fetch**

Add near the `playerPrefs` decl:

```lua
-- economy per player (for purchase gating + the client's prompts/labels): the fetched balance,
-- deck tier, owned teahouse loadouts, and the claimed pad (nil until they own+claim).
local playerEconomy: { [string]: { totalPoints: number, maxDeckSize: string?, teahouses: { [string]: any }, claimedPadId: string? } } = {}
-- the price catalog is identical for everyone; stash the first one fetched so echoes carry it.
local economyCatalog: any = nil
```

Add a helper (near the top-level fns) that echoes state to a client:

```lua
local function echoEconomy(player: Player, uid: string)
    local e = playerEconomy[uid]
    if e == nil or not player:IsDescendantOf(Players) then
        return
    end
    local teaSizes = {}
    for size in e.teahouses do
        table.insert(teaSizes, size)
    end
    EconomyState:FireClient(player, {
        totalPoints = e.totalPoints,
        maxDeckSize = e.maxDeckSize,
        teahouseSizes = teaSizes,
        claimedPadId = e.claimedPadId,
        catalog = economyCatalog,
    })
end
```

In `PlayerAdded`, replace the `net:getTeahouses` fetch and the `owned`/`onJoin` lines with a single `getEconomy` (the superset from Task 3 carries balance + tiers + teahouse loadouts + preferences + catalog):

```lua
        local res = net:getEconomy(tostring(player.UserId))
        local uid = tostring(player.UserId)
        local ecoData = if res.ok then res.data else nil
        local prefs = (ecoData and ecoData.padPreferences) or {}
        local teahouses = (ecoData and ecoData.teahouses) or {}
        playerPrefs[uid] = prefs
        if ecoData and ecoData.catalog then
            economyCatalog = ecoData.catalog
        end
        playerEconomy[uid] = {
            totalPoints = (ecoData and ecoData.totalPoints) or 0,
            maxDeckSize = ecoData and ecoData.maxDeckSize or nil,
            teahouses = teahouses,
            claimedPadId = nil,
        }
        local action = siteCoordinator:onJoin(uid, { maxDeckSize = playerEconomy[uid].maxDeckSize, teahouses = teahouses }, prefs)
        if action then
            -- (existing left-mid-fetch release guard stays: if the player left during the yield,
            -- run onLeave to release the just-claimed pad, clear the stashes, and return)
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
            playerEconomy[uid].claimedPadId = action.padId
        end
        echoEconomy(player, uid)
```

(Preserve the existing "player left mid-fetch" release guard and the `PreferenceState` echo already present.) Clear `playerEconomy[uid] = nil` in both leave paths next to the `playerPrefs` clears.

- [ ] **Step 5: The `RequestPurchase` handler**

After the `SetBackDoor` handler, add:

```lua
RequestPurchase.OnServerEvent:Connect(function(player, payload)
    local uid = tostring(player.UserId)
    local e = playerEconomy[uid]
    if e == nil then
        return
    end
    local item = if typeof(payload) == "table" then payload.item else nil
    if typeof(item) ~= "string" then
        return
    end
    local res = net:postPurchase(uid, item)
    if not res.ok then
        warn(`[B2] purchase {item} failed for {uid}: {tostring(res.error)}`)
        echoEconomy(player, uid) -- resync the client's labels/balance
        return
    end
    -- adopt the authoritative new state
    e.totalPoints = res.data.totalPoints
    e.maxDeckSize = res.data.maxDeckSize
    local kind, size = string.match(item, "^(%a+):(%a+)$")
    if kind == "teahouse" and size then
        e.teahouses[size] = { baseStyle = "teahouse-1story" }
    end
    -- buy-to-claim: a non-owner buying deck:S claims the pad named in the payload
    if e.claimedPadId == nil and kind == "deck" then
        local padId = if typeof(payload.padId) == "string" then payload.padId else nil
        if padId and PadSites[padId] then
            local action = siteCoordinator:onJoin(uid, { maxDeckSize = e.maxDeckSize, teahouses = e.teahouses }, { padId })
            if action then
                applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
                e.claimedPadId = action.padId
            end
        end
    elseif e.claimedPadId ~= nil then
        -- upgrade: live-rebuild the claimed pad at the new sizes
        local rec = padRegistry:get(e.claimedPadId) -- the registry instance used by siteCoordinator
        local spec = PadSites[e.claimedPadId]
        if spec then
            local teaSizes = {}
            for s in e.teahouses do
                table.insert(teaSizes, s)
            end
            local built = SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize)
            if built then
                local teaLoadout = if built.teahouseSize then e.teahouses[built.teahouseSize] else nil
                local teahouse = if built.teahouseSize then { size = built.teahouseSize, loadout = teaLoadout, placement = { offset = { 0, 0 }, facing = "N" } } else nil
                local treatment = { kind = "structure", loadout = teaLoadout, lit = true }
                applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
            end
        end
    end
    echoEconomy(player, uid)
end)
```

(Use whatever local name the composition root already gives the `PadRegistry` instance passed into `SiteCoordinator.new` — read it near the `siteCoordinator` construction. If it isn't in scope, thread it in or add a `SiteCoordinator:heldPad(uid)` accessor; keep it minimal.)

- [ ] **Step 6: Lint + suite**

Run: `cd roblox && stylua --check src tests && selene src` (clean), then `cd roblox && lune run tests/run` (no regressions).

- [ ] **Step 7: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau roblox/default.project.json roblox/src/server/main.server.luau
git commit -m "feat(roblox): server economy wiring — occupancy attr, remotes, purchase handler (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 8: `EconomyController` client + visual gate

**Files:**
- Create: `roblox/src/client/EconomyController.client.luau`

Roblox-runtime LocalScript (no Lune test); verified by lint + the visual gate. Mirrors `PerchPreferenceController`/`BackDoorController`.

**Interfaces:**
- Consumes: `RequestPurchase` (fires `{ item, padId? }`), `EconomyState` (`{ totalPoints, maxDeckSize, teahouseSizes, claimedPadId, catalog }`) from Task 7; `workspace.TeahouseSites.MaterializedSite_<id>` with the `Occupied` attribute (Task 7).

- [ ] **Step 1: Implement the controller**

Create `roblox/src/client/EconomyController.client.luau`:

```lua
--!strict
-- Walk-up buy/upgrade prompts for the size economy (B2). Non-owner (no maxDeckSize): a
-- "Buy S deck & claim" prompt on each VACANT materialized site (Occupied attribute false).
-- Owner: an "Upgrade" prompt on their OWN claimed site offering the next deck/teahouse tier.
-- Server-authoritative: this only fires RequestPurchase and relabels from the echoed EconomyState.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local SizeClasses = require(shared:WaitForChild("SizeClasses"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent

local state = { maxDeckSize = nil :: string?, teahouseSizes = {} :: { string }, claimedPadId = nil :: string?, catalog = nil :: any, totalPoints = 0 }
local prompts: { [string]: ProximityPrompt } = {} -- siteId -> its prompt

local function priceOf(item: string): number?
    local kind, size = string.match(item, "^(%a+):(%a+)$")
    if state.catalog and kind and size and state.catalog[kind] then
        return state.catalog[kind][size]
    end
    return nil
end

local function anchor(structure: Instance): BasePart?
    local deck = structure:FindFirstChild("PadDeck", true)
    if deck and deck:IsA("BasePart") then
        return deck
    end
    return structure:FindFirstChildWhichIsA("BasePart", true)
end

-- returns (item, actionText) or nil for what this site offers the local player
local function offerFor(siteId: string, occupied: boolean): (string?, string?)
    if state.maxDeckSize == nil then
        -- non-owner: buy the S deck & claim a VACANT site
        if not occupied then
            local p = priceOf("deck:S")
            return "deck:S", `Buy S deck & claim — {p} pts`
        end
        return nil, nil
    end
    -- owner: upgrades only on their OWN claimed site. ONE prompt alternates deck<->teahouse: if
    -- the deck is bigger than the biggest owned teahouse, the next step is a teahouse (to fill the
    -- deck); otherwise it's a bigger deck. Covers BOTH ladders through the single key.
    if siteId ~= state.claimedPadId then
        return nil, nil
    end
    local maxTea: string? = nil
    for _, s in state.teahouseSizes do
        if maxTea == nil or SizeClasses.rank[s] > SizeClasses.rank[maxTea] then
            maxTea = s
        end
    end
    local deckRank = if state.maxDeckSize ~= nil then SizeClasses.rank[state.maxDeckSize] else 0
    local teaRank = if maxTea ~= nil then SizeClasses.rank[maxTea] else 0
    if deckRank > teaRank then
        local nt = SizeClasses.nextTier(maxTea) -- next teahouse tier, guaranteed <= deck here
        if nt ~= nil then
            return `teahouse:{nt}`, `Add {nt} teahouse — {priceOf(`teahouse:{nt}`)} pts`
        end
    end
    local nd = SizeClasses.nextTier(state.maxDeckSize)
    if nd ~= nil then
        return `deck:{nd}`, `Upgrade deck → {nd} — {priceOf(`deck:{nd}`)} pts`
    end
    return nil, nil -- fully upgraded (L deck + L teahouse)
end

local function refresh()
    local sites = workspace:FindFirstChild("TeahouseSites")
    if sites == nil then
        return
    end
    for _, folder in sites:GetChildren() do
        local siteId = folder.Name:match("^MaterializedSite_(.+)$")
        if siteId then
            local occupied = folder:GetAttribute("Occupied") == true
            local item, text = offerFor(siteId, occupied)
            local existing = prompts[siteId]
            if item == nil then
                if existing then
                    existing:Destroy()
                    prompts[siteId] = nil
                end
            else
                local structure = folder:FindFirstChild("Structure")
                local a = structure and anchor(structure)
                if a then
                    local prompt = existing
                    if prompt == nil then
                        prompt = Instance.new("ProximityPrompt")
                        prompt.ObjectText = "Teahouse"
                        prompt.KeyboardKeyCode = Enum.KeyCode.G -- E=Favorite, F=door, G=economy
                        prompt.MaxActivationDistance = 14
                        prompt.RequiresLineOfSight = false
                        prompt.Parent = a
                        local capturedId = siteId
                        prompt.Triggered:Connect(function()
                            local it = select(1, offerFor(capturedId, (folder:GetAttribute("Occupied") == true)))
                            if it then
                                RequestPurchase:FireServer({ item = it, padId = capturedId })
                            end
                        end)
                        prompts[siteId] = prompt
                    end
                    prompt.ActionText = text
                end
            end
        end
    end
end

EconomyState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then
        return
    end
    state.totalPoints = payload.totalPoints or 0
    state.maxDeckSize = payload.maxDeckSize
    state.teahouseSizes = payload.teahouseSizes or {}
    state.claimedPadId = payload.claimedPadId
    if payload.catalog ~= nil then
        state.catalog = payload.catalog
    end
    refresh()
end)

workspace:WaitForChild("TeahouseSites")
task.defer(refresh)
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean (else `stylua src tests` then re-check).

- [ ] **Step 3: Suite (no regressions)**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 4: Visual gate (manual Studio — proves Tasks 3–8 end-to-end)**

Rojo-sync (restart `rojo serve` so the new remotes land) + Play, as a player who owns **nothing** (empty `maxDeckSize`/`teahouses`). Verify one attempt, then STOP and ask the user to look (stop-and-ask rule):

1. **Buy-to-claim:** at a **vacant** pad (dormant teahouse), a **"Buy S deck & claim — 50 pts"** prompt (key **G**) shows only if you can afford it; triggering it deducts points, claims that pad, and builds a **bare S deck** (no teahouse).
2. **Teahouse then upgrades:** the prompt on your claimed pad offers the next tier; buying **deck:M** live-rebuilds a bigger deck in place; balance deducts.
3. **Gating/affordability:** an unaffordable or out-of-order purchase does nothing (server rejects; prompt/balances unchanged).
4. **Non-owner sees no prompt on occupied pads;** owner sees the upgrade prompt only on their own pad.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/EconomyController.client.luau
git commit -m "feat(roblox): EconomyController walk-up buy/upgrade prompts (B2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

## Notes for the executor

- **Read before editing** `main.server.luau` (Task 7) and `SiteCoordinator.luau` (Task 5): locate anchors by surrounding code, not line number. Confirm the `PadRegistry` instance's local name and the exact `PlayerAdded` block before editing.
- **Single-prompt alternating upgrade (YAGNI for B2):** Task 8's owner prompt alternates deck↔teahouse (buy a teahouse to fill your deck, else upgrade the deck), so BOTH ladders are reachable through one key — do NOT build a multi-item chooser menu (that richer UI is B3's customization work).
- **Do not** commit `SecretsLocal.luau`/`server/.env`. The visual gate needs the branch pushed so the dev App Runner redeploys the new `/economy` + `/purchase` routes (Task 3 is server code — unlike B1's Roblox-only fixes, this DOES need a deploy before the Studio gate can pass).
- Place-only geometry (the built decks/teahouses) persists only when the user saves the place; the economy state persists in Mongo via the routes.
```
