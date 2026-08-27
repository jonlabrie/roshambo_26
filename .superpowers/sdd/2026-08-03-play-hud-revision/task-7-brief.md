### Task 7: `HudController` — the plate moves to the right margin

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `HudLayout.PLATE_W`, `PLATE_ROW_H`, `PLATE_JUMP_GAP`.

- [ ] **Step 1: Rebuild the plate**

Replace the whole `===== Plate: top-centre =====` section (the `plate` TextButton, its
three-cell loop, `cellValue`) with:

```luau
-- ===== Plate: the right margin, above the jump button =====
-- It left top-centre because that band is the middle of a phone's view. This is the strip
-- Roblox claims for jump and camera drag, and a display with NO interactive elements is the
-- one thing that can safely live in it: everything here is a Frame or a TextLabel at the
-- default Active = false, so every drag passes straight through to the camera.
--
-- The POT IS NOT HERE. It has its own button (see setBank). The streak is shown only when it
-- is non-zero — a "×0" is noise on a display whose whole job is to be ignorable.
local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.AnchorPoint = Vector2.new(1, 1)
plate.Size = UDim2.fromOffset(PLATE_W, PLATE_ROW_H)
plate.BackgroundColor3 = WASHI
plate.BackgroundTransparency = 0.3
plate.BorderSizePixel = 0
plate.Parent = gui
corner(plate, 6)
stroke(plate, GOLD, 1, 0.35)

local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "Streak"
streakLabel.Size = UDim2.new(1, 0, 0, PLATE_ROW_H)
streakLabel.Position = UDim2.fromOffset(0, 0)
streakLabel.BackgroundTransparency = 1
streakLabel.TextColor3 = GOLD
streakLabel.TextSize = 14
streakLabel.Font = Enum.Font.GothamBold
streakLabel.Text = ""
streakLabel.Visible = false
streakLabel.Parent = plate

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.AnchorPoint = Vector2.new(0, 1)
pointsLabel.Position = UDim2.fromScale(0, 1)
pointsLabel.Size = UDim2.new(1, 0, 0, PLATE_ROW_H)
pointsLabel.BackgroundTransparency = 1
pointsLabel.TextColor3 = INK_CREAM
pointsLabel.TextSize = 15
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.Text = "0"
pointsLabel.Parent = plate
```

- [ ] **Step 2: Measure the jump button**

```luau
-- WHERE THE PLATE SITS IS MEASURED, NOT PREDICTED.
--
-- Roblox's default TouchJump sizes the jump button 70px on screens <=500px tall and 120px
-- above that, and positions it UDim2.new(1, -(size*1.5-10), 1, -size-20). Those are current
-- defaults, not a contract: they differ by screen size, they have changed before, and nothing
-- stops them changing again. So rather than encoding that arithmetic, the plate reads the real
-- button and sits PLATE_JUMP_GAP above its measured top edge.
--
-- The fallback is the bottom-right corner, which is where a desktop client — no TouchGui, no
-- jump button at all — should put it anyway.
local function jumpButton(): GuiObject?
    local touchGui = playerGui:FindFirstChild("TouchGui")
    local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
    return frame and frame:FindFirstChild("JumpButton") :: GuiObject?
end

-- This function MEASURES; HudLayout.plateBottomOffset decides. The arithmetic (the fallback,
-- and the clamp against a stale AbsolutePosition) lives there because it is pure and therefore
-- testable, and this file is not.
local function placePlate()
    local jump = jumpButton()
    local jumpTop: number? = if jump and jump.AbsoluteSize.Y > 0 then jump.AbsolutePosition.Y else nil
    local guiBottom = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
    plate.Position = UDim2.new(1, -EDGE, 1, -HudLayout.plateBottomOffset(guiBottom, jumpTop))
end
```

- [ ] **Step 3: Keep it placed**

```luau
-- The jump button is not there at require time on every client, it resizes when the viewport
-- crosses the small-screen threshold, and it disappears entirely if the player docks a
-- keyboard. Watch all three rather than measuring once.
local jumpWatch: { RBXScriptConnection } = {}
local function rewatchJump()
    for _, c in jumpWatch do
        c:Disconnect()
    end
    table.clear(jumpWatch)
    local jump = jumpButton()
    if jump then
        table.insert(jumpWatch, jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(placePlate))
        table.insert(jumpWatch, jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlate))
    end
    placePlate()
end

rewatchJump()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rewatchJump)
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "TouchGui" then
        -- TouchControlFrame is built a frame or two after TouchGui itself.
        task.defer(rewatchJump)
    end
end)
playerGui.ChildRemoved:Connect(function(child)
    if child.Name == "TouchGui" then
        task.defer(rewatchJump)
    end
end)
```

Add `local playerGui = player:WaitForChild("PlayerGui")` near the top if the file does not
already resolve it. The file destructures `HudLayout`'s constants into locals (`EDGE`,
`AREA_H`, …); `plateBottomOffset` is a call, so `HudLayout` itself must also be in scope —
check the require line keeps the module bound, not just its fields.

- [ ] **Step 4: Render the plate**

In `render`, replace the three `cellValue` assignments with:

```luau
    -- A "×0" is noise on a display whose whole job is to be ignorable, so the streak row only
    -- exists when there is a streak — and the plate shrinks to one row when it goes.
    local hasStreak = view.plate.streak > 0
    streakLabel.Visible = hasStreak
    streakLabel.Text = if hasStreak then `×{view.plate.streak}` else ""
    pointsLabel.Text = tostring(view.plate.points)
    plate.Size = UDim2.fromOffset(PLATE_W, if hasStreak then PLATE_ROW_H * 2 else PLATE_ROW_H)
```

- [ ] **Step 5: Fix the day/night contrast pass**

`applyContrast` reads `plate.BackgroundTransparency`; the plate is now a `Frame` rather than a
`TextButton` but the property is the same, so that block needs no change. Confirm by reading
it, and confirm `PLATE_DAY_TRANSPARENCY` still refers to the plate that exists.

- [ ] **Step 6: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "cellValue\|PLATE_BOTTOM" src/client/HudController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the plate measures the jump button instead of guessing at it"
```

---

