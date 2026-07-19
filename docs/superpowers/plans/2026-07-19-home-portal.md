# Home Portal (MVP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A purchased home portal linking a player's own deck ↔ the arena — an always-open Arena Portal that sends you to your deck, and a deck railing control you open to step through to the arena — plus the DevChannelSpawn cleanup so everyone arrives at ArenaSpawn.

**Architecture:** The portal is a one-time `portalOwned` boolean bought through the existing RequestPurchase spine. Owning it threads a flag into the deck treatment so `TreatmentApplier` builds a tagged control fixture; a new `PortalController` server module builds the Arena Portal, wires the control's prompt, and does the `PivotTo` teleports. Destinations resolve through a pure `PortalTarget` module (Lune-tested), built forward-compatible for the deferred guest-pass system. Spec: `docs/superpowers/specs/2026-07-19-home-portal-design.md`.

**Tech Stack:** Server = TypeScript + Express + Mongoose, Vitest (`server/`). Roblox = Luau + Rojo, bespoke Lune harness (`roblox/`). Portal geometry + teleport is Roblox-runtime → visual gate.

## Global Constraints

- Portal is item `"portal"` (no size), flat price `PRICES.portal = 500` (placeholder). One-time boolean `portalOwned`; one per player.
- `validatePurchase("portal")`: requires `maxDeckSize !== null` (`NEEDS_DECK`), rejects if already owned (`ALREADY_OWNED`), then the points check.
- **Deck → arena is usable by anyone standing on the deck** (no owner-check — it only sends to the public arena). **Arena → deck sends you to your OWN home** (requires you own a portal + have a claimed perch).
- `portalOwned` threads into the treatment (like `lit`) at **every** `applier:apply` site; `TreatmentApplier` builds the control only when `treatment.portalOwned`.
- Teleport handlers are pure teleports (no DB write) → **not** on the HandlerQueue. The purchase flows through RequestPurchase, which **is** on the HandlerQueue.
- DevChannelSpawn cleanup: disable any SpawnLocation whose name ≠ `ArenaSpawn`; ensure `ArenaSpawn.Enabled = true`. Code-only (DevChannelSpawn is place-only).
- Placeholder art acceptable; art pass deferred. New remote? **No** — reuse RequestPurchase; the control prompt + arena touch are server-side.
- Server tests: `cd server && npm test`. Roblox tests: `cd roblox && lune run tests/run`. Lint: `cd roblox && stylua --check src tests && selene src`. Restart `rojo serve` before the Studio gate (no new remote, but new server modules).

---

## File Structure

- `server/src/economy.ts` (modify) — `portalOwned` in `EconomyState`, `PRICES.portal`, portal branch in `validatePurchase`/`applyPurchase`.
- `server/src/economy.test.ts` (modify) — portal purchase tests.
- `server/src/models/User.ts` (modify) — `portalOwned` field.
- `server/src/routes/apiV1.ts` (modify) — `readEconomy` + `GET /economy` + purchase route echo `portalOwned`.
- `server/src/routes/apiV1.test.ts` (modify) — route tests.
- `roblox/src/shared/PortalTarget.luau` (create) — pure destination resolver.
- `roblox/tests/PortalTarget.spec.luau` (create) — Lune tests.
- `roblox/src/server/main.server.luau` (modify) — `e.portalOwned` + thread into treatments + `echoEconomy` payload; wire `PortalController`; DevChannelSpawn cleanup.
- `roblox/src/server/TreatmentApplier.luau` (modify) — build + tag the deck control when `treatment.portalOwned`.
- `roblox/src/server/PortalController.luau` (create) — arena portal build + touch→home; deck-control tag-watch + open→walk-through→arena.
- `roblox/src/shared/TeahouseMenuModel.luau` (modify) — portal buyable in the view-model.
- `roblox/tests/TeahouseMenuModel.spec.luau` (modify) — portal-buyable tests.
- `roblox/src/client/TeahouseController.client.luau` (modify) — portal buy row.

---

## Task 1: Economy — `portalOwned` + portal purchase (server, Vitest TDD)

**Files:**
- Modify: `server/src/economy.ts` (`EconomyState` line 9; `PRICES` line 3; `validatePurchase` line 15; `applyPurchase` line 38)
- Test: `server/src/economy.test.ts`

**Interfaces:**
- Produces: `EconomyState` gains optional `portalOwned?: boolean`; `PRICES.portal: number`; `validatePurchase(state, "portal")` and `applyPurchase(state, "portal")` handle the portal item.

- [ ] **Step 1: Write the failing tests** (append to `server/src/economy.test.ts`; import `validatePurchase`, `applyPurchase`, `PRICES` from `./economy` if not already)

