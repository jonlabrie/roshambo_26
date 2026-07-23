# Drive-Chain Rebuild (Gearing, Jack Shaft, Hero Snail Cam) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the bell-drive for the y=120.7 striker: a hero snail cam at dowel height that honestly pushes the draw dowel, a vertical jack shaft with two toothed bevel corners, generalized shaft bearings, the kick paddle realigned, and the tsuki-za boss seated.

**Architecture:** Geometry is layout-driven (`ArenaLayout.bellDrive`) through the `BellDrive` builder; a new pure module `CamProfile.luau` computes the spiral flank analytically from the dowel's draw path (radius under the dowel = contact radius at every draw fraction p — honesty by construction, since `HammerController` already locks cam angle to p). The controller gains a Y-axis jack spin group and updates its two hardcoded axle mirrors.

**Tech Stack:** Luau (Lune tests `lune run tests/run`), Rojo `lune run tools/genmodels`, Roblox Studio MCP for boss seating, stylua + selene.

**Spec:** `docs/superpowers/specs/2026-07-23-drive-chain-gearing-cam-design.md`

## Global Constraints

- Cam axle `(-2.75, 120.7, 8)`, axis X; dowel rest `z=11`, draw +Z 4.06, rise `0.9·p²`, dowel radius 0.25.
- Reduction split: main→jack **1:1** (r 1.2/1.2, 10/10 teeth), jack→cam **1:2** (r 1.2/2.4, 10/20 teeth) — net = controller `REDUCTION = 2`.
- Controller contract names that MUST survive: `MainShaft`, `CamShaft`, `Cam*` (cam spin capture), `VertShaft`, `VertPaddle`, `ShuMokuDrawDowel` interplay unchanged.
- `HammerController` mirrors (`CAM_AXLE_YZ`, the `anchorNet` atan2, rise 0.9, DRAW_STUDS 4.06) must change in the same plan as the layout (Task 4).
- Timing is clock-master; no HammerCurve changes, no physics.
- Run from `roblox/`. Gates: all tests pass, `lune run tools/genmodels` ×2 stable, `stylua --check src tests tools`, `selene src`. Live gates: ONE attempt, then STOP and ask the user.

---

### Task 1: `CamProfile` pure module (TDD)

**Files:**
- Create: `roblox/src/shared/CamProfile.luau`
- Create: `roblox/tests/CamProfile.spec.luau`

**Interfaces:**
- Produces: `CamProfile.contact(p, g)` → `(radius, azimuthDeg)`; `CamProfile.samples(g, n)` → array of `{ deg: number, r: number }` (flank local angle behind the cliff, contact radius). `g = { gapZ, draw, rise, dowelR, dropDeg }`. Task 3's builder and tests consume both.

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local harness = require("./harness")
local CamProfile = require("../src/shared/CamProfile")
local describe, test, expect = harness.describe, harness.test, harness.expect

local G = { gapZ = 3, draw = 4.06, rise = 0.9, dowelR = 0.25, dropDeg = 12 }

