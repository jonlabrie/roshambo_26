### Task 11: The pot indicator, BANK THESE, the fate prompt — and remove the win gate

**This task withdraws a feature that Tasks 3–9 built, reviewed and shipped green.** Read the
spec's *The pot indicator* section before starting; the reasoning is the point, not the diff.

Short version: a button reading **RISK IT** is wager language on a mechanic that is deliberately
not a wager, and Roblox proscribes simulated gambling in a kid-first experience. It is replaced by
a persistent pot indicator — same information, framed as *collecting winnings*. **Throwing again
is riding**, so nothing blocks a throw and no client action resolves anything.

Deleting working code is the job here. Do it thoroughly: a half-removed gate is worse than either
design.

**Files:**
- Modify: `roblox/src/shared/HudModel.luau` + `roblox/tests/HudModel.spec.luau`
- Modify: `roblox/src/client/HudController.client.luau`, `roblox/src/client/main.client.luau`
- Modify: `roblox/src/server/main.server.luau`, `roblox/src/server/NetworkClient.luau`
- Modify: `roblox/default.project.json`
- Modify: `server/src/wallet.ts`, `server/src/wallet.test.ts`, `server/src/routes/apiV1.ts`

**Interfaces:**
- `HudModel.view` drops `choiceUp` and gains `slot: "pot" | "fate" | "none"` and
  `potPulses: boolean`.
- `BankRequest` (which already exists and predates this plan) carries banking again.

**Keep — do NOT remove these:** `unresolvedWin` on the profile and in `PlayerProfiles`,
`Settlement` maintaining it, `bankPot` clearing it and accruing `lifetimeBanked`, all nine
counters, and `buildProfilePayload` exposing them. Only the *gate* and its bespoke route go.

- [ ] **Step 1: Change `HudModel` — failing tests first**

`throwsEnabled` must no longer consider `unresolvedWin`; only `fateBound` blocks. The escalation's
`bound` term likewise becomes `fateBound` alone.

```luau
    test("a win no longer blocks throwing — riding IS throwing again", function()
        local v = HudModel.view(inputs({ unresolvedWin = true, pointsAtStake = 27 }), session(0))
        expect(v.throwsEnabled).toBe(true)
    end)

    test("a fate still blocks throwing", function()
        expect(HudModel.view(inputs({ fateBound = true }), session(0)).throwsEnabled).toBe(false)
    end)

    test("the slot holds the pot whenever points are unbanked", function()
        local v = HudModel.view(inputs({ pointsAtStake = 27 }), session(0))
        expect(v.slot).toBe("pot")
    end)

    test("the slot holds the fate prompt when fate-bound", function()
        expect(HudModel.view(inputs({ fateBound = true }), session(0)).slot).toBe("fate")
    end)

    test("the slot is empty with no pot and no fate", function()
        expect(HudModel.view(inputs({}), session(0)).slot).toBe("none")
    end)

    test("fate wins the slot if both are somehow set", function()
        -- a LOSS forfeits the pot, so this should be unreachable; assert the defensive order
        -- rather than trusting it, because the wrong tenant here hides the only way out of a fate
        local v = HudModel.view(inputs({ fateBound = true, pointsAtStake = 27 }), session(0))
        expect(v.slot).toBe("fate")
    end)

    test("the pot pulses only while the win is unacknowledged", function()
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = true }), session(0)).potPulses).toBe(true)
        expect(HudModel.view(inputs({ pointsAtStake = 27, unresolvedWin = false }), session(0)).potPulses).toBe(false)
    end)

    test("nothing pulses when there is no pot", function()
        expect(HudModel.view(inputs({ pointsAtStake = 0, unresolvedWin = true }), session(0)).potPulses).toBe(false)
    end)

    test("an unacknowledged win does not silence the escalation", function()
        -- it used to: unresolvedWin was part of `bound`, and bound players were never armed
        expect(HudModel.view(inputs({ secondsLeft = 3, unresolvedWin = true, pointsAtStake = 9 }), session(0)).escalate).toBe(true)
    end)
```

Delete every existing test asserting `choiceUp`, and the two asserting a win-bound player cannot
throw. **Keep** every fate-bound test — that gate is unchanged.

- [ ] **Step 2: Run them and watch them fail**

`lune run tests/run` from `roblox/`. Expected: the new cases fail, the deleted-behaviour cases are gone.

- [ ] **Step 3: Implement the `HudModel` change**

