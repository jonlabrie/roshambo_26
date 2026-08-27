# Grove recipes + Studio mirror — report

Source of truth: `roblox/tools/builders/ZoneScatter.luau` at commit 08b0f91 (the
new `grove`/`groveAffinity` Recipe fields, `GroveConfig`/`GroveAffinity` types,
the grove pre-pass loop, the per-sample exclusion of grove-recipe zones, and
the anchor index/groveAffinity density multiplication).

## Files changed

### `roblox/tools/studio/foliageZoneRecipes.luau`
- `Recipe` type gains `grove: GroveConfig?` and `groveAffinity: GroveAffinity?`,
  matching ZoneScatter's `Recipe` type exactly.
- Added `export type GroveConfig` and `export type GroveAffinity`, field-for-field
  identical to ZoneScatter's.
- `PreserveCore` gains the `grove` config (spacing 55, radiusMin/Max 8/16,
  membersMin/Max 3/8, memberSpacing 7, dominantScale 1.25, anchorDarts 300,
  maxGroves 12) — exactly the values in the task spec.
- `PreserveBrush` gains `groveAffinity = { radius = 22, inside = 1, outside = 0.25 }`
  and three small-tier pool entries appended after the existing four
  (XfHinokiYb/15/0.65, XfSpruceYb/15/0.65, XfFirYb/10/0.65); the original four
  entries' weights are untouched.
- Comments explain WHY: the grove pre-pass exists because the per-sample gate
  (steep/footing/spacing all compounding) rejected canopy too uniformly for
  the forest to ever read as clustered stands; the small tiers exist because
  the brush band read as a flat, uniform ~4-stud carpet and discrete
  short-scale entries (not wider jitter, which risks poking into the 5-stud
  sightline band) give real height variety.

### `roblox/tools/studio/scatterPreserve.luau`
Two of the file's four documented inline mirrors were updated (recipe table +
planner); the keep-outs and care-model mirrors were untouched (out of scope).

