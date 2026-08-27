### Task 1: Real glyphs on the canyon lanterns

The canonical glyph assets exist in `src/shared/Glyphs.luau` but only `DrumController` uses them. `LanternController` renders Unicode text, so every lantern up both gorge walls shows an approximation. Independent of the rest of the plan — land it first.

`BoardController.client.luau:28` has the same dead table, but that controller early-returns because `JumbotronBoard` was removed in the T23 redesign and is absent from `default.project.json`. **Leave it alone** — do not "fix" a renderer that never runs.

**Files:**
- Modify: `roblox/src/shared/Glyphs.luau` (add `renderGroup`)
- Modify: `roblox/src/client/LanternController.client.luau:20, 68-86, 144-164, 176-200`
- Test: `roblox/tests/Glyphs.spec.luau`

**Interfaces:**
- Produces: `Glyphs.renderGroup(parent: Instance, symbol: string, coreColor: Color3, outlineColor: Color3?): CanvasGroup` — the two glyph layers inside an aspect-locked `CanvasGroup` so a caller fades the whole glyph with one `GroupTransparency` tween.

- [ ] **Step 1: Write the failing test**

`Glyphs.render*` builds Instances and cannot run under Lune, so test the data that a typo would silently break — the asset table.

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local Glyphs = require("../src/shared/Glyphs")