```ts
describe('portal purchase', () => {
  const base = (over: Partial<EconomyState> = {}): EconomyState =>
    ({ totalPoints: 1000, maxDeckSize: 'S', teahouseSizes: [], portalOwned: false, ...over });

  it('accepts a portal when a deck is owned and affordable', () => {
    expect(validatePurchase(base(), 'portal')).toEqual({ ok: true, cost: PRICES.portal });
  });
  it('rejects a portal with no deck', () => {
    expect(validatePurchase(base({ maxDeckSize: null }), 'portal')).toEqual({ ok: false, error: 'NEEDS_DECK' });
  });
  it('rejects a portal already owned', () => {
    expect(validatePurchase(base({ portalOwned: true }), 'portal')).toEqual({ ok: false, error: 'ALREADY_OWNED' });
  });
  it('rejects a portal when too poor', () => {
    expect(validatePurchase(base({ totalPoints: 0 }), 'portal')).toEqual({ ok: false, error: 'INSUFFICIENT_POINTS' });
  });
  it('applyPurchase sets portalOwned and spends the cost', () => {
    const after = applyPurchase(base({ totalPoints: 700 }), 'portal');
    expect(after.portalOwned).toBe(true);
    expect(after.totalPoints).toBe(700 - PRICES.portal);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `cd server && npx vitest run src/economy.test.ts`
Expected: FAIL — portal treated as `BAD_ITEM`.

- [ ] **Step 3: Implement** — in `server/src/economy.ts`:

Add to `PRICES` (after the `teahouse` line, ~line 5):

```ts
    portal: 500,
```

Extend `EconomyState` (line 9):

```ts
export type EconomyState = { totalPoints: number; maxDeckSize: Size | null; teahouseSizes: Size[]; portalOwned?: boolean };
```

In `validatePurchase`, add a portal branch at the very top of the function body (before the `item.split` line at 16):

```ts
    if (item === 'portal') {
        if (state.maxDeckSize === null) return { ok: false, error: 'NEEDS_DECK' };
        if (state.portalOwned) return { ok: false, error: 'ALREADY_OWNED' };
        if (state.totalPoints < PRICES.portal) return { ok: false, error: 'INSUFFICIENT_POINTS' };
        return { ok: true, cost: PRICES.portal };
    }
```

In `applyPurchase`, handle portal before the `item.split` (after the `chk` guard, ~line 41). Replace the `next` construction so `portalOwned` carries through and portal sets it:

```ts
    const next: EconomyState = {
        totalPoints: state.totalPoints - chk.cost,
        maxDeckSize: state.maxDeckSize,
        teahouseSizes: [...state.teahouseSizes],
        portalOwned: state.portalOwned ?? false,
    };
    if (item === 'portal') {
        next.portalOwned = true;
        return next;
    }
    const [kind, size] = item.split(':') as [string, Size];
    if (kind === 'deck') next.maxDeckSize = size;
    else next.teahouseSizes.push(size);
    return next;
```

- [ ] **Step 4: Run to verify pass**

Run: `cd server && npm test`
Expected: PASS (all suites).

- [ ] **Step 5: Commit**

```bash
git add server/src/economy.ts server/src/economy.test.ts
git commit -m "feat(server): portal purchase item + portalOwned in economy (home portal)"
```

---

## Task 2: `User.portalOwned` + routes echo it (server, Vitest TDD)

**Files:**
- Modify: `server/src/models/User.ts` (interface ~line 24; schema ~line 51)
- Modify: `server/src/routes/apiV1.ts` (`readEconomy` line 138; `GET /economy` line 153; purchase route line 168)
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `validatePurchase`/`applyPurchase` portal handling (Task 1).
- Produces: `User.portalOwned: boolean`; `GET /economy` returns `portalOwned`; the purchase response includes `portalOwned`.

- [ ] **Step 1: Add the `User` field** — in `server/src/models/User.ts`, add to `IUser` after `maxDeckSize`/`deckDisplay` (~line 25):

```ts
    portalOwned: boolean;
```

and to the schema after the `deckDisplay` field (~line 52):

```ts
    portalOwned: { type: Boolean, default: false },
```

- [ ] **Step 2: Write the failing route tests** (append to `server/src/routes/apiV1.test.ts`, mirroring the existing economy/purchase test setup — reuse its `makeApp`/`API_KEY`/`request`/`User` imports + reset)

```ts
  it('GET economy returns portalOwned (false by default)', async () => {
    await User.create({ robloxId: 'p_portal1', totalPoints: 0, maxDeckSize: 'S' });
    const res = await request(app).get('/api/v1/players/p_portal1/economy').set('X-API-Key', API_KEY);
    expect(res.status).toBe(200);
    expect(res.body.portalOwned).toBe(false);
    expect(res.body.catalog.portal).toBe(500);
  });
  it('POST purchase portal persists portalOwned and echoes it', async () => {
    await User.create({ robloxId: 'p_portal2', totalPoints: 1000, maxDeckSize: 'S' });
    const res = await request(app).post('/api/v1/players/p_portal2/purchase').set('X-API-Key', API_KEY).send({ item: 'portal' });
    expect(res.status).toBe(200);
    expect(res.body.portalOwned).toBe(true);
    const u = await User.findOne({ robloxId: 'p_portal2' });
    expect(u?.portalOwned).toBe(true);
  });
