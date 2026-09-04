# Client Load Reduction (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the Roblox client spending frames on ambient work the player cannot see, so an iPhone 15 runs cooler and a Samsung A13 gains headroom — with no visual difference on any device.

**Architecture:** One new pure module, `AmbientBudget`, owns the "is this worth animating" policy and a fixed-interval accumulator; the `.client.luau` controllers keep the Roblox vector math and call into it. This mirrors `ImpostorFade` / `FoliageImpostorController`, which is the existing house pattern for exactly this split and the only way the rule gets test coverage (no harness in this repo can load a `.client.luau`). Three structural fixes ride along: streaming radii (never set), teahouse `Persistent` (never justified), and stats-room `MaxDistance` (never set).

**Tech Stack:** Luau (Roblox + Lune), the repo's bespoke test harness at `roblox/tests/harness.luau`, Rojo, StyLua, Selene.

**Spec:** `docs/superpowers/specs/2026-09-03-client-load-reduction-design.md`

## Global Constraints

- **No visual change on any device.** Anything a player could see the difference in belongs to phase 2. This is the owner's scope ruling and it governs every task; a change that trades looks for frames must be rejected even when it saves more.
- **Run the house gates before every commit**, from `roblox/`: `stylua src tests tools && selene src tools && lune run tests/run`. Selene fails on warnings. `rojo build -o /tmp/build.rbxl` must also succeed for any task touching `src/`.
- **All 129 existing spec files must stay green.** `tests/Compiles.spec.luau` picks up edited client files automatically.
- **Never hand-edit `roblox/assets/*.model.json`** — it is generator output (`lune run tools/genmodels`). No task here should touch it; if one seems to need to, stop and re-read the spec.
- **A push is not done until its CI run is seen green** (`docs/wiki/systems/rojo-and-place.md`).
- **Pure shared modules take scalars, not `Vector3`.** Lune cannot construct Roblox datatypes in this harness; `ImpostorFade.planeNormal` returning a plain `{x, z}` is the precedent.
- **No performance harness may be left enabled.** Per `docs/wiki/practice/perf-harness-contamination.md`, any measurement script is parked in the same session it reports, and nothing profiling-related goes into `StarterPlayerScripts`.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `roblox/src/shared/AmbientBudget.luau` | **New.** The cull policy and the accumulator. Pure. | 1 |
| `roblox/tests/AmbientBudget.spec.luau` | **New.** Lune coverage for the above. | 1 |
| `roblox/src/client/ChochinSway.client.luau` | Pole lanterns stop swaying; the rest get culled. | 2 |
| `roblox/src/client/NorenSway.client.luau` | Panels get culled. | 3 |
| `roblox/src/client/WheelController.client.luau` | Integration preserved; writes culled. | 4 |
| `roblox/src/client/HammerController.client.luau` | Timing split from rendering; rendering culled. | 5 |
| `roblox/src/client/ShopController.client.luau` | Proximity test polls at 4 Hz. | 6 |
| `roblox/src/client/AccessGateController.client.luau` | Distance test polls; fade stays per-frame. | 6 |
| `roblox/src/server/main.server.luau` | Streaming radii set at boot. | 7 |
| `roblox/src/client/FlapBoard.luau` | Wall-board `SurfaceGui`s get a `MaxDistance`. | 8 |
| `roblox/src/server/TreatmentApplier.luau` | Teahouse `Persistent` — investigation, may end in no change. | 9 |

---

### Task 1: `AmbientBudget` — the policy module

**Files:**
- Create: `roblox/src/shared/AmbientBudget.luau`
- Test: `roblox/tests/AmbientBudget.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, and every later task depends on these exact names:
  - `AmbientBudget.Config` = `{ radius: number, behindDot: number, interval: number }`
  - `AmbientBudget.DEFAULT: Config`
  - `AmbientBudget.inRange(distSq: number, cfg: Config?): boolean`
  - `AmbientBudget.inView(forwardDot: number, cfg: Config?): boolean`
  - `AmbientBudget.step(acc: number, dt: number, interval: number): (boolean, number)`

Note the argument order and the optional trailing `cfg`, which matches `ImpostorFade`. `step` returns **two** values, `(fire, nextAcc)`, in that order.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/AmbientBudget.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local AmbientBudget = require("../src/shared/AmbientBudget")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("AmbientBudget.inRange", function()
    test("at the camera is in range", function()
        expect(AmbientBudget.inRange(0)).toBe(true)
    end)

    test("exactly at the radius is still in range", function()
        local r = AmbientBudget.DEFAULT.radius
        expect(AmbientBudget.inRange(r * r)).toBe(true)
    end)

    test("just beyond the radius is out", function()
        local r = AmbientBudget.DEFAULT.radius
        expect(AmbientBudget.inRange(r * r + 1)).toBe(false)
    end)

    test("a custom radius is respected", function()
        local cfg = { radius = 10, behindDot = -0.15, interval = 1 / 30 }
        expect(AmbientBudget.inRange(100, cfg)).toBe(true)
        expect(AmbientBudget.inRange(101, cfg)).toBe(false)
    end)
end)

describe("AmbientBudget.inView", function()
    test("dead ahead is in view", function()
        expect(AmbientBudget.inView(1)).toBe(true)
    end)

    test("directly behind is not", function()
        expect(AmbientBudget.inView(-1)).toBe(false)
    end)

    test("exactly at the margin is still in view", function()
        expect(AmbientBudget.inView(AmbientBudget.DEFAULT.behindDot)).toBe(true)
    end)

    test("the margin keeps a little slack behind square", function()
        -- a prop level with the camera plane must survive a fast turn
        expect(AmbientBudget.inView(0)).toBe(true)
        expect(AmbientBudget.DEFAULT.behindDot < 0).toBe(true)
    end)
end)

describe("AmbientBudget.step", function()
    test("does not fire before the interval elapses", function()
        local fire, acc = AmbientBudget.step(0, 0.01, 1 / 30)
        expect(fire).toBe(false)
        expect(math.abs(acc - 0.01) < 1e-9).toBe(true)
    end)

    test("fires once the interval is reached", function()
        local fire = AmbientBudget.step(0.02, 0.02, 1 / 30)
        expect(fire).toBe(true)
    end)

    test("carries the remainder rather than zeroing", function()
        -- 0.05s against a 0.03s interval leaves 0.02s owed to the next tick;
        -- zeroing here is what silently drags a nominal 30Hz down to the frame rate
        local _, acc = AmbientBudget.step(0, 0.05, 0.03)
        expect(math.abs(acc - 0.02) < 1e-9).toBe(true)
    end)

    test("a long stall does not bank unbounded catch-up", function()
        local fire, acc = AmbientBudget.step(0, 5, 1 / 30)
        expect(fire).toBe(true)
        expect(acc < 1 / 30).toBe(true)
    end)

    test("a zero interval fires every call without dividing by zero", function()
        local fire, acc = AmbientBudget.step(0, 0.001, 0)
        expect(fire).toBe(true)
        expect(acc).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
cd roblox && lune run tests/run
```

