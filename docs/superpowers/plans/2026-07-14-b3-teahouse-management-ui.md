# B3 Teahouse Management UI + Display Size — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the three walk-up interactions (Favorite/back-door/buy-upgrade) behind one persistent HUD panel, and add a display-size cap so a player can show a smaller deck and/or teahouse than they own.

**Architecture:** Reuse the B1/B2 spine — pure logic modules (Lune/Vitest tested), occupant-gated RemoteEvents, `/api/v1` persistence, `EconomyState` echo, `SiteCoordinator`/handlers → `SizeClasses.resolveBuilt` → `TreatmentApplier` live rebuild. New: two `User` display fields + a `POST /display` route, display caps in `resolveBuilt`, a pure `TeahouseMenuModel` view-model, a `SetDisplay` remote+handler, the `TeahouseController` HUD panel, and a trim to `EconomyController`.

**Tech Stack:** Server = TypeScript + Express + Mongoose, Vitest (`server/`). Roblox = Luau + Rojo, bespoke Lune harness (`roblox/`). GUI is not Lune-testable → visual gate.

## Global Constraints

- **Display is display-only:** it can only ever *shrink* what `resolveBuilt` would otherwise build; it never shows a size the player does not own (a display larger than owned is clamped to owned).
- **Deck display floor is `S`** (no "none"); **teahouse display floor is `None`** (bare deck). `teahouse ≤ displayed deck` holds.
- **Persisted values:** `deckDisplay ∈ {'S','M','L',null}`, `teahouseDisplay ∈ {'none','S','M','L',null}`; `null` = biggest owned = pre-B3 behavior (backward compatible).
- **First `deck:S` stays a world buy-to-claim** (targets a specific pad); only *later* upgrades go through the HUD panel. Do not add a HUD path that buys the first deck.
- **Occupant/presence discipline (from B1/B2):** every server handler that yields on HTTP must re-check `player:IsDescendantOf(Players)` after the yield before mutating world state.
- **Sizes:** `SIZE_RANK = {S:1,M:2,L:3}`. `PRICES = { deck:{S:50,M:500,L:3000}, teahouse:{S:30,M:300,L:2000} }`.
- Server tests: `cd server && npm test`. Roblox tests: `cd roblox && lune run tests/run`. Lint: `cd roblox && stylua --check src tests && selene src`.

---

## File Structure

- `server/src/economy.ts` (modify) — add pure `validateDisplay`.
- `server/src/economy.test.ts` (modify) — `validateDisplay` unit tests.
- `server/src/models/User.ts` (modify) — add `deckDisplay` + `teahouseDisplay` fields.
- `server/src/routes/apiV1.ts` (modify) — `GET /economy` returns the two fields; new `POST /players/:id/display`.
- `server/src/routes/apiV1.test.ts` (modify, or the existing economy route test file) — route tests.
- `roblox/src/shared/SizeClasses.luau` (modify) — `resolveBuilt` gains `deckDisplay?`, `teahouseDisplay?`.
- `roblox/tests/SizeClasses.spec.luau` (modify) — display-cap tests.
- `roblox/src/shared/TeahouseMenuModel.luau` (create) — pure `viewModel(state)`.
- `roblox/tests/TeahouseMenuModel.spec.luau` (create) — view-model tests.
- `roblox/src/server/NetworkClient.luau` (modify) — `postDisplay`.
- `roblox/src/server/main.server.luau` (modify) — `SetDisplay` handler; thread display into `playerEconomy`/`echoEconomy`/join-fetch/`resolveBuilt` calls.
- `roblox/default.project.json` (modify) — register `SetDisplay` under `RoshamboRemotes`.
- `roblox/src/shared/SiteCoordinator.luau` (modify) — thread display into its `resolveBuilt` call.
- `roblox/src/client/TeahouseController.client.luau` (create) — HUD button + panel.
- `roblox/src/client/EconomyController.client.luau` (modify) — drop the upgrade prompt, keep buy-to-claim.

---

## Task 1: Pure `validateDisplay` (server)

**Files:**
- Modify: `server/src/economy.ts`
- Test: `server/src/economy.test.ts`

**Interfaces:**
- Consumes: `EconomyState = { totalPoints: number; maxDeckSize: Size|null; teahouseSizes: Size[] }`, `Size`, `SIZE_RANK` (existing in `economy.ts`).
- Produces: `type DeckDisplay = Size | null`, `type TeahouseDisplay = 'none' | Size | null`, and
  `validateDisplay(state: EconomyState, deckDisplay: unknown, teahouseDisplay: unknown): { ok: true; deckDisplay: DeckDisplay; teahouseDisplay: TeahouseDisplay } | { ok: false; error: string }`.

- [ ] **Step 1: Write the failing tests** (append to `server/src/economy.test.ts`)

