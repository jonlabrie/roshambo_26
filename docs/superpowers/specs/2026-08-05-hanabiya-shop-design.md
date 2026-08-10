# 花火屋 — the firework shop

**Status:** design, approved in conversation 2026-08-05.
**Programme:** layer 5 (merchant row) of the arena-amplified plan; the physical face of the
firework economy shipped in `a25f0c7..743665d`.

## Why

Fireworks are code-complete and **unbuyable**. The server accepts `firework:<id>` and `mortar:<S|M|L>`
through the existing `RequestPurchase` route, priced and validated and tested — and no surface
anywhere offers them. What actually works today is: win a round, receive one firecracker, launch it.
Peony and willow are greyed forever behind mortars nobody can buy; ishibana sits at ×0 forever.
**Three of the four shells can never fly**, and the picker renders them dimmed with correct reasons,
so it reads as working.

This project builds the smallest thing that closes that loop and, in doing so, establishes the
machiya archetype the rest of the merchant row will reuse.

## Scope

**In:** one building — 花火屋 — with a working counter selling all four shells and all three mortars.

**Out:** the other four shopfronts (植木屋 / 提灯屋 / 茶屋 / 面屋). They have no economy behind them —
decorations already sell through the teahouse panel, and lanterns, masks and the teahouse shop sell
nothing at all. Four facades that do nothing when approached is worse than one that works. They are
a later project which reuses this one's archetype, signage pipeline and threshold module wholesale.

Also out, deliberately: no shopkeeper NPC, no interior beyond the doma you stand in, no upper-floor
access, no opening hours, no stock limits.

---

## 1. Site

`ArenaLayout.karesansui.corridors.shopCorridor = { -20, 28, 34, 44 }` — the promenade, reserved as
an inviolable main street, with the note *"shops back onto the south upslope."* So the corridor is
the street and the building sits on its south side: **frontage line z44**, keeping all 16 studs of
promenade clear.

**Footprint: x18 → x34, z44 → z52.** 16 wide, 8 deep — the massing approved in conversation. Floor
datum **113.1**, the karesansui's `floorY.main`, so the shop floor is continuous with the square.

### The survey (2026-08-05, raycast, foliage excluded)

Top surface, floor datum 113.1:

| | x14 | x18 | x22 | x26 | x30 | x34 | x38 |
|---|---|---|---|---|---|---|---|
| z44 | 113.3 | 113.6 | 113.8 | 114.4 | 114.7 | 113.8 | 113.9 |
| z46 | 114.2 | 113.9 | 115.3 | 116.3 | 115.5 | 113.9 | 114.4 |
| z48 | 115.4 | 117.4 | 118.3 | 118.6 | 117.0 | 114.0 | 114.0 |
| z50 | 117.3 | 122.8 | 121.1 | 120.5 | 119.5 | 114.0 | 114.7 |
| z52 | 125.5 | 125.7 | 124.3 | 123.0 | 121.3 | 115.4 | 115.8 |

**There is a knoll at x18–x30 that climbs hard past z46.** Cut depth at the back wall (z52), floor
to grade: x18 **12.6**, x22 **11.2**, x26 **9.9**, x30 **8.2**, x34 **2.3**. The cut is a wedge —
two storeys of stone at the west end, barely a step at the east.

**⚠️ THE ONE NUMBER TO LOOK AT IN STUDIO.** A 12.6-stud cut behind an 8-deep building puts the shop
in a slot, with an ishigaki face as tall as the machiya itself. That may read as dramatic or as
buried; it cannot be judged from a survey table. **If it reads buried, pull the back wall to z50**
— the cut drops to 9.7 / 8.0 / 7.4 / 6.4 / 0.9 and the interior loses 2 studs of depth. Decide it by
looking, at the first Studio gate, before the ishigaki is built.

**This was checked against the alternative and rejected:** ground east of x34 is almost flat
(113–116 through z50), so a shop at x34–50 would need no cut at all — but that abandons the reserved
corridor, which the programme is explicit the row builds against, and crowds the Overlook approach.
Building where the reservation says is worth the excavation.

**A finding for the future row:** since the knoll rises westward, the remaining four shops will
need progressively deeper cuts. The row should **step up the hill going west** rather than hold one
floor level. Decide that when the row is specced; do not let this building's datum imply the others.

---

## 2. The building

Machiya, not teahouse. Every enclosed structure in the canyon so far is a teahouse; the whole point
of a new archetype is that a shop reads differently from a dwelling.

