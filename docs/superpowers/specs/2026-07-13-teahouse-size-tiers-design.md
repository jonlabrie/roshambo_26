# Teahouse Size Tiers — Design (authored per-size prefabs)

Replace the single scaled teahouse with **three authored per-size prefabs**, because the
current building is really M-scale, not S. S becomes a genuinely smaller *building* (fewer bays),
which scaling can't produce. Retires the `SizeClasses.scale` proxy for buildings; sizes now pick
a prefab instead of scaling one.

## Why

`SizeClasses` has always said the shipping sizes are authored per-size prefabs and the `scale`
factor is "a TESTING PROXY on the single S prefab only, retired when the authored prefabs land."
This is that. The trigger: the current `teahouse-1story` (3×2 bays) is too large to be S. B2 just
made teahouse *size* an earned/purchased item, so the sizes need to be visually distinct real
buildings, not one prefab scaled ±14%.

## The three sizes

Bay counts are `(long walls) × (short walls)` — front/back get the first number, left/right the
second. Bay ≈ 6.2 studs (matched to M).

| Size | Bays | Layout | Prefab | Source |
|---|---|---|---|---|
| **S** | 6 | 2×1 (front/back 2, sides 1) | `teahouse-1story-s` | **new** — hand-authored |
| **M** | 10 | 3×2 (front/back 3, sides 2) | `teahouse-1story-m` | the **current** `teahouse-1story`, re-designated |
| **L** | 14 | 4×3 (front/back 4, sides 3) | `teahouse-1story-l` | **new** — hand-authored |

Clean progression S(2×1) → M(3×2) → L(4×3). **L fit:** a 4×3's walls fit the L deck; the engawa
clearance is tight on *depth*, but the **back is open** (no rear railing — you exit off the back),
so only the front/view veranda + sides need walk-around, which the deck (growing toward the view)
keeps. Verify exact clearance while authoring L; if genuinely cramped, trim to 4×2 or nudge the L
deck placements — do **not** silently ship an L that crowds its pad.

## Teahouses are shell-only (engawa/koran belong to the deck)

**A teahouse prefab is the building shell only:** the modular `Bay_<side>_<index>` walls (each
with `Solid`/`Shoji`/`Door` variants), the hip roof, the interior tatami, and the shoji track
(kamoi/shikii/groove-rails/wall-posts). It does **NOT** include an engawa veranda floor or a koran
railing — the **deck provides both**: `PadOps.buildDeckSlab` is the veranda floor and
`PadOps.buildRailing` is the koran (already collidable + raised, matched to the teahouse's koran
dims). This decouples the two systems and removes the double-railing that a teahouse-owned koran
would create on top of the deck's.

Consequence: **strip the current M prefab's engawa/koran** as part of re-designating it — the
`Skirt`/`SkirtEnd` apron, the `Koran` folder, `WEndRail`, and the (now-empty) `EngawaSupport`
folder. Keep bays, roof, tatami, shoji track, wall posts, and the chōchin. (The teahouse has no
separate veranda-floor part today — the veranda is the deck — so nothing floor-like is lost.) S
and L are authored without those parts from the start.

## Size → prefab (code)

Today `StructureBuilder.build` clones `ServerStorage.StructurePrefabs[loadout.baseStyle]` and
`TreatmentApplier` scales it by `SizeClasses.scale[teahouse.size]`. Change to:

- **`baseStyle` stays the *style*** (`"teahouse-1story"`) — the loadout and the whole B2 economy
  are unchanged. The **size** picks the prefab within the style.
- **New resolver** `SizeClasses.prefabName(baseStyle, size) → \`{baseStyle}-{size:lower()}\``
  (e.g. `("teahouse-1story","M") → "teahouse-1story-m"`). Pure, Lune-tested.
- **`StructureBuilder.build` gains an explicit `prefabName` argument** (the resolved per-size
  prefab), replacing its internal `loadout.baseStyle` clone. The caller
  (`TreatmentApplier._buildBuilding`) computes it via `SizeClasses.prefabName(loadout.baseStyle,
  teahouse.size)`. Keeps `StructureBuilder` from needing to know the size→name rule.
