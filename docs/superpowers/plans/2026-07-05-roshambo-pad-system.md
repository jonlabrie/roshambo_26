# Pad System (Sub-Project B, Increment 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the cliff-perch pad — a pure `PadPlanner` (footprint + datum placement + injected ground function → support-post specs) and an ops-driven `PadBuilder` (real terrain raycast, builds posts, returns the `mount`) — and prove the A↔B seam by standing a `teahouse-1story` structure on pad-built stilts at a real cliff.

**Architecture:** Same planner/applier split as sub-project A. `PadPlanner` is pure and Lune-tested (CFrames are 12-number arrays; the ground lookup is injected). `PadBuilder` drives an injected `ops` adapter (fake in tests, real terrain raycast + Part build at runtime) and returns the `mount` that A's `StructureBuilder` consumes. The one cliff site is surveyed and baked. See spec: `docs/superpowers/specs/2026-07-05-roshambo-pad-system-design.md`.

**Tech Stack:** Luau; Lune harness (`roblox/tests/harness.luau`, `run.luau`); Rojo (`src/shared → ReplicatedStorage.RoshamboShared`); Roblox Studio via MCP `execute_luau` for the survey + integration demo.

## Global Constraints

- **Purity:** `PadPlanner` and `PadBuilder` run headless under Lune — plain tables/numbers only, **no Roblox datatypes, no `math.random`**. CFrames are 12-number arrays in `Spec.cframe` order: `{px,py,pz, R00,R01,R02, R10,R11,R12, R20,R21,R22}`; a local point transforms as `world = pos + R·local` (i.e. `wx = px + R00·lx + R01·ly + R02·lz`, etc).
- **Datum rule:** a post's TOP is the datum plane — `mountCF` applied to the post's local `(lx, 0, lz)`. The post spans from there DOWN to `groundAt(x,z) − 1` (1-stud embed). Nothing about the structure is built here.
- **Six posts** at the footprint's 4 corners + the two long-side (front/back, Z-edge) mids, matching the stripped `EngawaPost`. Post is **1.2 sq**, its **outer corner flush** to the footprint corner (centre pulled inward by half-width 0.6). Style at build time: black ink `Color3.fromRGB(45,48,56)`, `Wood`, `Anchored`, `CanCollide=false`, `CastShadow=false`.
- **Over-void:** when `groundAt` returns `nil`, omit that post and record its label (`FL/FR/BL/BR/MF/MB`) — do not stub it.
- **`mount` output shape** (consumed by A's `StructureBuilder.build`): `{ cframe = padSpec.mountCF, hand = padSpec.hand, footprint = padSpec.footprint }`.
- **Module paths:** pure modules in `roblox/src/shared/`; specs in `roblox/tests/*.spec.luau` require them as `../src/shared/<Name>`. Run tests with `lune run tests/run` from `roblox/` (baseline: 261 passing).
- **Studio tasks (3–4) stop for the user** — end by screenshotting and pausing for review; never self-judge and iterate (standing rule).

---

### Task 1: PadPlanner — support-post layout

**Files:**
- Create: `roblox/src/shared/PadPlanner.luau`
- Test: `roblox/tests/PadPlanner.spec.luau`

**Interfaces:**
- Produces: `PadPlanner.planSupport(footprint: Footprint, mountCF: {number}, groundAt: (number, number) -> number?) -> Support` where `Footprint = { minX, maxX, minZ, maxZ }`, `Post = { pos: {number}, height: number }`, `Support = { posts: {Post}, omitted: {string} }`. Posts are returned in order `FL, FR, BL, BR, MF, MB` (omitting any whose ground is nil).

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/PadPlanner.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local PadPlanner = require("../src/shared/PadPlanner")

local IDENT = { 0, 20, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } -- datum plane at y=20, identity rotation
local FP = { minX = -7, maxX = 15, minZ = -11, maxZ = 4 }

test("flat ground: 6 posts at corners+mids, flush, spanning datum->ground-embed", function()
    local s = PadPlanner.planSupport(FP, IDENT, function() return 0 end)
    expect(#s.posts).toBe(6)
    expect(#s.omitted).toBe(0)
    -- FL is first: outer corner flush -> centre (minX+0.6, .., minZ+0.6) = (-6.4, .., -10.4)
    expect(s.posts[1].pos[1]).toBe(-6.4)
    expect(s.posts[1].pos[3]).toBe(-10.4)
    -- height = datum(20) - (ground(0) - embed(1)) = 21; centre y = (20 + -1)/2 = 9.5
    expect(s.posts[1].height).toBe(21)
    expect(s.posts[1].pos[2]).toBe(9.5)
    -- MF (5th) sits at footprint centre-x = (-7+15)/2 = 4, minZ+0.6 = -10.4
    expect(s.posts[5].pos[1]).toBe(4)
    expect(s.posts[5].pos[3]).toBe(-10.4)
end)

test("sloped ground: per-post height follows groundAt(x,z)", function()
    -- ground rises 1 stud per +x; FR is at x = 15-0.6 = 14.4 -> ground 14.4
    local s = PadPlanner.planSupport(FP, IDENT, function(x, _z) return x end)
    -- FR is posts[2]; height = 20 - (14.4 - 1) = 6.6
    expect(s.posts[2].pos[1]).toBe(14.4)
    expect(s.posts[2].height).toBeCloseTo(6.6, 1e-6)
end)

test("over-void: nil ground omits the post and records its label", function()
    -- no ground on the front edge (minZ side): omit FL, FR, MF
    local s = PadPlanner.planSupport(FP, IDENT, function(_x, z)
        if z < -5 then return nil end
        return 0
    end)
    expect(#s.posts).toBe(3)
    expect(s.omitted).toEqual({ "FL", "FR", "MF" })
end)

test("rotated mount: 180-degree yaw negates local X/Z into world", function()
    -- yaw 180: R = {-1,0,0, 0,1,0, 0,0,-1}; world = pos + R*local
    local yaw180 = { 100, 20, 50, -1, 0, 0, 0, 1, 0, 0, 0, -1 }
    local s = PadPlanner.planSupport(FP, yaw180, function() return 0 end)
    -- FL local (-6.4, 0, -10.4) -> world (100 - -6.4, .., 50 - -10.4) = (106.4, .., 60.4)
    expect(s.posts[1].pos[1]).toBe(106.4)
    expect(s.posts[1].pos[3]).toBe(60.4)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `PadPlanner` not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/PadPlanner.luau
--!strict
-- Cliff-pad support planner: given the structure's frame footprint, the datum-plane
-- placement, and an injected ground-height function, emit the support-post specs the
-- PadBuilder materializes. Pure (Lune-tested); the ground lookup is a raycast at runtime
-- and a fake in tests. CFrames are 12-number arrays (Spec.cframe order); world = pos + R*local.
local PadPlanner = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Post = { pos: { number }, height: number }
export type Support = { posts: { Post }, omitted: { string } }

local PH = 0.6 -- half of the 1.2-stud post (outer corner flush to the footprint corner)
local EMBED = 1.0 -- studs the post foot sinks into terrain

local function xf(cf: { number }, lx: number, ly: number, lz: number): { number }
    return {
        cf[1] + cf[4] * lx + cf[5] * ly + cf[6] * lz,
        cf[2] + cf[7] * lx + cf[8] * ly + cf[9] * lz,
        cf[3] + cf[10] * lx + cf[11] * ly + cf[12] * lz,
    }
end

function PadPlanner.planSupport(
    footprint: Footprint,
    mountCF: { number },
    groundAt: (number, number) -> number?
): Support
    local cx = (footprint.minX + footprint.maxX) / 2
    local layout = {
        { "FL", footprint.minX + PH, footprint.minZ + PH },
        { "FR", footprint.maxX - PH, footprint.minZ + PH },
        { "BL", footprint.minX + PH, footprint.maxZ - PH },
        { "BR", footprint.maxX - PH, footprint.maxZ - PH },
        { "MF", cx, footprint.minZ + PH },
        { "MB", cx, footprint.maxZ - PH },
    }
    local posts: { Post } = {}
    local omitted: { string } = {}
    for _, p in layout do
        local top = xf(mountCF, p[2] :: number, 0, p[3] :: number)
        local groundY = groundAt(top[1], top[3])
        if groundY == nil then
            table.insert(omitted, p[1] :: string)
        else
            local foot = groundY - EMBED
            table.insert(posts, {
                pos = { top[1], (top[2] + foot) / 2, top[3] },
                height = top[2] - foot,
            })
        end
    end
    return { posts = posts, omitted = omitted }
end

return PadPlanner
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (4 new tests; suite green).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/PadPlanner.luau roblox/tests/PadPlanner.spec.luau
git commit -m "feat(roblox): PadPlanner — cliff support-post layout (flush, sloped, over-void)"
```

---

### Task 2: PadBuilder — ops-driven support build

**Files:**
- Create: `roblox/src/shared/PadBuilder.luau`
- Test: `roblox/tests/PadBuilder.spec.luau`

**Interfaces:**
- Consumes: `PadPlanner.planSupport` (Task 1).
- Produces: `PadBuilder.build(padSpec, ops) -> Mount`. `PadSpec = { mountCF: {number}, hand: string, footprint: PadPlanner.Footprint }`; `Ops = { raycastGround: (number, number) -> number?, buildPost: ({number}, number) -> () }`; `Mount = { cframe: {number}, hand: string, footprint: PadPlanner.Footprint }`. `ops.raycastGround` is passed straight to the planner as `groundAt`; `ops.buildPost(pos, height)` is called once per planned post.

- [ ] **Step 1: Write the failing test**

```lua
-- roblox/tests/PadBuilder.spec.luau
--!strict
local harness = require("./harness")
local test, expect = harness.test, harness.expect
local PadBuilder = require("../src/shared/PadBuilder")

local IDENT = { 0, 20, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local FP = { minX = -7, maxX = 15, minZ = -11, maxZ = 4 }

test("build calls buildPost per planned post and returns the mount", function()
    local built = {}
    local ground = {}
    local ops = {
        raycastGround = function(x, z)
            table.insert(ground, { x, z })
            return 0
        end,
        buildPost = function(pos, height)
            table.insert(built, { pos = pos, height = height })
        end,
    }
    local mount = PadBuilder.build({ mountCF = IDENT, hand = "right", footprint = FP }, ops)
    expect(#built).toBe(6)
    expect(#ground).toBe(6) -- planner queried ground once per candidate post
    expect(built[1].height).toBe(21) -- FL, flat ground at y=0, datum y=20
    expect(mount.cframe).toEqual(IDENT)
    expect(mount.hand).toBe("right")
    expect(mount.footprint).toEqual(FP)
end)

test("build skips buildPost for over-void posts", function()
    local built = 0
    local ops = {
        raycastGround = function(_x, z)
            if z < -5 then return nil end
            return 0
        end,
        buildPost = function(_pos, _height)
            built += 1
        end,
    }
    PadBuilder.build({ mountCF = IDENT, hand = "left", footprint = FP }, ops)
    expect(built).toBe(3) -- FL/FR/MF omitted
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `PadBuilder` not found.

- [ ] **Step 3: Write minimal implementation**

```lua
-- roblox/src/shared/PadBuilder.luau
--!strict
-- Thin applier: plans the cliff support (PadPlanner) using the injected ground raycast,
-- builds each post via the injected ops, and returns the mount that A's StructureBuilder
-- consumes. ops is faked in tests (Lune) and implemented for real in the Studio demo /
-- runtime. Requiring the pure planner is fine (Lune-loadable).
local PadPlanner = require("./PadPlanner")

local PadBuilder = {}

export type PadSpec = { mountCF: { number }, hand: string, footprint: PadPlanner.Footprint }
export type Ops = {
    raycastGround: (number, number) -> number?,
    buildPost: ({ number }, number) -> (),
}
export type Mount = { cframe: { number }, hand: string, footprint: PadPlanner.Footprint }

function PadBuilder.build(padSpec: PadSpec, ops: Ops): Mount
    local support = PadPlanner.planSupport(padSpec.footprint, padSpec.mountCF, ops.raycastGround)
    for _, post in support.posts do
        ops.buildPost(post.pos, post.height)
    end
    return { cframe = padSpec.mountCF, hand = padSpec.hand, footprint = padSpec.footprint }
end

return PadBuilder
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/PadBuilder.luau roblox/tests/PadBuilder.spec.luau
git commit -m "feat(roblox): PadBuilder — ops-driven support build, returns the mount"
```

---

### Task 3: Survey + bake the cliff PadSpec (Studio)

**Files:**
- Create: `roblox/tools/studio/padSites.luau` (committed record of the surveyed PadSpec; executed/derived via MCP `execute_luau`, datamodel `Edit`)

**Interfaces:**
- Produces: a baked `PadSpec` — `mountCF` (12-number array), `hand`, and `footprint` (`{minX,maxX,minZ,maxZ}` read from the `teahouse-1story` prefab). Task 4 consumes it.

Studio task — gate is inspection + the Task 4 visual. Run steps via MCP `execute_luau` (datamodel `Edit`).

- [ ] **Step 1: Read the structure footprint from the prefab**

```lua
local SS = game:GetService("ServerStorage")
local m = SS.StructurePrefabs["teahouse-1story"]
local piv = m:GetPivot()
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
for _, p in m:GetDescendants() do
    if p:IsA("BasePart") and p.Name:match("^Perim") then
        local s = p.Size / 2
        for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
            local l = piv:ToObjectSpace(p.CFrame * CFrame.new(sx * s.X, 0, sz * s.Z)).Position
            minX = math.min(minX, l.X); maxX = math.max(maxX, l.X)
            minZ = math.min(minZ, l.Z); maxZ = math.max(maxZ, l.Z)
        end end
    end
end
return string.format("footprint = { minX=%.2f, maxX=%.2f, minZ=%.2f, maxZ=%.2f }", minX, maxX, minZ, maxZ)
```
Record the printed footprint numbers.

- [ ] **Step 2: Choose an empty cliff site and capture the datum-plane mount CFrame**

Pick a clear cliff edge with terrain reachable below (not a sheer void on all sides). Set the mount so the veranda front (−Z local) points OUT over the canyon and the back sits toward the cliff; `hand` = the side the cliff wall is on (`"right"` if the cliff is on +X of the veranda, else `"left"`). Capture it (adjust `pos`/`yawDeg` to taste against the terrain — this is a judgment placement, iterate in Edit):

```lua
-- EDIT pos + yawDeg to seat the pad on the chosen cliff shelf; datum Y = desired floor underside
local pos = Vector3.new(0, 120, 0)   -- <-- surveyed: where the floor-underside centre goes
local yawDeg = 0                      -- <-- surveyed: veranda faces out over the canyon
local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
local c = { cf:GetComponents() }
-- print in Spec.cframe order (pos + row-major R) for baking
return string.format("mountCF = { %.3f, %.3f, %.3f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f }",
    c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
```
`CFrame:GetComponents()` returns `x,y,z, R00,R01,R02,R10,R11,R12,R20,R21,R22` — exactly the `Spec.cframe` order the planner's `xf` expects. Record the printed `mountCF`.

- [ ] **Step 3: Bake the PadSpec into the committed record**

Write `roblox/tools/studio/padSites.luau` with the surveyed values (substitute the numbers recorded in Steps 1–2):

```lua
--!strict
-- Surveyed cliff PadSpec(s) for the pad-system A<->B proof. Baked coordinates
-- (recipe rule: never depend on draft markers). mountCF is in Spec.cframe order
-- (pos + row-major rotation); footprint read from the teahouse-1story prefab.
return {
    cliff_proof = {
        mountCF = { --[[ paste Step 2 numbers ]] },
        hand = "right", -- or "left" per the surveyed cliff side
        footprint = { minX = 0, maxX = 0, minZ = 0, maxZ = 0 }, -- paste Step 1 numbers
    },
}
```

- [ ] **Step 4: Commit the baked PadSpec**

```bash
git add roblox/tools/studio/padSites.luau
git commit -m "chore(roblox): survey + bake the cliff PadSpec for the A<->B proof"
```

---

### Task 4: Integration demo + visual gate (Studio)

**Files:**
- Create: `roblox/tools/studio/buildPadDemo.luau` (committed record; executed via MCP `execute_luau`, datamodel `Edit`)

**Interfaces:**
- Consumes: the baked `PadSpec` (Task 3) and `ServerStorage.StructurePrefabs.teahouse-1story` (sub-project A). Inlines the real `ops` (raycast + post build) and mirrors `PadBuilder`/`StructureBuilder` — MCP Studio scripts cannot `require` repo modules (precedent: A's `materializeStructureDemo.luau`). The pure logic is Lune-tested in Tasks 1–2; this is the visual proof.

- [ ] **Step 1: Build the pad, mount a structure on it, at the surveyed site**

Substitute `PADSPEC` with the baked values from Task 3. This raycasts terrain, builds the posts, then materializes a `teahouse-1story` on the returned mount.

```lua
local SS = game:GetService("ServerStorage")
local PADSPEC = {
    mountCF = { --[[ Task 3 mountCF ]] },
    hand = "right",
    footprint = { minX = 0, maxX = 0, minZ = 0, maxZ = 0 }, -- Task 3 footprint
}
local BLACK = Color3.fromRGB(45, 48, 56)
local demo = workspace:FindFirstChild("PadDemo"); if demo then demo:Destroy() end
demo = Instance.new("Folder"); demo.Name = "PadDemo"; demo.Parent = workspace

-- rebuild mountCF as a real CFrame (Spec.cframe order == GetComponents order)
local m = PADSPEC.mountCF
local mountCF = CFrame.new(table.unpack(m))

-- real ops (mirror of PadBuilder's adapter; logic is Lune-tested in src/shared)
local function raycastGround(x, z)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = { workspace.Terrain }
    local top = Vector3.new(x, mountCF.Position.Y + 4, z)
    local hit = workspace:Raycast(top, Vector3.new(0, -600, 0), rp)
    return hit and hit.Position.Y or nil
end
local function buildPost(pos, height)
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.CanCollide, p.CastShadow = "PadPost", true, false, false
    p.Size, p.Color, p.Material = Vector3.new(1.2, height, 1.2), BLACK, Enum.Material.Wood
    p.CFrame = CFrame.new(pos[1], pos[2], pos[3])
    p.Parent = demo
end

-- mirror PadPlanner.planSupport (see src/shared/PadPlanner.luau) + PadBuilder.build
local FP = PADSPEC.footprint
local PH = 0.6
local cx = (FP.minX + FP.maxX) / 2
local layout = {
    { FP.minX + PH, FP.minZ + PH }, { FP.maxX - PH, FP.minZ + PH },
    { FP.minX + PH, FP.maxZ - PH }, { FP.maxX - PH, FP.maxZ - PH },
    { cx, FP.minZ + PH }, { cx, FP.maxZ - PH },
}
local built, omitted = 0, 0
for _, l in layout do
    local top = mountCF * CFrame.new(l[1], 0, l[2])
    local g = raycastGround(top.Position.X, top.Position.Z)
    if g == nil then omitted += 1 else
        local foot = g - 1
        buildPost({ top.Position.X, (top.Position.Y + foot) / 2, top.Position.Z }, top.Position.Y - foot)
        built += 1
    end
end

-- mount a teahouse-1story on the pad's mount (right-hand base = no mirror)
local structure = SS.StructurePrefabs["teahouse-1story"]:Clone()
structure.Parent = demo
structure:PivotTo(mountCF)

-- camera framing the pad + structure from the front-below
local c = mountCF.Position
local cam = c + Vector3.new(0, 4, -46); local look = c + Vector3.new(0, -4, 0)
return string.format("posts built=%d omitted=%d | cam=%.1f,%.1f,%.1f look=%.1f,%.1f,%.1f",
    built, omitted, cam.X, cam.Y, cam.Z, look.X, look.Y, look.Z)
```

- [ ] **Step 2: Screenshot and STOP for the user**

Screenshot the pad + structure (front-below, so the posts and the frame-underside junction are visible). Verify: the structure's frame underside lands **flush on the post tops** (no gap, no overlap), the posts read as cliff stilts to terrain, and any over-void corners are cleanly omitted. Then **STOP** and ask the user to review. Do not self-judge or iterate.

- [ ] **Step 3: Clean up the scaffold and commit the record**

```lua
local d = workspace:FindFirstChild("PadDemo"); if d then d:Destroy() end
return "pad demo scaffold removed"
```

```bash
git add roblox/tools/studio/buildPadDemo.luau
git commit -m "chore(roblox): pad A<->B integration demo + visual gate"
```

---

## Self-review

- **Spec coverage:** PadSpec → Task 3 (baked) + the `PadSpec` type in Task 2; PadPlanner (post layout, heights, flush, over-void, injected groundAt) → Task 1; PadBuilder (ops-driven, returns mount) → Task 2; the A↔B seam (PivotTo lands frame on post tops) → Task 4; post style/6-post/flush/black-ink/omit-on-void → Global Constraints + Tasks 1 & 4; testing (planner Lune, builder fake-ops Lune, integration visual) → Tasks 1/2/4; the mount shape A consumes → Task 2 `Mount` + Task 4.
- **Placeholder scan:** the only intentional blanks are the surveyed numbers in Tasks 3–4 (`mountCF`/`footprint`), which are *produced by* Task 3's Studio steps and pasted forward — not plan placeholders. All code steps are complete.
- **Type consistency:** `Footprint {minX,maxX,minZ,maxZ}`, `Post {pos,height}`, `Support {posts,omitted}`, `PadSpec {mountCF,hand,footprint}`, `Mount {cframe,hand,footprint}`, `Ops {raycastGround,buildPost}` are consistent across Tasks 1→2→4; the `Spec.cframe`/`GetComponents` CFrame order is stated once and used identically in `xf` (Task 1), the tests, and the demo (Task 4).
