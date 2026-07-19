# Deck Decoration Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a deck owner buy decorative props, ghost-drag them onto their deck, and move/remove them in-world — per-deck persisted, auto-hidden under a larger teahouse.

**Architecture:** Reuses the existing purchase spine (`RequestPurchase` → PWA `/purchase`), the B4 ghost-drag `MoveController` (generalized to move any placement-bearing target), and the `TreatmentApplier` transactional rebuild. A new pure `DecorationLayout.resolve` clamps each prop to the deck and marks props under the built teahouse invisible (stored placement never mutated, exactly like B3's display clamp). Props are non-collidable parts tagged `Decoration` with `id`+`padId` attributes; a client `DecorationController` (mirroring `BackDoorController`) puts owner-only Move/Remove prompts on them via a CollectionService tag watch.

**Tech Stack:** Express + Mongoose + Vitest (server TS); Luau + Rojo + bespoke Lune harness (Roblox); dependency-injected pure modules Lune-tested against real data.

## Global Constraints

- **Catalog propId set is fixed and mirrored across two codebases** (the known TS↔Luau drift caveat): `ishidoro`, `tsukubai`, `bonsai`, `bench`. TS `PRICES.decoration` (authority for the valid-id set + prices) and Luau `DecorationCatalog` (footprints + builders) must carry exactly these four ids.
- **`MAX_DECORATIONS = 24`** per deck. TS `economy.ts` is the enforcing authority; `DecorationCatalog.luau` mirrors the number for client-side cap display only.
- **`id` is server-assigned, monotonic** `max(existing ids) + 1`, starting at `1`; never reused. Buy-per-placement; **no refund on remove**.
- **`facing` ∈ {N,E,S,W}**; `offset` is a 2-element array of finite deck-local studs, each `|n| ≤ MAX_PLACEMENT_OFFSET` (32, already defined in `loadout.ts`).
- **Decoration parts:** every rendered prop is a `Model` named `Decoration`, tagged `Decoration`, with `id` (number) + `padId` (string) attributes, all BaseParts `Anchored=true, CanCollide=false, CanQuery=false, CanTouch=false`.
- **Stored placement is never mutated by rendering.** `DecorationLayout.resolve` returns render data (clamped offset/facing + a `visible` flag); the persisted list is only ever changed by explicit buy/place/remove.
- **The teahouse-move path must stay behavior-equivalent** after `MoveController` is generalized — it becomes one caller of the shared ghost-drag core, not a rewrite.
- **Pure Luau modules** (`DecorationLayout`, and the `footprintBounds` helper, and the pure lookups in `DecorationCatalog`) use no Roblox datatypes and are Lune-tested. Roblox-only code (the `DecorationCatalog` builder, `TreatmentApplier`, controllers, `main.server.luau` wiring) is proven by the visual gate.
- **Tests:** server `cd server && npm test` (Vitest); Roblox `cd roblox && lune run tests/run` (auto-discovers every `*.spec.luau` under `tests/` — no manual registration). Lint Luau with `cd roblox && stylua --check src tests && selene src`.
- **Every commit** ends with the two trailers:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Vf1gZydECjVW7ot94YH3ho
  ```

---

## File structure

**Server (TS):**
- `server/src/economy.ts` — MODIFY: add `PRICES.decoration`, `MAX_DECORATIONS`, `DECORATION_PROPS`, `EconomyState.deckDecorationCount`, `validatePurchase`/`applyPurchase` decoration branch, pure `nextDecorationId`/`appendDecoration`.
- `server/src/loadout.ts` — MODIFY: add `validateDecorations`.
- `server/src/models/User.ts` — MODIFY: add `deckDecorations` field + schema.
- `server/src/routes/apiV1.ts` — MODIFY: `readEconomy` populates `deckDecorationCount`; purchase route decoration branch; `GET /economy` returns `deckDecorations`; new `PUT /players/:id/decorations`.
- `server/src/economy.test.ts`, `server/src/loadout.test.ts` — MODIFY: new tests.

**Roblox pure (Lune-tested):**
- `roblox/src/shared/BuildingPlacer.luau` — MODIFY: add `footprintBounds`.
- `roblox/src/shared/DecorationCatalog.luau` — CREATE: pure lookups + placeholder builder.
- `roblox/src/shared/DecorationLayout.luau` — CREATE: `resolve`.
- `roblox/src/shared/TeahouseMenuModel.luau` — MODIFY: add `decorations` buyables to the view-model.
- `roblox/tests/BuildingPlacer.spec.luau`, `roblox/tests/DecorationCatalog.spec.luau`, `roblox/tests/DecorationLayout.spec.luau`, `roblox/tests/TeahouseMenuModel.spec.luau` — CREATE/MODIFY.

**Roblox runtime (visual-gate-proven):**
- `roblox/default.project.json` — MODIFY: 3 new RemoteEvents.
- `roblox/src/server/NetworkClient.luau` — MODIFY: `setDecorations`.
- `roblox/src/server/TreatmentApplier.luau` — MODIFY: decoration build step + `_buildBuilding` returns its placement.
- `roblox/src/server/main.server.luau` — MODIFY: stash + thread `deckDecorations`, echo it, `SetDecorationPlacement`/`SetDecorationRemove` handlers, `DecorationPlaced` fire, applier deps.
- `roblox/src/client/EventBus.luau` — MODIFY: add `MoveDecoration`.
- `roblox/src/client/MoveController.client.luau` — MODIFY: generalize to a descriptor-driven core + a decoration entry.
- `roblox/src/client/DecorationController.client.luau` — CREATE.
- `roblox/src/client/TeahouseController.client.luau` — MODIFY: Decorations catalog section.

---

## Task 1: Economy — decoration pricing, cap, validation, id authority

**Files:**
- Modify: `server/src/economy.ts`
- Test: `server/src/economy.test.ts`

**Interfaces:**
- Consumes: existing `PRICES`, `EconomyState`, `validatePurchase`, `applyPurchase`.
- Produces:
  - `PRICES.decoration: { ishidoro: number; tsukubai: number; bonsai: number; bench: number }`
  - `MAX_DECORATIONS: number` (= 24)
  - `DECORATION_PROPS: Set<string>` (the 4 propIds)
  - `EconomyState` gains optional `deckDecorationCount?: number`
  - `type DeckDecoration = { id: number; propId: string; offset: [number, number]; facing: 'N'|'E'|'S'|'W' }`
  - `nextDecorationId(decorations: DeckDecoration[]): number`
  - `appendDecoration(decorations: DeckDecoration[], propId: string): { list: DeckDecoration[]; instance: DeckDecoration }`
  - `validatePurchase(state, 'decoration:<propId>')` supported.

- [ ] **Step 1: Write the failing tests**

Add to `server/src/economy.test.ts` (extend the existing import line to include the new symbols):

```typescript
import {
  validatePurchase, applyPurchase, PRICES, EconomyState, validateDisplay,
  MAX_DECORATIONS, DECORATION_PROPS, nextDecorationId, appendDecoration, DeckDecoration,
} from './economy';

describe('validatePurchase — decorations', () => {
    it('rejects a decoration when no deck is owned', () => {
        expect(validatePurchase(fresh(), 'decoration:bonsai')).toEqual({ ok: false, error: 'NEEDS_DECK' });
    });
    it('accepts a known decoration on a claimed deck and charges its price', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'decoration:bonsai'))
            .toEqual({ ok: true, cost: PRICES.decoration.bonsai });
    });
    it('rejects an unknown propId', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S' }), 'decoration:dragon'))
            .toEqual({ ok: false, error: 'BAD_ITEM' });
    });
    it('rejects at the decoration cap', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S', deckDecorationCount: MAX_DECORATIONS }), 'decoration:bench'))
            .toEqual({ ok: false, error: 'DECOR_CAP' });
    });
    it('rejects when unaffordable', () => {
        expect(validatePurchase(fresh({ maxDeckSize: 'S', totalPoints: 0 }), 'decoration:tsukubai'))
            .toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
    });
    it('DECORATION_PROPS holds exactly the four launch props', () => {
        expect([...DECORATION_PROPS].sort()).toEqual(['bench', 'bonsai', 'ishidoro', 'tsukubai']);
    });
});

describe('applyPurchase — decorations charge points only', () => {
    it('deducts the price and leaves tiers untouched', () => {
        const s = applyPurchase(fresh({ totalPoints: 1000, maxDeckSize: 'S' }), 'decoration:ishidoro');
        expect(s.totalPoints).toBe(1000 - PRICES.decoration.ishidoro);
        expect(s.maxDeckSize).toBe('S');
        expect(s.teahouseSizes).toEqual([]);
    });
});

