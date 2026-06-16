# ZenDojo Canyon Clearing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the canyon's focal clearing — a leveled riverside shelf with a plunge pool + in-fall at the back, the ported bell/throw machine re-staged centred at the pool's downstream lip (waterwheel now overshot), two clearing-local flip-boards, a sandy gathering outcrop for ~50, and the river exiting the boundary fall.

**Architecture:** `ArenaLayout.luau` is evolved into the canyon's coordinate authority — its monument/machine block is retargeted to the clearing (machine at world X/Z origin, Y on the leveled clearing floor). The existing machine builders (`Bonsho`/`Shoro`/`Waterwheel`/`ThrowDrum`/`Sozu`) and client controllers are re-staged via those coordinates; the waterwheel becomes overshot (above water, flume-fed). Terrain leveling + water basins are MCP `execute_luau` operations on the imported canyon terrain (not Rojo-synced). Fall/mist are client VFX.

**Tech Stack:** Luau, Rojo, Lune test harness, Roblox Terrain (WriteVoxels) + Water, Beams/ParticleEmitters, MCP Roblox Studio.

**Spec:** `docs/superpowers/specs/2026-06-15-zendojo-canyon-clearing-design.md`.

**Conventions (every task honors):**
- Builders are pure, `require("./Spec")`, deterministic (no `math.random`/`math.noise`). After builder changes: from `roblox/`, `lune run tools/genmodels` (committed `assets/*.model.json` are CI drift-checked — never hand-edit).
- Gates from `roblox/`: `export PATH="$HOME/.rokit/bin:$PATH" && stylua --check src tests tools && selene src && lune run tests/run && lune run tools/genmodels && rojo build -o /tmp/b.rbxl`.
- **Terrain & VFX & live-staging tasks are MCP/Studio-verified, not Lune-tested** (terrain uses `math.noise`/WriteVoxels; controllers/VFX are runtime). They run in the **main session** via MCP `execute_luau` (datamodel `Edit`, Play stopped), and are signed off at gates. This mirrors the bowl build (T5/T9/T12 etc.).
- World frame: clearing centre = world origin; canyon along X (head −X, boundary +X); Z cross-canyon. Terrain imported at **1.5×**; clearing floor will be leveled to ~**y112** (tuned at the terrain gate). Roblox: 1 stud ≈ 1 ft, avatar ~5 studs.
- **Do not commit geometry/terrain as "done" until verified at its gate** (standing user rule). Commit code+tests when Lune-green; sign off visuals at gates.
- The clearing machine lives in the scene at world origin; the throwaway `ClearingGreybox` model is deleted once real parts replace it.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `roblox/tools/builders/ArenaLayout.luau` | Coordinate authority; add `clearing` block, retarget monument coords to the clearing, mark `overshot` | Modify |
| `roblox/tests/ArenaLayout.spec.luau` | Assert clearing machine coords self-consistent (bell centred, wheel above pool, etc.) | Modify |
| `roblox/tools/builders/Waterwheel.luau` | Overshot variant: supports to ground, headrace flume feeds the top | Modify |
| `roblox/tests/Waterwheel.spec.luau` | Assert wheel bottom above the pool water level; headrace present | Create/Modify |
| `roblox/src/client/WheelController.client.luau` | Flip spin sign (overshot) + new wheel position | Modify |
| `roblox/src/client/HammerController.client.luau` | Re-aim strike onto clearing axis (positions only) | Modify |
| `roblox/src/client/SozuController.client.luau` | Re-target sōzu + cord positions | Modify |
| `roblox/src/client/DrumController.client.luau` | Behavior unchanged; re-target if it reads positions | Verify/Modify |
| `roblox/src/client/BoardController.client.luau` | Two clearing-local flip-boards (was one large board) | Modify |
| `roblox/tools/studio/buildClearing.luau` | MCP terrain op: level shelf + carve pool/river/boundary-fall + water | Create (MCP-run) |
| `roblox/src/client/FallVfx.client.luau` | In-fall + boundary-fall water sheets + mist | Create |
| `roblox/src/server/main.server.luau` | Persistent streaming for clearing stage models (already loops stage models) | Verify |

