# ZenDojo Creek Water-Feature Rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **MCP Studio gates and USER GATEs run in the main session, not in subagents.**

**Goal:** Replace the engineered kakehi flume with a natural SW creek that turns an Asakura-style undershot waterwheel cluster (driving the shu-moku striker on a rotated SW–NE axis) and feeds a streamside sōzu that kicks the throw drum.

**Architecture:** Pure builders (`roblox/tools/builders/`) → committed `assets/*.model.json` via `lune run tools/genmodels` → referenced in `default.project.json`. `ArenaLayout.luau` is the single coordinate authority; client controllers inline-mirror its build-time constants (not replicated). The creek bed/water is carved into the MCP-run terrain heightfield. Spec: `docs/superpowers/specs/2026-06-09-zendojo-creek-water-feature-design.md`.

**Tech Stack:** Luau, Rojo (7.6.1), Lune test harness (`tests/run`), Roblox Terrain (WriteVoxels via MCP `execute_luau`), `stylua` + `selene`.

**Conventions:**
- South is −Z (entrance/torii); the current drive train sits on the +Z (north) axis. SW = (−X, −Z). Rotating the +Z drive train onto SW is **yaw = 225°** about world-Y through the origin (verified: local +Z `(0,0,1)` → `(sin225, cos225) = (−0.707, −0.707)`).
- Run all tooling from `roblox/` with `export PATH="$HOME/.rokit/bin:$PATH"`.
- Gate after every task: `stylua --check src tests tools && selene src && lune run tests/run && lune run tools/genmodels && rojo build -o /tmp/b.rbxl`.
- The shu-moku swing motion is **already approved** — this plan only rotates its heading. Preserve the feel.

---

## File Structure

**Create:**
- `roblox/tools/builders/Sozu.luau` — shishi-odoshi lever, pivot post, bamboo spout, catch stone.
- `roblox/tools/builders/Creek.luau` — bank/bed stones, cascade rocks, stepping-stone punctuation (water itself is terrain).
- `roblox/src/client/SozuController.client.luau` — fills the lever through ACTIVE, dumps on `latchClick`, animates the cord + inflow ripple.
- `roblox/tests/Sozu.spec.luau`, `roblox/tests/Creek.spec.luau`.

**Modify:**
- `roblox/tools/builders/ArenaLayout.luau` — remove `flume`; add `creek`, `waterwheel`, `sozu`; rotate `shuMoku` to SW (yaw + same proven local geometry).
- `roblox/tools/builders/Spec.luau` — add pure `rotY`, `rotYMat`, `matMul` rotation helpers.
- `roblox/tools/builders/Waterwheel.luau` — single overshot wheel → SW undershot **cluster** (`Wheel1..3`, `Paddle{w}_{i}`).
- `roblox/tools/builders/Bonsho.luau` — place log + gantry + chains on the SW diagonal via the yaw helpers.
- `roblox/src/client/WheelController.client.luau` — spin the cluster; drop the Kakehi dependency; foam at the wheel waterline.
- `roblox/src/client/HammerController.client.luau` — rotate inlined gantry/rope constants + swing axis to SW.
- `roblox/tools/genmodels.luau` — drop Kakehi; add Sozu, Creek.
- `roblox/default.project.json` — drop Kakehi; add Sozu, Creek.
- `roblox/tools/studio/buildTerrain.luau` — carve the SW creek channel + basin notch.

**Delete:**
- `roblox/tools/builders/Kakehi.luau`, `roblox/tests/Kakehi.spec.luau`, `roblox/assets/Kakehi.model.json`.

---

## Task 1: Pure yaw helpers in Spec

**Files:**
- Modify: `roblox/tools/builders/Spec.luau`
- Test: `roblox/tests/Spec.spec.luau`

- [ ] **Step 1: Write the failing test** — append inside the existing `describe("Spec", ...)` block in `tests/Spec.spec.luau`:

```lua
    test("rotY sends +Z to the SW diagonal at yaw 225", function()
        local p = Spec.rotY({ 0, 6, 10 }, 225)
        expect(p[1]).toBeCloseTo(-7.071, 0.01)
        expect(p[2]).toBe(6)
        expect(p[3]).toBeCloseTo(-7.071, 0.01)
    end)
    test("matMul of identity is identity", function()
        local id = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local r = Spec.matMul(id, Spec.rotYMat(225))
        local y = Spec.rotYMat(225)
        for i = 1, 9 do
            expect(r[i]).toBeCloseTo(y[i], 0.0001)
        end
    end)
```

- [ ] **Step 2: Run to verify it fails** — `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run` → FAIL (`rotY`/`rotYMat`/`matMul` nil).

- [ ] **Step 3: Implement** — in `Spec.luau`, before `return Spec`:

```lua
-- Rotation about world-Y through the origin. Row-major 3x3 (matches Spec.cframe).
function Spec.rotYMat(deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { c, 0, s, 0, 1, 0, -s, 0, c }
end

-- Rotate a point about world-Y through the origin.
function Spec.rotY(p: { number }, deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { p[1] * c + p[3] * s, p[2], -p[1] * s + p[3] * c }
end

-- Row-major 3x3 multiply (a * b).
function Spec.matMul(a: { number }, b: { number }): { number }
    local r = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local s = 0
            for k = 0, 2 do
                s += a[row * 3 + k + 1] * b[k * 3 + col + 1]
            end
            r[row * 3 + col + 1] = s
        end
    end
    return r
end
```

- [ ] **Step 4: Run to verify it passes** — `lune run tests/run` → PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/builders/Spec.luau tests/Spec.spec.luau
git commit -m "feat(roblox): pure yaw rotation helpers in Spec (rotY/rotYMat/matMul)"
```

---

## Task 2: ArenaLayout — add creek/waterwheel/sozu + rotate shuMoku to SW

`flume` stays for now (Kakehi/Waterwheel still read it) so the suite stays green; it's removed in Task 8. `shuMoku` keeps its proven local +Z geometry and gains `yaw = 225`; the builder/controller rotate it.

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau`
- Test: `roblox/tests/ArenaLayout.spec.luau`

