---
shelf: world
updated: 2026-08-15
---

# Switchback Deck

The FW11 hairpin viewing deck and its connected works on the far (south) wall: the
posted timber deck at the switchback apex, the upper-path extension reaching it, the
FW11→FW10 descent stair/path, and the fitted ishigaki retaining walls. Built
2026-06-27..07-01. The deck itself is Rojo-managed
(`tools/builders/SwitchbackDeck.luau` → `RoshamboStage.SwitchbackDeck`, verified in
the place 2026-08-15); everything else here is place-only by decision (below).

## As built

- **Viewing deck**: smaller sibling of the [[viewing-platform]] Overlook. Centre
  (159.7, −66.6), top 138.46, 18×15, on a promontory shelf the owner relocated it to.
  Six posts + under-slab girders; kōran railing on the East (downcanyon) + South
  edges; one hanji **result lantern** on the SE corner, body named `DeckLantern` so
  `LanternController.client.luau` paints the live World-Throw glyph on it.
- **Upper-path extension** (`Workspace.PathExtension`, ad-hoc): ~20-stud near-flat
  continuation of the upper cobble path landing flush on the deck's west edge.
  `ExtCobbles` is a published mesh, `rbxassetid://82556346085009` (unpublished
  EditableMeshes do not survive reload).
- **FW11→FW10 descent**: 6-step slate-on-stringer stair off the deck (builder
  `STAIR_FOOT` (138.7, 130.9, −62)), then `Workspace.DescentPath` — 19 timber risers
  on a Catmull-Rom spline, `DescCobbles` published `rbxassetid://132480572793631`.
  Sizing rule: timber 6.4 > bed 5.8 > cobbles 5.2 (timber ends reveal, cobble ends
  tucked). Stops ~8 studs short of FW10 = `Bridge3_B`; the river bridge there was
  built and confirmed 2026-07-01.
- **Retaining walls** (`Workspace.RetainingWalls`, 7 published `Wall_*` meshes):
  fitted ishigaki on the floating spans — dark recessed backing + flat proud stones
  (relief 0.22), horizontally coursed, monochromatic 96/98/94 ±3, top at bed
  underside, Perlin crown/base, taper to a ragged stub.
- **Railings + chōchin — shipped** (git truth; a stale memory note said otherwise):
  bamboo railing builder deployed across the canyon paths (`d247a2e`), chōchin
  builder reused per-path including DescentPath (`5d1a21e`); `PathSteps` fall-through
  fixed with per-gap `Bed_*` slabs. Chōchin recipe locked 2026-06-29
  (`buildChochinPole.luau`; glyphs painted by `LanternController` on a tagged
  `GlyphPlate`, swayed by `ChochinSway`).

## Gates & decisions

- 2026-06-27 review, decided **no**: consolidating `PathExtension`/`DescentPath` into
  the Rojo/genmodels pipeline. The whole path system is ad-hoc workspace geometry —
  source of truth = the saved place + the published cobble/wall assets. Capturing
  baked meshes to `.model.json` would add little and risk duplication.
- Owner drove placement throughout (relocated and lowered the deck, tuned terrain,
  set cobble/timber heights); per-unit Studio visual checkpoints were the process.

## Raw layer

- specs/plans: `docs/superpowers/specs/2026-06-27-zendojo-fw11-switchback-deck-design.md`
  (+ `-fw11-fw10-descent`, `-retaining-walls`, `-path-railings-lanterns` siblings) and
  their plans under `docs/superpowers/plans/`
- key commits: `d247a2e` bamboo railings all paths · `5d1a21e` chōchin per-path +
  DescentPath
