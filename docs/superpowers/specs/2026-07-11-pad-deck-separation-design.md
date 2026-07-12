# Pad / Deck Separation — Design Spec

**Date:** 2026-07-11
**Status:** Design approved; ready for implementation plan (Piece A only).
**Sub-project:** ZenDojo teahouse materialization (D-series). Supersedes the current fused
teahouse+deck build for the pad system.

## Problem

Today `StructureBuilder` builds a **fused teahouse** — deck + engawa + walls + roof + interior
as one prefab — and `PadPlanner` places support posts from `SizeClasses.BASE_FOOTPRINT`, which is
**off-center (+3.8 in X) and hand-unaware**. The whole structure mirrors for left-hand pads
(`StructurePlanner.mirror = hand=="left"`), but the post footprint does **not** mirror, so on
left-hand pads (T05, T06) the deck flips to one side while the posts stay on the other — stranding
the outer post ~28 studs away, in the gap between teahouses. The same mirror also splits the deck
floor from its railings (the "left-hand SideWall bug").

The root cause is conceptual: **the deck was modeled as part of the (handed) teahouse.** It should
be part of the **pad**, which is hand-agnostic.

## The model

- **Deck = pad.** They are the same thing. Pads/decks come in **S/M/L**.
- **Deck and teahouse are independently owned and independently sized.** A player can own a deck
  **alone** (a bare base of operations, no building), or a teahouse they drop onto any deck that is
  **≥ its size** (an S teahouse fits an S, M, or L deck).
- **Fit rule:** `teahouse.size ≤ deck.size`, and the building must seat within the deck bounds at its
  placement.
- **The legacy teahouse is a starter bundle** — S teahouse + S deck — just upgradeable parts.
- **Handedness is not a property of pads or posts.** It is only a per-teahouse *placement* on the
  deck. The pad is symmetric and identical regardless of what building (or placement) lands on it.

## Scope

**Piece A (this spec):** restructure materialization so the deck is a hand-agnostic S/M/L pad
(deck + beams + posts) and the teahouse is a building-only prefab placed on the deck via an
authored `placement`. Fixes the stray-post + left-hand-SideWall bugs; establishes the deck/building
separation and the two-input (`deckSize`, optional `teahouse`) materialization. Per-site **defaults**
(authored in `PadSites`) drive it so we can see it working.

**Piece B (separate later spec):** the economy behind it — players earning/buying/upgrading decks
and teahouses independently, a preference UI to override placement, and the **access variable**
feeding placement. Piece A builds `placement` as a real parameter; B just supplies different values
and a UI. **Not designed here.**

## Architecture — three units + composition

1. **`PadBuilder` (deck-builder)** — builds the whole hand-agnostic pad for `(deckSize, mountCF)`:
   a symmetric **deck slab** + engawa railings, the **beam frame**, and the **6 posts**. Knows
   nothing about hand, building, or shoji. Output: pad model.
2. **`StructureBuilder` (building-builder)** — builds the **building only** (walls, roof, shoji,
   interior — *no* deck/engawa), floor at deck-top `y = 0`. Takes the loadout + `openSide`
   (which two sides get the shoji L-wrap).
