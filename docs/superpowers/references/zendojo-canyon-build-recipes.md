# ZenDojo Canyon — Build Recipes (Quick Reference)

**Living doc. Source of truth for building the canyon path system at scale** (paths, switchback decks,
retaining walls, railings, lanterns). We've built ~5% of the total; this captures the hard-won recipes so
each new stretch is fast. Exact per-build params + published asset IDs live in the dated as-built specs
(linked per section); this is the *how* and the *gotchas*.

As-built specs to mine for exact numbers:
- Path: `specs/2026-06-26-zendojo-organic-path-system.md`, `specs/2026-06-27-zendojo-fw11-fw10-descent-design.md`
- Deck: `specs/2026-06-27-zendojo-fw11-switchback-deck-design.md`
- Walls: `specs/2026-06-27-zendojo-retaining-walls-design.md`
- Railings/lanterns: `specs/2026-06-27-zendojo-path-railings-lanterns-design.md`

---

## 0. Workflow (every stretch)

1. **brainstorm → spec → plan → inline execution.** Each stretch = its own spec+plan in `docs/superpowers/`.
2. **Prototype-first, ONE attempt, then STOP and ask.** Build one unit/stretch, let the user look in Studio,
   iterate on *their* read; only then batch. Never self-judge visuals. (`stop-and-ask-after-each-attempt`.)
3. **The user drives placement; you build to it.** They move decks, tune heights, and **finish-smooth
   terrain**. You survey what they did (read live Studio state) and build to it. Terrain is a *handoff*,
   not all-manual — see the path-creation flow next.
4. **Path-creation flow (markers → terrain → cobbles).** This is the canonical order for a new stretch:
   - **a. (user)** drops a row of `Marker_*` balls (Neon, tag `DevMarker` → hidden in Play by
     `tools/studio/hideDevMarkers.client.luau`) in `Workspace.PathDraft.<name>`, between two+ endpoints,
     and drags them into place.
   - **b. (you) carve a rough terrain path** along the marker line — a rough walkable grade/channel cut
     between the points (Terrain ops along the marker spline). This IS your step; don't wait for the user
     to do it.
   - **c. (user) smooths** the rough-carved terrain.
   - **d. (you) build the cobbled path** (§1): route a **Catmull-Rom** spline through the markers →
     timber risers + cement-gravel bed + flagstone cobbles → publish the cobble mesh.
   - **e. (you)** add walls (§3, where it floats), chōchin (§4), bamboo railing + invisible barriers (§4).
5. **Where things live:**
   - **Pipelined (Rojo + lune):** the arena, the **switchback deck** (`tools/builders/SwitchbackDeck.luau` →
     genmodels → `assets/*.model.json` → mapped in `default.project.json`), `LanternController`.
   - **Ad-hoc Workspace (published meshes/Parts):** the **paths, walls, railings, lanterns** — like the
     existing `PathSteps`/`PathMesh`. They persist via the **saved .rbxl place + published mesh assets**.
     *Remind the user to SAVE the place after any ad-hoc build.*
6. **Record as-built** (final params, counts, published asset IDs) in the stretch's spec when done.
7. **Teahouse access registers to the PAD, not the teahouse** (2026-07-04, meta-game spec). Spurs/
   stairs/bridges terminate at the pad boundary (the future claim-gate post), OUTSIDE the site's max
   expansion envelope (`references/2026-07-04-teahouse-envelope-audit.md`) — never on/against the
   current teahouse deck/engawa. Teahouses will be regenerated and grown (structural tiers); access
   built to the current form blocks the envelope or orphans on upgrade (see `Teahouse3Stair`).
   Railing gaps for the access opening follow the existing spur-gap rule above.

---

## 1a. ★ ISHIDAN STAIR / PATH — THE CANONICAL STEP RECIPE (2026-07-02)

**"Worn dark timber backed by worn flagstone."** User-locked on the NW1012 stairway; this is the step
treatment for ALL new stairs/paths. The old §1 cobble paths have all been converted (PathSteps,
PathExtension, DescentPath, NW1211Path — done 2026-07-02; NW1211 later narrowed −25% + a foot step added
2026-07-04). The engineering
lives in `tools/builders/IshidanStairs.luau` (`resample` → `layout` → **`dress`**, Lune-tested) with the
Studio mirror `tools/studio/buildIshidanStairs.luau` (CONFIG at top; publishes flag meshes).

**Layout (unchanged from the stair math):** Catmull-Rom through BAKED control points; **uniform risers per
flight** (target 0.6; terrain is carved to the stair, never the stair keyed to terrain bumps); flat landings;
2R+T ≈ 2.0–2.1 comfort check. Steep flights (tread < ~1) read timber-dominant; gentle ones (tread ≥ ~1.2)
show the full flagstone field — this scaling is intentional and matches the reference image.

**Per step, `dress()` emits:**
- **Riser beam** (`Riser_<i>[a|b]`): worn timber Part, `6.4 × (0.6–0.72) × 0.45`, top = tread, at the step
  FRONT; Wood, color **72/60/48 ±7** per beam; 35% split into 2 planks (0.06 gap); yaw ±1.5°, lateral ±0.06.
