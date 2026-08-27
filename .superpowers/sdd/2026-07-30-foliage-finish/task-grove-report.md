# Task: Grove-structured scatter — report

## Files changed
- `roblox/tools/builders/ZoneScatter.luau` — grove pre-pass, `GroveConfig`/`GroveAffinity`
  types, `Recipe.grove`/`Recipe.groveAffinity`, per-sample-pass changes.
- `roblox/tests/ZoneScatter.spec.luau` — appended `describe("ZoneScatter grove pre-pass", ...)`
  with 8 tests + a shared `clusterPlacements` single-linkage helper.

No other files touched.

## TDD evidence

### RED (tests written first, against unmodified ZoneScatter.luau)

```
FAIL  ZoneScatter grove pre-pass > clustering: groves form <= maxGroves clusters, each within [1, membersMax]
FAIL  ZoneScatter grove pre-pass > meadows: with spacing 50, cluster centroids stay spacing*0.8 apart
FAIL  ZoneScatter grove pre-pass > species coherence: each cluster has <= 2 distinct species
FAIL  ZoneScatter grove pre-pass > elder: cluster max scale reflects dominantScale and beats the median
FAIL  ZoneScatter grove pre-pass > groveAffinity plants understory only near grove placements
FAIL  ZoneScatter grove pre-pass > a grove-recipe zone does not plant via the per-sample path
726 passed, 6 failed, 732 total
```

Two of the eight new tests ("deterministic" and "keepOut gate") passed vacuously pre-implementation:
with no `grove` handling, the grove-flavoured recipe just ran through the ordinary per-sample path
(CORE-derived `spacingMin`/`spacingMax` etc. are all present), which already produces deterministic,
keepOut-respecting output — so those two weren't meaningful RED signals, but they are meaningful
GREEN signals post-implementation (they now exercise the actual grove pre-pass output, not
per-sample fallback, confirmed via the "does not plant via the per-sample path" test).

### GREEN (after implementation)

```
732 passed, 0 failed, 732 total
```

Full existing suite (724 tests) stayed green throughout — no existing recipe sets `grove`, so the
per-sample-loop's new "skip grove-recipe zones" branch and the `groveAffinity` density multiplier
are no-ops for every pre-existing test.

### Lint