3. **`BuildingPlacer`** — seats the building onto the pad's deck per `placement = { offset, facing,
   openSide }`: translate by `offset`, rotate to `facing`. Pure transform.

**Composition (`TreatmentApplier`):** every `apply` rebuilds from a clean slate:
`build pad(deckSize) → (if a teahouse) build building(teahouse.size, openSide) → place(offset, facing)
→ fit-check → shutter/lit`. Pad and building are **both** rebuilt each apply — the pad is sized to the
current occupant's `deckSize`, so it cannot be permanent (an L pad must give way to an incoming S
player's S pad).

## Pad geometry (deck + beams + posts)

Symmetric and centered on `mountCF` (no more off-center footprint):

- **Deck:** a thin symmetric slab. **S = 26 × 20** (long axis = X) → local `X[-13, 13], Z[-10, 10]`,
  centered on the mount. Deck top = the `y = 0` plane the building sits on. Engawa railings run the
  deck's exposed edges.
- **Sizes:** **M = ×√1.3, L = ×√1.6** (area intent, per `SizeClasses` — the linear scale is the
  square root of the area multiplier). S deck (26 × 20) is fixed here; the S *building* footprint and
  therefore the exact engawa may shrink later, and M/L exact deck dims are deferred.
- **Beam frame** (just under the deck): **2 long beams** along X at the ±Z edges (front/back), tied by
  **3 short beams** along Z at −X, +X, and mid-X. Beams rest on the post tops and carry the deck.
- **6 posts** at the beam intersections = the 4 corners `(±13, ±10)` + 2 mid-edge `(0, ±10)` — exactly
  `PadPlanner`'s existing `FL/FR/BL/BR/MF/MB` nodes. Each drops to terrain with the current rules:
  normal stilt where terrain is below the datum, **embed** where terrain rises above, **omit/cantilever**
  over a void or an `AccessKeepOut`-tagged path. Because the layout is symmetric and centered, posts are
  always under the deck's own corners — never stranded.
- **Hand-agnostic:** identical for any building or placement.

Reference measurements (S, current base prefab, right-hand): building (walls) ≈ **18.7 × 12.7**;
deck+engawa ≈ **26.4 × 20.0**; engawa ≈ **7.5** on the two open sides.

## Placement + per-pad defaults + shoji

A **`placement = { offset, facing, openSide }`**, all **authored** per pad (no derived offset — Piece B
lets users re-author it):

- **`offset`** — the building's `(dx, dz)` on the deck (tucks it toward a corner, leaving the engawa on
  the two open sides).
- **`facing`** — which deck edge the open front points to. **Snapped to one of the 4 edges.** All 4 are
  allowed, subject to the fit-check.
- **`openSide`** — left or right; the adjacent side that is *also* open (the L-wrap). This is what `hand`
  becomes. It selects which two sides `StructureBuilder` builds as shoji (front + openSide); the other
  two are solid walls.

**Shoji follow placement:** the building is built with the shoji L-wrap on `front + openSide`; `facing`
rotates the whole building so that open L points at the chosen deck edge. No deck or post mirroring —
only the building's shoji-wrap has an `openSide`, and only the building rotates/translates.

**Per-pad default:** `PadSites` stores each site's default `{ deckSize, teahouse{ size, placement } }`
(where placement = `{offset, facing, openSide}`), authored so the open front faces that pad's access —
the "specify defaults up front to ensure access" requirement.

## Data flow & lifecycle

Two **independent** inputs, not one `sizeClass`:

- **`deckSize`** (S/M/L) → sizes the pad. Bounded by the perch's `maxSize` (biggest deck the terrain
  supports).
- **`teahouse`** (optional) → `{ size, loadout, placement }`; if present, the building is built at
  `teahouse.size`, placed per `placement`, and must satisfy `teahouse.size ≤ deckSize`. If absent → a
  **bare deck**.

`apply(padId, deckSize, teahouse?)`:
1. Tear down the old `MaterializedSite_<padId>` (deck + beams + posts + building).
2. `PadBuilder.build(deckSize, mountCF)` → deck + beam frame + posts.
3. If `teahouse`: `StructureBuilder.build(teahouse.loadout, placement.openSide)` → building-only, then
   `BuildingPlacer.place(building, deckCF, placement)` → seat on the deck.
4. Shutter (dormant) or leave lit.

**Which sizes drive it** (`SiteCoordinator` already selects the relevant class per join/leave/vacant;
it now carries deckSize + optional teahouse rather than a single scale):
- **Vacant** → deckSize = site `maxSize`, dormant (as `vacantActions` does today; teahouse per the
  dormant treatment, e.g. a dormant starter or bare deck — exact dormant content is existing
  `VacantState` policy, unchanged here).
- **Claimed** → deckSize + teahouse from the owner, lit, with their placement.
- **On leave** → back to `maxSize`, dormant.

## Error handling

- **Fit-check** (`teahouse.size ≤ deckSize` **and** building footprint within deck bounds at its
  placement): if it fails, `warn` and **skip the building** — the pad still stands. Non-fatal, matching
  the applier's existing F2/F4 "degraded, not fatal; never blank the site or abort the caller's loop"
  contract.
- Build failures (pad or building) `pcall`-guarded and logged, same as today.

## Migration

- **Deck goes procedural.** Pull the deck / engawa / railing parts out of the `teahouse-1story` prefab.
  `PadBuilder` generates the deck slab + engawa railings + beam frame + posts procedurally, sized by
  `deckSize` (√area). One code path for S/M/L (simple geometry: a slab, 5 beams, 6 posts); no three
  deck prefabs.
- **Building prefab slims to building-only** (walls, roof, shoji, interior), floored at `y = 0`.
- **`openSide` replaces `mirror`:** `StructurePlanner.mirror = hand=="left"` becomes shoji-wrap
  selection (front + openSide). Whole-building mirroring goes away; `BuildingPlacer` does
  position/rotation. **This removes the left-hand SideWall bug.**
- **Data plumbing:** `PadSites` `hand` → default `{ deckSize, teahouse{ size, placement } }`;
  `SiteCoordinator` carries deckSize + optional teahouse; `TreatmentApplier.apply` new signature;
  `SizeClasses` deck footprint becomes symmetric/centered (26 × 20 at S).

## Testing

- **Pure / Lune:** `PadBuilder` deck-size + 6-node beam/post layout math; `PadPlanner` post planning
  (already covered); `BuildingPlacer` offset/facing transform + fit-check (`teahouse ≤ deck`, footprint
  within deck bounds); `openSide` shoji selection; `SiteCoordinator` two-input carry.
- **Visual gate** (Studio play, as `TreatmentApplier` is validated today): materialize **bare L deck**,
  **S teahouse on L deck**, **all 4 facings**, and **left vs right openSide** — eyeball posts-under-deck,
  engawa, and shoji orientation.

## Global constraints

- Luau modules are **dependency-injected, never `require` each other** (same files run under Lune and
  Roblox). Pure modules (planners, placer, size math) are Lune-tested; Roblox-part builders are
  visual-gated.
- **Area scale intent:** M/L = √1.3 / √1.6 linear (1.3× / 1.6× area). S/M/L buildings ship as
  **authored per-size prefabs** eventually; the `ScaleTo` scale is a testing proxy until then.
- **Place-only geometry** persists only in the saved `.rbxl`; the `teahouse-1story` prefab is currently
  place-only (committing it via a Rojo ServerStorage mount is an open follow-up).
- TDD: failing test first for the pure modules; visual gate for the builders.

## Deferred to Piece B (not in this spec)

Economy (earning/buying/upgrading decks & teahouses independently), the placement-override preference
UI, and the **access variable** feeding placement. Piece A exposes `placement` as the seam these plug
into.
