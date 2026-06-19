# ZenDojo Canyon Paths Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the canyon's lantern-lined, railed stone/timber circulation network — a circumnavigable trunk loop up both gorge walls plus a floor path and an overlook spur — that teahouses (next sub-project) branch off via private spur paths.

**Architecture:** A pure, Lune-tested builder `CanyonPath.luau` generates a route's geometry (invisible smooth collision ramp for walkability + decorative pavers/steps + rails + interval lanterns) from a polyline of waypoints. Routes are authored as draggable markers in Studio (agent drafts, user adjusts), baked into a `paths` block in `ArenaLayout`, then materialized by an MCP snap pass `buildPaths.luau` that raycasts each point onto the live terrain. The Studio pass mirrors `CanyonPath`'s piece logic because MCP-run Studio scripts cannot `require` repo modules — the two are kept in sync, with `CanyonPath`'s tests as the canonical spec (same pattern as `GameRules.ts` ↔ `GameRules.luau`).

**Tech Stack:** Luau, Lune (headless tests via `lune run tests/run`), Rojo, Roblox Studio MCP (`execute_luau`, raycasting), `Spec.luau` part-spec helpers, `StoneLantern.luau`.

---

## File Structure

- **Create** `roblox/tools/builders/CanyonPath.luau` — pure builder. Public API:
  - `CanyonPath.classifySegment(a, b) -> "paver" | "steps"`
  - `CanyonPath.placeAlong(points, spacing, includeEnds) -> { { pos = {x,y,z}, dir = {ux,uz} } }`
  - `CanyonPath.lanternPole(palette, at) -> PartSpec` (Model)
  - `CanyonPath.build(palette, route) -> PartSpec` (Model); `route = { name, class, points }`, `class` is `"trunk"` or `"spur"`
  - `CanyonPath.landing(palette, at, radius) -> PartSpec` (Model)
  - constants: `TRUNK_WIDTH=8`, `SPUR_WIDTH=5`, `RAIL_HEIGHT=3`, `RAIL_SPACING=6`, `LANTERN_INTERVAL=22`, `STEP_GRADE=0.27`
- **Create** `roblox/tests/CanyonPath.spec.luau` — Lune unit tests (auto-discovered by `tests/run.luau`).
- **Modify** `roblox/tools/builders/ArenaLayout.luau` — add a `paths` block (the baked waypoint polylines).
- **Create** `roblox/tools/studio/draftPathMarkers.luau` — MCP/Edit: drop draggable neon waypoint markers for first-pass routes.
- **Create** `roblox/tools/studio/bakePathMarkers.luau` — MCP/Edit: read marker positions, print a ready-to-paste `paths = {…}` table.
- **Create** `roblox/tools/studio/buildPaths.luau` — MCP/Edit: densify + raycast-snap + materialize the paths into `workspace.RoshamboStage.CanyonPaths`.

Reference existing patterns while implementing: `roblox/tools/builders/StoneLantern.luau` (palette + PointLight child spec), `roblox/tools/builders/Spec.luau` (`part`/`model`/`cframe`/`segment`/`ROT`), `roblox/tests/Overlook.spec.luau` (test style), `roblox/tools/studio/buildDowncanyon.luau` (MCP snap-pass + raycast pattern).

Verification commands (run from `roblox/`):
- Tests: `lune run tests/run`
- Format/lint: `stylua --check src tests tools && selene src tools`

---

### Task 1: Segment grade classification