```ts
import { validateDisplay } from './economy';

describe('validateDisplay', () => {
  const st = (over: Partial<EconomyState> = {}): EconomyState =>
    ({ totalPoints: 0, maxDeckSize: 'L', teahouseSizes: ['S', 'M', 'L'], ...over });

  it('accepts null/null (default = biggest owned)', () => {
    expect(validateDisplay(st(), null, null)).toEqual({ ok: true, deckDisplay: null, teahouseDisplay: null });
  });
  it('accepts a deck display <= owned and a teahouse display <= owned', () => {
    expect(validateDisplay(st(), 'M', 'S')).toEqual({ ok: true, deckDisplay: 'M', teahouseDisplay: 'S' });
  });
  it("accepts teahouse 'none'", () => {
    expect(validateDisplay(st(), 'S', 'none')).toEqual({ ok: true, deckDisplay: 'S', teahouseDisplay: 'none' });
  });
  it('rejects a deck display larger than owned', () => {
    expect(validateDisplay(st({ maxDeckSize: 'M' }), 'L', null)).toEqual({ ok: false, error: 'DISPLAY_UNOWNED' });
  });
  it('rejects a teahouse display larger than owned', () => {
    expect(validateDisplay(st({ teahouseSizes: ['S'] }), null, 'M')).toEqual({ ok: false, error: 'DISPLAY_UNOWNED' });
  });
  it("rejects 'none' for the deck", () => {
    expect(validateDisplay(st(), 'none' as unknown, null)).toEqual({ ok: false, error: 'BAD_DISPLAY' });
  });
  it('rejects garbage values', () => {
    expect(validateDisplay(st(), 'XL' as unknown, null)).toEqual({ ok: false, error: 'BAD_DISPLAY' });
    expect(validateDisplay(st(), null, 42 as unknown)).toEqual({ ok: false, error: 'BAD_DISPLAY' });
  });
  it('rejects a deck display when the player owns no deck', () => {
    expect(validateDisplay(st({ maxDeckSize: null }), 'S', null)).toEqual({ ok: false, error: 'DISPLAY_UNOWNED' });
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: FAIL — `validateDisplay is not a function`.

- [ ] **Step 3: Implement** (append to `server/src/economy.ts`)

```ts
export type DeckDisplay = Size | null;
export type TeahouseDisplay = 'none' | Size | null;

const isSize = (v: unknown): v is Size => v === 'S' || v === 'M' || v === 'L';
const ownedMaxTeahouse = (state: EconomyState): Size | null =>
  state.teahouseSizes.reduce<Size | null>((m, s) => (m === null || SIZE_RANK[s] > SIZE_RANK[m] ? s : m), null);