describe('decoration id authority', () => {
    it('nextDecorationId starts at 1 on an empty list', () => {
        expect(nextDecorationId([])).toBe(1);
    });
    it('nextDecorationId is max(id)+1, robust to gaps', () => {
        const list: DeckDecoration[] = [
            { id: 3, propId: 'bench', offset: [0, 0], facing: 'N' },
            { id: 7, propId: 'bonsai', offset: [1, 2], facing: 'E' },
        ];
        expect(nextDecorationId(list)).toBe(8);
    });
    it('appendDecoration appends a centered N instance with the next id, without mutating input', () => {
        const list: DeckDecoration[] = [{ id: 5, propId: 'bench', offset: [1, 1], facing: 'S' }];
        const { list: next, instance } = appendDecoration(list, 'bonsai');
        expect(instance).toEqual({ id: 6, propId: 'bonsai', offset: [0, 0], facing: 'N' });
        expect(next).toHaveLength(2);
        expect(list).toHaveLength(1); // input untouched
    });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: FAIL — `MAX_DECORATIONS`/`nextDecorationId`/etc. are not exported.

- [ ] **Step 3: Implement in `server/src/economy.ts`**

Add the constants and types near the top (after `PRICES`):

```typescript
export const PRICES = {
    deck: { S: 50, M: 500, L: 3000 },
    teahouse: { S: 30, M: 300, L: 2000 },
    portal: 500,
    decoration: { ishidoro: 40, tsukubai: 60, bonsai: 25, bench: 35 },
} as const;
export const DEFAULT_TEAHOUSE_LOADOUT = { baseStyle: 'teahouse-1story' };

export const MAX_DECORATIONS = 24;
export const DECORATION_PROPS: Set<string> = new Set(Object.keys(PRICES.decoration));

export type DeckDecoration = { id: number; propId: string; offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' };

export function nextDecorationId(decorations: DeckDecoration[]): number {
    return decorations.reduce((m, d) => Math.max(m, d.id), 0) + 1;
}

export function appendDecoration(
    decorations: DeckDecoration[],
    propId: string,
): { list: DeckDecoration[]; instance: DeckDecoration } {
    const instance: DeckDecoration = { id: nextDecorationId(decorations), propId, offset: [0, 0], facing: 'N' };
    return { list: [...decorations, instance], instance };
}
```

Add `deckDecorationCount` to the `EconomyState` type:

```typescript
export type EconomyState = { totalPoints: number; maxDeckSize: Size | null; teahouseSizes: Size[]; portalOwned?: boolean; deckDecorationCount?: number };
```

In `validatePurchase`, add the decoration branch immediately after the `portal` branch (before the `deck`/`teahouse` split):

```typescript
    if (item.startsWith('decoration:')) {
        const propId = item.slice('decoration:'.length);
        if (state.maxDeckSize === null) return { ok: false, error: 'NEEDS_DECK' };
        if (!DECORATION_PROPS.has(propId)) return { ok: false, error: 'BAD_ITEM' };
        if ((state.deckDecorationCount ?? 0) >= MAX_DECORATIONS) return { ok: false, error: 'DECOR_CAP' };
        const cost = (PRICES.decoration as Record<string, number>)[propId];
        if (state.totalPoints < cost) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost };
    }
```

In `applyPurchase`, after the `portal` early-return, add the decoration early-return (charges points only — decorations live in `user.deckDecorations`, not `EconomyState`):

```typescript
    if (item === 'portal') {
        next.portalOwned = true;
        return next;
    }
    if (item.startsWith('decoration:')) {
        return next; // cost already deducted above; decoration list is tracked outside EconomyState
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: PASS (all new + existing economy tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/economy.ts server/src/economy.test.ts
git commit -m "feat(server): decoration pricing, cap, purchase validation + id authority"
```

---

## Task 2: `validateDecorations` payload validator

**Files:**
- Modify: `server/src/loadout.ts`
- Test: `server/src/loadout.test.ts`

**Interfaces:**
- Consumes: `DECORATION_PROPS`, `MAX_DECORATIONS` from `./economy`; `PLACEMENT_FACINGS`, `MAX_PLACEMENT_OFFSET` already in `loadout.ts`.
- Produces: `validateDecorations(value: unknown): { ok: true } | { ok: false; error: string }`.

- [ ] **Step 1: Write the failing tests**

Add to `server/src/loadout.test.ts` (import `validateDecorations` alongside the existing imports):

```typescript
import { validateDecorations } from './loadout';

describe('validateDecorations', () => {
    const ok = (extra: unknown[] = []) => [
        { id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N' },
        { id: 2, propId: 'bench', offset: [3, -4], facing: 'E' },
        ...extra,
    ];
    it('accepts a well-formed list', () => {
        expect(validateDecorations(ok())).toEqual({ ok: true });
    });
    it('accepts an empty list', () => {
        expect(validateDecorations([])).toEqual({ ok: true });
    });
    it('rejects a non-array', () => {
        expect(validateDecorations({})).toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects an unknown propId', () => {
        expect(validateDecorations([{ id: 1, propId: 'dragon', offset: [0, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects a bad facing', () => {
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [0, 0], facing: 'X' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects a non-finite / out-of-range offset', () => {
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [999, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects a non-integer / non-positive id', () => {
        expect(validateDecorations([{ id: 0, propId: 'bonsai', offset: [0, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
        expect(validateDecorations([{ id: 1.5, propId: 'bonsai', offset: [0, 0], facing: 'N' }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects duplicate ids', () => {
        expect(validateDecorations([
            { id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N' },
            { id: 1, propId: 'bench', offset: [0, 0], facing: 'N' },
        ])).toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects an extra key on an entry', () => {
        expect(validateDecorations([{ id: 1, propId: 'bonsai', offset: [0, 0], facing: 'N', evil: 1 }]))
            .toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
    it('rejects over the cap', () => {
        const many = Array.from({ length: 25 }, (_, i) => ({ id: i + 1, propId: 'bonsai', offset: [0, 0], facing: 'N' }));
        expect(validateDecorations(many)).toEqual({ ok: false, error: 'BAD_DECORATION' });
    });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: FAIL — `validateDecorations` is not exported.

- [ ] **Step 3: Implement in `server/src/loadout.ts`**

Add the import at the top:

```typescript
import { DECORATION_PROPS, MAX_DECORATIONS } from './economy';
```

Add the validator (near `validatePlacement`, reusing `PLACEMENT_FACINGS` + `MAX_PLACEMENT_OFFSET`):

```typescript
export function validateDecorations(value: unknown): Check {
    if (!Array.isArray(value)) return { ok: false, error: 'BAD_DECORATION' };
    if (value.length > MAX_DECORATIONS) return { ok: false, error: 'BAD_DECORATION' };
    const seen = new Set<number>();
    for (const entry of value) {
        if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        const obj = entry as Record<string, unknown>;
        for (const k of Object.keys(obj)) {
            if (k !== 'id' && k !== 'propId' && k !== 'offset' && k !== 'facing') {
                return { ok: false, error: 'BAD_DECORATION' };
            }
        }
        if (typeof obj.id !== 'number' || !Number.isInteger(obj.id) || obj.id < 1 || seen.has(obj.id)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        seen.add(obj.id);
        if (typeof obj.propId !== 'string' || !DECORATION_PROPS.has(obj.propId)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        if (!Array.isArray(obj.offset) || obj.offset.length !== 2) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
        for (const n of obj.offset) {
            if (typeof n !== 'number' || !Number.isFinite(n) || Math.abs(n) > MAX_PLACEMENT_OFFSET) {
                return { ok: false, error: 'BAD_DECORATION' };
            }
        }
        if (typeof obj.facing !== 'string' || !PLACEMENT_FACINGS.has(obj.facing)) {
            return { ok: false, error: 'BAD_DECORATION' };
        }
    }
    return { ok: true };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/loadout.ts server/src/loadout.test.ts
git commit -m "feat(server): validateDecorations payload validator"
```

---

## Task 3: User schema + apiV1 decoration routes

**Files:**
- Modify: `server/src/models/User.ts`
- Modify: `server/src/routes/apiV1.ts`

**Interfaces:**
- Consumes: Task 1 (`appendDecoration`, `DeckDecoration`, `DECORATION_PROPS`, `MAX_DECORATIONS`), Task 2 (`validateDecorations`).
- Produces: `user.deckDecorations` persistence; `readEconomy` populates `deckDecorationCount`; purchase route handles `decoration:<propId>`; `GET /economy` returns `deckDecorations`; `PUT /players/:robloxUserId/decorations`.

> **Note on tests:** the repo has no route-level test suite (only pure-function Vitest specs). This task's correctness rests on Tasks 1–2's unit tests plus a clean `tsc` build and the visual gate. Do **not** invent a route test framework; verify with the build command in Step 4.

- [ ] **Step 1: Add the schema field in `server/src/models/User.ts`**

Add to the `IUser` interface (near `portalOwned`):

```typescript
    portalOwned: boolean;
    deckDecorations: { id: number; propId: string; offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' }[];
    updatedAt: Date;
```

Add to the schema (after `portalOwned`):

```typescript
    portalOwned: { type: Boolean, default: false },
    deckDecorations: { type: [Schema.Types.Mixed], default: [] },
```

- [ ] **Step 2: Wire the routes in `server/src/routes/apiV1.ts`**

Extend the economy import:

```typescript
import {
    validatePurchase, applyPurchase, validateDisplay, PRICES, DEFAULT_TEAHOUSE_LOADOUT,
    Size, EconomyState, appendDecoration,
} from '../economy';
import { validateLoadout, validateSizeClass, validatePadPreferences, validateDecorations } from '../loadout';
```

Update `readEconomy` to populate `deckDecorationCount` (add the field + widen the param type):

```typescript
    const readEconomy = (user: { totalPoints: number; maxDeckSize: Size | null; teahouses?: Map<string, unknown>; portalOwned?: boolean; deckDecorations?: unknown[] }): EconomyState => ({
        totalPoints: user.totalPoints,
        maxDeckSize: user.maxDeckSize,
        teahouseSizes: (user.teahouses ? Array.from(user.teahouses.keys()) : []) as Size[],
        portalOwned: user.portalOwned ?? false,
        deckDecorationCount: user.deckDecorations?.length ?? 0,
    });
```

In `GET /players/:robloxUserId/economy`, add `deckDecorations` to the response object (the `catalog: PRICES` already carries `decoration`):

```typescript
                catalog: PRICES,
                deckDisplay: user.deckDisplay ?? null,
                teahouseDisplay: user.teahouseDisplay ?? null,
                portalOwned: st.portalOwned ?? false,
                deckDecorations: user.deckDecorations ?? [],
```

In `POST /players/:robloxUserId/purchase`, insert the decoration branch right after the three `user.totalPoints/maxDeckSize/portalOwned` assignments and before the `const [kind, size] = ...` teahouse line:

```typescript
            user.totalPoints = after.totalPoints;
            user.maxDeckSize = after.maxDeckSize;
            user.portalOwned = after.portalOwned ?? false;
            if (item.startsWith('decoration:')) {
                const propId = item.slice('decoration:'.length);
                const { list, instance } = appendDecoration(user.deckDecorations ?? [], propId);
                user.deckDecorations = list;
                await user.save();
                res.json({ item, totalPoints: after.totalPoints, decoration: instance, deckDecorations: list });
                return;
            }
            const [kind, size] = item.split(':') as [string, Size];
```

Add the new PUT route (next to the existing `PUT .../preferences` route):

```typescript
    router.put('/players/:robloxUserId/decorations', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const decorations = req.body?.decorations;
            const check = validateDecorations(decorations);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.deckDecorations = decorations;
            await user.save();
            res.json({ deckDecorations: user.deckDecorations });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 3: Run the existing suite (nothing should regress)**

Run: `cd server && npm test`
Expected: PASS (all existing + Task 1/2 tests).

- [ ] **Step 4: Verify the build type-checks**

Run: `cd server && npm run build`
Expected: `tsc` completes with no errors.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/User.ts server/src/routes/apiV1.ts
git commit -m "feat(server): persist deckDecorations, purchase branch + PUT /decorations route"
```

---

## Task 4: `BuildingPlacer.footprintBounds` (rotation-aware deck-local AABB)

**Files:**
- Modify: `roblox/src/shared/BuildingPlacer.luau`
- Test: `roblox/tests/BuildingPlacer.spec.luau`

**Interfaces:**
- Consumes: existing `BuildingPlacer.facingYaw`.
- Produces: `BuildingPlacer.footprintBounds(fp: FP, p: Placement): FP` — the deck-local axis-aligned bounds of a centered footprint `fp` placed at `p.offset` with `p.facing` (90/270 swap the half-extents). `FP = {minX,maxX,minZ,maxZ}`.

- [ ] **Step 1: Write the failing tests**

Add to `roblox/tests/BuildingPlacer.spec.luau`:

```lua
describe("BuildingPlacer.footprintBounds", function()
    local B = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 } -- 12 x 6, centered
    test("facing N centers the AABB at the offset with the base half-extents", function()
        local b = BuildingPlacer.footprintBounds(B, { offset = { 2, -4 }, facing = "N" })
        expect(b.minX).toBeCloseTo(-4)
        expect(b.maxX).toBeCloseTo(8)
        expect(b.minZ).toBeCloseTo(-7)
        expect(b.maxZ).toBeCloseTo(-1)
    end)
    test("facing E swaps the half-extents (halfX<->halfZ)", function()
        local b = BuildingPlacer.footprintBounds(B, { offset = { 0, 0 }, facing = "E" })
        expect(b.minX).toBeCloseTo(-3)
        expect(b.maxX).toBeCloseTo(3)
        expect(b.minZ).toBeCloseTo(-6)
        expect(b.maxZ).toBeCloseTo(6)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `footprintBounds` is nil.

- [ ] **Step 3: Implement in `roblox/src/shared/BuildingPlacer.luau`**

Add before `return BuildingPlacer`:

```lua
-- Deck-local axis-aligned bounds of a centered footprint placed at p.offset with p.facing.
-- 90/270 swap the half-extents (rotation-aware), matching fits()/clamp(). Used to test
-- decoration-vs-teahouse overlap and to clamp decorations to the deck.
function BuildingPlacer.footprintBounds(fp: FP, p: Placement): FP
    local halfX = (fp.maxX - fp.minX) / 2
    local halfZ = (fp.maxZ - fp.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(p.facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    local dx, dz = p.offset[1], p.offset[2]
    return { minX = dx - halfX, maxX = dx + halfX, minZ = dz - halfZ, maxZ = dz + halfZ }
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/BuildingPlacer.luau roblox/tests/BuildingPlacer.spec.luau
git commit -m "feat(roblox): BuildingPlacer.footprintBounds rotation-aware AABB"
```

---

## Task 5: `DecorationCatalog.luau` — pure lookups + placeholder builder

**Files:**
- Create: `roblox/src/shared/DecorationCatalog.luau`
- Test: `roblox/tests/DecorationCatalog.spec.luau`

**Interfaces:**
- Produces:
  - `DecorationCatalog.MAX_DECORATIONS: number` (= 24, mirrors TS)
  - `DecorationCatalog.ids(): { string }` — the four propIds in a stable order
  - `DecorationCatalog.has(propId): boolean`
  - `DecorationCatalog.footprint(propId): Footprint?` — centered `{minX,maxX,minZ,maxZ}`, nil for unknown
  - `DecorationCatalog.build(propId): Model?` — Roblox-only placeholder Model with `PrimaryPart`, nil for unknown (never called under Lune)

- [ ] **Step 1: Write the failing tests** (pure lookups only; the builder is Roblox-only)

Create `roblox/tests/DecorationCatalog.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local DecorationCatalog = require("../src/shared/DecorationCatalog")

describe("DecorationCatalog", function()
    test("ids are exactly the four launch props", function()
        local ids = DecorationCatalog.ids()
        table.sort(ids)
        expect(ids).toEqual({ "bench", "bonsai", "ishidoro", "tsukubai" })
    end)
    test("has() distinguishes known from unknown", function()
        expect(DecorationCatalog.has("bonsai")).toBe(true)
        expect(DecorationCatalog.has("dragon")).toBe(false)
    end)
    test("footprint returns a centered box for a known prop", function()
        local fp = DecorationCatalog.footprint("bench")
        expect(fp).toBeTruthy()
        expect((fp :: any).minX).toBe(-(fp :: any).maxX)
        expect((fp :: any).minZ).toBe(-(fp :: any).maxZ)
    end)
    test("footprint is nil for an unknown prop", function()
        expect(DecorationCatalog.footprint("dragon")).toBeNil()
    end)
    test("MAX_DECORATIONS mirrors the server cap", function()
        expect(DecorationCatalog.MAX_DECORATIONS).toBe(24)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `roblox/src/shared/DecorationCatalog.luau`**

```lua
--!strict
-- The decoration catalog for the deck-decoration framework (2026-07-19). Pure lookups
-- (footprint/has/ids, Lune-tested) plus a Roblox-only placeholder builder (never called under
-- Lune — it only references Instance/Vector3/Color3 inside build()). The propId set MUST mirror
-- server/src/economy.ts PRICES.decoration (the TS<->Luau drift caveat): prices live TS-side, the
-- footprint + geometry live here. All footprints are centered on the prop origin.
local DecorationCatalog = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

-- mirrors server MAX_DECORATIONS (economy.ts); used only for client-side cap display
DecorationCatalog.MAX_DECORATIONS = 24

-- stable render/order list of propIds
local ORDER = { "ishidoro", "tsukubai", "bonsai", "bench" }

-- centered footprints (studs). Distinct per prop so the four read as different objects.
local FOOTPRINTS: { [string]: Footprint } = {
    ishidoro = { minX = -1, maxX = 1, minZ = -1, maxZ = 1 }, -- stone lantern ~2x2
    tsukubai = { minX = -1.5, maxX = 1.5, minZ = -1.5, maxZ = 1.5 }, -- water basin ~3x3
    bonsai = { minX = -0.75, maxX = 0.75, minZ = -0.75, maxZ = 0.75 }, -- potted plant ~1.5x1.5
    bench = { minX = -2, maxX = 2, minZ = -0.75, maxZ = 0.75 }, -- wooden bench ~4x1.5
}

function DecorationCatalog.ids(): { string }
    return table.clone(ORDER)
end

function DecorationCatalog.has(propId: string): boolean
    return FOOTPRINTS[propId] ~= nil
end

function DecorationCatalog.footprint(propId: string): Footprint?
    return FOOTPRINTS[propId]
end

-- ===== Roblox-only placeholder geometry (art pass later) =====
-- Each builder returns a Model with PrimaryPart set; the caller pivots, tags, and parents it.
-- Parts are anchored + fully non-interactive (the framework overlays its own prompts on the Model).
local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    return p
end

local STONE = Color3.fromRGB(150, 148, 140)
local WOOD = Color3.fromRGB(120, 82, 48)
local WATER = Color3.fromRGB(90, 130, 150)
local LEAF = Color3.fromRGB(70, 120, 60)

local BUILDERS: { [string]: () -> Model } = {}

BUILDERS.ishidoro = function(): Model
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local base = part("Base", Vector3.new(1.4, 0.6, 1.4), STONE, Enum.Material.Slate)
    base.CFrame = CFrame.new(0, 0.3, 0)
    base.Parent = m
    local shaft = part("Shaft", Vector3.new(0.5, 1.4, 0.5), STONE, Enum.Material.Slate)
    shaft.CFrame = CFrame.new(0, 1.3, 0)
    shaft.Parent = m
    local head = part("Head", Vector3.new(1.2, 0.8, 1.2), STONE, Enum.Material.Slate)
    head.CFrame = CFrame.new(0, 2.4, 0)
    head.Parent = m
    m.PrimaryPart = shaft
    return m
end

BUILDERS.tsukubai = function(): Model
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local basin = part("Basin", Vector3.new(2.6, 1.0, 2.6), STONE, Enum.Material.Slate)
    basin.Shape = Enum.PartType.Cylinder
    basin.CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90))
    basin.Parent = m
    local water = part("Water", Vector3.new(0.2, 2.0, 2.0), WATER, Enum.Material.Glass)
    water.Shape = Enum.PartType.Cylinder
    water.Transparency = 0.3
    water.CFrame = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(90))
    water.Parent = m
    m.PrimaryPart = basin
    return m
end

BUILDERS.bonsai = function(): Model
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local pot = part("Pot", Vector3.new(1.1, 0.7, 1.1), WOOD, Enum.Material.WoodPlanks)
    pot.CFrame = CFrame.new(0, 0.35, 0)
    pot.Parent = m
    local foliage = part("Foliage", Vector3.new(1.3, 1.1, 1.3), LEAF, Enum.Material.Grass)
    foliage.Shape = Enum.PartType.Ball
    foliage.CFrame = CFrame.new(0, 1.3, 0)
    foliage.Parent = m
    m.PrimaryPart = pot
    return m
end

BUILDERS.bench = function(): Model
    local m = Instance.new("Model")
    m.Name = "Decoration"
    local seat = part("Seat", Vector3.new(4.0, 0.3, 1.4), WOOD, Enum.Material.WoodPlanks)
    seat.CFrame = CFrame.new(0, 1.0, 0)
    seat.Parent = m
    for _, x in { -1.6, 1.6 } do
        local leg = part("Leg", Vector3.new(0.3, 1.0, 1.2), WOOD, Enum.Material.WoodPlanks)
        leg.CFrame = CFrame.new(x, 0.5, 0)
        leg.Parent = m
    end
    m.PrimaryPart = seat
    return m
end

function DecorationCatalog.build(propId: string): Model?
    local builder = BUILDERS[propId]
    if builder == nil then
        return nil
    end
    return builder()
end

return DecorationCatalog
```

- [ ] **Step 4: Run to verify it passes + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/DecorationCatalog.luau roblox/tests/DecorationCatalog.spec.luau
git commit -m "feat(roblox): DecorationCatalog pure lookups + placeholder builders"
```

---

## Task 6: `DecorationLayout.resolve` — clamp-to-deck + auto-hide

**Files:**
- Create: `roblox/src/shared/DecorationLayout.luau`
- Test: `roblox/tests/DecorationLayout.spec.luau`

**Interfaces:**
- Consumes: `BuildingPlacer.clamp` + `BuildingPlacer.footprintBounds` (Task 4); `DecorationCatalog.footprint`/`has` (Task 5).
- Produces: `DecorationLayout.resolve(deckFP, teahouseFP, decorations) -> { { id, propId, offset, facing, visible } }` — an ordered list preserving input order. `deckFP`/`teahouseFP` are `{minX,maxX,minZ,maxZ}` (`teahouseFP` may be `nil` = bare deck). `decorations` is a list of `{ id, propId, offset = {x,z}, facing }`. Each output carries the **clamped** offset/facing and `visible=false` when the clamped rotation-aware footprint overlaps `teahouseFP` (edge-touch is NOT overlap → visible). Unknown propIds are skipped. Stored input is never mutated.

- [ ] **Step 1: Write the failing tests**

Create `roblox/tests/DecorationLayout.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local DecorationLayout = require("../src/shared/DecorationLayout")

-- deck 26 x 20 (SizeClasses S-deck shape)
local DECK = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 }

describe("DecorationLayout.resolve", function()
    test("bare deck (nil teahouseFP): everything visible, order preserved", function()
        local out = DecorationLayout.resolve(DECK, nil, {
            { id = 1, propId = "bonsai", offset = { 0, 0 }, facing = "N" },
            { id = 2, propId = "bench", offset = { 4, 4 }, facing = "N" },
        })
        expect(#out).toBe(2)
        expect(out[1].id).toBe(1)
        expect(out[1].visible).toBe(true)
        expect(out[2].id).toBe(2)
        expect(out[2].visible).toBe(true)
    end)

    test("clamps an off-deck offset back onto the deck (stored input untouched)", function()
        local input = { { id = 1, propId = "bonsai", offset = { 99, 0 }, facing = "N" } }
        local out = DecorationLayout.resolve(DECK, nil, input)
        -- bonsai half 0.75; x max legal = 13 - 0.75 = 12.25
        expect(out[1].offset[1]).toBeCloseTo(12.25)
        expect(input[1].offset[1]).toBe(99) -- input not mutated
    end)

    test("a prop under the teahouse footprint is hidden; one clear of it stays visible", function()
        local teahouseFP = { minX = -6, maxX = 6, minZ = -4, maxZ = 4 }
        local out = DecorationLayout.resolve(DECK, teahouseFP, {
            { id = 1, propId = "bonsai", offset = { 0, 0 }, facing = "N" }, -- inside -> hidden
            { id = 2, propId = "bonsai", offset = { 10, 0 }, facing = "N" }, -- clear -> visible
        })
        expect(out[1].visible).toBe(false)
        expect(out[2].visible).toBe(true)
    end)

    test("edge-touch is NOT overlap (visible)", function()
        -- bonsai half 0.75 at x=6.75 spans [6.0, 7.5]; teahouse maxX=6 -> touch at x=6, no overlap
        local teahouseFP = { minX = -6, maxX = 6, minZ = -4, maxZ = 4 }
        local out = DecorationLayout.resolve(DECK, teahouseFP, {
            { id = 1, propId = "bonsai", offset = { 6.75, 0 }, facing = "N" },
        })
        expect(out[1].visible).toBe(true)
    end)

    test("rotation is honored in the overlap test (bench facing E is deep, not wide)", function()
        -- bench 4x1.5 (half 2 x 0.75). Facing E swaps -> half 0.75 x 2, spanning z in [-2,2].
        -- teahouse occupies z in [-4,4]; a bench at (10, 3) facing E spans z [1,5], x [9.25,10.75].
        -- teahouse spans x [-6,6] so no x-overlap -> visible regardless of z.
        local teahouseFP = { minX = -6, maxX = 6, minZ = -4, maxZ = 4 }
        local out = DecorationLayout.resolve(DECK, teahouseFP, {
            { id = 1, propId = "bench", offset = { 10, 3 }, facing = "E" },
        })
        expect(out[1].visible).toBe(true)
    end)

    test("unknown propIds are skipped", function()
        local out = DecorationLayout.resolve(DECK, nil, {
            { id = 1, propId = "dragon", offset = { 0, 0 }, facing = "N" },
            { id = 2, propId = "bench", offset = { 0, 0 }, facing = "N" },
        })
        expect(#out).toBe(1)
        expect(out[1].id).toBe(2)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `roblox/src/shared/DecorationLayout.luau`**

```lua
--!strict
-- Pure decoration render resolver (2026-07-19 deck-decoration framework). Given the deck bounds,
-- the built teahouse's deck-local AABB (nil for a bare deck), and the stored decoration list,
-- returns per-prop render data: each clamped onto the deck, and marked invisible when it would sit
-- under the built teahouse. Mirrors B3's display-clamp philosophy — the STORED placement is never
-- changed; only what renders adapts. Lune-tested; no Roblox datatypes.
local BuildingPlacer = require("./BuildingPlacer")
local DecorationCatalog = require("./DecorationCatalog")

local DecorationLayout = {}

export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }

-- AABB overlap with edge-touch treated as NON-overlap (strict inequalities): a prop whose footprint
-- merely touches the teahouse edge stays visible.
local function overlaps(a: Bounds, b: Bounds): boolean
    return a.minX < b.maxX and a.maxX > b.minX and a.minZ < b.maxZ and a.maxZ > b.minZ
end

function DecorationLayout.resolve(deckFP: Bounds, teahouseFP: Bounds?, decorations: { any }): { any }
    local out = {}
    for _, d in decorations do
        local fp = DecorationCatalog.footprint(d.propId)
        if fp == nil then
            continue -- unknown propId (shouldn't survive validation): skip, never crash
        end
        local clamped = BuildingPlacer.clamp(fp, deckFP, { offset = d.offset, facing = d.facing })
        local bounds = BuildingPlacer.footprintBounds(fp, clamped)
        local visible = true
        if teahouseFP ~= nil and overlaps(bounds, teahouseFP) then
            visible = false
        end
        table.insert(out, {
            id = d.id,
            propId = d.propId,
            offset = clamped.offset,
            facing = clamped.facing,
            visible = visible,
        })
    end
    return out
end

return DecorationLayout
```

- [ ] **Step 4: Run to verify it passes + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/DecorationLayout.luau roblox/tests/DecorationLayout.spec.luau
git commit -m "feat(roblox): DecorationLayout.resolve clamp-to-deck + auto-hide"
```

---

## Task 7: `TreatmentApplier` — build visible decorations

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau`
- Modify: `roblox/src/server/main.server.luau` (inject the two new applier deps only)

**Interfaces:**
- Consumes: `DecorationLayout.resolve` (Task 6), `DecorationCatalog.build`/`footprint` (Task 5), `BuildingPlacer.footprintBounds`/`placeCF` (Task 4 + existing), `SizeClasses.deckFootprint`/`buildingFootprint` (existing).
- Produces: after building deck + teahouse, when `treatment.lit == true` and `treatment.deckDecorations` is non-empty, builds every **visible** prop tagged `Decoration` with `id`+`padId`. `_buildBuilding` now **returns** the `Placement` it used (or `nil` if deck-only) so `apply` can compute the teahouse's deck-local AABB.

- [ ] **Step 1: Make `_buildBuilding` return its placement**

In `roblox/src/server/TreatmentApplier.luau`, change `_buildBuilding` so every early skip returns `nil` and the success path returns `placement`. Specifically:

- The two `warn(...) ; return` skip paths become `warn(...) ; return nil`.
- Add `return placement` as the final line of the function (after `model.Parent = staging` and the `ModelStreamingMode` block).

```lua
        if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
            warn(
                `[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`
            )
            return nil
        end
    end
    -- world pivot = deck CFrame composed with the local placement transform (offset + facing)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    local placedCF = deckCF * CFrame.new(table.unpack(self._buildingPlacer.placeCF(placement)))
    local mount = { cframe = { placedCF:GetComponents() }, footprint = buildingFP }
    local prefabName = self._sizeClasses.prefabName(teahouse.loadout.baseStyle, teahouse.size)
    local model = self._structureBuilder.build(
        teahouse.loadout,
        mount,
        self._catalog,
        self._structureOps,
        prefabName
    ) :: Model
    model.Name = "Structure"
    if not treatment.lit then
        shutter(model)
    end
    model.Parent = staging
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
    return placement
```

- [ ] **Step 2: Add the deps to `Deps` + the constructor**

In the `Deps` type and `TreatmentApplier.new`, add `decorationLayout` and `decorationCatalog`:

```lua
    deckPlacement: any, -- pure per-size deck-pivot lookup (DeckPlacement)
    decorationLayout: any, -- pure DecorationLayout.resolve
    decorationCatalog: any, -- DecorationCatalog (footprint pure; build is Roblox-only)
}
```

```lua
        _deckPlacement = deps.deckPlacement,
        _decorationLayout = deps.decorationLayout,
        _decorationCatalog = deps.decorationCatalog,
        _folders = {} :: { [string]: Folder },
```

- [ ] **Step 3: Add the `_buildDecorations` method**

Add after `_buildPortalControl`:

```lua
-- Build the owner's visible deck decorations onto the staged deck. teahouseFP is the built
-- teahouse's deck-local AABB (nil for a bare deck) — DecorationLayout hides props under it. Each
-- prop is a non-collidable Model tagged Decoration with id + padId attributes; DecorationController
-- (client) puts owner-only Move/Remove prompts on them. May throw on bad build data; fault-isolated
-- by the caller (a bad prop must never blank the deck).
function TreatmentApplier:_buildDecorations(
    padId: string,
    deckCF12: { number },
    deckSize: string,
    teahouseFP: any,
    decorations: { any },
    staging: Instance
)
    local deckFP = self._sizeClasses.deckFootprint(deckSize)
    local resolved = self._decorationLayout.resolve(deckFP, teahouseFP, decorations)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    for _, r in resolved do
        if not r.visible then
            continue
        end
        local model = self._decorationCatalog.build(r.propId)
        if model == nil then
            continue
        end
        local placeCF = self._buildingPlacer.placeCF({ offset = r.offset, facing = r.facing })
        model:PivotTo(deckCF * CFrame.new(table.unpack(placeCF)))
        model.Name = "Decoration"
        model:SetAttribute("id", r.id)
        model:SetAttribute("padId", padId)
        model:AddTag("Decoration")
        model.Parent = staging
    end
end
```

- [ ] **Step 4: Call it from `apply`, capturing the teahouse placement**

In `apply`, replace the building step block (the `if teahouse ~= nil and teahouse.loadout ~= nil then ... end`) so it captures the returned placement, then add the decoration step **before** the `if treatment.portalOwned` block:

```lua
    -- build a building only when there's one to build; a nil teahouse or nil loadout is a
    -- bare deck (Piece-B: owns a deck but no teahouse) — the deck stands alone.
    local builtPlacement: any = nil
    if teahouse ~= nil and teahouse.loadout ~= nil then
        local okBuilding, placementOrErr = pcall(function()
            return self:_buildBuilding(padId, deckCF12, treatment, teahouse, deckSize, staging)
        end)
        if okBuilding then
            builtPlacement = placementOrErr
        else
            warn(`[D.6] building step failed for {padId}: {placementOrErr}; deck only`)
        end
    end
    -- decorations: owner's placed props, hidden under the built teahouse. teahouseFP is the built
    -- teahouse's deck-local AABB (nil when deck-only). Fault-isolated: a bad prop never blanks the deck.
    local decorations = treatment.deckDecorations
    if treatment.lit == true and decorations ~= nil and #decorations > 0 then
        local teahouseFP: any = nil
        if builtPlacement ~= nil and teahouse ~= nil then
            local buildingFP = self._sizeClasses.buildingFootprint(teahouse.size)
            teahouseFP = self._buildingPlacer.footprintBounds(buildingFP, builtPlacement)
        end
        local okDecor, decorErr = pcall(function()
            self:_buildDecorations(padId, deckCF12, deckSize, teahouseFP, decorations, staging)
        end)
        if not okDecor then
            warn(`[DECOR] decoration step failed for {padId}: {decorErr}; deck without props`)
        end
    end
    if treatment.portalOwned == true and treatment.lit == true then
```

- [ ] **Step 5: Inject the deps in `main.server.luau`**

Add the requires (near the other `shared` requires, after `DeckPlacement`):

```lua
local DeckPlacement = require(shared:WaitForChild("DeckPlacement"))
local DecorationLayout = require(shared:WaitForChild("DecorationLayout"))
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))
```

Add them to the `TreatmentApplier.new({ ... })` call:

```lua
    sizeClasses = SizeClasses,
    deckPlacement = DeckPlacement,
    decorationLayout = DecorationLayout,
    decorationCatalog = DecorationCatalog,
})
```

- [ ] **Step 6: Verify existing Lune tests still pass + lint** (the applier has no Lune coverage; this proves nothing regressed in the pure modules and the files parse)

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): TreatmentApplier builds visible deck decorations"
```