- [ ] **Step 1: Write the failing tests** — append inside `describe("ArenaLayout", ...)`:

```lua
    test("creek descends from rim to basin mouth on the SW diagonal", function()
        expect(L.creek.entry[2] > L.creek.mouth[2]).toBe(true) -- downhill
        -- entry on/near the rim, mouth at the basin edge
        local er = math.sqrt(L.creek.entry[1] ^ 2 + L.creek.entry[3] ^ 2)
        local mr = math.sqrt(L.creek.mouth[1] ^ 2 + L.creek.mouth[3] ^ 2)
        expect(er > L.tiers[3].radius).toBe(true)
        expect(mr < L.apronRadius).toBe(true)
        -- both points in the SW quadrant (x<0, z<0)
        expect(L.creek.entry[1] < 0 and L.creek.entry[3] < 0).toBe(true)
        expect(L.creek.mouth[1] < 0 and L.creek.mouth[3] < 0).toBe(true)
    end)
    test("waterwheels sit on the SW creek line, descending order, inside the apron-ish band", function()
        local prev = 0
        for i, c in L.waterwheel.centers do
            expect(c[1] < 0 and c[3] < 0).toBe(true) -- SW
            expect(math.abs(c[1] - c[3]) < 2).toBe(true) -- on the x=z line
            local r = math.sqrt(c[1] ^ 2 + c[3] ^ 2)
            if i > 1 then
                expect(r > prev).toBe(true) -- further out as we go up the creek
            end
            prev = r
        end
        expect(L.waterwheel.driver >= 1 and L.waterwheel.driver <= #L.waterwheel.centers).toBe(true)
    end)
    test("shu-moku is rotated onto the SW axis and rests outside the bell", function()
        expect(L.shuMoku.yaw).toBe(225)
        local rest = Spec.rotY(L.shuMoku.restPos, L.shuMoku.yaw)
        expect(rest[1] < 0 and rest[3] < 0).toBe(true) -- swung to SW
        local d = math.sqrt(rest[1] ^ 2 + rest[3] ^ 2)
        expect(d > L.bell.radius).toBe(true) -- clears the bell body
    end)
    test("sozu sits streamside near the driving wheel; cord targets the drum axle end", function()
        local driver = L.waterwheel.centers[L.waterwheel.driver]
        local d = math.sqrt((L.sozu.pivot[1] - driver[1]) ^ 2 + (L.sozu.pivot[3] - driver[3]) ^ 2)
        expect(d < 14).toBe(true) -- beside the wheel
        -- cord top reaches a drum axle end (drum at throwDrum.pos, axle half = length/2 along X)
        expect(math.abs(L.sozu.cordTop[2] - L.throwDrum.pos[2]) < 1).toBe(true)
        expect(math.abs(math.abs(L.sozu.cordTop[1] - L.throwDrum.pos[1]) - L.throwDrum.length / 2) < 1.5).toBe(true)
    end)
```

Add `local Spec = require("../tools/builders/Spec")` at the top of the spec (next to the existing requires) if not present.

- [ ] **Step 2: Run to verify it fails** — `lune run tests/run` → FAIL (`L.creek` nil, etc.).

- [ ] **Step 3: Implement** — in `ArenaLayout.luau`, replace the `shuMoku = { ... }` block's trailing comment line `}, -- draws toward +Z` is kept; **add `yaw = 225`** to `shuMoku`, and add the three new tables. Concretely, change the `shuMoku` table to include yaw:

```lua
    shuMoku = {
        restPos = { 0, 6.2, 9.5 },
        length = 7,
        radius = 0.8,
        drawStuds = 6,
        yaw = 225, -- rotate the proven +Z geometry onto the SW->NE diagonal
        railX = 3,
        railY = 15,
        railZ = { 5, 20 },
        chainTops = { { 3, 15, 7.5 }, { 3, 15, 11.5 }, { -3, 15, 7.5 }, { -3, 15, 11.5 } },
        chainBottomsRest = { { 0.8, 6.6, 7.5 }, { 0.8, 6.6, 11.5 }, { -0.8, 6.6, 7.5 }, { -0.8, 6.6, 11.5 } },
        ropeBottomRest = { 0, 6.2, 13 },
    },
```

Then, immediately after the `flume = { ... }` block, add:

```lua
    -- Natural creek down the SW diagonal (replaces the flume; flume removed in a later task).
    creek = {
        entry = { -132, 28, -132 }, -- on the rim (tier-3 height) at ~225 deg
        mouth = { -12, 0, -12 }, -- meets the basin water at the SW edge
        width = 8, -- channel width (studs)
        fastReachRadius = 46, -- inside this radius the channel flattens for the wheels
    },
    -- Asakura-style undershot cluster sitting IN the creek; centers[driver] drives the striker.
    waterwheel = {
        radius = 5,
        yaw = 45, -- axle along NW-SE so wheels roll along the SW->NE current
        centers = { { -18, 5, -18 }, { -26, 6, -26 }, { -34, 7, -34 } },
        driver = 1,
        ropeAnchor = { -14.6, 5, -14.6 }, -- on the driver toward the log; DriveRope leaves here
    },
    -- Streamside sozu (shishi-odoshi) that meters the round and kicks the drum.
    sozu = {
        pivot = { -22, 4, -13 }, -- pivot point, beside the driving wheel
        troughLen = 5,
        cordTop = { -7, 31, 0 }, -- drum W axle end (throwDrum at {0,31,0}, length 14)
    },
```

- [ ] **Step 4: Run to verify it passes** — `lune run tests/run` → PASS (existing flume test still passes; new tests pass).

- [ ] **Step 5: Commit**

