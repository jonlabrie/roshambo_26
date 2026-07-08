# Roshambo Site-Fit Machinery — Design (sub-project D, increment 6.1)

**Status:** design approved in brainstorm (2026-07-08); pre-planning. First slice of D.6 (perch migration). **Pure Luau + Lune only** — no Studio, no visual gate.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** D.4 baked 3 surveyed sites into `PadSites` with a `maxSize` derived from *terrain* alone (largest teahouse the perch's terrain supports on posts, no void corners). At the D.4 gate we found terrain-max is insufficient — a larger footprint can encroach on a neighbor's access path or adjacent teahouse — so the baked `maxSize` values are **provisional**. The D.4 final review also flagged **F1** (pitched decks would skew `PadOps`' single ray-origin) and **F3** (dead `PadRegistry`/`SizeClasses` code). D.6.1 builds the reusable, testable machinery to resolve all three; the Studio survey that *uses* it (produce keep-outs, re-bake `PadSites`, retire legacy geometry, Far Wall access) is a later increment.

## Problem

1. **Spacing/encroachment.** A site's real max size is `min(terrain-max, spacing-max)`, where spacing-max is the largest footprint that doesn't overlap neighbor footprints or access-path corridors. There is no spacing check today.
2. **F1 — deck pitch.** `PadPlanner` already computes a per-corner datum (`top = xf(mountCF, px, 0, pz)`), but `PadOps.raycastGround` rays from a single `mountCF.Y + 250` for all corners. These coincide only for **yaw-only** (level) mounts; a pitched deck skews embed/void classification.
3. **F3 — dead code.** `PadRegistry.fits/findVacant/claimVacant/claimVacantFor` and `SizeClasses.nativeSize` are unreferenced (confirmed) after D.4/D.5.

## Decisions (from brainstorm)

- **Enforce yaw-only decks** (teahouse floors are level). Validate/flatten mounts to pure yaw; `PadOps` stays as-is. No per-corner-datum plumbing (YAGNI).
- **Spacing via OBB-SAT.** Footprints are yaw-rotated rectangles; overlap is Separating-Axis-Theorem on oriented boxes, not axis-aligned bounds (which would over-shrink pads).
- **One cohesive module** `src/shared/PadSiteFit.luau` for all three helpers (spacing, level, min-resolve) — the survey-support math.
- **`spacingMax` returns `nil`** when even S collides (a bad site the survey flags), rather than silently returning S.

## Non-goals (the later Studio increment)

- The MCP/Studio survey that produces keep-outs (neighbor footprints + path corridors) and re-bakes `PadSites` with `maxSize = min(terrain, spacing)`.
- Retiring the 14 legacy `CanyonTeahouses` (place-only geometry).
- Far Wall access paths + terrain-clearing.
- Wiring `PadSiteFit` into `SiteCoordinator`/the survey. D.6.1 ships pure functions + tests; nothing consumes them yet.

## Architecture

### New module — `src/shared/PadSiteFit.luau` (pure, Lune-tested)

Types (world-XZ, all 2D):
```
type Point = { number }              -- {x, z}
type OBB = { Point }                 -- 4 corners, consistent winding
type Footprint = SizeClasses.Footprint  -- { minX, maxX, minZ, maxZ }
```

Functions:
- `footprintOBB(footprint: Footprint, mountCF: { number }) -> OBB` — the 4 footprint corners transformed into world XZ by `mountCF` (reusing the `xf` transform from `PadPlanner`, keeping X and Z outputs). Produces both the candidate site OBB and, for the survey, neighbor keep-out OBBs.
- `overlaps(a: OBB, b: OBB) -> boolean` — SAT over the 4 edge-normal axes (2 per rectangle): project both boxes' corners onto each axis; if any axis separates the projections → `false`; else `true`. The meaty unit-tested geometry. (Basic ops only — no trig — so it's arch-stable.)
- `spacingMax(mountCF: { number }, keepOuts: { OBB }) -> string?` — for each `size` in `SizeClasses.order` (L→M→S): `obb = footprintOBB(SizeClasses.footprintFor(size), mountCF)`; if `overlaps(obb, k)` is false for every `k` in `keepOuts`, return `size`. Return `nil` if even S overlaps.
- `isLevel(mountCF: { number }, tol: number) -> boolean` — true iff the mount's rotation has no pitch/roll: `abs(cf[7]) < tol and abs(cf[9]) < tol and abs(cf[8] - 1) < tol` (the world-Y row `(cf[7],cf[8],cf[9]) ≈ (0,1,0)`, per `PadPlanner`'s 12-number CFrame order `world = R*local + pos`).
- `normalizeYaw(mountCF: { number }) -> { number }` — flatten a near-level mount to **pure yaw**: keep the position `cf[1..3]`; take the mount's local-X axis's world-XZ projection `(cf[4], cf[10])`, renormalize to unit length via `sqrt`, and rebuild the rotation as a pure yaw matrix from that horizontal direction (its perpendicular gives the Z axis). **Basic ops only (sqrt/÷), no trig** → arch-stable and Lune-safe. Gross pitch (fails `isLevel`) is out of scope to fix here; the survey flags it for manual correction.
- `resolveMaxSize(terrainMax: string, spacingMax: string) -> string` — the smaller of two sizes by `SizeClasses.rank` (so the survey computes `maxSize = min(terrain, spacing)`).

