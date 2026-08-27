### Task 6: UNDO? covers the button, and lasts long enough to read

**Files:**
- Modify: `roblox/src/shared/HudModel.luau` (the `UNDO_PROMPT_SECONDS` value and its comment)
- Modify: `roblox/src/client/HudController.client.luau:579-617` (the pill's size, corner, copy and type)
- Test: `roblox/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: the renamed surface from Tasks 4 and 5.
- Produces: nothing.

**Context:** One second was too short to notice, read and answer. The overlay was also a 24px-tall pill holding 7 characters across 36px of content box on a phone, which clipped to roughly `WITC` — the shorter word plus the full-button box is what fixes that.

- [ ] **Step 1: Write the failing test**

In `roblox/tests/HudModel.spec.luau`, the describe block currently named for a one-second fuse (`:459`) becomes:

```lua
describe("HudModel.UNDO_PROMPT_SECONDS — a two-second fuse", function()
    test("it is two seconds", function()
        -- One second was too quick to notice, read and answer (owner's gate 2026-08-04). Both
        -- outcomes of expiry are still safe — expiring restores exactly the state before the
        -- stray tap, and answering only ever unlocks — so a longer fuse costs nothing but a
        -- question hanging over a live button, and two seconds is short enough for that.
        expect(HudModel.UNDO_PROMPT_SECONDS).toBe(2)
    end)

    test("the fuse burns for the whole two seconds", function()
        local t = 500
        expect(HudModel.undoPromptExpired(t, t + 1.99)).toBe(false)
        expect(HudModel.undoPromptExpired(t, t + 2)).toBe(true)
    end)
end)
```

The generic boundary test at `:389-393` reads `HudModel.UNDO_PROMPT_SECONDS` symbolically and needs no change — leave it, since it is what proves the predicate tracks the constant rather than a literal.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `lune run tests/run`
Expected: FAIL — the constant is still 1.

- [ ] **Step 3: Change the constant**

In `roblox/src/shared/HudModel.luau`, set `HudModel.UNDO_PROMPT_SECONDS = 2` and rewrite the comment above it, which currently argues for one second:

```lua
-- TWO SECONDS. Four was chosen when a prompt was the only thing on screen and in practice it
-- lingered; one replaced it and proved too quick to notice, read and answer (owner's gate
-- 2026-08-04). Both outcomes of expiry are safe — expiring restores exactly the state before
-- the stray tap, and answering only ever unlocks — so the cost of a longer fuse is only a
-- question hanging over a live button, and two seconds is short enough for that.
```

Keep the word-change note added in Task 4.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Grow the overlay to the button**

In `roblox/src/client/HudController.client.luau`, at the `undoPill` construction (`:587`, `:594`):

```lua
undoPill.Size = UDim2.fromOffset(BTN_W, BTN_H)
```

and change its corner radius from 6 to 8, matching a throw button's:

```lua
corner(undoPill, 8)
```

Replace the sizing comment above it with:

```lua
-- EXACTLY THE BUTTON, both dimensions, both tiers (owner's gate 2026-08-04). It anchors at
-- (0.5, 0.5) on the button's centre, so it covers it precisely.
--
-- IT MUST STAY Active = false. It is a Frame, and the tap that answers it is delivered to the
-- TextButton underneath — a full-size overlay that sank would swallow the very tap that
-- resolves it, and the mechanic would break outright with every gate green.
```

Do **not** set `Active` on it. Do not change its `ZIndex` (4), its `WASHI` fill, or its `SEL_BLUE` stroke — the stroke is on the Frame, which is correct; never move it to the label.

`setUndoPrompt`'s position arithmetic is unchanged: `((i - 1) * (BTN_W + BTN_GAP) + BTN_W / 2, BTN_H / 2)` already centres the pill on the button at any size.

- [ ] **Step 6: Set the copy and let it fill**

At the `undoLabel` construction (`:604`, `:614`):

```lua
undoLabel.Text = "UNDO?"
```

and raise the size constraint:

```lua
    constraint.MaxTextSize = 22
```

Replace the comment above the `TextScaled` block with:

```lua
-- TextScaled + a MaxTextSize constraint, same pattern as `bankButton`. The old copy was seven
-- characters in a 36px content box on a phone and clipped to roughly "WITC"; five characters in
-- the same box land near 13px, which reads. The constraint caps growth on the wide tier — at
-- desktop's 68px content box, five characters of GothamBold cap out near 22px, and higher would
-- clip the word on the wide tier instead of the narrow one.
```

Keep `Enum.Font.GothamBold`. The owner's ruling was that size, not the typeface, was the problem — no font-family change anywhere in the HUD.

- [ ] **Step 7: The standing check for client files**

1. `undoPill.Active` is never assigned anywhere in the file. Verify: `grep -n "undoPill" roblox/src/client/HudController.client.luau`
2. `BTN_W` and `BTN_H` are declared above the `undoPill` construction.
3. No `UIStroke` was added to `undoLabel`.
4. The `SWITCH?` string appears nowhere: `grep -rn "SWITCH" roblox/src roblox/tests`

- [ ] **Step 8: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): UNDO? covers the button it questions, and waits to be read"
```

---

## After the last task

The Studio prototype `RingProto` is still parented to `PlayerGui` in the owner's running session. Clear it before the owner's gate so it cannot be mistaken for the shipped ring:

```lua
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local proto = pg:FindFirstChild("RingProto")
if proto then proto:Destroy() end
```

Then hand back for the owner's Studio gate. Nothing in this round is verifiable by any automated gate: what needs eyes is the ring's smoothness at both tiers, whether the digits read at GothamBold 20 on a phone over moving terrain, whether `UNDO?` is legible on a 44px square, and that tapping an unchosen glyph still resolves — the `Active = false` requirement in Task 6 is the one change that could break the throw mechanic outright with every test green.

**Do not push without telling the owner first.** Every push to `m4b-zendojo-art-pass` auto-deploys the `roshambo_server_dev` App Runner service, which restarts the backend under any live Studio session.
