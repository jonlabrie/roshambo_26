---
shelf: program
status: open
updated: 2026-08-15
---

# Item 4 — Merchant Row

Item 4 of [[friends-family-baseline]]: a machiya merchant row on the arena promenade —
4 façade shells plus one WORKING fireworks shop (browse/buy at the counter). The working
shop already exists: [[hanabiya]] (花火屋), built and owner-gated 2026-08-13 with the place
saved (`37469b8` names it "the merchant row's first machiya"). Remaining scope is the row
itself — the façade shells around it.

## Current state

- **[[hanabiya]] is built and working** (interior stair + attic `219509c..565c307`, shop-panel
  cursor fix `322d948`, frontage deepened z44 → z36 `22bcf2e`). It sets the archetype's
  as-built reference.
- **machiya is a new archetype — needs its own brainstorm** before the shells are built.
- Massing references: `ServerStorage.Sandbox_PARKED.MerchantMassing` (per the baseline
  spec, line 103) — verified in the live place 2026-08-15 (Studio MCP, Edit mode):
  6 children survive (`Machiya_1..4`, `Machiya_East`, `DockDeck`), matching [[place-state]].
- **The corridor-reservation prerequisite is dissolved** — the reservations were
  RETIRED 2026-08-15 (owner's call), not re-derived. Nothing at runtime or in any bake
  ever read them; their one job (keeping a free 55×30 garden slab out of the streets)
  ended when the panel was pinned to the pavilion's post faces (`17927df`, tested).
  The row builds to `Machiya.luau`'s owner-surveyed envelope (frontage z36); if the
  row wants a machine-readable street reservation, derive it fresh from the massing
  at the machiya brainstorm — which is now the next step.

## Gates & decisions

- 2026-08-15 owner decision: corridor reservations retired from `ArenaLayout.luau`
  (with their tests) rather than re-derived — see log.
- 2026-08-13 owner gate: hanabiya done for now, place saved. Dropped, do not re-raise:
  the terrain cut behind the shop + its ishigaki dressing.
- 2026-08-13: the frontage deepening was accepted against the promenade on the promise of
  the karesansui reduction; that reduction executed 2026-08-14 (`17927df`) — the borrowed
  promenade depth is repaid.

## Raw layer

- spec: `docs/superpowers/specs/2026-07-30-friends-family-baseline-design.md` (item 4)
- shop ledger: `.superpowers/sdd/2026-08-05-hanabiya-shop/`
- key commits: `37469b8` shop as-built doc · `22bcf2e` frontage z44→z36 · `219509c` stair
  + counter · `565c307` attic ties · `322d948` cursor grip · `17927df` karesansui shrink
