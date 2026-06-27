# ZenDojo FW11 Switchback Deck — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small posted timber viewing deck as the FarWall_11 hairpin landing — a smaller/simpler sibling of the clearing Overlook — via a new pure `SwitchbackDeck` builder synced into Studio through the existing genmodels→Rojo pipeline.

**Architecture:** A pure Luau builder module `tools/builders/SwitchbackDeck.luau` returns a deterministic `Spec.PartSpec` model (slab + girders + posts + railings + lanterns + threshold + step-downs), exactly like `Overlook.luau`. It is unit-tested headless with lune (`tests/SwitchbackDeck.spec.luau`), registered in `tools/genmodels.luau`, emitted to `assets/SwitchbackDeck.model.json`, and mapped into the workspace in `default.project.json`. Rojo live-syncs it into Studio for visual review after each unit.

**Tech Stack:** Luau, lune (headless test harness in `tests/`), Rojo (live-sync), Roblox Studio.

## Global Constraints

- **Compass (canyon-local, world dir is what the build keys off):** East = **+Z** (downcanyon / basin view), South = **+X** (open slope), North = **−Z** (cliff wall), West = **−X** (up-canyon; path enters + trail exits). Source: `docs/superpowers/specs/2026-06-27-zendojo-fw11-switchback-deck-design.md`.
- **Timber colour:** `{0.42, 0.31, 0.20}` (RGB 107/79/51, BrickColor "Earth orange") — match the Overlook on every wood part.
- **Lantern colour:** `{0.63, 0.49, 0.28}` (RGB 161/124/71), `Material = "Neon"`, with a warm `PointLight` child.
- **Materials:** slab = `"WoodPlanks"`; girders/posts/railings/steps = `"Wood"`; threshold = `"Slate"`; lantern = `"Neon"`.
- **Builders are pure & deterministic** — no terrain raycasts at build time. Post feet use the recorded terrain heights baked as constants (survey below). All parts `Anchored = true` (Spec.part default).
- **Deck footprint (world):** X (West→South edge) **124 → 136**; Z (North→East edge) **−76 → −66**; **deck top Y = 138.0**; slab thickness **0.6**.
- **Smaller/simpler than the Overlook:** single deck level, one perimeter ring of posts, railing on **East + South only**, **two** lanterns.
- **Run from `roblox/`.** Tests: `lune run tests/run`. Regenerate models: `lune run tools/genmodels`. Format/lint before commit: `stylua --check src tests tools && selene src tools` (the builder lives under `tools`).

### Recorded terrain survey (post-foot heights; raycast down, Rock/Basalt/Grass)

Grid `terrainY` at (x, z), rows x = 140→120 step −4, cols z = −82→−62 step 4:

| x\z | −82 | −78 | −74 | −70 | −66 | −62 |
|----|----|----|----|----|----|----|
|140|161.7|139.2|138.4|136.4|134.2|131.4|
|136|164.1|139.4|138.8|135.1|132.3|128.3|
|132|168.3|139.8|138.5|133.4|125.9|126.0|
|128|173.2|139.9|139.0|134.5|125.8|125.2|
|124|165.5|140.2|139.8|133.0|124.7|123.4|
|120|143.3|140.8|138.4|129.8|125.6|122.4|

Terrain under the deck ramps from ~139 at the North/cliff edge (z=−76) down to ~125 at the East/drop edge (z=−66). Posts grow toward the East edge.

### Upper-path arrival & onward heading (from survey)

- Arrival (Timber_0 of FW11→tunnel): `(131, 139, −74)`, heading **+X** (`(0.99, −0.10, 0.13)`).
- Onward FW11→FW10: heading `(−0.92, 0, 0.39)` (−X, +Z). Both legs are on the **West (−X)** side.

---

### Task 1: SwitchbackDeck module + deck slab, wired into the pipeline

**Files:**
- Create: `roblox/tools/builders/SwitchbackDeck.luau`
- Create: `roblox/tests/SwitchbackDeck.spec.luau`
- Modify: `roblox/tools/genmodels.luau` (add require + OUTPUTS entry)
- Modify: `roblox/default.project.json:32` (add `SwitchbackDeck` map next to `Overlook`)

