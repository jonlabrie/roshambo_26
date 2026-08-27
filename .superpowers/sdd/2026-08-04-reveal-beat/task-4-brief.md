### Task 4: The ring's glyph becomes a fadeable group

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — the `ringGlyphs` construction and the glyph swap in `render`

**Interfaces:**
- Consumes: `RevealBeat.FADE_SECONDS` from Task 3; `aux.worldThrow` and a new `aux.worldThrowFading` from Task 5.
- Produces: a ring glyph that fades rather than blinking out.

**Context:** Two things are wrong with the current glyph. It disappears with a `Visible` toggle, and it was invisible entirely until a fix earlier today — its `ImageLabel`s sat at the default ZIndex 1 behind an opaque ZIndex-4 disc, because this ScreenGui runs in **Global** `ZIndexBehavior` where a child does not draw above its parent.

`Glyphs.renderGroup` already exists for precisely this fade problem — its own comment says the lanterns need it "because tweening two ImageLabels independently drifts them out of step at the edges of the fade". It returns a `CanvasGroup`, which composites its descendants as one element, so a single `GroupTransparency` drives the fade **and** the ZIndex trap disappears: only the group's own ZIndex matters.

- [ ] **Step 1: Build the glyphs as groups**

Replace the ring's glyph block. The current version lifts each layer's ZIndex by hand (today's fix); the `CanvasGroup` makes that unnecessary — one ZIndex on the group covers it.

```lua
local ringGlyphs: { [string]: CanvasGroup } = {}
do
    local box = glyphBox(ringDisc, 0.82)
    box.ZIndex = 5 -- with the digits, above the disc
    for _, sym in THROWS do
        -- A CanvasGroup, not `Glyphs.render`'s bare frame, for two reasons that happen to have the
        -- same fix. It gives ONE `GroupTransparency` to fade — `Glyphs.renderGroup` exists because
        -- tweening the outline and core independently drifts them out of step at the edges.
        --
        -- And it closes the ZIndex trap that hid this glyph completely (2026-08-04): this ScreenGui
        -- runs in GLOBAL ZIndexBehavior, where a child does NOT draw above its parent, so the
        -- default-ZIndex-1 image layers rendered behind the opaque ZIndex-4 disc. A CanvasGroup
        -- composites its descendants as a single element, so only ITS ZIndex matters.
        --
        -- THE OUTLINE COLOUR IS PASSED EXPLICITLY, and it must be. The two builders disagree on
        -- their default: `render` falls back to WHITE, `renderGroup` falls back to the CORE colour.
        -- The ring has always had a white keyline (measured live: the outline layer renders at
        -- 1,1,1), so swapping builders without this argument would silently flatten the glyph to a
        -- single cream shape — a visual regression no gate could see.
        local g = Glyphs.renderGroup(box, sym, INK_CREAM, Color3.new(1, 1, 1))
        g.ZIndex = 5
        g.GroupTransparency = 1
        g.Visible = false
        ringGlyphs[sym] = g
    end
end
```

`Glyphs.renderGroup(parent, symbol, coreColor, outlineColor?)` returns the `CanvasGroup` already parented to `parent` — same parameter order as `render`. `LanternController` is the existing caller if you want a reference use.

- [ ] **Step 2: Drive the fade**

Replace the glyph swap in `render`:

```lua
    for _, sym in THROWS do
        ringGlyphs[sym].Visible = sym == worldThrow
    end
```

with a latched fade. Add above `render`:

```lua
-- The glyph's own fade. LATCHED on the (symbol, fading) pair, because `render` runs at 10Hz and a
-- tween cancelled and restarted on every repaint gets a few percent of its travel and renders
-- static — the failure `setBank`'s pulse already had once in this file.
local shownGlyph: string? = nil
local glyphFading = false
local glyphTween: Tween? = nil

local function setRingGlyph(symbol: string?, fading: boolean)
    if symbol == shownGlyph and fading == glyphFading then
        return
    end
    shownGlyph, glyphFading = symbol, fading
    if glyphTween then
        glyphTween:Cancel()
        glyphTween = nil
    end
    for _, sym in THROWS do
        ringGlyphs[sym].Visible = sym == symbol
    end
    if symbol == nil then
        return
    end
    local g = ringGlyphs[symbol]
    if fading then
        glyphTween = TweenService:Create(
            g,
            TweenInfo.new(RevealBeat.FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { GroupTransparency = 1 }
        )
        glyphTween:Play()
    else
        g.GroupTransparency = 0 -- it arrives instantly; the drum was the build-up
    end
end
```

and call it in `render` where the swap used to be:

```lua
    setRingGlyph(worldThrow, aux.worldThrowFading == true)
```

Add `RevealBeat` to the file's requires, beside the other `src/shared` modules.

- [ ] **Step 3: The standing check for client files**

No gate loads this file, and **`Visible = true` is not pixels** — that mistake is exactly what let the invisible glyph be reported as working. So:

1. Every `RevealBeat.X` and `aux.X` read resolves to something those modules actually export — `worldThrowFading` arrives in Task 5, so note it as expected-missing until then.
2. `RevealBeat`, `TweenService`, `THROWS`, `ringGlyphs` and `glyphBox` are all declared above their first use. Give line numbers.
3. `ringGlyphs` is typed `CanvasGroup`, not `Frame`, everywhere it is referenced.
4. The group's `ZIndex` is set — under Global it is the only thing keeping the glyph in front of the disc.
5. Nothing else in the ring moved: the pie layers, the disc's opacity, `ringCount`'s ZIndex 5.

- [ ] **Step 4: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the ring's glyph fades, and stops hiding behind its own disc"
```

---

