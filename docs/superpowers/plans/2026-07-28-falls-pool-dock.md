# Falls-Pool Dock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small posted timber dock on the north-east shore of pool 2 in the west canyon, running toward the `TopToOutfall` falls, with a result-displaying chōchin at the water end.

**Architecture:** The deck is a pure, Lune-tested Luau builder (`tools/builders/FallsDock.luau`) that returns a nested part-spec tree, exactly like `SwitchbackDeck`. `lune run tools/genmodels` bakes it to `assets/FallsDock.model.json`, and Rojo syncs that into `Workspace.RoshamboStage.FallsDock`. The chōchin is a separate Studio-run, place-only script, matching how every other chōchin in the canyon was built.

**Tech Stack:** Luau (strict), Lune (test runner + genmodels), Rojo, `tools/builders/Spec.luau`, stylua, selene.

## Global Constraints

Copied from the spec (`docs/superpowers/specs/2026-07-28-canyon-destinations-falls-dock-design.md`) and the build recipes (`docs/superpowers/references/zendojo-canyon-build-recipes.md` §2):

- Slab: **6 wide × 8 long**, `WoodPlanks`, **0.6** thick, Earth orange **`{0.42, 0.31, 0.20}`**
- Deck top: **~1.5 studs above the pool 2 water surface (y = 188.7)**, i.e. **y ≈ 190.2**
- Posts: `Wood`, **1.125** square, **outer faces flush with the slab edges**
- Girders: `Wood`, **1.2 × 0.825**, two long edges + one cross, **tops at the slab underside**
- **No railing.** Deliberate departure from recipe §2 (that specifies kōran on open-air *drop* edges; this is a 1.5-stud step into shallow water). Do not add one.
- Lantern discovery is by **CollectionService tag**, never by name or parent: `RoundLantern` for the chōchin's `GlyphPlate`s, `ChochinSwing` for the hanging sub-model.
- Pool 2 survey: surface **y = 188.7**, extent **x −371…−347 by z −29…15**. `TopToOutfall` falls run y 208 → 187, mist emitter at **(−367, 190, −4)**.
- All builders are **pure and deterministic** — no `math.random`, no `os.time`, no `DateTime`. Committed assets must be byte-identical on arm64 and x86_64 or CI's drift check fails.
- Every task ends green on: `lune run tests/run`, `stylua --check src tests tools`, `selene src tools`.

---

### Task 1: Bake the dock position from a user-placed marker

The recipe's standing workflow is "Rojo serve is one-way; read their move, bake it." The survey fixes the site; only the user fixes the seat. **This task is a gate — it cannot be completed without them.**

**Files:**
- Modify: none yet (produces two constants used by Task 2)

