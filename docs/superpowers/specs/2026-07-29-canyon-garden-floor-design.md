# ZenDojo Canyon — The Garden Floor

**Date:** 2026-07-29
**Supersedes:** the wild-forest reading of `2026-07-27-forest-preserve-foliage-design.md`.
That spec's tooling, zones, water map and keep-outs all carry over unchanged; what changes
is the register the floor is planted in, and where the care boundary sits.
**Complements:** `2026-07-28-canyon-destinations-falls-dock-design.md`, whose rule —
*richness only where players actually stand* — this spec turns into a formula.

---

## 1. Why the pivot

The 694-tree preserve bake reads correctly as a forest. The objection was not that it
failed, but that a forest is not what the canyon wants to be. The canyon is a **privately
managed resort**, and its floor should read as **curated and garden-like**, with a forest
preserve nominally tended by locals, staged sites like the falls-pool dock, and a
riverside path running west from the Square to the upper pools.

This forces one amendment to an existing law. The first aesthetic law of the foliage spec
reads *"pruned flora only where the resort tends; the preserve is untended."* The boundary
was drawn at the Square and the teahouse approaches. **It now extends along the path and
around every staged site, and the preserve itself is tended rather than wild.** The law
survives; its boundary moves.

## 2. The care model

Care is expressed as a **reach in studs** rather than an abstract level, so every value can
be paced out and judged in world.

```
reach(x) = 8 + 20 * (x + 430) / 470        clamped to [8, 28]
```

where `x = +40` is the Square and `x = −430` the western pools. The distance it is
compared against is **to the nearest path centreline, or to the nearest point on a staged
site's footprint** — footprint, not pivot, so a long deck tends its whole length rather
than only its middle. `x` in the formula is the x of the *sample being planted*, not of
the path.

| | x | reach | GARDEN within | TENDED within | beyond |
| --- | --- | --- | --- | --- | --- |
| Square | +40 | 28.0 | 9.8 | 28.0 | preserve |
| mid-canyon | −200 | 17.8 | 6.2 | 17.8 | preserve |
| dock | −345 | 11.6 | 4.1 | 11.6 | preserve |
| west end | −430 | 8.0 | 2.8 | 8.0 | preserve |

**GARDEN is the inner 35% of `reach`; TENDED is the remainder; everything else is
PRESERVE.**

**Staged sites override longitude.** Each carries its own garden radius irrespective of
where it sits, measured from its footprint: the **falls-pool dock gets 15 studs**. This is what makes the dock a
lantern-lit island in wild country rather than an anomaly at the wrong end of a gradient.

Two properties this is tuned to produce. Near the Square care reaches **wide** (28 studs),
so the resort's front yard feels continuous. Out west it is a **ribbon** (8 studs), so the
path threads *through* wildness instead of parting it. Walking west is the band narrowing
around you — the register changes without anything announcing it.

## 3. What each register is made of

Material and geometry are listed separately because they have completely different costs.
Material is free; geometry is the A13 budget.

| | **material** (free) | **geometry** (only inside `reach`) |
| --- | --- | --- |
| GARDEN | mossy slate/rock, **`ZenGravelFine`** (§6) | cherry / Japanese maple / katsura specimens, niwaki pruned pines, set stones, **iris at the water** (hosta only if the triage in §6 passes), moss mounds for silhouette |
| TENDED | mossy slate/rock | thinned preserve mix, occasional cherry/maple, clumped thickets incl. Hachiko bamboo, muhly, fern clumps |
| PRESERVE | as-is | the current bake, unchanged |

**Understory is cleared by the same gradient** — open floor and legible trunks near the
path and sites, thinned and clumped in the middle, current 360-tree density in the deep
preserve. Clearing the floor is most of what tending a wood actually is.

**Bamboo is TENDED, not garden or preserve.** Managed bamboo is a satoyama crop: it reads
as worked land, and it is the best screening plant in the kit for hiding what a reveal
should not show yet.

**Niwaki stays GARDEN-only.** That part of the original law is unchanged.

Moss is **material first**. `CanyonMossySlate` (Slate, Organic, StudsPerTile 12) and
`ZenMossRock` (Rock, Organic, 10) already exist and are already painted; **80 of 181
ground samples along the river corridor are Slate**, so nearly half the walkable floor is
mossy already. The purchased moss kit supplies *silhouette* — a modest number of clumps at
close range — not ground cover.

A consequence worth stating plainly: **ground cover only has to exist inside `reach`.**
The 0–2 stud layer has been an open worry since the foliage spec, with a specific fear of
"hundreds of small alpha plants at the camera" on the A13. Scoped to a ribbon either side
of the path plus the site radii, it is a small fraction of the floor, in the one place it
does the most work. The problem shrank by being scoped rather than solved.

### The waterline

The existing margin is **1,044 parts in six species**, and 888 of them — 85% — are weeds,
reeds and stalks. That mass *is* the wild register.