```bash
git add tools/builders/ArenaLayout.luau tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): ArenaLayout — creek/waterwheel/sozu + shu-moku SW yaw"
```

---

## Task 3: Waterwheel → SW undershot cluster

Rework the single overshot wheel into the SW cluster. Each wheel is a disc (Cylinder, axle along world X) rotated by `waterwheel.yaw` so it rolls along the current; paddles ring each. Names: `Wheel1..N`, `Axle1..N`, `Paddle{w}_{i}`, and the `RatchetDrum` on the driver toward the log.

**Files:**
- Modify: `roblox/tools/builders/Waterwheel.luau`
- Test: `roblox/tests/Waterwheel.spec.luau`

- [ ] **Step 1: Replace the test** — overwrite `tests/Waterwheel.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Waterwheel = require("../tools/builders/Waterwheel")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Waterwheel cluster builder", function()
    test("one Wheel part per layout center, at that center", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local wheels = 0
        for _, c in spec.children :: any do
            local i = c.name:match("^Wheel(%d+)$")
            if i then
                wheels += 1
                local ctr = L.waterwheel.centers[tonumber(i) :: number]
                expect(c.properties.CFrame[1]).toBe(ctr[1])
                expect(c.properties.CFrame[3]).toBe(ctr[3])
            end
        end
        expect(wheels).toBe(#L.waterwheel.centers)
    end)
    test("eight paddles ring every wheel", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local counts: { [string]: number } = {}
        for _, c in spec.children :: any do
            local w = c.name:match("^Paddle(%d+)_%d+$")
            if w then
                counts[w] = (counts[w] or 0) + 1
            end
        end
        for i = 1, #L.waterwheel.centers do
            expect(counts[tostring(i)]).toBe(8)
        end
    end)
    test("the driver carries the RatchetDrum", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "RatchetDrum" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — `lune run tests/run` → FAIL (still single-wheel builder; `Wheel1` not found).

- [ ] **Step 3: Implement** — overwrite `tools/builders/Waterwheel.luau`:

```lua
--!strict
-- Asakura-style undershot waterwheel cluster sitting in the SW creek. Each wheel
-- is a timber disc whose axle lies along NW-SE (waterwheel.yaw) so it rolls with
-- the SW->NE current. centers[driver] carries the RatchetDrum that the runtime
-- DriveRope (HammerController) leaves from toward the shu-moku log.
local Spec = require("./Spec")

local Waterwheel = {}

function Waterwheel.build(palette: { [string]: { number } }, L: any)
    local W = L.waterwheel
    local R = W.radius
    local timber = palette.timber
    local rot = Spec.yaw(W.yaw) -- axle (local X of the cylinder) swung to NW-SE
    local children = {}

    for wi, c in W.centers do
        table.insert(
            children,
            Spec.part(`Wheel{wi}`, {
                Size = { 1.2, 2 * R, 2 * R },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = timber,
                Material = "Wood",
            })
        )
        table.insert(
            children,
            Spec.part(`Axle{wi}`, {
                Size = { 4.5, 0.8, 0.8 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(c, rot),
                Color = palette.ink,
                Material = "Metal",
            })
        )
        -- paddles ring the wheel in its own (yawed) plane: offset in local (Y,Z),
        -- then rotate that offset by yaw about world-Y so it follows the disc.
        for i = 1, 8 do
            local a = (i - 1) * math.pi / 4
            local off = Spec.rotY({ 0, (R - 0.6) * math.cos(a), (R - 0.6) * math.sin(a) }, W.yaw)
            table.insert(
                children,
                Spec.part(`Paddle{wi}_{i}`, {
                    Size = { 1.4, 1.8, 0.4 },
                    CFrame = Spec.cframe({ c[1] + off[1], c[2] + off[2], c[3] + off[3] }, rot),
                    Color = timber,
                    Material = "WoodPlanks",
                })
            )
        end
        -- two support trestles straddling the axle (cross-axis = NW-SE)
        for si, d in { -1.6, 1.6 } do
            local off = Spec.rotY({ d, 0, 0 }, W.yaw)
            table.insert(
                children,
                Spec.part(`Support{wi}_{si}`, {
                    Size = { 0.9, c[2] + R * 0.4, 0.9 },
                    CFrame = Spec.cframe({ c[1] + off[1], (c[2] + R * 0.4) / 2, c[3] + off[3] }),
                    Color = timber,
                    Material = "Wood",
                })
            )
        end
    end

    -- RatchetDrum on the driver, on its log-facing side (toward the bell = +NE).
    local dc = W.centers[W.driver]
    local toward = Spec.rotY({ 0, 0, -2.4 }, W.yaw) -- local -Z (toward origin/bell), yawed
    table.insert(
        children,
        Spec.part("RatchetDrum", {
            Size = { 1.6, 1.6, 1.6 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ dc[1] + toward[1], dc[2] + toward[2], dc[3] + toward[3] }, rot),
            Color = palette.ink,
            Material = "Metal",
        })
    )
    return Spec.model("Waterwheel", children)
end

return Waterwheel
```

- [ ] **Step 4: Verify** — `lune run tests/run` → PASS; then `lune run tools/genmodels` (rewrites `assets/Waterwheel.model.json`).

- [ ] **Step 5: Commit**

```bash
git add tools/builders/Waterwheel.luau tests/Waterwheel.spec.luau assets/Waterwheel.model.json
git commit -m "feat(roblox): Waterwheel as SW undershot Asakura cluster"
```

---

## Task 4: Bonsho — place log + gantry on the SW diagonal

The bell sections are radially symmetric, so only the **shu-moku log, gantry rails, posts, and chains** rotate. Use `shuMoku.yaw` to rotate every gantry point and the log/rail orientations. The chains use `Spec.segment` (auto-orients from endpoints) so they only need rotated endpoints.

**Files:**
- Modify: `roblox/tools/builders/Bonsho.luau`
- Test: `roblox/tests/Bonsho.spec.luau`

- [ ] **Step 1: Add a failing test** — append inside `describe(...)` in `tests/Bonsho.spec.luau`:

```lua
    test("ShuMoku is swung onto the SW axis (rest x<0 and z<0)", function()
        local Bonsho = require("../tools/builders/Bonsho")
        local L = require("../tools/builders/ArenaLayout")
        local ZenDojo = require("../src/shared/themes/ZenDojo")
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "ShuMoku" then
                expect(c.properties.CFrame[1] < 0).toBe(true)
                expect(c.properties.CFrame[3] < 0).toBe(true)
            end
        end
    end)
