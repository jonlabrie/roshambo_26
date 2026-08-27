### Task 5: `main.client.luau` — park the fate branches

Separate from Task 4 so a reviewer can gate the state-machine change without the deletion
noise, and vice versa.

**Files:**
- Modify: `roblox/src/client/main.client.luau`

- [ ] **Step 1: Delete the fate wiring**

Remove, in order:
- `local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent`
- `local fateBound = false`
- `local pendingFate = false` and its comment block
- the `if pendingFate then … end` block inside `maybeShowReveal`
- the whole `FateResolvedEvt.OnClientEvent:Connect(…)` handler
- the `if mine and mine.result == "LOSS" then … end` block in the `RevealTheater` handler
  (the `pendingFate` set, the `maybeShowReveal()` call and the `REVEAL_SAFETY` delay). The
  whiff branch below it stays.

- [ ] **Step 2: Update the file header**

The header's bullet list mentions the fate. Replace the spoiler-gate bullet with:

```luau
--   • the DRUM-REST SPOILER GATE (see `visibleTape` / `maybeShowReveal`), which holds the tape
--     tile and the headline until the wheel stops turning,
```

and add a note under it:

```luau
--
-- FATES ARE PARKED (2026-08-03). The rock drop, the avatar grow and ACCEPT YOUR FATE are all
-- off; a LOSS now simply forfeits the pot and says so on the drum. The machinery they rode on
-- (ChoreographyMachine, EffectSelector, TheaterController) is intact and still drives the WIN,
-- SAFE and BANK effects — see the spec's §5 for where the seam is.
```

- [ ] **Step 3: Verify nothing dangles**

`REVEAL_SAFETY` must still be referenced (the `RevealResult` handler uses it). Confirm:

```bash
cd roblox && grep -n "fate\|Fate\|REVEAL_SAFETY" src/client/main.client.luau
```
Expected: only `REVEAL_SAFETY` (its definition and the `RevealResult` delay) and the header
note. No `fateBound`, no `pendingFate`, no `FateResolvedEvt`.

- [ ] **Step 4: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/client/main.client.luau
git commit -m "refactor(roblox): the client stops waiting for a fate that never comes"
```

---

