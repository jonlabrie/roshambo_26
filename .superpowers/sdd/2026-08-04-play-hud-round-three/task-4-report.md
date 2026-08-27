# Task 4 Report: The SWITCH → UNDO rename, in the shared model

## Status: DONE

Commit: `e6c78bd24b17f57883b6badfb58f8d43ae317cb5` — "refactor(roblox): the prompt is an UNDO, and now says so in the model"

## Steps followed (per brief order)

1. Renamed in `roblox/tests/HudModel.spec.luau` first (via `sed` on the exact identifiers
   `switchPromptExpired`, `SWITCH_PROMPT_SECONDS`, `switchPrompt` — in that order, longest-first,
   so no partial-match collisions).
2. Ran `lune run tests/run` — confirmed 9 failures (all `HudModel.spec` cases referencing the
   now-nil `undoPrompt`/`undoPromptExpired`/`UNDO_PROMPT_SECONDS` on the still-unrenamed module),
   961 passed / 970 total.
3. Renamed the same identifiers in `roblox/src/shared/HudModel.luau`, then hand-edited the prose
   comments (see below).
4. Verified with the brief's grep — no output.
5. Reran `lune run tests/run` — 970 passed / 0 failed / 970 total.
6. Ran `stylua --check src tests tools` (0 errors/warnings/parse errors) and `selene src tools`
   (0 errors) from `roblox/`, then staged and committed exactly the two files named in the brief.

## Every identifier renamed

In both `roblox/src/shared/HudModel.luau` and `roblox/tests/HudModel.spec.luau`:
- `HudModel.SWITCH_PROMPT_SECONDS` → `HudModel.UNDO_PROMPT_SECONDS` (value unchanged: still `1`)
- `HudModel.switchPromptExpired` → `HudModel.undoPromptExpired`
- `Inputs.switchPrompt` → `Inputs.undoPrompt`
- `View.switchPrompt` → `View.undoPrompt` (declaration + the `HudModel.view` assignment)
- `TapState.switchPrompt` → `TapState.undoPrompt` (declaration + all `applyTap` return sites)
- local variable `inputs.switchPrompt` reads in `tapAction` → `inputs.undoPrompt`
- test-local helper params/locals named `switchPrompt` (e.g. `state(chosen, prompt)`'s field,
  loop locals in the invariant walk, `sentInputs` table keys) → `undoPrompt`
- test/describe names: `"switchPrompt does not survive a send..."` →
  `"undoPrompt does not survive a send..."`; `describe("HudModel.switchPromptExpired", ...)` →
  `describe("HudModel.undoPromptExpired", ...)`; `describe("HudModel.SWITCH_PROMPT_SECONDS — a
  one-second fuse", ...)` → `describe("HudModel.UNDO_PROMPT_SECONDS — a one-second fuse", ...)`

Prose comments updated in `HudModel.luau`:
- `:35-36` — "the glyph currently carrying a SWITCH? prompt" → "an UNDO? prompt"
- `:87` (tapAction header) — `"prompt" — raise SWITCH? over \`symbol\`` → `raise UNDO? over
  \`symbol\``
- `:91` — "The switch path is the only way out" → "The undo path is the only way out"
- `:95` — "CONFIRMING A SWITCH UNLOCKS; IT DOES NOT SELECT" → "CONFIRMING AN UNDO UNLOCKS; IT DOES
  NOT SELECT"
- Added to the `UNDO_PROMPT_SECONDS` comment block (as specified verbatim by the brief) a note
  recording why the word changed, dated 2026-08-04.

## "switch" occurrences deliberately LEFT, and why

- `roblox/tests/HudModel.spec.luau:115` — `test("the preference switch silences it outright", ...)`.
  This exercises `inputs.escalationPrompts = false`, a settings toggle (the escalation-nag
  preference), not the UNDO?/back-out mechanic. Left untouched per the brief's explicit
  instruction and confirmed correct by reading the test body before touching it.
- `roblox/src/shared/HudModel.luau:72` (new comment, `UNDO_PROMPT_SECONDS` block) — "The word
  changed from SWITCH? to UNDO? on 2026-08-04 because SWITCH? described..." — this is the
  brief-mandated changelog note; it names the old word deliberately, as history, not as a
  live description of current behavior. Confirmed via `grep -ni switch` that no other occurrence
  of the word survives in either file.
- Left entirely alone: `roblox/src/client/main.client.luau` (`switchPrompt`, `switchPromptAt`,
  `HudModel.switchPromptExpired` call) and `roblox/src/client/HudController.client.luau`
  (`view.switchPrompt`, `setSwitchPrompt`) — per the brief and the calling agent's explicit
  instruction, these are Task 5's responsibility. Not modified.

## Gate output

```
lune run tests/run
970 passed, 0 failed, 970 total
(two [WARN] lines from HandlerQueue.spec's intentional error-path test — pre-existing, unrelated)

stylua --check src tests tools
0 errors, 0 warnings, 0 parse errors

selene src tools
0 errors
```

## Verification grep (brief's Step 4, re-run after commit)

```
grep -n "switchPrompt\|SWITCH_PROMPT\|switchPromptExpired" \
  roblox/src/shared/HudModel.luau roblox/tests/HudModel.spec.luau
```
No output, as expected.

## Concerns

- **The live client is now broken until Task 5 lands.** `main.client.luau` and
  `HudController.client.luau` still call `HudModel.switchPromptExpired` and read
  `view.switchPrompt` / `inputs.switchPrompt` / `TapState.switchPrompt`, all of which no longer
  exist on `HudModel`'s exported surface (they're all `nil` now, and
  `HudModel.switchPromptExpired` is `nil` — calling it will error). Since Studio/PWA dev
  auto-deploys the dev App Runner service on every push to `m4b-zendojo-art-pass`, pushing this
  commit alone would break the UNDO?/back-out flow (and the prompt-expiry heartbeat) at runtime
  for anyone testing in Studio, until Task 5's client-file rename is committed and deployed.
  This is expected per the brief and the calling agent's note 3 — flagging it so it isn't
  pushed in isolation without Task 5 following close behind.
- No other concerns. This was a mechanical, scoped rename with no behavior change; the fixture
  values, action-string vocabulary (`"choose"`/`"prompt"`/`"clear"`/`"ignore"`), and
  `UNDO_PROMPT_SECONDS` numeric value (`1`) are all unchanged.