```

(If `tests/Bonsho.spec.luau` already requires `Bonsho`/`L`/`ZenDojo` at the top, drop the local re-requires and use those.)

- [ ] **Step 2: Run to verify it fails** — `lune run tests/run` → FAIL (`ShuMoku` still on +Z; CFrame x/z are 0/positive).

- [ ] **Step 3: Implement** — in `Bonsho.luau`, introduce yaw rotation for the log + gantry. Replace the `ShuMoku` part and the gantry/rail/post/chain section. The log: compose yaw with `CYL_ALONG_Z`. Concretely:

Replace the `ShuMoku` insertion with:

```lua
    local sp = Spec.rotY(L.shuMoku.restPos, L.shuMoku.yaw)
    local logRot = Spec.matMul(Spec.rotYMat(L.shuMoku.yaw), Spec.ROT.CYL_ALONG_Z)
    table.insert(
        children,
        Spec.part("ShuMoku", {
            Size = { L.shuMoku.length, 2 * L.shuMoku.radius, 2 * L.shuMoku.radius },
            Shape = "Cylinder",
            CFrame = Spec.cframe(sp, logRot),
            Color = palette.timber,
            Material = "Wood",
        })
    )
```

Replace the gantry rails + posts + chains section with yaw-rotated placement:

```lua
    local sm = L.shuMoku
    local yaw = sm.yaw
    -- rail endpoints (local +Z frame) → world via yaw. Rails run along the draw axis.
    local railLen = sm.railZ[2] - sm.railZ[1] + 1
    local railMidZ = (sm.railZ[1] + sm.railZ[2]) / 2
    local railRot = Spec.matMul(Spec.rotYMat(yaw), Spec.ROT.IDENTITY)
    local y2 = 2
    for i, rx in { sm.railX, -sm.railX } do
        local p = Spec.rotY({ rx, sm.railY, railMidZ }, yaw)
        table.insert(
            children,
            Spec.part(`Rail{i}`, {
                Size = { 0.8, 0.8, railLen },
                CFrame = Spec.cframe(p, railRot),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    local postSpots = { { sm.railX, sm.railZ[1] }, { -sm.railX, sm.railZ[1] }, { sm.railX, sm.railZ[2] }, { -sm.railX, sm.railZ[2] } }
    for i, spot in postSpots do
        local p = Spec.rotY({ spot[1], (sm.railY + y2) / 2, spot[2] }, yaw)
        table.insert(
            children,
            Spec.part(`GantryPost{i}`, {
                Size = { 0.8, sm.railY - y2, 0.8 },
                CFrame = Spec.cframe(p),
                Color = palette.timber,
                Material = "Wood",
            })
        )
    end
    for i = 1, 4 do
        local top = Spec.rotY(sm.chainTops[i], yaw)
        local bot = Spec.rotY(sm.chainBottomsRest[i], yaw)
        local pos, len, rot = Spec.segment(top, bot)
        table.insert(
            children,
            Spec.part(`Chain{i}`, {
                Size = { len, 0.25, 0.25 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, rot),
                Color = { 0.25, 0.25, 0.28 },
                Material = "Metal",
            })
        )
    end
```

Note: `Spec.ROT.IDENTITY` is exported. The vertical posts are unrotated (square cross-section), only their position is yawed.

- [ ] **Step 4: Verify** — `lune run tests/run` → PASS (the existing "ShuMoku rest position matches layout" test reads `L.shuMoku.restPos` directly, but now the part is at the *rotated* position; **update that existing test** to compare against `Spec.rotY(L.shuMoku.restPos, L.shuMoku.yaw)`). Then `lune run tools/genmodels`.

- [ ] **Step 5: Commit**

```bash
git add tools/builders/Bonsho.luau tests/Bonsho.spec.luau assets/BonshoRig.model.json
git commit -m "feat(roblox): place shu-moku log + gantry on the SW diagonal"
```

---

## Task 5: HammerController — re-aim the swing to SW (live)

No unit test (client runtime); verified live at the Task 11 gate. Rotate the inlined gantry/rope mirrors and express draw/swing/recoil along the SW–NE axis. The motion math is unchanged — only its heading rotates.

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau`

- [ ] **Step 1: Rotate the inlined constants.** Replace the `chainTops`, `chainBottomsRest`, `ropeWheelAnchor`, `ropeBottomRest` definitions with a runtime yaw applied to the same +Z values (keep them readable as the proven geometry):

```lua
local YAW = CFrame.Angles(0, math.rad(225), 0) -- mirror ArenaLayout.shuMoku.yaw
local function rot(t: { number }): Vector3
    return (YAW * CFrame.new(t[1], t[2], t[3])).Position
end

local chains = {
    rig:WaitForChild("Chain1") :: BasePart,
    rig:WaitForChild("Chain2") :: BasePart,
    rig:WaitForChild("Chain3") :: BasePart,
    rig:WaitForChild("Chain4") :: BasePart,
}
local chainTops = { rot({ 3, 15, 7.5 }), rot({ 3, 15, 11.5 }), rot({ -3, 15, 7.5 }), rot({ -3, 15, 11.5 }) }
local chainBottomsRest = { rot({ 0.8, 6.6, 7.5 }), rot({ 0.8, 6.6, 11.5 }), rot({ -0.8, 6.6, 7.5 }), rot({ -0.8, 6.6, 11.5 }) }
local ropeWheelAnchor = rot({ -14.6, 5, -14.6 }) -- ArenaLayout.waterwheel.ropeAnchor (already SW; rot() is harmless? NO — see note)
local ropeBottomRest = rot({ 0, 6.2, 13 }) -- ArenaLayout.shuMoku.ropeBottomRest (+Z local)
```

**Important:** `ropeWheelAnchor` in the new layout (`waterwheel.ropeAnchor = {-14.6, 5, -14.6}`) is **already in SW world space** — do NOT pass it through `rot()`. Use it directly:

```lua
local ropeWheelAnchor = Vector3.new(-14.6, 5, -14.6) -- ArenaLayout.waterwheel.ropeAnchor (world SW)
```

- [ ] **Step 2: Re-aim the draw/swing/recoil onto the SW axis.** The current code uses world-Z offsets (`CFrame.new(0, riseY, drawZ)`, `CFrame.new(0,0,-0.8)`, `CFrame.new(0,0,1.1)`). Define the diagonal directions and rewrite the three offsets. Add near the top (after `restCFrame`):

```lua
local BACK = (YAW * CFrame.new(0, 0, 1)).Position -- draw direction: back toward the wheel (SW)
```

In the `gongStrike` handler, change the swing and recoil targets:

```lua
        -- Stage 1: swing forward (toward the bell = -BACK) to overshoot into it.
        local swing = TweenService:Create(
            arm,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { CFrame = CFrame.new(-BACK * 0.8) * restCFrame }
        )
```

and

```lua
            -- Stage 2: recoil back toward the wheel, then settle.
            local recoil = TweenService:Create(
                arm,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = CFrame.new(BACK * 1.1 + Vector3.new(0, 0.15, 0)) * restCFrame }
            )
```

In the draw Heartbeat, replace the `draw`/`pose` construction:

```lua
        local p = state.angleDeg / 100
        local drawZ = p * 6
        local riseY = p * p * 1.2
        local shiver = if state.trembling
            then math.sin(os.clock() * 28) * 0.15 + (math.random() - 0.5) * 0.04
            else 0
        local off = BACK * (drawZ + shiver) + Vector3.new(0, riseY, 0)
        local pose = CFrame.new(off) * restCFrame
        if state.trembling then
            pose = pose * CFrame.Angles(0, math.rad(math.sin(os.clock() * 23) * 0.4), 0)
        end
        arm.CFrame = pose
```

- [ ] **Step 3: Sync + live-check (MCP, main session).** Save; let Rojo sync (wait ~4s); `start_stop_play(true)`; over a round, screen_capture the bell from the SW and confirm: the log hangs from the SW gantry, draws toward the SW wheel, and swings NE onto the bell's SW face (the gold strike boss). Expect the same swing *feel*, new heading. `start_stop_play(false)`.

- [ ] **Step 4: Commit**

```bash
git add src/client/HammerController.client.luau
git commit -m "feat(roblox): re-aim shu-moku swing onto the SW diagonal"
```

---

## Task 6: WheelController — spin the cluster, drop the Kakehi dependency (live)

The current controller `WaitForChild("Kakehi")` and emits an overshot waterfall — both go. Spin all cluster wheels about each wheel's own axle; emit a small foam at the driver's waterline instead.

**Files:**
- Modify: `roblox/src/client/WheelController.client.luau`

- [ ] **Step 1: Rewrite the rig capture + particle.** Replace the wheel/paddle capture and the entire `kakehi`/`fall` block with cluster capture + a waterline foam:

```lua
local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Waterwheel")

type Spin = { part: BasePart, hub: CFrame, paddles: { BasePart }, offsets: { CFrame } }
local spins: { Spin } = {}
for _, child in rig:GetChildren() do
    local wi = child.Name:match("^Wheel(%d+)$")
    if wi then
        local wheel = child :: BasePart
        local s: Spin = { part = wheel, hub = wheel.CFrame, paddles = {}, offsets = {} }
        for _, p in rig:GetChildren() do
            if p.Name:match(`^Paddle{wi}_%d+$`) then
                table.insert(s.paddles, p :: BasePart)
                table.insert(s.offsets, wheel.CFrame:ToObjectSpace((p :: BasePart).CFrame))
            end
        end
        table.insert(spins, s)
    end
end

-- foam at the driving wheel's waterline (undershot — no overshot waterfall)
local driver = rig:FindFirstChild("Wheel1") :: BasePart?
local fall = Instance.new("ParticleEmitter")
fall.Color = ColorSequence.new(Color3.fromRGB(210, 222, 228))
fall.Size = NumberSequence.new(0.5, 1.1)
fall.Transparency = NumberSequence.new(0.5)
fall.Lifetime = NumberRange.new(0.3, 0.5)
fall.Rate = 22
fall.Speed = NumberRange.new(3, 5)
fall.SpreadAngle = Vector2.new(40, 40)
if driver then
    local sink = Instance.new("Attachment")
    sink.Position = Vector3.new(0, -driver.Size.Y / 2 + 0.4, 0)
    sink.Parent = driver
    fall.Parent = sink
end
```

- [ ] **Step 2: Spin every wheel.** Replace the `RunService.Heartbeat` body:

```lua
RunService.Heartbeat:Connect(function(dt)
    if not spinning then
        return
    end
    angle += dt * 0.9
    for _, s in spins do
        local spun = s.hub * CFrame.Angles(angle, 0, 0)
        s.part.CFrame = spun
        for i, p in s.paddles do
            p.CFrame = spun * s.offsets[i]
        end
    end
end)
```

The `RoundUpdate`/`Cue` handlers stay (set `spinning` and `fall.Rate`).

- [ ] **Step 3: Live-check (MCP).** Sync, play, confirm all wheels turn slowly and the foam sits at the driver's base; ratchet-freeze on lockout. Stop play.

- [ ] **Step 4: Commit**

```bash
git add src/client/WheelController.client.luau
git commit -m "feat(roblox): spin the SW wheel cluster; drop the Kakehi/overshot dependency"
```

---

## Task 7: Delete the kakehi flume + remove `flume` from ArenaLayout

Nothing reads `L.flume` now (Waterwheel uses `L.waterwheel`; WheelController dropped the Kakehi part). Remove it all.

**Files:**
- Delete: `roblox/tools/builders/Kakehi.luau`, `roblox/tests/Kakehi.spec.luau`, `roblox/assets/Kakehi.model.json`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`, `roblox/tools/builders/ArenaLayout.luau`, `roblox/tests/ArenaLayout.spec.luau`

- [ ] **Step 1: Update the failing flume test.** In `tests/ArenaLayout.spec.luau` delete the existing test `"flume runs downhill: pool higher than wheel top"` entirely (the creek-descends test from Task 2 replaces its intent).

- [ ] **Step 2: Delete files + references.**

```bash
git rm tools/builders/Kakehi.luau tests/Kakehi.spec.luau assets/Kakehi.model.json
```

In `tools/genmodels.luau`: remove `local Kakehi = require("./builders/Kakehi")` and the `["Kakehi"] = Kakehi.build(ZenDojo.palette, ArenaLayout),` line from `OUTPUTS`.

In `default.project.json`: remove the `"Kakehi": { "$path": "assets/Kakehi.model.json" },` line.

In `ArenaLayout.luau`: remove the entire `flume = { ... }` block.

- [ ] **Step 3: Verify** — `lune run tests/run` (PASS, no Kakehi spec), `lune run tools/genmodels` (no Kakehi output, no drift), `rojo build -o /tmp/b.rbxl` (PASS).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(roblox): delete the kakehi flume + flume layout"
```

---

## Task 8: Sozu builder

A shishi-odoshi: a pivot post, a trough lever (built in its resting/empty pose — the controller tweens it), a short bamboo spout, and a catch stone. Names the controller needs: `Lever`, `Pivot`.

**Files:**
- Create: `roblox/tools/builders/Sozu.luau`, `roblox/tests/Sozu.spec.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`

- [ ] **Step 1: Write the failing test** — `tests/Sozu.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Sozu = require("../tools/builders/Sozu")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Sozu builder", function()
    test("has a Lever and a Pivot at the layout pivot", function()
        local spec = Sozu.build(ZenDojo.palette, L)
        local names: { [string]: boolean } = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Lever"]).toBe(true)
        expect(names["Pivot"]).toBe(true)
    end)
    test("the lever sits at the streamside pivot height", function()
        local spec = Sozu.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "Lever" then
                expect(math.abs(c.properties.CFrame[1] - L.sozu.pivot[1]) < L.sozu.troughLen).toBe(true)
            end
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — `lune run tests/run` → FAIL (module missing).

- [ ] **Step 3: Implement** — `tools/builders/Sozu.luau`:

```lua
--!strict
-- Sozu (shishi-odoshi): a pivoting bamboo trough beside the driving wheel. Built
-- in its resting (empty, tipped-down-toward-fill) pose; SozuController tweens the
-- Lever between fill and dump and runs the cord to the drum. Part names Lever and
-- Pivot are the controller contract.
local Spec = require("./Spec")

local Sozu = {}

function Sozu.build(palette: { [string]: { number } }, L: any)
    local s = L.sozu
    local px, py, pz = s.pivot[1], s.pivot[2], s.pivot[3]
    local bamboo = palette.timber
    local children = {
        Spec.part("Pivot", {
            Size = { 0.6, py + 1, 0.6 },
            CFrame = Spec.cframe({ px, (py + 1) / 2, pz }),
            Color = palette.ink,
            Material = "Wood",
        }),
        -- the trough lever: a bamboo tube, resting tilted toward its open (fill) end
        Spec.part("Lever", {
            Size = { 1.0, 1.0, s.troughLen },
            CFrame = Spec.cframe({ px, py, pz }, { 1, 0, 0, 0, 0.97, -0.26, 0, 0.26, 0.97 }),
            Color = bamboo,
            Material = "Wood",
        }),
        -- catch stone the lever clacks against
        Spec.part("CatchStone", {
            Size = { 1.6, 0.8, 1.2 },
            CFrame = Spec.cframe({ px, 0.4, pz - s.troughLen / 2 }),
            Color = palette.gravel,
            Material = "Slate",
        }),
    }
    return Spec.model("Sozu", children)
end

return Sozu
```

- [ ] **Step 4: Wire + verify.** In `genmodels.luau` add `local Sozu = require("./builders/Sozu")` and `["Sozu"] = Sozu.build(ZenDojo.palette, ArenaLayout),`. In `default.project.json` add under `RoshamboStage`: `"Sozu": { "$path": "assets/Sozu.model.json" },`. Run `lune run tests/run` (PASS), `lune run tools/genmodels` (writes `assets/Sozu.model.json`), `rojo build -o /tmp/b.rbxl`.

- [ ] **Step 5: Commit**

```bash
git add tools/builders/Sozu.luau tests/Sozu.spec.luau tools/genmodels.luau default.project.json assets/Sozu.model.json
git commit -m "feat(roblox): Sozu builder (shishi-odoshi lever)"
```

---

## Task 9: SozuController + cord (live)

Fills the lever through ACTIVE, dumps on `latchClick` (the same cue that kicks the drum), runs a cord to the drum, and ripples the basin where the creek enters. Client runtime — verified live.

**Files:**
- Create: `roblox/src/client/SozuController.client.luau`

- [ ] **Step 1: Implement** — `src/client/SozuController.client.luau`:

```lua
--!strict
-- Sozu (shishi-odoshi) timing lever. Fills through ACTIVE; dumps on latchClick
-- (lockout) — the same cue that kicks the throw drum — then resets. A cord runs
-- from the lever's tip to the drum's W axle end (mirrors ArenaLayout.sozu.cordTop).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Sozu")
local lever = rig:WaitForChild("Lever") :: BasePart
local restCFrame = lever.CFrame

-- empty (fill) pose tilts the open end down; dump pose tilts it the other way.
local FILL = restCFrame
local DUMP = restCFrame * CFrame.Angles(math.rad(34), 0, 0)

-- cord from the lever tip up to the drum W axle end
local cordTop = Vector3.new(-7, 31, 0) -- ArenaLayout.sozu.cordTop
local cord = Instance.new("Part")
cord.Name = "SozuCord"
cord.Anchored = true
cord.CanCollide = false
cord.Color = Color3.fromRGB(60, 50, 40)
cord.Material = Enum.Material.Fabric
cord.Size = Vector3.new(0.15, 0.15, 1)
cord.Parent = rig

local function tipPos(): Vector3
    return (lever.CFrame * CFrame.new(0, 0, -lever.Size.Z / 2)).Position
end
local function updateCord()
    local a, b = tipPos(), cordTop
    local mid = (a + b) / 2
    cord.CFrame = CFrame.new(mid, b)
    cord.Size = Vector3.new(0.15, 0.15, (b - a).Magnitude)
end
updateCord()

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        -- ease back to the fill pose for the new round
        TweenService:Create(lever, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = FILL }):Play()
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "latchClick" then
        -- dump: quick tip, then a small clack settle
        local dump = TweenService:Create(lever, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = DUMP })
        dump:Play()
    end
end)

