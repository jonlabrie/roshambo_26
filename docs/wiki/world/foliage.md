---
shelf: world
updated: 2026-08-15
checked: 2026-08-27
---

# Foliage

The canyon's planting: a **curated, garden-like floor** (the 2026-07-29 pivot — the
canyon is a privately managed resort, so the earlier wild-forest reading died), built
by a zone-scatter system plus hand-composed hero sites, on the XfrogPlants Japan
palette. Closed as F&F item 1 on 2026-08-05 ([[friends-family-baseline]]). The planted
state is recorded twice: `ServerStorage.FoliageSnapshot_2026_08_02` (1,828 models —
verified present 2026-08-15) and the git-side manifest
`docs/superpowers/canyon/foliage-manifest-2026-08-02.csv` (1,870 rows, survives the
place).

## The governing rules

- **Composition first** (owner ruling, F&F item 1): **scatter is background fill
  only** — hand-composed arrangements and hero placements govern; a scatter rule must
  never bury a composition someone hand-placed. This settled the scatter-vs-composed
  conflict at the waterline. (Compiled with the other rulings on
  [[owner-rulings]].)
- **The care model**: `reach(x) = 8 + 20·(x+430)/470`, clamped [8,28], measured to
  the nearest path centreline or staged-site *footprint*. GARDEN = inner 35% of
  reach, TENDED the rest, PRESERVE beyond. Staged sites override longitude — the
  falls dock carries its own 15-stud garden radius ([[falls-dock]]). Committed as
  `tools/builders/CareModel.luau`.
- **Moss is NOT governed by the care gradient** (owner caught the category error):
  the gradient governs what people do; moss grows where nobody tends. Moss density
  answers to water distance and trampling instead.
- **Green-first 4:1** (owner): outside the square, weight green species ~4:1 over
  reds/golds — the jewel maples are placed accents, not mass.
- Mandatory per-clone engine flags on every scatter bake: RenderFidelity Automatic,
  CastShadow false, CanCollide/CanQuery/CanTouch false.

## The system (committed tooling)

`tools/builders/ZoneScatter.luau` (pure planner; layer-aware spacing, vertical
keep-out bands, water map, `pathMargin` standoff from real geometry, footing
predicate) + `tools/studio/foliageZoneRecipes.luau` +
`tools/studio/scatterPreserve.luau` (Studio shell — mirrors both; keep all three in
sync) + `tools/builders/CanyonKeepOuts.luau` (material keep-outs like the Square's
sand, exact and self-maintaining; volume keep-outs like the karesansui +4 studs).
Zone volumes live at `ServerStorage.FoliageZones` (35, verified 2026-08-15 — this
resolves the old "22 of 32 unaccounted" worry). Arrangements grammar + 13
pre-composed groups: `tools/studio/foliageArrangements.luau`; site-derived bake
`tools/studio/bakeArrangements.luau` (`82313a4`), which reads the `KO_*` keep-outs
(`2b07380`). Blender pipeline: `tools/blender/export_tree.py` (skirt trimming,
smart/proportional wood, root-flare budget), `triage_tree.py` (coverage metric — %
kept is a trap), `prep_foliage.py`, `export_forest_kit.sh` (the reproducible kit
export).

## As built (gated 2026-08-02)

- **Grove-structured world**: 590 tree placements over 4 owner-marked stands; the
  preserve on the Xfrog palette (canopy adults sparse, trimmed mediums + brush youngs
  dense at eye level; hinoki backbone, sugi hero accents, spruce workhorse, fir
  fill; Yoshino cherry replaced the transmission-blowout sakura).
- **Arrangements sweep**: 22 arrangement groups standing in
  `CanyonWorld.Foliage.ArrangementsDraft` (verified 2026-08-15; owner: "I can work
  with this"), zero inside any keep-out after the pad keep-out fix.
- **East backdrop** (`0c8609a`): 35 skyline trees on the scenery country east of the
  canyon — the far end of the canyon's longest sightline; sited by slope, pockets
  chosen by the owner.
- **Waterline**: 99 ishigumi shore rocks at pool waterlines; reed/weed mass = the
  wild register, culled by band (238 instances parked, never deleted:
  `ServerStorage.ParkedFoliage.MarginCull_2026_07_30`); **terrain grass painted into
  the bank IS the 0–2 stud ground layer** (rev 1 accepted 2026-08-01 — it was never
  an asset problem), honouring keep-outs via `repairKeepOutGrass`. Iris ensata
  planted at the falls pool (1 hero clump + 8 singles, every one in genuine wet
  margin, `placeFallsPoolIris.luau`); 52 bamboo clumps screen the 14 pad-slot
  terrain walls.
- **Cut/parked, do not revive without cause**: moss ground scatter (visual A/B
  2026-08-01, "nothing is lost" — 1,247 clumps at
  `ServerStorage.ParkedFoliage.MossTransitions_2026_08_01`, verified present; the
  live `MossScatter` folder is gone, which is correct); muhly grass (two full
  techniques failed the gate; kit at `ParkedFoliage.MuhlyKit_2026_07_31`, verified —
  revive only with a proper game-ready asset).
- **LOD + atlas colour pass** (accepted 2026-08-02): cheap maple variants, offstage
  culling (`cullOffstage`), skyline swaps, hotter gold/red maple atlases that hold
  colour at distance (gold `104112050806577`, red `125377348277491`; recipe in
  `tools/textures/recolor_leaves.py`).
- Perf ground truth: the foliage was clean in the 2026-08-05 audit (3,580 MeshParts,
  0 Precise, 96 deliberate shadow casters); mobile memory is engine floor, not
  content — the binding constraint is GPU triangles.

## Gates & decisions

- 2026-08-02 owner gate closed item 1: exit bar "reads intentional", explicitly not
  final. Punch-list handled by audit; 63 HALF_BURIED trees deliberately left for the
  eye.
- Species/tier calls: young/medium Xfrog stages carry eye-level density; both flared
  and `_NR` tiers approved ("they all work great") — **do not re-trim from the
  numbers alone**; judge foliage in Play at eye level, not Edit stills.
- Bamboo rejected as a monoculture (fights the mossy-gorge north star); kept for one
  contrast grove idea.
- Planting depth: measured on the owner's drag-into-ground rig
  (`Sandbox.PlantDepthRig`), stored as `PlantDepth` attributes — build the user a rig
  rather than inventing a metric.

## Raw layer

- specs: `2026-07-27-forest-preserve-foliage-design.md`,
  `2026-07-29-canyon-garden-floor-design.md` (`33fda03`); plan + ledger
  `.superpowers/sdd/2026-07-30-foliage-finish/progress.md`
- key commits: `82313a4` arrangements sweep · `0c8609a` east backdrop · `6473252`
  manifest · `2b07380`/`4a82491` keep-out fixes · `0625b7f` skirt trimming ·
  `4e1879e` path standoff + planting depth · `586b955` gated preserve values ·
  as-builts `a294e59`, `5357c2b`
