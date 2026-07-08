# Site-Fit Machinery Implementation Plan (sub-project D, increment 6.1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure, Lune-tested site-fit machinery the D.6 perch survey needs — spacing/encroachment (`spacingMax` via OBB-SAT), yaw-only enforcement (`isLevel`/`normalizeYaw`), size resolution (`resolveMaxSize`) — and delete the D.4/D.5 dead code (F3).

**Architecture:** One new pure module `roblox/src/shared/PadSiteFit.luau` (world-XZ oriented-box geometry, basic ops only — no trig — so it's CPU-arch-stable) + its Lune spec, plus removal of unreferenced `PadRegistry`/`SizeClasses` symbols. No Studio, no consumers yet.

**Tech Stack:** Luau `--!strict`; Lune bespoke harness (`tests/`, auto-discovers `*.spec.luau`); stylua + selene gates.

**Spec:** `docs/superpowers/specs/2026-07-08-roshambo-site-fit-machinery-design.md` (commit `79b9d09`).

## Global Constraints

- **Pure only.** No Roblox datatypes, no Studio, no `math.random`. `PadSiteFit` requires only `SizeClasses`.
- **No trig, basic ops only** (`+ - * /`, `math.abs`, `math.sqrt`) so output is bit-identical across CPU arch (per the genmodels arch-portability lesson) and float tests are stable. Float assertions use `toBeCloseTo`, never exact `toBe`.
- **12-number CFrame order** is `{px,py,pz, R…}` with `world = R*local + pos`: `worldX = px + cf[4]*lx + cf[5]*ly + cf[6]*lz`, `worldY = py + cf[7]*lx + cf[8]*ly + cf[9]*lz`, `worldZ = pz + cf[10]*lx + cf[11]*ly + cf[12]*lz` (matches `PadPlanner.xf`).
- **`spacingMax` returns `nil`** when even S collides.
- **F3 keeps** `PadRegistry.new/register/claim/release/get` and all live `SizeClasses` API; removes only the confirmed-dead symbols.
- **stylua + selene stay green** (`stylua --check src tests tools` + `selene src tools`; selene fails on warnings too).
- **Commit trailers** on every commit:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ
  ```

---

### Task 1: `PadSiteFit` module (pure, Lune-tested)

**Files:**
- Create: `roblox/src/shared/PadSiteFit.luau`
- Test: `roblox/tests/PadSiteFit.spec.luau`

**Interfaces:**
- Consumes: `SizeClasses.order`, `SizeClasses.footprintFor`, `SizeClasses.rank`, `SizeClasses.Footprint`.
- Produces: `footprintOBB(footprint, mountCF) -> OBB`, `overlaps(a: OBB, b: OBB) -> boolean`, `spacingMax(mountCF, keepOuts: {OBB}) -> string?`, `isLevel(mountCF, tol) -> boolean`, `normalizeYaw(mountCF) -> {number}`, `resolveMaxSize(a: string, b: string) -> string`. Types `Point = {number}` (`{x,z}`), `OBB = {Point}` (4 corners).

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/PadSiteFit.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local PadSiteFit = require("../src/shared/PadSiteFit")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

local IDENT = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } -- axis-aligned mount at origin

local function rect(minX: number, minZ: number, maxX: number, maxZ: number)
    return { { minX, minZ }, { maxX, minZ }, { maxX, maxZ }, { minX, maxZ } }
end

describe("PadSiteFit.overlaps (SAT)", function()
    test("separated rects do not overlap", function()
        expect(PadSiteFit.overlaps(rect(0, 0, 2, 2), rect(3, 0, 5, 2))).toBe(false)
    end)
    test("overlapping rects overlap", function()
        expect(PadSiteFit.overlaps(rect(0, 0, 2, 2), rect(1, 1, 3, 3))).toBe(true)
    end)
    test("edge contact counts as overlap", function()
        expect(PadSiteFit.overlaps(rect(0, 0, 2, 2), rect(2, 0, 4, 2))).toBe(true)
    end)
    test("two 45-deg diamonds whose AABBs overlap but true OBBs do not -> false", function()
        local d1 = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } } -- unit diamond at origin (AABB x,z in [-1,1])
        local d2 = { { 1.5, 2.5 }, { 2.5, 1.5 }, { 1.5, 0.5 }, { 0.5, 1.5 } } -- diamond, AABB x,z in [0.5,2.5]
        expect(PadSiteFit.overlaps(d1, d2)).toBe(false) -- separated along (1,1); an AABB test would say true
    end)
end)

describe("PadSiteFit.footprintOBB", function()
    test("axis-aligned mount -> footprint corners verbatim", function()
        local obb = PadSiteFit.footprintOBB({ minX = -1, maxX = 2, minZ = -3, maxZ = 4 }, IDENT)
        expect(obb[1][1]).toBeCloseTo(-1)
        expect(obb[1][2]).toBeCloseTo(-3)
        expect(obb[3][1]).toBeCloseTo(2)
        expect(obb[3][2]).toBeCloseTo(4)
    end)
    test("90-deg-yaw mount rotates corners", function()
        -- yaw 90: local X -> world +Z, local Z -> world -X (worldX = -lz, worldZ = lx)
        local yaw90 = { 0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }
        local obb = PadSiteFit.footprintOBB({ minX = 0, maxX = 2, minZ = 0, maxZ = 0 }, yaw90)
        expect(obb[2][1]).toBeCloseTo(0) -- (maxX=2, minZ=0) -> worldX = -0 = 0
        expect(obb[2][2]).toBeCloseTo(2) -- worldZ = lx = 2
    end)
end)

describe("PadSiteFit.spacingMax", function()
    test("no keep-outs -> L", function()
        expect(PadSiteFit.spacingMax(IDENT, {})).toBe("L")
    end)
    test("a keep-out clear of M but inside L -> M", function()
        -- M maxX = 15*1.5 = 22.5; L maxX = 15*2 = 30. A rect at x[23,28] hits L, misses M.
        expect(PadSiteFit.spacingMax(IDENT, { rect(23, -5, 28, 5) })).toBe("M")
    end)
    test("a keep-out over the origin collides with every size -> nil", function()
        expect(PadSiteFit.spacingMax(IDENT, { rect(-1, -1, 1, 1) })).toBe(nil)
    end)
    test("a rotated keep-out an AABB would hit does not shrink the pad", function()
        -- diamond far off the +X footprint edge; its AABB grazes but the OBB is clear of L
        local far = { { 40, 1 }, { 41, 0 }, { 40, -1 }, { 39, 0 } }
        expect(PadSiteFit.spacingMax(IDENT, { far })).toBe("L")
    end)
end)

describe("PadSiteFit.isLevel", function()
    test("a yaw-only mount is level", function()
        expect(PadSiteFit.isLevel({ 0, 0, 0, 0.6, 0, -0.8, 0, 1, 0, 0.8, 0, 0.6 }, 1e-6)).toBe(true)
    end)
    test("a pitched mount is not level", function()
        expect(PadSiteFit.isLevel({ 0, 0, 0, 1, 0, 0, 0.3, 0.95, 0, 0, 0, 1 }, 1e-6)).toBe(false)
    end)
    test("sub-tolerance pitch noise reads as level", function()
        expect(PadSiteFit.isLevel({ 0, 0, 0, 1, 0, 0, 1e-9, 1, 1e-9, 0, 0, 1 }, 1e-6)).toBe(true)
    end)
end)

describe("PadSiteFit.normalizeYaw", function()
    test("flattens pitch noise to pure yaw, preserving position and yaw", function()
        local noisy = { 5, 6, 7, 0.9754, 0, 0.2204, 3e-4, 1, -2e-4, -0.2204, 1e-4, 0.9754 }
        local out = PadSiteFit.normalizeYaw(noisy)
        expect(PadSiteFit.isLevel(out, 1e-9)).toBe(true)
        expect(out[1]).toBeCloseTo(5) -- position preserved
        expect(out[2]).toBeCloseTo(6)
        expect(out[3]).toBeCloseTo(7)
        expect(out[4]).toBeCloseTo(0.9754) -- yaw preserved (cos)
        expect(out[6]).toBeCloseTo(0.2204) -- yaw preserved (sin)
    end)
    test("an already-level mount is unchanged", function()
        local lvl = { 0, 0, 0, 0.6, 0, -0.8, 0, 1, 0, 0.8, 0, 0.6 }
        local out = PadSiteFit.normalizeYaw(lvl)
        for i = 1, 12 do
            expect(out[i]).toBeCloseTo(lvl[i])
        end
    end)
end)

describe("PadSiteFit.resolveMaxSize", function()
    test("returns the smaller of two sizes by rank", function()
        expect(PadSiteFit.resolveMaxSize("L", "M")).toBe("M")
        expect(PadSiteFit.resolveMaxSize("S", "L")).toBe("S")
        expect(PadSiteFit.resolveMaxSize("M", "M")).toBe("M")
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run (from `roblox/`): `lune run tests/run`
Expected: FAIL — `PadSiteFit` module doesn't exist.

- [ ] **Step 3: Implement the module**

Create `roblox/src/shared/PadSiteFit.luau`:

```lua
--!strict
-- Pure site-fit geometry for the D.6 perch survey (Lune-tested). Footprints and
-- keep-outs are yaw-oriented rectangles in world XZ. Basic ops only (no trig) so
-- output is CPU-arch-stable. Nothing consumes this yet — the Studio survey (a later
-- increment) produces the keep-outs and calls spacingMax / isLevel / normalizeYaw.
local SizeClasses = require("./SizeClasses")

local PadSiteFit = {}

export type Point = { number } -- {x, z}
export type OBB = { Point } -- 4 corners, consistent winding

-- world XZ of local (lx, lz) under the 12-number mountCF (world = R*local + pos)
local function xz(cf: { number }, lx: number, lz: number): Point
    return {
        cf[1] + cf[4] * lx + cf[6] * lz,
        cf[3] + cf[10] * lx + cf[12] * lz,
    }
end

function PadSiteFit.footprintOBB(footprint: SizeClasses.Footprint, mountCF: { number }): OBB
    local f = footprint
    return {
        xz(mountCF, f.minX, f.minZ),
        xz(mountCF, f.maxX, f.minZ),
        xz(mountCF, f.maxX, f.maxZ),
        xz(mountCF, f.minX, f.maxZ),
    }
end

-- the 2 unique edge normals of a rectangle (opposite edges are parallel)
local function axesOf(box: OBB): { Point }
    local out: { Point } = {}
    for i = 1, 2 do
        local a, b = box[i], box[i % 4 + 1]
        out[i] = { -(b[2] - a[2]), b[1] - a[1] } -- normal of edge a->b
    end
    return out
end

local function separated(a: OBB, b: OBB, axis: Point): boolean
    local amn, amx, bmn, bmx
    for _, p in a do
        local d = p[1] * axis[1] + p[2] * axis[2]
        amn = if amn == nil or d < amn then d else amn
        amx = if amx == nil or d > amx then d else amx
    end
    for _, p in b do
        local d = p[1] * axis[1] + p[2] * axis[2]
        bmn = if bmn == nil or d < bmn then d else bmn
        bmx = if bmx == nil or d > bmx then d else bmx
    end
    return (amx :: number) < (bmn :: number) or (bmx :: number) < (amn :: number)
end

function PadSiteFit.overlaps(a: OBB, b: OBB): boolean
    for _, axis in axesOf(a) do
        if separated(a, b, axis) then
            return false
        end
    end
    for _, axis in axesOf(b) do
        if separated(a, b, axis) then
            return false
        end
    end
    return true
end

function PadSiteFit.spacingMax(mountCF: { number }, keepOuts: { OBB }): string?
    for _, size in SizeClasses.order do
        local obb = PadSiteFit.footprintOBB(SizeClasses.footprintFor(size), mountCF)
        local clear = true
        for _, k in keepOuts do
            if PadSiteFit.overlaps(obb, k) then
                clear = false
                break
            end
        end
        if clear then
            return size
        end
    end
    return nil
end

function PadSiteFit.isLevel(mountCF: { number }, tol: number): boolean
    return math.abs(mountCF[7]) < tol and math.abs(mountCF[9]) < tol and math.abs(mountCF[8] - 1) < tol
end

function PadSiteFit.normalizeYaw(mountCF: { number }): { number }
    -- project the mount's local-X world image onto XZ, renormalize (sqrt/div, no trig),
    -- rebuild a pure-yaw orthonormal rotation: X=(ex,0,ez), Y=(0,1,0), Z = X x Y = (-ez,0,ex).
    local fx, fz = mountCF[4], mountCF[10]
    local len = math.sqrt(fx * fx + fz * fz)
    local ex, ez = fx / len, fz / len
    return {
        mountCF[1],
        mountCF[2],
        mountCF[3],
        ex,
        0,
        -ez,
        0,
        1,
        0,
        ez,
        0,
        ex,
    }
end

function PadSiteFit.resolveMaxSize(a: string, b: string): string
    return if SizeClasses.rank[a] <= SizeClasses.rank[b] then a else b
end

return PadSiteFit
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `roblox/`): `lune run tests/run`
Expected: PASS (all PadSiteFit tests + the full existing suite).

