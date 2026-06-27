# ZenDojo Organic Stepped-Cobble Path — Build System & Decisions

Status: in progress (2026-06-26). Prototype stretch **FarWall_20→30** approved in Play. This doc is the
source of truth for how these paths are built; correct it as decisions evolve.

Related: memory `zendojo-organic-cobble-path`, `zendojo-canyon-village`, `roblox-editablemesh-gotchas`,
`stop-and-ask-after-each-attempt`.

## ★ FINAL WORKING RECIPE (2026-06-27) — stepped staircase, single published meshes
This supersedes the per-stretch / continuous-ribbon attempts below. Proven on the full **FarWall_11 → tunnel
entrance (FW40)** run. Build a whole path as ONE set of meshes (avoids the cross-mesh tone mismatch — see Pitfalls).

1. **Route** — Catmull-Rom spline through the `FarWall_*` markers. Use phantom endpoints for tangents; to end a
   terminus *square* (no curl toward the next marker), set the phantom = straight extension (`2*P_end − P_prev`).
2. **Terrain bench (USER carves/smooths)** — carve a graded bench along the spline (snapshot region to
   ServerStorage first: `Terrain:CopyRegion`). I carve a first pass (modest fill below grade, generous overburden
   cut above, width ~9); the user smooths. Where conforming to terrain gets rough (e.g. toward a tunnel mouth),
   DON'T chase it — run a **straight linear incline** between the two endpoint markers for that segment instead.
3. **Stepped ribbon mesh (the bed)** — ONE published MeshPart. Place timber arcs first (step 4), then build the
   ribbon as **flat treads + vertical risers**: each section's tread is flat at the **uphill boundary's bench
   level + 0.15** (so it clears the rising bench → no terrain poke-through), risers at the timbers (build by
   doubling the cross-section at each boundary: two cross-sections same XZ, different tread Y → the swept top quad
   becomes a vertical riser), underside conforms down to the bench (`benchSm − 0.3`). Material **Concrete +
   ZenCement2** (StudsPerTile 5), tint **138,142,142**. Compute quad normals geometrically (handles flat treads
   AND vertical risers). Asset: `rbxassetid://103867179411835`.
4. **Timbers (riser fronts)** — Part **6.4×1.6×1.2**, Wood, color **74,52,32**, local X = cross-stream
   (`CFrame.fromMatrix(c, cross, yAxis)`). Spaced ~**3.5 studs** along arc. Reposition each so its **top ≈ the
   uphill tread's cobble level** (uphillTread + 0.25). They read as the proud step edges. Live: `workspace.PathSteps`.
5. **Cobbles (single published mesh, FLAT per tread)** — for each tread section: Voronoi of **uneven random seeds**
   (min-sep 0.55, ~3–4/section), inset 0.08, 1-pass Chaikin, multi-ring dome (DOME 0.42), **FLAT-UP normals**
   (every dome-top normal = (0,1,0) → uniform tone across the whole run), near-mono **122,127,117 ±4** vertex
   colours, Material Rock, white tint, DoubleSided. Sit FLAT on each tread at **tread + LIFT 0.10** (0.30 read
   too proud; 0.10 = flush in the tread, tops below the timbers). Asset: `rbxassetid://136935120139461`.
6. **TODO next session:** ishigaki retaining wall on the downhill edge; switchback landing at FW11; railings + lanterns.

### Pitfalls proven the hard way (don't re-investigate)
- **Cross-mesh cobble TONE mismatch is unsolvable from script** — two separate cobble meshes render at different
  brightness (identical colour/material/normals; matched under Neon, differed when lit) — a Roblox world-space
  rendering quirk. FIX: build the whole path as ONE mesh; use FLAT-UP normals for uniform tone.
- **Continuous-slope ribbon + flat cobbles → cobbles get buried** on steep pitches (ribbon rises above the flat
  cobbles). FIX: the STEPPED ribbon (flat treads) — that's why we step it.
- **Heights ANALYTIC, never raycast a Box-collision MeshPart for Y** (returns the flat bbox lid). Terrain
  raycasts are fine.
- **Unpublished EditableMesh does NOT survive a disconnect/reopen** (becomes a placeholder box) — PUBLISH
  (`CreateAssetAsync`) anything you want to keep.

## What it is
A Japanese stepping-stone mountain path: flat tread landings of rounded river cobbles set in fine cement
gravel, stepping at heavy timber risers, meandering along the canyon wall, with a dry-stacked fitted-stone
(*ishigaki*) retaining wall finishing the downhill edge where the graded bench meets natural terrain.

