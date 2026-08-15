---
shelf: practice
updated: 2026-08-15
---

# Build Recipes

**CONSULT FIRST before building, FIXING, or modifying ANY canyon path, switchback
deck, retaining wall, railing, or lantern.** The canonical recipe doc is
`docs/superpowers/references/zendojo-canyon-build-recipes.md`; prefer the reusable
builders in `roblox/tools/studio/` (`buildSteppedCobblePath.luau`,
`buildIshigakiWalls.luau`, `buildChochinPole.luau`, `buildBambooRailing.luau`,
`buildBridge.luau`, `buildTeahouseChochin.luau`, `buildHanabiyaChochin.luau`,
`buildIshidanStairs.luau`, `reskinPath.luau`). The dated as-built specs in
`docs/superpowers/specs/` hold exact per-build numbers + published asset IDs.

**Do NOT reverse-engineer dimensions/materials from existing placed Parts** (e.g.
eyeballing `ExtBed`). The recipe is the source of truth — matching one stray part
misses the rule (learned fixing the upper-path bed; the owner corrected it). And make
ONE attempt, then stop and let the owner look ([[owner-rulings]]).

## Chōchin

**THERE ARE THREE CHŌCHIN BUILDERS AND NO SHARED MODULE** — pole, teahouse, and
shopfront — because Studio tools are pasted whole into a session and cannot require
each other. The lantern itself (LS 0.65/0.9, Rmax 0.65, bodyH 2.8·LS, 18 neon slices,
16 ribs, PAPER {200,170,143} at T 0.42) is copied in each. **Retune one, retune all
three**, and check the copy you are editing says so in its header.
`buildHanabiyaChochin` hangs off a BUILDING (no pole/arm/brace), reads the eave's
underside as a PLANE off its CFrame because it is tilted, and places from the eave's
own extents so the lanterns follow the overhang rather than the wall.

**KEEP THE GLYPH PLATES on any new chōchin.** They look like decoration. The
`RoundLantern` tag on GlyphPlateA/B is how LanternController shows the World Throw AND
how PaperLanternDayNight finds the barrel to ride with nightFactor — drop them and the
lantern silently blazes at noon ([[day-night]]).

**Teahouse chōchin:** the legacy teahouses came in left/right-handed (mirrored)
versions, each placed at its own rotation. `buildTeahouseChochin` handles that by
reading each teahouse's OLD `Lantern` (position + LookVector) + `Cord` — never assume
a shared orientation. Latest chōchin hangs from a small metal hook at the beam (no
cord), CanCollide off. (The 14 legacy teahouses are retired to
`ServerStorage.RetiredLegacyTeahouses` — see [[teahouses]], [[place-state]].)

To mirror a chōchin to the path's other side: rotate the whole model 180° about the
vertical through its Step centerline (+ update Swing.WorldPivot). Newel lantern stack =
newel→lantern→black-cap LID.

## Path creation

**NEVER depend on draft markers in a final/extracted builder** — they're deleted in
the finished terrain. BAKE surveyed coordinates into the builder (like SwitchbackDeck
bakes its placement). Learned the hard way: `buildBridge` first read
`PathDraft.Bridge3_A/_B` and broke the moment the owner removed the markers.

