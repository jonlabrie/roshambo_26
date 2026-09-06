---
shelf: world
updated: 2026-09-06
checked: 2026-08-26
---

# Hanabiya

花火屋 — the fireworks shop, the merchant row's first machiya (`37469b8`), on the
square's south flank. A working shop, not a façade: browse/buy at the counter against
the live economy, verified end-to-end in game 2026-08-13 ([[fireworks]]). The shell is
Rojo-managed (`assets/Hanabiya.model.json`, builder `tools/builders/Machiya.luau`,
`RoshamboStage.Hanabiya` — verified in place 2026-08-15); its chōchin are place-only.
Program context: [[item-4-merchant-row]].

## As built (owner-gated 2026-08-13, place saved)

- **Frontage at z36** (`22bcf2e`): moved from z44, doubling the depth — the back is
  the terrain cut and does not move; customer floor went 3.6 → 11.6 studs. The roof
  flattened 45° → 24.5° (an improvement — 45° was a temple pitch on a townhouse), and
  the counter and the flank-bay COUNT re-pinned to the back (the 4-stud module is
  what is fixed, not the count).
- **Interior stair + attic** (`219509c..565c307`): counter forward a stud for a
  shopkeeper; steep east-wall stair (48°, 11 treads, housed into its stringers) with
  a headroom-derived well cut in the attic floor; roof raised a stud after a
  climber's head came through it (attic headroom 5.62 → 6.76, `a0e7287`); stringer
  feet buried (`f80e72f`); attic tie beams stopping an inch inside the walls
  (`cb7acc0`, `565c307`).
- **Noren**: chained cloth segments swayed by `NorenSway.client.luau`, Transparency
  0.1, `NorenCloth` material variant (variant verified in the place 2026-08-15).
- **Chōchin** at each of the eave's outside corners
  (`tools/studio/buildHanabiyaChochin.luau`; output place-only at
  `CanyonWorld.Structures.Chochin_Hanabiya` — verified present 2026-08-15). Hem 5.69
  above the floor; the owner accepted a duck-under.
- **Shop panel cursor** (`322d948`): while the panel is open the controller forces
  `MouseBehavior = Default` from `BindToRenderStep` at RenderPriority.Camera+1 and
  touches the camera not at all — took three commits; the owner caught both wrong
  ones.

## Gates & decisions

- 2026-08-13 owner gate: hanabiya done for now, place saved.
- **Dropped, not deferred — do not re-raise**: the terrain cut behind the shop ("it's
  fine for now") and therefore the ishigaki that would have dressed its exposed face.
- The frontage deepening was accepted against the promenade on the promise of the
  karesansui reduction; that executed 2026-08-14 (`17927df`, [[arena-square]]) — the
  borrowed depth is repaid.
- Duck-under chōchin hem accepted as-is.
- Worth carrying: the building took ~eighteen rounds of art correction, every one
  caught by the owner's eye, never by a test; the feature worked on its first real
  run. Nothing protects geometry but pressing Play.

## Raw layer

- ledger: `.superpowers/sdd/2026-08-05-hanabiya-shop/`; as-built doc commit `37469b8`
- key commits: `22bcf2e` frontage z44→z36 · `219509c` stair + counter · `a0e7287`
  roof +1 · `565c307` attic ties · `322d948` cursor grip

## The roof (added 2026-09-05 — the page did not mention its own roof)

A railed rooftop battery platform (Rojo asset `HanabiyaRooftop`, three aimed tubes, sized for
three players plus a console) was built and gated 2026-09-06 per `docs/wiki/log.md`; it is the fireworks
system's virtual sixth station and the future home of the MC console. As-built and design intent
live on [[fireworks]] and on [[backlog]] § Rooftop MC experience; access (a hatch through the
roof at the back-rail gap) is deliberately unbuilt so it can be gated.

## Melting (backend only, 2026-09-06)

The shop will melt held shells back to powder at list price — the backend route exists
(`POST …/fireworks/melt`, [[fireworks]] § Powder and drops) and `NetworkClient.postFireworkMelt`
calls it, but **the counter has no melt verb yet**: the client half waits for the
`main.server.luau` split ([[backlog]] § Hanabiya melt verb).
