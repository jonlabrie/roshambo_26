### Task 4: The SWITCH → UNDO rename, in the shared model

**Files:**
- Modify: `roblox/src/shared/HudModel.luau:35-40`, `:64`, `:71`, `:82`, `:91-127`, `:133-135`, `:195`
- Test: `roblox/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces, for Tasks 5 and 6:
  - `HudModel.UNDO_PROMPT_SECONDS` (was `SWITCH_PROMPT_SECONDS`) — **value unchanged at 1 in this task**; Task 6 changes it.
  - `HudModel.undoPromptExpired(setAt, now)` (was `switchPromptExpired`)
  - `Inputs.undoPrompt`, `View.undoPrompt`, `TapState.undoPrompt` (all were `switchPrompt`)
- Unchanged: the `"choose"` / `"prompt"` / `"clear"` / `"ignore"` action strings returned by `tapAction`. They already name the act, not the word.

**Context:** This is a **pure rename with no behaviour change**, kept in its own commit so its diff reads as one. The mechanic's copy is changing from `SWITCH?` to `UNDO?` because `SWITCH?` described something the button has never done: confirming that prompt clears the choice entirely — it does not switch the player to the glyph they tapped. That is why both unchosen buttons act as back-out proxies. Leaving the internal name as `switchPrompt` while the surface says `UNDO?` is exactly the stale-name trap that has cost this project a round already.

- [ ] **Step 1: Rename in the test file first**

In `roblox/tests/HudModel.spec.luau`, rename every occurrence of `switchPrompt` → `undoPrompt`, `switchPromptExpired` → `undoPromptExpired`, and `SWITCH_PROMPT_SECONDS` → `UNDO_PROMPT_SECONDS`. There are roughly 30, at lines 16, 73, 84-85, 90-93, 181-182, 301, 310, 314, 320, 326-370, 376, 384-392, 432, 466-467, 484.

Update the prose in test names and comments that says "switch" about this mechanic — e.g. `"switchPrompt does not survive a send"` becomes `"undoPrompt does not survive a send"`.

**Leave line 115 alone** (`"the preference switch silences it outright"`) — that "switch" means a settings toggle, not this mechanic.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `lune run tests/run`
Expected: FAIL — `HudModel.undoPromptExpired` is nil, and `undoPrompt` reads as nil throughout.

- [ ] **Step 3: Rename in HudModel**

Rename in `roblox/src/shared/HudModel.luau`:
- `Inputs.switchPrompt` → `Inputs.undoPrompt` (`:40`)
- `View.switchPrompt` → `View.undoPrompt` (`:64`, and the assignment at `:195`)
- `TapState.switchPrompt` → `TapState.undoPrompt` (`:82`, and all five returns in `applyTap` at `:121-127`)
- `inputs.switchPrompt` → `inputs.undoPrompt` in `tapAction` (`:107`)
- `HudModel.SWITCH_PROMPT_SECONDS` → `HudModel.UNDO_PROMPT_SECONDS` (`:71`, `:134`)
- `HudModel.switchPromptExpired` → `HudModel.undoPromptExpired` (`:133`)

Then update the comments that describe the mechanic by the old word:
- `:35-36` — "the glyph currently carrying a SWITCH? prompt" → "an UNDO? prompt"
- `:91-99` — the `tapAction` header block: `"prompt" — raise SWITCH? over `symbol`` → `raise UNDO? over `symbol``; "The switch path is the only way out" → "The undo path is the only way out"; "CONFIRMING A SWITCH UNLOCKS; IT DOES NOT SELECT" → "CONFIRMING AN UNDO UNLOCKS; IT DOES NOT SELECT".

Add to the `UNDO_PROMPT_SECONDS` comment block a line recording why the word changed:

```lua
-- The word changed from SWITCH? to UNDO? on 2026-08-04 because SWITCH? described something this
-- button has never done: answering it CLEARS the choice, it does not move the choice to the
-- glyph that was tapped. That is what makes either unchosen button a back-out proxy.
```

- [ ] **Step 4: Verify nothing was missed**

```bash
grep -n "switchPrompt\|SWITCH_PROMPT\|switchPromptExpired" roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
```
Expected: no output.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: FAIL still — `main.client.luau` and `HudController.client.luau` are not loaded by the harness, so they cannot break it, but **`HudModel.spec.luau` must now pass**. If anything else fails, it is a real miss. Task 5 repairs the two client files.

- [ ] **Step 6: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
git commit -m "refactor(roblox): the prompt is an UNDO, and now says so in the model"
```

---

