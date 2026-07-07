# Roshambo Site Model + Dynamic Posts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fixed-footprint pads with sites that carry a surveyed max-size (ordinal size-cap matching, biggest-first) and build support posts dynamically to the materialized structure — a stilt where terrain drops below the deck, none where the deck beds into the slope.

**Architecture:** `SizeClasses` gains a size rank + `fitsWithin`. `SiteCoordinator:onJoin` claims the first vacant site whose `maxSize` accommodates the player's largest owned size, biggest-first. `PadOps`/`PadPlanner` gain embed/void classification (post only where terrain is below the datum). `TreatmentApplier:apply` rebuilds structure + dynamic posts together. Proven on 3 real perches.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune harness (`roblox/tests/`), Roblox Studio (MCP for survey-capture + gate), the live `/api/v1` server.

## Global Constraints

- **DI rule:** pure Lune-loadable modules may require each other (`SizeClasses`→`PadRegistry`; `SiteCoordinator`→`VacantState`+`SizeClasses`); the `PadRegistry` instance stays injected; the Studio-only `PadOps`/`TreatmentApplier` require nothing.
- **`--!strict`** header on every Luau module.
- **Lint gate is GREEN — keep it:** changed files pass `stylua --check <file>` and `selene src` stays 0/0. No `selene: allow`; no deprecated `Instance.new(class, parent)`.
- **Studio-only** (`PadOps`, `TreatmentApplier`, `PadSites`, `main.server` wiring) have no Lune tests; correctness is proven by the real-perch visual gate.
- **Site spec shape:** `{ id, mountCF (12-number array, Deck-anchored: pos = deck underside, rot = deck rotation), hand = "right", maxSize ("S"/"M"/"L"), vacantForm = "dormant-structure" }`. (Replaces the D.3 `footprint` field with `maxSize`.)
- **Size ranks:** `SizeClasses.rank = { S = 1, M = 2, L = 3 }`; `fitsWithin(size, maxSize) = rank[size] <= rank[maxSize]`. `order = { "L", "M", "S" }` (largest first); `scale = { S = 1.0, M = 1.5, L = 2.0 }`.
- **Post classification (`MAXPOST = 80`):** for a corner with datum-plane top Y `topY` and ground `groundY` — **build** iff `groundY ~= nil and groundY < topY and (topY - groundY) <= MAXPOST`; else **omit** (embed = ground ≥ datum, or void = nil / deeper than MAXPOST).
- **`PadOps.raycastGround` rays from above the deck** (`mountCF.Y + 250`, down `350`) so it sees terrain above *and* below the datum.
- **Surveyed sites (MCP-verified 2026-07-07, current max):** `T02` max **L**, `T06` max **M**, `T04` max **S**. Register **T02 first**. Deck-anchored mountCFs are captured in Task 5.
- **`Action` gains `footprint`** (the materialized size's footprint) so the Studio applier builds posts without requiring `SizeClasses`. Full `Action = { padId, spec, treatment, scale, sizeClass?, footprint? }`.
- **Stop-and-ask:** the visual gate is ONE attempt, then STOP for the user.

---

### Task 1: `SizeClasses` — size rank + `fitsWithin`

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau`
- Test: `roblox/tests/SizeClasses.spec.luau` (add a `describe` block)

**Interfaces:**
- Produces: `SizeClasses.rank = { S=1, M=2, L=3 }`; `SizeClasses.fitsWithin(size: string, maxSize: string): boolean` (`rank[size] <= rank[maxSize]`).

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/SizeClasses.spec.luau` (before EOF):

```lua
describe("SizeClasses.fitsWithin", function()
    test("rank orders S < M < L", function()
        expect(SizeClasses.rank.S).toBe(1)
        expect(SizeClasses.rank.M).toBe(2)
        expect(SizeClasses.rank.L).toBe(3)
    end)
    test("a size fits a site whose max is that size or larger", function()
        expect(SizeClasses.fitsWithin("S", "L")).toBe(true)
        expect(SizeClasses.fitsWithin("M", "M")).toBe(true)
        expect(SizeClasses.fitsWithin("L", "L")).toBe(true)
    end)
    test("a size does not fit a smaller-max site", function()
        expect(SizeClasses.fitsWithin("L", "M")).toBe(false)
        expect(SizeClasses.fitsWithin("M", "S")).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `SizeClasses.fitsWithin` / `SizeClasses.rank` nil.

- [ ] **Step 3: Add rank + fitsWithin**

In `roblox/src/shared/SizeClasses.luau`, after the `scale` line (line 15), add:

```lua
SizeClasses.rank = { S = 1, M = 2, L = 3 } :: { [string]: number }

function SizeClasses.fitsWithin(size: string, maxSize: string): boolean
    return SizeClasses.rank[size] <= SizeClasses.rank[maxSize]
end
```

- [ ] **Step 4: Run to verify pass + lint**

Run: `cd roblox && lune run tests/run && stylua --check src/shared/SizeClasses.luau tests/SizeClasses.spec.luau && selene src`
Expected: all green; no diffs; 0/0.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): SizeClasses rank + fitsWithin (sub-project D.4)"
```

---

### Task 2: `PadPlanner` embed/void classification + `PadOps` high-origin ray

**Files:**
- Modify: `roblox/src/shared/PadPlanner.luau`
- Test: `roblox/tests/PadPlanner.spec.luau` (add 2 tests)
- Modify: `roblox/src/server/PadOps.luau` (raycast origin) — Studio-only, no test

**Interfaces:**
- Produces: `PadPlanner.planSupport(footprint, mountCF, groundAt)` now **omits** a corner when its ground is `nil`, at/above the datum (embed), or deeper than `MAXPOST = 80` below it; builds a post only for below-datum ground within reach. `PadOps.raycastGround` returns terrain Y (above or below datum) from a high origin.

- [ ] **Step 1: Write the failing tests**

Append to `roblox/tests/PadPlanner.spec.luau` (before EOF):

```lua
test("embed: ground at/above the datum omits the post (deck beds into the slope)", function()
    -- datum plane y = 20; ground at +25 everywhere (above the deck) -> all 6 omitted
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return 25
    end)
    expect(#s.posts).toBe(0)
    expect(#s.omitted).toBe(6)
end)

test("too-deep: ground more than MAXPOST(80) below the datum omits the post (void)", function()
    -- datum y = 20; ground at -70 -> depth 90 > 80 -> omit
    local s = PadPlanner.planSupport(FP, IDENT, function()
        return -70
    end)
    expect(#s.posts).toBe(0)
    expect(#s.omitted).toBe(6)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — current `planSupport` builds a post for any non-nil ground, so both new tests get 6 posts, not 0.

- [ ] **Step 3: Add the classification to `PadPlanner`**

In `roblox/src/shared/PadPlanner.luau`, add a `MAXPOST` constant beside the existing `PH`/`EMBED` (near the top, after the `local EMBED = 1.0` line):

```lua
local MAXPOST = 80 -- max stilt length; deeper ground reads as void (over-gorge)
```

Then change the classification branch inside the `for _, p in layout do` loop. Replace:

```lua
        local groundY = groundAt(top[1], top[3])
        if groundY == nil then
            table.insert(omitted, p[1] :: string)
        else
```

with:

```lua
        local groundY = groundAt(top[1], top[3])
        -- build a post only where terrain sits BELOW the datum within reach (normal);
        -- omit corners embedded in the slope (ground >= datum) or over a void (nil / deeper than MAXPOST).
        if groundY == nil or groundY >= top[2] or (top[2] - groundY) > MAXPOST then
            table.insert(omitted, p[1] :: string)
        else
```

(The `else` block — `foot`/`posts` insertion — is unchanged.)

- [ ] **Step 4: Change `PadOps.raycastGround` to a high origin**

In `roblox/src/server/PadOps.luau`, replace the `raycastGround` body's `hit` line:

```lua
            local hit =
                workspace:Raycast(Vector3.new(x, mountCF.Position.Y + 4, z), Vector3.new(0, -600, 0), rp)
```

with (ray from well above the deck, so terrain above the datum is seen too):

```lua
            local hit = workspace:Raycast(
                Vector3.new(x, mountCF.Position.Y + 250, z),
                Vector3.new(0, -350, 0),
                rp
            )
```

- [ ] **Step 5: Run tests + lint**

Run: `cd roblox && lune run tests/run && stylua --check src/shared/PadPlanner.luau tests/PadPlanner.spec.luau src/server/PadOps.luau && selene src`
Expected: all green (the 4 existing PadPlanner tests still pass — flat/sloped ground is below the datum, over-void nil still omits); no diffs; 0/0.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/PadPlanner.luau roblox/tests/PadPlanner.spec.luau roblox/src/server/PadOps.luau
git commit -m "feat(roblox): dynamic posts — embed/void classification + high-origin ray (sub-project D.4)"
```

---

### Task 3: `SiteCoordinator` size-cap matching (biggest-first) + `Action.footprint`

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau` (full rewrite below)
- Modify: `roblox/tests/SiteCoordinator.spec.luau` (full rewrite below)

**Interfaces:**
- Consumes: `SizeClasses.rank`/`fitsWithin`/`order`/`scale`/`footprintFor` (Task 1 + existing); injected `PadRegistry` (`:register`/`:get`/`:claim`/`:release`).
- Produces: `onJoin(playerId, ownedTeahouses)` claims the first vacant site (registration order) whose `spec.maxSize` accommodates the player's largest owned size (biggest-first); `Action = { padId, spec, treatment, scale, sizeClass?, footprint? }`; `vacantActions`/`onLeave` carry the site's `maxSize` scale + footprint.

- [ ] **Step 1: Rewrite the spec**

Replace `roblox/tests/SiteCoordinator.spec.luau` entirely with:

```lua
--!strict
local harness = require("./harness")
local SiteCoordinator = require("../src/shared/SiteCoordinator")
local PadRegistry = require("../src/shared/PadRegistry")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function spec(id: string, maxSize: string?)
    return {
        id = id,
        mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        maxSize = maxSize or "L",
        vacantForm = "dormant-structure",
    }
end
local LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }
local OWNED = { M = LOADOUT }

