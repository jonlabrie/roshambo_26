### Task 4: The payoff draws the eye

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — a new `setCelebrating`, called from `paintCounters`

**Interfaces:**
- Consumes: `paintCounters` and the counters' `startedAt` from Task 3.
- Produces: nothing.

**Context:** The owner: *"as point balances rise… we want the player to feel the satisfaction of a long points transfer, just like a slot machine paying off a big win. Maybe even change the color in the points display to something more festive/brighter while the balance is incrementing, draw a box around it or something."* The plate already has a `GOLD` `UIStroke` at 0.35 transparency (`plateStroke`) — the box exists; it gets brought up while counting rather than added.

- [ ] **Step 1: Add the treatment**

Add, immediately above `paintCounters`:

```lua
-- WHILE THE BALANCE CLIMBS, the plate lifts: its existing GOLD rim comes up from a hairline to a
-- real edge, and the figure itself goes gold. It settles back as the count lands.
--
-- THE PLATE ONLY. The bank button's figure is DRAINING to zero over the same seconds, and a
-- number counting down to nothing should not celebrate — the destination gets the emphasis, the
-- source just empties.
--
-- LATCHED, and that is not optional: this is called every frame while a count runs, and a tween
-- cancelled and restarted at frame rate gets a few percent of its travel and renders static.
-- That is exactly how the bank button's pulse failed earlier in this branch.
local CELEBRATE_SECONDS = 0.15
local celebrating = false

local function setCelebrating(active: boolean)
    if active == celebrating then
        return
    end
    celebrating = active
    local info = TweenInfo.new(CELEBRATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    -- The stroke is on the PLATE, a Frame. Never on plateLabel — an outline on text fills the
    -- counters of every glyph.
    TweenService:Create(plateStroke, info, {
        Transparency = if active then 0 else 0.35,
        Thickness = if active then 2 else 1,
    }):Play()
    TweenService:Create(plateLabel, info, {
        TextColor3 = if active then GOLD else INK_CREAM,
    }):Play()
end
```

`TweenService`, `plateLabel`, `GOLD` and `INK_CREAM` are all declared near the top of the file, and `plateStroke` is already captured as `local plateStroke = stroke(plate, GOLD, 1, 0.35)` — the box the owner asked for exists, at 0.35 transparency and 1px. This brings it up rather than adding a second one. Confirm all five resolve above your insertion point.

- [ ] **Step 2: Drive it from the paint**

At the end of `paintCounters`, add:

```lua
    -- Keyed on the POINTS counter alone. The pot draining and the streak resetting are not
    -- payoffs, and lighting the plate for them would spend the effect on nothing.
    setCelebrating(pointsCounter.startedAt ~= nil)
```

This is why Task 3's driver checks `countersAnimating()` **before** painting rather than after: the frame on which the count reaches its target still runs `paintCounters`, `tickCounter` clears `startedAt` inside it, and this line then releases the decoration in the same invocation. Were the check the other way round, the gold would stick permanently.

- [ ] **Step 3: Verify the release paths by reading**

No gate can see this. Walk each exit and confirm the decoration is released:

1. **A count completes.** `tickCounter` sets `startedAt = nil` at `t >= 1`; `setCelebrating(false)` runs in the same `paintCounters` call. ✔ by the ordering above — confirm that ordering is actually what Task 3 wrote.
2. **A second bank interrupts one already running.** `tickCounter` re-keys, `startedAt` is non-nil throughout, `setCelebrating(true)` returns early on the latch. No tween restart. The count continues from the displayed value.
3. **The plate fades out while a count is running.** The plate's own reveal/fade is independent; confirm the fade does not fight the stroke tween, and that when the count later settles the release still runs (it does — `paintCounters` is driven by the counter, not by the plate's visibility).
4. **A loss.** Points do not move on a loss, so the plate must not celebrate. Confirm `pointsCounter.startedAt` stays nil.

State what you found for each in your report.

- [ ] **Step 4: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): the plate lifts while the balance climbs"
```

---