## THE RECIPE (correct order — do NOT start with the timbers)
1. **Meander spline route** — centerline from the `FarWall_*` markers (Catmull-Rom through them).
2. **Shape the terrain FIRST** — carve overburden away + fill below to cut a smooth, continuously graded
   **bench** along the spline. This is the load-bearing foundation; it prevents the float-over-terrain gaps.
   Snapshot terrain to ServerStorage first (`Terrain:CopyRegion(Region3int16)`). *(Params LOST — reconstruct.)*
3. **Ribbon MeshPart (cement-gravel bed)** conforming to the graded bench.
4. **Timbers (risers) + cobbles** placed in/on the mesh path.
5. **Ishigaki retaining wall** on the exposed/downhill edge(s) — finishes the edge, doesn't carry the whole gap.

Generalize all 5 into a **route-driven builder** that takes a marker polyline → builds the whole segment.
Deterministic (`math.randomseed` per section/segment) so any state is rebuildable.

## Parameters (from the approved FarWall_20→30 build)

### Dimensions
- Path half-width **HW = 3.2** studs (tread 6.4 = timber length).
- Timber spacing along path ≈ **3.9** studs; uniform **step height ≈ 0.69** per section (varies w/ grade).

### Timbers (risers)
- Size **6.4 (cross) × 1.6 (h) × 1.2 (depth)**, Wood, brown. Local **X (RightVector) = cross-stream**; top = Pos.Y+0.8.
- Sunk **0.30** studs via idempotent `OrigY` attribute. (Open: maybe reduce height 1.6→~1.0 "plank"; deferred.)

### Cobbles (generated, not placed)
- Per section: **Voronoi** of **uneven RANDOM seeds** (NOT a grid) with **0.55-stud min separation** → size
  variation. ~**3–4** seeds inter-section, 4–6 lead/trail.
- Footprint **inset ~0.08** toward centroid (grout gap); **1-pass Chaikin** corner-round (2 passes too uniform).
- Shape = **multi-ring hemisphere dome** (rings {1.0,0}{0.87,0.5}{0.5,0.87}+apex), **DOME≈0.42** (×0.85–1.25),
  **smooth sphere-projected normals** (center 0.75 below; flat per-face = faceted pyramids — bad).
- **Section leveling:** shift each section so the **AVG of its stone tops == downhill timber top + LIFT**, with
  **LIFT ≈ 0.30**. The lift is REQUIRED: the cobble is a dome ~0.42 tall, so if you level the *apex* exactly to
  the timber top (LIFT 0) the dome's body sinks ~0.34 below the bed surface and the stones disappear INTO the
  gravel. LIFT ≈ 0.30 makes the dome **sit on** the bed (base ≈ bed top) and read as proud cobbles. (Confirmed
  via a wrong LIFT=0 attempt 2026-06-26 — cobbles vanished into the pathMesh.)
- **Timber proud of the bed = the step size** (pathMesh slope → riser height); near-flat sections ≈ **1 inch
  (~0.08 stud)**, just enough not to be buried. NOTE this means on flat sections the proud cobbles (apex ~bed+0.4)
  sit a bit above the barely-proud timbers — that's expected/accepted; the timber proud grows with the step on
  sloped sections.
- **Per-stone vertex colour** (`AddColor`/`SetFaceColors`, survives publish): mono mossy grey-green **122,127,117 ±4**.
- MeshPart Material=**Rock**, Color white, DoubleSided, CollisionFidelity=Box; verts local then PivotTo(centroid).
- Published: `rbxassetid://73166264980196` (ZenPathCobbles_20_30).

### Bed (cement-gravel ribbon)
- Width **±3.2**, thickness ~**1.0**, swept along spine. Material **Concrete + ZenCement2** (StudsPerTile **5**),
  tint **138,142,142**. Top must CONFORM to the graded bench (analytic, never raycast a Box-collision lid).
- Published: `rbxassetid://102884491610727` (ZenPathRibbon2_20_30; prior 100421407810835).
- **Extending/continuing a bed (joining a new segment to an existing ribbon)** — done 2026-06-26 for the
  FW30→tunnel piece (`PathRibbon_30tunnel`, unpublished):
  - **Start from the existing ribbon's true END, not a marker.** Detect the end POSITION by loading the
    published mesh editable (`CreateEditableMeshAsync(part.MeshContent)`) and reading the extreme vertices
    (the westmost end here = `(-12.0, 167.2, -86.5)`). Vertex POSITION is reliable; do NOT try to derive the
    heading by X-binning slices — a diagonal ribbon zig-zags and the tangent comes out garbage. Take the
    **tangent from the timber direction** at that end instead (T8→T9 ≈ (-0.986,0,0.166)); inclination ≈ 0.125.
  - Pin BOTH endpoints (existing end + target, e.g. tunnel mouth) and run a **straight LINEAR grade** between
    them. A Hermite that starts at the existing incline overshoots → a bulge in the middle; the user wants it
    flat, so linear endpoint-to-endpoint. Overlap ~2 studs back into the existing ribbon so there's no gap.
  - The bed stays a clean grade over any mid-dip in the carved bench; the ishigaki wall fills the float beneath.

