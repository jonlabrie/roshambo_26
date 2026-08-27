# Task: ShoreRocks pure planner (pool-waterline rock clusters)

User-approved insertion before the moss-transition bake: the stepped river pools have
rocky falls/runs but bare pool waterlines, so moss has no rock feet to gather around
there. This task is the PURE PLANNER ONLY: `roblox/tools/builders/ShoreRocks.luau` +
tests appended in a new file `roblox/tests/ShoreRocks.spec.luau`. The Studio
collector/bake mirror is the controller's follow-up; do NOT touch other files.

## Design register (drives every default below)

Ishigumi, not a necklace: asymmetric clustered grouping — one big ANCHOR stone, a few
mid ATTENDANTS, sometimes a small WADER half in the water — separated by long stretches
of deliberately bare bank. Density peaks at each pool's inflow/outfall LIPS (where
moving water actually deposits rock); quiet mid-bank edges get only sparse clusters.

## Module contract

```luau
export type WaterCell = { x: number, z: number, y: number }
export type Params = {
    seed: number,
    cell: number,          -- water-map grid pitch (4)
    sheetTol: number,      -- |dy| <= sheetTol => same water sheet (3)
    lipRadius: number,     -- radius scanned for elevation jumps (10)
    lipMinDrop: number,    -- min |dy| within lipRadius to count as a lip (1.5)
    lipSpacing: number,    -- min distance between lip-cluster anchors (35)
    quietSpacing: number,  -- min distance between quiet-bank anchors AND from lip anchors (55)
    memberRadiusMin: number, -- attendant polar offset from anchor (3)
    memberRadiusMax: number, -- (8)
    memberSpacing: number,   -- min distance between any two placements in the plan (2.5)
    attendantsMin: number,   -- (2)
    attendantsMax: number,   -- (4)
    wadersMax: number,       -- 0..wadersMax waders per cluster, rolled uniformly (2)
    waderReach: number,      -- how far a wader steps toward open water (4)
    scaleMin: number,        -- (0.85)
    scaleMax: number,        -- (1.25)
}
export type RockPlacement = {
    x: number, z: number,
    role: string,   -- "anchor" | "attendant" | "wader"
    yaw: number,    -- radians
    scale: number,
    lip: boolean,   -- true if this cluster was seeded by lip score (for plan reporting)
}
-- keepOut(x, z) -> true blocks; existing = XZ positions of already-placed rocks
-- (falls/run groups) that clusters must stand clear of
local function plan(
    cells: { WaterCell },
    params: Params,
    keepOut: ((number, number) -> boolean)?,
    existing: { { x: number, z: number } }?
): { RockPlacement }
```

Return the module as `{ plan = plan }`.

## Algorithm (exact)

1. **Index** cells by integer grid key `(cx, cz)` where `cx = floor(x / params.cell + 0.5)`
   (same rounding as the water map). A key may hold MULTIPLE cells (pools stack in plan
   view near falls) — store lists.
2. **Edge cells**: a cell is an edge if at least one of its 4 cardinal neighbour keys has
   NO cell within `sheetTol` of its own y (a neighbour on a different sheet does NOT
   count as present — a lip IS an edge). Record the missing direction(s); the FIRST
   missing direction in the fixed order east/west/south/north (+x, -x, +z, -z) is the
   cell's LAND direction; its opposite is the WATER-INWARD direction.
3. **Lip score** per edge cell: max |dy| between the cell and any cell within `lipRadius`
   (XZ euclidean, scan the index in grid-key range). Score >= `lipMinDrop` marks a LIP
   candidate.
4. **Candidate filter**: drop any edge cell where `keepOut(x, z)` is true, or within
   10 studs of any `existing` rock position.
5. **Anchor selection — EXHAUSTIVE, not darts** (the project standard): sort lip
   candidates by (score DESC, then x ASC, z ASC for determinism); greedily accept each
   that stands >= `lipSpacing` from every accepted anchor. Then sort the NON-lip
   candidates by (x ASC, z ASC); greedily accept each that stands >= `quietSpacing` from
   every accepted anchor (lip anchors included). No caps beyond spacing — spacing IS the
   density control.
