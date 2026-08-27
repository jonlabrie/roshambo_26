# Task 1 report: `HudModel` — the choose/switch state machine

## Status: DONE

## What changed

`roblox/src/shared/HudModel.luau`:
- Added four fields to `Inputs`: `chosen`, `switchPrompt`, `sent`, `declinedThisRound`. Old
  fields (`fateBound`, `pickedThisRound`, `confirmThrows`, `selectedThrow`) left untouched —
  `autoCommit` and `view`'s `selected` field still read `selectedThrow`.
- Added `HudModel.SWITCH_PROMPT_SECONDS = 4`.
- Replaced `throwsEnabledFor` with the simpler ACTIVE + secondsLeft>0 gate (no more
  `fateBound`/`pickedThisRound`/`confirmRequired` branching — the round now stays open to taps
  for the whole of ACTIVE).
- Deleted `HudModel.confirmRequired` entirely (per ambiguity resolution #4). Verified with a
  repo-wide grep (`grep -rn "confirmRequired" --include="*.luau" .`) that no code anywhere calls
  it any more — the only remaining hit is a stale comment reference inside `autoCommit`'s doc
  comment, which is prose, not a call, and out of this task's scope to edit.
- Rewrote `HudModel.tapAction` to the five-row table: `ignore` (closed round) / `choose`
  (nothing chosen yet) / `ignore` (tap on the chosen glyph) / `clear` (tap on the prompted
  glyph) / `prompt` (any other glyph).
- Rewrote `TapState` to `{ chosen: string?, switchPrompt: string? }` and `HudModel.applyTap` to
  match: `choose` sets chosen + drops prompt, `prompt` sets/moves the prompt without touching
  chosen, `clear` empties both (the back-out), anything else is a no-op passthrough.
- Added `HudModel.switchPromptExpired(setAt, now)`.
- Unhooked `view` from the deleted `confirmRequired`: removed `confirmPending` and `releasable`
  from the `View` type and the `view` return table, and removed the `throwsEnabled` gate on
  `selected` — it now reads `selected = inputs.selectedThrow` unconditionally, matching the
  ownership rule that `autoCommit` already codified (a selection outlives the round moving on).
- `HudModel.autoCommit` left completely untouched, as instructed (Task 2 removes it).

`roblox/tests/HudModel.spec.luau`:
- Extended the `inputs` helper's base table with `chosen = nil, switchPrompt = nil, sent =
  false, declinedThisRound = false`, leaving the old base fields in place.
- Replaced the four old describe blocks (`HudModel.tapAction — one tap, or two`,
  `HudModel.tapAction — releasing a confirmed throw`, `HudModel.applyTap — the transition
  table`, `HudModel — the full transition table`) — plus their two old header comment blocks
  that only made sense attached to the deleted tests — with the five new describe blocks from
  the brief, verbatim: `HudModel.tapAction — the five-row table`, `HudModel.applyTap — the
  transition table`, `HudModel — the invariant, over every reachable sequence`,
  `HudModel.switchPromptExpired`.
- In `HudModel.view — plate and throws`: deleted `throws are disabled once a pick is in` and `a
  fate still blocks throwing` (both assertions this task's `throwsEnabledFor` deliberately
  reverses), replacing them with the single new test `the round stays open to taps for the
  whole of ACTIVE`.
- Deleted the whole `HudModel.view — the confirm affordance` describe block and the whole
  `HudModel — pickedThisRound after a release` describe block (both asserted `confirmPending`/
  `releasable`, which no longer exist).

## Verification

- `lune run tests/run` before implementing: **FAIL, 12 failed / 892 passed / 904 total** — all
  12 failures were exactly the expected reason: `tapAction` still returning the old
  `commit`/`select` verbs against the new five-row-table assertions, `applyTap` still keyed on
  `selectedThrow`/`myPick` so the new `chosen`/`switchPrompt` fields came back `nil`, and
  `HudModel.switchPromptExpired` not existing yet (`attempt to call a nil value`). (Two of the
  new "invariant" tests passed even before the implementation — vacuously, since the old
  `applyTap` never populates `switchPrompt`, which the brief's Step 2 expectation already
  anticipated by only calling out the tapAction/switchPromptExpired failures.)
- After implementing: `lune run tests/run` → **904 passed, 0 failed, 904 total**.
- `stylua --check src tests tools` → clean (exit 0).
- `selene src tools` → 0 errors, 0 warnings, 0 parse errors.
- Repo-wide grep confirms no caller of `HudModel.confirmRequired` remains (only a stale prose
  mention inside a doc comment on `autoCommit`).

### Mutation check

Temporarily changed the `"clear"` branch of `applyTap` to `return { chosen = state.chosen,
switchPrompt = nil }` (a back-out that leaves the glyph chosen). Re-ran `lune run tests/run`:

**902 passed, 2 failed, 904 total.**

Failures:
- `HudModel.applyTap — the transition table > CLEAR EMPTIES BOTH — this is the back-out`
- `HudModel — the invariant, over every reachable sequence > a back-out is always reachable in
  two taps from any choice`

Reverted the mutation; suite is back to 904 passed / 0 failed. Both gates (`stylua --check`,
`selene`) re-verified clean after the revert.

## Scope note (not a concern, just a fact for the coordinator)

`roblox/src/client/HudController.client.luau` (a Roblox-runtime file, not `shared`, not run
under Lune) still references `view.confirmPending` / `view.releasable`, which no longer exist
on `View`. This task's brief scoped changes to `HudModel.luau` and its spec only — the
controller isn't in the Files list, isn't covered by any Lune spec, and both `stylua`/`selene`
gates pass regardless (neither does Luau strict-mode type checking). This is presumably fixed
by a later task in the 14-task plan that rewires the controller to the new
choose/prompt/clear/switchPromptExpired API.

## Commit

`feat(roblox): one tap chooses, and a switch has to be confirmed`
