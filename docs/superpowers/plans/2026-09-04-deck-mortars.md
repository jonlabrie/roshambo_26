# Deck Mortars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Owned mortars appear on the player's deck at front-edge defaults, are movable through the back-door editor, and gear-requiring shells launch from the required tier's muzzle.

**Architecture:** Persistence mirrors `deckDecorations` (`User.mortarPlacements` + a validated PUT); a pure `MortarPlacement.luau` resolves defaults/overrides/clamps/nudges and the muzzle's world position; the Studio server extends the decoration state flow and swaps the deck-launch origin; the client renders tubes in the decoration rebuild pass and the back-door editor gains a move-only mortar flow.

**Tech Stack:** TypeScript + Vitest (`server/`), Luau (strict) + Lune harness (`roblox/`), Mongo via the existing User model.

**Spec:** `docs/superpowers/specs/2026-09-04-deck-mortars-design.md`

## Global Constraints

- **Default-first** (owner ruling): owning a mortar renders it at its default spot with zero player action; placement is optional depth.
- **One tube per owned tier**, S/M/L staggered along the deck's canyon-facing front edge; **gear exempt from `MAX_DECORATIONS = 24`**.
- Gear-requiring shells launch from the REQUIRED tier's muzzle; `firecracker` (`kind = 'none'`) stays hand-launched; public sites unchanged.
- Mortars never hide under the built teahouse (unlike decorations) — overlapped spots NUDGE to the nearest clear front-edge position. Stored placements are never mutated; only what renders adapts (the DecorationLayout philosophy).
- Deck-local coordinate + `Facing = 'N'|'E'|'S'|'W'` conventions identical to `DeckDecoration`.
- Mortar ids are exactly `'mortar:S' | 'mortar:M' | 'mortar:L'` (`MORTAR_IDS` in `server/src/fireworks.ts`); the Luau mirror carries the TS<->Luau drift caveat comment like `DecorationCatalog` does.
- Shared Luau modules are pure `--!strict`, Lune-loadable. Lint gate from `roblox/`: `stylua --check src tests tools && selene src tools` — **read selene's full output; it fails CI on warnings** (a `tail -1` once hid two). Tests: `lune run tests/run`. Server: `npm test` from `server/` (run `nvm use` first if npm errors — local env quirk).
- `roblox/default.project.json` edited AS TEXT with Edit, never a JSON round-trip.
- `.client.luau`/`.server.luau` are untested by design; decisions live in pure modules.
- Commit after each task, repo message style, trailers:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01Vw3EoAN2H4ZcRXNtu2mFco`.

## File Structure

| File | Responsibility |
|---|---|
| `server/src/models/User.ts` (modify) | `mortarPlacements` field |
| `server/src/loadout.ts` (modify) | `validateMortarPlacements` |
| `server/src/routes/apiV1.ts` (modify) | PUT route; fireworks GET carries placements |
| `roblox/src/shared/MortarPlacement.luau` (create) | defaults/overrides/clamp/nudge + muzzle math |
| `roblox/src/server/NetworkClient.luau` (modify) | `putMortarPlacements`; GET passthrough |
| `roblox/src/server/main.server.luau` (modify) | state carriage, `SetMortarPlacement` handler, launch origin |
| `roblox/default.project.json` (modify, text) | `SetMortarPlacement` RemoteEvent |
| `roblox/src/client/DecorationController.client.luau` (modify) | tube render pass |
| `roblox/src/client/BackDoorController.client.luau` (modify) | move-only mortar flow |
| Tests | `roblox/tests/MortarPlacement.spec.luau` (create), `server/src/loadout.test.ts` + `server/src/routes/apiV1.test.ts` (extend) |

---

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

### Task 2: MortarPlacement — defaults, overrides, clamp, nudge, muzzle math

**Files:**
- Create: `roblox/src/shared/MortarPlacement.luau`
- Test: `roblox/tests/MortarPlacement.spec.luau`

**Interfaces:**
- Consumes: nothing (pure; deck bounds passed in).
- Produces (exact names later tasks rely on):
  - `MortarPlacement.MORTAR_ORDER = { "mortar:S", "mortar:M", "mortar:L" }` (⚠ mirrors `MORTAR_IDS` in `server/src/fireworks.ts` — carry the TS<->Luau drift caveat comment)
  - `MortarPlacement.TUBE: { [string]: { bore: number, length: number } }` — S `{1/6, 0.85}`, M `{1/3, 1.5}`, L `{0.5, 2.5}` (the proving-range proportions, 1 stud = 1 ft)
  - `type Placement = { x: number, z: number, facing: string }`
  - `MortarPlacement.resolve(deckBounds: Bounds, owned: { string }, stored: { [string]: { offset: { number }, facing: string } }?, teahouseFP: Bounds?): { [string]: Placement }` where `Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }` (DecorationLayout's shape)
  - `MortarPlacement.muzzleWorld(deckRow: { number }, placement: Placement, mortarId: string): (number, number, number)` — world x,y,z of the tube's muzzle: the 12-number row-major deck CFrame (position + 3x3 rotation, `PadSites.deckPlacements` convention) transforming the deck-local `(x, baseTop + length, z)` point, where baseTop = 0.5 (the timber base height used by the render task).

Behavior pinned by the spec:
- **Front edge = local `maxZ`** (deck rows are view-oriented; the canyon-facing side is +Z in deck-local space — the same convention `DecorationLayout`/`BuildingPlacer` use for "front"). Defaults sit at `z = maxZ - 1` (1-stud inset), owned tiers in MORTAR_ORDER order spread evenly across the middle half of the X span (e.g. one mortar at center; two at ±25% of span; three at −25%/0/+25%).
- Stored placements override defaults per mortar; both stored and default are **clamped** into `[minX+0.5, maxX-0.5] × [minZ+0.5, maxZ-0.5]`.
- **Teahouse nudge**: a resolved spot strictly inside `teahouseFP` moves to `z = maxZ - 1` keeping its clamped x; if STILL inside the footprint, walk x outward in 1-stud steps (alternating +/−) until clear or the bounds clamp stops progress — always returning a position, never nil, never mutating `stored`.
- Unknown or unowned ids in `stored` are ignored; every OWNED mortar always gets a row in the result.

- [ ] **Step 1: Write the failing spec** — `roblox/tests/MortarPlacement.spec.luau` (harness idiom: `describe/test/expect(...).toBe`):

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local MortarPlacement = require("../src/shared/MortarPlacement")

local BOUNDS = { minX = -8, maxX = 8, minZ = -6, maxZ = 6 }
local ALL = { "mortar:S", "mortar:M", "mortar:L" }

describe("MortarPlacement — default-first gear placement", function()
    test("every owned mortar gets a spot; defaults sit on the front edge, staggered", function()
        local out = MortarPlacement.resolve(BOUNDS, ALL, nil, nil)
        local xs = {}
        for _, id in MortarPlacement.MORTAR_ORDER do
            local p = out[id]
            expect(p ~= nil).toBe(true)
            assert(p)
            expect(p.z).toBe(BOUNDS.maxZ - 1)
            table.insert(xs, p.x)
        end
        expect(xs[1] < xs[2] and xs[2] < xs[3]).toBe(true) -- S left of M left of L
    end)

    test("a single owned mortar defaults to front-center", function()
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, nil, nil)
        expect(out["mortar:S"].x).toBe(0)
        expect(out["mortar:M"] == nil).toBe(true)
    end)

    test("stored placements override defaults and get clamped, never mutated", function()
        local stored = { ["mortar:S"] = { offset = { 40, -40 }, facing = "E" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:S"].x).toBe(BOUNDS.maxX - 0.5)
        expect(out["mortar:S"].z).toBe(BOUNDS.minZ + 0.5)
        expect(out["mortar:S"].facing).toBe("E")
        expect(stored["mortar:S"].offset[1]).toBe(40) -- untouched
    end)

    test("a spot inside the teahouse footprint NUDGES clear -- mortars never hide", function()
        local teahouse = { minX = -8, maxX = 8, minZ = 2, maxZ = 6 } -- swallows the front edge
        local stored = { ["mortar:S"] = { offset = { 0, 5 }, facing = "N" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, teahouse)
        local p = out["mortar:S"]
        local inside = p.x > teahouse.minX and p.x < teahouse.maxX and p.z > teahouse.minZ and p.z < teahouse.maxZ
        expect(inside).toBe(false)
    end)

    test("unowned/unknown stored ids are ignored", function()
        local stored = { ["mortar:L"] = { offset = { 0, 0 }, facing = "N" }, nonsense = { offset = { 0, 0 }, facing = "N" } }
        local out = MortarPlacement.resolve(BOUNDS, { "mortar:S" }, stored, nil)
        expect(out["mortar:L"] == nil).toBe(true)
        expect(out["mortar:S"] ~= nil).toBe(true)
    end)

    test("muzzleWorld transforms deck-local to world through the 12-number row", function()
        -- identity rotation, deck origin at (100, 50, -20)
        local row = { 100, 50, -20, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local x, y, z = MortarPlacement.muzzleWorld(row, { x = 2, z = 3, facing = "N" }, "mortar:L")
        expect(x).toBe(102)
        expect(z).toBe(-17)
        expect(math.abs(y - (50 + 0.5 + 2.5)) < 1e-6).toBe(true) -- baseTop + L tube length
        -- 90-degree yaw: local x maps to world -z (row-major R applied as p' = R*p)
        local rot = { 100, 50, -20, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local rx, _, rz = MortarPlacement.muzzleWorld(rot, { x = 2, z = 0, facing = "N" }, "mortar:S")
        expect(math.abs(rx - 100) < 1e-6).toBe(true)
        expect(math.abs(rz - (-22)) < 1e-6).toBe(true)
    end)
end)
```

