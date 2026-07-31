# Foliage Finish — Design

**Date:** 2026-07-30
**Status:** Approved direction (Approach 1: three engines + an asset batch).
**Program:** Item 1 of the Friends & Family Baseline
(`2026-07-30-friends-family-baseline-design.md`).
**Predecessors:** canyon garden floor (`2026-07-29-canyon-garden-floor-design.md` — care
model, palette, subtraction), forest preserve foliage
(`2026-07-27-forest-preserve-foliage-design.md` — zones, scatter tooling).

## Thesis

Every place examined with clear design intent turns out better (owner's standing
observation). This pass encodes that intent instead of hand-applying it: **plants live
where they would actually live.** The scatter system learns ecology (footing, slope,
submersion); moss learns to dwell at transitions; composition governs everything a player
walks past. The purchased assets (Xfrog Japan library, muhly, iris, moss kit) do visible
work.

## Scope decisions (settled in brainstorm)

- **All scatter-placed trees get the re-pass** — fringes (the 223 old-stock trees with
  the 205/223 footing defect), the recent Core/CoreUnder Xfrog planting, everything not a
  hand-placed hero. Heroes and the planted iris are untouched.
- **Waterline verdict: placement failures, mostly, not asset failures.** Weed/reed stock
  works in the right context — best partially submerged — and looks bad on steep
  hillsides. Ferns read drab and lifeless; verdict deferred to a context test. Iris is
  the model to copy.
- **Moss scatter gets redone.** The 829-clump pass was confetti — bits thrown around
  open ground. Moss is a transition-dweller: rock edges, bridge abutments, post and wall
  feet, the waterline splash zone, crevices.
- **Palette: convert a small accent set** from the unconverted XfrogPlants Japan library
  — Japanese maple (JA03), katsura (JA04), and **hachiku bamboo (JA14)** for the single
  reserved contrast grove (existing toolbox bamboo is suspected inferior and retires if
  the Xfrog conversion confirms it). No broad conversion.
- **Exit bar: "reads intentional at a walk-through." Explicitly not final.** This item
  gates and the program moves on.

## Part 1 — Asset batch

1. **Muhly triage + prep.** `foliage/muhly_grass/BC_PM_P013_Muhly_grass_01_FBX.FBX`
   (224 MB, untouched). It ships real opacity maps (`leaf_01_opa`, `fruit_01_opa`), so
   the blades are likely already cards → the **petal-patch** path in
   `tools/blender/prep_foliage.py`, not ribboning. Budget to a scatterable cost (the
   moss-tuft range, not the iris-hero range); produce a small variant set. Import is
   GUI-only (owner). Remember: Roblox imports FBX at 1 unit = 1 m; library scale is 20×.
