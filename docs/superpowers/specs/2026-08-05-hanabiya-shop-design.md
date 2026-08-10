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

**Footprint: x−1.67 → x16.26, z44 → z52, floor 113.10, top 127.36.** 17.93 wide × 8.00 deep ×
14.26 tall, yaw 0.

**THESE NUMBERS ARE THE OWNER'S, NOT A PROPOSAL.** They were not derived — a holdout block was put
in Studio at the proposed footprint and the owner moved and resized it in place; this is its
measured transform, read back on 2026-08-05. My proposed x18–34 was wrong in a way no survey table
would have caught: it sat the building at one end of the corridor rather than composing the row.
The study block survives at `Workspace.Sandbox.HanabiyaStudy` for re-measurement.

Three things the owner fixed, each load-bearing:

- **Centred on the corridor** (block centre x7.30; corridor centre x7.0), leaving **18.3 studs of
  frontage west and 17.7 east** for smaller flanking shops. 花火屋 is the row's ANCHOR, not one of
  five equals — that is a composition decision and it governs the rest of the row.
- **Floor exactly on datum** (113.10) and **frontage exactly on z44**, so the promenade is untouched.
- **Taller: 14.26**, up from my 12. It tops at 127.36 against the shōrō's 136.5 — **9 studs
  subordinate to the bell tower**, which is the relationship the square depends on. Do not let a
  later roof tweak close that gap.

The footprint is **completely clear**: no geometry and no foliage stands inside x−2…17, z43…53.

### The survey (2026-08-05, raycast, foliage excluded)

Cut depth above the floor datum along the back line (z52), across the whole corridor:

| x | −20 | −14 | −8 | −2 | 4 | 10 | 16 | 22 | 28 | 34 |
|---|---|---|---|---|---|---|---|---|---|---|
| cut | 11.1 | 9.7 | 6.7 | 6.8 | 6.9 | 11.1 | 12.5 | 11.2 | 9.3 | 2.3 |

**The hill is not a slope — it is a saddle (x−8…7) and a ridge (x10…22).** The building spans both:
roughly **6.8 studs of cut across its west two-thirds, 11–12.5 across its east third.**

Sliding it ~6 studs west would sit it wholly in the saddle at a uniform ~7 studs — and was
**rejected**, because it costs the centring. Composition cannot be fixed later; excavation is
terrain work.

**A correction to this spec's earlier draft:** it warned that a 12-stud ishigaki face was the one
thing to judge by eye. That over-stated it. With the building butted into its own cut, **most of the
retaining face is hidden behind the building** — what is actually visible is where the cut continues
past the shop's ends, and there it reads the same at either position. The wedge is not a risk to the
design; it is a variable-height wall, which recipe §3's `w = vs / Hs` rule already handles.

**What the row inherits from this decision:** with a centred anchor, the west flank (x−20…−2) sits
on 6.7–11.1 of cut and the east flank (x16…34) runs 12.5 down to 2.3. **The east flank is the
awkward one** — it drops 10 studs across its length, so it likely wants two small shops stepping
down rather than one. Decide that when the row is specced; do not let this building's single floor
level imply the others hold it.

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

**花火屋** on a kanban board under the upper floor, as a `SurfaceGui` `TextLabel`.

**CORRECTED 2026-08-05, during planning.** This section originally said the sign would come through
the glyph SDF pipeline that produced the R/P/S marks. It cannot. `tools/glyphs/glyphgen.cjs` is a
*dependency-free stroked-path rasterizer* — it draws R, P and S as line segments over a signed
distance field and **has no font support at all**. Three kanji of seven to nine strokes each would
have to be hand-authored as stroke coordinates, and then uploaded, and then wait on moderation — the
same pipeline that once had a green maple leaf removed as a false positive.

Roblox renders CJK from its built-in fonts for nothing. The real constraint is the documented one:
**`TextSize` caps at 100px and `TextScaled` is inert**, so large lettering needs a *small canvas* —
which is what `SurfaceGui.PixelsPerStud` controls. At 20 px/stud, 90px text fills the 2.6-stud board.

If the built-in font turns out not to cover these three characters, the fallback is an uploaded PNG.
Check before spending anything on it.

Two chōchin hang under the eave, tagged **`RoundLantern`** so `LanternController` finds them —
discovery is by CollectionService tag, not by name or parent, and not by living under
`RoshamboStage`. They will carry the round result like every other lantern in the canyon, which is a
free tie between the shop and the game.

---

## 4. The threshold

An invisible trigger volume over the shop **interior**: x−1.67…16.26, **z45–52**, y113.1–118, tagged
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
