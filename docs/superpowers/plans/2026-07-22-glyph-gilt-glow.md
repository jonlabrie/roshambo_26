# Glyph Gilt↔Glow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the revolving-lantern glyphs read gilded-gold by day and warm-amber glow by night, crossfading with the day/night `nightFactor` signal.

**Architecture:** Each facet's glyph is built as two full-bright `CanvasGroup`s — a Day group (gold, current look) and a Night group (amber core + soft halo) — tagged for a standalone subscriber that sets each group's `GroupTransparency` from `nightFactor` (day → `nightFactor`, night → `1 − nightFactor`). The `SurfaceGui` stays `LightInfluence = 0`, so this is a pure transparency crossfade (faux-glow, no light cast). `DrumController` swaps one render call; its motion is untouched.

**Tech Stack:** Luau, Rojo, Lune (test harness at `roblox/tests/`), the client `EventBus` + `ReplicatedStorage.DayNightConfig` from the day/night foundation, `CollectionService` tags.

## Global Constraints

- **Lune-safe `Glyphs.luau`:** all Roblox globals (`Instance`, `Color3`, `UDim2`, `Vector2`, `game:GetService`, `CanvasGroup`, `CollectionService`) must live **inside functions**, never at module scope — the Lune tests `require` the module and only touch `Glyphs.IMAGE` / `Glyphs.PALETTE` (plain data), never call the render functions.
- **Tag + attribute contract:** the day/night groups are tagged `"GlyphDayNight"` via `CollectionService`, each with attribute `layer` = `"day"` or `"night"`.
- **Crossfade formula:** `day` group `GroupTransparency = nightFactor`; `night` group `GroupTransparency = 1 − nightFactor` (`nightFactor ∈ [0,1]` from `EventBus.DayNight`).
- **No real light:** faux-glow only — never add `PointLight`/`SurfaceLight`; never change scene `Lighting`. `SurfaceGui.LightInfluence` stays `0`.
- **Starting colors (0–255, tuned at the Play gate):** gold `{212,176,102}`, ink `{20,17,16}`, amber `{255,178,92}`, amberHalo `{255,146,60}`.
- **Test harness:** Lune specs at `roblox/tests/<Name>.spec.luau`, `require("./harness")` → `describe, test, expect` (matchers: `toBe`, `toEqual`, `toBeCloseTo`, `toBeTruthy`, `toBeNil`). Run: `lune run tests/run` from `roblox/`.
- **Lint before commit:** `stylua --check src tests && selene src` from `roblox/`.
- **No gameplay change:** consumes `EventBus.DayNight` only; does not touch round logic, drum motion, or the day/night foundation.

---

## File Structure

- **Modify `roblox/src/shared/Glyphs.luau`** — add `Glyphs.PALETTE` (plain `{r,g,b}` arrays) + `Glyphs.renderDayNight(parent, symbol)`. Keep the existing `Glyphs.render` (other callers use it).
- **Modify `roblox/tests/Glyphs.spec.luau`** — add a `describe` block asserting the palette + `renderDayNight` API (the render body is `Instance`-based → Play-only).
- **Create `roblox/src/client/GlyphDayNight.client.luau`** — standalone auto-run subscriber that drives `GroupTransparency` from `nightFactor`.
- **Modify `roblox/src/client/DrumController.client.luau`** — swap the per-facet `Glyphs.render(...)` for `Glyphs.renderDayNight(...)`; drop the now-unused `GOLD`/`INK_OUTLINE` locals.

---

## Task 1: `Glyphs.renderDayNight` + palette

**Files:**
- Modify: `roblox/src/shared/Glyphs.luau`
- Test: `roblox/tests/Glyphs.spec.luau`

