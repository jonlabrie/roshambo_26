# Structure Builder (Sub-Project A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a portable, loadout-driven structure builder — `build(loadout, mount) → Model` — that clones a per-tier base prefab, mirrors it for the pad's handedness, fills its slots from a curated catalog, and snaps it to a pad datum, with the hard logic pure and Lune-tested.

**Architecture:** A pure `StructurePlanner` (`loadout + mount + manifest + catalog → plan`) computes what to do; a thin `StructureBuilder` drives injectable `ops` to do it against real Instances. Component customization resolves through three mechanisms only — recolor, texture swap, attachment prefab. The first base prefab is captured from the teahouse we perfected in the 2026-07-05 art pass; handedness is a data tag (`MirrorX`), not code. See spec: `docs/superpowers/specs/2026-07-05-roshambo-structure-builder-design.md`.

**Tech Stack:** Luau; Lune headless test harness (`roblox/tests/harness.luau`, `roblox/tests/run.luau`); Rojo (`src/shared → ReplicatedStorage.RoshamboShared`); Roblox Studio via MCP `execute_luau` for the prefab capture + visual demo.

## Global Constraints

- **Three component mechanisms only** — `recolor` (palette on role-tagged parts), `texture` (decal/SurfaceAppearance swap on a tagged surface), `attachment` (clone a prefab onto a named Attachment). No fourth mechanism.
- **Datum rule: nothing below Y0.** Y0 = the EngawaSupport **frame underside**. The structure keeps its joist frame (it carries the cantilevered engawa); the 6 terrain-raycasting `EngawaPost` parts are the pad's job and are stripped from the prefab.
- **Handedness is a pad input, not a loadout field.** `mount.hand ∈ {"left","right"}`. Left-hand = negate-X of every part tagged `MirrorX`; symmetric parts (roof, gables, shell front, back wall) stay untagged.
- **Purity:** `StructurePlanner` and `StructureCatalog` must run under Lune — plain tables/numbers only, **no Roblox datatypes, no `math.random`**. CFrames are 12-number arrays (matching `Spec.cframe`).
- **Module paths:** new pure modules live in `roblox/src/shared/`; specs in `roblox/tests/*.spec.luau` require them as `../src/shared/<Name>`. Run all tests with `lune run tests/run` from `roblox/`.
- **Prefab home:** `ServerStorage.StructurePrefabs.<baseStyle>`; component prefabs in `ServerStorage.StructureComponents.<prefabId>`. For v1 these are place-only (saved in the place), consistent with all canyon geometry; committing as `.rbxmx` via a Rojo mount is a documented non-blocking follow-up (see Notes).
- **Visual gates stop for the user.** Capture (Task 7) and demo (Task 8) end by screenshotting and stopping for the user to look — never self-judge and iterate (standing rule).

---

### Task 1: StructureCatalog — component defs + resolver

**Files:**
- Create: `roblox/src/shared/StructureCatalog.luau`
- Test: `roblox/tests/StructureCatalog.spec.luau`

**Interfaces:**
- Produces: `StructureCatalog.get(id: string) -> Entry?` where `Entry = { id: string, type: "recolor"|"texture"|"attachment", slot: string, payload: any }`. Recolor payload = `{ [role]: {r,g,b} }`; texture payload = `{ assetId: string }`; attachment payload = `{ prefabId: string }`.

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/StructureCatalog.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local Catalog = require("../src/shared/StructureCatalog")

test("get returns a recolor entry with per-role palette", function()
    local e = Catalog.get("scheme.ink")
    expect(e).toBeTruthy()
    expect((e :: any).type).toBe("recolor")
    expect((e :: any).slot).toBe("colorScheme")
    expect((e :: any).payload.cap).toEqual({ 45, 48, 56 })
end)

test("get returns texture and attachment entries", function()
    expect((Catalog.get("shoji.crane") :: any).type).toBe("texture")
    expect((Catalog.get("tatami.gold") :: any).type).toBe("texture")
    local flag = Catalog.get("flag.clan") :: any
    expect(flag.type).toBe("attachment")
    expect(flag.payload.prefabId).toBe("flag_clan")
end)

