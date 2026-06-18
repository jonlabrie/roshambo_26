# ZenDojo Downcanyon Viewing Platform + the View — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the clearing's east-edge tiered twin overlooks and the downcanyon vista they frame — the canyon swerving North around a mossy rock prow, the river cascading into mist — plus reusable canyon-wide greening/foliage/lantern/mist passes.

**Architecture:** `ArenaLayout.luau` stays the coordinate authority (new `overlooks` block + downcanyon anchors). A pure `Overlook` builder emits the two decks as a committed `*.model.json` (genmodels → Rojo → `workspace.RoshamboStage`). The view terrain is **native Roblox voxel** carved in-Studio via an MCP script (`tools/studio/buildDowncanyon.luau`, modeled on `buildClearing.luau`) — seamless to the existing voxel canyon, no destructive Gaea re-import. Greening/foliage/lantern/mist are reusable passes (pure point-scatter helper is Lune-tested; placement raycast-snaps in Studio). Spec: `docs/superpowers/specs/2026-06-17-zendojo-viewing-platform-design.md`.

**Tech Stack:** Luau, Rojo, Lune (headless tests), stylua + selene, MCP Roblox Studio (`execute_luau`, `screen_capture`, terrain `ReadVoxels`/`WriteVoxels`/`CopyRegion`).

**Compass:** clearing at world origin; **East = +X = downstream**; **North = −Z**; clearing floor ≈ y111; existing canyon ends ≈ x+135, floor ≈ y70 there. All terrain Y values are provisional — probed and raycast-snapped live.

---

## Conventions (every task honors)

- **Lune-testable tasks** (layout data, pure builders, pure helpers) follow **TDD**: failing spec → minimal impl → green. Run `lune run tests/run` from `roblox/`.
- **Terrain / VFX / placement / staging tasks are MCP/Studio-verified, not Lune-tested** (they need `workspace`/`Terrain`/raycasts). Run via MCP `execute_luau` (datamodel `Edit` for terrain), probe, screenshot, **sign off at the USER gate**.
- **Snapshot terrain before any destructive write**: `Terrain:CopyRegion(Region3int16)` → park in `ServerStorage`; the carve script pastes it back first so re-runs are idempotent. (Hard lesson from the clearing carve — coarse "restores" cannot recover eroded detail.)
- **Do not commit terrain/geometry as "done" until verified at the gate** (standing user rule). Commit code+tests when Lune-green; sign off visuals at gates.
- **Starting coordinates are tuned at the gate** — Lune tests assert *relationships*, not exact values.
- **Lint/format gate before every commit:** `stylua --check src tests` and `selene src` (run with `export PATH="$HOME/.rokit/bin:$PATH"`).
- **Commit messages end with:** `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `roblox/tools/builders/ArenaLayout.luau` | Coordinate authority: `overlooks` block (decks, stair, rail, downcanyon anchors) | Modify |
| `roblox/tests/ArenaLayout.spec.luau` | Relationship tests for the `overlooks` block | Modify |
| `roblox/tools/builders/Overlook.luau` | Pure builder: 2 decks + kake-zukuri posts + bamboo rails + stair + lanterns | Create |
| `roblox/tests/Overlook.spec.luau` | Relationship tests for the Overlook model | Create |
| `roblox/tools/builders/FoliageScatter.luau` | Pure reusable helper: deterministic candidate-point scatter (region+density+seed → points) | Create |
| `roblox/tests/FoliageScatter.spec.luau` | Determinism/bounds/count tests | Create |
| `roblox/tools/genmodels.luau` | Register `Overlook` output | Modify |
| `roblox/default.project.json` | Mount `Overlook.model.json` under `RoshamboStage` | Modify |
| `roblox/assets/Overlook.model.json` | Generated model | Generated |
| `roblox/tools/studio/buildDowncanyon.luau` | MCP terrain carve: snapshot + join + swerve + prow + pools | Create |
| `roblox/tools/studio/greenCanyon.luau` | MCP reusable greening pass: material repaint + foliage/lantern placement (uses FoliageScatter) | Create |

---

## Task 1: ArenaLayout — `overlooks` block + downcanyon anchors

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau`
- Test: `roblox/tests/ArenaLayout.spec.luau`

