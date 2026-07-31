# Foliage Finish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-plant the canyon floor with encoded design intent — muhly + new accent species prepped, ecology predicates (footing / slope / submersion / care) in ZoneScatter, a moss transition engine replacing the confetti scatter, and a composition layer on top.

**Architecture:** Pure Lune-tested planners (`tools/builders/`) mirrored into Studio bake scripts (`tools/studio/`, run via MCP `execute_luau`, datamodel Edit) — Studio cannot require from disk, so planner changes are made twice and kept in sync (existing convention: ZoneScatter ↔ scatterPreserve). Blender asset prep is headless CLI. All placements are place-only; the user saves the place and performs all 3D imports (GUI-only).

**Tech Stack:** Luau (Lune test harness `lune run tests/run`), Blender headless (`/Applications/Blender.app/Contents/MacOS/Blender`), Roblox Studio MCP.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-30-foliage-finish-design.md`. Exit bar: "reads intentional at a walk-through," explicitly not final.
- Lint MUST match CI scope: `stylua --check src tools tests && selene src tools` (selene FAILS ON WARNINGS). Run from `roblox/`.
- Tests: `lune run tests/run` from `roblox/`. All existing tests stay green.
- Determinism: integer LCG only — never `math.random`, `Date.now`, `os.time` in planners.
- Studio mirror convention: `tools/studio/scatterPreserve.luau` MIRRORS `tools/builders/ZoneScatter.luau` + `tools/studio/foliageZoneRecipes.luau`. Any planner/recipe change lands in BOTH.
- Park, never delete: removed populations go to `ServerStorage.ParkedFoliage.<Name>_2026_MM_DD`.
- Engine flags on every scattered clone: `Anchored=true, CastShadow=false, CanQuery=false, CanTouch=false`, `CanCollide=false` except mid/hero trunks (`flagClone` in scatterPreserve already does this — reuse it).
- `MeshPart.DoubleSided`: TRUE only for dense/dark foliage; FALSE for pale foliage (transmission blowout — the sakura incident).
- ONE visual attempt then STOP AND ASK the user to look (standing rule). User gates are labeled **USER GATE** below; do not iterate past them unprompted.
- 3D imports are GUI-only: prepare files + exact import settings, then hand off to the user.
- Roblox caps image uploads at 1024×1024 (silent downscale); FBX imports at 1 unit = 1 m (at 1 stud ≈ 1 ft everything real-scale is ~3.3× undersized).
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

## Part 1 — Asset batch

### Task 1: Muhly triage + prep

**Files:**
- Create: `~/Desktop/Roshambo Reference/foliage/muhly_grass/muhly.blend` (intermediate, not committed)
- Create: `~/Desktop/Roshambo Reference/foliage/muhly_grass/export/MuhlyGrass_*.fbx` (not committed)
- Modify (only if the report demands a new flag): `roblox/tools/blender/prep_foliage.py`

**Interfaces:**
- Produces: `ServerStorage.FoliageKit.MuhlyGrass` (+`MuhlyGrassB`/`MuhlyGrassC` if the source has variants) — Model, bbox height 2.5–3.5 studs, ≤ ~2,000 tris per variant. Task 9's `WaterMargin` recipe names `MuhlyGrass`.

- [ ] **Step 1: Convert the FBX to a .blend** (prep_foliage takes a .blend):

```bash
BL=/Applications/Blender.app/Contents/MacOS/Blender
SRC="$HOME/Desktop/Roshambo Reference/foliage/muhly_grass"
"$BL" --background --python-expr "import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.fbx(filepath='$SRC/BC_PM_P013_Muhly_grass_01_FBX.FBX')
bpy.ops.wm.save_as_mainfile(filepath='$SRC/muhly.blend')"
```

(224 MB source — expect minutes.)

- [ ] **Step 2: Report — change nothing yet**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
"$BL" --background "$SRC/muhly.blend" --python tools/blender/prep_foliage.py -- --report
```

Read the report for: object count (how many distinct plants = variants), per-object face counts, boundary-edge ratios (cards vs solids), which materials link an ALPHA input. Expected (from the shipped opacity maps `leaf_01_opa`, `fruit_01_opa`): blades/plumes already carded → the cheap path.

- [ ] **Step 3: Prep.** If the report confirms cards, the blades need no ribboning — prep is split-by-material + scale + warn-on-limit. If solid stems appear, add `--tube`. Nominal:

```bash
"$BL" --background "$SRC/muhly.blend" --python tools/blender/prep_foliage.py -- \
    --no-double --scale 3.3 --out "$SRC/export/MuhlyGrass.fbx"
```

If the file holds multiple plants and prep exports them merged, export per variant by deleting the others first (pattern per variant `NN`):

```bash
"$BL" --background "$SRC/muhly.blend" --python-expr "import bpy
keep = 'muhly_grass_01'   # substitute the report's object names
for o in list(bpy.data.objects):
    if o.type == 'MESH' and keep not in o.name:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath='$SRC/muhly_v01.blend')"
# then run prep_foliage on muhly_v01.blend with --out .../MuhlyGrass.fbx
```

- [ ] **Step 4: Verify the export** — re-run `--report` on the prepped output (import the exported FBX into a scratch blend the same way as Step 1) and confirm: per-mesh triangles ≤ 20,000, height ≈ 1 m × 3.3 ≈ 3.3 units, one material per object.

- [ ] **Step 5: USER IMPORT.** Hand the user the FBX list with settings: File → Import 3D (not "as package"), tick **Anchored** + **Ignore Vertex Colors**; on each foliage MeshPart set `SurfaceAppearance.AlphaMode = Transparency`. **DoubleSided decision:** muhly plumes are PALE — start `DoubleSided = false` (transmission blowout risk); flip to true only if the card culling reads broken at the Task 12 gate. Then move each imported model into `ServerStorage.FoliageKit` named `MuhlyGrass` (first/best), `MuhlyGrassB`, `MuhlyGrassC`.

- [ ] **Step 6: Verify in place** via MCP:

```lua
local kit = game:GetService("ServerStorage").FoliageKit
local out = {}
for _, n in { "MuhlyGrass", "MuhlyGrassB", "MuhlyGrassC" } do
    local m = kit:FindFirstChild(n)
    if m then
        local _, size = m:GetBoundingBox()
        table.insert(out, ("%s h=%.2f"):format(n, size.Y))
    else
        table.insert(out, n .. " MISSING")
    end
end
return table.concat(out, "\n")
```

Expected: heights 2.5–3.5. If wildly off, rescale the model in place (`Model:ScaleTo`) rather than re-exporting.