| species | count | band |
| --- | --- | --- |
| tall_weeds | 311 | waterline |
| reedy_mid | 299 | waterline, shore |
| weed_stalks | 278 | waterline |
| large_fern | 69 | mid |
| fern | 51 | shore |
| bush | 36 | mid |

- **`large_fern` is cut entirely** — all 69, **parked to ServerStorage, not deleted**,
  per the existing `*_PARKED` convention. User decision.
- **The 888 weeds are removed in GARDEN, thinned and clumped in TENDED, untouched in
  PRESERVE.**
- Subtraction does most of the visual work here. Removing weeds reads as *tended* faster
  than planting anything does.

## 4. The footing fix

The planner seats every tree from a **single ground raycast at its centre**. That is fine
on open ground and fails wherever the sample sits near an edge or on a narrow ledge — the
trunk then overhangs, with its base in free space. Measured by sampling 8 points around
each trunk's radius:

| population | fine | marginal | **bad (>3 stud gap)** | worst |
| --- | --- | --- | --- | --- |
| FringeNorth | 5 | 5 | **98 of 108** | 65 studs |
| FringeSouth | 3 | 5 | **107 of 115** | 72 studs |
| Core | 77 | 8 | 16 of 101 | 20 studs |
| CoreUnder | 345 | 9 | 6 of 360 | 15 studs |

**205 of 223 fringe trees — 92%.** The fringe amplifies the flaw twice: it plants cliff
walls, which are all edges, and it uses toolbox blobs whose trunks are **radius 4–10 studs**
against the Xfrog understory's 0.4–0.7.

This is a fourth member of a known family. Layer shadowing, cross-kind spacing, 2D
keep-outs over cliff perches and now footing are all *"the planner reasons about a point
where the tree is a volume."*

**Fix:** a **footing predicate** in `ZoneScatter` — sample 8 points at the trunk radius,
reject the placement if the worst gap exceeds a per-layer tolerance. It belongs in the
planner because it is the cause, it is pure and unit-testable like the other three, and it
protects Core and CoreUnder too.

**Accepted consequence: the wall gets sparser.** Rejecting 92% of current fringe
placements thins the cliffs substantially, and that is fine. Compensate with more candidate
samples — the planner is seeded and deterministic, so it can try many and keep the ones
that stand up.

**Also: discrete size tiers, not more jitter.** The current fringe is per-species scale
(ConiferA 0.7, B 0.62, C 0.9, CedarM 1.0) with `scaleJitter` 0.35. Jitter around a single
mean stays unimodal and still reads uniform. **Two or three weighted size classes per
species** give the emergent / canopy / suppressed hierarchy real stands have. Smaller trees
on a cliff face also read as further away, which the fringe wants anyway.

## 5. Sub-project 1 — the river path

**Build this first.** `reach` is measured from path geometry, so the floor cannot be baked
until the path exists. Baking sooner means baking twice.

### The terrain has already staged it

Valley-floor profile along the river corridor, sampled at 20-stud intervals:

```
x  +60 → −80    108.7 → 109.9    FLAT — 140 studs of Square terrace
x  −80 → −100   109.9 → 134.4    ▲ 24.5-stud riser
x −100 → −240   134.4 → 174.8    steady ~29% climb
x −240 → −300   174.8 → 177.2    FLAT — a natural bench
x −300 → −420   177.2 → 213.0    climb; the dock sits at −345
x −420 → −440   213.0 → 263.9    ▲ 51-stud riser (the hero falls headwall)
```

Walking west is climbing **155 studs**. Two risers and two terraces divide the route into
chapters with nothing invented.

| chapter | x | character |
| --- | --- | --- |
| Square terrace | +60…−80 | Level, GARDEN register, reach 28 — the resort's front yard |
| **First riser** | −80…−100 | 24.5 studs of ishidan stairs. A deliberate threshold: you leave the Square here |
| Mid climb | −100…−240 | Steady ascent, reach narrowing, register turning satoyama |
| **The bench** | −240…−300 | Flat. Bench, lantern, a view back east |
| Upper climb | −300…−420 | Wildest stretch; the dock at −345 is the lit island in it |
| Falls headwall | −420…−440 | **Already served by `NW80FallsStair`** — do not rebuild |

### Character and extent

A **stroll route that is also a lit line seen from above**. The destinations spec names
"the lit path threading the gorge" as one of the things pad owners look down at, so the
same build earns its keep twice: staged reveals and benches at ground level, drawn light
from 200 studs up. It **holds a terrace above the water**, crossing only where the river
demands it.

The build runs roughly **x +60 to −380** and ties into existing infrastructure at the west
end (`NW80FallsStair` at x −392, `FarWallBridge2Path` at x −411). It is a **valley-floor
promenade**, categorically unlike the existing 15 paths, which are all wall-hugging
switchback descents on the FarWall (z −66…−103) and NW (z +21…+83) — the river corridor
itself (z −30…+15) is currently path-free.

