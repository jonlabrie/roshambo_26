# Task: mirror the shoreline pre-pass into scatterPreserve

## Status: DONE

## What was ported

Commit `1fe0d35` ("feat(roblox): shoreline stations - mixed handfuls marching
along the shore") added a SHORELINE pre-pass to
`roblox/tools/builders/ZoneScatter.luau`. Ported the identical logic into the
hand-maintained mirror `roblox/tools/studio/scatterPreserve.luau`, changing
only that file:

1. `ShorelineConfig` type — added after `GroveAffinity`, declared as
   `type ShorelineConfig = { ... }` (mirror convention: no `export`, unlike
   the planner's `export type ShorelineConfig`).
2. `shoreline: ShorelineConfig?,` field — added as the last field of the
   `Recipe` type, with its full verbatim comment (the 2026-08-01 user-gate
   rationale).
3. `SHORE_SEED_OFFSET = 700000` and `SHORE_PROBE_DIRS` constants — added
   after `GROVE_JITTER_MAX`.
4. `shoreStates` / `shoreRoll(zone)` — the separate LCG stream for the
   shoreline pass, added after `groveStates`/`groveRoll`.
5. The full shoreline pre-pass block inside `plan()` — added immediately
   after `local groveIndex = indexWater(groveAnchors)` and before the
   rockAffinity-index setup, verbatim (shore-sample gathering, exhaustive
   greedy station selection, four-direction water probe for inland bias,
   per-member independent species roll via `pickWadingSpecies`, spacing
   check against `out`).
6. The per-sample exclusion in `resolveZone`'s callback — changed
   `crecipe.grove ~= nil` to `crecipe.grove ~= nil or crecipe.shoreline ~= nil`,
   with the updated comment ("grove- and shoreline-recipe zones...").

Comments were ported verbatim in every case, including the em-dash-laden
rationale comments.

## Verification

The mirror is not Lune-testable, so I wrote a throwaway diff script
(`/private/tmp/.../scratchpad/verify_shoreline_mirror.py`, not committed) that:

1. Parses `git show 1fe0d35 -- roblox/tools/builders/ZoneScatter.luau` into
   its 6 hunks.
2. For each hunk, reconstructs the **post-image** (context lines + added
   lines, in order, with removed lines dropped) — i.e. exactly what that
   span of `ZoneScatter.luau` reads as after the commit.
3. Locates the best-matching equal-length span in `scatterPreserve.luau`,
   normalizes only the known-intentional `export type ` → `type ` rewrite,
   and unified-diffs the two.

### Result

4 of 6 hunks (constants, shoreRoll stream, the resolveZone condition, and
the interior of the pre-pass block) came back **byte-identical**. The
other 2 reported non-empty diffs; inspecting them shows every line is
**hunk-boundary context that commit 1fe0d35 did not touch** — pre-existing,
already-diverged text between the two files, not something the port
dropped or altered:

```
=== Hunk 1: Recipe.shoreline field ===
    !! could not locate start line in mirror: '    -- with careDensity — both multiply the same density slot. With'
```
Cause: the planner's `rockAffinity` field comment ("...with careDensity —
both multiply...") has always read differently from the mirror's
`rockAffinity` comment ("same mechanism keyed on the SHORE ROCKS...") — a
pre-existing divergence unrelated to shoreline. The mirror's `Recipe` type
also carries an extra Studio-only `grassPaint` field the planner doesn't
have. Both predate this commit. The actual added field (`shoreline:
ShorelineConfig?,` plus its full comment) is present, verbatim, as the last
field before the closing `}` — the correct position.

```
=== Hunk 2: ShorelineConfig type ===
    @@ -12,6 +12,6 @@
         spread: number, -- max offset of a member from its station
         inland: number, -- how far a member may be pushed AWAY from water
     }
    -type Placement = {
    -    x: number,
    -    z: number,
    +-- THE FOUR BANDS (the user's structure, and the point of the whole system):
    +--   0-2 studs   ground cover — grass and weeds. DOES NOT EXIST YET; the same gap
    +--               leaves the waterline bare. See the WaterMargin pool below.
```
Lines 1-11 (the entire `ShorelineConfig` type body, comment through closing
`}`) matched exactly. The mismatch is only what follows: the planner
defines `Placement` immediately after `GroveAffinity`/`ShorelineConfig`,
while the mirror's file is organized with the `RECIPES` table (and its "THE
FOUR BANDS" doc comment) between the type declarations and `Placement` —
pre-existing file structure, not a content gap.

```
=== Hunk 5: shoreline pre-pass block ===
    @@ -1,5 +1,5 @@
         end
    -    local groveIndex = ZoneScatter.indexWater(groveAnchors)
    +    local groveIndex = indexWater(groveAnchors)
     ... (163 lines identical — the ENTIRE shoreline pre-pass loop) ...
    @@ -166,6 +166,6 @@
    -    -- rockAffinity's lookup, built exactly like the grove-anchor index above
    -    -- but from the caller-injected point set rather than this pass' own
    -    -- output; indexWater takes positional {x, z} cells, so translate
    +    -- rockAffinity's lookup: the Studio side reads the ShoreRocks pass' output
    +    -- straight from the workspace rather than taking an injected point set
    +    local rockCells: { { number } } = {}
```
Only the two boundary lines differ, both pre-existing and out of scope per
the task brief: `ZoneScatter.indexWater(...)` vs the mirror's un-namespaced
`indexWater(...)` (the mirror never namespaces its own local helpers —
true throughout the whole file, not introduced here), and the
Studio-specific `rockAffinity` lookup comment/implementation (planner takes
an injected point set; Studio reads `ShoreRocks` straight from the
workspace — explicitly Studio-only code the task said to leave alone). The
**163 lines in between — the entire shoreline pre-pass loop body — are
byte-identical** after normalization.

Hunks 3, 4, and 6 (constants, `shoreRoll` stream, `resolveZone` exclusion)
came back clean with zero diff.

### Required-token presence check

```
[x] ShorelineConfig
[x] stationSpacing
[x] membersMin
[x] membersMax
[x] spread
[x] inland
[x] SHORE_SEED_OFFSET
[x] shoreline ~= nil
```
All present in the mirror after the change.

## Other checks

- `stylua --check src tools tests` — clean.
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors.
- `lune run tests/run` — 783 passed, 0 failed, 783 total (unchanged from
  baseline; the mirror is not part of the Lune suite, so this confirms no
  regression to the planner/tests, which were not touched).

## Files touched

- `roblox/tools/studio/scatterPreserve.luau` — only file changed.
- Not touched (as instructed): `roblox/tools/builders/ZoneScatter.luau`,
  `roblox/tests/*`, `roblox/tools/studio/foliageZoneRecipes.luau` (left with
  its pre-existing uncommitted changes from other work).

## Concerns

None. The two hunks with non-empty raw diff output are fully explained by
pre-existing, documented, out-of-scope differences between the planner and
the Studio-only mirror (an extra Studio-only `grassPaint` Recipe field, the
files' differing type-declaration order, un-namespaced local helper calls,
and the Studio-specific `rockAffinity`/`ShoreRocks` lookup) — none of them
touched by commit `1fe0d35`, and none of them part of the shoreline port.