Expected: failure resolving `../src/shared/AmbientBudget` — the module does not exist yet.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/AmbientBudget.luau`:

```lua
--!strict
-- The "do not animate what the player cannot see" policy, in ONE place. Pure: no Roblox globals and
-- no instances, so Lune tests it -- unlike the .client.luau files that call it, which no harness in
-- this repo can load at all (see NorenSway.client.luau's header).
--
-- The controllers keep the vector math and the CollectionService bookkeeping; this module owns the
-- thresholds and the decision. That split is the only reason the rule is testable, and it mirrors
-- ImpostorFade's relationship to FoliageImpostorController.
local AmbientBudget = {}

export type Config = {
    radius: number, -- studs; beyond this an ambient prop is not animated
    behindDot: number, -- normalized forward dot below which the prop is behind the camera
    interval: number, -- seconds between updates while the prop IS being animated
}

AmbientBudget.DEFAULT = {
    radius = 180,
    behindDot = -0.15,
    interval = 1 / 30,
} :: Config

-- ⚠ TAKES DISTANCE SQUARED, deliberately. The caller has the squared distance for free and the
-- square root is the expensive half; for a canyon of lanterns most candidates fail THIS test, so it
-- has to be the one that can run first and short-circuit before anything calls math.sqrt.
function AmbientBudget.inRange(distSq: number, cfg: Config?): boolean
    local c = cfg or AmbientBudget.DEFAULT
    return distSq <= c.radius * c.radius
end

-- `forwardDot` is dot(normalize(prop - camera), cameraLook): 1 dead ahead, -1 directly behind.
--
-- NOT A FRUSTUM TEST, and not trying to be. `behindDot` is a MARGIN: it culls only what is clearly
-- behind the player, leaving slack for a wide FOV and for a fast turn -- because the cost of being
-- wrong is a prop the player watches start moving as it swings into view.
function AmbientBudget.inView(forwardDot: number, cfg: Config?): boolean
    local c = cfg or AmbientBudget.DEFAULT
    return forwardDot >= c.behindDot
end

-- Fixed-interval accumulator. Returns whether this frame should do the work, and the accumulator to
-- carry into the next one. Pure rather than stateful so the throttle itself is testable.
--
-- ⚠ CARRIES THE REMAINDER instead of zeroing. Zeroing discards up to a frame of time on every tick,
-- which quietly drags a nominal 30Hz down toward whatever the frame rate happens to be. The modulo
-- also bounds catch-up after a stall: one update is owed, not fifty.
function AmbientBudget.step(acc: number, dt: number, interval: number): (boolean, number)
    local elapsed = acc + dt
    if elapsed < interval then
        return false, elapsed
    end
    if interval <= 0 then
        return true, 0
    end
    return true, elapsed % interval
end

return AmbientBudget
```

- [ ] **Step 4: Run the test and watch it pass**

```bash
cd roblox && lune run tests/run
```

Expected: PASS, with the pre-existing suites still green.

- [ ] **Step 5: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run
git add roblox/src/shared/AmbientBudget.luau roblox/tests/AmbientBudget.spec.luau
git commit -m "feat(client): AmbientBudget -- the policy for not animating what nobody can see"
```

---

### Task 2: `ChochinSway` — path poles stop swaying, the rest get culled

**Files:**
- Modify: `roblox/src/client/ChochinSway.client.luau` (the whole file; it is 89 lines)

**Interfaces:**
- Consumes: `AmbientBudget.inRange`, `AmbientBudget.inView`, `AmbientBudget.step`, `AmbientBudget.DEFAULT` from Task 1.
- Produces: nothing other tasks consume. Tasks 3–5 copy this file's `cfg()` / camera-math shape, so get it right here.

**Context an implementer needs.** Three builders stamp the `ChochinSwing` tag: `tools/studio/buildChochinPole.luau` (the path poles, which hang their lantern from a `CrossArm` sibling), `buildTeahouseChochin.luau` and `buildHanabiyaChochin.luau` (which hang differently and have no arm). The owner's ruling is that **pole-hung lanterns do not sway at all** — measured, the effect is about an inch and a half of travel on a two-foot lantern over a seven-second cycle. The other two populations keep it. `hangPointFor` already distinguishes them, so it becomes the predicate; its hang-point derivation existed solely to make pole sway pivot correctly and dies with the population it served.

**Do not un-tag anything in the builders.** Those are Studio stamping tools; changing them would not touch lanterns already in the saved place. The split belongs in this file, where it is one predicate.

- [ ] **Step 1: Replace `hangPointFor` with the predicate**

Delete the whole `hangPointFor` function (lines 16–39, comment block included) and put this in its place:

```lua
-- ⚠ POLE-HUNG CHŌCHIN DO NOT SWAY (owner ruling, 2026-09-03). Measured, the effect was ~1.5 inches
-- of travel on a two-foot lantern over a seven-second cycle: legible at arm's length, under a pixel
-- past thirty feet, and a path is exactly where the player is moving. The path population is also
-- the large one (PathLanterns is 2,599 descendants). The teahouse and hanabiya chōchin -- seen from
-- a standstill on an engawa or in a doorway -- keep theirs.
--
-- A `CrossArm` sibling IS the discriminator: buildChochinPole stamps one, the teahouse and hanabiya
-- builders do not.
--
-- HISTORY, so nobody re-derives the bug if sway ever comes back to the poles: this used to derive
-- the hang point from the cross-arm rather than trust the stored WorldPivot, because the pivot is
-- place data and the geometry is builder data. When the poles were shortened, every already-stamped
-- lantern kept the taller pole's pivot and swung about a point 3.4 studs up in the air. That
-- derivation is gone with the sway it served; it is in git if it is ever needed again.
local function isPoleHung(m: Model): boolean
    local parent = m.Parent
    if parent == nil then
        return false
    end
    local arm = parent:FindFirstChild("CrossArm")
    return if arm then arm:IsA("BasePart") else false
end
```

- [ ] **Step 2: Skip pole lanterns at registration**

In `add`, replace the `local derived = hangPointFor(m) ... m.WorldPivot = derived` block (and its two-line comment about `WorldPivot` not moving geometry) with an early return, so the body becomes:

```lua
local function add(m: Instance)
    if not m:IsA("Model") then
        return
    end
    if isPoleHung(m) then
        return -- path poles never sway; see isPoleHung
    end
    for _, e in entries do
        if e.model == m then
            return
        end
    end
    local base = m:GetPivot()
    local p = base.Position
    local jitter = (math.floor(p.X) % 7) / 7 -- 0..1 per-site variation
    entries[#entries + 1] = {
        model = m,
        base = base,
        phase = (p.X * 0.13 + p.Z * 0.17) % (2 * math.pi), -- positional desync
        amp = AMP * (0.8 + 0.4 * jitter),
        speed = SPEED * (0.85 + 0.3 * jitter),
    }
end
```

The `isPoleHung` check goes **before** the duplicate scan so a pole lantern never enters `entries` by any path.

- [ ] **Step 3: Add the require and the live-tune config**

At the top, beside the existing service locals, add:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))
```

⚠ Require through `ReplicatedStorage.RoshamboShared`, never a relative path — a client file that used a relative require here has broken before (`16331e6`).

Then, above the `Heartbeat` connection:

```lua
-- Live-tunable from Workspace attributes during a walk, defaults from the module -- the same
-- convention FoliageImpostorController uses for ImpostorCapFadeLo and its neighbours.
local function num(attr: string, default: number): number
    local v = workspace:GetAttribute(attr)
    return if typeof(v) == "number" then v else default
