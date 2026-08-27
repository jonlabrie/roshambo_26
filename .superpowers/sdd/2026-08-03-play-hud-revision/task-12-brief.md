### Task 12: The teahouse becomes a takeover

**Files:**
- Modify: `roblox/src/client/TeahouseController.client.luau`

**Interfaces:**
- Consumes: `Takeover.acquire`/`release`.

- [ ] **Step 1: Make the panel viewport-relative**

The defect: `PANEL_W, PANEL_H = 340, 520` with the ✕ at
`viewportHeight − (PANEL_BOTTOM + PANEL_H) + CLOSE_INSET` = `viewportHeight − 572`. On a
landscape phone (~400px) that is ~170px above the top of the screen, unconditionally — there
is no clamp anywhere in that path. Replace the constants and the panel's geometry:

```luau
-- A TAKEOVER, on the ledger's pattern — which is the pattern that does not have the bug this
-- panel had. It was 520px tall at a fixed offset from the bottom, so on any viewport shorter
-- than 580px the ✕ sat ABOVE THE TOP OF THE SCREEN and the panel could not be dismissed at
-- all. Sizing against the viewport rather than in absolute pixels is what makes that
-- impossible rather than merely unlikely.
local PANEL_MARGIN = 12
local HEADER_H = 44
local CLOSE_W = 34
```
```luau
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -2 * PANEL_MARGIN, 1, -2 * PANEL_MARGIN)
```

Set the GUI's layer above the HUD:

```luau
gui.DisplayOrder = 20 -- a takeover, same layer as the ledger; only one is ever open
```

- [ ] **Step 2: Move the ✕ inside the panel**

```luau
-- INSIDE the panel's own header, positioned against the panel rather than against a fixed
-- offset from the viewport edge. That offset is what put it off-screen.
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -PANEL_MARGIN, 0, (HEADER_H - CLOSE_W) / 2)
closeButton.Size = UDim2.fromOffset(CLOSE_W, CLOSE_W)
closeButton.ZIndex = 3
closeButton.Parent = panel
```

Delete `PANEL_W`, `PANEL_H`, `PANEL_BOTTOM`, `CLOSE_INSET`, `CLOSE_SIZE` and every remaining
reference. Any child positioned relative to the old fixed panel size must be re-anchored in
scale or offset from the header — read the whole file and fix each one; a child laid out
against a 340×520 assumption will be wrong at every other size.

- [ ] **Step 3: Suspend movement**

```luau
local Takeover = require(script.Parent:WaitForChild("Takeover"))
```
```luau
local function setOpen(shouldOpen: boolean)
    if shouldOpen == isOpen then
        return -- idempotent: a double open must not double-acquire
    end
    isOpen = shouldOpen
    panel.Visible = shouldOpen
    closeButton.Visible = shouldOpen
    if shouldOpen then
        Takeover.acquire()
    else
        Takeover.release()
    end
end
```

Add `local isOpen = false` if the file does not already track it, and audit every existing
`setOpen(false)` call site — with the guard above, calling it while already closed is now a
no-op rather than a spurious release.

- [ ] **Step 4: Verify and commit**

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "PANEL_H\|PANEL_BOTTOM\|CLOSE_INSET\|CLOSE_SIZE" src/client/TeahouseController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/client/TeahouseController.client.luau
git commit -m "fix(roblox): the teahouse ✕ was 170px above the top of a phone screen"
```

---

