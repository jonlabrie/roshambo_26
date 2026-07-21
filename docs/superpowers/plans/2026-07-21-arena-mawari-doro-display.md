# Mawari-dōrō Revolving-Lantern Display — Implementation Plan (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Arena's placeholder hexagonal throw drum with a vertical-axis, 12-facet **mawari-dōrō revolving lantern** (4 windows, squat gray-cypress beacon) that reads the World Throw from all four cardinals, glows at night, and renders R/P/S using a new shared `Glyphs` module built from the approved PWA artwork.

**Architecture:** Follows the repo's geometry-as-code pipeline (pure builder modules → `lune run tools/genmodels` → committed `assets/*.model.json`, Rojo-synced, CI drift-checked) and DI pattern (pure Lune-testable modules; runtime `.client.luau` controllers create Instances). New pure `Glyphs.luau` (a `parts()` descriptor function that is Lune-tested + a runtime `render()` helper). The `DrumController` reveal state machine (rest → strike-kicked spin → cubic glide to detent) is preserved; only the spin axis (X→Y), detent period (180°→90°), and glyph attachment (Unicode `TextLabel` → `Glyphs.render`) change.

**Tech Stack:** Luau (`--!strict`), Rojo 7.x, Lune (bespoke test harness), StyLua + Selene, Roblox Studio (live gate via the Roblox_Studio MCP). Scale: 1 stud ≈ 1 foot.

**Scope (Plan A only):** the `Glyphs` module, `DrumStep` 6→12 generalization, the `ThrowDrum` builder + `ArenaLayout`, and the `DrumController`. **Deferred to Plan B:** chōchin (`LanternController`) + HUD (`main.client.luau`) glyph retrofits. **Deferred to T8 (drive-chain technical pass):** reconnecting the physical water-drive linkage to the vertical lantern. **Deferred:** split-flap kōsatsu boards.

## Global Constraints

- **Luau `--!strict`** on every file.
- **Lune-safety in shared/pure modules:** NO `Instance.new`, `Color3`, `Enum`, `UDim2`, etc. at module scope OR in any function the Lune tests call. Colors in pure code are `{number}` RGB arrays (0–1). `Color3`/Instance APIs live only inside runtime functions (`render`, controllers) that tests never invoke. (See the `DecorationCatalog`/`LanternController` "Color3 must stay inside builder bodies" lesson.)
- **Geometry-as-code determinism:** after editing any builder, run `lune run tools/genmodels` **twice**; `git diff --stat assets/` must show each changed `model.json` change **once** and be **identical on the second run**. No transcendental *hashes* (geometry `math.cos`/`math.sin` is fine; `JsonEmit` snaps near-zero residues to 0).
- **Tests:** `lune run tests/run` (bespoke harness: `harness.describe/test/expect`, `expect(x).toBe(y)`).
- **Lint/format:** `stylua --check src tests tools` and `selene src` must be clean before every commit.
- **Rojo:** `default.project.json` is unchanged (no new remotes/paths; `src/shared/Glyphs.luau` is already covered by the shared sync). No `rojo serve` restart needed — a running sync picks up the new file and the regenerated `assets/ThrowDrum.model.json`.
- **Ship by saving/publishing the place, never `rojo build`.** The `model.json` IS Rojo-managed, so it syncs into `Workspace.RoshamboStage.ThrowDrum` automatically.
- **MaterialVariant names (place-state, already set up):** `CypressWeathered`, `SlateTile`, `IronDark`, `BronzePatina`. Set both `Color` (palette tint) and `MaterialVariant` on parts.
- **Chevron orientation:** scissors is **∧ (apex up)** everywhere.
- **Live gate = ONE attempt, then STOP and show the user** (never self-judge visual quality and iterate unprompted).

---

## File Structure

- `roblox/src/shared/Glyphs.luau` — **new.** Pure `Glyphs.parts(symbol, coreColor, opts)` returning primitive descriptors; runtime `Glyphs.render(parent, symbol, coreColor, sizePx, opts)` building Frames/UIStrokes. Sole owner of "how an R/P/S glyph is drawn."
- `roblox/tests/Glyphs.spec.luau` — **new.** Lune tests for `Glyphs.parts`.
- `roblox/src/shared/DrumStep.luau` — **modify.** Generalize 6→12 faces.
- `roblox/tests/DrumStep.spec.luau` — **modify.** 12-face assertions.
- `roblox/tools/builders/ArenaLayout.luau` — **modify.** `throwDrum` becomes a vertical 12-facet lantern (radius 11, height, faces 12, windows 4; drop `yaw`/`southSpokeR`).
- `roblox/tools/builders/ThrowDrum.luau` — **rewrite.** Vertical-axis 12-facet drum + 4-post shade + kasa cap + finial + base + interior lamp.
- `roblox/tests/ThrowDrum.spec.luau` — **rewrite.** New parts contract.
- `roblox/assets/ThrowDrum.model.json` — **regenerated** (never hand-edited).
- `roblox/src/client/DrumController.client.luau` — **rewrite.** Local-Y spin, `Glyphs.render` glyphs, 90° detents; reveal state machine preserved.

---

## Task 1: `Glyphs` shared module (pure `parts` + runtime `render`)

**Files:**
- Create: `roblox/src/shared/Glyphs.luau`
- Test: `roblox/tests/Glyphs.spec.luau`