**The two risers are the only real engineering.** Everything between them is a graded walk
on ground that already slopes reasonably. Stairs use the ishidan recipe (§1a of
`zendojo-canyon-build-recipes.md`); graded runs use `CanyonPath`; lanterns throughout.

**Route:** the survey above fixes the corridor; the user drags markers to fix the line, and
the builder bakes them — the same workflow as the dock.

## 6. Sub-projects 2 and 3 — named, specified separately

**Sub-project 2 — the water-margin palette.** Independent of the path; can run in parallel.

Assets are bought and on disk at `~/Desktop/Roshambo Reference/foliage/`:

- **Iris ensata** ($32) — correctly *hanashōbu*, the wet-margin species, not *ayame*.
  **12 separate FBX variants**, 0.5–9.2 MB; the listing's 3.3M polygons is the total across
  all twelve. Flowers carry an Opacity map (carded); **leaves have Diffuse + Normal only,
  so the blades are solid geometry.** Iris blades are flat straps, the best case for that,
  but `triage_tree.py` must rule before more solid-geometry plants are bought.
- **Moss 7 Species and Stones** ($23) — the two useful files total under 2 MB:
  `Moss_ScatterElements_AssetKit.fbx` (503 KB, 49 low-poly elements) and
  `Stones_LowPoly_AssetKit.fbx` (1.4 MB, 5 stones). **Avoid `Moss_AllAssets_AssetKit.fbx`
  — 157 MB of high-poly patches.**
- **Hosta ($29) deliberately NOT bought** — held behind the iris triage, since it is the
  harder case (broad rounded leaves, 1.57M polygons, no low-poly variant advertised).

Also in scope: **`ZenGravelFine`** (StudsPerTile ~1.25 → 0.28" stones, `Part.Color` white)
for garden-band ground. Gravel041's ColorMap (`84735195211963`) and RoughnessMap
(`120842997538838`) are **already uploaded** — `groovegravel.py` built the karesansui
`RakedSand` variants from the same set — so only an un-grooved NormalGL needs uploading.

**Sub-project 3 — the floor re-plant.** Depends on both. The care model into
`foliageZoneRecipes.luau`, the footing predicate and size tiers into `ZoneScatter.luau`,
then wipe, re-bake, curate.

⚠️ **Resolve before re-baking:** `ServerStorage.Sandbox_PARKED.FoliageZones` holds **22**
zone volumes; the foliage spec records **32** built. Ten are unaccounted for — most likely
lost when the whole Sandbox was parked for the A13 benchmark. Re-baking against 22 zones
will not reproduce what was approved.

## 7. Corrections to existing documents

Three claims in the current record are wrong and should not be carried forward:

1. **"The waterline is bare."** It is not. `CanyonWorld.Foliage.WaterFoliage` holds 874
   waterline parts plus 105 mid and 65 shore, **49 of them within 30 studs of the dock**.
   What is missing is the *scatter capability* — `MuhlyGrass`/`ReedClump`/`FernClump`
   templates do not exist, so the WaterMargin recipe warn-skips ~123 placements.
2. **"`ZenGravel1` is broken on 356 parts."** It is a dangling reference, not damage. All
   356 are `Step_<i>` flagstone beds; they fall back to `Concrete` tinted 150/146/138,
   which reads correctly as the "speckled cement gravel bed" the recipe describes, and the
   user has walked them without complaint. **Building the variant as specified would make
   them worse:** Gravel041's colour map averages 141/139/118, and 141/139/118 × 150/146/138
   lands at **83/80/64** — dark olive-brown. Leave the path beds alone. If photographic
   gravel is ever wanted there, `Part.Color` must move to white in the same change.
3. **The recipe's gravel spec is internally inconsistent.** `ZenGravel1` is described as
   "fine decomposed granite" at **StudsPerTile 4**. Measured, Gravel041 has **53 stones
   across the tile**, so at 1 stud = 1 foot, StudsPerTile 4 gives **0.91-inch stones** —
   coarse river gravel, ~3× too big for the words. Fine decomposed granite is StudsPerTile
   1.0–1.5. Note also that `MaterialVariant` has **no `Color` property**; the tint is
   `Part.Color`, multiplied against the ColorMap.

Minor: the reference-folder reorganisation into `materials/` and `foliage/` orphaned two
default paths in `roblox/tools/blender/export_forest_kit.sh` (lines 26–27). Both are
env-overridable, so it is a one-line fix.

## 8. Out of scope

The Overlook and Statistics room at the east end. Hosta, pending the iris triage. Fireflies.
Re-texturing the existing path beds. Any change to the wall fringe's *species* (the cheap
toolbox blobs stay — distant scenery is the wrong place to spend the A13 budget; only their
seating and size distribution change). Performance reduction: the standing decision remains
build what we want and cut later.