---

## Task 1: ArenaLayout — clearing coordinate block

**Files:** Modify `roblox/tools/builders/ArenaLayout.luau`; Test `roblox/tests/ArenaLayout.spec.luau`.

Retarget the machine to the clearing. Add a `clearing` block and machine coordinates centred at world origin (X/Z) on the leveled clearing floor (`FLOOR = 112`), arranged: pool back third (−X), machine at the pool's downstream lip (≈origin), outcrop front (+X). Keep the existing field NAMES the builders read (`bell`, `shuMoku`, `waterwheel`, `sozu`, `throwDrum`, `pavilion`) so builders need no signature changes — only their values move. These starting values are tuned at the gates; the test only checks relationships.

- [ ] **Step 1: Write the failing test.** Append to `roblox/tests/ArenaLayout.spec.luau` inside a new `describe`:

```lua
describe("ArenaLayout canyon clearing", function()
    local L = require("../tools/builders/ArenaLayout")
    test("clearing block defines floor, pool, outcrop, boundary", function()
        expect(L.clearing ~= nil).toBe(true)
        expect(L.clearing.floorY).toBe(112)
        expect(L.clearing.poolSurfaceY < L.clearing.floorY).toBe(true) -- pool recessed
        expect(L.clearing.poolCentre[1] < 0).toBe(true)               -- back third (−X)
        expect(L.clearing.boundaryX > 0).toBe(true)                   -- downstream (+X)
    end)
    test("bell is on the clearing centreline, on the floor", function()
        expect(math.abs(L.bell.pos[1]) < 8).toBe(true)   -- near origin X
        expect(math.abs(L.bell.pos[3]) < 8).toBe(true)   -- near centreline Z
        expect(L.bell.pos[2] > L.clearing.floorY).toBe(true) -- bell hangs above the floor
    end)
    test("waterwheel is OVERSHOT: bottom above the pool surface, flume feeds the top", function()
        local w = L.waterwheel
        local bottom = w.centers[1][2] - w.radius
        expect(bottom > L.clearing.poolSurfaceY).toBe(true) -- above tailwater
        expect(w.overshot).toBe(true)
        expect(w.headFrom ~= nil and w.headTo ~= nil).toBe(true) -- flume head race
        -- flume delivers to the wheel TOP
        expect(math.abs(w.headTo[2] - (w.centers[1][2] + w.radius)) < 3).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run` → FAIL (`L.clearing` nil).

- [ ] **Step 3: Add the clearing block + retarget the machine.** In `ArenaLayout.luau`, add near the top (after the `local ArenaLayout = {` open) a clearing block and retarget the machine fields. Use these starting coordinates (world; FLOOR=112):

```lua
    -- ===== Canyon clearing (focal heart) — supersedes the bowl monument zone =====
    -- World origin = clearing centre. Pool/in-fall upstream (−X); boundary fall
    -- downstream (+X); machine centred at the pool's downstream lip. Y on the
    -- leveled clearing floor. Values are starting points — tuned at the gates.
    clearing = {
        floorY = 112,
        poolCentre = { -34, 110, 0 }, poolHalf = 28, poolSurfaceY = 110, -- recessed basin
        outcropCentre = { 40, 112, 0 }, outcropHalf = { 48, 34 },        -- gathering shelf
        boundaryX = 124, boundaryLipY = 100,                              -- lowest fall
        inFallTopY = 150,                                                 -- in-fall crest
    },
```

Then retarget the existing machine fields to clearing coordinates (replace the bowl values; keep the field names/shape the builders read). Bell centred just downstream of the pool, hanging above the floor; shōrō frames it; throw drum rides it; sōzu beside the wheel:

