# Task 10 Report: Sync the Studio mirror (scatterPreserve)

## Summary

`roblox/tools/studio/scatterPreserve.luau` is a Studio-only script (Studio
cannot `require` from disk) that mirrors `tools/builders/ZoneScatter.luau`'s
planner and `tools/studio/foliageZoneRecipes.luau`'s recipe table inline.
Tasks 5-9 changed both sources; this task re-synced the mirror and added the
Studio-side machinery (terrain submersion sampling, a `CanyonKeepOuts`
mirror, and a `CareModel`-backed care-distance index) that the brief
specified with code sketches.

## Files changed

- `roblox/tools/studio/scatterPreserve.luau` (only file touched, per the
  binding constraint) — 285 insertions, 27 deletions.

## What changed, section by section

**Header.** Extended the sync-warning comment to name all four mirrored
sources (ZoneScatter, foliageZoneRecipes, CanyonKeepOuts, CareModel) instead
of just the original two.

**RECIPES table + `Recipe`/`Species` types.** Replaced verbatim with Task 9's
result: `Recipe` type gains `footingRadius`/`footingMaxDrop`/`submergeMax`/
`careDensity`; `WallFringe`'s pool switched from the fictional
`ConiferA/B/C/CedarM` toolbox names to the real Xfrog untrimmed adults
(`XfHinokiM/XfSpruceM/XfFirM/XfSugi40`) plus `footingRadius = 3,
footingMaxDrop = 6`; `PreserveCore` gained `footingRadius = 2.5,
footingMaxDrop = 4`; `PreserveBrush` gained `footingRadius = 1.5,
footingMaxDrop = 3, careDensity = { GARDEN = 0.25, TENDED = 0.6 }`;
`WaterMargin`'s pool became `MuhlyGrass 45 / ReedClump 30 / WeedStalks 15 /
FernClump 10`, `maxSteep` 0.7 → 0.35, added `submergeMax = 1.0,
footingRadius = 1, footingMaxDrop = 2`. Added the "deciduous accents and
bamboo appear in no pool" comment.

**Planner (`Sample`/`Zone`/`Placement` types + functions).** `Sample` gained
`depth: number?, material: string?`. Added `SampleIndex`/`PlanOptions` types
and `sampleKey`/`indexSamples`/`footingDrop` functions (new in Task 5/6).
`plan()` gained an `opts: PlanOptions?` sixth parameter, builds a
`sampleIndex` via `indexSamples`, and its `accepts()` closure now gates in
the order: `keepOut` → `steep` → `footing` (via `footingDrop`) →
`submersion` (`s.depth`/`recipe.submergeMax`) → `innerClear` → `waterMargin`
→ `nearWater` → `pathMargin`. The density-thinning block now multiplies
`zone.densityScale` by `recipe.careDensity[o.careBand(s.x, s.z)]` when both
are present (Task 8). The clump-child `probe: Sample` now carries
`depth = cs and cs.depth or nil, material = cs and cs.material or nil`.

**`sampleTerrain`.** Rewritten per the brief's code sketch: two
`RaycastParams` (`rpGround` with `IgnoreWater = true`, `rpWater` with
`IgnoreWater = false`) per sample. A ground hit is now always kept — a
shallow-water cell becomes a `Sample` with `depth = surface.Position.Y -
ground.Position.Y` and `material = ground.Material.Name` instead of being
dropped outright (the old `if hit and hit.Material ~= Enum.Material.Water`
skip is gone).

**New: keep-outs mirror.** `KEEPOUT_MATERIALS = { "Sand" }` and
`KEEPOUT_ZONES` (the `Karesansui` box, values `x0=-25, x1=38, z0=-16, z1=22`)
mirror `CanyonKeepOuts.MATERIALS`/`.ZONES` verbatim (comments trimmed, same
convention `buildMossTransitions.luau` already uses for the same mirror).
`keepOutBlocks(x, z, materialName)` combines `materialBlocked` + `zoneAt`'s
logic into one boolean, passed as `PlanOptions.keepOut`.

**New: care model mirror.** `careReach(x)` and `careModelBand(x,
distToCare)` mirror `CareModel.reach`/`.band` verbatim (`GARDEN_FRACTION =
0.35`, `clamp(8 + 20*(x+430)/470, 8, 28)`).

**New: care-distance index.** `fallsDockCells()` reads
`RoshamboStage.FallsDock`'s bounding box (`:GetBoundingBox()`) and appends a
ring of points (`math.clamp(6 + floor(radius), 6, 10)` = 10 points, same
point-count formula `buildMossTransitions.perimeterSeeds` uses) at
`FALLS_DOCK_GARDEN_RADIUS = 15` studs around its center — the 15-stud garden
override documented in `placeFallsPoolIris.luau`'s siting notes, implemented
as more "care cells" (same bucketed index as built geometry) rather than a
special-cased branch. `nearestCareDist(index, x, z)` is the brief's
expanding-ring-over-buckets sketch, unchanged. The runner builds `careCells
= readBuiltCells() ++ fallsDockCells()`, indexes it with the existing
`indexWater` (reusing the `WATER_BUCKET` bucketing, per the brief), and
wires `careBand = function(x, z) return careModelBand(x,
nearestCareDist(careIndex, x, z)) end` into `plan()`'s `opts`, alongside
`keepOut = keepOutBlocks` and `pitch = SAMPLE_PITCH`.

## Mirror-fidelity self-check evidence

Ran a script-diff (Python `difflib`) of each mirrored block against its
source, function by function:

- **RECIPES table body**: byte-identical to `foliageZoneRecipes.luau`'s
  `Recipes` table (modulo the table's own name).
- **`Species`/`Recipe` type block**: byte-identical to
  `foliageZoneRecipes.luau`'s `export type` block.
- **Planner pure functions** (`lcg`, `seedState`, `containsXZ`, `contains`,
  `resolveZone`, `inInnerClear`, `pickSpecies`, `nearestSample`, `nearestY`,
  `indexWater`, `waterWithin`, `sampleKey`, `indexSamples`, `footingDrop`,
  `zoneBBox`): identical logic. Three pre-existing (not introduced by this
  task) cosmetic deviations from `ZoneScatter.luau` were confirmed present
  in the file *before* this change: `pickSpecies`'s param name (`r` vs
  `roll`) and its typed-alias signature (`{ Species }` vs the inline
  anonymous table type), `nearestY`'s combined-vs-split local declarations,
  and a paraphrased (not verbatim) comment on `resolveZone`. All are
  behaviorally identical; left as-is per the minimal-diff principle — they
  predate Task 10 and are not part of the deltas this task mirrors.
- **`accepts()` closure**: identical to `ZoneScatter.plan`'s `accepts`
  apart from the required de-namespacing (`ZoneScatter.footingDrop` →
  `footingDrop`, since the Studio script has no module table).
- **Clump-child block**: byte-identical (including the `probe: Sample`
  depth/material carry-through).
- **Density-thinning block**: byte-identical.
- **`plan()` signature**: byte-identical (modulo `function ZoneScatter.plan`
  → `local function plan`).
- **`sampleTerrain`**: matches the brief's code sketch line for line.
- **Keep-out mirror**: `KEEPOUT_MATERIALS` value (`"Sand"`) and
  `KEEPOUT_ZONES` values (name/x0/x1/z0/z1/why) match
  `CanyonKeepOuts.MATERIALS`/`.ZONES` exactly; `keepOutBlocks`'s logic
  matches `materialBlocked` + `zoneAt` combined.
- **Care model mirror**: `careReach`/`careModelBand` are line-for-line
  identical to `CareModel.reach`/`.band` (only the local-vs-module-table
  call syntax differs); `CARE_GARDEN_FRACTION = 0.35` matches
  `CareModel.GARDEN_FRACTION`.
- **`nearestCareDist`**: byte-identical to the brief's code sketch.

## Lint / test output

```
$ stylua --check src tools tests
(clean, exit 0)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run
706 passed, 0 failed, 706 total
```
(The `706` total is unchanged from Task 9's baseline — this file has no Lune
test suite of its own, being a Studio-only script; the two `[WARN] [QUEUE]`
lines are pre-existing `HandlerQueue.spec` fault-injection noise, unrelated.)

## Not run (documented limitation)

Step 7 of the brief ("smoke it via MCP `execute_luau`") requires a live
Studio session with `Workspace.Sandbox.FoliageZones` populated — not
available in this environment. Verification is lint + the line-by-line
self-diff above. `MODE="plan"` should print per-zone counts including
`water=` and `built=` counts and zero `WaterMargin` placements until the
zone is restored (Task 11), per the brief's expectation.

## Design note: the FallsDock 15-stud garden radius

`cullWaterMargin.luau` (a different, earlier ad hoc tool) implements the
same "FallsDock gets a garden override" idea as a hard branch that returns
`"GARDEN"` outright within a radius, bypassing the reach formula entirely.
This task instead followed the brief's literal instruction — append
perimeter points to the same bucketed "care cells" index used for built
geometry, then run everything through the ordinary `CareModel.band`
formula. Near FallsDock's longitude (`x ≈ -345`), `careReach(x) ≈ 11.6`, so
the *emergent* GARDEN band right at the ring is a few studs wide, widening
via TENDED out past the ring — not a literal uniform 15-stud GARDEN disk.
This is a deliberate reading of an ambiguous brief clause (the "15-stud
garden radius" language is copied from a comment in `placeFallsPoolIris.luau`
describing a *different* tool's hard-override design, not a spec for this
task's mechanism) — flagging it in case the intent was actually a hard
override matching `cullWaterMargin`'s.

## Commits

`cdda860` — `feat(roblox): scatterPreserve mirrors the ecology predicates`

## Fix report (code review: FallsDock override was Critical)

Code review confirmed the mirror-fidelity self-diff but adjudicated the
"design note" flagged above as a genuine Critical defect against the binding
spec text: `docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md:51-53`
reads, verbatim, **"Staged sites override longitude. Each carries its own
garden radius irrespective of where it sits, measured from its footprint:
the falls-pool dock gets 15 studs."** That is a hard override, not an input
to the ordinary `reach(x)` formula.

**The bug.** `fallsDockCells()` dropped 10 points on a radius-15 *ring*
around the dock's bbox center into the generic care-cell index, then ran
the result through the ordinary `careModelBand(x, nearestCareDist(...))`.
Numerically, at the dock's longitude (`x ≈ -345.4`), `careReach(x) ≈ 11.6`,
so `GARDEN` requires `distToCare ≤ 4.1` and `TENDED` requires `≤ 11.6`. The
dock's own center sits exactly `15` studs from every point on that ring —
`careModelBand(-345, 15)` returns `"PRESERVE"`. The dock's interior read as
untended wild ground and only a thin annulus near the ring itself (where
distance-to-ring happened to fall under ~11.6) read `GARDEN`/`TENDED` — the
inverse of "the dock gets 15 studs of garden."

**The fix.**
- Replaced `fallsDockCells()` with `fallsDockFootprint()`, which reads
  `RoshamboStage.FallsDock`'s `:GetBoundingBox()` (unchanged data source)
  and returns its extent as an axis-aligned XZ box `{x0, z0, x1, z1}` (or
  `nil` if the model isn't present yet) — footprint, not pivot, per the
  spec's explicit "measured from its footprint" clause.
- Added `distToFootprint(box, x, z)`: nearest-point-on-box distance (0 when
  `(x,z)` is inside the box), the standard clamped-axis formula.
- `careBand(x, z)` now checks the override **first**: `if dockFootprint ~=
  nil and distToFootprint(dockFootprint, x, z) <= FALLS_DOCK_GARDEN_RADIUS
  then return "GARDEN" end`, and only falls through to
  `careModelBand(x, nearestCareDist(careIndex, x, z))` when the override
  doesn't apply — matching the required order ("FIRST check... if ≤15 →
  GARDEN immediately; otherwise fall through").
- Removed the ring points from the generic care index entirely — `careIndex
  = indexWater(builtCells)` is now built-geometry-only (paths/structures),
  so the dock no longer wrongly extends `TENDED` beyond its own 15-stud
  override radius via the ordinary formula.
- Kept a comment citing the spec clause and file:line
  (`docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md:51-53`)
  directly above `FALLS_DOCK_GARDEN_RADIUS`, and noted why the override
  can't be folded into the generic index (the same reach(x)≈11.6 math that
  caused the bug).
- This now matches the pattern already established in
  `roblox/tools/studio/cullWaterMargin.luau:44` (`{ name = "FallsDock", x =
  -345.4, z = -15.4, garden = 15 }` checked before the reach-based path),
  modulo using a real bbox-footprint distance instead of a hardcoded
  center point + radius.

**Verification of the fix** (hand-computed, since there's no live Studio to
run this against): with a stand-in 2x2-stud footprint centered at
`(-345.4, -15.4)` — dock center: `distToFootprint = 0`, override applies,
band = `GARDEN`. A point exactly 15 studs out from the footprint edge:
`distToFootprint = 15.0`, override still applies (`<=`), `GARDEN`. A point
15.1 studs out: `distToFootprint = 15.1`, override does not apply, falls
through to `careModelBand(x, 15.1)` = `PRESERVE` (correctly bounded to the
override radius, not leaking `TENDED` beyond it as the old ring did).

**Covering verification:**

```
$ stylua --check src tools tests
(clean, exit 0)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run
706 passed, 0 failed, 706 total
```

(Same 706/0/706 baseline as before the fix — this file carries no Lune test
suite of its own; the `[WARN] [QUEUE]` lines are the same pre-existing
`HandlerQueue.spec` fault-injection noise.)

## Fix commit

`664d61d` — `fix(roblox): FallsDock garden radius is a hard override, not a care-index ring`