---

## Task 8: Server wiring — remotes, stash, handlers, `DecorationPlaced`

**Files:**
- Modify: `roblox/default.project.json`
- Modify: `roblox/src/server/NetworkClient.luau`
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `appendDecoration` semantics via the PWA (the id authority stays server-TS-side; the Roblox server updates its stash from the purchase response); `DecorationLayout` (already threaded through the applier in Task 7); `BuildingPlacer.clamp`/`footprintBounds`, `DecorationCatalog.footprint`.
- Produces:
  - 3 new RemoteEvents: `SetDecorationPlacement`, `SetDecorationRemove` (client→server), `DecorationPlaced` (server→client).
  - `NetworkClient.setDecorations(robloxUserId, decorations): Result` → `PUT /players/:id/decorations`.
  - `playerEconomy[uid].deckDecorations` stashed from the join fetch + kept current on buy/place/remove; threaded into every `treatment` via a helper; echoed in `EconomyState`.
  - `RequestPurchase{ item = "decoration:<propId>" }` appends from the purchase response, rebuilds the pad, and fires `DecorationPlaced{ id }`.

- [ ] **Step 1: Declare the remotes**

In `roblox/default.project.json`, inside `RoshamboRemotes`, add after `"SetPlacement"`:

```json
                "SetPlacement": { "$className": "RemoteEvent" },
                "SetDecorationPlacement": { "$className": "RemoteEvent" },
                "SetDecorationRemove": { "$className": "RemoteEvent" },
                "DecorationPlaced": { "$className": "RemoteEvent" }
```