- [ ] **Step 1: Write the failing tests** — add to `tests/ArenaLayout.spec.luau` inside the `describe("ArenaLayout ...")` block:

```lua
describe("ZenDojo overlooks", function()
    local o = L.overlooks
    test("two decks cantilever East off the clearing edge at distinct tiers", function()
        expect(#o.decks).toBe(2)
        local upper, lower
        for _, d in o.decks do
            if d.tier == "upper" then upper = d elseif d.tier == "lower" then lower = d end
        end
        expect(upper).never.toBeNil()
        expect(lower).never.toBeNil()
        expect(upper.pos[1] > 54).toBe(true) -- East of the terrace edge (~x54)
        expect(lower.pos[1] > 54).toBe(true)
        expect(upper.pos[2] > lower.pos[2]).toBe(true) -- upper deck sits higher
    end)
    test("the look direction faces downcanyon (East + a touch North)", function()
        expect(o.facing[1] > 0).toBe(true) -- East
        expect(o.facing[3] < 0).toBe(true) -- and North (−Z)
    end)
    test("the prow sits East of the decks and below the clearing floor", function()
        expect(o.prow[1] > o.decks[1].pos[1]).toBe(true) -- further East than the decks
        expect(o.prow[2] < 111).toBe(true) -- below clearing floor
    end)
    test("the gorge swerves North and keeps descending past the prow", function()
        expect(o.swerveTo[3] < o.prow[3]).toBe(true) -- North (−Z) of the prow
        expect(o.swerveTo[2] < o.prow[2]).toBe(true) -- lower than the prow (still descending)
    end)
    test("lantern perches recede and descend down the gorge", function()
        expect(#o.lanternPerches >= 3).toBe(true)
        local first, last = o.lanternPerches[1], o.lanternPerches[#o.lanternPerches]
        expect(last[1] > first[1]).toBe(true) -- further East (deeper)
        expect(last[2] < first[2]).toBe(true) -- and lower
    end)
end)
```

- [ ] **Step 2: Run to verify they fail**

Run: `export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (`L.overlooks` is nil → attempt to index nil).

- [ ] **Step 3: Add the `overlooks` block** to the returned table in `ArenaLayout.luau` (near the other ZenDojo blocks, e.g. after `bellDrive`). These are starting coords, tuned at the gate:

```lua
    -- Downcanyon overlook: tiered twin decks off the clearing's EAST edge, aimed ESE
    -- down the gorge. Decks/stair/rail are built by Overlook.luau; the prow/swerve/
    -- perch anchors drive the live terrain carve + greening/lantern passes.
    overlooks = {
        facing = { 1, 0, -0.35 }, -- ESE look direction (East + slightly North)
        railH = 2.8, -- bamboo handrail height
        decks = {
            { tier = "upper", pos = { 56, 113, 4 }, size = { 14, 0.6, 10 } },
            { tier = "lower", pos = { 60, 107, -2 }, size = { 12, 0.6, 9 } },
        },
        stair = { from = { 54, 111, 2 }, to = { 58, 107, 0 }, width = 4 }, -- lantern-lined steps between tiers
        postDrop = 12, -- kake-zukuri posts drop this far below a deck to seat in the terrace lip
        -- downcanyon set-piece anchors (terrain itself is carved live in Studio):
        prow = { 158, 92, 0 }, -- mossy buttress centre, mid-distance straight-ish East
        swerveTo = { 190, 70, -70 }, -- gorge bends North toward here, then fogs out
        lanternPerches = { { 120, 96, -30 }, { 150, 88, -48 }, { 175, 80, -70 } }, -- far warm-glow dots
    },
```

- [ ] **Step 4: Run to verify green**

Run: `export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS (all overlooks tests green; total count increases).

- [ ] **Step 5: Format/lint + commit**