- `Recipe` type (local, non-exported per this file's convention) gains the
  same `grove`/`groveAffinity` fields; added local `GroveConfig`/`GroveAffinity`
  type aliases.
- `RECIPES.PreserveCore` and `RECIPES.PreserveBrush` updated identically to
  `foliageZoneRecipes.luau` (same values, same comments).
- Added `GROVE_SEED_OFFSET = 900000` and `GROVE_ATTENDANT_THRESHOLD = 0.6`
  constants (byte-identical to ZoneScatter).
- Added the `groveStates`/`groveRoll` separate LCG stream, declared right
  after `roll`, exactly as in ZoneScatter — this keeps the grove roll sequence
  from perturbing the ordinary per-sample roll sequence of other zones.
- Inserted the full grove pre-pass block (anchor dart-throwing per grove
  recipe, exact-grid-cell anchor rejection, anchor spacing check, dominant/
  attendant species pick, elder placement, member ring placement with its own
  site-gate + same-layer spacing checks) between the `accepts` function and
  the per-sample loop. Logic, variable names (`zoneAnchors`, `anchorProbe`,
  `domSpecies`/`domScale`, `attPool`, `attSpecies`/`attScale`, `memberCount`,
  `mgs`, `memberProbe`, `memberTooClose`, `mSpecies`/`mScale`) and iteration
  order are identical to ZoneScatter, modulo the file's existing local type
  alias (`Species` instead of the inline pool-entry shape — already the file's
  established convention before this change).
- Built `groveIndex` via the existing local `indexWater` helper (mirrors
  ZoneScatter's `ZoneScatter.indexWater`) over the collected `groveAnchors`.
- Per-sample loop: `resolveZone`'s `accepts` closure now first checks whether
  the candidate zone's recipe has `grove ~= nil` and rejects it if so (grove
  zones are already planted in the pre-pass, so their samples fall through to
  whatever's layered beneath — exactly ZoneScatter's approach).
- Density calculation: after the existing `careDensity` multiplier, added the
  `groveAffinity` multiplier — `waterWithin(groveIndex, s.x, s.z, aff.radius)`
  picks `aff.inside` vs `aff.outside`, identical order and logic to
  ZoneScatter.

### `roblox/tests/FoliageZoneRecipes.spec.luau`
Appended a new `describe("grove pre-pass", ...)` block (existing tests
untouched):
- `PreserveCore runs a grove with sane member/anchor bounds` — spacing > 0,
  radiusMax >= radiusMin, membersMax >= membersMin, membersMin >= 2 (elder +
  at least one attendant), memberSpacing > 0, dominantScale > 1 (elder must
  read oversized), anchorDarts > 0, maxGroves > 0.
- `no other recipe carries a grove` — guards against an accidental grove
  config leaking onto another recipe and silently changing its planter.
- `PreserveBrush thickens near grove anchors via groveAffinity` — radius > 0,
  inside > outside.
- `PreserveBrush pool includes small-scale tiers` — exactly 3 pool entries
  with `scale < 1`, each with positive weight.

No changes were needed to the "recipes name only species that exist" test's
`KNOWN` table: the three new small-tier pool entries reuse existing species
names (XfHinokiYb/XfSpruceYb/XfFirYb) already present in `KNOWN`.

## Mirror-fidelity self-check

Read both files' `plan`/grove-pre-pass sections side by side after editing
(ZoneScatter.luau lines 322-624 vs scatterPreserve.luau's `plan` function).
Confirmed line-for-line equivalence of:
- Constants: `GROVE_SEED_OFFSET = 900000`, `GROVE_ATTENDANT_THRESHOLD = 0.6`.
- The `groveStates`/`groveRoll` separate-stream pattern, placed identically
  relative to `roll`.
- The grove pre-pass loop structure and gate order: anchor dart-throw ->
  containsXZ -> exact sampleIndex lookup (no nudging) -> `contains` (Y-band)
  -> `accepts` -> anchor-spacing check -> species pick -> elder placement ->
  member loop (ring placement -> sampleIndex lookup -> `accepts` -> same-layer
  spacing check -> dominant/attendant roll -> placement).
- `groveIndex` built the same way as the water/built indices, over collected
  anchors from every grove-recipe zone.
- The per-sample `accepts` closure's grove-zone exclusion, and the density
  calculation's `careDensity` then `groveAffinity` multiplier order.

The only differences are the file's pre-existing, established conventions
(local vs exported types; `Species` type alias for pool entries; `local`
function declarations instead of `ZoneScatter.` table members) — the same
divergences already present throughout the rest of the file relative to
ZoneScatter.luau before this change.

**Caveat**: `scatterPreserve.luau` is a Studio-only inline script (drives
`workspace`/`ServerStorage`/raycasts) and cannot be executed under Lune or any
other headless harness. Verification here is lint (stylua/selene) + the
line-by-line self-diff above, not a test run of this specific file. The
planner logic it mirrors IS covered by ZoneScatter.luau's own Lune-run
`ZoneScatter.spec.luau` suite (part of the 736 total below), which is the
actual behavioral guarantee; scatterPreserve.luau's correctness rests on the
mirror being faithful, checked by hand here.

## Verification

```
lune run tests/run
# 736 passed, 0 failed, 736 total   (was 732 before the added coverage)

stylua --check src tools tests
# exit 0, no diffs

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

## Commit

`feat(roblox): grove recipes + Studio mirror - Core groves, brush affinity, small tiers`

---

## Follow-up (2026-07-31): keep-out mirror fix + sparse iris on the waterline

Two live-gate follow-ups, same three files.

### 1. Grove keep-out fix mirrored (commit 1074bdc in ZoneScatter.luau)

`ZoneScatter.luau`'s fix extracted `resolveZone`'s inline KeepOut veto loop
into a shared `keepOutAt(zones, x, z, y): boolean` helper, then called it from
two NEW sites inside the grove pre-pass that previously ignored KeepOut zones
entirely: after the anchor's `contains(zone, ax, az, gs.y)` check, and after
the member's `mgs == nil` nil-check. Mirrored into `scatterPreserve.luau`
identically:

- Added `local function keepOutAt(zones, x, z, y): boolean` right before
  `resolveZone`, body byte-identical to ZoneScatter's.
- `resolveZone`'s inline veto loop replaced with `if keepOutAt(zones, x, z, y) then return nil end`.
- Grove pre-pass anchor loop: added `if keepOutAt(zones, ax, az, gs.y) then continue end`
  immediately after the existing `if not contains(zone, ax, az, gs.y) then continue end`,
  same comment as ZoneScatter ("pads are sacred...").
  scatterPreserve.luau:615.
- Grove pre-pass member loop: added `if keepOutAt(zones, mx, mz, mgs.y) then continue end`
  immediately after `if mgs == nil then continue end`, same comment as
  ZoneScatter ("pads are sacred: same KeepOut veto as an anchor dart").
  scatterPreserve.luau:679.

Confirmed via `grep -n keepOutAt` on both files: 4 occurrences each (the
definition + 3 call sites), same relative line order, same argument order at
every call site.

No test added to `FoliageZoneRecipes.spec.luau` for this: that spec covers
recipe DATA only (pool weights, spacing bands, species membership), never
planner mechanics — it has no fixture for zones/samples to exercise a keep-out
veto. The behavioral regression test for this fix already lives in
`ZoneScatter.spec.luau` ("gates hold: grove pre-pass honors KeepOut zones -
pads are sacred too", added in 1074bdc) and covers the shared logic that
`scatterPreserve.luau` mirrors; `scatterPreserve.luau` itself is Studio-only
and untestable under Lune regardless, per the original task's constraint.

### 2. Iris joins the waterline

`WaterMargin.pool` updated identically in both `foliageZoneRecipes.luau` and
`scatterPreserve.luau`'s `RECIPES`:

```
{ name = "ReedClump", weight = 28 },
{ name = "TallWeeds", weight = 27 },
{ name = "WeedStalks", weight = 20 },
{ name = "FernClump", weight = 15 },
{ name = "IrisA", weight = 5 },
{ name = "IrisB", weight = 5 },
```

with the comment "sparse iris = the waterline's jewel accent; the
hand-composed falls-pool planting remains separate and untouched." Added
`IrisA = true, IrisB = true` to the `KNOWN` table in
`FoliageZoneRecipes.spec.luau`. The existing `pool[1].name == "ReedClump"`
assertion in the "reeds wade, muhly keeps damp feet only" test still holds
unchanged (ReedClump stays first).

### Verification

```
lune run tests/run
# 737 passed, 0 failed, 737 total

stylua --check src tools tests
# exit 0

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

### Commit

`feat(roblox): mirror grove keep-out fix + sparse iris on the waterline`

---

## Follow-up (2026-07-31 #2): grove saplings, bigger groves, slope-adaptive planting depth

Final bundle for this feature, same three files.

### 1. Grove saplings mirrored (commit 75333be in ZoneScatter.luau)

`ZoneScatter.luau`'s `GroveConfig` gained an optional `saplings: { chance: number, map: { [string]: string } }?` field: a grove MEMBER (never the elder) whose rolled species has an entry in `map` may have its placed name swapped for a young/sapling model, chance-gated. The key design decision (documented in ZoneScatter's own comment, reproduced verbatim here) is that the sapling roll is **always drawn** — `local saplingRoll = groveRoll(zone)` runs unconditionally after the dominant/attendant pick, whether or not `grove.saplings` is set — so the LCG stream's shape never depends on an optional feature being toggled; only the *interpretation* of that draw (whether it's consulted at all, and whether the rolled species has a map entry) changes. Elders never roll this — only members do.

