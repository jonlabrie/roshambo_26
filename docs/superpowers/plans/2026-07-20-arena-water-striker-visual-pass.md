# Arena "Water Striker" Centerpiece Visual Pass — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise the Arena centerpiece (bonshō bell, shōrō tower + hip roof, throw drum, waterwheel, drive-chain) from placeholder box geometry to hero-quality art matching the user's weathered-shōrō reference, without breaking the signed-off working mechanism.

**Architecture:** The centerpiece geometry is procedural: builder modules in `roblox/tools/builders/` emit committed `roblox/assets/*.model.json` via `lune run tools/genmodels`, which Rojo syncs into `Workspace.RoshamboStage`. The art pass rewrites those builders, extends the emit vocabulary (`Spec.meshPart`) to reference uploaded MeshPart assets, adds a weathered palette to `ZenDojo.luau`, and creates place-state MaterialVariants in MaterialService (the established `ZenGravel1`/`ZenCement2` pattern). Hero organic forms (bell, ryūzu, hip roof, cam, gears, wheel) become generated meshes; structural timber stays primitives.

**Tech Stack:** Luau (builders + Lune tests via bespoke `tests/harness`), Rojo (`default.project.json`), Roblox Studio MCP (`execute_luau`, `generate_mesh`/`generate_procedural_model`, `screen_capture`, `inspect_instance`), MaterialVariants (place-state).

## Global Constraints

- **Mechanism contract — never rename or move these animated parts** (controllers `WaitForChild`/pattern-match them by name and capture their CFrame at init):
  - `BonshoRig`: `Bonsho` (invisible strike proxy, `Transparency=1`, `CanCollide=false`), `ShuMoku`, `ShuMokuDrawDowel`, `ShuMokuDowel`, `Chain1`–`Chain4`.
  - `ThrowDrum`: `Drum` (invisible hub), `Face0`–`Face5`, `Spoke1`–`Spoke12`.
  - `Waterwheel`: `Wheel1`, `Paddle1_1`–`Paddle1_8` (the ONLY parts WheelController spins; all other wheel parts are static), `RatchetDrum`.
  - `BellDrive`: at least one part whose name starts with `Cam` (HammerController spins every `^Cam` part about the cam shaft), plus `CamShaft`, `CamGear`, `DriverGear`, `MainShaft`, `VertShaft`, `VertPaddle`, `DriveGearA`, `DriveGearB`, `DrivePaddle`, `DriveGearBShaft`, `DrumYoke1`–`DrumYoke4`, `DrumBearing1`–`DrumBearing2`, `BearingPost1`–`4`, `BearingSaddle1`–`4`.
  - A replacement mesh MUST sit at the SAME `CFrame`/position as the primitive it replaces (controllers rotate about fixed world axle lines through `part.Position`).