**Interfaces:**
- Produces:
  - `Glyphs.parts(symbol: "R"|"P"|"S", coreColor: {number}, opts: {outlineColor: {number}?}?) : { GlyphPart }` — pure. `GlyphPart = { kind: "ring"|"bar", color: {number}, thickness: number?, pos: {number}?, size: {number}?, rotation: number? }`. `ring` uses `thickness` (fraction of the glyph square). `bar` uses `pos` (scale center, anchor 0.5), `size` (scale w,h), `rotation` (deg). Order = paint order (outline first, core second). Default `outlineColor` = white `{1,1,1}`.
  - `Glyphs.render(parent: Instance, symbol, coreColor: Color3, sizePx: number, opts?) : Frame` — runtime; builds a square, aspect-locked `Frame` named `"Glyph"` under `parent` and populates it from `parts`. `sizePx` sizes the ring `UIStroke.Thickness`.

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local Glyphs = require("../src/shared/Glyphs")
local describe, test, expect = harness.describe, harness.test, harness.expect

local GOLD = { 0.83, 0.69, 0.40 }

describe("Glyphs.parts", function()
    test("rock is an outlined ring: white outline behind, colored core in front", function()
        local p = Glyphs.parts("R", GOLD)
        expect(#p).toBe(2)
        expect(p[1].kind).toBe("ring")
        expect(p[2].kind).toBe("ring")
        -- outline is white and thicker than the core
        expect(p[1].color[1]).toBe(1)
        expect(p[1].color[2]).toBe(1)
        expect(p[1].color[3]).toBe(1)
        expect(p[1].thickness > p[2].thickness).toBe(true)
        -- core carries the requested color
        expect(p[2].color[1]).toBe(GOLD[1])
    end)

    test("paper is an outlined horizontal bar (outline taller than core, both centered)", function()
        local p = Glyphs.parts("P", GOLD)
        expect(#p).toBe(2)
        expect(p[1].kind).toBe("bar")
        expect(p[2].kind).toBe("bar")
        expect(p[1].size[2] > p[2].size[2]).toBe(true) -- outline height > core height
        expect(p[1].pos[2]).toBe(0.5) -- centered vertically
        expect(p[1].rotation).toBe(0)
    end)

    test("scissors is an upward chevron: two mirrored arms, apex up", function()
        local p = Glyphs.parts("S", GOLD)
        expect(#p).toBe(4) -- 2 arms x (outline + core)
        -- every arm centre sits in the upper half (apex up => arm midpoints above 0.5)
        for _, part in p do
            expect(part.kind).toBe("bar")
            expect(part.pos[2] < 0.5).toBe(true)
        end
        -- arms mirror about x=0.5: at least one left (x<0.5) and one right (x>0.5)
        local left, right = false, false
        for _, part in p do
            if part.pos[1] < 0.5 then
                left = true
            elseif part.pos[1] > 0.5 then
                right = true
            end
        end
        expect(left and right).toBe(true)
    end)

    test("outlineColor override is honored", function()
        local p = Glyphs.parts("P", GOLD, { outlineColor = { 0, 0, 0 } })
        expect(p[1].color[1]).toBe(0)
        expect(p[1].color[2]).toBe(0)
        expect(p[1].color[3]).toBe(0)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `Glyphs` module not found / `Glyphs.parts` nil.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/Glyphs.luau`:

```lua
--!strict
-- Shared R/P/S glyph geometry — the single source of truth for how a World-Throw
-- symbol is drawn, mirroring the PWA's src/components/Symbols.tsx. Each glyph is a
-- colored CORE flanked by a white OUTLINE (the SVG's two-pass stroke):
--   Rock  = a ring          (circle, white stroke 4.5 then color 2.5)
--   Paper = a rounded bar    (line,  white stroke 5   then color 3)
--   Scissors = ∧ chevron     (apex up, white 4.5 then color 2.5)
-- `parts` is PURE (colors are {r,g,b} arrays, no Instances) so it is Lune-tested;
-- `render` turns descriptors into native UI at runtime (Color3/Instance only here).
local Glyphs = {}

export type GlyphPart = {
    kind: string, -- "ring" | "bar"
    color: { number }, -- {r,g,b} 0..1
    thickness: number?, -- ring: stroke width as a fraction of the glyph square
    pos: { number }?, -- bar: {x,y} scale of centre (anchor 0.5,0.5)
    size: { number }?, -- bar: {w,h} scale
    rotation: number?, -- bar: degrees
}

local WHITE = { 1, 1, 1 }

-- Ring stroke fractions (SVG r=8 of 24; white 4.5 / color 2.5 → ~0.19 / ~0.10).
local RING_OUT, RING_CORE = 0.19, 0.10
-- Bar heights (SVG white 5 / color 3 of 24 → ~0.21 / ~0.125); paper width ≈ 14/24.
local BAR_OUT_H, BAR_CORE_H, BAR_W = 0.21, 0.125, 0.60
-- Chevron arm geometry: two bars from the apex (top-centre) down to the lower corners.
-- SVG (12,9)→(6,15) and (12,9)→(18,15): 45° arms, length √72/24 ≈ 0.354, mids at
-- (9,12) and (15,12) of 24 → scale (0.375,0.5) and (0.625,0.5). Apex-up ⇒ mids above
-- the glyph centre after we re-base y to the 0.30..0.70 band the chevron occupies.
local CHEV_LEN = 0.42
local CHEV_OUT_H, CHEV_CORE_H = 0.19, 0.10

function Glyphs.parts(symbol: string, coreColor: { number }, opts: { outlineColor: { number }? }?): { GlyphPart }
    local outline = (opts and opts.outlineColor) or WHITE
    if symbol == "R" then
        return {
            { kind = "ring", color = outline, thickness = RING_OUT },
            { kind = "ring", color = coreColor, thickness = RING_CORE },
        }
    elseif symbol == "P" then
        return {
            { kind = "bar", color = outline, pos = { 0.5, 0.5 }, size = { BAR_W, BAR_OUT_H }, rotation = 0 },
            { kind = "bar", color = coreColor, pos = { 0.5, 0.5 }, size = { BAR_W, BAR_CORE_H }, rotation = 0 },
        }
    else -- "S": ∧ apex up. Left arm rotated -45°, right arm +45°; both mids in the upper band.
        local ly, ry = 0.42, 0.42 -- arm-midpoint y (< 0.5 ⇒ apex-up region)
        return {
            { kind = "bar", color = outline, pos = { 0.34, ly }, size = { CHEV_LEN, CHEV_OUT_H }, rotation = -45 },
            { kind = "bar", color = outline, pos = { 0.66, ry }, size = { CHEV_LEN, CHEV_OUT_H }, rotation = 45 },
            { kind = "bar", color = coreColor, pos = { 0.34, ly }, size = { CHEV_LEN, CHEV_CORE_H }, rotation = -45 },
            { kind = "bar", color = coreColor, pos = { 0.66, ry }, size = { CHEV_LEN, CHEV_CORE_H }, rotation = 45 },
        }
    end
end

-- Runtime: build the native UI. Color3/Instance APIs live ONLY here.
function Glyphs.render(parent: Instance, symbol: string, coreColor: Color3, sizePx: number, opts: { outlineColor: { number }? }?): Frame
    local root = Instance.new("Frame")
    root.Name = "Glyph"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    local ar = Instance.new("UIAspectRatioConstraint") -- keep the glyph square so the ring stays round
    ar.AspectRatio = 1
    ar.Parent = root

    local function c3(rgb: { number }): Color3
        return Color3.new(rgb[1], rgb[2], rgb[3])
    end

    for _, p in Glyphs.parts(symbol, { coreColor.R, coreColor.G, coreColor.B }, opts) do
        if p.kind == "ring" then
            local f = Instance.new("Frame")
            f.BackgroundTransparency = 1
            f.Size = UDim2.fromScale(0.9, 0.9)
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale(0.5, 0.5)
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = f
            local stroke = Instance.new("UIStroke")
            stroke.Color = c3(p.color)
            stroke.Thickness = math.max(1, math.round((p.thickness :: number) * sizePx))
            stroke.Parent = f
            f.Parent = root
        else -- bar
            local f = Instance.new("Frame")
            f.BackgroundColor3 = c3(p.color)
            f.BorderSizePixel = 0
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Position = UDim2.fromScale((p.pos :: { number })[1], (p.pos :: { number })[2])
            f.Size = UDim2.fromScale((p.size :: { number })[1], (p.size :: { number })[2])
            f.Rotation = p.rotation or 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0) -- capsule (rounded caps)
            corner.Parent = f
            f.Parent = root
        end
    end

    root.Parent = parent
    return root
end

return Glyphs
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (all four `Glyphs.parts` tests green; the rest of the suite unaffected).

- [ ] **Step 5: Lint/format**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean (run `stylua src tests` to auto-format if `--check` complains).

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/Glyphs.luau roblox/tests/Glyphs.spec.luau
git commit -m "feat(roblox): shared Glyphs module (approved PWA R/P/S artwork as native UI)"
```

---

## Task 2: `DrumStep` — generalize 6→12 faces

**Files:**
- Modify: `roblox/src/shared/DrumStep.luau`
- Test: `roblox/tests/DrumStep.spec.luau`

**Interfaces:**
- Consumes: nothing new.
- Produces (signatures unchanged; face count now 12): `DrumStep.faceForThrow(throw): number` (0/1/2), `DrumStep.symmetric(index): number` (`(index+3)%12`), `DrumStep.landingStep(currentFace, throw): number` (1..3 steps ahead, `result%3 == faceForThrow(throw)`).

- [ ] **Step 1: Rewrite the test**

Replace the body of `roblox/tests/DrumStep.spec.luau` with:

```lua
--!strict
local harness = require("./harness")
local DrumStep = require("../src/shared/DrumStep")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("DrumStep (12 faces)", function()
    test("faceForThrow maps R/P/S to 0/1/2", function()
        expect(DrumStep.faceForThrow("R")).toBe(0)
        expect(DrumStep.faceForThrow("P")).toBe(1)
        expect(DrumStep.faceForThrow("S")).toBe(2)
    end)
    test("symmetric steps +3 (90 degrees) and preserves the symbol", function()
        for i = 0, 11 do
            expect(DrumStep.symmetric(i)).toBe((i + 3) % 12)
            expect(DrumStep.symmetric(i) % 3).toBe(i % 3)
        end
    end)
    test("landingStep lands on the throw's symbol within 1..3 steps, over 12 faces", function()
        for cur = 0, 11 do
            for _, t in { "R", "P", "S" } do
                local f = DrumStep.landingStep(cur, t)
                expect(f % 3).toBe(DrumStep.faceForThrow(t))
                local steps = (f - cur) % 12
                expect(steps >= 1 and steps <= 3).toBe(true)
            end
        end
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `symmetric(i)` returns `(i+3)%6` (wrong for i≥3), `landingStep` mods 6.

- [ ] **Step 3: Update the module**

Replace `roblox/src/shared/DrumStep.luau` with:

```lua
--!strict
-- Pure index math for the World-Throw drum. 12 facets 0..11 around the vertical
-- axis; face index % 3 → symbol (0=R, 1=P, 2=S). R,P,S repeats FOUR times around the
-- ring, so a symbol recurs every 3 facets (90°) and all four windows (90° apart)
-- show the same symbol at every detent.
local DrumStep = {}

local FACES = 12
local SYMBOLS = { R = 0, P = 1, S = 2 }

-- the low face index (0..2) carrying this throw's symbol
function DrumStep.faceForThrow(throw: string): number
    return SYMBOLS[throw] or 0
end

-- the next same-symbol face 90° around (used by consumers reasoning about windows)
function DrumStep.symmetric(index: number): number
    return (index + 3) % FACES
end

-- Continuing +1 detent stepping from `currentFace`, the next face that brings
-- `throw`'s symbol to the window. Always 1..3 steps ahead; result % 3 == faceForThrow.
function DrumStep.landingStep(currentFace: number, throw: string): number
    local target = DrumStep.faceForThrow(throw)
    for m = 1, 3 do
        local face = (currentFace + m) % FACES
        if face % 3 == target then
            return face
        end
    end
    return currentFace -- unreachable (a match exists within 3 steps)
end

return DrumStep
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint + commit**

```bash
cd roblox && stylua --check src tests && selene src
git add roblox/src/shared/DrumStep.luau roblox/tests/DrumStep.spec.luau
git commit -m "feat(roblox): generalize DrumStep 6→12 faces (mawari-dōrō)"
```

---

## Task 3: `ThrowDrum` builder rewrite + `ArenaLayout` + regen

**Files:**
- Modify: `roblox/tools/builders/ArenaLayout.luau:170` (the `throwDrum` line)
- Rewrite: `roblox/tools/builders/ThrowDrum.luau`
- Rewrite: `roblox/tests/ThrowDrum.spec.luau`
- Regenerate: `roblox/assets/ThrowDrum.model.json`

**Interfaces:**
- Consumes: `Spec` (`part`/`model`/`cframe`/`yaw`), `ArenaLayout.throwDrum` (`pos`, `radius`, `height`, `faces`, `windows`), `palette.cypressWeathered`/`.slateTile`/`.gold`/`.ink`.
- Produces: `ThrowDrum.build(palette, L) : Spec.PartSpec` — a `Model "ThrowDrum"` with children `Drum` (invisible vertical hub), `Face0`–`Face11` (cypress facets), `Post1`–`Post4` (shade uprights), `RoofCap`, `Finial`, `Base`, `Lamp` (a `PointLight` host). `ThrowDrum.SYMBOL_FOR_FACE[k]` = `"R"|"P"|"S"` for k=0..11 (k%3).

- [ ] **Step 1: Update `ArenaLayout.throwDrum`**

In `roblox/tools/builders/ArenaLayout.luau`, replace the `throwDrum = { ... }` line (currently line ~170) with:

```lua
    -- Mawari-dōrō revolving lantern (vertical axis) crowning the shōrō. radius from the
    -- 12-facet glyph legibility ("Beacon", ~56% of the 39-stud roof); height is squat.
    -- All four windows (90° apart) read the same symbol; the drive-linkage reconnect is T8.
    throwDrum = { pos = { -2, 148, 0 }, radius = 11, height = 9, faces = 12, windows = 4 },
```

(Also delete any now-unused `throwDrum.southSpokeR`/`yaw`/`length` references — they are only used by the old builder, rewritten below. Leave `bellDrive` untouched; its pin-wheel parts still exist and the controller still animates them.)

- [ ] **Step 2: Rewrite the test (new parts contract)**

Replace `roblox/tests/ThrowDrum.spec.luau` with:

```lua
--!strict
local harness = require("./harness")
local ThrowDrum = require("../tools/builders/ThrowDrum")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function childNames(spec)
    local names = {}
    for _, c in spec.children :: any do
        names[c.name] = true
    end
    return names
end

describe("ThrowDrum mawari-dōrō builder", function()
    test("hub + 12 facets + 4 shade posts + cap/finial/base/lamp", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local names = childNames(spec)
        expect(names["Drum"]).toBe(true)
        for k = 0, 11 do
            expect(names["Face" .. k]).toBe(true)
        end
        for i = 1, 4 do
            expect(names["Post" .. i]).toBe(true)
        end
        expect(names["RoofCap"]).toBe(true)
        expect(names["Finial"]).toBe(true)
        expect(names["Base"]).toBe(true)
        expect(names["Lamp"]).toBe(true)
    end)

    test("exactly 12 facets, no leftover horizontal-drum parts", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local faces, shafts, spokes = 0, 0, 0
        for _, c in spec.children :: any do
            if (c.name :: string):match("^Face%d+$") then
                faces += 1
            elseif c.name == "Shaft" then
                shafts += 1
            elseif (c.name :: string):match("^Spoke%d+$") then
                spokes += 1
            end
        end
        expect(faces).toBe(12)
        expect(shafts).toBe(0) -- vertical lantern: no horizontal axle
        expect(spokes).toBe(0)
    end)

    test("facets carry R,P,S repeated ×4 (k % 3)", function()
        local expected = { [0] = "R", [1] = "P", [2] = "S" }
        for k = 0, 11 do
            expect(ThrowDrum.SYMBOL_FOR_FACE[k]).toBe(expected[k % 3])
        end
    end)

    test("hub sits at the layout throwDrum position (centred over the roof)", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "Drum" then
                expect(math.abs(c.properties.CFrame[1] - L.throwDrum.pos[1]) < 0.01).toBe(true)
                expect(math.abs(c.properties.CFrame[2] - L.throwDrum.pos[2]) < 0.01).toBe(true)
                expect(math.abs(c.properties.CFrame[3] - L.throwDrum.pos[3]) < 0.01).toBe(true)
            end
        end
    end)

    test("facets use the CypressWeathered variant", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if (c.name :: string):match("^Face%d+$") then
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
    end)
end)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — old builder emits `Shaft`, 6 faces, no `Post`/`RoofCap`; `SYMBOL_FOR_FACE[6]` nil.

- [ ] **Step 4: Rewrite the builder**

Replace `roblox/tools/builders/ThrowDrum.luau` with:

```lua
--!strict
-- Mawari-dōrō revolving lantern crowning the shōrō (replaces the horizontal hex drum).
-- A squat 12-facet inner drum rotates on a VERTICAL axis behind a fixed 4-window outer
-- shade. Facets carry R,P,S ×4, so all four windows (90° apart) show the same symbol and a
-- 30° step advances all four. Glyphs are attached at runtime by DrumController (Glyphs.render
-- on a SurfaceGui, LightInfluence 0). The interior Lamp makes it glow at night; the opaque
-- cypress goes dark so only the always-bright glyph reads (day gold-on-cypress, night lit).
-- The DrumController spins the invisible `Drum` hub about its LOCAL Y.
local Spec = require("./Spec")

local ThrowDrum = {}

-- face index → glyph; k % 3 picks R/P/S. Exposed for tests + the controller.
ThrowDrum.SYMBOL_FOR_FACE = {} :: { [number]: string }
do
    local sym = { [0] = "R", [1] = "P", [2] = "S" }
    for k = 0, 11 do
        ThrowDrum.SYMBOL_FOR_FACE[k] = sym[k % 3]
    end
end

function ThrowDrum.build(palette: { [string]: { number } }, L: any): Spec.PartSpec
    local d = L.throwDrum
    local px, py, pz = d.pos[1], d.pos[2], d.pos[3]
    local r, h, faces = d.radius, d.height, d.faces
    local cyp = palette.cypressWeathered
    local slate = palette.slateTile
    local gold = palette.gold
    local ink = palette.ink

    local step = (2 * math.pi) / faces -- 30°
    local apothem = r * math.cos(math.pi / faces) -- centre→facet midpoint
    local side = 2 * r * math.sin(math.pi / faces) -- facet chord
    local faceW = side * 1.02 -- slight overlap so facets meet at the vertices

    local top: { Spec.PartSpec } = {}

    -- Invisible vertical-axis hub: its LOCAL Y is the spin axis the controller turns.
    table.insert(
        top,
        Spec.part("Drum", {
            Size = { 2 * r, h, 2 * r },
            CFrame = Spec.cframe({ px, py, pz }),
            Transparency = 1,
            CanCollide = false,
            Color = ink,
        })
    )

    -- 12 cypress facet panels around +Y. Face 0 faces the FRONT (-Z) window; face k is
    -- yawed k*30° about +Y. Slab Front (-Z) points radially outward (the showing side,
    -- where DrumController puts the glyph SurfaceGui).
    for k = 0, faces - 1 do
        local adeg = k * (360 / faces)
        local a = math.rad(adeg)
        local fx = px - apothem * math.sin(a)
        local fz = pz - apothem * math.cos(a)
        table.insert(
            top,
            Spec.part(`Face{k}`, {
                Size = { faceW, h, 0.5 },
                CFrame = Spec.cframe({ fx, py, fz }, Spec.yaw(adeg)),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end

    -- Fixed outer shade: 4 corner posts at the 45° diagonals (between the N/E/S/W windows),
    -- standing just outside the facet ring. The gaps between posts ARE the four windows.
    local postR = r + 1.2
    local postH = h + 2
    for i = 1, 4 do
        local a = math.rad(45 + (i - 1) * 90)
        table.insert(
            top,
            Spec.part(`Post{i}`, {
                Size = { 1.4, postH, 1.4 },
                CFrame = Spec.cframe({ px + postR * math.sin(a), py, pz + postR * math.cos(a) }),
                Color = cyp,
                Material = "Wood",
                MaterialVariant = "CypressWeathered",
            })
        )
    end

    -- Base ring the lantern seats on (bronze-banded cypress collar just under the facets).
    table.insert(
        top,
        Spec.part("Base", {
            Size = { 2 * (r + 1.6), 1.4, 2 * (r + 1.6) },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, py - h / 2 - 0.7, pz }, Spec.ROT.CYL_VERTICAL),
            Color = cyp,
            Material = "Wood",
            MaterialVariant = "CypressWeathered",
        })
    )

    -- Kasa cap (FIRST PASS — a wide low kawara disc; live-tuned into a miniature hip roof
    -- later, see the live gate). Sits on the post tops, overhanging the windows for shade.
    local capY = py + postH / 2 + 0.8
    table.insert(
        top,
        Spec.part("RoofCap", {
            Size = { 2 * (postR + 2.5), 1.6, 2 * (postR + 2.5) },
            Shape = "Cylinder",
            CFrame = Spec.cframe({ px, capY, pz }, Spec.ROT.CYL_VERTICAL),
            Color = slate,
            Material = "Slate",
            MaterialVariant = "SlateTile",
        })
    )

    -- Gilt hōju finial on the cap (a small sphere + a short spike stub, one part each).
    table.insert(
        top,
        Spec.part("Finial", {
            Size = { 2.2, 2.2, 2.2 },
            Shape = "Ball",
            CFrame = Spec.cframe({ px, capY + 1.8, pz }),
            Color = gold,
            Material = "Metal",
            MaterialVariant = "IronDark",
        })
    )

    -- Interior lamp: warm point light for the night bloom; hosted on a tiny invisible part
    -- at the hub centre (the controller does not spin it — symmetric, invisible).
    table.insert(
        top,
        Spec.part("Lamp", {
            Size = { 0.6, 0.6, 0.6 },
            CFrame = Spec.cframe({ px, py, pz }),
            Transparency = 1,
            CanCollide = false,
            Color = gold,
            children = {
                {
                    name = "LampLight",
                    className = "PointLight",
                    properties = {
                        Color = Color3.new(gold[1], gold[2], gold[3]),
                        Brightness = 2,
                        Range = 18,
                    },
                },
            },
        })
    )

    return Spec.model("ThrowDrum", top)
end

return ThrowDrum
```

> Note: the `Lamp`'s child `PointLight` uses `Color3.new` — this file is a **builder** run under Lune by `genmodels`, not a Lune *test*. `genmodels` provides `Color3`; the `ThrowDrum.spec` tests only inspect the returned table's `name`/`properties.CFrame`/`MaterialVariant`, never the `PointLight` child, so the pure tests stay Lune-safe. If `genmodels` errors on `Color3.new`, emit the child light color as a plain property table instead (match how existing builders emit light children — grep `PointLight` in `tools/builders`).

- [ ] **Step 5: Run test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS (all `ThrowDrum` + unchanged suites green).

- [ ] **Step 6: Regenerate the model + verify determinism**

```bash
cd roblox && lune run tools/genmodels && lune run tools/genmodels
git diff --stat assets/
```
Expected: `assets/ThrowDrum.model.json` shows as changed **once**; the second `genmodels` run leaves it byte-identical (no further diff). If it flickers, snap near-zero residues in `JsonEmit` (see the arch-portability memory) — but the existing `Spec.cframe` path already handles this.

- [ ] **Step 7: Lint + commit**

```bash
cd roblox && stylua --check src tests tools && selene src
git add roblox/tools/builders/ThrowDrum.luau roblox/tools/builders/ArenaLayout.luau roblox/tests/ThrowDrum.spec.luau roblox/assets/ThrowDrum.model.json
git commit -m "feat(roblox): mawari-dōrō lantern geometry — 12 facets, 4-post shade, kasa cap"
```

---

## Task 4: `DrumController` rewrite — vertical spin, `Glyphs` glyphs, 90° detents (live gate)

**Files:**
- Rewrite: `roblox/src/client/DrumController.client.luau`

**Interfaces:**
- Consumes: `Glyphs.render`, `DrumStep.faceForThrow`, `ThrowDrum.SYMBOL_FOR_FACE` (via `require` of the shared modules), the built `Workspace.RoshamboStage.ThrowDrum` (`Drum`, `Face0`–`Face11`), the `BellDrive` pin-wheel parts, `RoundUpdate`/`RevealTheater` remotes, `EventBus` (`gongHit` in, `drumRest` out).
- Produces: no new exports (runtime controller).

This controller is Roblox-runtime (creates Instances, uses services) → **not Lune-testable**; it is validated at the **live gate**. Its reveal state machine is preserved verbatim except: spin axis X→Y, `applyTheta` rotates about local Y, `landTargetFor` steps by π/2 with a `-sym*30°` front detent, and glyphs come from `Glyphs.render` (not Unicode `TextLabel`s).

- [ ] **Step 1: Rewrite the controller**

Replace `roblox/src/client/DrumController.client.luau` with:

```lua
--!strict
-- Drives the mawari-dōrō revolving lantern atop the shōrō. It RESTS through ACTIVE + TALLY
-- showing the prior throw; on the bell strike (`gongHit`) the inner 12-facet drum is kicked
-- into a fast spin about its VERTICAL axis and DECELERATES to rest on the actual World Throw
-- (that becomes the next round's "prior"). Four windows 90° apart all read the same symbol.
-- Offset-capture pattern (cf. WheelController). Glyphs come from the shared Glyphs module and
-- are always full-bright (SurfaceGui LightInfluence 0) so they read gold-on-cypress by day and
-- as a lit glyph on the darkened wood by night. The pin-wheel flick is preserved as ambient
-- machinery (its physical reconnection to the vertical drum is the T8 drive-chain pass).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local DrumStep = require(shared:WaitForChild("DrumStep"))
local Glyphs = require(shared:WaitForChild("Glyphs"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("ThrowDrum")
local drum = rig:WaitForChild("Drum") :: BasePart
local hub = drum.CFrame

local FACES = 12
local GOLD = Color3.fromRGB(212, 176, 102)

-- SYMBOL_FOR_FACE (k % 3). Mirrors ThrowDrum.SYMBOL_FOR_FACE without requiring the builder
-- (builders live under tools/ and are not replicated to clients).
local SYMBOL_FOR_FACE: { [number]: string } = {}
do
    local sym = { [0] = "R", [1] = "P", [2] = "S" }
    for k = 0, FACES - 1 do
        SYMBOL_FOR_FACE[k] = sym[k % 3]
    end
end

-- Capture each facet's offset from the hub so we can re-place it under any hub rotation.
-- Only the 12 facets spin (the shade posts/cap/base/lamp are static). The glyph SurfaceGui
-- is parented to each facet, so it rides along automatically.
local spinParts: { BasePart } = {}
local spinOffsets: { CFrame } = {}
for k = 0, FACES - 1 do
    local face = rig:WaitForChild("Face" .. k) :: BasePart
    table.insert(spinParts, face)
    table.insert(spinOffsets, hub:ToObjectSpace(face.CFrame))
    -- attach the always-bright approved glyph on the facet's outward (Front, -Z) side
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(200, 200)
    gui.LightInfluence = 0
    gui.Parent = face
    Glyphs.render(gui, SYMBOL_FOR_FACE[k], GOLD, 200)
end

-- MOTION (strike-keyed), preserved from the hex drum but on the VERTICAL axis.
-- Spin is about the hub's LOCAL Y. Symbol `sym` sits at the −Z front window when
-- θ ≡ −sym*30° (mod 360); symbols recur every 3 facets → a detent every 90° (π/2).
local DRUM_KICK = 4 -- rad/s during the constant spin (live-tunable via "DrumKick" attr)
local SPIN_SEC = 1.0
local GLIDE_SEC = 2.0
local KICK_DUR = 0.5

local theta = 0
local omega = 0
local mode = "hold"
local spinUntil = 0
local glideT0 = 0
local glideP0 = 0
local glideD = 0
local landTheta = 0
local strikeT0 = -1
local latestWorldThrow: string? = nil

-- PIN-WHEEL parts that flick on the strike (BellDrive) — unchanged; ambient machinery.
local bell = stage:WaitForChild("BellDrive")
local kickParts: { any } = {}
local function addKick(name: string, px: number, pz: number, sign: number)
    local p = bell:FindFirstChild(name)
    if p and p:IsA("BasePart") then
        table.insert(kickParts, { part = p, restCF = p.CFrame, restY = p.Position.Y, px = px, pz = pz, sign = sign })
    end
end
addKick("VertShaft", 1, 6, -1)
addKick("VertPaddle", 1, 6, -1)
addKick("DriveGearA", 1, 6, -1)
addKick("DriveGearB", -1.18, 7, 1)
addKick("DrivePaddle", -1.18, 7, 1)
local kickT0 = -1
local kickBase = 0
local function applyKick(angle: number)
    for _, k in kickParts do
        local piv = CFrame.new(k.px, k.restY, k.pz)
        k.part.CFrame = piv * CFrame.Angles(0, k.sign * angle, 0) * piv:Inverse() * k.restCF
    end
end

local function applyTheta()
    local spun = hub * CFrame.Angles(0, theta, 0) -- LOCAL Y is the spin axis
    for i, p in spinParts do
        p.CFrame = spun * spinOffsets[i]
    end
end

-- Resting θ showing `throw` at the −Z window, at least `dmin` below current θ (keeps the
-- drum turning one direction into rest). Detents for a symbol recur every π/2 (90°).
local function landTargetFor(throw: string, dmin: number): number
    local sym = DrumStep.faceForThrow(throw) -- 0/1/2
    local tgt = math.rad(-sym * 30) -- a detent with `sym` at the −Z front window
    while tgt > theta - dmin do
        tgt -= math.pi / 2 -- step down a quarter-turn (continuing the −θ direction)
    end
    return tgt
end

applyTheta()

RunService.Heartbeat:Connect(function(_dt)
    if mode == "spin" then
        theta -= omega * _dt
        if os.clock() >= spinUntil then
            local throw = latestWorldThrow or "R"
            landTheta = landTargetFor(throw, omega * GLIDE_SEC / 2)
            glideP0 = theta
            glideD = theta - landTheta
            glideT0 = os.clock()
            mode = "glide"
        end
        applyTheta()
    elseif mode == "glide" then
        local s = (os.clock() - glideT0) / GLIDE_SEC
        if s >= 1 then
            theta = landTheta
            omega = 0
            mode = "hold"
            EventBus.Cue:Fire({ kind = "drumRest" })
        else
            theta = glideP0
                - glideD * (3 * s * s - 2 * s * s * s)
                - omega * GLIDE_SEC * (s * s * s - 2 * s * s + s)
        end
        applyTheta()
    end
    if kickT0 >= 0 then
        local prog = (os.clock() - kickT0) / KICK_DUR
        if prog >= 1 then
            applyKick(kickBase + math.pi)
            kickBase += math.pi
            kickT0 = -1
        else
            applyKick(kickBase + math.pi * (1 - (1 - prog) * (1 - prog)))
        end
    end
end)

RevealTheater.OnClientEvent:Connect(function(reveal)
    latestWorldThrow = reveal.worldThrow
end)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" and mode ~= "hold" and strikeT0 >= 0 then
        if os.clock() - strikeT0 > SPIN_SEC + GLIDE_SEC + 1 then
            if latestWorldThrow then
                landTheta = landTargetFor(latestWorldThrow, 0)
            end
            theta = landTheta
            omega = 0
            mode = "hold"
            applyTheta()
        end
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongHit" then
        local throw = latestWorldThrow
        if not throw then
            return
        end
        latestWorldThrow = throw
        omega = (stage:GetAttribute("DrumKick") :: number) or DRUM_KICK
        spinUntil = os.clock() + SPIN_SEC
        strikeT0 = os.clock()
        mode = "spin"
        kickT0 = os.clock()
    end
end)
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src && selene src`
Expected: clean.

- [ ] **Step 3: Live gate in Studio (ONE attempt, then STOP and show the user)**

With `rojo serve` running and connected (the regenerated `ThrowDrum.model.json` + new `Glyphs`/`DrumController` sync in automatically), use the Roblox_Studio MCP:

1. `get_studio_state`; ensure Edit mode. The new lantern should be visible at `Workspace.RoshamboStage.ThrowDrum`.
2. `screen_capture` the crown composition (camera roughly `[34,150,34]` → `[-2,148,0]`) — confirm: squat cypress lantern, 4 windows, a legible gold **outlined** glyph in each window, all four the same, kasa cap + finial reading against the roofline (not top-heavy). Reset `CameraType=Custom` after any camera-arg capture (avoids locking the user's viewport).
3. **Verify day/night:** temporarily set `Lighting.ClockTime` to ~2 (night) and confirm the field darkens while the glyph stays lit and the interior `PointLight` halos; restore `ClockTime`.
4. **Play** (`start_stop_play`) and watch a full round (needs the backend loop — `docker compose up` if the striker only trembles): confirm the lantern **rests** on the prior throw, **spins** on the bell strike, and **glides to rest showing the actual World Throw** (cross-check the HUD/board). **If it lands on the WRONG symbol or spins the wrong way, flip the sign** of `theta` in `applyTheta` (`CFrame.Angles(0, -theta, 0)`) **or** the `-sym*30` in `landTargetFor` — one sign flip fixes it — then re-verify.
5. **STOP. Show the user the capture(s)** and the landing behavior. Do NOT tune proportions/cap further without their look. Likely live-tune items to raise: kasa cap → miniature hip roof, `radius`/`height`, glyph `sizePx`/canvas, `Lamp` brightness/range, `Post` thickness.

- [ ] **Step 4: Commit (after the user's look)**

```bash
cd roblox && stylua --check src && selene src
git add roblox/src/client/DrumController.client.luau
git commit -m "feat(roblox): DrumController drives the vertical mawari-dōrō (Glyphs, 90° detents)"
```

(Any place-state tuning the user approves — MaterialVariants, ClockTime, attribute tweaks — is saved with the place, not committed here.)

---

## Self-Review

**Spec coverage:**
- Mawari-dōrō form / 12 facets / 4 windows / vertical axis → Tasks 3 (geometry) + 4 (controller). ✓
- All-four-windows-agree (RPS×4, 30° step, 90° detents) → `DrumStep` (Task 2) + `landTargetFor` (Task 4) + `SYMBOL_FOR_FACE` (Task 3). ✓
- Gray cypress + slate cap + gold, day/night via opaque field + always-bright glyph + interior lamp → Task 3 (`MaterialVariant`, `Lamp`) + Task 4 (`LightInfluence=0`). ✓
- Approved PWA glyphs as native UI, recolorable, no images → Task 1. ✓ (∧-up baked into `Glyphs.parts` "S".)
- Crown composition (squat Beacon r11, cap, finial, base) → Task 3. ✓
- Behavior preserved (rest→spin→glide→detent) → Task 4 (verbatim state machine). ✓
- Scope boundary: pin-wheel left as ambient machinery (T8 reconnect); chōchin/HUD deferred to Plan B; boards deferred. ✓ (stated in header + Task 4).
- Testing (Glyphs.spec, DrumStep.spec, ThrowDrum.spec, determinism, live gate) → all present. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code; the kasa cap is an explicit, functional first-pass with a named live-tune step (not a placeholder). ✓

**Type consistency:** `Glyphs.parts`/`render`, `Glyphs.render(parent, symbol, coreColor: Color3, sizePx, opts)` used identically in Task 1 and Task 4. `DrumStep.faceForThrow` returns 0/1/2 in Tasks 2 & 4. `SYMBOL_FOR_FACE[k]` = `"R"|"P"|"S"` in Tasks 3 & 4. `throwDrum` fields (`pos/radius/height/faces/windows`) consistent across Tasks 3 & 4. `EventBus` cues `gongHit`/`drumRest` unchanged. ✓

## Execution Handoff

Two execution options:
1. **Subagent-Driven (recommended)** — a fresh subagent per task with review between tasks.
2. **Inline Execution** — batch the tasks in this session with checkpoints.
