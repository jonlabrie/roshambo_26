# Canyon River Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the valley-floor stroll route from the Square (x +60) west to x −380, where it ties into the existing `NW80FallsStair`.

**Architecture:** The route is divided into five chapters by the terrain's own profile — two flat terraces and three climbs. Chapter data lives in one pure, Lune-tested module (`RiverPathChapters.luau`) that the Studio scripts mirror. Flat chapters are built by `buildFlatShelfPath.luau` (uniform-tread layout), climbs by `buildIshidanStairs.luau` (uniform-riser layout); both apply the identical locked §1a dressing. Each chapter is carved, built, dressed and gated on its own before the next begins.

**Tech Stack:** Luau; Lune for headless tests; Rojo for the repo↔Studio sync of `src/`; Roblox Studio MCP (`execute_luau`, Edit datamodel) for all world building; stylua + selene for CI.

## Global Constraints

- **Place-only.** Paths, walls, railings and lanterns are ad-hoc `Workspace` content persisted by the saved place, **not** by Rojo (recipe §0.5). Ship by publishing/saving the place, **never `rojo build`** — CI fails if a `.rbxl(x)` is committed.
- **Parent under `Workspace.CanyonWorld.Paths`.** Never `Workspace` root (the sweep convention). Never add children to `RoshamboStage`.
- **ONE attempt, then STOP and ask** (recipe §0.2). Build one chapter, let the user look in Studio, iterate on *their* read. Never self-judge visuals; never proceed to the next chapter unprompted.
- **The user drives placement and finish-smooths terrain** (recipe §0.3). You carve rough; they smooth.
- **Never reverse-engineer dimensions from placed parts.** The locked §1a recipe values are authoritative: `riserWidth 6.4`, `riserDepth 0.45`, `splitFrac 0.35`, `flagHW 2.7`, `flagMinDepth 0.4`, `bedW 5.8`, `bedH 1.2`, `bedVariant "ZenGravel1"`, `bedColor Color3.fromRGB(150, 146, 138)`, `flagSideColor Color3.fromRGB(52, 52, 49)`, `riserTarget 0.6`.
- **Outer edges flush.** Support outer faces sit on the deck/tread edge, never inboard.
- **Walls register to the BUILT edge**, +~1.5–2 standoff — never to the excavation.
- **User units:** 1 stud ≈ 1 foot, 1 inch ≈ 1/12 stud.
- **Reversible terrain:** `Terrain:CopyRegion` to ServerStorage before any carve; restore with `PasteRegion(region, origin, true)` (pasteEmptyCells **true**).
- **`chunkFlags = 40`** — chunk published flag meshes by FLAG count, never by step count (blows Studio's triangle limit; this bit the project twice).
- **Mirror rule:** `tools/studio/*` cannot `require` repo modules. Where a Studio script duplicates repo logic, both copies must be kept in sync and the duplication noted in the file header.
- **CI scope:** `lune run tests/run`, `stylua --check src tests tools`, `selene src tools` (selene fails on warnings). Run all three from `roblox/` before every commit.
- **Do not rebuild the falls headwall** (x −420…−440). `NW80FallsStair` already serves it.
- **Do not touch the 356 existing `Step_<i>` beds** or build `ZenGravel1` — spec §7.2. The new chapters inherit `bedVariant = "ZenGravel1"` and will fall back to Concrete exactly as every existing path does.

## File Structure

| file | responsibility |
| --- | --- |
| `roblox/tools/builders/RiverPathChapters.luau` | **NEW.** Pure data + validation: the five chapters, their x-spans, baked control points, and declared layout kind. No Roblox API. |
| `roblox/tests/RiverPathChapters.spec.luau` | **NEW.** Locks the invariants: contiguous coverage, kind matches grade, monotonic westward climb, western terminus. |
| `roblox/tools/studio/draftRiverPathMarkers.luau` | **NEW.** Drops draggable markers for this route into `Workspace.PathDraft.River`. Separate from the legacy `draftPathMarkers.luau`, whose hardcoded 2026-06 routes are superseded. |
| `roblox/tools/studio/bakeRiverPathMarkers.luau` | **NEW.** Reads the dragged markers, prints a paste-ready chapter table for `RiverPathChapters.luau`. |
| `roblox/tools/studio/carveRiverPath.luau` | **NEW.** Rough terrain carve along a chapter's centerline, with a `CopyRegion` backup first. |
| `roblox/tools/studio/buildFlatShelfPath.luau` | **MODIFY.** Add the two flat chapters to `CONFIG.paths`. |
| `roblox/tools/studio/buildIshidanStairs.luau` | **MODIFY.** Add a `CONFIG.presets` table + `CONFIG.active` selector so all three climb chapters stay reproducible from the committed file. No layout-logic change. |
| `roblox/tools/studio/buildBambooRailing.luau` | **MODIFY.** Add a `RUNS` entry per chapter with an open-air edge. |
| `roblox/tools/studio/buildChochinPole.luau` | **MODIFY.** Add a `path` entry per chapter. |
| `docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md` | **MODIFY.** As-built record appended (recipe §0.6). |

---

### Task 1: `RiverPathChapters` data module + tests

**Files:**
- Create: `roblox/tools/builders/RiverPathChapters.luau`
- Test: `roblox/tests/RiverPathChapters.spec.luau`

**Interfaces:**
- Consumes: `roblox/tools/builders/CanyonPath.luau` — `CanyonPath.classifySegment(a: {number}, b: {number}) -> string` returning `"steps"` or `"paver"`, thresholded at `CanyonPath.STEP_GRADE = 0.27`.
- Produces:
  - `RiverPathChapters.CHAPTERS: { { name: string, kind: string, outModel: string, control: { { number } } } }` — `kind` is `"flat"` or `"stair"`; `control` is a list of `{x, y, z}` triples ordered **east → west** (descending x).
  - `RiverPathChapters.WEST_TERMINUS: number` = `-380`
  - `RiverPathChapters.kindFor(control: { { number } }) -> string` — `"stair"` if any consecutive pair classifies as `"steps"`, else `"flat"`.
  - `RiverPathChapters.validate() -> (boolean, { string })` — ok flag plus human-readable failures.

The control points seeded here are the **surveyed corridor profile**, sampled at 20-stud intervals along the river at the lowest ground between z −30 and +15. They are a first approximation; Task 3 replaces them with the user's dragged line. The tests written now guard that replacement.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/RiverPathChapters.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local RiverPathChapters = require("../tools/builders/RiverPathChapters")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RiverPathChapters.CHAPTERS", function()
    test("has five chapters", function()
        expect(#RiverPathChapters.CHAPTERS).toBe(5)
    end)

    test("every chapter has at least two control points", function()
        for _, c in RiverPathChapters.CHAPTERS do
            expect(#c.control >= 2).toBe(true)
        end
    end)

    test("control points run east to west within a chapter", function()
        for _, c in RiverPathChapters.CHAPTERS do
            for i = 2, #c.control do
                expect(c.control[i][1] < c.control[i - 1][1]).toBe(true)
            end
        end
    end)

    test("chapters are contiguous: each starts where the previous ended", function()
        local list = RiverPathChapters.CHAPTERS
        for i = 2, #list do
            local prevEnd = list[i - 1].control[#list[i - 1].control]
            local thisStart = list[i].control[1]
            expect(thisStart[1]).toBeCloseTo(prevEnd[1], 0.5)
            expect(thisStart[2]).toBeCloseTo(prevEnd[2], 0.5)
            expect(thisStart[3]).toBeCloseTo(prevEnd[3], 0.5)
        end
    end)

    test("the route climbs westward and never descends", function()
        for _, c in RiverPathChapters.CHAPTERS do
            for i = 2, #c.control do
                expect(c.control[i][2] >= c.control[i - 1][2] - 0.01).toBe(true)
            end
        end
    end)

    test("the west terminus stops short of NW80FallsStair", function()
        local list = RiverPathChapters.CHAPTERS
        local last = list[#list].control[#list[#list].control]
        expect(last[1]).toBeCloseTo(RiverPathChapters.WEST_TERMINUS, 1.0)
        expect(last[1] > -392).toBe(true)
    end)

    test("each chapter's declared kind matches its measured grade", function()
        for _, c in RiverPathChapters.CHAPTERS do
            expect(RiverPathChapters.kindFor(c.control)).toBe(c.kind)
        end
    end)

    test("outModel names are unique and prefixed River", function()
        local seen = {}
        for _, c in RiverPathChapters.CHAPTERS do
            expect(seen[c.outModel]).toBeNil()
            seen[c.outModel] = true
            expect(c.outModel:sub(1, 5)).toBe("River")
        end
    end)
end)

describe("RiverPathChapters.kindFor", function()
    test("a level run is flat", function()
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -100, 101, 0 } })).toBe("flat")
    end)
    test("a steep run is stair", function()
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -20, 125, 0 } })).toBe("stair")
    end)
    test("one steep pair among gentle ones makes the whole chapter a stair", function()
        expect(RiverPathChapters.kindFor({
            { 0, 100, 0 },
            { -50, 101, 0 },
            { -70, 126, 0 },
        })).toBe("stair")
    end)
