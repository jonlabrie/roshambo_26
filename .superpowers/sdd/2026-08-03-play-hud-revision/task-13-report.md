# Task 13 report: park the fates

**Status:** complete
**Commit:** c6d4366 — "feat(roblox): park the fates at the one line that summons them"

**Gates:**
- `lune run tests/run` — 923 passed, 0 failed (921 baseline + 2 new tests). Confirmed the
  `LOSS selects to nothing` test failed first (`expected fateBoulder to be nil`) before parking
  `EffectRegistry.LOSS`, per TDD.
- `stylua --check src tests tools` — clean.
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors.

**Test count:** 923 (up from 921).

**TweenService/DrumStep require check (before → after):**
- Before: `DrumStep` required at line 59, used only inside `growDelaySeconds`; `TweenService`
  fetched at line 93, used only inside `applyGrow`.
- After: both requires deleted (no other user existed for either). Both names now appear only
  inside prose comments (the recipe note above `onReveal`, and the deleted-function reference at
  line 339) — selene doesn't flag comment text, and the check confirmed there was no live code use
  left behind.

**Extra fix beyond the brief's literal steps:** the brief assumed `EffectSelector.spec.luau`'s
`byThrow` test already used a fixture registry; it actually called `EffectSelector.new(EffectRegistry, ...)`
directly against the real registry. Parking `LOSS` there broke that test (`expected nil to be
fateBoulder`), so I converted it to a local fixture (`{ LOSS = { byThrow = {...} } }`) with a
comment explaining why — keeping the `byThrow` branch covered independent of the real registry's
parked state, matching the brief's stated intent.

**Verification greps:**
- `applyGrow|growDelaySeconds|fates:begin` in `src/` → only comment mentions (the recipe note and
  the seam note), no live code.
- `fateBoulder|fatePaper|fateShears` in `src/` → live in `DoomEscalation.luau` and
  `FateController.client.luau` (untouched machinery, as intended) plus one comment in
  `EffectRegistry.luau`; none in `main.server.luau`.
- `FateRegistry`, `FateRegistry.spec.luau`, `DoomEscalation`, `ChoreographyMachine`,
  `EffectSelector`, `TheaterController.client.luau`, `FateController.client.luau` all present and
  compiling (full suite green).

**Concerns:** none. The park is exactly the one-line `EffectRegistry.LOSS = {}` plus the server's
`fates:begin`/`applyGrow`/`growDelaySeconds` removal; `FateController.client.luau` needed no edit,
as predicted.