- **Gravel bed** (`Step_<i>` — the downstream contract part for ishigaki/railing/chōchin CONFIG runs):
  Concrete + **`ZenGravel1`** MaterialVariant (generated fine decomposed-granite, **StudsPerTile 4**), tint
  150/146/138, `5.8 wide × 1.2`, top = tread − 0.05, **spanning riser to riser** (front+0.2 → front+pitch+0.3
  — a centered/short bed leaves flag edges hanging in air; a front-flush bed pokes concrete out of the riser
  face. Both bit us.)
- **Flagstones** (published mesh, `Flags_<n>`): flat Voronoi flags in the zone `u ±2.7, v 0.55 → pitch−0.08`
  (skip if usable depth < 0.4; landings use the full pad). Seeds min-sep 1.2 (8 tries, 14 on deep treads).
  **Rough outline pipeline: subdivide edges to ≤0.45 → per-point radial inset 0.05–0.14 with 12% NOTCHES
  (+0.15–0.33) and 8% slight bulges → ONE Chaikin pass** (two passes = smooth ovals, the classic mistake).
  **Rolled-edge profile:** bevel ring at top−0.07, crown ring inset 22% toward centroid at top, apex +0.012,
  skirt to top−0.32; SMOOTH per-vertex normals (flat facets read CNC-cut). Per-flag top jitter ±0.02.
  **Flags sit `flagProud = 0.08` above the bed** (crown ~0.13 proud of the gravel, edges just clearing it,
  skirt still embedded ~0.19 → no gap underneath); added to `topY` at mesh-build time (user-locked 2026-07-09).
  **Palette: grey g = 78–116 (mean ~96 — 25% darker than instinct), 35% warm variant (g+8, g, g−12), else
  cool (g, g+1, g−3); sides 52/52/49.** MeshPart: Slate, Color white, DoubleSided, **CanCollide FALSE**
  (players walk on beds/risers), CollisionFidelity Box, CFrame origin, world-space verts, publish
  (`CreateAssetAsync`). **Chunk by FLAG COUNT (~40 flags per mesh), never by step count** — deep treads pack
  8–14 flags each, so a step-count chunk blows Studio's triangle limit (bit us twice); contiguous chunks
  share the style stream so seams are invisible. NEW paths: `buildIshidanStairs.luau` (baked centerline);
  CONVERSIONS of old cobble paths: `reskinPath.luau` (survey → relayout if old risers > ~0.8, else
  preserve). Railing gaps for spur access (e.g. NW2040's teahouse opening) = build the run as two RUNS
  segments with end posts framing the opening — never leave a barrier across it.

**Flat-shelf promenade variant** (`tools/studio/buildFlatShelfPath.luau`, 2026-07-09). A near-LEVEL curved
shelf can't use `buildIshidanStairs` — the riser-driven layout collapses `rise/riserTarget ≈ 0` to one step.
The flat builder keeps the IDENTICAL §1a dressing (risers/beds/flags, `flagProud 0.08`) but swaps in a
**uniform-tread layout**: N equal treads along the arc (`nSteps` or `nSteps = round(arc/treadTarget)`, target
~6 studs), tread tops interpolated from the centerline so a gentle grade rides as a smooth ramp
(FarWallBridge2Path: +4.75 over 62). CONFIG is a `paths` list (baked centerline per path) sharing the style
block; parents under `CanyonWorld.Paths`. Baked: **FarWall7282Path** (12 treads, dead-level) and
**FarWallBridge2Path** (10 treads, ramps to the Bridge2_B abutment). **Lesson that forced this:** the first
pass laid 6 long (~12-stud) treads; the RightVector jumps ~25° between them at the bend, so the railing edge
zigzagged and floated posts. Halving the tread length (double the stones) smooths the curve — do that BEFORE
fighting the railing. Survey-driven: re-read the `Sandbox.PathDraft` markers, re-bake, rebuild (markers get
nudged between passes).
- **Flat-shelf RAILING** (RUNS entries in `buildBambooRailing.luau` with `noRelax = true, clampEnds = true,
  hw = bedW/2 = 2.9`): the v2.1 Laplacian relax BOWS the line off a short-tread curve and floats posts over
  the drop → `noRelax` runs the line straight through the tread-edge points; `clampEnds` extends it half a
  tread past the first/last CENTRE (along that step's travel) so it stops flush with the path — no overshoot.
  Long ishidan runs keep the relax (clean at seams). Drop/open edge = **−Right** on both Far-Wall shelves.
  The same variant now also rails the short curved Far-Wall runs: **FarWall5063Path** (open −Right; the +Right
  cut face holds its timber wall + one chōchin at Step 4 past the wall) and **FarWall_T11Spur** (open +Right,
  rail-only) — both committed as `buildBambooRailing.luau` RUNS entries.
- **Flat-shelf CHŌCHIN**: `buildChochinPole.luau`'s `buildOne(parent, name, base, up)` placed at explicit
  Step indices on the **+Right wall side** (opposite the rail), `up = +RightVector` (flattened), offset ~3.4
  from bed centre, **foot raycast-grounded to the bank** (the wall side sits ~1–2 studs below tread). Avoid
  cliff-bulge steps (probe first). Placed: FarWall7282Path Steps 3 & 9 (two); FarWallBridge2Path Step 6 (one).
  Parent under `CanyonWorld.Paths.PathLanterns/Chochin_<path>`.

**Timber retaining walls** (the pocket/cutting treatment, replaces ishigaki for CUT faces; ishigaki §3 stays
for under-path floating spans). Built by **`tools/studio/buildTimberRetainingWall.luau`** (Step_-native,
Parts-only, idempotent) — recipe RE-EXTRACTED 2026-07-09 from the reference builds
`CanyonWorld/Structures/RetainingWalls/TimberWall_WestTraverse` (+ `Pocket_E/U`) and `NWFallsWall`. A wall
**retains — it is not a fence**; the load-bearing rules (all three were gotten wrong the first pass):
- **Posts at EVEN spacing over the WHOLE run**: `nBays = round(runLen / ~6)`, `spacing = runLen/nBays`. Never
  pick an interval then tack a short post on the end to absorb the remainder.
- **Each bay is a LEVEL rectangle of full-width courses running post-centre to post-centre** — one continuous
  board per course; boards NEVER end mid-bay (a board that stops between posts retains nothing). Bays STEP up
  with the grade; the boundary post bridges the step.
- **Board `len × 0.71 h × 0.40 t`**, course pitch **0.75** (0.04 gap), `len = spacing + 0.2` (laps the posts),
  timber **72/60/48 ±8**, small depth jitter. Bay courses `= round((bayTop−bayFoot)/0.75)`.
- **Post `1.1 sq`**, ink **45/48/56**, NO top cap; foot = grade at the post, top = tallest adjacent bay top
  **+ ~1.3** (always proud of its boards).
- **Top follows the CUT depth** (`hold` = terrain-behind − tread, capped ≤ **11**), probed at the step CENTRES
  only and held flat at the run ends → post heights progress **smoothly** with the path. (A per-point terrain
  probe produced one erratically short post that the rest "recovered" from — looks broken.)
- **Register to the built path edge + standoff** (`offset` from centreline, never the excavation — see
  `roblox-walls-register-to-structure`); foot embeds ~0.8. This is the POCKET treatment: it reads right where
  earth packs behind it; on an OPEN shelf edge it becomes an exposed slatted screen (a low kerb + raw slope
  above, or additive backfill, suits an open edge better).

**Landing deck:** WoodPlanks slab, deck color 107/79/51, black frame band (0.6 wide, ink 30/26/20) around
the perimeter — sit it **~0.1 PROUD of the deck on top AND on the outer sides** (raise the top, push the
outer face past the deck edge); a band flush/coplanar with the deck boards z-fights (bit us on JunctionLanding
2026-07-09). Girders + short grounded posts. Junction rule: stair treads arrive FLUSH at the deck top; leave
~0.05 butt gaps (coplanar overlaps z-fight); non-90° turns fan the last ~3 steps (winder-style) instead of
wedge gaps.

**Deck balustrade** (optional formal railing on a landing/overlook edge — distinct from the bamboo PATH rail):
`tools/studio/buildDeckBalustrade.luau`, the LOCKED FallsLanding style — newel posts (0.62 sq × 3.70) topped by
a hanji result-lantern (1.0 × 1.5 Neon, **tagged `BlockLantern`** so LanternController drives it) + dark slate
cap (1.2 × 0.18); dark top rail cap (0.60 × 0.30, ink 30/26/19) + deck-wood mid rail (0.42 × 0.25) + balusters
(0.34 sq × 3.20, ~2.6 pitch); invisible barrier. Rail centreline inset ~0.4 so outer faces read flush; newels
inset 0.31 from the corners. CONFIG `runs`: `{ model, deckPart, edgeDir = world {x,z} outward (builder picks the
best-matching deck face), name, inset }`. Parents `Railing_<name>` under the deck model. (Extracted 2026-07-09
from FallsLanding; approved on JunctionLanding's SE edge.)

## 1. Stepped-cobble path — SUPERSEDED for steps by §1a (kept for reference / un-converted paths)

A meandering mountain stair: timber risers + flat cobble treads + cement-gravel bed, routed through markers.

**Timbers (risers):** Part `6.4 (cross) × 1.6 (h) × 1.2 (depth)`, `Wood`, color `RGB 74,52,32`. Local **X
(RightVector) = cross-stream**; place with `CFrame.fromMatrix(pos, cross, Vector3.yAxis)`. **~3.5-stud
spacing** along the spline arc-length. **Start on a riser:** with `leadFromFirstMarker`, place a lead timber
(index 0) *at the first marker* so the path opens on a timber, not a bare bed/cobble tread. *(Added 2026-07-01;
the old `leadFromFirstMarker` made marker[0] a bed-only boundary, so the path started on a cobble.)*

**Treads are FLAT per gap, stepping down at each timber — NOT sloped.** (Sloped treads bury the cobbles and
read wrong. The path is a staircase: flat tread, vertical riser at the timber.) Each gap's tread sits flat at
its **downhill (lower)** timber's grade.

**The timber is the FRONT (downhill riser) of its step, NOT the back.** A step = a timber riser with its tread
sitting *behind/above* it at the timber's top; the **uphill** timber of the gap then rises above that tread as
the riser up to the next step. So for the gap between two timbers, key the tread to the **lower** one —
`tread = math.min(A.grade, B.grade)` in the builder, **never the "next" timber**. Keying to the uphill timber
buries the downhill timber at the *back* of the tread and reads wrong; using `min` keeps it correct no matter
which way the markers run (uphill→downhill or downhill→uphill). *(Bug fixed 2026-06-30: the builder keyed to the
later boundary, which is the uphill timber when markers ascend — buried the downhill riser. Now uses `min`.)*

**Cobbles (one published mesh for the whole run):**
- **Per-section Voronoi** — generate a separate cell field **inside each timber-to-timber gap** (clipped to
  the gap + tread half-width), NOT one continuous field (that runs under the timbers / over the edges).
- `~3–4 seeds per gap`, **min-sep 0.55**, **inset 0.08**, **1-pass Chaikin**, multi-ring dome **0.42**
  (×0.85–1.25), **FLAT-UP normals** (every normal `(0,1,0)` → uniform tone across the run), mono mossy
  **`122/127/117` ±~3** vertex colors, Material **Rock**, Color white, **DoubleSided**, CollisionFidelity Box.
- Apex ~`tread + 0.15` (just below the timber tops). Build **all gaps into ONE EditableMesh → publish**.

**Bed (cement-gravel):** `Concrete` + **`ZenCement2`** MaterialVariant, tint `138/142/142`. **Flat slab per
gap** (horizontal), top **~0.05 below the downhill tread**, ~1.2 thick. (A single tilted/long bed buries the
downhill end — do it per-gap, flat, keyed to the downhill timber.)
- **Length: tuck the downhill end, hide the uphill overshoot.** Span the slab from `u = 0.3` (just behind the
  downhill timber's face) to `u = L + 0.5` (a small overshoot *under* the next timber). Do **NOT** center a
  `L + 1.0` slab across the gap — the old recipe did, and its 0.5 overshoot past the *downhill* timber poked a
  grey cement block into that timber's face (the bed top sits only 0.25 below the timber top, so the overshoot
  showed). Tucking the downhill end kills that; the uphill overshoot stays hidden under the higher next timber
  (its top is below that timber's body), so no seam/terrain gap opens. *(Bug fixed 2026-07-01.)*

**THE SIZING RULE (so it reads right):** **timber width (6.4) > bed width (~5.8–6.4) > cobble width (~5.2–6.4).**
Timber ends then reveal proud; cobble ends tuck into the gravel. (Upper run: bed 6.42, cobbles HW 3.2. Descent:
bed 5.8, cobbles HW 2.6.)

**Heights are ANALYTIC** from the timber/marker grade — **never raycast a Box-collision mesh for Y** (returns
the flat bbox lid). Terrain raycasts are fine.

---

## 2. Switchback deck

A small posted timber viewing deck at a hairpin — smaller sibling of the clearing `Overlook`. **In the
`SwitchbackDeck` builder** (pure, lune-tested, genmodels→Rojo). Position **baked from the user's in-Studio
placement** (Rojo serve is one-way; read their move, bake it).

- **Slab:** `WoodPlanks`, 0.6 thick, color `107/79/51` ("Earth orange" = `{0.42,0.31,0.20}`). Define by
  **center + size** (exact dims; avoids float drift).
- **Posts:** `Wood` **1.125 sq** (25% lighter than Overlook's 1.5), **inset flush** with the slab edges
  (outer face aligned: `x ± POST_W/2`). Feet from a **terrain survey** at each post XZ (cliff edge ~near
  grade = stub posts; drop edge = tall). All vertical (a raking strut read "goofy" — user rejected it).
- **Girders:** `Wood` **1.2 × 0.825**, two long edges + one cross, flush, top at slab underside.
- **KŌRAN railing** on the **open-air edges only** (the view/drop sides): top cap `0.3×0.6` + mid-rail +
  **balusters `0.34` run up to the cap (no gap)** + **newels `0.62×0.62 × 3.7`**. **Open** on the cliff edge
  and the path-entry edge.
- **Result-lantern (block style):** ONE hanji lantern on the jutting view corner. `Neon` body, warm
  `0.635/0.49/0.28`, name **ends in `Lantern`** + dark `palette.ink` cap + warm `PointLight` (1.0/0.76/0.46,
  bri 0.68, range 9). The block `LanternController` finds `*Lantern` under `Workspace.RoshamboStage` and
  paints the 4-face result SurfaceGui — so block result-lanterns must live under RoshamboStage.

**Deck→path stair (Overlook connecting-stair recipe):**
- **Slate treads**, **Size `{2, 0.5, width}`** = 2 deep **along travel**, `width` across. ⚠️ `{width,0.5,2}`
  is rotated 90° (the bug we hit). Color `palette.ink`. Lerp from head→foot; ~6–7 steps.
- **Two sloped Wood stringers** via `Spec.segment(footEdge, headEdge)`, `len × 0.9 × 0.5`, dropped 0.7 below
  the treads; framing **newels** at the head.
- Place the **foot via a user-dragged target marker** (a cyan ball they position = where the path/bridge
  meets the bottom); build head→target; tune tread seat (down) + forward-overhang on the stringers to taste.

**Deck-style stair railing (raked KŌRAN, in `SwitchbackDeck.stairRail`):** a KŌRAN railing down BOTH sides of
the stairway, built via `Spec.segment` (raked) — same cap/mid/newel dims as the flat deck railing.
- **Cap + mid-rail** are one continuous raked run, head → an **extended foot out on the path flagstone**
  (`RAIL_FOOT`, continuing the stair rake past the last step so the deck rail meets the bamboo path's top —
  this is the *style transition* between deck-KŌRAN and bamboo).
- **Balusters: exactly ONE per step**, plumb, seated **on each tread** near the front (downhill) edge, rising
  to the cap. (Evenly spacing along the rake makes them drift off the steps / float — don't.)
- **Foot newels** sit at the extended flagstone foot. Where a side **aligns with an existing deck corner
  newel**, reuse it (shift the whole stairway a few studs so the rail head lands on it — don't double up).
  *(Cement "footings" at the newel feet were tried and rejected — newels sit straight on the flagstone.)*
- **Invisible fall-wall** along the open side, raked, **15-stud vertical** (perp height = `15 / cos(rake)`),
  same jump-proof rule as everywhere.

---

## 3. Ishigaki retaining wall

Dry-stone facing on the **downhill edge** where a path floats above grade. **Selective** — only on contiguous
spans where the float **> ~2.5** studs (a `SpanFinder` pass over the timbers; pad each span **±1 timber** so
single-timber spans taper naturally instead of forming nubs). Per-span **published** meshes in
`Workspace.RetainingWalls`.

**❌ What FAILED (don't repeat):** Voronoi-**domed bulgy pebbles** on a flat face (inset 0.12, dome 0.35) →
"scattered pebbles." Then flat low-dome cells → "flat wallpaper" (no joint shadows).

**Builder (`buildIshigakiWalls.luau`, Step_-native since 2026-07-04):** surveys the ishidan `Step_<i>`
bed contract (NOT old timbers — the reskin deletes those). CONFIG per path is `{ model, edgeSign, hw? }`
like the railing RUNS: `edgeSign` is EXPLICIT (no auto-detect), `hw` overrides the 3.2 edge for narrowed
paths. `findSpans` measures downhill float at the **bed underside** vs terrain; contiguous runs >THRESH
(2.5), padded ±1. Each path's `Wall_<model>_*` are ALL cleared before rebuild (idempotent from scratch);
a path with no float >2.5 correctly yields no wall (e.g. DescentPath after its relayout). Re-run after any
path relayout/reskin — the old walls won't match the new float profile. As-built 2026-07-04: PathSteps
0_9/11_14/22_29/38_45, PathExtension 3_5, DescentPath none.

**✅ What WORKS (the recipe):**
- **Dark recessed backing** over the whole battered face (`COL_JOINT ~46/47/45`) + **flat proud stones on
  top** (`RELIEF ~0.22` above the backing → the gaps between stones are real recessed shadow = reads 3D).
- **Horizontally-coursed** stones: vertical stretch `SY 2.0`, min-sep `1.15` (cells ~2:1 wide).
- **Near-monochromatic** stone `96/98/94 ±3`; inset `0.12` (the joint width).
- **Batter:** top edge at the **bed edge (±3.2)**, base flared **±3.7 and down to terrain raycast − 0.4**.
- **Wall top at the BED UNDERSIDE** (~0.6 below the timber center), NOT at grade — so the timbers + bed edge
  stay visible above it and it reads as *supporting* the path.
- **`w = vs / Hs`** (map the stone field to the **local** wall height) so it fills base→top everywhere — a
  constant-height field leaves a mid-span dip where the wall is tallest.
- **Perlin-noise crown + base** so neither edge is a clean line; **taper to a ragged stub** (min-height
  clamp, not a sharp point) at span ends.

---

## 4. Bamboo railing + hanging chōchin

- **Bamboo railing — LOCKED v2.1, `tools/studio/buildBambooRailing.luau`** (user-approved 2026-07-02;
  deployed canyon-wide). **Warm bamboo tan `118,95,52`**; **rounded node collars** (sphere-mesh ellipsoids,
  radial +0.022, swell 0.16, `96,76,40`) every ~2.2–3.1 studs on both rails + 3 per post (geometry, not
  texture — world-space materials can't band along the culm); **posts dia 0.36 × 3.25** (~2 in proud of the
  top-rail crown) every **~7 studs of arc**. **Line generation: even 1.5-stud linear resample + 4 Laplacian
  relax passes** — NEVER Catmull-Rom through raw step points (overshoots at seams/grade changes; the
  PathSteps seam sag). Mid-rail wobble (amp 0.154, ~7-stud wavelength) rides ON the smooth line, so it's
  density-independent (the old `jitScale` knob is gone). **Contiguous path models rail as ONE stitched run**
  (`paths` list) — separate runs + a straight connector kink at the seam. The edge line follows each timber's **±RightVector END**, `HW=3.0` from
  centre (≈ the timber edge — posts ALWAYS embed at the timber edge, **terrain is irrelevant**, never plant on
  ground). Baseline = timber top. Per run:
  - **Top rail** — SMOOTH continuous **Catmull-Rom** through the per-timber edge points (`S=4` subdivisions),
    cylinder segments + ball joints, dia `0.32` at **+2.9** over baseline.
  - **Lower rail** — the SAME run dia `0.22` at **+1.25**, BUT its control points get low-frequency
    **lateral+vertical jitter** (`±0.154` / `±0.112`, seeded `20260629`) *before* the spline → a gentle
    hand-built wobble while the top rail stays true. Jitter is applied to interior control points only
    (endpoints stay put so adjacent runs/connectors meet cleanly). Rustic "lashed on site" read.
  - **Posts** — vertical bamboo dia `0.45 × 3.0` every **2 timbers** at the edge baseline.
  - **Invisible fall-barrier** — a `CanCollide`, `Transparency 1`, `CastShadow false` box per gap, **`15`
    tall**, `0.4` thick, rising from the path edge. **15, not 10:** a player can jump onto the rail cap
    (~3.2) then jump again (~7.2 ≈ 10.4) and clear a 10-stud wall — 15 defeats that. (Same 15-stud rule on
    the deck/stair fall-walls.) Reads only the bamboo.
  - **Side** = the **downhill / open-air (finite-drop) edge**; the no-terrain-hit (`999`) side is the
    cliff/wall — do NOT rail it. Probe both ends if unsure, but the USER knows the side — ask. `edgeSign`
    (`-1` = `-Right`, `+1` = `+Right`) picks it; a run is one side end-to-end (switch sides = a new run).
  - **Connectors** bridge a gap between two runs' endpoints (straight top+mid rail + barrier) so adjacent
    sections read continuous (e.g. PathSteps↔PathExtension's ~4.4-stud seam). As-built: PathSteps `0–47`
    (downhill), PathExtension `1–5`, DescentPath `2–20` (downhill), into `Workspace.PathRailings`.
  (Cylinder long axis = local X → vertical needs `CFrame.Angles(0,0,90°)`; rails along a run via `CFrame.lookAt`.)

- **Hanging chōchin — LOCKED, extracted to `tools/studio/buildChochinPole.luau`** (exact params + deployment
  in `specs/2026-06-27-zendojo-path-railings-lanterns-design.md` "As-built"). The hard-won lessons:
  - **Glyph display = SurfaceGui on a thin transparent `GlyphPlate`, NOT a BillboardGui.** A billboard reads as
    a floating label (and `AlwaysOnTop` makes it worse); a plate-mounted SurfaceGui is occluded + scales with
    distance → reads as ink on the paper. **Size the plate in studs (scale), never pixels (offset)** or it's huge
    from afar. Two plates **perpendicular to the crosspiece** (universal, not path-relative) → readable both ways.
    Round glyphs rest at **20% transparency** (block faces 0) via a per-label `ShownT` attribute the telegraph
    fades to. Tag the plate `RoundLantern`; `LanternController` paints it.
  - **Warm "oil-lamp through paper" glow = a soft radial glow SPRITE** (current approach, ALL lanterns).
    A Neon **ball** reads as a hard "uniform sphere" (esp. on the small block lanterns) — superseded. Use a
    `BillboardGui`+`ImageLabel` with a **custom soft radial-glow PNG** (white centre→transparent edge, tint via
    ImageColor3): **`rbxassetid://135490760661320`** (uploaded — marketplace "circle" *Decals* don't load in
    an ImageLabel, `IsLoaded=false`; upload your own *Image*; allow moderation time for other players). Size
    the sprite a bit larger than the body so the soft halo extends past the silhouette. Translucent Neon paper
    (`T~0.42`) behind it. The chōchin also keeps a **vertical gradient via per-slice colour** (centre bright →
    ends dimmer) for extra depth; the block box can't (single part for the 4-face glyph). **Light spill:**
    keep the PointLight low (Brightness ~0.3, Range ~5–9) so lanterns read as contained points, not cliff wash.
  - **Barrel shape = stacked Neon slices on a superellipse profile** `r=capR+(Rmax−capR)(1−dⁿ)^0.5`
    (n≈6 → straight middle + sharp corners). **Continuous profile (no straight+taper boundary) avoids a
    brightness STEP** at the shoulder (overlap-doubling jumps where tapering starts); **keep slice overlap
    (×1.15) to hide seams** (removing it exposes dark gaps). Vertical ribs at constant radius **only span the
    straight zone** or they poke past the curved ends.
  - **Sway:** `ChochinSway.client.luau` rocks each tagged `Swing` sub-model (pivot at the crosspiece hang point)
    ±~3° on a slow desynced sine.
  - **Deploy** every ~6 timbers on the **uphill** edge with a **±0.35-gap stagger** (≈5–10%, seeded) so it's
    not a rigid line; **up to 30% (`downhillFrac`) on the downhill side** where a raycast finds terrain within
    `dhMaxDrop`. `uphillSign` picks which RightVector end is the cliff (+1 PathSteps, −1 DescentPath); each path
    deploys into its own `PathLanterns.Chochin_<path>` sub-model (re-running one path won't disturb another).

---

## 5. Studio / EditableMesh gotchas (cross-cutting)

- **Publish meshes to keep them.** Unpublished `EditableMesh` (incl. `Content.fromObject` previews) becomes a
  **placeholder box on reload**. `AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {Name=...})` →
  returns **`(Enum.CreateAssetResult.Success, assetId)`** → `CreateMeshPartAsync(Content.fromUri("rbxassetid://"..id))`.
- **EditableMesh build:** verts in **world space**, place the MeshPart at **`CFrame.new()`** (origin). Faces
  need `AddNormal`+`SetFaceNormals` AND `AddColor`+`SetFaceColors` or they render nothing. Vertex colors
  survive publishing.
- **Tone:** two separate cobble meshes can light at different brightness — **flat-up normals** fix it; build
  a run as **one mesh**.
- **Cylinder primitive long axis = local X.** Vertical cylinder: `CFrame.Angles(0,0,math.rad(90))`.
- **Terrain raycast = fine.** Box-collision **MeshPart raycast = the flat bbox lid** (trap) — use analytic
  heights from timbers/markers.
- **MaterialVariant** for finishes: `ZenCement1` (Concrete, StudsPerTile 10, "river gravel"), `ZenCement2`
  (StudsPerTile 5, finer, the path bed). Recolor mesh packs via world-space MaterialVariant, not SurfaceAppearance.
- **Rojo:** `rojo serve` is **one-way** (file→Studio); in-Studio edits aren't written back — read them, bake
  into the builder. A **new `$path` in `default.project.json` needs a Disconnect→Connect** to apply.
- **Reversible terrain:** `Terrain:CopyRegion` to ServerStorage before carving; `PasteRegion(region, origin,
  true)` (pasteEmptyCells=**true**) to fully restore (false leaves added fill).
- **Compass (canyon-local):** the gorge bends, so N/E/S/W are not world-axis-aligned — record the world dir
  per stretch; don't assume.

---

## 6. Reusable build scripts (`roblox/tools/studio/`)

Proven generators are extracted into configurable runnables — set the `CONFIG` block at the top and run in
Studio (command bar / MCP `execute_luau`). They build into `Workspace.*` and **publish** their meshes.

- **`buildSteppedCobblePath.luau`** — drops a path from a `Workspace.PathDraft.<draft>` marker folder:
  Catmull-Rom spline → timber risers → flat per-tread cobbles + bed → published cobble mesh. CONFIG: `draft`,
  `outModel`, `timberPrefix`, `SPACING`, `COBBLE_HW`, `BED_W`. (Workflow: drop markers, user shapes them, run.)
- **`buildFlatShelfPath.luau`** — §1a dressing on a UNIFORM-TREAD layout for near-level / gently-ramped curved
  shelves (where `buildIshidanStairs` would collapse to one step). CONFIG is a `paths` list: `{ outModel,
  control (baked centerline), nSteps or treadTarget }` sharing the style block; parents under
  `CanyonWorld.Paths`. Baked: FarWall7282Path, FarWallBridge2Path. (See the flat-shelf variant note in §1a.)
- **`buildDeckBalustrade.luau`** — formal timber post-and-baluster railing on a deck edge (FallsLanding style):
  newels + hanji result-lanterns (tagged `BlockLantern`) + caps, rail cap/mid, balusters, barrier. CONFIG `runs`:
  `{ model, deckPart, edgeDir (world {x,z}), name, inset }`; parents `Railing_<name>` under the deck. (See §1a.)
- **`buildIshigakiWalls.luau`** — finds the floating spans (>`THRESH`) of the listed `CONFIG.paths` and builds
  a battered fitted-stone wall per span into `Workspace.RetainingWalls`. CONFIG: `paths`, `HW`, `THRESH`, `PAD`.
- **`buildTimberRetainingWall.luau`** — timber-lagging wall for CUT faces (§1a "pocket" treatment): reads a
  path's `Step_<i>` beds over `first..last`, even-spaced posts, level post-to-post board bays stepping with
  grade, top following the probed cut depth. Parts-only, idempotent, into
  `CanyonWorld/Structures/RetainingWalls/TimberWall_<model>_<first>_<last>`. CONFIG `walls`: `{ model, first,
  last, edgeSign, offset, cap, seed }`. (Extracted 2026-07-09; see §1a for the load-bearing rules.)
- **`buildChochinPole.luau`** — places hanging chōchin on bamboo posts along a path's uphill edge (staggered;
  up to 30% downhill where terrain allows); tags them so `LanternController`/`ChochinSway` drive them. CONFIG:
  `path`, `timberPrefix`, `interval`, `posJitter`, `uphillOffset`, `uphillSign`, `downhillFrac`, `dhMaxDrop`,
  `seed`. Deploys into `PathLanterns.Chochin_<path>`. (See §4; locked 2026-06-29.)
- **`buildBambooRailing.luau`** — runs a continuous bamboo railing along a path's downhill/open-air edge
  (smooth top rail + rustic-jittered lower rail + posts + invisible barriers), one `Rail_<name>` sub-model per
  run, idempotent. CONFIG: a `RUNS` list (`path`, `prefix`, `i0`/`i1`, `edgeSign`) + `CONNECTORS` list to bridge
  run seams. As-built: PathSteps/PathExtension/DescentPath into `Workspace.PathRailings`. (See §4; locked 2026-06-29.)
- **`buildBridge.luau`** — gentle Japanese arch footbridges (see §7), one `Bridges.<name>` sub-model per bridge,
  idempotent. CONFIG: a `BRIDGES` list with **baked** `A`/`B` endpoints + `rise`/`width`. (See §7; 2026-06-29.)
- **`buildSuspensionBridge.luau`** — the ~112-stud kazurabashi vine/rope setpiece (see §8): catenary cables +
  suspenders + woven lattice + see-through slats over a static collision floor + stone anchor piers, into
  `Bridges/SuspensionBridge`. Endpoints read live from the abutment caps; ropes use the `RopeHemp` variant.
  (See §8; 2026-07-10, ships static — sway deferred.)
- **`buildTeahouseChochin.luau`** — swaps each teahouse's old block lamp for the latest chōchin, hung from a
  small metal hook up at the beam (no rod/cord). Reads each teahouse's OLD `Lantern` (XZ + horizontal
  LookVector = glyph facing) + `Cord` top (hang Y), so it auto-adapts to each teahouse's position, rotation,
  AND left/right mirror. Idempotent (skips already-converted). CONFIG: `CONTAINERS` list. (2026-06-29.)

**Smoke-test each on its first reuse** (faithful extractions, not all re-run from the files). **Still TODO:**
**parameterizing `SwitchbackDeck.build`** (center/footprint/terrain-feet/stair-target) so decks can be dropped anywhere.

---

## 7. Arch bridge (taiko-bashi) — `tools/studio/buildBridge.luau`

A gentle Japanese arch footbridge in the **deck-timber language** (NOT a Rojo builder — fully-curved geometry
needs `CFrame.fromMatrix`, which the pure-Lune `Spec` can't do; place-only like the paths, SAVE THE PLACE).

- **Endpoints are BAKED** (`A`/`B` = the grade-spring point at each landing), surveyed once from the approved
  prototype. **Never read draft markers at build time** — they're deleted in the finished terrain (learned the
  hard way: a marker-reading builder broke the moment the markers were removed).
- **Profile:** a **parabola** `y(t) = lerp(A,B,t).Y + rise·4t(1−t)` — gentle (rise ~3 over a ~24 span);
  **springs from grade** at both ends (no end step). Deck = ~20 short `WoodPlanks` segments whose **top** follows
  the curve (segment centre = curvePoint − ½·thick·deckNormal), each oriented via `CFrame.fromMatrix(mid, xAxis,
  yAxis)` with `xAxis` = along-curve, `yAxis = xAxis×zAxis`, `zAxis` = horizontal cross.
- **Everything squares to the bridge axis** via `CFrame.fromMatrix(pos, zAxis, Vector3.yAxis)` — newels, balusters,
  footings. (World-axis `CFrame.new` leaves them visibly cocked on a skewed span — the bug we hit twice.)
- **Curved KŌRAN railing both sides:** cap `0.3×0.6` + mid `0.2×0.3` (both follow the curve as segments) +
  plumb balusters + **end newels only**. **Top rail (cap) is dark/black timber** `30,26,20`; everything else deck
  timber `107,79,51`. **No giboshi finials** (rejected — don't match the deck architecture) and **no invisible
  fall-walls** on this bridge (user opted out).
- **Squared stone footings** (`Slate`, `WIDTH+1 × 3 × 4`) sunk at each landing so the ends don't read as floating.
- As-built: `Bridge3` (span 23.6, rise 3.0, width 6.5) in `Workspace.Bridges`.

## 8. Suspension bridge (kazurabashi) — `tools/studio/buildSuspensionBridge.luau`

The valley setpiece: a ~112-stud vine/rope footbridge across the Far-Wall canyon, ~36 studs over the river
(spec `2026-07-09-suspension-bridge-design.md`, plan `2026-07-09-suspension-bridge.md`). Parts-only + catenary
math, place-only under `CanyonWorld/Structures/Bridges/SuspensionBridge`. SAVE THE PLACE.

- **Endpoints read live** from the abutment caps (`Abutment_A_Cap`/`Abutment_B_Cap`, top face) — unusual vs the
  bake-endpoints rule, but the abutments are permanent placed structures, not draft markers. (Gotcha: if the
  abutment parts are missing/renamed the builder asserts — they were accidentally deleted mid-build once.)
- **Deck = a parabolic catenary** `y(t) = lerp(seatA,seatB,t) − SAG·4t(1−t)`, **SAG 8**, **width 6** (edge
  cables at ±3). XZ centreline = straight lerp cap→cap.
- **Ropes = twisted-hemp cylinders**, `Material=Fabric` + place-only **`RopeHemp` MaterialVariant** (generated
  via the Studio material generator, base Fabric, StudsPerTile 0.6 — there is NO native rope material). 4
  catenary cables (2 deck-edge dia 0.5 + 2 hand dia 0.36 at +2.9), vertical suspenders every 4 studs, one
  alternating-lean diagonal lattice rope per bay (the weave). **Chain the cables with `cableOverlap` (0.6 past
  each end)** so joints read seamless.
- **Deck slats:** timber cross-pieces (`6.4 × 0.35 × 0.69`, `Size.X` = cross-stream via `lookAt` with **no**
  extra 90° yaw), pitch 1.05 → ~0.36 **see-through gaps** to the river, tinted, just proud of the catenary.
- **STATIC collision floor + barriers** (direct root children, never grouped/animated): a continuous CanCollide
  floor at slat-top level so players walk safely over the gaps, and **15-tall** invisible fall barriers on both
  edges (5 was jumpable). Slats/cables are `CanCollide=false` decoration.
- **Anchor piers:** dress each abutment as a stone body + **flush walkable timber cap** (dark band tucked UNDER
  the lip, never proud) — the pier top must stay a CLEAR walk-through platform. Cables lash out to **4 low
  mooring posts at the outward corners** (cross ±5, clear of the 6-wide walk). LESSON: a central deadman post /
  raised cap block makes the pier unwalkable — keep the centre + outward exit clear.
- **Sway DEFERRED (2026-07-10):** the visible parts group into `Seg_1..10` Models, but ambient sway was
  abandoned — rigid cylinders in independently-moving segment groups visibly SEPARATE at the seams (overlap
  only hides see-through gaps; the ends still pull apart). A seamless motion pass = **continuous per-frame
  deform** (reposition all parts along one swayed curve — keeps the round ropes) **or Beam cables** (continuous
  but flat ribbons). Ships static for now.
