---
shelf: world
updated: 2026-08-15
checked: 2026-09-03
---

# Paths

The canyon's circulation: the perimeter loop of wall paths, stairs, tunnels and
bridges (2026-06-19..07-03) plus the valley-floor river trail west from the Square
(2026-07-29/30). Pure planning logic is committed (`tools/builders/CanyonPath.luau`,
`RiverPathChapters.luau`, `TrailProfile.luau`, `CareModel.luau`); the built geometry
is place-only by decision (source of truth = saved place + published meshes, see
[[switchback-deck]]). Live containers verified 2026-08-15: `CanyonWorld.Paths` with
`PathRailings` (5,186 descendants) and `PathLanterns` (2,599).

## The register rule (owner-gated)

**The care gradient governs the path's own construction**, not just what grows beside
it: formal ishidan flagstone at the Square → dirt trail → single-file game trail at
the wild end. `RiverPathChapters` has three kinds — stair / flat / **trail** — and its
thresholds are one-directional *limits*, not a classifier: the register is an
authored, gated decision; numbers only catch terrain that cannot carry it
(`TRAIL_MAX_GRADE` 0.34, `FLAT_MAX_GRADE` 0.10). A trail has no bed — the terrain IS
the walking surface, benched to a target profile by voxel sculpting (`SURFACE_K`
0.47), with `Step_<i>` anchors keeping the dressing builders' contract alive.

## As built — wall network

- **CanyonPath** builder committed with 228 Lune tests (`f4e10bf`, `2ce48c4`,
  `754bf8f`, `d1b0a3a`); the walkable surface is flat stone treads + risers on a
  Catmull-Rom spline, every step ≤1.25 studs (Roblox auto-step ceiling), turning
  platforms at hairpins.
- Built runs (all place-only): `PathSteps`, `PathExtension`, `DescentPath`,
  `NW1012Path`, `NW1211Path`, `NW2040Path`, `NW40Descent`, `NW80FallsStair` (76
  steps, grade-break landings), `BenchLanding`, plus the behind-falls observation
  deck `FallsLanding` (now under `CanyonWorld.Arena`, verified 2026-08-15 — its
  lanterns are functional result displays).
- **Tunnels** bored through the walls (NearWall_12↔20, _31↔40 at 120 studs the
  longest, the FarWall set, Bridge_A/B connectors, the `HeroGallery` open gallery
  behind the hero falls); backups per-tunnel in ServerStorage ([[place-state]]).
- **Bridges**: `Bridge3` arch at the clearing river hop, the flat plank teahouse
  access span (arches are reserved for scenic water/gorge crossings — an access span
  wants to be understated), and the mid-canyon suspension bridge at y≈222 kept
  deliberately as a fireworks perch ([[fireworks]]).
- Dressing: bamboo railings on all paths (`d247a2e`), hanging chōchin per path
  including DescentPath (`5d1a21e`).

## As built — river trail (complete, gated, 2026-07-30)

Spec §10 of `docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md` is the
full as-built. Chapters: Square ishidan stair (42 beds, grade 0.551) → River traverse
(3.5-wide trail, 44 anchors) → W05 falls steps (12 grey-cypress logs, marutakaidan) →
Pool shore trail (under the suspension bridge) → rustic `RiverCrossing` bridge (27
boards, log rails, 40 fall-guards) → Upper climb (**1.5-stud game trail**, terminus
rock) + the T07 access spur. Grey cypress = the dock's treatment (`CypressWeathered`,
216/214/206); trail stones from `ServerStorage.TrailStoneLibrary` (Moss Kit meshes +
SurfaceAppearance). The Upper climb's exposure is unrailed on purpose: no fall
damage, and a railing is the wrong register for a game trail.

## Trail lighting (built 2026-07-30)

**Six yamadoro placed along the river trail, coordinates baked** (`0c8f362`,
`tools/studio/placeYamadoro.luau`; six Yamadoro models verified in the place
2026-08-15, library re-homed to `ServerStorage.YamadoroLibrary`), plus a night
ambient floor (`17bbb08`). The register ruling: **yamadoro, not chōchin** — chōchin
say *maintained* and belong to the formal upper/teahouse paths; a yamadoro says
*decades ago* and fits a trail. The lantern telegraph on the formal paths is
[[viewing-platform]]'s system. Undecided threads (firebox binding, the three-register
degradation idea) live on [[backlog]].

## Gates & decisions

- Register per chapter is an authored decision, owner-gated (trail register accepted
  2026-07-30; ishidan 200 studs west of the Square "overreaches the gradient").
- 2026-06-27: the path system stays out of the Rojo pipeline (see
  [[switchback-deck]]).
- Recipe fixes baked into the builders: lead timber at the first marker; bed tucked
  0.3 behind the downhill timber; tread grade = `min(A,B)`; hand edits a builder
  cannot re-derive are stored as as-built overrides (`terminusRock` size + full
  CFrame, `omitBoards`, `steps.ranges`).
- R9 retaining walls on the Upper climb: **nothing to build** — the drops are
  progressive hillside, not an unsupported edge (measured 0.6/3.3/16.8 at
  2/4/6 studs out).

## Raw layer

- specs: `2026-06-19-zendojo-canyon-paths-design.md` (`343c144`),
  `2026-07-29-canyon-garden-floor-design.md` (§10 as-built)
- key commits: `f4e10bf..d1b0a3a` CanyonPath · `db6dffb` paver-step build ·
  `e3318c2` cobble-path fixes · `d247a2e` railings · `5d1a21e` chōchin · `0c8f362`
  yamadoro placement · `17bbb08` night floor
