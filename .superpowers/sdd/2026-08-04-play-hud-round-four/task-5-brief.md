### Task 5: The splash lands with the drum

**Files:**
- Modify: `roblox/src/shared/DrumStep.luau`
- Modify: `roblox/src/client/DrumController.client.luau` — the glide branch
- Modify: `roblox/src/client/main.client.luau` — the reveal gate
- Test: `roblox/tests/DrumStep.spec.luau`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a new `EventBus.Cue` kind, `"drumSettling"`.

**Context:** The splash is not slow — it fires the instant `drumRest` lands. The wait is the drum's own 3.45s (0.45 swing + 1.0 spin + 2.0 glide), gated so the result is not announced before the drum has shown the world's throw. The glide is a smoothstep decelerating onto the detent, so by 65% through it the drum has covered ~88% of its travel and the face is effectively in the window. The splash fires there: **2.75s instead of 3.45s.**

**The tape tile does NOT move.** It stays on `drumRest`. The tape is the record of the *world's* throw — the actual spoiler — and it has no urgency. The resulting order is better than moving both: your outcome first, then the world's mark goes onto the tape as the drum stops.

- [ ] **Step 1: Write the failing test**

In `roblox/tests/DrumStep.spec.luau`, add:

```lua
describe("DrumStep.SPLASH_LEAD_SECONDS — how early the personal result may land", function()
    test("it is a real lead, but strictly inside the glide", function()
        -- At or beyond the glide's whole length the cue would fire the moment the glide STARTS,
        -- while the drum is still visibly travelling — which is the spoiler the drum-rest gate
        -- exists to prevent. At zero it buys nothing.
        expect(DrumStep.SPLASH_LEAD_SECONDS > 0).toBe(true)
        expect(DrumStep.SPLASH_LEAD_SECONDS < DrumStep.GLIDE_SECONDS).toBe(true)
    end)

    test("it leaves the drum most of the way home before the result shows", function()
        -- The glide is a smoothstep (3s^2 - 2s^3). Whatever the lead is, the drum must have
        -- covered a large majority of its travel by the time the splash fires, or the face is
        -- not yet readable in the window.
        local s = (DrumStep.GLIDE_SECONDS - DrumStep.SPLASH_LEAD_SECONDS) / DrumStep.GLIDE_SECONDS
        local travelled = 3 * s * s - 2 * s * s * s
        expect(travelled > 0.8).toBe(true)
    end)

    test("the drum's own timings are unchanged", function()
        -- The bell/drum choreography is signed off. This round changes when a CLIENT reacts,
        -- never how long the drum takes — and the server reads SETTLE_SECONDS to time round
        -- scheduling.
        expect(DrumStep.SETTLE_SECONDS).toBe(
            DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS
        )
    end)
end)
```

The file already requires `DrumStep` and the harness at its head — append the new `describe` block; do not touch the existing `describe("DrumStep (12 faces)", ...)`.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `lune run tests/run`
Expected: FAIL — `SPLASH_LEAD_SECONDS` is nil, so the comparison errors or fails.

- [ ] **Step 3: Add the constant**

In `roblox/src/shared/DrumStep.luau`, after `SETTLE_SECONDS`:

```lua
-- HOW EARLY THE PERSONAL RESULT MAY LAND, measured back from drumRest (spec §2).
--
-- The whole 3.45s of swing + spin + glide sat between a round closing and the player being told
-- what happened, and the owner's word for it was "a long time". But the wait is not padding —
-- it is what stops the result being announced before the drum has shown the world's throw.
--
-- The glide is a smoothstep, so it is nearly home long before it stops: at 0.7s from rest the
-- drum has covered ~88% of its travel and the face is effectively in the window. The remaining
-- beat is settling, not suspense. So the SPLASH fires here and the TAPE TILE does not — the tape
-- is the record of the WORLD's throw, the real spoiler, and it has no urgency.
DrumStep.SPLASH_LEAD_SECONDS = 0.7
```

Run `lune run tests/run` — expected: PASS.

- [ ] **Step 4: Fire the cue from the drum**

In `roblox/src/client/DrumController.client.luau`, near the existing `SPIN_SEC`/`GLIDE_SEC` locals (which already come from `DrumStep` — confirm this):

```lua
-- The fraction of the glide at which the personal result may show. Clamped: a lead longer than
-- the glide itself would fire at glide start, while the drum is still visibly travelling.
local SETTLING_S = math.clamp((GLIDE_SEC - DrumStep.SPLASH_LEAD_SECONDS) / GLIDE_SEC, 0, 1)
local settlingFired = false
```

In the glide branch, in the `else` arm (the one that is still travelling), **before** the `theta = ...` assignment:

```lua
            -- ONCE per glide. `drumSettling` says the drum is committed to its detent — near
            -- enough home that the face is readable — which is all the splash needs to know.
            if not settlingFired and s >= SETTLING_S then
                settlingFired = true
                EventBus.Cue:Fire({ kind = "drumSettling" })
            end
```

