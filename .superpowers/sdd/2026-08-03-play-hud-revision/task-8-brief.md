### Task 8: `HudController` — SWITCH?, the selection light, and the confirm strip's removal

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `view.chosen`, `view.switchPrompt`, `view.throwsEnabled`.

- [ ] **Step 1: Confirm the strip is already gone**

**This moved to Task 6.** The strip's construction read `HudLayout.SLOT_H`, `CONFIRM_H` and
`CONFIRM_GAP`, all of which Task 3 removed — so the whole file failed to load, and no task
between 3 and 8 could be run in Studio at all. Task 6 deleted the instance, its children
(`confirmHint`, `dontAsk`, `dontAskBox`, `dontAskLabel`), its constants and its click handler.

Verify rather than repeat the work:

```bash
cd roblox && grep -n "confirmStrip\|confirmHint\|dontAsk\|CONFIRM_" src/client/HudController.client.luau
```
Expected: no matches. If any remain, delete them here.

- [ ] **Step 2: Build the prompt pill**

```luau
-- ===== SWITCH?: the question raised over a glyph the player has just tapped =====
-- It sits ON the button rather than beside it, because the button is no longer offering an
-- option — it is asking a question, and covering the glyph is the clearest way to say so.
-- Answering it UNLOCKS all three; it does not select this one. That is what makes backing out
-- of a round possible at all.
--
-- No UIStroke on the label. Contrast comes from the opaque backing behind it (see the spec's
-- §3): an outline on 13px type fills the counters in and reads as a smear.
local switchPill = Instance.new("Frame")
switchPill.Name = "SwitchPrompt"
switchPill.AnchorPoint = Vector2.new(0.5, 0.5)
switchPill.Size = UDim2.fromOffset(BTN_W - 8, 24)
switchPill.BackgroundColor3 = WASHI
switchPill.BackgroundTransparency = 0
switchPill.BorderSizePixel = 0
switchPill.ZIndex = 4
switchPill.Visible = false
switchPill.Parent = throwArea
corner(switchPill, 6)
stroke(switchPill, SEL_BLUE, 2, 0)

local switchLabel = Instance.new("TextLabel")
switchLabel.Name = "Copy"
switchLabel.Size = UDim2.fromScale(1, 1)
switchLabel.BackgroundTransparency = 1
switchLabel.TextColor3 = INK_CREAM
switchLabel.TextSize = 13
switchLabel.Font = Enum.Font.GothamBold
switchLabel.Text = "SWITCH?"
switchLabel.ZIndex = 5
switchLabel.Parent = switchPill

local THROW_INDEX: { [string]: number } = {}
for i, sym in THROWS do
    THROW_INDEX[sym] = i
end

local function setSwitchPrompt(symbol: string?)
    switchPill.Visible = symbol ~= nil
    if symbol then
        local i = THROW_INDEX[symbol]
        switchPill.Position = UDim2.new(0, (i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, 0, BTN_H / 2)
    end
end
```

- [ ] **Step 3: Give `paintThrows` the prompted state**

The prompted button must lift out of the dimmed treatment — it is the thing being asked
about, so it cannot look like a discarded option. Change the signature and the second branch:

```luau
local function paintThrows(pick: string?, enabled: boolean, prompted: string?)
```
```luau
        elseif sym == prompted then
            -- Lifted OUT of the dimmed state: this button is carrying a question, and a
            -- question on a greyed-out control reads as unanswerable.
            t.button.BackgroundColor3 = IVORY
            t.button.BackgroundTransparency = 0
            tintGlyph(t.glyph, INK, GLYPH_OUTLINE)
            fadeGlyph(t.glyph, 0.2)
            t.rim.Color = SEL_BLUE
            t.rim.Thickness = 2
            t.rim.Transparency = 0.2
            t.halo.Visible = false
        elseif pick then
```

Deepen the unchosen treatment — the owner asked for "almost disappear":

```luau
            t.button.BackgroundTransparency = 0.75
            fadeGlyph(t.glyph, 0.7)
```

Update the press handler's optimistic call to `paintThrows(sym, canThrow, nil)`.

- [ ] **Step 4: Pulse the chosen glyph**

```luau
-- The chosen glyph PULSES. A static light says "this is selected"; a pulse says "this is what
-- is going in", which is the thing the player is being asked to be sure about.
local chosenPulse: Tween? = nil
local pulsingSym: string? = nil
local function setChosenPulse(symbol: string?)
    if pulsingSym == symbol then
        return
    end
    pulsingSym = symbol
    if chosenPulse then
        chosenPulse:Cancel()
        chosenPulse = nil
    end
    for _, sym in THROWS do
        throwTiles[sym].halo.BackgroundTransparency = 0.55
    end
    if symbol then
        chosenPulse = TweenService:Create(
            throwTiles[symbol].halo,
            TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.15 }
        )
        (chosenPulse :: Tween):Play()
    end
end
```

- [ ] **Step 5: Update `render`**

```luau
    -- The authoritative choice wins; until it has come back through main.client a press keeps
    -- its own tile lit (`pressedSym`), so a held finger does not flicker the light off on the
    -- next 10Hz repaint.
    if view.chosen then
        pressedSym = nil
    end
    local lit = view.chosen or pressedSym
    paintThrows(lit, view.throwsEnabled, view.switchPrompt)
    setChosenPulse(if view.throwsEnabled then lit else nil)
    setSwitchPrompt(view.switchPrompt)
```

- [ ] **Step 6: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "confirmStrip\|dontAsk\|aux.pick\|view.selected" src/client/HudController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): a tapped glyph asks SWITCH? instead of silently taking the round"
```

---

