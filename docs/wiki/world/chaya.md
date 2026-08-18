---
shelf: world
updated: 2026-08-17
---

# Riverside Chaya

The tea stand on the river square's beach, and the dock it is butted against — the last
shell of [[item-4-merchant-row]], owner-gated 2026-08-17 with the place saved. Rojo-managed
(`assets/Chaya.model.json`, builder `tools/builders/Chaya.luau`, `RoshamboStage.Chaya`); its
`Thatch` MaterialVariant is place-only, rebuilt by
`tools/studio/setupCenterpieceMaterials.luau`.

**Not a machiya, and not built like one.** The row's four shells are dressed town-houses:
stucco, kōshi, kawara. This vendor is rougher and open to the air (owner) — a pavilion of
round posts, thatch on exposed rafters, a plank counter, and no walls at all. Pushing it
through `Machiya.luau` would have given it the one thing it must not have: a front.

## The arrangement (owner, 2026-08-17)

> "the dock out over the water, and the chaya butted up against the dock's south edge,
> facing North. Basically you should be able to step onto the dock and turn left to look at
> the Chaya counter, or turn right and a couple of steps out onto the dock over the water."

You arrive along the beach from the east. Both structures share the same x span west of x
−41 so they read as one object from the water; only the dock runs further east, four studs
onto the sand, which is where you walk on.

| | extent | top | founded on |
|---|---|---|---|
| Dock | x −52…−37, z −3…7 | 112.6 | 12 round posts: bed at 101.7–108.5, then ashore |
| Chaya floor | x −52…−41, z 7…17 | 114.6 | 6 round posts, beach 111.8–113.6 |
| Counter | z 11.6…13.4 | 116.9 | keeper's strip 2.8 clear behind it |
| Ridge | over z 11.2 | 124.0 | eave oversails north to z 4.4, over the dock |

Two 1.0 risers step from dock to floor. The eave reaches out over the dock so the counter
has shelter in front of it.

## As built

- **Round posts everywhere** (owner's standing note for this build): every post carrying
  either deck is a stood-up cylinder on its own surveyed foot, twelve terrain probes taken
  2026-08-17 and baked into the builder. Tests pin the shape, the vertical aim and the
  circular section — a box post is the default a builder falls into.
- **The frame is a frame.** Post → girder → joist → board, each tier crossing the one
  below, joists at a 2.5 pitch. The roof has tie beams plate to plate over each post column,
  a king post on each tie, a ridge purlin on their heads, and knee braces at the four corner
  posts. The first cut had none of that — boards spanning eleven studs on faith, girders laid
  parallel to the boards they were meant to carry, no ridge member at all — and the owner
  called the engineering suspect on sight.
- **Thatch is a real scan**, ThatchedRoof002A (ambientCG CC0, owner-supplied), on
  BaseMaterial Grass at `StudsPerTile` 4.0. Edges are **rolled**: a bundle along each eave
  and up each verge, dropped an inch below the slab's centreline so nothing stands proud as a
  lip, with each verge dying into the eave roll's axis so the corners close flush.
- **The counter splits the floor.** Keeper's side south: brazier, kettle, caddy shelf on the
  rear posts, cup stacks. Customers north: three log-round stools at 24″ pulled up to the
  counter, and the endai bench at 18″ out by the rail facing the water. Two seats because
  they do different jobs — a bench at a 36″ counter cannot be served at, which is what the
  first arrangement tried.
- **`ChayaKeeperSlot`** — named, invisible, non-colliding, 4 wide × 6 tall × 2.8 deep. A
  future NPC binds to it BY NAME, never to a coordinate ([[replication-races]]). Until then
  the gear reads as "the keeper just stepped away". No NPC ships in item 4.
- One chōchin, canonical recipe, hung off the east rafter tail over the corner you step onto
  from the sand. Half-noren at the front rail, plain — no mon. A rolled sudare on the west
  side, on its own beam between the west posts.

## Gates & decisions

- **2026-08-17 owner gate: ACCEPTED, place saved.** Reached through five looks — the counter
  two studs south then one back north, the dock four studs east onto the sand, the seating
  rebuilt as stools plus bench, the thatch rolls added then dropped two inches then raised
  one.
- **Both massing marks are SUPERSEDED, not deleted.** `Machiya_2` sat twenty studs up the
  bank across an 11.20-stud fall with three shore boulders under its low corner;
  `DockDeck` sat 24 studs offshore over 8 studs of water with no way onto it. The blocks
  survive in `ServerStorage.Sandbox_PARKED.MerchantMassing` as history — see [[place-state]].
- **The lantern is RED** (owner: "Yes, I know red means alcohol and we're serving tea, but
  red is punchy"), overriding the row's 2026-08-15 rule excluding true red as izakaya
  signalling. What the ruling does not reach is `Chochin.LEGIBILITY_FLOOR`: the paper is
  `{255, 124, 84}`, luminance 0.584 against a floor of 0.55, because every chōchin in the
  canyon carries the World Throw glyph on an untinted plate and a deeper crimson (~0.32)
  would swallow it at night. The owner reads the result as "coral/mango, but that's not bad".
- **No NPC, no commerce.** The design spec's chaya is ambience — "no commerce, ever". The
  keeper slot is the whole of the future-proofing.

## Raw layer

- design spec: `docs/superpowers/specs/2026-08-15-machiya-row-design.md` §3
- plan: `docs/superpowers/plans/2026-08-15-machiya-row.md` Task 7
- key commits: `eb73071` first build · `3b4a0ee` counter/dock moves · `fb300f8` the frame ·
  `404e767` red lantern on a rafter tail · `fc92c2a` thatch scan · `c67dd39` stools + rolled
  edges · `8aebe48`/`1ceeb1b` corner and lip
