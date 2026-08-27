# Task 9 report: Recipe overhaul (foliageZoneRecipes)

## TDD evidence

1. Appended the brief's two new `describe` blocks to
   `roblox/tests/FoliageZoneRecipes.spec.luau` verbatim (KNOWN-species table
   with `FernClump = true` kept per the user's fern verdict; waterline
   ecology checks on `maxSteep`/`submergeMax`).
2. RED: `lune run tests/run` → 3 failures before touching the recipe table:
   - `WallFringe pool is real` (named `ConiferA`/`ConiferB`/`ConiferC`/`CedarM`,
     none of which are in KNOWN)
   - `margin flora refuses steep hillsides` (old `maxSteep = 0.7`)
   - `reeds wade, muhly keeps damp feet only` (old `submergeMax` was unset)
   - 703 passed / 3 failed / 706 total.
3. Rewrote `roblox/tools/studio/foliageZoneRecipes.luau` per the brief's
   deltas (see Files changed).
4. GREEN: `lune run tests/run` → 706 passed / 0 failed / 706 total. (The
   `[WARN] QUEUE ... handler error for u: boom` lines are pre-existing
   `HandlerQueue.spec` error-injection test noise, unrelated to this task.)
5. Lint: `stylua --check src tools tests && selene src tools` → 0 errors, 0
   warnings, 0 parse errors.

## Files changed

- `roblox/tools/studio/foliageZoneRecipes.luau`
  - `Recipe` type gains `footingRadius: number?`, `footingMaxDrop: number?`,
    `submergeMax: number?`, `careDensity: { [string]: number }?` — mirrors
    `ZoneScatter.luau`'s `Recipe` export exactly.
  - Added a top-of-file note ("Deciduous accents and bamboo appear in NO
    recipe pool in this file...") directly after the four-band comment
    block, which is otherwise unchanged/intact.
  - `PreserveCore` += `footingRadius = 2.5, footingMaxDrop = 4`.
  - `PreserveBrush` += `footingRadius = 1.5, footingMaxDrop = 3`,
    `careDensity = { GARDEN = 0.25, TENDED = 0.6 }`.
  - `WallFringe` pool replaced: `ConiferA/B/C/CedarM` (fictional, per-species
    `scale`) → `XfHinokiM 30, XfSpruceM 30, XfFirM 25, XfSugi40 15` (real
    Xfrog untrimmed adults, no per-species scale). Kept `heightScale = 0.5`.
    Added `footingRadius = 3, footingMaxDrop = 6`.
  - `WaterMargin` pool replaced: `MuhlyGrass 50, ReedClump 30, FernClump 20`
    → `MuhlyGrass 45, ReedClump 30, WeedStalks 15, FernClump 10` (fern
    verdict: FernClump stays, per user gate). `maxSteep` 0.7 → 0.35.
    Added `submergeMax = 1.0`, `footingRadius = 1, footingMaxDrop = 2`.
    Kept `nearWater = 8`, `layer = "ground"`.
  - `FutureClearing` untouched (no delta in the brief).
- `roblox/tests/FoliageZoneRecipes.spec.luau` — appended the brief's two
  `describe` blocks verbatim (species-reality check over every recipe pool
  via a `KNOWN` allowlist; waterline ecology checks).

All values transcribed exactly as specified in the brief — no numbers were
"improved."

## Self-review

- Diffed the committed change against the brief's deltas line-by-line: every
  number (weights, `maxSteep`, `footingRadius`/`footingMaxDrop`,
  `submergeMax`, `careDensity`) matches verbatim.
- Confirmed `Recipe` type in `foliageZoneRecipes.luau` is now a field-for-field
  mirror of `ZoneScatter.luau`'s `export type Recipe` (order differs
  slightly — `pool: { Species }` vs `pool: { { name, weight, scale? } }` —
  but this file's `Species` alias is structurally identical, and the new
  fields match name/type exactly).
- Verified `FernClump = true` line kept in the spec's `KNOWN` table per the
  binding fern verdict (pool stays at MuhlyGrass 45 / ReedClump 30 /
  WeedStalks 15 / FernClump 10 — did not take the brief's parked-fern
  reweight branch).
- Verified `git status` before staging: two unrelated pre-existing changes
  (`tools/blender/export_forest_kit.sh` modified, `tools/blender/
  bake_grass_patch.py` untracked) were NOT part of this task and were left
  out of the commit — staged and committed only the two task files.
- Re-ran full suite (706 passed) and lint (clean) post-commit to confirm the
  committed tree, not just the working tree, is green.
- No findings requiring a fix.