Set `settlingFired = false` at **both** points where a new glide can begin:
- where `mode = "glide"` is assigned (in the spin branch, alongside `glideT0 = os.clock()`)
- in the `gongHit` cue handler, where the drum respins (alongside `mode = "spin"` and `spinUntil = os.clock() + SPIN_SEC`)

A latch never reset fires the cue once per session and every later round's splash falls back to `drumRest` — which looks exactly like this task never landed.

`drumRest` continues to fire exactly as it does now, unchanged.

- [ ] **Step 5: Split the gate in main.client.luau**

Currently `maybeShowReveal` does everything behind one `drumAtRest` flag and consumes `pendingReveal` by setting it to nil. The splash needs to fire earlier without consuming the record.

Add beside `local drumAtRest = false`:

```lua
-- Two gates, not one. The SPLASH — the player's own result — releases on `drumSettling`, ~0.7s
-- before the drum stops. Everything else (the tape badge, the ledger's LAST ROUND band, the
-- first-win onboarding beat) stays on `drumRest`, because those name the WORLD's throw and
-- releasing them early is the spoiler this gate exists to prevent.
local drumSettling = false
local splashDone = false
```

Extract the splash into its own function, declared immediately above `maybeShowReveal` (it reads `wallet` and `pendingReveal`, so confirm both are declared above it):

```lua
local function maybeShowSplash()
    if not drumSettling or splashDone then
        return
    end
    local p = pendingReveal
    -- `p.result` is nil whenever this player had no throw counted this round (a spectator, or a
    -- whiff), so the splash cannot appear for a round the player did not throw in.
    if not p or not p.result then
        return
    end
    splashDone = true
    EventBus.Splash:Fire({
        result = p.result,
        streak = wallet.currentStreak,
        pot = wallet.pointsAtStake,
        forfeited = p.forfeited,
    })
end
```

In `maybeShowReveal`, call `maybeShowSplash()` as the **first** line (drumRest implies settling, so a dropped `drumSettling` cue still releases the splash here), and **delete** the `EventBus.Splash:Fire` block from its body. Update the comment there — it currently says the splash "inherits this same gate", which will no longer be true; say instead that the splash releases on the earlier `drumSettling` gate and that this call is its fallback.

In the `EventBus.Cue` handler:

```lua
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumSettling" then
        drumSettling = true
        maybeShowSplash()
    elseif cue.kind == "drumRest" then
        drumSettling = true -- drumRest implies it, even if that cue was dropped
        drumAtRest = true
        maybeShowReveal()
    end
end)
```

In the `RevealResult` handler's `REVEAL_SAFETY` fallback, set **both** flags before calling, so a dropped cue strands neither part:

```lua
            drumSettling = true
            drumAtRest = true
            maybeShowReveal()
```

Wherever a new round resets `pendingReveal`/`drumAtRest` (the `RoundUpdate` handler), reset the two new flags alongside:

```lua
        drumSettling = false
        splashDone = false
```

`splashDone` is per-round, not per-reveal: without the reset the second round of a session would never splash.

- [ ] **Step 6: The standing check for client files**

Neither client file is loaded by any gate. Verify by reading:

1. `maybeShowSplash` is declared **above** `maybeShowReveal` and above the `EventBus.Cue` handler, and below `wallet` and `pendingReveal`.
2. `settlingFired` is reset on **every** path that starts a glide. Name them.
3. The `drumSettling` cue fires exactly once per round: trace glide → rest → respin.
4. `EventBus.Splash:Fire` appears exactly **once** in the file.
5. The tape badge, `lastRound`, `revealedWorldThrow` and the `EventBus.Onboard:Fire("win", ...)` beat are all still behind `drumAtRest` — none of them moved.
6. Every new local is declared before first use.

- [ ] **Step 7: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/DrumStep.luau roblox/tests/DrumStep.spec.luau \
        roblox/src/client/DrumController.client.luau roblox/src/client/main.client.luau
git commit -m "feat(roblox): your result lands with the drum, the world's throw when it stops"
```

---

## After the last task

Hand back for the owner's Studio gate. Nothing in this round is verifiable by any automated gate. What needs eyes:

- **the count itself** — does a big bank read as a payoff, or as a wait? Is the gold plate treatment festive or noisy? Does the bank button's drain finish together with the balance's climb?
- **the count's smoothness** — the whole point of Task 3. If it still steps visibly, the `RenderStepped` driver is not running or `render` is still fighting it.
- **the splash's new timing** — 2.75s. Does it land *with* the drum, or does it still feel late? And does it ever spoil the drum by arriving while it is visibly still turning?
- **the ring's digits** — seated, or now too high?
- **the UNDO card** — ivory over an unchosen throw button; does it read as a question, or as an ordinary available tile?

**Do not push without telling the owner first.** Every push to `m4b-zendojo-art-pass` auto-deploys the `roshambo_server_dev` App Runner service, which restarts the backend under any live Studio session.