(Ensure the preceding `"SetPlacement"` line now ends with a comma.)

- [ ] **Step 2: Add `NetworkClient.setDecorations`**

In `roblox/src/server/NetworkClient.luau`, add before `return NetworkClient`:

```lua
function NetworkClient.setDecorations(self: any, robloxUserId: string, decorations: { any }): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/decorations`, { decorations = decorations })
end
```

- [ ] **Step 3: Stash + echo `deckDecorations`**

In `main.server.luau`, add the three remote handles (after `SetPlacement`):

```lua
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent
local SetDecorationPlacement = remotes:WaitForChild("SetDecorationPlacement") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
```

Extend the `playerEconomy` type annotation to include `deckDecorations`:

```lua
        deckDisplay: string?,
        teahouseDisplay: string?,
        portalOwned: boolean,
        deckDecorations: { any },
```

In the join handler (`Players.PlayerAdded` economy fetch), stash the list:

```lua
        playerEconomy[uid] = {
            totalPoints = (ecoData and ecoData.totalPoints) or 0,
            maxDeckSize = ecoData and ecoData.maxDeckSize or nil,
            teahouses = teahouses,
            claimedPadId = nil,
            deckDisplay = ecoData and ecoData.deckDisplay or nil,
            teahouseDisplay = ecoData and ecoData.teahouseDisplay or nil,
            portalOwned = (ecoData and ecoData.portalOwned) or false,
            deckDecorations = (ecoData and ecoData.deckDecorations) or {},
        }
