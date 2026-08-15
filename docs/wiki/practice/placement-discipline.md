---
shelf: practice
updated: 2026-08-15
---

# Placement Discipline

Standing rule: any ZenDojo asset placement — one-off or scripted — validates the FULL
FOOTPRINT (8-point ring) AND requires terrain as the top surface at every probe. A
single centre raycast is never sufficient.

## The rule

Placing anything in the canyon (a clump, a rock, a lantern, a stand of bamboo)
requires BOTH checks at EVERY probe point, not just the centre:

1. **Footprint footing** — centre + 8-point ring at the asset's *base* radius (culm
   cluster / root spread, not canopy overhang); every probe must hit ground and the
   vertical spread stays bounded (~3.5 studs). This is ZoneScatter's T5 footing
   predicate — reuse the idea even in throwaway scripts.
2. **Terrain-top** — rays hit ALL queryable geometry (`Exclude` filter, IgnoreWater)
   and the spot only counts when `hit.Instance == workspace.Terrain`. A terrain-only
   `Include` ray sees *through* paths, decks, and rocks and plants things on top of
   them.

**Why:** the owner caught the same failure class twice in one day (2026-08-01) — pad
bamboo floating off shelf edges (centre-ray-only: 38 of 52 spots failed the real
footprint check) and clumps sitting on paths (terrain-only rays) — after the moss pass
had already hit the path variant the day before. Their words: "if you're going to throw
darts, at least throw ones that sanity-check the entire footprint of the asset."

**How to apply:** copy the `footing()` + `terrainGround()` pair from the pad-bamboo
pass (the SDD foliage ledger's 2026-08-01 entry; the scatter system itself is on
[[foliage]]); when a slot fails, SEARCH (slide along the feature, step in/out,
downscale the asset) or SKIP — never place anyway. Related: [[flush-outside-edges]],
[[walls-register-to-structure]], and the one-attempt rule on [[owner-rulings]].
