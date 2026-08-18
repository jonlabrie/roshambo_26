---
shelf: program
status: closed
updated: 2026-08-17
---

# Item 4 — Merchant Row

Item 4 of [[friends-family-baseline]]: a machiya merchant row on the arena promenade —
4 façade shells plus one WORKING fireworks shop (browse/buy at the counter). The working
shop already exists: [[hanabiya]] (花火屋), built and owner-gated 2026-08-13 with the place
saved (`37469b8` names it "the merchant row's first machiya").

**CLOSED 2026-08-17.** The riverside chaya was the last of it and is owner-gated with the
place saved — [[chaya]]. Every shell of the row is built; what remains for these buildings
belongs to other items (commerce hookup at items 6/7, the Stats cavern's own contents at
item 7, an NPC for the chaya whenever NPCs happen).

## Current state

- **The row is BUILT.** As-built, west to east:
  | Shell | State |
  |---|---|
  | Stats false front (番付) | built `824f53e`, rear doorway `f36b05a`; cavern bored — [[stats-room]] |
  | apparel (Machiya_1) | built, **owner-gated 2026-08-15** (see Gates) |
  | 花火屋 (working shop) | built, **owner-gated 2026-08-13** — [[hanabiya]] |
  | accessories (Machiya_4) | built (`bd6f90b` window display, `0db82e5` signage) |
  | riverside chaya + dock | built, **owner-gated 2026-08-17** — [[chaya]] |
  ⚠ Accessories and the Stats false front carry no recorded owner gate; the owner stated both
  done 2026-08-16. Signage, noren mon and per-shop chōchin tints landed across all of them
  (`0db82e5`, `90a9eed`, `19e35bc`, `7c59f61`).
- **[[hanabiya]] is built and working** (interior stair + attic `219509c..565c307`, shop-panel
  cursor fix `322d948`, frontage deepened z44 → z36 `22bcf2e`). It sets the archetype's
  as-built reference.
- **The machiya brainstorm is DONE (2026-08-15)** — see the design spec in Raw layer.
  Street plan: apparel (Machiya_1, wide west) · 花火屋 · accessories (Machiya_4) ·
  Stats frontage (re-sited west of apparel; its cavern is now BORED — [[stats-room]]) ·
  riverside chaya + its dock, built at the waterline rather than at the Machiya_2 mark
  ([[chaya]] carries why). Shells are façades-with-identity, shallow-enterable (sports book
  closed-kōshi teaser).
- Massing references: `ServerStorage.Sandbox_PARKED.MerchantMassing` (per the baseline
  spec, line 103) — verified in the live place 2026-08-15 (Studio MCP, Edit mode):
  6 children survive (`Machiya_1..4`, `Machiya_East`, `DockDeck`), matching [[place-state]].
  `Machiya_2` and `DockDeck` are now history rather than instructions — both superseded by
  the built chaya, and kept for the record.
- **The corridor-reservation prerequisite is dissolved** — the reservations were
  RETIRED 2026-08-15 (owner's call), not re-derived. Nothing at runtime or in any bake
  ever read them; their one job (keeping a free 55×30 garden slab out of the streets)
  ended when the panel was pinned to the pavilion's post faces (`17927df`, tested).
  The row builds to `Machiya.luau`'s owner-surveyed envelope (frontage z36); if the
  row wants a machine-readable street reservation, derive it fresh from the massing.
  (The brainstorm this once deferred to is DONE — 2026-08-15, above. No reservation was
  derived, and the row was built without one.)

## Gates & decisions

- **2026-08-17 owner gate: the riverside chaya + dock ACCEPTED, place saved — item 4 closed.**
  Reached through five looks; the detail lives on [[chaya]]. Three rulings came out of it that
  outlive this item: support posts on this build are ROUND, not square; the chaya's chōchin is
  RED, overriding the row's own no-true-red rule but not `Chochin.LEGIBILITY_FLOOR`; and both
  of that shell's massing marks (`Machiya_2`, `DockDeck`) are superseded rather than deleted,
  because the ground under them could not carry what they described.

- **2026-08-15 owner gate: the apparel machiya (Machiya_1) ACCEPTED** after three correction
  rounds — the surveyed envelope overlapped 花火屋 by 3.97 studs (stale massing; east edge now
  registers to the built west face at a 1.5-stud roji, pinned by a test), the kit chōchin had
  been restated at half density (now `tools/builders/Chochin.luau`, the canonical canyon lantern,
  drift-guarded against the studio tool), and the owner hand-placed the kimono racks into the
  corners (baked as `APPAREL_RACK_OVERRIDES`, reproduced to 0.0008 studs).
- **2026-08-15 owner rule — lantern variety:** canyon paths stay UNIFORM (they are the wayfinding
  system); the merchant row VARIES per shop (light tinted barrels; glyph plates never tinted, and
  a CI floor of 0.55 relative luminance keeps the World Throw glyph legible at night). The rule
  once excluded true red as izakaya signalling (赤提灯); the owner lifted that for the chaya on
  2026-08-17 ("red is punchy") — see [[chaya]]. The luminance floor was NOT lifted and is the
  only thing still bounding a tint.
- 2026-08-15 owner decision: corridor reservations retired from `ArenaLayout.luau`
  (with their tests) rather than re-derived — see log.
- 2026-08-13 owner gate: hanabiya done for now, place saved. Dropped, do not re-raise:
  the terrain cut behind the shop + its ishigaki dressing.
- 2026-08-13: the frontage deepening was accepted against the promenade on the promise of
  the karesansui reduction; that reduction executed 2026-08-14 (`17927df`) — the borrowed
  promenade depth is repaid.

## Raw layer

- design spec: `docs/superpowers/specs/2026-08-15-machiya-row-design.md` (the row's
  own brainstorm — street plan, archetype refactor, identity kits, chaya)
- spec: `docs/superpowers/specs/2026-07-30-friends-family-baseline-design.md` (item 4)
- shop ledger: `.superpowers/sdd/2026-08-05-hanabiya-shop/`
- key commits: `37469b8` shop as-built doc · `22bcf2e` frontage z44→z36 · `219509c` stair
  + counter · `565c307` attic ties · `322d948` cursor grip · `17927df` karesansui shrink