**What makes it a machiya:**

- **Open shopfront** (*mise-no-ma*). No wall at z44 — posts and a raised timber floor 0.6 proud, so
  the goods face the street. This is the single strongest signal that it is not a teahouse.
- **Deep eave**, ~2.5 studs of overhang over the frontage, carrying the noren and two chōchin.
- **Upper floor** with *kōshi* lattice shutters. Closed, purely facade — nobody goes up. It exists so
  the kanban has somewhere to live at a height that reads from the suspension bridge and the perch
  teahouses, which is what the reference image gets its presence from.
- **Tiled hip roof** in the shōrō's vocabulary. Do not invent a second roof language for the square.
- **Ishigaki** on the exposed cut at z52, per recipe §3: dark recessed backing (`~46/47/45`), flat
  proud stones at `RELIEF 0.22`, horizontally coursed, near-monochromatic `96/98/94 ±3`, inset 0.12.
  The wedge shape is fine — §3's `w = vs / Hs` rule maps the stone field to local wall height
  precisely so a varying-height wall fills base-to-top everywhere.

**Materials, from `zendojo-canyon-build-recipes.md`** — no new palette:

| element | material | dims | colour |
|---|---|---|---|
| floor slab | `WoodPlanks` | 0.6 thick | `107/79/51` (earth orange, `{0.42,0.31,0.20}`) |
| posts | `Wood` | 1.125 sq | timber |
| girders | `Wood` | 1.2 × 0.825 | timber |
| counter | `WoodPlanks` | 0.6 | timber |
| kōshi lattice | `Wood` | 0.18 members | timber |
| ishigaki | per §3 | — | `96/98/94`, joint `46/47/45` |

**Standing rules that bind this build:**

- **Outer edges flush** — posts and girders inset so their outer face aligns with the slab edge
  (`x ± POST_W/2`), as `SwitchbackDeck` does. Non-flush work gets sent back.
- **Walls register to the BUILT edge**, +1.5–2 standoff, never to the excavation line; rough backfill
  goes behind and the user finish-smooths.
- **One visual attempt, then stop and ask.** Build it, let the owner look in Studio, iterate on their
  read. Never self-judge the look.

---

## 3. Signage

**花火屋** on a kanban board under the upper floor, generated through the glyph SDF pipeline
(`tools/glyphs/`) that produced the R/P/S glyphs — same route, three characters, wide board.

Two hazards carried forward from that pipeline:

- **Image moderation.** A green palmate leaf texture was once removed as a false positive while gold
  and red of the same leaf survived. Kanji should be uncontroversial, but upload early rather than at
  the end, so a rejection does not block the build.
- **`SurfaceGui` `TextSize` caps at 100px and `TextScaled` is inert.** Big text needs a *small*
  canvas. The board is an uploaded image, not a TextLabel, precisely to sidestep this.

Two chōchin hang under the eave, tagged **`RoundLantern`** so `LanternController` finds them —
discovery is by CollectionService tag, not by name or parent, and not by living under
`RoshamboStage`. They will carry the round result like every other lantern in the canyon, which is a
free tie between the shop and the game.

---

## 4. The threshold

An invisible trigger volume over the shop **interior**: x18–34, **z45–52**, y113–118, tagged
`ShopThreshold` with a `shopId` attribute.

**It starts at z45, one stud inside the frontage.** That is the whole design. A trigger on the
frontage line at z44 would fire on every player crossing the square along the promenade; a trigger
inside the building only fires on someone who has stepped in. This is what makes "walk in, panel
opens" safe rather than intrusive.

Detection is **client-side**, an axis-aligned box test against the local character, evaluated on a
heartbeat. Entering opens the panel, leaving closes it. No server round-trip, so it is instant — a
doorway that takes half a second to notice you reads as broken.

The inside test lives in a pure module, `ShopThreshold.luau`, for the same reason `LaunchSites` is
pure: **no harness in this repo loads a `.client.luau`**, so any rule worth trusting has to live
outside one. It is a small module and it should stay small.

---

## 5. The panel

A new `ShopController.client.luau`. Not folded into `TeahouseController` — that file is already
~1100 lines and owns a different surface.

Contents: the shop name, your points balance, the four shells with price and owned count, and the
three mortars with price and owned/locked state. A shell you cannot afford is dimmed with its price
still legible; a mortar whose tier below is unowned says so rather than simply failing.

Buying fires the existing `RequestPurchase` remote with `firework:<id>` or `mortar:<S|M|L>`.