### F3 — dead-code removal

- `src/shared/SizeClasses.luau`: delete `nativeSize` **and** the now-unneeded `local PadRegistry = require("./PadRegistry")` (nativeSize was its only use → decouples the modules).
- `src/shared/PadRegistry.luau`: delete `fits`, `findVacant`, `claimVacant`, `claimVacantFor`. Keep `new/register/claim/release/get` (all live).
- Remove the corresponding tests in `tests/SizeClasses.spec.luau` and `tests/PadRegistry.spec.luau`.

## Testing (Lune)

- **`overlaps` (SAT):** cleanly separated rects → false; overlapping → true; edge-touching; and the load-bearing case — two 45°-rotated rectangles whose axis-aligned bounds overlap but whose true OBBs do not → false (proves it's not an AABB test).
- **`footprintOBB`:** a known footprint at an axis-aligned mount → expected corners; at a 90°-yaw mount → corners rotated as expected (`toBeCloseTo`).
- **`spacingMax`:** no keep-outs → `L`; a keep-out overlapping L's footprint but clear of M → `M`; overlapping down through S → `nil`; a keep-out that only an AABB would hit (rotated) → still `L`.
- **`isLevel`:** a yaw-only mount → true; a pitched mount (non-zero `cf[7]`/`cf[9]`) → false; sub-tolerance survey noise → true.
- **`normalizeYaw`:** a mount with small pitch noise → output passes `isLevel(_, 1e-6)`, preserves position and yaw angle (`toBeCloseTo`), zeroes the Y-tilt. (Assert with tolerance, never exact bytes — keeps the test arch-stable.)
- **`resolveMaxSize`:** `(L,M)→M`, `(S,L)→S`, equal→same.
- **F3 regression:** the full Lune suite stays green after the deletions (nothing referenced the removed symbols).

## v1 deliverables

1. `src/shared/PadSiteFit.luau` + `tests/PadSiteFit.spec.luau` — the module + its tests (TDD).
2. `src/shared/SizeClasses.luau` + `tests/SizeClasses.spec.luau` — remove `nativeSize` + the `PadRegistry` require + its test.
3. `src/shared/PadRegistry.luau` + `tests/PadRegistry.spec.luau` — remove `fits/findVacant/claimVacant/claimVacantFor` + their tests.

## Build order

`PadSiteFit` (TDD: `overlaps` → `footprintOBB` → `spacingMax` → `isLevel`/`normalizeYaw` → `resolveMaxSize`) → F3 deletions (SizeClasses first, since it requires PadRegistry; then PadRegistry) → full Lune suite + stylua + selene green. No Studio, no gate — the increment is done when the suite is green.