local function coord(specs: { any })
    local c = SiteCoordinator.new(PadRegistry.new())
    for _, s in specs do
        c:registerPad(s.id, s)
    end
    return c
end

describe("SiteCoordinator.onJoin", function()
    test("an owner claims the first fitting site, lit, with size fields", function()
        local c = coord({ spec("p1"), spec("p2") })
        local a = c:onJoin("player1", OWNED)
        expect(a ~= nil).toBe(true)
        expect((a :: any).padId).toBe("p1")
        expect((a :: any).treatment.lit).toBe(true)
        expect((a :: any).treatment.loadout).toBe(LOADOUT)
        expect((a :: any).sizeClass).toBe("M")
        expect((a :: any).scale).toBe(1.5)
        expect((a :: any).footprint.maxX).toBeCloseTo(SizeClasses.footprintFor("M").maxX)
    end)

    test("a wanderer (nil map) claims nothing", function()
        local c = coord({ spec("p1") })
        expect(c:onJoin("player1", nil)).toBe(nil)
        expect((c:onJoin("player2", OWNED) :: any).padId).toBe("p1")
    end)

    test("nil when every site is occupied", function()
        local c = coord({ spec("p1") })
        c:onJoin("player1", OWNED)
        expect(c:onJoin("player2", OWNED)).toBe(nil)
    end)

    test("two owners take two distinct sites; a third gets nil", function()
        local c = coord({ spec("p1"), spec("p2") })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
        expect(c:onJoin("cc", OWNED)).toBe(nil)
    end)

    test("duplicate onJoin by the same player claims nothing and consumes no site", function()
        local c = coord({ spec("p1"), spec("p2") })
        expect((c:onJoin("a", OWNED) :: any).padId).toBe("p1")
        expect(c:onJoin("a", OWNED)).toBe(nil)
        expect((c:onJoin("b", OWNED) :: any).padId).toBe("p2")
    end)

    test("biggest-first: owning S,M,L claims the L site at L", function()
        local c = coord({ spec("L1", "L"), spec("M1", "M"), spec("S1", "S") })
        local a = c:onJoin("p", { S = LOADOUT, M = LOADOUT, L = LOADOUT })
        expect((a :: any).padId).toBe("L1")
        expect((a :: any).sizeClass).toBe("L")
        expect((a :: any).scale).toBe(2.0)
    end)

    test("size-cap fallback: only-L owner + only an M-max site => nil; L,M owner => M on it", function()
        local c1 = coord({ spec("m", "M") })
        expect(c1:onJoin("p", { L = LOADOUT })).toBe(nil)

        local c2 = coord({ spec("m", "M") })
        local a = c2:onJoin("p", { L = LOADOUT, M = LOADOUT })
        expect((a :: any).padId).toBe("m")
        expect((a :: any).sizeClass).toBe("M")
    end)
end)

