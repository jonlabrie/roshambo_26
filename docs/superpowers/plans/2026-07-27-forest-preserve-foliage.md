# Forest Preserve Foliage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plant the western-canyon forest preserve — zone-painted, rule-scattered, sugi-dominant, with a culled/re-dressed waterline and an optional night-mist layer — per `docs/superpowers/specs/2026-07-27-forest-preserve-foliage-design.md`.

**Architecture:** A pure Lune-tested planner (`ZoneScatter`) turns zone descriptions + terrain samples + recipes into deterministic placements; a thin Studio shell reads user-draggable zone Parts, samples terrain, and bakes clones from `ServerStorage.FoliageKit`. Interactive Studio/gate tasks alternate with code tasks. Mist ships last as a cuttable layer with a fireflies-ready ambience socket.

**Tech Stack:** Luau (strict) + bespoke Lune test harness (`lune run tests/run` from `roblox/`), Roblox Studio MCP (`execute_luau`, datamodel Edit), headless Blender (`export_tree.py`), stylua + selene (`stylua --check src tests tools && selene src tools` — selene fails on warnings).

## Global Constraints

- Target device: Samsung Galaxy A13. No mass double-sided foliage; SugiMid ships single-sided.
- All scatter deterministic: integer LCG only — **no `math.random`, no `Date.now`/`os.time`** in planners.
- Per-clone engine flags (scatter standard): `RenderFidelity = Automatic`; `CastShadow`, `CanQuery`, `CanTouch` = false. Exception: Mid/hero-grade **trunk** parts keep `CanCollide = true`; foliage parts and wall blobs fully non-collidable.
- Place geometry is place-only — never `rojo build`; ship by saving/publishing the place. Committed files here are code/docs only.
- Every visual step: ONE attempt, then stop and ask the user to look (standing rule).
- DoubleSided doctrine: dense/dark card foliage true; pale or blob-canopy false.
- Zone volumes live in `Workspace.Sandbox.FoliageZones`; bakes go to `Workspace.CanyonWorld.Foliage.Preserve.<ZoneName>`.

---

### Task 1: Waterline species survey + tropical cull

Interactive Studio task (no repo code). Produces the cull decision and executes it.

**Files:** none committed (MCP `execute_luau` snippets only).

**Interfaces:**
- Produces: a culled waterline; a species inventory list the user has seen and approved.

- [ ] **Step 1: Inventory the existing water-margin scatter.** Run via MCP (`datamodel_type: "Edit"`):

```lua
-- Survey every foliage-ish model near water level, grouped by name, with counts + a sample path.
local counts, sample = {}, {}
local function visit(root)
  for _, d in ipairs(root:GetDescendants()) do
    if d:IsA("Model") and d:FindFirstChildWhichIsA("MeshPart", true) then
      local piv = d:GetPivot().Position
      if piv.Y < 200 then -- valley floor band; walls excluded
        counts[d.Name] = (counts[d.Name] or 0) + 1
        sample[d.Name] = sample[d.Name] or d:GetFullName()
      end
    end
  end
end
visit(workspace.CanyonWorld)
local out = {}
for name, n in pairs(counts) do
  out[#out + 1] = { name = name, count = n, sample = sample[name] }
end
table.sort(out, function(a, b) return a.count > b.count end)
return game:GetService("HttpService"):JSONEncode(out)
```

- [ ] **Step 2: Identify tropical-reading species.** Cross-reference the inventory against the visible palm/cycad clusters (capture 1–2 close screenshots of representative clumps via `screen_capture` and match names by clicking/Selection if ambiguous).
- [ ] **Step 3: USER GATE — present the cull list.** Show the user: species name, count, screenshot. Wait for explicit approval of exactly which names die.
- [ ] **Step 4: Execute the approved cull.** For each approved name:

```lua
local doomed = { "<ApprovedName1>", "<ApprovedName2>" } -- literal list from the gate
local n = 0
for _, d in ipairs(workspace.CanyonWorld:GetDescendants()) do
  if d:IsA("Model") and table.find(doomed, d.Name) then
    d:Destroy(); n += 1
  end
end
return "culled " .. n .. " models"
```

- [ ] **Step 5: Capture before/after at two pool sites; user confirms; user saves the place.**

---