```lua
    bell = { pos = { -2, 121, 0 }, height = 13.5, radius = 5.1 },
    pavilion = { pos = { -2, 112, 0 }, postSpacing = 18, roofHeight = 22, yaw = 0 },
    throwDrum = { pos = { -2, 138, 0 }, length = 14, radius = 7, faces = 6, yaw = 0 },
    shuMoku = {
        restPos = { -2, 118, 9 }, length = 7, radius = 0.8, drawStuds = 6, yaw = 0,
        railX = 3, railY = 127, railZ = { 5, 20 },
        chainTops = { { 3, 127, 7.5 }, { 3, 127, 11.5 }, { -3, 127, 7.5 }, { -3, 127, 11.5 } },
        chainBottomsRest = { { 0.8, 118.6, 7.5 }, { 0.8, 118.6, 11.5 }, { -0.8, 118.6, 7.5 }, { -0.8, 118.6, 11.5 } },
        ropeBottomRest = { -2, 118, 13 },
    },
    -- OVERSHOT wheel: above the pool, fed on top by a headrace flume tapping the in-fall.
    waterwheel = {
        radius = 6, overshot = true, yaw = 90, driveYaw = 0,
        bedY = 112,                       -- supports stand on the clearing floor (not submerged)
        centers = { { -16, 118, -4 } },   -- hub; bottom = 118−6 = 112 > poolSurface 110
        driver = 1,
        ropeAnchor = { -13, 118, -4 },
        headFrom = { -30, 132, -4 },      -- taps the in-fall
        headTo = { -16, 124, -4 },        -- pours onto the wheel top (hub 118 + radius 6)
        launderTo = { -8, 116, 8 },       -- small bleed to the sōzu
    },
    sozu = { pivot = { -8, 116, 8 }, troughLen = 5, cordTop = { -2, 138, -2 } },
```

(Leave the now-dormant bowl fields — `tiers`, `creek`, `koiPond`, `promontories`, `teahouses`, `sando`, `torii`, `stele`, `jumbotron` — in place for now; removing them is out of scope and risks breaking other builders. They no longer drive the clearing.)

