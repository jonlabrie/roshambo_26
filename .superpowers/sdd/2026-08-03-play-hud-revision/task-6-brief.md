### Task 6: `HudController` — the cluster reorders and the pot becomes a button

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `HudLayout.BANK_H`, `BANK_GAP`, `AREA_H`; `view.bankVisible`, `view.pot`,
  `view.potPulses`.

- [ ] **Step 1: Swap the tape and the buttons**

The tape row moves to the bottom of `throwArea` and the buttons to the top:

```luau
-- Tape BELOW the buttons (owner's ruling): five square tiles, newest LEFT, ageing ivory ->
-- amber, with a corner dot for the personal WIN/SAFE/LOSS result. It is read, never touched,
-- so it takes the outermost edge and the buttons take the reachable one.
local tapeRow = Instance.new("Frame")
tapeRow.Name = "Tape"
tapeRow.AnchorPoint = Vector2.new(1, 1)
tapeRow.Position = UDim2.fromScale(1, 1)
```

and for each throw button and its halo, change the vertical anchor from bottom to top:

```luau
    halo.AnchorPoint = Vector2.new(0, 0)
    halo.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP) - HALO_BLEED, 0, -HALO_BLEED)
```
```luau
    b.AnchorPoint = Vector2.new(0, 0)
    b.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP), 0, 0)
```

- [ ] **Step 2: Replace the slot with one bank button**

Delete `potGroup`, `potDisc`, `potFigure`, `fateButton`, `setSlot`, and the `slotRow` frame.
Replace with:

```luau
-- ===== The bank button: directly above the throw row =====
-- ONE control, not a readout plus a button. The figure belongs IN the thing that acts on it —
-- a separate red disc saying "27" beside a generic BANK THESE made the player join two
-- elements to read one fact. Throwing again IS riding, so there is no counterpart button and
-- nothing to resolve.
local bankButton = Instance.new("TextButton")
bankButton.Name = "Bank"
bankButton.AnchorPoint = Vector2.new(1, 1)
bankButton.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP))
bankButton.Size = UDim2.fromOffset(BANK_W, BANK_H)
bankButton.BackgroundColor3 = POT_RED
bankButton.BackgroundTransparency = 0.15
bankButton.BorderSizePixel = 0
bankButton.AutoButtonColor = false
bankButton.TextColor3 = INK_CREAM
bankButton.TextSize = 15
bankButton.Font = Enum.Font.GothamBold
bankButton.Text = ""
bankButton.Visible = false
bankButton.Parent = gui
corner(bankButton, 8)
stroke(bankButton, GOLD, 1, 0.3)

bankButton.MouseButton1Click:Connect(function()
    EventBus.HudBank:Fire()
end)

-- The pulse says "this is unacknowledged", nothing more. Cancelled rather than left running,
-- and the transparency put back by hand, because Cancel leaves the property mid-tween.
local potPulse: Tween? = nil
local function setBank(visible: boolean, pot: number, pulses: boolean)
    bankButton.Visible = visible
    if visible then
        bankButton.Text = `BANK {pot} POINTS`
    end
    if potPulse then
        potPulse:Cancel()
        potPulse = nil
        bankButton.BackgroundTransparency = 0.15
    end
    if visible and pulses then
        potPulse = TweenService:Create(
            bankButton,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.6 }
        )
        (potPulse :: Tween):Play()
    end
end
```

Add `local BANK_W = 150` beside the other width constants, and `POT_RED` to the palette if
the deleted `potDisc` was the only user of that colour.

- [ ] **Step 3: Update `render`**

Replace the plate/slot lines at the top of `render` with:

```luau
    setBank(view.bankVisible, view.pot, view.potPulses)
```

(The plate lines move in Task 7; leave them for now, but delete `cellValue.pot.Text = …`
since `view.plate.pot` no longer exists.)

**Also delete the confirm strip's render block in this task**, even though its construction
waits for Task 8:

```luau
    confirmStrip.Visible = view.confirmPending or view.releasable
    if view.releasable then … else … end
```

`view.confirmPending` and `view.releasable` were removed in Task 1, so both operands are now
nil and `Visible = nil` is a runtime error — it would leave the branch unrunnable in Studio
between this task and Task 8. Leave the `confirmStrip` instance itself in place (unused and
hidden); Task 8 deletes it.

- [ ] **Step 4: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "potDisc\|fateButton\|setSlot\|view.slot" src/client/HudController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the pot says what banking it is worth, on the button that does it"
```

---