end

local function cfg(): AmbientBudget.Config
    local d = AmbientBudget.DEFAULT
    return {
        radius = num("AmbientRadius", d.radius),
        behindDot = num("AmbientBehindDot", d.behindDot),
        interval = if num("AmbientHz", 0) > 0 then 1 / num("AmbientHz", 0) else d.interval,
    }
end
```

- [ ] **Step 4: Replace the loop with the culled version**

Replace the `RunService.Heartbeat:Connect(...)` block at the end of the file with:

```lua
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    if not fire then
        return
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return
    end
    local camCF = cam.CFrame
    local camPos, look = camCF.Position, camCF.LookVector
    local t = os.clock()
    for _, e in entries do
        local d = e.base.Position - camPos
        local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
        if not AmbientBudget.inRange(distSq, c) then
            continue
        end
        -- sqrt only for what survived the range test; see AmbientBudget.inRange
        local dist = math.sqrt(distSq)
        local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
        if not AmbientBudget.inView(fdot, c) then
            continue
        end
        local a = e.amp * math.sin(t * e.speed + e.phase)
        local b = e.amp * 0.45 * math.sin(t * e.speed * 0.7 + e.phase * 1.3) -- subtle cross-axis drift
        e.model:PivotTo(e.base * CFrame.Angles(a, 0, b))
    end
