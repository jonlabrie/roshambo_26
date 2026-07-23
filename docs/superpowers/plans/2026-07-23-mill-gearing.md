# Mill Gearing (Face-Cog Wheels + Lantern Pinion) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four peg-tooth bevel discs with the water-mill reference vocabulary: two through-cog face wheels combing a single tall lantern pinion on the vertical arbor.

**Architecture:** Layout-driven (`ArenaLayout.bellDrive`) through the `BellDrive` builder; `HammerController` keeps three spin groups but the jack (lantern) group turns at `LANTERN_RATIO = cogsMain/staves = 12/9` of the driver rate, and the ratio honesty test becomes cog-count based (`24/12 = REDUCTION`). The lantern arbor lives at z=9.3 (off the cam shaft's z=11 line) and starts at y=117 (off the main shaft) — both former intersections are test-pinned.

**Tech Stack:** Luau (Lune tests), Rojo genmodels, stylua + selene.

**Spec:** `docs/superpowers/specs/2026-07-23-mill-gearing-design.md` (anchor numbers as corrected at plan-writing).

## Global Constraints

- Counts/radii: FaceWheelMain r 1.6 / 12 cogs / plane z 10.65; CamFaceWheel r 3.2 / 24 cogs / plane x −13.65; lantern 9 staves ring r 0.9 at (x −15, z 9.3), flanges y 117.2 / 124.2; arbor y 117.0–124.9.
- `camFaceWheelCogs / faceWheelMainCogs == 2` mirrors `REDUCTION = 2`; `LANTERN_RATIO = 12/9`.
- Capture prefixes: cam group `^Cam` (CamFaceWheel* rides free); driver adds `^FaceWheelMain`; jack captures `^JackShaftF` + `^JackLantern` ONLY (JackFrame*/JackBand* are static).
- Gates: `lune run tests/run` all green; `lune run tools/genmodels` ×2 stable; `stylua --check src tests tools`; `selene src`. Live gate: ONE attempt, STOP, user judges.

---

### Task 1: Layout + builder + tests (TDD)

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau` (bellDrive: bevel* → wheels/lantern; jack; bearings[3])
- Modify: `roblox/tools/builders/BellDrive.luau` (bevelGear block → faceCogWheel + lantern; frame re-site)
- Modify: `roblox/tests/BellDrive.spec.luau`, `roblox/tests/ArenaLayout.spec.luau`, `roblox/tests/CenterpieceContract.spec.luau`
- Regenerate: `roblox/assets/BellDrive.model.json`

**Interfaces:**
- Produces: parts `FaceWheelMain`(+`_C1..12`), `CamFaceWheel`(+`_C1..24`, `CamFaceWheelSpoke1..3`, `CamFaceWheelHub`), `JackLanternFlange1/2`, `JackLanternStave1..9`; layout fields `faceWheelMain/faceWheelMainR/faceWheelMainCogs`, `camFaceWheel/camFaceWheelR/camFaceWheelCogs`, `lantern{x,z,staves,staveRingR,flangeR,yBottom,yTop}`, `jack{x,z=9.3,yBottom=117,yTop=124.9}`. Task 2 consumes the names + `lantern.z`.

- [ ] **Step 1: Failing tests.** In `tests/BellDrive.spec.luau`, replace the whole `describe("BellDrive drive train (jack shaft + toothed bevels)", ...)` block with:

```lua
describe("BellDrive drive train (face-cog wheels + lantern pinion)", function()
    local spec = BellDrive.build(ZenDojo.palette, L)
    local d = L.bellDrive
    local byName = {}
    local cogs = { FaceWheelMain = 0, CamFaceWheel = 0 }
    local staves = 0
    for _, c in spec.children :: any do
        byName[c.name] = c
        local stem = c.name:match("^(%a+)_C%d+$")
        if stem and cogs[stem] ~= nil then
            cogs[stem] += 1
        end
        if c.name:match("^JackLanternStave%d+$") then
            staves += 1
        end
    end
    test("the train exists by name; the peg bevels are gone", function()
        for _, want in
            {
                "MainShaft",
                "JackShaftF1",
                "JackShaftF4",
                "FaceWheelMain",
                "CamFaceWheel",
                "CamFaceWheelHub",
                "JackLanternFlange1",
                "JackLanternFlange2",
                "CamShaft",
                "CamShaftF1",
                "JackFramePost",
                "VertShaft",
                "VertPaddle",
            }
        do
            expect(byName[want] ~= nil).toBe(true)
        end
        for name in byName do
            expect(name:match("^Bevel")).toBeNil()
        end
    end)
    test("cog and stave counts state the ratio: 12 combs in, 24 combs out", function()
        expect(cogs.FaceWheelMain).toBe(d.faceWheelMainCogs)
        expect(cogs.CamFaceWheel).toBe(d.camFaceWheelCogs)
        expect(d.camFaceWheelCogs / d.faceWheelMainCogs).toBeCloseTo(2, 0.001) -- REDUCTION mirror
        expect(staves).toBe(d.lantern.staves)
    end)
    test("the arbor and cage clear both horizontal shafts (the intersection bugs)", function()
        expect(math.abs(d.camShaft.z - d.lantern.z) >= d.lantern.staveRingR + d.camShaft.r + 0.2).toBe(true)
        expect(d.jack.yBottom - 0.2 >= d.shaftFrom[2] + 0.52).toBe(true) -- arbor bottom above the main-shaft octagon
        expect(math.abs(d.bearings[3].z - d.lantern.z) >= 1.5).toBe(true) -- pillow out of the cage
    end)
    test("the wheel discs stay clear of the stave sweep", function()
        local sweepZ = d.lantern.z + d.lantern.staveRingR + 0.14 -- staves' far reach toward the main wheel
        expect(d.faceWheelMain[3] - 0.2 >= sweepZ + 0.1).toBe(true)
        local sweepX = d.lantern.x + d.lantern.staveRingR + 0.14 -- toward the cam wheel
        expect(d.camFaceWheel[1] - 0.2 >= sweepX + 0.1).toBe(true)
    end)
    test("the kick paddle and pillow blocks are unchanged", function()
        expect(byName["VertPaddle"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
        expect(byName["BearingSaddle4"].properties.CFrame[2]).toBeCloseTo(120.7, 0.001)
    end)
end)
```

In `tests/ArenaLayout.spec.luau`, in the jack-corner test replace the two
`d.jack.yBottom/yTop` closeness asserts and the `bevelR2/bevelR1` line with:

```lua
        expect(d.jack.yBottom > d.shaftFrom[2]).toBe(true) -- arbor starts ABOVE the main shaft
        expect(d.jack.yTop > d.camShaft.y).toBe(true) -- and carries the cage past the cam wheel's mesh
        expect(d.camFaceWheelCogs / d.faceWheelMainCogs).toBeCloseTo(2, 0.001) -- the reduction, in cogs
```

In `tests/CenterpieceContract.spec.luau` BellDrive requireAll: replace
`"BevelMainA", "BevelJackA", "BevelJackB", "BevelCamB",` with
`"FaceWheelMain", "CamFaceWheel", "JackLanternFlange1",` (keep `"JackShaftF1"`).

- [ ] **Step 2: RED** — `lune run tests/run` shows the new describes failing.

- [ ] **Step 3: Layout.** In `ArenaLayout.luau` `bellDrive`, replace the
`jack`/`bevel*` lines with:

```lua
        -- Vertical LANTERN ARBOR (the "single vertical gear"): OFF the cam shaft's
        -- z=11 line and STARTING ABOVE the main shaft — the old jack intersected both.
        jack = { x = -15, z = 9.3, yBottom = 117.0, yTop = 124.9 },
        -- Water-mill gearing (reference photo): two face-cog wheels comb one lantern.
        -- lantern rate = main × cogsMain/staves; cam = lantern × staves/cogsCam →
        -- cam/main = 12/24 (staves cancel) = HammerController REDUCTION = 2.
        faceWheelMain = { -15, 116, 10.65 }, -- disc plane clear of the stave sweep (z ≤ 10.34)
        faceWheelMainR = 1.6,
        faceWheelMainCogs = 12,
        camFaceWheel = { -13.65, 120.7, 11 }, -- disc plane clear of the stave sweep (x ≥ -13.96)
        camFaceWheelR = 3.2,
        camFaceWheelCogs = 24, -- /faceWheelMainCogs MIRRORS REDUCTION = 2
        lantern = { x = -15, z = 9.3, staves = 9, staveRingR = 0.9, flangeR = 1.15, yBottom = 117.2, yTop = 124.2 },
```

And `bearings[3]` z 9.0 → **6.5** (comment: `-- out of the lantern cage`).

- [ ] **Step 4: Builder.** In `BellDrive.luau` replace everything from the
`AXIS_ROT` local through the `JackBand` loop (the bevelGear helper, its four
calls, the jack-shaft loop, and the frame/bands — keep the CAM SHAFT block that
follows) with:

```lua
    local AXIS_ROT: { [string]: { number } } = {
        X = Spec.ROT.IDENTITY,
        Y = Spec.ROT.CYL_VERTICAL,
        Z = Spec.ROT.CYL_ALONG_Z,
    }
    -- Face-cog wheel (water-mill reference): a cypress disc whose rectangular cogs
    -- are mortised THROUGH the rim — bodies protrude toward the lantern cage,
    -- tails proud on the back face (individually replaceable; slight deterministic
    -- length jitter for the hand-hammered read). axis = rotation axis; towards =
    -- ±1 along it, the side the cogs work.
    local cogSeed = 4241
    local function cogJig(spread: number): number
        cogSeed = (1103515245 * cogSeed + 12345) % 2147483648
        return (cogSeed / 2147483648 - 0.5) * 2 * spread
    end
    local function faceCogWheel(name: string, pos: { number }, r: number, nCogs: number, axis: string, towards: number)
        table.insert(
            children,
            Spec.part(name, {
                Size = { 0.4, r * 2, r * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, AXIS_ROT[axis]),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
        for k = 1, nCogs do
            local a = (k - 1) * 2 * math.pi / nCogs
            local ringR = r - 0.25
            local u, v = math.cos(a) * ringR, math.sin(a) * ringR
            local len = 1.2 + cogJig(0.06)
            local bias = towards * (len / 2 - 0.4) -- protrude ~0.6 toward the cage, tail ~0.2 behind
            local off, size
            if axis == "Z" then
                off = { u, v, bias }
                size = { 0.35, 0.35, len }
            else -- "X"
                off = { bias, u, v }
                size = { len, 0.35, 0.35 }
            end
            table.insert(
                children,
                Spec.part(`{name}_C{k}`, {
                    Size = size,
                    CFrame = Spec.cframe({ pos[1] + off[1], pos[2] + off[2], pos[3] + off[3] }),
                    Color = palette.cypressWeathered,
                    Material = "Wood",
                    MaterialVariant = "CypressWeathered",
                })
            )
        end
    end
    faceCogWheel("FaceWheelMain", d.faceWheelMain, d.faceWheelMainR, d.faceWheelMainCogs, "Z", -1)
    faceCogWheel("CamFaceWheel", d.camFaceWheel, d.camFaceWheelR, d.camFaceWheelCogs, "X", -1)
    -- CamFaceWheel dressing: three through-spokes proud of the west face + iron hub
    for s = 1, 3 do
        local a = (s - 1) * math.pi / 3 + math.pi / 6
        table.insert(
            children,
            Spec.part(`CamFaceWheelSpoke{s}`, {
                Size = { 0.25, 0.5, d.camFaceWheelR * 2 - 0.6 },
                CFrame = Spec.cframe(
                    { d.camFaceWheel[1] - 0.3, d.camFaceWheel[2], d.camFaceWheel[3] },
                    rotXm(a)
                ),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    table.insert(
        children,
        Spec.part("CamFaceWheelHub", {
            Size = { 0.6, 1.8, 1.8 },
            Shape = "Cylinder",
            CFrame = Spec.cframe(d.camFaceWheel),
            Color = iron,
            Material = "Metal",
            MaterialVariant = "IronDark",
        })
    )
    -- Vertical octagonal LANTERN ARBOR (spun about Y by HammerController's jack group).
    local jk = d.jack
    local jlen = jk.yTop - jk.yBottom
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
    -- LANTERN PINION: two flange discs + a cage of staves both face wheels comb.
    local lt = d.lantern
    for i, fy in { lt.yBottom, lt.yTop } do
        table.insert(
            children,
            Spec.part(`JackLanternFlange{i}`, {
                Size = { 0.35, lt.flangeR * 2, lt.flangeR * 2 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({ lt.x, fy, lt.z }, Spec.ROT.CYL_VERTICAL),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    local staveLen = lt.yTop - lt.yBottom - 0.35
    for s = 1, lt.staves do
        local a = (s - 0.5) * 2 * math.pi / lt.staves -- half-pitch offset off the mesh azimuths
        table.insert(
            children,
            Spec.part(`JackLanternStave{s}`, {
                Size = { staveLen, 0.28, 0.28 },
                Shape = "Cylinder",
                CFrame = Spec.cframe({
                    lt.x + math.cos(a) * lt.staveRingR,
                    (lt.yBottom + lt.yTop) / 2,
                    lt.z + math.sin(a) * lt.staveRingR,
                }, Spec.ROT.CYL_VERTICAL),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    -- Corner frame: a post clear of the stave sweep, an arm over the cage, a band
    -- on the arbor's top stub (the lantern HANGS from the frame, mill-style).
    table.insert(
        children,
        Spec.part("JackFramePost", {
            Size = { 0.9, 13.9, 0.9 },
            CFrame = Spec.cframe({ -16.6, 118.45, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    table.insert(
        children,
        Spec.part("JackFrameArm", {
            Size = { 2.1, 0.5, 0.9 },
            CFrame = Spec.cframe({ -15.75, 125.05, jk.z }),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    table.insert(
        children,
        Spec.part("JackBand1", {
            Size = { 0.4, 1.2, 1.2 },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ jk.x, 124.65, jk.z }, Spec.ROT.CYL_VERTICAL),
            Color = iron,
            Material = "Metal",
            MaterialVariant = "IronDark",
        })
    )
```

(`rotXm` and `iron` already exist in the file. The old `JackBand{i}` loop is
replaced by the single top band.)

- [ ] **Step 5: GREEN** — `lune run tests/run` all pass.
- [ ] **Step 6: genmodels ×2 + lint + commit**

```bash
lune run tools/genmodels && lune run tools/genmodels && git diff --stat -- assets/
stylua src tests tools && stylua --check src tests tools && selene src
git add tools/builders/ArenaLayout.luau tools/builders/BellDrive.luau tests/BellDrive.spec.luau tests/ArenaLayout.spec.luau tests/CenterpieceContract.spec.luau assets/BellDrive.model.json ../docs/superpowers/specs/2026-07-23-mill-gearing-design.md
git commit -m "feat(roblox): mill gearing — face-cog wheels comb a lantern pinion (photo-referenced)"
```

---

### Task 2: HammerController — lantern ratio + captures + arbor mirror

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau`

- [ ] **Step 1: Constants.** `JACK_AXLE_XZ` z 11 → **9.3** (comment: mirrors
`ArenaLayout.bellDrive.lantern`); add below it:

```lua
local LANTERN_RATIO = 12 / 9 -- cogsMain/staves: the lantern spins this much faster than the main shaft
```

- [ ] **Step 2: Captures.** In `captureSpinners()`: change the jack loop match to
`part.Name:match("^JackShaftF") or part.Name:match("^JackLantern")`; change the
driver bevel match from `^BevelMainA` to `^FaceWheelMain`. (Cam group: `^Cam`
already catches `CamFaceWheel*` — no change; delete the now-dead `^BevelCamB`
and `^BevelJack` clauses.)

- [ ] **Step 3: Rate.** In the heartbeat, the jack rotation becomes:

```lua
    local jrot = CFrame.Angles(0, jackDir * driverDir * camNet * REDUCTION * LANTERN_RATIO, 0)
```

- [ ] **Step 4: Lint + tests + commit**

```bash
stylua src && stylua --check src && selene src && lune run tests/run
git add src/client/HammerController.client.luau
git commit -m "feat(roblox): HammerController — lantern pinion rate (12/9) + face-wheel captures, arbor at z9.3"
```

---

### Task 3: Live gate (user judges)

- [ ] Rojo synced; fresh Play. Check: cogs comb between staves at BOTH cage
stations without interpenetrating at rest; through-cog tails read on the wheel
backs; lantern clears the cam shaft through full revolutions; senses right
(`JackDir` live); ratio reads (cam wheel half the main wheel's rate, lantern
slightly faster than the main); kick/draw unchanged. ONE attempt, then STOP.
- [ ] Apply verdicts; after sign-off update memories (`zendojo-bell-engine`:
mill-gearing vocabulary + the three collision fixes; roadmap: gearing done).

---

## Self-Review

- **Spec coverage:** wheels/cogs/lantern/frame → Task 1; ratio + captures +
  arbor mirror → Task 2; gate → Task 3; corrected anchor numbers land in the
  layout literals; all three collision fixes are test-pinned. ✓
- **Placeholders:** none — full code for every step. ✓
- **Type consistency:** layout field names identical across layout/builder/
  tests (`faceWheelMainCogs`, `lantern.staveRingR`, `jack.z`); part names match
  between builder, tests, contract, and Task 2's capture patterns. ✓
