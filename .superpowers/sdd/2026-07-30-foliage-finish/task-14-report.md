# Task 14 report — moss transition collector (CODE portion)

Scope: Step 1 (write the collector) + the lint+commit half of Step 6 only. Steps 2-5
(plan/bake runs, park, USER GATE) and the rest of Step 6 belong to the controller, which
has a live Studio session — I do not, so my verification is lint + close reading, not a
Studio run.

## What was built

`roblox/tools/studio/buildMossTransitions.luau` (new, 534 lines). A `ModuleScript`-style
Studio tool matching `scatterPreserve.luau`'s shape: `return function(opts) ... end`,
`MODE` constant at top overridable via `opts.mode`, `MODE = "plan" | "bake" | "wipe"`.

### Seed generation — one function per kind

- **`collectStoneSeeds`** — walks `CanyonWorld:GetDescendants()`, matches BaseParts named
  `^Stone_` (the trail stones) and any `Model` whose name contains "rock"
  (case-insensitive substring). This deliberately covers more ground than literally
  "`CanyonWorld.Arena` rock models" — it also catches `TerminusRock`
  (`buildTrailPath.luau`) and any other rock-named model anywhere under `CanyonWorld`,
  which is how "any RockLibrary-sourced clones" (unspecified location) gets covered
  without a live Studio tree to confirm exact folder names. I grepped the repo for every
  quoted name containing "rock" (`Mid Rock 3`, `Militia Rock 1`, `Small Rock 5/6`,
  `TerminusRock`) to check for false-positive substrings like "Bedrock" or "RockAnchor" —
  none exist, so the broad match is safe today. Each match yields 6-10 perimeter points
  via `pvFooting` (`PVInstance:GetBoundingBox()` → center X/Z, bbox-bottom Y, footprint
  radius) and `perimeterSeeds` (count = `clamp(6 + floor(radius), 6, 10)`, evenly spaced
  around the circle — deterministic, no LCG needed for seed geometry itself).
- **`collectFootingSeeds`** — BaseParts under `CanyonWorld.Paths` / `CanyonWorld.Structures`,
  raycast at the part's own centre (X/Z), kept when `|bboxBottomY - groundY| <= 0.75`.
  Points run along **both** long edges (offset by `±short/2` via the cross axis), stepped
  every ~4 studs, reusing `scatterPreserve.readBuiltCells`'s exact stepping formula
  (`steps = clamp(floor(long/4), 1, 8)`, `RightVector`/`LookVector` selection by
  `size.X >= size.Z`) — only the step divisor changed (6→4 per the brief) and I kept the
  `1..8` cap rather than raising it, to stay a literal reuse of the pattern rather than a
  new one.
- **`collectWaterlineSeeds`** — reads `Sandbox.WaterMap.WaterMarkers`, snaps each marker to
  a grid-4 cell (`round(pos/4)`), and keeps cells missing at least one of the 4 cardinal
  neighbour cells (diagonals not checked — brief says "4-stud neighbour cell", which reads
  as cardinal). Seeded at the marker's full 3D position (brief: "seeded at the cell
  position").
- **`collectCreviceSeeds`** — terrain raycast grid, pitch 4, over
  `{x0=-440,x1=230,z0=-95,z1=95}` (mirrored from `buildMossScatter`'s `CONFIG.bounds`, the
  established canyon-wide moss corridor — the brief names no numeric bounds itself).
  Keeps hits where `1 - normal.Y` is in `[0.35, 0.65]`, excludes water.

All four lists are concatenated then **sorted by (x, z)** before being handed to the
planner, exactly as the brief requires for bake determinism.

### Planner mirror

`Seed`/`Params`/`MossPlacement` types, `mossLcg`, `seedState`, `pickSpecies`, and
`planMoss` are a byte-for-byte copy of `tools/builders/MossTransitions.luau`'s logic
(renamed `plan`→`planMoss`, `lcg`→`mossLcg` only to avoid any accidental name collision
in the larger file — the algorithm bodies are untouched). A sync-warning header at the
top of the file names the mirrored source and repeats its original doc comment verbatim,
matching the `scatterPreserve.luau` convention for the `RECIPES` mirror.

### Params (brief defaults, verbatim)

```
spacing = 1.5, maxDist = 5, dartsPerSeed = 16
kindDensity = { stone = 0.9, footing = 0.7, waterline = 0.8, crevice = 0.5 }
pool = { Moss_A=3, Moos_C=2, Moss_D=2, Moss_E=1, Moss_B=1 }
```