end)
```

⚠ **Culling is free here and it is worth knowing why:** the pose is a pure function of `os.clock()`, not integrated state, so a lantern that comes back into view resumes at exactly the phase it would have had. Nothing to reset, no drift, no re-entry pop. Tasks 4 and 5 do **not** have this property and must not copy the pattern blindly.

- [ ] **Step 5: Update the file header**

The header still describes sway on "the hanging path chōchin". Rewrite the first paragraph to say the file animates the teahouse and hanabiya chōchin, that path poles are excluded by owner ruling, and that the swinging body carries the RoundLantern glyph (that clause is still true and still matters).

- [ ] **Step 6: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/ChochinSway.client.luau
git commit -m "perf(client): path chochin stop swaying; the rest animate only in view"
```

---

### Task 3: `NorenSway` — cull by panel

**Files:**
- Modify: `roblox/src/client/NorenSway.client.luau:81-96`

**Interfaces:**
- Consumes: `AmbientBudget` as in Task 2, including the identical `num`/`cfg` helpers.
- Produces: nothing.

Each panel already caches `panel.hinge` (a `Vector3`), so the cull anchor is in hand with no instance read. The pose is a pure function of `os.clock()`, so culling is free for the same reason it is in Task 2.

- [ ] **Step 1: Add the require and config**

Add the same `ReplicatedStorage` require and the same `num` / `cfg` helpers as Task 2, Step 3 (copy them verbatim — two small local functions in two files is cheaper than a shared client module neither can test).

- [ ] **Step 2: Replace the loop**

```lua
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    if not fire then
        return
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return
    end
    local camCF = cam.CFrame
    local camPos, look = camCF.Position, camCF.LookVector
    local t = os.clock()
    for _, panel in panels do
        local d = panel.hinge - camPos
        local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
        if not AmbientBudget.inRange(distSq, c) then
            continue
        end
        local dist = math.sqrt(distSq)
        local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
        if not AmbientBudget.inView(fdot, c) then
            continue
        end
        -- Walk the chain from the rail: each segment hangs off the bottom of the one above, so
        -- the panel stays joined no matter how far any single joint bends.
        local pos = panel.hinge
        for i, s in panel.segs do
            local ax = s.rest * (1 + SWAY * math.sin(t * SPEED + panel.phase + i * LAG))
            local az = s.rest * CROSS * math.sin(t * SPEED * 0.7 + panel.phase * 1.3 + i * LAG)
            local dir = CFrame.Angles(ax, 0, az)
            local drop = dir:VectorToWorldSpace(Vector3.new(0, -s.h, 0))
            s.part.CFrame = CFrame.new(pos + drop * 0.5) * dir
            pos += drop
        end
    end
end)
```

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/NorenSway.client.luau
git commit -m "perf(client): noren stir only for panels the camera can see"
```

---

### Task 4: `WheelController` — keep the integration, cull the writes

**Files:**
- Modify: `roblox/src/client/WheelController.client.luau:142-176`

**Interfaces:**
- Consumes: `AmbientBudget` as in Task 2.
- Produces: nothing.

⚠ **This file is not `ChochinSway`.** `angle` is **integrated** (`angle += dt * driveOmega * wheelDir`), so freezing it while the player looks away brings the wheel back at the wrong phase. Two rules follow, and both matter:

1. `angle` advances **every frame**, culled or not. It is one multiply-add.
2. The paddle-strike boundary block runs **every frame** too, and `lastStrike[side]` is **always** updated. Only the `b:Emit(3)` call is gated. Letting `k` advance without updating `lastStrike` would fire a splash on re-entry for a strike nobody saw.

- [ ] **Step 1: Add the require and config**

Same `ReplicatedStorage` require and the same `num` / `cfg` helpers as Task 2, Step 3.

- [ ] **Step 2: Replace the loop**

```lua
local angle = 0
local FALLBACK_OMEGA = 0.5 -- rad/s until HammerController publishes the real shaft rate (signed for WHEEL_DIR below)
local WHEEL_DIR = -1 -- maps the published shaft ω onto the wheel's local axle (live-tunable "WheelDir")
local lastStrike: { number } = { math.huge, math.huge } -- per-side paddle-boundary counters
local acc = 0

-- Range/view for the wheel itself, anchored on the first spin group's hub.
local function drawable(c: AmbientBudget.Config): boolean
    if #spins == 0 then
        return false
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return false
    end
    local camCF = cam.CFrame
    local d = spins[1].hub.Position - camCF.Position
    local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
    if not AmbientBudget.inRange(distSq, c) then
        return false
    end
    local dist = math.sqrt(distSq)
    local look = camCF.LookVector
    local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
    return AmbientBudget.inView(fdot, c)
end