- [ ] **Step 5: Lint**

Run (from `roblox/`): `stylua src tests && stylua --check src tests tools && selene src tools`
Expected: no diffs, 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/PadSiteFit.luau roblox/tests/PadSiteFit.spec.luau
git commit -m "feat(roblox): PadSiteFit — spacing (OBB-SAT), level, resolveMaxSize (sub-project D, increment 6.1)"
```

---

### Task 2: F3 — remove dead `PadRegistry`/`SizeClasses` code

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau`
- Modify: `roblox/src/shared/PadRegistry.luau`
- Test: `roblox/tests/SizeClasses.spec.luau`, `roblox/tests/PadRegistry.spec.luau`

**Interfaces:**
- Removes (confirmed zero live references): `SizeClasses.nativeSize`; `PadRegistry.fits`, `PadRegistry:findVacant`, `PadRegistry:claimVacant`, `PadRegistry:claimVacantFor`.
- Keeps: `SizeClasses` footprint/rank/scale/order/fitsWithin; `PadRegistry.new/register/claim/release/get`.

- [ ] **Step 1: Remove the `nativeSize` tests**

In `roblox/tests/SizeClasses.spec.luau`, delete the entire `describe("SizeClasses.nativeSize", ...)` block (its three tests: base→S, 2x→L, too-small→nil).