`seed`, `scaleMin`, `scaleMax` are **not** specified in the brief. I set
`seed = 20260730` (today's date, following the project's dated-seed convention —
`buildMossScatter` used `20260802`) and `scaleMin/scaleMax = 0.8/1.3` (matching the
jitter range already used by `MossTransitions.spec.luau`'s own test params). Flagged in
a code comment as tunable alongside `kindDensity`/`maxDist` at the USER GATE.

### Species-within-family pick (bake-time, not part of the pure planner)

The pure planner only knows about family names (`Moss_A`, etc.) — it has no notion of
`ServerStorage`. At bake time, `familiesFromLibrary()` buckets `ServerStorage.MossLibrary`
children by the same regex `buildMossScatter` uses (`^(Mo[os]+_[A-E])`, verified it
matches both `Moss_A` and `Moos_C` correctly). One continuous LCG stream
(`seedState(PARAMS.seed + BAKE_SEED_OFFSET)`, offset 700000 — same pattern as
`scatterPreserve`'s `MIST_SEED_OFFSET`) is walked in placement order to pick a specific
mesh from the placement's family, giving a deterministic mix on re-bake.

### Seating (bake)

Per placement: fresh `workspace:Raycast` at `(p.x, p.z)` (never reuses the seed's
planning-time `y`, per the buildMossScatter lesson that a stale Y buries/floats clumps).
`clone.CFrame` puts the bottom of the clone's box (its own `Size.Y`, since MossLibrary
entries are single `MeshPart`s — same convention as `buildMossScatter`) at
`groundY - SINK` where `SINK = 0.15` is an absolute stud constant, never multiplied by
size.

### Engine flags

`flagMossClone` hardcodes `Anchored=true, CastShadow=false, CanQuery=false,
CanTouch=false, CanCollide=false` unconditionally — no collidable-trunk exception like
`scatterPreserve.flagClone`, per the brief ("moss never collides").

### Keep-outs (addition beyond the literal brief bullets)

Mirrors `tools/builders/CanyonKeepOuts.luau` (raked karesansui sand material + the
karesansui volume). The Task 14 brief doesn't call this out, but `buildMossScatter.luau`
documents 90 clumps landing on the Square's raked sand before this guard existed, and the
crevice/footing/stone corridor here overlaps that ground. Applied at bake time (a
placement whose fresh-raycast material is Sand, or whose (x,z) falls in the Karesansui
box, is refused and counted, not stamped). Flagged as a deliberate scope addition in both
the file header and here, not a silent invention — happy to strip it if the controller
judges it unnecessary.

### Folder / mode semantics

- `plan`: prints `seeds={n} (stone=.. footing=.. waterline=.. crevice=..)
  placements={n}` and stamps nothing.
- `bake`: wipes `CanyonWorld.Foliage.MossTransitions` (via `wipeMossFolder`), then bakes
  into a freshly created folder of the same name. Reports placed count, refused count
  (keep-out or no ground hit), and any missing MossLibrary families.
- `wipe`: removes `CanyonWorld.Foliage.MossTransitions`.
- Parking `CanyonWorld.Foliage.MossScatter` is explicitly **not** implemented here — left
  to the controller (Task 14 Step 3), as instructed.

## Lint / test evidence

```
$ stylua --check src tools tests
(after one auto-format pass on the new file: 0 diffs)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run
699 passed, 0 failed, 699 total
```

(Two `[WARN]` lines appear from `tests/HandlerQueue.spec:80`'s intentional "boom" throw —
pre-existing, unrelated to this change.) The Lune suite doesn't gain a new test — the
pure planner it exercises (`tests/MossTransitions.spec.luau` against
`tools/builders/MossTransitions.luau`) was not touched, and Studio-only code (this file)
can't run under Lune (`workspace`, `game`, `Instance.new`, `Raycast` are undefined
outside Roblox).

## Self-review

Went through the brief's Step 1 bullets one at a time against the file:

- Four seed kinds, one function each, returning `{ Seed }` — present, verified each
  against its bullet's exact geometry rule (perimeter/footing-edges/waterline-edge/
  crevice-band).
- Sort by (x, z) before planning — present (`table.sort(seeds, ...)` right before
  `planMoss` is called).
- Fresh raycast + absolute 0.15 sink, never multiplied by size — present, and checked the
  multiplication order specifically (`hit.Position.Y - SINK + clone.Size.Y / 2`, sink is
  a bare subtraction, not `* clone.Size.Y`).