- [ ] **Step 7: Commit** any prep_foliage.py change (if none, no commit — assets are not in git):

```bash
git add roblox/tools/blender/prep_foliage.py
git commit -m "feat(roblox): prep_foliage handles the muhly grass kit"
```

### Task 2: Convert Japanese maple + katsura

**Files:**
- Modify: `roblox/tools/blender/export_forest_kit.sh` (add run lines)

**Interfaces:**
- Produces: `ServerStorage.FoliageKit.XfMapleA`, `XfMapleM`, `XfKatsuraA`, `XfKatsuraM` — untrimmed deciduous accents for the Part 4 composition layer. They are deliberately NOT added to any scatter recipe (spec: accents go through arrangements, and untrimmed foliage would wipe the sightline band).

- [ ] **Step 1: Verify source object names** (the a/m/y convention is per-species; do not assume):

```bash
ls "$HOME/Desktop/Roshambo Reference/XfrogPlants_Japan_OBJ/Models/JA03_Acer_palmatum_Japanese_Maple/"
ls "$HOME/Desktop/Roshambo Reference/XfrogPlants_Japan_OBJ/Models/JA04_Cercidiphyllum_japonicum_Katsura_Tree/"
```

- [ ] **Step 2: Add run lines** to `export_forest_kit.sh` after the BRUSH block (adjust obj names to Step 1's findings; skirt 0 — these are ornamental accents whose low canopy is the point, sited by hand where the sightline band doesn't apply):

```bash
MAPLE=JA03_Acer_palmatum_Japanese_Maple
KATSURA=JA04_Cercidiphyllum_japonicum_Katsura_Tree

echo "### ACCENTS — untrimmed deciduous, for the composition layer (never scatter pools)"
run XfMapleA    "$MAPLE/JA03a.obj"   JA03a 15000 12000 20 1.0 1 1 0
run XfMapleM    "$MAPLE/JA03m.obj"   JA03m 12000 10000 14 1.0 1 1 0
run XfKatsuraA  "$KATSURA/JA04a.obj" JA04a 15000 12000 26 1.0 1 1 0
run XfKatsuraM  "$KATSURA/JA04m.obj" JA04m 12000 10000 18 1.0 1 1 0
```