```

(If the test file constructs `app` per-test or names the key differently, mirror the existing economy-route tests exactly.)

- [ ] **Step 3: Run to verify failure**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: FAIL — `portalOwned` undefined / `catalog.portal` undefined.

- [ ] **Step 4: Implement** — in `server/src/routes/apiV1.ts`:

Extend `readEconomy`'s param type + body (line 138) so it carries `portalOwned`:

```ts
    const readEconomy = (user: { totalPoints: number; maxDeckSize: Size | null; teahouses?: Map<string, unknown>; portalOwned?: boolean }): EconomyState => ({
        totalPoints: user.totalPoints,
        maxDeckSize: user.maxDeckSize,
        teahouseSizes: (user.teahouses ? Array.from(user.teahouses.keys()) : []) as Size[],
        portalOwned: user.portalOwned ?? false,
    });
```

In `GET /economy`'s `res.json({...})` (line 153), add:

```ts
                portalOwned: st.portalOwned ?? false,
```

In the purchase route (line 177-185), persist + echo `portalOwned`:

```ts
            const after = applyPurchase(before, item);
            user.totalPoints = after.totalPoints;
            user.maxDeckSize = after.maxDeckSize;
            user.portalOwned = after.portalOwned ?? false;
            const [kind, size] = item.split(':') as [string, Size];
            if (kind === 'teahouse') {
                (user.teahouses as Map<string, unknown>).set(size, { ...DEFAULT_TEAHOUSE_LOADOUT });
            }
            await user.save();
            res.json({ item, totalPoints: after.totalPoints, maxDeckSize: after.maxDeckSize, teahouseSizes: after.teahouseSizes, portalOwned: after.portalOwned ?? false });
