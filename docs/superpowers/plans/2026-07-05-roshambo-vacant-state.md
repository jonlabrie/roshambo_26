# Vacant-State Resolver (Sub-Project B, Increment 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pure `VacantState.resolve` that maps a pad's occupancy + class to a discriminated visual treatment (`structure` | `garden`), with a dark `scheme.dormant` recolor for the vacant cliff form, verified in Studio (dormant vs claimed).

**Architecture:** The dormant shell reuses A's recolor mechanism (a new catalog entry); `VacantState.resolve` is a pure switch on occupant + `vacantForm`. Pure Luau, Lune-tested; one Studio visual gate. See spec: `docs/superpowers/specs/2026-07-05-roshambo-vacant-state-design.md`.

**Tech Stack:** Luau; Lune harness; Rojo (`src/shared → ReplicatedStorage.RoshamboShared`); Roblox Studio via MCP for the visual gate.

## Global Constraints

- **Purity:** `StructureCatalog` and `VacantState` run under Lune — plain tables only, no Roblox datatypes, no `math.random`.
- **`Treatment`** discriminated union: `{ kind = "structure", loadout, lit: boolean }` or `{ kind = "garden" }`.
- **`resolve(occupant, ownerLoadout, vacantForm)`** cases: claimed (occupant~=nil, loadout) → `{structure, ownerLoadout, lit=true}`; claimed no-loadout → `{structure, DORMANT, lit=true}`; vacant `"dormant-structure"`/omitted → `{structure, DORMANT, lit=false}`; vacant `"pocket-garden"` → `{garden}`.
- **`DORMANT`** = a *fresh* `{ baseStyle = "teahouse-1story", colorScheme = "scheme.dormant" }` each call (never return a shared mutable constant); the claimed case passes `ownerLoadout` **through by reference**.
- **`scheme.dormant`** recolor payload (exact): `timber={48,46,44}, wall={70,68,64}, roof={36,37,40}, cap={40,42,46}`.
- **Module paths:** `roblox/src/shared/`; specs require `../src/shared/<Name>`. Run `lune run tests/run` from `roblox/` (baseline: 273 passing).
- **Task 3 (Studio) stops for the user** — screenshot then pause; never self-judge.

---

### Task 1: scheme.dormant catalog entry

**Files:**
- Modify: `roblox/src/shared/StructureCatalog.luau`
- Modify: `roblox/tests/StructureCatalog.spec.luau`

**Interfaces:**
- Produces: `StructureCatalog.get("scheme.dormant")` → a recolor entry with a dark per-role palette. Consumed by `VacantState` (Task 2) and A's `StructureBuilder`.

- [ ] **Step 1: Write the failing test** (append to the spec)