- [ ] **Step 2: Remove the dead `PadRegistry` tests + fix the `release` test**

In `roblox/tests/PadRegistry.spec.luau`:
- Delete these whole `test(...)` blocks: `"findVacant returns first-registered vacant id; nil when full"`, `"claimVacant returns {id,spec}, marks claimed, hands out in registration order"`, `"fits: contained/exact -> true; overhang -> false"`, and all three `"claimVacantFor: ..."` tests.
- In the surviving `"release frees a claimed pad; ..."` test, replace the `findVacant`-based assertion:
  ```lua
      expect(r:findVacant()).toBe("a")
  ```
  with:
  ```lua
      expect(r:get("a").occupant).toBeNil()
  ```

- [ ] **Step 3: Run tests to verify the suite is green without the deleted code's tests**

Run (from `roblox/`): `lune run tests/run`
Expected: PASS — the removed tests are gone; the release test now asserts via `get`. (The implementations still exist at this point, just untested.)

- [ ] **Step 4: Remove `nativeSize` + the `PadRegistry` require from `SizeClasses`**

In `roblox/src/shared/SizeClasses.luau`:
- Delete the `local PadRegistry = require("./PadRegistry")` line (near the top).
- Delete the entire `function SizeClasses.nativeSize(padFootprint) ... end` block.

