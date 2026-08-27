---
shelf: world
updated: 2026-08-15
checked: 2026-08-26
---

# Viewing Platform

The clearing's east-edge overlook and the downcanyon vista it frames. The canyon's
terrain used to end at ~x135 with the view pouring into void; the fix (2026-06-17/18)
swerved the gorge north around a mossy prow, wrapped the river around it, and
dissolved the far end into mist. The twin decks are Rojo-managed
(`tools/builders/Overlook.luau` → `RoshamboStage.Overlook`, verified 2026-08-15); the
gorge itself was hand-carved by the owner and the water/VFX dressing is place-state.

## As built

- **Twin tiered kake-zukuri decks** (`e9f7fa1` builder, `691eeb7` staged) cantilevered
  east over the gorge: heavy posts, under-slab girders, kōran rails with open/gap/
  no-barrier edge options, invisible 12-stud barrier walls on the gorge edges, single
  `UpperStep` threshold. Upper deck pos {74,113,28}, size {34,0.6,30}. The
  [[arena-square]] torii now stands on the upper deck's west edge and `ArenaSpawn`
  sits on the deck. It is also a fireworks launch site (`Site_Overlook`,
  [[fireworks]]).
- **The gorge** (T4): a procedural carve was rejected — blocking sightlines left the
  river no logical exit — and the owner hand-carved the continuation instead
  (swerve north, buttes killing the eyelines). `buildDowncanyon.luau` then *dressed*
  the hand-carved groove (`ad1d341`): river line pools (head/Bow-Tie → run → lip →
  plunge, each behind a basalt sill so it doesn't read as a naked blob), Beam-ribbon
  falls with hand-positioned endpoints, light mist at the bases. Renamed into the
  W## series as `W14/15/16_*Cascade` (`20ac08b`, [[canyon]]).
- **Lantern telegraph** (`LanternController.client.luau`, prototyped here): each
  lantern body gets runtime SurfaceGui faces — kumiko frame + a dark glyph showing
  the last World Throw in unison, updating on the `drumRest` EventBus cue with a
  fade-down/swap/up. Since deployed on the deck newels, `FallsLanding`, the
  switchback `DeckLantern` and the chōchin poles; lanterns are found by `*Lantern`
  name (a CollectionService-tag rollout was noted as the cleaner canyon-wide
  mechanism and never became necessary).
- **Greening**: the T6 skin-moss + curated-pack foliage passes were superseded — the
  scatter foliage of that era was deleted ("need better assets") and the whole
  foliage program restarted later on the Xfrog palette ([[foliage]]). What survives
  from T6: the LeafyGrass moss base coat on the downcanyon walls and the
  `greenCanyon.luau` pattern.
- The 2026-06-18 "North Star" image (mossy gorge, stilted teahouses up both walls,
  lantern stairs, suspension bridge, hero falls) became the canyon-village program —
  paths, teahouses and bridge were subsequently built under it ([[paths]],
  [[teahouses]]); the plan's T7 lantern-dots and T9 composition gate were folded into
  that larger effort rather than closed standalone.

## Gates & decisions

- Owner ruling from the T4 revert: **solve the water's exit path first, then block
  sightlines around it** — a vista design that traps the river reads wrong.
- View is a solid set-piece (non-traversable); far end = cascade into mist; railing
  language bamboo/kōran per the reference; T6 "green balls" procedural blob plants
  rejected, and the interim curated foliage pack rejected after it ("need better
  assets") — both purges deliberate.
- Falls beams work with the official water texture (`16808804567`, Stretch, len 1,
  speed 0.35–0.55 — the owner kept lowering speed); the earlier "beams rejected"
  reading was wrong (the texture was the failure, not the beams).

## Raw layer

- spec: `docs/superpowers/specs/2026-06-17-zendojo-viewing-platform-design.md`
  (`f3d11a6`); plan (`98a6c6d`, 9 tasks)
- key commits: `a42fdb8` overlooks block · `e9f7fa1` Overlook builder · `340a2b1`
  FoliageScatter · `ad1d341` downcanyon water/VFX · `691eeb7` decks + telegraph
