# Per-Size Deck Placement — Design Spec

**Date:** 2026-07-13
**Status:** approved design, ready for implementation planning
**Supersedes:** the abandoned "server-authored access model (SP2)" direction — see *History* below.

## Goal

Position decks and teahouses correctly on the 14 canyon perches for a modular economy where **deck size and teahouse size are independent, earned items**. Each pad authors an explicit deck placement **per size** (surveyed to sit right on that perch's terrain *and* touch its access), and the teahouse sits **centered** on whatever deck. No runtime access data, no computed placement rule.

## Where this fits

- **Piece A (shipped):** pad/deck separation — the deck is a procedural slab (sized S/M/L via √area scaling); the teahouse is a deck-less prefab placed on it.
- **SP1 (shipped):** modular teahouse — walls are per-bay `solid | shoji | door` from a `wallBays` map; the whole-building mirror is retired.
- **This spec:** *how* the independently-sized deck + teahouse land on each real perch.
- **Piece B (next):** the modular economy itself — deck / teahouse / decoration as independent earned items (teahouse ≤ deck), the customization UI, the **player back door** (SP1's `applyBays` on a `wallBays` map), and teahouse repositioning on roomy decks.

## Model

**Decks and teahouses are independent, stackable items.** Deck size (S/M/L) and teahouse (none/S/M/L) are earned separately; the only rule is teahouse ≤ deck. A small teahouse — or none — on a big deck is a legitimate choice (big engawa, gardens, feeders). The S deck+teahouse *bundle* is the gateway earn. (The economy that manages this is Piece B; this spec only consumes the two **sizes** as inputs.)

**The deck is a yard anchored at access, growing toward the view.** Because a deck is usually smaller than the pad and independently sized, it cannot be centered on the pad — it must sit touching the access point (so a player emerging from the tunnel/path can step onto it) and extend toward the view as it grows, cantilevering out over the drop on bigger sizes (Piece A already supports post-omission / cantilever).

**Placement is authored per (pad × size), not computed.** These are 14 unique, hand-built cliff perches. A single "anchor + grow" rule would land clean on some and fight the rest (a rock, an awkward drop, an irregular edge), forcing per-pad overrides anyway — plus the rule code and an access-anchor abstraction. Authoring each deck size where it visibly sits right is less total work, strictly more robust, and reuses the existing draggable-marker survey flow. **Reachability is guaranteed by the author's eye** (each deck is placed touching its access), so no runtime access mark is needed.

**The teahouse is centered on the deck (a uniform rule).** The deck↔pad relationship is irregular (authored), but the deck↔teahouse relationship is uniform: the building sits centered on the deck top, facing the view. Centering yields balanced, walkable engawa margins → the player circles around to the front with no door. Tight-pad cases where an L teahouse can't leave a walkable margin (e.g. T05) are the exact cases a player adds a **back door in Piece B**; this spec leaves them centered at best-fit and does not author a door.

## Data model — `PadSites`

Each entry today carries `id`, `displayName`, `mountCF`, `maxSize`, `deckSize`, `placement`, `vacantForm`. Changes:

- **`mountCF` → `deckPlacements`**: a per-size table of authored deck CFrames (row-major 12-arrays, as `mountCF` was):
  ```
  deckPlacements = { S = {cf12}, M = {cf12}, L = {cf12} }   -- one entry per size ≤ maxSize
  ```
  Each CFrame is that size's **deck pivot** (center, exactly as `mountCF` was consumed by `TreatmentApplier`/`PadBuilder`): view-oriented, positioned so the deck touches access and extends toward the view. The existing `mountCF` **migrates to `deckPlacements.L`** (it was already baked as the L deck-center); `S` and `M` are surveyed fresh — their pivots shift toward the access edge, since a smaller deck doesn't fill the pad.
- **Drop `placement`** (teahouse offset/facing). The teahouse is centered on the deck (rule), so there is no per-pad teahouse placement to author.
- **`maxSize`, `deckSize`, `vacantForm`, `id`, `displayName`** unchanged. (`deckSize` remains the site's default/owned deck feeding `SiteCoordinator`; how deck size is *chosen* moves to the economy in Piece B — out of scope here. The vacant/dormant deck stays `S`.)

## Placement logic

- **Deck:** `deckCF = PadSites[padId].deckPlacements[deckSize]` — a pure lookup. If a requested size > `maxSize` or is unauthored, warn and fall back to `maxSize`'s placement (F2/F4: never fail the caller).
- **Teahouse:** centered on the deck, inheriting the deck's orientation. Reuse the existing `BuildingPlacer` machinery with a **centered constant** — `placement = { offset = {0, 0}, facing = "N" }` (facing `"N"` = aligned to the deck, whose CFrame already carries the view orientation) — so the building centroid sits over the deck centroid at the deck-top Y. (The `fits` check stays available for Piece B's player-repositioning, but a centered building always fits, since teahouse ≤ deck by size class.)

## Authoring workflow

- Extend the draggable-marker survey flow: for each perch, place each deck size (S…`maxSize`) where it sits right on the terrain **and** touches its access, and capture each deck's CFrame.
- A bake tool writes `deckPlacements` into `PadSites` (as `mountCF` was baked). `L` seeds from the current `mountCF`; `S`/`M` are surveyed.
- **Authoring guideline (not enforced):** place the sizes consistently on each perch (same access edge, extending toward the view) so a deck upgrade reads as *growing outward*, not jumping.

## Error handling / degradation

- Missing/oversized `deckSize` → warn, fall back to `maxSize`'s placement; never error the materialization (consistent with SP1's F2/F4 rule).
- A perch whose `maxSize` < a requested size simply can't hold it — the economy (Piece B) must gate purchases to `maxSize`; this spec's fallback keeps the runtime safe if it doesn't.

## Testing

- **Pure (Lune):** the teahouse-centering helper (deck CFrame + deck/teahouse sizes → centered building CFrame) is unit-tested like `BuildingPlacer`/`PadFrame`. Deck placement is a data lookup — test the fallback (unauthored/oversize → `maxSize`).
- **Visual gate (Studio, per Piece A pattern):** on real perches, each deck size lands touching access and extends toward the view; the teahouse is centered with walkable margins (circle-around works); tight-pad L confirms the "needs a door" case is left at best-fit. This is also the per-perch tuning pass the change unblocks.

## Out of scope (deferred)

- **Piece B:** the modular economy (deck/teahouse/decoration as earned items, teahouse ≤ deck, purchase gating), the customization UI, the **player back door**, and teahouse repositioning on roomy decks.
- **Access marks + placement rules** — dropped entirely; authoring per size subsumes them.
- **Growth continuity** — each size is independently authored; a deck upgrade rebuilds the deck. The authoring guideline keeps it reading as growth, but no anchor is enforced.
- **Scaling to future many-pad valleys** (the metagame's "50+ pads across two new valleys") — per-size authoring is linear in pads × sizes; if those valleys land, revisit a rule/hybrid then. Not a concern for the 14 perches.

## History

This piece began as a heavier "server-authored access model" (which bay becomes a door, deriving placement from a per-pad `{edge, position}`). Two realizations collapsed it: (1) the **back door is better left as a player choice** at the back wall (Piece B, powered by SP1's `applyBays`), so no server access model is needed for doors; and (2) the only thing access truly constrains is that a **sub-pad deck must touch it** — and that is more robustly handled by **authoring each deck size's placement by eye** than by a rule + access mark on irregular terrain. What remains is this: authored per-size deck placements + a centered-teahouse rule.