---

## 6. Two wiring gaps this exposes

Both are real defects in what is already shipped, not new work invented by this design.

### 6a. Prices are not on the wire

`EconomyState.catalog` carries `PRICES` from `economy.ts` — decks, teahouses, portal, decorations.
`SHELL_PRICES` and `MORTAR_PRICES` live in `fireworks.ts` and are sent to **nobody**. The panel needs
them.

Hardcoding them client-side would be a fourth instance of a defect class this project has already
been bitten by three times — a number authoritative on the server, re-derived client-side, going
stale, with the signature that *the display is wrong while the underlying number is right*. So:
**extend the catalog payload** with the shell and mortar prices, and read them.

### 6b. Buying a shell does not update your count

`RequestPurchase`'s handler echoes `EconomyState`, so points update. Nothing pushes `FireworkState`.
A player would buy a peony, watch their balance drop, and see the picker still reading ×0 until the
next reveal pushed state for its own reasons.

Fix: call `pushFireworkState(player)` after any `firework:` or `mortar:` purchase, in the same place
`echoEconomy` is already called.

---

## 7. One decision, stated so it is not mistaken for an oversight

**The server does not check that you are standing in the shop when you buy.**

Decks, teahouses, the portal and decorations are all bought from a panel, from anywhere in the
world. Gating this one route by location would be inconsistent machinery for no security gain: you
can only ever buy what you can afford, and the ledger is authoritative either way. **The shop is a
discovery surface, not a boundary.**

The *launch* referee is unchanged and does gate — where you may fire a shell from is a real rule,
re-validated server-side on every request. The distinction is deliberate: launching from someone
else's deck would be a broken rule; buying a peony while standing on a bridge is merely dull.

---

## 8. File structure

**New:**

| file | what |
|---|---|
| `roblox/tools/builders/Machiya.luau` | pure builder, the archetype; parameterised so the other four reuse it |
| `roblox/assets/Hanabiya.model.json` | generated, committed, never hand-edited |
| `roblox/tests/Machiya.spec.luau` | geometry invariants |
| `roblox/src/shared/ShopThreshold.luau` | pure inside test |
| `roblox/tests/ShopThreshold.spec.luau` | its tests |
| `roblox/src/client/ShopController.client.luau` | the panel |

**Modified:** `tools/genmodels.luau` (register the output), `default.project.json` (declare the
model), `server/src/routes/apiV1.ts` (catalog payload), `roblox/src/server/main.server.luau` (push
state after purchase).

**No new remote.** The panel reads counts and owned mortars from `FireworkState` and points and
prices from `EconomyState`, both of which already exist and already reach the client. Adding a
third channel carrying the same facts would be a second source of truth for a number the HUD picker
is also rendering.

The builder is **pure and deterministic** and its output is committed, so the arch-portability rule
applies: byte-identical on arm64 and x86_64 or the CI drift check fails. **No transcendental hashes**
— integer LCG only — and snap near-zero residues to 0 in `JsonEmit`.

---

## 9. Testing

**Testable, and therefore where the decisions live:**

- `Machiya.build()` — deterministic geometry. Frontage is open (no wall part at z44), the floor slab
  sits at 113.1, outer faces are flush with the slab edge, part count and naming are stable.
- `ShopThreshold.isInside()` — the box test, its boundaries, and the z45 inset that keeps promenade
  traffic out.
- Server-side: the catalog payload includes every shell id and every mortar id. **Verify by mutation**
  — removing a price must fail a test, or the gate is decoration.

**Not testable, by construction:** the panel, the trigger wiring, and how any of it looks. A green
suite says the builder still emits the same JSON. It says nothing about whether the shop reads as a
shop.

---

## 10. The Studio gate

1. **Sculpt the cut** behind the frontage — the one place-only step, and the biggest. Rough-carve;
   the owner finish-smooths.
2. **The building reads as a shop, not a teahouse**, from the promenade and from the bridge.
3. **The kanban is legible** from the suspension bridge — the reason the upper floor exists.
4. **Walking the promenade does not open the panel.** Walking in does. Walking out closes it.
5. **Buy a firecracker for 1 point** — balance drops, count rises immediately, no waiting for a reveal.
6. **Buy `mortar:S`, then a peony** — the peony stops saying "needs a small mortar" and flies from a
   launch site.
7. **`mortar:M` is refused before `mortar:S` is owned**, with the tier-order reason shown.
8. **Save and publish.** The terrain cut is place-only and in no repository.
