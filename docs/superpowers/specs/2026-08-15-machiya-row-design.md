# Machiya Row — Design

**Date:** 2026-08-15
**Status:** Approved
**Program:** friends-family baseline item 4 (`docs/wiki/program/item-4-merchant-row.md`)

## Scope ruling (owner, 2026-08-15)

**Façades with identity.** The new shops are shells with real archetype variety —
signage, noren, lit shallow interiors — each assigned its future business so the
street reads alive. Working commerce arrives with items 6/7. 花火屋 (built, working)
stays the row's one working shop.

**Shallow enterable.** Open frontage like 花火屋, dressed one room deep — racks,
shelves, a counter, warm light — nothing interactive yet. Exception: the sports book
is a closed kōshi teaser until its cavern exists.

## The street plan (from the owner's massing, ServerStorage.Sandbox_PARKED.MerchantMassing, surveyed live 2026-08-15)

| Shell | Envelope (massing) | Business |
|---|---|---|
| Machiya_1 | x −22..2, z 42, 24.7 wide (widest frontage) | **Avatar apparel** |
| 花火屋 (built) | x −1.67..16.26, z 36..52 | Fireworks (working) |
| Machiya_4 | x 24, z 43, 16.6 wide | **Teahouse accessories** |
| Machiya_East | x 74, z 48 | **Sports book frontage** |
| Machiya_2 | x −57, z 15 (lower ground, by the river) | **Riverside chaya** (tea stand — ambience, no commerce, ever) |
| DockDeck | (−44, −12), 14 × 10 | Chaya's companion deck |

Machiya_3 in the massing ≈ 花火屋's own slot; superseded by the built shop.

**Sports book siting (owner's call):** the two candidate sites converge — Machiya_East
is the frontage, and its future interior bores into the hillside under the western
Overlook, exactly where the 2026-07-28 canyon-destinations spec put the statistics
room (73, 110, 19). One destination, both ideas. **The cavern is item 7's work, not
this item's — no terrain is dug here.** The public-facing name is deferred: "sports
book" copy must be reconciled with the no-wager-language ruling
(`docs/wiki/practice/owner-rulings.md`) when signage is authored.

## 1. The archetype refactor (Machiya.luau)

`Machiya.build(palette, layout)` becomes `Machiya.build(palette, layout, shop)`:

- `shop.envelope` — `{x0, x1, z0, z1, floorY}`, **owner-surveyed, never derived**
  (measured from the massing blocks in Studio and read back as literals — the same
  holdout flow that built 花火屋).
- `shop.storeys` — count/heights where they legitimately vary.
- `shop.frontage` — `"open"` (posts + raised floor, no street wall) or `"koshi"`
  (closed lattice, lit within).
- `shop.identity` — the identity kit (§2).

花火屋's numbers move verbatim into the first spec table, comments preserved.
**Refactor gate: a snapshot test** — the emitted part-spec for 花火屋 must be
identical before and after the refactor; the suite proves the change is invisible.

Derived guards stay universal, run per shell:
- tower subordination: shell top ≤ `ArenaLayout.towerTopY − MIN_SHORO_GAP` (9.0)
- kamoi at 6.8 for avatar clearance; the shoji transom must not collapse to zero
- eave encroachment is aerial-only and clears an avatar
- timber faces sit exactly on the frontage plane; stucco sets back
  (flush-outside-edges and derive-from-what-it-touches rules,
  `docs/wiki/practice/`)

## 2. Identity kits

Per shop: noren (colour + mon, chained segments on `NorenSway.client.luau`), kanban
via the glyph SDF pipeline (`docs/wiki/practice/blender-pipeline.md`; moderation
rules in `image-moderation.md`), eave chōchin per the 花火屋 precedent
(`buildHanabiyaChochin.luau` pattern), warm interior lighting, and a one-room-deep
dressing set:

- **Apparel (Machiya_1):** kimono stands and racks in the open bays, folded cloth
  stacks, a counter. Display IS the façade — the wide frontage is why apparel lives
  here.
- **Accessories (Machiya_4):** shelves of actual decoration-economy props (lanterns,
  screens, flags) — the shop previews the Piece B catalog with committed assets.
- **Sports book (Machiya_East):** closed kōshi lattice, strong interior glow, an
  unlit exterior board. No interior. No name/copy yet.

Dressing reuses existing committed props/builders; anything new is built, never
toolbox-imported (`toolbox-backdoor-scan` rule).

## 3. The chaya + DockDeck

`Chaya.luau`, a separate small builder — an open pavilion is the wrong shape to force
through the machiya archetype. Posts, raised floor, roof, half-noren — organized
around **a service counter splitting the floor into a customer side and a working
side**:

- **NPC work slot (future-proofing, owner 2026-08-15):** a clear avatar-width
  standing spot behind the counter — flat floor, no collisions — with the gear
  (brazier, kettle, tea caddies, stacked cups) on the counter's back edge and a rear
  shelf, all within reach of the slot. A future NPC character will take, make, and
  deliver tea orders from here; no NPC ships in this item. Until then the working
  gear reads as "the keeper just stepped away."
- **`ChayaKeeperSlot`** — a named invisible anchor part marking the slot, so the
  future NPC binds to geometry, not coordinates (the replication-races lesson:
  discover by name/tag, never by position).
- Counter height follows the 花火屋 counter precedent (sized to a keeper standing
  behind it).
- Customer side: bench + floor cushions facing the water.

DockDeck: existing deck recipes (posted timber, flush edges,
`docs/wiki/practice/build-recipes.md`).

## 4. Siting & terrain

Shells sit on the massing positions with full-footprint footing probes at every
placement (placement-discipline rule). Machiya_East's yaw and its relationship to
the Overlook's structure get surveyed in Studio before its spec is written. South-row
backs take only whatever minimal grade-meeting the probes demand, owner-gated in
Play. No cavern, no street reservation (corridors retired 2026-08-15 — derive one
fresh only if this work proves it needs one).

## 5. Files & pipeline

- `roblox/tools/builders/Machiya.luau` — refactored archetype
- `roblox/tools/builders/MachiyaShops.luau` — one spec table per shop (envelopes,
  identity kits)
- `roblox/tools/builders/Chaya.luau` — new
- Emission via `JsonEmit` → `assets/*.model.json`, registered in
  `default.project.json` under `RoshamboStage` + `WorkspaceConvention`
  `DECLARED_STAGE_CHILDREN` — same pipeline as 花火屋 and the torii. Rojo re-reads
  project.json only on reconnect.
- Tests: snapshot refactor gate; per-shell guard tests (subordination, clearances,
  frontage planes); chaya suite (counter split, keeper slot clearance, deck flush).

## 6. Build order & gates

1. Refactor (invisible; suite-gated, no visual change)
2. Apparel (Machiya_1)
3. Accessories (Machiya_4)
4. Sports book teaser (Machiya_East)
5. Chaya + DockDeck

Each shell: one visual attempt in Studio, then the owner looks (standing rule). Wiki
updated at each gate per `docs/wiki/schema.md` triggers.

## 7. Out of scope

Working commerce (items 6/7), the cavern and statistics screens, sports-book
naming/signage copy, the NPC itself (geometry only), street reservations.