export function validateDisplay(
  state: EconomyState,
  deckDisplay: unknown,
  teahouseDisplay: unknown,
): { ok: true; deckDisplay: DeckDisplay; teahouseDisplay: TeahouseDisplay } | { ok: false; error: string } {
  // deck: null or a Size <= owned maxDeckSize; 'none' is NOT allowed for the deck
  if (deckDisplay !== null && !isSize(deckDisplay)) return { ok: false, error: 'BAD_DISPLAY' };
  if (isSize(deckDisplay)) {
    if (state.maxDeckSize === null || SIZE_RANK[deckDisplay] > SIZE_RANK[state.maxDeckSize]) {
      return { ok: false, error: 'DISPLAY_UNOWNED' };
    }
  }
  // teahouse: null, 'none', or a Size <= owned max teahouse
  if (teahouseDisplay !== null && teahouseDisplay !== 'none' && !isSize(teahouseDisplay)) {
    return { ok: false, error: 'BAD_DISPLAY' };
  }
  if (isSize(teahouseDisplay)) {
    const owned = ownedMaxTeahouse(state);
    if (owned === null || SIZE_RANK[teahouseDisplay] > SIZE_RANK[owned]) {
      return { ok: false, error: 'DISPLAY_UNOWNED' };
    }
  }
  return { ok: true, deckDisplay: deckDisplay as DeckDisplay, teahouseDisplay: teahouseDisplay as TeahouseDisplay };
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/economy.ts server/src/economy.test.ts
git commit -m "feat(server): pure validateDisplay for teahouse/deck display caps (B3)"
```

---

## Task 2: `User` display fields + `GET /economy` fields + `POST /display` route (server)

**Files:**
- Modify: `server/src/models/User.ts` (interface near line 24; schema near line 49)
- Modify: `server/src/routes/apiV1.ts` (`GET .../economy` near line 153; add `POST .../display` after the purchase route near line 184)
- Test: `server/src/routes/apiV1.test.ts` (or the existing economy-route test file — check `grep -rl "players/:robloxUserId/economy\|/economy'" server/src/**/*.test.ts`; if none, add the tests to `server/src/routes/apiV1.test.ts`)

**Interfaces:**
- Consumes: `validateDisplay` (Task 1); `resolveUser`, `readEconomy` (existing in `apiV1.ts:138`).
- Produces: `GET .../economy` response now includes `deckDisplay` + `teahouseDisplay`; `POST .../players/:robloxUserId/display` accepting `{ deckDisplay, teahouseDisplay }`, persisting to `User`, returning `{ deckDisplay, teahouseDisplay }`.

- [ ] **Step 1: Add the `User` fields** — in `server/src/models/User.ts`, add to the `IUser` interface after `maxDeckSize` (line ~24):

```ts
    deckDisplay: 'S' | 'M' | 'L' | null;
    teahouseDisplay: 'none' | 'S' | 'M' | 'L' | null;
```

and to the schema after the `maxDeckSize` field (line ~49):

```ts
    deckDisplay: { type: String, enum: ['S', 'M', 'L', null], default: null },
    teahouseDisplay: { type: String, enum: ['none', 'S', 'M', 'L', null], default: null },
```

- [ ] **Step 2: Write the failing route tests** (append to the economy-route test file)

```ts
  it('GET economy returns display fields (null by default)', async () => {
    await User.create({ robloxId: 'r1', totalPoints: 0, maxDeckSize: 'L', teahouses: new Map([['S', {}], ['M', {}], ['L', {}]]) });
    const res = await request(app).get('/api/v1/players/r1/economy').set('X-API-Key', KEY);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ deckDisplay: null, teahouseDisplay: null });
  });
  it('POST display persists valid caps and echoes them', async () => {
    await User.create({ robloxId: 'r2', totalPoints: 0, maxDeckSize: 'L', teahouses: new Map([['S', {}], ['M', {}], ['L', {}]]) });
    const res = await request(app).post('/api/v1/players/r2/display').set('X-API-Key', KEY).send({ deckDisplay: 'M', teahouseDisplay: 'none' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ deckDisplay: 'M', teahouseDisplay: 'none' });
    const u = await User.findOne({ robloxId: 'r2' });
    expect(u?.deckDisplay).toBe('M');
    expect(u?.teahouseDisplay).toBe('none');
  });
  it('POST display rejects an unowned size', async () => {
    await User.create({ robloxId: 'r3', totalPoints: 0, maxDeckSize: 'S', teahouses: new Map() });
    const res = await request(app).post('/api/v1/players/r3/display').set('X-API-Key', KEY).send({ deckDisplay: 'L' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('DISPLAY_UNOWNED');
  });
```

(Match the existing test file's harness: reuse its `app`, `KEY`, `request`, and `User` imports + `beforeEach` DB reset. If the file uses `robloxUserId` params differently, mirror the existing economy test's setup exactly.)

- [ ] **Step 3: Run to verify failure**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: FAIL — `deckDisplay` undefined / 404 on `/display`.

- [ ] **Step 4: Implement** — in `apiV1.ts`, extend the `GET .../economy` `res.json({...})` (near line 153) to add:

```ts
                deckDisplay: user.deckDisplay ?? null,
                teahouseDisplay: user.teahouseDisplay ?? null,
```

and add the new route after the `POST .../purchase` handler (after line ~186):

```ts
    router.post('/players/:robloxUserId/display', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const chk = validateDisplay(readEconomy(user), req.body?.deckDisplay ?? null, req.body?.teahouseDisplay ?? null);
            if (!chk.ok) { res.status(400).json({ error: chk.error }); return; }
            user.deckDisplay = chk.deckDisplay;
            user.teahouseDisplay = chk.teahouseDisplay;
            await user.save();
            res.json({ deckDisplay: chk.deckDisplay, teahouseDisplay: chk.teahouseDisplay });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

Add `validateDisplay` to the `economy` import on line 10.

- [ ] **Step 5: Run to verify pass**

Run: `cd server && npm test`
Expected: PASS (all suites).

- [ ] **Step 6: Commit**

```bash
git add server/src/models/User.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): User display fields + GET economy fields + POST /display route (B3)"
```

---

## Task 3: `SizeClasses.resolveBuilt` display caps (Roblox)

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau` (the `resolveBuilt` function, ~lines 67-84)
- Test: `roblox/tests/SizeClasses.spec.luau`

**Interfaces:**
- Consumes: existing `SizeClasses.minSize`, `SizeClasses.rank`.
- Produces: `SizeClasses.resolveBuilt(maxDeckSize: string?, teahouseSizes: {string}, perchMax: string, deckDisplay: string?, teahouseDisplay: string?): { deckSize: string, teahouseSize: string? }?`. The two new args are **optional** and default to `nil` (= biggest owned = current behavior); all existing 3-arg callers keep working.

- [ ] **Step 1: Write the failing tests** (add a `describe` block to `roblox/tests/SizeClasses.spec.luau`)

```lua
describe("SizeClasses.resolveBuilt display caps", function()
    test("nil display args = biggest owned (unchanged)", function()
        local r = SizeClasses.resolveBuilt("L", { "S", "M", "L" }, "L")
        expect(r.deckSize).toBe("L")
        expect(r.teahouseSize).toBe("L")
    end)
    test("deckDisplay caps the deck (and pulls the teahouse down with it)", function()
        local r = SizeClasses.resolveBuilt("L", { "S", "M", "L" }, "L", "M", nil)
        expect(r.deckSize).toBe("M")
        expect(r.teahouseSize).toBe("M") -- teahouse <= displayed deck
    end)
    test("teahouseDisplay caps only the teahouse", function()
        local r = SizeClasses.resolveBuilt("L", { "S", "M", "L" }, "L", nil, "S")
        expect(r.deckSize).toBe("L")
        expect(r.teahouseSize).toBe("S")
    end)
    test("teahouseDisplay 'none' = bare deck", function()
        local r = SizeClasses.resolveBuilt("L", { "S", "M", "L" }, "L", nil, "none")
        expect(r.deckSize).toBe("L")
        expect(r.teahouseSize == nil).toBe(true)
    end)
    test("a display larger than the perch/deck cap clamps down (never up)", function()
        -- perch caps at M, deckDisplay L -> deck stays M
        local r = SizeClasses.resolveBuilt("L", { "L" }, "M", "L", "L")
        expect(r.deckSize).toBe("M")
        expect(r.teahouseSize).toBe("M")
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL on the new block (deck not capped / extra args ignored).

- [ ] **Step 3: Implement** — replace the body of `SizeClasses.resolveBuilt` (keep the signature line but add the two params) with:

```lua
function SizeClasses.resolveBuilt(
    maxDeckSize: string?,
    teahouseSizes: { string },
    perchMax: string,
    deckDisplay: string?,
    teahouseDisplay: string?
): { deckSize: string, teahouseSize: string? }?
    if maxDeckSize == nil then
        return nil
    end
    -- deck: owned max, capped by the perch, then by the display (clamp only ever shrinks)
    local deckSize = SizeClasses.minSize(maxDeckSize, perchMax)
    if deckDisplay ~= nil then
        deckSize = SizeClasses.minSize(deckSize, deckDisplay)
    end
    -- teahouse: 'none' display = bare deck
    if teahouseDisplay == "none" then
        return { deckSize = deckSize, teahouseSize = nil }
    end
    local maxTea: string? = nil
    for _, s in teahouseSizes do
        if maxTea == nil or SizeClasses.rank[s] > SizeClasses.rank[maxTea] then
            maxTea = s
        end
    end
    if maxTea == nil then
        return { deckSize = deckSize, teahouseSize = nil }
    end
    local teahouseSize = maxTea
    if teahouseDisplay ~= nil then
        teahouseSize = SizeClasses.minSize(teahouseSize, teahouseDisplay)
    end
    teahouseSize = SizeClasses.minSize(teahouseSize, deckSize) -- teahouse <= (displayed) deck
    return { deckSize = deckSize, teahouseSize = teahouseSize }
end
```

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all PASS/clean (existing `resolveBuilt` tests still green — the 3-arg calls default the new params to `nil`).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): resolveBuilt display caps for deck/teahouse (B3)"
```

---

## Task 4: `TeahouseMenuModel` pure view-model (Roblox)

**Files:**
- Create: `roblox/src/shared/TeahouseMenuModel.luau`
- Test: `roblox/tests/TeahouseMenuModel.spec.luau`

**Interfaces:**
- Consumes: `SizeClasses.rank`, `SizeClasses.order` (largest-first `{"L","M","S"}`).
- Produces: `TeahouseMenuModel.viewModel(state)` where `state = { totalPoints: number, maxDeckSize: string?, teahouseSizes: {string}, deckDisplay: string?, teahouseDisplay: string?, padPreferences: {string}, catalog: {deck:{[string]:number}, teahouse:{[string]:number}} }` returns:
  `{ points, ownsDeck: boolean, ownsTeahouse: boolean, deckLadder: {Rung}, teahouseLadder: {Rung}, deckDisplayOptions: {Opt}, teahouseDisplayOptions: {Opt}, favorites: {string} }`
  where `Rung = { size, owned, isNext, price: number?, affordable: boolean?, locked: boolean }` (locked = teahouse rung above `maxDeckSize`) and `Opt = { value, enabled, selected }`.

- [ ] **Step 1: Write the failing tests** (`roblox/tests/TeahouseMenuModel.spec.luau`)

```lua
--!strict
local harness = require("./harness")
local Model = require("../src/shared/TeahouseMenuModel")
local describe, test, expect = harness.describe, harness.test, harness.expect

local CATALOG = { deck = { S = 50, M = 500, L = 3000 }, teahouse = { S = 30, M = 300, L = 2000 } }
local function state(over)
    local s = { totalPoints = 1000, maxDeckSize = nil, teahouseSizes = {}, deckDisplay = nil,
        teahouseDisplay = nil, padPreferences = {}, catalog = CATALOG }
    for k, v in over do s[k] = v end
    return s
end
local function rung(ladder, size)
    for _, r in ladder do if r.size == size then return r end end
    return nil
end

describe("TeahouseMenuModel.viewModel", function()
    test("non-owner: nothing owned, deck S is next, teahouse locked", function()
        local vm = Model.viewModel(state({}))
        expect(vm.ownsDeck).toBe(false)
        expect(rung(vm.deckLadder, "S").isNext).toBe(true)
        expect(rung(vm.deckLadder, "S").price).toBe(50)
        expect(rung(vm.teahouseLadder, "S").locked).toBe(true) -- needs a deck first
    end)
    test("owned deck M marks S,M owned; L is next; affordability from points", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", totalPoints = 100 }))
        expect(rung(vm.deckLadder, "M").owned).toBe(true)
        expect(rung(vm.deckLadder, "L").isNext).toBe(true)
        expect(rung(vm.deckLadder, "L").affordable).toBe(false) -- 100 < 3000
    end)
    test("teahouse rung locked above the owned deck size", function()
        local vm = Model.viewModel(state({ maxDeckSize = "S", teahouseSizes = {} }))
        expect(rung(vm.teahouseLadder, "S").locked).toBe(false) -- deck S covers teahouse S
        expect(rung(vm.teahouseLadder, "M").locked).toBe(true)
    end)
    test("display options enabled only up to owned; selection reflects state", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = { "S", "M" }, deckDisplay = "S", teahouseDisplay = "none" }))
        local function opt(list, v) for _, o in list do if o.value == v then return o end end return nil end
        expect(opt(vm.deckDisplayOptions, "S").enabled).toBe(true)
        expect(opt(vm.deckDisplayOptions, "L").enabled).toBe(false)
        expect(opt(vm.deckDisplayOptions, "S").selected).toBe(true)
        expect(opt(vm.teahouseDisplayOptions, "none").selected).toBe(true)
        expect(opt(vm.teahouseDisplayOptions, "S").enabled).toBe(true)
        expect(opt(vm.teahouseDisplayOptions, "L").enabled).toBe(false)
    end)
    test("favorites pass through", function()
        local vm = Model.viewModel(state({ padPreferences = { "T05", "T09" } }))
        expect(#vm.favorites).toBe(2)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement** (`roblox/src/shared/TeahouseMenuModel.luau`)

```lua
--!strict
-- Pure view-model for the B3 teahouse HUD panel: turns an echoed economy state into the display
-- data the GUI renders (owned marks, next-tier price + affordability, teahouse-locked-by-deck,
-- enabled display options, favorites). No Roblox datatypes -> Lune-tested. Mirrors the B1/B2
-- pure-editor pattern; the GUI controller only renders what this returns.
local SizeClasses = require("./SizeClasses")

local TeahouseMenuModel = {}
local SIZES = { "S", "M", "L" } -- smallest-first for ladder rendering

local function rankOf(size: string?): number
    return if size ~= nil then SizeClasses.rank[size] else 0
end

local function ownedMax(list: { string }): string?
    local m: string? = nil
    for _, s in list do
        if m == nil or SizeClasses.rank[s] > SizeClasses.rank[m] then
            m = s
        end
    end
    return m
end

function TeahouseMenuModel.viewModel(state: any): any
    local points = state.totalPoints or 0
    local deckRank = rankOf(state.maxDeckSize)
    local owns = {} -- teahouse size -> owned
    for _, s in state.teahouseSizes or {} do
        owns[s] = true
    end
    local teaMax = ownedMax(state.teahouseSizes or {})

    -- deck ladder: owned up to maxDeckSize; the NEXT rung (rank == deckRank+1) is buyable
    local deckLadder = {}
    for _, size in SIZES do
        local r = SizeClasses.rank[size]
        local isNext = r == deckRank + 1
        table.insert(deckLadder, {
            size = size,
            owned = r <= deckRank,
            isNext = isNext,
            price = if isNext then state.catalog.deck[size] else nil,
            affordable = if isNext then points >= state.catalog.deck[size] else nil,
            locked = false,
        })
    end

    -- teahouse ladder: owned per the set; next = smallest unowned in linear order; locked if its
    -- rank exceeds the owned deck (teahouse <= deck)
    local teaLadder = {}
    local teaMaxRank = rankOf(teaMax)
    for _, size in SIZES do
        local r = SizeClasses.rank[size]
        local isNext = r == teaMaxRank + 1
        local locked = r > deckRank -- needs a >= deck
        table.insert(teaLadder, {
            size = size,
            owned = owns[size] == true,
            isNext = isNext and not locked,
            price = if isNext then state.catalog.teahouse[size] else nil,
            affordable = if isNext then points >= state.catalog.teahouse[size] else nil,
            locked = locked,
        })
    end

    -- display options: deck S..maxDeckSize; teahouse none + S..teaMax
    local deckOpts = {}
    for _, size in SIZES do
        table.insert(deckOpts, {
            value = size,
            enabled = SizeClasses.rank[size] <= deckRank,
            selected = state.deckDisplay == size,
        })
    end
    local teaOpts = { { value = "none", enabled = true, selected = state.teahouseDisplay == "none" } }
    for _, size in SIZES do
        table.insert(teaOpts, {
            value = size,
            enabled = SizeClasses.rank[size] <= teaMaxRank,
            selected = state.teahouseDisplay == size,
        })
    end

    local favorites = {}
    for _, id in state.padPreferences or {} do
        table.insert(favorites, id)
    end

    return {
        points = points,
        ownsDeck = deckRank > 0,
        ownsTeahouse = teaMax ~= nil,
        deckLadder = deckLadder,
        teahouseLadder = teaLadder,
        deckDisplayOptions = deckOpts,
        teahouseDisplayOptions = teaOpts,
        favorites = favorites,
    }
end

return TeahouseMenuModel
```

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all PASS/clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/TeahouseMenuModel.luau roblox/tests/TeahouseMenuModel.spec.luau
git commit -m "feat(roblox): TeahouseMenuModel pure view-model for the B3 panel"
```

---

## Task 5: `SetDisplay` remote + handler + display threading (Roblox server)

**Files:**
- Modify: `roblox/default.project.json` (add `SetDisplay` under `RoshamboRemotes`)
- Modify: `roblox/src/server/NetworkClient.luau` (add `postDisplay`, after `postPurchase` at line ~150)
- Modify: `roblox/src/server/main.server.luau` (stash fields; `echoEconomy`; join-fetch; `SetDisplay` handler; thread display into the two `resolveBuilt` call sites — the RequestPurchase upgrade rebuild ~line 674 and the SiteCoordinator via its own change below)
- Modify: `roblox/src/shared/SiteCoordinator.luau` (thread display into its `resolveBuilt` call)

**Interfaces:**
- Consumes: `SizeClasses.resolveBuilt(...,deckDisplay,teahouseDisplay)` (Task 3); `EconomyState` echo payload; `net:getEconomy` (returns `deckDisplay`/`teahouseDisplay` from Task 2).
- Produces: `NetworkClient.postDisplay(self, robloxUserId, deckDisplay, teahouseDisplay)`; a `SetDisplay` RemoteEvent; `playerEconomy[uid].deckDisplay`/`.teahouseDisplay`; `EconomyState` payload gains `deckDisplay`/`teahouseDisplay`.

This task is wiring; correctness is proven by the visual gate (Task 6) plus the pure tests already landed. No new Lune tests, but existing suites must stay green.

- [ ] **Step 1: Register the remote** — in `roblox/default.project.json`, under the `RoshamboRemotes` folder children (alongside `SetBackDoor`/`RequestPurchase`), add:

```json
"SetDisplay": { "$className": "RemoteEvent" }
```

- [ ] **Step 2: `NetworkClient.postDisplay`** — add after `postPurchase` (line ~150) in `NetworkClient.luau`:

```lua
function NetworkClient.postDisplay(self: any, robloxUserId: string, deckDisplay: string?, teahouseDisplay: string?): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/display`, {
        deckDisplay = deckDisplay,
        teahouseDisplay = teahouseDisplay,
    })
end
```

- [ ] **Step 3: Stash + echo the display fields** — in `main.server.luau`:
  - Extend the `playerEconomy` type (line ~393) to add `deckDisplay: string?, teahouseDisplay: string?`.
  - In the join fetch (`playerEconomy[uid] = {...}` near line 465), add `deckDisplay = res.body.deckDisplay, teahouseDisplay = res.body.teahouseDisplay,`.
  - In `echoEconomy` (`EconomyState:FireClient(player, {...})` near line 414) add `deckDisplay = e.deckDisplay, teahouseDisplay = e.teahouseDisplay,`.

- [ ] **Step 4: Thread display into the resolveBuilt call sites**
  - In the RequestPurchase upgrade rebuild (line ~674): change
    `SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize)` →
    `SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)`.
  - In `SiteCoordinator.luau`, wherever `resolveBuilt(maxDeckSize, teahouseSizes, perchMax)` is called, thread the player's `deckDisplay`/`teahouseDisplay` through `onJoin`'s `economy` argument (add them to the `economy` table the caller passes from `main.server.luau`, and forward into `resolveBuilt`). Grep: `grep -n "resolveBuilt" roblox/src/shared/SiteCoordinator.luau roblox/src/server/main.server.luau`.

- [ ] **Step 5: Add the `SetDisplay` handler** — near the other handlers in `main.server.luau` (after the `RequestPurchase` handler), and declare `local SetDisplay = remotes:WaitForChild("SetDisplay") :: RemoteEvent` near line 35:

```lua
SetDisplay.OnServerEvent:Connect(function(player, payload)
    local uid = tostring(player.UserId)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
        return -- must own+occupy a perch to set a display
    end
    local deckDisplay = if typeof(payload) == "table" then payload.deckDisplay else nil
    local teahouseDisplay = if typeof(payload) == "table" then payload.teahouseDisplay else nil
    -- server is authoritative: persist through the PWA API (it re-validates against ownership)
    local res = net:postDisplay(uid, deckDisplay, teahouseDisplay)
    if not res.ok then
        warn(`[B3] postDisplay failed for {uid}: {tostring(res.error)}`)
        echoEconomy(player, uid) -- resync
        return
    end
    if not player:IsDescendantOf(Players) then
        return -- left during the HTTP yield; nothing to rebuild
    end
    e.deckDisplay = res.body.deckDisplay
    e.teahouseDisplay = res.body.teahouseDisplay
    -- live rebuild the claimed pad at the new displayed sizes
    local spec = PadSites[e.claimedPadId]
    if spec then
        local teaSizes = {}
        for s in e.teahouses do
            table.insert(teaSizes, s)
        end
        local built = SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
        if built then
            local teaLoadout = if built.teahouseSize then e.teahouses[built.teahouseSize] else nil
            local teahouse = if built.teahouseSize
                then { size = built.teahouseSize, loadout = teaLoadout, placement = { offset = { 0, 0 }, facing = "N" } }
                else nil
            local treatment = { kind = "structure", loadout = teaLoadout, lit = true }
            applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
        end
    end
    echoEconomy(player, uid)
end)
```

- [ ] **Step 6: Verify build + existing tests**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all green (no new tests; existing suites unaffected). Then a quick Studio smoke-load to confirm `SetDisplay` resolves (no infinite `WaitForChild` — restart `rojo serve` so the new remote reconciles, per the B1/B2 lesson).

- [ ] **Step 7: Commit**

```bash
git add roblox/default.project.json roblox/src/server/NetworkClient.luau roblox/src/server/main.server.luau roblox/src/shared/SiteCoordinator.luau
git commit -m "feat(roblox): SetDisplay remote + handler + display threading through resolveBuilt (B3)"
```

---

## Task 6: `TeahouseController` HUD panel (Roblox client)

**Files:**
- Create: `roblox/src/client/TeahouseController.client.luau`
- (Confirm it is picked up by Rojo — client scripts under `src/client` map to `StarterPlayerScripts`; check `default.project.json`.)

**Interfaces:**
- Consumes: `TeahouseMenuModel.viewModel` (Task 4); `EconomyState`/`PreferenceState`/`BackDoorState` echoes; fires `RequestPurchase` (`{ item = "deck:M" }` etc.), `SetDisplay` (`{ deckDisplay, teahouseDisplay }`), `SetPadPreference` (`siteId` — for *remove* favorite).
- Produces: the HUD button + panel; no exports.

This is GUI, not Lune-testable — build a **functional** panel (real data-binding + remote wiring), and iterate the visual layout in the visual gate (as B2's `EconomyController` was). Steps below give the load-bearing structure; polish is gate-driven.

- [ ] **Step 1: Scaffold the controller** — a `ScreenGui` (ResetOnSpawn=false) with a bottom-corner toggle `TextButton` and a hidden `Frame` panel. Subscribe to state:

```lua
--!strict
-- B3 teahouse management panel. A persistent HUD button opens a panel that renders
-- TeahouseMenuModel over the echoed economy/preference/back-door state, and fires the
-- purchase/display/preference remotes. World prompts (claim, back-door, favorite-add) live on
-- their own controllers; this is the from-anywhere hub for upgrades + display + favorites.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local MenuModel = require(shared:WaitForChild("TeahouseMenuModel"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RequestPurchase = remotes:WaitForChild("RequestPurchase") :: RemoteEvent
local SetDisplay = remotes:WaitForChild("SetDisplay") :: RemoteEvent
local SetPadPreference = remotes:WaitForChild("SetPadPreference") :: RemoteEvent
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local PreferenceState = remotes:WaitForChild("PreferenceState") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent

-- latest merged state fed to MenuModel.viewModel
local econ = { totalPoints = 0, maxDeckSize = nil, teahouseSizes = {}, deckDisplay = nil,
    teahouseDisplay = nil, padPreferences = {}, catalog = { deck = {}, teahouse = {} } }
local backDoorIndex: number? = nil
```

- [ ] **Step 2: Build the panel widgets** — header label (points + perch), a Deck row and Teahouse row of rung buttons, a Deck display row + Teahouse display row of toggle buttons, and a Favorites list container. Store references so `render()` can update them. Keep to the toast palette (`Color3.fromRGB(20,18,16)` bg, `Color3.fromRGB(240,228,205)` text, `UICorner` 8, `Font.Gotham`). Layout via `UIListLayout`. (Exact sizes/positions are gate-tuned.)

- [ ] **Step 3: `render()` from the view-model** — one function that reads `MenuModel.viewModel(econ)` and updates every widget:
  - Header: `vm.points` + perch (from `econ.claimedPadId`).
  - Deck/teahouse rungs: label = `size` + owned ✓ / `— {price} pts` for `isNext` / greyed for `locked`; the `isNext` rung's button enabled iff `affordable`; on click `RequestPurchase:FireServer({ item = "deck:"..size })` (or `teahouse:`).
  - Display rows: each option button shows `selected` state; enabled iff `opt.enabled`; on click, build the new `{deckDisplay, teahouseDisplay}` (change only that dimension, keep the other) and `SetDisplay:FireServer(...)`. First-deck preview: if `not vm.ownsDeck`, show the ladders greyed with a "Claim a free perch to begin" line; hide display rows if `not vm.ownsTeahouse`.
  - Favorites: rebuild the list from `vm.favorites`; each with a ✕ that `SetPadPreference:FireServer(siteId)` (toggles off).
  - Optional read-only "Back door: bay N" line from `backDoorIndex`.

- [ ] **Step 4: Wire the echoes** — each updates `econ`/`backDoorIndex` then calls `render()`:

```lua
EconomyState.OnClientEvent:Connect(function(p)
    econ.totalPoints = p.totalPoints; econ.maxDeckSize = p.maxDeckSize
    econ.teahouseSizes = p.teahouseSizes or {}; econ.claimedPadId = p.claimedPadId
    econ.deckDisplay = p.deckDisplay; econ.teahouseDisplay = p.teahouseDisplay
    if p.catalog then econ.catalog = p.catalog end
    render()
end)
PreferenceState.OnClientEvent:Connect(function(p) econ.padPreferences = p.padPreferences or {}; render() end)
BackDoorState.OnClientEvent:Connect(function(p) backDoorIndex = p.backDoorIndex; render() end)
```

- [ ] **Step 5: Toggle button** opens/closes the panel; `render()` once on open.

- [ ] **Step 6: Visual gate (Studio, user-driven).** Restart `rojo serve` (new `SetDisplay` remote). Play as the seeded owner account; open the panel; verify: points + perch header; buying `deck:M`/`teahouse:M` debits points and live-rebuilds the perch; setting Deck display S + Teahouse display None rebuilds the perch smaller/bare; removing a favorite updates the list; a non-owner sees the greyed preview + "claim a free perch" pointer and can still claim in-world. **One attempt, then stop and show the user** (per the stop-and-ask rule).

- [ ] **Step 7: Commit** (after the gate passes)

```bash
git add roblox/src/client/TeahouseController.client.luau
git commit -m "feat(roblox): TeahouseController HUD management panel (B3)"
```

---

## Task 7: Trim `EconomyController` (Roblox client)

**Files:**
- Modify: `roblox/src/client/EconomyController.client.luau`

**Interfaces:**
- Consumes: nothing new.
- Produces: `EconomyController` now only offers the **vacant-pad buy-to-claim** world prompt; the owner upgrade prompt is gone (moved to the panel).

- [ ] **Step 1: Remove the owner-upgrade branch** — in `offerFor` (the function returning the prompt for a site), delete the owner path so it returns `nil, nil` when `state.maxDeckSize ~= nil` (owner). Keep the non-owner `not occupied → "deck:S", "Buy S deck & claim …"` path. The prompt now only ever appears on vacant sites for non-owners.

- [ ] **Step 2: Remove now-dead code** — any `SizeClasses.nextTier`/`teahouseSizes`/`claimedPadId` logic used only by the deleted upgrade branch. Keep whatever the buy-to-claim path still needs (`state.maxDeckSize`, `catalog`, `priceOf`).

- [ ] **Step 3: Verify build + lint**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run`
Expected: clean/green (no test changes; controller is GUI).

- [ ] **Step 4: Visual gate (with Task 6's).** Confirm: as an owner walking past your own claimed site, **no** G-style upgrade prompt appears (upgrades are panel-only); as a non-owner on a vacant pad, the buy-to-claim prompt still appears and works.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/EconomyController.client.luau
git commit -m "refactor(roblox): EconomyController keeps buy-to-claim only; upgrades move to the panel (B3)"
```

---

## Final: whole-branch review

After Task 7, dispatch the whole-branch review (superpowers:requesting-code-review) over the B3 range (`git merge-base` of the plan-doc commit `..HEAD`) with the spec + these Global Constraints. Then per SDD, finish the branch.