test("get returns nil for an unknown id", function()
    expect(Catalog.get("nope.nope")).toBeNil()
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `StructureCatalog` module not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/StructureCatalog.luau
--!strict
-- Curated component catalog for player structures. Pure data + an id resolver;
-- StructurePlanner reads this to turn loadout ids into concrete recolor/texture/
-- attachment operations. v1 carries one of each mechanism to prove the pipeline;
-- the real economy catalog (sub-project E) supersedes this. No Roblox datatypes.
local StructureCatalog = {}

export type Entry = {
    id: string,
    type: "recolor" | "texture" | "attachment",
    slot: string,
    payload: any,
}

local ENTRIES: { [string]: Entry } = {
    ["scheme.ink"] = {
        id = "scheme.ink", type = "recolor", slot = "colorScheme",
        payload = { timber = { 74, 55, 38 }, wall = { 120, 100, 74 }, roof = { 45, 48, 56 }, cap = { 45, 48, 56 } },
    },
    ["scheme.vermilion"] = {
        id = "scheme.vermilion", type = "recolor", slot = "colorScheme",
        payload = { timber = { 120, 45, 35 }, wall = { 232, 216, 190 }, roof = { 40, 42, 48 }, cap = { 40, 42, 48 } },
    },
    ["shoji.plain"] = { id = "shoji.plain", type = "texture", slot = "shoji", payload = { assetId = "rbxassetid://0" } },
    ["shoji.crane"] = { id = "shoji.crane", type = "texture", slot = "shoji", payload = { assetId = "rbxassetid://102000000001" } },
    ["tatami.green"] = { id = "tatami.green", type = "texture", slot = "tatami", payload = { assetId = "rbxassetid://102000000010" } },
    ["tatami.gold"] = { id = "tatami.gold", type = "texture", slot = "tatami", payload = { assetId = "rbxassetid://102000000011" } },
    ["flag.clan"] = { id = "flag.clan", type = "attachment", slot = "flags", payload = { prefabId = "flag_clan" } },
    ["flag.noren"] = { id = "flag.noren", type = "attachment", slot = "flags", payload = { prefabId = "flag_noren" } },
}

function StructureCatalog.get(id: string): Entry?
    return ENTRIES[id]
end

return StructureCatalog
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (3 new tests green; existing suite still green).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructureCatalog.luau roblox/tests/StructureCatalog.spec.luau
git commit -m "feat(roblox): StructureCatalog — v1 component defs (recolor/texture/attachment)"
```

---

### Task 2: StructurePlanner — colorScheme recolors

**Files:**
- Create: `roblox/src/shared/StructurePlanner.luau`
- Test: `roblox/tests/StructurePlanner.spec.luau`

**Interfaces:**
- Consumes: `StructureCatalog.get` (Task 1).
- Produces: types `Loadout`, `Mount`, `Manifest`, `Plan` (below) and `StructurePlanner.plan(loadout: Loadout, mount: Mount, manifest: Manifest, catalog) -> Plan`. This task returns a `Plan` with only `recolors` populated; later tasks add `textures`, `attachments`, `mirror`, `pivotCF`.

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/StructurePlanner.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local Catalog = require("../src/shared/StructureCatalog")
local Planner = require("../src/shared/StructurePlanner")

local function baseMount(): any
    return { cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "right", footprint = { x = 26, z = 20 } }
end

test("recolors: emits one entry per manifest role present in the palette", function()
    local manifest = { roles = { "timber", "roof", "cap" }, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local plan = Planner.plan({ baseStyle = "teahouse-1story", colorScheme = "scheme.ink" }, baseMount(), manifest, Catalog)
    expect(plan.recolors).toEqual({
        { role = "timber", color = { 74, 55, 38 } },
        { role = "roof", color = { 45, 48, 56 } },
        { role = "cap", color = { 45, 48, 56 } },
    })
end)

test("recolors: empty when no colorScheme in loadout", function()
    local manifest = { roles = { "timber" }, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local plan = Planner.plan({ baseStyle = "teahouse-1story" }, baseMount(), manifest, Catalog)
    expect(plan.recolors).toEqual({})
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `StructurePlanner` not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/StructurePlanner.luau
--!strict
-- Pure planner for the structure builder. Turns a player loadout + a pad mount +
-- the base prefab's slot manifest into a concrete Plan of Instance operations.
-- No Roblox datatypes (Lune-tested); CFrames are 12-number arrays like Spec.cframe.
local StructurePlanner = {}

export type Color = { number }
export type Loadout = {
    baseStyle: string,
    colorScheme: string?,
    shoji: { [number]: string }?,
    tatami: string?,
    flags: { { mount: string, item: string } }?,
}
export type Mount = { cframe: { number }, hand: string, footprint: { x: number, z: number } }
export type Manifest = { roles: { string }, shojiBays: { number }, hasTatami: boolean, flagMounts: { string } }
export type Recolor = { role: string, color: Color }
export type Texture = { target: string, assetId: string }
export type Attachment = { mount: string, prefabId: string }
export type Plan = {
    recolors: { Recolor },
    textures: { Texture },
    attachments: { Attachment },
    mirror: boolean,
    pivotCF: { number },
}

type Catalog = { get: (string) -> any }

local function resolveRecolors(loadout: Loadout, manifest: Manifest, catalog: Catalog): { Recolor }
    local out: { Recolor } = {}
    if not loadout.colorScheme then
        return out
    end
    local entry = catalog.get(loadout.colorScheme)
    if not entry or entry.type ~= "recolor" then
        return out
    end
    for _, role in manifest.roles do
        local color = entry.payload[role]
        if color then
            table.insert(out, { role = role, color = color })
        end
    end
    return out
end

function StructurePlanner.plan(loadout: Loadout, mount: Mount, manifest: Manifest, catalog: Catalog): Plan
    return {
        recolors = resolveRecolors(loadout, manifest, catalog),
        textures = {},
        attachments = {},
        mirror = false,
        pivotCF = mount.cframe,
    }
end

return StructurePlanner
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructurePlanner.luau roblox/tests/StructurePlanner.spec.luau
git commit -m "feat(roblox): StructurePlanner — colorScheme recolor resolution"
```

---

### Task 3: StructurePlanner — shoji + tatami textures

**Files:**
- Modify: `roblox/src/shared/StructurePlanner.luau`
- Modify: `roblox/tests/StructurePlanner.spec.luau`

**Interfaces:**
- Produces: `plan().textures` populated — `{ target: string, assetId: string }` where `target` is `"ShojiBay:<index>"` or `"Tatami"`.

- [ ] **Step 1: Write the failing test** (append to the spec)

```lua
test("textures: per-bay shoji prints + tatami, only for bays the manifest exposes", function()
    local manifest = { roles = {}, shojiBays = { 1, 2, 3 }, hasTatami = true, flagMounts = {} }
    local loadout = { baseStyle = "teahouse-1story", shoji = { [1] = "shoji.crane", [3] = "shoji.plain" }, tatami = "tatami.gold" }
    local plan = Planner.plan(loadout, baseMount(), manifest, Catalog)
    expect(plan.textures).toEqual({
        { target = "ShojiBay:1", assetId = "rbxassetid://102000000001" },
        { target = "ShojiBay:3", assetId = "rbxassetid://0" },
        { target = "Tatami", assetId = "rbxassetid://102000000011" },
    })
end)

test("textures: tatami skipped when the base has no tatami surface", function()
    local manifest = { roles = {}, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local plan = Planner.plan({ baseStyle = "teahouse-1story", tatami = "tatami.gold" }, baseMount(), manifest, Catalog)
    expect(plan.textures).toEqual({})
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `textures` is `{}`, expected populated list.

- [ ] **Step 3: Write minimal implementation** (add resolver, wire into `plan`)

Add above `StructurePlanner.plan`:

```lua
local function resolveTextures(loadout: Loadout, manifest: Manifest, catalog: Catalog): { Texture }
    local out: { Texture } = {}
    if loadout.shoji then
        for _, bay in manifest.shojiBays do
            local id = loadout.shoji[bay]
            if id then
                local e = catalog.get(id)
                if e and e.type == "texture" then
                    table.insert(out, { target = "ShojiBay:" .. bay, assetId = e.payload.assetId })
                end
            end
        end
    end
    if manifest.hasTatami and loadout.tatami then
        local e = catalog.get(loadout.tatami)
        if e and e.type == "texture" then
            table.insert(out, { target = "Tatami", assetId = e.payload.assetId })
        end
    end
    return out
end
```

Change `textures = {},` in `plan` to `textures = resolveTextures(loadout, manifest, catalog),`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructurePlanner.luau roblox/tests/StructurePlanner.spec.luau
git commit -m "feat(roblox): StructurePlanner — shoji + tatami texture resolution"
```

---

### Task 4: StructurePlanner — flag attachments (+ skip missing mounts)

**Files:**
- Modify: `roblox/src/shared/StructurePlanner.luau`
- Modify: `roblox/tests/StructurePlanner.spec.luau`

**Interfaces:**
- Produces: `plan().attachments` populated — `{ mount: string, prefabId: string }`, one per loadout flag whose `mount` exists in `manifest.flagMounts`.

- [ ] **Step 1: Write the failing test** (append)

```lua
test("attachments: flags map to their mount; unknown mounts are skipped", function()
    local manifest = { roles = {}, shojiBays = {}, hasTatami = false, flagMounts = { "FlagMount_1", "FlagMount_2" } }
    local loadout = {
        baseStyle = "teahouse-1story",
        flags = { { mount = "FlagMount_1", item = "flag.clan" }, { mount = "FlagMount_9", item = "flag.noren" } },
    }
    local plan = Planner.plan(loadout, baseMount(), manifest, Catalog)
    expect(plan.attachments).toEqual({ { mount = "FlagMount_1", prefabId = "flag_clan" } })
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `attachments` is `{}`.

- [ ] **Step 3: Write minimal implementation** (add resolver + a `contains` helper, wire in)

Add near the top (below the type block):

```lua
local function contains(list: { string }, v: string): boolean
    for _, x in list do
        if x == v then
            return true
        end
    end
    return false
end
```

Add above `StructurePlanner.plan`:

```lua
local function resolveAttachments(loadout: Loadout, manifest: Manifest, catalog: Catalog): { Attachment }
    local out: { Attachment } = {}
    if not loadout.flags then
        return out
    end
    for _, f in loadout.flags do
        if contains(manifest.flagMounts, f.mount) then
            local e = catalog.get(f.item)
            if e and e.type == "attachment" then
                table.insert(out, { mount = f.mount, prefabId = e.payload.prefabId })
            end
        end
    end
    return out
end
```

Change `attachments = {},` in `plan` to `attachments = resolveAttachments(loadout, manifest, catalog),`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructurePlanner.luau roblox/tests/StructurePlanner.spec.luau
git commit -m "feat(roblox): StructurePlanner — flag attachment resolution"
```

---

### Task 5: StructurePlanner — handedness + datum pivot

**Files:**
- Modify: `roblox/src/shared/StructurePlanner.luau`
- Modify: `roblox/tests/StructurePlanner.spec.luau`

**Interfaces:**
- Produces: `plan().mirror = (mount.hand == "left")` and `plan().pivotCF = mount.cframe` (the prefab's authored pivot is the datum, so the snap is a passthrough).

- [ ] **Step 1: Write the failing test** (append)

```lua
test("mirror: true only for a left-hand mount", function()
    local manifest = { roles = {}, shojiBays = {}, hasTatami = false, flagMounts = {} }
    local right = Planner.plan({ baseStyle = "teahouse-1story" }, baseMount(), manifest, Catalog)
    local leftMount = { cframe = { 5, 6, 7, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "left", footprint = { x = 26, z = 20 } }
    local left = Planner.plan({ baseStyle = "teahouse-1story" }, leftMount, manifest, Catalog)
    expect(right.mirror).toBe(false)
    expect(left.mirror).toBe(true)
    expect(left.pivotCF).toEqual({ 5, 6, 7, 1, 0, 0, 0, 1, 0, 0, 0, 1 })
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `left.mirror` is `false`.

- [ ] **Step 3: Write minimal implementation**

In `StructurePlanner.plan`, change `mirror = false,` to `mirror = mount.hand == "left",`. (`pivotCF = mount.cframe` is already correct from Task 2.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS. The planner is now feature-complete.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructurePlanner.luau roblox/tests/StructurePlanner.spec.luau
git commit -m "feat(roblox): StructurePlanner — handedness flag + datum pivot passthrough"
```

---

### Task 6: StructureBuilder — orchestration over injectable ops

**Files:**
- Create: `roblox/src/shared/StructureBuilder.luau`
- Test: `roblox/tests/StructureBuilder.spec.luau`

**Interfaces:**
- Consumes: `StructurePlanner.plan` (Task 5), `StructureCatalog` (Task 1).
- Produces: `StructureBuilder.build(loadout, mount, catalog, ops) -> model`. `ops` is the Instance-operation adapter with this exact shape (the real one is defined in Task 8; a fake is used here):
  - `ops.clonePrefab(baseStyle: string) -> model`
  - `ops.readManifest(model) -> Manifest`
  - `ops.mirrorX(model)`
  - `ops.recolor(model, role: string, color: {number})`
  - `ops.setTexture(model, target: string, assetId: string)`
  - `ops.attachPrefab(model, mount: string, prefabId: string)`
  - `ops.pivotTo(model, pivotCF: {number})`

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/StructureBuilder.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local Catalog = require("../src/shared/StructureCatalog")
local Builder = require("../src/shared/StructureBuilder")

local function fakeOps(log: { any })
    return {
        clonePrefab = function(style: string)
            table.insert(log, { op = "clone", style = style })
            return { tag = "MODEL" }
        end,
        readManifest = function(_m)
            return { roles = { "cap" }, shojiBays = { 1 }, hasTatami = false, flagMounts = { "FlagMount_1" } }
        end,
        mirrorX = function(_m) table.insert(log, { op = "mirror" }) end,
        recolor = function(_m, role: string, _c) table.insert(log, { op = "recolor", role = role }) end,
        setTexture = function(_m, target: string, _a) table.insert(log, { op = "texture", target = target }) end,
        attachPrefab = function(_m, mount: string, _p) table.insert(log, { op = "attach", mount = mount }) end,
        pivotTo = function(_m, _cf) table.insert(log, { op = "pivot" }) end,
    }
end

test("build drives ops in order: clone, mirror(if left), recolor, texture, attach, pivot", function()
    local log: { any } = {}
    local mount = { cframe = { 1, 2, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "left", footprint = { x = 26, z = 20 } }
    local loadout = {
        baseStyle = "teahouse-1story",
        colorScheme = "scheme.ink",
        shoji = { [1] = "shoji.crane" },
        flags = { { mount = "FlagMount_1", item = "flag.clan" } },
    }
    local model = Builder.build(loadout, mount, Catalog, fakeOps(log))
    expect((model :: any).tag).toBe("MODEL")
    expect(log).toEqual({
        { op = "clone", style = "teahouse-1story" },
        { op = "mirror" },
        { op = "recolor", role = "cap" },
        { op = "texture", target = "ShojiBay:1" },
        { op = "attach", mount = "FlagMount_1" },
        { op = "pivot" },
    })
end)

test("build skips mirror for a right-hand mount", function()
    local log: { any } = {}
    local mount = { cframe = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, hand = "right", footprint = { x = 26, z = 20 } }
    Builder.build({ baseStyle = "teahouse-1story" }, mount, Catalog, fakeOps(log))
    expect(log).toEqual({ { op = "clone", style = "teahouse-1story" }, { op = "pivot" } })
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `StructureBuilder` not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/StructureBuilder.luau
--!strict
-- Thin orchestrator: asks the pure planner what to do, then drives an injected
-- `ops` adapter to do it against real Instances. The adapter is faked in tests
-- (Lune) and implemented for real in the Studio demo / runtime. Requiring the
-- planner is fine — it is pure and Lune-loadable.
local StructurePlanner = require("./StructurePlanner")

local StructureBuilder = {}

export type Ops = {
    clonePrefab: (string) -> any,
    readManifest: (any) -> StructurePlanner.Manifest,
    mirrorX: (any) -> (),
    recolor: (any, string, { number }) -> (),
    setTexture: (any, string, string) -> (),
    attachPrefab: (any, string, string) -> (),
    pivotTo: (any, { number }) -> (),
}

function StructureBuilder.build(loadout: StructurePlanner.Loadout, mount: StructurePlanner.Mount, catalog: any, ops: Ops): any
    local model = ops.clonePrefab(loadout.baseStyle)
    local manifest = ops.readManifest(model)
    local plan = StructurePlanner.plan(loadout, mount, manifest, catalog)
    if plan.mirror then
        ops.mirrorX(model)
    end
    for _, r in plan.recolors do
        ops.recolor(model, r.role, r.color)
    end
    for _, t in plan.textures do
        ops.setTexture(model, t.target, t.assetId)
    end
    for _, a in plan.attachments do
        ops.attachPrefab(model, a.mount, a.prefabId)
    end
    ops.pivotTo(model, plan.pivotCF)
    return model
end

return StructureBuilder
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS. Whole pure pipeline (catalog → planner → builder) is now covered.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructureBuilder.luau roblox/tests/StructureBuilder.spec.luau
git commit -m "feat(roblox): StructureBuilder — ops-driven orchestration (planner-integrated)"
```

---

### Task 7: Capture the `teahouse-1story` base prefab (Studio)

**Files:**
- Create: `roblox/tools/studio/captureTeahouseBase.luau` (committed record of the capture script; executed via MCP `execute_luau`, datamodel `Edit`)

**Interfaces:**
- Produces: `ServerStorage.StructurePrefabs.teahouse-1story` — a Model whose `WorldPivot` sits at the frame-underside datum with `LookVector` = veranda front, with the 6 `EngawaPost` parts removed, and the slot manifest authored: role tags, `ShojiBay` bay-indexed tags, `Tatami` tag, `FlagMount_1`/`FlagMount_2` Attachments, `MirrorX` tags on asymmetric parts. This is what `ops.clonePrefab("teahouse-1story")` clones in Task 8.

This is a Studio task — its gate is inspection + the Task 8 visual, not a Lune test. Run each step via MCP `execute_luau` (datamodel `Edit`).

- [ ] **Step 1: Clone the perfected prototype into a staging spot and strip pad-side posts**

```lua
local SS = game:GetService("ServerStorage")
local src = workspace:FindFirstChild("TeahousePrototype")
assert(src, "TeahousePrototype not found in workspace")
local folder = SS:FindFirstChild("StructurePrefabs") or Instance.new("Folder")
folder.Name = "StructurePrefabs"; folder.Parent = SS
local existing = folder:FindFirstChild("teahouse-1story")
if existing then existing:Destroy() end
local m = src:Clone()
m.Name = "teahouse-1story"
-- strip the pad's job: the terrain-raycasting support posts
local removed = 0
for _, p in m:GetDescendants() do
    if p:IsA("BasePart") and p.Name == "EngawaPost" then p:Destroy(); removed += 1 end
end
m.Parent = folder
return "cloned; removed " .. removed .. " EngawaPost"
```
Expected: `removed 6 EngawaPost`.

- [ ] **Step 2: Compute the datum (frame underside) and author the model pivot**

```lua
local SS = game:GetService("ServerStorage")
local m = SS.StructurePrefabs["teahouse-1story"]
local piv = m:GetPivot()  -- current placement (inherited from the prototype clone)
-- frame underside = min underside of the Perim* beams, in the model's LOCAL frame
local y0 = math.huge
for _, p in m:GetDescendants() do
    if p:IsA("BasePart") and p.Name:match("^Perim") then
        local ly = piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2
        y0 = math.min(y0, ly)
    end
end
-- confirm nothing lives below the datum (posts are gone)
local below = {}
for _, p in m:GetDescendants() do
    if p:IsA("BasePart") then
        local lb = piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2
        if lb < y0 - 0.01 then table.insert(below, p.Name) end
    end
end
-- author pivot: position = footprint-center at the datum plane; look = veranda front (local -Z)
local centerLocal = Vector3.new(0, y0, 0)  -- prototype local origin is centered on X/Z
local posW = piv:PointToWorldSpace(centerLocal)
local frontW = piv:VectorToWorldSpace(Vector3.new(0, 0, -1))
m.WorldPivot = CFrame.lookAt(posW, posW + frontW, Vector3.yAxis)
return "y0(local)=" .. string.format("%.2f", y0) .. " below={" .. table.concat(below, ",") .. "}"
```
Expected: `below={}` (nothing beneath the datum). Note the `y0` value.

- [ ] **Step 3: Author the slot manifest — role tags, ShojiBay, Tatami, MirrorX**

```lua
local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local m = SS.StructurePrefabs["teahouse-1story"]
local piv = m:GetPivot()
-- role tags for recolor (by part name -> role)
local ROLE = {
    Girder = "timber", RafterTail = "timber", Newel = "timber", Baluster = "timber",
    BackWall = "wall", SideWall = "wall", Shoji = "wall",
    RoofF = "roof", RoofB = "roof", GableA = "roof", GableB = "roof",
    RailCap = "cap", PerimF = "cap", PerimB = "cap", PerimL = "cap", PerimR = "cap", Joist = "cap", EngawaPost = "cap",
}
-- parts that flip on a left-hand build (asymmetric, engawa/support/side). Roof, gables,
-- front shoji, back wall stay UNtagged (symmetric / must not reflect).
local MIRROR = {
    EngawaF = true, EngawaS = true, RailCap = true, RailMid = true, Newel = true, Baluster = true,
    PerimF = true, PerimB = true, PerimL = true, PerimR = true, Joist = true,
    Lantern = true, Cord = true, LanCap = true, LanRib = true, SideWall = true,
}
local nRole, nMirror, nBay, nTat = 0, 0, 0, 0
for _, p in m:GetDescendants() do
    if p:IsA("BasePart") then
        if ROLE[p.Name] then p:AddTag("Role_" .. ROLE[p.Name]); nRole += 1 end
        -- side-wall shoji/glow/mull also mirror (thin in X, long in Z) — the bug we fixed
        local sideShoji = (p.Name == "Shoji" or p.Name == "ShojiGlow" or p.Name == "Mull") and p.Size.Z > p.Size.X
        if MIRROR[p.Name] or sideShoji then p:AddTag("MirrorX"); nMirror += 1 end
        -- ShojiBay: tag each FRONT shoji panel (faces Z) with a bay index by local X order
        if p.Name == "Shoji" and p.Size.X > p.Size.Z then
            local lx = piv:ToObjectSpace(p.CFrame).Position.X
            local bay = ({ [-6] = 1, [0] = 2, [6] = 3 })[math.floor(lx + 0.5)] or 0
            p:AddTag("ShojiBay"); p:SetAttribute("Bay", bay); nBay += 1
        end
        if p.Name == "Tatami" then p:AddTag("Tatami"); nTat += 1 end
    end
end
return string.format("roles=%d mirror=%d shojiBays=%d tatami=%d", nRole, nMirror, nBay, nTat)
```
Expected: nonzero counts for each (e.g. `shojiBays=3 tatami=1`).

- [ ] **Step 4: Author the flag-mount Attachments**

```lua
local SS = game:GetService("ServerStorage")
local m = SS.StructurePrefabs["teahouse-1story"]
local piv = m:GetPivot()
-- host the attachments on the front Perim beam so they travel with the model
local host = nil
for _, p in m:GetDescendants() do if p:IsA("BasePart") and p.Name == "PerimF" then host = p end end
assert(host, "PerimF host not found")
local function mount(name, localPos)
    local a = Instance.new("Attachment")
    a.Name = name
    a.WorldCFrame = piv * CFrame.new(localPos)
    a.Parent = host
    return a.Name
end
-- two flag masts at the front corners, above the veranda
mount("FlagMount_1", Vector3.new(-9, 12, -13))
mount("FlagMount_2", Vector3.new(15, 12, -13))
return "flag mounts authored: FlagMount_1, FlagMount_2"
```
Expected: attachments created.

- [ ] **Step 5: Verify the manifest reads back correctly, then STOP for the user**

```lua
local CollectionService = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local m = SS.StructurePrefabs["teahouse-1story"]
local function tagCount(t) local n=0 for _,p in m:GetDescendants() do if p:HasTag(t) then n+=1 end end return n end
local bays = {}
for _, p in m:GetDescendants() do if p:HasTag("ShojiBay") then table.insert(bays, p:GetAttribute("Bay")) end end
local mounts = {}
for _, a in m:GetDescendants() do if a:IsA("Attachment") and a.Name:match("^FlagMount_") then table.insert(mounts, a.Name) end end
return string.format("Role_*=%d MirrorX=%d Tatami=%d bays={%s} mounts={%s}",
    tagCount("Role_timber")+tagCount("Role_wall")+tagCount("Role_roof")+tagCount("Role_cap"),
    tagCount("MirrorX"), tagCount("Tatami"), table.concat(bays, ","), table.concat(mounts, ","))
```
Then **save the place** (place-only prefab) and **screenshot the prefab in ServerStorage / a cloned instance**, and **STOP** — ask the user to confirm the base prefab before proceeding. Do not iterate unprompted.

- [ ] **Step 6: Commit the capture record**

```bash
git add roblox/tools/studio/captureTeahouseBase.luau
git commit -m "chore(roblox): capture script for teahouse-1story base prefab (manifest + datum)"
```

---

### Task 8: Real ops + demo materialize + visual gate (Studio)

**Files:**
- Create: `roblox/tools/studio/materializeStructureDemo.luau` (committed record; executed via MCP `execute_luau`, datamodel `Edit`)

**Interfaces:**
- Consumes: the base prefab (Task 7). Implements the real `ops` (matching Task 6's `Ops` shape) inline, and applies a hardcoded sample `plan` (equal to what the Lune-tested `StructurePlanner` produces for the sample loadout) — because MCP Studio scripts cannot `require` repo modules, this is a deliberate mirror (precedent: `buildPaths.luau` mirrors `CanyonPath`). Its job is the visual proof, not logic coverage.

- [ ] **Step 1: Materialize a right-hand and a left-hand sample onto hand-placed mounts**

```lua
local SS = game:GetService("ServerStorage")
local prefab = SS.StructurePrefabs["teahouse-1story"]

-- real ops (mirror of StructureBuilder's adapter; logic is Lune-tested in src/shared)
local function recolorRole(m, role, rgb)
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("Role_" .. role) then p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3]) end
    end
end
local function setTexture(m, target, assetId)
    if target == "Tatami" then
        for _, p in m:GetDescendants() do if p:HasTag("Tatami") then
            local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal", p); d.Face = Enum.NormalId.Top; d.Texture = assetId
        end end
    else
        local bay = tonumber(target:match("ShojiBay:(%d+)"))
        for _, p in m:GetDescendants() do if p:HasTag("ShojiBay") and p:GetAttribute("Bay") == bay then
            local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal", p); d.Face = Enum.NormalId.Front; d.Texture = assetId
        end end
    end
end
local function mirrorX(m)
    local piv = m:GetPivot()
    for _, p in m:GetDescendants() do if p:IsA("BasePart") and p:HasTag("MirrorX") then
        local lc = piv:ToObjectSpace(p.CFrame); local rot = lc - lc.Position
        p.CFrame = piv * (CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * rot)
    end end
end

-- sample plan == StructurePlanner.plan for loadout{colorScheme=scheme.vermilion, shoji[2]=shoji.crane, tatami=tatami.gold}
local function apply(m, hand)
    if hand == "left" then mirrorX(m) end
    recolorRole(m, "timber", {120,45,35}); recolorRole(m, "wall", {232,216,190})
    recolorRole(m, "roof", {40,42,48}); recolorRole(m, "cap", {40,42,48})
    setTexture(m, "ShojiBay:2", "rbxassetid://102000000001")
    setTexture(m, "Tatami", "rbxassetid://102000000011")
end

local demo = workspace:FindFirstChild("StructureDemo") or Instance.new("Folder")
demo.Name = "StructureDemo"; demo:ClearAllChildren(); demo.Parent = workspace
local baseR = workspace.TeahousePrototype:GetPivot().Position + Vector3.new(120, 0, 0)
local mounts = {
    { hand = "right", cf = CFrame.new(baseR) },
    { hand = "left", cf = CFrame.new(baseR + Vector3.new(60, 0, 0)) },
}
for _, mt in mounts do
    local m = prefab:Clone(); m.Parent = demo
    apply(m, mt.hand)
    m:PivotTo(mt.cf)  -- snap datum -> mount
end
return "materialized right + left at " .. tostring(baseR)
```

- [ ] **Step 2: Screenshot both and STOP for the user**

Screenshot the right-hand and left-hand demo instances (front + underside). Confirm: floor/veranda coplanar, black cap, shoji print on bay 2, tatami mat, and — critically — the **left-hand instance's side shoji face its veranda** (the bug we fixed is prevented by the `MirrorX` tags). Then **STOP** and ask the user to review. Do not self-judge or iterate.

- [ ] **Step 3: Clean up the demo scaffold and commit the record**

```lua
local d = workspace:FindFirstChild("StructureDemo"); if d then d:Destroy() end
return "demo scaffold removed"
```

```bash
git add roblox/tools/studio/materializeStructureDemo.luau
git commit -m "chore(roblox): structure builder demo harness + visual gate"
```

---

## Notes / follow-ups (out of scope for this plan)

- **Versioned prefab:** v1 keeps `ServerStorage.StructurePrefabs.teahouse-1story` place-only (saved in the place), matching how all canyon geometry is stored. Committing it as a `.rbxmx` under a new Rojo `ServerStorage` mount in `default.project.json` is a non-blocking follow-up if we want the prefab in version control.
- **Runtime wiring (sub-project D):** the real `ops` implementation belongs in a committed module (e.g. `src/server/StructureOps.luau`) that `main.server.luau` requires and calls via `StructureBuilder.build`, driven by pad assignment. This plan proves the pipeline in Studio; D wires it to spawns.
- **Sliding shoji** interaction (prompt + tween + multiplayer state) is a separate follow-on; the prefab only needs the shoji grouped/slide-ready.

## Self-review

- **Spec coverage:** loadout schema → Task 2–5 types; three mechanisms → Tasks 2 (recolor) / 3 (texture) / 4 (attachment); slot manifest → Task 7; planner/applier split → Tasks 2–5 (planner) + 6 (builder) + 8 (real ops); datum + `mount` contract → Task 5 (`pivotCF`) + Task 7 (authored pivot, posts stripped) + Task 8 (`PivotTo`); handedness via `MirrorX` → Task 7 (tagging) + 8 (mirror) + Task 5 (flag); prefab home → Task 7; Lune testing → Tasks 1–6; visual gate → Task 8. Capture of the session-perfected prototype → Task 7.
- **Placeholder scan:** none — every code step is complete; the two Studio tasks carry full scripts and explicit expected outputs.
- **Type consistency:** `Loadout/Mount/Manifest/Plan` defined in Task 2, reused verbatim in 3–6; `ops` shape declared in Task 6 and implemented in Task 8; `plan` fields (`recolors/textures/attachments/mirror/pivotCF`) consistent across planner tasks and the builder; `target` format `"ShojiBay:<n>"`/`"Tatami"` matches between Task 3 (producer) and Task 8 (consumer); `Role_<role>` / `MirrorX` / `ShojiBay`+`Bay` / `FlagMount_*` tags consistent between Task 7 (author) and Task 8 (read).