```luau
    -- Only a FATE blocks a throw. An unacknowledged win does not: throwing again IS riding,
    -- which is why there is no RISK button and nothing to resolve.
    local blocked = inputs.fateBound
    local throwsEnabled = inputs.phase == "ACTIVE"
        and inputs.secondsLeft > 0
        and not blocked
        and not inputs.pickedThisRound

    -- One slot above the throw row, two possible tenants. A LOSS forfeits the pot, so
    -- pointsAtStake is always 0 while fate-bound and these cannot really coexist -- but fate
    -- takes precedence defensively, because the wrong tenant here would hide the only way out.
    local slot: string = if inputs.fateBound
        then "fate"
        elseif inputs.pointsAtStake > 0 then "pot"
        else "none"
```

and `potPulses = slot == "pot" and inputs.unresolvedWin`. Use `blocked` in the `armed` expression
where `bound` was.

- [ ] **Step 4: Render it in `HudController`**

In the slot directly above the throw row:

- **pot**: the figure in a red disc (`Frame`, `UICorner` at `UDim.new(1,0)`, `Active = false`),
  with **BANK THESE** beside it (`TextButton`, firing `EventBus.HudBank`). While `potPulses`, tween
  the disc's `BackgroundTransparency` on a loop; stop the tween when it clears.
- **fate**: one **ACCEPT YOUR FATE** button (`TextButton`) firing
  `EventBus.Cue:Fire({ kind = "acceptFate" })` — the cue `FateController` already listens for.
  This restores an affordance Task 10 deleted with the old UI.
- **none**: the slot is empty and occupies no space.

The interactive budget is now three throws + the plate + **exactly one** slot button. Two slot
buttons can never be live at once; assert that by construction, not by hoping.

- [ ] **Step 5: Render the escalation**

Elaborate Task 10's stub: a large centred count plus `CHOOSE A THROW`, shown on `view.escalate`,
with the bottom hairline turning red and thickening.

```luau
-- Active = false: this is a label, not a button. It covers the centre of the screen, which is
-- the middle of the camera-drag surface — sinking input here would make the canyon unrotatable
-- for the five seconds it is up.
```

- [ ] **Step 6: Remove the win gate, end to end**

Roblox server (`main.server.luau`): delete the `unresolvedWin` check in `SubmitPick` (leave the
`fates:isBound` check), the whole `ResolveWin.OnServerEvent` handler, and its `WaitForChild`.
`NetworkClient.luau`: delete `postResolveWin`. `default.project.json`: delete the `ResolveWin`
declaration. `main.client.luau`: wire `EventBus.HudBank` to the existing `BankRequest` remote.

Node server: delete `resolveWin` from `wallet.ts`, the `POST /resolve-win` route from `apiV1.ts`,
its import, and the `describe('resolveWin', ...)` block from `wallet.test.ts`. **Leave `bankPot`
exactly as it is** — its `unresolvedWin: false` and `lifetimeBanked` additions are still correct
and still needed.

Grep for `resolveWin`, `ResolveWin` and `postResolveWin` afterwards. Nothing but changelog prose
should remain.

- [ ] **Step 7: Add `escalationPrompts` to `ProfileUpdate`**

Task 10 found `fireProfile` does not carry it, so the client hard-defaults it to true and the
Task 12 preference switch would be write-only. Add it in `main.server.luau` beside `unresolvedWin`.

- [ ] **Step 7b: Two defects from the Task 10 review, in files you are already editing**

Both were rated Minor and deferred; fixing them here costs almost nothing and avoids a second pass.

1. **The timer hairline lies when the clock is unsynced.** `main.client.luau` returns a constant
   `UNSYNCED_SECONDS = 30` whenever `lockoutAt` is nil, and `lockoutAt` is only assigned at the
   ACTIVE transition — so if `secondsToLockout` ever arrives nil it stays nil all round, pinning
   the hairline **full and motionless** while throws keep working past the real lockout. Keeping
   throws enabled is right; showing a frozen full countdown is not. **Hide the hairline entirely
   when `lockoutAt == nil`** rather than faking a span.
2. **A whiffed pick stays illuminated.** The whiff branch toasts "TOO LATE — your throw didn't
   count" while leaving `myPick` set, so the tapped tile stays lit through REVEAL as though it
   counted — the toast and the tile contradict each other. Clear `myPick` there.

Leave the other two deferred Minors alone: the toast-queue backlog and the aged-tape glyph
contrast are Task 15 sweep items.

- [ ] **Step 8: Gates and commit**

```bash
cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run
cd ../server && npm test
git commit -m "feat(roblox): pot indicator replaces the blocking RISK/BANK overlay"
```

---