### Task 2: SugiMid exports (3 variants) + import + grade-lineup gate

**Files:**
- No repo changes (uses committed `roblox/tools/blender/export_tree.py` as-is; outputs land in `~/Desktop/Roshambo Reference/sugi/reduced/sugimid_{a,b,c}/`).

**Interfaces:**
- Consumes: vendor FBX `~/Desktop/Roshambo Reference/sugi/BC_PM_P02_japanese_cedar.fbx`, objects `_03` (26 → 22 studs), `_01` (25.8 → 26 studs), `_02` (30.6 → 30 studs).
- Produces: `ServerStorage.FoliageKit.SugiMidA/B/C` (Models, grounded in the template row, single-sided, atlas-shared) — the species names Task 3's recipes reference.

- [ ] **Step 1: Export three variants headless.** Budgets 10k foliage / 4k wood, single mesh each side (`FOLIAGE_PARTS=1 TRUNK_PARTS=1`), spray scale 1.9 (higher than the hero 1.6 because thinning is deeper), snap/relax/orphan off, smart wood on:

```bash
BL=/Applications/Blender.app/Contents/MacOS/Blender
SRC=~/Desktop/"Roshambo Reference"/sugi/BC_PM_P02_japanese_cedar.fbx
T=roblox/tools/blender/export_tree.py
"$BL" --background --python "$T" -- "$SRC" BC_PM_P02_japanese_cedar_03 leaves 10000 4000 22 \
  ~/Desktop/"Roshambo Reference"/sugi/reduced/sugimid_a/SugiMidA.fbx 1.9 0.0 1 0.0 0.0 1 1
"$BL" --background --python "$T" -- "$SRC" BC_PM_P02_japanese_cedar_01 leaves 10000 4000 26 \
  ~/Desktop/"Roshambo Reference"/sugi/reduced/sugimid_b/SugiMidB.fbx 1.9 0.0 1 0.0 0.0 1 1
"$BL" --background --python "$T" -- "$SRC" BC_PM_P02_japanese_cedar_02 leaves 10000 4000 30 \
  ~/Desktop/"Roshambo Reference"/sugi/reduced/sugimid_c/SugiMidC.fbx 1.9 0.0 1 0.0 0.0 1 1
```

Expected per run: `RESULT foliage_tris≈10k trunk_tris≈4k`, one `_leaves.png` beside each FBX.
- [ ] **Step 2: USER imports the three FBXs** (File → Import 3D, **Anchored** + **Ignore Vertex Colors** ticked; each file is a single import, two meshes).
- [ ] **Step 3: Post-import script** (MCP, Edit): for each imported `SugiMid?` model — foliage part: `SurfaceAppearance.AlphaMode = Transparency`, `ColorMap = "rbxassetid://93931429083373"` (the shared sugi atlas), `DoubleSided = false`; trunk part: `SurfaceAppearance` ColorMap `rbxassetid://109397671791816`; then parent to `ServerStorage.FoliageKit`, ground in the template row (raycast, pivot at trunk base — same convention as the 2026-07-26 re-ground).
- [ ] **Step 4: Grade-lineup — stamp temporary clones** of SugiMidA/B/C in `Workspace.Sandbox` beside a hero sugi clone and a `ConiferA` clone on open terrain; capture; **USER GATE**: judge canopy density (single-sided!) and family resemblance. If thin: re-export with foliage budget 12000 and/or spray 2.1 — one iteration per gate pass.
- [ ] **Step 5: Delete lineup clones; user saves the place.**

---

### Task 3: `foliageZoneRecipes.luau` (data module) + tests

**Files:**
- Create: `roblox/tools/studio/foliageZoneRecipes.luau`
- Test: `roblox/tests/FoliageZoneRecipes.spec.luau`

**Interfaces:**
- Produces: `Recipes: { [string]: Recipe }` where `Recipe = { pool: { { name: string, weight: number } }, spacingMin: number, spacingMax: number, clumpChance: number, clumpSize: number, maxSteep: number, waterMargin: number, scaleJitter: number, heightScale: number?, innerClear: number? }`. Recipe keys: `PreserveCore`, `WallFringe`, `WaterMargin`, `FutureClearing`. (`KeepOut` is not a recipe — the planner treats it structurally.)

