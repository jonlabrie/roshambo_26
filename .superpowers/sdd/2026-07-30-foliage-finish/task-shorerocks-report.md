# Task report: ShoreRocks pure planner

Commit: `4e6c01d3d11a1913a476710cf7696268a3221ffa` on branch `m4b-zendojo-art-pass`
("feat(roblox): shore-rock planner - ishigumi clusters at the pool waterlines")

Files touched (exactly the two named in the brief):
- `roblox/tools/builders/ShoreRocks.luau` (new, 368 lines)
- `roblox/tests/ShoreRocks.spec.luau` (new, 209 lines)

## What was built

A pure, deterministic Luau planner `ShoreRocks.plan(cells, params, keepOut?, existing?)`
implementing the exact algorithm in the brief:

1. **Grid index** — `WaterCell`s bucketed by string key `` `{cx},{cz}` `` using
   `cx = floor(x/cell + 0.5)` (matches the water-map rounding convention used
   elsewhere in the codebase, e.g. `ZoneScatter.indexSamples`). A key's bucket is a
   list, so stacked terraces at the same XZ column (different y) coexist.
2. **Edge detection** — per cell, walk the four cardinal directions in the fixed
   order east/west/south/north (`+x,-x,+z,-z`); a direction is "missing" if the
   neighbour key's bucket has no cell within `sheetTol` of the cell's own y. The
   first missing direction is recorded as `landDx/landDz`; its negation is the
   water-inward direction used later for wader placement.
3. **Lip score** — for each edge cell, the max `|dy|` to any cell within
   `lipRadius` (XZ euclidean), found by scanning only the grid-key range
   `ceil(lipRadius/cell)` around the cell (not a full O(n²) scan). Score
   `>= lipMinDrop` marks a lip candidate.
4. **Candidate filter** — drop cells where `keepOut(x,z)` is true or within 10
   studs (squared-distance test, `<= 100`) of any `existing` rock.
5. **Anchor selection** — lip candidates sorted `(score DESC, x ASC, z ASC)`,
   greedily accepted at `>= lipSpacing` from prior anchors; then non-lip
   candidates sorted `(x ASC, z ASC)`, greedily accepted at `>= quietSpacing`
   from *all* anchors accepted so far (lip anchors included). Anchors are
   appended into one ordered list — lip anchors first, in acceptance order,
   then quiet anchors, in acceptance order — which is also the roll order for
   step 6.
