# NW1012 Ishidan Stairway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the too-steep NW1012 stepped-cobble path with a slate ishidan stairway (~75–80 uniform-riser steps + 2 landings) that lands on an angled deck pad at the Overlook's lamp-newel corner.

**Architecture:** A pure, deterministic layout module (`tools/builders/IshidanStairs.luau`, Lune-tested) computes flights/steps/slabs from a baked centerline polyline; a standalone Studio runnable (`tools/studio/buildIshidanStairs.luau`) mirrors it and builds Parts. Deck pad, terrain carve, walls, railing, and chōchin are staged Studio scripts reusing the existing §-recipe builders via the `Step_<i>` part contract.

**Tech Stack:** Luau (Lune tests via bespoke harness), Roblox Studio via MCP `execute_luau`, existing builders in `roblox/tools/studio/`.

**Spec:** `docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md` (read it first; it holds the why and the survey table).

## Global Constraints

- **Stop-and-ask:** every USER GATE below is a hard stop — one attempt, then wait for the user to look/walk. Never self-judge visuals. No screenshots in reports; describe in words.
- **Place-only build:** everything under `Workspace.*` here persists only via the saved place. Remind the user to **save the place** at every gate. Never `rojo build` to ship.
- **Datamodels:** `Edit` is unavailable during Play (and `Client`/`Server` unavailable in Edit). If a call errors with "not available", the user toggled Play — switch datamodel or ask.
- **Terrain:** cut-only carves (clear `Air` above a target floor ≤ terrain; never fill-to-target). `Terrain:CopyRegion` snapshot → `ServerStorage` before ANY carve. Verify a carve in a **separate** `execute_luau` call — same-call reads are stale.
- **Heights are analytic** from the stair math. Never raycast a Box-collision MeshPart/Part for Y. Terrain raycasts are fine.
- **No draft-marker dependence in final builders:** survey once, bake coordinates into CONFIG. Markers get deleted later.
- **Flush outside edges** (standing user rule): supports/posts have their outer face flush with the edge of what they carry.
- **Part contract for downstream builders:** each step emits a full-width bed Part named `Step_<i>` (index from 0 at the foot), `CFrame.fromMatrix(pos, cross, Vector3.yAxis)` so **RightVector = cross-stream**, top ≈ tread − 0.05. `buildIshigakiWalls` / `buildBambooRailing` / `buildChochinPole` consume `prefix="Step"` unchanged.
- **Mirror rule:** `tools/studio/buildIshidanStairs.luau` mirrors `tools/builders/IshidanStairs.luau` (MCP Studio scripts cannot `require` repo modules). Any change to one must be copied to the other — same precedent as CanyonPath ↔ buildPaths.
- **Lint before commit:** from `roblox/`: `stylua src tests tools && selene src tools` (selene on tools may warn about `game`/`workspace` globals in studio scripts — matching existing files is fine).
- Tests: from `roblox/`: `lune run tests/run` (runs the whole suite; it's fast).

**Fixed design numbers (from the approved spec):** riser target **0.6** (accept 0.55–0.65 per flight); slab width **6.4**, depth **1.25**, body **0.8**; bed width **5.8**, thickness **1.2**, top **0.05 below tread**; stone color base **RGB 96/98/94 ±3**, Material **Slate**; jitter yaw **±2°**, lateral **±0.15**, size **±5%**; seed **20260702**; 2 landings ~⅓/~⅔ arc, len **5**; head tread **162.6** (must match existing so `Rail_NW1012_Tunnel` still meets it); pad top **113.3**.

---

### Task 1: `IshidanStairs.resample` + `IshidanStairs.layout` (pure flight math)

**Files:**
- Create: `roblox/tools/builders/IshidanStairs.luau`
- Test: `roblox/tests/IshidanStairs.spec.luau`

**Interfaces:**
- Consumes: nothing (pure; data-in/data-out, `{ {x, y, z} }` triples like `CanyonPath`).
- Produces:
  - `IshidanStairs.resample(control: { {number} }, spacing: number): { {number} }` — Catmull-Rom through control points, sampled every `spacing` studs of horizontal arc, endpoints included.
  - `IshidanStairs.layout(polyline: { {number} }, opts): Layout` where `opts = { riserTarget: number, footY: number, headY: number, landings: { { frac: number, len: number } } }` and `Layout = { flights: { {n: number, riser: number, pitch: number} }, steps: { Step } }`, `Step = { i: number, kind: "step"|"landing", pos: {number}, dir: {number}, tread: number, riser: number, pitch: number, len: number? }` — `i` counts from 0 at the foot; `pos` is the step-center XZ from the polyline with `pos[2] = tread`; `dir` is the unit horizontal heading `{dx, dz}`; landings get `kind="landing"`, `len`, and a flat `tread`.

- [ ] **Step 1: Write the failing tests**

```luau
--!strict
local harness = require("./harness")
local IshidanStairs = require("../tools/builders/IshidanStairs")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("IshidanStairs.resample", function()
    local control = { { 0, 100, 0 }, { 10, 105, 0 }, { 20, 110, 0 } }
    test("endpoints preserved", function()
        local p = IshidanStairs.resample(control, 2)
        expect(p[1][1]).toBeCloseTo(0)
        expect(p[#p][1]).toBeCloseTo(20)
    end)
    test("passes near interior control points", function()
        local p = IshidanStairs.resample(control, 0.5)
        local best = math.huge
        for _, q in p do
            best = math.min(best, math.abs(q[1] - 10) + math.abs(q[3] - 0))
        end
        expect(best < 0.6).toBe(true)
    end)
end)

describe("IshidanStairs.layout", function()
    -- straight 78-run, 42-rise line (the real NW1012 numbers, simplified)
    local line = {}
    for d = 0, 78 do
        table.insert(line, { d, 113.3 + d * (42.4 / 78), 0 })
    end
    local opts = { riserTarget = 0.6, footY = 113.3, headY = 155.7, landings = {} }

    test("uniform risers within a flight", function()
        local L = IshidanStairs.layout(line, opts)
        local r = L.steps[1].riser
        for _, s in L.steps do
            if s.kind == "step" then
                expect(s.riser).toBeCloseTo(r)
            end
        end
    end)
    test("risers near target", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[1].riser > 0.5 and L.steps[1].riser < 0.7).toBe(true)
    end)
    test("head tread is exact", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[#L.steps].tread).toBeCloseTo(155.7)
    end)
    test("treads are strictly monotonic", function()
        local L = IshidanStairs.layout(line, opts)
        for k = 2, #L.steps do
            expect(L.steps[k].tread > L.steps[k - 1].tread - 1e-6).toBe(true)
        end
    end)
    test("first tread is one riser above footY", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[1].tread).toBeCloseTo(113.3 + L.steps[1].riser)
    end)
    test("landing is flat, sits between flights, consumes its arc", function()
        local withL = { riserTarget = 0.6, footY = 113.3, headY = 155.7,
            landings = { { frac = 0.5, len = 5 } } }
        local L = IshidanStairs.layout(line, withL)
        local nLand = 0
        for k = 2, #L.steps do
            local s = L.steps[k]
            if s.kind == "landing" then
                nLand += 1
                expect(s.tread).toBeCloseTo(L.steps[k - 1].tread) -- flat: same height as step below
                expect(s.len).toBe(5)
            end
        end
        expect(nLand).toBe(1)
        expect(#L.flights).toBe(2)
    end)
    test("dir is unit horizontal heading", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[1].dir[1]).toBeCloseTo(1)
        expect(L.steps[1].dir[2]).toBeCloseTo(0)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run (from `roblox/`): `lune run tests/run`
Expected: FAIL — module not found / new spec errors. (Pre-existing suites still pass.)

- [ ] **Step 3: Implement the module**

```luau
--!strict
-- Ishidan (stone stair) layout: from a centerline polyline, compute uniform-riser
-- flights, flat landings, and per-step positions/headings. Pure + deterministic
-- (seeded LCG, no math.random) so it is Lune-tested; the Studio runnable
-- (tools/studio/buildIshidanStairs.luau) mirrors this logic since MCP Studio
-- scripts cannot require repo modules — keep them in sync.
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local IshidanStairs = {}

local function hyp(dx: number, dz: number): number
    return math.sqrt(dx * dx + dz * dz)
end

-- Catmull-Rom through control points (clamped ends), sampled ~every `spacing`
-- studs of horizontal arc. Returns { {x, y, z} }, endpoints included.
function IshidanStairs.resample(control: { { number } }, spacing: number): { { number } }
    local n = #control
    assert(n >= 2, "need at least 2 control points")
    local function P(i: number): { number }
        return control[math.clamp(i, 1, n)]
    end
    local out: { { number } } = { { control[1][1], control[1][2], control[1][3] } }
    for seg = 1, n - 1 do
        local p0, p1, p2, p3 = P(seg - 1), P(seg), P(seg + 1), P(seg + 2)
        local segRun = hyp(p2[1] - p1[1], p2[3] - p1[3])
        local samples = math.max(1, math.ceil(segRun / spacing))
        for k = 1, samples do
            local t = k / samples
            local q = {}
            for a = 1, 3 do
                local t2, t3 = t * t, t * t * t
                q[a] = 0.5 * ((2 * p1[a]) + (-p0[a] + p2[a]) * t
                    + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t2
                    + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t3)
            end
            table.insert(out, q)
        end
    end
    return out
end

type Landing = { frac: number, len: number }
type LayoutOpts = { riserTarget: number, footY: number, headY: number, landings: { Landing } }
export type Step = {
    i: number, kind: string, pos: { number }, dir: { number },
    tread: number, riser: number, pitch: number, len: number?,
}

-- cumulative horizontal arc table + samplers for pos/dir at an arc distance
local function arcTable(polyline: { { number } })
    local cum = { 0 }
    for k = 2, #polyline do
        local a, b = polyline[k - 1], polyline[k]
        cum[k] = cum[k - 1] + hyp(b[1] - a[1], b[3] - a[3])
    end
    local total = cum[#cum]
    local function at(d: number): ({ number }, { number })
        d = math.clamp(d, 0, total)
        for k = 2, #polyline do
            if d <= cum[k] + 1e-9 then
                local a, b = polyline[k - 1], polyline[k]
                local seg = cum[k] - cum[k - 1]
                local t = seg > 1e-9 and (d - cum[k - 1]) / seg or 0
                local run = hyp(b[1] - a[1], b[3] - a[3])
                local dir = run > 1e-9 and { (b[1] - a[1]) / run, (b[3] - a[3]) / run } or { 1, 0 }
                return {
                    a[1] + (b[1] - a[1]) * t,
                    a[2] + (b[2] - a[2]) * t,
                    a[3] + (b[3] - a[3]) * t,
                }, dir
            end
        end
        local last = polyline[#polyline]
        return { last[1], last[2], last[3] }, { 1, 0 }
    end
    return total, at
end

function IshidanStairs.layout(polyline: { { number } }, opts: LayoutOpts)
    local total, at = arcTable(polyline)
    -- flight arc boundaries from landings (foot-first fracs)
    local marks: { { a0: number, a1: number, landing: Landing? } } = {}
    local cursor = 0
    local sorted = table.clone(opts.landings)
    table.sort(sorted, function(x, y)
        return x.frac < y.frac
    end)
    for _, l in sorted do
        local a = math.clamp(l.frac, 0.05, 0.95) * total
        table.insert(marks, { a0 = cursor, a1 = a, landing = l })
        cursor = a + l.len
    end
    table.insert(marks, { a0 = cursor, a1 = total })

    -- flight end elevations: intermediate boundaries follow the polyline profile,
    -- snapped analytic; the final flight ends exactly at headY.
    local steps: { Step } = {}
    local flights = {}
    local E0 = opts.footY
    local idx = 0
    for m, fl in marks do
        local isLast = (m == #marks)
        local posEnd = select(1, at(fl.a1))
        local E1 = isLast and opts.headY or posEnd[2]
        local rise = E1 - E0
        local runArc = fl.a1 - fl.a0
        local n = math.max(1, math.floor(rise / opts.riserTarget + 0.5))
        local riser = rise / n
        local pitch = runArc / n
        table.insert(flights, { n = n, riser = riser, pitch = pitch })
        for i = 1, n do
            local d = fl.a0 + (i - 0.5) * pitch
            local pos, dir = at(d)
            local tread = E0 + i * riser
            idx += 1
            table.insert(steps, {
                i = idx - 1, kind = "step", pos = { pos[1], tread, pos[3] },
                dir = dir, tread = tread, riser = riser, pitch = pitch,
            })
        end
        E0 = E1
        if fl.landing then
            local d = fl.a1 + fl.landing.len / 2
            local pos, dir = at(d)
            idx += 1
            table.insert(steps, {
                i = idx - 1, kind = "landing", pos = { pos[1], E0, pos[3] },
                dir = dir, tread = E0, riser = 0, pitch = 0, len = fl.landing.len,
            })
        end
    end
    return { flights = flights, steps = steps }
end

return IshidanStairs
```

- [ ] **Step 4: Run tests**

Run: `lune run tests/run`
Expected: PASS (all suites).

- [ ] **Step 5: Lint + commit**

```bash
cd roblox && stylua tools/builders/IshidanStairs.luau tests/IshidanStairs.spec.luau && selene tools/builders/IshidanStairs.luau
git add roblox/tools/builders/IshidanStairs.luau roblox/tests/IshidanStairs.spec.luau
git commit -m "feat(roblox): IshidanStairs flight-layout math (resample + uniform-riser layout)"
```

---

### Task 2: `IshidanStairs.slabs` (stone + bed emission with seeded jitter)

**Files:**
- Modify: `roblox/tools/builders/IshidanStairs.luau` (append)
- Test: `roblox/tests/IshidanStairs.spec.luau` (append)

**Interfaces:**
- Consumes: `Layout` from `IshidanStairs.layout` (Task 1).
- Produces: `IshidanStairs.slabs(layout, opts): { StepBuild }` where `opts = { width: number, depth: number, body: number, bedW: number, bedH: number, seed: number }` and `StepBuild = { i: number, kind: string, bed: Box, stones: { Stone } }`, `Box = { pos: {number}, dir: {number}, size: {number} }`, `Stone = Box & { yawDeg: number, tint: number }`. `bed.pos[2]` centers the bed so its **top = tread − 0.05**; stone tops = tread. For `kind="landing"` the entry has `stones = {}` and a bed sized `len + 1` along travel (cobbles come later, §Task 9).

- [ ] **Step 1: Write the failing tests** (append to the spec file)

```luau
describe("IshidanStairs.slabs", function()
    local line = {}
    for d = 0, 78 do
        table.insert(line, { d, 113.3 + d * (42.4 / 78), 0 })
    end
    local layout = IshidanStairs.layout(line, { riserTarget = 0.6, footY = 113.3, headY = 155.7, landings = {} })
    local opts = { width = 6.4, depth = 1.25, body = 0.8, bedW = 5.8, bedH = 1.2, seed = 20260702 }

    test("deterministic for a fixed seed", function()
        local a = IshidanStairs.slabs(layout, opts)
        local b = IshidanStairs.slabs(layout, opts)
        expect(a[1].stones[1].pos[1]).toBeCloseTo(b[1].stones[1].pos[1])
        expect(a[1].stones[1].yawDeg).toBeCloseTo(b[1].stones[1].yawDeg)
    end)
    test("stone tops sit at the tread", function()
        local S = IshidanStairs.slabs(layout, opts)
        local step = layout.steps[1]
        local stone = S[1].stones[1]
        expect(stone.pos[2] + stone.size[2] / 2).toBeCloseTo(step.tread)
    end)
    test("bed top is 0.05 below the tread and narrower than the stones' full width", function()
        local S = IshidanStairs.slabs(layout, opts)
        local step = layout.steps[1]
        expect(S[1].bed.pos[2] + S[1].bed.size[2] / 2).toBeCloseTo(step.tread - 0.05)
        expect(S[1].bed.size[1]).toBeCloseTo(5.8)
    end)
    test("split steps: cross widths sum to width minus one 0.08 grout gap", function()
        local S = IshidanStairs.slabs(layout, opts)
        local found = false
        for _, sb in S do
            if #sb.stones == 2 then
                found = true
                expect(sb.stones[1].size[1] + sb.stones[2].size[1]).toBeCloseTo(6.4 - 0.08, 1)
            end
        end
        expect(found).toBe(true) -- with ~80 steps and splitFrac 0.5, at least one split
    end)
    test("jitter stays in bounds", function()
        local S = IshidanStairs.slabs(layout, opts)
        for _, sb in S do
            for _, st in sb.stones do
                expect(math.abs(st.yawDeg) <= 2 + 1e-6).toBe(true)
                expect(math.abs(st.tint) <= 3 + 1e-6).toBe(true)
            end
        end
    end)
end)
```

- [ ] **Step 2: Run to verify failure** — `lune run tests/run`, expected FAIL (`slabs` nil).

- [ ] **Step 3: Implement** (append to `IshidanStairs.luau`, before the final `return`)

```luau
-- deterministic LCG (Numerical Recipes constants), returns [0,1)
local function makeRng(seed: number): () -> number
    local state = seed % 2 ^ 32
    return function(): number
        state = (1664525 * state + 1013904223) % 2 ^ 32
        return state / 2 ^ 32
    end
end

type SlabOpts = { width: number, depth: number, body: number, bedW: number, bedH: number, seed: number }

function IshidanStairs.slabs(layout: any, opts: SlabOpts)
    local rng = makeRng(opts.seed)
    local out = {}
    for _, s in layout.steps :: { Step } do
        local perp = { -s.dir[2], s.dir[1] } -- unit cross-stream (left of travel)
        if s.kind == "landing" then
            local len = (s.len :: number) + 1
            table.insert(out, {
                i = s.i, kind = s.kind, stones = {},
                bed = {
                    pos = { s.pos[1], s.tread - 0.05 - opts.bedH / 2, s.pos[3] },
                    dir = s.dir, size = { opts.bedW, opts.bedH, len },
                },
            })
            continue
        end
        local stones = {}
        local split = rng() < 0.5
        local depth = opts.depth * (0.95 + 0.10 * rng())
        local widths = { opts.width }
        if split then
            local f = 0.4 + 0.2 * rng() -- 40–60% split
            widths = { opts.width * f - 0.04, opts.width * (1 - f) - 0.04 } -- 0.08 grout gap
        end
        local edge = -opts.width / 2
        for _, w in widths do
            local cCross = edge + w / 2
            edge += w + 0.08
            local lat = (rng() * 2 - 1) * 0.15
            local along = (rng() * 2 - 1) * 0.1
            table.insert(stones, {
                pos = {
                    s.pos[1] + perp[1] * cCross + s.dir[1] * along + perp[1] * lat,
                    s.tread - opts.body / 2,
                    s.pos[3] + perp[2] * cCross + s.dir[2] * along + perp[2] * lat,
                },
                dir = s.dir,
                yawDeg = (rng() * 2 - 1) * 2,
                size = { w, opts.body, depth },
                tint = math.floor((rng() * 2 - 1) * 3 + 0.5),
            })
        end
        table.insert(out, {
            i = s.i, kind = s.kind, stones = stones,
            bed = {
                pos = { s.pos[1], s.tread - 0.05 - opts.bedH / 2, s.pos[3] },
                dir = s.dir, size = { opts.bedW, opts.bedH, s.pitch + 0.5 },
            },
        })
    end
    return out
end
```

- [ ] **Step 4: Run tests** — `lune run tests/run`, expected PASS.

- [ ] **Step 5: Lint + commit**

```bash
cd roblox && stylua tools/builders/IshidanStairs.luau tests/IshidanStairs.spec.luau && selene tools/builders/IshidanStairs.luau
git add roblox/tools/builders/IshidanStairs.luau roblox/tests/IshidanStairs.spec.luau
git commit -m "feat(roblox): IshidanStairs slab/bed emission with seeded jitter"
```

---

### Task 3: Studio runnable `buildIshidanStairs.luau` (mirror + CONFIG)

**Files:**
- Create: `roblox/tools/studio/buildIshidanStairs.luau`

**Interfaces:**
- Consumes: verbatim copies of `resample`, `arcTable`, `layout`, `makeRng`, `slabs` from `roblox/tools/builders/IshidanStairs.luau` (Tasks 1–2) — paste them under the header; MCP Studio scripts cannot `require` repo modules.
- Produces: on run in Studio, builds `Workspace.<CONFIG.outModel>` containing per step: `Step_<i>` (the bed Part — the downstream contract), `Stone_<i>a` / `Stone_<i>b` (Slate). Idempotent: destroys and rebuilds `outModel`. `CONFIG.buildRange = {i0, i1}` builds a subset (staged attempts); `nil` = all.

- [ ] **Step 1: Write the runnable** — header + CONFIG + the mirrored functions + the Part emitter:

```luau
-- buildIshidanStairs.luau — slate ishidan stairway from a BAKED centerline.
-- MIRROR of tools/builders/IshidanStairs.luau (Lune-tested) — keep in sync.
-- Run in Studio (command bar / MCP execute_luau, Edit datamodel).
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local CONFIG = {
    outModel = "NW1012Stairs",
    control = {}, -- BAKED {x,y,z} centerline control points, FOOT (pad edge) FIRST — from bakeNW1012Stairway (Task 4)
    footY = 113.3, -- pad top; first tread = footY + riser
    headY = 162.6, -- must equal the old Timber_23 top so Rail_NW1012_Tunnel still meets the head
    riserTarget = 0.6,
    landings = { { frac = 0.33, len = 5 }, { frac = 0.66, len = 5 } },
    width = 6.4, depth = 1.25, body = 0.8, bedW = 5.8, bedH = 1.2,
    seed = 20260702,
    buildRange = nil :: { number }?, -- {i0, i1} step indices to build; nil = all
    resampleSpacing = 2.0,
    stoneColor = Color3.fromRGB(96, 98, 94),
    bedColor = Color3.fromRGB(138, 142, 142),
    bedMaterialVariant = "ZenCement2",
}

-- >>> PASTE the mirrored pure functions here (resample, arcTable, layout, makeRng, slabs) <<<

local function box(name: string, b, material: Enum.Material, color: Color3, parent: Instance, yawDeg: number?)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Material = material
    p.Color = color
    p.Size = Vector3.new(b.size[1], b.size[2], b.size[3])
    local cross = Vector3.new(-b.dir[2], 0, b.dir[1])
    local cf = CFrame.fromMatrix(Vector3.new(b.pos[1], b.pos[2], b.pos[3]), cross, Vector3.yAxis)
    if yawDeg and yawDeg ~= 0 then
        cf = cf * CFrame.Angles(0, math.rad(yawDeg), 0)
    end
    p.CFrame = cf
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local old = workspace:FindFirstChild(CONFIG.outModel)
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = CONFIG.outModel
model.Parent = workspace

local polyline = resample(CONFIG.control, CONFIG.resampleSpacing)
local layoutR = layout(polyline, {
    riserTarget = CONFIG.riserTarget, footY = CONFIG.footY, headY = CONFIG.headY,
    landings = CONFIG.landings,
})
local builds = slabs(layoutR, {
    width = CONFIG.width, depth = CONFIG.depth, body = CONFIG.body,
    bedW = CONFIG.bedW, bedH = CONFIG.bedH, seed = CONFIG.seed,
})
local made = 0
for _, sb in builds do
    if CONFIG.buildRange and (sb.i < CONFIG.buildRange[1] or sb.i > CONFIG.buildRange[2]) then
        continue
    end
    local bed = box("Step_" .. sb.i, sb.bed, Enum.Material.Concrete, CONFIG.bedColor, model)
    bed.MaterialVariant = CONFIG.bedMaterialVariant
    for si, st in sb.stones do
        local stone = box(
            "Stone_" .. sb.i .. string.char(96 + si), st, Enum.Material.Slate,
            Color3.fromRGB(96 + st.tint, 98 + st.tint, 94 + st.tint), model, st.yawDeg
        )
        stone.CastShadow = true
    end
    made += 1
end
print(("NW1012Stairs: built %d/%d steps (flights: %d)"):format(made, #builds, #layoutR.flights))
```

**Important:** the seed drives ONE rng stream across ALL steps, so `buildRange` must not change jitter — `slabs` always computes every step (cheap) and the range filter only skips Part creation (as written above). Do not "optimize" by slicing steps before `slabs`.

- [ ] **Step 2: Verify the mirror is faithful**

Run: `lune run tests/run` (still green — the module is untouched). Then diff the pasted functions against the module by eye or:
`diff <(sed -n '/^local function hyp/,/^return IshidanStairs/p' roblox/tools/builders/IshidanStairs.luau) <(grep -A400 "PASTE" roblox/tools/studio/buildIshidanStairs.luau)` — expect only the type-export / `IshidanStairs.` prefix differences.

- [ ] **Step 3: Lint + commit**

```bash
cd roblox && stylua tools/studio/buildIshidanStairs.luau
git add roblox/tools/studio/buildIshidanStairs.luau
git commit -m "feat(roblox): buildIshidanStairs Studio runnable (mirror of IshidanStairs)"
```

---

### Task 4: Survey & bake (Studio) — centerline, pad frame, landing proposals

**Files:**
- Create: `roblox/tools/studio/bakeNW1012Stairway.luau` (the survey script, kept for re-runs)
- Modify: `roblox/tools/studio/buildIshidanStairs.luau` (paste baked `control` into CONFIG)
- Modify: `docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md` (record baked numbers under a new "As-built" heading)

**Interfaces:**
- Consumes: live Studio state — `Workspace.NW1012Path.NW1012Timber_1..23` (MUST run before Task 5 teardown), `Workspace.PathDraft.NW10Foot.Marker_1..3`, `Workspace.PathDraft.NearWall_10`, `Workspace.RoshamboStage.Overlook.UpperDeck` + `NewelUpperDeck4`.
- Produces: printed Luau literals — `control = { ... }` (foot-first: pad-edge point, 3 foot markers' XZ, then the 23 timber centers' XZ with their tread Ys), and `PAD = { center = {x,z}, heading = {dx,dz}, topY = 113.3, wCross = 7.5, dAlong = 5.5, deckColor = {r,g,b} }` (pad frame: heading = unit XZ from Marker_2→NearWall_10; pad's stair-side edge = the stair foot; center placed so the deck-side reach crosses the Overlook west edge at X=57). Also prints total run/rise per candidate flight split so landings land on real meander points.

- [ ] **Step 1: Write + run the survey via MCP `execute_luau` (Edit)**

```luau
-- bakeNW1012Stairway.luau — survey once, paste output into buildIshidanStairs CONFIG.
local out = {}
local function v3(v) return string.format("{ %.2f, %.2f, %.2f },", v.X, v.Y, v.Z) end
table.insert(out, "control = {")
-- foot-first: pad edge point (stair meets pad), then foot markers, then timbers 1..23
local nw10 = workspace.PathDraft.NearWall_10.Position
local m = { workspace.PathDraft.NW10Foot.Marker_3, workspace.PathDraft.NW10Foot.Marker_2, workspace.PathDraft.NW10Foot.Marker_1 }
local heading = (Vector3.new(nw10.X, 0, nw10.Z) - Vector3.new(m[2].Position.X, 0, m[2].Position.Z)).Unit
table.insert(out, "  -- pad edge (stair foot)")
table.insert(out, v3(Vector3.new(nw10.X, 113.3, nw10.Z)))
table.insert(out, "  -- foot markers (terrain Y; layout ignores interior Y except at flight bounds)")
for i = #m, 1, -1 do
    table.insert(out, v3(Vector3.new(m[i].Position.X, m[i].Position.Y - 1.0, m[i].Position.Z)))
end
table.insert(out, "  -- old timber centers (tread grade)")
local path = workspace.NW1012Path
for i = 1, 23 do
    local t = path:FindFirstChild("NW1012Timber_" .. i)
    table.insert(out, v3(Vector3.new(t.Position.X, t.Position.Y + t.Size.Y / 2, t.Position.Z)))
end
table.insert(out, "}")
local deck = workspace.RoshamboStage.Overlook.UpperDeck
table.insert(out, string.format(
    "PAD = { center = {%.2f, %.2f}, heading = {%.3f, %.3f}, topY = %.2f, deckEdgeX = %.1f, deckColor = {%d, %d, %d} }",
    nw10.X + heading.X * 2.75, nw10.Z + heading.Z * 2.75, heading.X, heading.Z,
    deck.Position.Y + deck.Size.Y / 2, deck.Position.X - deck.Size.X / 2,
    deck.Color.R * 255, deck.Color.G * 255, deck.Color.B * 255))
return table.concat(out, "\n")
```

- [ ] **Step 2: Sanity-check the output** — control points strictly descend foot→…wait, they're foot-first so they strictly ASCEND in Y after the first four entries; XZ steps between neighbors all < 15 studs; heading points into the deck (positive X component). If the old path model is already gone, STOP — teardown ran early; restore from `ServerStorage.NW1012Retired` (Task 5) and re-survey.

- [ ] **Step 3: Paste** the `control` literal into `buildIshidanStairs.luau` CONFIG; save the survey script to `roblox/tools/studio/bakeNW1012Stairway.luau`; append the printed literals verbatim to the spec under `## As-built (2026-07-02 survey)`.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/studio/bakeNW1012Stairway.luau roblox/tools/studio/buildIshidanStairs.luau docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
git commit -m "feat(roblox): bake NW1012 stairway centerline + pad frame from Studio survey"
```

---

### Task 5: Teardown to ServerStorage (Studio, reversible)

**Files:** none (place-only; MCP `execute_luau`, Edit)

**Interfaces:**
- Consumes: `Workspace.NW1012Path`, `Workspace.PathRailings.Rail_NW1012`, `Workspace.PathLanterns.Chochin_NW1012Path`. Leaves `Rail_NW1012_Tunnel` and `NW1211Path` untouched.
- Produces: `ServerStorage.NW1012Retired` folder holding the three models (NOT destroyed — restorable until the user signs off the finished stairway).

- [ ] **Step 1: Run the move** (only after Task 4's bake is committed):

```luau
local SS = game:GetService("ServerStorage")
local bin = SS:FindFirstChild("NW1012Retired") or Instance.new("Folder")
bin.Name = "NW1012Retired"
bin.Parent = SS
for _, spec in {
    { workspace, "NW1012Path" },
    { workspace.PathRailings, "Rail_NW1012" },
    { workspace.PathLanterns, "Chochin_NW1012Path" },
} do
    local inst = spec[1]:FindFirstChild(spec[2])
    if inst then inst.Parent = bin end
end
return "retired: " .. #bin:GetChildren()
```

- [ ] **Step 2: Verify in a separate call** — `workspace:FindFirstChild("NW1012Path") == nil`, `ServerStorage.NW1012Retired` has 3 children, and `workspace.PathRailings.Rail_NW1012_Tunnel` still exists.
- [ ] **Step 3: Tell the user to SAVE THE PLACE.**

---

### Task 6: Terrain carve (cut-only) + USER GATE (smooth)

**Files:** none (place-only)

**Interfaces:**
- Consumes: the baked `control` + `layout` math from `buildIshidanStairs.luau` CONFIG (run the mirrored `resample`/`layout` inline to get per-step floor targets).
- Produces: `ServerStorage.NW1012CarveBackup` (pre-carve `Terrain:CopyRegion` snapshot); a rough stepped bench along the centerline (floor target = tread − 1.4 so bed+slab bodies seat into ground) and a pad-area cut-down to 112.5 over the pad footprint + 2-stud margin.

- [ ] **Step 1: Snapshot** — `Terrain:CopyRegion` over the stairway bbox (min/max of control points ±8 studs, Y from 105 to 170), store as `ServerStorage.NW1012CarveBackup` (a `TerrainRegion`). Record the region corner in the spec As-built section (needed for `PasteRegion(region, corner, true)` restore).
- [ ] **Step 2: Carve** — walk the layout steps; per step, `Terrain:FillBlock` with `Enum.Material.Air` a box `(width + 3) × 6 × (pitch + 1)` centered at `{pos.X, tread - 1.4 + 3, pos.Z}` oriented by `dir` — i.e., clear everything above the floor target; NEVER fill solid. Pad area: Air box over `PAD.center` footprint `10 × 6 × 9` down to 112.5. (Boxes are ≥4 studs in every dim — voxel resolution rule.)
- [ ] **Step 3: Verify in a SEPARATE `execute_luau`** — occupancy columns: `Terrain:ReadVoxels` a thin column at every 4th step center; assert the first occupied voxel below `tread + 2` is at or below `tread - 1` (floor target reached). Report per-step pass/fail counts.
- [ ] **Step 4: USER GATE** — ask the user to smooth the rough bench (their standard pass) and SAVE THE PLACE. **STOP until they confirm.**

---

### Task 7: Landing pad build (Studio) — angled deck section

**Files:**
- Create: `roblox/tools/studio/buildStairLandingPad.luau`

**Interfaces:**
- Consumes: the printed `PAD` literal from Task 4 (baked into this script's CONFIG — no live marker reads).
- Produces: `Workspace.RoshamboStage.OverlookStairPad` model: rotated slab + seam infill planks + posts + girders + KŌRAN on open edges. Idempotent (destroy + rebuild). The stair's Task 8 foot lands on its stair-side edge.

**Build spec (all from recipe §2 / spec §4):**
- **Slab:** `WoodPlanks`, 0.6 thick, top at `PAD.topY` (113.3), color = surveyed `deckColor`. Size `7.5 (cross) × 0.6 × 5.5 (along heading)`, `CFrame.fromMatrix(center, cross, yAxis)` with heading from `PAD.heading`. The slab's deck-side edge stops **0.4 short** of the closest approach to `deckEdgeX`.
- **Seam infill planks:** planks parallel to the pad heading, `1.2` wide (cross), 0.6 thick, tops at 113.3; loop across the pad's cross extent; each plank's length runs from the slab's deck-side edge to the deck edge plane `X = deckEdgeX` (per-plank length = distance along heading to the plane at that cross offset, min 0.5); butt edges, no overlap with the deck (`X ≤ deckEdgeX` always, so tops never z-fight).
- **Posts:** `Wood`, **1.5 sq** (Overlook weight), at the two outer slab corners + mid-edge if the drop > 6; **outer faces flush with the slab edges** (standing rule); feet from a terrain raycast at each post XZ, extend 1 stud into ground.
- **Girders:** `Wood` 1.2 × 0.825 under the two long edges, flush, top at slab underside.
- **KŌRAN railing** on open edges only (the downhill/south cross edge + any west remainder not occupied by the stair): cap 0.3×0.6, mid-rail 0.2×0.3, balusters 0.34 to the cap, newels 0.62 sq × 3.7 at rail ends. The stair-side edge and the deck-side seam get NO railing. Where a rail line lands at `NewelUpperDeck4`, terminate against it — do not build a second newel there.

- [ ] **Step 1: Write the script** with the geometry above (CONFIG at top = the PAD literal + dims). Commit it.

```bash
git add roblox/tools/studio/buildStairLandingPad.luau
git commit -m "feat(roblox): OverlookStairPad builder (angled landing pad, baked frame)"
```

- [ ] **Step 2: Run in Studio (Edit), then verify in a separate call** — pad exists, slab top Y == 113.3, no part crosses `X > deckEdgeX`, post bottoms touch terrain (raycast from just below slab, expect hit within 12 studs).
- [ ] **Step 3:** part of the Task 8 gate (user reviews pad + first flight together). SAVE THE PLACE.

---

### Task 8: Attempt #1 — foot flight (~20 steps) + HARD USER GATE

**Files:**
- Modify: `roblox/tools/studio/buildIshidanStairs.luau` (set `buildRange`)

**Interfaces:**
- Consumes: everything above.
- Produces: `Workspace.NW1012Stairs` with steps `0..≈20` (foot → just past the first landing's start), landing excluded if it falls beyond the range.

- [ ] **Step 1:** Set `CONFIG.buildRange = { 0, 20 }`, run the builder via MCP `execute_luau` (Edit). Expected print: `NW1012Stairs: built 21/<total> steps`.
- [ ] **Step 2: Self-check in a separate call** — for steps 0..20: monotone tread Ys with uniform riser (read `Step_<i>` tops); first stone top ≈ 113.3 + riser; no stone floats > 1.5 above terrain without the pad/bench under it (terrain raycast is allowed); last-range step meets the smoothed bench.
- [ ] **Step 3: SAVE THE PLACE reminder, then STOP.** Describe in words what was built (step count, riser, pitch, where it starts/ends) and ask the user to walk it — pad, joint, first flight. **Do not proceed, iterate, or self-judge. Wait.**

---

### Task 9: Remaining flights + landings (post-approval)

**Files:**
- Modify: `roblox/tools/studio/buildIshidanStairs.luau` (apply any gate feedback, then `buildRange = nil`)

**Interfaces:**
- Consumes: user feedback from Task 8 (riser/pitch/color/jitter tweaks go into CONFIG and, if they change math, back into `IshidanStairs.luau` + its tests — mirror rule).
- Produces: the full `Workspace.NW1012Stairs` (all steps + 2 landing beds); landing cobbles.

- [ ] **Step 1:** Apply feedback, set `buildRange = nil`, re-run (idempotent rebuild). Verify head: top step tread == 162.6 ± 0.05 and XZ within 1 stud of the old Timber_23 spot (so `Rail_NW1012_Tunnel` still meets it); if not, adjust the last control point and re-run.
- [ ] **Step 2: Landing cobbles** — per spec §1: flat Voronoi cobbles on each landing bed, using the §1 recipe params (3–4 seeds/gap equivalent over the landing rect, min-sep 0.55, inset 0.08, 1-pass Chaikin, dome 0.42, FLAT-UP normals, mono 122/127/117 ±3, Material Rock, DoubleSided, CollisionFidelity Box, verts world-space→recentred, `CreateAssetAsync` publish). Adapt the cobble-section generator from `buildSteppedCobblePath.luau` (its per-gap Voronoi code) over the two landing rects into ONE EditableMesh, publish, insert as `NW1012Stairs.LandingCobbles`.
- [ ] **Step 3: USER GATE** — user walks the full flight. SAVE THE PLACE. STOP.

---

### Task 10: Ishigaki retaining walls (CONFIG run)

**Files:**
- Modify: `roblox/tools/studio/buildIshigakiWalls.luau` (CONFIG only, if its part-reading matches; a small reader shim if not)

**Interfaces:**
- Consumes: `Workspace.NW1012Stairs.Step_<i>` (the full-width bed Parts — same read pattern as timbers: `prefix .. "_" .. i`, RightVector cross, top = grade).
- Produces: per-span published wall meshes in `Workspace.RetainingWalls` under the stairway's floating downhill spans.

- [ ] **Step 1:** Read `buildIshigakiWalls.luau`'s CONFIG/reader. If it takes `{ path, prefix (or timberPrefix), i0, i1, HW }`-style entries, add `{ path = "NW1012Stairs", prefix = "Step", i0 = 0, i1 = <top index>, HW = 3.2 }` with `THRESH = 2.5`, `PAD = 1`. If it hardcodes `Timber`, generalize the name pattern to a config field first (mechanical edit, commit separately).
- [ ] **Step 2:** Run; verify in a separate call (spans exist only where step float > 2.5; wall tops ≈ bed undersides). USER GATE + SAVE.

```bash
git add roblox/tools/studio/buildIshigakiWalls.luau && git commit -m "feat(roblox): ishigaki walls under NW1012Stairs floating spans"
```

---

### Task 11: Bamboo railing + tunnel connector (CONFIG run)

**Files:**
- Modify: `roblox/tools/studio/buildBambooRailing.luau` (CONFIG only)

**Interfaces:**
- Consumes: `Workspace.NW1012Stairs.Step_<i>`; the existing `Rail_NW1012_Tunnel` connector endpoints at the head.
- Produces: `Workspace.PathRailings.Rail_NW1012Stairs` (downhill edge, smooth raked top rail + jittered lower rail + posts every ~4 steps + 15-stud raked invisible barriers), plus a CONNECTORS entry bridging the head to `Rail_NW1012_Tunnel` and a foot termination at the pad's KŌRAN newel.

- [ ] **Step 1:** Add the RUNS entry `{ name = "NW1012Stairs", path = "NW1012Stairs", prefix = "Step", i0 = 0, i1 = <top index>, edgeSign = <downhill sign> }`. Determine `edgeSign` by reading one `Step` part's RightVector vs the downhill side — **ask the user which side is open-air if ambiguous** (recipe §4 rule). Post spacing: every 2 contract parts = every 2 steps is too dense — set the builder's post interval to 4 for this run (add a per-run `postEvery` field defaulting to 2 if absent; mechanical, commit separately).
- [ ] **Step 2:** Add a CONNECTORS entry head↔`Rail_NW1012_Tunnel` (same pattern as the existing PathSteps↔PathExtension one). Run, verify barriers exist per gap and are 15 tall / cos(rake). USER GATE + SAVE.

```bash
git add roblox/tools/studio/buildBambooRailing.luau && git commit -m "feat(roblox): bamboo railing on NW1012Stairs + tunnel connector"
```

---

### Task 12: Chōchin (CONFIG run)

**Files:**
- Modify: `roblox/tools/studio/buildChochinPole.luau` (CONFIG only)

**Interfaces:**
- Consumes: `Workspace.NW1012Stairs.Step_<i>`.
- Produces: `Workspace.PathLanterns.Chochin_NW1012Stairs` — every ~12 steps uphill edge (staggered, seeded), plus one at each landing (downhill allowed there per spec).

- [ ] **Step 1:** Add CONFIG: `path = "NW1012Stairs"`, `timberPrefix = "Step"`, `interval = 12`, `uphillSign = <opposite of Task 11's edgeSign>`, `downhillFrac = 0.3`, `seed = 20260702`. Run.
- [ ] **Step 2:** Manually add/verify one chōchin at each landing (`interval` may skip them; if so, place two extra via the same script scoped to the landing indices). Verify `LanternController`/`ChochinSway` pick them up (tags present). USER GATE + SAVE.

```bash
git add roblox/tools/studio/buildChochinPole.luau && git commit -m "feat(roblox): chochin on NW1012Stairs"
```

---

### Task 13: As-built record + memory + close-out

**Files:**
- Modify: `docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md` (final As-built: step count, riser/pitch per flight, landing indices, pad dims, wall spans, asset IDs for landing cobbles)
- Modify: `docs/superpowers/references/zendojo-canyon-build-recipes.md` (new §: "Ishidan stairway" — when grade > ~40%, use IshidanStairs instead of §1 spacing; the Step_<i> contract; pointer to this spec)

**Interfaces:** none — documentation.

- [ ] **Step 1:** Write both docs; final SAVE THE PLACE + remind the user the retired models in `ServerStorage.NW1012Retired` can be deleted once they're happy (their call, not ours).
- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md docs/superpowers/references/zendojo-canyon-build-recipes.md
git commit -m "docs(zendojo): NW1012 ishidan stairway as-built + recipe section"
```

---

## Self-Review Notes

- Spec coverage: route/geometry → Tasks 1, 4; steps → Tasks 2, 3, 8, 9; terrain/underpinning → Tasks 6, 10; railing/chōchin/foot → Tasks 7, 11, 12; teardown/tooling/persistence → Tasks 3, 5, 13; first-attempt gate → Task 8. Landing cobbles (spec §1 "cobble+gravel vocabulary") → Task 9 Step 2.
- The `slabs` no-slice rule (Task 3) exists because `buildRange` staging must not reshuffle the shared rng stream between attempts.
- Type consistency: `Step`/`Layout`/`StepBuild` names match across Tasks 1–3; the part contract `Step_<i>`/`Stone_<i>a|b` matches Tasks 3, 10, 11, 12.
