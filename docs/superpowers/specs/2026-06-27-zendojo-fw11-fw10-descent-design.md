# ZenDojo FarWall_11 → FarWall_10 Descent (Design)

Status: design, awaiting user review (2026-06-27).

Related: `docs/superpowers/specs/2026-06-27-zendojo-fw11-switchback-deck-design.md` (the deck this descends
from), `docs/superpowers/specs/2026-06-26-zendojo-organic-path-system.md` (the stepped-cobble recipe);
memory `zendojo-fw11-switchback-deck`, `zendojo-organic-cobble-path`, `zendojo-canyon-village`.

## Purpose

Carry the canyon trail from the FW11 switchback deck (out on the promontory) down to FarWall_10, the next
route node toward the clearing. The descent leaves the deck by a short stair (the deck↔path transition),
then a graded stepped-cobble path runs to FW10. This is the lower leg of the FW11 hairpin (the upper leg —
FW11→tunnel — and the deck are already built).

## Context (surveyed 2026-06-27)

- **Deck exit:** the upper path enters the deck's **West edge, north end** (~z−72); the descent leaves the
  **West edge, south end** (~z−62), heading −X back toward FW10 — a ~180° hairpin. The West edge is open
  (no railing), so no rail gap is needed.
- **Deck:** center (159.7, −66.6), top **138.46**, West edge X = **150.7**. Ground just off the SW/West
  edge is ~**135–136** (≈2.7 below the deck top), then falls away.
- **FW10:** `(52, 114.4, −39)`. Deck SW → FW10 is **~100 studs horizontal, ~24 down (~24% grade)**.
- **Basin sag:** along the straight chord the ground drops into the basin (terrain ~110–120), so the chord
  floats **+6 to +13** through the middle. The path is laid graded anyway; the **retaining-wall pass
  (separate, later)** supports the floating stretches.

## §1 — Deck→path stair (transition)

A short Overlook-style flight off the deck's **West edge, south end**, modelled on the clearing Overlook's
upper↔lower connecting stair:

- **3 Slate treads**, each ~**5 (wide) × 0.5 × 2.0**, colour `palette.ink` (dark), stepping down along the
  −X exit line.
- **Two sloped Wood stringers** (`palette.timber`) under the tread edges, aligned with `Spec.segment(top,
  foot)`, section ~**0.9 × 0.5**, dropped ~0.7 below the treads.
- Sheds ~**3–4 studs**: deck top **138.46** → **stair foot ≈ 134–135** (the cobble-path start).
- Two short **newel posts** flank the top of the flight to frame it (the West edge is otherwise open).
- **Lives in the `SwitchbackDeck` builder** (it's part of the deck): pure, lune-tested, genmodels → Rojo.

## §2 — Cobble descent (stair foot → FW10)

A graded **stepped-cobble path**, identical construction to the upper run, routed by a Catmull-Rom spline
through user-adjusted draft markers (see Route workflow):

- **Timber risers** (brown Wood, 6.4 × 1.6 × 1.2, ~3.5-stud spacing) following the grade.
- **Per-section Voronoi cobble treads** (min-sep 0.55, ~3–4 seeds per gap, inset 0.08, 1-pass Chaikin,
  dome 0.42, **flat-up normals**, mossy **122/127/117**, Material Rock, **published** so it persists).
- **Cement-gravel bed** (Concrete + `ZenCement2` MaterialVariant, ~**6.42** wide, tint 138/142/142).
- **6.4 tread width**, matching the rest of the trail.
- ~100 studs at ~24% average; **floats over the basin** in the middle (walls later). Downhill edge left
  open for now — the ishigaki facing comes with the retaining-wall pass.
- **Built ad-hoc** (like `Workspace.PathExtension`); folded into the later "consolidate into pipeline" work.

## Route workflow

1. Build §1 (the stair); its **foot is the first route marker**.
2. I drop a row of draft `FarWall_*` markers from the stair foot down the chord to FW10 (`Workspace.PathDraft`).
3. **User adjusts** the markers in Studio to shape the line.
4. I route the §2 stepped-cobble path through them (Catmull-Rom), publish the cobbles.

## Units

- **DeckStair** — Slate treads + Wood stringers + framing newels, in `SwitchbackDeck.luau` (lune-tested).
- **DraftMarkers** — a row of markers stair-foot → FW10 for the user to adjust.
- **DescentPath** — the stepped-cobble path through the markers (timbers + published cobble mesh + bed),
  ad-hoc in workspace.

## Out of scope (separate work)

- **Retaining walls / ishigaki** on the descent's floating stretches — the planned later pass across *all*
  paths.
- **FW10 connection** — how the descent ties into whatever continues below FW10 (its own step).
- **Consolidating** the ad-hoc descent path into the builder pipeline (tracked with the extension cleanup).

## As-built (2026-06-27)

- **Stair** (in `SwitchbackDeck` builder, synced via Rojo): **6** Slate treads (`2 × 0.5 × 5`, `palette.ink`)
  on two Wood stringers + two framing newels, off the West-south edge, descending −X from the deck top
  (138.46) to the foot at **(138.7, 130.9, −62)**. `SwitchbackDeck.STAIR_FOOT` publishes that point.
  (Tread `Size` is `{2, 0.5, 5}` — 2 deep along travel, 5 wide across; an earlier `{5,0.5,2}` read rotated.)
- **Route:** draft markers (`Workspace.PathDraft.Descent.Marker_0..8`) dropped stair-foot → FW10 and
  **user-adjusted**; the bottom marker sits ~8 studs back from **FW10 = `Bridge3_B`** (one end of Bridge 3
  across the river) to leave the bridge transition.
- **Descent path** (ad-hoc, `Workspace.DescentPath`): **19** `DescTimber_*` risers (Wood `74/52/32`,
  6.4 × 1.6 × 1.2) along a Catmull-Rom spline through the markers; **19** `DescBed_*` flat per-gap slabs
  (Concrete + `ZenCement2`, **5.8** wide, top ~0.05 below each gap's downhill-timber tread); `DescCobbles`
  **published `rbxassetid://132480572793631`** — per-section Voronoi cobbles, **flat per tread** (stepped,
  not sloped), half-width **2.6** (≈5.2 wide, inside the bed so ends are covered while the 6.4 timber ends
  stay proud), apex `tread + 0.25`, dome 0.42, flat-up normals, mossy 122/127/117.
- **Key sizing rule learned:** timber (6.4) > bed (5.8) > cobbles (~5.2) — so timber ends reveal, cobble
  ends stay tucked in the gravel.

## Open questions

- The descent **floats over the basin** mid-run (by design) — pending the separate retaining-wall pass.
- `StairTarget` (cyan ball) is kept as the path's top reference; draft markers remain (DevMarker, hidden in Play).
