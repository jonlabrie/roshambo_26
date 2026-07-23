# Shu-moku Striker Assembly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the shu-moku strike to the tsuki-za boss height (y=120.7), replace the freestanding gantry with tower-hung hemp-rope suspension, and fully dress the log — establishing the height the next task's gearing rebuild targets.

**Architecture:** All geometry is data-driven from `ArenaLayout.shuMoku` through the `Bonsho` builder (Rojo-synced `BonshoRig`); `HammerController.client.luau` animates the log and carries **inlined mirrors** of the chain constants that MUST change in the same task. A new `HempRope` MaterialVariant (Fabric base, ambientCG Rope001) is place-state, like the existing five.

**Tech Stack:** Luau (Lune tests via `lune run tests/run`), Rojo model.json via `lune run tools/genmodels`, Roblox Studio MCP (`upload_image`, `execute_luau`) for the material, stylua + selene.

**Spec:** `docs/superpowers/specs/2026-07-23-shu-moku-striker-assembly-design.md`

## Global Constraints

- Strike centreline **y = 120.7** (tsuki-za boss, measured); rest pos `(-2, 120.7, 9)`.
- Controller contract names unchanged: `Bonsho`, `ShuMoku`, `ShuMokuDrawDowel`, `ShuMokuDowel`, `Chain1-4`.
- `HammerController` cannot `require` builders — its inlined chain constants mirror `ArenaLayout.shuMoku` and must be updated in lockstep (Task 3).
- Run everything from `roblox/`. Gates: `lune run tests/run` (all pass), `lune run tools/genmodels` ×2 (stable diff), `stylua --check src tests tools`, `selene src`.
- Live-gate discipline: ONE visual attempt, then STOP and ask the user (standing rule).
- The cam/draw geometry is NOT realigned here (next task); the kick/draw dowels just rise with the log.

---

### Task 1: HempRope MaterialVariant (uploads are moderation-gated — do this first)

**Files:**
- Modify: `roblox/tools/studio/setupCenterpieceMaterials.luau` (add one SPECS entry)
- Source textures: `roshambo_reference/Rope001_1K-PNG/` (repo root, untracked)

**Interfaces:**
- Produces: place-state MaterialVariant named `"HempRope"`, `BaseMaterial = Fabric`. Tasks 2/3 set `Material = "Fabric"`, `MaterialVariant = "HempRope"` on rope parts.

- [ ] **Step 1: Serve the texture folder over localhost**

```bash
cd "/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roshambo_reference/Rope001_1K-PNG" && python3 -m http.server 8765
```
(Background it; `upload_image` needs http URLs, not file paths.)

- [ ] **Step 2: Upload the four maps via the Roblox Studio MCP**

Call `upload_image` for each of:
- `http://localhost:8765/Rope001_1K-PNG_Color.png`
- `http://localhost:8765/Rope001_1K-PNG_NormalGL.png` (GL, not DX)
- `http://localhost:8765/Rope001_1K-PNG_Roughness.png`
- `http://localhost:8765/Rope001_1K-PNG_Metalness.png`

Record the four `rbxassetid://` ids. NOTE: freshly uploaded images render BLANK until moderation approves (minutes) — upload now, verify at the Task 4 gate.

- [ ] **Step 3: Add the SPECS entry**

In `tools/studio/setupCenterpieceMaterials.luau`, append to `SPECS` (paste the real ids):

```lua
    {
        name = "HempRope", -- shu-moku hanger ropes + whipping collars
        base = Enum.Material.Fabric,
        tile = 1.0, -- tune at the live gate; world-space projection (rotate maps 90° like CypressVertical if the strands read sideways on the vertical drops)
        color = "rbxassetid://UPLOADED_COLOR_ID",
        normal = "rbxassetid://UPLOADED_NORMALGL_ID",
        metal = "rbxassetid://UPLOADED_METALNESS_ID",
        rough = "rbxassetid://UPLOADED_ROUGHNESS_ID",
    },
```

- [ ] **Step 4: Run the tool in Studio (Edit mode)**

Via `execute_luau` (datamodel Edit): run the full contents of `setupCenterpieceMaterials.luau`, then verify:

```lua
local mv = game:GetService("MaterialService"):FindFirstChild("HempRope")
return mv and ("ok base=" .. tostring(mv.BaseMaterial)) or "MISSING"
```
Expected: `ok base=Enum.Material.Fabric`. Remind the user the place must be SAVED to persist it.

- [ ] **Step 5: Commit**

