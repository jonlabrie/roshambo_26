### Task 3: The counters leave the heartbeat

**Files:**
- Modify: `roblox/src/client/HudController.client.luau` — the `Counter` type, `newCounter`, `tickCounter`, a new `paintCounters`, and `render`'s plate/bank block

**Interfaces:**
- Consumes: `RollingNumber.durationFor` and `RollingNumber.MIN_DURATION` from Task 2.
- Produces, for Task 4: a `paintCounters()` function that is the single place the plate line and the bank figure are painted, and which knows whether the points counter is mid-count.

**Context:** **This task is what decides whether Task 2 was worth doing.** `render` is driven by `main.client.luau`'s 10Hz heartbeat. Today's 0.5s count is 5 frames — coarse, but over too quickly to read as anything. A 2.2s count at 10Hz is ~22 visible steps: a number lurching, not counting. Shipping Task 2 without this makes the exact thing the owner reported *worse*.

- [ ] **Step 1: Give each counter its own duration**

`RollingNumber.DURATION` no longer exists. Each leg of a count now has a duration computed when its target changes.

Add `duration: number` to the `Counter` type, with a comment:

```lua
    -- The duration of the CURRENT leg, fixed when the target changed. Recomputed per leg rather
    -- than read per frame so a count that is interrupted mid-flight finishes on the curve it
    -- started on instead of jumping to a new one.
    duration: number,
```

In `newCounter`, initialise it to `RollingNumber.MIN_DURATION`.

In `tickCounter`, inside the `if target ~= c.target then` block, after `c.startedAt = os.clock()`:

```lua
        c.duration = RollingNumber.durationFor(target - c.from)
```

and change the elapsed-fraction line from `RollingNumber.DURATION` to `c.duration`.

- [ ] **Step 2: Extract the paint**

`render` currently ticks all three counters and paints inline. That work moves into a function that a per-frame driver can also call.

Add, **after `setBank` is declared** (it is called from here) and before `render`:

```lua
-- The targets `render` last handed the counters. The per-frame driver below re-ticks toward
-- these without needing a `view` — `render` keeps sole ownership of WHERE the numbers are going;
-- the driver only advances how far along they are.
local counterPoints, counterStreak, counterPot = 0, 0, 0
local counterPulses = false

local function countersAnimating(): boolean
    return pointsCounter.startedAt ~= nil or streakCounter.startedAt ~= nil or potCounter.startedAt ~= nil
end

-- The ONE place the plate's line and the bank button's figure are painted. Safe to call at any
-- rate: `tickCounter` is keyed on the target CHANGING, so re-invoking it with the target it
-- already has is a no-op re-key that only advances the clock.
local function paintCounters()
    local displayedPoints = tickCounter(pointsCounter, counterPoints)
    local displayedStreak = tickCounter(streakCounter, counterStreak)
    plateLabel.Text = if displayedStreak > 0
        then `×{displayedStreak}  {displayedPoints}`
        else tostring(displayedPoints)

    -- The bank button's VISIBILITY follows the DISPLAYED figure, not the model's: the model's
    -- pot goes to zero the instant a bank lands, and a button that hid on THAT transition would
    -- take the count-down off screen before anyone saw it. `counterPot > 0` stays in the
    -- condition so the button appears on the very first tick a pot exists, even though the
    -- display still reads 0 for that one frame.
    local displayedPot = tickCounter(potCounter, counterPot)
    setBank(counterPot > 0 or displayedPot > 0, displayedPot, counterPulses)
end

-- 10Hz IS NOT ENOUGH FRAMES TO COUNT WITH (spec §3c). `render` runs off main.client's 10Hz
-- heartbeat: a 0.5s count was 5 frames, brief enough that nobody read the steps, but a 2.2s
-- payoff at that rate is ~22 visible jumps — a number lurching, not counting. So while anything
-- is mid-count it repaints per frame instead.
--
-- The connection is permanent and does nothing once everything has settled, which is nearly all
-- the time. Note the ordering: the check runs BEFORE the paint, so the frame on which a count
-- reaches its target still paints — which is what lets that final paint land the exact value and
-- release any decoration hung on "still counting".
RunService.RenderStepped:Connect(function()
    if countersAnimating() then
        paintCounters()
    end
end)
```

`HudController` does **not** currently require `RunService` (it has `Players`, `ReplicatedStorage`, `TweenService`, `UserInputService`). Add it with those, keeping their alphabetical order:

```lua
local RunService = game:GetService("RunService")
```

- [ ] **Step 3: Rewire render**

Replace `render`'s inline counter block — the `tickCounter` calls, the `plateLabel.Text` assignment and the `setBank` call — with:

```lua
    counterPoints = view.plate.points
    counterStreak = view.plate.streak
    counterPot = view.pot
    counterPulses = view.potPulses
    paintCounters()
```

Leave `bankArmed = view.pot > 0` exactly where it is, and leave its comment: arming follows the MODEL's pot, not the displayed one, so a tap during the drain cannot send a `BankRequest` for a pot that no longer exists.

Move any comment that explained the inline block up to `paintCounters` rather than deleting it.

- [ ] **Step 4: The standing check for client files**

1. `paintCounters` is declared **after** `setBank`, `plateLabel`, `tickCounter`, `pointsCounter`, `streakCounter` and `potCounter`, and **before** `render` calls it. Give actual line numbers.
2. `counterPoints`/`counterStreak`/`counterPot`/`counterPulses` are declared above `paintCounters`.
3. `RunService` is required.
4. No remaining reference to `RollingNumber.DURATION`: `grep -rn "RollingNumber\." roblox/src roblox/tests` — only `valueAt`, `durationFor`, `MIN_DURATION`, `MAX_DURATION`, `SCALE_CAP` may appear.
5. `render` no longer paints `plateLabel.Text` or calls `setBank` directly.

- [ ] **Step 5: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/HudController.client.luau
git commit -m "fix(roblox): a count that lasts two seconds cannot be painted ten times a second"
```

---

