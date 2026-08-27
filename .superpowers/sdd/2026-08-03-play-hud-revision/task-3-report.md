# Task 3 report — `HudLayout` — the new skeleton

## Status
DONE

## What happened

`roblox/tests/HudLayout.spec.luau` already existed on disk (the brief's premise that it did
not was stale) — it held 9 pre-revision tests. Initial pass replaced the whole file with the
brief's Step 1 content, which was wrong: only 4 of the 9 old tests (`PLATE_BOTTOM` derivation,
the two `CLUSTER_TOP_FROM_BOTTOM(_TOUCH)` derivations that summed in `SLOT_H`/`CONFIRM_*`, and
the 375px-viewport band test) actually asserted geometry this task deletes and were correctly
unsatisfiable afterward. The other 5 were either satisfiable unchanged or adaptable, and
dropping them silently lost coverage:
- `AREA_H` / `AREA_H_TOUCH` derivation (2 tests) — this task doesn't touch their formula's
  primitives (`TILE`, `ROW_GAP`, `BTN_H`/`BTN_H_TOUCH`); the new "cluster is bank + throws +
  tape" test reads `AREA_H` back from the module rather than expanding it, so it's circular
  and can't catch a bad edit to `AREA_H` itself.
- the touch-tier derivation test (`BTN_H_TOUCH`/`TILE_TOUCH` from their scale constants) —
  untouched by this task.
- the "no Roblox globals" purity guard — needed adapting (allow `typeof(value) == "function"`
  for `plateBottomOffset`), not deleting.
- the "touch throw target clears 44px" test was correctly retained in the first pass.

Fixed in a follow-up per coordinator review: restored the 3 legitimately-dropped derivation
tests verbatim and adapted the purity guard, added to the spec's second describe block. Left
out (per review) the 375px-viewport test, whose successor concern (plate/cluster clearance)
belongs to the OnboardingController task since the plate no longer occupies a top band.

Ran `lune run tests/run` before editing the module: 6 failures, all for the right reason
(`BANK_H` nil / arithmetic on nil, `CONFIRM_H`/`CONFIRM_GAP`/`PLATE_BOTTOM` still present,
`plateBottomOffset` not callable).

Edited `roblox/src/shared/HudLayout.luau`:
- Deleted `PLATE_H`, `PLATE_BOTTOM`, `CONFIRM_H`, `CONFIRM_GAP`.
- Renamed `SLOT_H`/`SLOT_GAP` → `BANK_H`/`BANK_GAP` (values unchanged: 40 / 8).
- Added `PLATE_W`, `PLATE_ROW_H`, `PLATE_JUMP_GAP` and the pure function
  `HudLayout.plateBottomOffset(guiBottomY, jumpTopY)`, verbatim from the brief.
- Rewrote `AREA_H`/`AREA_H_TOUCH` term order (BTN_H + ROW_GAP + TILE) with the "tape moved
  below the buttons" comment; value unchanged.
- Rewrote `CLUSTER_TOP_FROM_BOTTOM(_TOUCH)` to drop the slot/confirm terms and add `BANK_H`
  in their place.
- Updated the module header: replaced the "plain numbers only" closing line with "numbers,
  and pure arithmetic over them" plus the rationale for `plateBottomOffset` being the one
  function in the module.

After the edit (first pass, whole-file replacement): `lune run tests/run` → 902 passed,
0 failed (902 total). After the follow-up restoring the 4 tests: `lune run tests/run` →
**906 passed, 0 failed (906 total)**.

Confirmed no other `src`/`tests` file references the removed names outside the two excluded
client controllers (`grep -rn` for `PLATE_H|PLATE_BOTTOM|CONFIRM_H|CONFIRM_GAP|SLOT_H|SLOT_GAP`
across `src tests`, filtered out `HudController.client.luau` and
`OnboardingController.client.luau`) — only comment mentions and the new spec's
"is gone"/"is nil" assertions remain.

## Mutation checks

1. Dropped the `math.max` clamp in `plateBottomOffset` (bare
   `guiBottomY - jumpTopY + PLATE_JUMP_GAP`). Suite → **1 failed** (901 passed, 902 total):
   "a button measured below the screen edge cannot push the plate off-screen — expected -90
   to be 12". Reverted; suite back to 902/902 passing.
2. Added a 28px confirm row back into `CLUSTER_TOP_FROM_BOTTOM`. Suite → **1 failed**
   (901 passed, 902 total): "the cluster is bank + throws + tape, and nothing else — expected
   210 to be 182". Reverted; suite back to 902/902 passing.

Both mutations were caught by exactly the test written to catch them.

Mutation checks above were run against the 902-test state (before the follow-up restoration);
the restored tests are additive and don't touch `plateBottomOffset` or the cluster derivation,
so the mutation results stand unchanged at 906.

## Gates (re-run after the follow-up)

- `lune run tests/run` → 906 passed, 0 failed (final state).
- `stylua --check src tests tools` → clean, no diff.
- `selene src tools` → 0 errors, 0 warnings, 0 parse errors.

## Files touched

- `roblox/src/shared/HudLayout.luau` (modified)
- `roblox/tests/HudLayout.spec.luau` (replaced, then amended — pre-existing file held 9
  pre-revision tests; first pass dropped 5 of them, follow-up restored 4 that were
  legitimately still coverage this module needs)

## Not touched (per instructions)

- `roblox/src/shared/HudModel.luau` (Tasks 1–2)
- `roblox/src/client/HudController.client.luau`, `roblox/src/client/OnboardingController.client.luau`
  (left with stale references to `PLATE_H`/`PLATE_BOTTOM`/`CONFIRM_H`/`CONFIRM_GAP`/`SLOT_H`/
  `SLOT_GAP` — Tasks 6–10 fix them; the Lune suite does not compile `.client.luau` files, so
  this does not fail anything now)

## Commit

Committed as instructed:
`feat(roblox): the tape goes under the buttons and the confirm row goes away`