RunService.Heartbeat:Connect(function(dt)
    -- The wheel IS the driver gear's shaft, so it turns at the EXACT angular velocity the
    -- bell-engine drive publishes ("DriveOmega", rad/s about Z) — matched rate + direction,
    -- not a free constant that out-runs the gears. WHEEL_DIR corrects the wheel's local axle
    -- orientation; flip it (or "DriverDir") live to fix the spin direction.
    local driveOmega = (stage:GetAttribute("DriveOmega") :: number) or FALLBACK_OMEGA
    local wheelDir = (stage:GetAttribute("WheelDir") :: number) or WHEEL_DIR
    -- ⚠ INTEGRATED, so it advances EVERY frame whether or not the wheel is drawn. Freezing it while
    -- the player looks away would bring the wheel back at a stale phase.
    angle += dt * driveOmega * wheelDir

    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    local visible = drawable(c)
    if fire and visible then
        for _, s in spins do
            local spun = s.hub * CFrame.Angles(angle, 0, 0)
            s.part.CFrame = spun
            for i, p in s.paddles do
                p.CFrame = spun * s.offsets[i]
            end
        end
    end
    -- splash when a paddle strikes the waterline: one boundary per 2π/paddleCount of
    -- rotation; the two sides (enter/exit) are offset half a bay so they alternate.
    --
    -- ⚠ RUNS EVERY FRAME AND ALWAYS UPDATES lastStrike, even when culled. Only the Emit is gated:
    -- skipping the bookkeeping would bank a boundary and splash on re-entry for a strike the player
    -- never saw.
    if paddleCount > 0 then
        local spacing = 2 * math.pi / paddleCount
        for side, b in bursts do
            local k = math.floor((angle + (side - 1) * spacing / 2) / spacing)
            if k ~= lastStrike[side] then
                if lastStrike[side] ~= math.huge and visible then
                    b:Emit(3)
                end
                lastStrike[side] = k
            end
        end
    end
end)
```

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/WheelController.client.luau
git commit -m "perf(client): waterwheel keeps turning, only draws when it is on screen"
```

---

### Task 5: `HammerController` — split timing from rendering

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau:355-377`, `:398-452`, `:457`

**Interfaces:**
- Consumes: `AmbientBudget` as in Task 2.
- Produces: continues to write the `DriveOmega` attribute on `RoshamboStage`, which Task 4's `WheelController` reads every frame. That write must not become conditional.

⚠ **The middle loop (`:398`) is load-bearing. It must keep running every frame.** It is not decorative:

- it detects the bell strike via `metronome:strikesBetween(lastMetroNow, nowSt)`, using `lastMetroNow` as the previous sample — throttle it and the bonshō is late, cull it and the bell goes silent;
- it publishes `DriveOmega`, which `WheelController` reads as its rate;
- it carries the self-healing backstop for a dropped `RoundUpdate` broadcast (the machine must never stop);
- it retries `captureSpinners()` until parts replicate.

So this is a **split**, not a gate. The timing half is a metronome read, a comparison and an attribute write — a handful of scalar operations, and it stays unconditional. The three spinner write loops are the expensive half and get the cull.

`arm` (`rig:WaitForChild("ShuMoku") :: BasePart`, declared at `:46`) is the shared cull anchor for all three loops — it is the machine's own moving part and is in scope at every site.

- [ ] **Step 1: Add the require, config and shared anchor**

Add the same `ReplicatedStorage` require and `num` / `cfg` helpers as Task 2, Step 3, plus:

```lua
-- All three loops below animate one machine, so they share one cull anchor: the shu-moku itself.
local function machineDrawable(c: AmbientBudget.Config): boolean
    local cam = workspace.CurrentCamera
    if cam == nil then
        return false
    end
    local camCF = cam.CFrame
    local d = arm.Position - camCF.Position
    local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
    if not AmbientBudget.inRange(distSq, c) then
        return false
    end
    local dist = math.sqrt(distSq)
    local look = camCF.LookVector
    local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
    return AmbientBudget.inView(fdot, c)
end
```

- [ ] **Step 2: Gate the draw loop (`:355`)**

Declare `local drawAcc = 0` immediately above the connection, change the callback signature to `function(dt: number)`, and make the gate the **first** thing in the body — before the `DrawHold` attribute read, so a culled machine does no work at all:

```lua
local drawAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(drawAcc, dt, c.interval)
    drawAcc = nextAcc
    if not (fire and machineDrawable(c)) then
        return
    end
    -- DRAW HOLD (tuning): while the "DrawHold" attribute is set, pin the log at FULL draw
    -- (p=1, the top of its travel) and ignore the strike — so we can park the dowel at its
    -- pullback-top position and aim the cam's high point at it.
    local hold = stage:GetAttribute("DrawHold")
    if striking and not hold then
        return
    end
    -- ... the rest of the existing body is unchanged ...
