# B4 Teahouse Repositioning — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player repositions their teahouse on the deck via an in-world ghost drag (1-stud snap, 90° rotation), persisted per teahouse size inside the loadout.

**Architecture:** Client-side ghost, server-validated commit. A translucent clone follows the aim across the deck using shared pure math (`BuildingPlacer.clamp`); one `SetPlacement` remote commits; the server re-validates with the same pure function, persists via the existing `PUT /teahouses/:size` loadout route, rebuilds through `TreatmentApplier`, and re-arms back-door prompts via the existing geometry watch. Spec: `docs/superpowers/specs/2026-07-16-b4-teahouse-repositioning-design.md`.

**Tech Stack:** Server = TypeScript + Express + Mongoose, Vitest (`server/`). Roblox = Luau + Rojo, bespoke Lune harness (`roblox/`). GUI is not Lune-testable → visual gate.

## Global Constraints

- **Placement shape:** `placement = { offset = {dx, dz}, facing = "N"|"E"|"S"|"W" }`, deck-local studs, stored per teahouse size inside the loadout. **Absent placement = centered** (`{offset={0,0}, facing="N"}`) — existing loadouts keep today's behavior, no migration.
- **Stored values are never rewritten at build time.** An unfit saved placement is clamped at render (minimal slide into deck bounds, facing preserved) — same philosophy as the B3 display clamp. The server DOES persist the clamped value at commit time (never raw client numbers).
- **Occupant/presence discipline (B1/B2/B3):** every server handler that yields on HTTP must re-check `player:IsDescendantOf(Players)` after the yield before mutating world state.
- **Both-stashes rule (B3 gate lesson):** any rebuild-triggering handler that changes a loadout must update BOTH `playerEconomy[uid].teahouses[size]` AND `playerHouse[uid]`, then call `echoBackDoor(player, uid)` after `applier:apply`.
- **Facing whitelist:** exactly `N/E/S/W` (`BuildingPlacer` yaw 0/90/180/270; the fit/clamp math swaps footprint half-extents at 90°/270°).
- Server tests: `cd server && npm test`. Roblox tests: `cd roblox && lune run tests/run`. Lint: `cd roblox && stylua --check src tests && selene src`.
- New remote ⇒ **restart `rojo serve`** before any Studio session (B1/B3 lesson).

---

## File Structure

- `roblox/src/shared/BuildingPlacer.luau` (modify) — add pure `clamp`.
- `roblox/tests/BuildingPlacer.spec.luau` (modify) — clamp tests.
- `server/src/loadout.ts` (modify) — `LOADOUT_KEYS` + `validatePlacement`.
- `server/src/loadout.test.ts` (modify) — placement validation tests.
- `roblox/src/shared/TeahouseMenuModel.luau` (modify) — `canMove` flag.
- `roblox/tests/TeahouseMenuModel.spec.luau` (modify) — canMove tests.
- `roblox/default.project.json` (modify) — `SetPlacement` RemoteEvent.
- `roblox/src/server/TreatmentApplier.luau` (modify) — clamp-then-build; stamp `MountCF`/`DeckSize`/`TeahouseSize` attributes.
- `roblox/src/shared/SiteCoordinator.luau` (modify) — `loadout.placement or CENTERED` in `onJoin`.
- `roblox/tests/SiteCoordinator.spec.luau` (modify) — one placement-passthrough test.
- `roblox/src/server/main.server.luau` (modify) — placement from loadout at the 2 rebuild sites; `SetPlacement` handler.
- `roblox/src/client/EventBus.luau` (modify) — add `"MoveTeahouse"` name.
- `roblox/src/client/TeahouseController.client.luau` (modify) — "Move teahouse" button.
- `roblox/src/client/MoveController.client.luau` (create) — the ghost-drag mode.

---

## Task 1: `BuildingPlacer.clamp` (pure, Lune TDD)

**Files:**
- Modify: `roblox/src/shared/BuildingPlacer.luau` (append after `fits`, ~line 45)
- Test: `roblox/tests/BuildingPlacer.spec.luau` (append)

**Interfaces:**
- Consumes: existing `BuildingPlacer.facingYaw`, `Placement = { offset: {number}, facing: string }`, `FP = { minX, maxX, minZ, maxZ }`.
- Produces: `BuildingPlacer.clamp(buildingFP: FP, deckFP: FP, p: Placement): Placement` — returns a NEW placement whose rotation-aware footprint fits inside `deckFP`, sliding `offset` the minimum distance; facing preserved; degenerate axis (building wider than deck) centers that axis.