**Interfaces:**
- Consumes: `tools/builders/Spec.luau` — `Spec.part(name, props) -> PartSpec`, `Spec.model(name, children) -> PartSpec`, `Spec.cframe(pos, rot?) -> {number}`.
- Produces: `SwitchbackDeck.build(palette: any, layout: any) -> Spec.PartSpec` — a `Model` named `SwitchbackDeck` whose direct children include a `WoodPlanks` part named `DeckSlab`. (palette/layout accepted for signature parity with sibling builders; unused for now.)

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local SwitchbackDeck = require("../tools/builders/SwitchbackDeck")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local model = SwitchbackDeck.build(ZenDojo.palette, ArenaLayout)

local function find(node, name)
	for _, c in node.children do
		if c.name == name then return c end
	end
	return nil
end

describe("SwitchbackDeck", function()
	test("builds a WoodPlanks deck slab at deck-top 138", function()
		local slab = find(model, "DeckSlab")
		expect(slab ~= nil).toBe(true)
		expect(slab.properties.Material).toBe("WoodPlanks")
		-- slab top = center.Y + thickness/2 == 138
		expect(slab.properties.CFrame[2] + slab.properties.Size[2] / 2).toBe(138)
		-- footprint 12 (X) x 10 (Z)
		expect(slab.properties.Size[1]).toBe(12)
		expect(slab.properties.Size[3]).toBe(10)
	end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `module '../tools/builders/SwitchbackDeck' not found` (or similar).

- [ ] **Step 3: Write minimal implementation**

```lua
--!strict
-- Small posted timber viewing deck at the FarWall_11 hairpin (spec 2026-06-27).
-- A smaller/simpler sibling of Overlook: single slab on a post ring, KORAN railing on
-- the East+South edges, two lanterns, a threshold + timber step-downs at the West exit.
-- Pure & deterministic; post feet are baked from the recorded terrain survey.
local Spec = require("./Spec")

local SwitchbackDeck = {}

-- ===== constants (see plan Global Constraints) =====
local DECK_TOP = 138.0
local SLAB_T = 0.6
local X0, X1 = 124, 136 -- West, South edges
local Z0, Z1 = -76, -66 -- North, East edges
local TIMBER = { 0.42, 0.31, 0.20 }

function SwitchbackDeck.build(_palette: any, _layout: any): Spec.PartSpec
	local kids: { Spec.PartSpec } = {}

	-- deck slab
	table.insert(
		kids,
		Spec.part("DeckSlab", {
			Size = { X1 - X0, SLAB_T, Z1 - Z0 },
			CFrame = Spec.cframe({ (X0 + X1) / 2, DECK_TOP - SLAB_T / 2, (Z0 + Z1) / 2 }),
			Color = TIMBER,
			Material = "WoodPlanks",
		})
	)

	return Spec.model("SwitchbackDeck", kids)
end

return SwitchbackDeck
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (SwitchbackDeck describe block green).

- [ ] **Step 5: Wire into the model pipeline**

In `roblox/tools/genmodels.luau`, add after the `Overlook` require (line ~18):
```lua
local SwitchbackDeck = require("./builders/SwitchbackDeck")
```
and in the `OUTPUTS` table, after the `Overlook` entry:
```lua
	["SwitchbackDeck"] = SwitchbackDeck.build(ZenDojo.palette, ArenaLayout),
```
In `roblox/default.project.json`, after the `Overlook` line (`:32`):
```json
                "SwitchbackDeck": { "$path": "assets/SwitchbackDeck.model.json" },
```

- [ ] **Step 6: Generate the model + format/lint**

Run: `cd roblox && lune run tools/genmodels`
Expected: prints `wrote assets/SwitchbackDeck.model.json`.
Run: `stylua --check src tests tools && selene src tools`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add roblox/tools/builders/SwitchbackDeck.luau roblox/tests/SwitchbackDeck.spec.luau \
  roblox/tools/genmodels.luau roblox/default.project.json roblox/assets/SwitchbackDeck.model.json
git commit -m "feat(roblox): FW11 switchback deck — slab + pipeline wiring"
```

- [ ] **Step 8: VISUAL REVIEW (stop for user)**

Rojo live-syncs `SwitchbackDeck` into the workspace. Ask the user to look at the deck slab floating at the FW11 hairpin (~world 130, 138, −71): right size and position, tucked toward the cliff, edge out over the drop? **Make one attempt, then stop and ask** (per `stop-and-ask-after-each-attempt`). Do not proceed until approved.

---

### Task 2: Girders, posts & X-brace

**Files:**
- Modify: `roblox/tools/builders/SwitchbackDeck.luau`
- Modify: `roblox/tests/SwitchbackDeck.spec.luau`

**Interfaces:**
- Consumes: `Spec.part`, `Spec.cframe` (as Task 1).
- Produces: direct children named `GirderX_N` / `GirderZ_N` (Wood beams), `Post_N` (Wood 1.5×1.5 columns), `Brace_N` (Wood diagonal). Post count ≥ 6.

- [ ] **Step 1: Write the failing test** (append inside the `describe` block)

```lua
	test("stands on >=6 posts with feet on recorded terrain", function()
		local function countPrefix(prefix)
			local n = 0
			for _, c in model.children do
				if (c.name :: string):sub(1, #prefix) == prefix then n += 1 end
			end
			return n
		end
		expect(countPrefix("Post_") >= 6).toBe(true)
		-- the East-edge posts (z=-66) are tall (deck floats ~12 over terrain ~125)
		local tallest = 0
		for _, c in model.children do
			if (c.name :: string):sub(1, 5) == "Post_" then
				tallest = math.max(tallest, c.properties.Size[2])
			end
		end
		expect(tallest >= 10).toBe(true)
	end)
	test("has under-slab girders", function()
		local g = 0
		for _, c in model.children do
			if (c.name :: string):sub(1, 6) == "Girder" then g += 1 end
		end
		expect(g >= 3).toBe(true)
	end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `Post_` count 0, no girders.

- [ ] **Step 3: Write minimal implementation**

In `SwitchbackDeck.luau`, add helpers above `build` and the bodies inside `build` before `return`:

```lua
-- horizontal beam between p0,p1 ({x,z}) at height y, cross-section ch(height) x cw(width)
local function barSeg(kids, name, p0, p1, y, ch, cw)
	local dx, dz = p1[1] - p0[1], p1[2] - p0[2]
	local size = if math.abs(dx) >= math.abs(dz) then { math.abs(dx), ch, cw } else { cw, ch, math.abs(dz) }
	table.insert(kids, Spec.part(name, {
		Size = size,
		CFrame = Spec.cframe({ (p0[1] + p1[1]) / 2, y, (p0[2] + p1[2]) / 2 }),
		Color = TIMBER,
		Material = "Wood",
	}))
end

-- baked post feet {x, z, terrainY} from the survey
local POSTS = {
	{ X0, Z0, 140.0 }, -- NW (West+North) short
	{ X1, Z0, 139.2 }, -- SN (South+North) short
	{ 130, Z0, 139.4 }, -- N mid short
	{ X0, Z1, 124.7 }, -- WE (West+East) tall
	{ 130, Z1, 125.8 }, -- E mid tall
	{ X1, Z1, 132.3 }, -- SE (South+East) medium
}
```

then inside `build`, after the slab insert:

```lua
	local girderTopY = DECK_TOP - SLAB_T - 0.8 -- girder section 1.6 tall, top under slab
	barSeg(kids, "GirderX_N", { X0, Z0 }, { X1, Z0 }, girderTopY, 1.6, 1.1) -- North edge
	barSeg(kids, "GirderX_E", { X0, Z1 }, { X1, Z1 }, girderTopY, 1.6, 1.1) -- East edge
	barSeg(kids, "GirderZ_M", { 130, Z0 }, { 130, Z1 }, girderTopY, 1.6, 1.1) -- mid span

	for i, p in POSTS do
		local px, pz, foot = p[1], p[2], p[3]
		local top = girderTopY - 0.8 -- top of post meets underside of girder
		local h = math.max(top - foot, 1.0)
		table.insert(kids, Spec.part(`Post_{i}`, {
			Size = { 1.5, h, 1.5 },
			CFrame = Spec.cframe({ px, foot + h / 2, pz }),
			Color = TIMBER,
			Material = "Wood",
		}))
	end

	-- one X-brace between the two tall East posts (indices 4 & 5: {X0,Z1} and {130,Z1})
	local braceY = (124.7 + 137.0) / 2
	table.insert(kids, Spec.part("Brace_1", {
		Size = { 0.6, 14, 0.6 },
		CFrame = Spec.cframe({ 127, braceY, Z1 }, Spec.yaw(0)),
		Color = TIMBER,
		Material = "Wood",
	}))
```

(The brace is a simple diagonal stand-in; refine angle visually in Step 6 if needed.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Regenerate + lint**

Run: `cd roblox && lune run tools/genmodels && stylua --check src tests tools && selene src tools`
Expected: rewrites `assets/SwitchbackDeck.model.json`, no lint errors.

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/SwitchbackDeck.luau roblox/tests/SwitchbackDeck.spec.luau roblox/assets/SwitchbackDeck.model.json
git commit -m "feat(roblox): FW11 deck — girders, posts, brace"
```

- [ ] **Step 7: VISUAL REVIEW (stop for user)**

Ask the user: does the deck now read as standing on timber legs over the notch — short posts on the cliff (North) edge, tall posts on the drop (East) edge? Adjust post feet / brace and re-sync if asked. Stop until approved.

---

### Task 3: KŌRAN railing on East + South edges only

**Files:**
- Modify: `roblox/tools/builders/SwitchbackDeck.luau`
- Modify: `roblox/tests/SwitchbackDeck.spec.luau`

**Interfaces:**
- Consumes: `barSeg`, `Spec.part`, `Spec.cframe`, constants.
- Produces: children prefixed `RailEastCap` / `RailSouthCap` (top rails), `Baluster_N` (Wood 0.34×3.2×0.34 pickets), `Newel_N` (Wood 0.62×3.7×0.62). Railing exists on East (z=Z1) and South (x=X1) edges; **none** on North/West.

- [ ] **Step 1: Write the failing test** (append in describe)

```lua
	test("railing on East and South edges only", function()
		local function has(prefix)
			for _, c in model.children do
				if (c.name :: string):sub(1, #prefix) == prefix then return true end
			end
			return false
		end
		expect(has("RailEastCap")).toBe(true)
		expect(has("RailSouthCap")).toBe(true)
		expect(has("RailNorth")).toBe(false)
		expect(has("RailWest")).toBe(false)
		-- balusters present
		local b = 0
		for _, c in model.children do
			if (c.name :: string):sub(1, 9) == "Baluster_" then b += 1 end
		end
		expect(b >= 6).toBe(true)
	end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — no RailEastCap.

- [ ] **Step 3: Write minimal implementation**

Add a railing helper above `build`:

```lua
local RAIL_H = 3.2
local BAL_STEP = 2.0

-- railing run a->b ({x,z}) on deck-top: top cap + mid rail + square balusters.
local function railRun(kids, tag, a, b, balCounter)
	local capY = DECK_TOP + RAIL_H
	local midY = DECK_TOP + RAIL_H - 1.1
	barSeg(kids, `Rail{tag}Cap`, a, b, capY, 0.3, 0.6)
	barSeg(kids, `Rail{tag}Mid`, a, b, midY, 0.2, 0.3)
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.max(2, math.floor(len / BAL_STEP))
	for i = 0, n do
		local t = i / n
		local x, z = a[1] + dx * t, a[2] + dz * t
		balCounter.v += 1
		table.insert(kids, Spec.part(`Baluster_{balCounter.v}`, {
			Size = { 0.34, RAIL_H - 0.3, 0.34 },
			CFrame = Spec.cframe({ x, DECK_TOP + (RAIL_H - 0.3) / 2, z }),
			Color = TIMBER,
			Material = "Wood",
		}))
	end
end
```

then inside `build`, before `return`:

```lua
	local balCounter = { v = 0 }
	railRun(kids, "East", { X0, Z1 }, { X1, Z1 }, balCounter) -- East edge (z = Z1)
	railRun(kids, "South", { X1, Z0 }, { X1, Z1 }, balCounter) -- South edge (x = X1)

	-- newel posts at the three corners of the L (WE, SE jut, SN)
	for i, c in { { X0, Z1 }, { X1, Z1 }, { X1, Z0 } } do
		table.insert(kids, Spec.part(`Newel_{i}`, {
			Size = { 0.62, 3.7, 0.62 },
			CFrame = Spec.cframe({ c[1], DECK_TOP + 3.7 / 2, c[2] }),
			Color = TIMBER,
			Material = "Wood",
		}))
	end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Regenerate + lint**

Run: `cd roblox && lune run tools/genmodels && stylua --check src tests tools && selene src tools`

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/SwitchbackDeck.luau roblox/tests/SwitchbackDeck.spec.luau roblox/assets/SwitchbackDeck.model.json
git commit -m "feat(roblox): FW11 deck — KORAN railing on East+South edges"
```

- [ ] **Step 7: VISUAL REVIEW (stop for user)**

Ask: railing reads right on the two open-air (East/downcanyon + South) edges, open on the cliff (North) and path (West) edges, ~3.2 high with balusters? Stop until approved.

---

### Task 4: Two lanterns

**Files:**
- Modify: `roblox/tools/builders/SwitchbackDeck.luau`
- Modify: `roblox/tests/SwitchbackDeck.spec.luau`

**Interfaces:**
- Consumes: `Spec.part`, `Spec.cframe`, constants.
- Produces: two children named `Lantern_1`, `Lantern_2` (`Neon`, 1×1.5×1, colour `{0.63,0.49,0.28}`), each with a `PointLight` child.

- [ ] **Step 1: Write the failing test** (append in describe)

```lua
	test("carries two warm lanterns with PointLights at the rail-run ends", function()
		local lit = 0
		for _, c in model.children do
			if c.children then
				for _, gc in c.children do
					if gc.className == "PointLight" then lit += 1 end
				end
			end
		end
		expect(lit).toBe(2)
	end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `lit` is 0.

- [ ] **Step 3: Write minimal implementation**

Add a constant near the top: `local LANTERN = { 0.63, 0.49, 0.28 }`.
Inside `build`, before `return`, add the two lanterns at the **ends of the railed L-run** — East rail's West end `(X0, Z1)` and South rail's North end `(X1, Z0)`:

```lua
	for i, c in { { X0, Z1 }, { X1, Z0 } } do
		table.insert(kids, {
			name = `Lantern_{i}`,
			className = "Part",
			properties = {
				Anchored = true,
				Size = { 1, 1.5, 1 },
				CFrame = Spec.cframe({ c[1], DECK_TOP + 3.7 + 0.75, c[2] }), -- atop the newel
				Color = LANTERN,
				Material = "Neon",
			},
			children = {
				{
					name = `Lantern_{i}Light`,
					className = "PointLight",
					properties = { Color = LANTERN, Brightness = 1.2, Range = 14 },
				},
			},
		})
	end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (`lit == 2`).

- [ ] **Step 5: Regenerate + lint**

Run: `cd roblox && lune run tools/genmodels && stylua --check src tests tools && selene src tools`

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/SwitchbackDeck.luau roblox/tests/SwitchbackDeck.spec.luau roblox/assets/SwitchbackDeck.model.json
git commit -m "feat(roblox): FW11 deck — two lantern-newels"
```

- [ ] **Step 7: VISUAL REVIEW (stop for user)**

Ask: two warm lanterns flanking the view, glow reads at dusk? Stop until approved.

---

### Task 5: Threshold + timber step-downs (descent handoff)

**Files:**
- Modify: `roblox/tools/builders/SwitchbackDeck.luau`
- Modify: `roblox/tests/SwitchbackDeck.spec.luau`

**Interfaces:**
- Consumes: `Spec.part`, `Spec.cframe`, constants.
- Produces: child `Threshold` (`Slate` flat slab at the West entry), and children `StepDown_1..3` (Wood treads descending off the West edge toward FW10), each lower in Y than the last. Exposes `SwitchbackDeck.COBBLE_START : {number}` — the world point where the cobble traverse should begin (consumed by the later, separate FW11→FW10 path plan).

- [ ] **Step 1: Write the failing test** (append in describe)

```lua
	test("threshold at the West entry and descending timber step-downs", function()
		local function find(name)
			for _, c in model.children do
				if c.name == name then return c end
			end
			return nil
		end
		expect(find("Threshold") ~= nil).toBe(true)
		expect(find("Threshold").properties.Material).toBe("Slate")
		-- three steps, strictly descending in Y
		local s1, s2, s3 = find("StepDown_1"), find("StepDown_2"), find("StepDown_3")
		expect(s1 ~= nil and s2 ~= nil and s3 ~= nil).toBe(true)
		expect(s1.properties.CFrame[2] > s2.properties.CFrame[2]).toBe(true)
		expect(s2.properties.CFrame[2] > s3.properties.CFrame[2]).toBe(true)
		-- the cobble-path handoff point is published and sits below deck-top
		expect(SwitchbackDeck.COBBLE_START[2] < 138).toBe(true)
	end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — no Threshold / COBBLE_START nil.

- [ ] **Step 3: Write minimal implementation**

Near the top of the module add the published handoff point (the steps walk −X and +Z off the West edge):

```lua
-- where the cobble traverse to FW10 begins (after the timber step-downs)
SwitchbackDeck.COBBLE_START = { 121.0, 135.0, -69.0 }
```

Inside `build`, before `return`:

```lua
	-- flat Slate threshold where the upper cobble path meets the deck (West entry, north half)
	table.insert(kids, Spec.part("Threshold", {
		Size = { 2.5, 0.3, 4 },
		CFrame = Spec.cframe({ X0 + 0.5, DECK_TOP - 0.15, -73 }),
		Color = { 0.36, 0.38, 0.40 },
		Material = "Slate",
	}))

	-- three timber step-downs off the West edge (south half), descending toward COBBLE_START
	local stepStart = { X0, DECK_TOP, -69 } -- {x, topY, z}
	local cs = SwitchbackDeck.COBBLE_START
	for i = 1, 3 do
		local t = i / 3
		local x = stepStart[1] + (cs[1] - stepStart[1]) * t
		local y = stepStart[2] + (cs[2] - stepStart[2]) * t
		local z = stepStart[3] + (cs[3] - stepStart[3]) * t
		table.insert(kids, Spec.part(`StepDown_{i}`, {
			Size = { 5, 0.5, 2.4 },
			CFrame = Spec.cframe({ x, y, z }),
			Color = TIMBER,
			Material = "Wood",
		}))
	end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Regenerate + lint**

Run: `cd roblox && lune run tools/genmodels && stylua --check src tests tools && selene src tools`

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/SwitchbackDeck.luau roblox/tests/SwitchbackDeck.spec.luau roblox/assets/SwitchbackDeck.model.json
git commit -m "feat(roblox): FW11 deck — threshold + timber step-down handoff"
```

- [ ] **Step 7: VISUAL REVIEW (stop for user)**

Ask: the path lands cleanly on the deck at the threshold; after the 180° turn the timber steps shed height off the West edge toward where the cobble traverse will pick up (COBBLE_START ≈ 121, 135, −69)? Stop until approved. Record any final coordinate tweaks back into the design spec.

---

## Self-Review

**1. Spec coverage:**
- Concept/siting (posted deck, hairpin, ~12×10, top 138) → Tasks 1–2. ✓
- Structure & materials (slab WoodPlanks, girders, posts, X-brace, Overlook colours) → Tasks 1–2. ✓
- Railings East+South only, open North+West → Task 3. ✓
- Two lanterns at L-run ends → Task 4. ✓
- Hairpin flow: threshold entry + wooden step-down → cobble handoff → Task 5. ✓
- Compass mapping → Global Constraints. ✓
- Out of scope (cobble traverse, ishigaki, greening) → not planned here; COBBLE_START published for the next plan. ✓

**2. Placeholder scan:** No TBD/TODO; every code step has complete code. The X-brace (Task 2) is a labelled simple stand-in with a visual-refine note — acceptable (cosmetic, gated by review), not a placeholder for required logic.

**3. Type consistency:** `SwitchbackDeck.build(palette, layout)` signature matches genmodels call and all tests. `COBBLE_START` defined in Task 5, consumed only in its own test. Child-name prefixes used in tests (`Post_`, `Girder`, `RailEastCap`, `Baluster_`, `Newel_`, `Lantern_`, `Threshold`, `StepDown_`) all match the implementation names. Lantern nodes use raw table form (not `Spec.part`) to attach a `PointLight` child — consistent with how `Spec.model` children are consumed by `genmodels.toRojo`.

## Notes for the implementer

- This builds the deck **only**. The FW11→FW10 cobble traverse and any ishigaki facing are separate, later plans; this plan publishes `SwitchbackDeck.COBBLE_START` as the handoff point for that work.
- `palette`/`layout` params are accepted for parity with sibling builders but unused; do not delete them (genmodels passes them).
- If lune can't resolve `ZenDojo.palette` in a test, mirror exactly what `tests/Overlook.spec.luau` imports — it's the canonical example.