6. **Cluster growth**, per anchor in acceptance order, all rolls from ONE LCG stream
   seeded `seedState(params.seed)` (the standard `(1103515245 * s + 12345) % 2^31` LCG /
   `seedState(seed) = (seed * 2654435761) % 2^31 + 1` — same constants as the other
   planners; integer only, no math.random):
   - The ANCHOR places at the cell position: `roll` yaw (0..2pi), `roll` scale in
     [scaleMin, scaleMax].
   - Attendant count = integer in [attendantsMin, attendantsMax] by roll. Each
     attendant: polar offset from the anchor (angle roll x 2pi, radius roll in
     [memberRadiusMin, memberRadiusMax]); the spot must (a) pass keepOut, (b) be within
     `params.cell * 1.5` of SOME edge cell of the same plan (stay on the bank — check
     against the edge-cell index), (c) stand >= memberSpacing from every placement
     already in the output. Up to 4 retries per attendant slot (fresh rolls), else the
     slot is abandoned.
   - Wader count = integer in [0, wadersMax] by roll. Each wader starts from the
     anchor's edge cell and steps `roll * waderReach` studs along the WATER-INWARD
     direction (+ a perpendicular jitter of (roll*2-1) * 2 studs); must pass keepOut and
     memberSpacing (waders sit IN water, so no edge-band check). Scale roll is
     multiplied by 0.6 (waders read small).
   - Every placement records the cluster's `lip` flag.
7. **Determinism**: identical inputs => identical output. Roll ORDER is fixed by the
   spec above (yaw, scale, count, then per-slot rolls) so tests can rely on it.

## Tests (RED first, then implement)

New file `roblox/tests/ShoreRocks.spec.luau`, using the existing harness
(`require("./harness")`, `describe/test/expect` — copy the import style of
`roblox/tests/MossTransitions.spec.luau`). Build helper water grids inline (e.g. a
20x5-cell flat pool at y=100, and a two-terrace pool pair at y=100/y=90 sharing a lip
column). Cover at least:

1. Determinism: two identical `plan` calls return identical placement lists.
2. Lip preference: on the two-terrace grid, the first accepted anchor's position is
   within `lipRadius` of the terrace boundary, and its placements carry `lip = true`.
3. Clustering: every attendant/wader lies within `memberRadiusMax + waderReach + 2.5`
   of some anchor; anchors are >= lipSpacing apart (lip pairs) and every non-lip anchor
   is >= quietSpacing from all other anchors.
4. Roles: each cluster has exactly one anchor; attendant count within
   [attendantsMin, attendantsMax]; wader scale < attendant minimum possible scale
   (0.6 * scaleMax < scaleMin is NOT guaranteed by params — instead assert every wader's
   scale <= 0.6 * scaleMax).
5. Keep-out: `keepOut = function(x) return x > 40 end` yields zero placements with
   x > 40.
6. Existing standoff: an `existing` rock at an edge cell suppresses any anchor within
   10 studs of it.
7. Quiet banks are sparse: on the single flat pool (no lips anywhere), with
   quietSpacing 55 and a ~80-stud bank, at most 2 clusters form.
8. Waders sit waterward: on the flat pool, every wader's position is on the WATER side
   of its cluster's edge cell (distance from pool interior centroid is LESS than the
   anchor's, or equivalent directional assertion).

## Constraints

- Work from /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
- `--!strict`; integer LCG only (constants above); no math.random, no os/Date.
- `lune run tests/run` all green (754 existing); lint `stylua --check src tools tests &&
  selene src tools` (selene FAILS on warnings — run from roblox/, rokit-managed).
- Match the file style of `roblox/tools/builders/MossTransitions.luau` (header comment
  explaining the register, exported types, pure functions).
- Commit message: `feat(roblox): shore-rock planner - ishigumi clusters at the pool waterlines`
  ending with:
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Wkn8pmb3GYwsXZrSRnZYNu