end)
```

The draw pose is derived from `r.drawP`, a pure function of the metronome's schedule, so it resumes at the correct position on re-entry with nothing to reset.

⚠ Note that this loop is safe to gate **only** because it does nothing but pose `arm`. It reads `striking`, it never writes it — the loop in Step 3 owns that flag. Confirm that is still true before gating; if this loop has gained a write to shared state, it needs the same split treatment as Step 3 instead.

- [ ] **Step 3: Split the cam/driver/jack loop (`:398`)**

⚠ **`DriveOmega` is currently written on the LAST line of this loop, after the three write loops. It must move above the gate.** If it stays below, the waterwheel falls back to `FALLBACK_OMEGA` every time the player looks away and the two machines silently desynchronise. `driverDir` is read once and used by both halves, so it is hoisted with it.

Replace the entire connection with this. Everything above the gate is the existing code in its existing order, with the `driverDir` read and the `DriveOmega` write lifted to the end of that half:

```lua
local spinAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
    if #camSpinners == 0 then
        captureSpinners() -- parts hadn't replicated at init; keep trying until they do
    end
    local nowSt = workspace:GetServerTimeNow()
    local r = metronome:read(nowSt)
    if r == nil then
        return
    end
    if lastMetroNow and not striking and metronome:strikesBetween(lastMetroNow, nowSt) > 0 then
        strike(r.prevStrikeAt)
    end
    lastMetroNow = nowSt
    -- Self-timed backstop: RoundUpdate("OPEN") normally clears `striking`, but a
    -- dropped broadcast must not freeze the machine (spec: it never stops). Clear once
    -- the next round's ramp is underway — drawP has wrapped low — never mid-REVEAL
    -- (releasing early would slam the log back to near-full draw before the wrap).
    if striking and anchorAt and nowSt - anchorAt > 2 and r.drawP < 0.5 then
        striking = false
    end
    -- Turn WITH the metronome's own camAngle (0 at each strike), offset by the
    -- geometric anchor pinned at the last release.
    local camNet
    if anchorNet then
        camNet = anchorNet + CAM_DIR * r.camAngle
    else
        camNet = CAM_DIR * r.camAngle
    end
    local driverDir = (stage:GetAttribute("DriverDir") :: number) or DRIVER_DIR
    -- Published for WheelController, which LOCKS the wheel to this shaft (matched rate + direction).
    stage:SetAttribute("DriveOmega", driverDir * CAM_DIR * r.omega * REDUCTION) -- rad/s about Z

    -- ⚠ EVERYTHING ABOVE THIS LINE RUNS EVERY FRAME AND MUST KEEP DOING SO. Strike detection reads
    -- lastMetroNow as its previous sample, so throttling it makes the bonshō late and culling it
    -- silences the bell; the backstop above keeps the machine from freezing on a dropped broadcast;
    -- and WheelController reads DriveOmega as its rate every frame. Only the CFrame writes below are
    -- worth culling, and they are also the only expensive part of this loop.
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(spinAcc, dt, c.interval)
    spinAcc = nextAcc
    if not (fire and machineDrawable(c)) then
        return
    end
    local rot = CFrame.Angles(camNet, 0, 0)
    for _, s in camSpinners do
        s.part.CFrame = s.pivotCF * rot * s.pivotCF:Inverse() * s.restCF
    end
    -- Driver gear + main shaft are CO-AXIAL with the waterwheel (one N-S shaft), so they
    -- turn at the cam rate × REDUCTION.
    local drot = CFrame.Angles(0, 0, driverDir * camNet * REDUCTION)
    for _, s in driverSpinners do
        s.part.CFrame = s.pivotCF * drot * s.pivotCF:Inverse() * s.restCF
    end
    -- Jack shaft: 1:1 off the main shaft through the corner bevel, spun about world Y.
    local jackDir = (stage:GetAttribute("JackDir") :: number) or JACK_DIR
    local jrot = CFrame.Angles(0, jackDir * driverDir * camNet * REDUCTION * LANTERN_RATIO, 0)
    for _, s in jackSpinners do
        s.part.CFrame = s.pivotCF * jrot * s.pivotCF:Inverse() * s.restCF
    end
end)
```

Diff this against the original before committing: the only intended changes are the added `dt` parameter, the hoisted `driverDir` and `DriveOmega`, and the inserted gate. If anything else moved, the timing half has been disturbed.

- [ ] **Step 4: Gate the suspension loop (`:457`)**

`RunService.Heartbeat:Connect(updateSuspension)` becomes:

```lua
local suspAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(suspAcc, dt, c.interval)
    suspAcc = nextAcc
    -- updateSuspension recomputes chains and dowels from the log's LIVE CFrame every time, so it
    -- self-corrects on its first frame back and needs no reset after a cull.
    if fire and machineDrawable(c) then
        updateSuspension()
    end
end)
```

- [ ] **Step 5: Verify the bell still rings when you look away**

This one cannot be caught by the test suite. In Studio, Play, walk the avatar behind the drum so the machine is out of view, and confirm from the console/audio that the bonshō still strikes on schedule and that `RoshamboStage`'s `DriveOmega` attribute keeps changing in the Explorer. If either stops, the split is wrong — the timing half has been caught by the gate.

- [ ] **Step 6: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/HammerController.client.luau
git commit -m "perf(client): bell engine splits timing from rendering; only the CFrames are culled"
```

---

### Task 6: The two proximity loops

**Files:**
- Modify: `roblox/src/client/ShopController.client.luau:433-458`
- Modify: `roblox/src/client/AccessGateController.client.luau:92-124`

**Interfaces:**
- Consumes: `AmbientBudget.step` from Task 1. Neither file needs `inRange`/`inView` — these are player-position tests, not camera-visibility ones.
- Produces: nothing.

Two small same-shape edits, batched. Both currently run a proximity test at full frame rate for a trigger a walking player takes a quarter-second to cross. **They do not get the same treatment**, and the difference is the point of this task.

- [ ] **Step 1: `ShopController` — convert wholesale**

Its loop is a pure inside/outside test with a state change; nothing interpolates. Add the `ReplicatedStorage` require for `AmbientBudget`, then wrap the existing body:

```lua
local inside = false
local acc = 0
local POLL = 0.25 -- matches TourBeamController; a threshold a walking player crosses in ~0.25s
RunService.Heartbeat:Connect(function(dt: number)
    local fire, nextAcc = AmbientBudget.step(acc, dt, POLL)
    acc = nextAcc
    if not fire then
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local now = false
    if root then
        local p = root.Position
        local pos = { x = p.X, y = p.Y, z = p.Z }
        for _, entry in boxes do
            if ShopThreshold.isInside(pos, entry.box) then
                now = true
                break
            end
        end
    end
    if now ~= inside then
        inside = now
        if now then
            dismissed = false -- a fresh visit always opens
            paint()
        end
        setOpen(now)
    elseif inside and not dismissed and not gui.Enabled then
        setOpen(true)
    end
end)
```

- [ ] **Step 2: `AccessGateController` — split, do not convert**

⚠ **This loop must not be polled wholesale.** Its fade is frame-rate coupled — `pad.alpha += (target - pad.alpha) * math.clamp(dt * FADE_RATE, 0, 1)` — so a 4 Hz body turns a smooth reveal into four visible steps a second. That is a visual regression, which this plan's Global Constraints forbid. Throttle only the distance test; cache its answer on the pad; keep the fade on the real frame `dt`.

Add `near` to the pad entry built around `:79` (initialise it `false`, beside the existing `collidable = false`), and note that the `Pad` type declaration near the top of the file needs the same field. Then:

```lua
local acc = 0
local POLL = 0.25 -- the reveal radii are ~90 studs; a walking player cannot cross one in a tick
RunService.Heartbeat:Connect(function(dt: number)
    if #pads == 0 then
        return
    end
    -- The O(pads) distance test is the throttled half. The fade below is NOT: it integrates against
    -- the real frame dt, and stepping it four times a second is a visible regression.
    local fire, nextAcc = AmbientBudget.step(acc, dt, POLL)
    acc = nextAcc
    if fire then
        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local pos = hrp and hrp.Position
        for _, pad in pads do
            local near = false
            if pos ~= nil then
                local dx = pos.X - pad.center.X
                local dz = pos.Z - pad.center.Z
                near = (dx * dx + dz * dz) <= (pad.radius * pad.radius)
            end
            pad.near = near
            -- collision snaps at the threshold (solid the instant you're in range); the visual fades.
            if near ~= pad.collidable then
                pad.collidable = near
                for _, part in pad.parts do
                    part.CanCollide = near
                end
            end
        end
    end
    for _, pad in pads do
        local target = if pad.near then SHOWN else 1
        if math.abs(pad.alpha - target) > 0.001 then
            pad.alpha += (target - pad.alpha) * math.clamp(dt * FADE_RATE, 0, 1)
            if math.abs(pad.alpha - target) <= 0.01 then
                pad.alpha = target
            end
            for _, part in pad.parts do
                part.Transparency = pad.alpha
            end
        end
    end
end)
```

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/ShopController.client.luau roblox/src/client/AccessGateController.client.luau
git commit -m "perf(client): proximity tests poll at 4Hz; the gate fade keeps its frame dt"
```

---

### Task 7: Streaming radii

**Files:**
- Modify: `roblox/src/server/main.server.luau:141-143` (immediately after the `StagePersistence` loop)

**Interfaces:**
- Consumes: nothing.
- Produces: `Workspace` attributes `StreamMinRadius` and `StreamTargetRadius`, readable in the Explorer during a walk.

Nothing in git has ever set these; the place runs on engine defaults (min 64, target 1024). Setting them from the server at boot puts them in git and makes them self-healing, which is the same treatment `ArenaSpawn` and stage persistence already get.

- [ ] **Step 1: Set the radii at boot**

Insert after the `for _, model in StagePersistence.persistTargets(persistRoots) do ... end` loop:

```lua
-- STREAMING RADII, code-owned rather than left as place data. Nothing in git had ever set these and
-- the place ran on the engine defaults (min 64, target 1024). The stage and the horizon backdrop are
-- Persistent and unaffected; what tightens is the far canyon -- PathRailings (5,186 descendants),
-- PathLanterns (2,599), foliage -- which is precisely the bulk a low-end phone is carrying.
--
-- ⚠ THE TARGET IS AN OWNER-TUNED NUMBER, not a computed one. The canyon has long sightlines and the
-- failure mode is content popping in at the edge of view, which no test can see. Published as
-- attributes so it can be turned during a walk; record what lands in docs/wiki/world/place-state.md.
local STREAM_MIN, STREAM_TARGET = 64, 512
workspace.StreamingMinRadius = STREAM_MIN
workspace.StreamingTargetRadius = STREAM_TARGET
workspace:SetAttribute("StreamMinRadius", STREAM_MIN)
workspace:SetAttribute("StreamTargetRadius", STREAM_TARGET)
```

- [ ] **Step 2: Verify it applies**

Studio, Play, check `Workspace`'s properties: `StreamingTargetRadius` reads 512. If assigning it errors, `StreamingEnabled` is off in the place — stop and report, because three separate code comments assert it is on and that contradiction needs the owner, not a workaround.

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/server/main.server.luau
git commit -m "perf(server): own the streaming radii in code instead of engine defaults"
```

---

### Task 8: Stats-room `MaxDistance`

**Files:**
- Modify: `roblox/src/client/FlapBoard.luau:173-179`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

The stats room holds roughly 8,400 GUI instances (about seven per flap cell) and none of them stop rendering when the player leaves. `StatsController.client.luau` is `FlapBoard`'s only caller and it returns early for `isRoundDisplay(id)` at `:257`, so a default set here reaches exactly the in-room wall boards and **cannot** touch the cavern round display. No new `Config` field is needed.

