# Task: shoreline stations — "a line of shuffled mixes marching along the shore"

User gate, 2026-08-01. The waterline currently reads as a *band* of plants sprinkled
across the bank, with monospecific clumps. The user wants it to read as a LINE
following the shore, punctuated by small MIXED handfuls where species co-locate:

> "your approach is also either/or, never and. An iris could be more or less
>  co-located with a fern. I like the shuffled mix, but it should be a line of
>  shuffled mixes marching along the shore."

PURE PLANNER ONLY: `roblox/tools/builders/ZoneScatter.luau` + tests appended to
`roblox/tests/ZoneScatter.spec.luau`. The Studio mirror, recipe values and the bake are
the controller's follow-up. Do NOT touch any other file.

## Two faults to fix

1. **Clumps are monospecific.** Today a clump child inherits its parent's species, so a
   clump is three reeds or three ferns — never a mixed handful.
2. **Placement is area-scatter.** Every sample within `nearWater` is a candidate, so
   plants spread across the bank with nothing following the shoreline.

## New Recipe field (exact)

```luau
shoreline: {
    stationSpacing: number,   -- min distance between stations ALONG the shore
    membersMin: number,
    membersMax: number,       -- plants per station
    spread: number,           -- max offset of a member from its station
    inland: number,           -- how far a member may be pushed AWAY from water
}?
```

When present, the recipe's zone is planted by the SHORELINE PASS instead of the ordinary
per-sample scatter (like `grove`, this excludes the zone from per-sample resolution).

## Semantics

**Finding the shore.** A sample is a SHORE SAMPLE when it is within `recipe.nearWater` of
water (reuse `waterWithin` with the existing water index — the same test `accepts`
already applies) AND passes the full `accepts` gate. Water direction for a sample is
computed by probing the water index at the four cardinal offsets at `pitch` distance and
taking the vector toward whichever are water; if none/all, treat as no bias.

**Stations.** Exhaustive selection, NOT darts (project standard): collect all shore
samples, sort deterministically by (x, z), then greedily accept a sample as a station if
it is ≥ `stationSpacing` from every already-accepted station. This walks the shoreline
and yields evenly spaced stations along it.

**Members.** Per station, member count = integer in [membersMin, membersMax] by roll.
Each member INDEPENDENTLY draws its own species via the existing `pickWadingSpecies`
(so per-species `submergeMax` / `nearWater` gates apply per member — this is what sorts
iris toward the wet end and ferns toward the dry end WITHIN one mixed handful). A member
sits at a polar offset from the station (angle roll, radius roll in [0, spread]), then is
pushed AWAY from water by `roll * inland` along the station's inland direction (the
negation of its water direction). The member must:
  - find a nearest grid sample (nil → skip this member),
  - pass `accepts` for the zone,
  - stand ≥ `recipe.spacingMin` from every same-layer placement already in `out`.
Up to 3 attempts per member slot, then the slot is abandoned.

The station itself is NOT automatically planted — it is a position on the shore, and its
members are the planting. (A station whose members all fail contributes nothing.)

**Determinism:** unchanged inputs → identical output. Integer LCG only, no `math.random`.
Use a distinct seed offset for the shoreline stream, in the style of the existing grove
offset, so adding/removing the feature does not perturb other zones' streams.

## Tests (RED first, then implement)

Append to `roblox/tests/ZoneScatter.spec.luau`, matching the file's existing style
(`steep` IS a required Sample field — omitting it throws). Cover at least:

1. **Determinism** — two identical runs produce identical output.
2. **Follows the shore** — with a straight line of water cells, every placement is within
   `nearWater` of water, and the placements' spread ALONG the shore axis is much greater
   than across it (assert the along-axis range exceeds the across-axis range).
3. **Stations are spaced** — cluster the placements; no two station centroids sit closer
   than `stationSpacing * 0.8`.
4. **Handfuls are MIXED** — with a two-species pool of equal weight and no per-species
   gates, at least one station contains more than one distinct species. (Assert across
   the whole plan: the number of stations containing ≥2 species is > 0. This is the fault
   being fixed, so it must fail against monospecific clumping.)
5. **Per-species gates still sort within a handful** — pool of `Wet` (`nearWater = 3`) and
   `Dry` (`submergeMax = 0`), over samples at varying distance/depth: every `Wet`
   placement is within 3 of water; no `Dry` placement stands in water.
6. **Member count is respected** — no station has more than `membersMax` placements.
7. **A shoreline recipe's zone does NOT also scatter per-sample** — total placements are
   bounded by `stations * membersMax`.

## Constraints

- Work from /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
- `lune run tests/run` all green (776 existing); lint `stylua --check src tools tests &&
  selene src tools` (selene FAILS on warnings; run from roblox/).
- `--!strict`; match the file's comment register — explain WHY a rule exists.
- Commit message: `feat(roblox): shoreline stations - mixed handfuls marching along the shore`
  ending with:
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Wkn8pmb3GYwsXZrSRnZYNu