- [ ] **Step 2: Verify failure** — `lune run tests/run`: module not found.
- [ ] **Step 3: Implement** per the Interfaces block (row-major transform: `world = pos + R * local`, with `R` rows `{r[4],r[5],r[6]; r[7],r[8],r[9]; r[10],r[11],r[12]}` — matching how `Spec.cframe` lays out model.json CFrames).
- [ ] **Step 4: Green** — `lune run tests/run`.
- [ ] **Step 5: Lint (FULL output) + commit**

```bash
stylua --check src tests tools && selene src tools
git add src/shared/MortarPlacement.luau tests/MortarPlacement.spec.luau
git commit -m "feat(mortars): MortarPlacement -- front-edge defaults, overrides, clamp, teahouse nudge, muzzle math"
```

---

### Task 3: NetworkClient — placements out and back

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau`

**Interfaces:**
- Consumes: the backend routes from Task 1.
- Produces: `NetworkClient.putMortarPlacements(self, robloxUserId: string, placements: { [string]: any }): Result` (PUT `/players/{id}/mortar-placements`, body `{ placements = placements }`); `getFireworks`'s decoded result now includes `mortarPlacements` (no change needed if the method returns the decoded body as-is — verify and state which in the report).

- [ ] **Step 1: Read the file's existing PUT method** (the decorations one) and mirror it exactly — same retry/error idiom, name `putMortarPlacements`.
- [ ] **Step 2: Verify `getFireworks` passes the whole decoded body through** (it should — it returns `res.data`); if any field-picking exists, add `mortarPlacements`.
- [ ] **Step 3: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/server/NetworkClient.luau
git commit -m "feat(mortars): NetworkClient.putMortarPlacements + GET passthrough"
```