game:GetService("RunService").Heartbeat:Connect(updateCord)
```

- [ ] **Step 2: Live-check (MCP).** Sync, play, watch a round: the lever rests in fill pose during ACTIVE, tips at lockout (as the drum kicks into its spin), the cord tracks the tip. Confirm the dump and the drum spin read as cause→effect. Stop play.

- [ ] **Step 3: Commit**

```bash
git add src/client/SozuController.client.luau
git commit -m "feat(roblox): SozuController — fill/dump timing lever + cord to the drum"
```

---

## Task 10: Creek dressing builder

Static garden dressing along the creek line (the water itself is terrain, Task 11): bank/bed river stones, cascade rocks near each tier crossing, and a couple of placed boulders. Sampled along the `creek.entry → creek.mouth` line.

**Files:**
- Create: `roblox/tools/builders/Creek.luau`, `roblox/tests/Creek.spec.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`

- [ ] **Step 1: Write the failing test** — `tests/Creek.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Creek = require("../tools/builders/Creek")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Creek dressing builder", function()
    test("places stones along the SW creek line, descending from entry to mouth", function()
        local spec = Creek.build(ZenDojo.palette, L)
        local stones = 0
        local maxY, minY = -1e9, 1e9
        for _, c in spec.children :: any do
            if c.name:match("^Stone%d+$") then
                stones += 1
                expect(c.properties.CFrame[1] < 0 and c.properties.CFrame[3] < 0).toBe(true)
                maxY = math.max(maxY, c.properties.CFrame[2])
                minY = math.min(minY, c.properties.CFrame[2])
            end
        end
        expect(stones >= 6).toBe(true)
        expect(maxY > minY).toBe(true) -- descends
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — `lune run tests/run` → FAIL.

- [ ] **Step 3: Implement** — `tools/builders/Creek.luau`:

```lua
--!strict
-- Creek dressing: river stones along the SW channel + cascade rocks. The water
-- ribbon is carved into terrain (tools/studio/buildTerrain.luau); this is the
-- stone garniture sampled along creek.entry -> creek.mouth.
local Spec = require("./Spec")

local Creek = {}

function Creek.build(palette: { [string]: { number } }, L: any)
    local e, m = L.creek.entry, L.creek.mouth
    local children = {}
    local N = 9
    for i = 0, N do
        local t = i / N
        local x = e[1] + (m[1] - e[1]) * t
        local y = e[2] + (m[2] - e[2]) * t
        local z = e[3] + (m[3] - e[3]) * t
        -- alternate banks: offset perpendicular to the SW line (the NW-SE axis)
        local side = (i % 2 == 0) and 1 or -1
        local off = Spec.rotY({ side * (L.creek.width / 2 + 0.6), 0, 0 }, 45)
        table.insert(
            children,
            Spec.part(`Stone{i}`, {
                Size = { 2 + (i % 3) * 0.6, 1.4 + (i % 2) * 0.5, 2.2 - (i % 2) * 0.4 },
                CFrame = Spec.cframe({ x + off[1], y + 0.3, z + off[3] }, Spec.yaw(20 * i)),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        -- a cascade rock midstream every third sample (where it steps down a tier)
        if i % 3 == 1 then
            table.insert(
                children,
                Spec.part(`Cascade{i}`, {
                    Size = { L.creek.width * 0.7, 1.0, 1.2 },
                    CFrame = Spec.cframe({ x, y - 0.2, z }, Spec.yaw(45)),
                    Color = palette.gravel,
                    Material = "Rock",
                })
            )
        end
    end
    return Spec.model("Creek", children)
end

return Creek
```

- [ ] **Step 4: Wire + verify.** `genmodels.luau`: add `local Creek = require("./builders/Creek")` and `["Creek"] = Creek.build(ZenDojo.palette, ArenaLayout),`. `default.project.json`: add `"Creek": { "$path": "assets/Creek.model.json" },`. Run `lune run tests/run` (PASS), `lune run tools/genmodels`, `rojo build -o /tmp/b.rbxl`.

- [ ] **Step 5: Commit**

```bash
git add tools/builders/Creek.luau tests/Creek.spec.luau tools/genmodels.luau default.project.json assets/Creek.model.json
git commit -m "feat(roblox): Creek dressing builder (bank stones + cascades)"
```

---

## Task 11: Terrain — carve the SW creek channel + basin notch (MCP, main session)

The terrain is a WriteVoxels heightfield run via MCP `execute_luau` (not Rojo-synced). Add a creek channel cut along the SW diagonal that overrides the tier surface where it applies. Edit the committed script AND run it in Studio.

**Files:**
- Modify: `roblox/tools/studio/buildTerrain.luau`

- [ ] **Step 1: Add the creek profile helper.** In `buildTerrain.luau`, after the `KOI` constant and `padDist`, add:

```lua
-- Creek: a channel down the SW diagonal (the x=z line, both negative) from the
-- rim to the basin. Overrides the tier surface where it applies: carves the bed
-- below the surroundings and lays a connected water ribbon.
local CREEK = { halfW = 4, mouthR = 12, rimR = 190, bedMouth = -1, bedRim = 25 }
local function creekColumn(x, z, r)
    if x > 4 or z > 4 then
        return nil -- SW quadrant only
    end
    local dCenter = math.abs(x - z) / 1.41421356 -- distance to the x=z centerline
    if dCenter > CREEK.halfW or r < CREEK.mouthR or r > CREEK.rimR then
        return nil
    end
    local t = math.clamp((r - CREEK.mouthR) / (CREEK.rimR - CREEK.mouthR), 0, 1)
    local bed = CREEK.bedMouth + t * (CREEK.bedRim - CREEK.bedMouth)
    -- bank lip: lerp bed up toward the channel edge so the cut has sloped sides
    local edge = ss(CREEK.halfW - 1.5, CREEK.halfW, dCenter)
    return { g = bed + edge * 1.5, wb = bed - 1, wt = bed + 1.0 }
end
```

- [ ] **Step 2: Apply it in `evalColumn`.** At the very top of `evalColumn` (right after `local r = math.sqrt(x * x + z * z)`), insert:

```lua
    local creek = creekColumn(x, z, r)
    if creek then
        return creek
    end
```

This makes the creek win over the basin/apron/tier logic where it applies (and the basin's own `r < BASIN_R` branch still handles the pond; the creek's `mouthR = 12 < 16` lets the channel notch into the basin's SW edge).

- [ ] **Step 3: Run it in Studio (MCP).** Confirm Edit mode (`get_studio_state`). Paste the full updated `buildTerrain.luau` into `execute_luau` (it is idempotent — rebuilds every column). Then `screen_capture` from the SW rim looking down to the basin and confirm: a continuous water ribbon descends the SW slope, cuts through the terraces, and joins the basin; the wheels sit in it.

- [ ] **Step 4: Commit the script** (the terrain itself lives in the place, not git — only the script is committed):

```bash
git add tools/studio/buildTerrain.luau
git commit -m "feat(roblox): carve the SW creek channel + basin notch into terrain"
```

---

## Task 12: Full water-feature USER GATE (main session)

- [ ] **Step 1: Sync + play.** Ensure `rojo serve` is running; let it push all builder/controller changes; `start_stop_play(true)`; wait for a spawn + a full round.

- [ ] **Step 2: Capture + verify the whole feature.** Screen_capture from the south sandō approach and from the SW:
  - Creek enters SW, runs straight + fast down the terraces, spills into the basin (no flume remnants anywhere).
  - The Asakura wheel cluster turns in the current; the driver couples toward the log.
  - The shu-moku draws toward the SW wheel and strikes the bell's SW boss — same motion feel, new heading.
  - The sōzu fills through ACTIVE, dumps/clacks at lockout, the drum kicks into its spin and lands at reveal; the cord tracks.
  - Top of the arena still clear; HUD unaffected.

- [ ] **Step 3: Tune (iterate).** Adjust `ArenaLayout` coordinates (wheel centers, sōzu pivot, creek width, `CREEK` bed slope) and re-run as needed; re-`genmodels` + re-run terrain after each change. This is the live-tuning step the spec calls for.

- [ ] **Step 4: Final gate** — `stylua --check src tests tools && selene src && lune run tests/run && lune run tools/genmodels && rojo build -o /tmp/b.rbxl` all green; `git status` clean.

- [ ] **Step 5: Finish the branch** — use `superpowers:finishing-a-development-branch`.

---

## Self-Review

**Spec coverage:**
- §1 vibe (no plumbing) → flume deleted (T7); creek + Asakura wheels are garden objects. ✓
- §2 SW creek + drive-train rotation → ArenaLayout creek/yaw (T2), Bonsho (T4), HammerController (T5). ✓
- §3 Asakura undershot cluster + fast reach → Waterwheel cluster (T3), terrain fast reach via `fastReachRadius`/bed slope (T2/T11). ✓
- §4 sōzu drum-driver, drum unchanged → Sozu builder (T8) + controller (T9); DrumController untouched (not in the file list). ✓
- §5 creek terrain channel + dressing → terrain (T11), Creek builder (T10). ✓
- §6 component change list → every file covered across T1–T11. ✓
- §7 preserve hammer motion → T5 rotates the *same* math (proven geometry + yaw), live-verified. ✓
- §8 testing → ArenaLayout relationship tests (T2), builder part tests (T3/T8/T10), drift check + gates every task. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code. Coordinate values are concrete (tuning is an explicit live step in T12, not a placeholder). ✓

**Type/name consistency:** Part names are consistent across builders↔controllers — `Wheel{n}`/`Paddle{w}_{i}`/`RatchetDrum` (T3↔T6), `Lever`/`Pivot` (T8↔T9), `Chain1..4` (T4↔T5). `Spec.rotY/rotYMat/matMul` defined in T1 and used in T2/T3/T4. `waterwheel.ropeAnchor` is world-SW and used directly (not re-rotated) in T5 — flagged explicitly. ✓