### Ishigaki wall
- Voronoi on the **vertical battered face**, stones **bulge outward** (DOME **0.35**, ×0.85–1.25), 1-pass Chaikin,
  inset 0.12, min-sep 0.7, back extruded 0.6 in for solidity.
- **Batter:** top at bed edge (±3.2), base flared **out to ±3.7** (BATTER 0.5).
- **Top height = analytic timber grade − 0.2, interpolated** along the path (NEVER raycast — box-lid trap).
- Bottom = **terrain raycast − 0.4** embed (terrain raycasts are fine; they hit real voxels).
- Colour slightly darker than cobbles **116,121,111 ±6**, Rock. Smooth normals from center − outward*0.75.

### Materials library (MaterialService)
- **ZenCement1** (Concrete, StudsPerTile 10) — "river gravel", KEEP at this scale.
- **ZenCement2** (Concrete, StudsPerTile 5) — finer; on the bed.
- (Abandoned experiments: GoldColoredRocks 1 / Asphalt, ZenFlagstone1 / Slate.)

## Route (the western descent to build now)
Loop order ascends 10→11→20→30→40…; descending = 30→20→11→10. Build target: tunnel mouth → FarWall_11.
| Marker | Pos (x,y,z) | Note |
|---|---|---|
| tunnel mouth | FarWall_30 end of Tunnel_30_40 (toward FarWall_40 −89.8,178.5,−70.5) | extend W into mouth |
| FarWall_30 | −15.0, 167.7, −86.2 | seq 4 |
| FarWall_20 | 23.2, 160.0, −101.0 | seq 3 — current stretch |
| FarWall_11 | 133.0, 138.4, −74.2 | seq 2 — **switchback landing** (path reverses toward FarWall_10 51.6,114.4,−39.4) |

## Build plan (checkpointed)
1. Reconstruct the **terrain-bench** carve/fill params on one short new segment (suggest FarWall_30→tunnel mouth,
   adjacent to known-good stretch) — review & record numbers.
2. Generalize the route-driven builder; validate it reproduces FarWall_20→30.
3. Finish FarWall_20→30: wall on BOTH edges, reach tunnel mouth, publish.
4. Build FarWall_20→FarWall_11 descent; design + build the switchback landing at FarWall_11.
Review between each.

## Hard rules
- **Heights are ANALYTIC from timber grade — never raycast a Box-collision MeshPart for Y** (returns the flat
  bounding-box lid). Terrain raycasts are OK.
- EditableMesh: normals required; build verts in LOCAL space then PivotTo(centroid); publish via
  `CreateAssetAsync(em,…)` → `CreateMeshPartAsync(Content.fromUri(...))`; never write `MeshPart.MeshContent`.
- Vertex colours survive publishing.
- Process: one change at a time, describe in words (the user works in a terminal and can't see screenshots),
  wait for review. No `screen_capture` unless asked.

## PIVOT 2026-06-26 (late) — cobble tone inconsistency abandoned; single-ribbon rebuild
Two stretches' cobble meshes rendered at different brightness (existing darker, new lighter) and we could NOT
equalize them despite exhaustive isolation: identical vertex colors (Neon test matched), identical material,
identical avg normals, size-independent normals, even flat-up normals + SmoothPlastic — still differed. Same
mesh at 3 positions matched (ruled out simple world-pos), yet two different-geometry meshes never matched.
Concluded it's a Roblox world-space-rendering quirk we can't beat from script; **abandoned the investigation.**

**NEW PLAN:** deleted BOTH bed ribbons (`PathRibbon` 102884491610727, `PathRibbon_30tunnel` 78858149972493) and
all test scaffolding. Timbers + cobble meshes in `PathSteps_20_30` / `PathSteps_30tunnel` left orphaned for now.
Next: (1) USER repositions the `FarWall_*` path markers to define the carve route down to **FarWall_11**;
(2) I continue carving the graded terrain bench along them down to FarWall_11; (3) build ONE **single** mesh
ribbon spanning **FarWall_11 → tunnel entrance** (replacing the two separate beds).

## Open / unknown
- **Terrain-bench carve/fill parameters** (overburden cut depth, fill, bench width, how the ribbon conformed) —
  lost in compression; must reconstruct and record here.
- Timber height (keep 1.6 vs reduce to ~1.0).
- Whether the bed top should follow continuous grade or stepped tread levels (currently continuous; wall top
  follows the bed ramp).