- [ ] **Step 1: Write the failing test** `roblox/tests/FoliageZoneRecipes.spec.luau`:

```lua
local harness = require("./harness")
local Recipes = require("../tools/studio/foliageZoneRecipes")

return harness.suite("FoliageZoneRecipes", function(t)
  t.test("all four recipes exist with positive spacing bands", function()
    for _, key in { "PreserveCore", "WallFringe", "WaterMargin", "FutureClearing" } do
      local r = Recipes[key]
      t.ok(r ~= nil, key .. " exists")
      t.ok(r.spacingMin > 0 and r.spacingMax >= r.spacingMin, key .. " spacing band sane")
      t.ok(#r.pool > 0, key .. " has species")
      for _, s in r.pool do
        t.ok(s.weight > 0, key .. "/" .. s.name .. " weight positive")
      end
    end
  end)
  t.test("PreserveCore is sugi-dominant and clump-capable", function()
    local core = Recipes.PreserveCore
    local sugi = 0
    local total = 0
    for _, s in core.pool do
      total += s.weight
      if s.name:find("SugiMid") then sugi += s.weight end
    end
    t.ok(sugi / total >= 0.7, "sugi >= 70% of core pool")
    t.ok(core.clumpChance > 0 and core.clumpSize >= 2, "clumping configured")
  end)
  t.test("FutureClearing reserves its inner half", function()
    t.eq(Recipes.FutureClearing.innerClear, 0.5)
  end)
end)
```