2. **Three Xfrog conversions** via the proven pipeline (`tools/blender/export_tree.py` +
   `split_fbx.py`, recipes in the exporters' headers): Japanese maple and katsura as
   deciduous accents with real seasonal color; hachiku bamboo prepped for grove planting
   (expect multi-culm handling to need a pipeline look). Casting decisions (sizes, tiers)
   at conversion time, as with the conifers.
3. **Fern context test.** Place the existing fern stock where ferns actually live —
   shade, crevices, under-canopy, north faces — and judge. Keep if context redeems them;
   park the species if still lifeless. (`WaterMargin` recipe's `FernClump`, along with
   `MuhlyGrass` and `ReedClump`, names kit templates that do not exist — the recipe is
   corrected as part of Part 2.)

## Part 2 — Ecology predicates + the re-plant

Extend `tools/builders/ZoneScatter.luau` with pure, Lune-tested predicates (same shape as
the existing layer-shadowing / spacing / keep-out logic):

- **Footing** — the designed-never-built 8-point ground sample around the trunk; reject
  placements whose ground spread exceeds a per-species tolerance. Accepted consequence:
  the walls get sparser.
- **Slope** — per-species maximum ground slope (weeds/reeds excluded from steep
  hillsides; conifers tolerate more than margin plants).
- **Submersion affinity** — species opt into the water table: reeds/muhly accept (and
  prefer) feet at or below water level near the margin; everything else rejects wet
  cells. Builds on the existing WaterMap (grid-4 raycast).
- **Care-model governance** folded into `tools/studio/foliageZoneRecipes.luau`
  (reach-based GARDEN/TENDED/PRESERVE from the garden-floor spec §care model), and the
  recipe's phantom species corrected to the real post-Part-1 kit.
- **Keep-out consolidation**: fold ZoneScatter's private keep-out mechanism onto
  `tools/builders/CanyonKeepOuts.luau` — one module owns sacred ground.
- **Zone audit before any re-bake**: `Sandbox_PARKED.FoliageZones` holds 22 of the 32
  recorded zone volumes; recover or re-author the missing 10 first.

Then **wipe and re-bake**: park (never delete) the current Preserve populations and the
waterline background (707 weeds/reeds/stalks, 60 ferns, 33 bushes), and re-bake through
the new predicates — preserve zones with the conifer stock plus new deciduous accents,
waterline with muhly as workhorse + reeds partially submerged + ferns where the context
test says. Standard per-clone engine flags apply (RenderFidelity Automatic, CastShadow/
CanCollide/CanQuery/CanTouch off); DoubleSided only on dense dark foliage, never pale
(transmission blowout); sugi stay hero-only.

## Part 3 — Moss transition engine

A new small pure module (working name `MossTransitions`) replacing the broadcast scatter:

- **Seed sites, not fields.** Candidate generation from adjacencies: BasePart-meets-
  terrain contact edges (post feet, wall bases, bridge abutments, stair stringers),
  rock-meets-ground perimeters (RockLibrary instances, trail stones), the waterline
  splash band (existing WaterMap), and crevice cells (the normal-Z ramp logic already
  proven in the yamadoro material work, applied at terrain scale).
- Clump density falls off with distance from the seed edge — moss gathers *in* the
  transition and thins outward. Same seating rules the moss bugs taught (seat the box
  bottom, re-sample ground after any jitter).
- Existing 829 clumps park to `ServerStorage.ParkedFoliage` alongside the earlier culls.
- `MossLibrary` (49 prepped meshes) is the stock; no new moss assets.

## Part 4 — Composition layer

With backgrounds rebuilt, the human layer goes on top, using
`tools/studio/foliageArrangements.luau` (site grammar + 13 arrangements, extended as
needed):

- Arrangements at the named site types actually present: bridge ends, path gates, pool
  mirror, stair companions, tunnel mouths, deck corners (already stamped, hand-tune).
- **The bamboo contrast grove** — one deliberate hachiku stand as a destination moment;
  site chosen at the gate (candidate: a river-trail reach where the grove reads across
  water). Bamboo appears nowhere else.
- Iris-style hand-siting for any remaining composed moments at the falls pool and dock
  (which remain a composed site — additions join the composition, never a scatter rule).

## Sequencing

Part 1 (assets) → Part 2 (predicates, then re-bake) → Part 3 (moss) → Part 4
(composition) → walk-through gate. Parts 2 and 3 are independent after Part 1 and may
interleave; Part 4 is last because it reacts to the rebuilt background.

## Testing & safety

- All new predicates and MossTransitions are pure Lune-tested modules
  (`lune run tests/run`), matching the existing ZoneScatter test discipline.
- Every placement tool keeps a dry-run mode; every wipe parks to ServerStorage.
- All placements are place-only: **save the place** after each shipped part; tools and
  recipes commit to git as usual (stylua + selene `src tools`).

## Out of scope

Final-quality polish (later art passes may rework any of this) · broad Xfrog conversion ·
hosta or further purchases · mass sugi scatter (A13 verdict stands) · the 0–2 stud ground
cover question beyond the reach ribbon · water/hydrology work · FoliageDayNight
night-dimming (parked with the arena program's foliage notes).
