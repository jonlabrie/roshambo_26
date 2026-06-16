# ZenDojo Bell Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the clearing's throw machine as one legible water engine — a single in-river wheel drives a visible cam-and-gear train that draws and trips the shu-moku into the bonshō (gong), and the shu-moku's dowel kicks a vertical shaft that spins the throw drum.

**Architecture:** `ArenaLayout.luau` is the coordinate authority; pure builders (`require("./Spec")`, deterministic) emit `assets/*.model.json` via `lune run tools/genmodels`, Rojo-synced into `workspace.RoshamboStage`. A new `BellDrive` builder adds the exposed drive train; `Bonsho`/`ThrowDrum`/`Waterwheel`/`Shoro` are modified. DI'd client controllers animate the named parts, choreographed to the clock (`HammerCurve`) — the motion is theatre, not physics. Part names are the builder↔controller contract.

**Tech Stack:** Luau, Rojo, Lune test harness, MCP Roblox Studio (live gates).

**Spec:** `docs/superpowers/specs/2026-06-16-zendojo-bell-engine-design.md`.

**Conventions (every task honors):**
- Builders are pure, `require("./Spec")`, deterministic (no `math.random`). After builder changes: from `roblox/`, `lune run tools/genmodels` (committed `assets/*.model.json` are CI drift-checked — never hand-edit).
- Gates from `roblox/`: `export PATH="$HOME/.rokit/bin:$PATH" && stylua --check src tests tools && selene src && lune run tests/run && lune run tools/genmodels && rojo build -o /tmp/b.rbxl`.
- **Controller & live-staging tasks are MCP/Studio-verified, not Lune-tested** (runtime). Run in the main session via MCP `execute_luau` (datamodel `Edit`/`Client`, Play as needed); signed off at gates. Rojo must be connected (`rojo serve` from `roblox/`).
- World frame: clearing centre = origin; up-canyon −X (West), down-canyon +X (East); river/wheel = North (−Z); gathering = South (+Z); bell struck face South. Terrace ~y111; bell hangs ~y120.
- **Do not commit geometry/controllers as "done" until verified at the gate** (standing user rule). Commit code+tests when Lune-green; sign off visuals at gates.
- Starting coordinates below are tuned at the staging/machine gates — Lune tests assert *relationships*, not exact values.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `roblox/tools/builders/ArenaLayout.luau` | Coordinate authority; add `bellDrive` block, reposition `waterwheel` riverside, add `shuMoku.dowel`, shorten gantry, re-orient `throwDrum` | Modify |
| `roblox/tools/builders/BellDrive.luau` | NEW: main shaft, gear-down, cam, vertical shaft + paddle, drum yoke | Create |
| `roblox/tools/builders/Bonsho.luau` | Add `ShuMokuDowel`; shorten the gantry rail to the real draw | Modify |
| `roblox/tools/builders/ThrowDrum.luau` | Re-orient 90° (faces ±X); mount on the vertical-shaft top; drop self-support | Modify |
| `roblox/tools/builders/Waterwheel.luau` | Confirm axle heading = the main-shaft line (riverside) | Verify/Modify |
| `roblox/tools/builders/Shoro.luau` | Open frame clears the drum yoke + houses the trestle | Verify/Modify |
| `roblox/tools/genmodels` (build list) + `roblox/default.project.json` | Register `BellDrive` model | Modify |
| `roblox/tests/BellDrive.spec.luau` | Drive-train fixture: parts present, gears mesh, paddle on the dowel arc, yoke carries the drum | Create |
| `roblox/tests/ArenaLayout.spec.luau` | Relationship asserts for the engine layout | Modify |
| `roblox/tests/Bonsho.spec.luau` | Dowel present; gantry shortened | Modify/Create |
| `roblox/tests/ThrowDrum.spec.luau` | Faces ±X; carried on the vertical shaft | Modify/Create |
| `roblox/src/client/HammerController.client.luau` | Animate cam + gear-down tracking the shu-moku draw | Modify |
| `roblox/src/client/DrumController.client.luau` | Strike-keyed drum spin on the vertical shaft (kick→spin→settle) | Modify |