```
stylua --check src tools tests   -> pass (after one stylua auto-format pass on ZoneScatter.luau)
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

## Implementation notes

- New constant `GROVE_SEED_OFFSET = 900000` (same style as `MIST_SEED_OFFSET`), and
  `GROVE_ATTENDANT_THRESHOLD = 0.6` for the member dominant/attendant species roll.
- A second LCG stream (`groveStates`/`groveRoll`), seeded `seedState(zone.seed + 900000)` per
  grove-recipe zone, isolated from the main `states`/`roll` used by the per-sample pass — adding a
  grove recipe cannot perturb another zone's ordinary roll sequence.
- The pre-pass runs after `accepts` is defined and before the per-sample `for _, s in ordered`
  loop, so it can reuse `accepts(zone, probe)` verbatim as the single-zone site gate.
- Anchor and member candidates use the exact-cell `sampleIndex[sampleKey(x, z, pitch)]` lookup
  (nil → reject) rather than the linear-scan `nearestSample` clump children use — a dart with no
  sample under it is rejected outright rather than snapped to a neighbour. The brief specified this
  explicitly for anchors ("use the Task-5 sampleIndex exact-cell lookup"); for members it only says
  "find a nearest grid sample" without naming the mechanism. I used the same exact-cell lookup for
  members too, for consistency and because it's already indexed (O(1) vs. `nearestSample`'s O(n)
  scan over every terrain sample) — flagging this as a judgment call in case the intent was
  `nearestSample` instead.
- Per the brief, grove members are NOT re-checked against `containsXZ`/y-band the way clump
  children are (clump children re-resolve through `resolveZone` across all zones and require
  `czone == zone`; grove members only need their own zone's `accepts` gate plus the grid-sample
  lookup). In practice this is bounded anyway: `groveProbe`'s exact-cell lookup returns nil for
  any position off the sample grid, and `radiusMax` is expected to be small relative to zone size.
- Grove placements append straight into the shared `out` array with `recipe.layer or "canopy"`, so
  every ordinary per-sample zone processed afterward spacing-checks against them like any other
  placement — verified by the existing "ground cover does not veto trees" per-layer-spacing test
  still passing unmodified.
- Per-sample exclusion of grove-recipe zones is done by returning `false` from the `accepts`
  closure passed into `resolveZone`'s zone-resolution wrapper (not by filtering the `zones` array),
  so a grove zone still correctly vetoes nothing and simply lets `resolveZone` fall through to
  whatever zone is layered beneath — matching "their samples fall through to lower zones" exactly,
  and reusing the existing layering machinery rather than adding a new code path.
- `groveAffinity` builds its proximity index from ANCHORS only (`ZoneScatter.indexWater(groveAnchors)`,
  populated after all grove zones' pre-passes run), per the brief's explicit "collect every accepted
  anchor... build a bucketed index" — not from every grove placement (elders+members). This is safe
  for the "near a grove placement" framing in the test list because the anchor is itself always one
  of the grove's placements (the elder), so "within `radius` of an anchor" implies "within `radius`
  of some grove placement."

## Self-review

Walked every brief requirement against the diff:

- [x] `grove`/`groveAffinity` recipe fields, exact shape — `GroveConfig`/`GroveAffinity` types added,
  wired onto `Recipe`.
- [x] LCG stream `seedState(zone.seed + 900000)` — `groveStates[zone] = seedState(zone.seed + GROVE_SEED_OFFSET)`.
- [x] Dart-throw `anchorDarts` attempts, uniform in bbox, stop at `maxGroves` — loop with early `break`.
- [x] All four anchor gates (containsXZ+y-band, exact grid sample, `accepts`, spacing) — implemented
  in that order; tested by "clustering" (spacing/maxGroves), "meadows" (spacing), "gates hold"
  (keepOut via `accepts`).
- [x] Dominant/attendant species roll, pool-of-one degenerate case — tested indirectly via
  "species coherence" (3-species pool, ≤2 per cluster) and "elder" (dominant scale visible).
- [x] Member count in `[membersMin, membersMax]` — floor formula, capped by construction.
- [x] Elder formula exact — `(1 + (roll*2-1)*scaleJitter) * heightScale * domScale * grove.dominantScale`,
  tested by "elder" test's `dominantScale * (1 - scaleJitter)` lower bound and median comparison.
- [x] Member polar offset, grid+accepts+memberSpacing gates, dominant/attendant 0.6 threshold, normal
  scale (no `dominantScale` multiplier) — implemented; scale formula omits `grove.dominantScale`.
- [x] Grove placements share `out`, correct `layer` default — confirmed by the pre-existing
  per-layer-spacing test staying green with zero code changes to it.
- [x] Anchors collected as `{x,z}`, indexed via `ZoneScatter.indexWater` after all grove zones —
  `groveIndex` built once, after the full pre-pass zone loop.
- [x] Grove-recipe zones excluded from per-sample resolution, fall through — "does not plant via the
  per-sample path" test (`#out <= maxGroves * membersMax` even though the zone covers the full grid).
- [x] `groveAffinity` inside/outside multiplier via `waterWithin` on the anchor index — "groveAffinity"
  test (radius 20, inside=1/outside=0, understory-only-near-grove assertion).
- [x] Determinism, no `math.random` — "deterministic" test (two runs, same zones/samples/recipes,
  full-field equality including `scale`).
- [x] All 724 pre-existing tests untouched and still green.
- [x] `--!strict` maintained; `stylua`/`selene` clean at CI scope.

No findings requiring further fixes. One documented judgment call (member grid-sample lookup
mechanism) noted above in case the controller's follow-up wants the alternative interpretation.

## Commit
`feat(roblox): grove-structured scatter - trees get social, meadows get real`

---

## Fix: grove pre-pass bypassed KeepOut zones (2026-07-31)

Live-world gate found groves planting inside `KO_Pad_*` keep-out zones (trees through teahouse
pads). Root cause, confirmed by re-reading my own diff: `resolveZone`'s KeepOut veto is enforced
per-sample in the ordinary path, but the grove pre-pass only ever called `accepts(zone, probe)`
(the recipe/site gates) and `containsXZ`/`contains` for its OWN zone — it never checked whether
some OTHER zone in the array was a `KeepOut` covering that spot, for either anchor darts or
members. `accepts()` doesn't carry a KeepOut check at all (KeepOut isn't a recipe, `recipes[zone.recipe]`
would be nil for it) — that veto lives entirely inside `resolveZone`, which the grove pre-pass never
calls.

### RED

Added `"gates hold: grove pre-pass honors KeepOut zones - pads are sacred too"` to the
`ZoneScatter grove pre-pass` describe block: a grove zone over the full 100x100 flat grid plus a
`KO_Pad` KeepOut zone over `x in [50,100]`, asserting no placement (anchor or member) has `x >= 50`.

```
FAIL  ZoneScatter grove pre-pass > gates hold: grove pre-pass honors KeepOut zones - pads are sacred too
      .../ZoneScatter.spec:840: expected false to be true
736 passed, 1 failed, 737 total
```

