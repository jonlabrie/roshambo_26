# ZenDojo — NW1012 Ishidan Stairway (design)

**Date:** 2026-07-01
**Status:** Approved design, pending implementation plan
**Replaces:** the stepped-cobble treatment of `Workspace.NW1012Path` (built to the §1 path recipe at 3.5-stud
spacing, which at this pitch produced 1.5–2.25-stud risers — barely auto-steppable, janky, rejected as a
resort-feel showcase).

## Why

Survey of the placed NW1012 timbers (2026-07-01): 22 steps, **77.9 studs of run, 42.4 studs of rise — 54%
average grade**, per-step risers 1.5–2.25 studs (18–27 inches; a comfortable stair riser is ~7 inches). The
tallest risers sit at the edge of the character auto-step limit. 54% is normal *staircase* territory (a 7"/11"
stair is 64%), so the fix is stair proportions, not a different route: **riser ≈ 0.55–0.65, tread ≈ 1.0–1.1**
(the stair-comfort rule 2R+T ≈ 25" lands on R 0.55 / T 1.0 at exactly this grade). The stretch becomes a
deliberate **slate ishidan** (hand-set stone stair) — correct Japanese steep-garden vocabulary, and it echoes
the Overlook's slate connecting stairs right where the flight lands.

User decisions (2026-07-01): slate ishidan (over timber kaidan / mixed flights); keep the existing alignment;
user places the foot leg via draft markers; 1–2 flat landings.

## Key survey numbers

| Point | Position | Notes |
|---|---|---|
| NW1012 head (Timber_23) | (-27.2, 161.8, 75.9), top 162.6 | unchanged; meets Rail_NW1012_Tunnel |
| NW1012 current foot (Timber_1) | (45.0, 119.4, 47.2), top 120.2 | current build stops here |
| NearWall_10 marker | (56.4, 115.1, 39.3) | survives in `Workspace.PathDraft` |
| Overlook upper deck | center (74, 113, 28), top Y 113.3, 34×30 | NW corner ≈ at NearWall_10 |

New foot leg: current foot → NearWall_10 is ~14 studs horizontal, ~5 studs down (~37% — gentler than the main
flight). Full stairway: **~47.5 rise over ~106 studs of arc ≈ 75–80 steps + landings**.

## 1. Route & geometry

- **Main flight line:** Catmull-Rom resampled through the 23 existing `NW1012Timber_*` centers (the
  user-approved walked line). Surveyed once, **baked into the builder** — never read live parts or markers at
  build time (recipe rule).
- **Foot leg:** user drops 1–3 `Marker_*` balls in `Workspace.PathDraft` from the current foot down to
  NearWall_10; I carve a rough bench, user smooths, I survey and bake the final points.
- **Uniform risers per flight** (rise between landings ÷ step count, target 0.55–0.65). Consistent risers are
  what reads/feels engineered — the terrain bench is carved to fit the stair, NOT the stair keyed to local
  terrain (keying to terrain caused half the jank in the current build).
- **Landings:** 1–2, at natural meander points (~⅓ and ~⅔ of the flight; exact spots proposed at build time),
  4–6 studs long, dead flat, built in the existing cobble+gravel path vocabulary (§1 of the recipe doc, minus
  timbers — a flat cobble/gravel pad).
- **Foot arrival:** small flagstone apron near the Overlook's NW corner at grade ~113.3–115; user smooths the
  final approach terrain.

## 2. Step construction (all plain Parts — no EditableMesh, nothing to publish)

- **Slab:** Slate, path width **6.4 cross**, slab depth **~1.25** along travel, body dropping **~0.8** below
  its tread so riser faces are stone, not terrain/bed. **Tread pitch derives per flight** (horizontal run ÷
  step count): ~1.1 on the main 54% flight — slabs overlap the joint below (stone nosing hides the riser
  seam) — and ~1.6 on the gentler foot leg, where the gap between slabs shows as a gravel/grout band
  (normal for gentle garden steps).
- **Hand-set read via seeded jitter** (fixed seed, rebuildable): yaw ±2°, lateral ±0.15, size ±5%, thickness
  variation; **1–2 stones per step** (seeded random 40/60-ish split with offset joints) so steps don't read as
  machined monoliths.
- **Color:** near-monochromatic grey in the ishigaki-stone family, starting point `96/98/94 ±3`, tuned at the
  first-look gate.
- **Bed/grout:** per-step flat `Concrete` + `ZenCement2` slab beneath (top ~0.05 below tread, tucked per the
  §1 bed rule), **bed width 5.8 < slab width 6.4** (sizing rule: structure proudest) — grout shows at side
  margins and the split joints.
- Heights are **analytic** from the stair math (riser × index off the flight base). Never raycast parts for Y.

## 3. Terrain & underpinning

- **Cut-only carve** to re-bench the main flight for the new step heights (`Air` above target floor; never
  fill-to-target). `Terrain:CopyRegion` snapshot → `ServerStorage` first; verify carve in a **separate**
  `execute_luau` call (same-call raycasts read stale).
- Fresh rough carve on the foot leg after the user places its markers (then user smooths — standard handoff).
- **Ishigaki retaining walls** (§3 recipe) on downhill spans where slabs float >2.5 studs —
  `buildIshigakiWalls` adapted to read step slabs instead of timbers (span-find over slab grades).

## 4. Railing, chōchin, transitions

- **Bamboo railing** (§4 recipe, `buildBambooRailing` adapted from timber-keyed to step-keyed): downhill/open
  edge only; top rail is a smooth Catmull-Rom through per-step edge points following the rake; posts every ~4
  steps; rustic-jittered lower rail; **15-stud raked invisible fall-barrier** (perp height 15/cos(rake)).
- **Chōchin** every ~12 steps on the uphill edge (staggered, seeded, per §4) **plus one at each landing**
  (downhill allowed at landings where terrain permits).
- **Head:** Timber_23-equivalent top step stays at the current head position/level, so the existing
  `Rail_NW1012_Tunnel` connector should still meet it; re-link if the new head geometry misses it.
- **Foot:** bamboo terminates at posts on the flagstone apron. **No KŌRAN splice** — the Overlook keeps its
  own railing vocabulary; the apron is the transition.

## 5. Teardown, tooling, persistence

- **Remove:** `Workspace.NW1012Path` (timbers, beds, cobble MeshPart — the published cobble asset just goes
  unused), `Workspace.PathRailings.Rail_NW1012`, `Workspace.PathLanterns.Chochin_NW1012Path`.
- **Keep:** `Rail_NW1012_Tunnel` (see §4 head note); `NW1211Path` untouched.
- **New reusable builder:** `roblox/tools/studio/buildIshidanStairs.luau` — CONFIG: baked control-point
  polyline, landings list (arc-position + length), riser target, slab/bed widths, jitter params, seed;
  idempotent (`outModel` replace-on-rerun) in the style of the existing §6 builders.
- **Place-only build** (like all paths — [[roblox-rojo-vs-place-state]]): SAVE THE PLACE after every session;
  ship by publishing the place.
- **First-attempt gate (stop-and-ask):** attempt #1 = **foot leg + lowest flight only** (~20 steps + apron),
  then STOP for the user to walk it before batching the remaining flights, landings, walls, railing, chōchin.
- Record as-built (final params, counts) back into this spec when done.