```

In `echoEconomy`, add `deckDecorations` to the fired payload:

```lua
        deckDisplay = e.deckDisplay,
        teahouseDisplay = e.teahouseDisplay,
        portalOwned = e.portalOwned,
        deckDecorations = e.deckDecorations,
    })
```

- [ ] **Step 4: Thread `deckDecorations` into every treatment**

There are five `treatment` construction/mutation sites. Add `deckDecorations` at each so a rebuild always carries the owner's current props. At each owner `applier:apply` site, set the field on the treatment:

1. **Initial join claim** (`action.treatment.portalOwned = playerEconomy[uid].portalOwned`):
```lua
            action.treatment.portalOwned = playerEconomy[uid].portalOwned
            action.treatment.deckDecorations = playerEconomy[uid].deckDecorations
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
```

2. **Buy-to-claim** (in `RequestPurchase`, `action.treatment.portalOwned = e.portalOwned`):
```lua
                    action.treatment.portalOwned = e.portalOwned
                    action.treatment.deckDecorations = e.deckDecorations
                    applier:apply(...)
```

3. **Upgrade rebuild** (in `RequestPurchase`, the `treatment = { kind = "structure", ..., portalOwned = e.portalOwned }`):
```lua
                    local treatment =
                        { kind = "structure", loadout = teaLoadout, lit = true, portalOwned = e.portalOwned, deckDecorations = e.deckDecorations }
```

4. **SetDisplay rebuild** (same shape):
```lua
                local treatment =
                    { kind = "structure", loadout = teaLoadout, lit = true, portalOwned = e.portalOwned, deckDecorations = e.deckDecorations }
```

5. **SetPlacement rebuild** (`local treatment = { kind = "structure", loadout = fresh, lit = true, portalOwned = e.portalOwned }`):
```lua
        local treatment = { kind = "structure", loadout = fresh, lit = true, portalOwned = e.portalOwned, deckDecorations = e.deckDecorations }
```

- [ ] **Step 5: Handle the decoration purchase in `RequestPurchase`**

The purchase HTTP call already runs (`net:postPurchase(uid, item)`). For a `decoration:*` item the response carries `{ decoration, deckDecorations }`. After the existing `e.totalPoints = res.data.totalPoints` / `maxDeckSize` / `portalOwned` adoption, add a decoration branch **before** the `isBuyToClaim`/upgrade branches (a decoration buy is never a claim or a tier change — it just re-renders the claimed pad and fires `DecorationPlaced`):

```lua
        -- adopt the authoritative new state
        e.totalPoints = res.data.totalPoints
        e.maxDeckSize = res.data.maxDeckSize
        e.portalOwned = res.data.portalOwned or false
        if string.sub(item, 1, 11) == "decoration:" then
            -- the PWA is the id authority: adopt the returned list + the new instance's id, rebuild
            -- the claimed pad so the prop renders, then tell the client to enter placement for it.
            e.deckDecorations = res.data.deckDecorations or e.deckDecorations
            if e.claimedPadId ~= nil then
                rebuildClaimedPad(uid)
            end
            if player:IsDescendantOf(Players) and res.data.decoration ~= nil then
                DecorationPlaced:FireClient(player, { id = res.data.decoration.id })
            end
            echoEconomy(player, uid)
            return
        end
        local kind, size = string.match(item, "^(%a+):(%a+)$")