---

### Task 4: Studio server — state carriage, SetMortarPlacement, muzzle-true launches

**Files:**
- Modify: `roblox/default.project.json` (AS TEXT: one line in `RoshamboRemotes`, beside `SetDecorationPlacement`): `"SetMortarPlacement": { "$className": "RemoteEvent" },`
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `MortarPlacement.resolve/muzzleWorld/MORTAR_ORDER` (Task 2), `net:putMortarPlacements` (Task 3), `deckSiteFor`/`PadSites`/`DeckPlacement` (existing), the fireworks GET's new `mortarPlacements`.
- Produces: per-player mortar state the client render (Task 5) and editor (Task 6) read; deck launches from the required tier's muzzle.

Behavior contract (this file is runtime-only; decisions already live in Task 2's tested module):

1. **State**: wherever the fireworks GET result is consumed (`pushFireworkState` and the economy bootstrap that stores `e.deckDecorations`), stow `e.mortarPlacements` (raw stored map, may be nil) and `e.mortars` if not already held. Extend the SAME state tables that carry `deckDecorations` to clients (the ~line 1088/1424 tables) with `mortarPlacements = e.mortarPlacements` and `mortars = e.mortars` — visitors render every deck's mortars, exactly like decorations.
2. **`SetMortarPlacement` handler**: mirror `SetDecorationPlacement`'s shape (occupant-only, payload validation: `mortarId` in `MortarPlacement.MORTAR_ORDER` AND in `e.mortars`; `offset` two finite numbers; `facing` N/E/S/W). Update the in-memory map, echo the same client-facing state event the decoration flow echoes, then persist via `net:putMortarPlacements` on the handlerQueue (full-map PUT, decoration discipline: optimistic local, reconciled by the echo).
3. **Launch origin**: in `RequestFireworkLaunch`, after `LaunchSites.isValid` passes — when the valid site is the player's OWN deck (`deckSiteFor(uid)` matched) AND the shell's requirement is gear (consult the fireworks state's `reason`-free launchable data the server already holds, or simply: shell id has a mortar requirement per a small shared mirror — implementer's choice, stated in the report), compute origin = `MortarPlacement.muzzleWorld(deckRow, resolvedPlacement, requiredMortarId)` where `deckRow` is the same `spec.deckPlacements` row `deckSiteFor` reads and `resolvedPlacement` comes from `MortarPlacement.resolve` with the deck's bounds + stored map. `firecracker` and public-site launches keep `root.Position + Vector3.new(0, 6, 0)`.
4. ⚠ The required-tier mapping lives server-side in TS (`REQUIREMENTS`); the Studio server knows only `reason` strings. Add the minimal honest mirror: `MortarPlacement.SHELL_MORTAR: { [string]: string }` in Task 2's module — `{ peony = "mortar:S", willow = "mortar:M", kiku = "mortar:S" }` — with the drift caveat comment, and a line in this task's report flagging that promotion of a gear shell now touches that table too (the ShellDisplay lesson, pre-empted).

- [ ] **Step 1: project.json line (text Edit).**
- [ ] **Step 2: Implement the contract.** (Task 2 must first gain `SHELL_MORTAR` — do that edit + a two-line spec test as part of THIS task, since Task 2 may already be reviewed: test that every `SHELL_MORTAR` value is in `MORTAR_ORDER`.)
- [ ] **Step 3: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add default.project.json src/server/main.server.luau src/shared/MortarPlacement.luau tests/MortarPlacement.spec.luau
git commit -m "feat(mortars): server state carriage, SetMortarPlacement, muzzle-true deck launches"
```

---

### Task 5: Tube render — the decoration pass grows a gear pass

**Files:**
- Modify: `roblox/src/client/DecorationController.client.luau`

**Interfaces:**
- Consumes: the state tables from Task 4 (`mortarPlacements`, `mortars`, alongside `deckDecorations`), `MortarPlacement.resolve/TUBE/MORTAR_ORDER`, the controller's existing rebuild triggers and deck-bounds derivation.
- Produces: visible tubes on every deck with owned mortars; later Task 6 overlays prompts on these models.

Behavior contract:
- In the same rebuild that redraws decorations for a pad, additionally render one Model per owned mortar at `MortarPlacement.resolve(...)` positions (pass the built teahouse footprint the decoration pass already computes, so the nudge rule engages).
- Tube geometry per tier from `MortarPlacement.TUBE` (bore/length): a vertical metal cylinder (`Size = Vector3.new(length, bore*3, bore*3)` with the CylinderMesh-free `Shape = Cylinder` + `CFrame.Angles(0, 0, math.rad(90))` axis fix, OR match however `DecorationCatalog`'s builders orient cylinders — read `tsukubai`'s builder and copy the idiom) on a `0.5`-tall timber base (`Color3.fromRGB(216, 214, 206)`, `Enum.Material.Wood`), anchored, non-interactive, Model named `Mortar_S/M/L` with PrimaryPart the tube.
- Tag each Model the way decoration models are tagged, PLUS an attribute `MortarId` (string) so the editor can find them.
- Rebuild on the same events decorations rebuild on (placement echo included).

- [ ] **Step 1: Read the controller's decoration rebuild pass fully; implement the mortar pass beside it.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/DecorationController.client.luau
git commit -m "feat(mortars): tubes render on every deck -- one per owned tier, default or placed"
```

---

### Task 6: Back-door editor — move-only gear

**Files:**
- Modify: `roblox/src/client/BackDoorController.client.luau`

**Interfaces:**
- Consumes: Task 5's `MortarId`-attributed Models, the `SetMortarPlacement` remote (Task 4), the editor's existing decoration move flow.
- Produces: the owner-facing placement UX.

Behavior contract:
- Mortars join the editor's movable set with the decoration DRAG/rotate flow, firing `SetMortarPlacement:FireServer({ mortarId = id, offset = { x, z }, facing = f })` on drop.
- NO remove/sell affordance for mortars: whatever prompt/action the decoration flow shows for removal is absent on a `MortarId` model. Move and rotate only.
- The 24-cap display logic ignores mortars entirely.

- [ ] **Step 1: Read the editor's decoration flow fully; implement.**
- [ ] **Step 2: Suite + lint (full output) + commit**

```bash
lune run tests/run && stylua --check src tests tools && selene src tools
git add src/client/BackDoorController.client.luau
git commit -m "feat(mortars): back-door editor moves gear -- drag and rotate, never remove"
```

---

### Task 7: Backend deploy, owner gate, wiki — MAIN SESSION ONLY

**Do not dispatch this task to a subagent.** Needs the owner, Studio, and AWS.

- [ ] **Step 1:** Push main; `aws apprunner start-deployment` on `roshambo_server_dev` (auto-deploy is OFF — verified 2026-09-04); wait for `SUCCEEDED`.
- [ ] **Step 2:** Rojo reconnect (new project.json entry — the mid-session trap); verify `SetMortarPlacement` exists in Studio.
- [ ] **Step 3: Owner gate in Play:** three tubes on their deck at front-edge defaults (they own all mortars); fire a kiku — leaves the S muzzle; move a mortar via the back door; fire again — leaves the moved muzzle; rejoin — placement persisted; firecracker still hand-launched; visit another pad — no phantom mortars.
- [ ] **Step 4:** Wiki: `fireworks.md` as-built paragraph + `log.md` ship entry; note the `SHELL_MORTAR` promotion-pipeline addition in the proving-range spec's §5 correction block. Commit docs.

---

## Self-Review (performed at write time)

- **Spec coverage:** §1 → T1; §2 → T2 (+`SHELL_MORTAR` in T4); §3 → T5; §4 → T4; §5 → T6; §6 → T1/T2 tests; deploy/gate → T7. Cap exemption → T6; visitors see mortars → T4 state + T5 render.
- **Placeholder scan:** T4/T5/T6 are behavior contracts over runtime files (house pattern, three successful precedents); each names its reference symbols and the pure module carrying its decisions. T4 point 3 leaves one implementation choice (how the server learns "gear-required") and requires the report to state it — a decision delegated explicitly, not a TBD.
- **Type consistency:** `Placement {x,z,facing}` (T2) consumed in T4/T5; `muzzleWorld(deckRow, placement, mortarId)` matches T4's call; `MORTAR_ORDER`/`TUBE`/`SHELL_MORTAR` names consistent; backend field `mortarPlacements` spelled identically in T1 model/route/GET and T3/T4 consumers.
