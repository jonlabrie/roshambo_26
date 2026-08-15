---
shelf: program
status: open
updated: 2026-08-15
---

# Item 4 — Merchant Row

Item 4 of [[friends-family-baseline]]: a machiya merchant row on the arena promenade —
4 façade shells plus one WORKING fireworks shop (browse/buy at the counter). The working
shop already exists: hanabiya (花火屋), built and owner-gated 2026-08-13 with the place
saved (`37469b8` names it "the merchant row's first machiya"). Remaining scope is the row
itself — the façade shells around it.

## Current state

- **hanabiya is built and working** (interior stair + attic `219509c..565c307`, shop-panel
  cursor fix `322d948`, frontage deepened z44 → z36 `22bcf2e`). It sets the archetype's
  as-built reference.
- **machiya is a new archetype — needs its own brainstorm** before the shells are built.
- Massing references: `ServerStorage.Sandbox_PARKED.MerchantMassing` (per the baseline
  spec, line 103) — ⚠ unverified: Studio not connected to confirm it survives in the
  live place.
- **Prerequisite: re-derive the corridor reservations.** The `corridors` block in
  `roblox/tools/builders/ArenaLayout.luau:210-213` (`eastCorridor = {34,-10,54,38}`,
  `shopCorridor = {-20,28,34,44}`) is stale: it predates the hanabiya frontage move
  z44 → z36 (`22bcf2e`) and the 2026-08-14 karesansui shrink to the bell tower's own
  floor (`17927df`). Do not build shells against those rectangles as written.

## Gates & decisions

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