```lua
test("get returns the dormant recolor scheme with a dark per-role palette", function()
    local e = Catalog.get("scheme.dormant")
    expect(e).toBeTruthy()
    expect((e :: any).type).toBe("recolor")
    expect((e :: any).slot).toBe("colorScheme")
    expect((e :: any).payload.timber).toEqual({ 48, 46, 44 })
    expect((e :: any).payload.wall).toEqual({ 70, 68, 64 })
    expect((e :: any).payload.roof).toEqual({ 36, 37, 40 })
    expect((e :: any).payload.cap).toEqual({ 40, 42, 46 })
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `Catalog.get("scheme.dormant")` is nil.

- [ ] **Step 3: Add the entry**

In `roblox/src/shared/StructureCatalog.luau`, add to the `ENTRIES` table (alongside the other `scheme.*` entries):

```lua
	["scheme.dormant"] = {
		id = "scheme.dormant", type = "recolor", slot = "colorScheme",
		payload = { timber = { 48, 46, 44 }, wall = { 70, 68, 64 }, roof = { 36, 37, 40 }, cap = { 40, 42, 46 } },
	},
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StructureCatalog.luau roblox/tests/StructureCatalog.spec.luau
git commit -m "feat(roblox): StructureCatalog — scheme.dormant (vacant-pad dark shell)"
```

---

### Task 2: VacantState.resolve

**Files:**
- Create: `roblox/src/shared/VacantState.luau`
- Test: `roblox/tests/VacantState.spec.luau`

**Interfaces:**
- Consumes: `scheme.dormant` (Task 1) indirectly (the dormant loadout references it).
- Produces: `VacantState.resolve(occupant: string?, ownerLoadout: any?, vacantForm: string?) -> Treatment` where `Treatment = { kind: "structure", loadout: any, lit: boolean } | { kind: "garden" }`.

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/VacantState.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local VacantState = require("../src/shared/VacantState")

test("vacant cliff (omitted or dormant-structure) -> dark structure, unlit", function()
    local t = VacantState.resolve(nil, nil, nil)
    expect(t.kind).toBe("structure")
    expect(t.loadout.baseStyle).toBe("teahouse-1story")
    expect(t.loadout.colorScheme).toBe("scheme.dormant")
    expect(t.lit).toBe(false)
    expect(VacantState.resolve(nil, nil, "dormant-structure").lit).toBe(false)
end)

test("claimed with loadout -> owner structure (passed through), lit", function()
    local owner = { baseStyle = "teahouse-1story", colorScheme = "scheme.vermilion" }
    local t = VacantState.resolve("player1", owner, "dormant-structure")
    expect(t.kind).toBe("structure")
    expect(t.loadout).toBe(owner) -- same reference, not a copy
    expect(t.lit).toBe(true)
end)

test("claimed without loadout -> dormant structure, lit (defensive)", function()
    local t = VacantState.resolve("player1", nil, "dormant-structure")
    expect(t.kind).toBe("structure")
    expect(t.loadout.colorScheme).toBe("scheme.dormant")
    expect(t.lit).toBe(true)
end)

test("vacant valley (pocket-garden) -> garden marker", function()
    local t = VacantState.resolve(nil, nil, "pocket-garden")
    expect(t.kind).toBe("garden")
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `VacantState` not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/VacantState.luau
--!strict
-- Maps a pad's occupancy + class to the visual treatment for the pad. Pure (Lune-tested).
-- Vacant cliff pads show a dark base-form teahouse (scheme.dormant) with unlit shoji;
-- vacant valley pads show a pocket-garden mask (marker only here — applier deferred);
-- a claimed pad shows the owner's loadout, lit. `occupant` comes from PadRegistry:get(id),
-- `vacantForm` from the PadSpec; both are parameters so this stays decoupled from the registry.
local VacantState = {}

export type Treatment =
	{ kind: "structure", loadout: any, lit: boolean }
	| { kind: "garden" }

local VACANT_BASE = "teahouse-1story"

local function dormant(): { baseStyle: string, colorScheme: string }
	return { baseStyle = VACANT_BASE, colorScheme = "scheme.dormant" }
end

function VacantState.resolve(occupant: string?, ownerLoadout: any?, vacantForm: string?): Treatment
	if occupant ~= nil then
		-- claimed: the owner's structure, lit (dormant fallback if a loadout is missing)
		return { kind = "structure", loadout = ownerLoadout or dormant(), lit = true }
	end
	if vacantForm == "pocket-garden" then
		-- valley: a garden mask (applier deferred to a later increment)
		return { kind = "garden" }
	end
	-- cliff (dormant-structure, or omitted): dark base form, shoji unlit
	return { kind = "structure", loadout = dormant(), lit = false }
end

return VacantState
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/VacantState.luau roblox/tests/VacantState.spec.luau
git commit -m "feat(roblox): VacantState.resolve — occupancy+class -> structure|garden treatment"
```

---

### Task 3: Vacant vs claimed visual gate (Studio)

**Files:**
- Create: `roblox/tools/studio/vacantStateDemo.luau` (committed record; executed via MCP `execute_luau`, datamodel `Edit`)

**Interfaces:**
- Consumes: `ServerStorage.StructurePrefabs.teahouse-1story` (A); mirrors `PadRegistry` + `VacantState.resolve` + A's recolor inline (MCP can't `require` repo modules — same pattern as A/B demos). Visual proof only; the logic is Lune-tested in Tasks 1–2.