```

(The `[kind, size]` split on `"portal"` yields `kind = "portal"`, `size = undefined`; the `teahouse` branch is skipped — no change needed there.)

- [ ] **Step 5: Run to verify pass**

Run: `cd server && npm test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add server/src/models/User.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): persist + echo portalOwned in economy routes (home portal)"
```

---

## Task 3: `PortalTarget` pure destination resolver (Roblox, Lune TDD)

**Files:**
- Create: `roblox/src/shared/PortalTarget.luau`
- Test: `roblox/tests/PortalTarget.spec.luau`

**Interfaces:**
- Produces:
  - `PortalTarget.DECK_LANDING_LOCAL: { [string]: { number } }` — per-size `{dx,dy,dz}` local landing offset (gate-tuned; placeholder identical across sizes for now).
  - `PortalTarget.deckLanding(deckCF12: { number }, deckSize: string): { number }` — the deck datum CFrame (12-number, row-major) composed with the size's local offset (offset rotated by the deck's rotation, added to its position; rotation preserved). Returns 12-number CFrame components. **Forward-compat:** resolves from a pad's `deckCF12` — a future guest pass passes a friend's pad.
  - `PortalTarget.ARENA_PORTAL_CF: { number }` — where the Arena Portal structure builds (gate-tuned placeholder near ArenaSpawn).
  - `PortalTarget.ARENA_LANDING: { number }` — the arrival CFrame beside the arena portal (gate-tuned).

- [ ] **Step 1: Write the failing tests** (`roblox/tests/PortalTarget.spec.luau`)

```lua
--!strict
local harness = require("./harness")
local PortalTarget = require("../src/shared/PortalTarget")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("PortalTarget.deckLanding", function()
    test("identity rotation: landing = deck position + the size's local offset", function()
        local deckCF = { 10, 200, -5, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local r = PortalTarget.deckLanding(deckCF, "L")
        local o = PortalTarget.DECK_LANDING_LOCAL.L
        expect(r[1]).toBeCloseTo(10 + o[1])
        expect(r[2]).toBeCloseTo(200 + o[2])
        expect(r[3]).toBeCloseTo(-5 + o[3])
        expect(r[4]).toBeCloseTo(1) -- rotation preserved
        expect(r[12]).toBeCloseTo(1)
    end)
    test("rotates the local offset by the deck's yaw (90deg)", function()
        -- yaw 90: rotation rows r00=0,r02=1 ; r20=-1,r22=0 (matches BuildingPlacer's convention)
        local deckCF = { 0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local r = PortalTarget.deckLanding(deckCF, "L")
        local o = PortalTarget.DECK_LANDING_LOCAL.L
        expect(r[1]).toBeCloseTo(o[3]) -- wx = r02*oz = oz
        expect(r[3]).toBeCloseTo(-o[1]) -- wz = r20*ox = -ox
    end)
    test("all three sizes resolve", function()
        local deckCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        for _, s in { "S", "M", "L" } do
            expect(#PortalTarget.deckLanding(deckCF, s)).toBe(12)
        end
    end)
end)

describe("PortalTarget arena constants", function()
    test("ARENA_PORTAL_CF and ARENA_LANDING are 12-number CFrames", function()
        expect(#PortalTarget.ARENA_PORTAL_CF).toBe(12)
        expect(#PortalTarget.ARENA_LANDING).toBe(12)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement** (`roblox/src/shared/PortalTarget.luau`)

```lua
--!strict
-- Pure destination resolver for the home portal (2026-07-19 spec). No Roblox datatypes (the
-- runtime composes CFrames from these 12-number arrays where CFrame exists) -> Lune-testable.
-- Forward-compat: deckLanding resolves from a pad's deck CFrame, so a future guest pass supplies a
-- friend's pad and gets the same resolution; ARENA_LANDING is a single destination that later
-- becomes a parameter without reworking callers.
local PortalTarget = {}

-- local {dx,dy,dz} where a portal arrival stands ON the deck: up to HRP height, back toward the
-- walkable centre, facing the deck's forward (= the view). Gate-tuned; placeholder identical per
-- size for now (per-size tuning waits for the visual gate).
PortalTarget.DECK_LANDING_LOCAL = {
    S = { 0, 3, -4 },
    M = { 0, 3, -4 },
    L = { 0, 3, -4 },
} :: { [string]: { number } }

-- Where the Arena Portal structure builds, and where arrivals land beside it. Gate-tuned
-- placeholders near ArenaSpawn (dialed in during the visual gate).
PortalTarget.ARENA_PORTAL_CF = { 0, 30, 40, 1, 0, 0, 0, 1, 0, 0, 0, 1 } :: { number }
PortalTarget.ARENA_LANDING = { 0, 30, 46, 1, 0, 0, 0, 1, 0, 0, 0, 1 } :: { number }

function PortalTarget.deckLanding(deckCF12: { number }, deckSize: string): { number }
    local o = PortalTarget.DECK_LANDING_LOCAL[deckSize] or PortalTarget.DECK_LANDING_LOCAL.L
    local px, py, pz = deckCF12[1], deckCF12[2], deckCF12[3]
    local r00, r01, r02 = deckCF12[4], deckCF12[5], deckCF12[6]
    local r10, r11, r12 = deckCF12[7], deckCF12[8], deckCF12[9]
    local r20, r21, r22 = deckCF12[10], deckCF12[11], deckCF12[12]
    -- world = deckPos + deckRot * localOffset (offset has identity rotation, so only its
    -- translation is rotated); the deck's rotation is preserved so the arrival faces the view.
    local wx = px + r00 * o[1] + r01 * o[2] + r02 * o[3]
    local wy = py + r10 * o[1] + r11 * o[2] + r12 * o[3]
    local wz = pz + r20 * o[1] + r21 * o[2] + r22 * o[3]
    return { wx, wy, wz, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

return PortalTarget
```

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all PASS/clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/PortalTarget.luau roblox/tests/PortalTarget.spec.luau
git commit -m "feat(roblox): PortalTarget pure destination resolver (home portal)"
```

---

## Task 4: Thread `portalOwned` server-side + build the deck control (Roblox server)

**Files:**
- Modify: `roblox/src/server/main.server.luau` (`playerEconomy` type ~line 407; join fetch ~line 504; purchase response ~line 696; `echoEconomy` ~line 437; the treatment tables at every `applier:apply` site)
- Modify: `roblox/src/server/TreatmentApplier.luau` (`apply` commit ~line 182; `_buildBuilding` region)

**Interfaces:**
- Consumes: the purchase-route `portalOwned` echo (Task 2).
- Produces: `playerEconomy[uid].portalOwned`; `treatment.portalOwned` at every build site; `EconomyState` payload gains `portalOwned`; `TreatmentApplier` builds + tags a `PortalControl` fixture (attribute `padId`) when `treatment.portalOwned` is true.

This is Roblox-runtime wiring — verification is: Lune suite stays green, `rojo build` succeeds, stylua/selene clean. The control-appears behavior is confirmed at the Task 6 combined gate.

- [ ] **Step 1: Stash `portalOwned`** — in `main.server.luau`:
  - Add `portalOwned: boolean,` to the `playerEconomy` value type (~line 407, alongside `deckDisplay`).
  - In the join fetch (`playerEconomy[uid] = {...}` ~line 504), add `portalOwned = (ecoData and ecoData.portalOwned) or false,`.
  - In the purchase handler, after `e.maxDeckSize = res.data.maxDeckSize` (~line 697), add `e.portalOwned = res.data.portalOwned or false`.

- [ ] **Step 2: Echo it** — in `echoEconomy` (`EconomyState:FireClient(player, {...})` ~line 437), add `portalOwned = e.portalOwned,`.

- [ ] **Step 3: Thread into every treatment** — each `local treatment = { kind = "structure", loadout = ..., lit = true }` in `main.server.luau` (the upgrade rebuild ~line 774, the SetDisplay rebuild ~line 843, the SetPlacement rebuild ~line 957) gains `portalOwned = e.portalOwned,`. Also the join/buy-to-claim path builds its treatment via `VacantState.resolve` (in `SiteCoordinator`) — thread `portalOwned` through there: in `main.server.luau`'s join handler and `RequestPurchase` buy-to-claim, after computing the action, set `action.treatment.portalOwned = playerEconomy[uid].portalOwned` before `applier:apply(action.padId, action.spec, action.treatment, ...)`. (The vacant/dormant treatments for unclaimed pads keep `portalOwned = nil`, i.e. no control.) Grep to find all `applier:apply(` sites and ensure each `treatment` carries `portalOwned`.

- [ ] **Step 4: Build + tag the control** — in `TreatmentApplier.luau`, add a private helper and call it from `apply` after the building step (before the commit swap ~line 155, so the control stages with the deck):

```lua
-- The home-portal deck control: a small tagged fixture on the deck railing (placeholder art).
-- Built only for an owner's lit deck that has the portal; PortalController wires its prompt.
function TreatmentApplier:_buildPortalControl(padId: string, deckCF12: { number }, staging: Instance)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    local control = Instance.new("Part")
    control.Name = "PortalControl"
    control.Size = Vector3.new(1.5, 3, 0.5)
    control.Anchored = true
    control.CanCollide = false
    control.Color = Color3.fromRGB(120, 90, 200)
    control.Material = Enum.Material.Neon
    -- deck-relative railing spot (gate-tuned placeholder): front-right of the deck, on the surface
    control.CFrame = deckCF * CFrame.new(6, 1.5, -6)
    control:SetAttribute("padId", padId)
    control:AddTag("PortalControl")
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Open portal"
    prompt.ObjectText = "To arena"
    prompt.KeyboardKeyCode = Enum.KeyCode.G
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = control
    control.Parent = staging
end
```

Then in `apply`, after the `_buildBuilding` pcall block and before the commit loop (~line 154), add:

```lua
    if treatment.portalOwned == true then
        local okPortal, portalErr = pcall(function()
            self:_buildPortalControl(padId, deckCF12, staging)
        end)
        if not okPortal then
            warn(`[HP] portal control build failed for {padId}: {portalErr}`)
        end
    end
```

(`deckCF12` is the resolved deck placement already in scope in `apply`; reuse it.)

- [ ] **Step 5: Verify build + suites + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src && rojo build -o /tmp/hp-check.rbxl && rm -f /tmp/hp-check.rbxl`
Expected: Lune green (unchanged count), stylua/selene clean, `rojo build` succeeds.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/main.server.luau roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): thread portalOwned into the build; TreatmentApplier stages the deck portal control (home portal)"
```

---

## Task 5: Portal buy row — view-model + panel (Roblox, Lune TDD + GUI)

**Files:**
- Modify: `roblox/src/shared/TeahouseMenuModel.luau` (return table ~line 115)
- Test: `roblox/tests/TeahouseMenuModel.spec.luau`
- Modify: `roblox/src/client/TeahouseController.client.luau` (`econ` stash ~line 45; catalog type ~line 54; `EconomyState` handler; a new buy row + `render`)

**Interfaces:**
- Consumes: `state.portalOwned`, `state.catalog.portal`, `state.claimed`, `state.maxDeckSize`, `state.totalPoints` (the echo carries `portalOwned` from Task 4).
- Produces: `vm.portal = { owned: boolean, price: number?, affordable: boolean?, canBuy: boolean }` — `canBuy` true iff claimed AND owns a deck AND not owned AND affordable. The panel fires `RequestPurchase { item = "portal" }`.

- [ ] **Step 1: Write the failing view-model tests** (append a `describe` to `roblox/tests/TeahouseMenuModel.spec.luau`; the file's `state(over)` helper builds the input — pass `portalOwned`, `catalog`, etc. Ensure the helper's default `catalog` includes `portal` — if the helper hardcodes a catalog without `portal`, pass a `catalog` override in these tests.)

```lua
describe("TeahouseMenuModel.portal", function()
    local CAT = { deck = { S = 50, M = 500, L = 3000 }, teahouse = { S = 30, M = 300, L = 2000 }, portal = 500 }
    test("claimed deck-owner who can afford and doesn't own it can buy", function()
        local vm = Model.viewModel(state({ maxDeckSize = "S", claimed = true, totalPoints = 500, portalOwned = false, catalog = CAT }))
        expect(vm.portal.owned).toBe(false)
        expect(vm.portal.price).toBe(500)
        expect(vm.portal.canBuy).toBe(true)
    end)
    test("already owned -> not buyable", function()
        local vm = Model.viewModel(state({ maxDeckSize = "S", claimed = true, totalPoints = 500, portalOwned = true, catalog = CAT }))
        expect(vm.portal.owned).toBe(true)
        expect(vm.portal.canBuy).toBe(false)
    end)
    test("too poor -> not buyable", function()
        local vm = Model.viewModel(state({ maxDeckSize = "S", claimed = true, totalPoints = 0, portalOwned = false, catalog = CAT }))
        expect(vm.portal.affordable).toBe(false)
        expect(vm.portal.canBuy).toBe(false)
    end)
    test("unclaimed -> not buyable", function()
        local vm = Model.viewModel(state({ maxDeckSize = "S", claimed = false, totalPoints = 500, portalOwned = false, catalog = CAT }))
        expect(vm.portal.canBuy).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `vm.portal` nil.

- [ ] **Step 3: Implement the view-model** — in `TeahouseMenuModel.viewModel`, before the `return {` (~line 115), add:

```lua
    -- home portal: a one-time buy for a claimed deck-owner who doesn't already own it
    local portalPrice = state.catalog.portal
    local portalOwned = state.portalOwned == true
    local portalAffordable = if portalPrice ~= nil then points >= portalPrice else false
    local portalCanBuy = state.claimed == true and ownsDeck and not portalOwned and portalAffordable
    local portal = {
        owned = portalOwned,
        price = portalPrice,
        affordable = portalAffordable,
        canBuy = portalCanBuy,
    }
```

and add `portal = portal,` to the returned table.

- [ ] **Step 4: Run to verify the view-model passes + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: PASS/clean.

- [ ] **Step 5: Panel buy row** (GUI — no unit test; lint + the combined gate verify it). In `TeahouseController.client.luau`:
  - Add `portal = 0` to the `econ.catalog` type/init (~line 54): change the annotation to `{ deck: {...}, teahouse: {...}, portal: number }` and ensure the `EconomyState` handler copies `p.catalog` wholesale (it already assigns `econ.catalog = p.catalog` — verify; if it rebuilds the catalog field-by-field, add `portal`).
  - In the `EconomyState.OnClientEvent` handler, stash `econ.portalOwned = p.portalOwned` (add a `portalOwned` field to the `econ` table init ~line 45, default `false`).
  - Build a `TextButton` `portalButton` (Name `"PortalButton"`) styled like the ladder/move buttons (toast palette, `UICorner` 8, `Font.Gotham`), `LayoutOrder` between the move button (72) and the shown-smaller hint (75) — e.g. `73`. On click:

```lua
portalButton.MouseButton1Click:Connect(function()
    if currentPortalCanBuy then
        RequestPurchase:FireServer({ item = "portal" })
    end
end)
```

  - In `render()`, from `vm.portal`: set `currentPortalCanBuy = vm.portal.canBuy`; label = `vm.portal.owned` → `"Home Portal ✓"`, else `` `Home Portal — {vm.portal.price} pts` ``; enabled/coloring mirrors the display-row buttons' enabled/disabled idiom (Active + TextColor3), enabled iff `vm.portal.canBuy`. Hide the button (`Visible = false`) when `not vm.ownsDeck` (nothing to attach a portal to), consistent with how the other owner-only rows gate. Declare `local currentPortalCanBuy = false` with the other mirror-state vars (~line 45-67).

- [ ] **Step 6: Verify lint + suites**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run`
Expected: clean/green.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/TeahouseMenuModel.luau roblox/tests/TeahouseMenuModel.spec.luau roblox/src/client/TeahouseController.client.luau
git commit -m "feat(roblox): home-portal buy row in the teahouse panel + view-model flag"
```

---

## Task 6: `PortalController` — arena portal, teleports, spawn cleanup (Roblox server, gate-driven)

**Files:**
- Create: `roblox/src/server/PortalController.luau`
- Modify: `roblox/src/server/main.server.luau` (require + instantiate near the other server modules; wire the DevChannelSpawn cleanup at startup)

**Interfaces:**
- Consumes: `PortalTarget` (Task 3); the tagged `PortalControl` fixtures (Task 4); `playerEconomy[uid]` (`portalOwned`, `claimedPadId`) + `PadSites[padId].deckPlacements` + the built deck size; `SizeClasses.resolveBuilt` for the current deck size.
- Produces: the Arena Portal structure + both teleport flows; the spawn cleanup.

Roblox-runtime — verified by the Lune suite staying green, `rojo build`, and the **visual gate**. `PortalController` is dependency-injected (like the other server modules) so `main.server` stays the composition root.

- [ ] **Step 1: Scaffold `PortalController`** with an injected dependency table (mirrors how `main.server` builds `deps` for other modules). It needs: `players` (Players service), `workspace`, `portalTarget` (the module), and reader callbacks `getEconomy(uid) -> {portalOwned, claimedPadId}?` and `deckCFForClaim(uid) -> ({number}, string)?` (returns the claimed pad's deck CFrame + built deck size, or nil). Keeping these as injected callbacks avoids `PortalController` reaching into `main.server`'s stashes directly.

```lua
--!strict
-- Home portal runtime (2026-07-19 spec): builds the always-open Arena Portal (walk in -> your own
-- deck) and wires each tagged deck PortalControl (open -> a passable threshold -> step through to
-- the arena). Pure teleports (PivotTo), no DB writes, so NOT on the HandlerQueue. Deck->arena is
-- usable by anyone on the deck; arena->deck sends you to YOUR own home only.
local CollectionService = game:GetService("CollectionService")

local PortalController = {}
PortalController.__index = PortalController

export type Deps = {
    players: Players,
    portalTarget: any,
    getEconomy: (uid: string) -> { portalOwned: boolean, claimedPadId: string? }?,
    deckCFForClaim: (uid: string) -> ({ number }?, string?), -- (deckCF12, deckSize); nil,nil if no claim
}

function PortalController.new(deps: Deps)
    return setmetatable({ _d = deps, _openThresholds = {} :: { [Instance]: boolean } }, PortalController)
end
```

- [ ] **Step 2: Build the Arena Portal + touch→home.** A method `PortalController:buildArena()` that creates a passable portal part at `portalTarget.ARENA_PORTAL_CF`, parents it in `workspace` (persistent), and connects `Touched`:

```lua
function PortalController:buildArena()
    local pt = self._d.portalTarget
    local portal = Instance.new("Part")
    portal.Name = "ArenaPortal"
    portal.Anchored = true
    portal.CanCollide = false
    portal.Size = Vector3.new(6, 10, 1)
    portal.Color = Color3.fromRGB(120, 90, 200)
    portal.Material = Enum.Material.Neon
    portal.CFrame = CFrame.new(table.unpack(pt.ARENA_PORTAL_CF))
    portal.Parent = workspace
    local debounce: { [Player]: boolean } = {}
    portal.Touched:Connect(function(hit)
        local player = self._d.players:GetPlayerFromCharacter(hit.Parent)
        if player == nil or debounce[player] then
            return
        end
        local eco = self._d.getEconomy(tostring(player.UserId))
        if eco == nil or not eco.portalOwned or eco.claimedPadId == nil then
            return -- landmark for non-owners; only home-portal owners travel
        end
        local deckCF12, deckSize = self._d.deckCFForClaim(tostring(player.UserId))
        if deckCF12 == nil or deckSize == nil then
            return
        end
        debounce[player] = true
        local char = player.Character
        if char then
            char:PivotTo(CFrame.new(table.unpack(pt.deckLanding(deckCF12, deckSize))))
        end
        task.delay(1, function()
            debounce[player] = nil
        end)
    end)
end
```

(`deckCFForClaim` multi-returns `(deckCF12, deckSize)` or `nil, nil` — captured as two locals here and returned that way in Step 5.)

- [ ] **Step 3: Wire deck controls (open → walk-through → arena).** A method `PortalController:bindControls()` that, via `CollectionService:GetInstanceAddedSignal("PortalControl")` + the existing tagged set, connects each control's `ProximityPrompt.Triggered`:

```lua
function PortalController:_bindControl(control: Instance)
    local prompt = control:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt == nil then
        return
    end
    prompt.Triggered:Connect(function(player)
        -- anyone standing on the deck may open it (deck -> public arena is not privileged)
        self:_openThreshold(control, player)
    end)
end

function PortalController:_openThreshold(control: Instance, opener: Player)
    if not control:IsA("BasePart") then
        return
    end
    if self._openThresholds[control] then
        return -- already open
    end
    local pt = self._d.portalTarget
    local threshold = Instance.new("Part")
    threshold.Name = "PortalThreshold"
    threshold.Anchored = true
    threshold.CanCollide = false
    threshold.Size = Vector3.new(4, 7, 1)
    threshold.Color = Color3.fromRGB(150, 120, 230)
    threshold.Material = Enum.Material.ForceField
    threshold.CFrame = (control :: BasePart).CFrame * CFrame.new(0, 2, -2)
    threshold.Parent = workspace
    self._openThresholds[control] = true
    local conn
    conn = threshold.Touched:Connect(function(hit)
        local player = self._d.players:GetPlayerFromCharacter(hit.Parent)
        if player == nil then
            return
        end
        local char = player.Character
        if char then
            char:PivotTo(CFrame.new(table.unpack(pt.ARENA_LANDING)))
        end
        conn:Disconnect()
        threshold:Destroy()
        self._openThresholds[control] = nil
    end)
    task.delay(12, function()
        if self._openThresholds[control] then
            conn:Disconnect()
            threshold:Destroy()
            self._openThresholds[control] = nil
        end
    end)
end

function PortalController:bindControls()
    for _, control in CollectionService:GetTagged("PortalControl") do
        self:_bindControl(control)
    end
    CollectionService:GetInstanceAddedSignal("PortalControl"):Connect(function(control)
        self:_bindControl(control)
    end)
end
```

- [ ] **Step 4: Start method** — `PortalController:start()` calls `self:buildArena()` and `self:bindControls()`. `return PortalController` at the end of the file.

- [ ] **Step 5: Wire into `main.server.luau`** — require it with the other server modules (~line 8):

```lua
local PortalController = require(script.Parent:WaitForChild("PortalController"))
```

After the economy stashes + `SizeClasses`/`PadSites` are in scope (near the other startup wiring, after the handlers are defined is fine), instantiate + start it with callbacks that read the existing stashes:

```lua
local portalController = PortalController.new({
    players = Players,
    portalTarget = PortalTarget,
    getEconomy = function(uid)
        local e = playerEconomy[uid]
        if e == nil then
            return nil
        end
        return { portalOwned = e.portalOwned == true, claimedPadId = e.claimedPadId }
    end,
    deckCFForClaim = function(uid)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil then
            return nil
        end
        local spec = PadSites[e.claimedPadId]
        if spec == nil then
            return nil
        end
        local teaSizes = {}
        for s in e.teahouses do
            table.insert(teaSizes, s)
        end
        local built = SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
        if built == nil then
            return nil
        end
        return spec.deckPlacements[built.deckSize], built.deckSize
    end,
})
portalController:start()
```

Add `local PortalTarget = require(shared:WaitForChild("PortalTarget"))` with the other `shared` requires (~line 18). (`deckCFForClaim` multi-returns `(deckCF12, deckSize)`, matching Step 2's `local deckCF12, deckSize = ...` capture; the `built == nil` / no-claim paths `return nil` — a bare `return` yields `nil, nil`.)

- [ ] **Step 6: DevChannelSpawn cleanup** — add a startup routine in `main.server.luau` (near the other workspace setup, after `Players` is required):

```lua
-- Everyone arrives at ArenaSpawn: disable any other (place-only, e.g. leftover DevChannelSpawn)
-- SpawnLocation, and make sure ArenaSpawn itself is enabled. Code-only + self-healing.
for _, inst in workspace:GetDescendants() do
    if inst:IsA("SpawnLocation") then
        inst.Enabled = inst.Name == "ArenaSpawn"
    end
end
```

(If `ArenaSpawn` may stream in late, also connect `workspace.DescendantAdded` for `SpawnLocation` and apply the same rule — but ArenaSpawn is under the persistent `RoshamboStage`, so the startup sweep suffices; add the watcher only if the gate shows a stray spawn slipping through.)

- [ ] **Step 7: Verify build + suites + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src && rojo build -o /tmp/hp-check.rbxl && rm -f /tmp/hp-check.rbxl`
Expected: Lune green (unchanged), stylua/selene clean, `rojo build` succeeds.

- [ ] **Step 8: Commit**

```bash
git add roblox/src/server/PortalController.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): PortalController arena portal + deck-control teleports; ArenaSpawn cleanup (home portal)"
```

- [ ] **Step 9: Visual gate (Studio, user-driven).** Push the branch first (the purchase persists `portalOwned` through `/purchase`, which 400s on the stale dev backend until it redeploys — same trap as B1/B3/B4), then restart `rojo serve` and Play as the seeded owner. Verify: the "Home Portal" buy row appears (claimed owner), buying it debits points and a control fixture appears on the deck railing; the control survives a display/size/move rebuild; interacting with the control opens a threshold you step through to arrive at the arena; walking into the Arena Portal drops you on your own deck; a non-owner gets nothing at the Arena Portal but CAN use a deck control they're standing on; players spawn at ArenaSpawn (no DevChannelSpawn). Placeholder art is fine — note art/placement tuning for a follow-up. **One attempt, then stop and show the user.**

---

## Final: whole-branch review

After Task 6's gate, dispatch the whole-branch review (superpowers:requesting-code-review) over the range (spec commit `13a6cb9`..HEAD) with the spec + these Global Constraints. Then per SDD, finish the branch.
