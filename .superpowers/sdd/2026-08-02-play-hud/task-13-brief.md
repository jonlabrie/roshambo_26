### Task 13: Onboarding beats on screen

**Files:**
- Create: `roblox/src/client/OnboardingController.client.luau`
- Modify: `roblox/src/client/main.client.luau` (fire `EventBus.Onboard`)

**Interfaces:**
- Consumes: `OnboardingBeats`, `EventBus.Onboard` fired with an event name, and the profile's
  `seenBeats` list.
- Produces: a `seenBeat` write via `EventBus.HudPreference` → the `SetHudPreference` remote from
  Task 9 (`{ seenBeat = "<id>" }`). The same remote as the preference switch — do not add another.

- [ ] **Step 1: Build the renderer**

One dismissable card at a time, anchored near its `beat.anchor` (`drum`, `throwArea`,
`choiceOverlay`, `plate`). A card is a `TextButton` (dismiss on tap) plus a label. On dismiss:

```luau
table.insert(seenLocal, beat.id) -- optimistic: stops a re-fire before the round trip lands
EventBus.HudPreference:Fire({ seenBeat = beat.id })
```

Hold `seenLocal` seeded from the profile's `seenBeats` and pass it to `OnboardingBeats.next`.
Never queue two cards at once — if a second event fires while a card is up, drop it rather than
stacking; these are bones, and a stack of cards is a tutorial.

- [ ] **Step 2: Fire the events**

- `join` — once, after the first `RoundUpdate` (waits until the arena is live)
- `throwsUnlocked` — the first time `view.throwsEnabled` becomes true
- `win` — the first `RevealResult` with `result == "WIN"`
- `bank` — the first successful bank echo

- [ ] **Step 3: Verify in Studio**

Join with a profile whose `seenBeats` is empty. Confirm each beat fires on its own event, once,
and never returns after a rejoin.

- [ ] **Step 4: Run the gates and commit**

```bash
stylua --check src tests tools && selene src tools
git add roblox/src/client/OnboardingController.client.luau roblox/src/client/main.client.luau
git commit -m "feat(roblox): four event-triggered onboarding beats"
```

---