---

## Task 1: ArenaLayout — engine coordinate blocks

**Files:** Modify `roblox/tools/builders/ArenaLayout.luau`; Test `roblox/tests/ArenaLayout.spec.luau`.

Add a `bellDrive` block and reposition the wheel riverside of the tower; add the shu-moku dowel; re-orient the throw drum. These are starting coordinates (tuned at Task 6's gate); the test checks relationships.

- [ ] **Step 1: Write the failing test.** Append to `roblox/tests/ArenaLayout.spec.luau` inside a new `describe`:

```lua
describe("ArenaLayout bell engine", function()
    local L = require("../tools/builders/ArenaLayout")
    test("waterwheel sits riverside (North, -Z) directly off the tower", function()
        local c = L.waterwheel.centers[1]
        expect(c[3] < -8).toBe(true) -- North of the tower
        expect(math.abs(c[1]) < 10).toBe(true) -- ~on the tower axis, not downriver
    end)
    test("bellDrive block defines a meshing gear-down", function()
        local d = L.bellDrive
        expect(d ~= nil).toBe(true)
        local dx = d.camGear[1] - d.driverGear[1]
        local dy = d.camGear[2] - d.driverGear[2]
        local dz = d.camGear[3] - d.driverGear[3]
        local centre = math.sqrt(dx * dx + dy * dy + dz * dz)
        expect(math.abs(centre - (d.driverR + d.camR)) < 0.6).toBe(true) -- pitch circles touch
        expect(d.camR > d.driverR * 2).toBe(true) -- big reduction (cam creeps)
    end)
    test("vertical shaft carries the drum and its paddle is at the shu-moku swing level", function()
        local d = L.bellDrive
        expect(d.vertTop[2] > d.vertBase[2] + 15).toBe(true) -- a tall shaft up to the drum
        expect(math.abs(d.paddle[2] - L.shuMoku.restPos[2]) < 4).toBe(true) -- paddle meets the dowel arc
        expect(math.abs(d.vertTop[1] - L.throwDrum.pos[1]) < 4).toBe(true) -- drum rides the shaft top
        expect(math.abs(d.vertTop[3] - L.throwDrum.pos[3]) < 4).toBe(true)
    end)
    test("shu-moku has a dowel that reaches toward the paddle", function()
        expect(L.shuMoku.dowel ~= nil).toBe(true)
        expect(L.shuMoku.dowel.length > 1).toBe(true)
    end)
    test("throw drum is re-oriented to face up/downriver (yaw 90)", function()
        expect(L.throwDrum.yaw).toBe(90)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run` → FAIL (`L.bellDrive` nil / `shuMoku.dowel` nil).

- [ ] **Step 3: Edit `ArenaLayout.luau`.** Reposition the waterwheel riverside, add the dowel, re-orient the drum, add the `bellDrive` block. Replace the `waterwheel` `centers`/`ropeAnchor` lines:

```lua
        centers = { { 0, 112, -18 } }, -- in the river, due North of the tower; axle (Z) runs South into the house
        driver = 1,
        ropeAnchor = { 0, 112, -10 },
```

In `shuMoku`, add a `dowel` field (a peg on the log flank that strikes the vertical-shaft paddle as it swings):

```lua
        dowel = { from = { -2, 118, 6 }, length = 3, yaw = 0 }, -- flank peg → kicks the BellDrive paddle
```

In `throwDrum`, set `yaw = 90` (faces present up/downriver ±X) and lift it onto the vertical-shaft top:

```lua
    throwDrum = { pos = { 6, 140, 4 }, length = 14, radius = 7, faces = 6, yaw = 90 },
```

Add the `bellDrive` block near the machine fields:

```lua
    -- ===== Bell engine drive train (exposed on the open frame) =====
    -- One input (the river wheel's Z-axle) → gear-down → cam draws/trips the shu-moku;
    -- the shu-moku's dowel kicks the vertical shaft → spins the drum. Starting coords;
    -- tuned at the staging gate. Builders read these by name.
    bellDrive = {
        shaftFrom = { 0, 112, -18 }, shaftTo = { 0, 112, -3 }, shaftR = 0.5, -- wheel axle into the house
        driverGear = { 0, 112, -3 }, driverR = 1.6, -- small fast gear on the main shaft
        camGear = { 0, 117.2, -3 }, camR = 3.6, -- big slow gear (centre 5.2 above → meshes)
        camShaftFrom = { 0, 117.2, -3 }, camShaftTo = { -2, 117.2, 7 }, -- cam shaft (along Z) to the striker
        cam = { -2, 117.2, 7 }, camLobe = 2.2, -- wiper that draws the shu-moku tail
        vertBase = { 6, 112, 4 }, vertTop = { 6, 140, 4 }, vertR = 0.7, -- vertical drum shaft
        paddle = { 6, 118, 4 }, paddleLen = 2.4, -- struck by the shu-moku dowel
        yoke = { 6, 140, 4 }, yokeSpan = 10, -- bearing arms holding the drum above the roof
    },
```

- [ ] **Step 4: Run tests.** `lune run tests/run` → PASS (engine asserts green; other specs still green — note Bonsho/ThrowDrum builders not yet updated may have their own specs to fix in later tasks).

- [ ] **Step 5: Commit.**
```bash
git add roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): ArenaLayout bell-engine block — riverside wheel, gear-down/cam, vertical drum shaft, dowel"
```

---

## Task 2: BellDrive builder

**Files:** Create `roblox/tools/builders/BellDrive.luau`; Test `roblox/tests/BellDrive.spec.luau`; register in `tools/genmodels` + `default.project.json`.

Emits the exposed drive train. Part names are the controller contract: `MainShaft`, `DriverGear`, `CamGear`, `CamShaft`, `Cam`, `VertShaft`, `VertPaddle`, `DrumYoke1`/`DrumYoke2`.

- [ ] **Step 1: Write the failing test.** Create `roblox/tests/BellDrive.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local BellDrive = require("../tools/builders/BellDrive")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BellDrive builder", function()
    local function names(spec)
        local n = {}
        for _, c in spec.children :: any do
            n[c.name] = true
        end
        return n
    end
    test("emits the whole train by name", function()
        local n = names(BellDrive.build(ZenDojo.palette, L))
        for _, want in { "MainShaft", "DriverGear", "CamGear", "CamShaft", "Cam", "VertShaft", "VertPaddle" } do
            expect(n[want]).toBe(true)
        end
    end)
    test("two drum-yoke arms carry the drum", function()
        local n = names(BellDrive.build(ZenDojo.palette, L))
        expect(n["DrumYoke1"] and n["DrumYoke2"]).toBe(true)
    end)
    test("the gears are placed at the layout centres", function()
        local spec = BellDrive.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "DriverGear" then
                expect(c.properties.CFrame[1]).toBe(L.bellDrive.driverGear[1])
                expect(c.properties.CFrame[2]).toBe(L.bellDrive.driverGear[2])
            end
        end
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails.** `lune run tests/run` → FAIL (`BellDrive` module not found).

- [ ] **Step 3: Implement `roblox/tools/builders/BellDrive.luau`:**

```lua
--!strict
-- Exposed bell-engine drive train: the wheel's axle extended into the house as the
-- MAIN SHAFT, a visible gear-down (small DriverGear meshing a big slow CamGear), the
-- CamShaft + Cam that draws/trips the shu-moku, and the VertShaft (with VertPaddle the
-- shu-moku's dowel kicks) carrying the drum on a two-arm DrumYoke. Part names are the
-- HammerController/DrumController contract — do not rename without retargeting them.
local Spec = require("./Spec")

local BellDrive = {}

function BellDrive.build(palette: { [string]: { number } }, L: any)
    local d = L.bellDrive
    local timber, iron = palette.timber, palette.ink
    local children = {}

    -- main shaft (the wheel's Z-axle into the house)
    local sp, slen, srot = Spec.segment(d.shaftFrom, d.shaftTo)
    table.insert(children, Spec.part("MainShaft", {
        Size = { slen, d.shaftR * 2, d.shaftR * 2 },
        Shape = "Cylinder",
        CFrame = Spec.cframe(sp, srot),
        Color = iron,
        Material = "Metal",
    }))
    -- gear-down: discs in the X-Y plane (axle along Z), centres a pitch-radius apart
    for _, g in { { "DriverGear", d.driverGear, d.driverR }, { "CamGear", d.camGear, d.camR } } do
        table.insert(children, Spec.part(g[1] :: string, {
            Size = { 0.8, (g[3] :: number) * 2, (g[3] :: number) * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(g[2], Spec.ROT.CYL_ALONG_Z),
            Color = timber,
            Material = "WoodPlanks",
        }))
    end
    -- cam shaft + cam (the wiper that draws the shu-moku tail)
    local cp, clen, crot = Spec.segment(d.camShaftFrom, d.camShaftTo)
    table.insert(children, Spec.part("CamShaft", {
        Size = { clen, 0.7, 0.7 },
        Shape = "Cylinder",
        CFrame = Spec.cframe(cp, crot),
        Color = iron,
        Material = "Metal",
    }))
    table.insert(children, Spec.part("Cam", {
        Size = { 1.2, d.camLobe, d.camLobe },
        CFrame = Spec.cframe(d.cam, Spec.ROT.CYL_ALONG_Z),
        Color = timber,
        Material = "Wood",
    }))
    -- vertical drum shaft + the paddle the dowel kicks
    local vp, vlen = Spec.segment(d.vertBase, d.vertTop)
    table.insert(children, Spec.part("VertShaft", {
        Size = { d.vertR * 2, vlen, d.vertR * 2 },
        Shape = "Cylinder",
        CFrame = Spec.cframe(vp, Spec.ROT.CYL_VERTICAL),
        Color = iron,
        Material = "Metal",
    }))
    table.insert(children, Spec.part("VertPaddle", {
        Size = { d.paddleLen, 1.4, 0.5 },
        CFrame = Spec.cframe(d.paddle),
        Color = timber,
        Material = "Wood",
    }))
    -- two yoke arms straddling the drum axle, above the roof
    for i, dx in { -d.yokeSpan / 2, d.yokeSpan / 2 } do
        table.insert(children, Spec.part(`DrumYoke{i}`, {
            Size = { 0.8, 5, 0.8 },
            CFrame = Spec.cframe({ d.yoke[1] + dx, d.yoke[2] + 2.5, d.yoke[3] }),
            Color = timber,
            Material = "Wood",
        }))
    end
    return Spec.model("BellDrive", children)
end

return BellDrive
```

(If `Spec.ROT.CYL_ALONG_Z` / `CYL_VERTICAL` are not present, check `tools/builders/Spec.luau` for the existing rotation constants — `Bonsho.luau` and `Waterwheel.luau` use `Spec.ROT.CYL_VERTICAL` and `Spec.yaw(...)`. Use whatever the codebase already exposes; the names above mirror `Bonsho.luau`.)

- [ ] **Step 4: Run tests.** `lune run tests/run` → PASS.

- [ ] **Step 5: Register the model.** In `tools/genmodels` add `BellDrive` to the builders it writes (mirror the `Waterwheel` entry). In `default.project.json`, under `Workspace.RoshamboStage`, add `"BellDrive": { "$path": "assets/BellDrive.model.json" }` (mirror `Waterwheel`).

- [ ] **Step 6: Regenerate + gate.** `lune run tools/genmodels && stylua --check src tests tools && selene src && lune run tests/run && rojo build -o /tmp/b.rbxl` → all green; `assets/BellDrive.model.json` created.

- [ ] **Step 7: Commit.**
```bash
git add roblox/tools/builders/BellDrive.luau roblox/tests/BellDrive.spec.luau roblox/tools/genmodels roblox/default.project.json roblox/assets/BellDrive.model.json
git commit -m "feat(roblox): BellDrive builder — main shaft, gear-down, cam, vertical drum shaft, yoke"
```

---

## Task 3: Bonsho — dowel + shortened gantry

**Files:** Modify `roblox/tools/builders/Bonsho.luau`; Test `roblox/tests/Bonsho.spec.luau` (create if absent).

Add the `ShuMokuDowel` peg on the log flank, and shorten the over-long gantry rail to the actual draw (the rail was sized for the retired SW layout).

- [ ] **Step 1: Write the failing test.** Add to (or create) `roblox/tests/Bonsho.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Bonsho = require("../tools/builders/Bonsho")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Bonsho dowel + gantry", function()
    test("emits a ShuMokuDowel peg", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "ShuMokuDowel" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)
    test("gantry rail is no longer than the shu-moku draw needs (<= 9 studs)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Rail%d$") then
                expect(c.properties.Size[3] <= 9).toBe(true)
            end
        end
    end)
end)
```

- [ ] **Step 2: Run it.** `lune run tests/run` → FAIL (no `ShuMokuDowel`; rails are 16 long).

- [ ] **Step 3: Edit `Bonsho.luau`.** (a) Shorten the gantry: in `ArenaLayout.shuMoku`, change `railZ = { 5, 20 }` to `railZ = { 6, 13 }` (a 7-stud rail). (b) In `Bonsho.luau`, after the `ShuMoku` insert, add the dowel from `L.shuMoku.dowel`:

```lua
    -- dowel peg on the shu-moku flank: sweeps with the swing and kicks the BellDrive paddle
    local dw = L.shuMoku.dowel
    local dpos, dlen, drot = Spec.segment(dw.from, { dw.from[1], dw.from[2], dw.from[3] + dw.length })
    table.insert(children, Spec.part("ShuMokuDowel", {
        Size = { dlen, 0.5, 0.5 },
        Shape = "Cylinder",
        CFrame = Spec.cframe(dpos, drot),
        Color = palette.timber,
        Material = "Wood",
    }))
```

- [ ] **Step 4: Run tests.** `lune run tests/run` → PASS.

- [ ] **Step 5: Regenerate + gate.** `lune run tools/genmodels && stylua --check src tests tools && selene src && rojo build -o /tmp/b.rbxl` → green; `assets/BonshoRig.model.json` regenerated.

- [ ] **Step 6: Commit.**
```bash
git add roblox/tools/builders/Bonsho.luau roblox/tools/builders/ArenaLayout.luau roblox/tests/Bonsho.spec.luau roblox/assets/BonshoRig.model.json
git commit -m "feat(roblox): shu-moku dowel + shortened gantry rail"
```

---

## Task 4: ThrowDrum — re-orient + ride the vertical shaft

**Files:** Modify `roblox/tools/builders/ThrowDrum.luau`; Test `roblox/tests/ThrowDrum.spec.luau` (create if absent).

Re-orient the drum 90° (faces up/downriver, ±X), mount it on the vertical-shaft top (`bellDrive.vertTop`), and drop any self-supporting legs (the yoke carries it now).

- [ ] **Step 1: Write the failing test.** Add to (or create) `roblox/tests/ThrowDrum.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local ThrowDrum = require("../tools/builders/ThrowDrum")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ThrowDrum on the vertical shaft", function()
    test("the drum body sits at the vertical-shaft top", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "ThrowDrum" or c.name == "Drum" then
                expect(math.abs(c.properties.CFrame[1] - L.bellDrive.vertTop[1]) < 3).toBe(true)
                expect(math.abs(c.properties.CFrame[3] - L.bellDrive.vertTop[3]) < 3).toBe(true)
            end
        end
    end)
    test("no self-supporting legs (yoke carries it) — no part named Leg/Post", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            expect(c.name:match("Leg") == nil and c.name:match("Post") == nil).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run it.** `lune run tests/run` → FAIL (drum at old pos / has legs).

- [ ] **Step 3: Edit `ThrowDrum.luau`.** Read the builder; set the drum body CFrame to `L.throwDrum.pos` (now `bellDrive.vertTop` = `{6,140,4}`) with `Spec.yaw(L.throwDrum.yaw)` (yaw 90 → faces ±X); rotate the face windows with the same yaw; remove any support-leg/post parts (the `DrumYoke` from BellDrive carries it). Keep the face/window geometry and the `ThrowDrum` part name (the DrumController contract).

- [ ] **Step 4: Run tests.** `lune run tests/run` → PASS.

- [ ] **Step 5: Regenerate + gate.** `lune run tools/genmodels && stylua --check src tests tools && selene src && rojo build -o /tmp/b.rbxl` → green; `assets/ThrowDrum.model.json` regenerated.

- [ ] **Step 6: Commit.**
```bash
git add roblox/tools/builders/ThrowDrum.luau roblox/tests/ThrowDrum.spec.luau roblox/assets/ThrowDrum.model.json
git commit -m "feat(roblox): throw drum re-oriented (faces up/downriver), rides the vertical shaft"
```

---

## Task 5: Waterwheel + Shoro — seat the wheel, clear the yoke

**Files:** Verify/Modify `roblox/tools/builders/Waterwheel.luau`, `roblox/tools/builders/Shoro.luau`.

The Task-1 coords moved the wheel due North of the tower (axle = the main-shaft line). Confirm the wheel builds there in the current and its axle aligns to `bellDrive.shaftFrom→shaftTo`; confirm the Shoro open frame + roof clears the drum yoke at `vertTop`.

- [ ] **Step 1: Regenerate + read.** `lune run tools/genmodels`; if the assets changed, note the diff. Read `Waterwheel.luau` — confirm the wheel center reads `L.waterwheel.centers[1]` and yaw aligns the axle along Z (toward the house). Read `Shoro.luau` — confirm the frame footprint/roof spans the tower without colliding with `bellDrive.vertTop`/`yoke`.

- [ ] **Step 2: Adjust only if needed.** If the Shoro roof clips the drum/yoke (drum at y140, roof lower), widen the roof opening or shift the yoke clear — keep changes minimal and coordinate-driven via `ArenaLayout`. If nothing needs changing, skip to Step 4.

- [ ] **Step 3: Re-run gate** if any builder changed: `lune run tools/genmodels && stylua --check src tests tools && selene src && lune run tests/run && rojo build -o /tmp/b.rbxl`.

- [ ] **Step 4: Commit** (only if files changed).
```bash
git add roblox/tools/builders/Waterwheel.luau roblox/tools/builders/Shoro.luau roblox/tools/builders/ArenaLayout.luau roblox/assets/*.model.json
git commit -m "feat(roblox): seat the wheel on the main-shaft line; Shoro frame clears the drum yoke"
```

---

## Task 6: MACHINE STAGING GATE (MCP/live) — assemble the static engine

**Files:** none (Studio verification + ArenaLayout coordinate tuning only).

- [ ] **Step 1: Sync.** Ensure `rojo serve` is connected and Studio has the regenerated assets (`BellDrive`, `BonshoRig`, `ThrowDrum`, `Waterwheel`, `Shoro` under `workspace.RoshamboStage`).

- [ ] **Step 2: Inspect via MCP.** With `execute_luau` (datamodel `Edit`), read each model's bounding box; verify: wheel in the river due North of the tower with its axle pointing South into the house; `MainShaft`→`DriverGear`→`CamGear` form a continuous line with the gears meshing (edges touching); `Cam` sits beside the shu-moku tail; `VertShaft` rises beside the shu-moku to the drum; `VertPaddle` lies on the arc the `ShuMokuDowel` sweeps; `ThrowDrum` rides `vertTop` facing ±X with the `DrumYoke` arms straddling it clear of the roof.

- [ ] **Step 3: Screenshot + tune.** Capture from the spawn (downstream, up-canyon) and a 3/4 angle. Tune `ArenaLayout.bellDrive`/`waterwheel`/`shuMoku`/`throwDrum` coords until the train reads as one continuous engine (gears mesh, cam reaches the striker, paddle under the dowel, drum readable). Re-run `lune run tools/genmodels` after each coord change; re-sync.

- [ ] **Step 4: GATE (USER).** Confirm the static assembly reads right; tune until signed off.

- [ ] **Step 5: Commit any coordinate tuning.**
```bash
git add roblox/tools/builders/ArenaLayout.luau roblox/assets/*.model.json
git commit -m "feat(roblox): tune the bell-engine staging to read as one continuous train"
```

---

## Task 7: HammerController — cam + gear-down track the draw

**Files:** Modify `roblox/src/client/HammerController.client.luau`.

The controller already draws/swings the shu-moku from the clock (`HammerCurve`). Add visual rotation of the gear-down + cam **locked to the same draw value**, so the cam visibly creeps the shu-moku back through ACTIVE and snaps past at the trip — selling the linkage as causal.

- [ ] **Step 1: Read the file** to find the draw value (the `HammerCurve` output / the shu-moku tween phase) and where parts are captured by name.

- [ ] **Step 2: Capture the new parts.** Grab `BellDrive`'s `DriverGear`, `CamGear`, `Cam`, `CamShaft` from `workspace.RoshamboStage.BellDrive` (alongside the existing shu-moku/chain captures).

- [ ] **Step 3: Drive them off the draw.** Map the same normalized draw value `p ∈ [0,1]` (creep up over ACTIVE, snap at trip) to: `CamGear`/`Cam` rotation `= p * drawAngle` about their axle (local X / Z per their build rotation); `DriverGear` rotation `= -p * drawAngle * (camR/driverR)` (counter-rotates, faster, matching the reduction so the mesh reads correct). Rotate about the part's hub like the existing shu-moku spin (`hubCFrame * CFrame.Angles(...)`). Keep the actual shu-moku draw/swing exactly as-is (clock-driven).

- [ ] **Step 4: Verify live (MCP).** In Studio Play (or by driving the cue), confirm through a round: the wheel turns; the cam + gears creep the shu-moku back during ACTIVE; at the trip the cam snaps past and the shu-moku swings into the bell. The gear pair counter-rotates and the cam stays visually locked to the log (no slip).

- [ ] **Step 5: Gate + commit.** `stylua --check src tests tools && selene src && rojo build -o /tmp/b.rbxl`
```bash
git add roblox/src/client/HammerController.client.luau
git commit -m "feat(roblox): HammerController drives the cam + gear-down to track the shu-moku draw"
```

---

## Task 8: DrumController — strike-keyed spin on the vertical shaft

**Files:** Modify `roblox/src/client/DrumController.client.luau`.

The drum no longer free-spins during ACTIVE. It is **at rest** until the strike; the shu-moku's dowel "kicks" it, then it spins up on the vertical shaft and **settles on the world-throw face** at reveal.

- [ ] **Step 1: Read the file** to find how it captures the drum and how the reveal/world-throw face is signaled (the existing reveal cue + face-index logic).

- [ ] **Step 2: Re-key the spin.** Replace continuous/ACTIVE spinning with a strike-triggered tween: on the reveal cue (the same beat the shu-moku strikes), kick the `VertShaft` + `ThrowDrum` into a fast spin about the **vertical axis**, then ease to a stop on the world-throw face's heading (faces present ±X). At rest otherwise. Keep the face-index→heading mapping; only the axis (now vertical) and the trigger (now the strike, not ACTIVE) change.

- [ ] **Step 3: Spin the VertShaft with it.** Rotate `BellDrive.VertShaft` in lockstep with the drum so the shaft visibly drives it (both about world-Y through `vertTop`).

- [ ] **Step 4: Verify live (MCP).** In Studio Play, run a round: drum rests through ACTIVE; at reveal the dowel meets the paddle, the vertical shaft + drum spin up and settle showing the world throw to up/downriver. Confirm the settle lands on the correct face and coincides with the gong.

- [ ] **Step 5: Gate + commit.** `stylua --check src tests tools && selene src && rojo build -o /tmp/b.rbxl`
```bash
git add roblox/src/client/DrumController.client.luau
git commit -m "feat(roblox): DrumController — strike-keyed drum spin/settle on the vertical shaft"
```

---

## Task 9: MACHINE GATE (USER) — full live round

**Files:** none (verification + tuning only).

- [ ] **Step 1: Bring it together.** `rojo serve` current, Studio reconnected, all assets synced.
- [ ] **Step 2: Run a full round** in Play (or drive cues). Verify the causal story end-to-end: wheel turns → gear-down creeps the cam → cam draws the shu-moku back through ACTIVE → at reveal the cam trips → shu-moku swings → **gong** + the dowel kicks the paddle → vertical shaft + **drum spin up and settle** on the world throw (facing up/downriver). Re-cock for the next round.
- [ ] **Step 3: Tune** coordinates (`ArenaLayout`) and controller timings until it reads as one engine — the gear-down creeping and the dowel-kick coinciding with the drum spin are the two beats that sell causality. Capture a hero shot from the spawn and from a sample perch.
- [ ] **Step 4: Hold commits until sign-off**, then commit any final tuning.

---

## Self-Review (plan author)

**Spec coverage:** Form/open frame → Tasks 5,6. Single in-river wheel + axle-as-shaft → Tasks 1,5. Gear-down → Tasks 1,2,7. Cam draw/trip → Tasks 1,2,7. Bonshō + shu-moku cam-driven + gantry fix → Tasks 1,3,7. Dowel → Tasks 1,3. Vertical shaft + paddle → Tasks 1,2,8. Drum up top, yoke, faces ±X → Tasks 1,2,4,8. Sōzu dropped → already removed (prior commit; no task needed). Clock reconciliation → Tasks 7,8,9. Testing (Lune fixtures + MCP gates) → Tasks 1–4 specs, 6/7/8/9 gates. ✓ no gaps.

**Placeholder scan:** Task 4 Step 3 and Task 5 are read-then-edit (the existing `ThrowDrum`/`Shoro`/`Waterwheel` builders' internals aren't reproduced here) — the *targets* are specified (drum at `vertTop`, yaw 90, no legs; frame clears the yoke); the implementer matches them to each file's existing structure. Task 1's coords are explicit starting values, tuned at the Task-6 gate (called out). No "TBD"/"handle edge cases".

**Type/name consistency:** Part names `MainShaft`/`DriverGear`/`CamGear`/`CamShaft`/`Cam`/`VertShaft`/`VertPaddle`/`DrumYoke{i}` (Task 2 builder) are consumed by Tasks 7 (`DriverGear`/`CamGear`/`Cam`/`CamShaft`) and 8 (`VertShaft`). `ShuMokuDowel` (Task 3) pairs with `VertPaddle` (Task 2) at Task-8's kick. `ThrowDrum` part name preserved (Task 4 ↔ DrumController Task 8). `ArenaLayout.bellDrive` fields (`shaftFrom/To`, `driverGear/driverR`, `camGear/camR`, `camShaftFrom/To`, `cam/camLobe`, `vertBase/vertTop/vertR`, `paddle/paddleLen`, `yoke/yokeSpan`) used identically across Tasks 1,2,6,7,8. `shuMoku.dowel` (Task 1) read in Task 3. `throwDrum.yaw=90` (Task 1) read in Task 4. ✓