- [ ] **Step 5: Remove the dead functions from `PadRegistry`**

In `roblox/src/shared/PadRegistry.luau`, delete these four function blocks: `PadRegistry.fits`, `PadRegistry:findVacant`, `PadRegistry:claimVacant`, `PadRegistry:claimVacantFor`. Keep `new`, `register`, `claim`, `release`, `get`. (Also drop the now-stale "claimVacant() on spawn" phrase in the header comment if present — the header mentions the removed op.)

- [ ] **Step 6: Run tests + lint**

Run (from `roblox/`): `lune run tests/run && stylua src tests && stylua --check src tests tools && selene src tools`
Expected: PASS; no diffs; 0 errors; 0 warnings. (Confirms nothing referenced the removed symbols — `SizeClasses` no longer requires `PadRegistry`.)

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/src/shared/PadRegistry.luau roblox/tests/SizeClasses.spec.luau roblox/tests/PadRegistry.spec.luau
git commit -m "refactor(roblox): remove dead PadRegistry/SizeClasses code, decouple the two (F3)"
```

---

## Self-Review

**1. Spec coverage:** `spacingMax`/`overlaps`/`footprintOBB` (T1) ✓; `isLevel`/`normalizeYaw` (T1) ✓; `resolveMaxSize` (T1) ✓; F3 deletions (T2) ✓. The Studio survey/consumers are correctly absent (non-goal).

**2. Placeholder scan:** none — every step has concrete code or an exact edit.

**3. Type/name consistency:** `OBB`/`Point` used identically in module and spec; 12-number CFrame indexing (`cf[4]/cf[6]/cf[10]/cf[12]` for the yaw XZ terms, `cf[7]/cf[8]/cf[9]` for the level check) matches `PadPlanner.xf` and the spec; `normalizeYaw`'s output is orthonormal pure-yaw (`X=(ex,0,ez)`, `Z=X×Y=(-ez,0,ex)`), verified to be identity on an already-level mount (the `T02`-style test).

**4. Arch-stability:** no trig anywhere (`spacingMax` and `normalizeYaw` use `*`/`+`/`sqrt`/`abs` only); float assertions use `toBeCloseTo`. Consistent with the genmodels arch-portability rule — no risk of reintroducing the CI drift class.

**5. F3 safety:** the only non-obvious edge — the `release` test's use of `findVacant` — is explicitly rewritten (T2 Step 2). `SizeClasses` loses its `PadRegistry` require (nativeSize was the sole user), which Step 6's green run confirms.

## Execution Handoff

**"Plan complete and saved to `docs/superpowers/plans/2026-07-08-roshambo-site-fit-machinery.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh implementer per task, review between. Both tasks are pure Lune-TDD / mechanical deletion — cheap-tier work.

**2. Inline Execution** — both tasks in this session with checkpoints.

**Which approach?"**