```bash
git add tools/studio/setupCenterpieceMaterials.luau
git commit -m "feat(roblox): HempRope MaterialVariant (ambientCG Rope001, Fabric base) for the striker rigging"
```

---

### Task 2: ArenaLayout + Bonsho builder — tower suspension, hemp ropes, dressed log (TDD)

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau` (the `shuMoku` block, ~lines 60-88)
- Modify: `roblox/tools/builders/Bonsho.luau` (replace lines ~100-170: gantry/rails/chains)
- Modify: `roblox/tests/Bonsho.spec.luau` (replace the `"Bonsho dowel + gantry"` describe)
- Modify: `roblox/tests/CenterpieceContract.spec.luau` (extend the BonshoRig requireAll)
- Regenerate: `roblox/assets/BonshoRig.model.json` (via genmodels)

**Interfaces:**
- Consumes: `HempRope` variant (Task 1); `Spec.part/cframe/rotY/rotYMat/matMul/segment`, `Spec.ROT.CYL_ALONG_Z`; `L.pavilion.{pos,postSpacing}`.
- Produces: parts `HangerBeam`, `Spreader1`, `Spreader2`, `RopeEye1-4`, dress parts `ShuMokuD_Nose`, `ShuMokuD_Band1`, `ShuMokuD_Band2`, `ShuMokuD_Whip1`, `ShuMokuD_Whip2`, `ShuMokuD_TailRing` (Task 3 WaitForChild's the six dress names). Layout fields `shuMoku.hangerY`, updated `chainTops` (y 132) / `chainBottomsRest` (y 121.3) / `restPos` (y 120.7) / dowels (y 120.7); `railX/railY/railZ/ropeBottomRest` REMOVED.

- [ ] **Step 1: Write the failing tests**

In `roblox/tests/Bonsho.spec.luau`, replace the entire `describe("Bonsho dowel + gantry", ...)` block (lines 55-74) with:

```lua
describe("Shu-moku striker assembly (tower-hung, boss-height)", function()
    local STRIKE_Y = 120.7 -- tsuki-za LotusBoss centre, measured in place
    local spec = Bonsho.build(ZenDojo.palette, L)
    local byName = {}
    for _, c in spec.children :: any do
        byName[c.name] = c
    end
    test("the log rests at the boss strike height and the dowels ride with it", function()
        expect(math.abs(byName["ShuMoku"].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
        expect(math.abs(byName["ShuMokuDrawDowel"].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
        expect(math.abs(byName["ShuMokuDowel"].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
    end)
    test("the freestanding gantry is gone; the tower suspension exists", function()
        for _, c in spec.children :: any do
            expect(c.name:match("^Rail%d$")).toBeNil()
            expect(c.name:match("^GantryPost")).toBeNil()
            expect(c.name:match("^GantryBrace")).toBeNil()
        end
        expect(byName["HangerBeam"] ~= nil).toBe(true)
        expect(byName["Spreader1"] ~= nil).toBe(true)
        expect(byName["Spreader2"] ~= nil).toBe(true)
        for i = 1, 4 do
            expect(byName["RopeEye" .. i] ~= nil).toBe(true)
        end
        -- the hanger beam spans the two +Z pavilion posts, just under the ring beams
        local hb = byName["HangerBeam"].properties
        expect(hb.CFrame[2]).toBeCloseTo(L.shuMoku.hangerY, 0.001)
        expect(hb.Size[1] >= L.pavilion.postSpacing).toBe(true)
    end)
    test("the four hangers are hemp ropes dropping from the spreaders to the log", function()
        for i = 1, 4 do
            local ch = byName["Chain" .. i].properties
            expect(ch.Material).toBe("Fabric")
            expect(ch.MaterialVariant).toBe("HempRope")
            expect(ch.Size[2]).toBeCloseTo(0.35, 0.001)
            expect(ch.Size[1] > 9).toBe(true) -- long tower drop, not the old 6-stud gantry chain
        end
    end)
    test("the log is fully dressed: nose cap, bands, whipping, tail ring", function()
        expect(byName["ShuMokuD_Nose"].properties.MaterialVariant).toBe("BronzePatina")
        expect(byName["ShuMokuD_Band1"].properties.MaterialVariant).toBe("IronDark")
        expect(byName["ShuMokuD_Band2"].properties.MaterialVariant).toBe("IronDark")
        expect(byName["ShuMokuD_Whip1"].properties.MaterialVariant).toBe("HempRope")
        expect(byName["ShuMokuD_Whip2"].properties.MaterialVariant).toBe("HempRope")
        expect(byName["ShuMokuD_TailRing"].properties.MaterialVariant).toBe("IronDark")
        -- dress rings sit on the log's centreline height
        for _, n in { "ShuMokuD_Band1", "ShuMokuD_Whip1", "ShuMokuD_TailRing" } do
            expect(math.abs(byName[n].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
        end
    end)
end)
```

In `roblox/tests/CenterpieceContract.spec.luau`, extend the BonshoRig requireAll list by adding after `"Chain4",`:

```lua
            "HangerBeam",
            "Spreader1",
            "Spreader2",
```

- [ ] **Step 2: Run tests, verify RED**

Run: `lune run tests/run` — expect failures in the new describe (missing fields/parts), everything else green.

- [ ] **Step 3: Update the layout**

In `roblox/tools/builders/ArenaLayout.luau`, replace the whole `shuMoku = { ... }` block with:

```lua
    -- shu-moku striker, tower-hung (2026-07-23): strikes the tsuki-za boss at y120.7
    -- (bell raised +2.7 in T5; the old y118 hit ~1 stud above the mouth rim). Ropes
    -- drop from spreader arms on a hanger beam spanning the two +Z pavilion posts
    -- (z=+9 sits between the chain planes 7.5/11.5). The cam/draw realignment to this
    -- height is the NEXT task; the dowels simply rise with the log.
    shuMoku = {
        restPos = { -2, 120.7, 9 },
        length = 7,
        radius = 0.8,
        drawStuds = 6,
        yaw = 0,
        hangerY = 132, -- hanger-beam centreline, just under the ring beams (~134)
        chainTops = { { 2, 132, 7.5 }, { 2, 132, 11.5 }, { -6, 132, 7.5 }, { -6, 132, 11.5 } },
        chainBottomsRest = {
            { -1.2, 121.3, 7.5 },
            { -1.2, 121.3, 11.5 },
            { -2.8, 121.3, 7.5 },
            { -2.8, 121.3, 11.5 },
        },
        -- DRAW dowel: short peg out the tail reaching West to the BellDrive cam.
        drawDowel = { from = { -1.5, 120.7, 11 }, to = { -4, 120.7, 11 } },
        -- KICK dowel: short east-flank peg that kicks the vertical-shaft paddle.
        kickDowel = { from = { -1.5, 120.7, 6 }, to = { 0.75, 120.7, 6 } },
    },
```

(`railX/railY/railZ` and `ropeBottomRest` are deleted — `ropeBottomRest` has no consumers; the rails are replaced by the tower suspension.)

- [ ] **Step 4: Rewrite the builder's suspension + add the dress**

In `roblox/tools/builders/Bonsho.luau`, replace everything from the `-- Gantry:` comment (line ~100) through the end of the chain loop (line ~170, just before `return Spec.model(...)`) with:

```lua
    -- Tower-hung suspension: a cypress hanger beam spans the two +Z pavilion posts,
    -- two spreader arms bridge the chain planes (post plane z=+9 sits between them),
    -- and iron eyes take the four hemp-rope drops. The freestanding gantry is gone.
    local sm = L.shuMoku
    local yaw = sm.yaw
    local px = L.pavilion.postSpacing / 2
    local hemp = { 0.76, 0.66, 0.47 }
    local beamP = Spec.rotY({ L.pavilion.pos[1], sm.hangerY, L.pavilion.pos[3] + px }, yaw)
    table.insert(
        children,
        Spec.part("HangerBeam", {
            Size = { 2 * px + 2.4, 1.2, 1.4 },
            CFrame = Spec.cframe(beamP, Spec.rotYMat(yaw)),
            Color = palette.cypressWeathered,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )
    local spreadZ = (sm.chainTops[1][3] + sm.chainTops[2][3]) / 2 -- 9.5: chain-plane midpoint
    local spreadLen = sm.chainTops[2][3] - sm.chainTops[1][3] + 2 -- spans both planes + overhang
    for i, sx in { sm.chainTops[1][1], sm.chainTops[3][1] } do -- x = 2 and -6
        local p = Spec.rotY({ sx, sm.hangerY - 1.1, spreadZ }, yaw)
        table.insert(
            children,
            Spec.part(`Spreader{i}`, {
                Size = { 1.0, 1.0, spreadLen },
                CFrame = Spec.cframe(p, Spec.rotYMat(yaw)),
                Color = palette.cypressWeathered,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end
    for i = 1, 4 do
        local e = Spec.rotY({ sm.chainTops[i][1], sm.chainTops[i][2] - 0.35, sm.chainTops[i][3] }, yaw)
        table.insert(
            children,
            Spec.part(`RopeEye{i}`, {
                Size = { 0.5, 0.55, 0.55 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(e),
                Color = palette.ink,
                Material = "Metal",
                MaterialVariant = "IronDark",
            })
        )
    end
    -- 4 hemp-rope hangers: fixed spreader eyes down to the log's rest attach points.
    for i = 1, 4 do
        local top = Spec.rotY(sm.chainTops[i], yaw)
        local bot = Spec.rotY(sm.chainBottomsRest[i], yaw)
        local pos, len, rot = Spec.segment(top, bot)
        table.insert(
            children,
            Spec.part(`Chain{i}`, {
                Size = { len, 0.35, 0.35 },
                Shape = "Cylinder",
                CFrame = Spec.cframe(pos, rot),
                Color = hemp,
                Material = "Fabric",
                MaterialVariant = "HempRope",
            })
        )
    end
    -- Full-dress fittings, rigid to the log (HammerController re-applies the log's
    -- delta each frame): domed bronze nose at the striking (-Z) end, iron bands,
    -- hemp whipping at the rope stations, iron tail ring where the draw leads off.
    local cx2, cy2 = sm.restPos[1], sm.restPos[2]
    local function logRing(name: string, z: number, od: number, w: number, variant: string, color: { number })
        local p = Spec.rotY({ cx2, cy2, z }, yaw)
        table.insert(
            children,
            Spec.part(name, {
                Size = { w, od, od },
                Shape = "Cylinder",
                CFrame = Spec.cframe(p, logRot),
                Color = color,
                Material = if variant == "HempRope" then "Fabric" else "Metal",
                MaterialVariant = variant,
            })
        )
    end
    local noseP = Spec.rotY({ cx2, cy2, sm.restPos[3] - sm.length / 2 + 0.15 }, yaw)
    table.insert(
        children,
        Spec.part("ShuMokuD_Nose", {
            Size = { 1.7, 1.7, 1.7 },
            Shape = "Ball",
            CFrame = Spec.cframe(noseP),
            Color = palette.bronzePatina,
            Material = "Metal",
            MaterialVariant = "BronzePatina",
        })
    )
    logRing("ShuMokuD_Band1", sm.restPos[3] - 0.6, 1.75, 0.35, "IronDark", palette.ink)
    logRing("ShuMokuD_Band2", sm.restPos[3] + 1.4, 1.75, 0.35, "IronDark", palette.ink)
    logRing("ShuMokuD_Whip1", sm.chainBottomsRest[1][3], 1.8, 0.6, "HempRope", hemp)
    logRing("ShuMokuD_Whip2", sm.chainBottomsRest[2][3], 1.8, 0.6, "HempRope", hemp)
    logRing("ShuMokuD_TailRing", sm.restPos[3] + sm.length / 2 - 0.15, 1.95, 0.3, "IronDark", palette.ink)
```

Notes: `logRot` is already defined above (log axis along Z); band/whip stations in
log-local terms: bands at z 8.4 / 10.4, whips at the rope planes 7.5 / 11.5, nose at
z≈5.65 (log spans 5.5..12.5), tail ring at z≈12.35 — all expressed via `sm` fields so
the whole dress follows `restPos`.

- [ ] **Step 5: Run tests, verify GREEN**

Run: `lune run tests/run` — expect all pass (507+ total).

- [ ] **Step 6: Regenerate models, determinism check, lint**

```bash
lune run tools/genmodels && lune run tools/genmodels && git diff --stat -- assets/
stylua src tests tools && stylua --check src tests tools && selene src
```
Expected: only `assets/BonshoRig.model.json` changed; second run adds nothing; lint clean.

- [ ] **Step 7: Commit**

```bash
git add tools/builders/ArenaLayout.luau tools/builders/Bonsho.luau tests/Bonsho.spec.luau tests/CenterpieceContract.spec.luau assets/BonshoRig.model.json
git commit -m "feat(roblox): shu-moku strikes the tsuki-za boss — tower-hung hemp rigging + dressed log"
```

---

### Task 3: HammerController — mirrored constants + dress riders + rope width

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau` (chain constants ~lines 54-66; dowel capture ~lines 71-78; `updateSuspension` chain resize ~line 150)

**Interfaces:**
- Consumes: Task 2's part names (`ShuMokuD_Nose/Band1/Band2/Whip1/Whip2/TailRing`) and layout values (chainTops y=132, bottoms y=121.3).
- Produces: nothing new — the dress parts follow the log like the dowels always have.

- [ ] **Step 1: Update the mirrored chain constants**

Replace the `chainTops`/`chainBottomsRest` literals with (comment updated too):

```lua
-- Rope tops are FIXED on the tower spreaders; bottoms ride the log. World coords
-- mirror ArenaLayout.shuMoku (no yaw): chainTops y132, chainBottomsRest y121.3.
local chainTops = {
    Vector3.new(2, 132, 7.5),
    Vector3.new(2, 132, 11.5),
    Vector3.new(-6, 132, 7.5),
    Vector3.new(-6, 132, 11.5),
}
local chainBottomsRest = {
    Vector3.new(-1.2, 121.3, 7.5),
    Vector3.new(-1.2, 121.3, 11.5),
    Vector3.new(-2.8, 121.3, 7.5),
    Vector3.new(-2.8, 121.3, 11.5),
}
```

- [ ] **Step 2: Capture the dress parts as riders**

Extend the `dowels` list (keep the variable name; it is "parts rigid to the log"):

```lua
local dowels = {
    rig:WaitForChild("ShuMokuDrawDowel") :: BasePart,
    rig:WaitForChild("ShuMokuDowel") :: BasePart,
    -- full-dress fittings (2026-07-23): rigid to the log exactly like the dowels
    rig:WaitForChild("ShuMokuD_Nose") :: BasePart,
    rig:WaitForChild("ShuMokuD_Band1") :: BasePart,
    rig:WaitForChild("ShuMokuD_Band2") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip1") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip2") :: BasePart,
    rig:WaitForChild("ShuMokuD_TailRing") :: BasePart,
}
```
(WaitForChild by exact name — replication-race-proof, per the B3/BellDrive lessons.)

- [ ] **Step 3: Rope width in the live resize**

In `updateSuspension`, find `chain.Size = Vector3.new(len, 0.25, 0.25)` and change to:

```lua
        chain.Size = Vector3.new(len, 0.35, 0.35)
```

- [ ] **Step 4: Lint + full tests**

```bash
stylua src && stylua --check src && selene src && lune run tests/run
```
Expected: clean, all tests pass (controller has no Lune tests; this catches syntax).

- [ ] **Step 5: Commit**

```bash
git add src/client/HammerController.client.luau
git commit -m "feat(roblox): HammerController rides the dressed shu-moku — tower rope mirrors + 0.35 hemp width"
```

---

### Task 4: Live gate (user judges) + record

**Files:**
- Possibly tune: `tools/studio/setupCenterpieceMaterials.luau` (HempRope tile), rope `hemp` color in `Bonsho.luau`
- Update: memory `roshambo-roadmap` / `zendojo-bell-engine` after sign-off

- [ ] **Step 1: Sync + stage.** Ensure `rojo serve` is connected (Studio plugin Connect); confirm `BonshoRig` rebuilt in Edit (gantry gone, ropes hang from the tower).

- [ ] **Step 2: Verify the HempRope maps cleared moderation** — if rope parts render blank/gray, swap a known-good texture in temporarily to confirm it is moderation, then wait.

- [ ] **Step 3: ONE Play attempt, then STOP and ask the user to judge:**
  - the strike lands ON the tsuki-za boss (not above/below);
  - ropes read as hemp at gate distance; strand direction runs along the drop (rotate maps 90° into a second upload if sideways);
  - the swing clears the tower posts; the kick dowel still flicks the drum paddle (ambient — it may not, that is NEXT task's territory, just report);
  - night look under the frozen cycle (`CycleLength=1e9, PhaseOffset=0.75`).

- [ ] **Step 4: Apply the user's tuning verdicts** (tile, rope color, spreader/eye sizes) — one change round per instruction, re-gate.

- [ ] **Step 5: After sign-off:** update `roshambo-roadmap` memory (striker DONE, height y=120.7 is the gearing task's input) and `zendojo-bell-engine` memory (gantry → tower-hung); commit any tuned files:

```bash
git add -A tools/ src/ assets/ && git commit -m "polish(roblox): striker gate tuning (rope tile/colour)"
```

---

## Self-Review

- **Spec coverage:** heights/suspension/dress/rigging/material/controller mirrors/tests/live-gate — Tasks 1-4 cover all; `ropeBottomRest` removal and the no-DriveRope correction are reflected (spec errata noted in the spec file).
- **Placeholders:** the two `UPLOADED_*_ID` slots in Task 1 Step 3 are deliberate runtime inputs (ids exist only after upload) — the step says exactly how to obtain them.
- **Type consistency:** `sm.chainTops`/`chainBottomsRest` shapes match between layout, builder loops, and controller mirrors; dress part names identical across Task 2 tests, Task 2 builder, Task 3 WaitForChild list.
