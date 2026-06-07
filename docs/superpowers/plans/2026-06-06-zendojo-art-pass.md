# ZenDojo Art Pass (M4b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every placeholder in the Roblox arena with real ZenDojo art — terraced bowl, karesansui center, bonshō monument with kakehi flume + waterwheel, teahouses, fate models, champion statues + stele, lighting and sound — per `docs/superpowers/specs/2026-06-06-zendojo-art-pass-design.md`.

**Architecture:** Geometry is code: pure Luau *builder modules* (`roblox/tools/builders/`) return part-spec tables; a Lune script (`roblox/tools/genmodels.luau`) serializes them to Rojo `.model.json` files in `roblox/assets/` (committed, generated — never hand-edited). `ArenaLayout.luau` is the single source of truth for every world coordinate. Terrain (not Rojo-syncable) is an idempotent Studio script run via the Roblox Studio MCP. The M4a machinery is never edited — only manifest data, thin controllers, and the new `ChampionSeats`/`StatueDresser` modules.

**Tech Stack:** Luau + Lune (bespoke harness in `roblox/tests/harness.luau`), Rojo 7.6, Roblox Studio MCP (`execute_luau`, `screen_capture`, `start_stop_play`, `generate_mesh`, `search_creator_store`), stylua + selene.

**Working directory note:** Execute in the main checkout, NOT an isolated worktree — `rojo serve` and the Studio MCP session are bound to this working tree.

**Conventions used below:**
- All Luau files start with `--!strict` and pass `stylua --check` + `selene`.
- Run tests from `roblox/`: `lune run tests/run` (expect: all pass; count grows per task).
- "MCP gate" = build/sync via `rojo serve`, playtest via MCP `start_stop_play(true)`, capture via `screen_capture`, stop, judge against the step's checklist. User walkthrough gates are marked **USER GATE** — stop and get explicit approval before the next task.
- Rojo model.json property shorthand: `Size: [x,y,z]`, `Color: [r,g,b]` (0–1), `CFrame: [px,py,pz, r00,r01,r02, r10,r11,r12, r20,r21,r22]`.

---

## Pass 0 — Pipeline proof

### Task 1: ZenDojo manifest v2 (palette, lighting, materials, new sound key)

**Files:**
- Modify: `roblox/src/shared/ThemeManifest.luau`
- Modify: `roblox/src/shared/themes/ZenDojo.luau`
- Test: `roblox/tests/ThemeManifest.spec.luau`

- [ ] **Step 1: Write the failing tests** — append to `roblox/tests/ThemeManifest.spec.luau` inside the existing `describe`:

```lua
    test("v2: missing palette key fails loudly", function()
        local theme = makeValidTheme() -- existing helper in this spec; if absent, copy ZenDojo into a local table
        theme.palette.moss = nil
        local ok, errs = ThemeManifest.validate(theme)
        expect(ok).toBe(false)
        expect(table.concat(errs, ";"):find("palette.moss") ~= nil).toBe(true)
    end)

    test("v2: missing lighting key fails loudly", function()
        local theme = makeValidTheme()
        theme.lighting.clockTime = nil
        local ok = ThemeManifest.validate(theme)
        expect(ok).toBe(false)
    end)

    test("v2: waterAmbience is a required sound", function()
        local theme = makeValidTheme()
        theme.sounds.waterAmbience = nil
        local ok = ThemeManifest.validate(theme)
        expect(ok).toBe(false)
    end)

    test("ZenDojo theme passes v2 validation", function()
        local ZenDojo = require("../src/shared/themes/ZenDojo")
        local ok, errs = ThemeManifest.validate(ZenDojo)
        expect(ok).toBe(true)
    end)
```

If the spec file has no `makeValidTheme` helper, add one at the top of the describe that returns a deep copy of the ZenDojo module (`require` once, copy tables).

- [ ] **Step 2: Run tests, verify the new ones fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — palette/lighting/waterAmbience assertions.

- [ ] **Step 3: Implement** — in `ThemeManifest.luau` add after `REQUIRED_MODELS`:

```lua
ThemeManifest.REQUIRED_PALETTE = { "moss", "ivory", "vermilion", "ink", "gold", "water", "gravel", "timber" }
ThemeManifest.REQUIRED_LIGHTING = { "clockTime", "brightness", "ambient", "outdoorAmbient" }
```

Add `"waterAmbience"` to `REQUIRED_SOUNDS`. In `validate`, after the models loop:

```lua
    local palette = if type(theme.palette) == "table" then theme.palette else {}
    for _, key in ThemeManifest.REQUIRED_PALETTE do
        local c = palette[key]
        if type(c) ~= "table" or #c ~= 3 then
            table.insert(errs, `missing palette.{key}`)
        end
    end
    local lighting = if type(theme.lighting) == "table" then theme.lighting else {}
    for _, key in ThemeManifest.REQUIRED_LIGHTING do
        if lighting[key] == nil then
            table.insert(errs, `missing lighting.{key}`)
        end
    end
```

In `ZenDojo.luau` add the data (0–1 RGB; lighting ambients are 0–255 triples consumed by Color3.fromRGB later):

```lua
    palette = {
        moss = { 0.48, 0.54, 0.39 },
        ivory = { 0.87, 0.84, 0.76 },
        vermilion = { 0.63, 0.36, 0.27 },
        ink = { 0.18, 0.19, 0.22 },
        gold = { 0.83, 0.69, 0.40 },
        water = { 0.20, 0.35, 0.43 },
        gravel = { 0.79, 0.76, 0.70 },
        timber = { 0.42, 0.31, 0.20 },
    },
    lighting = {
        clockTime = 16.5,
        brightness = 2.4,
        ambient = { 90, 88, 84 },
        outdoorAmbient = { 130, 120, 105 },
    },
    sounds = { clack = "0", gong = "0", drumroll = "0", latch = "0", splash = "0", bank = "0", waterAmbience = "0" },
```

(keep existing keys; only `waterAmbience` is new in `sounds`).

- [ ] **Step 4: Run tests, verify pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS, count > 113.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests && selene src
git add roblox/src/shared/ThemeManifest.luau roblox/src/shared/themes/ZenDojo.luau roblox/tests/ThemeManifest.spec.luau
git commit -m "feat(roblox): theme manifest v2 - palette, lighting, waterAmbience required"
```

### Task 2: Builder pipeline — part specs → Rojo model.json

**Files:**
- Create: `roblox/tools/builders/JsonEmit.luau` (deterministic JSON, sorted keys)
- Create: `roblox/tools/builders/Spec.luau` (part-spec helpers)
- Create: `roblox/tools/builders/StoneLantern.luau` (first real builder)
- Create: `roblox/tools/genmodels.luau` (Lune entrypoint)
- Modify: `roblox/default.project.json`
- Modify: `.github/workflows/roblox-ci.yml`
- Test: `roblox/tests/JsonEmit.spec.luau`, `roblox/tests/StoneLantern.spec.luau`

- [ ] **Step 1: Failing test for deterministic JSON** — `roblox/tests/JsonEmit.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local JsonEmit = require("../tools/builders/JsonEmit")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("JsonEmit", function()
    test("emits sorted keys deterministically", function()
        local s = JsonEmit.encode({ b = 1, a = { 2, 3 }, c = "x" })
        expect(s).toBe('{"a":[2,3],"b":1,"c":"x"}')
    end)
    test("arrays of tables and numbers", function()
        expect(JsonEmit.encode({ { n = 1 }, { n = 2 } })).toBe('[{"n":1},{"n":2}]')
    end)
end)
```

- [ ] **Step 2: Run, expect FAIL** (`module not found`).

- [ ] **Step 3: Implement `JsonEmit.luau`**

```lua
--!strict
-- Deterministic JSON (sorted object keys) so generated model.json files are
-- stable across runs — required for the CI drift check.
local JsonEmit = {}

local function isArray(t: { [any]: any }): boolean
    local n = 0
    for _ in t do
        n += 1
    end
    return n == #t and n > 0
end

function JsonEmit.encode(v: any): string
    local ty = type(v)
    if ty == "number" then
        -- avoid 1.0 vs 1 drift
        if v % 1 == 0 and math.abs(v) < 2 ^ 53 then
            return string.format("%d", v)
        end
        return string.format("%.6g", v)
    elseif ty == "string" then
        return string.format("%q", v):gsub("\\\n", "\\n")
    elseif ty == "boolean" then
        return tostring(v)
    elseif ty == "table" then
        if isArray(v) then
            local parts = {}
            for _, item in ipairs(v) do
                table.insert(parts, JsonEmit.encode(item))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in v do
            table.insert(keys, k)
        end
        table.sort(keys)
        local parts = {}
        for _, k in keys do
            table.insert(parts, string.format("%q", k) .. ":" .. JsonEmit.encode(v[k]))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error(`JsonEmit: unsupported type {ty}`)
end

return JsonEmit
```

(Note: `string.format("%q", ...)` in Luau escapes per Lua rules — acceptable for our ASCII keys and values; CJK board strings never pass through builders.)

- [ ] **Step 4: Implement `Spec.luau`** — helpers every builder uses:

```lua
--!strict
-- Part-spec helpers. A spec is a plain table that genmodels.luau converts to
-- Rojo model.json. Rotations: identity, or named axis helpers below.
local Spec = {}

export type PartSpec = {
    name: string,
    className: string,
    properties: { [string]: any },
    children: { PartSpec }?,
}

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
-- cylinder axis is +X; these re-aim it:
local CYL_VERTICAL = { 0, -1, 0, 1, 0, 0, 0, 0, 1 } -- axis → Y
local CYL_ALONG_Z = { 0, 0, 1, 0, 1, 0, -1, 0, 0 } -- axis → Z

function Spec.cframe(pos: { number }, rot: { number }?): { number }
    local r = rot or IDENTITY
    return { pos[1], pos[2], pos[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] }
end

Spec.ROT = { IDENTITY = IDENTITY, CYL_VERTICAL = CYL_VERTICAL, CYL_ALONG_Z = CYL_ALONG_Z }

function Spec.part(name: string, props: { [string]: any }): PartSpec
    local properties: { [string]: any } = { Anchored = true }
    for k, v in props do
        properties[k] = v
    end
    return { name = name, className = "Part", properties = properties }
end

function Spec.model(name: string, children: { PartSpec }): PartSpec
    return { name = name, className = "Model", properties = {}, children = children }
end

