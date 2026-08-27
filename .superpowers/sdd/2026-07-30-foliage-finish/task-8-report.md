# Task 8 Report: CareModel + care-banded density

## Summary

New pure module `CareModel.luau` implements the canyon-garden spec's care
gradient: `reach(x)` (a clamped linear ramp of tending distance in studs from
8 at the west end to 28 at the square) and `band(x, distToCare)` (GARDEN /
TENDED / PRESERVE, GARDEN being the inner 35% of reach). `ZoneScatter.plan`
now scales a zone's `densityScale` by a per-band multiplier when both
`PlanOptions.careBand` and the recipe's new `careDensity` table are present,
so care-aware recipes (e.g. clearing wild growth in a GARDEN band) can opt in
without touching any existing caller.

## Files changed

- `roblox/tools/builders/CareModel.luau` (new)
  - `CareModel.GARDEN_FRACTION = 0.35`
  - `CareModel.reach(x)` = `clamp(8 + 20 * (x + 430) / 470, 8, 28)`, verbatim
    from the garden-floor spec.
  - `CareModel.band(x, distToCare)` — GARDEN within `0.35 * reach(x)`, TENDED
    within `reach(x)`, else PRESERVE.
- `roblox/tools/builders/ZoneScatter.luau`
  - `Recipe` type: added `careDensity: { [string]: number }?`.
  - Density-thinning block in the main placement loop replaced: computes a
    local `density` starting at `zone.densityScale`, multiplied by
    `recipe.careDensity[o.careBand(s.x, s.z)]` only when both `o.careBand` and
    `recipe.careDensity` are non-nil and the band has an entry in the table;
    `roll(zone) >= density` gates as before. No change to the clump-child
    path (clump children are not separately density-gated — unchanged from
    prior behavior).
- `roblox/tests/CareModel.spec.luau` (new) — the two `describe` blocks from
  the brief verbatim (reach anchor values; GARDEN/TENDED/PRESERVE boundary).
- `roblox/tests/ZoneScatter.spec.luau` — appended
  `describe("ZoneScatter care-banded density", ...)`: a recipe with
  `careDensity = { GARDEN = 0 }` plus a `careBand` callback that returns
  GARDEN for `x < 50` and PRESERVE otherwise; asserts placements exist and
  all lie at `x >= 50`.

## TDD evidence

**RED** (`lune run tests/run`, before implementation — `CareModel.luau` did
not exist yet):
```
error requiring module "../tools/builders/CareModel": could not resolve child component "CareModel"
[Stack Begin]
    Script '/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tests/CareModel.spec', Line 3
[Stack End]
```
(Hard require failure, not a soft assertion failure — confirms the test file
depends on code that doesn't exist yet. The `ZoneScatter.spec.luau` addition
was written but not run standalone in this state since the suite aborts on
the require error; its would-be-failing behavior — `careDensity` field
unused, all placements pass through undimmed regardless of band — was
reasoned from the pre-change `ZoneScatter.luau` source rather than executed,
per the brief's Step 1/Step 2 sequencing.)

**GREEN** (after implementing `CareModel.luau` and wiring `ZoneScatter.luau`):
```
695 passed, 0 failed, 695 total
```
(692 pre-existing + 3 new: 2 `CareModel` tests + 1 `ZoneScatter` care-banded
density test. The `[WARN] [QUEUE] ...` lines around the pass count are
pre-existing noise from an unrelated `HandlerQueue.spec` fault-injection
test, not a failure.)

**Lint:**
```
stylua --check src tools tests   -> clean
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

## Commit

`4b7e225` — `feat(roblox): CareModel - the care gradient as a pure, testable reach`

## Self-review

- Verified the reach formula's anchor values by hand: `reach(-345) = 8 + 20 *
  85 / 470 ≈ 11.617`, matching the spec's ~11.6 and the test's 0.05 tolerance.
- Verified the care multiplier is additive-only: `o.careBand == nil` (the
  default for every pre-existing caller/test) or `recipe.careDensity == nil`
  (every pre-existing recipe) leaves `density == zone.densityScale`,
  byte-identical to the prior `if roll(zone) >= zone.densityScale` gate — all
  692 pre-existing tests passed unmodified, confirming no regression.
- Verified the new ZoneScatter test's logic: with `densityScale = 1` and a
  GARDEN multiplier of 0, `density` becomes `0` for `x < 50` so
  `roll(zone) >= 0` is always true (roll returns `[0, 1)`) and every such
  sample is skipped; PRESERVE samples (`x >= 50`) get no table entry (`mul ==
  nil`), so `density` stays `1` and placements proceed normally — matching
  the brief's "placements survive only where the band is PRESERVE" framing
  for this particular (deliberately inverted) multiplier choice.
- Checked `recipe.careDensity[band]` for a missing key: returns `nil` in
  Luau, so `mul ~= nil` correctly no-ops rather than crashing or zeroing.
- Checked no other production caller (`tools/studio/foliageZoneRecipes.luau`,
  `tools/studio/scatterPreserve.luau`) passes `careBand` yet — wiring an
  actual `CareModel`-backed callback into the Studio scatter run is out of
  this task's declared scope (Task 8 is the pure module + planner plumbing
  only).
- Confirmed `--!strict` holds in both new/modified files (selene and stylua
  both clean at CI scope).

No follow-up concerns identified.
