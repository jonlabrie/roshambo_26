# Task 5 report: The SWITCH → UNDO rename, in the client

Commit: `73724e5` — "refactor(roblox): carry the UNDO rename into the client"

## Identifiers renamed

### `roblox/src/client/main.client.luau`
- `local switchPrompt` → `local undoPrompt`, `local switchPromptAt` → `local undoPromptAt` (declaration)
- `switchPrompt = switchPrompt,` in `buildInputs()`'s returned table → `undoPrompt = undoPrompt,` (the brief called this "the field in `publish()`"; it actually lives in `buildInputs()`, which `publish()` calls — same field, correct rename either way)
- `HudModel.applyTap({ chosen = chosen, switchPrompt = switchPrompt }, action, value)` → `undoPrompt = undoPrompt`
- `switchPrompt = nextState.switchPrompt` → `undoPrompt = nextState.undoPrompt`
- `switchPromptAt = if switchPrompt then os.clock() else nil` → `undoPromptAt = if undoPrompt then os.clock() else nil`
- The two clears in the `RevealTheater` handler (whiff path) → `undoPrompt = nil`, `undoPromptAt = nil`
- The two clears in the `RoundUpdate` handler (ACTIVE branch) → `undoPrompt = nil`, `undoPromptAt = nil`
- `HudModel.switchPromptExpired(switchPromptAt, os.clock())` → `HudModel.undoPromptExpired(undoPromptAt, os.clock())`, and its two accompanying clears → `undoPrompt = nil`, `undoPromptAt = nil`
- Comment: `"An unanswered SWITCH? ages out."` → `"An unanswered UNDO? ages out."` (describes the mechanic, not the brief's itemized list, but left in the old word would contradict HudModel's own already-renamed comments — see "judgment calls" below)

### `roblox/src/client/HudController.client.luau`
- `local switchPill` → `local undoPill` (and all 9 of its property assignments/calls: `.Name`, `.AnchorPoint`, `.Size`, `.BackgroundColor3`, `.BackgroundTransparency`, `.BorderSizePixel`, `.ZIndex`, `.Visible`, `.Parent`, plus `corner(...)`/`stroke(...)` call sites)
- `switchPill.Name = "SwitchPrompt"` → `undoPill.Name = "UndoPrompt"`
- `local switchLabel` → `local undoLabel` (and its property assignments: `.Name`, `.Size`, `.BackgroundTransparency`, `.TextColor3`, `.TextSize`, `.Font`, `.ZIndex`, `.Parent`, `.TextScaled`, plus the `UITextSizeConstraint.Parent` assignment)
- `local function setSwitchPrompt` → `local function setUndoPrompt`, and its two body reads/writes of `switchPill` → `undoPill`
- `view.switchPrompt` → `view.undoPrompt` at both call sites in `render` (`paintThrows(lit, view.throwsEnabled, view.undoPrompt)` and `setUndoPrompt(view.undoPrompt)`)
- Comment block header `"===== SWITCH?: the question raised..."` → `"===== UNDO?: the question raised..."`, and its body: `"Confirming a switch UNLOCKS"` → `"Confirming an undo UNLOCKS"`, `"proxies for switch-and-cancel"` → `"proxies for undo-and-cancel"`
- Four cross-reference comments citing `switchLabel` by name → `undoLabel` (near `plateLabel`'s TextScaled rationale; twice in the escalation-panel width-arithmetic comments; once in `escalationPrompt`'s belt-and-braces comment)
- Two comments describing the mechanic generically (not citing an identifier, not in the brief's itemized line ranges): `"...a tap that would only raise a SWITCH? prompt..."` (near `chosenSym`'s declaration) and `"...the tap only raises a SWITCH? prompt..."` (in the press handler) → both → `"...an UNDO? prompt..."` / `"...an UNDO? prompt..."`

## "switch" occurrences deliberately LEFT, with reason

- `main.client.luau:31` — "one remote for every preference, never one per switch" (settings-toggle sense)
- `main.client.luau:267` — "the preference switch" (settings-toggle sense)
- `main.client.luau:434` — "there is deliberately not a second one per switch" (settings-toggle sense)
- `main.client.luau:436` — "The switch's own paint is optimistic in LedgerController" (settings-toggle sense)
- `HudController.client.luau:89` — "the same switch so its safe band" (touch-tier boolean, per brief)
- `HudController.client.luau:584-587` and `:610-612` — the pill-sizing rationale comments that quote the literal `"SWITCH?"` string as data for the current 13px/BTN_W measurements. Left untouched because they document *Size/TextSize* reasoning, which the brief explicitly reserves for Task 6 ("do not change the pill's Size, corner radius, TextSize, or MaxTextSize"). Renaming the quoted string inside them without redoing the arithmetic would make them describe a measurement that no longer matches the code.
- `HudController.client.luau:605` — `undoLabel.Text = "SWITCH?"`. The identifier is renamed; the literal copy is untouched per the explicit instruction ("LEAVE the display string 'SWITCH?' as-is if the brief does not tell you to change it — Task 6 sets the copy").
- `HudModel.luau:72` — "The word changed from SWITCH? to UNDO?..." — out of scope (shared file, previous task's territory, and it's a historical note, not a live reference).

## Judgment calls / discrepancy noted

The brief's own Step 3 verify command (`task-5-brief.md` line 37) includes a bare `SWITCH?` in its grep alternation and expects no output — which would conflict with leaving `undoLabel.Text = "SWITCH?"` and its two Size-rationale comments untouched (both still contain that literal string). I followed the orchestrating instructions instead, which explicitly told me to leave the display string as-is and gave a verify list *without* `SWITCH?` in it. I did rename the two other "SWITCH? prompt" mechanic-description comments (not itemized by line number in the brief, and not matched by the case-sensitive `switch|Switch` check either, since they're all-caps) for consistency with HudModel.luau's own already-renamed prose — leaving them would have read as a stale description of the mechanic sitting right next to newly-renamed code. Flagging this as a minor judgment call rather than a strict-brief-compliance item.

## `view.X` reconciliation

`HudModel.view` returns: `plate {streak, points}`, `throwsEnabled`, `bankVisible`, `pot`, `potPulses`, `escalate`, `secondsLeft`, `chosen`, `undoPrompt`.

Every `view.*` read in `HudController`'s `render` (lines ~1279-1394): `view.throwsEnabled`, `view.chosen`, `view.plate.points`, `view.plate.streak`, `view.pot`, `view.potPulses`, `view.undoPrompt`, `view.secondsLeft`, `view.escalate` — all match returned fields exactly. `view.bankVisible` is not read in code (matches HudModel.luau's own comment: "Nothing renders this field directly"). No mismatch found; `view.undoPrompt` in particular resolves correctly on both sides of the rename.

## Gate output

```
lune run tests/run    → 970 passed, 0 failed, 970 total
stylua --check src tests tools → 0 errors, 0 warnings, 0 parse errors
selene src tools       → 0 errors, 0 warnings
```

## Concerns

None blocking. The only open item is the brief-vs-orchestrator discrepancy on the `SWITCH?` grep pattern noted above — resolved in favor of the orchestrator's explicit, more specific instruction, and the literal display string is exactly where Task 6 expects to find it (`undoLabel.Text = "SWITCH?"`, sizing comments intact and accurate for the current Size).
