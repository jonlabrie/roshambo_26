### Task 5: The SWITCH → UNDO rename, in the client

**Files:**
- Modify: `roblox/src/client/main.client.luau:92-93`, `:231`, `:408-411`, `:494-495`, `:525-526`, `:663-665`
- Modify: `roblox/src/client/HudController.client.luau:566-630`, `:1304-1306`, and the comments at `:352`, `:1072`, `:1075`, `:1137`

**Interfaces:**
- Consumes: the renamed `HudModel` surface from Task 4.
- Produces: `undoPill` / `undoLabel` / `setUndoPrompt` in `HudController`, which Task 6 restyles.

**Context:** Mechanical rename, no behaviour change, no visual change. Task 6 does the look. Neither of these files is loaded by any gate, so the rename's completeness has to be verified by grep rather than by a green run.

- [ ] **Step 1: Rename in main.client.luau**

- `local switchPrompt` → `local undoPrompt`; `local switchPromptAt` → `local undoPromptAt` (`:92-93`)
- the `switchPrompt = switchPrompt` field in `publish()` → `undoPrompt = undoPrompt` (`:231`)
- `HudModel.applyTap({ chosen = chosen, switchPrompt = switchPrompt }, ...)` → `undoPrompt = undoPrompt` (`:408`), and `nextState.switchPrompt` → `nextState.undoPrompt` (`:410`)
- the clears at `:494-495` and `:525-526`
- `HudModel.switchPromptExpired(switchPromptAt, os.clock())` → `HudModel.undoPromptExpired(undoPromptAt, os.clock())` and the two clears beneath it (`:663-665`)

**Leave alone:** `:31` ("one remote for every preference, never one per switch"), `:267` ("the preference switch"), `:434` and `:436` ("there is deliberately not a second one per switch", "The switch's own paint is optimistic in LedgerController"). Those mean settings toggles, not this mechanic. Read each in context before deciding.

- [ ] **Step 2: Rename in HudController.client.luau**

- `switchPill` → `undoPill`, `switchLabel` → `undoLabel`, `setSwitchPrompt` → `setUndoPrompt` (`:579-630`)
- `switchPill.Name = "SwitchPrompt"` → `undoPill.Name = "UndoPrompt"`
- `view.switchPrompt` → `view.undoPrompt` at `:1304` and `:1306`
- the comment block at `:566-578`, which explains the mechanic in the old word throughout
- the cross-references in other comments at `:352`, `:1072`, `:1075`, `:1137` that cite `switchLabel` by name

**Leave alone:** `:89` ("the same switch so its safe band") — that is the touch-tier boolean.

- [ ] **Step 3: Verify nothing was missed, and nothing over-renamed**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
grep -rn "switchPrompt\|switchPill\|switchLabel\|setSwitchPrompt\|SWITCH_PROMPT\|SWITCH?" roblox/src roblox/tests
```
Expected: no output.

```bash
grep -rn "switch\|Switch" roblox/src/client/main.client.luau roblox/src/client/HudController.client.luau
```
Expected: only the settings-toggle and touch-tier senses listed in Steps 1 and 2. Read every hit.

- [ ] **Step 4: The standing check for client files**

Confirm every `view.X` read in `HudController`'s `render` resolves to a field `HudModel.view` actually returns — `undoPrompt` in particular, since it was just renamed on both sides and a mismatch here would silently disable the prompt with every gate green.

- [ ] **Step 5: Run every gate and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/client/main.client.luau roblox/src/client/HudController.client.luau
git commit -m "refactor(roblox): carry the UNDO rename into the client"
```

---