describe("CamProfile (analytic snail flank)", function()
    test("contact at rest is the base radius, dead ahead", function()
        local r, az = CamProfile.contact(0, G)
        expect(r).toBeCloseTo(3 - 0.25, 0.001) -- gapZ - dowelR = 2.75
        expect(az).toBeCloseTo(0, 0.001)
    end)
    test("contact at full draw reaches the lobe, tilted up by the pendulum rise", function()
        local r, az = CamProfile.contact(1, G)
        expect(r).toBeCloseTo(math.sqrt(7.06 ^ 2 + 0.9 ^ 2) - 0.25, 0.001) -- ≈ 6.867
        expect(az).toBeCloseTo(math.deg(math.atan2(0.9, 7.06)), 0.001) -- ≈ 7.26
    end)
    test("samples: radius monotonic, angle decreasing to the cliff, count honoured", function()
        local s = CamProfile.samples(G, 40)
        expect(#s).toBe(41)
        for i = 2, #s do
            expect(s[i].r > s[i - 1].r).toBe(true)
            expect(s[i].deg < s[i - 1].deg).toBe(true)
        end
        expect(s[1].deg).toBeCloseTo(360 - G.dropDeg, 0.001) -- rest contact sits just behind a full turn
        local _, az1 = CamProfile.contact(1, G)
        expect(s[#s].deg).toBeCloseTo(az1, 0.001) -- the flank ends at the tilted release azimuth
    end)
end)
```

- [ ] **Step 2: Run to verify RED** — `lune run tests/run` → new describe fails (module missing).

- [ ] **Step 3: Implement**

```lua
--!strict
-- Analytic snail-cam flank for the bell-drive draw. The cam axle sits at the draw
-- dowel's height, gapZ north of its rest plane; the dowel draws +Z by `draw` and
-- rises `rise·p²` on the rope arc. HammerController locks cam angle to the draw
-- fraction p (one revolution per round, peak on the dowel at the strike), so a
-- flank whose radius at local angle λ(p) equals the contact radius r(p) stays
-- visually in contact through the WHOLE draw — geometric honesty by construction.
-- Local angle convention matches the controller's anchor: 0° = the cliff/peak,
-- angles measured the same sense the cam rotates; the flank trails the cliff.
local CamProfile = {}

export type Geom = { gapZ: number, draw: number, rise: number, dowelR: number, dropDeg: number }

-- Contact radius + azimuth (degrees, from the rest direction toward the rise) at p.
function CamProfile.contact(p: number, g: Geom): (number, number)
    local dz = g.gapZ + g.draw * p
    local dy = g.rise * p * p
    return math.sqrt(dz * dz + dy * dy) - g.dowelR, math.deg(math.atan2(dy, dz))
end

-- n+1 flank samples from rest (p=0, local angle just behind a full turn) to the
-- release (p=1, local angle = the tilted contact azimuth, right at the cliff).
function CamProfile.samples(g: Geom, n: number): { { deg: number, r: number } }
    local out = {}
    for i = 0, n do
        local p = i / n
        local r, az = CamProfile.contact(p, g)
        table.insert(out, { deg = (1 - p) * (360 - g.dropDeg) + az * p, r = r })
    end
    return out
end

return CamProfile
```

(Note the sample angle: at p=0 it is `360 − dropDeg`; at p=1 it is `az(1)` — the
interpolation `(1−p)·(360−dropDeg) + az·p` is monotonic because draw dominates.)

- [ ] **Step 4: Run to verify GREEN** — `lune run tests/run` → all pass.
- [ ] **Step 5: Lint + commit**

```bash
stylua src tests && stylua --check src tests && selene src
git add src/shared/CamProfile.luau tests/CamProfile.spec.luau
git commit -m "feat(roblox): CamProfile — analytic snail flank from the dowel draw path"
```

---

### Task 2: Layout rewrite + gears/jack/shafts/bearings in BellDrive (TDD)

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau` (the `bellDrive` block; `shuMoku.drawStuds`)
- Modify: `roblox/tools/builders/BellDrive.luau` (gear/camshaft blocks + bearings loop)
- Modify: `roblox/tests/BellDrive.spec.luau` (rewrite)
- Modify: `roblox/tests/CenterpieceContract.spec.luau` (BellDrive requireAll)
- Regenerate: `roblox/assets/BellDrive.model.json`

**Interfaces:**
- Consumes: layout fields it defines below; `Spec.part/cframe/segment/matMul/rotYMat`, `Spec.ROT.CYL_ALONG_Z/CYL_VERTICAL`.
- Produces: parts `JackShaftF1-4`, `BevelMainA`(+`_T1..10`), `BevelJackA`(+`_T`), `BevelJackB`(+`_T`), `BevelCamB`(+`_T1..20`), `CamShaft` (invisible proxy) + `CamShaftF1-4`, `JackFramePost/Arm`, `JackBand1/2`, 4 generalized pillow blocks. Task 3 consumes `cam/camWidth/camHubR/camDropDeg/camDowelRise` layout fields; Task 4 consumes the part names.

- [ ] **Step 1: Rewrite `tests/BellDrive.spec.luau` (failing first)**

```lua
--!strict
local harness = require("./harness")
local BellDrive = require("../tools/builders/BellDrive")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BellDrive drive train (jack shaft + toothed bevels)", function()
    local spec = BellDrive.build(ZenDojo.palette, L)
    local byName = {}
    local counts = {}
    for _, c in spec.children :: any do
        byName[c.name] = c
        local stem = c.name:match("^(Bevel%a+)_T%d+$")
        if stem then
            counts[stem] = (counts[stem] or 0) + 1
        end
    end
    test("the train exists by name; the old placeholder gears are gone", function()
        for _, want in
            { "MainShaft", "JackShaftF1", "JackShaftF4", "BevelMainA", "BevelJackA", "BevelJackB", "BevelCamB", "CamShaft", "CamShaftF1", "CamShaftF4", "JackFramePost", "VertShaft", "VertPaddle" }
        do
            expect(byName[want] ~= nil).toBe(true)
        end
        expect(byName["DriverGear"]).toBeNil()
        expect(byName["CamGear"]).toBeNil()
    end)
    test("tooth counts state the reduction: 10/10 then 10/20", function()
        expect(counts.BevelMainA).toBe(10)
        expect(counts.BevelJackA).toBe(10)
        expect(counts.BevelJackB).toBe(10)
        expect(counts.BevelCamB).toBe(20)
        expect(L.bellDrive.bevelR2 / L.bellDrive.bevelR1).toBeCloseTo(2, 0.001) -- REDUCTION mirror
    end)
    test("the cam shaft proxy rides the cam axle line and is invisible", function()
        local cs = byName["CamShaft"].properties
        expect(cs.Transparency).toBe(1)
        expect(cs.CFrame[2]).toBeCloseTo(L.bellDrive.camShaft.y, 0.001)
        expect(cs.CFrame[3]).toBeCloseTo(L.bellDrive.camShaft.z, 0.001)
    end)
    test("the kick paddle meets the raised dowel", function()
        expect(byName["VertPaddle"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
    end)
    test("the tall cam-shaft pillow block sits under the cam shaft", function()
        expect(byName["BearingSaddle4"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
        expect(byName["BearingPost4"] ~= nil).toBe(true)
        expect(byName["BearingPlate4"] ~= nil).toBe(true)
    end)
end)
```

Also update `tests/CenterpieceContract.spec.luau` BellDrive requireAll: remove
`"DriverGear"`, `"CamGear"`; add `"BevelMainA"`, `"BevelJackA"`, `"BevelJackB"`,
`"BevelCamB"`, `"JackShaftF1"`. (Keep `CamShaft`, `MainShaft`, `Cam`, the Vert/Drive
names.)

- [ ] **Step 2: Run to verify RED.**

- [ ] **Step 3: Layout rewrite** — in `ArenaLayout.luau` replace the `bellDrive` block with:

```lua
    bellDrive = {
        -- MAIN SHAFT: along Z from the wheel, ending at the SW jack corner.
        shaftFrom = { -15, 116, -19 },
        shaftTo = { -15, 116, 8 },
        shaftR = 0.6,
        -- Vertical JACK SHAFT routes power up to the cam shaft:
        -- main (axis Z, y116) → bevel 1:1 → jack (axis Y) → bevel 1:2 → cam (axis X, y120.7)
        jack = { x = -15, z = 8, yBottom = 116, yTop = 120.7 },
        bevelMainA = { -15, 116, 6.9 }, -- on the main shaft (axis Z); rim kisses the jack-bottom bevel
        bevelJackA = { -15, 117.2, 8 }, -- jack bottom (axis Y)
        bevelJackB = { -15, 119.5, 8 }, -- jack top (axis Y)
        bevelCamB = { -13.8, 120.7, 8 }, -- on the cam shaft (axis X); the 1:2 stage
        bevelR1 = 1.2,
        bevelR2 = 2.4, -- bevelR2/bevelR1 MIRRORS HammerController REDUCTION = 2
        -- E-W CAM SHAFT at dowel height (octagonal; spun with the cam via ^Cam names).
        camShaft = { y = 120.7, z = 8, fromX = -15, toX = -1.5, r = 0.5 },
        -- HERO SNAIL CAM: axle at dowel height, 3 studs north; flank generated
        -- analytically by CamProfile from the dowel's draw path.
        cam = { -2.75, 120.7, 8 },
        camWidth = 1.6,
        camHubR = 2.0, -- hub disc; flank planks span hub→contact radius
        camDropDeg = 12, -- the cliff (release face) width
        camDowelRise = 0.9, -- MIRRORS HammerController riseY = p²·0.9
        -- KICK shaft + paddle (drum kick), paddle raised to the dowel height.
        vertBase = { 1, 112, 6 },
        vertTop = { 1, 137.6, 6 },
        vertR = 0.23,
        paddle = { 1, 120.7, 6 },
        paddleLen = 2.4,
        driveGearA = { 1, 137.5, 6 },
        driveGearAR = 1.2,
        driveGearB = { -1.18, 137.5, 7 },
        driveGearBR = 1.2,
        -- Pillow blocks, generalized: axis "Z" = main-run (shaft y116), axis "X" =
        -- the tall post under the cam shaft. baseY per entry (river bank vs clearing).
        bearings = {
            { x = -15, z = -6, y = 116, axis = "Z", baseY = 110 },
            { x = -15, z = 2, y = 116, axis = "Z", baseY = 110 },
            { x = -15, z = 6.5, y = 116, axis = "Z", baseY = 110 },
            { x = -5, z = 8, y = 120.7, axis = "X", baseY = 111.5 },
        },
    },
```

Also in `shuMoku`: `drawStuds = 6` → `drawStuds = 4.06` with the comment
`-- MIRRORS HammerController DRAW_STUDS (the cam flank is generated from this)`.
Delete the old `bearingBaseY` consumer expectation (field replaced by per-entry `baseY`).

- [ ] **Step 4: Builder rewrite (gears/shafts/bearings)** — in `BellDrive.luau`:

(a) Change `shaftTo` consumption: nothing to do (layout-driven).

(b) Replace the `DriverGear`/`CamGear`/`CamShaft` blocks (the two placeholder discs
and the iron cylinder) with:

```lua
    -- Toothed bevel gear helper: a disc plus peg teeth around the rim, axis-aligned.
    -- axis: "X" | "Y" | "Z" (the gear's rotation axis). Teeth are cylinders whose long
    -- axis matches the gear axis, so they read as bevel pegs from every side.
    local AXIS_ROT: { [string]: { number } } = {
        X = Spec.ROT.IDENTITY,
        Y = Spec.ROT.CYL_VERTICAL,
        Z = Spec.ROT.CYL_ALONG_Z,
    }
    local function bevelGear(name: string, pos: { number }, r: number, teeth: number, axis: string)
        table.insert(
            children,
            Spec.part(name, {
                Size = { 0.5, r * 2, r * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, AXIS_ROT[axis]),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
        for t = 1, teeth do
            local a = (t - 1) * 2 * math.pi / teeth
            local u, v = math.cos(a) * (r + 0.1), math.sin(a) * (r + 0.1)
            local off = if axis == "Z"
                then { u, v, 0 }
                elseif axis == "Y" then { u, 0, v }
                else { 0, u, v }
            table.insert(
                children,
                Spec.part(`{name}_T{t}`, {
                    Size = { 0.7, 0.3, 0.3 },
                    Shape = "Cylinder",
                    CFrame = Spec.cframe({ pos[1] + off[1], pos[2] + off[2], pos[3] + off[3] }, AXIS_ROT[axis]),
                    Color = iron,
                    Material = "Metal",
                    MaterialVariant = "IronDark",
                })
            )
        end
    end
    bevelGear("BevelMainA", d.bevelMainA, d.bevelR1, 10, "Z")
    bevelGear("BevelJackA", d.bevelJackA, d.bevelR1, 10, "Y")
    bevelGear("BevelJackB", d.bevelJackB, d.bevelR1, 10, "Y")
    bevelGear("BevelCamB", d.bevelCamB, d.bevelR2, 20, "X")
    -- Vertical octagonal JACK SHAFT (spun about Y by HammerController's jack group).
    local jk = d.jack
    local jlen = jk.yTop - jk.yBottom + 0.4
    for k = 1, 4 do
        table.insert(
            children,
            Spec.part(`JackShaftF{k}`, {
                Size = { jlen, 0.7, 0.29 },
                CFrame = Spec.cframe(
                    { jk.x, (jk.yBottom + jk.yTop) / 2, jk.z },
                    Spec.matMul(Spec.ROT.CYL_VERTICAL, rotXm((k - 1) * math.pi / 4))
                ),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    -- Jack corner frame: a cypress post west of the shaft with an arm + static bands.
    table.insert(
        children,
        Spec.part("JackFramePost", {
            Size = { 0.9, 9.9, 0.9 },
            CFrame = Spec.cframe({ -16.4, 115.0, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    table.insert(
        children,
        Spec.part("JackFrameArm", {
            Size = { 1.9, 0.5, 0.9 },
            CFrame = Spec.cframe({ -15.65, 119.9, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    for i, by in { 117.0, 119.9 } do
        table.insert(
            children,
            Spec.part(`JackBand{i}`, {
                Size = { 0.4, 1.2, 1.2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ jk.x, by, jk.z }, Spec.ROT.CYL_VERTICAL),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
    -- CAM SHAFT: invisible contract proxy + visible octagonal prism (^Cam names →
    -- HammerController's cam group spins them with the cam).
    local cs = d.camShaft
    local csLen = cs.toX - cs.fromX
    local csMid = { (cs.fromX + cs.toX) / 2, cs.y, cs.z }
    table.insert(
        children,
        Spec.part("CamShaft", {
            Size = { csLen, cs.r * 2, cs.r * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(csMid),
            Color = iron,
            Material = "Metal",
            Transparency = 1,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
        })
    )
    for k = 1, 4 do
        table.insert(
            children,
            Spec.part(`CamShaftF{k}`, {
                Size = { csLen, 0.85, 0.36 },
                CFrame = Spec.cframe(csMid, rotXm((k - 1) * math.pi / 4)),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
```

(`rotXm` already exists in this file from the MainShaft octagon work. `iron` is the
existing local.)

(c) Replace the bearings loop tail (currently `for i, b in d.bearings do` with
`b[1]/b[2]` pairs and `d.bearingBaseY`) with the generalized form:

```lua
    -- Pillow blocks (generalized): cypress post → square plate → static IronDark ring
    -- → wider spinning collar. axis "Z" collars spin with the main shaft
    -- (^MainShaft names); the axis "X" collar spins with the cam (^Cam name).
    for i, b in d.bearings do
        local PLATE_T = 0.2
        local pierTop = b.y - 1.55 / 2 - PLATE_T
        local bandRot = if b.axis == "Z" then Spec.ROT.CYL_ALONG_Z else Spec.ROT.IDENTITY
        table.insert(
            children,
            Spec.part(`BearingPost{i}`, {
                Size = { 0.9, pierTop - b.baseY, 0.9 },
                CFrame = Spec.cframe({ b.x, (pierTop + b.baseY) / 2, b.z }),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
        table.insert(
            children,
            Spec.part(`BearingPlate{i}`, {
                Size = { 0.9, PLATE_T, 0.9 },
                CFrame = Spec.cframe({ b.x, pierTop + PLATE_T / 2, b.z }),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
        table.insert(
            children,
            Spec.part(`BearingSaddle{i}`, {
                Size = { 0.5, 1.55, 1.55 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ b.x, b.y, b.z }, bandRot),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
        local collarName = if b.axis == "Z" then `MainShaftCollar{i}` else `CamCollar{i}`
        table.insert(
            children,
            Spec.part(collarName, {
                Size = { 0.72, 1.24, 1.24 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ b.x, b.y, b.z }, bandRot),
                Color = iron,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
```

Note the old `srot` reference for main-run bands is replaced by `Spec.ROT.CYL_ALONG_Z`
(same orientation, no dependence on the segment call). `CamCollar4` matches `^Cam` →
spins with the cam shaft automatically.

- [ ] **Step 5: Run to verify GREEN** — `lune run tests/run` (Task 3's cam tests
don't exist yet; the old cam block still builds against the new `cam` fields — if
`d.camHubR` name collisions arise, the old cam block reads `camHubR` which SURVIVES
in the new layout; `camLobeR`/`camShaftFrom` reads must be deleted with the replaced
blocks in this step). Expected: all pass.

- [ ] **Step 6: genmodels ×2 + lint + commit**

```bash
lune run tools/genmodels && lune run tools/genmodels && git diff --stat -- assets/
stylua src tests tools && stylua --check src tests tools && selene src
git add tools/builders/ArenaLayout.luau tools/builders/BellDrive.luau tests/BellDrive.spec.luau tests/CenterpieceContract.spec.luau assets/BellDrive.model.json
git commit -m "feat(roblox): jack-shaft gear tower — toothed bevels, octagonal cam shaft, generalized pillow blocks"
```

---

### Task 3: Hero cam rebuild from CamProfile (TDD)

**Files:**
- Modify: `roblox/tools/builders/BellDrive.luau` (replace the snail-cam block: the
  `FLANK`/`profileR`/`plankRot`/`Cam`/`CamEdge` section)
- Modify: `roblox/tests/BellDrive.spec.luau` (append a describe)
- Regenerate: `roblox/assets/BellDrive.model.json`

**Interfaces:**
- Consumes: `CamProfile.samples(g, n)` (Task 1), layout `cam/camWidth/camHubR/camDropDeg/camDowelRise`, `L.shuMoku.drawStuds`, `L.shuMoku.drawDowel` (z plane).
- Produces: parts `Cam` (hub), `CamEdge{n}` planks, `CamDrop` cliff wall, `CamStrap{n}` iron accents — all `^Cam` (existing controller capture).

- [ ] **Step 1: Append failing tests to `tests/BellDrive.spec.luau`**

```lua
describe("Hero snail cam (analytic flank)", function()
    local CamProfile = require("../src/shared/CamProfile")
    local spec = BellDrive.build(ZenDojo.palette, L)
    local d = L.bellDrive
    local G = {
        gapZ = L.shuMoku.drawDowel.from[3] - d.cam[3],
        draw = L.shuMoku.drawStuds,
        rise = d.camDowelRise,
        dowelR = 0.25,
        dropDeg = d.camDropDeg,
    }
    test("flank planks reach the analytic lobe and no further", function()
        local maxReach = 0
        local edges = 0
        for _, c in spec.children :: any do
            if c.name:match("^CamEdge%d+$") then
                edges += 1
                local dy = c.properties.CFrame[2] - d.cam[2]
                local dz = c.properties.CFrame[3] - d.cam[3]
                local reach = math.sqrt(dy * dy + dz * dz) + c.properties.Size[2] / 2
                if reach > maxReach then
                    maxReach = reach
                end
            end
        end
        local lobe = select(1, CamProfile.contact(1, G))
        expect(edges >= 30).toBe(true)
        expect(math.abs(maxReach - lobe) <= 0.3).toBe(true)
    end)
    test("the lobe clears the clearing floor", function()
        local lobe = select(1, CamProfile.contact(1, G))
        expect(d.cam[2] - lobe >= 112 + 1.5).toBe(true)
    end)
    test("hub and cliff exist and wear cypress/iron", function()
        local found = { Cam = false, CamDrop = false }
        for _, c in spec.children :: any do
            if found[c.name] ~= nil then
                found[c.name] = true
            end
        end
        expect(found.Cam).toBe(true)
        expect(found.CamDrop).toBe(true)
    end)
end)
```

- [ ] **Step 2: RED**, then **Step 3: replace the cam block** in `BellDrive.luau`
(everything from `-- SNAIL draw cam` through the `CamEdge` loop) with:

```lua
    -- HERO SNAIL CAM: flank generated analytically from the dowel's draw path
    -- (CamProfile) — the radius under the dowel equals the contact radius at every
    -- draw fraction, so the face visibly carries the dowel through the whole draw.
    -- All parts named ^Cam so HammerController spins them about the cam axle.
    local CamProfile = require("../../src/shared/CamProfile")
    local G = {
        gapZ = L.shuMoku.drawDowel.from[3] - d.cam[3],
        draw = L.shuMoku.drawStuds,
        rise = d.camDowelRise,
        dowelR = 0.25,
        dropDeg = d.camDropDeg,
    }
    local thick = d.camWidth
    local hubR = d.camHubR
    local ccx, ccy, ccz = d.cam[1], d.cam[2], d.cam[3]
    local function plankRot(theta: number): { number }
        local c, s = math.cos(theta), math.sin(theta)
        return { 0, 0, 1, c, -s, 0, s, c, 0 } -- columns: X=(0,c,s) Y=(0,-s,c) Z=(1,0,0)
    end
    table.insert(
        children,
        Spec.part("Cam", {
            Size = { thick, hubR * 2, hubR * 2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.cam),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    local SAMPLES = 44
    local flank = CamProfile.samples(G, SAMPLES)
    local lobe = flank[#flank].r
    for i, s in flank do
        local theta = math.rad(s.deg)
        local midR = (hubR + s.r) / 2
        table.insert(
            children,
            Spec.part(`CamEdge{i}`, {
                Size = { (s.r - hubR) + 0.2, (2 * math.pi * lobe / SAMPLES) * 1.15, thick },
                CFrame = Spec.cframe(
                    { ccx, ccy + math.cos(theta) * midR, ccz + math.sin(theta) * midR },
                    plankRot(theta)
                ),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
        if i % 4 == 1 then -- iron strap accents along the spiral rim
            table.insert(
                children,
                Spec.part(`CamStrap{i}`, {
                    Size = { 0.25, 0.5, thick + 0.1 },
                    CFrame = Spec.cframe(
                        { ccx, ccy + math.cos(theta) * (s.r - 0.2), ccz + math.sin(theta) * (s.r - 0.2) },
                        plankRot(theta)
                    ),
                    Color = palette.ink,
                    Material = "Metal",
                    MaterialVariant = "IronDark",
                })
            )
        end
    end
    -- The CLIFF: a radial wall from hub to lobe at local angle ~0 (the release face).
    table.insert(
        children,
        Spec.part("CamDrop", {
            Size = { (lobe - hubR) + 0.2, 0.5, thick },
            CFrame = Spec.cframe({ ccx, ccy + (hubR + lobe) / 2, ccz }, plankRot(0)),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
```

(The old `FLANK` table, `TIGHTEN`, `PEAK`, `DROP0`, `profileR`, `baseR`, and the
`cx/cy/cz` locals go away with the replaced block. Keep the ONE `plankRot` shown.
`require("../../src/shared/CamProfile")` — check the actual relative path other
builders use to reach `src/shared` (`ZenDojo` is required in genmodels as
`../src/shared/themes/ZenDojo` from `tools/`; from `tools/builders/` the module is
`../../src/shared/CamProfile`).)

- [ ] **Step 4: GREEN** — `lune run tests/run` all pass.
- [ ] **Step 5: genmodels ×2 + lint + commit**

```bash
lune run tools/genmodels && lune run tools/genmodels && git diff --stat -- assets/
stylua src tests tools && stylua --check src tests tools && selene src
git add tools/builders/BellDrive.luau tests/BellDrive.spec.luau assets/BellDrive.model.json
git commit -m "feat(roblox): hero snail cam at dowel height — CamProfile-generated flank, cliff, straps"
```

---

### Task 4: HammerController — axle mirrors + jack spin group

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau`

**Interfaces:**
- Consumes: part names from Tasks 2-3; layout values (cam axle (120.7, 8); jack at x=−15, z=8).
- Produces: nothing new downstream.

- [ ] **Step 1: Update the axle mirror constants**

```lua
local CAM_AXLE_YZ = Vector2.new(120.7, 8) -- E-W cam shaft: world-X axis through (y120.7, z8); MIRRORS ArenaLayout.bellDrive.camShaft
local JACK_AXLE_XZ = Vector2.new(-15, 8) -- vertical jack shaft: world-Y axis through (x-15, z8)
local JACK_DIR = -1 -- bevel corner reverses handedness (flip live if the mesh reads wrong)
```

(`MAIN_AXLE_XY` unchanged.)

- [ ] **Step 2: Update the strike anchor atan2** — in the `gongStrike` handler:

```lua
        anchorNet = math.atan2(dp.Z - CAM_AXLE_YZ.Y, dp.Y - CAM_AXLE_YZ.X) + math.rad(fineDeg)
```

(Replaces the hardcoded `dp.Z - 11, dp.Y - 116`.)

- [ ] **Step 3: Add the jack spin group.** Next to `camSpinners`/`driverSpinners`:

```lua
local jackSpinners = {} -- the vertical jack shaft + its bevels (about Y), at the driver rate
local function addJackPart(name: string)
    local part = bell and bell:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        table.insert(jackSpinners, {
            part = part,
            restCF = part.CFrame,
            pivotCF = CFrame.new(JACK_AXLE_XZ.X, part.Position.Y, JACK_AXLE_XZ.Y),
        })
    end
end
```

In `captureSpinners()` add (and clear `jackSpinners` alongside the others):

```lua
    for _, part in bell:GetChildren() do
        if part:IsA("BasePart") and (part.Name:match("^JackShaftF") or part.Name:match("^BevelJack")) then
            addJackPart(part.Name)
        end
        if part:IsA("BasePart") and part.Name:match("^BevelMainA") then
            addDriverPart(part.Name)
        end
        if part:IsA("BasePart") and part.Name:match("^BevelCamB") then
            addCamPart(part.Name)
        end
    end
```

- [ ] **Step 4: Rotate the jack group each frame.** Read the heartbeat block that
applies `camSpinners` (about X) and `driverSpinners` (about Z) rotations; add the
jack loop in the same style, rotating about **Y** by the SAME net angle the driver
group uses, times `JACK_DIR`. Pattern (adapt variable names to the block's own):

```lua
    for _, s in jackSpinners do
        s.part.CFrame = s.pivotCF
            * CFrame.Angles(0, driverNet * JACK_DIR, 0)
            * s.pivotCF:Inverse()
            * s.restCF
    end
```

- [ ] **Step 5: Lint + tests + commit**

```bash
stylua src && stylua --check src && selene src && lune run tests/run
git add src/client/HammerController.client.luau
git commit -m "feat(roblox): HammerController — cam axle mirrors to (120.7,8), jack-shaft spin group"
```

---

### Task 5: Seat the tsuki-za boss (Studio + user save)

**Files:**
- Update (place asset, user-saved): `roblox/assets/meshes/BonshoBell.rbxm`

- [ ] **Step 1: Measure and move (Studio Edit, via `execute_luau`)**

```lua
local bb = workspace.RoshamboStage.BonshoBell
local boss = bb.LotusBoss
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { bb.BellBody }
local hit = workspace:Raycast(Vector3.new(-2, 120.7, 20), Vector3.new(0, 0, -30), params)
if not hit then return "no surface hit — check BellBody" end
local surfaceZ = hit.Position.Z
boss.Position = Vector3.new(boss.Position.X, boss.Position.Y, surfaceZ + boss.Size.Y / 2 - 0.1)
return ("boss seated: surface z=%.2f, boss z=%.2f"):format(surfaceZ, boss.Position.Z)
```

(The boss is a 2×0.5×2 disc lying flat toward +Z; verify which Size component is
its thickness in-Studio and adjust the `Size.Y/2` term to the thickness axis if it
differs. Embed 0.1 into the surface.)

- [ ] **Step 2: USER saves the asset** — right-click `BonshoBell` → Save to File →
overwrite `roblox/assets/meshes/BonshoBell.rbxm` (bell precedent; binary format).

- [ ] **Step 3: Commit**

```bash
git add assets/meshes/BonshoBell.rbxm
git commit -m "fix(roblox): seat the tsuki-za lotus boss on the bell face (was floating)"
```

---

### Task 6: Live gate (user judges) + record

- [ ] **Step 1:** Rojo connected; confirm the new train in Edit (jack tower, toothed
bevels, octagonal cam shaft, hero cam, tall pillow block, kick paddle at 120.7).
- [ ] **Step 2: ONE Play attempt, then STOP.** User checks: cam face carries the
dowel through the whole draw at close zoom; cliff release reads; bevels
counter-rotate at rate (flip `JACK_DIR`/`CamPhaseDeg`/`WheelDir` attrs live if any
sense reads wrong); kick paddle meets the dowel; boss seated under the strike;
daylight lock held.
- [ ] **Step 3:** Apply verdicts one round at a time; re-gate.
- [ ] **Step 4:** After sign-off: update memories (`roshambo-roadmap`: drive-chain
rebuilt, T8-visual complete; `zendojo-bell-engine`: new cam/jack geometry, mirrors
list) and commit any tuning.

---

## Self-Review

- **Spec coverage:** anchor numbers → Tasks 2-3 literals; CamProfile → Task 1;
  bevels/jack/bearings → Task 2; cam → Task 3; controller mirrors + jack group →
  Task 4; boss → Task 5; live gate → Task 6. Out-of-scope items absent. ✓
- **Placeholders:** Task 4 Step 4 adapts to the heartbeat block's local names by
  instruction with the invariant stated — deliberate, since that block is read at
  execution time; all other steps carry full literals. ✓
- **Type consistency:** `bearings` entries `{x, z, y, axis, baseY}` match between
  layout (Task 2 Step 3) and builder loop (Step 4c); `G` construction identical in
  Task 3 builder and tests; part names align across Tasks 2/3/4 and the contract
  list. `camHubR` retained in the new layout for the hub disc. ✓
