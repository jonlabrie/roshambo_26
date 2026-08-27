### Task 1: The ring's digits sit up, and UNDO becomes a card

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — the `ringCount` construction, and the `undoPill`/`undoLabel` construction

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

**Context:** Two small, independent repaints, both from the owner's Studio gate. No logic changes anywhere.

- [ ] **Step 1: Seat the digits**

`ringCount` fills `ringDisc` and Roblox centres the **line box**, which reserves descender space. Digits have no descenders, so a vertically centred box always seats them low by roughly half a descender. Every countdown this HUD shows is digits, so the correction is unconditional.

Find `ringCount`'s construction (it currently sets `Size = UDim2.fromScale(1, 1)` and no `AnchorPoint`/`Position`). Add, after `TextSize` is assigned so the nudge can derive from it:

```lua
-- OPTICAL CENTRING, not a fudge. Roblox centres the LINE BOX, which reserves room for
-- descenders; digits have none, so a vertically centred box seats them low by roughly half a
-- descender. Every value this label ever shows is digits, so the correction is unconditional.
-- Derived from TextSize rather than a literal pair, so a future size change carries its own
-- correction: 2px at 34 (desktop), 1px at 20 (touch).
local COUNT_NUDGE = math.max(1, math.round(ringCount.TextSize * 0.06))
ringCount.AnchorPoint = Vector2.new(0.5, 0.5)
ringCount.Position = UDim2.new(0.5, 0, 0.5, -COUNT_NUDGE)
```

**Do not touch the world-throw glyph.** `glyphBox(ringDisc, 0.82)` holds geometric artwork that is already centred correctly; nudging it would introduce the defect this fixes. Verify the glyph box construction is unchanged when you are done.

- [ ] **Step 2: Repaint the UNDO overlay**

`WASHI` (26, 24, 28) is the HUD's dark, but opaque at full-button size over a cream throw button it reads as a hole punched in the HUD rather than a card laid on it. Change exactly two colours:

```lua
undoPill.BackgroundColor3 = IVORY
```

```lua
undoLabel.TextColor3 = INK
```

Replace the comment above `undoPill.BackgroundColor3` (or add one) with:

```lua
-- IVORY, not WASHI (owner's gate 2026-08-04). At 24px the near-black pill read as an accent; at
-- full button size and fully opaque it read as a hole punched in the HUD. Cream-on-ink under a
-- cool rim is this HUD's own washi idiom, and the SEL_BLUE stroke is what keeps a light tile
-- from reading as an ordinary available throw.
```

**Everything else about the pill is unchanged**: `Size`, corner radius 8, `ZIndex` 4/5, the `SEL_BLUE` 2px stroke, `TextScaled`, `MaxTextSize = 22`, `GothamBold`, and — critically — `Active` is still never assigned on it.

Confirm `IVORY` and `INK` are declared above this point in the file (they are in the palette block near the top).

- [ ] **Step 3: The standing check for client files**

1. `ringCount.TextSize` is assigned **above** the `COUNT_NUDGE` line that reads it. A forward read gives nil and `math.round(nil * 0.06)` errors at load.
2. `IVORY`, `INK`, `Vector2`, `UDim2` all resolve.
3. `grep -n "undoPill" roblox/src/client/HudController.client.luau` — `Active` still never assigned.
4. The glyph box construction is untouched.

- [ ] **Step 4: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "fix(roblox): seat the ring's digits, and lay UNDO on the HUD rather than through it"
```

---

