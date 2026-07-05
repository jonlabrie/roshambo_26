# Roshambo Vacant-State Resolver — Design (pad occupancy → structure visual)

**Status:** design approved in brainstorm (2026-07-05); pre-planning. A B increment — the visual expression of pad occupancy. Pure resolver + one Studio visual gate.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** reads the occupancy state from [`PadRegistry`](2026-07-05-roshambo-pad-registry-design.md) (B increment 2) and reuses the recolor mechanism of the [structure builder](2026-07-05-roshambo-structure-builder-design.md) (A). Realizes the [meta-game](2026-07-04-roshambo-metagame-design.md) rule "cliff perches vacant = dark base-form teahouse; shoji glow = the occupancy signal; claiming swaps the dark shell for the owner's tier."

## Problem

Occupancy is signalled *visually*, and the **vacant** form depends on the pad's class:
- **Cliff-perch** pad vacant → a dark, dormant base-form teahouse with unlit shoji (the vista stays built; the dark shell + unlit shoji is the "empty" signal).
- **Valley-floor** pad vacant → a pocket garden / locally-accurate flora that *masks* the pad's existence (no structure), persisting as the yard.

**Claiming** any pad swaps to the owner's loadout with lit shoji. This increment is the pure mapping from occupancy + pad class → the visual treatment, plus a visual confirmation of the cliff (dormant-structure) form. The valley garden **applier** is out of scope, but the resolver is shaped so it slots in without rework.

## Goals

- A pure `VacantState.resolve` that maps a pad's occupancy + class (+ the owner's loadout, if any) to a **discriminated treatment** (`structure` or `garden`) so cliff and valley vacant forms both fit one seam.
- The dormant cliff shell expressed through A's **existing recolor mechanism** (a new `scheme.dormant` catalog entry) — no new customization mechanism.
- Lune-tested; one Studio visual gate for the cliff (dormant-structure) form.

## Non-goals (later)

- The valley pocket-garden **applier / builder** (the resolver returns a `garden` marker; rendering it is a later increment, once valley pads exist).
- Gate chōchin unlit/lit + noren claim signaling.
- Wiring to real spawns / the live registry (sub-project D threads `PadRegistry` → `VacantState` → `StructureBuilder`).
- Animated claim transitions.

## Architecture

### `scheme.dormant` (StructureCatalog addition)

A new `recolor` entry, dark and desaturated across every role so the whole shell reads dormant:

```
["scheme.dormant"] = { id="scheme.dormant", type="recolor", slot="colorScheme",
  payload = { timber = {48,46,44}, wall = {70,68,64}, roof = {36,37,40}, cap = {40,42,46} } }
```

This reuses A's recolor machinery verbatim — the dark shell is just a colorScheme the builder already knows how to apply.

### `VacantState.resolve` (pure, Lune-tested)

```
VacantState.resolve(occupant: string?, ownerLoadout: Loadout?, vacantForm: string?) -> Treatment
  Treatment = { kind = "structure", loadout: Loadout, lit: boolean }
            | { kind = "garden" }
```

`vacantForm` is the pad's vacant class — `"dormant-structure"` (cliff, the default when omitted) or `"pocket-garden"` (valley). It comes from the `PadSpec` (a small field the pad carries; the resolver takes it as a **parameter**, staying decoupled from `PadRegistry` — D threads occupant + loadout + vacantForm together).

- **Claimed** (`occupant ~= nil`, `ownerLoadout` present) — regardless of pad class: `{ kind = "structure", loadout = ownerLoadout, lit = true }`. A claimed pad shows the owner's structure.
- **Claimed without a loadout** (`occupant ~= nil`, `ownerLoadout == nil`, defensive): `{ kind = "structure", loadout = DORMANT_LOADOUT, lit = true }` — dormant shell but *lit*, so a mis-wired claim is visible rather than crashing.
- **Vacant + `vacantForm == "dormant-structure"`** (or omitted): `{ kind = "structure", loadout = DORMANT_LOADOUT, lit = false }` — dark base form, shoji unlit.
- **Vacant + `vacantForm == "pocket-garden"`**: `{ kind = "garden" }` — the valley mask; **v1 returns the marker only**, the garden applier is deferred.

`DORMANT_LOADOUT = { baseStyle = "teahouse-1story", colorScheme = "scheme.dormant" }` (module constant; the base tier a dormant cliff pad shows). `lit` is a pad-occupancy **state** signal driving the `ShojiGlow` parts — deliberately separate from the three catalog mechanisms (not a purchasable slot).

Callers discriminate on `kind`: `"structure"` → build via `StructureBuilder` with `loadout` and light per `lit`; `"garden"` → render the valley mask (deferred).

### Applier (Studio gate only, this increment)

For a `kind="structure"` treatment, build via A's builder for `treatment.loadout`, then apply the **dormant treatment keyed off `treatment.lit`**:
- `lit = true` (claimed): `ShojiGlow` visible (translucent, ~0.6), chōchin kept — the inhabited look.
- `lit = false` (vacant): the full "shut up" look — `ShojiGlow` off (transparency 1), the `Shoji` panels set **opaque** (transparency 0, closed), and the **`ChochinSwing` removed** (no lantern hung; the owner hangs their own on claiming). Combined with the dark `scheme.dormant` recolor, this reads as a dark shuttered shell.

So `resolve` stays `{loadout, lit}` — the extra vacant deltas (opaque shoji, glow off, chōchin removed) live in the **applier**, not the resolver. This increment's gate only exercises `"structure"` (cliff); a `"garden"` applier is deferred. A committed `ops` module is D's concern; here it lives in the visual-gate script (MCP can't `require` repo modules — same mirror pattern as A/B demos).

## Testing

- **`VacantState`** — Lune unit tests: vacant cliff (`dormant-structure` / omitted) → `{kind="structure", DORMANT_LOADOUT, lit=false}`; claimed-with-loadout → `{kind="structure", ownerLoadout, lit=true}`; claimed-without-loadout → `{kind="structure", DORMANT_LOADOUT, lit=true}`; vacant valley (`pocket-garden`) → `{kind="garden"}`.
- **`StructureCatalog`** — assert `scheme.dormant` resolves to a recolor entry with all four role colors.
- **Visual gate** — Studio: materialize a vacant structure (dormant, shoji unlit) beside a claimed one (owner colors, shoji lit), the two states resolved from a `PadRegistry`; confirm the dormant shell reads as empty; stop for the user.

## v1 deliverables

1. `scheme.dormant` added to `roblox/src/shared/StructureCatalog.luau` (+ a catalog test).
2. `roblox/src/shared/VacantState.luau` + `roblox/tests/VacantState.spec.luau`.
3. A Studio visual-gate script (`roblox/tools/studio/vacantStateDemo.luau`) — vacant vs claimed, read from a registry.

## Build order

Add `scheme.dormant` + its test → TDD `VacantState.resolve` (all four cases: vacant cliff, claimed, claimed-no-loadout, vacant valley→garden) → Studio visual gate (cliff vacant vs claimed) → stop for the user.