- [ ] **Step 1: Write the failing tests** (append to `roblox/tests/BuildingPlacer.spec.luau`; the file already requires `harness` and `BuildingPlacer` at top)

```lua
describe("BuildingPlacer.clamp", function()
    -- building 12x6 (half 6x3) on a deck 26x20 (SizeClasses S-deck shape)
    local B = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 }
    local D = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 }

    test("in-bounds placement is returned unchanged", function()
        local p = BuildingPlacer.clamp(B, D, { offset = { 2, -4 }, facing = "N" })
        expect(p.offset[1]).toBe(2)
        expect(p.offset[2]).toBe(-4)
        expect(p.facing).toBe("N")
    end)
    test("slides the minimum distance back into bounds per axis", function()
        -- x max legal = 13 - 6 = 7; z min legal = -10 + 3 = -7
        local p = BuildingPlacer.clamp(B, D, { offset = { 11, -9 }, facing = "N" })
        expect(p.offset[1]).toBe(7)
        expect(p.offset[2]).toBe(-7)
    end)
    test("rotated facings swap the half-extents", function()
        -- facing E: halfX becomes 3, halfZ becomes 6 -> x legal to 10, z legal to 4
        local p = BuildingPlacer.clamp(B, D, { offset = { 12, 9 }, facing = "E" })
        expect(p.offset[1]).toBe(10)
        expect(p.offset[2]).toBe(4)
        expect(p.facing).toBe("E")
    end)
    test("clamped result always fits", function()
        local p = BuildingPlacer.clamp(B, D, { offset = { 99, -99 }, facing = "W" })
        expect(BuildingPlacer.fits(B, D, p)).toBe(true)
    end)
    test("degenerate axis (building wider than deck) centers that axis", function()
        local wide = { minX = -30, maxX = 30, minZ = -3, maxZ = 3 }
        local p = BuildingPlacer.clamp(wide, D, { offset = { 5, 2 }, facing = "N" })
        expect(p.offset[1]).toBe(0) -- centered on the too-narrow axis
        expect(p.offset[2]).toBe(2) -- other axis untouched (in bounds)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `attempt to call a nil value (clamp)`.

- [ ] **Step 3: Implement** (append to `roblox/src/shared/BuildingPlacer.luau`, before the final `return`)

```lua
-- Slide a placement the minimum distance so its rotation-aware footprint fits inside the deck
-- (B4). Facing is preserved; a degenerate axis (building wider than the deck) centers on that
-- axis. Returns a NEW placement — never mutates the input; callers may persist the result.
function BuildingPlacer.clamp(buildingFP: FP, deckFP: FP, p: Placement): Placement
    local halfX = (buildingFP.maxX - buildingFP.minX) / 2
    local halfZ = (buildingFP.maxZ - buildingFP.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(p.facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    local function axis(v: number, half: number, lo: number, hi: number): number
        if half * 2 > (hi - lo) then
            return (lo + hi) / 2
        end
        return math.clamp(v, lo + half, hi - half)
    end
    return {
        offset = {
            axis(p.offset[1], halfX, deckFP.minX, deckFP.maxX),
            axis(p.offset[2], halfZ, deckFP.minZ, deckFP.maxZ),
        },
        facing = p.facing,
    }
end
```

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all PASS/clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/BuildingPlacer.luau roblox/tests/BuildingPlacer.spec.luau
git commit -m "feat(roblox): BuildingPlacer.clamp — minimal slide into deck bounds (B4)"
```

---

## Task 2: `validatePlacement` + loadout whitelist (server, Vitest TDD)

**Files:**
- Modify: `server/src/loadout.ts` (LOADOUT_KEYS at line 5; new validator after `validateWallBays` ~line 29; hook in `validateLoadout` ~line 42)
- Test: `server/src/loadout.test.ts` (append; mirror the existing `validateWallBays` test style in that file)

**Interfaces:**
- Consumes: the `Check` type (`{ ok: true } | { ok: false; error: string }`) already in `loadout.ts`.
- Produces: `PLACEMENT_FACINGS: Set<string>`, `MAX_PLACEMENT_OFFSET = 32`, `validatePlacement(value: unknown): Check` (error code `BAD_PLACEMENT`); `'placement'` accepted in `LOADOUT_KEYS`; `validateLoadout` rejects malformed placements.

- [ ] **Step 1: Write the failing tests** (append to `server/src/loadout.test.ts`, importing `validatePlacement` and `validateLoadout` from `./loadout` alongside the file's existing imports)

```ts
describe('validatePlacement', () => {
  it('accepts a valid placement', () => {
    expect(validatePlacement({ offset: [3, -4.5], facing: 'E' })).toEqual({ ok: true });
  });
  it('rejects non-objects and arrays', () => {
    expect(validatePlacement(null).ok).toBe(false);
    expect(validatePlacement([1, 2]).ok).toBe(false);
    expect(validatePlacement('N').ok).toBe(false);
  });
  it('rejects wrong offset arity', () => {
    expect(validatePlacement({ offset: [1], facing: 'N' })).toEqual({ ok: false, error: 'BAD_PLACEMENT' });
    expect(validatePlacement({ offset: [1, 2, 3], facing: 'N' })).toEqual({ ok: false, error: 'BAD_PLACEMENT' });
  });
  it('rejects non-finite and out-of-range offsets', () => {
    expect(validatePlacement({ offset: [NaN, 0], facing: 'N' }).ok).toBe(false);
    expect(validatePlacement({ offset: [Infinity, 0], facing: 'N' }).ok).toBe(false);
    expect(validatePlacement({ offset: [33, 0], facing: 'N' }).ok).toBe(false);
    expect(validatePlacement({ offset: [0, -33], facing: 'N' }).ok).toBe(false);
  });
  it('rejects bad facings and unknown keys', () => {
    expect(validatePlacement({ offset: [0, 0], facing: 'NE' }).ok).toBe(false);
    expect(validatePlacement({ offset: [0, 0], facing: 'N', extra: 1 }).ok).toBe(false);
  });
  it('validateLoadout accepts placement and still rejects unknown keys', () => {
    expect(validateLoadout({ baseStyle: 'teahouse-1story', placement: { offset: [2, 2], facing: 'S' } })).toEqual({ ok: true });
    expect(validateLoadout({ baseStyle: 'teahouse-1story', placement: { offset: [2], facing: 'S' } }).ok).toBe(false);
    expect(validateLoadout({ baseStyle: 'teahouse-1story', teleporter: true }).ok).toBe(false);
  });
});
```

- [ ] **Step 2: Run to verify failure**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: FAIL — `validatePlacement is not a function`.

- [ ] **Step 3: Implement** — in `server/src/loadout.ts`:

Line 5, add `'placement'`:

```ts
const LOADOUT_KEYS = new Set(['baseStyle', 'colorScheme', 'shoji', 'tatami', 'flags', 'wallArt', 'wallBays', 'placement']);
```

After `validateWallBays` (~line 29), add:

```ts
export const PLACEMENT_FACINGS = new Set(['N', 'E', 'S', 'W']);
export const MAX_PLACEMENT_OFFSET = 32;

export function validatePlacement(value: unknown): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'BAD_PLACEMENT' };
    }
    const obj = value as Record<string, unknown>;
    for (const k of Object.keys(obj)) {
        if (k !== 'offset' && k !== 'facing') return { ok: false, error: 'BAD_PLACEMENT' };
    }
    if (!Array.isArray(obj.offset) || obj.offset.length !== 2) {
        return { ok: false, error: 'BAD_PLACEMENT' };
    }
    for (const n of obj.offset) {
        if (typeof n !== 'number' || !Number.isFinite(n) || Math.abs(n) > MAX_PLACEMENT_OFFSET) {
            return { ok: false, error: 'BAD_PLACEMENT' };
        }
    }
    if (typeof obj.facing !== 'string' || !PLACEMENT_FACINGS.has(obj.facing)) {
        return { ok: false, error: 'BAD_PLACEMENT' };
    }
    return { ok: true };
}
```

In `validateLoadout`, after the `wallBays` block (~line 45), add:

```ts
    if (obj.placement !== undefined) {
        const p = validatePlacement(obj.placement);
        if (!p.ok) return p;
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `cd server && npm test`
Expected: PASS (all suites).

- [ ] **Step 5: Commit**

```bash
git add server/src/loadout.ts server/src/loadout.test.ts
git commit -m "feat(server): placement joins the loadout whitelist with validatePlacement (B4)"
```

---

## Task 3: `TeahouseMenuModel.canMove` (pure, Lune TDD)

**Files:**
- Modify: `roblox/src/shared/TeahouseMenuModel.luau` (compute near `needsClaim` ~line 34; add to the return table ~line 115)
- Test: `roblox/tests/TeahouseMenuModel.spec.luau` (append a describe block; the file's `state(over)` helper builds a full state table — pass `claimed = true` etc. via `over`)

**Interfaces:**
- Consumes: existing `state.claimed: boolean`, `state.teahouseSizes: {string}`, `state.teahouseDisplay: string?`, local `teaMax` (already computed).
- Produces: `vm.canMove: boolean` — true iff the player is claimed AND owns a teahouse AND `teahouseDisplay ~= "none"` (i.e. a teahouse is actually standing to move). Task 5's button gates on this.

- [ ] **Step 1: Write the failing tests** (append; mirror the file's existing helper usage)

```lua
describe("TeahouseMenuModel.canMove", function()
    test("claimed owner with a shown teahouse can move", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = { "S" }, claimed = true }))
        expect(vm.canMove).toBe(true)
    end)
    test("display 'none' means nothing is standing to move", function()
        local vm = Model.viewModel(
            state({ maxDeckSize = "M", teahouseSizes = { "S" }, claimed = true, teahouseDisplay = "none" })
        )
        expect(vm.canMove).toBe(false)
    end)
    test("unclaimed owner cannot move", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = { "S" }, claimed = false }))
        expect(vm.canMove).toBe(false)
    end)
    test("deck-only owner has no teahouse to move", function()
        local vm = Model.viewModel(state({ maxDeckSize = "M", teahouseSizes = {}, claimed = true }))
        expect(vm.canMove).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `canMove` nil.

- [ ] **Step 3: Implement** — in `TeahouseMenuModel.viewModel`, after the `teahouseShownSmaller` block (~line 113), add:

```lua
    -- B4: the Move-teahouse mode needs a standing building on a claimed perch. Perch caps only
    -- shrink the built SIZE, never remove the building, so presence = owns one + not hidden.
    local canMove = state.claimed == true and teaMax ~= nil and state.teahouseDisplay ~= "none"
```

and `canMove = canMove,` in the return table.

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all PASS/clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/TeahouseMenuModel.luau roblox/tests/TeahouseMenuModel.spec.luau
git commit -m "feat(roblox): TeahouseMenuModel.canMove gates the B4 move mode"
```

---

## Task 4: Server wiring — remote, clamp-then-build, folder attributes, placement from loadout, `SetPlacement` handler

**Files:**
- Modify: `roblox/default.project.json` (add `SetPlacement` under `RoshamboRemotes`, after `"SetDisplay"`)
- Modify: `roblox/src/server/TreatmentApplier.luau` (`_buildBuilding` ~lines 82-90; `apply` commit ~line 162 and clear branch ~lines 119-124)
- Modify: `roblox/src/shared/SiteCoordinator.luau` (`onJoin` teahouse table ~line 147)
- Test: `roblox/tests/SiteCoordinator.spec.luau` (append one passthrough test; mirror that file's existing onJoin test setup — registry/spec fakes already exist there)
- Modify: `roblox/src/server/main.server.luau` (rebuild sites ~751 and ~810; new handler after the `SetDisplay` handler; declare the remote near the others ~line 85)

**Interfaces:**
- Consumes: `BuildingPlacer.clamp` (Task 1); existing `SizeClasses.resolveBuilt/buildingFootprint/deckFootprint`, `net:setTeahouse(uid, size, loadout)` (`NetworkClient.luau:140`), `echoBackDoor(player, uid)` (main.server ~line 432), `playerEconomy`/`playerHouse` stashes, `applier:apply`.
- Produces: `SetPlacement` RemoteEvent; site-folder attributes `MountCF: CFrame`, `DeckSize: string`, `TeahouseSize: string` ("" for bare deck) — Task 6's client reads these; every build path renders `loadout.placement or CENTERED`.

This is wiring: no new Lune tests except the SiteCoordinator passthrough; all suites must stay green.

- [ ] **Step 1: Register the remote** — in `roblox/default.project.json`, after `"SetDisplay": { "$className": "RemoteEvent" }` add:

```json
"SetPlacement": { "$className": "RemoteEvent" }
```

- [ ] **Step 2: TreatmentApplier — clamp then build** — in `_buildBuilding`, replace lines 82-90 (`local placement = ...` through the `fits` early-return) with:

```lua
    local deckFP = self._sizeClasses.deckFootprint(deckSize)
    local buildingFP = self._sizeClasses.buildingFootprint(teahouse.size)
    -- B4: clamp the SAVED placement into this deck at render time (stored values never change;
    -- a display-shrunk deck slides the building minimally back into bounds). fits() stays only
    -- as a last-ditch guard for pathological data.
    local placement = self._buildingPlacer.clamp(buildingFP, deckFP, teahouse.placement)
    if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
        warn(
            `[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`
        )
        return
    end
```

(The two lines that previously computed `deckFP`/`buildingFP` below the old `placement` line are replaced by the block above — do not compute them twice.)

- [ ] **Step 3: TreatmentApplier — stamp folder attributes** — in `apply`, next to the existing `folder:SetAttribute("Occupied", treatment.lit == true)` (~line 162), add:

```lua
    -- B4: authoritative deck frame + built sizes for the client move mode (MoveController).
    folder:SetAttribute("MountCF", mountCF)
    folder:SetAttribute("DeckSize", deckSize)
    folder:SetAttribute("TeahouseSize", if teahouse ~= nil and teahouse.loadout ~= nil then teahouse.size else "")
```

and in the garden/clear branch (~lines 119-124, after the children loop), add:

```lua
        folder:SetAttribute("MountCF", nil)
        folder:SetAttribute("DeckSize", nil)
        folder:SetAttribute("TeahouseSize", nil)
```

- [ ] **Step 4: SiteCoordinator — placement from the loadout** — at ~line 147 replace:

```lua
                local teahouse = if built.teahouseSize ~= nil
                    then { size = built.teahouseSize, loadout = teaLoadout, placement = CENTERED }
                    else nil
```

with:

```lua
                local teahouse = if built.teahouseSize ~= nil
                    then {
                        size = built.teahouseSize,
                        loadout = teaLoadout,
                        placement = (teaLoadout and teaLoadout.placement) or CENTERED,
                    }
                    else nil
```

Also apply the same expression at the starter-bundle site (~line 69) for uniformity — replace `placement = CENTERED` with `placement = (treatment.loadout and treatment.loadout.placement) or CENTERED`. (The dormant starter loadout never carries a placement, so this is behaviorally identical; the uniform rule means no build site special-cases placement.)

- [ ] **Step 5: SiteCoordinator passthrough test** — append to `roblox/tests/SiteCoordinator.spec.luau`, reusing that file's existing registry/spec/onJoin fixtures (read them first and mirror the closest existing onJoin test):

```lua
    test("onJoin passes the loadout's saved placement through to the action", function()
        -- build the same registry/coordinator the neighboring onJoin tests use, with a
        -- teahouse loadout that carries a placement:
        local placed = { baseStyle = "teahouse-1story", placement = { offset = { 4, -2 }, facing = "E" } }
        -- (mirror the file's existing economy-table shape)
        local action = coordinator:onJoin("p1", {
            maxDeckSize = "L",
            teahouses = { L = placed },
        })
        expect(action.teahouse.placement.offset[1]).toBe(4)
        expect(action.teahouse.placement.facing).toBe("E")
    end)
```

- [ ] **Step 6: main.server — placement from the loadout at both rebuild sites** — near the top of the economy section (by the `playerHouse` declaration ~line 390) add:

```lua
local CENTERED_PLACEMENT = { offset = { 0, 0 }, facing = "N" }
```

Then at the upgrade rebuild (~line 751) and the SetDisplay rebuild (~line 810), replace

```lua
                        placement = { offset = { 0, 0 }, facing = "N" },
```

with

```lua
                        placement = (teaLoadout and teaLoadout.placement) or CENTERED_PLACEMENT,
```

- [ ] **Step 7: main.server — declare + handle `SetPlacement`** — declare near the other remotes (~line 85):

```lua
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent
```

Add the handler directly after the `SetDisplay` handler:

```lua
SetPlacement.OnServerEvent:Connect(function(player, payload)
    local uid = tostring(player.UserId)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
        return -- occupant-only, same discipline as SetDisplay
    end
    if typeof(payload) ~= "table" or typeof(payload.offset) ~= "table" then
        return
    end
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
    if built == nil or built.teahouseSize == nil then
        return -- bare deck / nothing built: nothing to move
    end
    local size = built.teahouseSize
    -- server-authoritative: clamp the request against the BUILT combination and persist the
    -- clamped value (never raw client numbers)
    local clamped = BuildingPlacer.clamp(
        SizeClasses.buildingFootprint(size),
        SizeClasses.deckFootprint(built.deckSize),
        { offset = { dx, dz }, facing = facing }
    )
    -- merge into a NEW copy of the built size's loadout (pre-persist clone discipline)
    local newLoadout = table.clone(e.teahouses[size])
    newLoadout.placement = clamped
    local persisted = net:setTeahouse(uid, size, newLoadout)
    if not persisted.ok then
        warn(`[B4] setTeahouse(placement) failed for {uid}/{size}: {tostring(persisted.error)}`)
        echoEconomy(player, uid) -- resync
        return
    end
    if not player:IsDescendantOf(Players) then
        return -- left during the HTTP yield; nothing to rebuild
    end
    -- both stashes (B3 gate lesson), then rebuild at the new placement
    e.teahouses[size] = newLoadout
    local teahouse = { size = size, loadout = newLoadout, placement = clamped }
    local treatment = { kind = "structure", loadout = newLoadout, lit = true }
    applier:apply(e.claimedPadId, spec, treatment, built.deckSize, teahouse)
    playerHouse[uid] = { padId = e.claimedPadId, size = size, loadout = newLoadout }
    echoBackDoor(player, uid) -- geometry watch re-arms the F prompts on the new structure
end)
```

(`BuildingPlacer` is already required in main.server at line 377.)

- [ ] **Step 8: Verify + lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests && selene src`
Expected: all green (existing suites + the new SiteCoordinator test).

- [ ] **Step 9: Commit**

```bash
git add roblox/default.project.json roblox/src/server/TreatmentApplier.luau roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): SetPlacement remote + handler; builds render loadout placement with clamp (B4)"
```

---

## Task 5: EventBus name + "Move teahouse" panel button (client)

**Files:**
- Modify: `roblox/src/client/EventBus.luau` (line 4)
- Modify: `roblox/src/client/TeahouseController.client.luau` (require EventBus; add the button; gate on `vm.canMove`)

**Interfaces:**
- Consumes: `vm.canMove` (Task 3); `econ.claimedPadId` (already stashed in the controller, ~line 48).
- Produces: `EventBus.MoveTeahouse:Fire({ padId = <string> })` — Task 6 listens on `EventBus.MoveTeahouse.Event`.

- [ ] **Step 1: EventBus name** — in `roblox/src/client/EventBus.luau` line 4:

```lua
local NAMES = { "Cue", "TickerMessage", "MoveTeahouse" }
```

- [ ] **Step 2: Require EventBus in TeahouseController** — alongside its existing requires (~line 33):

```lua
local EventBus = require(script.Parent:WaitForChild("EventBus"))
```

- [ ] **Step 3: Add the button** — read the panel's existing widget construction (e.g. the `needsClaimHint` block at ~line 175 and the display-row buttons) and build a `TextButton` in the same style/palette, `Name = "MoveButton"`, text `"Move teahouse"`, `LayoutOrder` placing it directly after the display rows. On click:

```lua
moveButton.MouseButton1Click:Connect(function()
    if not currentCanMove or econ.claimedPadId == nil then
        return
    end
    setPanelOpen(false) -- use the controller's existing open/close mechanism
    EventBus.MoveTeahouse:Fire({ padId = econ.claimedPadId })
end)
```

Store `currentCanMove` from the view-model in `render()`:

```lua
    currentCanMove = vm.canMove
    moveButton.Active = vm.canMove
    moveButton.AutoButtonColor = vm.canMove
    moveButton.TextTransparency = if vm.canMove then 0 else 0.5
```

(Match exactly how the display-row buttons express their disabled state — read them first and reuse the idiom; if the panel hides sections pre-`ready`, include the button in the same group it visually belongs to.)

- [ ] **Step 4: Lint + suites**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run`
Expected: clean/green.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/EventBus.luau roblox/src/client/TeahouseController.client.luau
git commit -m "feat(roblox): Move-teahouse panel button publishes over the client EventBus (B4)"
```

---

## Task 6: `MoveController.client.luau` — the ghost-drag mode (client, gate-driven)

**Files:**
- Create: `roblox/src/client/MoveController.client.luau` (picked up automatically — `default.project.json` maps all of `src/client` into StarterPlayerScripts)

**Interfaces:**
- Consumes: `EventBus.MoveTeahouse.Event` (Task 5, payload `{ padId }`); site-folder attributes `MountCF`/`DeckSize`/`TeahouseSize` (Task 4); shared `BuildingPlacer` (`clamp`, `placeCF`, `facingYaw`) and `SizeClasses` (`buildingFootprint`, `deckFootprint`) from `ReplicatedStorage.RoshamboShared`; fires `SetPlacement:FireServer({ offset = {dx,dz}, facing = f })`.
- Produces: the mode. No exports.

This is GUI — not Lune-testable; lint is the only automated check. Build the load-bearing structure below; feel/polish is gate-tuned. **Spec deviation, deliberate:** the cancel KEY is `X`, not Esc — Roblox reserves Esc for the core menu and it is not deliverable to `InputBegan`. The HUD Cancel button is the primary cancel affordance (and the only one on touch).

- [ ] **Step 1: Scaffold + state**

```lua
--!strict
-- B4 move mode: a client-side translucent ghost of your teahouse follows the aim across the
-- deck (1-stud snap, R rotates 90°), click/✓ commits one SetPlacement, X/✕ cancels. The ghost
-- is local-only; the server re-validates with the same shared math and rebuilds. Entry is the
-- panel's Move button via EventBus.MoveTeahouse { padId }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local BuildingPlacer = require(shared:WaitForChild("BuildingPlacer"))
local SizeClasses = require(shared:WaitForChild("SizeClasses"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetPlacement = remotes:WaitForChild("SetPlacement") :: RemoteEvent

local player = Players.LocalPlayer
local FACING_ORDER = { "N", "E", "S", "W" }

-- mode state (nil when inactive)
local active = false
local ghost: Model? = nil
local original: Model? = nil
local mountCF: CFrame? = nil
local buildingFP: any = nil
local deckFP: any = nil
local current = { offset = { 0, 0 }, facing = "N" }
local conns: { RBXScriptConnection } = {}
local hud: ScreenGui? = nil
```

- [ ] **Step 2: Ghost + fade helpers**

```lua
local function makeGhost(structure: Model): Model
    local g = structure:Clone()
    g.Name = "MoveGhost"
    for _, d in g:GetDescendants() do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            if d.Transparency < 1 then
                d.Transparency = 0.6
            end
        elseif d:IsA("ProximityPrompt") then
            d:Destroy() -- no interactables on the ghost (back-door prompts clone along)
        end
    end
    g.Parent = workspace -- NOT the site folder: the drag raycast includes only the folder
    return g
end

local function fadeOriginal(structure: Model, amount: number)
    for _, d in structure:GetDescendants() do
        if d:IsA("BasePart") then
            d.LocalTransparencyModifier = amount
        end
    end
end
```

- [ ] **Step 3: Placement math** — initial state from the live pivot; per-frame drag:

```lua
-- placeCF's yaw convention: N=0, E=90, S=180, W=270 (CCW, matches CFrame.Angles(0, rad(y), 0))
local function facingFromPivot(structure: Model): (number, number, string)
    local rel = (mountCF :: CFrame):ToObjectSpace(structure:GetPivot())
    local _, ry, _ = rel:ToOrientation()
    local deg = (math.round(math.deg(ry) / 90) * 90) % 360
    local facing = if deg == 0 then "N" elseif deg == 90 then "E" elseif deg == 180 then "S" else "W"
    return rel.Position.X, rel.Position.Z, facing
end

local function applyGhost()
    local g, m = ghost, mountCF
    if g == nil or m == nil then
        return
    end
    current = BuildingPlacer.clamp(buildingFP, deckFP, current)
    g:PivotTo(m * CFrame.new(table.unpack(BuildingPlacer.placeCF(current))))
end

local function stepDrag(folder: Instance)
    local camera = workspace.CurrentCamera
    if camera == nil then
        return
    end
    local pos = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { folder }
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
    if hit then
        local rel = (mountCF :: CFrame):PointToObjectSpace(hit.Position)
        current = { offset = { math.round(rel.X), math.round(rel.Z) }, facing = current.facing }
        applyGhost()
    end
    -- no hit: ghost holds its last valid position
end
```

- [ ] **Step 4: Mode HUD** — write `local function buildHud()` that creates a `ScreenGui` (`ResetOnSpawn = false`), assigns it to the `hud` state variable, and builds a small pinned strip, toast palette (`Color3.fromRGB(20,18,16)` bg, `Color3.fromRGB(240,228,205)` text, `UICorner` 8, `Font.Gotham` — same as the B3 panel): three `TextButton`s — `⟳ Rotate (R)`, `✓ Place`, `✕ Cancel (X)` — bottom-center. `Rotate` advances `current.facing` through `FACING_ORDER` and calls `applyGhost()`; `Place` calls `commit()`; `Cancel` calls `exit()`. Declare it above `enter` (which calls it) and below `commit`/`exit` (which it references).

- [ ] **Step 5: Enter / commit / exit lifecycle**

```lua
local function exit()
    if not active then
        return
    end
    active = false
    for _, c in conns do
        c:Disconnect()
    end
    conns = {}
    if ghost then
        ghost:Destroy()
        ghost = nil
    end
    if original then
        fadeOriginal(original, 0)
        original = nil
    end
    if hud then
        hud:Destroy()
        hud = nil
    end
end

local function commit()
    if not active then
        return
    end
    SetPlacement:FireServer({ offset = { current.offset[1], current.offset[2] }, facing = current.facing })
    exit() -- the server rebuild arriving is the confirmation
end

local function enter(payload: any)
    if active or typeof(payload) ~= "table" or typeof(payload.padId) ~= "string" then
        return
    end
    local sites = workspace:FindFirstChild("TeahouseSites")
    local folder = sites and sites:FindFirstChild("MaterializedSite_" .. payload.padId)
    local structure = folder and folder:FindFirstChild("Structure")
    local m = folder and folder:GetAttribute("MountCF")
    local deckSize = folder and folder:GetAttribute("DeckSize")
    local teaSize = folder and folder:GetAttribute("TeahouseSize")
    if structure == nil or typeof(m) ~= "CFrame" or typeof(deckSize) ~= "string" then
        return
    end
    if typeof(teaSize) ~= "string" or teaSize == "" then
        return -- bare deck: nothing to move (canMove should have gated this)
    end
    active = true
    mountCF = m
    buildingFP = SizeClasses.buildingFootprint(teaSize)
    deckFP = SizeClasses.deckFootprint(deckSize)
    original = structure :: Model
    local dx, dz, facing = facingFromPivot(structure :: Model)
    current = { offset = { math.round(dx), math.round(dz) }, facing = facing }
    ghost = makeGhost(structure :: Model)
    fadeOriginal(structure :: Model, 0.7)
    applyGhost()
    buildHud() -- Step 4's HUD; store in `hud`
    table.insert(conns, RunService.RenderStepped:Connect(function()
        stepDrag(folder :: Instance)
    end))
    table.insert(conns, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == Enum.KeyCode.R then
            local idx = table.find(FACING_ORDER, current.facing) or 1
            current.facing = FACING_ORDER[(idx % 4) + 1]
            applyGhost()
        elseif input.KeyCode == Enum.KeyCode.X then
            exit()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            commit() -- desktop: click places. Touch uses the ✓ button (a tap would
            -- commit mid-positioning, so Touch deliberately does NOT commit here)
        end
    end))
    table.insert(conns, (structure :: Model).Destroying:Connect(exit)) -- rebuild landed mid-mode
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        table.insert(conns, humanoid.Died:Connect(exit))
    end
    table.insert(conns, player.CharacterAdded:Connect(exit))
end

EventBus.MoveTeahouse.Event:Connect(enter)
```

- [ ] **Step 6: Lint + suites**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run`
Expected: clean/green (file is GUI-only; suites unaffected).

- [ ] **Step 7: Commit**

```bash
git add roblox/src/client/MoveController.client.luau
git commit -m "feat(roblox): MoveController ghost-drag teahouse repositioning mode (B4)"
```

- [ ] **Step 8: Visual gate (Studio, user-driven).** Restart `rojo serve` (new `SetPlacement` remote). As the seeded owner: open the panel → "Move teahouse" → ghost appears at the current spot, original fades locally; drag across the deck (1-stud snap, never leaves the deck), R rotates; click commits → the real building rebuilds where the ghost stood and the back-door F prompts re-arm on it; re-enter and Cancel (✕ / X) → nothing changes; per-size memory: park L somewhere, display M, park M elsewhere, restore L → each size returns to its own spot; shrink the deck display below a corner-parked placement → building slides minimally inboard (stored spot restored when the deck display is raised). **One attempt, then stop and show the user.**

---

## Final: whole-branch review

After Task 6's gate, dispatch the whole-branch review (superpowers:requesting-code-review) over the B4 range (spec commit `962053e`..HEAD) with the spec + these Global Constraints. Then per SDD, finish the branch.
