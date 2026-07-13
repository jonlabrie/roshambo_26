# Modular Teahouse Foundation (SP1) — Design Spec

**Date:** 2026-07-12
**Status:** Design — for user review before planning.
**Sub-project:** SP1 of the teahouse access/flexibility stack (see "Decomposition"). Builds on the
completed Piece A (pad/deck separation). Feeds SP2 (access model) and SP3 (M/L program), and is
architected so a later **Piece B** (player customization) reuses its data model unchanged.

## Problem

Placement tuning is blocked on an undefined access model. Canyon access varies widely — rear
tunnels (most), side-exit tunnels, and a pad or two with no tunnel — with **no left/right
convention**. The old model fused four separable concerns (access touchpoint, pad apron, building
orientation, building openness) and encoded handedness as a whole-building **mirror**, which does
not generalize.

Two design decisions resolve it:
- **The building faces the view, not its access** (the pads were already surveyed veranda-to-view,
  so the building inherits the view with no per-pad rotation).
- **Access goes *through* the building, not around it** — a door-sized opening in the wall the
  access arrives at, so the building can hug that edge (no wasted setback) and the entire front
  deck is freed for the veranda + features (e.g. a hydroponic garden). Forward space is at a
  premium on these perches; an enforced rear/side walkway wastes it.

Realizing the door cleanly, and doing it in a way that also fixes the "an L teahouse is just a
magnified S" problem, requires making the building **modular**. That modular foundation is SP1.

## Decomposition (the stack)

Bottom-up, each piece independently shippable:

1. **SP1 — Modular teahouse foundation (this spec).** The fixed spatial module; all four walls as
   bays with a `solid | shoji | door` state map; the door capability; retiring the whole-building
   mirror. Re-authors the **S** building on the grid and defines the data model B will drive.
2. **SP2 — Access model.** The per-pad `{edge, position}` access variable → derived placement (hug
   the access edge) + door-bay selection + a setback-aware fit-check. Unblocks placement tuning
   (the original goal). Consumes SP1's door.
3. **SP3 — M/L authored program.** Hand-designed M and L floorplans (more bays + tokonoma / genkan
   / tea-nook), fixed module & height — retires the `ScaleTo` size proxy for the building.

`SP1 → SP2` is the critical path; `SP3` is a parallel quality track. Full player customization is
the eventual **Piece B**; SP1's data model is built to accept it.

## Architecture principle: building-as-data on a fixed module

The single most important decision, cheap to honor now: **the building is described as data over a
fixed module, and authored (A) prefabs are compositions of a shared parts vocabulary.** In A the
prefab *ships* a default configuration; in B the player edits that same configuration. Same
representation, different author — so B is not a rewrite.

- **Bay states are data**, not baked geometry: a per-wall, per-bay map (`solid | shoji | door`).
- **Interior program is a vocabulary of discrete, grid-snapped pieces** (tatami mat, tokonoma,
  genkan, tea-nook) — hand-placed in A, player-placed in B. SP1 defines the mat module; the
  richer fixtures land with SP3/B.

## The module (grounded in the current S prefab)

Measured from `ServerStorage.StructurePrefabs.teahouse-1story`:

- **Bay pitch = 6 studs.** Divides the 18-stud front into **3 bays** and the 12-stud sides into
  **2 bays** (GCD(18,12)=6). A shoji panel is ~3.7 wide within its bay, framed by mullions
  (existing pattern: `Mull` parts + `Shoji`/`ShojiBay` tags).
- **Height is FIXED and never scales** — wall 10, corner post 11, shoji 8.5 studs. This is
  avatar-relative, exactly like the deck railings (the precedent set in Piece A). An L teahouse is
  wider/deeper (more modules), **not taller**.
- **Tatami is a counted mat module, not a single stretched mat.** Today's floor is one 17×11 mat;
  it becomes a standard ~1:2 mat unit laid in a standard pattern (mat count scales with size — the
  Japanese room-sizing convention). SP1 defines the mat unit and re-lays the S floor with it.

The module is the shared primitive for SP1 (bays), SP3 (M/L = more modules), and B.

## Bay system

The building frame is **corner posts + intermediate mullions**; the wall between each adjacent pair
is a **bay** in one of three states:

- **solid** — an opaque wall panel.
- **shoji** — the translucent sliding screen (openable/lit; today's front panels).
- **door** — a passable opening: a framed threshold, no collision, optional noren curtain. Occupies
  a bay slot like any other state. The door bay is *forced by the access model (SP2)*; every other
  bay is the owner's aesthetic choice.

**Grid (S):** front 3, back 3, each side 2 = **10 bays**. SP1 extends the front's existing bay
system to the back and both sides, and **regularizes** the current non-uniform side (3 panels at
~4-stud pitch) to 2 clean 6-stud bays.

**Default S configuration (A):** shoji on the **front** (view side), solid elsewhere — matching
today's read, minus the whole-building mirror. Access (SP2) later flips one bay to a door.

## Data model

A building's walls are a **bay-state map** carried by the loadout, keyed by building-local side
(front = the view/veranda side, then back/left/right — orientation is fixed to the pad's
view-facing mount):

```
wallBays = {
  front = { "shoji", "shoji", "shoji" },   -- 3 bays
  back  = { "solid", "solid", "solid" },    -- 3 bays
  left  = { "solid", "solid" },             -- 2 bays
  right = { "solid", "solid" },             -- 2 bays
}
```

- The loadout schema gains `wallBays` (optional; a default map is applied when absent).
- Bay indices run in a fixed, documented order per side (e.g. left-to-right as seen from outside).
- **`wallBays` (state) is orthogonal to the existing `loadout.shoji` (texture) map:** a bay's state
  says solid/shoji/door; a bay in the `shoji` state then takes its screen texture from
  `loadout.shoji[side][index]` (extending today's front-only `shoji` map to all sides). Door and
  solid bays ignore texture.
- Validation: each side's array length must match the size's grid (S = 3/3/2/2); each entry is one
  of the three states. Invalid maps fall back to the default (non-fatal).

This map is what SP2 writes a `door` into (at the access bay) and what Piece B lets a player edit.

## Retiring the mirror

The whole-building `mirror` / `openSide`-as-shoji-selector is removed:

- `StructurePlanner`: drop `openSide`; add the `wallBays` resolution (which bays to render in which
  state). `StructureBuilder`: drop the `ops.mirrorX(model)` call; apply bay states instead.
- `StructureOps`: `mirrorX` retired (no longer used by the building — confirm no other consumer).
  Bay-state application replaces it (show/hide/swap the panel per bay; toggle door collision).
- `captureTeahouseBase.luau`: tag **every** bay on **all four walls** with its side + index (not
  just the front `ShojiBay`), so the runtime can address any bay. `MirrorX`/`MirrorXRigid` tags are
  dropped for the building; the chochin is positioned directly.
- `Placement.openSide` is retired from its shoji-selection role. Placement keeps `offset`/`facing`
  for positioning; the *door side* comes from SP2's access variable, not `openSide`.

Because the walls are symmetric and addressable, "which side is open" is just the map — no flipping.

## Code vs. art split

- **Geometry (Studio, mostly script-drivable via `execute_luau`, visual-gated):** split `BackWall`
  and both `SideWall`s into 6-stud bay panels + mullions (the current walls are simple boxes, so
  this is scriptable like the Piece-A pad geometry); author the three bay-state pieces (solid /
  shoji / door) as swappable within a bay slot; author the door piece (framed threshold + optional
  noren, no collision); re-lay the tatami as counted mats. Then re-capture the prefab.
- **Pure/Lune-tested code:** the `wallBays` schema + validation + default-fill; the bay-state
  resolution in `StructurePlanner` (map → per-bay render decisions). No Roblox datatypes.
- **Roblox adapter (visual-gated):** `StructureOps` bay-state application (render solid/shoji/door,
  toggle door collision) replacing `mirrorX`.

## Error handling

- Invalid/mismatched `wallBays` → warn + fall back to the size's default map (never blank the
  building), consistent with the applier's F2/F4 degradation contract.
- A missing bay part in the prefab (author error) → warn for that bay, render the rest.

## Testing

- **Pure (Lune):** `wallBays` validation (length per side, valid states), default-fill when absent,
  and `StructurePlanner`'s map→render resolution. TDD, failing test first.
- **Visual gate (Studio Play/Edit):** the re-authored S building renders all four walls as bays;
  a `door` bay is passable (walk through) and reads as an intentional opening; shoji still open/lit
  and texture correctly; the left/right symmetry works from the map with no mirror; the chochin
  sits correctly. Regression: existing shoji-bay texturing + tatami texturing still apply.

## Scope boundaries

**In SP1:** the module definition; the S building re-authored with all-4-walls bays + door
capability; the `wallBays` data model + validation + default; retiring the whole-building mirror;
the tatami mat module (S floor re-laid). **S size only.**

**Not in SP1:**
- **SP2** — deriving placement + the door bay from the access variable; the setback-aware fit-check.
  SP1 provides the *capability* (a door bay can exist anywhere) but does not choose where.
- **SP3** — M and L authored floorplans/program; retiring `ScaleTo`. SP1 fixes the module they use.
- **Piece B** — the player-facing customization UI/economy. SP1 provides the data model it edits.
- Richer interior fixtures (tokonoma, genkan, tea-nook) beyond the tatami mat — land with SP3/B.

## Deferred / open follow-ups

- Noren curtain art on door bays (cosmetic; a plain framed opening is acceptable for SP1).
- EngawaBarrier fall-collision → move to the pad (tracked from Piece A; touches the deck, not SP1).
- Flag-mount tag/attachment mismatch (tracked from Piece A; independent).