Mirrored into `scatterPreserve.luau` identically:
- `GroveConfig` type (local, non-exported) gains the same `saplings` field, same comment.
- In the member loop, immediately after the existing dominant/attendant `mSpecies, mScale` selection and before `table.insert(out, ...)`, added the unconditional `local saplingRoll = groveRoll(zone)` draw, then `if saplings ~= nil and saplingRoll < saplings.chance then ... end` swap logic — byte-identical to ZoneScatter (confirmed via `diff` of the two blocks, no output).

### 2. Recipe changes (both tables, identical)

`PreserveCore.grove`:
- `membersMax` 8 -> 10.
- Added `saplings = { chance = 0.25, map = { XfHinokiT = "XfHinokiYb", XfHinokiMT = "XfHinokiYb", XfSpruceMT = "XfSpruceYb", XfFirMT = "XfFirYb", XfSugi25T = "XfSugiYb" } }`.
- Comment: "gate feedback (2026-07-31): bigger groves with youngsters among the elders sell the grove read."

Confirmed identical between `foliageZoneRecipes.luau` and `scatterPreserve.luau`'s `RECIPES` via `diff` of the extracted `grove = { ... }` blocks (no output = byte-identical).

`Recipe` type in both files already had `grove: GroveConfig?`; `GroveConfig` itself (in both files) gained the `saplings` field described above.

### 3. Slope-adaptive bed-in (`scatterPreserve.luau`'s `bake()` only — no pure-planner change)

Trees seated only by their calibrated `PlantDepth` attribute still showed a naked, downhill root ball on sloped ground (the depth is calibrated for flat ground; the uphill side of the root flare pokes out on a slope). In `bake()`, after the existing `depth *= clone:GetScale()` line and before `local box, size = clone:GetBoundingBox()`, added:
- A `local rpBed = RaycastParams.new()` (Include={workspace.Terrain}, IgnoreWater=true) built once per `bake()` call, same raycast style as `sampleTerrain`'s `rpGround`.
- A probe of 4 compass points (N/E/S/W, `i * math.pi / 2` for i=0..3) at radius 1.5 studs around `(p.x, p.z)`, each raycast from `(px, p.y + 50, pz)` straight down 200 studs, collecting `minY`/`maxY` across the hits.
- `depth += math.clamp((maxY - minY) / 2, 0, 2.5)` when at least one probe hit — flat ground gives `maxY - minY ≈ 0` so calibrated depths are untouched; a slope's vertical spread across the 4 probes sinks the tree further, capped at 2.5 extra studs.