- **Byte-determinism** ([[roblox-genmodels-arch-portability]]): `lune run tools/genmodels` output must be identical arm64≡x86_64. MeshIds are static string literals (safe). Any NEW procedural math must round in `JsonEmit` (it snaps `|v|<1e-9`→0 and integer-formats whole numbers); do not feed transcendental residues into hashes/seeds.
- **Rojo ownership** ([[roblox-rojo-vs-place-state]]): `RoshamboStage` is Rojo-managed — never hand-add geometry in Studio (wiped on `rojo build`). MaterialVariant *definitions* are place-state (save/publish the place); builders only set the `MaterialVariant` string property.
- **Palette values are floats 0..1** (matching `ZenDojo.palette`), and are STARTING values — final look is tuned at live Studio gates.
- **Visual sign-off is manual** at live Studio staging gates via MCP `screen_capture`: make ONE attempt, then STOP and ask the user to look ([[stop-and-ask-after-each-attempt]]). Do not self-judge and iterate unprompted.
- **Green bars before every commit:** `lune run tests/run` (0 failed), `stylua` formatted, `selene src` clean.
- **Mesh generation fallback:** if MCP mesh generation is unavailable or the result is unusable, each mesh task specifies a refined-primitive fallback so no task dead-ends.
- **Mesh asset IDs are produced values, not placeholders:** a mesh step generates + uploads an asset and records the returned `rbxassetid://…` into a named constant in the builder's `ASSETS` table. "Paste the uploaded id" is a concrete data-capture step.
- **Commit trailers** (every commit):
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Vf1gZydECjVW7ot94YH3ho
  ```

## File Structure

| File | Responsibility | Tasks |
|---|---|---|
| `roblox/tools/builders/Spec.luau` | Add `Spec.meshPart` emit helper | 1 |
| `roblox/tests/Spec.spec.luau` | Test `Spec.meshPart` shape | 1 |
| `roblox/src/shared/themes/ZenDojo.luau` | New weathered palette entries | 1 |
| `roblox/tests/CenterpieceContract.spec.luau` | NEW — lock every animated part name across all 5 builders | 1 |
| `roblox/tools/studio/setupCenterpieceMaterials.luau` | NEW — reproducible MaterialVariant creation (place-state) | 2 |
| `roblox/tools/builders/Bonsho.luau` + `tests/Bonsho.spec.luau` | Cast bell mesh, ryūzu, tsuki-za, patina | 3 |
| `roblox/tools/builders/Shoro.luau` + `tests/Shoro.spec.luau` | Weathered posts/beams, tokyō brackets, rafters | 4 |
| `roblox/tools/builders/Shoro.luau` (roof), `ArenaLayout.luau`, `tests/Shoro.spec.luau`, `tests/ArenaLayout.spec.luau` | Hip-roof mesh + raise drum (coupled linkage) | 5 |
| `roblox/tools/builders/ThrowDrum.luau` + `tests/ThrowDrum.spec.luau` | Iron bands, hub, face/yoke dressing | 6 |
| `roblox/tools/builders/Waterwheel.luau` + `tests/Waterwheel.spec.luau` | Mill-wheel mesh, buckets, wet paddles | 7 |
| `roblox/tools/builders/BellDrive.luau` + `tests/BellDrive.spec.luau` | Cam mesh, toothed gears, timber shafts | 8 |
| memories + `finishing-a-development-branch` | Composite gate + wrap | 9 |

Each builder edit is followed by `lune run tools/genmodels` (regenerates `assets/*.model.json`) and a Rojo re-sync so Studio shows the change.

---

### Task 1: Pipeline groundwork (mesh vocabulary, palette, contract lock)

Pure-code task, no meshes or place changes yet. Establishes the tools every later task needs and **locks the mechanism contract before any art edit**.

**Files:**
- Modify: `roblox/tools/builders/Spec.luau`
- Modify: `roblox/tests/Spec.spec.luau`
- Modify: `roblox/src/shared/themes/ZenDojo.luau`
- Create: `roblox/tests/CenterpieceContract.spec.luau`

**Interfaces:**
- Produces: `Spec.meshPart(name: string, props: {[string]:any}) -> Spec.PartSpec` — emits `className="MeshPart"`, forces `Anchored=true` and `TextureID=""`, passes through `MeshId`, `Size`, `CFrame`, `Color`, `Material`, `MaterialVariant`, `Transparency`, `CanCollide`, and a `children` list. Same mutation-safety contract as `Spec.part`.
- Produces: `ZenDojo.palette.cypressWeathered`, `.bronzePatina`, `.slateTile`, `.ironDark`, `.paddleWet` (each `{r,g,b}` floats).

- [ ] **Step 1: Write the failing test for `Spec.meshPart`**

Append to `roblox/tests/Spec.spec.luau`:
```lua
describe("Spec.meshPart", function()
    test("emits a MeshPart node with MeshId and cleared TextureID", function()
        local m = Spec.meshPart("BellBody", {
            MeshId = "rbxassetid://123",
            Size = { 10, 13, 10 },
            CFrame = Spec.cframe({ -2, 121, 0 }),
            Material = "Metal",
            MaterialVariant = "BronzePatina",
        })
        expect(m.className).toBe("MeshPart")
        expect(m.name).toBe("BellBody")
        expect(m.properties.MeshId).toBe("rbxassetid://123")
        expect(m.properties.TextureID).toBe("")
        expect(m.properties.Anchored).toBe(true)
        expect(m.properties.MaterialVariant).toBe("BronzePatina")
    end)
    test("does not mutate the caller's props table", function()
        local props: { [string]: any } = { MeshId = "rbxassetid://1", Size = { 1, 1, 1 } }
        Spec.meshPart("A", props)
        expect(props.TextureID).toBeNil()
    end)
end)
```

- [ ] **Step 2: Run it, verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: `FAIL  Spec.meshPart > …` with an error like `attempt to call a nil value (field 'meshPart')`.

- [ ] **Step 3: Implement `Spec.meshPart`**

In `roblox/tools/builders/Spec.luau`, after `Spec.part` (before `Spec.model`):
```lua
function Spec.meshPart(name: string, props: { [string]: any }): PartSpec
    local kids = props.children
    local properties: { [string]: any } = { Anchored = true, TextureID = "" }
    for k, v in props do
        if k ~= "children" then
            properties[k] = v
        end
    end
    return { name = name, className = "MeshPart", properties = properties, children = kids }
end
```

- [ ] **Step 4: Run it, verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: the two `Spec.meshPart` tests pass; summary line shows the same failed-count as before this task minus these (i.e. `0 failed`).

- [ ] **Step 5: Add palette entries**

In `roblox/src/shared/themes/ZenDojo.luau`, inside `palette = { … }`, add after `timber`:
```lua
        -- weathered temple palette (2026-07-20 Water Striker art pass; starting values)
        cypressWeathered = { 0.56, 0.55, 0.51 }, -- sun-bleached aged hinoki posts/beams/brackets
        bronzePatina = { 0.18, 0.25, 0.22 }, -- dark verdigris green-black bell
        slateTile = { 0.13, 0.14, 0.16 }, -- near-black hip-roof tile
        ironDark = { 0.16, 0.16, 0.18 }, -- hoop bands, collars, chains, gears
        paddleWet = { 0.34, 0.35, 0.33 }, -- darkened wet lower paddles
```

- [ ] **Step 6: Write the contract-lock test (the key safety net)**

Create `roblox/tests/CenterpieceContract.spec.luau`:
```lua
--!strict
-- Locks every animated part name the client controllers depend on, across all five
-- centerpiece builders, BEFORE the art pass edits them. If an art edit renames or
-- drops an animated part, this fails — catching a silently-broken mechanism at CI
-- instead of in-world. Names sourced from HammerController/DrumController/WheelController.
local harness = require("./harness")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local Bonsho = require("../tools/builders/Bonsho")
local Shoro = require("../tools/builders/Shoro")
local Waterwheel = require("../tools/builders/Waterwheel")
local ThrowDrum = require("../tools/builders/ThrowDrum")
local BellDrive = require("../tools/builders/BellDrive")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function nameSet(spec: any): { [string]: boolean }
    local names = {}
    for _, c in spec.children :: any do
        names[c.name] = true
    end
    return names
end

local function requireAll(names: { [string]: boolean }, required: { string })
    for _, r in required do
        expect(names[r]).toBe(true)
    end
end

local function countMatching(spec: any, pat: string): number
    local n = 0
    for _, c in spec.children :: any do
        if (c.name :: string):match(pat) then
            n += 1
        end
    end
    return n
end

describe("centerpiece mechanism contract", function()
    test("BonshoRig keeps the striker/bell/chain parts", function()
        local names = nameSet(Bonsho.build(ZenDojo.palette, L))
        requireAll(names, {
            "Bonsho", "ShuMoku", "ShuMokuDrawDowel", "ShuMokuDowel",
            "Chain1", "Chain2", "Chain3", "Chain4",
        })
    end)
    test("ThrowDrum keeps the hub, 6 faces, and 12 spokes", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local names = nameSet(spec)
        requireAll(names, { "Drum", "Face0", "Face1", "Face2", "Face3", "Face4", "Face5" })
        expect(countMatching(spec, "^Spoke%d+$")).toBe(12)
    end)
    test("Waterwheel keeps Wheel1, its 8 paddles, and the ratchet", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local names = nameSet(spec)
        requireAll(names, { "Wheel1", "RatchetDrum" })
        expect(countMatching(spec, "^Paddle1_%d+$")).toBe(8)
    end)
    test("BellDrive keeps a Cam part plus the shafts/gears/yokes", function()
        local spec = BellDrive.build(ZenDojo.palette, L)
        local names = nameSet(spec)
        requireAll(names, {
            "CamShaft", "CamGear", "DriverGear", "MainShaft", "VertShaft", "VertPaddle",
            "DriveGearA", "DriveGearB", "DrivePaddle", "DriveGearBShaft",
            "DrumYoke1", "DrumYoke2", "DrumYoke3", "DrumYoke4", "DrumBearing1", "DrumBearing2",
        })
        expect(countMatching(spec, "^Cam") >= 1).toBe(true)
    end)
    test("Shoro still builds a model (no contract parts, art may change freely)", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        expect(spec.className).toBe("Model")
    end)
end)
```

- [ ] **Step 7: Run the full suite — contract test must PASS against the current (pre-art) builders**

Run: `cd roblox && lune run tests/run`
Expected: `0 failed`. (If any contract assertion fails now, the contract names above are wrong — fix the test to match the current builders before proceeding; do NOT change builders in this task.)

- [ ] **Step 8: Format, lint, commit**

```bash
cd roblox && stylua tools/builders/Spec.luau tests/Spec.spec.luau tests/CenterpieceContract.spec.luau src/shared/themes/ZenDojo.luau && selene src
git add roblox/tools/builders/Spec.luau roblox/tests/Spec.spec.luau roblox/tests/CenterpieceContract.spec.luau roblox/src/shared/themes/ZenDojo.luau
git commit  # message: "feat(roblox): centerpiece art-pass groundwork — Spec.meshPart, weathered palette, contract-lock test"
```

---

### Task 2: MaterialVariant setup (place-state)

Creates the five weathered MaterialVariants in MaterialService and saves them with the place. This is place-state (not Rojo/CI), captured in a reproducible committed script. **No Lune test** — verification is a live Studio check.

**Files:**
- Create: `roblox/tools/studio/setupCenterpieceMaterials.luau`

**Interfaces:**
- Produces (in the place's `MaterialService`): MaterialVariants named `CypressWeathered` (base `Wood`), `BronzePatina` (base `Metal`), `SlateTile` (base `Slate`), `IronDark` (base `Metal`), `MossyPaddle` (base `Wood`). Builders reference these by the `MaterialVariant` string.

- [ ] **Step 1: Write the reproducible setup script**

Create `roblox/tools/studio/setupCenterpieceMaterials.luau` (run once via the MCP command bar / Studio; idempotent — reuses an existing variant of the same name):
```lua
--!strict
-- Creates the Water Striker art-pass MaterialVariants in MaterialService (place-state;
-- SAVE/PUBLISH the place after running). Base materials chosen so the world-space PBR
-- reads as weathered temple. TextureIDs are set by the art pass once maps are uploaded
-- (generate_material / ambientCG upload); StudsPerTile starting values below.
local MaterialService = game:GetService("MaterialService")

local SPECS = {
    { name = "CypressWeathered", base = Enum.Material.Wood, tile = 3.0 },
    { name = "BronzePatina", base = Enum.Material.Metal, tile = 2.0 },
    { name = "SlateTile", base = Enum.Material.Slate, tile = 1.5 },
    { name = "IronDark", base = Enum.Material.Metal, tile = 2.0 },
    { name = "MossyPaddle", base = Enum.Material.Wood, tile = 2.0 },
}

for _, s in SPECS do
    local mv = MaterialService:FindFirstChild(s.name)
    if not mv then
        mv = Instance.new("MaterialVariant")
        mv.Name = s.name
        mv.Parent = MaterialService
    end
    mv.BaseMaterial = s.base
    mv.StudsPerTile = s.tile
    -- MaterialPattern MUST be Regular for parts (Organic is terrain-only) — see
    -- [[roblox-mossy-terrain-pbr]]; texture maps assigned by the art pass.
end
return "materials ready"
```

- [ ] **Step 2: Run it in Studio (Edit datamodel) via MCP**

Use `mcp__Roblox_Studio__execute_luau` (datamodel `Edit`) with the script body; expect return `"materials ready"`. Then `inspect_instance` on `MaterialService` to confirm the five variants exist.

- [ ] **Step 3: Generate/assign texture maps for each variant**

For each variant, generate a tiling PBR map via `mcp__Roblox_Studio__generate_material` (or upload ambientCG maps via the localhost upload flow per [[roblox-mossy-terrain-pbr]]) and assign `ColorMap`/`NormalMap`/`MetalnessMap`/`RoughnessMap` on the variant. Aim: `CypressWeathered` = gray weathered plank grain; `BronzePatina` = mottled verdigris; `SlateTile` = dark tile; `IronDark` = dark hammered metal; `MossyPaddle` = wet mossy wood.

- [ ] **Step 4: Live verification (staging gate — STOP and ask)**

Temporarily set a scratch Part in `Workspace` to each `Material=base` + `MaterialVariant=<name>`; `screen_capture` a close view; confirm each variant reads as intended. Delete the scratch part. Make ONE pass, then STOP and show the user the captures for sign-off before continuing.

- [ ] **Step 5: Save the place + commit the script**

Ask the user to save/publish the place (place-state persistence). Then:
```bash
git add roblox/tools/studio/setupCenterpieceMaterials.luau
git commit  # "chore(roblox): reproducible MaterialVariant setup for the centerpiece art pass"
```

---

### Task 3: Bonshō bell — cast body, ryūzu crown, tsuki-za, patina (the money shot)

**Files:**
- Modify: `roblox/tools/builders/Bonsho.luau`
- Modify: `roblox/tests/Bonsho.spec.luau`

**Interfaces:**
- Consumes: `Spec.meshPart` (Task 1), `ZenDojo.palette.bronzePatina`/`.ironDark` (Task 1), `BronzePatina` variant (Task 2).
- Produces: `BonshoRig` emits `BellBody` (MeshPart), `Ryuzu` (MeshPart), `LotusBoss` (mesh or disc), plus the unchanged contract parts. `BellSection1-5`, `BellDome`, `CrownLug` are REMOVED (no controller references them; `BellHanger` math uses computed `crownTopY`, not the part).

- [ ] **Step 1: Generate + vet the three bell meshes (MCP)**

- `BellBody`: `mcp__Roblox_Studio__generate_mesh` (or `generate_procedural_model`) prompt: "Japanese bonshō temple bell, surface of revolution: near-vertical flank flaring slightly to the mouth, rounded kasagata shoulder, flat top; four raised horizontal obi bands dividing the body into panels; two rows of chi studs (nipples) around the shoulder; hollow open bottom; low-to-moderate poly for mobile." Target ≤ ~4k tris.
- `Ryuzu`: prompt: "small stylized twin-dragon bell crown loop (ryūzu), a single arched handle with paired dragon-head ends, compact, low poly." Target ≤ ~1.5k tris.
- `LotusBoss`: prompt: "shallow lotus-flower relief disc (tsuki-za bell striking boss), round, thin, radial petals, low poly." Target ≤ ~800 tris. (Fallback: keep a `Cylinder` primitive disc as today.)

Vet each (no backdoors — these are generated, not imported), upload, and record the returned asset ids.

- [ ] **Step 2: Add an `ASSETS` table and record the uploaded ids**

At the top of `roblox/tools/builders/Bonsho.luau`, after the `local Bonsho = {}` line:
```lua
-- Uploaded mesh assets for the 2026-07-20 art pass (generated via Studio MCP; provenance:
-- generate_mesh, no third-party import). Fill each with the rbxassetid returned at upload.
local ASSETS = {
    bellBody = "rbxassetid://0", -- ← paste uploaded BellBody id
    ryuzu = "rbxassetid://0", -- ← paste uploaded Ryuzu id
    lotusBoss = "rbxassetid://0", -- ← paste uploaded LotusBoss id (or leave 0 to keep the primitive fallback)
}
```

- [ ] **Step 3: Update the failing tests first**

In `roblox/tests/Bonsho.spec.luau`, DELETE the `"bell sections widen toward the skirt"` test (BellSection parts are gone) and add:
```lua
    test("emits a bronze BellBody mesh at the bell centre (no stacked sections)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local names = {}
        local body
        for _, c in spec.children :: any do
            names[c.name] = true
            if c.name == "BellBody" then
                body = c
            end
        end
        expect(names["BellSection1"]).toBeNil()
        expect(body).toBeTruthy()
        expect(body.className).toBe("MeshPart")
        expect(body.properties.CFrame[1]).toBeCloseTo(L.bell.pos[1], 0.001)
        expect(body.properties.CFrame[2]).toBeCloseTo(L.bell.pos[2], 0.001)
        expect(body.properties.MaterialVariant).toBe("BronzePatina")
    end)
    test("emits a Ryuzu crown above the bell", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "Ryuzu" then
                expect(c.properties.CFrame[2] > L.bell.pos[2]).toBe(true)
                return
            end
        end
        error("no Ryuzu emitted")
    end)
```

- [ ] **Step 4: Run tests, verify the new ones fail**

Run: `cd roblox && lune run tests/run`
Expected: `FAIL` on the two new Bonsho tests (BellBody/Ryuzu not emitted yet). CenterpieceContract still passes.

- [ ] **Step 5: Rewrite the bell body in `Bonsho.luau`**

Replace the `profile`/`sectionH`/BellSection loop AND the `BellDome` block AND the `CrownLug` block with:
```lua
    -- Cast bonshō body: one mesh spanning the full bell envelope (height h, radius r),
    -- centred at the layout bell position. Patina via the BronzePatina variant.
    table.insert(
        children,
        Spec.meshPart("BellBody", {
            MeshId = ASSETS.bellBody,
            Size = { 2 * r, h, 2 * r },
            CFrame = Spec.cframe({ bx, by, bz }),
            Color = bronze,
            Material = "Metal",
            MaterialVariant = "BronzePatina",
        })
    )
    -- Ryūzu crown loop the bell hangs from, seated on the bell top.
    table.insert(
        children,
        Spec.meshPart("Ryuzu", {
            MeshId = ASSETS.ryuzu,
            Size = { 2.2, 2.4, 1.4 },
            CFrame = Spec.cframe({ bx, by + h / 2 + 1.1, bz }),
            Color = bronze,
            Material = "Metal",
            MaterialVariant = "BronzePatina",
        })
    )
```
Keep the existing `bronze` local, `bx/by/bz`, `h`, `r`. Keep `BellHanger` unchanged (its `crownTopY = by + h/2 + 1.9` still lands just above the ryūzu). Keep the invisible `Bonsho` proxy, `ShuMoku`, both dowels, `Chain1-4`, gantry, rails, posts, braces UNCHANGED.

- [ ] **Step 6: Upgrade the `LotusBoss` (tsuki-za)**

Replace the existing `LotusBoss` `Spec.part(... Shape="Cylinder" ...)` block with a mesh when an id is present, else keep the disc:
```lua
    local bossProps: { [string]: any } = {
        Size = { 1.8, 1.8, 0.6 },
        CFrame = Spec.cframe(bossPos, bossRot),
        Color = palette.gold,
        Material = "Metal",
        MaterialVariant = "BronzePatina",
    }
    if ASSETS.lotusBoss ~= "rbxassetid://0" then
        bossProps.MeshId = ASSETS.lotusBoss
        table.insert(children, Spec.meshPart("LotusBoss", bossProps))
    else
        bossProps.Shape = "Cylinder"
        bossProps.Size = { 0.6, 1.8, 1.8 }
        bossProps.CFrame = Spec.cframe(bossPos, bossRot)
        table.insert(children, Spec.part("LotusBoss", bossProps))
    end
```
(Keep the existing `bossPos`/`bossRot`/`strikeY` computation above it so the boss stays on the strike axis.)

- [ ] **Step 7: Run tests, regen assets, verify**

```bash
cd roblox && lune run tests/run          # expect 0 failed (new Bonsho tests + contract pass)
lune run tools/genmodels                  # regenerate assets/BonshoRig.model.json
git status --short assets/                 # expect assets/BonshoRig.model.json modified
lune run tools/genmodels                  # run again — no further diff (determinism)
git diff --stat assets/BonshoRig.model.json  # expect NO change on the second run
```
Expected: tests `0 failed`; `BonshoRig.model.json` changed once and is stable on re-run.

- [ ] **Step 8: Live staging gate (STOP and ask)**

Re-sync Rojo so Studio picks up the new model.json (`rojo serve` running, or ask the user to reconnect). `screen_capture` the bell from the south (camera ~`[-2,122,30]` → `[-2,120,0]`) and a 3/4 angle. Confirm the bell reads as dark patinated bronze with the ryūzu crown and the strike boss on the south face. Make ONE attempt, then STOP and show the user for sign-off. Tune palette/StudsPerTile/mesh only after feedback.

- [ ] **Step 9: Commit**

```bash
cd roblox && stylua tools/builders/Bonsho.luau tests/Bonsho.spec.luau && selene src
git add roblox/tools/builders/Bonsho.luau roblox/tests/Bonsho.spec.luau roblox/assets/BonshoRig.model.json
git commit  # "feat(roblox): bonshō cast-bell mesh, ryūzu crown, tsuki-za, bronze patina"
```

---

### Task 4: Shōrō tower — weathered posts/beams, tokyō brackets, rafters

Roof stays as-is (the flat wedges) until Task 5; this task upgrades everything below the roofline. All new pieces are primitives (no meshes).

**Files:**
- Modify: `roblox/tools/builders/Shoro.luau`
- Modify: `roblox/tests/Shoro.spec.luau`

**Interfaces:**
- Consumes: `ZenDojo.palette.cypressWeathered`, `CypressWeathered`/`SlateTile` variants.
- Produces: posts/beams carry `MaterialVariant="CypressWeathered"`; NEW `Bracket{i}_{j}` stepped block-stacks atop each post; NEW `Rafter{i}` tails under the eave; NEW `BeamNose{i}` projecting beam ends.

- [ ] **Step 1: Write failing tests**

Append a new `describe` block at the END of `roblox/tests/Shoro.spec.luau` (the file already binds `Shoro`, `L`, `ZenDojo`, `describe/test/expect` at the top):
```lua
describe("Shoro art pass", function()
    test("posts wear the weathered cypress variant", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Post%d$") then
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
    end)
    test("emits a stepped tokyō bracket stack over each of the 4 posts", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local n = 0
        for _, c in spec.children :: any do
            if c.name:match("^Bracket%d+_%d+$") then
                n += 1
            end
        end
        expect(n >= 8).toBe(true) -- >= 2 blocks per post
    end)
    test("emits exposed rafter tails under the eave", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local n = 0
        for _, c in spec.children :: any do
            if c.name:match("^Rafter%d+$") then
                n += 1
            end
        end
        expect(n >= 8).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run tests, verify failure**

Run: `cd roblox && lune run tests/run` — expect `FAIL` on the three new Shoro tests.

- [ ] **Step 3: Add the cypress variant to posts + beams**

In `roblox/tools/builders/Shoro.luau`, add `MaterialVariant = "CypressWeathered"` to every timber `Spec.part` call (the four `Post{i}`, the two `RingBeamX{i}`, the two `RingBeamZ{i}`, and `BellBeam`). Add `MaterialVariant = "SlateTile"` to the four `Plinth{i}` (keep `Material="Slate"`).

- [ ] **Step 4: Add tokyō bracket stacks over each post**

After the post loop (before the ring beams), add:
```lua
    -- Tokyō: a stepped block-stack over each post head, each course wider than the one
    -- below (the reference's bracket complex). Cheap primitives, weathered cypress.
    local postTopY = 1.2 + (roofY - 1.2) -- top of the posts (post base 1.2 + height)
    for i, c in corners do
        for j = 1, 3 do
            local w = 1.6 + j * 0.5 -- each course steps outward
            table.insert(
                children,
                Spec.part(`Bracket{i}_{j}`, {
                    Size = { w, 0.55, w },
                    CFrame = place({ c[1], postTopY + (j - 0.5) * 0.55, c[2] }),
                    Color = timber,
                    Material = "Wood",
                    MaterialVariant = "CypressWeathered",
                })
            )
        end
    end
```

- [ ] **Step 5: Add rafter tails + projecting beam noses**

After the `BellBeam` block, add:
```lua
    -- Exposed rafter tails: a fan of thin square battens projecting past each eave line
    -- (the reference's radiating rafters). One row per side just under the roof.
    local eaveY = roofY - 0.1
    local roofHalfR = s + 4
    local nR = 0
    for _, side in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
        for k = -3, 3 do
            nR += 1
            local along = k * 2.4
            local px = side[1] ~= 0 and side[1] * (roofHalfR - 1) or along
            local pz = side[2] ~= 0 and side[2] * (roofHalfR - 1) or along
            table.insert(
                children,
                Spec.part(`Rafter{nR}`, {
                    Size = { 0.4, 0.4, 3.2 },
                    CFrame = place(
                        { px, eaveY, pz },
                        side[1] ~= 0 and Spec.ROT.CYL_ALONG_Z or Spec.ROT.IDENTITY
                    ),
                    Color = timber,
                    Material = "Wood",
                    MaterialVariant = "CypressWeathered",
                })
            )
        end
    end
    -- Projecting carved beam noses (kibana) where the ring beams cross the corner posts.
    for i, c in corners do
        table.insert(
            children,
            Spec.part(`BeamNose{i}`, {
                Size = { 0.9, 1.0, 1.4 },
                CFrame = place({ c[1], roofY - 0.6, c[2] }),
                Color = timber,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
```
(These use the existing `s`, `roofY`, `timber`, `corners`, `place` locals. `Rafter` orientation: `CYL_ALONG_Z` is reused only as a 90° yaw for the E/W sides — verify visually at the gate; adjust the rot literal if a batten points wrong.)

- [ ] **Step 6: Dragon corner brackets — OPTIONAL, low-effort only**

Only if a suitable carved dragon-head mesh is cheap to generate/vet: add `DragonBracket{i}` meshParts at the four corner bracket heads (`MeshId` in a new `ASSETS` entry, `MaterialVariant="CypressWeathered"`). If not cheap, SKIP — the plain tokyō stacks stand on their own. Do not block the task on this.

- [ ] **Step 7: Run tests, regen, verify determinism**

```bash
cd roblox && lune run tests/run          # 0 failed
lune run tools/genmodels && lune run tools/genmodels   # regen twice
git diff --stat assets/Shoro.model.json   # changed once, stable on re-run
```

- [ ] **Step 8: Live staging gate (STOP and ask)** — `screen_capture` the tower 3/4; confirm weathered posts + bracket complexes + rafter tails read right. ONE attempt, then STOP for sign-off.

- [ ] **Step 9: Commit**

```bash
cd roblox && stylua tools/builders/Shoro.luau tests/Shoro.spec.luau && selene src
git add roblox/tools/builders/Shoro.luau roblox/tests/Shoro.spec.luau roblox/assets/Shoro.model.json
git commit  # "feat(roblox): weathered shōrō posts/beams + tokyō brackets + rafter tails"
```

---

### Task 5: Hip roof mesh + raise the throw drum (coupled)

Replaces the four flat roof wedges with a generated hip roof and raises the drum so a proper roofline fits — including the coupled drive-linkage lift. This is the mechanism-adjacent task; verify engagement live.

**Files:**
- Modify: `roblox/tools/builders/Shoro.luau`
- Modify: `roblox/tools/builders/ArenaLayout.luau`
- Modify: `roblox/tests/Shoro.spec.luau`
- Modify: `roblox/tests/ArenaLayout.spec.luau`

**Interfaces:**
- Consumes: `Spec.meshPart`, `SlateTile` variant.
- Produces: `Shoro` emits `RoofMesh` (MeshPart) replacing `RoofWedge1-4`, keeps `Finial`. `ArenaLayout.throwDrum.pos[2]` raised by `DRUM_LIFT`; `bellDrive.vertTop[2]`, `driveGearA[2]`, `driveGearB[2]` raised by the same `DRUM_LIFT` so the pin-wheel still reaches the drum's south-spoke pins.

- [ ] **Step 1: Generate + vet the hip-roof mesh (MCP)**

`generate_mesh` prompt: "Japanese temple hip roof (irimoya/hōgyō style), square plan, four sloped faces meeting at a central peak, deep overhanging eaves with gently upturned corners, dark tile courses; hollow underside; single centred finial seat at the apex; low-to-moderate poly." Target ≤ ~5k tris. Vet, upload, record the id. **Fallback:** if unusable, keep the four `RoofWedge` primitives but deepen `pitch` to ~4 and extend `roofHalf` for a bigger eave, and skip the mesh (still an improvement); note the fallback for the user.

- [ ] **Step 2: Choose `DRUM_LIFT` and update `ArenaLayout.luau`**

Set `local DRUM_LIFT = 5` near the top of `ArenaLayout.luau` (after `_pavilionYaw`). Then:
- `throwDrum.pos` → `{ -2, 148 + DRUM_LIFT, 0 }`.
- In `bellDrive`, `vertTop` → `{ 1, 137.6 + DRUM_LIFT, 6 }`; `driveGearA` → `{ 1, 137.5 + DRUM_LIFT, 6 }`; `driveGearB` → `{ -1.18, 137.5 + DRUM_LIFT, 7 }`.
(DrumYoke/DrumBearing are built FROM `throwDrum.pos` + roof in BellDrive, so they follow automatically. The drum's south-spoke pins reach `southSpokeR` below centre, so they rise with the drum; the linkage above rises the same `DRUM_LIFT` to stay under them.)

- [ ] **Step 3: Write failing tests**

Append a new `describe` block at the END of `roblox/tests/ArenaLayout.spec.luau` (self-contained require to avoid shadowing the file's binding):
```lua
describe("ArenaLayout drum lift", function()
    local AL = require("../tools/builders/ArenaLayout")
    test("drum and its pin-wheel linkage rose together (same lift)", function()
        local lift = AL.throwDrum.pos[2] - 148
        expect(lift > 0).toBe(true)
        expect(AL.bellDrive.driveGearA[2]).toBeCloseTo(137.5 + lift, 0.001)
        expect(AL.bellDrive.driveGearB[2]).toBeCloseTo(137.5 + lift, 0.001)
        expect(AL.bellDrive.vertTop[2]).toBeCloseTo(137.6 + lift, 0.001)
    end)
end)
```
Append a new `describe` block at the END of `roblox/tests/Shoro.spec.luau`:
```lua
describe("Shoro hip roof", function()
    test("roof is a single slate hip mesh, not four wedges", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["RoofWedge1"]).toBeNil()
        expect(names["RoofMesh"]).toBe(true)
    end)
end)
```

- [ ] **Step 4: Run tests, verify failure** — `cd roblox && lune run tests/run` → `FAIL` on the two new tests.

- [ ] **Step 5: Replace the roof wedges in `Shoro.luau`**

Add an `ASSETS` table at the top of `Shoro.luau` (`local ASSETS = { roof = "rbxassetid://0" }` — paste the uploaded id). Replace the `local wedges = {…}` block and its `for i, w in wedges` loop with:
```lua
    local roofHalf = s + 4
    local roofRise = 6.5 -- taller than the old flat slab; fits under the raised drum
    table.insert(
        children,
        Spec.meshPart("RoofMesh", {
            MeshId = ASSETS.roof,
            Size = { 2 * roofHalf, roofRise, 2 * roofHalf },
            CFrame = place({ 0, roofY + roofRise / 2, 0 }),
            Color = ink,
            Material = "Slate",
            MaterialVariant = "SlateTile",
        })
    )
```
Update the `Finial` `CFrame` to sit on the new apex: `place({ 0, roofY + roofRise + 1.1, 0 })`. Keep `Material="Metal"`, `Color=palette.gold`. (If using the wedge fallback from Step 1, keep the wedge loop with `pitch=4`/bigger `roofHalf` and skip `RoofMesh` — but then Step 3's Shoro test must be adjusted; prefer the mesh.)

- [ ] **Step 6: Run tests, regen (Shoro + BellDrive + ThrowDrum all depend on the layout)**

```bash
cd roblox && lune run tests/run          # 0 failed
lune run tools/genmodels && lune run tools/genmodels
git diff --stat assets/                   # Shoro, BellDrive, ThrowDrum model.json changed; stable on re-run
```

- [ ] **Step 7: Live staging gate — verify BOTH look AND mechanism (STOP and ask)**

Re-sync Rojo. In Studio, `screen_capture` the roof/drum composition (camera ~`[34,150,34]` → `[-2,144,0]`). Then **Play** (`start_stop_play`) and watch a full round to confirm the pin-wheel's `DrivePaddle` still flicks the drum's south spoke and the drum spins on reveal (the coupling worked). If the paddle no longer reaches the spoke, adjust `DRUM_LIFT` or the three linkage Y's together and re-verify. Make ONE attempt at the look, then STOP and show the user before tuning further.

- [ ] **Step 8: Commit**

```bash
cd roblox && stylua tools/builders/Shoro.luau tools/builders/ArenaLayout.luau tests/Shoro.spec.luau tests/ArenaLayout.spec.luau && selene src
git add roblox/tools/builders/Shoro.luau roblox/tools/builders/ArenaLayout.luau roblox/tests/Shoro.spec.luau roblox/tests/ArenaLayout.spec.luau roblox/assets/Shoro.model.json roblox/assets/BellDrive.model.json roblox/assets/ThrowDrum.model.json
git commit  # "feat(roblox): shōrō hip-roof mesh + raise throw drum with its pin-wheel linkage"
```

---

### Task 6: ThrowDrum dressing — iron bands, hub, face/yoke polish

Keeps `Drum`, `Face0-5`, `Spoke1-12` (contract); adds static dressing and reskins.

**Files:**
- Modify: `roblox/tools/builders/ThrowDrum.luau`
- Modify: `roblox/tests/ThrowDrum.spec.luau`

**Interfaces:**
- Consumes: `ZenDojo.palette.ironDark`/`.cypressWeathered`, `IronDark`/`CypressWeathered` variants.
- Produces: faces + spokes carry `CypressWeathered`; NEW `Hoop1`/`Hoop2` iron bands ringing the ends; `Shaft` reskinned `IronDark`.

- [ ] **Step 1: Write failing test**

Append a new `describe` block at the END of `roblox/tests/ThrowDrum.spec.luau`:
```lua
describe("ThrowDrum art pass", function()
    test("emits two iron hoop bands and cypress faces", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
            if c.name:match("^Face%d$") then
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
        expect(names["Hoop1"]).toBe(true)
        expect(names["Hoop2"]).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run, verify failure** — `lune run tests/run` → FAIL (`Hoop1` missing).

- [ ] **Step 3: Reskin faces/spokes/shaft + add hoops**

In `ThrowDrum.luau`: add `MaterialVariant = "CypressWeathered"` to each `Face{k}` and `Spoke{spoke}` part, and `MaterialVariant = "IronDark"` to `Shaft`. After the faces loop, add two iron hoops ringing the drum near each end:
```lua
    -- Iron hoop bands ringing the drum near each end (cooperage look). Thin cylinders
    -- co-axial with the hub (local X = the spin axis) — but they're static dressing:
    -- symmetric rings, so leaving them unspun is invisible.
    for hi, ex in { -length / 2 + 0.6, length / 2 - 0.6 } do
        table.insert(
            top,
            Spec.part(`Hoop{hi}`, {
                Size = { 0.4, 2 * r + 0.3, 2 * r + 0.3 },
                Shape = "Cylinder",
                CFrame = place({ px + ex, py, pz }),
                Color = palette.ink,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
```
Reskin the A-frame yokes? Those live in `BellDrive` (`DrumYoke*`) — deferred to Task 8. Nothing else here.

- [ ] **Step 4: Run tests, regen, determinism** — `lune run tests/run` (0 failed); `lune run tools/genmodels` ×2; `git diff --stat assets/ThrowDrum.model.json` changed once, stable.

- [ ] **Step 5: Live gate (STOP and ask)** — capture the drum; confirm banded wooden drum with legible R/P/S faces. ONE attempt, then STOP.

- [ ] **Step 6: Commit**
```bash
cd roblox && stylua tools/builders/ThrowDrum.luau tests/ThrowDrum.spec.luau && selene src
git add roblox/tools/builders/ThrowDrum.luau roblox/tests/ThrowDrum.spec.luau roblox/assets/ThrowDrum.model.json
git commit  # "feat(roblox): throw-drum iron hoops + weathered faces"
```

---

### Task 7: Waterwheel — mill-wheel mesh, buckets, wet paddles

`Wheel1` and `Paddle1_1..8` are the only spun parts, so the wheel visual is ONE `Wheel1` mesh (rims/spokes/hub baked in) and the buckets stay the named paddles.

**Files:**
- Modify: `roblox/tools/builders/Waterwheel.luau`
- Modify: `roblox/tests/Waterwheel.spec.luau`

**Interfaces:**
- Consumes: `Spec.meshPart`, `CypressWeathered`/`MossyPaddle`/`IronDark` variants.
- Produces: `Wheel{wi}` becomes a MeshPart (rims/spokes/hub) at the same CFrame; `Paddle{wi}_{i}` reskinned `MossyPaddle`; `Axle{wi}` reskinned `IronDark`; `RatchetDrum` unchanged names.

- [ ] **Step 1: Generate + vet the mill-wheel mesh (MCP)**

`generate_mesh` prompt: "wooden undershot mill waterwheel: two concentric rims joined by radial spokes to a central hub, open construction, weathered planks, cylindrical (thin along the axle); no paddles/buckets (added separately); low poly." Target ≤ ~3k tris. Model so its axis matches a cylinder's local X (the axle), since `Wheel1` is placed with `Spec.yaw(W.yaw)`. Upload, record id. **Fallback:** keep the solid `Cylinder` `Wheel1` but add static rim/spoke... no — dressing can't spin. If the mesh is unusable, keep the solid disc `Wheel1` and only reskin (cypress) — note to user.

- [ ] **Step 2: Write failing test**

Append a new `describe` block at the END of `roblox/tests/Waterwheel.spec.luau`:
```lua
describe("Waterwheel art pass", function()
    test("Wheel1 is a mesh and paddles wear the wet variant", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "Wheel1" then
                expect(c.className).toBe("MeshPart")
            end
            if c.name:match("^Paddle1_%d+$") then
                expect(c.properties.MaterialVariant).toBe("MossyPaddle")
            end
        end
    end)
end)
```

- [ ] **Step 3: Run, verify failure** — `lune run tests/run` → FAIL.

- [ ] **Step 4: Swap the wheel disc to a mesh + reskin**

Add `local ASSETS = { wheel = "rbxassetid://0" }` at the top of `Waterwheel.luau` (paste id). Replace the `Wheel{wi}` `Spec.part(... Shape="Cylinder" ...)` with:
```lua
        table.insert(
            children,
            Spec.meshPart(`Wheel{wi}`, {
                MeshId = ASSETS.wheel,
                Size = { width, 2 * R, 2 * R },
                CFrame = Spec.cframe(c, rot),
                Color = timber,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
```
Add `MaterialVariant = "MossyPaddle"` AND change `Color = timber` to `Color = palette.paddleWet` on each `Paddle{wi}_{i}` (darker wet tone); add `MaterialVariant = "IronDark"` to each `Axle{wi}`. Keep the `Support{wi}_{si}` posts (`CypressWeathered`) and `RatchetDrum` (`IronDark`).

- [ ] **Step 5: Run tests, regen, determinism** — `lune run tests/run` (0 failed, incl. contract: `Wheel1` + 8 paddles still present); `lune run tools/genmodels` ×2; stable diff.

- [ ] **Step 6: Live gate — verify look AND spin (STOP and ask)** — capture the wheel; **Play** and confirm `Wheel1` (now a mesh) still spins with its buckets and the lower paddles churn spray. ONE attempt, then STOP.

- [ ] **Step 7: Commit**
```bash
cd roblox && stylua tools/builders/Waterwheel.luau tests/Waterwheel.spec.luau && selene src
git add roblox/tools/builders/Waterwheel.luau roblox/tests/Waterwheel.spec.luau roblox/assets/Waterwheel.model.json
git commit  # "feat(roblox): waterwheel mill mesh + wet mossy paddles"
```

---

### Task 8: Drive-chain — cam mesh, toothed gears, timber shafts

`^Cam` parts spin about the cam shaft; a single `Cam` mesh replaces the 80 `CamEdge` planks. Toothed gear meshes replace the flat discs. The technical pass may later reshape these — that's the accepted re-skin risk.

**Files:**
- Modify: `roblox/tools/builders/BellDrive.luau`
- Modify: `roblox/tests/BellDrive.spec.luau`

**Interfaces:**
- Consumes: `Spec.meshPart`, `IronDark`/`CypressWeathered` variants.
- Produces: single `Cam` MeshPart replaces `Cam`+`CamEdge1..80`; `DriverGear`/`CamGear`/`DriveGearA`/`DriveGearB` become toothed gear meshes (names unchanged); shafts reskinned; yokes/bearings reskinned.

- [ ] **Step 1: Generate + vet the cam + gear meshes (MCP)**

- `Cam`: prompt "snail/scroll draw cam disc: circular base with one spiral rising lobe and a sharp drop wall, thin along the axle; low poly." Model axis = cylinder local X. Target ≤ ~1.5k tris.
- `Gear`: prompt "flat spur gear, teeth around the rim, thin, central bore, low poly." One reusable mesh scaled per gear. Target ≤ ~1.5k tris.
Upload; record ids. **Fallback:** keep the faceted `CamEdge` planks / disc gears (already functional) and only reskin materials — note to user.

- [ ] **Step 2: Write failing test**

Append a new `describe` block at the END of `roblox/tests/BellDrive.spec.luau`:
```lua
describe("BellDrive art pass", function()
    test("cam is a single mesh (no CamEdge planks) and gears are meshes", function()
        local spec = BellDrive.build(ZenDojo.palette, L)
        local names, camPart = {}, nil
        for _, c in spec.children :: any do
            names[c.name] = true
            if c.name == "Cam" then
                camPart = c
            end
        end
        expect(names["CamEdge1"]).toBeNil()
        expect(camPart).toBeTruthy()
        expect(camPart.className).toBe("MeshPart")
        expect(camPart.name:match("^Cam") ~= nil).toBe(true) -- still spun by HammerController
    end)
end)
```

- [ ] **Step 3: Run, verify failure** — `lune run tests/run` → FAIL.

- [ ] **Step 4: Replace the cam plank fan with one mesh**

Add `local ASSETS = { cam = "rbxassetid://0", gear = "rbxassetid://0" }` at the top of `BellDrive.luau`. DELETE the `FLANK`/`TIGHTEN`/`PEAK`/`DROP0`/`profileR`/`plankRot`/`STEP`/`plankW` block AND the `for deg = 0, 360-STEP` `CamEdge` loop. Replace the existing `Cam` base-circle `Spec.part` with:
```lua
    -- One snail-cam mesh on the E-W cam shaft (turns about X with the shaft). Name starts
    -- "Cam" so HammerController spins it. camLobeR sets the visual throw envelope.
    local camDia = d.camLobeR * 2
    table.insert(
        children,
        Spec.meshPart("Cam", {
            MeshId = ASSETS.cam,
            Size = { 0.6, camDia, camDia },
            CFrame = Spec.cframe(d.cam),
            Color = timber,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
```

- [ ] **Step 5: Swap the four gears to toothed meshes + reskin shafts/yokes**

For `DriverGear`, `CamGear`, `DriveGearA`, `DriveGearB`: change each `Spec.part(... Shape="Cylinder" ...)` to `Spec.meshPart` with `MeshId = ASSETS.gear`, keeping the SAME `name`, `Size`, `CFrame`, and adding `MaterialVariant = "IronDark"` (or `"CypressWeathered"` for the wooden `DriverGear`/`CamGear` — keep their current `Color`/`Material` intent). Add `MaterialVariant = "IronDark"` to `MainShaft`, `CamShaft`, `VertShaft`, `DriveGearBShaft`, `DrumBearing{i}`, `BearingSaddle{i}`; add `MaterialVariant = "CypressWeathered"` to `VertPaddle`, `DrivePaddle`, `DrumYoke{n}`, `BearingPost{i}`.

- [ ] **Step 6: Run tests, regen, determinism** — `lune run tests/run` (0 failed, incl. contract `^Cam` ≥ 1 and all gear/shaft/yoke names present); `lune run tools/genmodels` ×2; stable diff. Expect `BellDrive.model.json` to SHRINK (80 CamEdge parts gone).

- [ ] **Step 7: Live gate — verify look AND cam action (STOP and ask)** — capture the drive train; **Play** a full round and confirm the cam still draws/trips the shu-moku (the mesh spins about the shaft) and the gears turn. ONE attempt, then STOP.

- [ ] **Step 8: Commit**
```bash
cd roblox && stylua tools/builders/BellDrive.luau tests/BellDrive.spec.luau && selene src
git add roblox/tools/builders/BellDrive.luau roblox/tests/BellDrive.spec.luau roblox/assets/BellDrive.model.json
git commit  # "feat(roblox): drive-chain cam mesh + toothed gears + weathered shafts"
```

---

### Task 9: Composite gate + branch finish

**Files:** memory updates; no code.

- [ ] **Step 1: Full green bar**

```bash
cd roblox && lune run tests/run && rojo build -o /tmp/roshambo-verify.rbxl && stylua --check src tests && selene src
```
Expected: `0 failed`, build succeeds, lints clean. (Also run `stylua --check tools` if the repo's stylua config globs `tools`; otherwise the per-task `stylua tools/…` formats already applied.)

- [ ] **Step 2: Determinism sweep** — `lune run tools/genmodels` once more; `git status --short assets/` must be clean (no drift after the committed regens).

- [ ] **Step 3: Composite staging gate (STOP and ask)** — `screen_capture` the whole centerpiece from the south, a 3/4, and a downcanyon angle; **Play** one full round to confirm the entire mechanism animates (wheel spins → cam draws → bell strikes → drum spins). Show the user the composite for final sign-off against the reference photo.

- [ ] **Step 4: Update memories**

- `zendojo-bell-engine.md`: mark the beauty pass DONE (bell mesh + ryūzu + patina, hip-roof mesh + raised drum, drum/wheel/drive-chain dressing), note the drum-lift coupling and the new `CenterpieceContract` test.
- `roshambo-roadmap.md`: move the "Water Striker visual pass" from NEXT-UP to shipped; leave the **drive-chain technical/mechanism pass** as the next deferred item.
- Note any mesh assets that fell back to primitives (for a later revisit).

- [ ] **Step 5: Finish the branch** — use `superpowers:finishing-a-development-branch` (this is on the long-lived `m4b-zendojo-art-pass` branch; follow that skill's guidance for whether to keep accumulating or open a PR).

---

## Notes for the executor

- **Rojo sync between tasks:** after each `lune run tools/genmodels`, the committed `assets/*.model.json` change only appears in Studio when Rojo re-syncs. Keep `rojo serve` connected, or ask the user to reconnect the Rojo plugin, before each live gate.
- **MCP datamodel:** builder work is filesystem + Lune (no Studio needed); live gates use the MCP `Edit` datamodel for `screen_capture`/`inspect_instance` and `start_stop_play` + a `Client`/`Server` datamodel to watch a round. Reset `CameraType=Custom` after camera-arg captures ([[roblox-screencapture-camera-lock]]).
- **One attempt, then stop:** every live gate is a hard stop for user eyes — never self-judge visual quality and iterate unprompted ([[stop-and-ask-after-each-attempt]]).
- **If a mesh won't generate well:** take the per-task fallback (refined primitives), commit that, and flag it — do not block the pass on one mesh.
