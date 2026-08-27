### Task 4: `main.client.luau` — pick state and the wire

**Files:**
- Modify: `roblox/src/client/main.client.luau`

**Interfaces:**
- Consumes: `HudModel.tapAction`, `applyTap`, `sendAtLockout`, `switchPromptExpired`,
  `SWITCH_PROMPT_SECONDS`.
- Produces: `EventBus.HudState:Fire(inputs, aux)` where `inputs` is the Task-2 `Inputs` and
  `aux` is `{ session, tape, timerKnown }` — **`aux.pick` is removed**; `view.chosen` carries
  it now.

- [ ] **Step 1: Replace the pick state**

Delete `local myPick: string? = nil` and `local selectedThrow: string? = nil`. Add:

```luau
-- THE ROUND'S PICK STATE. `chosen` is the player's commitment and `sent` is the wire's, and
-- they are separate on purpose: the pick is held here until the lockout (HudModel.sendAtLockout)
-- because ThrowBuffer is upsert-only, so sending on the first tap would make backing out a lie.
local chosen: string? = nil
local switchPrompt: string? = nil
local switchPromptAt: number? = nil
local sent = false
-- Set by a back-out, cleared when ACTIVE reopens. A player who withdrew has answered the
-- question the escalation asks, so it must not ask again this round.
local declinedThisRound = false
```

- [ ] **Step 2: Rewrite `buildInputs`**

```luau
local function buildInputs(): any
    return {
        phase = phase,
        secondsLeft = secondsLeft(),
        pointsAtStake = wallet.pointsAtStake,
        currentStreak = wallet.currentStreak,
        totalPoints = wallet.totalPoints,
        unresolvedWin = wallet.unresolvedWin,
        escalationPrompts = escalationPrompts,
        chosen = chosen,
        switchPrompt = switchPrompt,
        sent = sent,
        declinedThisRound = declinedThisRound,
    }
end
```

- [ ] **Step 3: Replace `commitPick` and the tap handler**

```luau
-- The one place a pick leaves this client, and it happens ONCE per round at the lockout.
-- `sent` is set before the fire, not after: a re-entrant heartbeat tick must not be able to
-- send the same pick twice.
local function sendPick(value: string)
    sent = true
    SubmitPick:FireServer(value)
    publish()
end
```

```luau
-- HudController fires this on every accepted tap; the MODEL decides what the tap means
-- (HudModel.tapAction) and what the state becomes (HudModel.applyTap). The controller
-- re-derives neither.
--
-- NOTHING HERE TALKS TO THE SERVER. Choosing, prompting and clearing are all local; the pick
-- goes over the wire in the heartbeat below, at the lockout.
EventBus.HudPick.Event:Connect(function(value: string)
    local action = HudModel.tapAction(buildInputs(), value)
    if action == "ignore" then
        return
    end
    local next = HudModel.applyTap({ chosen = chosen, switchPrompt = switchPrompt }, action, value)
    chosen = next.chosen
    switchPrompt = next.switchPrompt
    switchPromptAt = if switchPrompt then os.clock() else nil
    if action == "clear" then
        declinedThisRound = true
    end
    publish()
end)
```

- [ ] **Step 4: Rewrite the heartbeat**

```luau
task.spawn(function()
    while true do
        if phase == "ACTIVE" then
            roundCouldThrow = true
        end
        -- An unanswered SWITCH? ages out. Both outcomes of expiry are safe: it restores
        -- exactly the state before the stray tap.
        if HudModel.switchPromptExpired(switchPromptAt, os.clock()) then
            switchPrompt = nil
            switchPromptAt = nil
        end
        -- THE PICK'S ONE TRIP TO THE WIRE. The model decides when; this loop is simply the only
        -- thing watching the countdown, at 10Hz — close enough to the half-second boundary that
        -- the pick still makes the lockout.
        local send = HudModel.sendAtLockout(buildInputs())
        if send then
            sendPick(send)
        end
        publish()
        task.wait(TICK)
    end
end)
```

- [ ] **Step 5: Update `publish`, `roundEnded` and the round boundary**

In `publish`, drop `pick = myPick` from the `aux` table. In the `RoundUpdate` handler:

```luau
    if phase == "ACTIVE" and info.phase ~= "ACTIVE" then
        -- A STANDING CHOICE COUNTS AS PLAYED. The lockout normally sends it half a second
        -- before this fires; a choice made inside that last sliver must not be scored as an
        -- ignored round, because three of those start the escalation nagging someone who is
        -- demonstrably playing.
        roundEnded(roundCouldThrow, chosen ~= nil)
    end
    phase = info.phase
    if info.phase == "ACTIVE" then
        chosen = nil
        switchPrompt = nil
        switchPromptAt = nil
        sent = false
        declinedThisRound = false
        roundCouldThrow = true
        lockoutAt = if info.secondsToLockout then os.clock() + info.secondsToLockout else nil
        pendingReveal = nil
        drumAtRest = false
    else
        lockoutAt = nil
    end
```

In the `RevealTheater` whiff branch, replace the two clears with:

```luau
        -- and stop lighting the glyph: leaving it chosen would keep the tile illuminated
        -- through REVEAL as though it had counted, contradicting the toast.
        chosen = nil
        switchPrompt = nil
        switchPromptAt = nil
```

- [ ] **Step 6: Verify by inspection, then commit**

There is no Lune coverage for `.client.luau` files (they are Roblox-runtime). Verify by
reading: `myPick` and `selectedThrow` appear nowhere; `SubmitPick:FireServer` appears exactly
once, inside `sendPick`; `sendPick` is called only from the heartbeat.

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "myPick\|selectedThrow\|SubmitPick:FireServer" src/client/main.client.luau
git add roblox/src/client/main.client.luau
git commit -m "feat(roblox): hold the pick until the lockout so backing out is honest"
```

---

