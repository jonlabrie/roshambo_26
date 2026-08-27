# Task: Grove-structured scatter (ZoneScatter pure planner)

Gate-fix feature from the T12 walk ("looks like random scatter"): canopy trees get
SOCIAL structure — tight species-coherent groves with open meadows between — and the
understory follows the groves. Pure planner only (`roblox/tools/builders/ZoneScatter.luau`
+ `roblox/tests/ZoneScatter.spec.luau` append). The Studio mirror, recipe values, and
bake are the controller's follow-up; do NOT touch other files.

## New Recipe fields (exact)

```luau
grove: {
    spacing: number, -- min distance between grove ANCHORS (meadows live between)
    radiusMin: number,
    radiusMax: number, -- member distance from the anchor
    membersMin: number,
    membersMax: number, -- trees per grove INCLUDING the elder
    memberSpacing: number, -- min distance between members of the same layer
    dominantScale: number, -- the elder's extra scale multiplier
    anchorDarts: number, -- dart-throw attempts per zone
    maxGroves: number,
}?
groveAffinity: { radius: number, inside: number, outside: number }?
```

## Semantics

**Grove pre-pass** (new, runs in `plan()` BEFORE the existing per-sample loop, for each
zone whose recipe has `grove`, in zone-array order):
- LCG stream per zone: `seedState(zone.seed + 900000)` (new offset constant, same style
  as MIST_SEED_OFFSET).
- Dart-throw `anchorDarts` candidate anchors uniformly in the zone bbox: keep a dart if
  (a) `containsXZ` (+ y-band via nearest sample like clump children do), (b) the nearest
  grid sample exists (use the Task-5 `sampleIndex` exact-cell lookup; nil → reject),
  (c) the full `accepts(zone, sample)` gate passes (keep-out, steep, footing,
  submersion, water, path — reuse the existing closure), (d) ≥ `grove.spacing` from
  every already-accepted anchor. Stop at `maxGroves`.
- Per accepted anchor: roll a DOMINANT species from the pool (existing `pickSpecies`),
  and an ATTENDANT = `pickSpecies` over the pool EXCLUDING the dominant entry (pool of
  one → attendant = dominant). Member count = integer in [membersMin, membersMax] by
  roll. The ELDER plants at the anchor: species = dominant, scale =
  `(1 + (roll*2-1)*scaleJitter) * heightScale * speciesScale * dominantScale`. The other
  members: polar offsets (angle roll, radius roll in [radiusMin, radiusMax]), each must
  find a nearest grid sample, pass `accepts`, and stand ≥ `memberSpacing` from every
  same-layer placement already in the output; species = dominant on roll < 0.6 else
  attendant; normal scale (no dominantScale).
- Grove placements append to the same `out` array (recipe's `layer`, default "canopy"),
  so later per-sample zones spacing-check against them exactly like any placement.
- Collect every accepted anchor as `{x, z}`; after all grove zones, build a bucketed
  index (reuse `ZoneScatter.indexWater` — anchors are `{ {x, z} }` cells).

**Per-sample pass changes:**
- Zones whose recipe has `grove` are EXCLUDED from per-sample resolution (they already
  planted; their samples fall through to lower zones — this is intended).
- Recipes with `groveAffinity` multiply their effective density (the same slot
  careDensity multiplies) by `inside` when the sample is within `radius` of any grove
  anchor (use `waterWithin` on the anchor index) else by `outside`.

**Determinism:** unchanged inputs → identical output. No math.random.

## Tests (append to ZoneScatter.spec.luau; use the existing flatSamples/CORE helpers)

Write REAL failing tests first (RED), then implement (GREEN). Cover at least:
1. Determinism of a grove plan (two runs identical).
2. Clustering: every placement lies within `radiusMax + 0.5` of at least one other
   placement's position cluster — simplest robust form: greedily cluster placements by
   linking any two within `radiusMax * 2`; assert cluster count ≤ maxGroves and every
   cluster has ≥ membersMin*0 (≥1) and ≤ membersMax members.
3. Meadows: with grove spacing 50 on a 100x100 flat zone, cluster centroids are ≥
   spacing * 0.8 apart.
4. Species coherence: each cluster contains ≤ 2 distinct species.
5. Elder: each cluster's max placement scale ≥ dominantScale * (1 - scaleJitter) — and
   strictly greater than the cluster's median scale when membersMax > 1.
6. Gates hold: a keepOut callback (opts.keepOut) excluding x > 50 yields no grove
   placement with x > 50 (anchors OR members).
7. Affinity: a second zone/recipe with `groveAffinity = { radius = 20, inside = 1,
   outside = 0 }` (layer "understory") plants ONLY within 20 studs of some grove
   placement cluster.
8. A grove-recipe zone no longer plants via the per-sample path (e.g., total canopy
   placements ≤ maxGroves * membersMax even though the zone covers the whole grid).

## Constraints

- Work from /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
- `lune run tests/run` all green (724 existing); lint `stylua --check src tools tests &&
  selene src tools` (selene fails on warnings).
- `--!strict`; integer LCG only; match file style.
- Commit message: `feat(roblox): grove-structured scatter - trees get social, meadows get real`
  ending with:
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