6. **Cluster growth** — one continuous LCG stream, seeded via
   `seedState(seed) = (seed * 2654435761) % 2^31 + 1`, `lcg(state) = (1103515245*state + 12345) % 2^31`,
   consumed in anchor-acceptance order:
   - anchor: yaw roll, scale roll.
   - attendant count: `attendantsMin + floor(roll() * (attendantsMax - attendantsMin + 1))`
     (same integer-in-range idiom as `ZoneScatter`'s `memberTarget`). Each
     attendant slot rolls angle, radius, yaw, scale, checks keepOut / bank-band
     (`cell*1.5` of some edge cell, via a second bucketed index built from all
     edge cells) / memberSpacing-vs-output, up to 4 retries, else abandoned.
   - wader count: `floor(roll() * (wadersMax + 1))` (uniform 0..wadersMax). Each
     wader rolls step, perpendicular jitter, yaw, scale; steps
     `step` studs along the water-inward unit vector plus `(jitter*2-1)*2`
     studs along its perpendicular; checked against keepOut and memberSpacing
     only (no bank-band check, per spec); no retries (a rejected wader is
     simply dropped, consuming its rolls — preserves the stream for later
     anchors).
   - every placement in a cluster carries the cluster's `lip` flag.

Returned as `{ plan = plan }` per the brief's module contract.

## Design decisions inside the brief's latitude

The brief's §7 "Determinism" note ("Roll order is fixed... yaw, scale, count,
then per-slot rolls") states the *anchor-block* order but doesn't spell out
every per-slot roll's internal order for attendants/waders (attendants clearly
need a yaw+scale roll to fill `RockPlacement` but the prose only mentions
angle+radius; waders' prose mentions step+jitter+scale but not yaw). I chose:

- **Attendant per-slot order**: angle, radius, yaw, scale (position rolls
  first, then orientation/size, mirroring the anchor's own yaw-then-scale
  tail).
- **Wader per-slot order**: step, jitter, yaw, scale (same shape).

This only affects the *specific* numeric sequence for a given seed, not any
externally-specified value — nothing in the brief or tests pins exact
roll-for-roll output, only internal-consistency properties (determinism,
spacing invariants, role bounds, keepOut/existing exclusion, lip flagging).
I verified this choice by running the suite; all listed invariants hold.

A second small latitude call: the "edge-cell index" used for the attendant
bank-band check is built from **all** edge cells found in step 2, not
narrowed by the `keepOut`/`existing` candidate filter — i.e. it represents
the bank's geometry, independent of where rocks are permitted to sit. This
reads as the more natural interpretation of "edge cell of the same plan."

## Tests (8, all in `roblox/tests/ShoreRocks.spec.luau`)

1. Determinism — two identical `plan()` calls on the two-terrace grid produce
   identical placement lists (x/z/yaw/scale via `toBeCloseTo`, role/lip via
   `toBe`).
2. Lip preference — on a two-terrace grid (upper terrace y=100 at z=0,4,8;
   lower terrace y=90 at z=8,12,16,20,24, sharing a stacked column at z=8),
   the first accepted anchor sits within `lipRadius` of the shared boundary
   (z=8) and is flagged `lip = true`.
3. Clustering — every non-anchor placement lies within
   `memberRadiusMax + waderReach + 2.5` of *some* anchor; for every anchor
   pair, lip-lip pairs are `>= lipSpacing` apart, and any pair involving a
   non-lip anchor is `>= quietSpacing` apart (this directly encodes the
   algorithm's own acceptance invariant, so it's guaranteed by construction
   rather than RNG-dependent — a genuine regression check).
4. Roles — sequential scan of the output groups each anchor with its
   following attendants/waders; asserts exactly one anchor starts each group,
   attendant count `<= attendantsMax`, and every wader's `scale <= 0.6 * scaleMax`.
5. Keep-out — `keepOut = x -> x > 40` on the flat pool yields zero placements
   (of any role) with `x > 40`; true by construction since every insertion
   site (anchor candidate, attendant retry, wader) re-checks `keepOut`.
6. Existing standoff — an `existing` rock at `(0,0)` suppresses any anchor
   within 10 studs (squared-distance `>= 100` asserted for all anchors).
7. Quiet-bank sparsity — on a 20x5-cell (76x16-stud) flat pool with no
   elevation drop anywhere (all candidates quiet, `quietSpacing = 55`), at
   most 2 anchors form, and all are `lip = false`. Hand-traced the sort/accept
   order to confirm this grid produces exactly 2 (at `(0,0)` and `(56,0)`).
8. Waders sit waterward — on the flat pool, for every wader, its distance to
   the pool's interior centroid `(38,8)` is less than its anchor's distance to
   that centroid. Because wader count is itself a roll (`0..wadersMax`), I
   probed seeds 1..40 offline (scratch script, not committed) to find one
   (`seed = 12`, override of the shared `PARAMS` via `table.clone`) that
   reliably produces at least one wader on this grid, so the assertion is
   never vacuously true — the test also asserts `sawWader` directly as a
   belt-and-braces guard.

## Test/lint output

RED confirmed first (module didn't exist yet):
```
error requiring module "../tools/builders/ShoreRocks": could not resolve child component "ShoreRocks"
```

GREEN after implementation, from `lune run tests/run` (run from `roblox/`):
```
762 passed, 0 failed, 762 total
```
(754 baseline + 8 new ShoreRocks tests = 762; the `[WARN] [QUEUE] ...` lines
in the output are pre-existing intentional noise from
`HandlerQueue.spec.luau`, unrelated to this change.)

Lint, from `roblox/`:
```
stylua --check src tools tests   -> exit 0 (clean; one auto-format applied
                                     during dev to ShoreRocks.luau for a
                                     wrapped function signature and a
                                     wrapped arithmetic expression, both
                                     fixed by running stylua directly on the
                                     file before the final --check pass)
selene src tools                 -> 0 errors, 0 warnings, 0 parse errors
```
(Initial selene pass flagged one warning: an unused `local ShoreRocks = {}`
table I'd declared out of habit before switching to the brief's literal
`return { plan = plan }` contract — removed, since `plan` is a plain local
function and the module has no other exports.)

## Concerns

- **Unrelated pre-existing diff**: `git status` shows
  `roblox/tools/blender/export_forest_kit.sh` modified (adds Maple/Katsura/
  Bamboo accent export lines) — present before I touched anything and left
  untouched throughout; not staged or committed by me. Flagging in case it's
  orphaned work from another session that still needs a commit.
- **Roll-order latitude** (see above): if the eventual Studio
  collector/bake mirror or any golden-value expectation elsewhere assumes a
  *specific* per-slot roll order for attendants/waders, it should match what
  I picked (angle, radius, yaw, scale for attendants; step, jitter, yaw,
  scale for waders) or be treated as free to diverge, since no test anywhere
  pins literal numeric output.
- No Luau mirror/fixture sync concern here (unlike `GameRules.luau`) — this
  planner has no server-side TypeScript counterpart per the brief.
