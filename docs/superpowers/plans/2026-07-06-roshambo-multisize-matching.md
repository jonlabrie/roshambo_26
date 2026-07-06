# Roshambo Multi-Size Fit Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A joining teahouse-owner gets the largest owned size that fits a vacant pad (falling back smaller), materialized at that size, across two differently-footprinted pads.

**Architecture:** A pure `SizeClasses` module defines `S/M/L` (footprint + proxy scale). `SiteCoordinator:onJoin` generalizes to take the player's whole `{sizeClass→loadout}` map and pick the largest owned size that fits a vacant pad via `PadRegistry:claimVacantFor`; the `Action` carries the chosen `scale`. `TreatmentApplier:apply` gains a `Model:ScaleTo(scale)` step. Wiring passes the full map and threads scale.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune test harness (`roblox/tests/`), Roblox Studio (MCP for the gate), the live `/api/v1` server (C.1, running with the teahouses routes).

## Global Constraints

- **DI rule:** pure Lune-loadable modules may require each other — `SizeClasses` requires `./PadRegistry` (for the static `fits`); `SiteCoordinator` requires `./VacantState` + `./SizeClasses`. The `PadRegistry` **instance** stays injected. The Studio-only `TreatmentApplier` requires nothing.
- **`--!strict`** header on every Luau module.
- **Lint gate is GREEN — keep it:** new/changed files pass `stylua --check <file>` and `selene src` stays 0/0. No `selene: allow` suppressions; no deprecated `Instance.new(class, parent)`.
- **Studio-only** (`TreatmentApplier`, `PadSites`, `main.server` wiring) have no Lune tests; correctness proven by the two-pad visual gate.
- **Sizes (S = today's teahouse):** `scale = { S = 1.0, M = 1.5, L = 2.0 }`; `order = { "L", "M", "S" }` (largest first). `BASE_FOOTPRINT = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }`. `footprintFor(size) = BASE × scale[size]`.
- **Pads (MCP-verified 2026-07-06):** `cliff-proof` (small) footprint = base (fits S), mountCF `{ -60, 274, 105, … }`; `cliff-proof-2` (large) footprint = `2×base` = `{ minX = -14.80, maxX = 30.00, minZ = -23.40, maxZ = 8.64 }` (fits L/M/S), mountCF `{ -130, 240, 125, … }` (6/6 posts). **Register `cliff-proof-2` first.**
- **`PadRegistry:claimVacantFor(owner, structFootprint)`** returns `{id, spec}?` — first vacant pad whose `spec.footprint` contains `structFootprint`; `PadRegistry.fits(padFP, structFP)` is the static containment check.
- **`VacantState.resolve(occupant, ownerLoadout, vacantForm)`** → `{kind="structure", loadout, lit}` (occupant non-nil → lit=true/loadout=ownerLoadout; else dormant lit=false/loadout={baseStyle="teahouse-1story", colorScheme="scheme.dormant"}).
- **`Model:ScaleTo(scale)`** scales about the datum pivot; a no-op at `scale == 1`.
- **Stop-and-ask:** the visual gate is ONE attempt, then STOP for the user.

---

### Task 1: `SizeClasses` (pure, Lune TDD)

**Files:**
- Create: `roblox/src/shared/SizeClasses.luau`
- Test: `roblox/tests/SizeClasses.spec.luau`

**Interfaces:**
- Consumes: `PadRegistry.fits` (static, `src/shared`).
- Produces: `SizeClasses.BASE_FOOTPRINT`, `.order` (`{"L","M","S"}`), `.scale` (`{S=1.0,M=1.5,L=2.0}`), `SizeClasses.footprintFor(size: string) -> Footprint`, `SizeClasses.nativeSize(padFootprint: Footprint) -> string?` (largest class fitting the pad, or nil). `Footprint = {minX,maxX,minZ,maxZ}`.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/SizeClasses.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("SizeClasses.footprintFor", function()
    test("S is the base footprint (scale 1.0)", function()
        local s = SizeClasses.footprintFor("S")
        expect(s.minX).toBeCloseTo(-7.40)
        expect(s.maxX).toBeCloseTo(15.00)
        expect(s.minZ).toBeCloseTo(-11.70)
        expect(s.maxZ).toBeCloseTo(4.32)
    end)

    test("L is 2x the base", function()
        local l = SizeClasses.footprintFor("L")
        expect(l.minX).toBeCloseTo(-14.80)
        expect(l.maxX).toBeCloseTo(30.00)
        expect(l.minZ).toBeCloseTo(-23.40)
        expect(l.maxZ).toBeCloseTo(8.64)
    end)

    test("scale values and order", function()
        expect(SizeClasses.scale.S).toBe(1.0)
        expect(SizeClasses.scale.M).toBe(1.5)
        expect(SizeClasses.scale.L).toBe(2.0)
        expect(SizeClasses.order[1]).toBe("L")
        expect(SizeClasses.order[3]).toBe("S")
    end)
end)

describe("SizeClasses.nativeSize", function()
    test("a base pad's native size is S", function()
        expect(SizeClasses.nativeSize(SizeClasses.footprintFor("S"))).toBe("S")
    end)

    test("a 2x-base pad's native size is L", function()
        expect(SizeClasses.nativeSize(SizeClasses.footprintFor("L"))).toBe("L")
    end)

    test("a pad smaller than S has no native size", function()
        expect(SizeClasses.nativeSize({ minX = -1, maxX = 1, minZ = -1, maxZ = 1 })).toBe(nil)
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `SizeClasses` module not found.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/SizeClasses.luau`:

```lua
--!strict
-- The single definition of teahouse size classes for sub-project D. Pure data +
-- footprint helpers (Lune-tested). `scale` is a TESTING PROXY on the one prefab
-- (applied via Model:ScaleTo); the destination is authored per-size prefabs, at
-- which point scale -> 1 and each size's stored loadout points at its authored
-- baseStyle, with NO change here. S = today's teahouse (base footprint); L = 2x S.
local PadRegistry = require("./PadRegistry")

local SizeClasses = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }

SizeClasses.BASE_FOOTPRINT = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 } :: Footprint
SizeClasses.order = { "L", "M", "S" } -- largest first
SizeClasses.scale = { S = 1.0, M = 1.5, L = 2.0 } :: { [string]: number }

function SizeClasses.footprintFor(sizeClass: string): Footprint
    local s = SizeClasses.scale[sizeClass]
    local b = SizeClasses.BASE_FOOTPRINT
    return { minX = b.minX * s, maxX = b.maxX * s, minZ = b.minZ * s, maxZ = b.maxZ * s }
end

function SizeClasses.nativeSize(padFootprint: Footprint): string?
    for _, size in SizeClasses.order do
        if PadRegistry.fits(padFootprint, SizeClasses.footprintFor(size)) then
            return size
        end
    end
    return nil
end

return SizeClasses
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS — all specs green.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src/shared/SizeClasses.luau tests/SizeClasses.spec.luau && selene src`
Expected: no diffs; 0/0.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): SizeClasses (S/M/L footprint + proxy scale) (sub-project D.3)"
```

---

### Task 2: `SiteCoordinator` multi-size `onJoin` + scale in Action

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau` (full rewrite below)
- Modify: `roblox/tests/SiteCoordinator.spec.luau` (full rewrite below — D.2 tests to the map form + real footprints, plus D.3 tests)

**Interfaces:**
- Consumes: `SizeClasses` (Task 1), injected `PadRegistry` (`:claimVacantFor(owner, footprint)`, `:register`, `:release`, `:get`), `VacantState.resolve`.
- Produces: `onJoin(playerId, ownedTeahouses: {[string]: any}?) -> Action?` (largest owned size that fits, size-first); `Action = { padId, spec, treatment, scale: number, sizeClass: string? }`; `vacantActions`/`onLeave` carry the pad's `nativeSize` scale.

- [ ] **Step 1: Write the failing tests**

Replace `roblox/tests/SiteCoordinator.spec.luau` entirely with:

```lua
--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

local HUGE = { minX = -1000, maxX = 1000, minZ = -1000, maxZ = 1000 }
local function spec(id: string, footprint: any?)
    return {
        id = id,
        mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        footprint = footprint or HUGE,
        vacantForm = "dormant-structure",
    }
end
local LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }
local OWNED = { M = LOADOUT } -- a player owning a single (M) teahouse

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
        local a = c:onJoin("player1", OWNED)
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.kind).toBe("structure")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
    end)

    test("a wanderer (nil map) claims nothing", function()
        local c = coordWithPads({ "p1" })
        expect(c:onJoin("player1", nil)).toBe(nil)
        expect((c:onJoin("player2", OWNED) :: any).padId).toBe("p1")
    end)

    test("an owner gets nil when every pad is occupied", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", OWNED)
        expect(c:onJoin("player2", OWNED)).toBe(nil)
    end)

    test("two owners claim two distinct pads; a third gets nil", function()
        local c = coordWithPads({ "p1", "p2" })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", OWNED)).toBe(nil)
    end)

    test("a duplicate onJoin by the same player claims nothing and consumes no extra pad", function()
        local c = coordWithPads({ "p1", "p2" })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect(c:onJoin("a", OWNED)).toBe(nil)
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
    end)

    test("picks the largest owned size that fits, with its scale/sizeClass", function()
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("big", spec("big", SizeClasses.footprintFor("L")))
        local a = c:onJoin("p", { S = LOADOUT, M = LOADOUT, L = LOADOUT })
        expect((a :: any).sizeClass).toBe("L")
        expect((a :: any).scale).toBe(2.0)
        expect((a :: any).treatment.lit).toBe(true)
    end)

    test("falls back to a smaller owned size when the vacant pad is too small for the largest", function()
        -- pad fits M (1.5x) but not L (2x)
        local padFP = { minX = -11.84, maxX = 24.0, minZ = -18.72, maxZ = 6.912 }
        local c1 = SiteCoordinator.new(PadRegistry.new())
        c1:registerPad("m", spec("m", padFP))
        expect(c1:onJoin("p", { L = LOADOUT })).toBe(nil) -- owns only L, which doesn't fit

        local c2 = SiteCoordinator.new(PadRegistry.new())
        c2:registerPad("m", spec("m", padFP))
        local a = c2:onJoin("p", { L = LOADOUT, M = LOADOUT })
        expect((a :: any).sizeClass).toBe("M")
        expect((a :: any).scale).toBe(1.5)
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases with a dormant treatment and frees the pad", function()
        local c = coordWithPads({ "p1" })
        c:onJoin("player1", OWNED)
        local a = c:onLeave("player1")
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        expect((c:onJoin("player2", OWNED) :: any).padId).toBe("p1")
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coordWithPads({ "p1" })
        expect(c:onLeave("ghost")).toBe(nil)
    end)

    test("dormant action carries the pad's native-size scale", function()
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("big", spec("big", SizeClasses.footprintFor("L")))
        c:onJoin("p", { L = LOADOUT })
        expect((c:onLeave("p") :: any).scale).toBe(2.0) -- big pad's native size is L
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

    test("skips pads that are currently occupied", function()
        local c = coordWithPads({ "p1", "p2" })
        c:onJoin("player1", OWNED)
        local acts = c:vacantActions()
        expect(#acts).toBe(1)
        expect(acts[1].padId).toBe("p2")
    end)

    test("each dormant action carries the pad's native-size scale", function()
        local c = SiteCoordinator.new(PadRegistry.new())
        c:registerPad("small", spec("small", SizeClasses.footprintFor("S")))
        c:registerPad("big", spec("big", SizeClasses.footprintFor("L")))
        local acts = c:vacantActions()
        expect(acts[1].scale).toBe(1.0) -- small pad -> native S
        expect(acts[2].scale).toBe(2.0) -- big pad -> native L
    end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — the new size/scale tests fail (old `onJoin` takes a bare loadout and returns no `scale`/`sizeClass`; `claimVacantFor` unused).

- [ ] **Step 3: Rewrite the module**

Replace `roblox/src/shared/SiteCoordinator.luau` entirely with:

```lua
--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (treatment) and SizeClasses (multi-size fit). Pure
-- (Lune-tested): no Roblox datatypes. The Studio-side TreatmentApplier executes
-- the Actions (and applies Action.scale via Model:ScaleTo).
local VacantState = require("./VacantState")
local SizeClasses = require("./SizeClasses")

local SiteCoordinator = {}
SiteCoordinator.__index = SiteCoordinator

export type Action = {
    padId: string,
    spec: any,
    treatment: VacantState.Treatment,
    scale: number,
    sizeClass: string?,
}

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

local function dormantScale(spec: any): number
    local native = spec and SizeClasses.nativeSize(spec.footprint)
    return if native then SizeClasses.scale[native] else 1
end

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            table.insert(out, {
                padId = id,
                spec = rec.spec,
                treatment = VacantState.resolve(nil, nil, rec.spec.vacantForm),
                scale = dormantScale(rec.spec),
            })
        end
    end
    return out
end

function SiteCoordinator:onJoin(playerId: string, ownedTeahouses: { [string]: any }?): Action?
    if self._held[playerId] ~= nil then
        return nil
    end
    if ownedTeahouses == nil then
        return nil
    end
    for _, size in SizeClasses.order do
        local loadout = ownedTeahouses[size]
        if loadout ~= nil then
            local claim = self._registry:claimVacantFor(playerId, SizeClasses.footprintFor(size))
            if claim then
                self._held[playerId] = claim.id
                return {
                    padId = claim.id,
                    spec = claim.spec,
                    treatment = VacantState.resolve(playerId, loadout, claim.spec.vacantForm),
                    scale = SizeClasses.scale[size],
                    sizeClass = size,
                }
            end
        end
    end
    return nil
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
        scale = dormantScale(spec),
    }
end

return SiteCoordinator
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS — all specs green (updated D.2 tests + new D.3 tests + the rest of the suite).

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src/shared/SiteCoordinator.luau tests/SiteCoordinator.spec.luau && selene src`
Expected: no diffs; 0/0.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau
git commit -m "feat(roblox): SiteCoordinator multi-size fit matching + scale in Action (sub-project D.3)"
```

---

### Task 3: `TreatmentApplier` — apply scale

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau` (the `apply` method)

**Interfaces:**
- Consumes: an `Action`'s `scale` (number) — passed by the caller.
- Produces: `:apply(padId, spec, treatment, scale)` — after building and naming the structure, `Model:ScaleTo(scale)` when `scale ~= 1`.

No Lune test (Studio-only). Verified by the Task 5 gate.

- [ ] **Step 1: Update the `apply` signature and add the scale step**

In `roblox/src/server/TreatmentApplier.luau`, change the `apply` method. Replace:

```lua
function TreatmentApplier:apply(padId: string, spec: any, treatment: any)
```

with:

```lua
function TreatmentApplier:apply(padId: string, spec: any, treatment: any, scale: number?)
```

Then, inside `apply`, immediately after these two lines:

```lua
    local model = result :: Model
    model.Name = "Structure"
```

insert:

```lua
    if scale ~= nil and scale ~= 1 then
        model:ScaleTo(scale)
    end
```

(so the structure is scaled about its datum pivot before the shutter/parent steps).

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src/server/TreatmentApplier.luau && selene src`
Expected: no diffs (auto-format with `stylua src/server/TreatmentApplier.luau` first if needed); `selene src` 0/0, no `selene: allow`.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): TreatmentApplier applies Action.scale via ScaleTo (sub-project D.3)"
```

---

### Task 4: `PadSites` — `cliff-proof-2` becomes the large (2×base) pad

**Files:**
- Modify: `roblox/src/server/PadSites.luau`

**Interfaces:**
- Produces: `PadSites["cliff-proof-2"].footprint = { minX = -14.80, maxX = 30.00, minZ = -23.40, maxZ = 8.64 }` (2×base); `cliff-proof` unchanged (base).

- [ ] **Step 1: Enlarge `cliff-proof-2`'s footprint**

In `roblox/src/server/PadSites.luau`, change the `cliff-proof-2` entry's `footprint` from `{ minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }` to:

```lua
        footprint = { minX = -14.80, maxX = 30.00, minZ = -23.40, maxZ = 8.64 },
```

and update its header comment to describe it as the **large** pad (2×base, fits L; MCP-verified 6/6 at `(-130,240,125)` on 2026-07-06). Leave `cliff-proof` (the small pad, base footprint) unchanged.

- [ ] **Step 2: Verify the enlarged footprint still lands 6/6 posts (MCP)**

Run this in Studio (Edit) via MCP `execute_luau` and confirm `6/6`:

```lua
local FP = { minX = -14.80, maxX = 30.00, minZ = -23.40, maxZ = 8.64 }
local PH, cx = 0.6, (-14.80 + 30.00) / 2
local layout = {
    { FP.minX + PH, FP.minZ + PH }, { FP.maxX - PH, FP.minZ + PH },
    { FP.minX + PH, FP.maxZ - PH }, { FP.maxX - PH, FP.maxZ - PH },
    { cx, FP.minZ + PH }, { cx, FP.maxZ - PH },
}
local mountCF = CFrame.new(-130, 240, 125)
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { workspace.Terrain }
local hits = 0
for _, l in layout do
    local top = mountCF * CFrame.new(l[1], 0, l[2])
    if workspace:Raycast(Vector3.new(top.Position.X, 244, top.Position.Z), Vector3.new(0, -600, 0), rp) then hits += 1 end
end
return "posts hitting terrain: " .. hits .. "/6"
```

Expected: `posts hitting terrain: 6/6`.

- [ ] **Step 3: Lint**

Run: `cd roblox && stylua --check src/server/PadSites.luau && selene src`
Expected: no diffs; 0/0.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/PadSites.luau
git commit -m "feat(roblox): PadSites — cliff-proof-2 becomes the large 2x pad (sub-project D.3)"
```

---

### Task 5: Wire `main.server.luau` (full map + scale + register order) + seed + two-pad gate

**Files:**
- Modify: `roblox/src/server/main.server.luau` (the D.2 block, ~lines 350–413)

**Interfaces:**
- Consumes: `SiteCoordinator:onJoin(playerId, ownedTeahouses)` (Task 2), `TreatmentApplier:apply(padId, spec, treatment, scale)` (Task 3), `PadSites` (Task 4).
- Produces: a large lit L teahouse on `cliff-proof-2` and a small dormant S shell on `cliff-proof`.

Setup (seeding S/M/L) is folded in because the gate needs it.

- [ ] **Step 1: Register the large pad first**

In `roblox/src/server/main.server.luau`, change the registration loop:

```lua
-- cliff-proof registered first: the sole local joiner claims it; cliff-proof-2 stays dormant
for _, id in { "cliff-proof", "cliff-proof-2" } do
    siteCoordinator:registerPad(id, PadSites[id])
end
```

to:

```lua
-- cliff-proof-2 (large) registered first: the sole local joiner claims it with L; cliff-proof (small) stays dormant at S
for _, id in { "cliff-proof-2", "cliff-proof" } do
    siteCoordinator:registerPad(id, PadSites[id])
end
```

- [ ] **Step 2: Thread `scale` through the startup vacant loop**

Change:

```lua
for _, action in siteCoordinator:vacantActions() do
    applier:buildSupport(action.spec)
    applier:apply(action.padId, action.spec, action.treatment)
end
```

to:

```lua
for _, action in siteCoordinator:vacantActions() do
    applier:buildSupport(action.spec)
    applier:apply(action.padId, action.spec, action.treatment, action.scale)
end
```

- [ ] **Step 3: Pass the full teahouses map on join + thread scale (both apply sites)**

In the `PlayerAdded` handler, change:

```lua
        -- a non-ok fetch reads as "owns nothing" (no pad this session, no retry) — a D.3+ concern
        local loadout = if res.ok then (res.data.teahouses or {}).M else nil
        local action = siteCoordinator:onJoin(tostring(player.UserId), loadout)
```

to:

```lua
        -- a non-ok fetch reads as "owns nothing" (no pad this session, no retry)
        local owned = if res.ok then res.data.teahouses or {} else nil
        local action = siteCoordinator:onJoin(tostring(player.UserId), owned)
```

Then change the release-path apply and the claim apply/print:

```lua
                local rel = siteCoordinator:onLeave(tostring(player.UserId))
                if rel then
                    applier:apply(rel.padId, rel.spec, rel.treatment)
                end
                return
            end
            applier:apply(action.padId, action.spec, action.treatment)
            print(`[D.2] {player.UserId} claimed {action.padId}`)
```

to:

```lua
                local rel = siteCoordinator:onLeave(tostring(player.UserId))
                if rel then
                    applier:apply(rel.padId, rel.spec, rel.treatment, rel.scale)
                end
                return
            end
            applier:apply(action.padId, action.spec, action.treatment, action.scale)
            print(`[D.3] {player.UserId} claimed {action.padId} @ {tostring(action.sizeClass)}`)
```

And in the `PlayerRemoving` handler, change `applier:apply(action.padId, action.spec, action.treatment)` to `applier:apply(action.padId, action.spec, action.treatment, action.scale)` (and its `[D.2]` print to `[D.3]`).

- [ ] **Step 4: Lint**

Run: `cd roblox && stylua src/server/main.server.luau && stylua --check src/server/main.server.luau && selene src`
Expected: clean; 0/0.

- [ ] **Step 5: Seed the local player S/M/L**

Read the local player's UserId (Studio Edit): `return game:GetService("StudioService"):GetUserId()`. Then seed all three sizes (vermilion) against `http://localhost:3001` (key `roshambo_local_dev_api_key`):

```bash
for SZ in S M L; do
  curl -sS -X PUT "http://localhost:3001/api/v1/players/<USERID>/teahouses/$SZ" \
    -H "X-API-Key: roshambo_local_dev_api_key" -H "Content-Type: application/json" \
    -d '{"loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}'
  echo
done
curl -sS "http://localhost:3001/api/v1/players/<USERID>/teahouses" -H "X-API-Key: roshambo_local_dev_api_key"
```

Expected: the final GET returns `{"teahouses":{"S":{…},"M":{…},"L":{…}}}`.

- [ ] **Step 6: Run the two-pad visual gate (ONE attempt, then STOP)**

With Rojo synced, Play, and confirm under `workspace.TeahouseSites`:
- **`MaterializedSite_cliff-proof-2`** — a **large (2×) lit L** teahouse: vermilion, glowing, chōchin present, on 6 stilts.
- **`MaterializedSite_cliff-proof`** — a **current-size (1×) dormant S** shell: dark `scheme.dormant`, shoji opaque, glow hidden, no chōchin, on 6 stilts.
- Console shows `[D.3] <userid> claimed cliff-proof-2 @ L` and no `apply failed` warnings.

The 2× size difference between the two teahouses is the proof. **Do not self-judge/iterate — STOP and ask the user to look.** (Fallback and release are Lune-covered.)

- [ ] **Step 7: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): wire multi-size claim + scale on two differently-sized pads (sub-project D.3)"
```

---

## Self-Review

**Spec coverage:**
- `SizeClasses` (footprint + proxy scale + `nativeSize`) → Task 1. ✓
- `SiteCoordinator:onJoin` multi-size, size-first, fallback, `scale`/`sizeClass` in Action; dormant native-size scale → Task 2. ✓
- `TreatmentApplier:apply` `ScaleTo` → Task 3. ✓
- `cliff-proof-2` → 2×base (MCP re-verified); `cliff-proof` stays base → Task 4. ✓
- main.server: register large-first, full map to `onJoin`, scale threaded through all four apply sites (startup/join/leave/leave-during-join) → Task 5 Steps 1–3. ✓
- Seed S/M/L + two-pad gate → Task 5 Steps 5–6. ✓
- Proxy → authored swap isolated to `scale` → Task 1 module comment. ✓
- Non-goals (authored prefabs, best-fit, D.4/D.5) → excluded; no task touches them. ✓

**Placeholder scan:** `<USERID>` in Task 5 Step 5 is read via `StudioService:GetUserId()` in the same step (an execution-time value, not an unfilled placeholder). No `TODO`/`TBD`/"add error handling".

**Type consistency:** `Action = {padId, spec, treatment, scale, sizeClass?}` (Task 2) is consumed as `action.scale`/`action.sizeClass` in Task 5 and as the `scale` param of `apply` (Task 3). `SizeClasses.footprintFor`/`.scale`/`.order`/`.nativeSize` (Task 1) are called with matching names in Task 2. `claimVacantFor(owner, footprint)` matches `PadRegistry`'s real signature. The updated D.2 tests pass `OWNED = {M=LOADOUT}` (a map) to the new map-typed `onJoin`, and pads carry real footprints (`HUGE`) so `claimVacantFor` matches — consistent with the removed `footprint = {}`.
