# ZenDojo Canyon Teahouses — Design

**Status:** design in progress (2026-06-20). Teahouse *form* is locked + prototyped; this spec covers turning it into a **parameterized builder** with per-site variation.
**Branch:** `m4b-zendojo-art-pass`
**Sub-project 2 of the "canyon village"** (paths → **teahouses** → bridge → interiors/spawns)

## Goal

Place the ~18 **cliff-perch teahouses** up both gorge walls, each hanging off a path **spur** (sub-project 1). One reusable, idempotent **`Teahouse` builder** stamps them from a per-site spec, so the whole set is regenerable when the design changes, while still allowing genuine per-location differences (egress side, stilt mode, etc.).

## World frame (context)

- Clearing at world origin, floor ≈ y112; gorge up-canyon (−X) and down-canyon (+X); walls on both ±Z. Terrain is organic — **Y is always provisional**, raycast-snapped at build.
- `StreamingEnabled = true`; ~50 players/server. Persistent-model rules apply to anything that must stream as a unit.
- The veranda faces the clearing **bell rig** (the "shrine" = Shōrō/Bonshō ≈ (−2,·,1)) by convention, unless a site overrides facing.

## The locked teahouse form (source of truth)

The teahouse *design* is already locked and prototyped on `TeahousePrototype` (perched in the cleft above path marker `NearWall_12`). The canonical recipe is **`roblox/tools/studio/teahouseUpgrade.luau`** (idempotent `upgrade(model)`, commit 9e4717f) — this builder spec exists to **port that recipe into a parameterized Lune builder**. The locked form, all in the model's LOCAL frame (`GetPivot`):

- **Engawa veranda 8 studs deep**, wrapping front (−Z) + right (+X), corner filled.
- **Kōran (railing) flush to the engawa floor outer edge** — newel outer corners sit on the floor corners; cap + mid rail + newels + balusters.
- **Interior PointLights contained**: `InteriorGlow` 1.1/Range13, `Lantern` 0.9/Range9, both `Shadows=true` (no spill above the eaves). Visible glow is the Neon `ShojiGlow` only.
- **Shoji glow dimmed**: `ShojiGlow` Neon at (127,103,70). Shoji only on the two engawa-facing sides; back/left solid.
- **Walk-through doorway** in one bay: the shoji skin + glow **and the 4 `Mull` lattice bars** all set non-colliding/transparent (mullions are separate parts — must clear them too).
- **Chōchin lantern at an eave corner** on a cord up to the hip; the lantern is a multi-part assembly (Lantern + Cord + LanCap + LanRib) — moved/placed as a unit.
- **4 hip rafters** under the eave mitres (ridge apex → eave corner, slight overhang).
- **Black (45,48,56) understructure**: recolored deck frame + a **6-post perimeter frame** (4 corners + mid of each long side) under a full perimeter-beam rectangle (footprint = teahouse + half the engawa width) + joists. Posts are yaw-aligned (not world-axis), outer corners flush to the beam outer corners, raycast down to terrain (cliff-aware).

## Regenerability principle (why per-site variation must be data, not hand-edits)

The builder is **idempotent — it rebuilds (destroy + recreate) on every run**. Therefore:

- **Do not hand-edit placed teahouses in Studio** and expect it to survive — a builder re-run wipes it. The default-but-wrong instinct ("place, then tweak each one by hand") defeats the builder.
- **All per-location variation is an input** (a site-spec field or an override callback), so re-running regenerates the variation deterministically. This mirrors the paths pipeline (draft markers → bake → builder snapshot).

## Per-site spec

Teahouses are placed from an ordered list of **site specs**, baked into `ArenaLayout` (authored via the same draft-marker → bake flow as paths). One entry per teahouse:

```
{
  name        = "Teahouse_07",        -- stable id (used for idempotent find/replace)
  cf          = <CFrame>,             -- placement pivot (position + yaw); Y provisional, snapped
  facing      = "bell" | <Vector3>,   -- default: veranda faces the bell rig; override per site
  egress      = "front" | "right" | "front-left" | ...,  -- which bay opens + where the path meets it
  engawaSides = { "front", "right" }, -- which sides get veranda + shoji (default front+right)
  stiltMode   = "cliff" | "pad",      -- understructure mode (see below)
  hand        = "right" | "left",     -- which corner the engawa/shoji wrap (see Handed variant)
  pathLink    = <Vector3 | marker>,   -- the spur connection point this teahouse's egress ties to
  frozen      = false,                -- if true, builder SKIPS this instance (fully hand-authored)
}
```

### Egress (the per-location axis that varies most)

Each teahouse connects to the path network on whatever side the spur approaches, so egress is explicitly parameterized:

- **Doorway side** — `egress` selects which bay becomes the walk-through opening (the locked recipe hard-codes the *center front* bay; the builder generalizes this to any engawa-facing bay).
- **Approach / landing** — the builder emits a small landing deck or stair stub on the egress side and connects it to `pathLink`, so the spur (sub-project 1's `spur` class) meets the engawa cleanly.
- **Threshold** — kōran is broken (gap, no balusters) at the egress bay so the opening is walkable.

### Stilt mode

- **`cliff`** — posts raycast straight down to the terrain/cliff face (variable length; the kake-zukuri look). Used for wall perches.
- **`pad`** — posts to a flat shelf/foundation pad (uniform short length). Used where a perch sits on a ledge.

### Handed (mirror) variant — `hand = "right" | "left"`

The engawa + shoji wrap a **fixed corner** of the building (front + one side). Rotation can't change *which* corner wraps relative to the facing — so the open/view side and the slope can't both be satisfied on **both** gorge walls with one handedness. Near-wall perches generally want the **right** wrap; far-wall perches (mirrored geometry, facing back across the gorge) generally want the **left** wrap. So handedness is a per-site parameter, not something rotation solves.

- **`right`** (the base form): engawa + shoji wrap **front (−Z) + right (+X)**; solid walls back + left; doorway/corner-lantern on the right; understructure footprint = teahouse + half engawa on front+right.
- **`left`** (mirror): the same, reflected across the model's local **X=0** plane — engawa/shoji **front + left**, solid back + right, lantern on the left, understructure footprint mirrored.

Implementation (verified): **do NOT geometrically reflect the whole model** — the roof uses WedgeParts (gables `GableA/GableB`, eave `SkirtEnd`) and angled hip rafters that flip the wrong way under reflection (they stab up through the roof). The shell, roof, gables, hip rafters, and shoji are symmetric/shared and stay **untouched**. The left variant only **negates local X of the engawa-assembly box parts** — `EngawaF`, `EngawaS`, the kōran (`RailCap/RailMid/Newel/Baluster`), the understructure (`PerimF/B/L/R`, `JoistF/JoistR`) — plus the **hanging lamp** (`Lantern/Cord/LanCap/LanRib`), then refits the `EngawaPost` stilts at the mirrored footprint. Captured as `makeLeftHand(model)`; template `ServerStorage.TeahousePrototypeL` = clone + makeLeftHand. (NOTE: the shoji panels currently stay on the original front+right side — TBD whether to also mirror `Shoji/ShojiGlow/Mull`, same safe negate-X, so the screens face the left veranda.) In the parameterized builder this is native: build the handed pieces with X negated from the start.

## Override hook + frozen instances (escape hatches for true one-offs)

For bespoke sites that no spec field captures, two mechanisms keep everything regenerable:

1. **`customize(model, site)` callback** — after the builder lays the base form, it calls a per-site customize hook (keyed by `name`) for ad-hoc additions (an extra deck, a tea-garden gate, a private second lantern). The tweak lives in **code**, so it survives rebuilds.
2. **`frozen = true`** — the builder skips that instance entirely; it's fully hand-authored and excluded from regeneration. Use sparingly (it opts out of the design system).

Order of operations per site: `build base form → apply site-spec fields (egress/engawaSides/stiltMode) → customize(model, site)`.

## Build pipeline

- **`Teahouse` builder (`tools/builders/Teahouse.luau`):** pure logic that emits the spec for the locked form given a site spec + palette. Pure/deterministic (no `math.random` — sin-hash/LCG jitter only, for CI drift), so **Lune-testable**. Terrain raycasts (stilt feet, snapping) are injected so tests can stub them.
- **Site authoring:** draft draggable teahouse markers on the live terrain → user nudges (perch, facing, egress side) → bake into an `ArenaLayout.teahouses` block.
- **Placement pass (`tools/studio/...`):** reads the baked site list, runs the builder per site, parents each into the stage; idempotent by `name`. Spurs (sub-project 1's `spur` class) are built here too, linking each `pathLink` to the egress landing.

## Out of scope (this sub-project)

- The **real suspension bridge** at the pinch (sub-project 3).
- **Interiors / spawns / furnishings** beyond the locked tatami shell (sub-project 4).
- Hooking teahouse lanterns into the **lantern telegraph** (future; same deferral as path lanterns).

## Open questions

- Final teahouse **count and perch positions** (driven by the marker pass once paths are locked).
- Whether some teahouses want a **larger/smaller footprint** (a `scale` or `size` spec field) or all share the one form.
- Whether `pathLink` is best as an explicit point or inferred from the nearest spur endpoint.