**Interfaces:**
- Produces: `DOCK_CX`, `DOCK_CZ` (numbers, deck centre in world x/z) and `DOCK_YAW_DEG` (number, degrees, rotation about Y so the deck's long axis points WSW toward the falls). Task 2 consumes all three.

- [ ] **Step 1: Create the marker in Studio**

Run in Studio (Edit mode) via MCP `execute_luau`:

```lua
local m = Instance.new("Part")
m.Name = "FallsDockMarker"
m.Shape = Enum.PartType.Ball
m.Size = Vector3.new(3, 3, 3)
m.Color = Color3.fromRGB(0, 255, 255)
m.Material = Enum.Material.Neon
m.Anchored = true
m.CanCollide = false
-- seeded at the NE shore of pool 2, on the water surface; the user drags it from here
m.Position = Vector3.new(-347, 190.2, -20)
m.Parent = workspace
return "FallsDockMarker created at " .. tostring(m.Position)
```

- [ ] **Step 2: Ask the user to place it**

Ask them to drag `FallsDockMarker` to where the **centre of the dock slab** should sit, then say when done. Tell them the deck is 6 × 8 and the long axis will point at the falls.

- [ ] **Step 3: Read the marker back and compute the yaw**

```lua
local m = workspace:FindFirstChild("FallsDockMarker")
local p = m.Position
-- aim the long axis at the TopToOutfall base; that is the view the dock is for
local target = Vector3.new(-370, 187, -6)
local d = (target - p)
local yaw = math.deg(math.atan2(-d.X, -d.Z))  -- Roblox yaw: 0 = -Z, +ve = toward -X
return string.format("DOCK_CX = %.2f\nDOCK_CZ = %.2f\nDOCK_YAW_DEG = %.2f\nmarker y = %.2f",
    p.X, p.Z, yaw, p.Y)
```

Record the three printed values. They are baked as literals in Task 2 — the builder must not read Workspace.

- [ ] **Step 4: Delete the marker**

```lua
local m = workspace:FindFirstChild("FallsDockMarker")
if m then m:Destroy() end
return "marker removed"
```

- [ ] **Step 5: Commit nothing**

This task produces numbers, not files. Carry them into Task 2.

---

### Task 2: The `FallsDock` builder — slab, posts, girders

**Files:**
- Create: `roblox/tools/builders/FallsDock.luau`
- Test: `roblox/tests/FallsDock.spec.luau`

**Interfaces:**
- Consumes: `DOCK_CX`, `DOCK_CZ`, `DOCK_YAW_DEG` from Task 1; `Spec.part`, `Spec.model`, `Spec.cframe`, `Spec.yaw` from `tools/builders/Spec.luau`.
- Produces: `FallsDock.build(palette, ArenaLayout) -> PartSpec` — a `Model` named `FallsDock` whose children are `Slab`, `Post_1…Post_6`, `GirderLongA`, `GirderLongB`, `GirderCross`. Task 3 registers it; Task 4 mounts the lantern beside it.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/FallsDock.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local FallsDock = require("../tools/builders/FallsDock")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local model = FallsDock.build(ZenDojo.palette, ArenaLayout)

local function find(node, name)
    for _, c in node.children do
        if c.name == name then
            return c
        end
    end
    return nil
end

local function countPrefix(node, prefix)
    local n = 0
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            n += 1
        end
    end
    return n
end

describe("FallsDock", function()
    test("is a model named FallsDock", function()
        expect(model.className).toBe("Model")
        expect(model.name).toBe("FallsDock")
    end)

    test("slab is 6 x 8 x 0.6 WoodPlanks", function()
        local slab = find(model, "Slab")
        expect(slab ~= nil).toBe(true)
        assert(slab ~= nil)
        expect(slab.properties.Size[1]).toBe(6)
        expect(slab.properties.Size[2]).toBe(0.6)
        expect(slab.properties.Size[3]).toBe(8)
        expect(slab.properties.Material).toBe("WoodPlanks")
    end)

    test("has six posts, all 1.125 square", function()
        expect(countPrefix(model, "Post_")).toBe(6)
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Post_" then
                expect(c.properties.Size[1]).toBe(1.125)
                expect(c.properties.Size[3]).toBe(1.125)
            end
        end
    end)

    -- The standing rule for every canyon build: a post's OUTER face is flush with
    -- the slab edge, so no post juts past the deck when seen from the water.
    test("post outer faces sit flush inside the slab footprint", function()
        local slab = find(model, "Slab")
        assert(slab ~= nil)
        local halfW, halfD = slab.properties.Size[1] / 2, slab.properties.Size[3] / 2
        for _, c in model.children do
            if (c.name :: string):sub(1, 5) == "Post_" then
                -- positions are LOCAL to the model origin, before the yaw is applied
                local lx, lz = c.properties.CFrame[1], c.properties.CFrame[3]
                expect(math.abs(lx) <= halfW + 1e-6).toBe(true)
                expect(math.abs(lz) <= halfD + 1e-6).toBe(true)
            end
        end
    end)

    test("girder tops meet the slab underside", function()
        local slab = find(model, "Slab")
        assert(slab ~= nil)
        local slabBottom = slab.properties.CFrame[2] - slab.properties.Size[2] / 2
        for _, name in { "GirderLongA", "GirderLongB", "GirderCross" } do
            local g = find(model, name)
            expect(g ~= nil).toBe(true)
            assert(g ~= nil)
            expect(g.properties.Size[2]).toBe(1.2)
            local top = g.properties.CFrame[2] + g.properties.Size[2] / 2
            expect(math.abs(top - slabBottom) < 1e-6).toBe(true)
        end
    end)

    -- The spec forbids a railing. This test exists so a later reader who "fixes"
    -- the missing kōran against recipe section 2 gets a red test instead of a merge.
    test("has no railing parts", function()
        for _, c in model.children do
            local n = c.name :: string
            expect(n:find("Rail") == nil).toBe(true)
            expect(n:find("Newel") == nil).toBe(true)
            expect(n:find("Baluster") == nil).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `FallsDock` module does not exist.

- [ ] **Step 3: Write the builder**

Create `roblox/tools/builders/FallsDock.luau`. **Replace the three `DOCK_*` constants with the values recorded in Task 1.**

```lua
--!strict
-- Small posted timber dock on the NE shore of pool 2, west canyon
-- (spec 2026-07-28-canyon-destinations-falls-dock-design).
-- Runs WSW toward the TopToOutfall falls: you walk out along it toward the water.
-- A smaller, simpler sibling of SwitchbackDeck — no railing (see the spec; a 1.5-stud
-- step into shallow water is not a drop edge), and one chōchin added separately in Studio.
-- Pure & deterministic; the seat is baked from the user's in-Studio marker.
local Spec = require("./Spec")

local FallsDock = {}

-- ===== baked placement (Task 1: user-dragged FallsDockMarker) =====
local DOCK_CX = -347.00 -- REPLACE with the value printed in Task 1
local DOCK_CZ = -20.00 -- REPLACE with the value printed in Task 1
local DOCK_YAW_DEG = 0.00 -- REPLACE with the value printed in Task 1

-- ===== dimensions (plan Global Constraints) =====
local DECK_W, DECK_D = 6, 8 -- X across, Z along (long axis points at the falls)
local SLAB_T = 0.6
local WATER_Y = 188.7 -- pool 2 surface, from the terrain survey
local DECK_TOP = WATER_Y + 1.5
local SLAB_BOTTOM = DECK_TOP - SLAB_T

local POST_W = 1.125
local GIRDER_H, GIRDER_W = 1.2, 0.825
local GIRDER_TOP = SLAB_BOTTOM
local POOL_BED_Y = 184.0 -- posts run into the water to the bed; survey value

local TIMBER = { 0.42, 0.31, 0.20 }

local X0, X1 = -DECK_W / 2, DECK_W / 2
local Z0, Z1 = -DECK_D / 2, DECK_D / 2

-- inset so a post's OUTER face is flush with the slab edge
local function flush(v: number, lo: number, hi: number): number
    if math.abs(v - lo) < 0.01 then
        return v + POST_W / 2
    elseif math.abs(v - hi) < 0.01 then
        return v - POST_W / 2
    end
    return v
end

function FallsDock.build(_palette: any, _layout: any): any
    local children = {}

    table.insert(
        children,
        Spec.part("Slab", {
            Size = { DECK_W, SLAB_T, DECK_D },
            CFrame = Spec.cframe({ 0, DECK_TOP - SLAB_T / 2, 0 }),
            Material = "WoodPlanks",
            Color = TIMBER,
        })
    )

    -- six posts: both ends plus a mid pair, so an 8-stud span does not sag visually
    local postXZ = {
        { X0, Z0 },
        { X1, Z0 },
        { X0, 0 },
        { X1, 0 },
        { X0, Z1 },
        { X1, Z1 },
    }
    for i, xz in postXZ do
        local px, pz = flush(xz[1], X0, X1), flush(xz[2], Z0, Z1)
        local h = SLAB_BOTTOM - POOL_BED_Y
        table.insert(
            children,
            Spec.part(`Post_{i}`, {
                Size = { POST_W, h, POST_W },
                CFrame = Spec.cframe({ px, POOL_BED_Y + h / 2, pz }),
                Material = "Wood",
                Color = TIMBER,
            })
        )
    end

    -- girders: two along the long edges, one cross at mid-span; tops flush under the slab
    local gy = GIRDER_TOP - GIRDER_H / 2
    table.insert(
        children,
        Spec.part("GirderLongA", {
            Size = { GIRDER_W, GIRDER_H, DECK_D },
            CFrame = Spec.cframe({ flush(X0, X0, X1), gy, 0 }),
            Material = "Wood",
            Color = TIMBER,
        })
    )
    table.insert(
        children,
        Spec.part("GirderLongB", {
            Size = { GIRDER_W, GIRDER_H, DECK_D },
            CFrame = Spec.cframe({ flush(X1, X0, X1), gy, 0 }),
            Material = "Wood",
            Color = TIMBER,
        })
    )
    table.insert(
        children,
        Spec.part("GirderCross", {
            Size = { DECK_W, GIRDER_H, GIRDER_W },
            CFrame = Spec.cframe({ 0, gy, 0 }),
            Material = "Wood",
            Color = TIMBER,
        })
    )

    return Spec.model("FallsDock", children)
end

return FallsDock
```

Note: parts are authored in **local** coordinates about the deck centre. `DOCK_CX`, `DOCK_CZ` and `DOCK_YAW_DEG` are applied in Task 3, where the model is placed into the world.

- [ ] **Step 4: Run the test and watch it pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS — all six `FallsDock` tests green, and the pre-existing suite still green.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests tools && selene src tools`
Expected: both clean. If stylua complains, run `stylua src tests tools` and re-check.

- [ ] **Step 6: Commit**

```bash
git add roblox/tools/builders/FallsDock.luau roblox/tests/FallsDock.spec.luau
git commit -m "feat(roblox): FallsDock builder - 6x8 posted timber dock on pool 2"
```

---

### Task 3: Register the dock in genmodels and Rojo

**Files:**
- Modify: `roblox/tools/genmodels.luau` (require block near line 17; `OUTPUTS` table near line 48)
- Modify: `roblox/default.project.json` (the `RoshamboStage` children block, near line 53)
- Create (generated): `roblox/assets/FallsDock.model.json`

**Interfaces:**
- Consumes: `FallsDock.build(palette, ArenaLayout)` from Task 2.
- Produces: `Workspace.RoshamboStage.FallsDock` in the running place, positioned at `DOCK_CX/DOCK_CZ` with `DOCK_YAW_DEG`.

- [ ] **Step 1: Apply the world placement in the builder**

The builder currently emits local coordinates. Wrap the returned model so the whole dock is seated and rotated. In `roblox/tools/builders/FallsDock.luau`, replace the final `return Spec.model("FallsDock", children)` with:

```lua
    -- seat and rotate the whole dock: authored about the origin, placed here
    local rot = Spec.rotYMat(DOCK_YAW_DEG)
    for _, c in children do
        local cf = c.properties.CFrame
        local p = Spec.rotY({ cf[1], cf[2], cf[3] }, DOCK_YAW_DEG)
        c.properties.CFrame = {
            p[1] + DOCK_CX,
            p[2],
            p[3] + DOCK_CZ,
            rot[1], rot[2], rot[3],
            rot[4], rot[5], rot[6],
            rot[7], rot[8], rot[9],
        }
    end
    return Spec.model("FallsDock", children)
```

- [ ] **Step 2: Add a test that the dock is seated at the baked position**

Append to `roblox/tests/FallsDock.spec.luau`, inside the existing `describe`:

```lua
    test("slab is seated at the baked marker position", function()
        local slab = find(model, "Slab")
        assert(slab ~= nil)
        -- the baked centre from Task 1; update both here and in the builder together
        expect(math.abs(slab.properties.CFrame[1] - (-347.00)) < 0.5).toBe(true)
        expect(math.abs(slab.properties.CFrame[3] - (-20.00)) < 0.5).toBe(true)
    end)
```

Replace `-347.00` / `-20.00` with the Task 1 values.

- [ ] **Step 3: Run tests**

Run: `cd roblox && lune run tests/run`
Expected: PASS. The flush-face test still passes because it compares each post against the slab, and both moved together.

- [ ] **Step 4: Register the builder in genmodels**

In `roblox/tools/genmodels.luau`, add next to the other requires (near line 17):

```lua
local FallsDock = require("./builders/FallsDock")
```

and inside the `OUTPUTS` table (near line 48):

```lua
    ["FallsDock"] = FallsDock.build(ZenDojo.palette, ArenaLayout),
```

- [ ] **Step 5: Generate the asset**

Run: `cd roblox && lune run tools/genmodels`
Expected: prints `wrote assets/FallsDock.model.json` among the others.

- [ ] **Step 6: Wire it into Rojo**

In `roblox/default.project.json`, inside the `RoshamboStage` children block, next to the `SwitchbackDeck` line:

```json
                "FallsDock": { "$path": "assets/FallsDock.model.json" },
```

- [ ] **Step 7: Lint and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools
cd .. && git add roblox/tools/builders/FallsDock.luau roblox/tests/FallsDock.spec.luau \
  roblox/tools/genmodels.luau roblox/default.project.json roblox/assets/FallsDock.model.json
git commit -m "feat(roblox): seat FallsDock at the baked marker and sync it through Rojo"
```

---

### Task 4: The chōchin at the water end

**Files:**
- Create: `roblox/tools/studio/buildDockChochin.luau`

**Deliberate deviation from the spec's "build form" line:** the deck is a committed Rojo builder, but this lantern is **place-only**, run from Studio. Reason: the canyon's chōchin is a ~60-part assembly (18 barrel slices, 16 ribs, 6 vribs, 14 loop segments, caps, pole, crossarm, brace, swing model), and `buildChochinPole.luau` already builds it — but only as a path-walking, place-only script. Porting all of it to a pure builder to place **one** lantern is out of proportion, and every other chōchin in the canyon is place-only, so this stays consistent. Flag it to the user; if they want it committed, that is a separate task to write a reusable `Chochin` builder.

**Interfaces:**
- Consumes: the locked chōchin recipe values in `roblox/tools/studio/buildChochinPole.luau` (colours `WOOD`, `INK`, `METAL`, `PAPER`; barrel/rib/pole geometry) and the dock position from Task 1.
- Produces: `Workspace.CanyonWorld.Structures.DockChochin`, with both `GlyphPlate` parts tagged `RoundLantern` and the `Swing` sub-model tagged `ChochinSwing`.

- [ ] **Step 1: Write the script**

`buildChochinPole.luau` already has the seam we need: **`buildOne(parent, name, base, up) -> Model`** (line 65) builds one complete chōchin — pole, crossarm, brace, swing sub-model, 18-slice barrel, ribs, caps and both glyph plates — and **applies both tags itself** (`RoundLantern` on the plates at line 245, `ChochinSwing` on the swing at line 251). Lines 255 onward are only the path-walking deployment, which we replace.

Create `roblox/tools/studio/buildDockChochin.luau`:

1. Copy **lines 1–253** of `roblox/tools/studio/buildChochinPole.luau` verbatim — the header, the locked colour/material constants, `cyl`, `profile` and `buildOne`. Do not re-derive any value; these are the locked prototype recipe.
2. Change the header comment to describe this script (one pole, at the dock).
3. Delete everything from `-- ===== deploy along the path =====` (line 255) to the end, and replace it with:

```lua
-- ===== deploy: one pole at the dock's water end =====
local dock = ws:WaitForChild("RoshamboStage"):WaitForChild("FallsDock")
local slab = dock:WaitForChild("Slab") :: BasePart

local structures = ws:WaitForChild("CanyonWorld"):WaitForChild("Structures")
local existing = structures:FindFirstChild("DockChochin")
if existing then
    existing:Destroy() -- re-runnable
end
local root = Instance.new("Model")
root.Name = "DockChochin"
root.Parent = structures

-- the slab's local +Z is the long axis, pointing at the falls; put the pole at that
-- end, inset far enough that the barrel does not overhang the deck edge
local INSET = 0.9
local endCF = slab.CFrame * CFrame.new(0, slab.Size.Y / 2, slab.Size.Z / 2 - INSET)
buildOne(root, "DockChochinPole", endCF.Position, Vector3.new(0, 1, 0))

return string.format("DockChochin built at (%.1f, %.1f, %.1f)",
    endCF.Position.X, endCF.Position.Y, endCF.Position.Z)
```

Note: `buildOne` takes `up` as a world vector; the dock is level, so `(0, 1, 0)` is correct here.

- [ ] **Step 2: Run it in Studio**

Run the script from the Studio command bar (or via MCP `execute_luau`, Edit datamodel). Expected output: a single chōchin standing at the water end of the dock.

- [ ] **Step 3: Verify the tags took**

`buildOne` applies both tags, so this is a check that the copy survived intact, not a step that adds them.

```lua
local CS = game:GetService("CollectionService")
local plates, swings = 0, 0
for _, d in ipairs(workspace.CanyonWorld.Structures.DockChochin:GetDescendants()) do
    if CS:HasTag(d, "RoundLantern") then plates += 1 end
    if CS:HasTag(d, "ChochinSwing") then swings += 1 end
end
return string.format("RoundLantern plates: %d (expect 2), ChochinSwing: %d (expect 1)", plates, swings)
```

Expected: `RoundLantern plates: 2, ChochinSwing: 1`. If either is 0 the lantern will never light or sway.

- [ ] **Step 4: Confirm the result display drives it**

Enter Play. Wait for a round to reveal. Expected: the glyph plates paint the World-Throw result, and the barrel rocks gently.

- [ ] **Step 5: Save the place**

The chōchin is place-only. **Tell the user to save the place** or it is lost.

- [ ] **Step 6: Commit the script**

```bash
git add roblox/tools/studio/buildDockChochin.luau
git commit -m "feat(roblox): buildDockChochin - single result chochin at the dock's water end"
```

---

### Task 5: Visual gate

**Files:** none.

- [ ] **Step 1: Look at it from the dock**

In Play, walk out onto the dock. Check: the falls are ahead of you, the deck reads as timber rather than plastic, the posts do not jut past the slab edge, and the chōchin sits at the far end without blocking the view.

- [ ] **Step 2: Look at it from above**

Fly to roughly (−347, 260, −20) and look down. Check the composition the spec is built for: a long dark pool with one warm point of light at its north end and white water beside it.

- [ ] **Step 3: Report to the user and stop**

Show both views and ask for the gate. **Do not iterate on the look unprompted** — make one attempt, then ask.