return Spec
```

- [ ] **Step 5: Failing test for the lantern builder** — `roblox/tests/StoneLantern.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local StoneLantern = require("../tools/builders/StoneLantern")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("StoneLantern builder", function()
    test("builds a model with base, post, firebox, cap", function()
        local spec = StoneLantern.build(ZenDojo.palette, { 0, 0, 0 })
        expect(spec.className).toBe("Model")
        expect(#(spec.children :: any)).toBe(4)
    end)
    test("every part uses only palette colors", function()
        local spec = StoneLantern.build(ZenDojo.palette, { 0, 0, 0 })
        local allowed = {}
        for _, c in ZenDojo.palette :: any do
            allowed[table.concat(c, ",")] = true
        end
        for _, child in spec.children :: any do
            expect(allowed[table.concat(child.properties.Color, ",")]).toBe(true)
        end
    end)
    test("position offset moves every part", function()
        local a = StoneLantern.build(ZenDojo.palette, { 0, 0, 0 })
        local b = StoneLantern.build(ZenDojo.palette, { 10, 0, 0 })
        expect((b.children :: any)[1].properties.CFrame[1] - (a.children :: any)[1].properties.CFrame[1]).toBe(10)
    end)
end)
```

- [ ] **Step 6: Run, expect FAIL. Implement `StoneLantern.luau`:**

```lua
--!strict
-- Ishidōrō stone lantern: base / post / firebox / cap. ~5 studs tall.
local Spec = require("./Spec")

local StoneLantern = {}

function StoneLantern.build(palette: { [string]: { number } }, at: { number })
    local x, y, z = at[1], at[2], at[3]
    local stone = palette.gravel
    local glow = palette.gold
    return Spec.model("StoneLantern", {
        Spec.part("Base", {
            Size = { 2.2, 0.8, 2.2 },
            CFrame = Spec.cframe({ x, y + 0.4, z }),
            Color = stone,
            Material = "Slate",
        }),
        Spec.part("Post", {
            Size = { 0.9, 2.2, 0.9 },
            CFrame = Spec.cframe({ x, y + 1.9, z }),
            Color = stone,
            Material = "Slate",
        }),
        Spec.part("Firebox", {
            Size = { 1.6, 1.2, 1.6 },
            CFrame = Spec.cframe({ x, y + 3.6, z }),
            Color = glow,
            Material = "Neon",
            Transparency = 0.2,
        }),
        Spec.part("Cap", {
            Size = { 2.6, 0.7, 2.6 },
            CFrame = Spec.cframe({ x, y + 4.55, z }),
            Color = stone,
            Material = "Slate",
        }),
    })
end

return StoneLantern
```

- [ ] **Step 7: Implement `genmodels.luau`** (Lune entrypoint):

```lua
--!strict
-- Generates roblox/assets/*.model.json from builder modules. Output is
-- committed; never hand-edit. Run from roblox/: lune run tools/genmodels
local fs = require("@lune/fs")
local JsonEmit = require("./builders/JsonEmit")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local StoneLantern = require("./builders/StoneLantern")

local function toRojo(spec): any
    local node: any = { className = spec.className, properties = spec.properties }
    if spec.children then
        node.children = {}
        for _, child in spec.children do
            local c = toRojo(child)
            c.name = child.name
            table.insert(node.children, c)
        end
    end
    return node
end

local OUTPUTS: { [string]: any } = {
    -- filename (under assets/) → builder spec
    ["PipelineProofLantern"] = StoneLantern.build(ZenDojo.palette, { 0, 0, 20 }),
}

if not fs.isDir("assets") then
    fs.writeDir("assets")
end
for name, spec in OUTPUTS do
    local rojo = toRojo(spec)
    fs.writeFile(`assets/{name}.model.json`, JsonEmit.encode(rojo) .. "\n")
    print(`wrote assets/{name}.model.json`)
end
```

Run: `cd roblox && lune run tools/genmodels`
Expected: `wrote assets/PipelineProofLantern.model.json`

- [ ] **Step 8: Wire into the project** — in `roblox/default.project.json`, inside `"RoshamboStage"`, add:

```json
"PipelineProofLantern": { "$path": "assets/PipelineProofLantern.model.json" }
```

- [ ] **Step 9: Run all tests + rojo build**

Run: `cd roblox && lune run tests/run && rojo build -o /tmp/proof.rbxl`
Expected: tests PASS; rojo build succeeds (validates the model.json parses).

- [ ] **Step 10: MCP gate** — with `rojo serve` connected to Studio: playtest, `screen_capture` aimed at `(0, 0, 20)` — the lantern stands on the baseplate with a glowing firebox.

- [ ] **Step 11: CI drift check** — in `.github/workflows/roblox-ci.yml`, after the `Lune tests` step add:

```yaml
      - name: Generated models are current
        run: |
          lune run tools/genmodels
          git diff --exit-code assets
```

- [ ] **Step 12: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/tools roblox/assets roblox/tests/JsonEmit.spec.luau roblox/tests/StoneLantern.spec.luau roblox/default.project.json .github/workflows/roblox-ci.yml
git commit -m "feat(roblox): geometry-as-code pipeline - builders -> model.json -> Rojo, CI drift check"
```

> Note: selene may need `tools` added to its include paths in `roblox/selene.toml` — if `selene tools` errors on config, add the directory per the existing config pattern.

### Task 3: Mesh-route probe (decision task)

**Files:** none committed — this task produces a *decision* recorded in the plan checklist.

- [ ] **Step 1:** In Studio (edit mode) via MCP, call `generate_mesh` with prompt "weathered moss-flecked garden boulder, smooth worn granite, stylized" targeting a ~4-stud rock.
- [ ] **Step 2:** Inspect the result (`inspect_instance`): does the produced MeshPart have a stable `MeshId` asset URL (`rbxassetid://…`)?
  - **If YES:** meshes serialize — record the route `MESH_OK`: bell + shears + boulders may use `generate_mesh`, with `MeshId`/`TextureID` strings captured into builder specs as `MeshPart` properties.
  - **If NO** (EditableMesh / place-bound content): record `MESH_FALLBACK`: all geometry stays part-built (the builders in Tasks 7, 16 already define part-built forms; mesh becomes an M5+ upgrade).
- [ ] **Step 3:** Delete the probe instance from the place. Tell the user which route was recorded and why before proceeding.

---

## Pass 1 — Graybox

### Task 4: ArenaLayout — the coordinate authority

**Files:**
- Create: `roblox/tools/builders/ArenaLayout.luau`
- Test: `roblox/tests/ArenaLayout.spec.luau`

- [ ] **Step 1: Failing tests:**

```lua
--!strict
local harness = require("./harness")
local L = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ArenaLayout", function()
    test("rings nest strictly: basin < apron < tiers ascending < bowl", function()
        expect(L.basinRadius < L.apronRadius).toBe(true)
        expect(L.apronRadius < L.tiers[1].radius).toBe(true)
        expect(L.tiers[1].radius < L.tiers[2].radius).toBe(true)
        expect(L.tiers[2].radius < L.tiers[3].radius).toBe(true)
        expect(L.tiers[3].radius < L.bowlRadius).toBe(true)
    end)
    test("tier heights ascend", function()
        expect(L.tiers[1].height < L.tiers[2].height).toBe(true)
        expect(L.tiers[2].height < L.tiers[3].height).toBe(true)
    end)
    test("promontories sit on tier 2 inside its radius", function()
        for _, p in L.promontories do
            local d = math.sqrt(p.pos[1] ^ 2 + p.pos[3] ^ 2)
            expect(d < L.tiers[2].radius and d > L.tiers[1].radius).toBe(true)
            expect(p.pos[2]).toBe(L.tiers[2].height)
        end
    end)
    test("flume runs downhill: pool higher than wheel top", function()
        expect(L.flume.poolPos[2] > L.flume.wheelPos[2] + L.flume.wheelRadius).toBe(true)
    end)
    test("teahouses sit on tiers, outside the apron", function()
        for _, t in L.teahouses do
            local d = math.sqrt(t.pos[1] ^ 2 + t.pos[3] ^ 2)
            expect(d > L.apronRadius).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run, expect FAIL. Implement:**

```lua
--!strict
-- Single source of truth for every world coordinate in the ZenDojo arena.
-- Y=0 is the basin waterline. South (−Z) is the entrance.
local ArenaLayout = {
    bowlRadius = 110,
    basinRadius = 16,
    apronRadius = 42, -- karesansui gravel: basinRadius..apronRadius
    tiers = {
        { radius = 58, height = 3 },
        { radius = 76, height = 8 },
        { radius = 94, height = 14 },
    },
    pavilion = { pos = { 0, 0, 0 }, postSpacing = 14, roofHeight = 18 },
    bell = { pos = { 0, 7.5, 0 }, height = 9, radius = 3.4 }, -- bottom lip ~3 studs over water
    shuMoku = { restPos = { 0, 6.2, 9.5 }, length = 7, radius = 0.8, drawStuds = 6 }, -- draws toward +Z
    flume = {
        poolPos = { 34, 8, -26 }, -- on tier 2 (SE)
        poolSize = { 10, 2, 8 },
        wheelPos = { 7, 4, 5 }, -- beside the pavilion, NE of bell
        wheelRadius = 4,
        -- flume runs pool → over the apron → drops onto wheel top
    },
    promontories = {
        { name = "Record", pos = { 0, 8, 64 } }, -- north (opposite entrance)
        { name = "Streak", pos = { -60, 8, 18 } }, -- west
        { name = "LocalHero", pos = { 60, 8, 18 } }, -- east
    },
    teahouses = {
        { pos = { -52, 8, -46 }, facing = 45 }, -- SW, porch faces center
        { pos = { 52, 8, -46 }, facing = -45 }, -- SE
        { pos = { -64, 14, 30 }, facing = 115 }, -- NW upper
    },
    torii = { pos = { 0, 0, -100 } },
    sando = { fromZ = -98, toZ = -44, width = 6 }, -- gate to apron edge
    stele = { pos = { -10, 0, -92 } },
    koiPond = { pos = { -70, 0, -62 }, radius = 14 },
    jumbotron = { pos = { 0, 26, 0 }, size = { 28, 9, 1 } },
    heroTile = { pos = { 0, 19, 0 }, size = { 5, 6.5, 0.8 } },
    spawn = { pos = { 0, 1, -52 } }, -- on the sandō, facing the bell
}
return ArenaLayout
```

- [ ] **Step 3: Run tests (PASS), format, commit**

```bash
cd roblox && lune run tests/run && stylua tools tests && selene tools
git add roblox/tools/builders/ArenaLayout.luau roblox/tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): ArenaLayout - coordinate authority for the ZenDojo bowl"
```

### Task 5: Terrain builder (Studio script, idempotent)

**Files:**
- Create: `roblox/tools/studio/buildTerrain.luau`

This file is *executed in Studio via MCP `execute_luau`*, not required by anything — it cannot use `require("./...")` Lune-style paths, so the layout numbers are read from the synced `ReplicatedStorage.RoshamboShared` tree? No — `ArenaLayout` lives in `tools/` (not synced). Instead the script declares `local L = { ... }` mirroring ArenaLayout's ring numbers with a header comment **"numbers come from tools/builders/ArenaLayout.luau — keep in sync by re-pasting on layout change"**. (Two consumers, one authority, manual refresh — acceptable for a build-time tool; the alternative of syncing tools/ into ReplicatedStorage ships build tooling to players.)

- [ ] **Step 1: Write `buildTerrain.luau`:**

```lua
-- Idempotent ZenDojo terrain: run via MCP execute_luau in EDIT mode.
-- Numbers from tools/builders/ArenaLayout.luau — re-paste on layout change.
local L = {
    bowlRadius = 110,
    basinRadius = 16,
    apronRadius = 42,
    tiers = { { radius = 58, height = 3 }, { radius = 76, height = 8 }, { radius = 94, height = 14 } },
    koiPond = { pos = { -70, 0, -62 }, radius = 14 },
}
local Terrain = workspace.Terrain
-- wipe the build region
Terrain:FillRegion(
    Region3.new(Vector3.new(-140, -20, -140), Vector3.new(140, 40, 140)):ExpandToGrid(4),
    4,
    Enum.Material.Air
)
-- bowl rim (outer ground ring at top tier height)
Terrain:FillCylinder(
    CFrame.new(0, L.tiers[3].height - 2, 0),
    8,
    L.bowlRadius + 30,
    Enum.Material.LeafyGrass
)
-- carve tiers: each lower tier cuts a flat-bottomed cylinder down to its height
for i = #L.tiers, 1, -1 do
    local t = L.tiers[i]
    Terrain:FillCylinder(CFrame.new(0, t.height + 14, 0), 28, t.radius, Enum.Material.Air)
    Terrain:FillCylinder(CFrame.new(0, t.height - 2, 0), 4, t.radius, Enum.Material.LeafyGrass)
end
-- apron disc (gravel floor) and basin hole + water
Terrain:FillCylinder(CFrame.new(0, 0, 0), 2, L.apronRadius, Enum.Material.Ground)
Terrain:FillCylinder(CFrame.new(0, 0.5, 0), 3, L.basinRadius, Enum.Material.Air)
Terrain:FillCylinder(CFrame.new(0, -1, 0), 2, L.basinRadius, Enum.Material.Water)
-- koi pond
Terrain:FillCylinder(CFrame.new(L.koiPond.pos[1], -0.5, L.koiPond.pos[3]), 2, L.koiPond.radius, Enum.Material.Water)
return "terrain built"
```

- [ ] **Step 2:** Run it via MCP `execute_luau` (edit mode). Expected return: `"terrain built"`.
- [ ] **Step 3:** MCP `screen_capture` from `(-150, 80, -150)` looking at `(0, 0, 0)`: a terraced green bowl, gravel disc, water basin, koi pond. Re-run the script — same result (idempotent).
- [ ] **Step 4:** Commit the script:

```bash
git add roblox/tools/studio/buildTerrain.luau
git commit -m "feat(roblox): idempotent ZenDojo terrain bowl script"
```

> The terrain lives in the user's saved Studio place, not in Rojo files. The script is the reproducible source.

### Task 6: Graybox massing + relocate stage parts — **USER GATE**

**Files:**
- Create: `roblox/tools/builders/Graybox.luau`
- Modify: `roblox/tools/genmodels.luau` (add output)
- Modify: `roblox/default.project.json` (move JumbotronBoard/HammerArm/GongPad to layout positions; add Graybox)
- Test: `roblox/tests/Graybox.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Graybox = require("../tools/builders/Graybox")
local L = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Graybox", function()
    test("emits a shell for every layout landmark", function()
        local spec = Graybox.build(L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        for _, want in { "PavilionShell", "ToriiShell", "FlumeShell", "PoolShell", "SteleShell" } do
            expect(names[want]).toBe(true)
        end
        -- one per teahouse and promontory
        expect(names["TeahouseShell1"]).toBe(true)
        expect(names["TeahouseShell3"]).toBe(true)
        expect(names["Promontory_Record"]).toBe(true)
        expect(names["Promontory_LocalHero"]).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement `Graybox.luau`** — every landmark as a gray box at ArenaLayout coordinates:

```lua
--!strict
-- Massing shells: validate scale & sightlines before any beauty work.
local Spec = require("./Spec")

local Graybox = {}
local GRAY = { 0.55, 0.55, 0.58 }

function Graybox.build(L)
    local children = {
        Spec.part("PavilionShell", {
            Size = { L.pavilion.postSpacing + 4, L.pavilion.roofHeight, L.pavilion.postSpacing + 4 },
            CFrame = Spec.cframe({ 0, L.pavilion.roofHeight / 2, 0 }),
            Color = GRAY,
            Transparency = 0.55,
            CanCollide = false,
        }),
        Spec.part("ToriiShell", {
            Size = { 14, 12, 2 },
            CFrame = Spec.cframe({ L.torii.pos[1], 6, L.torii.pos[3] }),
            Color = GRAY,
        }),
        Spec.part("FlumeShell", {
            Size = { 2, 1.5, 44 },
            CFrame = Spec.cframe({
                (L.flume.poolPos[1] + L.flume.wheelPos[1]) / 2,
                (L.flume.poolPos[2] + L.flume.wheelPos[2] + L.flume.wheelRadius) / 2 + 1,
                (L.flume.poolPos[3] + L.flume.wheelPos[3]) / 2,
            }),
            Color = GRAY,
        }),
        Spec.part("PoolShell", {
            Size = L.flume.poolSize,
            CFrame = Spec.cframe(L.flume.poolPos),
            Color = { 0.3, 0.45, 0.55 },
        }),
        Spec.part("SteleShell", {
            Size = { 4, 7, 1.2 },
            CFrame = Spec.cframe({ L.stele.pos[1], 3.5, L.stele.pos[3] }),
            Color = GRAY,
        }),
    }
    for i, t in L.teahouses do
        table.insert(
            children,
            Spec.part(`TeahouseShell{i}`, {
                Size = { 16, 9, 12 },
                CFrame = Spec.cframe({ t.pos[1], t.pos[2] + 4.5, t.pos[3] }),
                Color = GRAY,
                Transparency = 0.3,
            })
        )
    end
    for _, p in L.promontories do
        table.insert(
            children,
            Spec.part(`Promontory_{p.name}`, {
                Size = { 8, 1.5, 8 },
                CFrame = Spec.cframe({ p.pos[1], p.pos[2] + 0.75, p.pos[3] }),
                Color = { 0.45, 0.48, 0.52 },
            })
        )
    end
    return Spec.model("Graybox", children)
end

return Graybox
```

- [ ] **Step 3:** In `genmodels.luau`: add `local Graybox = require("./builders/Graybox")`, `local ArenaLayout = require("./builders/ArenaLayout")`, and `["Graybox"] = Graybox.build(ArenaLayout)` to `OUTPUTS`. Remove the `PipelineProofLantern` entry **and** its project.json reference (proof served its purpose; the lantern builder returns in Task 13). Run `lune run tools/genmodels`.

- [ ] **Step 4:** In `default.project.json`: add `"Graybox": { "$path": "assets/Graybox.model.json" }` under RoshamboStage; update placeholder CFrames to layout positions — JumbotronBoard to `[0, 26, 0, …identity]`, GongPad (bell placeholder) to `[0, 7.5, 0, 0,-1,0, 1,0,0, 0,0,1]`, HammerArm to `[0, 6.2, 9.5, …identity]`. Add a SpawnLocation entry:

```json
"ArenaSpawn": {
    "$className": "SpawnLocation",
    "$properties": { "Anchored": true, "Size": [8, 1, 8], "CFrame": [0, 1, -52, 1, 0, 0, 0, 1, 0, 0, 0, 1], "Neutral": true }
}
```

- [ ] **Step 5:** Tests + build: `cd roblox && lune run tests/run && rojo build -o /tmp/graybox.rbxl` — PASS.
- [ ] **Step 6: MCP gate:** playtest. Screenshots: (a) spawn POV down the sandō toward the bell, (b) aerial from `(-150, 90, -150)`, (c) from each teahouse shell toward bell + jumbotron (sightline check), (d) from a promontory. Verify: bell visible from all tiers/porches; the placeholder rig still draws and strikes (HammerController unaffected — same part names, new positions).
- [ ] **Step 7: USER GATE** — user walkthrough in Studio. Iterate ArenaLayout numbers (then re-run genmodels + terrain script) until scale and sightlines feel right. Only then:

```bash
cd roblox && stylua tools tests && selene tools
git add roblox/tools roblox/assets roblox/tests/Graybox.spec.luau roblox/default.project.json
git commit -m "feat(roblox): graybox massing - bowl landmarks at ArenaLayout positions"
```

---

## Pass 2 — The monument

### Task 7: Bonshō bell + shu-moku log (real geometry, controller retarget)

**Files:**
- Create: `roblox/tools/builders/Bonsho.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json` (remove GongPad/HammerArm placeholders, add Bonsho model)
- Modify: `roblox/src/client/HammerController.client.luau` (retarget part lookups)
- Test: `roblox/tests/Bonsho.spec.luau`

The bell is part-lathed: 5 stacked cylinders of varying radius (skirt → waist → shoulder) + a dome cap + the lotus **boss** (strike pad) facing the log + two crown lugs. The log is a cylinder along Z with chain links (thin cylinders) up to the pavilion beam. *(If Task 3 recorded `MESH_OK`, the bell body MAY instead be a single MeshPart whose `MeshId` is captured in the builder — the boss, lugs, and log stay parts either way. The part-built form below is the committed default.)*

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Bonsho = require("../tools/builders/Bonsho")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Bonsho builder", function()
    test("contains the two controller-contract parts: Bonsho and ShuMoku", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Bonsho"]).toBe(true)
        expect(names["ShuMoku"]).toBe(true)
    end)
    test("ShuMoku rest position matches layout", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "ShuMoku" then
                expect(c.properties.CFrame[3]).toBe(L.shuMoku.restPos[3])
            end
        end
    end)
    test("bell sections widen toward the skirt", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local radii = {}
        for _, c in spec.children :: any do
            local i = c.name:match("^BellSection(%d)$")
            if i then
                radii[tonumber(i) :: number] = c.properties.Size[2] -- cylinder: Size = {h, d, d}
            end
        end
        expect(radii[1] > radii[3]).toBe(true) -- section 1 = skirt (bottom, widest)
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement `Bonsho.luau`:**

```lua
--!strict
-- Bronze bonshō (Chion-in form): lathed sections, dome, lotus boss, crown
-- lugs; the shu-moku log on chains. Part names Bonsho and ShuMoku are the
-- HammerController contract — do not rename without retargeting it.
local Spec = require("./Spec")

local Bonsho = {}

function Bonsho.build(palette: { [string]: { number } }, L: any)
    local bronze = { 0.36, 0.30, 0.22 } -- patinated bronze (intentionally off-palette metal)
    local bx, by, bz = L.bell.pos[1], L.bell.pos[2], L.bell.pos[3]
    local h, r = L.bell.height, L.bell.radius
    -- five lathed sections bottom→top: radius factors of the classic profile
    local profile = { 1.0, 0.93, 0.88, 0.86, 0.78 }
    local sectionH = h / #profile
    local children = {}
    for i, f in profile do
        local d = 2 * r * f
        table.insert(
            children,
            Spec.part(`BellSection{i}`, {
                Size = { sectionH, d, d },
                Shape = "Cylinder",
                CFrame = Spec.cframe(
                    { bx, by - h / 2 + sectionH * (i - 0.5), bz },
                    Spec.ROT.CYL_VERTICAL
                ),
                Color = bronze,
                Material = "Metal",
            })
        )
    end
    -- dome cap + crown lug
    table.insert(children, Spec.part("BellDome", {
        Size = { 2 * r * 0.7, 1.6, 2 * r * 0.7 },
        Shape = "Ball",
        CFrame = Spec.cframe({ bx, by + h / 2, bz }),
        Color = bronze,
        Material = "Metal",
    }))
    table.insert(children, Spec.part("CrownLug", {
        Size = { 1.2, 1.4, 1.2 },
        CFrame = Spec.cframe({ bx, by + h / 2 + 1.2, bz }),
        Color = bronze,
        Material = "Metal",
    }))
    -- lotus boss: the strike pad facing the log (+Z side), gold — the mascot
    -- glyph relief lands here (brand geometry, parent spec §7)
    table.insert(children, Spec.part("LotusBoss", {
        Size = { 0.6, 1.8, 1.8 },
        Shape = "Cylinder",
        CFrame = Spec.cframe({ bx, by - h * 0.1, bz + r + 0.2 }, Spec.ROT.CYL_ALONG_Z),
        Color = palette.gold,
        Material = "Metal",
    }))
    -- the invisible controller-contract proxy spanning the bell (flash/ring anchor)
    table.insert(children, Spec.part("Bonsho", {
        Size = { h, 2 * r, 2 * r },
        Shape = "Cylinder",
        CFrame = Spec.cframe({ bx, by, bz }, Spec.ROT.CYL_VERTICAL),
        Color = bronze,
        Transparency = 1,
        CanCollide = false,
    }))
    -- shu-moku: log along Z, chains up to the (Task 8) pavilion beam
    local sp = L.shuMoku.restPos
    table.insert(children, Spec.part("ShuMoku", {
        Size = { L.shuMoku.length, 2 * L.shuMoku.radius, 2 * L.shuMoku.radius },
        Shape = "Cylinder",
        CFrame = Spec.cframe(sp, Spec.ROT.CYL_ALONG_Z),
        Color = palette.timber,
        Material = "Wood",
    }))
    for i, off in { -2.2, 2.2 } do
        table.insert(children, Spec.part(`Chain{i}`, {
            Size = { 7, 0.25, 0.25 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ sp[1], sp[2] + 3.8, sp[3] + off }, Spec.ROT.CYL_VERTICAL),
            Color = { 0.25, 0.25, 0.28 },
            Material = "Metal",
        }))
    end
    return Spec.model("BonshoRig", children)
end

return Bonsho
```

- [ ] **Step 3:** genmodels: add `["BonshoRig"] = Bonsho.build(ZenDojo.palette, ArenaLayout)`. Run it. In `default.project.json`: **delete** the `GongPad` and `HammerArm` entries, add `"BonshoRig": { "$path": "assets/BonshoRig.model.json" }`.

- [ ] **Step 4: Retarget HammerController** — the rig parts are now nested in a Model:

```lua
local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("BonshoRig")
local arm = rig:WaitForChild("ShuMoku") :: BasePart
local gong = rig:WaitForChild("Bonsho") :: BasePart
```

The chains are static placeholders this pass (the arm tweens alone, chains stay) — note a TODO comment: `-- TODO(4b Task 12): weld chains to follow the draw`.

Wait — do it now, it is two lines per chain and Task 12 is the gate: in the Heartbeat pose block and both strike tweens, the chains must follow. Simplest robust approach: parent chains as children of ShuMoku in the builder instead (`children` field on the ShuMoku spec, with relative CFrames) so they move with it automatically when the controller sets `arm.CFrame`. **Do that:** in `Bonsho.luau` build the chains as `children` of the ShuMoku part spec with CFrames relative to the log (Rojo model.json children of a Part are just child instances — they do NOT move with the parent's CFrame automatically; only Welds do that, and welded unanchored parts can't tween-anchor cleanly).

**Correction — final approach:** keep chains as separate anchored parts BUT have HammerController move them with the same offset it applies to the arm: capture `chainRest = {chain1.CFrame, chain2.CFrame}` beside `restCFrame`, and wherever the controller writes `arm.CFrame = restCFrame * X`, also write `chains[i].CFrame = chainRest[i] * X`. Three call sites: Heartbeat pose, swing tween (use a parallel tween on each chain with the same TweenInfo and `{ CFrame = chainRest[i] * CFrame.new(0, 0, -0.8) }`), recoil/settle (same pattern).

- [ ] **Step 5:** `cd roblox && lune run tests/run && rojo build -o /tmp/bell.rbxl` — PASS.
- [ ] **Step 6: MCP gate:** playtest; screenshot the bell from spawn POV and close-up at `(14, 9, 14)` looking at `(0, 7, 0)`. Full round: log draws, trembles, strikes the boss, recoils; chains track the log.
- [ ] **Step 7: Format, lint, commit**

```bash
cd roblox && stylua src tools tests && selene src tools
git add roblox/tools roblox/assets roblox/tests/Bonsho.spec.luau roblox/default.project.json roblox/src/client/HammerController.client.luau
git commit -m "feat(roblox): real bonsho rig - lathed bell, lotus boss, chained shu-moku"
```

### Task 8: Shōrō pavilion

**Files:**
- Create: `roblox/tools/builders/Shoro.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json` (add; remove Graybox's PavilionShell — see step 3)
- Test: `roblox/tests/Shoro.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Shoro = require("../tools/builders/Shoro")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Shoro builder", function()
    test("four posts at postSpacing corners", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local posts = 0
        for _, c in spec.children :: any do
            if c.name:match("^Post%d$") then
                posts += 1
                expect(math.abs(c.properties.CFrame[1])).toBe(L.pavilion.postSpacing / 2)
                expect(math.abs(c.properties.CFrame[3])).toBe(L.pavilion.postSpacing / 2)
            end
        end
        expect(posts).toBe(4)
    end)
    test("beam carries the bell: beam present above bell crown", function()
        local spec = Shoro.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "BellBeam" then
                found = true
                expect(c.properties.CFrame[2] > L.bell.pos[2] + L.bell.height / 2).toBe(true)
            end
        end
        expect(found).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement `Shoro.luau`** — 4 posts on stone plinths, ring beams, the bell-carrying crossbeam, hipped roof from 4 wedges + ridge, gold finial:

```lua
--!strict
-- Timber shōrō (bell pavilion) standing over the basin.
local Spec = require("./Spec")

local Shoro = {}

function Shoro.build(palette: { [string]: { number } }, L: any)
    local s = L.pavilion.postSpacing / 2
    local roofY = L.pavilion.roofHeight
    local timber = palette.timber
    local ink = palette.ink
    local children = {}
    local corners = { { s, s }, { s, -s }, { -s, s }, { -s, -s } }
    for i, c in corners do
        table.insert(children, Spec.part(`Plinth{i}`, {
            Size = { 2.4, 1.2, 2.4 },
            CFrame = Spec.cframe({ c[1], 0.6, c[2] }),
            Color = palette.gravel,
            Material = "Slate",
        }))
        table.insert(children, Spec.part(`Post{i}`, {
            Size = { 1.4, roofY - 1.2, 1.4 },
            CFrame = Spec.cframe({ c[1], 1.2 + (roofY - 1.2) / 2, c[2] }),
            Color = timber,
            Material = "Wood",
        }))
    end
    -- ring beams (X-pair and Z-pair) under the roof
    for i, z in { s, -s } do
        table.insert(children, Spec.part(`RingBeamX{i}`, {
            Size = { 2 * s + 2.4, 1.2, 1.4 },
            CFrame = Spec.cframe({ 0, roofY - 0.6, z }),
            Color = timber,
            Material = "Wood",
        }))
    end
    for i, x in { s, -s } do
        table.insert(children, Spec.part(`RingBeamZ{i}`, {
            Size = { 1.4, 1.2, 2 * s + 2.4 },
            CFrame = Spec.cframe({ x, roofY - 0.6, 0 }),
            Color = timber,
            Material = "Wood",
        }))
    end
    -- the beam the bell + chains hang from
    table.insert(children, Spec.part("BellBeam", {
        Size = { 2.2, 1.8, 2 * s + 2.4 },
        CFrame = Spec.cframe({ 0, roofY - 1.8, 0 }),
        Color = timber,
        Material = "Wood",
    }))
    -- hipped roof: 4 wedges meeting a ridge cap + finial
    local roofHalf = s + 4
    local pitch = 4.5
    local wedges = {
        { rot = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, pos = { 0, roofY + pitch / 2, roofHalf / 2 } }, -- +Z slope
        { rot = { -1, 0, 0, 0, 1, 0, 0, 0, -1 }, pos = { 0, roofY + pitch / 2, -roofHalf / 2 } }, -- −Z
        { rot = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }, pos = { roofHalf / 2, roofY + pitch / 2, 0 } }, -- +X
        { rot = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }, pos = { -roofHalf / 2, roofY + pitch / 2, 0 } }, -- −X
    }
    for i, w in wedges do
        table.insert(children, {
            name = `RoofWedge{i}`,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = { 2 * roofHalf, pitch, roofHalf },
                CFrame = Spec.cframe(w.pos, w.rot),
                Color = ink,
                Material = "Slate",
            },
        })
    end
    table.insert(children, Spec.part("Finial", {
        Size = { 1, 2.2, 1 },
        CFrame = Spec.cframe({ 0, roofY + pitch + 1.1, 0 }),
        Color = palette.gold,
        Material = "Metal",
    }))
    return Spec.model("Shoro", children)
end

return Shoro
```

- [ ] **Step 3:** genmodels: add `["Shoro"] = Shoro.build(ZenDojo.palette, ArenaLayout)`; **edit `Graybox.luau`** to drop `PavilionShell` from its children (the real pavilion replaces it) and update `Graybox.spec.luau` to remove `PavilionShell` from the expected list. Run genmodels; project.json: add `"Shoro": { "$path": "assets/Shoro.model.json" }`.
- [ ] **Step 4:** Tests + build PASS; MCP gate: bell hangs *inside* the pavilion, chains reach the BellBeam plausibly (adjust `Chain` length in `Bonsho.luau` if not).
- [ ] **Step 5:** Format, lint, commit: `feat(roblox): shoro pavilion - posts, bell beam, hipped roof`.

### Task 9: Waterwheel + draw machinery + WheelController

**Files:**
- Create: `roblox/tools/builders/Waterwheel.luau`
- Create: `roblox/src/client/WheelController.client.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/Waterwheel.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Waterwheel = require("../tools/builders/Waterwheel")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Waterwheel builder", function()
    test("has the spinning Wheel part centered at layout wheelPos", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "Wheel" then
                found = true
                expect(c.properties.CFrame[1]).toBe(L.flume.wheelPos[1])
                expect(c.properties.Size[2]).toBe(2 * L.flume.wheelRadius)
            end
        end
        expect(found).toBe(true)
    end)
    test("eight paddles ring the wheel", function()
        local spec = Waterwheel.build(ZenDojo.palette, L)
        local paddles = 0
        for _, c in spec.children :: any do
            if c.name:match("^Paddle%d$") then
                paddles += 1
            end
        end
        expect(paddles).toBe(8)
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement** — `Wheel` is a wide cylinder (axis X), 8 `Paddle` parts at 45° steps around it (computed positions, identity-rotation boxes are fine at this fidelity), an axle, a support A-frame, and the ratchet drum + rope (a thin part from drum toward the ShuMoku rest position):

```lua
--!strict
-- Overshot waterwheel + ratchet drum: the machine that draws the shu-moku.
local Spec = require("./Spec")

local Waterwheel = {}

function Waterwheel.build(palette: { [string]: { number } }, L: any)
    local w = L.flume.wheelPos
    local R = L.flume.wheelRadius
    local timber = palette.timber
    local children = {
        Spec.part("Wheel", {
            Size = { 1.2, 2 * R, 2 * R },
            Shape = "Cylinder",
            CFrame = Spec.cframe(w),
            Color = timber,
            Material = "Wood",
        }),
        Spec.part("Axle", {
            Size = { 4.5, 0.8, 0.8 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(w),
            Color = palette.ink,
            Material = "Metal",
        }),
        Spec.part("RatchetDrum", {
            Size = { 1.6, 1.6, 1.6 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ w[1] + 2.4, w[2], w[3] }),
            Color = palette.ink,
            Material = "Metal",
        }),
        Spec.part("DrawRope", {
            Size = { 0.25, 0.25, 11 },
            CFrame = Spec.cframe({
                (w[1] + L.shuMoku.restPos[1]) / 2 + 1.2,
                (w[2] + L.shuMoku.restPos[2]) / 2,
                (w[3] + L.shuMoku.restPos[3]) / 2,
            }),
            Color = { 0.55, 0.48, 0.35 },
            Material = "Fabric",
        }),
    }
    for i = 1, 8 do
        local a = (i - 1) * math.pi / 4
        table.insert(children, Spec.part(`Paddle{i}`, {
            Size = { 1.4, 1.8, 0.4 },
            CFrame = Spec.cframe({ w[1], w[2] + (R - 0.6) * math.cos(a), w[3] + (R - 0.6) * math.sin(a) }),
            Color = timber,
            Material = "WoodPlanks",
        }))
    end
    -- A-frame supports either side
    for i, dx in { -1.6, 1.6 } do
        table.insert(children, Spec.part(`Support{i}`, {
            Size = { 0.9, w[2] + R * 0.4, 0.9 },
            CFrame = Spec.cframe({ w[1] + dx, (w[2] + R * 0.4) / 2, w[3] }),
            Color = timber,
            Material = "Wood",
        }))
    end
    return Spec.model("Waterwheel", children)
end

return Waterwheel
```

- [ ] **Step 3: `WheelController.client.luau`** — spins Wheel+Paddles during ACTIVE (water torque), freezes at the latch (ratchet holds), resumes after reveal. It mirrors HammerController's phase tracking:

```lua
--!strict
-- Spins the waterwheel while the machine draws; ratchet-freezes at latch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Waterwheel")
local wheel = rig:WaitForChild("Wheel") :: BasePart
local hub = wheel.CFrame
local paddles: { BasePart } = {}
local paddleOffsets: { CFrame } = {}
for _, child in rig:GetChildren() do
    if child.Name:match("^Paddle%d$") then
        table.insert(paddles, child :: BasePart)
        table.insert(paddleOffsets, hub:ToObjectSpace((child :: BasePart).CFrame))
    end
end

local spinning = true
local angle = 0

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        spinning = true
    end
end)
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "latchClick" then
        spinning = false -- ratchet holds through TALLY/REVEAL
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not spinning then
        return
    end
    angle += dt * 0.9 -- rad/s: slow, heavy
    local spun = hub * CFrame.Angles(angle, 0, 0)
    wheel.CFrame = spun
    for i, p in paddles do
        p.CFrame = spun * paddleOffsets[i]
    end
end)
```

- [ ] **Step 4:** genmodels + project.json (`"Waterwheel": { "$path": "assets/Waterwheel.model.json" }`); tests + build PASS.
- [ ] **Step 5: MCP gate:** playtest — wheel turns through ACTIVE, freezes at the arena-wide latch click, resumes next round.
- [ ] **Step 6:** Format, lint, commit: `feat(roblox): waterwheel + ratchet draw machinery, spin synced to round phases`.

### Task 10: Kakehi flume + collecting pool + falling water

**Files:**
- Create: `roblox/tools/builders/Kakehi.luau`
- Modify: `roblox/tools/builders/Graybox.luau` (drop FlumeShell + PoolShell), `roblox/tests/Graybox.spec.luau`, `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/Kakehi.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local Kakehi = require("../tools/builders/Kakehi")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Kakehi builder", function()
    test("trough segments descend monotonically from pool to wheel", function()
        local spec = Kakehi.build(ZenDojo.palette, L)
        local ys = {}
        for _, c in spec.children :: any do
            local i = c.name:match("^Trough(%d)$")
            if i then
                ys[tonumber(i) :: number] = c.properties.CFrame[2]
            end
        end
        for i = 2, #ys do
            expect(ys[i] < ys[i - 1]).toBe(true)
        end
        expect(#ys >= 3).toBe(true)
    end)
    test("every trough segment clears the apron gravel (y > 2)", function()
        local spec = Kakehi.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Trough%d$") then
                expect(c.properties.CFrame[2] > 2).toBe(true)
            end
        end
    end)
    test("support posts land on integer ground (y base 0)", function()
        local spec = Kakehi.build(ZenDojo.palette, L)
        local posts = 0
        for _, c in spec.children :: any do
            if c.name:match("^FlumePost%d$") then
                posts += 1
                -- post center y == half its height → base at ground
                expect(math.abs(c.properties.CFrame[2] - c.properties.Size[2] / 2) < 0.01).toBe(true)
            end
        end
        expect(posts >= 2).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement `Kakehi.luau`** — interpolate 4 trough segments along pool→wheel-top, each a U-channel (floor part + 2 lip parts grouped as one box at this fidelity: a `Trough{i}` timber box + a `Water{i}` thin water-colored strip on top), posts where segments cross the apron, plus the `Pool` basin box and a `WaterfallAnchor` invisible part above the wheel that carries a ParticleEmitter child for the falling-water effect:

```lua
--!strict
-- Kakehi: raised timber flume flying the terrace pool's water over the
-- unbroken karesansui to the overshot wheel.
local Spec = require("./Spec")

local Kakehi = {}

local SEGMENTS = 4

function Kakehi.build(palette: { [string]: { number } }, L: any)
    local from = { L.flume.poolPos[1], L.flume.poolPos[2] + 0.8, L.flume.poolPos[3] }
    local to = { L.flume.wheelPos[1], L.flume.wheelPos[2] + L.flume.wheelRadius + 1.2, L.flume.wheelPos[3] }
    local children = {
        Spec.part("Pool", {
            Size = L.flume.poolSize,
            CFrame = Spec.cframe(L.flume.poolPos),
            Color = palette.water,
            Material = "Glass",
            Transparency = 0.25,
        }),
        Spec.part("WaterfallAnchor", {
            Size = { 1, 1, 1 },
            CFrame = Spec.cframe(to),
            Transparency = 1,
            CanCollide = false,
            children = nil,
        }),
    }
    local dx = (to[1] - from[1]) / SEGMENTS
    local dy = (to[2] - from[2]) / SEGMENTS
    local dz = (to[3] - from[3]) / SEGMENTS
    local segLen = math.sqrt(dx * dx + dz * dz) + 0.6
    local yaw = math.atan2(dx, dz)
    local cy, sy = math.cos(yaw), math.sin(yaw)
    local rot = { sy, 0, cy, 0, 1, 0, cy, 0, -sy } -- box length along the run
    for i = 1, SEGMENTS do
        local cxp = from[1] + dx * (i - 0.5)
        local cyp = from[2] + dy * (i - 0.5)
        local czp = from[3] + dz * (i - 0.5)
        table.insert(children, Spec.part(`Trough{i}`, {
            Size = { 2.2, 1.1, segLen },
            CFrame = Spec.cframe({ cxp, cyp, czp }, rot),
            Color = palette.timber,
            Material = "WoodPlanks",
        }))
        table.insert(children, Spec.part(`Water{i}`, {
            Size = { 1.5, 0.25, segLen },
            CFrame = Spec.cframe({ cxp, cyp + 0.55, czp }, rot),
            Color = palette.water,
            Material = "Glass",
            Transparency = 0.3,
            CanCollide = false,
        }))
        -- a post under each segment joint that sits over the apron/ground
        table.insert(children, Spec.part(`FlumePost{i}`, {
            Size = { 0.8, cyp - 0.55, 0.8 },
            CFrame = Spec.cframe({ cxp, (cyp - 0.55) / 2, czp }),
            Color = palette.timber,
            Material = "Wood",
        }))
    end
    return Spec.model("Kakehi", children)
end

return Kakehi
```

- [ ] **Step 3:** Drop `FlumeShell`/`PoolShell` from `Graybox.luau` + its spec expectations. genmodels (`["Kakehi"] = …`) + project.json. Tests + build PASS.
- [ ] **Step 4: Falling water particles** — append to `WheelController.client.luau` after the rig lookups:

```lua
local kakehi = stage:WaitForChild("Kakehi")
local fallAnchor = kakehi:WaitForChild("WaterfallAnchor") :: BasePart
local fall = Instance.new("ParticleEmitter")
fall.Color = ColorSequence.new(Color3.fromRGB(127, 168, 190))
fall.Size = NumberSequence.new(0.4, 0.9)
fall.Transparency = NumberSequence.new(0.4)
fall.Lifetime = NumberRange.new(0.4, 0.6)
fall.Rate = 26
fall.Speed = NumberRange.new(7, 9)
fall.EmissionDirection = Enum.NormalId.Bottom
fall.Parent = fallAnchor
```

and gate it with the ratchet: in the latch handler add `fall.Rate = 4` (trickle while held), in the ACTIVE handler `fall.Rate = 26`.

- [ ] **Step 5: MCP gate:** screenshot from spawn and from `(60, 30, -60)` looking at the flume line: pool → descending trough → water falling onto the turning wheel; gravel below unbroken.
- [ ] **Step 6:** Format, lint, commit: `feat(roblox): kakehi flume - pool, descending troughs, waterfall onto the wheel`.

### Task 11: Basin ripples + splash crown (contact upgrade)

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau` (contact block)

- [ ] **Step 1:** Replace the single-ring contact block (the `ring` local through its `task.delay(1.3, …)` destroy) with three palette-staggered rings + a splash emitter. The theme module is already syncable — add at the top of the controller:

```lua
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local WATER = Color3.new(ZenDojo.palette.water[1], ZenDojo.palette.water[2], ZenDojo.palette.water[3])
```

Contact block replacement:

```lua
            for i = 1, 3 do
                task.delay((i - 1) * 0.22, function()
                    local ring = Instance.new("Part")
                    ring.Shape = Enum.PartType.Cylinder
                    ring.Anchored = true
                    ring.CanCollide = false
                    ring.Transparency = 0.35 + (i - 1) * 0.15
                    ring.Color = WATER
                    ring.Size = Vector3.new(0.25, 2, 2)
                    ring.CFrame = CFrame.new(gong.Position.X, 0.4, gong.Position.Z)
                        * CFrame.Angles(0, 0, math.rad(90))
                    ring.Parent = workspace
                    TweenService
                        :Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
                            Size = Vector3.new(0.25, 30 - i * 4, 30 - i * 4),
                            Transparency = 1,
                        })
                        :Play()
                    task.delay(1.5, function()
                        ring:Destroy()
                    end)
                end)
            end
            local splash = Instance.new("ParticleEmitter")
            splash.Color = ColorSequence.new(WATER)
            splash.Lifetime = NumberRange.new(0.5, 0.9)
            splash.Speed = NumberRange.new(9, 14)
            splash.SpreadAngle = Vector2.new(70, 70)
            splash.Rate = 0
            splash.Parent = gong
            splash:Emit(36)
            task.delay(1.2, function()
        splash:Destroy()
            end)
```

(keep the existing PointLight flash and recoil logic around it).

- [ ] **Step 2: MCP gate:** playtest a reveal — three rings radiate across the basin, splash crown at contact.
- [ ] **Step 3:** Format, lint, commit: `feat(roblox): basin ripple rings + splash crown at bell contact`.

### Task 12: Monument gate — **USER GATE**

- [ ] **Step 1:** Full-round MCP playtest: capture (a) ACTIVE mid-draw, (b) TALLY tremble, (c) contact frame, (d) ripple decay. Wheel freezes at latch; chains track; waterfall trickles while latched.
- [ ] **Step 2:** **USER GATE** — user walkthrough of the monument. Iterate builder dimensions on feedback (re-run genmodels per change). Commit any tuning as `fix(roblox): monument tuning - <what>`.

---

## Pass 3 — The bowl

### Task 13: Terrace finish — tier walls, cushions, tea tables, lantern ring

**Files:**
- Create: `roblox/tools/builders/TerraceDressing.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/TerraceDressing.spec.luau`

- [ ] **Step 1: Failing test:**

```lua
--!strict
local harness = require("./harness")
local TerraceDressing = require("../tools/builders/TerraceDressing")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("TerraceDressing", function()
    test("places a lantern ring on each tier (8/tier)", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        local lanterns = 0
        for _, c in spec.children :: any do
            if c.name:match("^Lantern_") then
                lanterns += 1
            end
        end
        expect(lanterns).toBe(24)
    end)
    test("cushion clusters land on tier surfaces", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        local found = 0
        for _, c in spec.children :: any do
            if c.name:match("^Cushion_") then
                found += 1
                local y = c.properties.CFrame[2]
                local onATier = false
                for _, t in L.tiers do
                    if math.abs(y - (t.height + 0.25)) < 0.01 then
                        onATier = true
                    end
                end
                expect(onATier).toBe(true)
            end
        end
        expect(found > 12).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement** — reuse `StoneLantern.build` (this is why it stayed): 8 lanterns per tier at `tier.radius - 4`, angle-stepped, skipping ±20° around the sandō gap at the south; cushion clusters (flat cylinders, vermilion/ivory alternating) with low tea tables (ink boxes) at 6 spots per tier between lanterns:

```lua
--!strict
-- Tier dressing: lantern rings, cushion clusters, tea tables.
local Spec = require("./Spec")
local StoneLantern = require("./StoneLantern")

local TerraceDressing = {}

function TerraceDressing.build(palette: { [string]: { number } }, L: any)
    local children = {}
    for ti, tier in L.tiers do
        local r = tier.radius - 4
        for i = 1, 8 do
            local a = (i - 0.5) * math.pi / 4
            -- skip the sandō gap (south = −Z): angle near 3π/2
            if math.abs(a - 1.5 * math.pi) > 0.35 then
                local lantern = StoneLantern.build(palette, {
                    r * math.cos(a),
                    tier.height,
                    r * math.sin(a),
                })
                lantern.name = `Lantern_{ti}_{i}`
                table.insert(children, lantern)
            end
        end
        for i = 1, 6 do
            local a = i * math.pi / 3 + 0.26
            local cx = (r - 5) * math.cos(a)
            local cz = (r - 5) * math.sin(a)
            table.insert(children, Spec.part(`Table_{ti}_{i}`, {
                Size = { 3, 0.9, 3 },
                CFrame = Spec.cframe({ cx, tier.height + 0.45, cz }),
                Color = palette.ink,
                Material = "Wood",
            }))
            for ci, off in { { 2.6, 0 }, { -2.6, 0 }, { 0, 2.6 }, { 0, -2.6 } } do
                table.insert(children, Spec.part(`Cushion_{ti}_{i}_{ci}`, {
                    Size = { 0.5, 1.8, 1.8 },
                    Shape = "Cylinder",
                    CFrame = Spec.cframe(
                        { cx + off[1], tier.height + 0.25, cz + off[2] },
                        Spec.ROT.CYL_VERTICAL
                    ),
                    Color = if ci % 2 == 0 then palette.vermilion else palette.ivory,
                    Material = "Fabric",
                }))
            end
        end
    end
    return Spec.model("TerraceDressing", children)
end

return TerraceDressing
```

Adjust the lantern-count test if the sandō gap skips tier lanterns (8 placed minus skipped: the test count must match the implementation — compute: angles `(i-0.5)·π/4` for i=1..8; the gap condition excludes exactly one angle per tier (a=11π/8∉…)? Run the test, read the actual count, and pin the test to that number with a comment explaining the gap.)

- [ ] **Step 3:** Lantern fireboxes glow at night via their Neon material — add one PointLight per firebox at genmodels level? No — keep build-time: add to `StoneLantern.build` a `children` entry on the Firebox spec:

```lua
        -- inside the Firebox Spec.part table, add:
        children = {
            {
                name = "Glow",
                className = "PointLight",
                properties = { Brightness = 0.8, Range = 14, Color = { 0.9, 0.75, 0.45 } },
            },
        },
```

and extend `Spec.part` to pass through a `children` prop (one-line change: `properties.children` must NOT leak into properties — pull it out before the loop: `local kids = props.children; props.children = nil; … return { name = name, className = "Part", properties = properties, children = kids }`). Update `genmodels.toRojo` — it already recurses `spec.children`; verify PointLight color serializes as `Color = [r,g,b]` (Color3 shorthand — yes, same as Part Color).

- [ ] **Step 4:** genmodels + project.json (`"TerraceDressing"`); tests + build PASS; MCP gate: tiers furnished, lantern ring glowing, sandō gap clear.
- [ ] **Step 5:** Format, lint, commit: `feat(roblox): terrace dressing - lantern rings, cushions, tea tables`.

### Task 14: Teahouses (real) + vetted interior props

**Files:**
- Create: `roblox/tools/builders/Teahouse.luau`
- Modify: `roblox/tools/builders/Graybox.luau` (drop TeahouseShells), `roblox/tests/Graybox.spec.luau`, `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/Teahouse.spec.luau`

- [ ] **Step 1: Failing test** (pattern as before — assert per-teahouse: 4 walls with a door gap on the facing side, shoji panels (ivory, Transparency 0.4), porch slab toward center, noren strip over the door, hipped roof wedges; assert the porch's center is closer to the origin than the house center):

```lua
--!strict
local harness = require("./harness")
local Teahouse = require("../tools/builders/Teahouse")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Teahouse builder", function()
    test("porch faces the arena center", function()
        for _, t in L.teahouses do
            local spec = Teahouse.build(ZenDojo.palette, t)
            for _, c in spec.children :: any do
                if c.name == "Porch" then
                    local hx, hz = t.pos[1], t.pos[3]
                    local px, pz = c.properties.CFrame[1], c.properties.CFrame[3]
                    expect((px ^ 2 + pz ^ 2) < (hx ^ 2 + hz ^ 2)).toBe(true)
                end
            end
        end
    end)
    test("noren hangs over the doorway", function()
        local spec = Teahouse.build(ZenDojo.palette, L.teahouses[1])
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Noren"]).toBe(true)
        expect(names["Roof1"]).toBe(true)
    end)
end)
```

- [ ] **Step 2: Implement `Teahouse.luau`** — house body 14×8×11 at `t.pos`, rotated by `t.facing` degrees (Spec needs a yaw helper: add to `Spec.luau`:

```lua
function Spec.yaw(deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { c, 0, s, 0, 1, 0, -s, 0, c }
end
```

) — walls (timber), front wall split into two segments leaving a 4-stud door gap, two shoji windows (ivory, `Transparency = 0.4`, Material `"SmoothPlastic"`) on the side walls, `Porch` slab (4×0.6×12, wood planks) offset toward the origin along the facing direction, `Noren` (3.6×2.4×0.1, ink fabric, over the gap, `CanCollide = false`), two roof wedges. ~60 lines in the established pattern; positions all derived from `t.pos` + `Spec.yaw(t.facing)`.

- [ ] **Step 3:** genmodels emits one model per house: `["Teahouse1"] = Teahouse.build(ZenDojo.palette, ArenaLayout.teahouses[1])` (×3); Graybox drops its shells (+ spec update); project.json gains the three entries. Tests + build PASS.

- [ ] **Step 4: Interior props from the Creator Store (vetted)** — via MCP `search_creator_store` find: tea set, floor mat, hanging scroll. Vet each: creator reputation, free license, part count < 200, no scripts (inspect after `insert_from_creator_store`, **delete any Script/LocalScript/ModuleScript before accepting**). Place one set per teahouse interior in Studio, then group as `TeahouseProps` under RoshamboStage **in the place** (store assets keep their own meshes/textures; they live in the place like terrain — record asset IDs in a comment block at the top of `Teahouse.luau` for reproducibility).

- [ ] **Step 5: MCP gate:** screenshots inside a teahouse porch looking out (bell + jumbotron visible through the doorway) and from center looking up at the houses.
- [ ] **Step 6:** Format, lint, commit: `feat(roblox): teahouses - shoji, noren, porches + vetted interior props`.

---

## Pass 4 — Periphery & inhabitants

### Task 15: Torii, sandō, koi pond dressing, rocks & foliage

**Files:**
- Create: `roblox/tools/builders/Periphery.luau`
- Modify: `roblox/tools/builders/Graybox.luau` (drop ToriiShell — Graybox is now empty: **delete** `Graybox.luau`, its spec, its genmodels output, and its project.json entry), `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Test: `roblox/tests/Periphery.spec.luau`

- [ ] **Step 1: Failing test** — assert: torii has 2 pillars + 2 lintels, all vermilion; sandō pavers run from `L.sando.fromZ` to `L.sando.toZ` (count ≥ 12, alternating slight x-jitter); a `Bridge` arcs the koi pond; ≥ 10 `Rock_` parts ring the bowl exterior between apron and tier 1 in the non-sandō arc.
- [ ] **Step 2: Implement** in the established Spec pattern (~80 lines): pillars are vertical cylinders (`CYL_VERTICAL`), the curved top lintel approximated by 3 ink boxes with slight y-steps, pavers are flat gravel-colored cylinders every 4.5 studs of Z with `((i % 3) - 1) * 0.8` x-jitter, rocks are gravel/moss `Ball` parts of random-ish sizes derived from index (`2 + (i * 7 % 5) * 0.6` — deterministic, no `math.random` in builders, ever, for drift-free output), bridge from 5 stepped wood planks.
- [ ] **Step 3:** Foliage via Creator Store (vetted per Task 14 step 4 rules): 2–3 maple/pine models placed on terraces in the place; IDs recorded in `Periphery.luau`'s header comment.
- [ ] **Step 4:** genmodels + project.json; tests + build PASS; MCP gate: entrance sequence screenshot — through the torii, down the pavers, stele to the left, bowl opening up.
- [ ] **Step 5:** Format, lint, commit: `feat(roblox): periphery - torii, sando pavers, koi bridge, rocks; graybox retired`.

### Task 16: Fate models + umbrella (replace placeholder primitives)

**Files:**
- Create: `roblox/tools/builders/FateProps.luau`
- Create: `roblox/assets/replicated/` outputs (new genmodels target dir)
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json` (ReplicatedStorage gains `RoshamboAssets`), `roblox/src/shared/themes/ZenDojo.luau` (model names), `roblox/src/client/FateController.client.luau`, `roblox/src/client/TheaterController.client.luau`
- Test: `roblox/tests/FateProps.spec.luau`

- [ ] **Step 1: Failing test** — `FateProps.boulder(palette)` returns a Model named `FateBoulder` with ≥ 3 overlapping moss-flecked Ball parts (composite rock silhouette); `FateProps.washiSheet(palette)` a `FateWashi` model of 2 thin ivory parts at slight angles (fluttering sheet); `FateProps.shears(palette)` a `FateShears` model with two Blade wedges + a U-spring loop (3 thin boxes) — nigiri-basami one-piece form; `FateProps.umbrella(palette)` a `FateUmbrella` model: vermilion canopy cylinder + ivory rib ring + timber pole.

```lua
--!strict
local harness = require("./harness")
local FateProps = require("../tools/builders/FateProps")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("FateProps", function()
    test("boulder is a composite of at least 3 lobes", function()
        local spec = FateProps.boulder(ZenDojo.palette)
        expect(spec.name).toBe("FateBoulder")
        expect(#(spec.children :: any) >= 3).toBe(true)
    end)
    test("shears have two blades and a spring", function()
        local spec = FateProps.shears(ZenDojo.palette)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["BladeA"] and names["BladeB"] and names["SpringLoop"] ~= nil).toBe(true)
    end)
    test("all four props build", function()
        expect(FateProps.washiSheet(ZenDojo.palette).name).toBe("FateWashi")
        expect(FateProps.umbrella(ZenDojo.palette).name).toBe("FateUmbrella")
    end)
end)
```

- [ ] **Step 2: Implement `FateProps.luau`** (~90 lines, established pattern; all parts `CanCollide = false`, root positions at origin — these are *templates* that get cloned and positioned at runtime).
- [ ] **Step 3: genmodels** — second output dir: write these four to `assets/replicated/{Name}.model.json`. project.json, under ReplicatedStorage:

```json
"RoshamboAssets": {
    "$className": "Folder",
    "FateBoulder": { "$path": "assets/replicated/FateBoulder.model.json" },
    "FateWashi": { "$path": "assets/replicated/FateWashi.model.json" },
    "FateShears": { "$path": "assets/replicated/FateShears.model.json" },
    "FateUmbrella": { "$path": "assets/replicated/FateUmbrella.model.json" }
}
```

ZenDojo manifest models become the asset names: `models = { boulder = "FateBoulder", paperSheet = "FateWashi", shears = "FateShears", umbrella = "FateUmbrella" }`.

- [ ] **Step 4: FateController swap** — `makeEntity` clones the template when the manifest names one; primitives remain the fallback for `"0"`:

```lua
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local assetsFolder = ReplicatedStorage:WaitForChild("RoshamboAssets")

local TEMPLATE_BY_FATE: { [string]: string } = {
    fateBoulder = ZenDojo.models.boulder,
    fatePaper = ZenDojo.models.paperSheet,
    fateShears = ZenDojo.models.shears,
}

local function makeEntity(fateId: string, near: Vector3): BasePart
    local templateName = TEMPLATE_BY_FATE[fateId]
    local template = if templateName ~= "0" then assetsFolder:FindFirstChild(templateName) else nil
    if template then
        local model = template:Clone() :: Model
        local root = model:FindFirstChildWhichIsA("BasePart") :: BasePart
        model.Parent = workspace
        -- position exactly as the primitive branch does for this fateId
        if fateId == "fateBoulder" then
            model:PivotTo(CFrame.new(near + Vector3.new(math.random(-8, 8), 40, math.random(-8, 8))))
        elseif fateId == "fatePaper" then
            model:PivotTo(
                CFrame.new(near + Vector3.new(math.random(-20, 20), math.random(4, 10), math.random(-20, 20)))
            )
        else
            local at = near + Vector3.new(math.random(-10, 10), -3, math.random(-10, 10))
            model:PivotTo(CFrame.new(at))
            TweenService:Create(root, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
                Position = at + Vector3.new(0, 4, 0),
            }):Play()
        end
        return root
    end
    -- …existing primitive branches unchanged (fallback)…
end
```

**Important:** the rest of FateController homes/tweens `BasePart`s — returning the template's root keeps every downstream reference working, but cloned siblings won't follow a root `.Position` write. Convert the model to move as one: in the template builders, make every non-root part **massless and welded**: genmodels can't emit Welds practically — instead make each template a **single root part with the decorative lobes as direct children using `WeldConstraint`**… WeldConstraints also can't be emitted as JSON children with part0/part1 refs (Rojo refs require `Ref` properties — not supported in model.json shorthand). **Resolution:** templates are MODELS, and FateController moves them with `model:PivotTo` everywhere it currently writes `e.Position`. Change the flight entity type from `{ BasePart }` to `{ Model }` and replace the three `e.Position = …` write sites with `e:PivotTo(CFrame.new(...))`, reads of `e.Position` with `e:GetPivot().Position`. The primitive fallback wraps its Part in a Model (`local m = Instance.new("Model"); part.Parent = m; m.PrimaryPart = part`). `performCatch`'s Transparency fade iterates `e:GetDescendants()` filtering BaseParts. This is a mechanical refactor of ~10 lines; the M4a Doom math is untouched.

- [ ] **Step 5: TheaterController umbrella swap** — in `umbrella(character)`: when `ZenDojo.models.umbrella ~= "0"`, clone `RoshamboAssets.FateUmbrella`, `PivotTo(head.CFrame * CFrame.new(0, 3.5, 0))`, tween its canopy child's Size up with the same Back easing, destroy after 2.3s; primitive branch stays as fallback.
- [ ] **Step 6:** Tests + build PASS; MCP gate: lose a round on purpose (TEST_MODE makes the world throw predictable) — composite boulders rain, washi flutters, shears leap; SAFE shows the wagasa.
- [ ] **Step 7:** Format, lint, commit: `feat(roblox): fate props - composite boulder, washi, nigiri-basami, wagasa; controllers clone manifest assets`.

### Task 17: ChampionSeats (pure module)

**Files:**
- Create: `roblox/src/shared/ChampionSeats.luau`
- Test: `roblox/tests/ChampionSeats.spec.luau`

- [ ] **Step 1: Failing tests:**

```lua
--!strict
local harness = require("./harness")
local ChampionSeats = require("../src/shared/ChampionSeats")
local describe, test, expect = harness.describe, harness.test, harness.expect

local LEADERS = {
    { displayName = "Aiko", totalPoints = 9000, robloxId = "101", currentStreak = 2 },
    { displayName = "Brick", totalPoints = 7500, currentStreak = 11 }, -- PWA: no robloxId
    { displayName = "Cyn", totalPoints = 100, robloxId = "103", currentStreak = 4 },
}
local ROSTER = {
    { userId = "201", name = "LocalA", points = 40 },
    { userId = "202", name = "LocalB", points = 90 },
}

describe("ChampionSeats", function()
    test("record = top of leaders (already points-sorted)", function()
        local seats = ChampionSeats.resolve(LEADERS, ROSTER)
        expect(seats.record.name).toBe("Aiko")
        expect(seats.record.robloxId).toBe("101")
    end)
    test("streak = max currentStreak; PWA holder has nil robloxId", function()
        local seats = ChampionSeats.resolve(LEADERS, ROSTER)
        expect(seats.streak.name).toBe("Brick")
        expect(seats.streak.robloxId).toBe(nil)
        expect(seats.streak.streak).toBe(11)
    end)
    test("localHero = max points in roster", function()
        local seats = ChampionSeats.resolve(LEADERS, ROSTER)
        expect(seats.localHero.userId).toBe("202")
    end)
    test("empty inputs yield nil seats, not errors", function()
        local seats = ChampionSeats.resolve({}, {})
        expect(seats.record).toBe(nil)
        expect(seats.streak).toBe(nil)
        expect(seats.localHero).toBe(nil)
    end)
    test("zero streaks seat nobody", function()
        local seats = ChampionSeats.resolve({ { displayName = "Z", totalPoints = 5, currentStreak = 0 } }, {})
        expect(seats.streak).toBe(nil)
    end)
    test("one player may hold multiple seats", function()
        local solo = { { displayName = "Solo", totalPoints = 1, robloxId = "9", currentStreak = 3 } }
        local seats = ChampionSeats.resolve(solo, {})
        expect(seats.record.name).toBe("Solo")
        expect(seats.streak.name).toBe("Solo")
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement:**

```lua
--!strict
-- Resolves the three champion seats from the leaderboard payload (cross-
-- platform, points-sorted, may lack robloxId for PWA players) + the live
-- server roster. Pure; name filtering happens at the composition root.
local ChampionSeats = {}

export type Seat = { name: string, robloxId: string?, streak: number?, userId: string?, points: number? }
export type Seats = { record: Seat?, streak: Seat?, localHero: Seat? }

function ChampionSeats.resolve(
    leaders: { { displayName: string?, totalPoints: number?, robloxId: string?, currentStreak: number? } },
    roster: { { userId: string, name: string, points: number } }
): Seats
    local seats: Seats = {}
    local top = leaders[1]
    if top then
        seats.record = { name = top.displayName or "?", robloxId = top.robloxId }
    end
    local bestStreak, holder = 0, nil
    for _, l in leaders do
        if (l.currentStreak or 0) > bestStreak then
            bestStreak, holder = l.currentStreak :: number, l
        end
    end
    if holder then
        seats.streak = { name = holder.displayName or "?", robloxId = holder.robloxId, streak = bestStreak }
    end
    local bestPoints = -1
    for _, p in roster do
        if p.points > bestPoints then
            bestPoints = p.points
            seats.localHero = { name = p.name, userId = p.userId, robloxId = p.userId, points = p.points }
        end
    end
    return seats
end

return ChampionSeats
```

(Local heroes are always Roblox players, so `robloxId = userId` — the dresser treats robloxId as "can be dressed".)

- [ ] **Step 3: Run (PASS), format, lint, commit:** `feat(roblox): ChampionSeats - record/streak/localHero from leaderboard + roster`.

### Task 18: StatueDresser + pedestals + stele + composition wiring

**Files:**
- Create: `roblox/src/server/StatueDresser.luau`
- Create: `roblox/tools/builders/Champions.luau` (pedestal trio + stele slab)
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`, `roblox/src/server/main.server.luau`
- Test: `roblox/tests/StatueDresser.spec.luau`, `roblox/tests/Champions.spec.luau`

- [ ] **Step 1: Failing StatueDresser tests** — pure *plan* function: given seats + current assignments, emit minimal actions:

```lua
--!strict
local harness = require("./harness")
local StatueDresser = require("../src/server/StatueDresser")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("StatueDresser.plan", function()
    test("dresses an avatar for a roblox holder", function()
        local actions = StatueDresser.plan(
            { record = { name = "Aiko", robloxId = "101" } },
            {}
        )
        expect(#actions).toBe(3) -- record dress + streak clear + localHero clear
        local byseat = {}
        for _, a in actions do
            byseat[a.seat] = a
        end
        expect(byseat.record.kind).toBe("avatar")
        expect(byseat.record.robloxId).toBe("101")
        expect(byseat.streak.kind).toBe("clear")
    end)
    test("effigy for a PWA holder", function()
        local actions = StatueDresser.plan({ streak = { name = "Brick", streak = 11 } }, {})
        local byseat = {}
        for _, a in actions do
            byseat[a.seat] = a
        end
        expect(byseat.streak.kind).toBe("effigy")
        expect(byseat.streak.name).toBe("Brick")
    end)
    test("unchanged seat plans keep (no re-dress)", function()
        local seats = { record = { name = "Aiko", robloxId = "101" } }
        local current = { record = "rbx:101" }
        local byseat = {}
        for _, a in StatueDresser.plan(seats, current) do
            byseat[a.seat] = a
        end
        expect(byseat.record.kind).toBe("keep")
    end)
    test("holder change re-dresses", function()
        local seats = { record = { name = "New", robloxId = "555" } }
        local byseat = {}
        for _, a in StatueDresser.plan(seats, { record = "rbx:101" }) do
            byseat[a.seat] = a
        end
        expect(byseat.record.kind).toBe("avatar")
        expect(byseat.record.key).toBe("rbx:555")
    end)
end)
```

- [ ] **Step 2: Run (FAIL). Implement `StatueDresser.luau`:**

```lua
--!strict
-- Plans statue updates for the three champion pedestals. Pure: the
-- composition root executes the actions (model fetch, posing, plaques).
local StatueDresser = {}

export type Action = {
    seat: string,
    kind: "avatar" | "effigy" | "clear" | "keep",
    key: string?,
    robloxId: string?,
    name: string?,
    detail: string?, -- plaque second line, e.g. "STREAK 11"
}

local SEATS = { "record", "streak", "localHero" }

local function keyOf(seat: any): string?
    if not seat then
        return nil
    end
    return if seat.robloxId then `rbx:{seat.robloxId}` else `pwa:{seat.name}`
end

function StatueDresser.plan(seats: { [string]: any }, current: { [string]: string? }): { Action }
    local actions: { Action } = {}
    for _, seatName in SEATS do
        local seat = seats[seatName]
        local key = keyOf(seat)
        if key == nil then
            table.insert(actions, { seat = seatName, kind = if current[seatName] then "clear" else "clear" })
        elseif key == current[seatName] then
            table.insert(actions, { seat = seatName, kind = "keep", key = key })
        else
            table.insert(actions, {
                seat = seatName,
                kind = if seat.robloxId then "avatar" else "effigy",
                key = key,
                robloxId = seat.robloxId,
                name = seat.name,
                detail = if seat.streak then `STREAK {seat.streak}` elseif seat.points then `{seat.points} PTS` else nil,
            })
        end
    end
    return actions
end

return StatueDresser
```

(The double-"clear" branch is deliberate: an empty seat always plans `clear`; executing a clear on an already-empty pedestal is a no-op, which keeps plan() stateless about emptiness.)

- [ ] **Step 3: Failing Champions builder test** — pedestal per `L.promontories` entry (named `Pedestal_Record` etc.: stone base + plaque part + invisible `StatueAnchor` + `Beacon` neon ring, all CanCollide where appropriate) and `Stele` (slab + `SteleFace` part for the SurfaceGui). Assert the three pedestals land at promontory positions and the stele at `L.stele.pos`.

- [ ] **Step 4: Implement `Champions.luau`** (established pattern, ~60 lines: base 6×1.5×6 slate, plaque 2.5×1×0.2 gold on the center-facing side, `StatueAnchor` 1×1×1 invisible at base top, `Beacon` 0.4-thick neon gold cylinder ring `Transparency = 1` by default — the server reveals it when the holder is present). genmodels + project.json under RoshamboStage.

- [ ] **Step 5: Wire the composition root** — in `main.server.luau`:

(a) requires:

```lua
local ChampionSeats = require(shared:WaitForChild("ChampionSeats"))
local StatueDresser = require(script.Parent:WaitForChild("StatueDresser"))
```

(b) executor (after `filterExternalName`):

```lua
local stage = workspace:WaitForChild("RoshamboStage")
local champions = stage:WaitForChild("Champions")
local currentStatues: { [string]: string? } = {}
local SEAT_PEDESTAL = { record = "Pedestal_Record", streak = "Pedestal_Streak", localHero = "Pedestal_LocalHero" }

local function setPlaque(pedestal: Model, name: string?, detail: string?)
    local plaque = pedestal:FindFirstChild("Plaque") :: BasePart?
    if not plaque then
        return
    end
    local gui = plaque:FindFirstChildOfClass("SurfaceGui")
    if not gui then
        gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        local label = Instance.new("TextLabel")
        label.Name = "NameLine"
        label.Size = UDim2.fromScale(1, 0.6)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.TextColor3 = Color3.fromRGB(40, 36, 28)
        label.Parent = gui
        local detailLabel = label:Clone()
        detailLabel.Name = "DetailLine"
        detailLabel.Size = UDim2.fromScale(1, 0.4)
        detailLabel.Position = UDim2.fromScale(0, 0.6)
        detailLabel.Parent = gui
        gui.Parent = plaque
    end
    (gui:FindFirstChild("NameLine") :: TextLabel).Text = name or "";
    (gui:FindFirstChild("DetailLine") :: TextLabel).Text = detail or ""
end

local function clearStatue(pedestal: Model)
    local old = pedestal:FindFirstChild("Statue")
    if old then
        old:Destroy()
    end
end

local function executeStatueActions(actions: { StatueDresser.Action })
    for _, action in actions do
        local pedestal = champions:FindFirstChild(SEAT_PEDESTAL[action.seat]) :: Model?
        if not pedestal or action.kind == "keep" then
            continue
        end
        currentStatues[action.seat] = action.key
        if action.kind == "clear" then
            clearStatue(pedestal)
            setPlaque(pedestal, nil, nil)
            continue
        end
        local anchor = pedestal:FindFirstChild("StatueAnchor") :: BasePart
        task.spawn(function()
            clearStatue(pedestal)
            local statue: Model?
            if action.kind == "avatar" then
                local ok, model = pcall(function()
                    return Players:CreateHumanoidModelFromUserId(tonumber(action.robloxId) :: number)
                end)
                statue = if ok then model else nil
            end
            if not statue then
                -- effigy: stone jizō stand-in (also the avatar-fetch fallback)
                statue = Instance.new("Model")
                local body = Instance.new("Part")
                body.Shape = Enum.PartType.Cylinder
                body.Size = Vector3.new(4.2, 2.4, 2.4)
                body.Color = Color3.fromRGB(150, 148, 140)
                body.Material = Enum.Material.Slate
                body.CFrame = anchor.CFrame * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(90))
                body.Anchored = true
                body.Parent = statue
                local head = Instance.new("Part")
                head.Shape = Enum.PartType.Ball
                head.Size = Vector3.new(1.8, 1.8, 1.8)
                head.Color = body.Color
                head.Material = body.Material
                head.CFrame = anchor.CFrame * CFrame.new(0, 4.6, 0)
                head.Anchored = true
                head.Parent = statue
            else
                statue:PivotTo(anchor.CFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.pi, 0))
                for _, d in statue:GetDescendants() do
                    if d:IsA("BasePart") then
                        d.Anchored = true
                    end
                end
                local humanoid = statue:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                end
            end
            statue.Name = "Statue"
            statue.Parent = pedestal
            setPlaque(pedestal, action.name, action.detail)
        end)
    end
end

local function updateBeacons(seats: any)
    for seatName, pedestalName in SEAT_PEDESTAL do
        local pedestal = champions:FindFirstChild(pedestalName) :: Model?
        local beacon = pedestal and pedestal:FindFirstChild("Beacon") :: BasePart?
        if beacon then
            local seat = seats[seatName]
            local present = seat and seat.robloxId and playerByUserId(seat.robloxId) ~= nil
            beacon.Transparency = if present then 0.25 else 1
        end
    end
end
```

(c) in the BoardData poll loop, after `lastBoard = { … }` is computed, before `FireAllClients`:

```lua
        local roster = {}
        for _, p in Players:GetPlayers() do
            local row = profiles:get(tostring(p.UserId))
            table.insert(roster, { userId = tostring(p.UserId), name = p.DisplayName, points = row and row.totalPoints or 0 })
        end
        local rawLeaders = if res.ok and res.data.leaders then res.data.leaders else {}
        local seats = ChampionSeats.resolve(rawLeaders, roster)
        for _, seat in { seats.record, seats.streak } :: { any } do
            if seat then
                seat.name = filterExternalName(seat.name)
            end
        end
        executeStatueActions(StatueDresser.plan(seats :: any, currentStatues))
        updateBeacons(seats)
        lastBoard.champions = seats
        lastBoard.allTime = {}
        for i = 1, math.min(10, #rawLeaders) do
            table.insert(lastBoard.allTime, {
                name = filterExternalName(rawLeaders[i].displayName or "?"),
                points = rawLeaders[i].totalPoints or 0,
            })
        end
```

(d) stele writer (after `updateBeacons`):

```lua
local function updateStele(allTime: { { name: string, points: number } })
    local stele = stage:FindFirstChild("Stele")
    local face = stele and stele:FindFirstChild("SteleFace") :: BasePart?
    if not face then
        return
    end
    local gui = face:FindFirstChildOfClass("SurfaceGui")
    if not gui then
        gui = Instance.new("SurfaceGui")
        gui.Face = Enum.NormalId.Front
        local list = Instance.new("UIListLayout")
        list.Parent = gui
        for i = 1, 10 do
            local row = Instance.new("TextLabel")
            row.Name = `Row{i}`
            row.LayoutOrder = i
            row.Size = UDim2.fromScale(1, 0.1)
            row.BackgroundTransparency = 1
            row.TextScaled = true
            row.TextColor3 = Color3.fromRGB(214, 205, 184)
            row.Parent = gui
        end
        gui.Parent = face
    end
    for i = 1, 10 do
        local row = gui:FindFirstChild(`Row{i}`) :: TextLabel
        local entry = allTime[i]
        row.Text = if entry then `{i}.  {entry.name}  —  {entry.points}` else ""
    end
end
```

call `updateStele(lastBoard.allTime)` right after the champions block.

- [ ] **Step 6:** Tests + build PASS. MCP gate: playtest with the production server config — statues dress on the promontories within one poll (≤30s), plaques read, stele lists names; join as the only player → you are Local Hero, your statue appears and your beacon glows.
- [ ] **Step 7: USER GATE** — user walkthrough of fates + champions (end of Pass 4).
- [ ] **Step 8:** Format, lint, commit: `feat(roblox): champion pedestals, statue dressing, presence beacons, all-time stele`.

---

## Pass 5 — Unification

### Task 19: Audio — sourced IDs, Sfx helper, full wiring

**Files:**
- Create: `roblox/src/client/Sfx.luau`
- Modify: `roblox/src/shared/themes/ZenDojo.luau` (sound IDs), `roblox/src/client/HammerController.client.luau`, `roblox/src/client/BoardController.client.luau`, `roblox/src/client/main.client.luau`, `roblox/src/server/main.server.luau` (water ambience)
- Test: `roblox/tests/Sfx.spec.luau`

- [ ] **Step 1: Source the sounds** — via Creator Store audio search (MCP `search_creator_store`, category audio, licensed/free): one candidate each for: temple bell strike (gong), taiko drum roll (drumroll), wood block clack (clack), heavy wooden latch (latch), water splash (splash), coin drop (bank), stream/water loop (waterAmbience). Vet: monetization-safe license, duration sane (< 8s except the loop). Record the seven `rbxassetid://` IDs into `ZenDojo.luau`'s `sounds` table.
- [ ] **Step 2: Failing test for Sfx** (pure part only — the pool-limit math):

```lua
--!strict
local harness = require("./harness")
local Sfx = require("../src/client/Sfx")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Sfx.shouldPlay", function()
    test("allows up to 6 concurrent clacks", function()
        expect(Sfx.shouldPlay("clack", 5)).toBe(true)
        expect(Sfx.shouldPlay("clack", 6)).toBe(false)
    end)
    test("placeholder id never plays", function()
        expect(Sfx.idPlayable("0")).toBe(false)
        expect(Sfx.idPlayable("rbxassetid://123")).toBe(true)
    end)
end)
```

- [ ] **Step 3: Implement `Sfx.luau`** — a ModuleScript usable from any client controller (NOT a `.client.luau`):

```lua
--!strict
-- Pooled one-shot sound player. Pure decision helpers are Lune-tested; the
-- play path touches Instances and only runs under Roblox.
local Sfx = {}

local MAX_CONCURRENT: { [string]: number } = { clack = 6 }
local active: { [string]: number } = {}

function Sfx.idPlayable(id: string): boolean
    return id ~= "0" and id ~= ""
end

function Sfx.shouldPlay(kind: string, activeCount: number): boolean
    local cap = MAX_CONCURRENT[kind] or 3
    return activeCount < cap
end

function Sfx.play(kind: string, id: string, parent: Instance, volume: number?)
    if not Sfx.idPlayable(id) then
        return
    end
    local count = active[kind] or 0
    if not Sfx.shouldPlay(kind, count) then
        return
    end
    active[kind] = count + 1
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = volume or 0.6
    sound.Parent = parent
    sound.Ended:Once(function()
        active[kind] = (active[kind] or 1) - 1
        sound:Destroy()
    end)
    sound:Play()
end

return Sfx
```

- [ ] **Step 4: Wire call sites:**
  - `HammerController`: `Sfx.play("latch", ZenDojo.sounds.latch, gong, 0.8)` where `latchClick` fires; `Sfx.play("gong", ZenDojo.sounds.gong, gong, 1)` at contact (with the flash); `Sfx.play("splash", ZenDojo.sounds.splash, gong, 0.7)` with the rings.
  - `BoardController`: on each flap step batch, `Sfx.play("clack", ZenDojo.sounds.clack, board, 0.35)`.
  - `TheaterController`: on the TALLY phase cue (`Choreo.phaseCues` emits its drumroll cue kind — match the existing kind string), `Sfx.play("drumroll", ZenDojo.sounds.drumroll, workspace, 0.8)`.
  - `main.client.luau`: on `ProfileUpdate` with `source == "banked"`, `Sfx.play("bank", ZenDojo.sounds.bank, workspace, 0.8)`.
  - `main.server.luau`: at boot, if `ZenDojo.sounds.waterAmbience` is playable, create a looping `Sound` (`Looped = true, Volume = 0.35`) parented to the basin (`stage.BonshoRig.Bonsho`), `:Play()`.
- [ ] **Step 5:** Tests + build PASS. MCP gate with audio: playtest, confirm in console no `Failed to load sound` warnings; user listens (clack density, bong weight).
- [ ] **Step 6:** Format, lint, commit: `feat(roblox): zen dojo audio - sourced ids, pooled sfx, full wiring`.

### Task 20: Lighting pass + R15 pin + final tune — **USER GATE**

**Files:**
- Modify: `roblox/src/server/main.server.luau`

- [ ] **Step 1: Apply manifest lighting at boot** (after theme validation):

```lua
local Lighting = game:GetService("Lighting")
local lt = ZenDojo.lighting
Lighting.ClockTime = lt.clockTime
Lighting.Brightness = lt.brightness
Lighting.Ambient = Color3.fromRGB(lt.ambient[1], lt.ambient[2], lt.ambient[3])
Lighting.OutdoorAmbient = Color3.fromRGB(lt.outdoorAmbient[1], lt.outdoorAmbient[2], lt.outdoorAmbient[3])
```

- [ ] **Step 2: R15 pin (manual user step)** — Studio → Game Settings → Avatar → Avatar Type → **R15**. Verify in playtest: `execute_luau` → `return (game.Players:GetPlayers()[1].Character:FindFirstChildOfClass("Humanoid")).RigType.Name` → `"R15"`.
- [ ] **Step 3: Final tune session** — golden-hour screenshots from: spawn POV, teahouse porch, promontory, aerial. User adjusts `ZenDojo.lighting` values + lantern Brightness to taste (data-only edits; re-run genmodels only if lantern values changed in builders).
- [ ] **Step 4: USER GATE** — full user walkthrough at minimum graphics quality (Studio quality slider 1): wander 10 minutes, play several rounds, lose one, bank one.
- [ ] **Step 5:** Format, lint, commit: `feat(roblox): manifest-driven lighting + final zen dojo tune`.

### Task 21: Done-criteria verification

- [ ] **Step 1:** Run the full local suite:

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools && lune run tools/genmodels && git diff --exit-code assets && rojo build -o /tmp/final.rbxl
```

Expected: all green; no asset drift.

- [ ] **Step 2:** Done-criteria sweep against the spec §10 — confirm each with evidence (screenshot or test name):
  - No placeholder geometry (search project.json + place for GongPad/HammerArm/Graybox: gone)
  - Full round reads in the real set under final lighting (screenshot sequence from Task 20)
  - Manifest validation green with all-real entries (no `"0"` remains in `ZenDojo.luau` sounds/models)
  - Champions dress from live data; effigy fallback exercised (force by hand-feeding a no-robloxId leader through `ChampionSeats.resolve` in a playtest `execute_luau` snippet, or verify the unit tests + a prod leaderboard PWA entry)
  - Stele shows top-10
  - Stable at minimum graphics quality (Task 20 walkthrough)
- [ ] **Step 3:** Push and confirm `roblox-ci` green on GitHub.
- [ ] **Step 4:** Update the roadmap memory (M4b DONE, what changed, M4c contents reminder: TextChannels, self-win feedback, tremble tune).

---

## Self-review notes (already applied)

- **Spec coverage:** §2 amendments → Tasks 5/6 (layout), 10 (flume), 18 (champions), watermark deferred (no task — correct); §3 layout → Tasks 4–6, 13–15; §4 champions → Tasks 17–18; §5 art direction → palette in Task 1, used everywhere; §6 production table → Tasks 3 (mesh probe), 5 (terrain), 7–16 (builders + store vetting), 19 (audio); §7 sequence → pass structure; §8 testing → per-task Lune tests + MCP gates + CI drift check; §9 deferrals → no tasks (correct); §10 done criteria → Task 21.
- **Brand geometry note:** the parent spec's bell-boss mascot glyphs are represented by the gold `LotusBoss` in Task 7; engraving the glyph relief (ring + macron eyes, ∨ smile as raised geometry) is a Task 12 tuning item with the user present — flagged here so it isn't lost.
- **Type consistency check:** `ChampionSeats.Seats` field names (`record/streak/localHero`) match `StatueDresser.plan` seat keys and `SEAT_PEDESTAL`; builder part names (`Bonsho`, `ShuMoku`, `Wheel`, `WaterfallAnchor`, `Pedestal_*`, `StatueAnchor`, `Beacon`, `SteleFace`) match every controller/composition lookup; `FateController` entity refactor (BasePart → Model + PivotTo) is specified at its single definition site.