- [ ] **Step 3: Run the four exports** (script prints RESULT/WROTE lines; a BARE or ORPHAN warning means the foliage material key missed — check the species' material names against `KEYS="needle,leaf,flower,blossom,frond"` and extend KEYS if the maple uses something else):

```bash
tools/blender/export_forest_kit.sh "$HOME/Desktop/Roshambo Reference/xfrog_import_accents"
```

- [ ] **Step 4: USER IMPORT** — same settings as Task 1 Step 5. Maples/katsura are mid-toned: start `DoubleSided = true` and watch the night gate (autumn maple reds are dark enough; if a pale-gold katsura blows out backlit, flip it false). Into `ServerStorage.FoliageKit` under the exact names above.

- [ ] **Step 5: Verify in place** (same snippet as Task 1 Step 6 with the four names; expected heights ≈ 20/14/26/18).

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/blender/export_forest_kit.sh
git commit -m "feat(roblox): export maple and katsura accents from the Xfrog library"
```

### Task 3: Convert hachiku bamboo

**Files:**
- Modify: `roblox/tools/blender/export_forest_kit.sh` (bamboo run line(s), added once structure is known)

**Interfaces:**
- Produces: `ServerStorage.FoliageKit.XfBambooA` (and `XfBambooM` if the source offers sizes) — culm-and-leaf models for the single Part 4 contrast grove. Never in scatter pools.

- [ ] **Step 1: Inspect the source** — bamboo may be modelled as a single culm or a clump, and culms are thin geometry that uniform decimation shreds:

```bash
ls "$HOME/Desktop/Roshambo Reference/XfrogPlants_Japan_OBJ/Models/JA14_Phyllostachis_nigra_var_Henonis_Hachiko_Bamboo/"
BL=/Applications/Blender.app/Contents/MacOS/Blender
"$BL" --background --python tools/blender/triage_tree.py -- \
    "$HOME/Desktop/Roshambo Reference/XfrogPlants_Japan_OBJ/Models/JA14_Phyllostachis_nigra_var_Henonis_Hachiko_Bamboo/<obj from ls>"
```

(If triage_tree's CLI differs, read its header first — same convention as the other tools.)

- [ ] **Step 2: Export.** Wood budget generous relative to foliage (culms ARE the look), skirt 0, spray 1.0:

```bash
run XfBambooA "$BAMBOO/<objfile>" <objname> 12000 14000 22 1.0 1 1 0
```

If the RESULT shows shredded culms (spaghetti segments in the printed island stats), re-run with a higher wood budget before touching anything else.

- [ ] **Step 3: Visual check in Blender before bothering the user** — render a thumbnail of the export:

```bash
"$BL" --background --python-expr "import bpy
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.fbx(filepath='<out.fbx>')
bpy.context.scene.render.filepath = '/tmp/bamboo_check.png'
bpy.ops.render.opengl(write_still=True)"
```

Judge culm integrity yourself; only then hand off.

- [ ] **Step 4: USER IMPORT** — same settings; bamboo leaves are mid-green: `DoubleSided = true`. Into `ServerStorage.FoliageKit.XfBambooA`.

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/blender/export_forest_kit.sh
git commit -m "feat(roblox): export hachiku bamboo for the contrast grove"
```

### Task 4: Fern context test — USER GATE

**Files:** none committed (place-only experiment).

**Interfaces:**
- Produces: a recorded verdict (`keep` or `park`) that Task 9 reads: `FernClump` stays in the `WaterMargin` pool, or is dropped and the placed ferns park in Task 12.

- [ ] **Step 1: Stamp a context row.** Via MCP, clone 6–8 ferns from `CanyonWorld.Foliage.WaterFoliage.shore` (species `fern_06_good`, `fern_09_good`, `fern_10_good`) into a throwaway `Workspace.Sandbox.FernContextTest` folder, seated at genuinely fern-right spots picked by eye near the falls pool: shaded rock bases, north faces, under-canopy, crevices. Seat by raycast (bottom of bbox on ground). One attempt.
- [ ] **Step 2: USER GATE.** Ask the user to look — in the right context, do the ferns still read drab? Record the verdict verbatim.
- [ ] **Step 3: Clean up** the test folder. If verdict = park, note it for Task 9 (pool) and Task 12 (park `shore` ferns).

---

## Part 2 — Ecology predicates + the re-plant

### Task 5: Footing predicate + PlanOptions plumbing (ZoneScatter)

**Files:**
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces (later tasks and the Studio mirror rely on these exact names):
  - `ZoneScatter.indexSamples(samples: { Sample }, pitch: number): SampleIndex`
  - `ZoneScatter.footingDrop(index: SampleIndex, pitch: number, x: number, z: number, y: number, radius: number): number?`
  - `export type PlanOptions = { pitch: number?, keepOut: ((number, number, string?) -> boolean)?, careBand: ((number, number) -> string)? }` (keepOut lands in Task 7, careBand in Task 8 — declare the full type now so the signature never churns)
  - `ZoneScatter.plan(zones, samples, recipes, water, built, opts: PlanOptions?)` — 6th parameter, optional, fully backward compatible
  - New `Recipe` fields: `footingRadius: number?`, `footingMaxDrop: number?`

- [ ] **Step 1: Write the failing tests** (append to `tests/ZoneScatter.spec.luau`):

```luau
describe("ZoneScatter.footingDrop", function()
    local function grid(yFn: (number, number) -> number?): { ZoneScatter.Sample }
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                local y = yFn(x, z)
                if y ~= nil then
                    table.insert(s, { x = x, z = z, y = y, steep = 0 })
                end
            end
        end
        return s
    end

    test("flat ground drops nothing", function()
        local idx = ZoneScatter.indexSamples(grid(function()
            return 50
        end), 4)
        expect(ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)).toBe(0)
    end)

    test("a cliff lip reports the drop", function()
        local idx = ZoneScatter.indexSamples(grid(function(x)
            return if x >= 52 then 10 else 50
        end), 4)
        local drop = ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)
        expect(drop).toBe(40)
    end)

    test("a missing probe (void/water) is nil, not level ground", function()
        local idx = ZoneScatter.indexSamples(grid(function(x)
            return if x >= 52 then nil else 50
        end), 4)
        expect(ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)).toBe(nil)
    end)
end)

describe("ZoneScatter.plan footing gate", function()
    test("placements never straddle the cliff", function()
        local samples = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                table.insert(samples, { x = x, z = z, y = if x >= 52 then 10 else 50, steep = 0 })
            end
        end
        local footed = table.clone(CORE)
        footed.footingRadius = 4
        footed.footingMaxDrop = 4
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Footed",
                densityScale = 1,
                seed = 7,
            },
        }
        local placements = ZoneScatter.plan(zones, samples, { Footed = footed }, nil, nil, { pitch = 4 })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            -- within footingRadius of the lip (x 52) the drop exceeds 4
            expect(p.x < 48 or p.x > 56).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure:** `lune run tests/run` — expected: `indexSamples` is not a function.
- [ ] **Step 3: Implement.** In `ZoneScatter.luau`: add after the `WaterIndex` section:

```luau
export type SampleIndex = { [string]: Sample }
export type PlanOptions = {
    pitch: number?,
    keepOut: ((number, number, string?) -> boolean)?,
    careBand: ((number, number) -> string)?,
}

local function sampleKey(x: number, z: number, pitch: number): string
    return `{math.floor(x / pitch + 0.5)},{math.floor(z / pitch + 0.5)}`
end

function ZoneScatter.indexSamples(samples: { Sample }, pitch: number): SampleIndex
    local index: SampleIndex = {}
    for _, s in samples do
        index[sampleKey(s.x, s.z, pitch)] = s
    end
    return index
end

-- Max drop in studs from (x,z,y) to the ground at 8 compass probes `radius` out.
-- nil = a probe found NO sample (void: water, off-grid, past a lip) — callers
-- treat that as the WORST footing, never as level ground.
function ZoneScatter.footingDrop(
    index: SampleIndex,
    pitch: number,
    x: number,
    z: number,
    y: number,
    radius: number
): number?
    local worst = 0
    for i = 0, 7 do
        local ang = i * math.pi / 4
        local probe = index[sampleKey(x + math.cos(ang) * radius, z + math.sin(ang) * radius, pitch)]
        if probe == nil then
            return nil
        end
        worst = math.max(worst, y - probe.y)
    end
    return worst
end
```

In `plan(...)`: change the signature to `function ZoneScatter.plan(zones, samples, recipes, water, built, opts: PlanOptions?)`; at the top add `local o: PlanOptions = opts or {}`, `local pitch = o.pitch or 4`, `local sampleIndex = ZoneScatter.indexSamples(samples, pitch)`. Add to `Recipe` type: `footingRadius: number?`, `footingMaxDrop: number?`. In the `accepts` closure, after the steep check:

```luau
        local fr = recipe.footingRadius
        if fr ~= nil then
            local drop = ZoneScatter.footingDrop(sampleIndex, pitch, s.x, s.z, s.y, fr)
            if drop == nil or drop > (recipe.footingMaxDrop or 4) then
                return false
            end
        end
```

- [ ] **Step 4: Run tests:** `lune run tests/run` — all green (existing plan() callers pass nil opts implicitly).
- [ ] **Step 5: Lint:** `stylua --check src tools tests && selene src tools`
- [ ] **Step 6: Commit:** `git add roblox/tools/builders/ZoneScatter.luau roblox/tests/ZoneScatter.spec.luau && git commit -m "feat(roblox): footing predicate - 8-point ground sample in ZoneScatter"`

### Task 6: Submersion affinity (ZoneScatter)

**Files:**
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces: `Sample` gains `depth: number?` (studs of water above the ground point; nil/0 = dry). `Recipe` gains `submergeMax: number?` — nil preserves today's behavior (submerged samples never existed before; now they are REJECTED unless the recipe opts in), a number accepts `0 < depth <= submergeMax`. Task 10 fills `depth` from Studio raycasts.

- [ ] **Step 1: Write the failing tests:**

```luau
describe("ZoneScatter submersion", function()
    local function shoreSamples(): { ZoneScatter.Sample }
        -- x<=48 dry bank y=50; x>=52 shallow water: ground 49, half a stud deep
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                if x >= 52 then
                    table.insert(s, { x = x, z = z, y = 49, steep = 0, depth = 0.5 })
                else
                    table.insert(s, { x = x, z = z, y = 50, steep = 0 })
                end
            end
        end
        return s
    end
    local zones: { ZoneScatter.Zone } = {
        {
            name = "A",
            shape = "rect",
            bounds = { 0, 0, 100, 100 },
            recipe = "R",
            densityScale = 1,
            seed = 7,
        },
    }

    test("a dry recipe never plants in water", function()
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = CORE })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x <= 48).toBe(true)
        end
    end)

    test("a wet-footed recipe wades in, to its depth limit", function()
        local reed = table.clone(CORE)
        reed.submergeMax = 1.0
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = reed })
        local wet = 0
        for _, p in placements do
            if p.x >= 52 then
                wet += 1
            end
        end
        expect(wet > 0).toBe(true)
    end)

    test("too deep is still too deep", function()
        local reed = table.clone(CORE)
        reed.submergeMax = 0.3 -- shallower than the 0.5 water
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = reed })
        for _, p in placements do
            expect(p.x <= 48).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure** (`wet > 0` fails — depth is ignored today, so the dry-recipe test also fails by planting everywhere).