- [ ] **Step 1: Set the distance**

Add the constant beside the file's other top-level constants:

```lua
-- The wall boards live in an enclosed room and are read from a few studs away; nothing outside the
-- room can make out a flap. Without this they render from anywhere in the canyon -- ~8,400 GUI
-- instances at roughly seven per cell, and the A13 measured this room as costing what the whole
-- arena square costs (docs/wiki/world/stats-room.md, 2026-08-17).
--
-- FlapBoard's only caller is StatsController, which returns early for the round display, so this
-- reaches the wall boards and cannot reach the cavern display.
local BOARD_MAX_DISTANCE = 150
```

and in `buildFace`, after `gui.CanvasSize = ...`:

```lua
    gui.MaxDistance = BOARD_MAX_DISTANCE
```

- [ ] **Step 2: Verify in Studio**

Play, walk into the stats room and confirm every board still paints normally at reading distance. Then walk out to the arena square and confirm the boards go blank rather than rendering across the canyon. If a board blanks while still legible from inside the room, raise the constant — do not remove it.

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/FlapBoard.luau
git commit -m "perf(client): stats-room boards stop rendering from outside the room"
```

---

### Task 9: Teahouse `Persistent` — investigate, then decide by rule

**Files:**
- Investigate: `roblox/src/server/TreatmentApplier.luau:154-156`
- Investigate (read-only): `roblox/src/client/TeahouseController.client.luau`, `DecorationController.client.luau`, `EconomyController.client.luau`, `ShojiController.client.luau`, `roblox/src/shared/ShojiRun.luau`
- Modify: `roblox/src/server/TreatmentApplier.luau` — **only if step 2 clears it**

**Interfaces:**
- Consumes: nothing.
- Produces: nothing other tasks depend on. This task may correctly end in no code change at all.

Every materialized teahouse is marked `ModelStreamingMode.Persistent`, so it never streams out for any client. The cost scales with occupied pads across the whole server, for every player, uncapped by distance — the largest potential memory win here and the only change in this plan that could break other people's teahouses. The stage does this for a documented reason (`main.server.luau:123-127`: spawn-watchers 200 studs out, and controllers that capture parts once at startup). Teahouses are built at runtime, after those controllers have started, so that justification does not obviously transfer — but nothing in the file or the wiki says why the line is there.

⚠ **This is an investigation with a decision rule, not a predetermined edit.** A guess here is worse than the status quo: the status quo is merely expensive, and a wrong guess breaks structures other players own.

- [ ] **Step 1: Find every dependency on a distant teahouse's parts**

```bash
cd roblox
grep -rn "WaitForChild" src/client/TeahouseController.client.luau src/client/DecorationController.client.luau src/client/ShojiController.client.luau src/client/EconomyController.client.luau
grep -rn "Structure\|teahouse\|Teahouse" src/client/*.luau | grep -i "waitforchild\|findfirstchild\|getchildren\|descendant"
```

Write down, for each hit: does it act on the local player's **own** structure, on **any** structure, or on a structure it found by tag or attribute? A controller that only ever touches the player's own pad is not a blocker; one that walks every structure in the world at startup is.

- [ ] **Step 2: Apply the decision rule**

Exactly one of these, and record which in the commit message:

1. **Nothing depends on a distant teahouse's parts** → delete the three lines at `:154-156` and let teahouses stream like the rest of the far canyon.
2. **Something does** → narrow persistence rather than removing it: keep `Persistent` for the structure on the claiming player's own pad, drop it for everyone else's. Record in a comment what forced this.
3. **Neither can be established with confidence** → **change nothing.** Add a comment at `:154-156` recording what was checked and what remains unknown, and carry the finding to the phase-2 spec.

- [ ] **Step 3: If a change was made, verify with two clients**

Studio, two-player local test: both players claim pads, then walk one player far from the other's teahouse and back. Confirm the structure reappears intact, its shoji still slide via their `ProximityPrompt`, and its decorations are still present. If any of that fails, revert to outcome 3 rather than patching around it.

- [ ] **Step 4: Commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/server/TreatmentApplier.luau
git commit -m "perf(server): <what you actually did, naming the decision-rule outcome>"
```

If the outcome was 3 and nothing changed but the comment, say so plainly in the message — a recorded non-change is a result, not a failure.

---

## After the tasks

- [ ] **Push, and watch CI go green.** A push is not done until its run is seen green.
- [ ] **Hand the owner the walk list**, which is the real gate for this plan:
  - the waterwheel, watched from the arena and from behind, for a frozen shadow or a stale phase;
  - the bonshō — does it still ring while you are looking away from it;
  - the machiya row, for noren that visibly start moving as they come into view;
  - a teahouse chōchin at arm's length, confirming the remaining sway is intact;
  - a path chōchin, confirming it is now still and that the round glyph on it still changes;
  - the canyon paths at speed, for content popping in at the edge of view (`StreamTargetRadius`);
  - the stats room, in and out, for boards that blank too early.
- [ ] **Tune live and record.** `AmbientRadius`, `AmbientBehindDot`, `AmbientHz`, `StreamMinRadius`, `StreamTargetRadius` are all `Workspace` attributes. Whatever lands goes into `docs/wiki/world/place-state.md`, and the day's entry goes into `docs/wiki/log.md`.