- [ ] **Step 4: Run tests to verify pass.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run` → PASS (clearing tests green; other specs still green).

- [ ] **Step 5: Commit.**
```bash
git add roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): ArenaLayout retargeted to the canyon clearing (machine at origin, overshot wheel)"
```

---

## Task 2: Overshot waterwheel builder

**Files:** Modify `roblox/tools/builders/Waterwheel.luau`; Test `roblox/tests/Waterwheel.spec.luau`.

The wheel currently stands supports down to a submerged creek bed and a launder carries scoop-lifted water *from* the top *to* the sōzu (undershot). Convert to overshot: supports rise from the clearing floor (`bedY`) to the hub; add a **headrace flume** from `headFrom` (taps the in-fall) to `headTo` (the wheel top). Keep the wheel/paddle/axle/RatchetDrum geometry (the controller spins it unchanged).

- [ ] **Step 1: Write the failing test.** Create/extend `roblox/tests/Waterwheel.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local Waterwheel = require("../tools/builders/Waterwheel")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Waterwheel (overshot)", function()
    test("emits a Headrace flume part feeding the wheel top", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do names[c.name] = true end
        expect(names["Headrace"]).toBe(true)
        expect(names["Wheel1"]).toBe(true)
    end)
    test("support posts reach the clearing floor, not a submerged bed", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Support") then
                -- support spans hub-ish down to bedY (clearing floor); its bottom ≈ bedY
                local cy = c.properties.CFrame[2]; local h = c.properties.Size[2]
                expect(cy - h / 2 <= L.waterwheel.bedY + 1).toBe(true)
            end
        end
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run` → FAIL (`Headrace` not found).

- [ ] **Step 3: Implement overshot.** In `Waterwheel.luau`, the supports already span `postTop` down to `W.bedY` — with `bedY = clearing floor` (Task 1) they now correctly reach the floor; no change needed there. Replace the launder block (lines ~94-105, the `-- launder (open trough) ...` through the `Launder` insert) with a **headrace flume feeding the top** plus the small sōzu bleed:

```lua
    -- OVERSHOT: headrace flume taps the in-fall and pours onto the wheel TOP.
    if W.overshot and W.headFrom and W.headTo then
        local hpos, hlen, hrot = Spec.segment(W.headFrom, W.headTo)
        table.insert(children, Spec.part("Headrace", {
            Size = { hlen, 0.5, 1.6 }, CFrame = Spec.cframe(hpos, hrot),
            Color = timber, Material = "Wood",
        }))
    end
    -- small bleed trough from the wheel top to the sōzu mouth (unchanged role)
    local ltop = { dc[1], dc[2] + R, dc[3] }
    local lpos, llen, lrot = Spec.segment(ltop, W.launderTo)
    table.insert(children, Spec.part("Launder", {
        Size = { llen, 0.4, 0.9 }, CFrame = Spec.cframe(lpos, lrot),
        Color = timber, Material = "Wood",
    }))
```

(The existing `RatchetDrum` insert stays above this. The supports loop already uses `W.bedY` — verify it reads the new floor value.)

- [ ] **Step 4: Run tests to verify pass.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run` → PASS.

- [ ] **Step 5: Regenerate + gate.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && stylua --check src tests tools && selene src && rojo build -o /tmp/b.rbxl` → all green; `assets/Waterwheel.model.json` regenerated.

- [ ] **Step 6: Commit.**
```bash
git add roblox/tools/builders/Waterwheel.luau roblox/tests/Waterwheel.spec.luau roblox/assets/Waterwheel.model.json
git commit -m "feat(roblox): overshot waterwheel — headrace flume feeds the top, supports to the floor"
```

---

## Task 3: WheelController — overshot spin direction

**Files:** Modify `roblox/src/client/WheelController.client.luau`.

The controller spins `angle -= dt*0.9` (undershot: submerged bottom paddles pushed toward centre). Overshot loads water on the **top, head-side**, so the wheel turns the **opposite** way. Flip the sign and remove the undershot foam attachment (overshot sheets off the buckets instead).

- [ ] **Step 1: Read the file** to confirm the current spin line and the foam `ParticleEmitter` block (`WheelController.client.luau:30-61`).

- [ ] **Step 2: Flip the spin sign.** Change the heartbeat spin from `angle -= dt * 0.9` to `angle += dt * 0.9` and update the comment to explain overshot (top-loaded, head-side descends).

- [ ] **Step 3: Re-aim the foam.** Move the foam `ParticleEmitter` attachment from the wheel's waterline (`-driver.Size.Y/2 + 0.4`) to the wheel **bottom** where water sheets off (`-driver.Size.Y/2`), and lower its `Rate` (overshot drip, not a churning waterline). If simpler, leave the emitter but reposition the attachment.

- [ ] **Step 4: Verify live (MCP, main session).** Restart `rojo serve` is not needed (existing node). In Studio Play (or Run), confirm the wheel turns with the head/top side descending (water-driven look). Capture a screenshot from the clearing.

- [ ] **Step 5: Gate + commit.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && stylua --check src tests tools && selene src && rojo build -o /tmp/b.rbxl`
```bash
git add roblox/src/client/WheelController.client.luau
git commit -m "fix(roblox): WheelController spin direction for overshot wheel"
```

---

## Task 4: Terrain — level the clearing shelf + carve pool/river/boundary-fall (MCP)

**Files:** Create `roblox/tools/studio/buildClearing.luau` (MCP-run; committed as source, not Rojo-synced).

Level the clearing into a gentle-grade shelf and carve the water basins, on the **imported canyon terrain** (do not rebuild the whole gorge). This is an MCP `execute_luau` WriteVoxels op over the clearing region only. **No Lune test** — verified at the terrain gate.

- [ ] **Step 1: Write the script.** Create `roblox/tools/studio/buildClearing.luau` that, over the clearing region (world x∈[−70,140], z∈[−45,45]):
  - Sets the ground surface to a gentle grade around `floorY=112` (e.g. lerp 114→110 head→downstream), leaving the surrounding gorge walls (outside the region / above a Z/▽ threshold) untouched.
  - Carves the **plunge pool** basin (centre ≈(−34,0), half 28): floor ~`104`, water surface `110`.
  - Carves a shallow **river channel** meandering from the pool (z≈−10) downstream to the boundary, water ~1 below grade.
  - Drops the **boundary lip** at x≈124 so the river falls away to the lower gorge.
  - Fills basins with `Water`; uses fractional occupancy (the `occFor` pattern from `buildTerrain.luau`) so waterlines sit between voxel rows. Mirror the structure of `tools/studio/buildTerrain.luau` (RES=4, tiled WriteVoxels, `return` a summary string).

- [ ] **Step 2: Run it in Studio (MCP, main session).** Edit datamodel, Play stopped. Paste the full script via `execute_luau` (datamodel_type `"Edit"`). Expected: returns a summary (e.g. `"clearing leveled (N tiles)"`), no error.

- [ ] **Step 3: Probe to verify.** Via `execute_luau`, raycast a grid across the clearing: confirm the shelf grade is gentle (≤ a few studs over the outcrop), the pool holds continuous water at ~110, and the boundary lip drops away. Report the probe.

- [ ] **Step 4: TERRAIN GATE (USER).** Capture screenshots from the outcrop and from above; confirm with the user the clearing reads as a believable gentle gathering shelf with continuous pool/river water and a boundary drop. Tune levels and re-run until signed off. **Do not commit until the user signs off.**

- [ ] **Step 5: Commit the script.**
```bash
git add roblox/tools/studio/buildClearing.luau
git commit -m "feat(roblox): clearing terrain — leveled shelf + plunge pool + river + boundary lip (MCP)"
```

---

## Task 5: Re-stage the machine + re-aim controllers (MCP/live)

**Files:** `roblox/src/client/HammerController.client.luau`, `SozuController.client.luau`, `DrumController.client.luau` (modify); verify `BonshoRig`/`Shoro`/`ThrowDrum`/`Sozu` assets land correctly via the Task-1 coordinates.

The builders now emit at clearing coordinates (Task 1 regen). The controllers hold **inlined mirrors** of ArenaLayout constants — update each to the new positions. Behavior/feel is preserved; only positions/headings change.

- [ ] **Step 1: Regenerate + sync.** `cd roblox && export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels`. The new project.json has no new nodes, but the machine assets moved — confirm in Studio the `BonshoRig`/`Shoro`/`ThrowDrum`/`Sozu`/`Waterwheel` models now sit in the clearing (Rojo synced; reconnect if needed). Delete the throwaway `workspace.ClearingGreybox` via `execute_luau`.

- [ ] **Step 2: HammerController re-aim.** Read `HammerController.client.luau`; it swings the shu-moku relative offsets from its rest CFrame and reads inlined `shuMoku`/bell constants. Update those inlined constants to the Task-1 `shuMoku`/`bell` values (rest pos, chain tops/bottoms, rope anchor, strike target = bell SW→ now bell centre face). Preserve the swing/recoil offset *vectors* (the approved feel); only the rest pose + strike target move.

- [ ] **Step 3: SozuController re-target.** Read `SozuController.client.luau`; update the inlined `cordTop` and lever rest to the Task-1 `sozu` values (`cordTop = {-2,138,-2}` = drum axle end; pivot `{-8,116,8}`). Fill/dump behavior unchanged.

- [ ] **Step 4: DrumController verify.** Read `DrumController.client.luau`; confirm it captures the drum part by name and animates relative to its own CFrame (no world-coordinate assumptions). If it reads any inlined position, update to `throwDrum.pos`. Behavior unchanged.

- [ ] **Step 5: MACHINE GATE (USER) — live round.** In Studio Play, run a round (or drive cues): verify drum spins during ACTIVE → sōzu clacks at lockout → drum reveals → bell gongs at reveal → (boards flip, Task 6). Confirm the overshot wheel reads water-driven, the hammer strikes the bell true on the clearing axis, and the bell is visible from a sample teahouse-perch camera up-canyon. Capture screenshots. Tune until signed off.

- [ ] **Step 6: Commit.**
```bash
git add roblox/src/client/HammerController.client.luau roblox/src/client/SozuController.client.luau roblox/src/client/DrumController.client.luau roblox/assets/*.model.json
git commit -m "feat(roblox): re-stage the throw machine in the clearing; re-aim hammer/sozu/drum controllers"
```

---

## Task 6: Flip-boards — two clearing-local kōsatsu

**Files:** Modify `roblox/src/client/BoardController.client.luau` (and the board renderer it uses); coordinates from `ArenaLayout` (add a `boards` field).

Replace the single large board with **two human-scale kōsatsu** flanking the machine, facing the outcrop, sized for nearby reading only.

- [ ] **Step 1: Add board coordinates.** In `ArenaLayout.luau` add:
```lua
    boards = {
        { pos = { 6, 116, -13 }, yaw = 200, size = { 10, 7, 0.8 } },
        { pos = { 6, 116, 13 }, yaw = 160, size = { 10, 7, 0.8 } },
    },
```
Add a quick `ArenaLayout.spec` assertion: `expect(#L.boards).toBe(2)`. Run tests → green.

- [ ] **Step 2: Read `BoardController.client.luau`** and the board/flap renderer (`FlapScheduler` is in `shared`). Determine how the single board surface is created and rendered.

- [ ] **Step 3: Build two boards.** Refactor the controller to instantiate **two** board surfaces at `ArenaLayout.boards[i]` positions/sizes, each running the same flap render. Keep the render scheduling; only the count/placement/size change. Human-scale (≈10×7 studs) so it reads at the outcrop, not the perches.

- [ ] **Step 4: Verify live (MCP).** In Studio, confirm two boards flank the machine, face the outcrop, and flip on reveal. Capture a screenshot from the outcrop.

- [ ] **Step 5: Gate + commit.** `stylua`/`selene`/`rojo build` green.
```bash
git add roblox/src/client/BoardController.client.luau roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): two clearing-local flip-boards flanking the machine"
```

---

## Task 7: Fall & mist VFX (in-fall + boundary fall)

**Files:** Create `roblox/src/client/FallVfx.client.luau`.

Add the in-fall and boundary-fall water sheets + mist (terrain water can't render a vertical sheet on steep/mesh terrain). A client controller builds them at `ArenaLayout.clearing` coordinates.

- [ ] **Step 1: Write the controller.** `FallVfx.client.luau` creates, at the in-fall (`clearing.poolCentre` upstream edge, top `clearing.inFallTopY`) and the boundary fall (`clearing.boundaryX`, `clearing.boundaryLipY`):
  - a translucent **water-sheet** part (thin, tall, `Glass`/`Water`-toned, low transparency),
  - a `Beam` or stacked `ParticleEmitter`s for falling streaks (white, downward `Acceleration`),
  - a base **mist** `ParticleEmitter` (LightInfluence low, slow, fading) at the plunge point.
  Read the coords from `ReplicatedStorage.RoshamboShared` ArenaLayout mirror or inline the `clearing` constants (keep-in-sync comment).

- [ ] **Step 2: Verify live (MCP).** Confirm both falls read as water with mist at the base; the in-fall lands in the pool, the boundary fall spills off the lip. Screenshot at dusk.

- [ ] **Step 3: Gate + commit.** `stylua`/`selene`/`rojo build` green.
```bash
git add roblox/src/client/FallVfx.client.luau roblox/default.project.json
git commit -m "feat(roblox): in-fall + boundary-fall water sheets and mist VFX"
```

(If `FallVfx` needs a new client script node, it's under `src/client` which is already a `$path` — no project.json change; drop the project.json from the add if unchanged.)

---

## Task 8: Outcrop finish + spawn points

**Files:** Modify `roblox/src/server/main.server.luau` (spawn cluster); `ArenaLayout.luau` (spawn points).

Reserve clustered spawn pads on the outcrop and confirm clearing stage models are Persistent.

- [ ] **Step 1: Add spawn points.** In `ArenaLayout.luau` add `clearing.spawns = { {x,z}, ... }` — ~5 points spread across the outcrop (`outcropCentre` ± spread). Test: `expect(#L.clearing.spawns >= 4).toBe(true)`. Run tests → green.

- [ ] **Step 2: Place SpawnLocations.** In `main.server.luau` (which already loops stage models for Persistent streaming), add a loop creating an anchored `SpawnLocation` (Neutral) at each `clearing.spawns` point on the outcrop floor (`clearing.floorY`). Confirm the existing Persistent-streaming loop covers the new clearing machine models.

- [ ] **Step 3: Verify live (MCP).** Play: spawn lands on the outcrop facing the machine; multiple pads spread arrivals. Screenshot.

- [ ] **Step 4: Gate + commit.** `stylua`/`selene`/`lune run tests/run`/`rojo build` green.
```bash
git add roblox/src/server/main.server.luau roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): clearing spawn cluster on the outcrop + persistent staging"
```

---

## Task 9: USER GATE — full clearing live

**Files:** none (verification + tuning only).

- [ ] **Step 1: Bring it all together.** Ensure `rojo serve` is current (restart if any new node was added), Studio reconnected, terrain rebuilt (`buildClearing.luau` via MCP), greybox removed.
- [ ] **Step 2: Verify against the spec done-criteria.** From the outcrop and from a sample perch camera: leveled gathering shelf; continuous pool/river/boundary water; centred machine with overshot wheel reading water-driven; a full round plays out (spin → clack → reveal → gong → two boards flip); bell visible up-canyon; falls + mist reading; spawns on the outcrop. Capture a dusk hero shot.
- [ ] **Step 3: Tune** (levels, positions, VFX, lighting) with the user until signed off, then commit any tuning. **Hold commits until sign-off.**

---

## Self-Review (plan author)

**Spec coverage:** §2 staging → Tasks 1,4,5. §3 terrain leveling → Task 4. §4 water (pool/in-fall/boundary) → Tasks 4,7. §5 machine ported & re-staged + overshot → Tasks 1,2,3,5. flip-boards → Task 6. §6 outcrop/spawns → Task 8. §7 components → Tasks 1–8. §8 risks (feel preserved, sync, overshot, visibility, legibility) → carried in Tasks 3,5 + gates. §9 testing → Lune specs (Tasks 1,2,6,8) + MCP gates (Tasks 4,5,9). §10 sequence → Tasks 1–9 in order. ✓ no gaps.

**Placeholder scan:** Terrain (Task 4) and VFX (Task 7) describe MCP scripts rather than full literal code — intentional and consistent with the project's MCP-built terrain (buildTerrain.luau is authored live and tuned at gates); concrete region bounds, target levels, and the `occFor`/tiled-WriteVoxels pattern to mirror are given. Controller-retarget tasks (3,5,6) instruct read-then-edit because the controllers hold inlined constants that must be updated to the Task-1 values — the *values* are specified; the implementer matches them to each file's existing constant names.

**Type/name consistency:** `clearing.{floorY,poolCentre,poolHalf,poolSurfaceY,outcropCentre,outcropHalf,boundaryX,boundaryLipY,inFallTopY,spawns}`, `waterwheel.{overshot,headFrom,headTo,bedY,centers,radius}`, `boards[]`, machine fields (`bell`,`pavilion`,`throwDrum`,`shuMoku`,`sozu`) used identically across Tasks 1–8. Builder part name `Headrace` matches between Task 2 builder and its test.
