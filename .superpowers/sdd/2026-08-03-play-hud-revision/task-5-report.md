# Task 5 report — park the fate wiring in `main.client.luau`

## Summary

Removed the client's fate wiring from `roblox/src/client/main.client.luau`:

- `local FateResolvedEvt = remotes:WaitForChild("FateResolved") :: RemoteEvent`
- `local fateBound = false` plus its write-only comment block and the
  `-- selene: allow(unused_variable)` suppression Task 4 left pointing at this task
- `local pendingFate = false` and its explanatory comment block
- the `if pendingFate then … end` branch inside `maybeShowReveal`
- the whole `FateResolvedEvt.OnClientEvent:Connect(…)` handler
- the `if mine and mine.result == "LOSS" then … end` block in the `RevealTheater` handler
  (including the now-unused `local mine = r.results and r.results[myId]`), leaving the
  `whiffed` branch untouched
- a leftover `pendingFate is deliberately NOT cleared here…` comment inside the
  `RoundUpdate` handler (`drumAtRest = false` line), which referenced the just-deleted flag
- a stray `(fate-bound, phase, pick already made)` mention inside the `publish()` beat-2
  comment — not explicitly named in the brief's deletion list, but it matched the fate grep
  and described a rule (fate-gating `throwsEnabled`) that Task 4 already removed from
  `HudModel.view`, so it was corrected to `(phase, pick already made)` rather than left
  stale.

Updated the file header per Step 2: replaced the spoiler-gate bullet (dropped the "which now
holds the FATE as well" clause) and added the "FATES ARE PARKED (2026-08-03)" note. Placed
the note after the full three-item bullet list (rather than splitting the list) so the
bullets stay together and the parked-fate note reads as a standalone paragraph before "It
publishes all of that on `EventBus.HudState:Fire(...)`".

`REVEAL_SAFETY` was left untouched — it still gates the `RevealResult` handler's
dropped-drumRest fallback (`task.delay(REVEAL_SAFETY, ...)` around line 462).

No other files were touched. `FateController.client.luau`, `TheaterController.client.luau`,
`FateRegistry.luau`, `default.project.json`'s `FateResolved` remote entry, and the server
side are all untouched, per the brief's ambiguity resolutions.

## Verification greps (all match expectations)

```
$ grep -n "fate\|Fate" src/client/main.client.luau
(no output)

$ grep -n "selene: allow" src/client/main.client.luau
(no output)

$ grep -n "REVEAL_SAFETY" src/client/main.client.luau
53:local REVEAL_SAFETY = 3 -- seconds before a dropped drumRest cue is assumed lost
462:    task.delay(REVEAL_SAFETY, function()

$ grep -n "whiffed" src/client/main.client.luau
395:    if r.whiffed and r.whiffed[myId] then
```

The `whiffed` branch inside `RevealTheater.OnClientEvent` is confirmed intact and is now the
only conditional in that handler (the `LOSS` branch above it is gone).

## Gates

- `stylua --check src tests tools` — 0 errors, clean
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors
- `lune run tests/run` — 910 passed, 0 failed, 910 total (two `[WARN]` lines are an
  intentional queue-overflow/handler-error test fixture in `HandlerQueue.spec`, unrelated to
  this change)

## Commit

`roblox/src/client/main.client.luau` — diffstat: 1 file changed, 9 insertions(+), 56
deletions(-).

Commit message: `refactor(roblox): the client stops waiting for a fate that never comes`

## Concerns

None. The deletion left no dangling references; `mine` (only used by the deleted LOSS
branch) was removed along with it since `RevealTheater`'s payload's `results` field is no
longer read anywhere in this file. Roblox Studio's cloud dev backend will push this on the
next commit to `m4b-zendojo-art-pass` — this is a client-only, additive-nothing change so it
should not affect current arena behavior beyond removing the (already server-parked-in-
waiting) fate UI branch.