describe("SiteCoordinator.onLeave", function()
    test("a holder releases dormant at the site's max size and frees it", function()
        local c = coord({ spec("L1", "L") })
        c:onJoin("player1", { L = LOADOUT })
        local a = c:onLeave("player1")
        expect((a :: any).treatment.lit).toBe(false)
        expect((a :: any).treatment.loadout.colorScheme).toBe("scheme.dormant")
        expect((a :: any).scale).toBe(2.0)
        expect((c:onJoin("player2", { L = LOADOUT }) :: any).padId).toBe("L1")
    end)

    test("a non-holder leaving is a no-op", function()
        local c = coord({ spec("p1") })
        expect(c:onLeave("ghost")).toBe(nil)
    end)
end)

describe("SiteCoordinator.vacantActions", function()
    test("one dormant action per site at the site's max-size scale", function()
        local c = coord({ spec("L1", "L"), spec("S1", "S") })
        local acts = c:vacantActions()
        expect(#acts).toBe(2)
        expect(acts[1].scale).toBe(2.0)
        expect(acts[2].scale).toBe(1.0)
        expect(acts[1].treatment.lit).toBe(false)
    end)

    test("skips occupied sites", function()
        local c = coord({ spec("p1"), spec("p2") })
        c:onJoin("player1", OWNED)
        local acts = c:vacantActions()
        expect(#acts).toBe(1)
        expect(acts[1].padId).toBe("p2")
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — current `onJoin` uses `claimVacantFor(footprint)` and sites here have `maxSize` (no `footprint`); size fields / footprint assertions fail.

- [ ] **Step 3: Rewrite the module**

Replace `roblox/src/shared/SiteCoordinator.luau` entirely with:

```lua
--!strict
-- Per-server orchestration brain for sub-project D materialization. Turns player
-- join/leave + startup into Actions by composing an injected PadRegistry (claim/
-- release) with VacantState (treatment) and SizeClasses (size-cap fit). Pure
-- (Lune-tested): no Roblox datatypes. A site carries a `maxSize`; onJoin claims the
-- first vacant site whose maxSize accommodates the player's largest owned size,
-- biggest-first. The Studio-side TreatmentApplier executes the Actions (scale + posts).
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
    footprint: SizeClasses.Footprint?,
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

-- A vacant site renders its dormant shell at the site's own max size.
local function dormantOf(spec: any): (number, SizeClasses.Footprint?)
    local maxSize = spec and spec.maxSize
    if maxSize == nil then
        return 1, nil
    end
    return SizeClasses.scale[maxSize], SizeClasses.footprintFor(maxSize)
end

function SiteCoordinator:vacantActions(): { Action }
    local out: { Action } = {}
    for _, id in self._padIds do
        local rec = self._registry:get(id)
        if rec and rec.occupant == nil then
            local scale, footprint = dormantOf(rec.spec)
            table.insert(out, {
                padId = id,
                spec = rec.spec,
                treatment = VacantState.resolve(nil, nil, rec.spec.vacantForm),
                scale = scale,
                footprint = footprint,
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
    for _, size in SizeClasses.order do -- L, M, S (biggest first)
        local loadout = ownedTeahouses[size]
        if loadout ~= nil then
            for _, id in self._padIds do -- registration order (first-fit)
                local rec = self._registry:get(id)
                if rec and rec.occupant == nil and SizeClasses.fitsWithin(size, rec.spec.maxSize) then
                    self._registry:claim(id, playerId)
                    self._held[playerId] = id
                    return {
                        padId = id,
                        spec = rec.spec,
                        treatment = VacantState.resolve(playerId, loadout, rec.spec.vacantForm),
                        scale = SizeClasses.scale[size],
                        sizeClass = size,
                        footprint = SizeClasses.footprintFor(size),
                    }
                end
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
    local scale, footprint = dormantOf(spec)
    return {
        padId = padId,
        spec = spec,
        treatment = VacantState.resolve(nil, nil, spec and spec.vacantForm),
        scale = scale,
        footprint = footprint,
    }
end

return SiteCoordinator
```

- [ ] **Step 4: Run tests + lint**

Run: `cd roblox && lune run tests/run && stylua --check src/shared/SiteCoordinator.luau tests/SiteCoordinator.spec.luau && selene src`
Expected: all green; no diffs; 0/0.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/SiteCoordinator.luau roblox/tests/SiteCoordinator.spec.luau
git commit -m "feat(roblox): SiteCoordinator size-cap biggest-first + Action.footprint (sub-project D.4)"
```

---

### Task 4: `TreatmentApplier` — merge support into `apply` + dynamic posts

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau`

**Interfaces:**
- Consumes: `Action.footprint` (Task 3), `PadBuilder.build`, `PadOps.new`, `StructureBuilder.build`, `StructureCatalog`, `StructureOps`.
- Produces: `:apply(padId, spec, treatment, scale, footprint)` — rebuilds the site's structure AND its posts (dynamic, from `footprint`) transactionally. `buildSupport` is removed.

No Lune test (Studio-only). Verified by the Task 6 gate.

- [ ] **Step 1: Remove `buildSupport`**

In `roblox/src/server/TreatmentApplier.luau`, delete the entire `buildSupport` method (lines 42–46):

```lua
function TreatmentApplier:buildSupport(spec: any)
    local folder = self:_folder(spec.id)
    local mountCF = CFrame.new(table.unpack(spec.mountCF))
    self._padBuilder.build(spec, self._padOpsNew(mountCF, folder))
end
```

- [ ] **Step 2: Rewrite `apply` to take `footprint` and build posts dynamically**

Replace the whole `apply` method (currently starting `function TreatmentApplier:apply(padId: string, spec: any, treatment: any, scale: number?)`) with:

```lua
function TreatmentApplier:apply(padId: string, spec: any, treatment: any, scale: number?, footprint: any?)
    local folder = self:_folder(padId)
    if treatment.kind ~= "structure" then
        local existing = folder:FindFirstChild("Structure")
        if existing then
            existing:Destroy()
        end
        return -- garden treatment: applier deferred to a later increment
    end
    local mount = { cframe = spec.mountCF, hand = spec.hand, footprint = footprint }
    local ok, result = pcall(function()
        return self._structureBuilder.build(treatment.loadout, mount, self._catalog, self._structureOps)
    end)
    if not ok then
        warn(`[D.4] apply failed for {padId}: {result}`)
        return -- keep whatever was there (F4: no crash, no orphan swap)
    end
    local model = result :: Model
    model.Name = "Structure"
    if scale ~= nil and scale ~= 1 then
        model:ScaleTo(scale)
    end
    if not treatment.lit then
        shutter(model)
    end
    -- transactional swap: drop the old structure + old posts, build the new posts to
    -- the materialized footprint (dynamic: a stilt only where terrain is below the deck),
    -- then parent the new structure.
    local existing = folder:FindFirstChild("Structure")
    if existing then
        existing:Destroy()
    end
    for _, c in folder:GetChildren() do
        if c.Name == "PadPost" then
            c:Destroy()
        end
    end
    if footprint ~= nil then
        local mountCF = CFrame.new(table.unpack(spec.mountCF))
        self._padBuilder.build(
            { mountCF = spec.mountCF, hand = spec.hand, footprint = footprint },
            self._padOpsNew(mountCF, folder)
        )
    end
    model.Parent = folder
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
end
```

- [ ] **Step 3: Lint**

Run: `cd roblox && stylua --check src/server/TreatmentApplier.luau && selene src`
Expected: no diffs (auto-format with `stylua src/server/TreatmentApplier.luau` if needed); 0/0, no `selene: allow`.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): TreatmentApplier builds dynamic posts + structure together (sub-project D.4)"
```

---

### Task 5: `PadSites` — 3 real Deck-anchored perch sites *(interactive, Studio MCP)*

**Files:**
- Modify: `roblox/src/server/PadSites.luau` (replace the two cliff-proof entries)

**Interfaces:**
- Produces: `PadSites["T02"|"T06"|"T04"]` = `{ id, mountCF (12-num, Deck-anchored), hand = "right", maxSize, vacantForm = "dormant-structure" }`.

- [ ] **Step 1: Capture the 3 Deck-anchored mountCFs (Studio, Edit)**

Run via MCP `execute_luau` and record the printed 12-number `mountCF` per site:

```lua
local out = {}
for _, name in { "Teahouse_02", "Teahouse_06", "Teahouse_04" } do
    local th = workspace.CanyonTeahouses[name]
    local best, ba
    for _, p in th:GetDescendants() do
        if p:IsA("BasePart") and (p.Name == "Deck" or p.Name:match("^Engawa")) then
            local a = p.Size.X * p.Size.Z
            if not ba or a > ba then best, ba = p, a end
        end
    end
    local underside = best.Position.Y - best.Size.Y / 2
    local cf = CFrame.new(best.Position.X, underside, best.Position.Z) * best.CFrame.Rotation
    out[#out + 1] = name .. " = { " .. table.concat({ cf:GetComponents() }, ", ") .. " }"
end
return table.concat(out, "\n")
```

- [ ] **Step 2: Bake `PadSites.luau`**

Replace the two existing entries in `roblox/src/server/PadSites.luau`'s returned table with the three real sites (using the Step 1 output for each `mountCF`; `maxSize` per the survey: T02=L, T06=M, T04=S), and rewrite the header comment. Template:

```lua
return {
    ["T02"] = {
        id = "T02",
        mountCF = { --[[ Step 1 output for Teahouse_02 ]] },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T06"] = {
        id = "T06",
        mountCF = { --[[ Step 1 output for Teahouse_06 ]] },
        hand = "right",
        maxSize = "M",
        vacantForm = "dormant-structure",
    },
    ["T04"] = {
        id = "T04",
        mountCF = { --[[ Step 1 output for Teahouse_04 ]] },
        hand = "right",
        maxSize = "S",
        vacantForm = "dormant-structure",
    },
}
```

Header comment: Deck-anchored sites (pos = deck underside datum, rot = deck rotation) with survey-derived `maxSize`; captured 2026-07-07. Superseded the D.1–D.3 `cliff-proof` synthetic pads.

- [ ] **Step 3: Lint**

Run: `cd roblox && stylua --check src/server/PadSites.luau && selene src`
Expected: no diffs; 0/0.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/PadSites.luau
git commit -m "feat(roblox): PadSites — 3 real Deck-anchored perch sites with surveyed maxSize (sub-project D.4)"
```

---

### Task 6: Wire `main.server.luau` + archive + seed + real-perch gate *(interactive, Studio MCP)*

**Files:**
- Modify: `roblox/src/server/main.server.luau` (the D.3 block)

**Interfaces:**
- Consumes: `SiteCoordinator` size-cap `onJoin` (Task 3), `TreatmentApplier:apply(...,footprint)` (Task 4), `PadSites` T02/T06/T04 (Task 5).

Setup (archive + seed) is folded in because the gate needs it.

- [ ] **Step 1: Update the registration + startup loop**

In `roblox/src/server/main.server.luau`, replace the registration + startup block:

```lua
-- cliff-proof-2 (large) registered first: the sole local joiner claims it with L; cliff-proof (small) stays dormant at S
for _, id in { "cliff-proof-2", "cliff-proof" } do
    siteCoordinator:registerPad(id, PadSites[id])
end
for _, action in siteCoordinator:vacantActions() do
    applier:buildSupport(action.spec)
    applier:apply(action.padId, action.spec, action.treatment, action.scale)
end
```

with (T02 first; no more `buildSupport` — `apply` builds posts now; thread `footprint`):

```lua
-- real perches, T02 (max L) registered first so the sole local joiner claims it with L
for _, id in { "T02", "T06", "T04" } do
    siteCoordinator:registerPad(id, PadSites[id])
end
for _, action in siteCoordinator:vacantActions() do
    applier:apply(action.padId, action.spec, action.treatment, action.scale, action.footprint)
end
```

- [ ] **Step 2: Thread `footprint` through the join + leave apply sites**

In the `PlayerAdded` handler, change the release-path apply and the claim apply:

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

to:

```lua
                local rel = siteCoordinator:onLeave(tostring(player.UserId))
                if rel then
                    applier:apply(rel.padId, rel.spec, rel.treatment, rel.scale, rel.footprint)
                end
                return
            end
            applier:apply(action.padId, action.spec, action.treatment, action.scale, action.footprint)
            print(`[D.4] {player.UserId} claimed {action.padId} @ {tostring(action.sizeClass)}`)
```

And in `PlayerRemoving`, change `applier:apply(action.padId, action.spec, action.treatment, action.scale)` to `applier:apply(action.padId, action.spec, action.treatment, action.scale, action.footprint)` (and its `[D.3]` print to `[D.4]`).

- [ ] **Step 3: Lint**

Run: `cd roblox && stylua src/server/main.server.luau && stylua --check src/server/main.server.luau && selene src`
Expected: clean; 0/0.

- [ ] **Step 4: Archive the 3 legacy perches (Studio, Edit — reversible)**

Run via MCP `execute_luau` so the materialized ones stand in their place (do NOT save the place; restore by moving them back afterward):

```lua
local moved = {}
for _, name in { "Teahouse_02", "Teahouse_06", "Teahouse_04" } do
    local th = workspace.CanyonTeahouses:FindFirstChild(name)
    if th then
        th.Parent = game:GetService("ServerStorage")
        moved[#moved + 1] = name
    end
end
return "archived: " .. table.concat(moved, ", ")
```

- [ ] **Step 5: Seed the local player S/M/L**

Read the UserId (Edit): `return game:GetService("StudioService"):GetUserId()`. Then seed all three sizes (vermilion) against `http://localhost:3001` (key `roshambo_local_dev_api_key`):

```bash
for SZ in S M L; do
  curl -sS -X PUT "http://localhost:3001/api/v1/players/<USERID>/teahouses/$SZ" \
    -H "X-API-Key: roshambo_local_dev_api_key" -H "Content-Type: application/json" \
    -d '{"loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}' >/dev/null
done
curl -sS "http://localhost:3001/api/v1/players/<USERID>/teahouses" -H "X-API-Key: roshambo_local_dev_api_key"
```

Expected: the GET returns `{"teahouses":{"S":…,"M":…,"L":…}}`.

- [ ] **Step 6: Run the real-perch gate (ONE attempt, then STOP)**

With Rojo synced, Play, and confirm under `workspace.TeahouseSites`:
- **`MaterializedSite_T02`** — a **lit L** teahouse standing flush on the real cliff perch, **posts only at normal corners** (corners that bed into the slope have no post), no float/overhang.
- **`MaterializedSite_T06` / `_T04`** — dormant **M / S** shells, posts likewise only at normal corners.
- Console shows `[D.4] <userid> claimed T02 @ L` and no `apply failed` warnings.

Server-side check (`execute_luau`, Server datamodel): for each site, `Structure:GetScale()` (T02≈2.0, T06≈1.5, T04≈1.0) and the `PadPost` count equals the number of normal (below-datum) corners. **Do not self-judge/iterate — STOP and ask the user to look.** (Fallback/release are Lune-covered.)

- [ ] **Step 7: Restore the archived perches + commit**

Move the 3 legacy teahouses back from `ServerStorage` to `workspace.CanyonTeahouses` (MCP, Edit) so the place is unchanged. Then:

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): site model + dynamic posts on real perches (sub-project D.4)"
```

---

## Self-Review

**Spec coverage:**
- Size rank + `fitsWithin` → Task 1. ✓
- Dynamic posts: embed/void classification (`PadPlanner`) + high-origin ray (`PadOps`) → Task 2. ✓
- Site-cap biggest-first `onJoin` + `Action.footprint` + dormant=maxSize → Task 3. ✓
- Applier rebuilds structure + dynamic posts together; `buildSupport` removed → Task 4. ✓
- 3 real Deck-anchored sites with surveyed maxSize → Task 5. ✓
- Wiring (T02 first, thread footprint, no buildSupport), archive, seed, real-perch gate → Task 6. ✓
- Non-goals (preference D.5, full migration D.6, clearing, per-site handedness, best-fit) → excluded. ✓

**Placeholder scan:** the `--[[ Step 1 output ... ]]` markers in Task 5 and `<USERID>` in Task 6 are execution-time values captured by the immediately-preceding step (MCP capture / `GetUserId`), not unfilled placeholders. No `TODO`/`TBD`/"add error handling".

**Type consistency:** `Action = {padId, spec, treatment, scale, sizeClass?, footprint?}` (Task 3) is consumed as `action.footprint`/`action.scale` in Tasks 4 (`apply(...,scale,footprint)`) and 6. Site spec `maxSize` (Task 5) is read by `SiteCoordinator` `fitsWithin(size, rec.spec.maxSize)` / `dormantOf` (Task 3). `PadPlanner.planSupport`'s `MAXPOST=80` and the embed rule match `PadOps`'s high-origin ray depth (`+250` down `350` reaches `-100`, past `MAXPOST`). `PadBuilder.build({mountCF, hand, footprint}, ops)` (Task 4) matches `PadBuilder`'s existing `{mountCF, hand, footprint}` shape. `dormantOf`/`vacantActions`/`onLeave` all carry the site's `maxSize` scale + footprint consistently.
