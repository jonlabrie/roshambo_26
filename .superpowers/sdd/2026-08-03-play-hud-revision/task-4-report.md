# Task 4 report: `main.client.luau` — pick state and the wire

## Summary

Rewired `roblox/src/client/main.client.luau` to the Task 2/3 `HudModel` API. `myPick` and
`selectedThrow` are gone, replaced by the five-field pick state (`chosen`, `switchPrompt`,
`switchPromptAt`, `sent`, `declinedThisRound`) exactly as specified in Steps 1–5 of the brief.
`commitPick` is gone; `sendPick` is the only function that talks to the server, and it is called
only from the heartbeat's `HudModel.sendAtLockout` branch. No `Instance.new` was added (none was
present before either).

## Deviations from the brief's literal text, and why

1. **`fateBound` needed a `-- selene: allow(unused_variable)` suppression.** The brief's Step 2
   (`buildInputs` drops `fateBound`) and ambiguity note 4 (`roundCouldThrow = true`, unconditional)
   together make `fateBound` write-only in this file — it's still assigned in `maybeShowReveal`'s
   fate branch and in the `FateResolvedEvt` handler (left alone per ambiguity note 3), but nothing
   reads it anymore. Selene's `unused_variable` lint flagged this and failed the gate (exit 1) with
   zero errors / one warning. I added a suppression comment directly above the declaration
   explaining it's temporary pending Task 5's removal of the fate system, rather than deviating from
   the brief's specified `buildInputs`/`roundCouldThrow` code. Confirmed clean after: `stylua`
   exit 0, `selene` "0 errors, 0 warnings" exit 0.

2. **`maybeShowReveal`'s fate branch: `myPick = nil` / `selectedThrow = nil` became
   `chosen = nil` / `switchPrompt = nil` / `switchPromptAt = nil`.** Ambiguity note 3 says to leave
   "the fate branch in `maybeShowReveal`" alone, but that branch's two lines directly reference the
   two variables Step 1 deletes — leaving them as bare identifiers would be an unknown-global
   reference under `--!strict` and would also fail the brief's own required verification grep
   (`myPick`/`selectedThrow` must appear nowhere). I read "leave alone" as scoped to the fate
   *logic* (the `pendingFate`/`fateBound` gating, left untouched) and translated only the pick-state
   side effects to the new variable names, mirroring the treatment the brief itself gives the
   structurally identical whiff branch in `RevealTheater` (same comment reasoning, same three-line
   clear). Flagging this as the one place I exercised judgment beyond the brief's literal text.

Everything else — `buildInputs`, `sendPick`, the tap handler, the heartbeat, the `publish()` aux
table, the `RoundUpdate` boundary/reset block, the `RevealTheater` whiff branch — matches the
brief's provided code verbatim.

## Verification

```
$ cd roblox && stylua --check src tests tools; echo $?
0
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
$ lune run tests/run
906 passed, 0 failed, 906 total
$ grep -n "myPick\|selectedThrow\|autoCommit\|pickedThisRound\|commitPick" src/client/main.client.luau
(no output)
$ grep -n "SubmitPick:FireServer" src/client/main.client.luau
332:    SubmitPick:FireServer(value)
$ grep -n "sendPick(" src/client/main.client.luau
330:local function sendPick(value: string)
607:            sendPick(send)
```

`SubmitPick:FireServer` appears exactly once, inside `sendPick` (line 330–338). The only call site
of `sendPick` is the heartbeat's `if send then sendPick(send) end` (line 607–612), gated on
`HudModel.sendAtLockout(buildInputs())`. No other code path — not the tap handler, not any reveal
handler — reaches the server directly.

## Trace: `chosen` / `switchPrompt` / `switchPromptAt` / `sent` / `declinedThisRound`

State before each row is whatever the previous row left; all rows assume mid-round unless noted.