Comment added: "slope-adaptive sink so downhill roots bury (2026-07-31 gate)." Also noted per the coordinator's instruction: this makes `bake()` non-pure-deterministic only in the sense that it raycasts live terrain on every call — terrain doesn't change between bakes, so a re-bake still reproduces the same result; this is the same caveat that already applies to `sampleTerrain`, `readWaterCells`, `readBuiltCells`, and `fallsDockFootprint` elsewhere in this file.

### Test coverage added

`FoliageZoneRecipes.spec.luau` — one new test in the existing `describe("grove pre-pass", ...)` block: `"PreserveCore groves fit 10 members and swap saplings from real species"` — asserts `membersMax == 10`, `saplings ~= nil`, `0 < chance < 1`, every map key is a real `PreserveCore` pool species name, and every map value contains `"Yb"` (a real sapling model name). No test was added for the `bake()` slope-adaptive logic or the sapling stream-ordering guarantee itself — both are Studio-only/live-raycast behavior in `scatterPreserve.luau`, untestable under Lune; the stream-ordering guarantee is exercised by ZoneScatter's own `ZoneScatter.spec.luau` (source of truth, part of the Lune suite below) and mirrored here by inspection + `diff`.

### Verification

```
lune run tests/run
# 741 passed, 0 failed, 741 total   (740 was the coordinator's baseline before
# the one additional recipe-level sapling test added here)

stylua --check src tools tests
# exit 0

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

Self-diff: `diff` of the extracted `grove = { ... }` blocks in both recipe
files (no output, byte-identical) and `diff` of the sapling-roll block in
`ZoneScatter.luau` vs `scatterPreserve.luau` (no output, byte-identical).
`scatterPreserve.luau` itself was NOT run — it is Studio-only and cannot
execute under Lune; verification is lint + the diffs above, per the standing
constraint on this file.

### Commit

`feat(roblox): mirror saplings, bigger groves, slope-adaptive planting depth`

---

## Follow-up (2026-07-31 #3, final): grove member retries + fewer/fuller reshape

Last increment for this feature, same three files.

### 1. Grove member retries mirrored (commit 789c70b in ZoneScatter.luau)

`ZoneScatter.luau`'s `GroveConfig` gained an optional `memberTries: number?`
(default 1 = old single-shot behavior): each member SLOT now gets up to
`memberTries` fresh dart attempts, the first that clears every gate places
and the slot stops retrying (`break`), instead of a single rejected dart
abandoning the slot outright. The stream-ordering discipline this preserves
(read carefully from the source, since it's the whole point of the change):
position rolls (`ang`, `rad` -> `mx`, `mz`) are drawn **fresh on every
attempt**, but species/sapling/yaw/scale rolls are only drawn on the
**successful** attempt, inside the same gate sequence as before (nil-sample
-> keepOut -> accepts -> spacing -> species pick -> sapling swap -> yaw/scale
-> insert -> break). A slot that succeeds on try 1 draws exactly the rolls it
always did — `memberTries=1` reproduces the pre-existing stream bit-for-bit.

Mirrored into `scatterPreserve.luau` identically: wrapped the member-slot
body in `for _ = 1, memberTries do ... break end` (with `local memberTries =
grove.memberTries or 1` declared once before the `for _ = 2, memberCount do`
loop), every `continue` inside now retries the same slot rather than
abandoning it, and the successful branch still ends in `break`. Comments
matched verbatim to ZoneScatter's ("each slot gets up to `memberTries` fresh
dart attempts...", "sapling roll: always drawn **on a successful attempt**...").
Confirmed via `diff` of the two `local memberTries = grove.memberTries or 1`
... `end` blocks: no output, byte-identical.

`GroveConfig` type (local in `scatterPreserve.luau`, exported in
`foliageZoneRecipes.luau`) gained the matching `memberTries: number?` field
with the same comment in both files.

### 2. Recipe reshape (both tables, identical)

`PreserveCore.grove`:
- `maxGroves` 12 -> 6.
- `membersMin` 3 -> 5 (membersMax stays 10).
- `radiusMax` 16 -> 20 (radiusMin stays 8).
- Added `memberTries = 6`.
- `spacing` (55), `memberSpacing` (7), `dominantScale` (1.25), `anchorDarts`
  (300), and `saplings` all left unchanged, per the coordinator's spec.
- Comment appended: "gate feedback (2026-07-31, again): fewer, fuller stands;
  slots retry for ground."

Confirmed identical between `foliageZoneRecipes.luau` and
`scatterPreserve.luau`'s `RECIPES` via `diff` of the extracted `grove = { ... }`
blocks (no output = byte-identical, covers all fields including the retained
ones).

### Test coverage added

`FoliageZoneRecipes.spec.luau` — one new test in the `describe("grove
pre-pass", ...)` block: `"PreserveCore reshaped to fewer, fuller groves with
member retries"` — asserts `maxGroves == 6`, `membersMin == 5`, `radiusMax ==
20`, `memberTries == 6` and `memberTries > 0`. The existing `membersMax ==
10` and `membersMin >= 2` assertions in earlier tests still hold unchanged
(no regression). No test was added for the retry LOOP mechanics themselves —
that behavior lives entirely in the planner (Studio-only in this file,
untestable under Lune); it's covered by ZoneScatter's own
`ZoneScatter.spec.luau` (source of truth, already part of the Lune suite
below) and mirrored here by inspection + `diff`.

### Verification

```
lune run tests/run
# 744 passed, 0 failed, 744 total   (743 was the coordinator's baseline
# before the one additional recipe-level reshape test added here)

stylua --check src tools tests
# exit 0

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

Self-diff: `diff` of the extracted `grove = { ... }` blocks in both recipe
files (no output, byte-identical) and `diff` of the member-retry loop
(`local memberTries = grove.memberTries or 1` through its closing `end`) in
`ZoneScatter.luau` vs `scatterPreserve.luau` (no output, byte-identical).
`scatterPreserve.luau` itself was NOT run — Studio-only, cannot execute under
Lune; verification is lint + the diffs above, per the standing constraint on
this file.

### Commit

`feat(roblox): fewer fuller groves - mirror retries + reshape`

---

## Follow-up (2026-07-31 #4, final): free-mix groves — the sugi stand seats all six

Last increment for this feature, same three files. Note: between this
increment and the previous one, other commits landed directly on the branch
(`ee5d664` tune, `f7dec34`/`d87e2d8` adding the `SugiStand` recipe) that
already touched both recipe mirror files and the spec — those are pre-existing
state this increment builds on top of, not part of this diff.

### 1. Free-mix groves mirrored (commit 0b2cf5d in ZoneScatter.luau)

`ZoneScatter.luau`'s `GroveConfig` gained an optional `coherent: boolean?`
(default/nil = true = the ordinary coherent dominant/attendant grove). When
`coherent == false` ("free-mix"), every placement — elder included — draws
its species independently from the full pool instead of the dominant/
attendant pair. The stream-ordering note from the source (reproduced here
since it's the point of the change): free-mix draws exactly **one** species
roll per member including the elder, and the dominant/attendant rolls never
enter the stream in that mode — "draw only what's used." A coherent grove's
stream is completely unchanged (same two rolls for dom/att, same per-member
attendant-threshold roll).

Mirrored into `scatterPreserve.luau` identically, two sites:
- Elder/anchor species selection: replaced the unconditional dominant+
  attendant pick with `local coherent = grove.coherent ~= false` then an
  `if coherent then ... else elderSpecies, elderScale = pickSpecies(recipe.pool, groveRoll(zone)) end`
  branch — coherent computes `domSpecies`/`domScale`/`attSpecies`/`attScale`
  and aliases `elderSpecies, elderScale = domSpecies, domScale`; free-mix
  computes only `elderSpecies`/`elderScale` via a single independent roll.
  The elder placement's `species =` and `scale =` fields now reference
  `elderSpecies`/`elderScale` instead of `domSpecies`/`domScale`.
- Member species selection: `if coherent then <old dom/att-threshold logic> else mSpecies, mScale = pickSpecies(recipe.pool, groveRoll(zone)) end`.

Confirmed via `diff` of both blocks against `ZoneScatter.luau`: the member
species selector is byte-identical; the elder/anchor block differs in exactly
one line — `local attPool: { { name: string, weight: number, scale: number? } } = {}`
in ZoneScatter vs `local attPool: { Species } = {}` in `scatterPreserve.luau`,
which is the file's pre-existing `Species` type-alias convention already
established in the original grove mirror (not a fidelity gap).

`GroveConfig` type (local in `scatterPreserve.luau`, exported in
`foliageZoneRecipes.luau`) gained the matching `coherent: boolean?` field
with the same comment in both files.

### 2. Recipe change (both tables, identical)

`SugiStand.grove` gains `coherent = false,` (placed after the existing
`memberTries = 8,` line, before `saplings = {`), with the comment "free-mix:
hero stand draws all six sculpted variants." `PreserveCore.grove` is
untouched — it stays coherent (default/nil), as it should: only the sugi hero
stand wants the fully-mixed read. Confirmed identical between
`foliageZoneRecipes.luau` and `scatterPreserve.luau` via `diff` of the
extracted `SugiStand = { ... }` blocks (no output = byte-identical).

### Test coverage added

`FoliageZoneRecipes.spec.luau` — one new test in the `describe("grove
pre-pass", ...)` block: `"SugiStand free-mixes; PreserveCore stays coherent"`
— asserts `Recipes.SugiStand.grove.coherent == false` and
`Recipes.PreserveCore.grove.coherent` is `nil` or `true`. No test was added
for the free-mix stream mechanics themselves (which species get drawn in
which mode) — that's Studio-only/planner behavior in this file, untestable
under Lune; it's covered by ZoneScatter's own `ZoneScatter.spec.luau` (source
of truth, already part of the Lune suite below) and mirrored here by
inspection + `diff`.

### Verification

```
lune run tests/run
# 748 passed, 0 failed, 748 total   (747 was the coordinator's baseline
# before the one additional recipe-level coherent test added here)

stylua --check src tools tests
# exit 0

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

Self-diff: `diff` of the extracted `SugiStand = { ... }` grove blocks in both
recipe files (no output, byte-identical); `diff` of the member species-select
`if coherent then ... end` block in `ZoneScatter.luau` vs
`scatterPreserve.luau` (no output, byte-identical); `diff` of the elder/anchor
species-select block (one line differs, the file's pre-existing `Species`
type-alias convention, not a fidelity gap). `scatterPreserve.luau` itself was
NOT run — Studio-only, cannot execute under Lune; verification is lint + the
diffs above, per the standing constraint on this file.

### Commit

`feat(roblox): mirror free-mix - the sugi stand seats all six`

---

## Follow-up (2026-07-31 #5, final): centre-seeking single-grove anchors + adult-heavy sugi stand

Last increment for this feature, same three files.

### 1. Centre-seeking anchors mirrored (commit 19b0fcf in ZoneScatter.luau)

`ZoneScatter.luau` refactored the anchor-placement body into a shared
`placeGrove(ax, az, gs)` local function (moving the `coherent` computation up
one level, since it no longer needs to be recomputed inside the anchor loop),
then split anchor SELECTION into two strategies:
- **multi-grove** (`maxGroves ~= 1`, the pre-existing behavior): unchanged
  first-accept dart-throw with inter-anchor spacing, now calling
  `placeGrove(ax, az, gs)` on acceptance instead of inlining the placement
  logic.
- **single-grove** (`maxGroves == 1`, NEW): a user-placed stand needs to land
  near the zone's marked centre, not wherever the first passing dart happens
  to fall (which could be hard against a zone edge). This path evaluates
  **every** dart in the budget (no early `break` on first success), drawing
  position rolls exactly as before regardless of acceptance, and keeps
  whichever accepted candidate is closest (squared distance, no `sqrt`) to
  the zone's centroid `(cx, cz) = ((x1+x2)/2, (z1+z2)/2)`. After the full
  scan, `placeGrove` is called once on the best candidate if one was found.

Mirrored into `scatterPreserve.luau` identically: extracted the same
`placeGrove(ax: number, az: number, gs: Sample)` local function (with the
`coherent` computation hoisted above it, right after
`groveStates[zone] = seedState(...)`), then the same
`if grove.maxGroves == 1 then <centre-seeking> else <unchanged multi-grove, now calling placeGrove> end`
split. Comments matched verbatim to ZoneScatter's ("plants one grove (elder +
members) at an anchor that already cleared every site gate...", "CENTER-
SEEKING: a single-grove zone represents a user-placed stand...").

Confirmed via `diff` of the full grove pre-pass block (from
`local grove = recipe.grove :: GroveConfig` through the `groveIndex` line) in
both files: only two differences, both pre-existing established conventions
(the file's local `Species` type alias in the attendant-pool declaration, and
local `indexWater(...)` vs `ZoneScatter.indexWater(...)`) — no logic
divergence.

### 2. Recipe change (both tables, identical)

`SugiStand.grove`:
- `membersMin` 5 -> 7.
- `membersMax` 8 -> 10.
- `saplings.chance` 0.35 -> 0.25.
- `spacing` (30), `radiusMin`/`radiusMax` (4/12), `memberSpacing` (5),
  `dominantScale` (1.2), `anchorDarts` (200), `maxGroves` (1, unchanged —
  this is exactly the value that triggers the new centre-seeking path),
  `memberTries` (8), and `coherent = false` all left unchanged, per the
  coordinator's spec.
- Comment added: "gate feedback (2026-07-31): adult-heavy shrine stand
  centred on the user's mark."

Confirmed identical between `foliageZoneRecipes.luau` and
`scatterPreserve.luau`'s `RECIPES` via `diff` of the extracted
`SugiStand = { ... }` blocks (no output = byte-identical).

### Test coverage added

`FoliageZoneRecipes.spec.luau` — one new test in the `describe("grove
pre-pass", ...)` block: `"SugiStand is adult-heavy and single-grove
(centre-seeking)"` — asserts `maxGroves == 1` (the trigger condition for
centre-seeking anchor selection), `membersMin == 7`, `membersMax == 10`, and
`saplings.chance == 0.25`. No test was added for the centre-seeking distance
comparison itself (which candidate wins when multiple darts pass) — that's
Studio-only/planner behavior in this file, untestable under Lune; it's
covered by ZoneScatter's own `ZoneScatter.spec.luau` (source of truth,
already part of the Lune suite below) and mirrored here by inspection +
`diff`.

### Verification

```
lune run tests/run
# 752 passed, 0 failed, 752 total   (751 was the coordinator's baseline
# before the one additional recipe-level test added here)

stylua --check src tools tests
# exit 0

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

Self-diff: `diff` of the extracted `SugiStand = { ... }` grove blocks in both
recipe files (no output, byte-identical); `diff` of the entire grove pre-pass
block (`local grove = recipe.grove :: GroveConfig` through `local groveIndex
= indexWater(groveAnchors)`) in `ZoneScatter.luau` vs `scatterPreserve.luau`
(two differences, both pre-existing established local-naming conventions —
`Species` type alias and unqualified `indexWater` — no logic divergence).
`scatterPreserve.luau` itself was NOT run — Studio-only, cannot execute under
Lune; verification is lint + the diffs above, per the standing constraint on
this file.

### Commit

`feat(roblox): mirror centre-seek + adult-heavy sugi stand`

---

## Follow-up (2026-07-31 #6, final): exhaustive grove placement

Last increment for this feature. Scope this time was narrower than prior
rounds: `scatterPreserve.luau` only — the coordinator's brief said "no recipe
value changes this time," so `foliageZoneRecipes.luau` is untouched. The new
`GroveConfig` field-deprecation comments (below) also live only in
`scatterPreserve.luau`'s inline mirror, matching where they live in
`ZoneScatter.luau` — they document planner behavior (which fields the LCG
stream reads), not recipe data, and `foliageZoneRecipes.luau` is pure data
with no LCG/planner logic of its own to document.

### Exhaustive placement mirrored (commit 3fdbbff in ZoneScatter.luau)

This is a full replacement of the dart-throwing grove placement strategy with
an exhaustive, candidate-pool one. Summary of the source's own framing
(reproduced since it explains the "why"): a single-dart-per-slot design left
legal ground unused while stands starved — confirmed in-world as a grove
anchored at a zone edge because the centre's one dart happened to fail
`pathMargin`. The fix: every terrain sample that clears the site gates is now
a placement **candidate**, and anchors/members are chosen from that pool by
**support** (density) and **proximity**, never by hoping a random throw lands
well. `anchorDarts`, `radiusMin`, and `memberTries` are now dead fields —
kept in the type (with `DEPRECATED / unused` comments) purely so existing
recipe literals don't need to drop them.

Mirrored into `scatterPreserve.luau`'s inline planner, matching ZoneScatter
piece for piece:
- `GroveConfig` type: added the `DEPRECATED / unused` comment blocks on
  `radiusMin`, `anchorDarts`, and `memberTries`, and reworded `radiusMax`'s
  comment to describe its new dual role as the support radius.
- New module-level constant `GROVE_JITTER_MAX = 1.2` (every grove placement
  is now a literal terrain grid point until jittered up to this many studs
  per axis, so groves don't read as trees standing on a lattice).
- Per-zone, before the placement loop: build a `candidates: { Sample }` list
  — every sample from `ordered` that passes `contains` + `not keepOutAt` +
  `accepts` for this zone's recipe — replacing the old dart-throw's implicit
  per-attempt gate checks.
- `supportOf(c)`: counts other remaining candidates within `radiusMax` of
  `c`, against the CURRENT (shrinking) candidate pool — so ground already
  claimed by an earlier grove in the same zone doesn't inflate a later
  grove's odds.
- `removeCandidate(target)`: removes a candidate from the pool by identity
  once it's been placed (elder or member).
- `jitter()`: one `groveRoll(zone)` draw mapped to `±GROVE_JITTER_MAX`.
- `placeGrove(anchor: Sample, memberTarget: number)`: reworked signature
  (was `(ax, az, gs)`, now takes the candidate `Sample` directly and an
  explicit member-count target rolled by the caller). Removes the anchor
  from `candidates`, does the coherent/free-mix elder species pick exactly
  as before, then plants the elder jittered off the anchor's exact grid
  point. The member loop is now `while placedCount < memberTarget do`:
  greedily takes the unused candidate NEAREST the anchor (within
  `radiusMax`) that clears `memberSpacing` against every already-placed
  member of THIS grove (a new `groveMembers` list scoped to the grove, not
  the whole `out` array — so one grove's members can't sterilise a tight
  legal patch for another), removes it from `candidates`, then runs the same
  coherent/free-mix member species pick + sapling swap + jittered placement
  as before. No candidate found near the anchor → the grove ends short of
  its target rather than fabricating ground (`break`, not an error).
- Anchor SELECTION, replacing the old dart-throw loops entirely with
  `while #zoneAnchors < grove.maxGroves and #candidates > 0 do`:
  - `memberTarget` is rolled once per iteration, BEFORE the anchor is chosen
    (single-grove zones need it for anchor eligibility; multi-grove zones
    just carry it forward).
  - **single-grove** (`maxGroves == 1`): among candidates with support
    `>= memberTarget - 1` (enough legal neighbors to reach the full target),
    pick the one nearest the zone centroid `(cx, cz)`; if no candidate has
    enough support, fall back to whichever has the MOST support (a partial
    grove beats none).
  - **multi-grove**: greedily, among candidates clearing `grove.spacing`
    from every prior anchor in this zone, pick the one with the most
    support; stop entirely once even the best remaining candidate can't
    support a minimally viable grove (`support < membersMin - 1`) — real
    meadow gaps, not an artifact of running out of darts.
  - `placeGrove(anchor, memberTarget)` is called once an anchor is chosen;
    the loop then re-evaluates from the shrunk candidate pool.

### Self-diff verification

Extracted the full grove pre-pass block from both files (from the
`-- grove pre-pass: species-coherent clumps...` comment through the
`groveIndex = ...indexWater(groveAnchors)` line — 270 lines in each) and
diffed them directly. Two differences, both pre-existing established
local-naming conventions from earlier mirror rounds, no logic divergence:
- `local attPool: { { name: string, weight: number, scale: number? } } = {}`
  (ZoneScatter) vs `local attPool: { Species } = {}` (scatterPreserve's
  established `Species` type alias).
- `ZoneScatter.indexWater(groveAnchors)` vs the local unqualified
  `indexWater(groveAnchors)`.

Also confirmed the `GroveConfig` type block is diff-identical (modulo the
`export` keyword ZoneScatter uses and scatterPreserve doesn't, per that
file's existing local-type convention) and the `GROVE_JITTER_MAX` constant
and its one call site match exactly in both files.

### Test coverage

No test changes — the coordinator specified no recipe value changes, and the
Lune suite already sat at 753 (matching the stated baseline) with no new
assertions needed; the existing "grove pre-pass" describe block's assertions
are all against recipe DATA (spacing, membersMin/Max, saplings, coherent),
none of which changed, so they continue to pass unmodified. The exhaustive
placement ALGORITHM itself (support scoring, candidate-pool shrinkage,
centre-seeking vs greedy-support anchor selection) is Studio-only/planner
behavior in this file, untestable under Lune; it's covered by ZoneScatter's
own `ZoneScatter.spec.luau` (source of truth, already part of the Lune suite
below) and mirrored here by inspection + the diffs above.

### Verification

```
lune run tests/run
# 753 passed, 0 failed, 753 total   (matches the coordinator's stated
# baseline exactly — no test changes made)

stylua --check src tools tests
# exit 0

selene src tools
# 0 errors, 0 warnings, 0 parse errors
```

`scatterPreserve.luau` itself was NOT run — Studio-only, cannot execute under
Lune; verification is lint + the diffs above, per the standing constraint on
this file. `foliageZoneRecipes.luau` was not touched this round (no recipe
value changes were requested).

### Commit

`feat(roblox): mirror exhaustive grove placement`
