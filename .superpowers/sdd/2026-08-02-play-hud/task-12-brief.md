### Task 12: `LedgerController` — maximal

**Files:**
- Create: `roblox/src/client/LedgerController.client.luau`

**Interfaces:**
- Consumes: `LedgerModel`, `Glyphs`, `EventBus.OpenLedger`, the profile payload's `counters`.
- Produces: `EventBus.HudPreference` fired with `{ escalationPrompts: boolean }`.

- [ ] **Step 1: Build the panel**

Full-screen `ScreenGui` with a scrim and a panel inset ~3%. Header (title, "MOVEMENT SUSPENDED
WHILE OPEN", ✕), hero band, three cards, preferences footer.

**Suspend movement while open:**

```luau
-- The canyon is cliff edges and switchbacks. Reading statistics while a thumb drifts on the
-- stick is how someone walks off the FW11 deck. The header says so in plain text — it is a
-- promise, not an apology.
local Controls = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
-- on open:  Controls:Disable()
-- on close: Controls:Enable()
```

Verify the `PlayerModule` path in Studio before relying on it; if the place uses a different
control stack, fall back to `Humanoid.WalkSpeed = 0` restored on close.

- [ ] **Step 2: Wire entry and exit**

Open on `EventBus.OpenLedger`. Close on the ✕, on a tap outside the panel, and on
`UserInputService.InputBegan` for `Enum.KeyCode.Escape`. **Every path must re-enable controls** —
a ledger that leaves a player frozen is worse than no ledger. Route all three through one
`close()` function so the re-enable cannot be forgotten on a new path.

- [ ] **Step 3: Render the blocks**

Hero: streak / pot / points, then `A WIN HERE PAYS <view.paysNext>`, plus a **BANK THESE** button
whenever `live.pot > 0` — so a player studying the decision can act on it without closing the
panel. There is no RISK button anywhere; riding is throwing again (see the spec's
*The pot indicator*). Lifetime card: the five figures and the `view.bar` segmented bar. Your-throws card:
three rows of `Glyphs.render` + a proportional bar + `view.mix` percentage. Feed card: a
`ScrollingFrame`, **personal events only in v1**.

- [ ] **Step 4: Preferences footer**

One row, one switch — *Escalation prompts* — firing `EventBus.HudPreference` with
`{ escalationPrompts = <bool> }`. Wire it in `main.client.luau` to the `SetHudPreference` remote
declared in Task 9:

```luau
EventBus.HudPreference.Event:Connect(function(body)
    SetHudPreference:FireServer(body)
end)
```

Add `"HudPreference"` to `EventBus.NAMES`. Size the row for later additions, but ship exactly one
switch — the rest is YAGNI until there is a second preference to put in it.

The switch reads its initial state from the profile's `escalationPrompts` and applies optimistically;
the next `ProfileUpdate` echo reconciles.

- [ ] **Step 4b: Counters are authoritative at open, not accumulated**

The nine counters are lifetime totals and must never be advanced optimistically client-side. The
local reveal is computed from the pick buffer whether or not the `POST /throws` flush ever
reached the backend, so an accumulating counter can only drift **upward** — a player watches
ROUNDS THROWN climb to 40, rejoins, and sees 37. A lifetime total that goes down is worse than
one that is briefly stale.

Instead: **re-seed from the authoritative profile when the panel opens.** Opening maximal is a
deliberate, occasional act, `net:getPlayer` already returns `counters`, and the numbers only
matter on the one occasion someone looks at them. Check whether the existing `RequestSync`
remote is the right hook before adding another.

Seed zeros **unconditionally** at join, before the fetch. If the join fetch fails and the
counters stay nil, a nil-gate downstream will blank the entire panel — including the live
hero band and the preference switch, which have nothing to do with counters.

- [ ] **Step 5: Verify in Studio**

Open from the plate. Confirm: movement is suspended and restored by **all three** exit paths;
"A WIN HERE PAYS" matches `GameRules.nextPot(pot, "WIN")`; the bar has no gap; the throw mix
sums to 100; the preference switch survives a rejoin.

- [ ] **Step 6: Run the gates and commit**

```bash
stylua --check src tests tools && selene src tools
git add roblox/src/client/LedgerController.client.luau roblox/src/client/main.client.luau
git commit -m "feat(roblox): LedgerController — the maximal takeover panel"
```

---

