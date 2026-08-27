### Task 5: The kanban

The sign. **Not** through the glyph pipeline — see below.

**Files:**
- Modify: `roblox/tools/builders/Machiya.luau` (the `Kanban` part gains a SurfaceGui child)
- Modify: `roblox/assets/Hanabiya.model.json` (regenerated)

**Interfaces:**
- Consumes: `Machiya`'s `Kanban` part from Task 4.
- Produces: nothing downstream.

**WHY NOT THE GLYPH PIPELINE, despite what the spec says.** `tools/glyphs/glyphgen.cjs` is a
*dependency-free stroked-path rasterizer*: it draws R, P and S as three geometric strokes over a
signed distance field, and it has no font support of any kind. 花火屋 is three kanji of seven to
nine strokes each. Hand-authoring them as stroke coordinates would be a day of miserable work, and
it would then need an asset upload with a moderation wait — the same pipeline that once had a green
maple leaf removed as a false positive.

A Roblox `SurfaceGui` renders CJK from the built-in fonts for free. The documented catch is that
**`TextSize` caps at 100px and `TextScaled` is inert**, so large lettering needs a *small canvas* —
which is exactly what `SurfaceGui.PixelsPerStud` controls. Set it low and 90px text fills a
2.6-stud board.

If the built-in font turns out not to cover these three characters, the fallback is an uploaded
PNG — but check before spending anything on it.

- [ ] **Step 1: Replace the Kanban part with a signed one**

In `roblox/tools/builders/Machiya.luau`, replace the `add("Kanban", ...)` call with:

```lua
    -- The sign board. A SurfaceGui, not a Decal: Roblox renders CJK from the built-in fonts, and
    -- the glyph pipeline next door is a stroked-path rasterizer with no font support — it draws
    -- R/P/S as line segments and could not produce a kanji without hand-authored stroke geometry.
    --
    -- PixelsPerStud is LOW on purpose. TextSize caps at 100 and TextScaled is inert, so the only
    -- way to get large lettering is a small canvas — 20 px/stud over a 2.6-stud board means 90px
    -- text fills it.
    table.insert(
        children,
        Spec.part("Kanban", {
            Size = { W * 0.55, 2.6, 0.25 },
            CFrame = Spec.cframe({ CX, FLOOR + STOREY_H - 1.6, Z0 - 0.2 }),
            Color = ink,
            Material = "WoodPlanks",
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
            children = {
                {
                    name = "Face",
                    className = "SurfaceGui",
                    properties = {
                        -- Front is -Z, which is north: onto the promenade.
                        Face = "Front",
                        PixelsPerStud = 20,
                        ZIndexBehavior = "Sibling",
                        AlwaysOnTop = false,
                    },
                    children = {
                        {
                            name = "Text",
                            className = "TextLabel",
                            properties = {
                                Size = { 1, 0, 1, 0 },
                                BackgroundTransparency = 1,
                                Text = "花火屋",
                                TextColor3 = palette.ivory,
                                TextSize = 90,
                                Font = "GothamBold",
                            },
                        },
                    },
                },
            },
        })
    )
```

`Size = { 1, 0, 1, 0 }` is a UDim2 in Rojo's scale/offset order — full width, full height of the
canvas.

- [ ] **Step 2: Add the test**

Add to `roblox/tests/Machiya.spec.luau`, inside the "the parts other tasks bind to" describe:

```lua
    test("the Kanban carries the shop's name", function()
        local k = find(model, "Kanban")
        local face = find(k, "Face")
        expect(face ~= nil).toBe(true)
        local text = find(face, "Text")
        expect(text ~= nil).toBe(true)
        expect(text.properties.Text).toBe("花火屋")
        -- TextSize caps at 100 and TextScaled is inert: a LOW PixelsPerStud is the only lever
        -- that makes the lettering read from the bridge.
        expect(face.properties.PixelsPerStud <= 25).toBe(true)
    end)
```

- [ ] **Step 3: Regenerate, test, lint**

Run from `roblox/`:

```bash
lune run tools/genmodels && lune run tests/run && stylua --check src tests tools && selene src tools
```

Expected: PASS, clean, zero warnings.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/builders/Machiya.luau roblox/tests/Machiya.spec.luau roblox/assets/Hanabiya.model.json
git commit -m "feat(roblox): the 花火屋 kanban, on a small canvas so it reads big"
```

---

