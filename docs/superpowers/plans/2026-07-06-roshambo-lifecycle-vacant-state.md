# Roshambo Lifecycle + Vacant State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make teahouse materialization player-driven and reversible — a joining owner claims a vacant pad from the per-server pool (lit), a wanderer/leaver leaves it dormant — across two pads.

**Architecture:** A pure Lune-tested `SiteCoordinator` turns join/leave/startup into `Action`s by composing `PadRegistry` (claim/release) + `VacantState` (treatment). A Studio-only `TreatmentApplier` builds each pad's support once and (re)builds its structure per treatment, shuttering it when dormant. `main.server.luau` wires them to `PlayerAdded`/`PlayerRemoving`, replacing D.1's static block.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune test harness (`roblox/tests/`), Roblox Studio (MCP for the gate), the live `/api/v1` server (C.1, already rebuilt with the teahouses routes).

## Global Constraints

- **DI rule:** runtime modules never `require` each other except pure Lune-loadable modules; `SiteCoordinator` (pure) may `require("./VacantState")`; the Studio-only `TreatmentApplier` requires nothing and receives builders/ops/catalog by injection.
- **`--!strict`** header on every Luau module.
- **Lint gate (now green — keep it green):** the new file must pass `stylua --check <file>` and `selene src` must stay 0/0. Do NOT add `selene: allow` suppressions; if the deprecated `Instance.new(class, parent)` pattern would appear, construct without a parent arg and set `.Parent` last.
- **Studio-only modules can't be Lune-tested** (`CFrame`/`Instance`/`CollectionService`): `TreatmentApplier`, `PadSites`, and the `main.server` wiring have **no specs**; correctness is proven by the D.2 two-pad visual gate.
- **`teahouse-1story` prefab is PLACE-ONLY** (runs in the saved place; Rojo-commit of the prefab is a separate open follow-up).
- **Pad specs (baked, MCP-verified 2026-07-06):**
  - `cliff-proof`: `mountCF = { -60, 274, 105, 1,0,0, 0,1,0, 0,0,1 }`, `hand = "right"` (already in `PadSites`).
  - `cliff-proof-2`: `mountCF = { -130, 240, 125, 1,0,0, 0,1,0, 0,0,1 }`, `hand = "right"` (6/6 posts, lengths 7–32, ~73 studs from `cliff-proof`).
  - Both: `footprint = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }`, `vacantForm = "dormant-structure"`.
- **Registration order:** register `cliff-proof` **first** so the sole local joiner claims it (lit) and `cliff-proof-2` stays dormant.
- **Dormant shutter rule (real prefab names, verified):** parts named `Shoji` → `Transparency = 0` (opaque); parts named `ShojiGlow` → `Transparency = 1` (hidden; they have no child lights); every `PointLight` in the model → `Enabled = false`; the `ChochinSwing` model → `Destroy()`. Lit structures are left as built.
- **`VacantState.resolve(occupant, ownerLoadout, vacantForm)`** returns `{ kind = "structure", loadout, lit }` (occupant non-nil → `lit = true, loadout = ownerLoadout`; else dormant → `lit = false, loadout = { baseStyle = "teahouse-1story", colorScheme = "scheme.dormant" }`) or `{ kind = "garden" }` (only for `vacantForm == "pocket-garden"` — not used in D.2).
- **Stop-and-ask:** the visual gate is ONE attempt, then STOP for the user.

---

### Task 1: `SiteCoordinator` (pure, Lune TDD)

**Files:**
- Create: `roblox/src/shared/SiteCoordinator.luau`
- Test: `roblox/tests/SiteCoordinator.spec.luau`

**Interfaces:**
- Consumes: an injected `PadRegistry` instance (`:register(id, spec) -> boolean`, `:claimVacant(owner) -> {id, spec}?`, `:release(id) -> boolean`, `:get(id) -> {id, spec, occupant}?`), and `VacantState.resolve` (pure, `src/shared`).
- Produces: `SiteCoordinator.new(registry)`; `:registerPad(id: string, spec: any) -> boolean`; `:vacantActions() -> { Action }`; `:onJoin(playerId: string, ownedLoadout: any?) -> Action?`; `:onLeave(playerId: string) -> Action?`. `type Action = { padId: string, spec: any, treatment: VacantState.Treatment }`.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/SiteCoordinator.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function spec(id: string)
    return { id = id, mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "right", footprint = {}, vacantForm = "dormant-structure" }