**PATH-CREATION FLOW (don't forget the terrain handoff):** owner lays draft markers →
**I carve a rough terrain path along them** (my step, not the owner's) → owner smooths
it → I build the path (Catmull-Rom → timbers + gravel bed + flagstones) →
walls/chōchin/railings+barriers. (Recipe §0 step 4.)

**Stepped-cobble TREAD keys to the DOWNHILL (lower) timber**
(`tread = math.min(A.grade, B.grade)`) — the timber is the FRONT (downhill riser) of
its step, not the back. Fixed 2026-06-30; `min` is order-independent. Recipe §1.

**VALLEY paths = TWO ishidan runs.** `buildIshidanStairs` (and `IshidanStairs.layout`)
assume MONOTONIC ASCENT per flight — a descending flight collapses to ONE giant step.
A down-then-up path must be split at the LOW point into two ascending runs, both
footed there, with grade-break landings at the inflections.

**BENCH/junction landing:** where two runs meet at a valley low, don't leave colliding
rail-ends + doubled chōchin — shorten both paths by the foot step, drop a small flat
ishidan flag landing (the §1a Voronoi flag pipeline on a flat gravel pad; **flags sit
+0.05 proud of the bed** — flush-to-bed reads as buried), one uphill chōchin, leave
the open side as access.

**Path-collision gotcha:** big procedural MeshParts use `CollisionFidelity=Hull`
(immutable from script on EditableMesh-built meshes) → the convex hull of a long
descending ribbon becomes a giant wall, and a cobble mesh alone has gaps (no real
floor). FIX = per-gap Concrete `Bed_*` slabs per the recipe (box collision; also
restores the gravel look). Paths are place-only — SAVE THE PLACE after
([[place-state]]).

## Terrain-carve gotchas (learned hard 2026-06-30)

- **A Terrain raycast in the SAME `execute_luau` as a Terrain edit reads STALE**
  (pre-edit). ALWAYS verify a carve/fill in a SEPARATE call — same-script "it got
  worse" checks are bogus.
- **To CARVE a path DOWN through high ground, cut ONLY** — clear `Air` above a target
  floor that is `≤` terrain; NEVER `FillBlock` a solid column up to a target that sits
  above nearby geometry (that's an embankment that BURIES the existing path/markers).
  "Carve" = excavate, not build up. Snapshot region → ServerStorage first; restore via
  `PasteRegion(region, corner, true)`.
- **Live-position placement:** the `Edit` datamodel is UNAVAILABLE while the owner is
  in Play (and `Server` is unavailable in Edit) — capture the avatar pos via a
  `Client` `execute_luau`, then build in `Edit` after they stop Play. A raycast from
  high above at a tunnel spot hits the tunnel **ROOF** — cast down from just below the
  roof (≈ the HRP height) to land on the actual floor. (More Studio-MCP quirks:
  [[studio-tooling]]; tunnel boring: [[misc-engine-traps]].)

## Walls, railings, barriers

**TIMBER RETAINING WALL (the CUT-face treatment; §1a's "pocket/cutting" — built
inline, match `workspace.RetainingWalls`):** boards are **HORIZONTAL and LEVEL** (NOT
raked to the grade — raked was rejected), Wood **79/67/55**, ~7 long ×0.71 ×0.40,
stacked ~0.75 course pitch, in **BAYS between posts** (each course a level plank
spanning post-to-post + a tuck; the WALL steps up in bays with the grade while planks
stay level). Posts 1.1×12×1.1 Wood 45/48/56 at bay ends + ~6.5 spacing, **+1.0 proud**
of the boards (normalize fixed-height posts to a uniform proud, holding each base).
**Register ~4.7 off the tread centerline** (bed half 2.9 + ~1.8), to the BUILT
structure NOT the excavation ([[walls-register-to-structure]]). Height cap **11**;
where the cut is taller, raw cliff rock reads above the top board. **HOLD OFF until
the cut is tall enough to matter** (skip 1–3 stud banks — owner rule).
`buildIshigakiWalls` is the STONE ishigaki, for UNDER-path FLOATING spans (§3), NOT
cut faces.

**Railings:** bamboo railing (`buildBambooRailing.luau`, LOCKED v2 2026-07-02: warm
tan 118/95/52 + rounded ellipsoid node collars + slim proud posts + per-run
jitScale/postEvery); deck-style raked stair railings on the SwitchbackDeck stairway
(ONE baluster per step, extended down to a flagstone foot newel). **All invisible
fall-walls = 15 studs** (a player can jump onto a rail cap then re-jump to clear a
10-stud wall; 15 defeats it). Keep the walkable gap between barriers ≥ ~3 studs
([[flush-outside-edges]]).

**Engawa fall-barriers + collision groups:** invisible 15-stud barriers along each
teahouse's `RailCap` live in `Workspace.EngawaBarriers` (per-teahouse sub-model,
survives rebuilds), CollisionGroup **`EngawaBarrier`** (collidable with
Default=players; NOT collidable with **`Projectile`**). Client particle/beam VFX never
collide, so barriers don't block fireworks off the verandas; a future *physical*
projectile just needs CollisionGroup=`Projectile`. ([[teahouses]], [[fireworks]])

## Lantern functionality

Block `*Lantern` parts are FUNCTIONAL World-Throw result-displays ONLY as descendants
of `workspace.RoshamboStage` (LanternController scans the stage by name) — decks live
under RoshamboStage, ad-hoc paths under Workspace. Chōchin work canyon-wide via the
`RoundLantern` tag (on GlyphPlates) + `ChochinSwing`. **Overlook
(`RoshamboStage.Overlook`) is the DECK style ref** (WoodPlanks 107/79/51 slab +
girders + 1.5-sq posts + kōran).

## §1a Ishidan steps — THE canonical step style

User-locked 2026-07-02 on the NW1012 stairway, from their original reference image:
**worn dark timber riser beams (72/60/48 ±7) + fine `ZenGravel1` gravel beds + flat
Voronoi flagstones with rough NOTCHED outlines** (subdivide → radial jitter + 12%
notches → ONE Chaikin; rolled-edge profile, smooth normals; palette grey 78–116 mean
~96, 35% warm). Full parameters: recipe **§1a**; engine:
`roblox/tools/builders/IshidanStairs.luau` (`layout` + `dress`, Lune-tested) mirrored
in `roblox/tools/studio/buildIshidanStairs.luau`.

**Supersedes** the §1 stepped-cobble (dome cobbles read as river stones) and the
interim slate-slab style; all pre-existing paths were converted 2026-07-02 via
`reskinPath.luau` (railings v2.1, resample+relax line, stitched multi-path runs).
Rules: **relayout when old risers exceed ~0.8; preserve geometry otherwise. Flag-mesh
chunking by FLAG COUNT (~40/chunk), never steps** (deep treads pack 8–14 flags each);
≤20 steps per published chunk (Studio triangle limit), CanCollide false. **New paths:
`buildIshidanStairs.luau` with a baked centerline.** Companion treatments: the timber
retaining wall above; landing decks with flush black frame band, no railings by
default.

## §1 Organic cobble path (historical — superseded by §1a, technique still reusable)

The FarWall prototype (2026-06-26/27): flat river-cobble treads in cement gravel,
stepping at heavy timber risers. Committed design doc:
`docs/superpowers/specs/2026-06-26-zendojo-organic-path-system.md` (★ FINAL WORKING
RECIPE section). Durable pieces:

- **The 5-step order (do NOT start with the timbers):** (1) meander spline route from
  markers; (2) **SHAPE THE TERRAIN FIRST** — carve/fill a smooth continuously-graded
  BENCH along the spline (this is what prevents float-over-terrain gaps); (3) ribbon
  MeshPart (cement-gravel bed) conforming to the bench; (4) timbers (risers 6.4×1.6×1.2
  Wood) + cobbles; (5) ishigaki wall only where the bench still drops to natural
  terrain — it FINISHES the edge, it doesn't carry the whole gap.
- **Voronoi cobble builder** (one combined EditableMesh, deterministic seed): per-stone
  footprint = Voronoi cell from UNEVEN random seeds (grids read uniform; 0.55-stud min
  separation), clipped by perpendicular-bisector half-planes; 1-pass Chaikin corner-cut
  (2 passes = too smooth); multi-ring hemisphere dome, **smooth normals via
  sphere-projection** (flat per-face normals read as faceted pyramids); per-stone
  vertex colour (survives publish) near-monochromatic 122,127,117 ±4; section leveling
  to the downhill timber top; DoubleSided, CollisionFidelity=Box, verts local then
  PivotTo.
- Cross-mesh cobble TONE mismatch is an unbeatable world-space quirk → ONE mesh +
  flat-up normals. A continuous-slope ribbon buries flat cobbles on steep pitches →
  STEP the ribbon.
- **HEIGHTS MUST BE ANALYTIC — NEVER RAYCAST A MESH FOR Y.** A MeshPart with
  CollisionFidelity=Box returns its flat bounding-box lid (constant Y), so anything
  keyed off it comes out level instead of following the grade. Derive surface heights
  from the timber tops (the known grade) interpolated along the path. Terrain raycasts
  ARE fine — they hit real voxels.
- Timbers sunk via an idempotent `OrigY` attribute then `Y = OrigY - SINK`, so re-runs
  don't double-sink.
- Bed materials: **ZenCement1** (cool grey speckled cement, reads as river gravel at
  StudsPerTile 10 — owner wants it kept in the library at this scale); **ZenCement2**
  = a clone at StudsPerTile 5 (finer), tint 138,142,142 (neutral cool grey; warm tints
  read brown; black is wrong — a mid grey a touch darker than the stones).

## §9 Mossy terrain PBR

Canyon terrain reads "lush green moss over dark wet stone" via a custom PBR
`MaterialVariant` applied as a **terrain override** — not paint or colour-tint. Full
recipe (params, live asset IDs, texture pipeline): recipe doc **§9**. In one breath:
convert canyon Basalt → Slate (slate renders smoother under the override), then a
MaterialVariant (BaseMaterial Slate) with `TerrainDetail` Top=moss / Side=rock (engine
auto-blends by slope), activated by the Material Manager **"Set as Override"** toggle.

Three hard-won gotchas:

1. **`MaterialPattern` MUST be `Organic`** — the default `Regular` is parts-only and
   silently won't render on terrain.
2. **Override activation is Material-Manager-UI only** —
   `MaterialService:SetBaseMaterialOverride` returns success but does NOT render; the
   UI toggle is the only way (guide the owner, 2 clicks).
3. **The override re-skins EVERY part using that base material, not just terrain** —
   260 Slate-material build parts got re-skinned to dark wet rock (accepted as
   cohesive). New builds wanting plain stone must NOT use raw `Slate`
   ([[material-and-mesh-traps]] §2).

Texture pipeline: CC0 from ambientCG (Moss004, Rock035) → `curl`+`unzip` →
`upload_image` only accepts trusted URLs, so serve via
`python3 -m http.server 127.0.0.1` and upload localhost URLs. Tint/de-tile with
ImageMagick `-modulate`/`-brightness-contrast`; reduce distant tiling with **bigger
StudsPerTile (moss=18)**, NOT by flattening the texture (washes out).

Related: [[switchback-deck]], [[paths]], [[editablemesh-gotchas]],
[[texturing-pack-meshes]], [[derive-from-what-it-touches]].