describe("Glyphs.IMAGE", function()
    test("every throw has a core and an outline layer", function()
        for _, sym in { "R", "P", "S" } do
            local layers = Glyphs.IMAGE[sym]
            expect(layers ~= nil).toBe(true)
            expect(typeof(layers.core) == "string").toBe(true)
            expect(typeof(layers.outline) == "string").toBe(true)
            expect(layers.core:match("^rbxassetid://%d+$") ~= nil).toBe(true)
            expect(layers.outline:match("^rbxassetid://%d+$") ~= nil).toBe(true)
        end
    end)

    test("no two layers share an asset id", function()
        -- a copy-paste in this table renders the wrong throw on every lantern in the canyon
        local seen: { [string]: boolean } = {}
        for _, sym in { "R", "P", "S" } do
            for _, id in { Glyphs.IMAGE[sym].core, Glyphs.IMAGE[sym].outline } do
                expect(seen[id]).toBe(nil)
                seen[id] = true
            end
        end
    end)

    test("night meshes cover the same three throws", function()
        for _, sym in { "R", "P", "S" } do
            expect(typeof(Glyphs.NIGHT.mesh[sym]) == "string").toBe(true)
        end
    end)

    test("renderGroup is exposed", function()
        expect(typeof(Glyphs.renderGroup) == "function").toBe(true)
    end)
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run from `roblox/`: `lune run tests/run`
Expected: FAIL on "renderGroup is exposed" — `typeof(nil) == "function"` is false.

- [ ] **Step 3: Add `renderGroup` to `Glyphs.luau`**

Insert after `Glyphs.render`. Same layer order as `render` (wider outline behind, core in front); the `CanvasGroup` gives the caller one transparency handle.

```luau
-- As `render`, but inside a CanvasGroup so the caller fades the whole glyph with a single
-- GroupTransparency tween. The lanterns need this: they cross-fade every reveal, and tweening
-- two ImageLabels independently drifts them out of step at the edges of the fade.
function Glyphs.renderGroup(
    parent: Instance,
    symbol: string,
    coreColor: Color3,
    outlineColor: Color3?
): CanvasGroup
    local g = Instance.new("CanvasGroup")
    g.Name = "Glyph"
    g.BackgroundTransparency = 1
    g.AnchorPoint = Vector2.new(0.5, 0.5)
    g.Position = UDim2.fromScale(0.5, 0.5)
    g.Size = UDim2.fromScale(1, 1)
    local ar = Instance.new("UIAspectRatioConstraint")
    ar.AspectRatio = 1
    ar.Parent = g

    local imgs = Glyphs.IMAGE[symbol]
    if imgs then
        local function layer(assetId: string, tint: Color3)
            local img = Instance.new("ImageLabel")
            img.BackgroundTransparency = 1
            img.Size = UDim2.fromScale(1, 1)
            img.Image = assetId
            img.ImageColor3 = tint
            img.Parent = g
        end
        layer(imgs.outline, outlineColor or coreColor)
        layer(imgs.core, coreColor)
    end

    g.Parent = parent
    return g
end
```

- [ ] **Step 4: Run the test — it should pass**

Run: `lune run tests/run` → PASS.

- [ ] **Step 5: Swap the lantern faces to real glyphs**

Four edits in `LanternController.client.luau`:

1. Delete `local GLYPH = { R = "○", P = "─", S = "∧" }` (line 20) and require `Glyphs`:

```luau
local Glyphs = require(shared:WaitForChild("Glyphs"))
```

(`shared` is already resolved in this file for `FlapScheduler`-style requires; if it is not, add
`local shared = ReplicatedStorage:WaitForChild("RoshamboShared")`.)

2. Change the tracking list's type and name — it holds groups now, not labels:

```luau
local glyphGroups: { CanvasGroup } = {}
```

3. In **both** `buildFace` (block lanterns) and `buildRoundFace` (round chōchin), replace the
`TextLabel` construction with a group. The block-lantern version, keeping its existing frame
geometry (position `0.22, 0.34`, size `0.56, 0.52`) and resting transparency of 0:

```luau
    -- glyph centered in the clear field below the double-line
    local holder = Instance.new("Frame")
    holder.Name = "GlyphHolder"
    holder.BackgroundTransparency = 1
    holder.Position = UDim2.fromScale(0.22, 0.34)
    holder.Size = UDim2.fromScale(0.56, 0.52)
    holder.Parent = gui

    local g = Glyphs.renderGroup(holder, current or "R", INK, INK)
    g:SetAttribute("ShownT", 0)
    -- late-arriving lanterns (streamed in) pick up whatever throw is currently shown
    g.GroupTransparency = if current then 0 else 1
    table.insert(glyphGroups, g)
```

The round-chōchin version is identical except it keeps its own geometry (anchor `0.5, 0.5`,
size `0.7, 0.7`) and `g:SetAttribute("ShownT", 0.2)` with `GroupTransparency = if current then 0.2 else 1`.

Note `renderGroup(holder, current or "R", ...)`: a group must be built with *some* symbol so the
layers exist; when `current` is nil it is built invisible and `showThrow` retargets it.

4. Replace the three fade/swap functions. `showThrow` can no longer set `.Text` — it must
retarget both `ImageLabel`s inside each group:

```luau
local function fadeBlank()
    for _, g in glyphGroups do
        TweenService:Create(g, FADE, { GroupTransparency = 1 }):Play()
    end
end

local function fadeShown()
    -- each group rises to its own resting transparency (block faces 0, round chōchin 0.2)
    for _, g in glyphGroups do
        local st = (g:GetAttribute("ShownT") :: number?) or 0
        TweenService:Create(g, FADE, { GroupTransparency = st }):Play()
    end
end

-- Retarget the two ImageLabels in a group. Layer order is outline-behind, core-in-front, matching
-- Glyphs.renderGroup; children come back in insertion order so index 1 is the outline.
local function setGroupSymbol(g: CanvasGroup, symbol: string)
    local layers = Glyphs.IMAGE[symbol]
    if not layers then
        return
    end
    local kids = g:GetChildren()
    local imgs: { ImageLabel } = {}
    for _, k in kids do
        if k:IsA("ImageLabel") then
            table.insert(imgs, k)
        end
    end
    if #imgs >= 2 then
        imgs[1].Image = layers.outline
        imgs[2].Image = layers.core
    end
end

local function showThrow(throw: string)
    if not Glyphs.IMAGE[throw] then
        return
    end
    fadeBlank() -- fade the old symbol down…
    task.delay(0.4, function() -- swap after the (slower) fade-out completes
        for _, g in glyphGroups do
            setGroupSymbol(g, throw)
        end
        fadeShown() -- …swap, then fade the new one up
    end)
end
```

- [ ] **Step 6: Run the Roblox gates**

Run from `roblox/`:
```bash
stylua --check src tests tools && selene src tools
lune run tests/run
```
Expected: both clean.

- [ ] **Step 7: Verify in Studio**

Connect Rojo, enter Play. Confirm: block lanterns and round chōchin both show the ring / bar /
chevron shapes (not typographic approximations); the cross-fade on reveal still works; the round
chōchin still rest visibly softer than the block faces.

- [ ] **Step 8: Commit**

```bash
git add roblox/src/shared/Glyphs.luau roblox/src/client/LanternController.client.luau roblox/tests/Glyphs.spec.luau
git commit -m "fix(roblox): lanterns render the real glyph assets, not Unicode stand-ins"
```

---