- **Retire building scale:** remove `model:ScaleTo(SizeClasses.scale[size])` in
  `TreatmentApplier` — prefabs are authored at final size. `SizeClasses.scale` **stays** (the deck
  footprint still scales via `deckFootprint`); only the building's `ScaleTo` goes.
- **Per-size fit-check:** `TreatmentApplier` currently fit-checks with `BUILDING_BASE × scale`.
  Replace with `SizeClasses.buildingFootprint(size)` — a per-size wall footprint measured from
  each authored prefab (S/M/L), since buildings no longer scale uniformly.

## Dormant / vacant + economy (mostly unchanged)

- **Vacant pads show the new S (2×1) darkened.** No logic change: `starterAction` already
  materializes the STARTER (`S`) dormant teahouse; it now resolves to `teahouse-1story-s`.
  `VacantState.VACANT_BASE` stays `"teahouse-1story"` (the style).
- **Economy unchanged:** `DEFAULT_TEAHOUSE_LOADOUT.baseStyle` stays `"teahouse-1story"`; the
  size already flows through `teahouse.size` from `SiteCoordinator`/the purchase handler.
- **Deck sizes unchanged** (S/M/L decks per B2). The smaller S just leaves more yard on its deck
  (intended — "the deck is a yard").

## Authoring approach

Hand-author S and L in Studio, **adapting from M's already-tagged components** — copy M's tagged
`Bay_*` models (they carry the `Bay` tag + `Side`/`Index`/`GrooveDepth`/`Role_*`/`ShownTransparency`
attributes), lay out the new bay grid (S: front/back 2 + sides 1; L: front/back 4 + sides 3),
then adapt the hip roof, tatami, and shoji track (kamoi/shikii/groove-rails) to the new footprint.
Because tags ride along on the copies, the **capture tool is not needed** for S/L — its job is to
tag raw geometry, and we start from tagged geometry. Tag only genuinely-new parts to match. Save
each finished shell as `teahouse-1story-{s,m,l}` under `ServerStorage.StructurePrefabs`. (Place-only
prefabs — persist only when the user saves the place.)

## Testing & verification

- **Lune:** `SizeClasses.prefabName` (style+size → name, lowercase size) and
  `SizeClasses.buildingFootprint` (returns each size's footprint). Existing bay-driven systems (B1
  back-door `BackDoorController`, B2 economy, `WallBays.resolve`) enumerate bays **dynamically**,
  so they need no changes and are covered by their own tests.
- **Visual gate (Studio), per size:** each of S/M/L builds correctly on its deck; the deck's
  koran/veranda reads right with the shell-only teahouse (no double railing, no gap); the L (4×3)
  clearance on the L deck is acceptable (open-back mitigation holds) or is trimmed; the B1 back
  door works on the new back-bay counts (S: 2 back bays, L: 4); the dormant vacant pads show the
  small S darkened.

## Non-goals / deferred

- No change to the B2 economy, loadout schema, deck sizes, or deck-placement survey (unless L is
  found not to fit, which reopens the L deck placements only).
- No procedural teahouse generator (hand-authored, per the build-approach decision).
- No new style families (`baseStyle` stays `"teahouse-1story"`); the `prefabName` resolver leaves
  room for future styles but none are added here.
- Two-story / kake-zukuri L and premium engawa features are out (L is a bigger 1-story footprint).

## Open decisions (resolved in brainstorm)

- **Sizes:** S 2×1, M 3×2 (current), L 4×3 — all three authored (scale proxy retired for buildings).
- **Shell-only:** engawa/koran are the deck's; strip them from the teahouse (incl. the current M).
- **Mapping:** per-size prefab via `SizeClasses.prefabName(baseStyle, size)`; `baseStyle` = style;
  building `ScaleTo` removed, deck scale kept.
- **Dormant:** vacant pads show the new S darkened.
- **Build:** hand-author S & L from M's tagged parts; capture tool not needed for S/L.