end
local LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }

local function coordWithPads(ids: { string })
    local c = SiteCoordinator.new(PadRegistry.new())
    for _, id in ids do
        c:registerPad(id, spec(id))
    end
    return c
end

describe("SiteCoordinator.onJoin", function()
    test("an owner claims the first vacant pad with a lit treatment", function()
        local c = coordWithPads({ "p1", "p2" })
        local a = c:onJoin("player1", LOADOUT)
        expect(a).never.toBe(nil)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.kind).toBe("structure")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
    end)

    test("a wanderer (nil loadout) claims nothing", function()
        local c = coordWithPads({ "p1" })
        expect(c:onJoin("player1", nil)).toBe(nil)
        -- pad still vacant: a real owner can still claim it
        expect((c:onJoin("player2", LOADOUT) :: any).padId).toBe("p1")
    end)

    test("an owner gets nil when every pad is occupied", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", LOADOUT)
        expect(c:onJoin("player2", LOADOUT)).toBe(nil)
    end)

    test("two owners claim two distinct pads; a third gets nil", function()
        local c = coordWithPads({ "p1", "p2" })
        expect((c:onJoin("a", LOADOUT) :: any).padId).toBe("p1")
        expect((c:onJoin("b", LOADOUT) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", LOADOUT)).toBe(nil)
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases with a dormant treatment and frees the pad", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", LOADOUT)
        local a = c:onLeave("player1")
        expect(a).never.toBe(nil)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        -- freed: a new owner can claim it again
        expect((c:onJoin("player2", LOADOUT) :: any).padId).toBe("p1")
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coordWithPads({ "p1" })
        expect(c:onLeave("ghost")).toBe(nil)
    end)
end)