**Interfaces:**
- Consumes: `Glyphs.IMAGE[symbol]` (existing `{ core, outline }` asset ids).
- Produces:
  - `Glyphs.PALETTE: { gold: {number}, ink: {number}, amber: {number}, amberHalo: {number} }` — each a 3-element 0–255 array.
  - `Glyphs.renderDayNight(parent: Instance, symbol: string) -> ()` — builds a Day `CanvasGroup` (name `"GlyphDay"`, `layer="day"`, `GroupTransparency=0`) and a Night `CanvasGroup` (name `"GlyphNight"`, `layer="night"`, `GroupTransparency=1`) under `parent`, both tagged `"GlyphDayNight"`.

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/Glyphs.spec.luau` (before the final line), a new block:

```lua
describe("Glyphs day/night palette + renderDayNight", function()
    test("PALETTE exposes gold/ink/amber/amberHalo as 0-255 rgb arrays", function()
        for _, key in { "gold", "ink", "amber", "amberHalo" } do
            local c = Glyphs.PALETTE[key]
            expect(c ~= nil).toBe(true)
            expect(#c).toBe(3)
            for _, ch in c do
                expect(ch >= 0 and ch <= 255).toBe(true)
            end
        end
    end)

    test("day gold and night amber are distinct", function()
        expect(Glyphs.PALETTE.gold[1] ~= Glyphs.PALETTE.amber[1] or Glyphs.PALETTE.gold[3] ~= Glyphs.PALETTE.amber[3]).toBe(true)
    end)

    test("renderDayNight is a function", function()
        expect(type(Glyphs.renderDayNight)).toBe("function")
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -12`
Expected: FAIL — `Glyphs.PALETTE` is nil (indexing it errors) and `Glyphs.renderDayNight` is nil (`type` returns `"nil"`, not `"function"`).

- [ ] **Step 3: Implement the palette + renderDayNight**

In `roblox/src/shared/Glyphs.luau`, add — after the `Glyphs.IMAGE = {...}` block and before `Glyphs.render`:

```lua
-- Day/night palette (plain {r,g,b} 0-255 arrays so the module stays Lune-safe; renderDayNight
-- converts to Color3 internally). Tuned at the Play gate.
Glyphs.PALETTE = {
    gold = { 212, 176, 102 }, -- day core (gilt)
    ink = { 20, 17, 16 }, -- keyline outline
    amber = { 255, 178, 92 }, -- night core (warm glow)
    amberHalo = { 255, 146, 60 }, -- night bloom
}
```

Then add — after the existing `Glyphs.render` function and before `return Glyphs`:

```lua
-- Build the glyph as a DAY CanvasGroup (gilt gold, the current look) + a NIGHT CanvasGroup
-- (warm-amber core over a soft amber halo), stacked in the same SurfaceGui. A day/night subscriber
-- crossfades them via each group's GroupTransparency (GlyphDayNight.client.luau). SurfaceGui stays
-- LightInfluence 0, so both are full-bright — gold reads gilt on cypress by day, amber reads self-lit
-- against the dark by night (faux-glow, no light cast). Roblox globals live here (not module scope)
-- so the module stays Lune-safe.
function Glyphs.renderDayNight(parent: Instance, symbol: string)
    local imgs = Glyphs.IMAGE[symbol]
    if not imgs then
        return
    end
    local CollectionService = game:GetService("CollectionService")
    local function c3(rgb: { number }): Color3
        return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
    end
    -- one image layer, centred + scaled (scale 1 = fills the aspect-locked group)
    local function layer(into: Instance, assetId: string, tint: Color3, scale: number, transparency: number)
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.Size = UDim2.fromScale(scale, scale)
        img.Image = assetId
        img.ImageColor3 = tint
        img.ImageTransparency = transparency
        img.Parent = into
    end
    -- an aspect-locked CanvasGroup (so the ○ ring stays round on a non-square facet)
    local function makeGroup(name: string, layerKind: string, startTransparency: number): CanvasGroup
        local g = Instance.new("CanvasGroup")
        g.Name = name
        g.BackgroundTransparency = 1
        g.AnchorPoint = Vector2.new(0.5, 0.5)
        g.Position = UDim2.fromScale(0.5, 0.5)
        g.Size = UDim2.fromScale(1, 1)
        g.GroupTransparency = startTransparency
        local ar = Instance.new("UIAspectRatioConstraint")
        ar.AspectRatio = 1
        ar.Parent = g
        g:SetAttribute("layer", layerKind)
        CollectionService:AddTag(g, "GlyphDayNight")
        g.Parent = parent
        return g
    end

    -- DAY: gilt gold (current approved look), visible by day.
    local day = makeGroup("GlyphDay", "day", 0)
    layer(day, imgs.outline, c3(Glyphs.PALETTE.ink), 1, 0) -- keyline behind
    layer(day, imgs.core, c3(Glyphs.PALETTE.gold), 1, 0) -- gold core in front

    -- NIGHT: amber glyph over a soft amber halo, hidden by day (faded in by nightFactor).
    local night = makeGroup("GlyphNight", "night", 1)
    layer(night, imgs.outline, c3(Glyphs.PALETTE.amberHalo), 1.3, 0.5) -- widest, softest = halo bloom
    layer(night, imgs.outline, c3(Glyphs.PALETTE.ink), 1, 0) -- ink keyline for definition
    layer(night, imgs.core, c3(Glyphs.PALETTE.amber), 1, 0) -- amber core (glows)
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3`
Expected: all pass (`0 failed`; count up by the 3 new Glyphs cases).

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no stylua diff; selene `0 errors 0 warnings`. (If stylua diffs, run `stylua src tests` and re-check.)

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/Glyphs.luau roblox/tests/Glyphs.spec.luau
git commit -m "feat(roblox): Glyphs.renderDayNight — day-gold/night-amber crossfade groups"
```

---

## Task 2: subscriber + wire-in (Play-gated)

**Files:**
- Create: `roblox/src/client/GlyphDayNight.client.luau`
- Modify: `roblox/src/client/DrumController.client.luau:28-29` (remove unused locals), `:61` (render swap)

**Interfaces:**
- Consumes: `EventBus.DayNight` (`{ t, nightFactor, phase }`), `ReplicatedStorage.DayNightConfig` attribute `CurrentNightFactor`, the `"GlyphDayNight"`-tagged `CanvasGroup`s (attribute `layer`).
- Produces: sets `GroupTransparency` on those groups; no new public API.

- [ ] **Step 1: Write the subscriber**

Create `roblox/src/client/GlyphDayNight.client.luau`:

```lua
--!strict
-- First day/night subscriber: crossfades the lantern glyphs gilt-gold (day) ↔ amber-glow (night)
-- by reading nightFactor. Standalone auto-run LocalScript (like ChochinSway.client.luau) — nothing
-- starts it. The glyph day/night CanvasGroups are tagged "GlyphDayNight" (attr layer="day"/"night")
-- by Glyphs.renderDayNight; DrumController builds them at runtime, so we also apply to groups added
-- after startup. Reads the live nightFactor from EventBus.DayNight, with the DayNightConfig
-- CurrentNightFactor attribute as a start-order-proof prime + backstop.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local config = ReplicatedStorage:WaitForChild("DayNightConfig")

local TAG = "GlyphDayNight"
local current = config:GetAttribute("CurrentNightFactor") or 0

local function applyTo(g: Instance)
    if not g:IsA("CanvasGroup") then
        return
    end
    local layer = g:GetAttribute("layer")
    if layer == "day" then
        g.GroupTransparency = current
    elseif layer == "night" then
        g.GroupTransparency = 1 - current
    end
end

local function applyAll()
    for _, g in CollectionService:GetTagged(TAG) do
        applyTo(g)
    end
end

applyAll() -- prime any glyphs already built
CollectionService:GetInstanceAddedSignal(TAG):Connect(applyTo) -- glyphs built later get current value

EventBus.DayNight.Event:Connect(function(payload)
    current = payload.nightFactor
    applyAll()
end)

-- backstop: the config attribute is set on every publish and replicates, closing the startup race
-- where this script connects to the BindableEvent after the controller's first fire.
config:GetAttributeChangedSignal("CurrentNightFactor"):Connect(function()
    current = config:GetAttribute("CurrentNightFactor") or current
    applyAll()
end)
```

- [ ] **Step 2: Swap the render call in DrumController**

In `roblox/src/client/DrumController.client.luau`:

Delete the two now-unused constants (lines ~28–29):

```lua
local GOLD = Color3.fromRGB(212, 176, 102)
local INK_OUTLINE = Color3.fromRGB(20, 17, 16) -- black keyline (more authentic than the PWA's white on cypress)
```

And change the render call (line ~61) from:

```lua
    Glyphs.render(gui, SYMBOL_FOR_FACE[k], GOLD, INK_OUTLINE)
```

to:

```lua
    Glyphs.renderDayNight(gui, SYMBOL_FOR_FACE[k])
```

- [ ] **Step 3: Lint + tests**

Run: `cd roblox && stylua --check src tests && selene src && lune run tests/run 2>&1 | tail -3`
Expected: stylua clean; selene `0 errors 0 warnings` (confirms no unused-local left behind in DrumController); tests `0 failed`.

- [ ] **Step 4: Play gate — the visual verification**

`SurfaceGui`/`CanvasGroup` render only in Play. With Rojo connected, enter Play and (server command bar) shorten the cycle so the crossfade is watchable: `game.ReplicatedStorage.DayNightConfig:SetAttribute("CycleLength", 45)`. Verify:
1. **Day:** glyphs read gold-on-cypress exactly as before (no regression).
2. **Dusk → night:** as `nightFactor` climbs, the glyphs dissolve to warm amber with a soft halo, reading as self-lit against the darkening scene.
3. **Through the dragons:** the glowing amber glyphs are visible spinning behind the pierced ranma cutouts.
4. **Dawn:** dissolves back to gold.
5. **Late/spin robustness:** the crossfade holds while the drum spins (groups ride the facets), and a glyph is correct immediately at whatever phase you enter Play in (not stuck gold at night).

**One attempt, then STOP and show the user.** Tune `Glyphs.PALETTE` (amber/halo) at this gate if the glow reads off. Restore `CycleLength` (or restart) when done.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/GlyphDayNight.client.luau roblox/src/client/DrumController.client.luau
git commit -m "feat(roblox): glyphs gild↔glow with the day/night cycle (first nightFactor subscriber)"
```

---

## Self-Review

**1. Spec coverage:**
- Two full-bright `CanvasGroup`s (Day gold / Night amber+halo) per facet → Task 1 `renderDayNight`. ✓
- Crossfade `GroupTransparency` by `nightFactor` (day=`nf`, night=`1−nf`) → Task 2 subscriber. ✓
- Standalone subscriber, tag-driven, handles runtime-built glyphs + late join → Task 2 (`GetInstanceAddedSignal` + attribute prime/backstop). ✓
- One-line `DrumController` swap, motion untouched → Task 2 Step 2. ✓
- Palette constants in `Glyphs.luau`, tunable → Task 1 `Glyphs.PALETTE`. ✓
- Faux-glow, no light cast, `LightInfluence` stays 0 → Global Constraints + Task 2 leaves the `SurfaceGui` alone. ✓
- Lune-safe module (globals inside functions) → Task 1 implementation (`game:GetService`/`Color3`/`CanvasGroup` inside `renderDayNight`). ✓
- Testing: minimal Lune (palette/API) + Play gate → Task 1 Step 1, Task 2 Step 4. ✓

**2. Placeholder scan:** No TBD/TODO/"handle edge cases". Every code step is complete; commands show expected output. ✓

**3. Type consistency:** `renderDayNight(parent, symbol)` signature matches between Task 1 (definition) and Task 2 Step 2 (call site). Tag `"GlyphDayNight"` and attribute `layer`/values `"day"`/`"night"` match between Task 1 (`makeGroup`) and Task 2 (`applyTo`). `Glyphs.PALETTE` keys (`gold`/`ink`/`amber`/`amberHalo`) match between the test, the palette, and `renderDayNight`'s uses. `CurrentNightFactor` attribute name matches the day/night foundation's controller. ✓