- [ ] **Step 3: Implement.** `Sample` type += `depth: number?`; `Recipe` type += `submergeMax: number?`. In `accepts`, after the footing gate:

```luau
        local depth = s.depth or 0
        if depth > 0 then
            local submergeMax = recipe.submergeMax
            if submergeMax == nil or depth > submergeMax then
                return false
            end
        end
```

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): submersion affinity - reeds may wade, everything else stays dry"`

### Task 7: Keep-out gate + terrain material in samples (ZoneScatter)

**Files:**
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces: `Sample` gains `material: string?` (terrain material name under the sample, Studio-filled). `PlanOptions.keepOut` (declared in Task 5) is now enforced: `keepOut(x, z, material?) -> true` vetoes a placement AND clump children. `CanyonKeepOuts.blocks(x, z, materialName?)` is the intended callback — this consolidates the two keep-out systems: FoliageZones "KeepOut" parts stay for ad-hoc dragging, CanyonKeepOuts is the authored authority, and the planner consults both.

- [ ] **Step 1: Write the failing tests:**

```luau
describe("ZoneScatter keep-out gate", function()
    local CanyonKeepOuts = require("../tools/builders/CanyonKeepOuts")
    local zones: { ZoneScatter.Zone } = {
        {
            name = "A",
            shape = "rect",
            bounds = { 0, 0, 100, 100 },
            recipe = "R",
            densityScale = 1,
            seed = 7,
        },
    }

    test("an injected keep-out vetoes ground and clump children alike", function()
        local clumpy = table.clone(CORE)
        clumpy.clumpChance = 1
        clumpy.clumpSize = 3
        local placements = ZoneScatter.plan(zones, flatSamples(), { R = clumpy }, nil, nil, {
            keepOut = function(x, _z, _m)
                return x > 50
            end,
        })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x <= 50).toBe(true)
        end
    end)

    test("CanyonKeepOuts slots straight in as the callback", function()
        -- samples over the karesansui zone (x -25..38, z -16..22) get vetoed
        local samples = {}
        for x = -40, 60, 4 do
            for z = -30, 40, 4 do
                table.insert(samples, { x = x, z = z, y = 0, steep = 0 })
            end
        end
        local wide: { ZoneScatter.Zone } = {
            {
                name = "W",
                shape = "rect",
                bounds = { -40, -30, 60, 40 },
                recipe = "R",
                densityScale = 1,
                seed = 3,
            },
        }
        local placements = ZoneScatter.plan(wide, samples, { R = CORE }, nil, nil, {
            keepOut = function(x, z, m)
                return (CanyonKeepOuts.blocks(x, z, m))
            end,
        })
        for _, p in placements do
            expect(CanyonKeepOuts.zoneAt(p.x, p.z)).toBe(nil)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.** `Sample` type += `material: string?`. In `accepts`, first gate:

```luau
        if o.keepOut ~= nil and o.keepOut(s.x, s.z, s.material) then
            return false
        end
```

(Clump children already re-run `accepts` on their probe — extend the probe construction to carry the nearest sample's `material` and `depth`: `local probe: Sample = { x = cx, z = cz, y = cy, steep = if cs then cs.steep else 0, depth = cs and cs.depth or nil, material = cs and cs.material or nil }`.)

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): one keep-out authority - the planner consults CanyonKeepOuts"`

### Task 8: CareModel + care-banded density

**Files:**
- Create: `roblox/tools/builders/CareModel.luau`
- Modify: `roblox/tools/builders/ZoneScatter.luau`
- Test: `roblox/tests/CareModel.spec.luau` (new), `roblox/tests/ZoneScatter.spec.luau` (append)