**Files:**
- Create: `roblox/tools/builders/CanyonPath.luau`
- Test: `roblox/tests/CanyonPath.spec.luau`

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/CanyonPath.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local CanyonPath = require("../tools/builders/CanyonPath")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("CanyonPath.classifySegment", function()
    test("gentle grade is a paver run", function()
        expect(CanyonPath.classifySegment({ 0, 10, 0 }, { 10, 11, 0 })).toBe("paver")
    end)
    test("steep grade is steps", function()
        expect(CanyonPath.classifySegment({ 0, 0, 0 }, { 2, 10, 0 })).toBe("steps")
    end)
    test("vertical/zero-run is steps", function()
        expect(CanyonPath.classifySegment({ 0, 0, 0 }, { 0, 10, 0 })).toBe("steps")
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `CanyonPath` module not found / `classifySegment` nil.

- [ ] **Step 3: Write minimal implementation**

Create `roblox/tools/builders/CanyonPath.luau`:

```luau
--!strict
-- Canyon circulation builder: from a polyline of waypoints, emit a route's geometry —
-- an invisible smooth collision ramp (walkability) under decorative pavers/steps, slim
-- timber rails on both edges, and warm lanterns at intervals. Pure + deterministic
-- (no math.random) so it is Lune-tested; the Studio snap pass (buildPaths.luau) mirrors
-- this logic since MCP Studio scripts cannot require repo modules — keep them in sync.
local Spec = require("./Spec")
local StoneLantern = require("./StoneLantern")

local CanyonPath = {}

CanyonPath.TRUNK_WIDTH = 8
CanyonPath.SPUR_WIDTH = 5
CanyonPath.RAIL_HEIGHT = 3
CanyonPath.RAIL_SPACING = 6
CanyonPath.LANTERN_INTERVAL = 22
CanyonPath.STEP_GRADE = 0.27 -- tan(~15°): rise/run above this => steps

local function hyp(dx: number, dz: number): number
    return math.sqrt(dx * dx + dz * dz)
end

function CanyonPath.classifySegment(a: { number }, b: { number }): string
    local run = hyp(b[1] - a[1], b[3] - a[3])
    local rise = math.abs(b[2] - a[2])
    if run < 1e-4 then
        return "steps"
    end
    return rise / run > CanyonPath.STEP_GRADE and "steps" or "paver"
end

return CanyonPath
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (3 classifySegment tests green).

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/CanyonPath.luau roblox/tests/CanyonPath.spec.luau
git commit -m "feat(roblox): CanyonPath.classifySegment (paver vs steps by grade)"
```

---

### Task 2: Even spacing along a polyline (`placeAlong`)

**Files:**
- Modify: `roblox/tools/builders/CanyonPath.luau`
- Test: `roblox/tests/CanyonPath.spec.luau`

- [ ] **Step 1: Write the failing test** — append to `CanyonPath.spec.luau`:

```luau
describe("CanyonPath.placeAlong", function()
    local line = { { 0, 0, 0 }, { 60, 0, 0 } }
    test("interior samples every spacing, ends excluded", function()
        local s = CanyonPath.placeAlong(line, 20, false)
        expect(#s).toBe(2) -- at 20 and 40 (60 is not < total)
    end)
    test("includeEnds adds start and end", function()
        local s = CanyonPath.placeAlong(line, 20, true)
        expect(#s).toBe(4) -- 0, 20, 40, 60
    end)
    test("dir is the unit heading of the segment", function()
        local s = CanyonPath.placeAlong(line, 20, false)
        expect(s[1].dir[1]).toBeCloseTo(1)
        expect(s[1].dir[2]).toBeCloseTo(0)
    end)
    test("samples interpolate position", function()
        local s = CanyonPath.placeAlong(line, 20, false)
        expect(s[1].pos[1]).toBeCloseTo(20)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `placeAlong` is nil.

- [ ] **Step 3: Write minimal implementation** — insert into `CanyonPath.luau` above `return CanyonPath`:

```luau
-- Walk the polyline; emit a sample every `spacing` studs of 3D length. Each sample
-- carries the unit horizontal heading (dir) of the segment it falls on, so callers
-- can offset rails/lanterns perpendicular to the path. includeEnds adds 0 and total.
function CanyonPath.placeAlong(
    points: { { number } },
    spacing: number,
    includeEnds: boolean
): { { pos: { number }, dir: { number } } }
    local segs = {}
    local total = 0
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local dir = run > 1e-4 and { (b[1] - a[1]) / run, (b[3] - a[3]) / run } or { 1, 0 }
        table.insert(segs, { a = a, b = b, len = len, dir = dir, start = total })
        total += len
    end
    local function sample(d: number)
        for _, s in segs do
            if d <= s.start + s.len + 1e-6 then
                local t = s.len > 1e-6 and math.clamp((d - s.start) / s.len, 0, 1) or 0
                return {
                    pos = {
                        s.a[1] + (s.b[1] - s.a[1]) * t,
                        s.a[2] + (s.b[2] - s.a[2]) * t,
                        s.a[3] + (s.b[3] - s.a[3]) * t,
                    },
                    dir = s.dir,
                }
            end
        end
        local last = segs[#segs]
        return { pos = last and last.b or points[1], dir = last and last.dir or { 1, 0 } }
    end
    local out = {}
    if includeEnds then
        table.insert(out, sample(0))
    end
    local d = spacing
    while d < total - 1e-6 do
        table.insert(out, sample(d))
        d += spacing
    end
    if includeEnds and total > 1e-6 then
        table.insert(out, sample(total))
    end
    return out
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/CanyonPath.luau roblox/tests/CanyonPath.spec.luau
git commit -m "feat(roblox): CanyonPath.placeAlong (even spacing + heading along a polyline)"
```

---

### Task 3: Assemble a route (`build` + `lanternPole`)

**Files:**
- Modify: `roblox/tools/builders/CanyonPath.luau`
- Test: `roblox/tests/CanyonPath.spec.luau`

- [ ] **Step 1: Write the failing test** — append to `CanyonPath.spec.luau`:

```luau
local ZenDojo = require("../src/shared/themes/ZenDojo")

local function findPrefix(node, prefix)
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            return c
        end
    end
    return nil
end
local function anyLight(node)
    if not node.children then
        return false
    end
    for _, c in node.children do
        if c.className == "PointLight" then
            return true
        end
        if anyLight(c) then
            return true
        end
    end
    return false
end

describe("CanyonPath.build", function()
    local route = { name = "TestTrunk", class = "trunk", points = { { 0, 0, 0 }, { 40, 0, 0 }, { 40, 20, 40 } } }
    local m = CanyonPath.build(ZenDojo.palette, route)
    test("returns a Model", function()
        expect(m.className).toBe("Model")
    end)
    test("has an invisible colliding ramp per segment", function()
        local ramp = findPrefix(m, "Ramp")
        expect(ramp ~= nil).toBe(true)
        expect(ramp.properties.CanCollide).toBe(true)
        expect(ramp.properties.Transparency).toBe(1)
    end)
    test("trunk ramp is the trunk width", function()
        expect(findPrefix(m, "Ramp").properties.Size[3]).toBe(8)
    end)
    test("has rails", function()
        expect(findPrefix(m, "RailPost") ~= nil).toBe(true)
    end)
    test("has at least one lantern light", function()
        expect(anyLight(m)).toBe(true)
    end)
    test("spur class is narrower", function()
        local sm = CanyonPath.build(ZenDojo.palette, { name = "S", class = "spur", points = { { 0, 0, 0 }, { 40, 0, 0 } } })
        expect(findPrefix(sm, "Ramp").properties.Size[3]).toBe(5)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `build` / `lanternPole` nil.

- [ ] **Step 3: Write minimal implementation** — insert into `CanyonPath.luau` above `return CanyonPath`:

```luau
-- A standing paper-lantern on a dark post.
function CanyonPath.lanternPole(palette: { [string]: { number } }, at: { number }): Spec.PartSpec
    local x, y, z = at[1], at[2], at[3]
    return Spec.model("LanternPole", {
        Spec.part("Pole", {
            Size = { 0.3, 6, 0.3 },
            CFrame = Spec.cframe({ x, y + 3, z }),
            Color = palette.ink,
            Material = "Wood",
        }),
        Spec.part("Chochin", {
            Size = { 1.6, 2.2, 1.6 },
            CFrame = Spec.cframe({ x, y + 6, z }),
            Color = palette.gold,
            Material = "Neon",
            Transparency = 0.25,
            children = {
                {
                    name = "Glow",
                    className = "PointLight",
                    properties = { Brightness = 0.9, Range = 16, Color = { 1.0, 0.78, 0.46 } },
                },
            },
        }),
    })
end

-- Build one route's full geometry from its waypoints.
function CanyonPath.build(palette: { [string]: { number } }, route: any): Spec.PartSpec
    local width = route.class == "spur" and CanyonPath.SPUR_WIDTH or CanyonPath.TRUNK_WIDTH
    local pts = route.points
    local children = {}

    -- tread + invisible collision ramp per segment
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local pos, len, rot = Spec.segment(a, b)
        local kind = CanyonPath.classifySegment(a, b)
        table.insert(
            children,
            Spec.part("Ramp" .. (i - 1), {
                Size = { len, 0.5, width },
                CFrame = Spec.cframe(pos, rot),
                Transparency = 1,
                Material = "SmoothPlastic",
                CanCollide = true,
            })
        )
        table.insert(
            children,
            Spec.part((kind == "steps" and "Steps" or "Paver") .. (i - 1), {
                Size = { len, 0.4, width - 0.4 },
                CFrame = Spec.cframe({ pos[1], pos[2] + 0.45, pos[3] }, rot),
                Color = kind == "steps" and palette.timber or palette.gravel,
                Material = kind == "steps" and "WoodPlanks" or "Slate",
                CanCollide = false,
            })
        )
    end

    -- rail posts on both edges
    local posts = CanyonPath.placeAlong(pts, CanyonPath.RAIL_SPACING, true)
    for k, s in posts do
        local px, pz = -s.dir[2], s.dir[1] -- perpendicular in XZ
        for _, side in { -1, 1 } do
            table.insert(
                children,
                Spec.part(("RailPost%d_%d"):format(k, side), {
                    Size = { 0.4, CanyonPath.RAIL_HEIGHT, 0.4 },
                    CFrame = Spec.cframe({
                        s.pos[1] + px * (width / 2) * side,
                        s.pos[2] + CanyonPath.RAIL_HEIGHT / 2,
                        s.pos[3] + pz * (width / 2) * side,
                    }),
                    Color = palette.timber,
                    Material = "Wood",
                    CanCollide = false,
                })
            )
        end
    end

    -- top rails per segment, both sides
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local px = run > 1e-4 and -(b[3] - a[3]) / run or 0
        local pz = run > 1e-4 and (b[1] - a[1]) / run or 1
        for _, side in { -1, 1 } do
            local ox, oz = px * (width / 2) * side, pz * (width / 2) * side
            local aa = { a[1] + ox, a[2] + CanyonPath.RAIL_HEIGHT, a[3] + oz }
            local bb = { b[1] + ox, b[2] + CanyonPath.RAIL_HEIGHT, b[3] + oz }
            local rpos, rlen, rrot = Spec.segment(aa, bb)
            table.insert(
                children,
                Spec.part(("RailTop%d_%d"):format(i - 1, side), {
                    Size = { rlen, 0.3, 0.3 },
                    CFrame = Spec.cframe(rpos, rrot),
                    Color = palette.timber,
                    Material = "Wood",
                    CanCollide = false,
                })
            )
        end
    end

    -- lanterns at intervals, alternating pole / stone, set just off the path edge
    local stops = CanyonPath.placeAlong(pts, CanyonPath.LANTERN_INTERVAL, false)
    for k, s in stops do
        local px, pz = -s.dir[2], s.dir[1]
        local edge = { s.pos[1] + px * (width / 2 + 1), s.pos[2], s.pos[3] + pz * (width / 2 + 1) }
        if k % 2 == 1 then
            table.insert(children, CanyonPath.lanternPole(palette, edge))
        else
            table.insert(children, StoneLantern.build(palette, edge))
        end
    end

    return Spec.model(route.name or "CanyonPath", children)
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/CanyonPath.luau roblox/tests/CanyonPath.spec.luau
git commit -m "feat(roblox): CanyonPath.build — route geometry (ramp + tread + rails + lanterns)"
```

---

### Task 4: Junction landings (`landing`)

**Files:**
- Modify: `roblox/tools/builders/CanyonPath.luau`
- Test: `roblox/tests/CanyonPath.spec.luau`

- [ ] **Step 1: Write the failing test** — append to `CanyonPath.spec.luau` (reuses `anyLight`, `ZenDojo` from Task 3):

```luau
describe("CanyonPath.landing", function()
    local L = CanyonPath.landing(ZenDojo.palette, { 0, 100, 0 }, 16)
    test("returns a Model", function()
        expect(L.className).toBe("Model")
    end)
    test("has a collidable pad", function()
        local pad = findPrefix(L, "Pad")
        expect(pad ~= nil).toBe(true)
        expect(pad.properties.CanCollide).toBe(true)
    end)
    test("has a lantern light", function()
        expect(anyLight(L)).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `landing` nil.

- [ ] **Step 3: Write minimal implementation** — insert into `CanyonPath.luau` above `return CanyonPath`:

```luau
-- A small flat paver node where routes branch/meet, with a feature lantern.
function CanyonPath.landing(palette: { [string]: { number } }, at: { number }, radius: number): Spec.PartSpec
    local x, y, z = at[1], at[2], at[3]
    return Spec.model("Landing", {
        Spec.part("Pad", {
            Shape = "Cylinder",
            Size = { 0.5, radius * 2, radius * 2 },
            CFrame = Spec.cframe({ x, y, z }, Spec.ROT.CYL_VERTICAL),
            Color = palette.gravel,
            Material = "Slate",
            CanCollide = true,
        }),
        CanyonPath.lanternPole(palette, { x, y, z }),
    })
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS. Then format/lint: `stylua --check src tests tools && selene src tools` (fix any findings).

- [ ] **Step 5: Commit**

```bash
git add roblox/tools/builders/CanyonPath.luau roblox/tests/CanyonPath.spec.luau
git commit -m "feat(roblox): CanyonPath.landing — junction node + feature lantern"
```

---

### Task 5: Author the routes (draft → adjust → bake) — MCP + USER GATE

**Files:**
- Create: `roblox/tools/studio/draftPathMarkers.luau`
- Create: `roblox/tools/studio/bakePathMarkers.luau`
- Modify: `roblox/tools/builders/ArenaLayout.luau` (add `paths` block)

This task is run via the Roblox Studio MCP in **Edit** mode, not Lune. First confirm the active Studio: `list_roblox_studios` → `set_active_studio`.

- [ ] **Step 1: Draft first-pass markers.** Create `roblox/tools/studio/draftPathMarkers.luau` and run it via `execute_luau` (datamodel `Edit`). It drops bright draggable spheres along the agent's first guess for each route, grouped under `workspace.PathDraft`, named `<route>_<index>`:

```luau
-- MCP/Edit: draggable first-pass waypoint markers. Drag in Studio, then run
-- bakePathMarkers.luau to emit the ArenaLayout.paths table. Idempotent.
local old = workspace:FindFirstChild("PathDraft")
if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "PathDraft"; folder.Parent = workspace

-- First-pass routes as {x,z} (Y is snapped later). Clearing ≈ origin, floor y≈112.
-- Trunk up the near (+Z) wall, trunk up the far (−Z) wall, a floor path, an overlook spur.
-- These are STARTING GUESSES — the user drags them onto the real terrain.
local ROUTES = {
    NearWall = { class = "trunk", xz = { { 30, 30 }, { 70, 45 }, { 110, 60 }, { 150, 70 } } },
    FarWall  = { class = "trunk", xz = { { 30, -30 }, { 70, -45 }, { 110, -55 }, { 150, -65 } } },
    Floor    = { class = "trunk", xz = { { 0, 0 }, { 60, 8 }, { 120, 0 }, { 180, -10 } } },
    Overlook = { class = "spur",  xz = { { 60, 20 }, { 74, 28 } } },
}
local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }
for name, route in ROUTES do
    for i, p in route.xz do
        local hit = workspace:Raycast(Vector3.new(p[1], 500, p[2]), Vector3.new(0, -1000, 0), rc)
        local y = hit and hit.Position.Y + 1 or 120
        local m = Instance.new("Part")
        m.Name = ("%s_%02d"):format(name, i)
        m.Shape = Enum.PartType.Ball; m.Size = Vector3.new(4, 4, 4)
        m.Anchored = true; m.CanCollide = false; m.Material = Enum.Material.Neon
        m.Color = route.class == "spur" and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(255, 210, 90)
        m.Position = Vector3.new(p[1], y, p[2]); m.Parent = folder
    end
end
return "drafted markers under workspace.PathDraft — drag them onto the routes you want"
```

- [ ] **Step 2: USER GATE — adjust markers.** Ask the user to drag/add/delete markers in Studio so each route follows the terrain they want (add markers by duplicating one and renaming `<route>_NN` with a higher index; keep names contiguous per route). Wait for confirmation before baking.

- [ ] **Step 3: Bake markers to a table.** Create `roblox/tools/studio/bakePathMarkers.luau` and run via `execute_luau` (Edit). It reads `workspace.PathDraft`, groups by route name, sorts by index, and prints a paste-ready Lua table:

```luau
-- MCP/Edit: read PathDraft markers -> print an ArenaLayout.paths table.
local folder = workspace:FindFirstChild("PathDraft")
if not folder then return "no PathDraft folder" end
local CLASS = { NearWall = "trunk", FarWall = "trunk", Floor = "trunk", Overlook = "spur" }
local routes = {}
for _, m in folder:GetChildren() do
    local name, idx = m.Name:match("^(.-)_(%d+)$")
    if name then
        routes[name] = routes[name] or {}
        table.insert(routes[name], { idx = tonumber(idx), p = m.Position })
    end
end
local lines = { "    paths = {" }
for name, pts in routes do
    table.sort(pts, function(a, b) return a.idx < b.idx end)
    local parts = {}
    for _, e in pts do
        table.insert(parts, ("{ %.1f, %.1f, %.1f }"):format(e.p.X, e.p.Y, e.p.Z))
    end
    table.insert(lines, ("        { name = %q, class = %q, points = { %s } },"):format(
        name, CLASS[name] or "trunk", table.concat(parts, ", ")))
end
table.insert(lines, "    },")
return table.concat(lines, "\n")
```

- [ ] **Step 4: Paste into ArenaLayout.** Copy the printed `paths = { … }` table into `roblox/tools/builders/ArenaLayout.luau` as a new top-level field (place it after the `clearing` block). The Y values are the snapped guide heights; `buildPaths.luau` re-snaps at build time, so they only need to be roughly right.

- [ ] **Step 5: Verify tests still pass and commit**

Run: `cd roblox && lune run tests/run` (existing tests unaffected) and `stylua --check tools`.

```bash
git add roblox/tools/studio/draftPathMarkers.luau roblox/tools/studio/bakePathMarkers.luau roblox/tools/builders/ArenaLayout.luau
git commit -m "feat(roblox): canyon path route authoring (draft/bake markers) + ArenaLayout.paths"
```

---

### Task 6: Materialize the paths — MCP snap pass + USER GATE

**Files:**
- Create: `roblox/tools/studio/buildPaths.luau`

Run via the Studio MCP in **Edit** mode. This script **mirrors** `CanyonPath.luau`'s piece logic (Studio cannot `require` repo modules) — if you change one, change both; `CanyonPath`'s Lune tests are canonical.

- [ ] **Step 1: Write the snap pass.** Create `roblox/tools/studio/buildPaths.luau`. Paste the current `ArenaLayout.paths` value into the `PATHS` table at the top before running.

```luau
-- MCP/Edit: materialize ArenaLayout.paths into workspace.RoshamboStage.CanyonPaths.
-- Densify each route (a point every ~6 studs), raycast-snap every point onto the
-- terrain for Y, then lay an invisible collision ramp + decorative tread + rails +
-- interval lanterns. Junction landings where route endpoints nearly coincide.
-- Idempotent: rebuilds the CanyonPaths folder each run. Mirrors CanyonPath.luau.
local PATHS = {
    -- PASTE ArenaLayout.paths HERE, e.g.
    -- { name = "NearWall", class = "trunk", points = { {30,118,30}, ... } },
}

local TRUNK_W, SPUR_W = 8, 5
local RAIL_H, RAIL_SP, LANT_INT, STEP_GRADE = 3, 6, 22, 0.27
local STEP = 6 -- densify interval (studs)

local stage = workspace.RoshamboStage
local old = stage:FindFirstChild("CanyonPaths")
if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "CanyonPaths"; root.Parent = stage

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }
local function snapY(x, z)
    local h = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rc)
    return h and h.Position.Y or nil
end

local function part(parent, name, size, cf, color, mat, canCollide, transp)
    local p = Instance.new("Part")
    p.Name = name; p.Anchored = true; p.CanCollide = canCollide; p.CanQuery = false
    p.CastShadow = false; p.Size = size; p.CFrame = cf; p.Color = color
    p.Material = mat; p.Transparency = transp or 0; p.Parent = parent
    return p
end
local function lanternPole(parent, x, y, z)
    part(parent, "Pole", Vector3.new(0.3, 6, 0.3), CFrame.new(x, y + 3, z), Color3.fromRGB(46, 48, 56), Enum.Material.Wood, false)
    local c = part(parent, "Chochin", Vector3.new(1.6, 2.2, 1.6), CFrame.new(x, y + 6, z), Color3.fromRGB(212, 176, 102), Enum.Material.Neon, false, 0.25)
    local l = Instance.new("PointLight"); l.Brightness = 0.9; l.Range = 16; l.Color = Color3.fromRGB(255, 199, 117); l.Parent = c
end
local function stoneLantern(parent, x, y, z)
    part(parent, "SLBase", Vector3.new(2.2, 0.8, 2.2), CFrame.new(x, y + 0.4, z), Color3.fromRGB(201, 194, 179), Enum.Material.Slate, false)
    part(parent, "SLPost", Vector3.new(0.9, 2.2, 0.9), CFrame.new(x, y + 1.9, z), Color3.fromRGB(201, 194, 179), Enum.Material.Slate, false)
    local fb = part(parent, "SLFire", Vector3.new(1.6, 1.2, 1.6), CFrame.new(x, y + 3.6, z), Color3.fromRGB(212, 176, 102), Enum.Material.Neon, false, 0.2)
    local l = Instance.new("PointLight"); l.Brightness = 0.8; l.Range = 14; l.Color = Color3.fromRGB(230, 191, 115); l.Parent = fb
    part(parent, "SLCap", Vector3.new(2.6, 0.7, 2.6), CFrame.new(x, y + 4.55, z), Color3.fromRGB(201, 194, 179), Enum.Material.Slate, false)
end

local function hyp(dx, dz) return math.sqrt(dx * dx + dz * dz) end

-- densify + snap a route's waypoints into a dense snapped point list
local function densify(points)
    local out = {}
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local n = math.max(1, math.floor(run / STEP))
        for k = 0, n - (i < #points and 1 or 0) do
            local t = k / n
            local x = a[1] + (b[1] - a[1]) * t
            local z = a[3] + (b[3] - a[3]) * t
            local y = snapY(x, z) or (a[2] + (b[2] - a[2]) * t)
            table.insert(out, { x, y + 0.25, z })
        end
    end
    return out
end

local TIMBER, GRAVEL = Color3.fromRGB(107, 79, 51), Color3.fromRGB(201, 194, 179)
local function buildRoute(route)
    local folder = Instance.new("Folder"); folder.Name = route.name; folder.Parent = root
    local width = route.class == "spur" and SPUR_W or TRUNK_W
    local pts = densify(route.points)
    -- tread + invisible ramp
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local mid = Vector3.new((a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2)
        local len = (Vector3.new(b[1], b[2], b[3]) - Vector3.new(a[1], a[2], a[3])).Magnitude
        local cf = CFrame.lookAt(mid, Vector3.new(b[1], b[2], b[3]))
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local steps = run > 1e-4 and (math.abs(b[2] - a[2]) / run > STEP_GRADE) or true
        -- ramp uses CFrame.lookAt so its -Z faces b; size is (width, 0.5, len)
        part(folder, "Ramp" .. (i - 1), Vector3.new(width, 0.5, len), cf, GRAVEL, Enum.Material.SmoothPlastic, true, 1)
        part(folder, (steps and "Steps" or "Paver") .. (i - 1), Vector3.new(width - 0.4, 0.4, len),
            cf + Vector3.new(0, 0.45, 0), steps and TIMBER or GRAVEL, steps and Enum.Material.WoodPlanks or Enum.Material.Slate, false)
    end
    -- rails: posts + top rail, both edges
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local px = run > 1e-4 and -(b[3] - a[3]) / run or 0
        local pz = run > 1e-4 and (b[1] - a[1]) / run or 1
        for _, side in { -1, 1 } do
            local ox, oz = px * (width / 2) * side, pz * (width / 2) * side
            -- post at a
            part(folder, ("RailPost%d_%d"):format(i - 1, side), Vector3.new(0.4, RAIL_H, 0.4),
                CFrame.new(a[1] + ox, a[2] + RAIL_H / 2, a[3] + oz), TIMBER, Enum.Material.Wood, false)
            -- top rail a->b
            local aa = Vector3.new(a[1] + ox, a[2] + RAIL_H, a[3] + oz)
            local bb = Vector3.new(b[1] + ox, b[2] + RAIL_H, b[3] + oz)
            local cf = CFrame.lookAt((aa + bb) / 2, bb)
            part(folder, ("RailTop%d_%d"):format(i - 1, side), Vector3.new(0.3, 0.3, (bb - aa).Magnitude), cf, TIMBER, Enum.Material.Wood, false)
        end
    end
    -- lanterns at intervals
    local acc, nextAt, idx = 0, LANT_INT, 0
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local seg = (Vector3.new(b[1], b[2], b[3]) - Vector3.new(a[1], a[2], a[3])).Magnitude
        while acc + seg >= nextAt do
            local t = (nextAt - acc) / seg
            local run = hyp(b[1] - a[1], b[3] - a[3])
            local px = run > 1e-4 and -(b[3] - a[3]) / run or 0
            local pz = run > 1e-4 and (b[1] - a[1]) / run or 1
            local x = a[1] + (b[1] - a[1]) * t + px * (width / 2 + 1)
            local z = a[3] + (b[3] - a[3]) * t + pz * (width / 2 + 1)
            local y = snapY(x, z) or (a[2] + (b[2] - a[2]) * t)
            idx += 1
            if idx % 2 == 1 then lanternPole(folder, x, y, z) else stoneLantern(folder, x, y, z) end
            nextAt += LANT_INT
        end
        acc += seg
    end
end

for _, route in PATHS do buildRoute(route) end

-- landings where any two route endpoints are within 12 studs
local ends = {}
for _, r in PATHS do
    table.insert(ends, r.points[1]); table.insert(ends, r.points[#r.points])
end
local landings = stage.CanyonPaths
for i = 1, #ends do
    for j = i + 1, #ends do
        local a, b = ends[i], ends[j]
        if hyp(a[1] - b[1], a[3] - b[3]) < 12 and math.abs(a[2] - b[2]) < 8 then
            local x, z = (a[1] + b[1]) / 2, (a[3] + b[3]) / 2
            local y = snapY(x, z) or a[2]
            local f = Instance.new("Folder"); f.Name = "Landing"; f.Parent = landings
            local pad = part(f, "Pad", Vector3.new(0.5, 32, 32), CFrame.new(x, y + 0.25, z) * CFrame.Angles(0, 0, math.rad(90)), GRAVEL, Enum.Material.Slate, true)
            pad.Shape = Enum.PartType.Cylinder
            lanternPole(f, x, y + 0.25, z)
        end
    end
end

return "built " .. #PATHS .. " routes into RoshamboStage.CanyonPaths"
```

- [ ] **Step 2: Run it.** `execute_luau` (Edit) with the script (PATHS pasted). Expect a "built N routes" result and a `CanyonPaths` folder under `RoshamboStage`.

- [ ] **Step 3: USER GATE — walk it.** Reset the camera (`workspace.CurrentCamera.CameraType = Enum.CameraType.Custom`), then enter Play and walk the loop. Verify: clean traversal on the invisible ramp (no stuck steps), rails present on drop sides, lanterns at sensible intervals, and you can circumnavigate (clearing → near wall → [bridge gap] → far wall → floor → clearing). Note tuning the user requests (width, lantern interval, route nudges).

- [ ] **Step 4: Tune + re-run** as needed (adjust constants at the top of `buildPaths.luau` and the matching constants in `CanyonPath.luau`, re-run, re-walk).

- [ ] **Step 5: Commit + save**

```bash
git add roblox/tools/studio/buildPaths.luau
git commit -m "feat(roblox): buildPaths snap pass — materialize canyon paths on terrain"
```
Then **save the place** in Studio (the `CanyonPaths` folder lives in the .rbxl).

---

### Task 7: Final gate + sync check

**Files:** none (verification only)

- [ ] **Step 1: Full test + lint.** `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`. Expected: all green.
- [ ] **Step 2: Mirror check.** Diff the constants and piece sizing between `CanyonPath.luau` and `buildPaths.luau`; confirm they match (widths, RAIL_HEIGHT, LANTERN_INTERVAL, STEP_GRADE, tread/rail sizes). Fix drift.
- [ ] **Step 3: Composition gate.** With the user, confirm the network reads like the reference (lantern-lined railed stone/timber paths, junction landings) and that circumnavigation works (closing fully once the bridge sub-project lands).
- [ ] **Step 4: Update memory** (`zendojo-viewing-platform.md` or a new canyon-village note): paths built, `ArenaLayout.paths` schema, `CanyonPath`/`buildPaths` mirror, spur class ready for teahouses, bridge still needed to close the loop.

---

## Self-Review

**Spec coverage:**
- 8-stud trunk / 5-stud spur tread → Task 3 (`width` by class), tested. ✓
- Paver vs steps by grade → Task 1, tested. ✓
- Invisible collision ramp (walkability) → Task 3 (`Ramp*` CanCollide+Transparency 1), tested. ✓
- Slim timber rails both edges → Task 3 (`RailPost*`/`RailTop*`). ✓
- Lanterns ~every 20–24 studs, alternating pole / stone → Task 3 (`LANTERN_INTERVAL=22`, alternation). ✓
- Junction landings 14–18 studs → Task 4 (`landing` radius; buildPaths uses 16). ✓
- Route topology (near/far wall trunks, floor, overlook spur) + circumnavigation loop → Task 5 routes; Task 6 builds + landings; loop closes via bridge (out of scope, noted). ✓
- Spur class supported now, built later → Tasks 3/5 (`class="spur"`). ✓
- Authoring method B (draft → adjust → bake) → Task 5. ✓
- `ArenaLayout.paths` schema + reproducible snap pass → Tasks 5/6. ✓
- Lune tests for pure logic → Tasks 1–4. ✓
- Out of scope (teahouses, bridge structure, spawns, telegraph hookup) → not in any task. ✓

**Placeholder scan:** none — all steps carry runnable code/commands. (The `PATHS`/`ROUTES` route coordinates are intentional first-pass guesses the user adjusts in Task 5, not placeholders for missing logic.)

**Type/name consistency:** `classifySegment`, `placeAlong`, `lanternPole`, `build`, `landing`, and constants (`TRUNK_WIDTH`/`SPUR_WIDTH`/`RAIL_HEIGHT`/`RAIL_SPACING`/`LANTERN_INTERVAL`/`STEP_GRADE`) are used identically across tasks and mirrored (lowercase, in `buildPaths`) in Task 6. Part-name prefixes (`Ramp`, `Paver`/`Steps`, `RailPost`, `RailTop`, `Pad`) match between tests and both builders.

**Known intentional duplication:** `buildPaths.luau` mirrors `CanyonPath.luau` because MCP Studio scripts can't `require` repo modules (precedent: `GameRules.ts` ↔ `GameRules.luau`). Task 7 Step 2 guards against drift.