(Match the harness's actual API — read `roblox/tests/harness.luau` and one existing spec, e.g. `CanopyScatter.spec.luau`, and adapt `suite/test/ok/eq` names accordingly before writing.)
- [ ] **Step 2: Run to verify failure.** `cd roblox && lune run tests/run` → new spec fails (module missing).
- [ ] **Step 3: Implement the module** with the spec's palette table:

```lua
--!strict
-- Zone recipes for the forest preserve (spec 2026-07-27-forest-preserve-foliage-design).
-- Data only: the ZoneScatter planner interprets these. Tune values live at the gates.
export type Species = { name: string, weight: number }
export type Recipe = {
  pool: { Species },
  spacingMin: number, spacingMax: number,
  clumpChance: number, clumpSize: number,
  maxSteep: number, waterMargin: number,
  scaleJitter: number,
  heightScale: number?,
  innerClear: number?,
}
local Recipes: { [string]: Recipe } = {
  PreserveCore = {
    pool = {
      { name = "SugiMidA", weight = 25 }, { name = "SugiMidB", weight = 25 },
      { name = "SugiMidC", weight = 25 }, { name = "FirM", weight = 15 },
      { name = "CedarS", weight = 10 },
    },
    spacingMin = 14, spacingMax = 22, clumpChance = 0.18, clumpSize = 3,
    maxSteep = 0.55, waterMargin = 4, scaleJitter = 0.15,
  },
  WallFringe = {
    pool = {
      { name = "ConiferA", weight = 30 }, { name = "ConiferB", weight = 30 },
      { name = "ConiferC", weight = 25 }, { name = "CedarM", weight = 15 },
    },
    spacingMin = 10, spacingMax = 16, clumpChance = 0, clumpSize = 0,
    maxSteep = 0.9, waterMargin = 4, scaleJitter = 0.2, heightScale = 1.15,
  },
  WaterMargin = {
    pool = {
      { name = "MuhlyGrass", weight = 50 }, { name = "ReedClump", weight = 30 },
      { name = "FernClump", weight = 20 },
    },
    spacingMin = 4, spacingMax = 8, clumpChance = 0.3, clumpSize = 3,
    maxSteep = 0.7, waterMargin = 0, scaleJitter = 0.25,
  },
  FutureClearing = {
    pool = {
      { name = "SugiMidA", weight = 25 }, { name = "SugiMidB", weight = 25 },
      { name = "SugiMidC", weight = 25 }, { name = "FirM", weight = 15 },
      { name = "CedarS", weight = 10 },
    },
    spacingMin = 20, spacingMax = 30, clumpChance = 0, clumpSize = 0,
    maxSteep = 0.55, waterMargin = 4, scaleJitter = 0.15, innerClear = 0.5,
  },
}
return Recipes
```

(`MuhlyGrass`/`ReedClump`/`FernClump` are FoliageKit template names to be satisfied in Task 6; the recipes module doesn't resolve assets.)
- [ ] **Step 4: Run tests → pass.** `cd roblox && lune run tests/run`
- [ ] **Step 5: Lint + commit.** `cd roblox && stylua --check src tests tools && selene src tools`; then `git add roblox/tools/studio/foliageZoneRecipes.luau roblox/tests/FoliageZoneRecipes.spec.luau && git commit -m "feat(roblox): forest-preserve zone recipes"`

---

### Task 4: `ZoneScatter.luau` pure planner + tests

**Files:**
- Create: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau`

**Interfaces:**
- Consumes: `Recipe` shape from Task 3 (passed in — no `require` of the recipes module inside the planner; DI keeps it pure and testable with synthetic recipes).
- Produces:

```lua
export type Zone = {
  name: string,            -- bake folder name
  shape: "rect" | "circle",
  bounds: { number },      -- rect: {x1,z1,x2,z2}; circle: {cx,cz,r}
  recipe: string,          -- key into recipes table, or "KeepOut"
  densityScale: number,
  seed: number,
  mist: boolean?,
  still: boolean?,
}
export type Placement = { x: number, z: number, y: number, species: string, yaw: number, scale: number, zone: string }
export type MistAnchor = { x: number, z: number, y: number, zone: string }
ZoneScatter.plan(zones: { Zone }, samples: { CanopyScatter.Sample }, recipes: { [string]: Recipe })
  -> ({ Placement }, { MistAnchor })
```

Reuses `Sample` from CanopyScatter (`{ x, z, y, steep }`) and the same LCG constants.

- [ ] **Step 1: Write failing tests** `roblox/tests/ZoneScatter.spec.luau` (adapt to the real harness API as in Task 3):

```lua
local harness = require("./harness")
local ZoneScatter = require("../tools/builders/ZoneScatter")

-- helpers: a flat 100x100 grid of samples, 4-stud pitch
local function flatSamples()
  local s = {}
  for x = 0, 100, 4 do
    for z = 0, 100, 4 do
      s[#s + 1] = { x = x, z = z, y = 50, steep = 0 }
    end
  end
  return s
end
local CORE = {
  pool = { { name = "SugiMidA", weight = 1 } },
  spacingMin = 10, spacingMax = 14, clumpChance = 0, clumpSize = 0,
  maxSteep = 0.6, waterMargin = 0, scaleJitter = 0.1,
}
local recipes = { PreserveCore = CORE, FutureClearing = (function()
  local r = table.clone(CORE); r.innerClear = 0.5; return r
end)() }

return harness.suite("ZoneScatter", function(t)
  t.test("deterministic: same input twice = identical output", function()
    local zones = { { name = "A", shape = "rect", bounds = { 0, 0, 100, 100 },
      recipe = "PreserveCore", densityScale = 1, seed = 7 } }
    local a = ZoneScatter.plan(zones, flatSamples(), recipes)
    local b = ZoneScatter.plan(zones, flatSamples(), recipes)
    t.eq(#a, #b)
    for i, p in a do
      t.eq(p.x, b[i].x); t.eq(p.species, b[i].species); t.eq(p.yaw, b[i].yaw)
    end
  end)
  t.test("spacing respected", function()
    local zones = { { name = "A", shape = "rect", bounds = { 0, 0, 100, 100 },
      recipe = "PreserveCore", densityScale = 1, seed = 7 } }
    local out = ZoneScatter.plan(zones, flatSamples(), recipes)
    t.ok(#out > 5, "planted something")
    for i = 1, #out do
      for j = i + 1, #out do
        local dx, dz = out[i].x - out[j].x, out[i].z - out[j].z
        t.ok(dx * dx + dz * dz >= 10 * 10 - 1e-6, "min spacing held")
      end
    end
  end)
  t.test("KeepOut wins over overlapping zone", function()
    local zones = {
      { name = "A", shape = "rect", bounds = { 0, 0, 100, 100 },
        recipe = "PreserveCore", densityScale = 1, seed = 7 },
      { name = "KO", shape = "circle", bounds = { 50, 50, 30 },
        recipe = "KeepOut", densityScale = 1, seed = 1 },
    }
    local out = ZoneScatter.plan(zones, flatSamples(), recipes)
    for _, p in out do
      local dx, dz = p.x - 50, p.z - 50
      t.ok(dx * dx + dz * dz > 30 * 30, "nothing inside keep-out")
    end
  end)
  t.test("FutureClearing inner half is empty", function()
    local zones = { { name = "C", shape = "circle", bounds = { 50, 50, 40 },
      recipe = "FutureClearing", densityScale = 1, seed = 7 } }
    local out = ZoneScatter.plan(zones, flatSamples(), recipes)
    for _, p in out do
      local dx, dz = p.x - 50, p.z - 50
      t.ok(dx * dx + dz * dz >= 20 * 20, "inner 50% radius clear")
    end
  end)
  t.test("mist anchors only from mist zones, wide-spaced", function()
    local zones = { { name = "A", shape = "rect", bounds = { 0, 0, 100, 100 },
      recipe = "PreserveCore", densityScale = 1, seed = 7, mist = true } }
    local _, anchors = ZoneScatter.plan(zones, flatSamples(), recipes)
    t.ok(#anchors >= 2, "anchors produced")
    for i = 1, #anchors do
      for j = i + 1, #anchors do
        local dx, dz = anchors[i].x - anchors[j].x, anchors[i].z - anchors[j].z
        t.ok(dx * dx + dz * dz >= 30 * 30 - 1e-6, "30-stud mist spacing")
      end
    end
  end)
  t.test("clumps place clumpSize trees inside spacingMin when triggered", function()
    local clumpy = table.clone(CORE); clumpy.clumpChance = 1; clumpy.clumpSize = 3
    local zones = { { name = "A", shape = "rect", bounds = { 0, 0, 100, 100 },
      recipe = "Clumpy", densityScale = 1, seed = 7 } }
    local out = ZoneScatter.plan(zones, flatSamples(), { Clumpy = clumpy })
    -- with clumpChance=1 every accepted dart becomes a clump: count neighbors within 8
    local clumped = 0
    for i = 1, #out do
      for j = 1, #out do
        if i ~= j then
          local dx, dz = out[i].x - out[j].x, out[i].z - out[j].z
          if dx * dx + dz * dz < 8 * 8 then clumped += 1 break end
        end
      end
    end
    t.ok(clumped > #out / 2, "majority of trees have a close clump neighbor")
  end)
end)
```

- [ ] **Step 2: Run to verify failure.** `cd roblox && lune run tests/run` → module missing.
- [ ] **Step 3: Implement `ZoneScatter.luau`.** Core algorithm (mirror CanopyScatter idioms — strict mode, LCG `(1103515245 * s + 12345) % 2147483648`, sorted sample iteration):
  - For each sample (sorted by x then z): find the highest-priority zone containing it (`KeepOut` recipe → excluded outright; otherwise last-matching non-KeepOut zone wins, so users can layer patches over big zones).
  - Recipe lookup; skip if `steep > maxSteep`; skip if inside `innerClear` fraction of the zone (circle: radius fraction; rect: inset fraction of half-extents).
  - Density: accept with probability `densityScale` (LCG roll) before spacing, so `DensityScale` thins uniformly.
  - Spacing: greedy min-distance against accepted placements using `spacingMin + roll * (spacingMax - spacingMin)`.
  - Clump: after accepting a tree, roll `clumpChance`; on success place up to `clumpSize - 1` extra trees at radius 4–7 studs, same species, snapped to the nearest sample's y, ignoring min-spacing *within the clump* but still honoring zone membership and keep-outs.
  - Species/yaw/scale rolls exactly as CanopyScatter (`pickSpecies` by weight; yaw `0..2π`; `scale = 1 ± scaleJitter`, times `heightScale` if set).
  - Mist: independent second pass per `mist == true` zone — dart-throw anchors at fixed 30-stud min spacing from that zone's seed + 500000 offset; y from nearest sample.
  - Returns `(placements, mistAnchors)`; both carry `zone = zone.name`.
- [ ] **Step 4: Run tests → all pass.** `cd roblox && lune run tests/run`
- [ ] **Step 5: Lint + commit.** stylua/selene as Task 3; `git commit -m "feat(roblox): ZoneScatter pure planner for the forest preserve"`

---

### Task 5: Studio shell `scatterPreserve.luau`

**Files:**
- Create: `roblox/tools/studio/scatterPreserve.luau`

**Interfaces:**
- Consumes: `ZoneScatter.plan` (Task 4), `foliageZoneRecipes` (Task 3), zone Parts in `Workspace.Sandbox.FoliageZones` (attributes: `Recipe: string`, `DensityScale: number?`, `Seed: number?`, `Mist: boolean?`, `Still: boolean?`), templates in `ServerStorage.FoliageKit`.
- Produces: baked clones under `Workspace.CanyonWorld.Foliage.Preserve.<ZoneName>` and anchors under `...Preserve.Mist`. Run via MCP `execute_luau` or command bar; `MODE` constant at top: `"bake"`, `"wipe"`, `"plan"` (plan = counts only, no stamping); `ZONES` filter list (empty = all).

- [ ] **Step 1: Write the shell.** Structure (single file, ~150 lines):
  - Read every BasePart child of `Workspace.Sandbox.FoliageZones`; map to `ZoneScatter.Zone`: name from Part name, shape from `Shape == Enum.PartType.Cylinder` (circle, r = Size.X/2) vs block (rect from world-axis footprint), recipe/density/mist/still/seed from attributes (seed default: stable hash of the part name — sum of byte values, NOT random).
  - Sample terrain on a 4-stud grid across the union of zone bounds: `workspace:Raycast` straight down from y=400, terrain-only filter; reject water material hits; `steep` from `hit.Normal` (`steep = 1 - normal.Y`).
  - Call `ZoneScatter.plan(zones, samples, Recipes)`.
  - `"plan"`: print per-zone counts and return.
  - `"wipe"`: destroy `Preserve.<name>` folders for zones in the filter (and `Preserve.Mist` if any wiped zone had mist).
  - `"bake"`: wipe first, then for each placement clone `FoliageKit[species]`, `PivotTo` at `(x, y, z)` with yaw, `ScaleTo(scale)`, apply engine flags (Global Constraints; trunk-collide only for names matching `SugiMid` — the mid grade), parent under the zone folder. Mist anchors = invisible anchored 1-stud parts named `MistAnchor` in `Preserve.Mist`.
  - Missing species template → collect and print ONE warning line per species, skip those placements (planner counts still reported), never error mid-bake.
- [ ] **Step 2: Sanity-run `MODE="plan"`** in Studio via MCP against 1 temporary test zone part; confirm counts print and no stamping occurs. Delete the test zone.
- [ ] **Step 3: Lint + commit.** stylua/selene; `git commit -m "feat(roblox): scatterPreserve Studio shell (zone bake/wipe/plan)"`

---

### Task 6: Margin flora templates (muhly export + reed/fern/lily inventory)

**Files:** none committed (Blender CLI + Studio work). Template names must match Task 3's recipes.

**Interfaces:**
- Produces: `ServerStorage.FoliageKit.MuhlyGrass`, `.ReedClump`, `.FernClump` (Models, grounded in the template row). Lilies only if sourced (`.LilyPad`, and `WaterMargin` zones with `Still = true` get them in a follow-up recipe tweak — cut from v1 if unsourced).

- [ ] **Step 1: Export muhly grass** from `~/Desktop/Roshambo Reference/` (free set already on disk) via `export_tree.py` if it's card-based (budget 2000/500, height 2.5), else import its FBX directly if already low-poly. Judge tri count ≤ 3k.
- [ ] **Step 2: Inventory ferns/reeds/lilies.** Ferns exist in the current margin scatter (survivors of the Task 1 cull) — promote one surviving fern clump model into `FoliageKit.FernClump` (clone, ground, rename). Reeds/lilies: check `~/Desktop/Roshambo Reference/` and the kit; if absent, search toolbox (any import gets the **backdoor scan** — attr-hidden `require(assetId)` check — before parenting into the place) or mark CUT for v1 and remove `ReedClump` from the `WaterMargin` recipe pool (weights renormalize implicitly).
- [ ] **Step 3: Post-import hygiene** for each new template: single-sided unless dense/dark cards, engine flags left to bake time, grounded in the template row, pivot at base.
- [ ] **Step 4: USER GATE — one clone of each margin species stamped at a pool edge; capture; approve or adjust.** Delete gate clones after.

---

### Task 7: Zone painting + first bake (PreserveCore, mid-canyon)

**Files:** none committed (place-only zone parts + bakes).

**Interfaces:**
- Consumes: everything above.
- Produces: approved PreserveCore look; tuned recipe values (committed as edits to `foliageZoneRecipes.luau` if changed).

- [ ] **Step 1: Stamp draft zones** via MCP: create `Workspace.Sandbox.FoliageZones` with translucent color-coded parts — first draft covering the western canyon: 1 big `PreserveCore` rect mid-valley; `WallFringe` strips along both walls; `WaterMargin` ribbons over the pool chain; 2 `FutureClearing` circles (upper pool bank = future dock; lower-falls flat = future clearing); `KeepOut` volumes over every path, build, spawn sightline, and the water itself. Color code: green core, dark-green fringe, blue margin, yellow clearings, red keep-outs; all `Transparency = 0.7`, `Anchored = true`, `CanCollide = false`.
- [ ] **Step 2: USER GATE — zone review.** User drags/resizes/duplicates/deletes zone parts in Studio (minutes). Wait for go.
- [ ] **Step 3: First bake, one zone:** `MODE="bake"`, `ZONES={"<the core zone name>"}`. Capture 3 player-height views + 1 overview.
- [ ] **Step 4: USER GATE — walk the woods.** Knob feedback (spacing/density/mix/clumps) → edit `foliageZoneRecipes.luau` values → wipe + re-bake. One iteration per look. When approved, commit any recipe value changes: `git commit -m "tune(roblox): PreserveCore recipe values from first-bake gate"`

---

### Task 8: Full bake + A13 re-bench + curation

**Files:** none committed.

- [ ] **Step 1: Full bake** all zones (`ZONES = {}`). Capture overview + two walk-throughs.
- [ ] **Step 2: USER GATE — desktop walk-around.** Fix egregious placements by zone re-shape + re-bake while still cheap.
- [ ] **Step 3: USER publishes; A13 re-bench** standing in the preserve: client memory (target ≤ the arena's ~1 GB reading), frame feel, canopy read at mobile LOD. If over budget: first lever `DensityScale` on WallFringe, second lever SugiMid count via PreserveCore spacing +2. Re-bench after any lever.
- [ ] **Step 4: Hand-curation pass (bakes are now FINAL — no more re-runs):** place 2–3 momiji jewels (MapleRed/MapleGold clones by hand at pool bank + falls overlook), delete/nudge offenders as the user directs, thin anything crowding the future dock/clearing reservations.
- [ ] **Step 5: USER saves the place.**

---

### Task 9: Ambience scheduler + MistController + mist bake

**Files:**
- Create: `roblox/src/shared/PreserveAmbience.luau`
- Create: `roblox/src/client/MistController.client.luau`
- Test: `roblox/tests/PreserveAmbience.spec.luau`

**Interfaces:**
- Consumes: `EventBus` (`"DayNight"` event `{ t, nightFactor, phase }`), `ReplicatedStorage.DayNightConfig` attributes (`CycleEpoch`, `CycleLength`), mist anchors in `Workspace.CanyonWorld.Foliage.Preserve.Mist`.
- Produces: `PreserveAmbience.moodAt(nightIndex: number) -> { mist: number, fireflies: number }` — deterministic per absolute night count since epoch; mist and fireflies alternate (fireflies value is produced now, consumed by the future FireflyController — the socket). `MistController` drives emitter `Rate`/`Transparency` from `nightFactor * mood.mist`, with `MistDensity`/`MistNightBoost` live-tune attributes on `Workspace.RoshamboStage`.

- [ ] **Step 1: Write failing test** `roblox/tests/PreserveAmbience.spec.luau`:

```lua
local harness = require("./harness")
local Ambience = require("../src/shared/PreserveAmbience")

return harness.suite("PreserveAmbience", function(t)
  t.test("deterministic and alternating", function()
    local sawMist, sawFly = false, false
    for night = 0, 9 do
      local a = Ambience.moodAt(night)
      local b = Ambience.moodAt(night)
      t.eq(a.mist, b.mist)
      t.eq(a.fireflies, b.fireflies)
      t.ok(a.mist >= 0 and a.mist <= 1, "mist in range")
      t.ok(a.fireflies >= 0 and a.fireflies <= 1, "fireflies in range")
      t.ok(a.mist + a.fireflies > 0.4, "some ambience every night")
      if a.mist > a.fireflies then sawMist = true else sawFly = true end
    end
    t.ok(sawMist and sawFly, "both moods occur across 10 nights")
  end)
end)
```

- [ ] **Step 2: Run → fails.**
- [ ] **Step 3: Implement `PreserveAmbience.luau`:** pure; `moodAt(nightIndex)` runs the standard LCG seeded by `nightIndex * 2654435761 % 2147483648 + 1`; roll `m`; `mist = 0.15 + 0.85 * m`, `fireflies = 0.15 + 0.85 * (1 - m)` (complementary, both floored so no night is dead). Also export `nightIndexAt(now: number, epoch: number, cycleLength: number): number` = `math.floor((now - epoch) / cycleLength)` so the client derives *tonight* from the same fixed-epoch clock as DayNight.
- [ ] **Step 4: Run → pass; lint.**
- [ ] **Step 5: Write `MistController.client.luau`** (GlyphDayNight subscriber pattern): wait for `Preserve.Mist` folder (WaitForChild — replication race rule), create one ParticleEmitter per `MistAnchor` (falls-mist texture id read from the existing falls emitters at runtime; size 12–20 by anchor-hash; `Transparency` NumberSequence floor 0.91; `Lifetime` 6–10; `Speed` 0.2; `Acceleration` slight lateral; `Rate` 0); subscribe EventBus `DayNight` + prime from `DayNightConfig.CurrentNightFactor`; per update: `mood = PreserveAmbience.moodAt(PreserveAmbience.nightIndexAt(workspace:GetServerTimeNow(), epoch, cycleLength))`; `Rate = baseRate * MistDensity * mood.mist * (0.35 + nightFactor * MistNightBoost)`. Hard cap: if anchors > 24, use the first 24 (sorted by name).
- [ ] **Step 6: Restart `rojo serve`** (new client script). Bake mist anchors if Task 7 zones carried `Mist=true` (re-run `MODE="bake"` for mist-flagged zones — anchors only regenerate; trees are final, so this step ONLY touches `Preserve.Mist`: use a dedicated `MODE="mist"` added to the shell that wipes/stamps `Preserve.Mist` alone; add that mode in this task, lint, commit).
- [ ] **Step 7: USER GATE — night walk** (use the `DayNightLockT` dev knob to hold night, then dawn): judge knee-depth, drift, density; tune the stage attributes live; bake approved values into the controller defaults; clear the dev knob.
- [ ] **Step 8: Commit** shared module + tests + controller + shell mode: `git commit -m "feat(roblox): preserve mist layer + ambience scheduler (fireflies socket)"`

---

### Task 10: Final gate + docs

- [ ] **Step 1: Full walk-around gate — day AND night** (cycle unlocked): preserve, waterline, arena approach sightlines, bridge view. One capture set.
- [ ] **Step 2: USER saves + publishes the place.**
- [ ] **Step 3: Run full checks:** `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`.
- [ ] **Step 4: Push the branch** (user's call — CI + dev App Runner redeploy).
- [ ] **Step 5: Update the SDD ledger** `.superpowers/sdd/progress.md` with gate outcomes and any carried minors.

## Self-Review Notes

- Spec coverage: care gradient (recipes + species roles, Tasks 3/6/8), fitted-to-space (zones, Task 7), foliage-only scope with reservations (FutureClearing zones), waterline cull (Task 1) + top-ups (Task 6), SugiMid (Task 2), scatter engine + flags (Tasks 4/5), mist + fireflies socket (Task 9), A13 gates (Tasks 2/8/9), process gates throughout. Lilies `Still` handling deferred-with-cut-path (Task 6) matching the spec's "source or cut from v1".
- Harness API is asserted from memory in test listings; Tasks 3/4/9 explicitly instruct reading `tests/harness.luau` first and adapting names — treat the listings as content, not literal API.
- Type consistency: `Zone`/`Placement`/`MistAnchor`/`Recipe` defined once (Tasks 3–4) and consumed by name in Tasks 5/9.
