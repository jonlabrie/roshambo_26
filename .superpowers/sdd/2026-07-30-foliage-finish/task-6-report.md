# Task 6: Submersion affinity (ZoneScatter) — Report

## Summary

Added `Sample.depth: number?` and `Recipe.submergeMax: number?` to
`roblox/tools/builders/ZoneScatter.luau`. The `accepts` gate in `plan()` now
rejects any sample with `depth > 0` unless the recipe sets `submergeMax` and
the depth is within it — placed immediately after the footing gate, before
`innerClear`, per the brief. Nothing else changed; the clump-child probe
(which does not carry `depth`) is intentionally untouched — that's Task 7's
job per the brief's explicit note.

## TDD Evidence

### RED

Appended the brief's `describe("ZoneScatter submersion", ...)` block (3 tests)
to `roblox/tests/ZoneScatter.spec.luau`, using the existing top-of-file
`CORE` recipe. Ran `lune run tests/run`:

```
FAIL  ZoneScatter submersion > a dry recipe never plants in water
      .../ZoneScatter.spec:520: expected false to be true
FAIL  ZoneScatter submersion > too deep is still too deep
      .../ZoneScatter.spec:542: expected false to be true
688 passed, 2 failed, 690 total
```

Matches the brief's predicted failure mode exactly: depth was ignored, so
the dry-recipe test failed (planted in water) and the too-deep test failed
too; the wet-footed test happened to pass already since dry planting fills
both x<=48 and x>=52 columns.

### GREEN

Implemented exactly the brief's Step 3 diff (`Sample.depth`, `Recipe.submergeMax`,
and the gate in `accepts` right after the footing-drop check). Re-ran:

```
690 passed, 0 failed, 690 total
```

(The pre-existing `[WARN] QUEUE ...` lines are unrelated noise from an
unrelated HandlerQueue test that intentionally throws — present before this
change too.)

### Lint

```
stylua --check src tools tests   -> clean
selene src tools                  -> 0 errors, 0 warnings, 0 parse errors
```

## Files Changed

- `roblox/tools/builders/ZoneScatter.luau` — `Sample.depth: number?`,
  `Recipe.submergeMax: number?`, submersion gate in `accepts` (after footing,
  before innerClear).
- `roblox/tests/ZoneScatter.spec.luau` — appended `describe("ZoneScatter
  submersion", ...)` with the brief's 3 tests verbatim (shore samples helper,
  dry-recipe-never-wet, wet-footed-wades-in, too-deep-still-too-deep).

## Self-Review

- Diff matches the brief's Step 3 code verbatim; gate ordering (steep →
  footing → submersion → innerClear → water/nearWater/pathMargin) matches
  "AFTER the footing gate" instruction.
- Confirmed I did not touch the clump-child probe (`local probe: Sample = {
  x = cx, z = cz, y = cy, steep = ... }` near line ~418) — it still omits
  `depth`, which is correct per the brief: Task 7 extends that probe, not
  this task. A clump child spawned into water today falls through to the
  submersion gate with `depth = nil -> 0`, i.e. treated as dry — acceptable
  scope boundary per the brief.
- `--!strict` preserved; no new Roblox API usage (still pure/Lune-testable).
- Full suite: 690/690 passing, up from 687 baseline (+3 new tests). No
  existing test's expectations were touched.
- Lint clean at CI scope (stylua + selene over `src tools tests` / `src
  tools`).
- Commit `d8b885c` — single commit, conventional subject line, correct
  Co-Authored-By trailer, only the two intended files changed.