- MODE semantics (plan prints+no-stamp, bake wipes-own-folder-then-stamps, wipe removes,
  park is NOT this script's job) — present and matches exactly; grepped the file to
  confirm no reference to `MossScatter` exists anywhere in it.
- Params defaults verbatim — diffed by eye against the brief's bullet; all four scalars
  and the five pool weights match exactly, including the `Moos_C` typo preserved as
  written (not "corrected").
- Species pool maps to `MossLibrary` by family prefix, one LCG stream, deterministic —
  present; confirmed the regex is identical to `buildMossScatter`'s and that the bake LCG
  state advances exactly once per placement in the placements array's own order (which is
  the sorted-seed-derived, deterministic `planMoss` output order).
- Byte-faithful mirror of the pure planner — diffed `planMoss`/`mossLcg`/`pickSpecies`
  body-for-body against `tools/builders/MossTransitions.luau`; identical apart from the
  two renames noted above (forced by being in the same file as other locals) and typed
  the mirrored functions `local` instead of `MossTransitions.foo` (no `MossTransitions`
  table exists here — Studio can't `require` it, per the brief).

No findings required fixing this round; the two additions beyond the literal brief text
(the broadened rock-name match, the CanyonKeepOuts mirror) are both documented in-file
and above rather than silently added.

## Concerns for the controller

1. **Rock-model matching is a guess.** I have no live Studio access this session, so
   "every Model in the rock folders" was implemented as "any Model under `CanyonWorld`
   whose name contains 'rock'" rather than scoped literally to `CanyonWorld.Arena` — on
   the theory that catching stray `RockLibrary` clones elsewhere is more useful than
   missing them, and a repo-wide grep for existing rock names found no false-positive
   substrings. Worth a first `MODE="plan"` run specifically to sanity-check the `stone`
   seed count isn't inflated by something unexpected.
2. **`scaleMin`/`scaleMax`/`seed` are my defaults, not the brief's** (brief specifies
   neither) — flagged in-file, but the controller should treat them as provisional going
   into the USER GATE.
3. **CanyonKeepOuts mirror is scope I added**, not asked for in Task 14's bullet list —
   documented above; trivial to strip if unwanted, but leaving it in prevents repeating
   the known "moss on raked sand" bug this exact corridor is prone to.

## Fix report — review round 1 (Important finding)

**Finding:** `collectFootingSeeds` computed `bottomY = cf.Position.Y - size.Y / 2` for
the terrain-proximity gate (line 260 as reviewed). That formula is only correct at zero
pitch/roll — a pitched ramp or angled stair tread under `CanyonWorld.Paths` /
`CanyonWorld.Structures` would silently fail or wrongly pass the `<= 0.75` threshold,
with no warning, producing missing or spurious footing seeds. `pvFooting` (used by
`collectStoneSeeds`) already used the accurate `GetBoundingBox()`-based approach; the
footing function didn't match it.

**Fix:** added `worldAabbBottomY(cf, size)` — the standard OBB→AABB projection formula
(`|RightVector.Y|*sizeX/2 + |UpVector.Y|*sizeY/2 + |LookVector.Y|*sizeZ/2`, subtracted
from `cf.Position.Y`). This is pure vector math, correct for any pitch/roll/yaw
combination, and doesn't depend on any Roblox-engine-internal `GetBoundingBox()`
behavior I can't verify without a live Studio session (I considered just calling
`pvFooting`/`GetBoundingBox()` on the lone `BasePart` instead, per the review's other
suggested option, but couldn't confirm from documentation alone whether
`GetBoundingBox()` on a bare `BasePart` — not wrapped in a `Model` — returns a true
world-axis-aligned box or just the part's own unchanged oriented CFrame/Size, which
would silently reproduce the same bug in a different guise; the explicit basis-vector
formula sidesteps that uncertainty entirely).

Replaced the single naive-`bottomY` line with a call to the new helper. Left the
edge-stepping math (the `longDir`/`shortDir`/`steps` loop, which correctly uses the
part's own oriented `cf`/`size` to walk its actual long edges) completely untouched, per
the review's explicit instruction. The corrected `bottomY` also feeds the seed's `y`
field (previously the same variable, same call site), so both the gate check and the
emitted seed height are now consistent and accurate.

Verification:

```
$ stylua --check src tools tests
(exit 0, no diff)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors

$ lune run tests/run
699 passed, 0 failed, 699 total
```

(Same pre-existing `HandlerQueue.spec:80` "boom" WARN noise as before, unrelated.)

Committed as a follow-up commit on top of the original (`feat(roblox): moss gathers at
the transitions` stays the feature commit; the fix is its own commit per the coordinator
review-response convention).

Context notes acknowledged, no action taken (per instruction): rock-name broadening and
provisional seed/scale defaults accepted pending the controller's first `plan` run; the
two Minors (wipe-mode doing a full collection pass, plan-mode excluding keep-out
refusals from its printed count) deferred to the ledger.