```bash
export PATH="$HOME/.rokit/bin:$PATH" && stylua src tests tools && selene src
git add tools/builders/ArenaLayout.luau tests/ArenaLayout.spec.luau
git commit -m "feat(roblox): ArenaLayout overlooks block + downcanyon anchors

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Overlook builder + model

**Files:**
- Create: `roblox/tools/builders/Overlook.luau`
- Create: `roblox/tests/Overlook.spec.luau`
- Modify: `roblox/tools/genmodels.luau`, `roblox/default.project.json`
- Generated: `roblox/assets/Overlook.model.json`

- [ ] **Step 1: Write the failing test** — `tests/Overlook.spec.luau`:

```lua
local Overlook = require("../tools/builders/Overlook")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")

local model = Overlook.build(ZenDojo.palette, ArenaLayout)

local function find(node, name)
    for _, c in node.children do
        if c.name == name then return c end
    end
    return nil
end
local function countPrefix(node, prefix)
    local n = 0
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then n += 1 end
    end
    return n
end

describe("Overlook", function()
    test("builds both deck slabs", function()
        expect(find(model, "UpperDeck")).never.toBeNil()
        expect(find(model, "LowerDeck")).never.toBeNil()
    end)
    test("each deck stands on kake-zukuri posts", function()
        expect(countPrefix(model, "Post") >= 6).toBe(true) -- >=3 posts per deck
    end)
    test("has a bamboo rail and a connecting stair", function()
        expect(countPrefix(model, "Rail") >= 1).toBe(true)
        expect(countPrefix(model, "Step") >= 2).toBe(true)
    end)
    test("carries warm lanterns (hero chochin + rail ishidoro)", function()
        expect(find(model, "Chochin")).never.toBeNil()
        expect(countPrefix(model, "Ishidoro") >= 1).toBe(true)
    end)
    test("the upper deck slab is placed above the lower deck slab", function()
        expect(find(model, "UpperDeck").properties.CFrame[2] > find(model, "LowerDeck").properties.CFrame[2]).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (`Overlook` module not found).

- [ ] **Step 3: Write the builder** — `tools/builders/Overlook.luau`. Reuses the `Spec` helpers (cf. `BellDrive.luau`) and the locked teahouse recipes (kake-zukuri posts, plank deck, chōchin/ishidōrō primitives). Bamboo rail = thin cylinders in `ZenDojo.palette` bamboo/timber:

```lua
--!strict
-- Tiered twin downcanyon overlooks off the clearing's EAST edge (spec 2026-06-17).
-- Two stepped kake-zukuri decks + bamboo rail + connecting stair + warm lanterns.
-- Overlooks, not buildings. Part names are the placement/prop-snap contract.
local Spec = require("./Spec")

local Overlook = {}

local function deck(children, name, d, palette, railH, postDrop)
    local timber, bamboo = palette.timber, (palette.bamboo or palette.timber)
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local sx, sy, sz = d.size[1], d.size[2], d.size[3]
    -- plank deck slab
    table.insert(children, Spec.part(name, {
        Size = { sx, sy, sz },
        CFrame = Spec.cframe(d.pos),
        Color = timber,
        Material = "WoodPlanks",
    }))
    -- four kake-zukuri posts dropping from the deck corners into the terrace lip
    local hx, hz = sx / 2 - 0.6, sz / 2 - 0.6
    local i = 0
    for _, cx in { -hx, hx } do
        for _, cz in { -hz, hz } do
            i += 1
            table.insert(children, Spec.part(`Post{name}{i}`, {
                Size = { 0.7, postDrop, 0.7 },
                CFrame = Spec.cframe({ px + cx, py - sy / 2 - postDrop / 2, pz + cz }),
                Color = timber,
                Material = "Wood",
            }))
        end
    end
    -- bamboo rail: a top cap cylinder on short posts around the outboard 3 sides
    table.insert(children, Spec.part(`Rail{name}`, {
        Size = { sx, 0.18, 0.18 },
        Shape = "Cylinder",
        CFrame = Spec.cframe({ px, py + sy / 2 + railH, pz - sz / 2 }, Spec.ROT.CYL_ALONG_X),
        Color = bamboo,
        Material = "Wood",
    }))
    -- (the East + side rail runs are added the same way; tuned at the gate)
    return px, py, pz, sx, sy, sz
end

function Overlook.build(palette: { [string]: { number } }, L: any)
    local o = L.overlooks
    local children = {}
    local upper = o.decks[1].tier == "upper" and o.decks[1] or o.decks[2]
    local lower = o.decks[1].tier == "lower" and o.decks[1] or o.decks[2]
    local ux, uy, uz, usx, _, usz = deck(children, "UpperDeck", upper, palette, o.railH, o.postDrop)
    deck(children, "LowerDeck", lower, palette, o.railH, o.postDrop)

    -- connecting stone stair between the tiers (a few steps; lantern-lined)
    local s = o.stair
    local steps = 4
    for k = 1, steps do
        local t = (k - 0.5) / steps
        table.insert(children, Spec.part(`Step{k}`, {
            Size = { s.width, 0.5, 1.6 },
            CFrame = Spec.cframe({
                s.from[1] + (s.to[1] - s.from[1]) * t,
                s.from[2] + (s.to[2] - s.from[2]) * t,
                s.from[3] + (s.to[3] - s.from[3]) * t,
            }),
            Color = palette.ink,
            Material = "Slate",
        }))
    end

    -- hero hanging chochin at the upper deck's outboard corner (SpecialMesh-sphere
    -- primitive per the teahouse recipe → true oblong; Neon body + PointLight added
    -- at the live pass). Placeholder block here carries the name + position.
    table.insert(children, Spec.part("Chochin", {
        Size = { 1.45, 2.38, 1.45 },
        CFrame = Spec.cframe({ ux + usx / 2 - 0.6, uy + 2.0, uz - usz / 2 }),
        Color = palette.gold,
        Material = "Neon",
    }))
    -- standing ishidoro along the upper rail line
    for k, cx in { -usx / 2 + 1.5, usx / 2 - 1.5 } do
        table.insert(children, Spec.part(`Ishidoro{k}`, {
            Size = { 0.8, 2.4, 0.8 },
            CFrame = Spec.cframe({ ux + cx, uy + 1.5, uz - usz / 2 + 0.4 }),
            Color = palette.ink,
            Material = "Slate",
        }))
    end
    return Spec.model("Overlook", children)
end

return Overlook
```

- [ ] **Step 4: Register in genmodels** — add to `tools/genmodels.luau`: a `local Overlook = require("./builders/Overlook")` near the other requires (after line 16), and `["Overlook"] = Overlook.build(ZenDojo.palette, ArenaLayout),` in the `OUTPUTS` table (after the `Foliage` line).

- [ ] **Step 5: Mount in the project** — in `roblox/default.project.json`, under the `RoshamboStage` children (after the `ThrowDrum` line ~31), add:

```json
                "Overlook": { "$path": "assets/Overlook.model.json" },
```

- [ ] **Step 6: Generate the model + run tests**

Run: `export PATH="$HOME/.rokit/bin:$PATH" && lune run tools/genmodels && lune run tests/run`
Expected: `wrote assets/Overlook.model.json`; all tests PASS.

- [ ] **Step 7: Format/lint + commit**

```bash
export PATH="$HOME/.rokit/bin:$PATH" && stylua src tests tools && selene src
git add tools/builders/Overlook.luau tests/Overlook.spec.luau tools/genmodels.luau default.project.json assets/Overlook.model.json
git commit -m "feat(roblox): Overlook builder — tiered twin downcanyon decks

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: FoliageScatter — reusable deterministic scatter helper

**Files:**
- Create: `roblox/tools/builders/FoliageScatter.luau`
- Test: `roblox/tests/FoliageScatter.spec.luau`

The greening pass needs scattered foliage positions canyon-wide. Keep the *point generation* pure + deterministic (Lune-tested); the live pass raycasts Y onto terrain. Reusable for the whole gorge, not just downcanyon.

- [ ] **Step 1: Write the failing test** — `tests/FoliageScatter.spec.luau`:

```lua
local FoliageScatter = require("../tools/builders/FoliageScatter")

describe("FoliageScatter", function()
    local region = { xMin = 100, xMax = 200, zMin = -80, zMax = 0 }
    test("is deterministic for a given seed", function()
        local a = FoliageScatter.points(region, 0.01, 42)
        local b = FoliageScatter.points(region, 0.01, 42)
        expect(#a).toBe(#b)
        expect(a[1][1]).toBe(b[1][1])
        expect(a[1][2]).toBe(b[1][2])
    end)
    test("different seeds differ", function()
        local a = FoliageScatter.points(region, 0.01, 1)
        local b = FoliageScatter.points(region, 0.01, 2)
        expect(a[1][1] ~= b[1][1] or a[1][2] ~= b[1][2]).toBe(true)
    end)
    test("density scales the count", function()
        local sparse = FoliageScatter.points(region, 0.005, 7)
        local dense = FoliageScatter.points(region, 0.02, 7)
        expect(#dense > #sparse).toBe(true)
    end)
    test("all points fall within the region", function()
        for _, p in FoliageScatter.points(region, 0.01, 3) do
            expect(p[1] >= region.xMin and p[1] <= region.xMax).toBe(true)
            expect(p[2] >= region.zMin and p[2] <= region.zMax).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement** — `tools/builders/FoliageScatter.luau` (seeded LCG over a jittered grid; returns `{ {x, z}, ... }`):

```lua
--!strict
-- Deterministic foliage/lantern scatter — pure point generation (region + density +
-- seed → {x,z} list). The live greening pass raycasts Y onto the terrain. Reusable
-- canyon-wide (the downcanyon view is the first caller). No Math.random (banned under
-- Lune + non-reproducible): a small LCG keyed off the seed.
local FoliageScatter = {}

local function lcg(state: number): (number, number)
    state = (1103515245 * state + 12345) % 2147483648
    return state, state / 2147483648 -- next state, [0,1)
end

-- density = expected points per square stud. Walks a grid whose cell ≈ 1/sqrt(density)
-- and jitters one point per cell so the scatter reads organic, not gridded.
function FoliageScatter.points(region: { xMin: number, xMax: number, zMin: number, zMax: number }, density: number, seed: number): { { number } }
    local cell = 1 / math.sqrt(math.max(density, 1e-6))
    local pts = {}
    local state = (seed * 2654435761) % 2147483648 + 1
    local x = region.xMin
    while x < region.xMax do
        local z = region.zMin
        while z < region.zMax do
            local jx, jz
            state, jx = lcg(state)
            state, jz = lcg(state)
            local px = math.clamp(x + jx * cell, region.xMin, region.xMax)
            local pz = math.clamp(z + jz * cell, region.zMin, region.zMax)
            table.insert(pts, { px, pz })
            z += cell
        end
        x += cell
    end
    return pts
end

return FoliageScatter
```

- [ ] **Step 4: Run to verify green**

Run: `export PATH="$HOME/.rokit/bin:$PATH" && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Format/lint + commit**

```bash
export PATH="$HOME/.rokit/bin:$PATH" && stylua src tests tools && selene src
git add tools/builders/FoliageScatter.luau tests/FoliageScatter.spec.luau
git commit -m "feat(roblox): FoliageScatter — deterministic reusable scatter helper

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Carve the downcanyon terrain (MCP / USER GATE)

**Files:**
- Create: `roblox/tools/studio/buildDowncanyon.luau` (MCP-run in Edit; NOT Rojo-synced, NOT Lune-tested)

Builds the join + swerve + prow in the existing voxel grid. Mirror `buildClearing.luau`'s structure: snapshot-paste-first for idempotency, RES4 tiled `WriteVoxels`, an `occFor` smoothing helper, water at FULL occupancy on snapped rows.

- [ ] **Step 1: Set the active Studio + confirm Edit mode**

Run via MCP `list_roblox_studios` then `set_active_studio`; ensure we're in **Edit** (`start_stop_play` false if needed).

- [ ] **Step 2: Snapshot the work region** (idempotent rollback) — `execute_luau` (Edit):

```lua
local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain
-- work region: East of the clearing, into the void, North for the swerve
local minV = Vector3.new(90, 40, -130)
local maxV = Vector3.new(230, 130, 30)
local region = Region3.new(minV, maxV):ExpandToGrid(4)
if not ServerStorage:FindFirstChild("DowncanyonBackup") then
    local snap = Terrain:CopyRegion(region:ExpandToGrid(4))
    -- CopyRegion needs Region3int16; convert:
    local r16 = Region3int16.new(
        Vector3int16.new(minV.X//4, minV.Y//4, minV.Z//4),
        Vector3int16.new(maxV.X//4, maxV.Y//4, maxV.Z//4)
    )
    local copy = Terrain:CopyRegion(r16)
    copy.Name = "DowncanyonBackup"
    copy.Parent = ServerStorage
    copy:SetAttribute("cornerX", minV.X) copy:SetAttribute("cornerY", minV.Y) copy:SetAttribute("cornerZ", minV.Z)
end
return "snapshot ready"
```

- [ ] **Step 3: Write `tools/studio/buildDowncanyon.luau`** — a self-contained carve script with these parameters (starting values; tuned at the gate). It (a) pastes `DowncanyonBackup` first, (b) defines the river centreline as a spline from the boundary (`{135, 70}`) East to the prow then bending North to `swerveTo` (`{190,70,-70}` → continue to ~`{205, 52, -110}`), (c) for each voxel column near the spline writes rock walls + a descending floor, carving a channel, and (d) leaves the prow mass (centre `{158,92,0}`) as solid rock the channel wraps around the North side of. Floor Y descends from ~70 at x135 to ~50 at the fog end. Mirror `buildClearing.luau`'s `occFor`/tiled-WriteVoxels helpers. Run it via `execute_luau` (Edit).

- [ ] **Step 4: Probe the result** — `execute_luau` reading voxels along the spline to confirm the floor descends monotonically and walls exist on both sides (cf. the water-probe in the bell-engine session). Print floor Y at x = 135,150,170 (z 0) and x = 190,205 (z −70,−110).

- [ ] **Step 5: Screenshot from both decks' vantage**

MCP `screen_capture` from `o.decks` upper (`~{56,116,4}`) and lower, look toward the prow `{158,92,0}` and the swerve. Confirm the void is gone — rock fills the frame, the channel bends North.

- [ ] **Step 6: USER GATE** — present screenshots; tune spline/floor/prow/walls live until the composition reads (no visible cutoff straight-ahead; river path bends North believably). Iterate Steps 3–5.

- [ ] **Step 7: Commit the script** (after sign-off)

```bash
git add tools/studio/buildDowncanyon.luau
git commit -m "feat(roblox): carve the downcanyon swerve + prow (voxel set-piece)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Downcanyon water — pools, cascade VFX, far fog (MCP / USER GATE)

**Files:** extends `tools/studio/buildDowncanyon.luau` (water section) + live VFX instances.

- [ ] **Step 1: Stepped pools** — in `buildDowncanyon.luau`, add terrain **water at FULL occupancy** on snapped voxel rows for 2–3 calm plunge pools down the channel (boundary base pool ~y68, a mid pool wrapping the prow ~y58, a far pool ~y50). (WriteVoxels silently drops fractional water → basalt spikes; keep water rows full.)

- [ ] **Step 2: Cascade VFX** — between pools, instance the established fall pattern (reuse the clearing's recipe): a translucent water-sheet mesh/part down each drop + a `Beam` + a mist `ParticleEmitter` at the base. Place at the spline drops. Parented under a `workspace.RoshamboStage.DowncanyonVFX` folder.

```lua
-- per drop (pseudo-params, tuned at the gate): sheet part Color WATER, Transparency 0.35,
-- thin, spanning the drop face; ParticleEmitter Rate ~40, white, short lifetime; Beam
-- between top/bottom attachments. Mirror the clearing fall VFX.
```

- [ ] **Step 3: Far-end fog volume** — at the swerve/fog terminus (`~x195+, z−90+`), add layered `ParticleEmitter` mist banks (low Rate, large Size, high Transparency, slow drift) so the terrain cutoff dissolves. Optionally nudge `Lighting.Atmosphere`/`workspace.Terrain` only if it doesn't fight the bright review lighting (the clearing reviews use bright, not dusk).

- [ ] **Step 4: Screenshot + USER GATE** — confirm the river reads as descending + cascading into mist with no hard cutoff. Tune pool levels, VFX density, fog opacity live.

- [ ] **Step 5: Commit** (after sign-off): `feat(roblox): downcanyon water — pools + cascade VFX + far mist`.

---

## Task 6: Greening pass — reusable material + foliage application (MCP / USER GATE)

**Files:**
- Create: `roblox/tools/studio/greenCanyon.luau` (MCP-run; reusable canyon-wide; uses `FoliageScatter`)

- [ ] **Step 1: Material greening** — `greenCanyon.luau`: define the shared moss targets once and apply, e.g.:

```lua
local Terrain = workspace.Terrain
Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(74, 96, 58))      -- moss green
Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(66, 88, 50))
Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(96, 102, 92))      -- damp grey-green
```

Then repaint the downcanyon wall voxels from bare Rock toward Grass/LeafyGrass on the upper faces (ReplaceMaterial over the work region, or per-column in the carve). These `SetMaterialColor` values are the canyon-wide moss targets reused everywhere.

- [ ] **Step 2: Foliage placement** — call `FoliageScatter.points` over the downcanyon region (density highest near the decks, thinning toward the fog), raycast each `{x,z}` down onto the terrain for Y + normal, and place foliage instances (reuse `Foliage.luau`'s shrubs/ferns + a few clinging trees) anchored under `workspace.RoshamboStage.DowncanyonFoliage`. Keep `FoliageScatter` as the single source of scatter points (DRY — same helper will green the rest of the gorge later).

```lua
local FoliageScatter = ... -- inline the pure function or read points baked from genmodels
local pts = FoliageScatter.points({ xMin=120, xMax=205, zMin=-110, zMax=20 }, 0.012, 1337)
for _, p in pts do
    local hit = workspace:Raycast(Vector3.new(p[1], 200, p[2]), Vector3.new(0,-300,0))
    if hit then -- place a foliage clump at hit.Position, aligned to hit.Normal
    end
end
```

- [ ] **Step 3: Screenshot + USER GATE** — confirm the walls read mossy + foliage clings + density gradient toward fog matches the reference. Tune colors/density live.

- [ ] **Step 4: Commit** (after sign-off): `feat(roblox): reusable canyon greening pass + downcanyon foliage`.

---

## Task 7: Lantern-dots on the far perches (MCP / USER GATE)

**Files:** extends `tools/studio/greenCanyon.luau` (lantern-dot helper section).

- [ ] **Step 1: Lantern-dot helper** — a reusable function `placeLanternDot(pos)` that instances a chōchin (SpecialMesh-sphere body, Neon + PointLight, per the teahouse round-lantern primitive) at a world pos. Reusable canyon-wide.

- [ ] **Step 2: Scatter on far perches** — call it for each `L.overlooks.lanternPerches` anchor (raycast-snapped to the far wall), plus a few extra `FoliageScatter` points up the far wall, so the distance reads as dotted with warm teahouse glow (pure backdrop life). Parent under `workspace.RoshamboStage.DowncanyonLanterns`.

- [ ] **Step 3: Screenshot + USER GATE** — dusk-leaning preview if helpful (then back to bright for terrain review). Confirm the warm dots add depth without looking placed-on-a-grid. Tune count/brightness live.

- [ ] **Step 4: Commit** (after sign-off): `feat(roblox): reusable lantern-dot helper + far-perch glow`.

---

## Task 8: Place + prop-snap the twin overlooks (MCP / USER GATE)

**Files:** placement pass (live) over the Rojo-synced `workspace.RoshamboStage.Overlook` model.

- [ ] **Step 1: Confirm the model synced** — Rojo serving; `workspace.RoshamboStage.Overlook` present with `UpperDeck`/`LowerDeck`/posts/rails/steps/`Chochin`/`Ishidoro*`.

- [ ] **Step 2: Seat the posts** — raycast each `Post*` bottom down onto the terrace lip terrain; extend/trim so posts meet ground (cf. the canyon prop-snap pattern). Keep decks at the layout Y; lengthen posts to reach.

- [ ] **Step 3: Light the lanterns** — convert the `Chochin` placeholder to the full primitive (SpecialMesh sphere + Neon + PointLight + rib rings) and add PointLights to `Ishidoro*`. (This is the only "art" here; everything else stays rough-in.)

- [ ] **Step 4: Walk both decks in Play** — spawn, walk to the east edge, stand on each deck; confirm the sightline frames boundary fall → river → prow → fog, and the lower deck gives the closer-to-the-river second framing.

- [ ] **Step 5: USER GATE** — tune deck pos/size/rail/lantern placement in `ArenaLayout.overlooks` live; re-run genmodels if the builder changes; re-verify.

- [ ] **Step 6: Commit** (after sign-off): `feat(roblox): seat + light the twin overlooks at the clearing edge` (include any `ArenaLayout`/`Overlook` tuning + regenerated `Overlook.model.json`).

---

## Task 9: Composition gate (USER) — full review + hero shots

**Files:** none (verification + final tuning only).

- [ ] **Step 1: Bright review lighting** — set the clearing review lighting (GlobalShadows off, Brightness ~2.5, ClockTime 12, bloom/DOF off) so the form reads, then a dusk pass (ClockTime ~18.4, fog) to check the lantern glow.

- [ ] **Step 2: Full review from both decks** — verify end-to-end: the void is gone; the river descends + cascades + fogs out; walls read mossy with clinging foliage; warm lantern-dots give depth; the prow blocks the straight-ahead and the gorge bends North believably; both decks frame distinct, satisfying compositions.

- [ ] **Step 3: Tune** anything that doesn't sell the reference (spline, prow, floor grade, greening density, mist opacity, lantern count, deck placement) live until sign-off.

- [ ] **Step 4: Hero shots** — capture from the upper deck, the lower deck, and a flying camera angle (set-piece must hold from multiple angles).

- [ ] **Step 5: Final commit** of any tuning + update the project memory (`zendojo` notes) marking the viewing platform + downcanyon view done.

---

## Self-Review (plan author)

**Spec coverage:** Composition/swerve/prow → Tasks 1,4. Cascade-into-mist → Task 5. Approach A native voxel + snapshot → Task 4. Greening (reusable + downcanyon) → Tasks 3,6. Lantern-dots (reusable) → Task 7. Twin tiered overlooks + bamboo rail + lanterns → Tasks 1,2,8. Coordinate authority in ArenaLayout → Task 1. Testing (Lune relationship + MCP gates) → Tasks 1–3 specs, 4–9 gates. Out-of-scope (full art, rest-of-canyon greening application, Gaea re-import) honored — only the reusable helpers + downcanyon application are built. ✓ no gaps.

**Placeholder scan:** Live terrain/VFX/placement tasks (4–9) intentionally carry concrete starting parameters + exact MCP steps + a USER gate rather than full final code, per the project convention (called out in Conventions) that these are tuned live — same style as the committed clearing/bell-engine plans. Pure tasks (1–3) carry complete test + implementation code.

**Type/name consistency:** `L.overlooks` fields (`facing`, `railH`, `decks[].tier/pos/size`, `stair`, `postDrop`, `prow`, `swerveTo`, `lanternPerches`) defined in Task 1 are consumed identically in Tasks 2,4,6,7,8. Part-name prefixes (`UpperDeck`/`LowerDeck`/`Post*`/`Rail*`/`Step*`/`Chochin`/`Ishidoro*`) asserted in Task 2's spec match the builder and the Task 8 snap pass. `FoliageScatter.points(region, density, seed)` signature defined in Task 3 is called identically in Tasks 6,7. ✓
