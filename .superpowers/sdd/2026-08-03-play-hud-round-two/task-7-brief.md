### Task 7: The result splash

**Files:** Create `roblox/src/client/SplashController.client.luau`; modify
`roblox/src/client/main.client.luau`, `roblox/src/client/EventBus.luau`.

- [ ] **Step 1: The controller**

Its own `ScreenGui`, `DisplayOrder = 30` — above both takeovers (20) and the minimal HUD (0),
because a result that lands while the ledger is open must still be seen. `ResetOnSpawn = false`.

Two labels on one opaque backing, centred: the headline and the consequence line. **No `UIStroke`
on either label.** Everything `Active = false`, no button — see the spec's Decision 1.

```luau
-- NOTHING HERE IS INTERACTIVE, deliberately. A large sinking element in the middle of the screen
-- is the failure this branch has already made twice — a card on the movement thumbstick, and a
-- panel leaking taps to live buttons beneath it. An accidental tap that dropped the player into
-- a movement-suspending takeover would be worse than the friction it saved. The hamburger and
-- the revealed plate are the doors.
```

Copy, driven by result:

| Result | Headline | Consequence |
| --- | --- | --- |
| `WIN` | `YOU WIN!` | `×{streak} — pot is now {pot}` |
| `SAFE` | `SAFE` | `your pot survives, streak resets` |
| `LOSS` | `YOU LOSE` | `{forfeited} points forfeited` |

Colour the headline per result (gold / blue / red) using the palette constants already in
`HudController` — duplicate them locally with a comment, exactly as `OnboardingController` does,
rather than inventing a palette module for a fourth file.

Hold ~2s then fade, on the same generation-guard pattern `HudController`'s plate reveal uses:
increment a generation before cancelling, and have the fade's `Completed` refuse a stale one.

- [ ] **Step 2: Wire it**

Add `Splash` to `EventBus.luau`. In `main.client.luau`'s `maybeShowReveal` — which already holds
the `drumRest` gate and the `REVEAL_SAFETY` fallback — fire it alongside the existing toast:

```luau
        EventBus.Splash:Fire({
            result = p.result,
            streak = wallet.currentStreak,
            pot = wallet.pointsAtStake,
            forfeited = p.forfeited,
        })
```

`forfeited` is the pot as it stood **before** the loss cleared it. Read it the way the bank toast
reads `bankedNow` — capture before the wallet is overwritten. If that value is not available at
this point in the file, say so in your report rather than guessing; do not print a wrong number.

**Remove the result from the toast.** The toast keeps whiffs and bank confirmations; the splash
owns results. Both firing would say the same thing twice in two places.

- [ ] **Step 3: Verify and commit**

Confirm by reading: the splash fires only on the `drumRest` gate (never directly from
`RevealResult`); it cannot appear for a round the player did not throw in; `DisplayOrder` is 30;
nothing in the file is a button or `Active`.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the round ends with your name on it"
```

---