**Interfaces:**
- Produces:
  - `CareModel.reach(x: number): number` — `clamp(8 + 20 * (x + 430) / 470, 8, 28)` (the garden-floor spec's formula, verbatim)
  - `CareModel.band(x: number, distToCare: number): string` — `"GARDEN"` within 35% of reach, `"TENDED"` within reach, else `"PRESERVE"`
  - `Recipe.careDensity: { [string]: number }?` — per-band multiplier on the zone's densityScale, applied only when `PlanOptions.careBand` is provided

- [ ] **Step 1: Write the failing tests** (`tests/CareModel.spec.luau`):

```luau
--!strict
local harness = require("./harness")
local CareModel = require("../tools/builders/CareModel")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("CareModel.reach", function()
    test("the garden-floor spec's anchor values hold", function()
        -- Square x=+40 → 28 (clamped); dock x=−345 → 11.6; west end x=−430 → 8
        expect(CareModel.reach(40)).toBe(28)
        expect(math.abs(CareModel.reach(-345) - 11.6) < 0.05).toBe(true)
        expect(CareModel.reach(-430)).toBe(8)
        expect(CareModel.reach(-9999)).toBe(8)
    end)
end)

describe("CareModel.band", function()
    test("GARDEN is the inner 35% of reach", function()
        expect(CareModel.band(40, 9.7)).toBe("GARDEN") -- 0.35*28 = 9.8
        expect(CareModel.band(40, 9.9)).toBe("TENDED")
        expect(CareModel.band(40, 28.0)).toBe("TENDED")
        expect(CareModel.band(40, 28.1)).toBe("PRESERVE")
    end)
end)
```

And in `ZoneScatter.spec.luau`:

```luau
describe("ZoneScatter care-banded density", function()
    test("a zero GARDEN multiplier clears the tended front yard", function()
        local weedy = table.clone(CORE)
        weedy.careDensity = { GARDEN = 0 }
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "R",
                densityScale = 1,
                seed = 7,
            },
        }
        local placements = ZoneScatter.plan(zones, flatSamples(), { R = weedy }, nil, nil, {
            careBand = function(x, _z)
                return if x < 50 then "GARDEN" else "PRESERVE"
            end,
        })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x >= 50).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement.** `CareModel.luau`:

```luau
--!strict
-- The care model (spec 2026-07-29-canyon-garden-floor-design): how far human
-- tending reaches from paths and staged sites, as a distance in STUDS. Pure.
local CareModel = {}

CareModel.GARDEN_FRACTION = 0.35

function CareModel.reach(x: number): number
    return math.clamp(8 + 20 * (x + 430) / 470, 8, 28)
end

function CareModel.band(x: number, distToCare: number): string
    local r = CareModel.reach(x)
    if distToCare <= CareModel.GARDEN_FRACTION * r then
        return "GARDEN"
    elseif distToCare <= r then
        return "TENDED"
    end
    return "PRESERVE"
end

return CareModel
```

In `ZoneScatter.plan`, `Recipe` type += `careDensity: { [string]: number }?`, and replace the density-thinning block:

```luau
        -- density thinning before spacing so DensityScale thins uniformly;
        -- the care band scales it further where recipes opt in
        local density = zone.densityScale
        if o.careBand ~= nil and recipe.careDensity ~= nil then
            local mul = recipe.careDensity[o.careBand(s.x, s.z)]
            if mul ~= nil then
                density *= mul
            end
        end
        if roll(zone) >= density then
            continue
        end
```

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): CareModel - the care gradient as a pure, testable reach"`

### Task 9: Recipe overhaul

**Files:**
- Modify: `roblox/tools/studio/foliageZoneRecipes.luau`
- Test: `roblox/tests/FoliageZoneRecipes.spec.luau` (append)

**Interfaces:**
- Consumes: the Task 4 fern verdict; Task 1's `MuhlyGrass` template names.
- Produces: recipes the Task 10 mirror copies verbatim. Key changes below; every value is a starting point, tuned live at the Task 12 gate.

- [ ] **Step 1: Write the failing tests** (append):

```luau
describe("recipes name only species that exist", function()
    -- the kit as of Task 1-3 + the reed/weed exemplars Task 11 clones in
    local KNOWN = {
        MuhlyGrass = true,
        ReedClump = true,
        WeedStalks = true,
        FernClump = true, -- drop this line if the Task 4 verdict was park
        XfHinokiT = true,
        XfHinokiMT = true,
        XfSpruceMT = true,
        XfFirMT = true,
        XfSugi25T = true,
        XfHinokiYb = true,
        XfSpruceYb = true,
        XfFirYb = true,
        XfSugiYb = true,
        XfHinokiM = true,
        XfSpruceM = true,
        XfFirM = true,
        XfSugi40 = true,
    }
    for name, recipe in Recipes do
        test(name .. " pool is real", function()
            for _, sp in recipe.pool do
                expect(KNOWN[sp.name] == true).toBe(true)
            end
        end)
    end
end)

describe("waterline ecology", function()
    test("margin flora refuses steep hillsides", function()
        expect(Recipes.WaterMargin.maxSteep <= 0.4).toBe(true)
    end)
    test("reeds wade, muhly keeps damp feet only", function()
        expect(Recipes.WaterMargin.pool[1].name).toBe("MuhlyGrass")
        expect(Recipes.WaterMargin.submergeMax ~= nil).toBe(true)
    end)
end)
```

(`FoliageZoneRecipes.spec.luau` already requires the recipes table — follow its existing local names.)

- [ ] **Step 2: Run to verify failure** (WallFringe pool still names ConiferA etc.).
- [ ] **Step 3: Rewrite the recipe table** — the deltas:
  - `Recipe` type += `footingRadius: number?`, `footingMaxDrop: number?`, `submergeMax: number?`, `careDensity: { [string]: number }?` (mirror of Task 5-8).
  - **WallFringe** pool → the Xfrog untrimmed adults: `{ XfHinokiM 30, XfSpruceM 30, XfFirM 25, XfSugi40 15 }`, drop the per-species toolbox scales, keep `heightScale = 0.5` as the starting tune, add `footingRadius = 3, footingMaxDrop = 6` (walls are steep; sparser is accepted — the spec says so).
  - **PreserveCore** += `footingRadius = 2.5, footingMaxDrop = 4`.
  - **PreserveBrush** += `footingRadius = 1.5, footingMaxDrop = 3`, `careDensity = { GARDEN = 0.25, TENDED = 0.6 }` (understory cleared where tended — "clearing the floor is most of what tending a wood actually is").
  - **WaterMargin** → `pool = { MuhlyGrass 45, ReedClump 30, WeedStalks 15, FernClump 10 }` (drop FernClump if parked, reweight to 50/35/15), `maxSteep = 0.35` (the user's "weeds on steep hillsides just look bad"), `submergeMax = 1.0` (partial submersion is a feature), `footingRadius = 1, footingMaxDrop = 2`, keep `nearWater = 8`, `layer = "ground"`.
  - Deciduous accents and bamboo appear in NO pool (composition layer only — add a comment saying exactly that).
- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): recipes learn ecology - real species, wet feet, footing, care"`

### Task 10: Sync the Studio mirror (scatterPreserve)

**Files:**
- Modify: `roblox/tools/studio/scatterPreserve.luau`

**Interfaces:**
- Consumes: Tasks 5–9 verbatim (this file MIRRORS the planner + recipes — copy the logic, keep the header's sync warning).
- Produces: a bake tool whose `MODE="plan"` reports per-zone counts under the new rules. Task 12 runs it.

- [ ] **Step 1: Mirror the recipe table** from Task 9 into the `RECIPES` block (types too).
- [ ] **Step 2: Mirror the planner changes** into the inline planner: `indexSamples`/`footingDrop`, the accepts gates (keep-out first, then steep, footing, submersion), care-banded density, PlanOptions equivalent.
- [ ] **Step 3: Upgrade `sampleTerrain` for submersion** — ground under shallow water must become a sample (today `hit.Material == Water` cells are skipped entirely):

```lua
local function sampleTerrain(zones: { Zone }): { Sample }
    local rpGround = RaycastParams.new()
    rpGround.FilterType = Enum.RaycastFilterType.Include
    rpGround.FilterDescendantsInstances = { workspace.Terrain }
    rpGround.IgnoreWater = true
    local rpWater = RaycastParams.new()
    rpWater.FilterType = Enum.RaycastFilterType.Include
    rpWater.FilterDescendantsInstances = { workspace.Terrain }
    rpWater.IgnoreWater = false
    -- (bbox loop unchanged)
    for x = x1, x2, SAMPLE_PITCH do
        for z = z1, z2, SAMPLE_PITCH do
            local origin = Vector3.new(x, PROBE_TOP, z)
            local ground = workspace:Raycast(origin, Vector3.new(0, -900, 0), rpGround)
            if ground then
                local surface = workspace:Raycast(origin, Vector3.new(0, -900, 0), rpWater)
                local depth = 0
                if surface and surface.Material == Enum.Material.Water then
                    depth = surface.Position.Y - ground.Position.Y
                end
                table.insert(samples, {
                    x = x,
                    z = z,
                    y = ground.Position.Y,
                    steep = 1 - math.clamp(ground.Normal.Y, 0, 1),
                    depth = depth,
                    material = ground.Material.Name,
                })
            end
        end
    end
    return samples
end
```

- [ ] **Step 4: Keep-out callback** — mirror `CanyonKeepOuts.MATERIALS` + `ZONES` as inline constants (with the sync-warning comment) and pass `keepOut = function(x, z, m) ... end` implementing the same `blocks` logic.
- [ ] **Step 5: Care distance** — build a bucketed index over `readBuiltCells()` (reuse the `WATER_BUCKET` pattern) plus the staged-site override (the FallsDock footprint gets a 15-stud garden radius — read `RoshamboStage.FallsDock`'s bbox and append its perimeter points to the care cells). `careBand = function(x, z) return CareModelBand(x, nearestCareDist(x, z)) end` with `CareModelBand` mirrored from Task 8. Nearest distance by expanding ring over buckets:

```lua
local function nearestCareDist(index, x, z): number
    for ring = 0, 8 do -- 8 buckets * 16 studs = beyond any reach
        local best = math.huge
        local bx, bz = math.floor(x / WATER_BUCKET), math.floor(z / WATER_BUCKET)
        for gx = bx - ring, bx + ring do
            for gz = bz - ring, bz + ring do
                if math.max(math.abs(gx - bx), math.abs(gz - bz)) == ring then
                    local bucket = index[`{gx},{gz}`]
                    if bucket then
                        for _, c in bucket do
                            local dx, dz = x - c[1], z - c[2]
                            best = math.min(best, dx * dx + dz * dz)
                        end
                    end
                end
            end
        end
        if best < math.huge and ring >= 1 then -- one extra ring so a closer diagonal can't hide
            return math.sqrt(best)
        end
    end
    return math.huge
end
```

- [ ] **Step 6: Lint** (`stylua --check src tools tests && selene src tools` — selene runs on tools; dead locals fail CI).
- [ ] **Step 7: Smoke it** via MCP `execute_luau` (Edit): run with `MODE="plan"` — it should print per-zone counts without stamping. Expect zeros for WaterMargin (zones not restored yet — that's Task 11).
- [ ] **Step 8: Commit:** `git commit -m "feat(roblox): scatterPreserve mirrors the ecology predicates"`

### Task 11: Studio prep — zones restored, exemplar templates

**Files:** none committed (place state). Uses MCP `execute_luau` (Edit) throughout.

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-27-forest-preserve-foliage-design.md` (the recorded 32-zone inventory).
- Produces: `Workspace.Sandbox.FoliageZones` live again with a complete zone set; `ServerStorage.FoliageKit.ReedClump` / `WeedStalks` / `FernClump` exemplar templates. Task 12 bakes against these.

- [ ] **Step 1: Restore the parked zones:** move `ServerStorage.Sandbox_PARKED.FoliageZones` → `Workspace.Sandbox.FoliageZones` (Instance.Parent reassignment; also restore `Sandbox_PARKED.WaterMap` → `Workspace.Sandbox.WaterMap` — scatterPreserve reads it from there and warns if absent).
- [ ] **Step 2: Audit.** List the restored zone parts (name, Recipe attribute, shape, bounds) and diff against the 32 recorded in the forest-preserve spec. Print the missing list.
- [ ] **Step 3: Re-author the missing zones** as parts with the spec's recorded bounds/attributes (Recipe, DensityScale, Seed, Mist). If the spec's record is insufficient for any zone, STOP and ask the user rather than inventing coverage.
- [ ] **Step 4: Exemplar templates.** Clone one healthy instance of each kept waterline species into the kit, renamed to the recipe names:

```lua
local ss = game:GetService("ServerStorage")
local wf = workspace.CanyonWorld.Foliage.WaterFoliage
local map = {
    { from = wf.waterline, match = "reedy_mid_14_good", to = "ReedClump" },
    { from = wf.waterline, match = "weed_stalks_09_good", to = "WeedStalks" },
    { from = wf.shore, match = "fern_06_good", to = "FernClump" }, -- skip if parked (Task 4)
}
for _, e in map do
    if ss.FoliageKit:FindFirstChild(e.to) == nil then
        for _, inst in e.from:GetChildren() do
            if inst.Name == e.match then
                local c = inst:Clone()
                c.Name = e.to
                c.Parent = ss.FoliageKit
                break
            end
        end
    end
end
return "templates done"
```

- [ ] **Step 5: Plan-mode dry run:** `scatterPreserve` with `MODE="plan"` — capture per-zone counts. Sanity: WaterMargin now nonzero; no zone at 0 that should plant; total in the low thousands, not tens of thousands.
- [ ] **Step 6:** Report counts to the user before any wipe (this is the last cheap look before Task 12 rebuilds the world).

### Task 12: Park + re-bake + USER GATE

**Files:** none committed (place state; the bake tool itself was committed in Task 10).

**Interfaces:**
- Consumes: Task 11's restored zones + templates; the Task 10 bake tool.
- Produces: the re-planted preserve + waterline. The plan's biggest visible moment.

- [ ] **Step 1: Park the outgoing populations** (never delete):

```lua
local ss = game:GetService("ServerStorage")
local parked = ss:FindFirstChild("ParkedFoliage") or Instance.new("Folder", ss)
parked.Name = "ParkedFoliage"
local dst = Instance.new("Folder", parked)
dst.Name = "Replant_2026_08"
local moves = {}
local F = workspace.CanyonWorld.Foliage
for _, name in { "Preserve", "WaterFoliage" } do
    local f = F:FindFirstChild(name)
    if f then
        f.Parent = dst
        table.insert(moves, name)
    end
end
return "parked: " .. table.concat(moves, ", ")
```

(Heroes and MossScatter stay — moss is Task 13-14's business.)

- [ ] **Step 2: Bake** — `scatterPreserve` `MODE="bake"`, all zones. One attempt.
- [ ] **Step 3: Screenshot survey** for your own eyes first (`screen_capture` with camera args at: the square looking west, the falls pool, mid-canyon from the suspension bridge, a fringe wall; **reset `CameraType = Custom` after** — the capture leaves the Edit camera Scriptable and locks the user's viewport).
- [ ] **Step 4: USER GATE.** Ask the user to walk it. Expected tuning axes (edit recipe values or zone attributes, re-bake the affected zones only — determinism means untouched zones reproduce): density, heightScale on the fringe, muhly/reed balance, care multipliers. Iterate ONLY as directed, one change-set per look.
- [ ] **Step 5: On pass — user saves the place.** Confirm before proceeding.

---

## Part 3 — Moss transition engine

### Task 13: MossTransitions planner (pure)

**Files:**
- Create: `roblox/tools/builders/MossTransitions.luau`
- Test: `roblox/tests/MossTransitions.spec.luau`

**Interfaces:**
- Produces (Task 14's collector consumes exactly these):

```luau
export type Seed = { x: number, z: number, y: number, kind: string }
export type Params = {
    seed: number,
    spacing: number,          -- min distance between clumps (studs)
    maxDist: number,          -- how far moss wanders from its seed
    dartsPerSeed: number,
    kindDensity: { [string]: number }, -- 0..1 acceptance scale per seed kind
    pool: { { name: string, weight: number } },
    scaleMin: number,
    scaleMax: number,
}
export type MossPlacement = { x: number, z: number, species: string, yaw: number, scale: number, kind: string }
MossTransitions.plan(seeds: { Seed }, params: Params): { MossPlacement }
```

Note: placements carry NO y — the collector re-raycasts the ground at the final (x, z) and seats the BOTTOM of the bounding box (the moss-bug lessons: never reuse a height measured elsewhere, never seat the centre).

- [ ] **Step 1: Write the failing tests:**

```luau
--!strict
local harness = require("./harness")
local MossTransitions = require("../tools/builders/MossTransitions")
local describe, test, expect = harness.describe, harness.test, harness.expect

local PARAMS: MossTransitions.Params = {
    seed = 11,
    spacing = 1.5,
    maxDist = 6,
    dartsPerSeed = 24,
    kindDensity = { stone = 1.0, waterline = 0.8 },
    pool = { { name = "Moss_A", weight = 3 }, { name = "Moss_B", weight = 1 } },
    scaleMin = 0.8,
    scaleMax = 1.3,
}

describe("MossTransitions.plan", function()
    test("deterministic: same input twice = identical output", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "stone" } }
        local a = MossTransitions.plan(seeds, PARAMS)
        local b = MossTransitions.plan(seeds, PARAMS)
        expect(#a).toBe(#b)
        for i, p in a do
            expect(p.x).toBe(b[i].x)
            expect(p.species).toBe(b[i].species)
        end
    end)

    test("moss hugs the transition: density falls with distance", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "stone" } }
        local near, far = 0, 0
        for _, p in MossTransitions.plan(seeds, PARAMS) do
            local d = math.sqrt(p.x * p.x + p.z * p.z)
            expect(d <= PARAMS.maxDist).toBe(true)
            if d <= PARAMS.maxDist / 2 then
                near += 1
            else
                far += 1
            end
        end
        expect(near > far).toBe(true)
    end)

    test("spacing holds across neighbouring seeds", function()
        local seeds = {
            { x = 0, z = 0, y = 10, kind = "stone" },
            { x = 3, z = 0, y = 10, kind = "stone" },
        }
        local placements = MossTransitions.plan(seeds, PARAMS)
        for i, p in placements do
            for j = i + 1, #placements do
                local q = placements[j]
                local dx, dz = p.x - q.x, p.z - q.z
                expect(dx * dx + dz * dz >= PARAMS.spacing * PARAMS.spacing).toBe(true)
            end
        end
    end)

    test("an unknown kind places nothing", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "confetti" } }
        expect(#MossTransitions.plan(seeds, PARAMS)).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run to verify failure.**
- [ ] **Step 3: Implement:**

```luau
--!strict
-- Moss as a TRANSITION-DWELLER (spec 2026-07-30-foliage-finish-design §Part 3):
-- clumps generated around adjacency seeds (rock feet, timber-meets-stone, the
-- splash band, crevices), density falling off with distance from the seed. Pure,
-- deterministic (integer LCG). The collector re-raycasts ground for Y at bake.
local MossTransitions = {}

export type Seed = { x: number, z: number, y: number, kind: string }
export type Params = {
    seed: number,
    spacing: number,
    maxDist: number,
    dartsPerSeed: number,
    kindDensity: { [string]: number },
    pool: { { name: string, weight: number } },
    scaleMin: number,
    scaleMax: number,
}
export type MossPlacement = {
    x: number,
    z: number,
    species: string,
    yaw: number,
    scale: number,
    kind: string,
}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648
end

local function pickSpecies(pool: { { name: string, weight: number } }, roll: number): string
    local total = 0
    for _, s in pool do
        total += s.weight
    end
    local at = roll * total
    for _, s in pool do
        at -= s.weight
        if at <= 0 then
            return s.name
        end
    end
    return pool[#pool].name
end

function MossTransitions.plan(seeds: { Seed }, params: Params): { MossPlacement }
    local state = (params.seed * 2654435761) % 2147483648 + 1
    local function roll(): number
        local r
        state, r = lcg(state)
        return r
    end

    local out: { MossPlacement } = {}
    for _, seed in seeds do
        local density = params.kindDensity[seed.kind]
        if density == nil then
            continue
        end
        for _ = 1, params.dartsPerSeed do
            local ang = roll() * 2 * math.pi
            local dist = roll() * params.maxDist
            -- linear falloff: acceptance shrinks as the dart lands further out
            local accept = roll()
            if accept >= density * (1 - dist / params.maxDist) then
                continue
            end
            local x = seed.x + math.cos(ang) * dist
            local z = seed.z + math.sin(ang) * dist
            local tooClose = false
            for _, p in out do
                local dx, dz = x - p.x, z - p.z
                if dx * dx + dz * dz < params.spacing * params.spacing then
                    tooClose = true
                    break
                end
            end
            if tooClose then
                continue
            end
            table.insert(out, {
                x = x,
                z = z,
                species = pickSpecies(params.pool, roll()),
                yaw = roll() * 2 * math.pi,
                scale = params.scaleMin + roll() * (params.scaleMax - params.scaleMin),
                kind = seed.kind,
            })
        end
    end
    return out
end

return MossTransitions
```

- [ ] **Step 4: Run tests, Step 5: Lint, Step 6: Commit:** `git commit -m "feat(roblox): MossTransitions - moss lives in the crevices, not the confetti"`

### Task 14: Moss collector + re-bake + USER GATE

**Files:**
- Create: `roblox/tools/studio/buildMossTransitions.luau`

**Interfaces:**
- Consumes: `MossTransitions.plan` (MIRRORED inline — Studio cannot require from disk; carry the sync-warning header), `ServerStorage.MossLibrary` (49 meshes, families `Moss_A/B/D/E`, `Moos_C` — note the kit's own typo), the moss seating lessons (bottom-of-box + absolute sink + re-raycast at final position).
- Produces: `CanyonWorld.Foliage.MossTransitions` folder; the old `MossScatter` parked.

- [ ] **Step 1: Write the collector** with `MODE = "plan" | "bake" | "wipe"`. Seed generation, one function per kind:
  - **`stone`** — for every BasePart under `CanyonWorld` whose name matches `^Stone_` (the 35 trail stones) plus every Model in the rock folders (`CanyonWorld.Arena` rock models, any `RockLibrary`-sourced clones): 6–10 perimeter points around the base at bbox-bottom height.
  - **`footing`** — for BaseParts under `CanyonWorld.Paths` and `CanyonWorld.Structures` whose bbox bottom sits within 0.75 studs of the terrain (raycast at the part centre): points along the two long bottom edges, stepped every ~4 studs (reuse the `readBuiltCells` stepping pattern from scatterPreserve).
  - **`waterline`** — WaterMap cells (`Workspace.Sandbox.WaterMap.WaterMarkers`) that have at least one missing 4-stud neighbour cell (edge of water = the splash band), seeded at the cell position.
  - **`crevice`** — terrain raycast grid (pitch 4) over the corridor bounds; keep samples whose `1 - normal.Y` sits in a band (default 0.35–0.65: steep enough to be a fold, not a cliff face).
  Params defaults: `spacing = 1.5, maxDist = 5, dartsPerSeed = 16, kindDensity = { stone = 0.9, footing = 0.7, waterline = 0.8, crevice = 0.5 }`, pool weighted toward mats (`Moss_A` 3, `Moos_C` 2, `Moss_D` 2, `Moss_E` 1, `Moss_B` 1 — sporophyte accent stays rare).
  Seating at bake: fresh ground raycast at each placement's (x, z); position the clone so the BOTTOM of its bounding box sits at ground minus an absolute `SINK = 0.15` studs. Engine flags via the same `flagClone` treatment as scatterPreserve (never collide). Sort seeds by (x, z) before planning so collection order can't change the bake.
- [ ] **Step 2: `MODE="plan"`** — print seed counts per kind and total placements. Sanity: hundreds to ~1,500, not tens of thousands; if crevice dominates 10:1 the band is too wide.
- [ ] **Step 3: Park the old moss:** move `CanyonWorld.Foliage.MossScatter` → `ServerStorage.ParkedFoliage.MossConfetti_2026_08`.
- [ ] **Step 4: Bake.** One attempt. Screenshot survey (same discipline as Task 12 Step 3).
- [ ] **Step 5: USER GATE.** Walk: moss should read as gathering at feet-of-things and waterline, not broadcast. Tune `kindDensity`/`maxDist` only as directed.
- [ ] **Step 6: Lint + commit the tool:** `git add roblox/tools/studio/buildMossTransitions.luau && git commit -m "feat(roblox): moss gathers at the transitions"`
- [ ] **Step 7: User saves the place.**

---

## Part 4 — Composition layer

### Task 15: Bamboo grove + arrangements pass + USER GATE

**Files:**
- Modify: `roblox/tools/studio/foliageArrangements.luau` (new arrangement)

**Interfaces:**
- Consumes: `ServerStorage.FoliageKit.XfBambooA` (Task 3), `XfMapleA/M`, `XfKatsuraA/M` (Task 2), the existing site grammar + 13 arrangements in `foliageArrangements.luau` (MODE="display" tuning row / MODE="place" single deploy).
- Produces: the composed accent layer over the rebuilt background.

- [ ] **Step 1: Add a `BambooGrove` arrangement** to the arrangements table, following the file's existing entry shape: 7–9 `XfBambooA` at 3–5 stud spacing in a loose ellipse (real groves are tight), odd count, one culm-cluster dominant at centre, hard keep-out consulted, per-tree ground raycast (the file's composition rules already do this — reuse them). Comment: bamboo appears here and NOWHERE else (monoculture fights the mossy-gorge north star — one contrast grove only).
- [ ] **Step 2: Add maple/katsura** to the arrangement palette where the grammar's species lists live (jewel-tone rule applies: never touching dark conifer masses; green-first 4:1 — the maples are the exception, not the rule).
- [ ] **Step 3: Site the grove with the user.** Propose 2–3 candidate sites read from the map (leading candidate per spec: a river-trail reach where the grove is seen across water); stamp `MODE="display"` previews at the candidates; **USER picks.** Deploy with `MODE="place"`, delete the other previews.
- [ ] **Step 4: Arrangements pass at the named sites** — walk the site-grammar list that exists in-world (bridge ends, path gates, pool mirror, stair companions, tunnel mouths); stamp where the rebuilt background left a hole. ONE pass, then **USER GATE** — the user hand-tunes; do not iterate unprompted.
- [ ] **Step 5: Lint + commit:** `git add roblox/tools/studio/foliageArrangements.luau && git commit -m "feat(roblox): the bamboo contrast grove and accent arrangements"`
- [ ] **Step 6: User saves the place.**

### Task 16: Final walk-through + as-built record

**Files:**
- Modify: `docs/superpowers/specs/2026-07-30-foliage-finish-design.md` (append an As-Built section)

- [ ] **Step 1: USER GATE — the exit-bar walk-through** (day AND night — the lantern/yamadoro trail and moss read differently at night). The bar: "reads intentional." Not final.
- [ ] **Step 2: Append an As-Built section** to the spec: what shipped, final tuned values (recipe deltas from the plan's starting points), the fern verdict, muhly variant count, grove site, anything parked, anything deliberately left.
- [ ] **Step 3: Confirm the place is saved** (all of Parts 2–4 are place-only).
- [ ] **Step 4: Commit + push** (push auto-deploys the dev backend; Roblox-only changes are harmless there):

```bash
git add docs/superpowers/specs/2026-07-30-foliage-finish-design.md
git commit -m "docs: foliage finish as-built"
git push
```

Expect `roblox-ci` to run the Lune suite + stylua/selene — all green locally before pushing.