**1. A tap that chooses** (round open, nothing chosen yet). `HudModel.tapAction` sees
`inputs.chosen == nil` → `"choose"`. `HudModel.applyTap` → `{ chosen = symbol, switchPrompt = nil }`.
Handler sets `chosen = symbol`, `switchPrompt = nil`, and since `switchPrompt` is now nil,
`switchPromptAt = nil`. `sent` and `declinedThisRound` untouched.

**2. A tap that prompts** (`chosen` set, tap on a *different*, non-prompted glyph).
`tapAction`: `symbol ~= inputs.chosen` and `symbol ~= inputs.switchPrompt` → `"prompt"`.
`applyTap` → `{ chosen = state.chosen (unchanged), switchPrompt = symbol }`. Handler sets
`switchPrompt = symbol`, and because `switchPrompt` is now truthy, `switchPromptAt = os.clock()`.
`chosen`, `sent`, `declinedThisRound` untouched.

**3. A tap that clears** (a `switchPrompt` is standing, tap lands on that same prompted glyph —
confirming the back-out). `tapAction`: `symbol == inputs.switchPrompt` → `"clear"`. `applyTap` →
`{ chosen = nil, switchPrompt = nil }`. Handler sets `chosen = nil`, `switchPrompt = nil`,
`switchPromptAt = nil` (switchPrompt now nil), and — because `action == "clear"` — additionally
sets `declinedThisRound = true`. `sent` untouched.

**4. Prompt expiry** (a `switchPrompt` has been standing ≥`HudModel.SWITCH_PROMPT_SECONDS` = 4s
with no confirming tap). Every heartbeat tick calls `HudModel.switchPromptExpired(switchPromptAt,
os.clock())`; once true, `switchPrompt = nil` and `switchPromptAt = nil`. `chosen`, `sent`,
`declinedThisRound` untouched — expiry restores exactly the pre-prompt state, it does not touch the
underlying choice or the decline flag.

**5. The lockout send** (`chosen` set, not yet `sent`, `secondsLeft <= 0.5` or phase has already
left ACTIVE). Every heartbeat tick calls `HudModel.sendAtLockout(buildInputs())`; once it returns
the chosen value, `sendPick(value)` runs: `sent = true` (set *before* the fire, so a re-entrant tick
in the same frame can't double-send), `SubmitPick:FireServer(value)`, `publish()`. `chosen` and
`switchPrompt` are untouched by the send itself — `sendAtLockout` only stops returning a value on
the *next* call because `inputs.sent` is now true, not because `chosen` was cleared.
`declinedThisRound` untouched.

**6. A whiff** (`RevealTheater` lands with `r.whiffed[myId]` true — the player's send arrived too
late for the server to accept, or nothing was ever chosen this round but the flag is checked
regardless). Toast fires, then `chosen = nil`, `switchPrompt = nil`, `switchPromptAt = nil`. `sent`
is left as-is (it will be reset on the next ACTIVE transition regardless) and
`declinedThisRound` is untouched — a whiff is the server's refusal, not the player's decision, so it
must not silence the escalation the way a real back-out does.

**7. The ACTIVE boundary** (`RoundUpdate` fires with `info.phase`). Two things happen in order:
   - If the *previous* `phase` was `"ACTIVE"` and the *new* `info.phase` is not, `roundEnded(roundCouldThrow, chosen ~= nil)` runs first, using the **pre-reset** `chosen` — a choice standing in the last half-second before lockout-send still counts as "played" even though the send itself already happened up to 0.5s earlier.
   - Then, if `info.phase == "ACTIVE"` (the *new* round opening), all five fields reset together:
     `chosen = nil`, `switchPrompt = nil`, `switchPromptAt = nil`, `sent = false`,
     `declinedThisRound = false`, and `roundCouldThrow = true` unconditionally (per the brief's
     explicit ambiguity resolution — no longer gated on `fateBound`/`pendingFate`).

## Files touched

- `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/src/client/main.client.luau`