end)

describe("RiverPathChapters.validate", function()
    test("the shipped data validates", function()
        local ok, errs = RiverPathChapters.validate()
        expect(#errs).toBe(0)
        expect(ok).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd roblox && lune run tests/run
```

Expected: FAIL — `RiverPathChapters` module not found.

- [ ] **Step 3: Write the module**

Create `roblox/tools/builders/RiverPathChapters.luau`:

```luau
--!strict
-- The river path's chapter definitions: the valley-floor stroll route from the Square
-- (x +60) west to x -380, where it meets the existing NW80FallsStair.
--
-- The terrain divides the route for us. Sampling the lowest ground between z -30 and
-- +15 at 20-stud intervals gives two flat terraces and three climbs, with two sharp
-- risers acting as thresholds. Chapter boundaries sit ON those breaks, so no chapter
-- mixes a terrace with a climb -- which matters because the two are built by different
-- layout engines (uniform tread vs uniform riser).
--
-- Spec: docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md section 5.
-- MIRRORED into tools/studio/buildFlatShelfPath.luau and buildIshidanStairs.luau
-- (Studio cannot require repo modules) -- keep the control points in sync.
local CanyonPath = require("./CanyonPath")

local RiverPathChapters = {}

-- The build stops here; NW80FallsStair (centre x -392) carries the falls headwall.
RiverPathChapters.WEST_TERMINUS = -380

-- SEED DATA: the surveyed corridor profile, not yet the user's line. Task 3 of the
-- plan replaces `control` with the baked marker positions; the spec tests guard it.
RiverPathChapters.CHAPTERS = {
    {
        name = "Square terrace",
        kind = "flat",
        outModel = "RiverTerracePath",
        control = {
            { 60.0, 108.7, -8.0 },
            { 0.0, 109.9, -8.0 },
            { -80.0, 109.9, -8.0 },
        },
    },
    {
        name = "First riser",
        kind = "stair",
        outModel = "RiverFirstRiser",
        control = {
            { -80.0, 109.9, -8.0 },
            { -100.0, 134.4, -8.0 },
        },
    },
    {
        name = "Mid climb",
        kind = "stair",
        outModel = "RiverMidClimb",
        control = {
            { -100.0, 134.4, -8.0 },
            { -160.0, 152.2, -8.0 },
            { -200.0, 159.4, -8.0 },
            { -240.0, 174.8, -8.0 },
        },
    },
    {
        name = "The bench",
        kind = "flat",
        outModel = "RiverBenchShelf",
        control = {
            { -240.0, 174.8, -8.0 },
            { -280.0, 174.8, -8.0 },
            { -300.0, 177.2, -8.0 },
        },
    },
    {
        name = "Upper climb",
        kind = "stair",
        outModel = "RiverUpperClimb",
        control = {
            { -300.0, 177.2, -8.0 },
            { -340.0, 186.9, -8.0 },
            { -360.0, 188.7, -8.0 },
            { -380.0, 199.5, -8.0 },
        },
    },
}

-- A chapter is a stair if ANY consecutive pair exceeds CanyonPath.STEP_GRADE (0.27).
-- Whole-chapter average would smuggle a short steep pitch into a flat-shelf layout,
-- where the uniform-tread engine would render it as an unclimbable lip.
function RiverPathChapters.kindFor(control: { { number } }): string
    for i = 2, #control do
        if CanyonPath.classifySegment(control[i - 1], control[i]) == "steps" then
            return "stair"
        end
    end
    return "flat"
end

function RiverPathChapters.validate(): (boolean, { string })
    local errs: { string } = {}
    local list = RiverPathChapters.CHAPTERS
    for ci, c in list do
        if #c.control < 2 then
            table.insert(errs, ("%s: needs at least two control points"):format(c.name))
        end
        for i = 2, #c.control do
            if c.control[i][1] >= c.control[i - 1][1] then
                table.insert(errs, ("%s: control %d does not run westward"):format(c.name, i))
            end
            if c.control[i][2] < c.control[i - 1][2] - 0.01 then
                table.insert(errs, ("%s: control %d descends"):format(c.name, i))
            end
        end
        local measured = RiverPathChapters.kindFor(c.control)
        if measured ~= c.kind then
            table.insert(errs, ("%s: declared %q but measures %q"):format(c.name, c.kind, measured))
        end
        if ci > 1 then
            local prev = list[ci - 1].control[#list[ci - 1].control]
            local here = c.control[1]
            for axis = 1, 3 do
                if math.abs(prev[axis] - here[axis]) > 0.5 then
                    table.insert(errs, ("%s: does not start where %s ended"):format(c.name, list[ci - 1].name))
                    break
                end
            end
        end
    end
    local last = list[#list].control[#list[#list].control]
    if math.abs(last[1] - RiverPathChapters.WEST_TERMINUS) > 1.0 then
        table.insert(errs, "route does not end at WEST_TERMINUS")
    end
    return #errs == 0, errs
end

return RiverPathChapters
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd roblox && lune run tests/run
```

Expected: PASS, with the new `RiverPathChapters` describes green and the pre-existing suite unchanged.

**If "each chapter's declared kind matches its measured grade" fails:** two chapters sit close to the 0.27 threshold — Mid climb measures 0.289 and Upper climb 0.279. Do **not** adjust `STEP_GRADE`. Change the chapter's `kind` to match what it measures, and note the change; the terrain decides, not the plan.

- [ ] **Step 5: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/builders/RiverPathChapters.luau roblox/tests/RiverPathChapters.spec.luau
git commit -m "feat(roblox): river path chapter definitions + invariant tests"
```

---

### Task 2: Draft the route markers and gate the line

**Files:**
- Create: `roblox/tools/studio/draftRiverPathMarkers.luau`

**Interfaces:**
- Consumes: `RiverPathChapters.CHAPTERS` control points from Task 1 (copied in as literals — Studio cannot require repo modules).
- Produces: `Workspace.PathDraft.River` containing markers named `River_<NN>`, contiguously indexed west-to-east ordering irrelevant, positions dragged by the user.

- [ ] **Step 1: Write the drafting script**

Create `roblox/tools/studio/draftRiverPathMarkers.luau`:

```luau
-- MCP/Edit: draggable waypoint markers for the RIVER PATH (Square -> upper pools).
-- Idempotent: rebuilds Workspace.PathDraft.River each run.
--
-- Seeded from the surveyed corridor profile in tools/builders/RiverPathChapters.luau
-- (MIRROR -- keep in sync). Drag them onto the line you want, then run
-- bakeRiverPathMarkers.luau and paste the result back into that module.
--
-- The legacy draftPathMarkers.luau seeds a DIFFERENT, superseded 2026-06 network and
-- rebuilds Workspace.PathDraft wholesale -- do not run it, it would destroy these.
local SEED = {
    { 60.0, 108.7, -8.0 },
    { 0.0, 109.9, -8.0 },
    { -80.0, 109.9, -8.0 },
    { -100.0, 134.4, -8.0 },
    { -160.0, 152.2, -8.0 },
    { -200.0, 159.4, -8.0 },
    { -240.0, 174.8, -8.0 },
    { -280.0, 174.8, -8.0 },
    { -300.0, 177.2, -8.0 },
    { -340.0, 186.9, -8.0 },
    { -360.0, 188.7, -8.0 },
    { -380.0, 199.5, -8.0 },
}

local draft = workspace:FindFirstChild("PathDraft")
if not draft then
    draft = Instance.new("Folder")
    draft.Name = "PathDraft"
    draft.Parent = workspace
end
local old = draft:FindFirstChild("River")
if old then
    old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "River"
folder.Parent = draft

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }

for i, p in ipairs(SEED) do
    local hit = workspace:Raycast(Vector3.new(p[1], 500, p[3]), Vector3.new(0, -1000, 0), rc)
    local y = hit and hit.Position.Y + 1 or p[2]
    local m = Instance.new("Part")
    m.Name = ("River_%02d"):format(i)
    m.Shape = Enum.PartType.Ball
    m.Size = Vector3.new(4, 4, 4)
    m.Anchored = true
    m.CanCollide = false
    m.CanQuery = false
    m.Material = Enum.Material.Neon
    m.Color = Color3.fromRGB(120, 255, 170)
    m.Position = Vector3.new(p[1], y, p[3])
    m.Parent = folder
    game:GetService("CollectionService"):AddTag(m, "DevMarker")
end

return ("drafted %d markers under Workspace.PathDraft.River"):format(#SEED)
```

- [ ] **Step 2: Run it in Studio**

Via MCP `execute_luau`, `datamodel_type: "Edit"`. Expected return: `drafted 12 markers under Workspace.PathDraft.River`.

- [ ] **Step 3: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/draftRiverPathMarkers.luau
git commit -m "feat(roblox): river path draft markers"
```

- [ ] **Step 4: USER GATE — the line**

Tell the user the markers are placed and ask them to drag them onto the route they want, adding or deleting markers as needed (duplicate one and bump its `_NN` to insert). Point out specifically:

- The markers are seeded straight down z = −8; the real line should meander with the river and hold a terrace above the water rather than tracking the exact floor.
- Pool 2 occupies x −371…−347 by z −29…+15 and the dock projects into it from the north-east shore at (−345.4, 190.2, −15.5) — the path must pass without cutting the dock's approach.
- The route must not descend anywhere; the tests enforce it.

**STOP. Do not carve or build anything until the user says the line is right.**

---

### Task 3: Bake the dragged markers into the chapter module

**Files:**
- Create: `roblox/tools/studio/bakeRiverPathMarkers.luau`
- Modify: `roblox/tools/builders/RiverPathChapters.luau` (the `control` lists only)

**Interfaces:**
- Consumes: `Workspace.PathDraft.River` markers from Task 2.
- Produces: updated `RiverPathChapters.CHAPTERS[*].control`, still satisfying every Task 1 test.

- [ ] **Step 1: Write the bake script**

Create `roblox/tools/studio/bakeRiverPathMarkers.luau`:

```luau
-- MCP/Edit: read Workspace.PathDraft.River -> print paste-ready control lists for
-- tools/builders/RiverPathChapters.luau, split at the chapter boundaries.
--
-- Boundaries are x values, not marker indices, so the user may add or delete markers
-- freely. A marker landing exactly on a boundary is emitted into BOTH adjoining
-- chapters, which is what makes them contiguous (the Task 1 test requires it).
local BOUNDARIES = { -80, -100, -240, -300 }
local NAMES = { "RiverTerracePath", "RiverFirstRiser", "RiverMidClimb", "RiverBenchShelf", "RiverUpperClimb" }

local folder = workspace:FindFirstChild("PathDraft")
folder = folder and folder:FindFirstChild("River")
if not folder then
    return "no Workspace.PathDraft.River -- run draftRiverPathMarkers.luau first"
end

local pts = {}
for _, m in folder:GetChildren() do
    if m:IsA("BasePart") then
        table.insert(pts, m.Position)
    end
end
table.sort(pts, function(a, b)
    return a.X > b.X
end)
if #pts < 2 then
    return "need at least two markers"
end

local function chapterIndex(x)
    for i, b in ipairs(BOUNDARIES) do
        if x > b then
            return i
        end
    end
    return #BOUNDARIES + 1
end

local buckets = {}
for i = 1, #NAMES do
    buckets[i] = {}
end
for _, p in ipairs(pts) do
    table.insert(buckets[chapterIndex(p.X)], p)
end
-- stitch: every chapter after the first begins at its predecessor's last point
for i = 2, #NAMES do
    local prev = buckets[i - 1]
    if #prev > 0 then
        table.insert(buckets[i], 1, prev[#prev])
    end
end

local out = {}
for i, name in ipairs(NAMES) do
    table.insert(out, ("-- %s"):format(name))
    table.insert(out, "        control = {")
    for _, p in ipairs(buckets[i]) do
        table.insert(out, ("            { %.1f, %.1f, %.1f },"):format(p.X, p.Y, p.Z))
    end
    table.insert(out, "        },")
end
return table.concat(out, "\n")
```

- [ ] **Step 2: Run it and paste the result**

Run via MCP `execute_luau` in Edit. Replace each chapter's `control` list in `roblox/tools/builders/RiverPathChapters.luau` with the corresponding block. Change nothing else in that file.

- [ ] **Step 3: Run the tests**

```bash
cd roblox && lune run tests/run
```

Expected: PASS. The Task 1 invariants now guard the user's real line.

**If "the route climbs westward and never descends" fails:** a marker was dragged below its eastern neighbour. Report the offending chapter and control index to the user and ask them to raise it — do not silently clamp the Y.

**If a `kind` mismatch appears:** update that chapter's `kind` to the measured value and say so in the commit message. A terrace that turned into a climb must be built by the stair engine, not forced flat.

- [ ] **Step 4: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/builders/RiverPathChapters.luau roblox/tools/studio/bakeRiverPathMarkers.luau
git commit -m "feat(roblox): bake the user's river path line into the chapters"
```

---

### Task 4: Chapter 1 — the Square terrace (flat)

The first chapter proves the whole recipe on the easiest ground: 140 studs, near dead level, next to the Square. Everything learned here applies to the remaining four.

**Files:**
- Create: `roblox/tools/studio/carveRiverPath.luau`
- Modify: `roblox/tools/studio/buildFlatShelfPath.luau` (`CONFIG.paths`)
- Modify: `roblox/tools/studio/buildBambooRailing.luau` (`RUNS`)
- Modify: `roblox/tools/studio/buildChochinPole.luau` (`CONFIG`)

**Interfaces:**
- Consumes: `RiverPathChapters.CHAPTERS[1].control` (baked in Task 3), copied as literals into the Studio scripts.
- Produces: `Workspace.CanyonWorld.Paths.RiverTerracePath` containing `Riser_<i>[a|b]`, `Step_<i>` (bed; `RightVector` = cross-stream, top = tread − 0.05) and `Flags_<n>` published meshes. `Step_<i>` is the downstream contract every dressing builder reads.

- [ ] **Step 1: Write the carve script**

Create `roblox/tools/studio/carveRiverPath.luau`:

```luau
-- MCP/Edit: rough-carve a walkable grade along one river-path chapter's centerline,
-- backing the region up first. The user finish-smooths afterwards (recipe section 0.4c).
--
-- Recipe section 5: boxes must be >= 4 studs in EVERY dimension or the voxel resolution
-- carves nothing at all.
local CONFIG = {
    name = "RiverTerracePath",
    control = {
        { 60.0, 108.7, -8.0 },
        { 0.0, 109.9, -8.0 },
        { -80.0, 109.9, -8.0 },
    },
    width = 10, -- carve wider than the 5.8 bed so the shoulders are workable
    depth = 5,
    spacing = 4,
}

local Terrain = workspace.Terrain
local SS = game:GetService("ServerStorage")

-- backup first, always
local minv, maxv = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
for _, p in ipairs(CONFIG.control) do
    local v = Vector3.new(p[1], p[2], p[3])
    minv = Vector3.new(math.min(minv.X, v.X), math.min(minv.Y, v.Y), math.min(minv.Z, v.Z))
    maxv = Vector3.new(math.max(maxv.X, v.X), math.max(maxv.Y, v.Y), math.max(maxv.Z, v.Z))
end
local pad = Vector3.new(CONFIG.width + 8, CONFIG.depth + 20, CONFIG.width + 8)
local region = Region3.new(minv - pad, maxv + pad):ExpandToGrid(4)
local backupName = ("RiverCarve_%s_Backup"):format(CONFIG.name)
local existing = SS:FindFirstChild(backupName)
if existing then
    return ("backup %s already exists -- carve already run; delete it to re-carve"):format(backupName)
end
local backup = Terrain:CopyRegion(region)
backup.Name = backupName
backup.Parent = SS

-- carve: march the polyline, fill an air box at each sample
local carved = 0
for i = 2, #CONFIG.control do
    local a = CONFIG.control[i - 1]
    local b = CONFIG.control[i]
    local d = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
    local n = math.max(1, math.floor(d / CONFIG.spacing))
    for s = 0, n do
        local t = s / n
        local p = Vector3.new(
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t,
            a[3] + (b[3] - a[3]) * t
        )
        local size = Vector3.new(CONFIG.width, CONFIG.depth, CONFIG.width)
        Terrain:FillBlock(CFrame.new(p + Vector3.new(0, CONFIG.depth / 2, 0)), size, Enum.Material.Air)
        carved += 1
    end
end
return ("backed up to ServerStorage.%s; carved %d blocks along %s"):format(backupName, carved, CONFIG.name)
```

- [ ] **Step 2: Run the carve in Studio**

Via MCP `execute_luau`, Edit datamodel. Expected return names the backup and a non-zero block count.

- [ ] **Step 3: USER GATE — smooth the carve**

Ask the user to finish-smooth the rough cut in Studio (recipe §0.3 — terrain is a handoff). **STOP until they confirm.**

- [ ] **Step 4: Add the chapter to the flat-shelf builder**

In `roblox/tools/studio/buildFlatShelfPath.luau`, append to `CONFIG.paths`:

```luau
        {
            -- River path chapter 1: the Square terrace. Near dead level over ~140 studs.
            outModel = "RiverTerracePath",
            control = {
                { 60.0, 108.7, -8.0 },
                { 0.0, 109.9, -8.0 },
                { -80.0, 109.9, -8.0 },
            },
            treadTarget = 6.0,
        },
```

Replace the `control` literals with the Task 3 baked values.

- [ ] **Step 5: Build it and verify the contract parts exist**

Run `buildFlatShelfPath.luau` via MCP in Edit, then verify:

```luau
local m = workspace.CanyonWorld.Paths:FindFirstChild("RiverTerracePath")
if not m then return "MISSING RiverTerracePath" end
local risers, beds, flags = 0, 0, 0
for _, c in ipairs(m:GetChildren()) do
    if c.Name:match("^Riser_") then risers += 1
    elseif c.Name:match("^Step_") then beds += 1
    elseif c.Name:match("^Flags_") then flags += 1 end
end
return ("risers %d  beds %d  flagmeshes %d"):format(risers, beds, flags)
```

Expected: roughly 23 beds (140 studs ÷ 6.0 tread), a similar or greater riser count, and at least one flag mesh.

- [ ] **Step 6: Dress it — railing and lanterns**

Add to `buildBambooRailing.luau`'s `RUNS`:

```luau
    { path = "RiverTerracePath", prefix = "RiverTerrace", i0 = 1, i1 = nil, edgeSign = -1 },
```

`edgeSign = -1` puts the railing on the river (open) side; flip to `1` if the build lands on the wrong edge. Then add to `buildChochinPole.luau`'s `CONFIG`:

```luau
    path = "RiverTerracePath",
    timberPrefix = "Riser",
    interval = 22,
    posJitter = 0.6,
    uphillOffset = 4.2,
    uphillSign = 1,
    downhillFrac = 0.3,
    dhMaxDrop = 6,
    seed = 20260729,
```

`interval = 22` matches `CanyonPath.LANTERN_INTERVAL`; `uphillOffset = 4.2` clears the 5.8-wide bed by ~1.3 studs, satisfying the walls-register-to-the-built-edge rule.

Run both via MCP in Edit.

- [ ] **Step 7: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/carveRiverPath.luau roblox/tools/studio/buildFlatShelfPath.luau \
        roblox/tools/studio/buildBambooRailing.luau roblox/tools/studio/buildChochinPole.luau
git commit -m "feat(roblox): river path chapter 1 - the Square terrace"
```

- [ ] **Step 8: USER GATE — walk it**

Ask the user to save the place and walk the terrace in Play. Report only what you built; do not judge how it looks. **STOP.** Feed their notes back as edits to this chapter before starting Task 5 — the remaining four chapters inherit whatever is fixed here.

---

### Task 5: Chapter 2 — the first riser (stair)

24.5 studs of climb over 20 of run. The threshold out of the Square, and the steepest thing on the route.

**Files:**
- Modify: `roblox/tools/studio/carveRiverPath.luau` (`CONFIG`)
- Modify: `roblox/tools/studio/buildIshidanStairs.luau` (add `CONFIG.presets` + `CONFIG.active`)
- Modify: `roblox/tools/studio/buildBambooRailing.luau`, `buildChochinPole.luau`

**Interfaces:**
- Consumes: `RiverPathChapters.CHAPTERS[2].control`.
- Produces: `Workspace.CanyonWorld.Paths.RiverFirstRiser` with the same `Riser_<i>` / `Step_<i>` / `Flags_<n>` contract as Task 4.

- [ ] **Step 1: Refactor `buildIshidanStairs.luau` to hold presets**

The file currently carries a single `CONFIG` describing whichever path was built last, so only one chapter can ever be reproducible from it. Introduce a preset table **without touching any layout logic**. Replace the `outModel` / `control` / `footY` / `headY` fields at the top of `CONFIG` with:

```luau
-- Each entry is one buildable stretch. Set CONFIG.active and run.
local PRESETS = {
    FarWall5063Path = {
        outModel = "FarWall5063Path",
        control = {
            { -82.4, 178.0, -72.4 },
            { -116.5, 180.4, -79.7 },
            { -151.5, 182.0, -75.0 },
        },
        footY = 178.0,
        headY = 182.0,
    },
    RiverFirstRiser = {
        outModel = "RiverFirstRiser",
        control = {
            { -80.0, 109.9, -8.0 },
            { -100.0, 134.4, -8.0 },
        },
        footY = 109.9,
        headY = 134.4,
    },
}

local ACTIVE = "RiverFirstRiser"
```

and make `CONFIG` read from it:

```luau
local CONFIG = {
    outModel = PRESETS[ACTIVE].outModel,
    control = PRESETS[ACTIVE].control,
    footY = PRESETS[ACTIVE].footY,
    headY = PRESETS[ACTIVE].headY,
    riserTarget = 0.6,
    -- ... every other field unchanged ...
}
```

The `FarWall5063Path` preset preserves the previously-built values verbatim so the existing path stays reproducible. Replace `RiverFirstRiser`'s control with the Task 3 baked values.

- [ ] **Step 1b: Fix the builder's parenting — it violates the sweep convention**

`buildIshidanStairs.luau` parents its output to `workspace` **root**:

```luau
local old = workspace:FindFirstChild(CONFIG.outModel)   -- line ~386
...
model.Parent = workspace                                 -- line ~392
```

Its sibling `buildFlatShelfPath.luau` does it correctly (`local paths = workspace.CanyonWorld.Paths; model.Parent = paths`) and its header states the rule outright: *"Parents under Workspace.CanyonWorld.Paths (NEVER Workspace root — the sweep convention)."* The stair builder predates the 2026-07-08 workspace reorg and was never updated; the existing `FarWall5063Path` sits under `CanyonWorld.Paths` because it was moved by hand afterwards.

Change both lines to match the sibling:

```luau
local paths = workspace.CanyonWorld.Paths
local old = paths:FindFirstChild(CONFIG.outModel)
...
model.Parent = paths
```

and update the file header's `-- destroys and rebuilds Workspace.<CONFIG.outModel>.` to say `Workspace.CanyonWorld.Paths.<CONFIG.outModel>`.

Verify no stray model was left at the root by a previous run:

```luau
local strays = {}
for _, c in ipairs(workspace:GetChildren()) do
    if c:IsA("Model") and c:FindFirstChild("Step_1") then
        table.insert(strays, c.Name)
    end
end
return #strays == 0 and "no path models at Workspace root" or ("STRAYS: " .. table.concat(strays, ", "))
```

Expected: `no path models at Workspace root`. If any are listed, move them under `CanyonWorld.Paths` before continuing — `verifyWorkspaceConvention.luau` is a pre-publish gate and a root-level path model will fail it.

- [ ] **Step 2: Verify the refactor changed nothing for the existing path**

Set `ACTIVE = "FarWall5063Path"` and confirm the resolved config matches the pre-refactor literals:

```luau
-- paste the file's PRESETS/ACTIVE/CONFIG head, then:
return ("%s foot %.1f head %.1f pts %d"):format(CONFIG.outModel, CONFIG.footY, CONFIG.headY, #CONFIG.control)
```

Expected exactly: `FarWall5063Path foot 178.0 head 182.0 pts 3`. Then set `ACTIVE = "RiverFirstRiser"`.

- [ ] **Step 3: Carve**

Set `carveRiverPath.luau`'s `CONFIG.name` to `"RiverFirstRiser"` and `CONFIG.control` to the chapter's baked points, then run in Edit. The backup guard means a re-run is refused until the previous backup is deleted — that is intentional.

- [ ] **Step 4: USER GATE — smooth the carve.** **STOP until confirmed.**

- [ ] **Step 5: Build the stair**

Run `buildIshidanStairs.luau` in Edit. Verify:

```luau
local m = workspace.CanyonWorld.Paths:FindFirstChild("RiverFirstRiser")
if not m then return "MISSING RiverFirstRiser" end
local beds = 0
for _, c in ipairs(m:GetChildren()) do
    if c.Name:match("^Step_") then beds += 1 end
end
return ("beds %d (expect ~%d at riserTarget 0.6 over 24.5 studs)"):format(beds, math.floor(24.5 / 0.6))
```

Expected: ~41 beds. A count near 1 means the stair collapsed and the chapter should have been `flat`; a count in the hundreds means `footY`/`headY` are wrong.

- [ ] **Step 6: Dress it**

Add to `buildBambooRailing.luau`'s `RUNS`:

```luau
    { path = "RiverFirstRiser", prefix = "RiverFirstRiser", i0 = 1, i1 = nil, edgeSign = -1 },
```

and add a `CONNECTORS` entry bridging `RiverTerracePath` to `RiverFirstRiser` so the railing reads continuous across the chapter seam. Add the matching `buildChochinPole.luau` entry with `path = "RiverFirstRiser"`, `seed = 20260730`, and the same interval and offsets as Task 4.

- [ ] **Step 7: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/buildIshidanStairs.luau roblox/tools/studio/carveRiverPath.luau \
        roblox/tools/studio/buildBambooRailing.luau roblox/tools/studio/buildChochinPole.luau
git commit -m "feat(roblox): river path chapter 2 - the first riser threshold"
```

- [ ] **Step 8: USER GATE — walk the threshold.** **STOP.**

---

### Task 6: Chapter 3 — the mid climb (stair)

140 studs at ~29%, the longest single stretch. Measures 0.289 against the 0.27 step threshold, so it is only just a stair.

**Files:** same four Studio scripts as Task 5.

**Interfaces:**
- Consumes: `RiverPathChapters.CHAPTERS[3].control`.
- Produces: `Workspace.CanyonWorld.Paths.RiverMidClimb`.

- [ ] **Step 1: Add the preset**

In `buildIshidanStairs.luau`, add to `PRESETS` (baked control from Task 3):

```luau
    RiverMidClimb = {
        outModel = "RiverMidClimb",
        control = {
            { -100.0, 134.4, -8.0 },
            { -160.0, 152.2, -8.0 },
            { -200.0, 159.4, -8.0 },
            { -240.0, 174.8, -8.0 },
        },
        footY = 134.4,
        headY = 174.8,
    },
```

Set `ACTIVE = "RiverMidClimb"`.

- [ ] **Step 2: Set landings**

140 studs of continuous stair is too long without a rest. `Landing` is
`{ frac: number, len: number }` — `frac` is the fraction along the chapter's arc
(clamped internally to 0.05…0.95) and `len` is the flat landing's length in studs. Set:

```luau
    landings = {
        { frac = 0.34, len = 5 },
        { frac = 0.67, len = 5 },
    },
```

Two landings split the climb into three flights of roughly 13 studs of rise each. `len = 5`
is a shade under one tread pitch (`treadTarget` 6.0 on the flat chapters), so a landing
reads as a pause rather than as a terrace.

- [ ] **Step 3: Carve, then USER GATE — smooth.** **STOP until confirmed.**

- [ ] **Step 4: Build and verify**

```luau
local m = workspace.CanyonWorld.Paths:FindFirstChild("RiverMidClimb")
if not m then return "MISSING RiverMidClimb" end
local beds = 0
for _, c in ipairs(m:GetChildren()) do
    if c.Name:match("^Step_") then beds += 1 end
end
return ("beds %d (expect ~%d)"):format(beds, math.floor(40.4 / 0.6))
```

Expected: ~67 beds.

- [ ] **Step 5: Dress** — railing run, connector from `RiverFirstRiser`, chōchin entry with `seed = 20260731`.

- [ ] **Step 6: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/
git commit -m "feat(roblox): river path chapter 3 - the mid climb"
```

- [ ] **Step 7: USER GATE.** **STOP.**

---

### Task 7: Chapter 4 — the bench shelf (flat) and its vantage

60 studs of natural flat, two-thirds of the way west. The spec calls for a bench, a lantern and a view back east.

**Files:**
- Modify: `roblox/tools/studio/buildFlatShelfPath.luau`, `carveRiverPath.luau`, `buildBambooRailing.luau`, `buildChochinPole.luau`

**Interfaces:**
- Consumes: `RiverPathChapters.CHAPTERS[4].control`; `ServerStorage.RockLibrary` (49 rock models) for the seat.
- Produces: `Workspace.CanyonWorld.Paths.RiverBenchShelf`, plus a widened landing and a seat rock.

- [ ] **Step 1: Add the chapter to `buildFlatShelfPath.luau`'s `CONFIG.paths`**

```luau
        {
            -- River path chapter 4: the bench. Natural flat between two climbs.
            outModel = "RiverBenchShelf",
            control = {
                { -240.0, 174.8, -8.0 },
                { -280.0, 174.8, -8.0 },
                { -300.0, 177.2, -8.0 },
            },
            treadTarget = 6.0,
        },
```

- [ ] **Step 2: Carve, then USER GATE — smooth.** **STOP until confirmed.**

- [ ] **Step 3: Build and dress** as Task 4 steps 5–6, with `seed = 20260801` for the chōchin.

- [ ] **Step 4: Place the vantage seat**

A flat rock from the library, set on the river side of the shelf's midpoint, facing back east down the canyon. No new builder — furniture here is one placed rock:

```luau
local SS = game:GetService("ServerStorage")
local lib = SS:FindFirstChild("RockLibrary")
if not lib then return "no ServerStorage.RockLibrary" end
local paths = workspace.CanyonWorld.Paths
local shelf = paths:FindFirstChild("RiverBenchShelf")
if not shelf then return "build RiverBenchShelf first" end

-- midpoint bed of the shelf
local beds = {}
for _, c in ipairs(shelf:GetChildren()) do
    if c.Name:match("^Step_(%d+)$") then table.insert(beds, c) end
end
table.sort(beds, function(a, b) return a.Position.X > b.Position.X end)
if #beds == 0 then return "no Step_ beds found" end
local mid = beds[math.ceil(#beds / 2)]

local src = lib:GetChildren()[1]
local seat = src:Clone()
seat.Name = "BenchSeat"
-- river side is -RightVector of the bed (cross-stream contract); 4.6 clears the 5.8 bed
seat:PivotTo(CFrame.new(mid.Position + mid.CFrame.RightVector * -4.6 + Vector3.new(0, 0.4, 0)))
seat.Parent = shelf
return ("seat placed at %s from %s"):format(tostring(seat:GetPivot().Position), src.Name)
```

Pick a genuinely flat-topped rock by inspecting `RockLibrary` first rather than taking `GetChildren()[1]` blindly; report which one you used.

- [ ] **Step 5: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/
git commit -m "feat(roblox): river path chapter 4 - the bench shelf and vantage"
```

- [ ] **Step 6: USER GATE — sit and look east.** **STOP.**

---

### Task 8: Chapter 5 — the upper climb (stair)

80 studs rising 22.3, past the falls-pool dock at x −345, terminating at x −380 where `NW80FallsStair` takes over. The wildest stretch, and the one whose `reach` is narrowest under the care model.

**Files:** the four Studio scripts.

**Interfaces:**
- Consumes: `RiverPathChapters.CHAPTERS[5].control`; `RiverPathChapters.WEST_TERMINUS = -380`.
- Produces: `Workspace.CanyonWorld.Paths.RiverUpperClimb`.

- [ ] **Step 1: Add the preset and set `ACTIVE = "RiverUpperClimb"`**

```luau
    RiverUpperClimb = {
        outModel = "RiverUpperClimb",
        control = {
            { -300.0, 177.2, -8.0 },
            { -340.0, 186.9, -8.0 },
            { -360.0, 188.7, -8.0 },
            { -380.0, 199.5, -8.0 },
        },
        footY = 177.2,
        headY = 199.5,
    },
```

- [ ] **Step 2: Check the dock clearance before carving**

```luau
local dock = Vector3.new(-345.4, 190.2, -15.5)
local pts = {
    Vector3.new(-300, 177.2, -8), Vector3.new(-340, 186.9, -8),
    Vector3.new(-360, 188.7, -8), Vector3.new(-380, 199.5, -8),
}
local best = 1e9
for i = 2, #pts do
    for t = 0, 1, 0.05 do
        local p = pts[i - 1]:Lerp(pts[i], t)
        best = math.min(best, (p - dock).Magnitude)
    end
end
return ("closest approach to the dock: %.1f studs"):format(best)
```

The dock's garden radius is 15 studs (spec §2). A closest approach under ~8 studs means the path would land on the dock's approach — report it and ask the user to move the markers rather than carving through.

- [ ] **Step 3: Carve, then USER GATE — smooth.** **STOP until confirmed.**

- [ ] **Step 4: Build and verify the terminus**

```luau
local m = workspace.CanyonWorld.Paths:FindFirstChild("RiverUpperClimb")
if not m then return "MISSING RiverUpperClimb" end
local beds, westmost = 0, 1e9
for _, c in ipairs(m:GetChildren()) do
    if c.Name:match("^Step_") then
        beds += 1
        westmost = math.min(westmost, c.Position.X)
    end
end
local stair = workspace.CanyonWorld.Paths:FindFirstChild("NW80FallsStair")
local gap = stair and (westmost - stair:GetBoundingBox().Position.X) or -1
return ("beds %d  westmost x %.1f  gap to NW80FallsStair centre %.1f"):format(beds, westmost, gap)
```

Expected: ~37 beds and a westmost x near −380. The route should reach toward `NW80FallsStair` without overlapping it.

- [ ] **Step 5: Dress** — railing run, connector from `RiverBenchShelf`, chōchin with `seed = 20260802`.

- [ ] **Step 6: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/
git commit -m "feat(roblox): river path chapter 5 - the upper climb to the falls"
```

- [ ] **Step 7: USER GATE — walk the whole route end to end.** **STOP.**

---

### Task 9: Retaining walls on the floating spans

Where a bed's underside stands proud of the terrain, it needs a wall; where the path cuts into a bank, it needs timber lagging. Both builders find their own spans — they only need to be told which paths to look at.

**Files:**
- Modify: `roblox/tools/studio/buildIshigakiWalls.luau` (`CONFIG.paths`)
- Modify: `roblox/tools/studio/buildTimberRetainingWall.luau` (`CONFIG.walls`)

**Interfaces:**
- Consumes: the five `Step_<i>` bed sets built in Tasks 4–8.
- Produces: `Workspace.RetainingWalls` entries and `CanyonWorld/Structures/RetainingWalls/TimberWall_<model>_<first>_<last>`.

- [ ] **Step 1: Survey which spans actually float**

```luau
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { workspace.CanyonWorld.Paths, workspace.CanyonWorld.Foliage }
for _, name in ipairs({
    "RiverTerracePath", "RiverFirstRiser", "RiverMidClimb", "RiverBenchShelf", "RiverUpperClimb",
}) do
    local m = workspace.CanyonWorld.Paths:FindFirstChild(name)
    if m then
        local worst, n = 0, 0
        for _, c in ipairs(m:GetChildren()) do
            if c.Name:match("^Step_") then
                local under = c.Position - Vector3.new(0, c.Size.Y / 2, 0)
                local hit = workspace:Raycast(under + Vector3.new(0, 1, 0), Vector3.new(0, -60, 0), params)
                if hit then
                    local gap = under.Y - hit.Position.Y
                    if gap > 1.5 then n += 1 end
                    worst = math.max(worst, gap)
                end
            end
        end
        print(("%-20s floating beds %3d  worst %.1f"):format(name, n, worst))
    end
end
return "survey done"
```

- [ ] **Step 2: Add the floating paths to `buildIshigakiWalls.luau`'s `CONFIG.paths`** and run it. Only add paths the survey showed floating beds for — an empty span list builds nothing and wastes a gate.

- [ ] **Step 3: Add cut faces to `buildTimberRetainingWall.luau`'s `CONFIG.walls`**, one entry per contiguous cut run, using `{ model, first, last, edgeSign, offset, cap, seed }` with `first`/`last` taken from the `Step_<i>` indices the survey reported.

- [ ] **Step 4: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
git add roblox/tools/studio/buildIshigakiWalls.luau roblox/tools/studio/buildTimberRetainingWall.luau
git commit -m "feat(roblox): retaining walls along the river path"
```

- [ ] **Step 5: USER GATE.** **STOP.**

---

### Task 10: As-built record, place save, and notes

**Files:**
- Modify: `docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md`
- Modify: `~/.claude/projects/-Users-jonlabrie-Desktop-ClaudeCode-Roshambo-26/memory/` (new memory + `MEMORY.md` index line)

- [ ] **Step 1: Collect the as-built numbers**

```luau
local out = {}
for _, name in ipairs({
    "RiverTerracePath", "RiverFirstRiser", "RiverMidClimb", "RiverBenchShelf", "RiverUpperClimb",
}) do
    local m = workspace.CanyonWorld.Paths:FindFirstChild(name)
    if m then
        local beds, risers, flags = 0, 0, 0
        for _, c in ipairs(m:GetChildren()) do
            if c.Name:match("^Step_") then beds += 1
            elseif c.Name:match("^Riser_") then risers += 1
            elseif c.Name:match("^Flags_") then flags += 1 end
        end
        local cf, size = m:GetBoundingBox()
        table.insert(out, ("%-20s beds %3d risers %3d flagmeshes %2d  span %.0f x %.0f"):format(
            name, beds, risers, flags, size.X, size.Z))
    else
        table.insert(out, ("%-20s MISSING"):format(name))
    end
end
return table.concat(out, "\n")
```

- [ ] **Step 2: Append an as-built section to the spec** (recipe §0.6) recording per-chapter bed/riser/flag counts, published flag-mesh asset IDs, the final baked control points, and every value that changed from this plan during execution.

- [ ] **Step 3: Write the memory note**

Create a `zendojo-river-path` memory covering: the chapter structure and why the terrain dictated it, the `PRESETS`/`ACTIVE` pattern added to `buildIshidanStairs.luau`, the carve backup convention, and anything that bit during execution. Link `[[zendojo-build-recipes]]`, `[[zendojo-dock-uguisu]]` and `[[forest-preserve-foliage]]`. Add one index line to `MEMORY.md`.

- [ ] **Step 4: Remind the user to SAVE AND PUBLISH the place**

Every chapter is place-only. Nothing built in Tasks 4–9 survives a Studio close without a save. Also run the pre-publish gate:

```bash
# in Studio, Edit datamodel
tools/studio/verifyWorkspaceConvention.luau
```

Expected: `[convention] PASS`.

- [ ] **Step 5: Commit the docs**

```bash
git add docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md
git commit -m "docs(roblox): river path as-built record"
```

---

## Out of scope

- **The floor re-plant** (spec §6 sub-project 3). The path exists so `reach` can be measured from it; planting is a separate plan.
- **The water-margin palette** (spec §6 sub-project 2). Independent; can run in parallel with this plan.
- **`ZenGravelFine`.** Belongs to sub-project 2. These chapters use `bedVariant = "ZenGravel1"` and fall back to Concrete exactly as all 356 existing beds do — that is the approved look, per spec §7.2.
- **The falls headwall** (x −420…−440). `NW80FallsStair` already serves it.
- **Bridges or river crossings.** The route holds a terrace above the water on one bank (spec §5).
- **`buildPaths.luau`.** A superseded 2026-06-19 snapshot targeting `RoshamboStage.CanyonPaths`, which does not exist. Do not run or revive it.

## Self-Review Notes

**Spec coverage.** §5's chapter table maps to Tasks 4–8 one for one; the west-end tie-in is verified in Task 8 step 4; the bench and its eastward view are Task 7 step 4; lanterns for the read-from-above are dressed per chapter; the marker-driven route is Tasks 2–3. §5's "benches and vantages at intervals" is honoured only at the bench shelf — intermediate seating is left to a dressing pass rather than invented here.

**A defect this review caught.** `buildIshidanStairs.luau` parents its output to `workspace` root, not `CanyonWorld.Paths` — it predates the 2026-07-08 reorg and its sibling `buildFlatShelfPath.luau` gets it right. Three of the five chapters use the stair builder, so unfixed this plan would have put them in the wrong place and failed the pre-publish convention gate. Task 5 step 1b fixes the builder and sweeps for strays.

**Known soft spot.** Task 7 step 4 picks a seat rock by inspection rather than by index; `RockLibrary` holds 49 models and only some are flat-topped. Flagged rather than papered over — the implementer must look and report which they used.

**Threshold risk.** Mid climb (0.289) and Upper climb (0.279) sit just above `CanyonPath.STEP_GRADE` (0.27). If the user's dragged line eases either grade, that chapter flips to `flat` and must be built by `buildFlatShelfPath` instead. Task 3 step 3 handles this explicitly.