- [ ] **Step 1: Materialize a vacant (dormant, unlit) structure beside a claimed (vermilion, lit) one**

```lua
local SS = game:GetService("ServerStorage")
local demo = workspace:FindFirstChild("VacantStateDemo"); if demo then demo:Destroy() end
demo = Instance.new("Folder"); demo.Name = "VacantStateDemo"; demo.Parent = workspace

-- palettes (mirror StructureCatalog: scheme.dormant + scheme.vermilion)
local DORMANT = { timber={48,46,44}, wall={70,68,64}, roof={36,37,40}, cap={40,42,46} }
local VERMILION = { timber={120,45,35}, wall={232,216,190}, roof={40,42,48}, cap={40,42,48} }

-- mirror VacantState.resolve for two pad states
local function resolve(occupant, ownerPalette)
  if occupant ~= nil then return { palette = ownerPalette or DORMANT, lit = true } end
  return { palette = DORMANT, lit = false } -- cliff vacant
end

local function recolor(m, pal)
  for _, p in m:GetDescendants() do
    if p:IsA("BasePart") then
      for _, role in {"timber","wall","roof","cap"} do
        if p:HasTag("Role_"..role) then p.Color = Color3.fromRGB(pal[role][1], pal[role][2], pal[role][3]) end
      end
    end
  end
end
local function setLit(m, lit)
  for _, p in m:GetDescendants() do
    if p:IsA("BasePart") and p.Name == "ShojiGlow" then p.Transparency = lit and 0.6 or 1 end
  end
end

local function place(occupant, ownerPalette, x)
  local t = resolve(occupant, ownerPalette)
  local m = SS.StructurePrefabs["teahouse-1story"]:Clone(); m.Parent = demo
  recolor(m, t.palette); setLit(m, t.lit)
  m:PivotTo(CFrame.new(x, 300, 120)) -- open sky (clear of terrain)
  return m
end

place(nil, nil, 120)                 -- VACANT: dormant, unlit
place("player1", VERMILION, 180)     -- CLAIMED: owner colours, lit
local c = Vector3.new(150, 300, 120)
local cam = c + Vector3.new(0, 12, -58); local look = c + Vector3.new(0, 3, 0)
return string.format("placed vacant + claimed | cam=%.1f,%.1f,%.1f look=%.1f,%.1f,%.1f", cam.X,cam.Y,cam.Z, look.X,look.Y,look.Z)
```

- [ ] **Step 2: Screenshot and STOP for the user**

Screenshot both (front). Verify the **vacant** one reads as a dark, dormant, unlit shell and the **claimed** one as the warm owner-coloured, lit teahouse — a clear occupancy signal. Then **STOP** and ask the user to review. Do not self-judge or iterate.

- [ ] **Step 3: Clean up and commit the record**

```lua
local d = workspace:FindFirstChild("VacantStateDemo"); if d then d:Destroy() end
return "vacant-state demo scaffold removed"
```

```bash
git add roblox/tools/studio/vacantStateDemo.luau
git commit -m "chore(roblox): vacant-state visual gate (dormant vs claimed)"
```

---

## Self-review

- **Spec coverage:** `scheme.dormant` recolor → Task 1; the four `resolve` cases (vacant cliff, claimed, claimed-no-loadout, vacant valley→garden) → Task 2 tests + impl; the `Treatment` discriminated union → Task 2; the cliff visual gate (dormant vs claimed, shoji lit/unlit) → Task 3; `DORMANT` fresh-copy + owner pass-through-by-reference → Task 2 (`dormant()` helper + `t.loadout).toBe(owner)` test). Non-goals (garden applier, chōchin/noren, spawn wiring) correctly absent.
- **Placeholder scan:** none — full code in every step; Task 3's palettes/`ShojiGlow` handling are concrete.
- **Type consistency:** `Treatment {kind,loadout,lit}`/`{kind}` and `resolve(occupant, ownerLoadout, vacantForm)` consistent between impl and tests; `scheme.dormant` payload identical between Task 1, the constraint block, and Task 3's mirrored `DORMANT` palette.