Confirmed the bug reproduces exactly as described.

### Fix

- Factored the KeepOut scan out of `resolveZone` into `local function keepOutAt(zones, x, z, y): boolean`
  — identical loop body (`zone.recipe == "KeepOut" and contains(zone, x, z, y)`), just returns a
  boolean instead of `nil`/continuing. `resolveZone` now calls `keepOutAt(zones, x, z, y)` — pure
  refactor, behavior unchanged (verified: full suite green before AND after touching `resolveZone`
  in isolation).
- Grove pre-pass anchor gate: added `if keepOutAt(zones, ax, az, gs.y) then continue end` right
  after the y-band `contains(zone, ax, az, gs.y)` check and before `accepts(zone, anchorProbe)` —
  uses the grid sample's `y` for the y-band check, same as `resolveZone` does via its `y` parameter.
- Grove pre-pass member gate: same veto, `keepOutAt(zones, mx, mz, mgs.y)`, added right after the
  exact-cell grid lookup (`mgs`) and before `accepts(zone, memberProbe)`.

### GREEN

```
737 passed, 0 failed, 737 total
```

All 736 previously-green tests (724 original + 8 grove tests + the "does not plant via per-sample
path" regression) plus the new KeepOut test are green.

### Lint

```
stylua --check src tools tests   -> pass
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

### Files touched (this fix)
- `roblox/tools/builders/ZoneScatter.luau` — `keepOutAt` extraction + two new call sites.
- `roblox/tests/ZoneScatter.spec.luau` — one new test.

### Commit
`fix(roblox): grove pre-pass honors KeepOut zones - pads are sacred too` (1074bdc)

---

## Feature: grove saplings (2026-07-31)

Gate feedback wanted groves richer: a chance for grove MEMBERS (never the elder) to plant as a
young/sapling model instead of the adult, via a new optional `grove.saplings = { chance, map }`
field.

### RED

Added a nested `describe("grove saplings", ...)` under the existing grove pre-pass describe block,
with three tests:
1. `chance=1 + full map: every non-elder member is a mapped young species` — asserts every
   non-elder placement's species ends in `_Yb` and the elder's never does.
2. `chance=0: byte-identical to a run without saplings config (stream-ordering discipline)` — same
   seed/zones/samples, one recipe with `saplings = {chance=0, map=FULL_MAP}`, one with no
   `saplings` field at all; asserts every placement's x/z/species/scale/yaw match exactly.
3. `an unmapped species stays adult even at chance=1` — map only covers one of the three pool
   species; asserts members never surface the raw unmapped-but-rollable species name and the
   mapped one is never left adult.

```
FAIL  ZoneScatter grove pre-pass > grove saplings > chance=1 + full map: every non-elder member is a mapped young species
      .../ZoneScatter.spec:927: expected false to be true
739 passed, 1 failed, 740 total
```

Tests 2 and 3 passed vacuously pre-implementation (with `saplings` unread by the planner, nothing
ever gets mapped, so "stays adult"/"identical to no-saplings" both trivially hold) — expected, and
still meaningful post-implementation as regression/negative-case coverage.

### Fix

- Added `GroveConfig.saplings: { chance: number, map: { [string]: string } }?`.
- In the member-placement loop, after the existing dominant/attendant species roll
  (`groveRoll(zone) < GROVE_ATTENDANT_THRESHOLD`) and before the yaw/scale rolls, added:
  `local saplingRoll = groveRoll(zone)` — **always drawn**, regardless of whether `grove.saplings`
  is configured. This is the key design decision: the brief's test 2 requires a `chance=0` run to be
  byte-identical to a run with NO `saplings` field at all. Since the LCG stream is positional (every
  draw shifts subsequent state), the only way both cases produce identical output is if the draw
  itself is unconditional — its INTERPRETATION (whether to apply the substitution) is what's gated
  on `grove.saplings ~= nil` and `saplingRoll < chance`, not the draw's occurrence. This keeps the
  stream's shape independent of which optional features a recipe happens to enable, matching "the
  stream ordering of existing draws is unchanged" from the brief.
- Substitution: `if saplings ~= nil and saplingRoll < saplings.chance then local young =
  saplings.map[mSpecies]; if young ~= nil then mSpecies = young end end` — only touches `mSpecies`;
  `mScale` (looked up earlier from the dominant/attendant pool entry) and the existing scale-jitter
  formula are untouched, so scale/heightScale/speciesScale apply exactly as before, per the brief
  ("NO other changes"). Elders are never in scope (this code lives inside the `for _ = 2,
  memberCount do` member loop, after the elder is already appended to `out`).

### GREEN

```
740 passed, 0 failed, 740 total
```

### Lint

```
stylua --check src tools tests   -> pass (one auto-format pass needed on the new nested test)
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

### Files touched (this feature)
- `roblox/tools/builders/ZoneScatter.luau` — `GroveConfig.saplings` field + member-loop roll/substitution.
- `roblox/tests/ZoneScatter.spec.luau` — nested `describe("grove saplings", ...)`, 3 tests.

### Commit
`feat(roblox): grove saplings - youngsters among the elders` (75333be)

---

## Feature: grove member retries (2026-07-31)

Gate feedback: groves weren't reading because member slots die on a single dart attempt — real
terrain rejects the one dart and the "grove" ends up 1-3 trees. Fix: give each member slot up to
`grove.memberTries` attempts (new optional field, default 1 = old behavior) before it's abandoned.

### RED

Added a nested `describe("grove member retries", ...)` with two tests:
1. `memberTries=1 is byte-identical to a run without memberTries config` — same seed/zones,
   `memberTries=1` explicit vs. no `memberTries` field at all; asserts every field of every
   placement matches.
2. `memberTries=6 on hostile ground yields substantially fuller groves than memberTries=1` — a
   second zone list adds a `KeepOut` covering x in [0,60] (60% of the 100-wide zone) alongside the
   grove zone, so anchors get pushed into the remaining strip and many single-dart member attempts
   land on blocked ground; asserts `#out6 > #out1`.

```
FAIL  ZoneScatter grove pre-pass > grove member retries > memberTries=6 on hostile ground yields substantially fuller groves than memberTries=1
      .../ZoneScatter.spec:1036: expected false to be true
742 passed, 1 failed, 743 total
```

Test 1 passed vacuously pre-implementation (with `memberTries` unread, both configs behave
identically — expected, still meaningful post-fix as the determinism regression).

### Fix

- Added `GroveConfig.memberTries: number?` (default 1, documented as "the old single-shot
  behavior").
- Wrapped the member slot's placement logic in a bounded retry loop: `for _ = 1, memberTries do
  ... end`. Each iteration draws a **fresh** angle/radius roll (`groveRoll(zone) * 2 * math.pi`,
  `radiusMin + groveRoll(zone) * (radiusMax - radiusMin)`) and re-runs every existing gate in the
  same order (grid-sample lookup, `keepOutAt`, `accepts`, `memberSpacing`). A failed gate at any
  point `continue`s to the next attempt (innermost loop). The species roll, sapling roll, yaw roll,
  and scale roll — everything tied to actually PLACING the member — only fire once a candidate
  clears every gate, immediately followed by `table.insert(out, ...)` and `break`, so a successful
  early attempt draws exactly the same roll sequence as before this change (satisfies "a slot that
  succeeds on try 1 draws the same rolls as today").
- The sapling roll's relative position (after species selection, tied to the successful attempt)
  is unchanged from the previous feature — it now naturally sits inside the retry loop's success
  branch, drawn once per successfully-placed member, never per failed attempt.
- A slot that exhausts all `memberTries` without a successful attempt is abandoned (no placement,
  no extra rolls beyond what each failed attempt consumed) — matches "the slot is abandoned".

### GREEN

```
743 passed, 0 failed, 743 total
```

### Lint

```
stylua --check src tools tests   -> pass (one auto-format pass on the new nested tests)
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

### Files touched (this feature)
- `roblox/tools/builders/ZoneScatter.luau` — `GroveConfig.memberTries` field + member-slot retry loop.
- `roblox/tests/ZoneScatter.spec.luau` — nested `describe("grove member retries", ...)`, 2 tests.

### Commit
`feat(roblox): grove member retries - slots fight for ground instead of dying` (789c70b)

---

## Feature: free-mix groves / `grove.coherent` (2026-07-31)

Final grove option: an opt-out of the dominant/attendant species pairing. `grove.coherent = false`
makes every placement in a grove — elder included — draw its species independently from the full
pool, for a "hero stand" that reads as genuinely mixed rather than one species with a minority
accent.

### RED

Added a nested `describe("free-mix groves (coherent = false)", ...)` with two tests:
1. `coherent unset behaves byte-identically to before (coherent = true explicit)` — same
   seed/zones, `grove.coherent = true` explicit vs. no `coherent` field; asserts every field of
   every placement matches.
2. `coherent=false with a 6-species pool yields >=3 distinct species in one grove` — a 6-entry
   equal-weight pool, `coherent = false`, generous `membersMin/Max` (5-8) and `memberTries = 4` to
   give slots room to land; asserts the richest cluster has ≥3 distinct species.

```
FAIL  ZoneScatter grove pre-pass > free-mix groves (coherent = false) > coherent=false with a 6-species pool yields >=3 distinct species in one grove
      .../ZoneScatter.spec:1105: expected false to be true
746 passed, 1 failed, 747 total
```

Test 1 passed vacuously pre-implementation (with `coherent` unread, both configs hit the same old
dominant/attendant code path — expected, and still a meaningful regression test post-implementation).

### Fix

- Added `GroveConfig.coherent: boolean?` (nil/true = default coherent behavior, false = free-mix).
- `local coherent = grove.coherent ~= false` resolves the default without needing an explicit nil
  check (only an explicit `false` flips it).
- Restructured the per-anchor species selection: the existing dominant/attendant
  pickSpecies-and-pool-filter block now only runs `if coherent`; in the `else` (free-mix) branch,
  a single `pickSpecies(recipe.pool, groveRoll(zone))` roll produces `elderSpecies`/`elderScale`
  directly — the dominant/attendant rolls (2 rolls in coherent mode) are entirely skipped, so
  free-mix mode draws exactly 1 species roll for the elder where coherent mode draws 2. Both
  branches converge on `elderSpecies`/`elderScale`, which the elder placement (previously
  `domSpecies`/`domScale`) now reads uniformly.
- Member species selection: `if coherent then` the existing dominant/attendant-threshold roll (1
  roll) runs unchanged; `else` a single `pickSpecies(recipe.pool, groveRoll(zone))` roll (also 1
  roll) replaces it — so free-mix and coherent modes both draw exactly one species roll per
  successful member placement, satisfying "draw only what's used — per-member one species roll;
  elder one species roll."
- The sapling roll's position (right after species selection, on a successful placement attempt
  only) is untouched — it now simply reads whichever `mSpecies` the active mode produced.
- Because free-mix mode consumes fewer rolls per anchor (1 vs. 2 for the elder's species), turning
  `coherent` on/off DOES reshuffle the rest of that grove's stream — this is intentional and
  explicitly sanctioned by the brief ("draw only what's used"), unlike the saplings/memberTries
  features which were required to reserve a stream slot unconditionally. The determinism guarantee
  here is narrower and correct: `coherent` unset/true is byte-identical to `coherent = true`
  explicit (verified), not to a hypothetical free-mix run.

### GREEN

```
747 passed, 0 failed, 747 total
```

### Lint

```
stylua --check src tools tests   -> pass (no reformatting needed this round)
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

### Files touched (this feature)
- `roblox/tools/builders/ZoneScatter.luau` — `GroveConfig.coherent` field, anchor species-selection
  branch (coherent/free-mix), member species-selection branch.
- `roblox/tests/ZoneScatter.spec.luau` — nested `describe("free-mix groves (coherent = false)",
  ...)`, 2 tests.

### Commit
`feat(roblox): free-mix groves - hero stands draw the whole pool` (0b2cf5d)

---

## Fix: single-grove zones anchor nearest the marked centre (2026-07-31)

Gate feedback on user-placed stands: a single-grove zone (`grove.maxGroves == 1`) anchored at the
zone EDGE — the zone centre failed `pathMargin` on the first dart, and since the pre-pass took the
first passing dart, the anchor wandered off to wherever the next dart happened to land. For a
user-placed stand (as opposed to wild multi-grove growth) that reads as broken.

### RED

Added a nested `describe("single-grove anchors seek the centre (maxGroves = 1)", ...)` with three
tests:
1. `determinism regression: maxGroves > 1 zones stay byte-identical` — a golden-value snapshot.
   Captured the EXACT output (x, z, species, scale, yaw for all 12 placements, full `%.17g`
   precision) of `groveRecipe()` + `groveZones()` (`maxGroves = 4`) by running it against the
   pre-fix implementation (commit `0b2cf5d`) via a throwaway script, then hardcoded those values as
   the expected result. This is a stronger check than the "two live runs match" idiom used for
   prior grove features, because THIS fix has no equivalent-config toggle to compare against post-
   refactor — the only way to prove the multi-grove code path is untouched is to snapshot its
   literal output before touching it.
2. `open centre: single-grove anchor lands within 8 studs of the zone centroid` — a wide-open flat
   zone, `maxGroves = 1`, `anchorDarts = 500`; asserts the placed anchor (the grove's elder, always
   `out[1]` for an isolated single-grove zone) is within 8 studs of `(50, 50)`.
3. `blocked centre: single-grove anchor hugs the keep-out boundary, not the far edge` — same
   recipe plus a `KeepOut` circle of radius 15 centred on `(50, 50)`; asserts the anchor's distance
   to centre is `>= 15` (still honors the veto) `and < 25` (hugs the boundary rather than landing
   near a ~70-stud-distant corner).

```
FAIL  ZoneScatter grove pre-pass > single-grove anchors seek the centre (maxGroves = 1) > open centre: single-grove anchor lands within 8 studs of the zone centroid
      .../ZoneScatter.spec:1225: expected false to be true
FAIL  ZoneScatter grove pre-pass > single-grove anchors seek the centre (maxGroves = 1) > blocked centre: single-grove anchor hugs the keep-out boundary, not the far edge
      .../ZoneScatter.spec:1254: expected false to be true
749 passed, 2 failed, 751 total
```

The golden-snapshot regression test (1) passed immediately pre-fix, as expected — it's a proof
that the snapshot itself is accurate, not a RED signal (there was nothing to break yet).

### Fix

- Extracted the entire "accepted anchor → elder + members" body (species selection, member count,
  elder insert, the member-slot retry loop with sapling substitution) into a local closure
  `placeGrove(ax: number, az: number, gs: Sample)`, defined once per grove-recipe zone (capturing
  `zone`, `recipe`, `grove`, `layer`, `heightScale`, `coherent`, `zoneAnchors`, `out` as upvalues —
  all already in scope). This is byte-for-byte the same code that used to run inline; only its
  location moved.
- `local coherent = grove.coherent ~= false` was hoisted out of the accepted-anchor block to
  right after `groveStates[zone] = ...`, since it never depended on anchor position — this doesn't
  change its value or the roll sequence, just where the resolution happens.
- Split the dart-throw loop on `grove.maxGroves == 1`:
  - **`maxGroves == 1`** (new): loop through all `grove.anchorDarts` unconditionally (no early
    `break`), drawing the same `ax`/`az` rolls every iteration regardless of whether the dart
    passes — matching "the stream consumes the same rolls regardless of acceptance." Every dart
    that clears `containsXZ` → grid-sample lookup → y-band → `keepOutAt` → `accepts` (identical
    gates and order to the multi-grove path) is compared by squared distance to the zone's bbox
    centroid (`(x1+x2)/2, (z1+z2)/2`); the closest passing candidate's `ax`/`az`/`gs` are kept.
    After the full scan, `placeGrove` is called once with the winner (skipped entirely if nothing
    passed — "no grove" unchanged). Inter-anchor spacing is not checked here since `zoneAnchors` is
    always empty for a single-grove zone.
  - **`maxGroves > 1`** (unchanged): the original first-accept loop, `break`ing once
    `#zoneAnchors >= grove.maxGroves`, with the `tooClose`-vs-other-anchors spacing check —
    identical code, just now calling `placeGrove(ax, az, gs)` instead of inlining the body.
- Because `maxGroves == 1` now scans every dart instead of stopping at the first accept, its
  overall roll consumption legitimately differs from before this fix — that's the point of the
  change, and the brief doesn't ask for byte-identical behavior here (only for `maxGroves > 1`,
  which the golden snapshot proves).

### GREEN

```
751 passed, 0 failed, 751 total
```

### Lint

```
stylua --check src tools tests   -> pass (no reformatting needed)
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

### Files touched (this fix)
- `roblox/tools/builders/ZoneScatter.luau` — `placeGrove` extraction, `coherent` hoist, dart-loop
  split on `maxGroves == 1` (center-seeking scan) vs. `> 1` (unchanged first-accept).
- `roblox/tests/ZoneScatter.spec.luau` — nested `describe("single-grove anchors seek the centre
  (maxGroves = 1)", ...)`, 3 tests (golden-snapshot regression + 2 new-behavior tests).

### Commit
`fix(roblox): single-grove zones anchor nearest the marked centre` (19b0fcf)

---

## Rewrite: exhaustive grove placement, dart-throwing removed entirely (2026-07-31)

User verdict on the dart-throwing approach (after all the fixes above): fundamentally flawed.
Confirmed in-world — legal ground sat unused while stands starved, because each anchor/member slot
got a bounded number of continuous-random dart attempts, and a sparse or awkwardly-shaped patch of
legal ground could easily never get hit. This is a full rewrite of the grove pre-pass per the
user's algorithm; darts are gone.

### New algorithm (implemented exactly as specified, per grove zone, in zone order)

1. **CANDIDATES** — every grid sample inside the zone (`contains(zone, s.x, s.z, s.y)`, the same
   containsXZ+y-band check `resolveZone` uses) that clears `accepts(zone, s)` and isn't vetoed by
   `keepOutAt`. Built once per zone from `ordered` (already x-then-z sorted), so it and every
   tie-break below is deterministic. No randomness anywhere in this step.
2. **TARGET** — `memberTarget = membersMin + floor(groveRoll(zone) * (membersMax-membersMin+1))`,
   rolled once per grove instance, BEFORE the anchor is chosen (needed for eligibility in the
   single-grove branch; just carried forward to the member pass for multi-grove).
3. **ANCHOR** — `support(c)` = count of other candidates in the CURRENT (shrinking) pool within
   `radiusMax` of `c`.
   - `maxGroves == 1`: among candidates with `support >= memberTarget - 1` ("eligible" — enough
     neighbours to reach the FULL target, not just survive), pick the one nearest the zone
     centroid; if none eligible, fall back to the max-support candidate.
   - `maxGroves > 1`: repeatedly pick the max-support candidate that's `>= grove.spacing` from
     every prior anchor; stop when `maxGroves` is reached or the best remaining support
     `< membersMin - 1`.
4. **MEMBERS** — the elder plants at the anchor (`dominantScale` as before). Then greedily take the
   unused candidate NEAREST the anchor (within `radiusMax`) that's `>= memberSpacing` from every
   already-placed member of THIS grove (elder included — scoped to the grove, not the whole `out`
   array), repeating until `memberTarget` total or no candidate qualifies. Every chosen position
   (elder and each member) gets a deterministic LCG jitter up to `±1.2` studs per axis
   (`GROVE_JITTER_MAX`), applied AFTER the position is chosen — gates, support, and spacing all use
   the exact grid position; only the final rendered `x`/`z` wobbles, so a grove doesn't read as
   trees standing on a lattice.
5. Chosen candidates (anchor and every member) are removed from the zone's candidate pool
   immediately, so later groves in the same zone (and the per-sample pass afterward, unchanged)
   never reuse that ground.
6. `anchorDarts` and `memberTries` are now dead config: kept in `GroveConfig` (not removed, so
   existing recipe literals don't need edits) with `DEPRECATED / unused` comments, never read.

### Implementation notes / judgment calls

- **`radiusMin` also went unused.** The brief's algorithm text never mentions it — proximity is now
  bounded above by `radiusMax` and below by `memberSpacing`, making a separate anchor-distance
  minimum redundant (it made sense for continuous polar dart offsets, not for picking among literal
  grid points). The brief explicitly called out `anchorDarts`/`memberTries` as legacy but didn't
  mention `radiusMin` either way; I judged it equally vestigial under the new algorithm and marked
  it `DEPRECATED / unused` in the same style, rather than silently leaving a dead-but-undocumented
  field. Flagging this explicitly in case the intent was different.
- **Jitter applies to the elder too**, not just members. The brief's MEMBERS section opens with "the
  elder plants AT the anchor" and then describes jitter as applying "after choosing each position"
  — read in context of the whole section, every chosen position (elder included) gets jittered;
  otherwise every elder would sit exactly on a grid intersection, undermining the stated goal ("so
  grid alignment doesn't read").
- **`placeGrove` is a closure per zone** (mirrors the structure from the earlier center-seeking fix)
  capturing `zone`/`recipe`/`grove`/`layer`/`heightScale`/`coherent`/`candidates`/`out` — species
  selection (coherent/free-mix), the sapling roll, and the elder/member scale-and-yaw formulas are
  byte-for-byte the logic from the prior features, just now driven by a chosen candidate instead of
  a passing dart.
- **Support is recomputed live** against the shrinking `candidates` pool on every anchor-selection
  pass (`O(n)` per candidate, `O(n²)` per grove-selection round) — a later grove's anchor eligibility
  correctly reflects ground already claimed by an earlier grove in the same zone. Not optimized for
  large sample counts; the brief didn't ask for it and Lune-test-scale grids are small.

### Tests: full rewrite of the grove-pre-pass describe block

Most existing behavioral-guarantee tests (determinism, clustering ≤ maxGroves, meadows spacing,
species coherence, elder scale, keep-out exclusion via both `opts.keepOut` and a `KeepOut` zone,
"doesn't plant via the per-sample path", grove saplings ×3, free-mix ×2) turned out to assert
*properties*, not dart-specific mechanics, and kept passing unmodified against the new algorithm —
confirmed by running the full suite against the new implementation before touching most of the test
file. Three things genuinely needed rewriting:

1. **`groveAffinity` test** — failed by a small margin (nearest canopy placement ~21.5 studs vs. the
   asserted `<= 20`). Root cause: the affinity density gate checks proximity to the exact
   (unjittered) anchor, but jitter can push the nearest actual canopy placement's rendered position
   a bit further away. Fixed by padding the assertion's radius with `slack = 3` studs — the gate
   itself is still exact; only the assertion needed to account for the now-jittered geometry it's
   verifying against.
2. **"grove member retries" describe block** — its "memberTries=6 fuller than memberTries=1" test
   directly contradicted the new design (memberTries is now inert) and was removed. Replaced with
   `describe("legacy dart-era fields are inert (anchorDarts, memberTries)", ...)`: kept the
   `memberTries` byte-identical regression (still meaningful, now proving true inertness rather
   than "retries succeed on try 1"), and added a symmetric `anchorDarts` byte-identical test
   (`anchorDarts = 1` vs. `anchorDarts = 5000`, identical output) proving that field is dead too.
3. **"single-grove anchors seek the centre" golden-snapshot test** — the exact dart-era position
   values it asserted are meaningless under a completely different algorithm; removed. The "open
   centre" and "blocked centre" tests survived conceptually (both passed once `centeredRecipe` no
   longer needed an `anchorDarts` tuning parameter) but needed `JITTER_SLACK = 2` padding on their
   distance bounds for the same jitter-vs-exact-gate reason as `groveAffinity`.

New tests, added as `describe("starvation regression: exhaustive placement finds sparse legal
ground", ...)`:

- **The flagship regression**: exactly 5 samples exist in the entire synthetic "world" — a
  plus-shaped patch 4 studs apart, nothing else — with `membersMin = membersMax = 5` (forcing a
  deterministic `memberTarget = 5`, independent of the LCG roll) and `radiusMax = 8` /
  `memberSpacing = 3` tuned so all 5 points are mutually reachable. Asserts `#out == 5` — a
  complete, full-target grove using every legal spot. Hand-traced the tie-breaking (centroid
  distance ties at (48,48)/(52,48)/(48,52), support ties among all 5 neighbours, nearest-to-anchor
  ties at every member-selection step) against the deterministic `ordered`-order tie-break to
  confirm the exact expected count before running — matches. Under the OLD dart-throw algorithm,
  hitting any of these 5 sparse points would have required a continuous random float to land on an
  EXACT grid cell — vanishingly unlikely, which is exactly the in-world bug this rewrite fixes.
- **Inverse control**: 5 candidates mutually farther apart than `radiusMax` (support always 0).
  Asserts `#out == 1` — an elder can always anchor alone, but the grove can never grow past it,
  proving the placer isn't just unconditionally filling to `memberTarget` regardless of real ground.

### RED/GREEN evidence

Ran the full suite immediately after the ZoneScatter.luau rewrite, BEFORE touching most of the test
file, to see exactly what the new algorithm broke against the OLD tests (a live regression signal,
not a hand-predicted one):

```
FAIL  ZoneScatter grove pre-pass > groveAffinity plants understory only near grove placements
FAIL  ZoneScatter grove pre-pass > grove member retries > memberTries=6 on hostile ground yields substantially fuller groves than memberTries=1
FAIL  ZoneScatter grove pre-pass > single-grove anchors seek the centre (maxGroves = 1) > determinism regression: maxGroves > 1 zones stay byte-identical
749 passed, 3 failed, 752 total
```

Exactly the 3 tests reasoned above as needing rewrite, and nothing else — validating that the
remaining tests genuinely assert algorithm-independent behavioral guarantees. After rewriting those
3 (plus the 2 new starvation tests, +2 net over the pre-rewrite count):

```
753 passed, 0 failed, 753 total
```

One lint fix needed along the way: `selene` flagged variable shadowing (`o` reused inside
`supportOf`, already bound by the outer `local o: PlanOptions = opts or {}`) — renamed the loop
variable to `other`.

### Lint

```
stylua --check src tools tests   -> pass
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```

### Files touched (this rewrite)
- `roblox/tools/builders/ZoneScatter.luau` — `GroveConfig` deprecation comments (`anchorDarts`,
  `memberTries`, `radiusMin`), `GROVE_JITTER_MAX` constant, full grove pre-pass replacement
  (candidate pool, `supportOf`/`removeCandidate`/`jitter` helpers, `placeGrove`, anchor-selection
  branches for `maxGroves == 1` vs. `> 1`).
- `roblox/tests/ZoneScatter.spec.luau` — `groveAffinity` slack fix, "legacy dart-era fields are
  inert" describe block (replacing "grove member retries"), "single-grove anchors seek the centre"
  simplified + golden snapshot removed, new "starvation regression" describe block (2 tests).

### Commit
`feat(roblox): exhaustive grove placement - find the ground, then plant it` (3fdbbff)