describe("SiteCoordinator.vacantActions", function()
    test("one dormant action per registered pad", function()
        local c = coordWithPads({ "p1", "p2" })
        local acts = c:vacantActions()
        expect(#acts).toBe(2)
        expect(acts[1].padId).toBe("p1")
        expect(acts[1].treatment.lit).toBe(false)
        expect(acts[2].padId).toBe("p2")
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `SiteCoordinator` module not found / `attempt to call a nil value`.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/SiteCoordinator.luau`:

```lua
--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (which treatment). Pure (Lune-tested): no Roblox
-- datatypes. The Studio-side TreatmentApplier executes the Actions.
local VacantState = require("./VacantState")

local SiteCoordinator = {}
SiteCoordinator.__index = SiteCoordinator

export type Action = { padId: string, spec: any, treatment: VacantState.Treatment }

function SiteCoordinator.new(registry: any)
    return setmetatable({
        _registry = registry,
        _padIds = {} :: { string },
        _held = {} :: { [string]: string },
    }, SiteCoordinator)
end

function SiteCoordinator:registerPad(id: string, spec: any): boolean
    local ok = self._registry:register(id, spec)
    if ok then
        table.insert(self._padIds, id)
    end
    return ok
end

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec then
            table.insert(out, {
                padId = id,
                spec = rec.spec,
                treatment = VacantState.resolve(nil, nil, rec.spec.vacantForm),
            })
        end
    end
    return out
end

function SiteCoordinator:onJoin(playerId: string, ownedLoadout: any?): Action?
    if ownedLoadout == nil then
        return nil
    end
    local claim = self._registry:claimVacant(playerId)
    if not claim then
        return nil
    end
    self._held[playerId] = claim.id
    return {
        padId = claim.id,
        spec = claim.spec,
        treatment = VacantState.resolve(playerId, ownedLoadout, claim.spec.vacantForm),
    }
end

function SiteCoordinator:onLeave(playerId: string): Action?
    local padId = self._held[playerId]
    if not padId then
        return nil
    end
    self._registry:release(padId)
    self._held[playerId] = nil
    local rec = self._registry:get(padId)
    local spec = rec and rec.spec
    return {
        padId = padId,
        spec = spec,
        treatment = VacantState.resolve(nil, nil, spec and spec.vacantForm),
    }
end

return SiteCoordinator
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS — all specs green (new `SiteCoordinator` block + the existing suite).

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src/shared/SiteCoordinator.luau tests/SiteCoordinator.spec.luau && selene src`
Expected: no diffs; `selene src` 0 errors / 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau
git commit -m "feat(roblox): SiteCoordinator lifecycle brain (sub-project D.2)"
```

---

### Task 2: F2 — reconcile the `Mount` footprint type

**Files:**
- Modify: `roblox/src/shared/StructurePlanner.luau:15`
- Modify: `roblox/tests/StructurePlanner.spec.luau:8`
- Modify: `roblox/tests/StructureBuilder.spec.luau:37,59`

**Interfaces:**
- Produces: `StructurePlanner.Mount.footprint` typed as `{ minX: number, maxX: number, minZ: number, maxZ: number }` (matching `PadPlanner.Footprint`), so `PadBuilder`'s returned mount type-aligns with `StructureBuilder.build`'s `mount` param. `StructurePlanner.plan` reads only `mount.cframe`/`mount.hand`, so this is a pure annotation + fixture change — no behavior change.

- [ ] **Step 1: Update the type**

In `roblox/src/shared/StructurePlanner.luau`, change the `Mount` type (line 15):

```lua
export type Mount = { cframe: { number }, hand: string, footprint: { minX: number, maxX: number, minZ: number, maxZ: number } }
```

- [ ] **Step 2: Update the test fixtures**

In `roblox/tests/StructurePlanner.spec.luau` line 8, change the `baseMount` footprint:

```lua
    return { cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "right", footprint = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } }
```

In `roblox/tests/StructureBuilder.spec.luau`, change BOTH mount fixtures (lines 37 and 59) from `footprint = { x = 26, z = 20 }` to:

```lua
        footprint = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 },
```

(The two lines currently read `{ cframe = { 1, 2, 3, ... }, hand = "left", footprint = { x = 26, z = 20 } }` and `{ cframe = { 0, 0, 0, ... }, hand = "right", footprint = { x = 26, z = 20 } }` — update only the `footprint = { x = 26, z = 20 }` part in each.)

- [ ] **Step 3: Run the tests to verify they still pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS — the planner ignores `footprint`, so behavior is unchanged and all specs stay green.

- [ ] **Step 4: Lint**

Run: `cd roblox && stylua --check src/shared/StructurePlanner.luau tests/StructurePlanner.spec.luau tests/StructureBuilder.spec.luau && selene src`
Expected: no diffs; 0/0.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructurePlanner.luau roblox/tests/StructurePlanner.spec.luau roblox/tests/StructureBuilder.spec.luau
git commit -m "refactor(roblox): reconcile Mount.footprint with PadPlanner.Footprint (D.2 F2)"
```

---

### Task 3: `TreatmentApplier` (Studio-only)

**Files:**
- Create: `roblox/src/server/TreatmentApplier.luau`

**Interfaces:**
- Consumes: `PadBuilder.build(spec, ops)` (B), `StructureBuilder.build(loadout, mount, catalog, ops)` (A), `StructureCatalog`, `StructureOps` (D.1), `PadOps.new(mountCF, parent)` (D.1); a `spec` (`PadSites` entry: `{ id, mountCF, hand, footprint, vacantForm }`) and an `Action.treatment` (`VacantState.Treatment`).
- Produces: `TreatmentApplier.new(deps) -> TreatmentApplier`; `:buildSupport(spec)` (builds the 6 posts once per pad); `:apply(padId, spec, treatment)` (transactionally rebuilds the pad's `Structure` child per the treatment, shuttering when not lit). `deps = { container, padBuilder, structureBuilder, catalog, structureOps, padOpsNew }`.

No Lune test (Roblox datatypes). Verified by the Task 5 gate.

- [ ] **Step 1: Write the module**

Create `roblox/src/server/TreatmentApplier.luau`:

```lua
--!strict
-- Studio-runtime applier for sub-project D. Builds a pad's support posts once
-- (buildSupport) and transactionally (re)builds its Structure child per a
-- VacantState Treatment (apply), shuttering the structure when not lit. Roblox
-- datatypes -> not Lune-testable; proven by the D.2 visual gate. A thin adapter:
-- the builders/ops/catalog are injected.
local TreatmentApplier = {}
TreatmentApplier.__index = TreatmentApplier

export type Deps = {
    container: Instance,
    padBuilder: any,
    structureBuilder: any,
    catalog: any,
    structureOps: any,
    padOpsNew: (CFrame, Instance) -> any,
}

function TreatmentApplier.new(deps: Deps)
    return setmetatable({
        _c = deps.container,
        _padBuilder = deps.padBuilder,
        _structureBuilder = deps.structureBuilder,
        _catalog = deps.catalog,
        _structureOps = deps.structureOps,
        _padOpsNew = deps.padOpsNew,
        _folders = {} :: { [string]: Folder },
    }, TreatmentApplier)
end

function TreatmentApplier:_folder(padId: string): Folder
    local f = self._folders[padId]
    if not f then
        f = Instance.new("Folder")
        f.Name = "MaterializedSite_" .. padId
        f.Parent = self._c
        self._folders[padId] = f
    end
    return f
end

function TreatmentApplier:buildSupport(spec: any)
    local folder = self:_folder(spec.id)
    local mountCF = CFrame.new(table.unpack(spec.mountCF))
    self._padBuilder.build(spec, self._padOpsNew(mountCF, folder))
end

local function shutter(model: Model)
    for _, d in model:GetDescendants() do
        if d:IsA("PointLight") then
            d.Enabled = false
        elseif d:IsA("BasePart") then
            if d.Name == "Shoji" then
                d.Transparency = 0
            elseif d.Name == "ShojiGlow" then
                d.Transparency = 1
            end
        end
    end
    local chochin = model:FindFirstChild("ChochinSwing", true)
    if chochin then
        chochin:Destroy()
    end
end

function TreatmentApplier:apply(padId: string, spec: any, treatment: any)
    local folder = self:_folder(padId)
    if treatment.kind ~= "structure" then
        local existing = folder:FindFirstChild("Structure")
        if existing then
            existing:Destroy()
        end
        return -- garden treatment: applier deferred to D.5
    end
    local mount = { cframe = spec.mountCF, hand = spec.hand, footprint = spec.footprint }
    local ok, result = pcall(function()
        return self._structureBuilder.build(treatment.loadout, mount, self._catalog, self._structureOps)
    end)
    if not ok then
        warn(`[D.2] apply failed for {padId}: {result}`)
        return -- keep whatever structure was already there (F4: no crash, no orphan swap)
    end
    local model = result :: Model
    model.Name = "Structure"
    if not treatment.lit then
        shutter(model)
    end
    local existing = folder:FindFirstChild("Structure")
    if existing then
        existing:Destroy()
    end
    model.Parent = folder
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end

return TreatmentApplier
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src/server/TreatmentApplier.luau && selene src`
Expected: no diffs (run `stylua src/server/TreatmentApplier.luau` first to auto-format if needed); `selene src` 0/0, no `selene: allow` added.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): TreatmentApplier — build support + shutter (sub-project D.2)"
```

---

### Task 4: `PadSites` — add `cliff-proof-2`

**Files:**
- Modify: `roblox/src/server/PadSites.luau`

**Interfaces:**
- Produces: `PadSites["cliff-proof-2"]` = `{ id = "cliff-proof-2", mountCF = { -130, 240, 125, ... }, hand = "right", footprint = <shared>, vacantForm = "dormant-structure" }` (MCP-verified 6/6 posts).

- [ ] **Step 1: Add the entry**

In `roblox/src/server/PadSites.luau`, add a second entry inside the returned table (after the `["cliff-proof"]` entry), and extend the header comment:

```lua
    ["cliff-proof-2"] = {
        id = "cliff-proof-2",
        mountCF = { -130, 240, 125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        footprint = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 },
        vacantForm = "dormant-structure",
    },
```

(The header note for `cliff-proof-2`: a second terrain-backed shelf ~73 studs from `cliff-proof`, datum lowered to 240 so its stilts (7–32) match; MCP-verified 6/6 on 2026-07-06. It stays dormant while `cliff-proof` is claimed.)

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src/server/PadSites.luau && selene src`
Expected: no diffs; 0/0.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/PadSites.luau
git commit -m "feat(roblox): PadSites — second pad cliff-proof-2 (sub-project D.2)"
```

---

### Task 5: Wire `main.server.luau` lifecycle + two-pad visual gate

**Files:**
- Modify: `roblox/src/server/main.server.luau` (replace the D.1 static block)

**Interfaces:**
- Consumes: `SiteCoordinator` (Task 1), `TreatmentApplier` (Task 3), `PadSites` (Task 4), `PadRegistry`/`PadBuilder`/`StructureBuilder`/`StructureCatalog` (shared), `StructureOps`/`PadOps` (D.1), `net:getTeahouses` (D.1).
- Produces: two materialized sites under `workspace.TeahouseSites`; a claimed/lit structure on the pad the local player claims, a dormant one on the other.

Setup (seeding the local player) is folded into this task because the gate needs it.

- [ ] **Step 1: Replace the D.1 static block**

In `roblox/src/server/main.server.luau`, delete the entire `-- D.1: static materialization spine …` block (from that comment through its closing `end)`), keeping the following `print(\`[ROSHAMBO] playable loop starting …\`)` line, and insert this in its place (immediately before that `print`):

```lua
-- D.2: lifecycle + vacant state — two pads; a joining owner claims one (lit), the
-- other stays dormant; release on leave. Replaces D.1's static single-owner block.
local StructureBuilder = require(shared:WaitForChild("StructureBuilder"))
local PadBuilder = require(shared:WaitForChild("PadBuilder"))
local StructureCatalog = require(shared:WaitForChild("StructureCatalog"))
local PadRegistry = require(shared:WaitForChild("PadRegistry"))
local SiteCoordinator = require(shared:WaitForChild("SiteCoordinator"))
local StructureOps = require(script.Parent:WaitForChild("StructureOps"))
local PadOps = require(script.Parent:WaitForChild("PadOps"))
local PadSites = require(script.Parent:WaitForChild("PadSites"))
local TreatmentApplier = require(script.Parent:WaitForChild("TreatmentApplier"))

local siteCoordinator = SiteCoordinator.new(PadRegistry.new())
local sitesFolder = Instance.new("Folder")
sitesFolder.Name = "TeahouseSites"
sitesFolder.Parent = workspace

local applier = TreatmentApplier.new({
    container = sitesFolder,
    padBuilder = PadBuilder,
    structureBuilder = StructureBuilder,
    catalog = StructureCatalog,
    structureOps = StructureOps,
    padOpsNew = PadOps.new,
})

-- cliff-proof registered first: the sole local joiner claims it; cliff-proof-2 stays dormant
for _, id in { "cliff-proof", "cliff-proof-2" } do
    siteCoordinator:registerPad(id, PadSites[id])
end
for _, action in siteCoordinator:vacantActions() do
    applier:buildSupport(action.spec)
    applier:apply(action.padId, action.spec, action.treatment)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        local res = net:getTeahouses(tostring(player.UserId))
        local loadout = if res.ok then (res.data.teahouses or {}).M else nil
        local action = siteCoordinator:onJoin(tostring(player.UserId), loadout)
        if action then
            applier:apply(action.padId, action.spec, action.treatment)
            print(`[D.2] {player.UserId} claimed {action.padId}`)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local action = siteCoordinator:onLeave(tostring(player.UserId))
    if action then
        applier:apply(action.padId, action.spec, action.treatment)
        print(`[D.2] {player.UserId} released {action.padId}`)
    end
end)
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua src/server/main.server.luau && stylua --check src/server/main.server.luau && selene src`
Expected: clean; 0/0.

- [ ] **Step 3: Seed the local player's loadout**

Determine the local player's Roblox `UserId` (in the running Studio place) and seed it a vermilion loadout so the claim path lights up. Run against the same backend the place uses (`http://localhost:3001`, key `roshambo_local_dev_api_key`):

First read the UserId — in Studio, Play once and read the console, or run (Edit) `return game:GetService("StudioService"):GetUserId()`. Then:

```bash
curl -sS -X PUT "http://localhost:3001/api/v1/players/<USERID>/teahouses/M" \
  -H "X-API-Key: roshambo_local_dev_api_key" -H "Content-Type: application/json" \
  -d '{"loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}'
```

Expected: `200 {"sizeClass":"M","loadout":{...vermilion}}`.

- [ ] **Step 4: Run the two-pad visual gate (ONE attempt, then STOP)**

With Rojo synced into the saved place, Play, and confirm under `workspace.TeahouseSites`:
- **`MaterializedSite_cliff-proof`** — a **claimed/lit** teahouse: vermilion, `ShojiGlow` visible, `ChochinSwing` present, glow on, on 6 stilts.
- **`MaterializedSite_cliff-proof-2`** — a **vacant/dormant** teahouse: `scheme.dormant` dark recolor, `Shoji` opaque (solid), `ShojiGlow` hidden, no chōchin, lights off, on 6 stilts.
- Console shows `[D.2] <userid> claimed cliff-proof` and no `[D.2] apply failed` warnings.

Both should stand within one camera frame (~73 studs apart). **Do not self-judge/iterate — STOP and ask the user to look.** (Release-on-leave is covered by Task 1's unit test, not this gate.)

- [ ] **Step 5: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): player-driven lifecycle + vacant state on two pads (sub-project D.2)"
```

---

## Self-Review

**Spec coverage:**
- `SiteCoordinator` (pure, Lune-tested) join/leave/startup → Actions → Task 1. ✓
- `TreatmentApplier` build-support-once + rebuild-per-treatment + dormant shutter → Task 3. ✓
- Second surveyed pad `cliff-proof-2` → Task 4 (coords MCP-verified, baked in Global Constraints). ✓
- F2 Mount/footprint reconcile → Task 2. ✓
- F4 failure cleanup → Task 3 (`apply` pcall, transactional swap, keep-old-on-failure). ✓
- Lifecycle wiring replacing D.1 static block, register order, startup dormant, join/leave → Task 5 Step 1. ✓
- Seed local player + two-pad gate criteria → Task 5 Steps 3–4. ✓
- Dormant shutter uses real verified part names (`Shoji`/`ShojiGlow`/`ChochinSwing` + all PointLights) → Global Constraints + Task 3. ✓
- Non-goals (multi-size, preference, garden applier, real perch/migration, release-in-gate) → excluded; no task implements them. ✓

**Placeholder scan:** `<USERID>` in Task 5 Step 3 is an execution-time value the step tells you how to read (`StudioService:GetUserId()`); not an unfilled placeholder. No `TODO`/`TBD`/"add error handling".

**Type consistency:** `Action = { padId, spec, treatment }` produced in Task 1 is consumed field-for-field in Tasks 3/5 (`applier:apply(action.padId, action.spec, action.treatment)`). `TreatmentApplier.new(deps)` keys (`container/padBuilder/structureBuilder/catalog/structureOps/padOpsNew`) in Task 3 match the table built in Task 5 Step 1. `padOpsNew = PadOps.new` matches `PadOps.new(mountCF, parent)` (D.1). `spec.id`/`spec.mountCF`/`spec.hand`/`spec.footprint`/`spec.vacantForm` match the `PadSites` entry shape (Task 4). `VacantState.resolve(occupant, ownerLoadout, vacantForm)` calls match its signature; the dormant loadout's `colorScheme == "scheme.dormant"` matches the Task 1 test assertion.