```

This introduces one shared rebuild helper `rebuildClaimedPad(uid)`. **Define it once, immediately after the `applier = TreatmentApplier.new({ ... })` block** (it closes over `applier`, `playerEconomy`, `PadSites`, `SizeClasses`, `playerHouse`, `CENTERED_PLACEMENT` — all file-scope by that point), so it is in scope for every handler below. Only the decoration paths (the buy branch here + the two decoration handlers in Step 6) call it; leave the existing inline upgrade/SetDisplay/SetPlacement rebuild blocks untouched (refactoring them is out of scope and risks their `echoBackDoor` sequencing).

```lua
-- Rebuild the player's claimed pad at its currently-resolved sizes/placement, threading the
-- current portal + decoration state, keeping playerHouse in sync. Used by the decoration
-- buy/place/remove paths, which change decoration state and then re-render the standing pad.
local function rebuildClaimedPad(uid: string)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
        return
    end
    local spec = PadSites[e.claimedPadId]
    if spec == nil then
        return
    end
    local teaSizes = {}
    for s in e.teahouses do
        table.insert(teaSizes, s)
    end
    local built = SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
    if built == nil then
        return
    end
    local teaLoadout = if built.teahouseSize then e.teahouses[built.teahouseSize] else nil
    local teahouse = if built.teahouseSize
        then {
            size = built.teahouseSize,
            loadout = teaLoadout,
            placement = (teaLoadout and teaLoadout.placement) or CENTERED_PLACEMENT,
        }
        else nil
    local treatment = {
        kind = "structure",
        loadout = teaLoadout,
        lit = true,
        portalOwned = e.portalOwned,
        deckDecorations = e.deckDecorations,
    }
    applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
    if built.teahouseSize ~= nil then
        playerHouse[uid] = { padId = e.claimedPadId, size = built.teahouseSize, loadout = teaLoadout }
    else
        playerHouse[uid] = nil
    end
end
```

The decoration-buy branch in the `RequestPurchase` handler calls it as `rebuildClaimedPad(uid)` then `echoBackDoor(player, uid)` (the rebuild replaces the Structure instance, so re-fire BackDoorState for parity with the other rebuild paths) — see the branch code above, which already has both plus `echoEconomy`. Adjust that branch to include the `echoBackDoor` call:

```lua
        if string.sub(item, 1, 11) == "decoration:" then
            e.deckDecorations = res.data.deckDecorations or e.deckDecorations
            if e.claimedPadId ~= nil then
                rebuildClaimedPad(uid)
                echoBackDoor(player, uid)
            end
            if player:IsDescendantOf(Players) and res.data.decoration ~= nil then
                DecorationPlaced:FireClient(player, { id = res.data.decoration.id })
            end
            echoEconomy(player, uid)
            return
        end
```

- [ ] **Step 6: Add the `SetDecorationPlacement` + `SetDecorationRemove` handlers**

Add after the `SetPlacement.OnServerEvent` handler. Both are HandlerQueue'd, occupant-gated, HTTP-yielding (PUT the whole list), then rebuild via `rebuildClaimedPad`:

```lua
SetDecorationPlacement.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return -- occupant-only, same discipline as SetPlacement
        end
        if typeof(payload) ~= "table" or typeof(payload.id) ~= "number" or typeof(payload.offset) ~= "table" then
            return
        end
        local id = payload.id
        local dx, dz = payload.offset[1], payload.offset[2]
        local facing = payload.facing
        if typeof(dx) ~= "number" or dx ~= dx or math.abs(dx) == math.huge then
            return
        end
        if typeof(dz) ~= "number" or dz ~= dz or math.abs(dz) == math.huge then
            return
        end
        if facing ~= "N" and facing ~= "E" and facing ~= "S" and facing ~= "W" then
            return
        end
        -- find the instance by id (stale client view -> no-op)
        local idx: number? = nil
        for i, d in e.deckDecorations do
            if d.id == id then
                idx = i
                break
            end
        end
        if idx == nil then
            return
        end
        local propId = e.deckDecorations[idx].propId
        local fp = DecorationCatalog.footprint(propId)
        if fp == nil then
            return
        end
        -- server-authoritative clamp against the CURRENT deck footprint (full deck; decorations may
        -- sit to the very edge). Persist the clamped value, never raw client numbers.
        local spec = PadSites[e.claimedPadId]
        if spec == nil then
            return
        end
        local teaSizes = {}
        for s in e.teahouses do
            table.insert(teaSizes, s)
        end
        local built =
            SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
        if built == nil then
            return
        end
        local deckFP = SizeClasses.deckFootprint(built.deckSize)
        local clamped = BuildingPlacer.clamp(fp, deckFP, { offset = { dx, dz }, facing = facing })
        -- build a NEW list (pre-persist clone discipline) with this instance updated
        local newList = table.clone(e.deckDecorations)
        newList[idx] = { id = id, propId = propId, offset = clamped.offset, facing = clamped.facing }
        local persisted = net:setDecorations(uid, newList)
        if not persisted.ok then
            warn(`[DECOR] setDecorations(place) failed for {uid}: {tostring(persisted.error)}`)
            echoEconomy(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.deckDecorations = newList
        rebuildClaimedPad(uid)
        echoBackDoor(player, uid) -- rebuild replaced the Structure; re-arm the F prompts (parity)
        echoEconomy(player, uid)
    end)
end)

SetDecorationRemove.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return
        end
        local id = if typeof(payload) == "table" then payload.id else payload
        if typeof(id) ~= "number" then
            return
        end
        local newList = {}
        local found = false
        for _, d in e.deckDecorations do
            if d.id == id then
                found = true
            else
                table.insert(newList, d)
            end
        end
        if not found then
            return -- stale id: no-op
        end
        local persisted = net:setDecorations(uid, newList)
        if not persisted.ok then
            warn(`[DECOR] setDecorations(remove) failed for {uid}: {tostring(persisted.error)}`)
            echoEconomy(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.deckDecorations = newList
        rebuildClaimedPad(uid)
        echoBackDoor(player, uid) -- rebuild replaced the Structure; re-arm the F prompts (parity)
        echoEconomy(player, uid)
    end)
end)
```

- [ ] **Step 7: Verify + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS (no regressions).
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 8: Commit**

```bash
git add roblox/default.project.json roblox/src/server/NetworkClient.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): decoration remotes, stash, place/remove handlers + DecorationPlaced"
```

---

## Task 9: Generalize `MoveController` to move any placement target

**Files:**
- Modify: `roblox/src/client/EventBus.luau`
- Modify: `roblox/src/client/MoveController.client.luau`

**Interfaces:**
- Consumes: `SetDecorationPlacement` remote (Task 8); `DecorationCatalog.build`/`footprint` (Task 5); `SizeClasses.deckFootprint`/`placementBounds`/`buildingFootprint` (existing); `BuildingPlacer` (existing).
- Produces:
  - `EventBus.MoveDecoration` BindableEvent.
  - A shared ghost-drag core `startMove(descriptor)` where `descriptor = { original: Model, ghost: Model, footprint, deckFP, mountCF: CFrame, initialOffset, initialFacing, commit: (offset, facing) -> () }`.
  - The **teahouse** entry (`EventBus.MoveTeahouse`) is behavior-equivalent: it builds a descriptor with `placementBounds(deckSize)` bounds, ghosts a clone of the `Structure`, and commits → `SetPlacement`.
  - The **decoration** entry (`EventBus.MoveDecoration`, payload `{ padId, id, propId, part: Model }`) uses `deckFootprint(deckSize)` bounds, ghosts a `DecorationCatalog.build(propId)`, and commits → `SetDecorationPlacement{ id, offset, facing }`.

> **Constraint (Global):** the teahouse-move path must stay behavior-equivalent. It becomes one caller of `startMove`, not a rewrite.

- [ ] **Step 1: Add the EventBus channel**

In `roblox/src/client/EventBus.luau`:

```lua
local NAMES = { "Cue", "TickerMessage", "MoveTeahouse", "MoveDecoration" }
```

- [ ] **Step 2: Refactor `MoveController` to the descriptor core**

In `roblox/src/client/MoveController.client.luau`:

1. Add the new requires + remote near the existing ones:

```lua
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent
local SetDecorationPlacement = remotes:WaitForChild("SetDecorationPlacement") :: RemoteEvent
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))
```

2. Add a module-level `commitFn` alongside the existing mode state (`active`, `ghost`, ...):

```lua
local current = { offset = { 0, 0 }, facing = "N" }
local commitFn: ((offset: { number }, facing: string) -> ())? = nil
local conns: { RBXScriptConnection } = {}
```

3. Rename `makeGhost` into `ghostify` — it now ghostifies a model the caller already produced (a Structure clone OR a catalog-built decoration) rather than cloning internally:

```lua
-- Turn a caller-supplied model into a translucent, non-interactive ghost parented to workspace.
-- The caller decides what the ghost IS (a Structure clone for a teahouse, a fresh catalog prop for
-- a decoration); this only fades/anchors it and strips any interactables.
local function ghostify(model: Model): Model
    model.Name = "MoveGhost"
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d.Transparency < 1 then
                d.Transparency = 0.6
            end
        elseif d:IsA("ProximityPrompt") then
            d:Destroy()
        end
    end
    model.Parent = workspace
    return model
end
```

4. In `commit`, call the stored `commitFn` instead of hard-coding `SetPlacement`:

```lua
local function commit()
    if not active then
        return
    end
    if commitFn then
        commitFn(current.offset, current.facing)
    end
    exit() -- the server rebuild arriving is the confirmation
end
```

5. In `exit`, clear `commitFn`:

```lua
    if hud then
        hud:Destroy()
        hud = nil
    end
    commitFn = nil
end
```

6. Replace the old `enter(payload)` body with a generic `startMove(descriptor)` core, plus two thin entry functions. `facingFromPivot` and `applyGhost`/`rotate`/`stepDrag`/`buildHud` stay as-is (they read the module `current`/`mountCF`/`buildingFP`/`deckFP`/`ghost`). Replace `EventBus.MoveTeahouse.Event:Connect(enter)` at the bottom with the new wiring:

```lua
-- ===== Step 5: generic core + entries =====

-- descriptor: { original: Model, ghost: Model (already ghostified), footprint, deckFP, mountCF,
--   initialOffset: {n,n}, initialFacing: string, commit: (offset, facing) -> () }
local function startMove(descriptor: any)
    if active then
        return
    end
    active = true
    mountCF = descriptor.mountCF
    buildingFP = descriptor.footprint
    deckFP = descriptor.deckFP
    original = descriptor.original
    commitFn = descriptor.commit
    current = { offset = { descriptor.initialOffset[1], descriptor.initialOffset[2] }, facing = descriptor.initialFacing }
    ghost = descriptor.ghost
    fadeOriginal(descriptor.original, 0.7)
    for _, d in descriptor.original:GetDescendants() do
        if d:IsA("ProximityPrompt") and d.Enabled then
            d.Enabled = false
            table.insert(disabledPrompts, d)
        end
    end
    applyGhost()
    buildHud()
    table.insert(conns, RunService.RenderStepped:Connect(stepDrag))
    table.insert(
        conns,
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then
                return
            end
            if input.KeyCode == Enum.KeyCode.R then
                rotate()
            elseif input.KeyCode == Enum.KeyCode.X then
                exit()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                commit()
            end
        end)
    )
    table.insert(conns, descriptor.original.Destroying:Connect(exit))
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(conns, humanoid.Died:Connect(exit))
    end
    table.insert(conns, player.CharacterAdded:Connect(exit))
