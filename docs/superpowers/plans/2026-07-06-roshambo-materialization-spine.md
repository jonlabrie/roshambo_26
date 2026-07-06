# Roshambo Materialization Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At server startup, materialize one player's persisted teahouse loadout as a correctly-standing structure on a surveyed NearWall pad — proving A + B + C compose end-to-end.

**Architecture:** Add one Lune-tested `NetworkClient` method to fetch the loadout (C), plus Studio-only runtime `ops` adapters productionized from the throwaway demos, a baked surveyed pad spec, and startup wiring in `main.server.luau` that runs `PadBuilder.build` → `StructureBuilder.build` once for a hardcoded owner. No player lifecycle (that's D.2).

**Tech Stack:** Luau (`--!strict`), Rojo, Lune test harness (`roblox/tests/`), Roblox Studio (MCP `execute_luau` for survey + gate), the live `/api/v1` server (C.1).

## Global Constraints

- **DI rule:** runtime modules never `require` each other except pure Lune-loadable planners; the `ops` adapters are injected into `StructureBuilder.build` / `PadBuilder.build`. Copied verbatim from the repo pattern (`main.server.luau` wires `deps`).
- **`--!strict`** header on every Luau module.
- **Lint gate:** `stylua --check src tests && selene src` must pass (run from `roblox/`).
- **Studio-only modules can't be Lune-tested** (Roblox datatypes: `CFrame`, `Instance`, `RaycastParams`). `StructureOps`, `PadOps`, `PadSites`, and the `main.server.luau` wiring have **no specs**; their correctness is proven by the single visual gate in Task 5.
- **`teahouse-1story` prefab is PLACE-ONLY** (`ServerStorage.StructurePrefabs.teahouse-1story`, captured via `tools/studio/captureTeahouseBase.luau`). This increment depends on running in the saved place; committing the prefab via Rojo is a **separate open follow-up**, not in scope.
- **Footprint is shared:** every `teahouse-1story` pad uses the prefab's frame extents `{ minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 }` (same as `tools/studio/padSites.luau` `cliff_proof`). Only `mountCF` (datum pos + facing) and `hand` are surveyed per perch.
- **`TEST_OWNER = "90000001"`** — an arbitrary but fixed robloxUserId string, identical in the seed command (Task 5) and `main.server.luau`. `resolveUser` treats it as a `robloxId`.
- **Seeded loadout (Task 5):** `{ "baseStyle": "teahouse-1story", "colorScheme": "scheme.vermilion" }` — recolor only. The visible gate proof is the vermilion recolor; shoji/tatami textures are placeholder asset ids that will not render (deferred until real prints exist), so they are intentionally omitted.
- **Stop-and-ask:** the visual gate is ONE attempt, then STOP for the user to look — never self-judge and iterate (user standing rule).

---

### Task 1: `NetworkClient:getTeahouses` (Lune TDD)

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau` (add method after `getLeaderboards`, ~line 126)
- Test: `roblox/tests/NetworkClient.spec.luau` (add a `describe` block after the `getLeaderboards` block, ~line 237)

**Interfaces:**
- Consumes: `NetworkClient._request(self, method, path)` (existing) → `Result`.
- Produces: `net:getTeahouses(robloxUserId: string): Result` — `GET /api/v1/players/{robloxUserId}/teahouses`; on 200 → `{ ok = true, data = { teahouses = {...} } }`.

- [ ] **Step 1: Write the failing test**

Add to `roblox/tests/NetworkClient.spec.luau` (after line 237, before EOF):

```lua
describe("NetworkClient.getTeahouses", function()
    test("hits the player teahouses path and decodes the map", function()
        local f = makeDeps({
            { ok = true, statusCode = 200, body = '{"teahouses":{"M":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}}' },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getTeahouses("90000001")
        expect(res.ok).toBe(true)
        expect(res.data.teahouses.M.baseStyle).toBe("teahouse-1story")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/90000001/teahouses")
        expect(f.calls[1].method).toBe("GET")
    end)

    test("wanderer returns an empty map, still ok", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"teahouses":{}}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getTeahouses("90000001")
        expect(res.ok).toBe(true)
        expect(next(res.data.teahouses)).toBe(nil)
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL in the `NetworkClient.getTeahouses` block — `attempt to call a nil value (method 'getTeahouses')`.

- [ ] **Step 3: Write the minimal implementation**

Add to `roblox/src/server/NetworkClient.luau` after `getLeaderboards` (after line 126, before `return NetworkClient`):

```lua
function NetworkClient.getTeahouses(self: any, robloxUserId: string): Result
    return self:_request("GET", `/api/v1/players/{robloxUserId}/teahouses`)
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS — all specs green (the two new tests plus the existing suite).

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no diffs, no warnings.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(roblox): NetworkClient:getTeahouses (sub-project D.1)"
```

---

### Task 2: `StructureOps` runtime adapter

**Files:**
- Create: `roblox/src/server/StructureOps.luau`

**Interfaces:**
- Consumes: nothing (leaf module). Reads `ServerStorage.StructurePrefabs[baseStyle]` and CollectionService tags at runtime.
- Produces: a table satisfying `StructureBuilder.Ops` (`roblox/src/shared/StructureBuilder.luau:10-18`): `clonePrefab`, `readManifest`, `mirrorX`, `recolor`, `setTexture`, `attachPrefab`, `pivotTo`. `readManifest` returns `StructurePlanner.Manifest` = `{ roles: {string}, shojiBays: {number}, hasTatami: boolean, flagMounts: {string} }`.

No Lune test — this module uses Roblox datatypes. `recolor`/`setTexture`/`mirrorX` are productionized verbatim from `tools/studio/materializeStructureDemo.luau` (do not re-derive); `readManifest`, `pivotTo`, `clonePrefab`, `attachPrefab` are new. Verified by the Task 5 gate.

- [ ] **Step 1: Write the module**

Create `roblox/src/server/StructureOps.luau`:

```lua
--!strict
-- Runtime `ops` adapter for A's StructureBuilder (injected in main.server.luau).
-- recolor/setTexture/mirrorX are productionized verbatim from the throwaway
-- tools/studio/materializeStructureDemo.luau; readManifest/clonePrefab/pivotTo are new.
-- Roblox datatypes -> not Lune-testable; proven by the D.1 visual gate.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local StructureOps = {}

function StructureOps.clonePrefab(baseStyle: string): Model
    return (ServerStorage:FindFirstChild("StructurePrefabs") :: Folder):FindFirstChild(baseStyle):Clone() :: Model
end

function StructureOps.readManifest(model: Model): any
    local roleSet: { [string]: boolean } = {}
    local shojiSet: { [number]: boolean } = {}
    local flagSet: { [string]: boolean } = {}
    local hasTatami = false
    for _, d in model:GetDescendants() do
        for _, tag in CollectionService:GetTags(d) do
            local role = string.match(tag, "^Role_(.+)$")
            if role then
                roleSet[role] = true
            elseif tag == "ShojiBay" then
                local bay = d:GetAttribute("Bay")
                if typeof(bay) == "number" then
                    shojiSet[bay] = true
                end
            elseif tag == "Tatami" then
                hasTatami = true
            elseif string.match(tag, "^FlagMount") then
                flagSet[tag] = true
            end
        end
    end
    local roles, shojiBays, flagMounts = {}, {}, {}
    for r in roleSet do
        table.insert(roles, r)
    end
    for b in shojiSet do
        table.insert(shojiBays, b)
    end
    for fm in flagSet do
        table.insert(flagMounts, fm)
    end
    return { roles = roles, shojiBays = shojiBays, hasTatami = hasTatami, flagMounts = flagMounts }
end

function StructureOps.mirrorX(m: Model)
    local piv = m:GetPivot()
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("MirrorX") then
            local lc = piv:ToObjectSpace(p.CFrame)
            local rot = lc - lc.Position
            p.CFrame = piv * (CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * rot)
        end
    end
    for _, d in m:GetDescendants() do
        if d:IsA("Model") and d:HasTag("MirrorXRigid") then
            local lc = piv:ToObjectSpace(d:GetPivot())
            d:PivotTo(piv * CFrame.new(-lc.Position.X, lc.Position.Y, lc.Position.Z) * (lc - lc.Position))
        end
    end
end

function StructureOps.recolor(m: Model, role: string, rgb: { number })
    for _, p in m:GetDescendants() do
        if p:IsA("BasePart") and p:HasTag("Role_" .. role) then
            p.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
        end
    end
end

function StructureOps.setTexture(m: Model, target: string, assetId: string)
    if target == "Tatami" then
        for _, p in m:GetDescendants() do
            if p:HasTag("Tatami") then
                local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal", p)
                d.Face = Enum.NormalId.Top
                d.Texture = assetId
            end
        end
    else
        local bay = tonumber(target:match("ShojiBay:(%d+)"))
        for _, p in m:GetDescendants() do
            if p:HasTag("ShojiBay") and p:GetAttribute("Bay") == bay then
                local d = p:FindFirstChildOfClass("Decal") or Instance.new("Decal", p)
                d.Face = Enum.NormalId.Front
                d.Texture = assetId
            end
        end
    end
end

function StructureOps.attachPrefab(_m: Model, mount: string, prefabId: string)
    -- Flags/attachments are out of D.1 scope (seeded loadout carries none). A real
    -- implementation clones ServerStorage.StructureComponents[prefabId] to the named
    -- anchor; deferred until component prefabs + the economy catalog exist.
    warn(`[StructureOps] attachPrefab not implemented in D.1 (mount={mount}, prefab={prefabId})`)
end

function StructureOps.pivotTo(m: Model, cf12: { number })
    m:PivotTo(CFrame.new(table.unpack(cf12)))
end

return StructureOps
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no diffs, no warnings. (Fix any `stylua` formatting by running `stylua src` and re-checking.)

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/StructureOps.luau
git commit -m "feat(roblox): StructureOps runtime adapter (sub-project D.1)"
```

---

### Task 3: `PadOps` runtime adapter

**Files:**
- Create: `roblox/src/server/PadOps.luau`

**Interfaces:**
- Consumes: nothing (leaf). Raycasts `workspace.Terrain`.
- Produces: `PadOps.new(mountCF: CFrame, parent: Instance)` → a table satisfying `PadBuilder.Ops` (`roblox/src/shared/PadBuilder.luau:11-14`): `raycastGround(x, z) -> number?`, `buildPost(pos: {number}, height: number) -> ()`. A **factory** (unlike `StructureOps`) because both ops need baked context — the ray origin Y (from `mountCF`) and the post parent.

Productionized verbatim from `tools/studio/buildPadDemo.luau:33-47`. No Lune test.

- [ ] **Step 1: Write the module**

Create `roblox/src/server/PadOps.luau`:

```lua
--!strict
-- Runtime `ops` adapter for B's PadBuilder (injected in main.server.luau). Factory:
-- raycastGround needs the datum-plane Y (from mountCF) as its ray origin and buildPost
-- needs a parent, so both are baked at construction. Productionized verbatim from the
-- throwaway tools/studio/buildPadDemo.luau. Roblox datatypes -> not Lune-testable.
local PadOps = {}

local BLACK = Color3.fromRGB(45, 48, 56)

function PadOps.new(mountCF: CFrame, parent: Instance)
    return {
        raycastGround = function(x: number, z: number): number?
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = { workspace.Terrain }
            local hit = workspace:Raycast(Vector3.new(x, mountCF.Position.Y + 4, z), Vector3.new(0, -600, 0), rp)
            return hit and hit.Position.Y or nil
        end,
        buildPost = function(pos: { number }, height: number)
            local p = Instance.new("Part")
            p.Name, p.Anchored, p.CanCollide, p.CastShadow = "PadPost", true, false, false
            p.Size = Vector3.new(1.2, height, 1.2)
            p.Color = BLACK
            p.Material = Enum.Material.Wood
            p.CFrame = CFrame.new(pos[1], pos[2], pos[3])
            p.Parent = parent
        end,
    }
end

return PadOps
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no diffs, no warnings.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/PadOps.luau
git commit -m "feat(roblox): PadOps runtime adapter (sub-project D.1)"
```

---

### Task 4: Survey a NearWall perch → `PadSites.luau`

**Files:**
- Create: `roblox/src/server/PadSites.luau`

**Interfaces:**
- Consumes: nothing.
- Produces: `PadSites["nearwall-1"]` = `{ id: string, mountCF: {number}(12), hand: string, footprint: {minX,maxX,minZ,maxZ}, vacantForm: string }` — the `PadBuilder.PadSpec` shape (`id`/`vacantForm` are ignored by `PadBuilder`, carried for D.2).

This task runs **in Studio** (MCP `execute_luau`) to measure a real perch, then bakes the numbers. The footprint is reused from the prefab (Global Constraints); only `mountCF` and `hand` are measured. Per the floor-vs-pivot rule, probe the floor stack (`Deck`/`EngawaF`/`Table`), NOT the model pivot (buried stilts drag it down).

- [ ] **Step 1: Choose the perch**

Pick a NearWall perch that already has walk-up access and a legacy `teahouse-1story`-style teahouse, ideally where the ground drops away on the veranda side so all 6 support posts hit terrain (like `cliff_proof`). Note its model path under `workspace` (e.g. `workspace.CanyonTeahouses.<name>`).

- [ ] **Step 2: Probe the datum + facing in Studio**

Run via MCP `execute_luau` (Edit datamodel) against the chosen model `TH` — this reads the floor-underside Y, the horizontal center, and the yaw, and prints the ready-to-bake 12-number `mountCF`:

```lua
local TH = workspace.CanyonTeahouses["<CHOSEN_NAME>"] -- set path
-- floor-underside datum: lowest Y of the floor stack, not the buried pivot
local floorY = math.huge
for _, p in TH:GetDescendants() do
    if p:IsA("BasePart") and (p.Name == "Deck" or p.Name:match("^Engawa") or p.Name == "Table") then
        floorY = math.min(floorY, p.Position.Y - p.Size.Y / 2)
    end
end
local pivot = TH:GetPivot()
local _, yaw = pivot:ToEulerAnglesYXZ()
local datum = CFrame.new(pivot.Position.X, floorY, pivot.Position.Z) * CFrame.Angles(0, yaw, 0)
print(("mountCF = { %.2f, %.2f, %.2f, %s }"):format(
    datum.Position.X, datum.Position.Y, datum.Position.Z,
    table.concat({ select(4, datum:GetComponents()) }, ", ")))
return "hand: veranda(-Z) faces the open drop? then right; if mirrored, left"
```

Record the printed `mountCF` numbers. Determine `hand`: the prefab veranda faces local **-Z** on a right-hand build; if the legacy teahouse's veranda faces the opposite way relative to the yaw, it is `"left"`. (Confirm visually against the perch in Task 5's gate — if handedness is wrong, flip and re-run once.)

- [ ] **Step 3: Write the module**

Create `roblox/src/server/PadSites.luau` with the measured values (example numbers shown — replace with the Step 2 output):

```lua
--!strict
-- Baked surveyed PadSpec(s) for sub-project D materialization. mountCF is in
-- CFrame:GetComponents order (pos + row-major rotation); the datum plane is the
-- structure's floor-underside (probe Deck/EngawaF/Table, never the buried pivot).
-- footprint is the teahouse-1story prefab's frame extents (shared by all teahouse-1story
-- pads). id/vacantForm are carried for D.2 (the registry + vacant-state applier).
return {
    ["nearwall-1"] = {
        id = "nearwall-1",
        mountCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, -- REPLACE with Task 4 Step 2 output
        hand = "right", -- REPLACE if Step 2 determined "left"
        footprint = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 },
        vacantForm = "dormant-structure",
    },
}
```

- [ ] **Step 4: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no diffs, no warnings.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/server/PadSites.luau
git commit -m "feat(roblox): PadSites — surveyed nearwall-1 perch (sub-project D.1)"
```

---

### Task 5: Wire `main.server.luau` + seed + stage + visual gate

**Files:**
- Modify: `roblox/src/server/main.server.luau` (add a startup block near the end, before or after the poll loop at line 351)

**Interfaces:**
- Consumes: `net:getTeahouses` (Task 1), `StructureOps` (Task 2), `PadOps.new` (Task 3), `PadSites` (Task 4), `StructureBuilder.build`/`PadBuilder.build`/`StructureCatalog` (shared, existing).
- Produces: a materialized teahouse `Model` under `workspace.MaterializedSite_nearwall-1`, standing on `PadPost` parts.

Setup (seed + legacy staging) is folded into this task because the gate needs it.

- [ ] **Step 1: Seed the TEST_OWNER loadout**

Against the same `baseUrl`/`apiKey` the Studio place uses (`roblox/src/server/SecretsLocal.luau`), run:

```bash
curl -sS -X PUT "$BASE_URL/api/v1/players/90000001/teahouses/M" \
  -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" \
  -d '{"loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}'
```

Expected: `200 {"sizeClass":"M","loadout":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}`.
Verify: `curl -sS "$BASE_URL/api/v1/players/90000001/teahouses" -H "X-API-Key: $API_KEY"` → `{"teahouses":{"M":{...}}}`.

- [ ] **Step 2: Stage the legacy perch (reversible)**

In Studio (MCP `execute_luau`, Edit), archive the chosen perch's legacy teahouse so the materialized one stands in a clean spot — move it, don't delete:

```lua
local TH = workspace.CanyonTeahouses["<CHOSEN_NAME>"]
TH.Parent = game:GetService("ServerStorage") -- reversible: drag back to restore
return "archived " .. TH.Name
```

- [ ] **Step 3: Add the materialization block to `main.server.luau`**

Insert before the poll loop (`print(\`[ROSHAMBO] playable loop starting...\`)`, line 350):

```lua
-- D.1: static materialization spine — stand TEST_OWNER's persisted teahouse on a surveyed pad.
local StructureBuilder = require(shared:WaitForChild("StructureBuilder"))
local PadBuilder = require(shared:WaitForChild("PadBuilder"))
local StructureCatalog = require(shared:WaitForChild("StructureCatalog"))
local StructureOps = require(script.Parent:WaitForChild("StructureOps"))
local PadOps = require(script.Parent:WaitForChild("PadOps"))
local PadSites = require(script.Parent:WaitForChild("PadSites"))

local TEST_OWNER = "90000001"

task.spawn(function()
    local res = net:getTeahouses(TEST_OWNER)
    if not res.ok then
        warn(`[D.1] getTeahouses failed: {res.error or res.status}`)
        return
    end
    local loadout = (res.data.teahouses or {}).M
    if not loadout then
        warn("[D.1] TEST_OWNER has no 'M' teahouse; seed one via PUT .../teahouses/M")
        return
    end

    local site = PadSites["nearwall-1"]
    local folder = Instance.new("Folder")
    folder.Name = "MaterializedSite_nearwall-1"
    folder.Parent = workspace

    local mountCF = CFrame.new(table.unpack(site.mountCF))
    local mount = PadBuilder.build(site, PadOps.new(mountCF, folder))
    local model = StructureBuilder.build(loadout, mount, StructureCatalog, StructureOps)
    model.Parent = folder
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
    print("[D.1] materialized TEST_OWNER teahouse on nearwall-1")
end)
```

- [ ] **Step 4: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no diffs, no warnings.

- [ ] **Step 5: Run the visual gate (ONE attempt, then STOP)**

Sync via Rojo into the open saved place (`cd roblox && rojo serve`, connect in Studio), Play, and confirm at `workspace.MaterializedSite_nearwall-1`:
- a teahouse stands at the surveyed perch, **vermilion** (persisted `colorScheme` visibly applied — reddish timber, not the default brown);
- correct handedness (side shoji face the veranda, solid SideWall on the cliff side; chōchin on the correct corner);
- 6 `PadPost` stilts descend to terrain (back short, front long over the drop);
- the frame underside is flush on the post tops at the datum;
- the veranda faces the open drop.

Check the output for `[D.1] materialized TEST_OWNER teahouse on nearwall-1` (and no `[D.1]` warnings). **Do not judge/iterate — STOP and ask the user to look.** If handedness is wrong, that's the one allowed correction: flip `hand` in `PadSites.luau` and re-run.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): materialize persisted loadout on surveyed pad (sub-project D.1)"
```

---

## Self-Review

**Spec coverage:**
- `NetworkClient:getTeahouses` (Lune-tested) → Task 1. ✓
- `StructureOps` productionized from demo → Task 2. ✓
- `PadOps` productionized from demo → Task 3. ✓
- `PadSites` surveyed NearWall perch → Task 4. ✓
- Startup wiring, `Persistent`, hardcoded owner+pad, no registry → Task 5 Step 3. ✓
- Seeded visibly-customized loadout → Task 5 Step 1. ✓
- Legacy-perch staging (reversible) → Task 5 Step 2. ✓
- `teahouse-1story` place-only dependency → Global Constraints (not solved here). ✓
- Visual gate criteria → Task 5 Step 5. ✓
- Non-goals (lifecycle/vacant/multi-size/preference/migration) → excluded; no task touches them. ✓

**Placeholder scan:** the only "REPLACE" markers are in Task 4 Step 3 `PadSites.luau`, whose values are the printed output of the Task 4 Step 2 probe — a measurement, not an unfilled placeholder. `<CHOSEN_NAME>`/`$BASE_URL`/`$API_KEY` are execution-time inputs the executor supplies, documented where used. No `TODO`/`TBD`/"add error handling".

**Type consistency:** `getTeahouses` returns `Result` with `data.teahouses` (Task 1) — consumed as `res.data.teahouses.M` (Task 5). `PadOps.new(mountCF, parent)` (Task 3) — called with `(mountCF, folder)` (Task 5). `PadBuilder.build(site, ops)` returns the mount consumed by `StructureBuilder.build(loadout, mount, catalog, ops)`; the planner reads only `mount.cframe`/`mount.hand` (verified `StructurePlanner.plan:95-103`), so `PadBuilder`'s `footprint` shape is harmlessly ignored. `readManifest` returns `{roles, shojiBays, hasTatami, flagMounts}` matching `StructurePlanner.Manifest` (Task 2). `mountCF` 12-array → `CFrame.new(table.unpack(...))` (Task 5) matches the `padSites.luau`/`buildPadDemo` convention.