end

-- Resolve a claimed site's deck frame + deck size from a MaterializedSite folder.
local function siteInfo(folder: Instance?): (CFrame?, string?)
    if folder == nil then
        return nil, nil
    end
    local m = folder:GetAttribute("MountCF")
    local deckSize = folder:GetAttribute("DeckSize")
    if typeof(m) ~= "CFrame" or typeof(deckSize) ~= "string" then
        return nil, nil
    end
    return m, deckSize
end

-- Teahouse entry (behavior-equivalent to the pre-generalization enter): ghost the Structure clone,
-- bounds = placementBounds (off the railings), commit -> SetPlacement.
local function enterTeahouse(payload: any)
    if active or typeof(payload) ~= "table" or typeof(payload.padId) ~= "string" then
        return
    end
    local sites = workspace:FindFirstChild("TeahouseSites")
    local folder = sites and sites:FindFirstChild("MaterializedSite_" .. payload.padId)
    local structure = folder and folder:FindFirstChild("Structure")
    local m, deckSize = siteInfo(folder)
    local teaSize = folder and folder:GetAttribute("TeahouseSize")
    if structure == nil or m == nil or deckSize == nil then
        return
    end
    if typeof(teaSize) ~= "string" or teaSize == "" then
        return -- bare deck: nothing to move
    end
    local dx, dz, facing = facingFromPivotOf(structure :: Model, m)
    startMove({
        original = structure,
        ghost = ghostify((structure :: Model):Clone()),
        footprint = SizeClasses.buildingFootprint(teaSize),
        deckFP = SizeClasses.placementBounds(deckSize),
        mountCF = m,
        initialOffset = { math.round(dx), math.round(dz) },
        initialFacing = facing,
        commit = function(offset, f)
            SetPlacement:FireServer({ offset = { offset[1], offset[2] }, facing = f })
        end,
    })
end

-- Decoration entry: ghost a fresh catalog prop, bounds = full deck footprint (props may sit to the
-- edge), commit -> SetDecorationPlacement{ id }.
local function enterDecoration(payload: any)
    if
        active
        or typeof(payload) ~= "table"
        or typeof(payload.id) ~= "number"
        or typeof(payload.propId) ~= "string"
        or typeof(payload.part) ~= "Instance"
    then
        return
    end
    local part = payload.part :: Model
    local folder = part.Parent
    local m, deckSize = siteInfo(folder)
    local fp = DecorationCatalog.footprint(payload.propId)
    if m == nil or deckSize == nil or fp == nil then
        return
    end
    local ghostModel = DecorationCatalog.build(payload.propId)
    if ghostModel == nil then
        return
    end
    local dx, dz, facing = facingFromPivotOf(part, m)
    startMove({
        original = part,
        ghost = ghostify(ghostModel),
        footprint = fp,
        deckFP = SizeClasses.deckFootprint(deckSize),
        mountCF = m,
        initialOffset = { math.round(dx), math.round(dz) },
        initialFacing = facing,
        commit = function(offset, f)
            SetDecorationPlacement:FireServer({ id = payload.id, offset = { offset[1], offset[2] }, facing = f })
        end,
    })
end

EventBus.MoveTeahouse.Event:Connect(enterTeahouse)
EventBus.MoveDecoration.Event:Connect(enterDecoration)
```

7. `facingFromPivot` currently closes over the module `mountCF`. Since the entries need it BEFORE `startMove` sets `mountCF`, generalize it to take the mount explicitly — rename to `facingFromPivotOf(structure, mount)`:

```lua
local function facingFromPivotOf(structure: Model, mount: CFrame): (number, number, string)
    local rel = mount:ToObjectSpace(structure:GetPivot())
    local _, ry, _ = rel:ToOrientation()
    local deg = (math.round(math.deg(ry) / 90) * 90) % 360
    local facing = if deg == 0 then "N" elseif deg == 90 then "E" elseif deg == 180 then "S" else "W"
    return rel.Position.X, rel.Position.Z, facing
end
```

(Delete the old `facingFromPivot`; nothing else references it.)

- [ ] **Step 3: Lint + parse check**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS (client files aren't Lune-loaded, but the pure suite must stay green).

- [ ] **Step 4: Commit**

```bash
git add roblox/src/client/EventBus.luau roblox/src/client/MoveController.client.luau
git commit -m "feat(roblox): generalize MoveController to move any placement target"
```

---

## Task 10: Panel Decorations section + `TeahouseMenuModel` buyables

**Files:**
- Modify: `roblox/src/shared/TeahouseMenuModel.luau`
- Test: `roblox/tests/TeahouseMenuModel.spec.luau`
- Modify: `roblox/src/client/TeahouseController.client.luau`

**Interfaces:**
- Consumes: `DecorationCatalog.ids`/`MAX_DECORATIONS` (Task 5); the echoed `catalog.decoration` + `deckDecorations` (Task 8).
- Produces:
  - `viewModel(state).decorations: { { propId, price, affordable, canBuy } }` (ordered by `DecorationCatalog.ids()`); `canBuy = claimed AND ownsDeck AND affordable AND under the cap`. The view-model reads `state.deckDecorations` (list) for the cap count.
  - Panel: a "Decorations" section with a buy button per prop firing `RequestPurchase{ item = "decoration:<propId>" }`.

- [ ] **Step 1: Write the failing view-model tests**

Add to `roblox/tests/TeahouseMenuModel.spec.luau` (a `state` helper likely already exists in that spec — reuse it; otherwise build a minimal state inline as below):

```lua
local DecorationCatalog = require("../src/shared/DecorationCatalog")

describe("TeahouseMenuModel.viewModel — decorations", function()
    local function baseState(over)
        local s = {
            totalPoints = 1000,
            maxDeckSize = "S",
            teahouseSizes = {},
            claimed = true,
            claimedPadId = "T01",
            deckDisplay = nil,
            teahouseDisplay = nil,
            padPreferences = {},
            portalOwned = false,
            deckDecorations = {},
            catalog = {
                deck = { S = 50, M = 500, L = 3000 },
                teahouse = { S = 30, M = 300, L = 2000 },
                portal = 500,
                decoration = { ishidoro = 40, tsukubai = 60, bonsai = 25, bench = 35 },
            },
        }
        for k, v in over or {} do
            s[k] = v
        end
        return s
    end

    test("lists all catalog props in catalog order with price + affordability", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState())
        expect(#vm.decorations).toBe(#DecorationCatalog.ids())
        expect(vm.decorations[1].propId).toBe("ishidoro")
        expect(vm.decorations[1].price).toBe(40)
        expect(vm.decorations[1].affordable).toBe(true)
        expect(vm.decorations[1].canBuy).toBe(true)
    end)

    test("unaffordable prop is not buyable", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState({ totalPoints = 10 }))
        for _, d in vm.decorations do
            expect(d.affordable).toBe(false)
            expect(d.canBuy).toBe(false)
        end
    end)

    test("no claim -> nothing buyable", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState({ claimed = false, claimedPadId = nil }))
        for _, d in vm.decorations do
            expect(d.canBuy).toBe(false)
        end
    end)

    test("no deck -> nothing buyable", function()
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState({ maxDeckSize = nil }))
        for _, d in vm.decorations do
            expect(d.canBuy).toBe(false)
        end
    end)

    test("at the cap -> nothing buyable", function()
        local full = {}
        for i = 1, DecorationCatalog.MAX_DECORATIONS do
            table.insert(full, { id = i, propId = "bonsai", offset = { 0, 0 }, facing = "N" })
        end
        local vm = require("../src/shared/TeahouseMenuModel").viewModel(baseState({ deckDecorations = full }))
        for _, d in vm.decorations do
            expect(d.canBuy).toBe(false)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `vm.decorations` is nil.

- [ ] **Step 3: Implement in `roblox/src/shared/TeahouseMenuModel.luau`**

Add the require at the top:

```lua
local SizeClasses = require("./SizeClasses")
local DecorationCatalog = require("./DecorationCatalog")
```

Before the final `return { ... }` in `viewModel`, build the decorations list:

```lua
    -- decorations: buy-per-placement props, buyable only on a claimed deck under the cap.
    local decorCatalog = state.catalog.decoration or {}
    local decorCount = #(state.deckDecorations or {})
    local underCap = decorCount < DecorationCatalog.MAX_DECORATIONS
    local decorations = {}
    for _, propId in DecorationCatalog.ids() do
        local price = decorCatalog[propId]
        local affordable = if price ~= nil then points >= price else false
        local canBuy = state.claimed == true and ownsDeck and underCap and affordable and price ~= nil
        table.insert(decorations, { propId = propId, price = price, affordable = affordable, canBuy = canBuy })
    end
```

Add `decorations = decorations,` to the returned table.

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Add the panel section in `roblox/src/client/TeahouseController.client.luau`**

Store `deckDecorations` on `econ` (default empty) so the view-model gets the cap count:

```lua
    padPreferences = {} :: { string },
    catalog = { deck = {}, teahouse = {}, portal = 0, decoration = {} } :: {
        deck: { [string]: number },
        teahouse: { [string]: number },
        portal: number,
        decoration: { [string]: number },
    },
    portalOwned = false,
    deckDecorations = {} :: { any },
}
```

In the `EconomyState.OnClientEvent` handler, adopt the list:

```lua
    econ.portalOwned = p.portalOwned == true
    econ.deckDecorations = p.deckDecorations or {}
    render()
```

Add a labels map + a decorations section builder near the other section builders (after `buildDisplayRow`). Placeholder labels for the placeholder art:

```lua
local DECOR_LABELS = {
    ishidoro = "Stone Lantern",
    tsukubai = "Water Basin",
    bonsai = "Potted Bonsai",
    bench = "Wooden Bench",
}

sectionLabel(76, "Decorations")
local decorContainer = Instance.new("Frame")
decorContainer.Name = "Decorations"
decorContainer.LayoutOrder = 77
decorContainer.Size = UDim2.new(1, 0, 0, 0)
decorContainer.AutomaticSize = Enum.AutomaticSize.Y
decorContainer.BackgroundTransparency = 1
decorContainer.Parent = panel
local decorLayout = Instance.new("UIListLayout")
decorLayout.FillDirection = Enum.FillDirection.Vertical
decorLayout.Padding = UDim.new(0, 4)
decorLayout.SortOrder = Enum.SortOrder.LayoutOrder
decorLayout.Parent = decorContainer

-- propId -> its buy button, created once (catalog is fixed); render() updates label/enabled.
local decorButtons: { [string]: TextButton } = {}
```

Because the panel's construction order runs before the first echo, create the buttons lazily on the first render that has a catalog. Add a helper + call it from `render`:

```lua
local function ensureDecorButtons(vm: any)
    if next(decorButtons) ~= nil then
        return
    end
    for i, d in vm.decorations do
        local button = Instance.new("TextButton")
        button.Name = "Decor_" .. d.propId
        button.LayoutOrder = i
        button.Size = UDim2.new(1, 0, 0, 30)
        button.BackgroundColor3 = BG
        button.BackgroundTransparency = 0.1
        button.TextColor3 = DIM
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Active = false
        button.Parent = decorContainer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
        local propId = d.propId
        button.MouseButton1Click:Connect(function()
            if button.Active then
                RequestPurchase:FireServer({ item = "decoration:" .. propId })
            end
        end)
        decorButtons[propId] = button
    end
end
```

In `render()` (after the portal block, before `renderFavorites`), render the decoration buttons:

```lua
    ensureDecorButtons(vm)
    for _, d in vm.decorations do
        local button = decorButtons[d.propId]
        if button then
            local label = DECOR_LABELS[d.propId] or d.propId
            local priceText = if d.price ~= nil then `{d.price} pts` else "—"
            button.Text = `  {label} — {priceText}`
            button.Active = d.canBuy
            button.TextColor3 = if d.canBuy then TEXT else DIM
        end
    end
    decorContainer.Visible = vm.ownsDeck
```

- [ ] **Step 6: Lint + tests**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/TeahouseMenuModel.luau roblox/tests/TeahouseMenuModel.spec.luau roblox/src/client/TeahouseController.client.luau
git commit -m "feat(roblox): decorations catalog section in the teahouse panel"
```

---

## Task 11: `DecorationController` — owner prompts + auto-place on buy

**Files:**
- Create: `roblox/src/client/DecorationController.client.luau`

**Interfaces:**
- Consumes: `EconomyState` (own `claimedPadId`), `DecorationPlaced` (Task 8), `SetDecorationRemove` (Task 8), `EventBus.MoveDecoration` (Task 9); the `Decoration` tag + `id`/`padId` attributes (Task 7).
- Produces: for each `Decoration` Model whose `padId` == the client's own `claimedPadId`, a **Move** prompt (fires `EventBus.MoveDecoration`) and a **Remove** prompt (fires `SetDecorationRemove`). On `DecorationPlaced{ id }` after a buy, auto-enters ghost-drag for that instance once it exists.

- [ ] **Step 1: Implement `roblox/src/client/DecorationController.client.luau`**

```lua
--!strict
-- Owner-only in-world controls for placed deck decorations (2026-07-19 framework). Mirrors
-- BackDoorController's geometry-driven binding, but keyed on the CollectionService "Decoration"
-- tag: whenever a Decoration Model whose padId attribute matches THIS client's claimed pad
-- replicates in, it gets Move + Remove ProximityPrompts. Tag replication + GetInstanceAddedSignal
-- make RemoteEvent/replication ordering irrelevant (same lesson as the back-door rebind). A buy
-- fires DecorationPlaced{ id }; when that instance is present + owned, we auto-enter ghost-drag.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DecorationCatalog = require(shared:WaitForChild("DecorationCatalog"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetDecorationRemove = remotes:WaitForChild("SetDecorationRemove") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local myPadId: string? = nil
local pendingAutoMoveId: number? = nil
local bound: { [Instance]: boolean } = {} -- decoration Model -> prompts added

local function anchorPart(model: Model): BasePart?
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

-- propId is written by TreatmentApplier._buildDecorations as a model attribute (Task 11 Step 2).
local function propIdOf(model: Instance): string?
    return model:GetAttribute("propId") :: string?
end

local function addPrompts(model: Model)
    if bound[model] then
        return
    end
    local anchor = anchorPart(model)
    if anchor == nil then
        return
    end
    bound[model] = true

    local move = Instance.new("ProximityPrompt")
    move.Name = "DecorMove"
    move.ActionText = "Move"
    move.ObjectText = "Decoration"
    move.KeyboardKeyCode = Enum.KeyCode.E
    move.MaxActivationDistance = 10
    move.RequiresLineOfSight = false
    move.Parent = anchor
    move.Triggered:Connect(function()
        local id = model:GetAttribute("id")
        local propId = propIdOf(model)
        if typeof(id) == "number" and typeof(propId) == "string" then
            EventBus.MoveDecoration:Fire({ padId = myPadId, id = id, propId = propId, part = model })
        end
    end)

    local remove = Instance.new("ProximityPrompt")
    remove.Name = "DecorRemove"
    remove.ActionText = "Remove"
    remove.ObjectText = "Decoration"
    remove.KeyboardKeyCode = Enum.KeyCode.X
    remove.MaxActivationDistance = 10
    remove.RequiresLineOfSight = false
    remove.Parent = anchor
    remove.Triggered:Connect(function()
        local id = model:GetAttribute("id")
        if typeof(id) == "number" then
            SetDecorationRemove:FireServer({ id = id })
        end
    end)
end

-- Bind a tagged decoration IF it belongs to this client's claimed pad. Also fulfils a pending
-- auto-move (post-buy) when the matching instance appears.
local function tryBind(inst: Instance)
    if not inst:IsA("Model") then
        return
    end
    local padId = inst:GetAttribute("padId")
    if myPadId == nil or padId ~= myPadId then
        return
    end
    addPrompts(inst)
    local id = inst:GetAttribute("id")
    if pendingAutoMoveId ~= nil and typeof(id) == "number" and id == pendingAutoMoveId then
        local propId = propIdOf(inst)
        if typeof(propId) == "string" then
            pendingAutoMoveId = nil
            EventBus.MoveDecoration:Fire({ padId = myPadId, id = id, propId = propId, part = inst })
        end
    end
end

local function rescanAll()
    for _, inst in CollectionService:GetTagged("Decoration") do
        tryBind(inst)
    end
end

CollectionService:GetInstanceAddedSignal("Decoration"):Connect(tryBind)
CollectionService:GetInstanceRemovedSignal("Decoration"):Connect(function(inst)
    bound[inst] = nil
end)

EconomyState.OnClientEvent:Connect(function(p)
    local newPad = p.claimedPadId
    if newPad ~= myPadId then
        myPadId = newPad
        rescanAll() -- claim just resolved: bind any decorations already replicated in
    end
end)

DecorationPlaced.OnClientEvent:Connect(function(p)
    if typeof(p) == "table" and typeof(p.id) == "number" then
        pendingAutoMoveId = p.id
        rescanAll() -- the freshly-built prop may already be here; otherwise tryBind catches it
    end
end)

rescanAll()
```

> **`propId` recovery:** `addPrompts`/`tryBind` read a `propId` attribute off the Decoration model. Task 7's `_buildDecorations` tags `id` + `padId` but NOT `propId`. Add `model:SetAttribute("propId", r.propId)` in `_buildDecorations` (one line) so the client can pass it to `MoveDecoration`. Make that edit as part of THIS task (it's the consumer that needs it) and re-commit the applier line here.

- [ ] **Step 2: Add the `propId` attribute in `TreatmentApplier._buildDecorations`**

In `roblox/src/server/TreatmentApplier.luau`, in `_buildDecorations`, add the attribute next to the others:

```lua
        model.Name = "Decoration"
        model:SetAttribute("id", r.id)
        model:SetAttribute("padId", padId)
        model:SetAttribute("propId", r.propId)
        model:AddTag("Decoration")
```

- [ ] **Step 3: Lint + tests**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/client/DecorationController.client.luau roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): DecorationController owner prompts + auto-place on buy"
```

---

## Visual gate (after Task 11 — run in Studio via Rojo, not a task)

Sync with `rojo serve`, play as a claimed deck-owner, and verify:
1. The panel's **Decorations** section lists four props with prices; buying one spends points.
2. After a buy, ghost-drag begins automatically on the new prop; a click/✓ places it; four props place with **distinct footprints**.
3. Each placed prop shows owner-only **Move** and **Remove** prompts; Move re-enters ghost-drag, Remove deletes it (no refund).
4. **Auto-hide:** place props in the open yard under a small teahouse display, then raise the teahouse Display to a larger size — the covered props vanish; shrink back and they return. Stored placement is unchanged (they reappear where they were).
5. Cap: buying past 24 is refused (button disabled at the cap).
6. Props survive Display / size-upgrade / teahouse-Move rebuilds.
7. **Regression:** the teahouse **Move** still works exactly as before (the generalized `MoveController`).

---

## Self-Review notes (for the executor)

- **Spec coverage:** data model (T1,T3), catalog split (T1 TS, T5 Luau), `DecorationLayout.resolve` (T6), server routes (T1–T3), Roblox stash/thread/handlers (T7,T8), `MoveController` generalization (T9), panel section (T10), `DecorationController` (T11), all error-handling rows (T1 cap/unknown, T2 malformed, T8 stale-id no-op + occupant gate, T6 bare-deck) — covered.
- **Type consistency:** `deckDecorations` is `{ id, propId, offset:{x,z}, facing }` everywhere; the propId set is the same four ids in TS + Luau; `footprintBounds`/`resolve`/`clamp` signatures match their call sites.
- **Known deferred (do NOT build):** swap-decoration economy, teahouse-anchored props, banner/noren slot content + flex economies, flex behaviors, collidable/sittable props, partial refunds, multi-pad decoration memory, art pass.
