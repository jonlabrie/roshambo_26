# Roshambo Structure Builder — Design (portable, loadout-driven teahouses)

**Status:** design approved in brainstorm (2026-07-05); pre-planning. This is an *implementation-architecture* spec for one sub-project — the builder engine and its data contracts — not the whole meta-game feature.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** realizes the personal-teahouse pillar of the [meta-game design](2026-07-04-roshambo-metagame-design.md) (portable loadouts materializing on server-assigned pads). Supersedes the never-built parameterized-teahouse design in [2026-06-20-zendojo-canyon-teahouses-design.md](2026-06-20-zendojo-canyon-teahouses-design.md), which coupled the building to its perch. The base prefab is the teahouse we perfected in the 2026-07-05 art-pass session (unified support frame, leveled floor, black rail cap, corrected left-hand mirror, grouped sliding-ready shoji).

## Problem

The meta-game reality is that a **structure is a portable, player-owned loadout** that the server materializes onto whatever empty **pad** it assigns when the player spawns — not a fixed building welded to a cliff perch. Players start as **wanderers/ronin** with no structure and no pad; a "place of operations" is earned, and it climbs a ladder of tiers (entry tent → single-story teahouse → multi-story flex), personalized with **curated catalog components** (shoji prints, tatami, art, flags, colors) — never raw materials, never free-form building.

The 14 teahouses in `Workspace.CanyonTeahouses` are hand-placed on specific perches, with terrain-raycasting stilts and per-site orientation baked in. That entanglement of **structure design** with **pad/site design** is the thing to break. This spec designs the structure side of that split: a builder that turns a loadout into a self-contained building that ends at a **datum plane** and knows nothing about where it lives.

## Decomposition context

The full "teahouse-on-a-pad, for real" feature is five sub-projects, each its own spec → plan → build:

- **A. Portable Structure builder** *(this spec)* — `loadout → Model`, build-time and runtime, Lune-tested.
- **B. Pad system + per-site recipes + registry** — the mount, support strategy (cliff stilts / valley footings), access, dressing, vacant-state visuals; the 14 perches re-expressed as pads.
- **C. Loadout persistence** — Mongo schema + `/api/v1` save/load, keyed by `resolveUser(robloxId)`.
- **D. Runtime assignment + materialization** — server assigns an empty pad on spawn, materializes the loadout, swaps vacant→claimed, releases on leave.
- **E. Customization / catalog / economy UI** — buying and equipping components; extends the `/store` pattern.

The **A↔B contract** (the `mount` descriptor + the datum rule) is co-designed here so the pad system slots in cleanly.

## Goals

- A **pure `spec → Model` builder** for structures, callable at runtime (server-authoritative materialization) and testable headless under Lune.
- A **loadout schema** that is the shared contract across the catalog (E), persistence (C), and this builder.
- A **slot/catalog model** with exactly three component mechanisms (recolor, texture swap, attachment prefab) — small enough to hold in one's head, extensible without engine changes.
- **Handedness as data** (a `MirrorX` tag), retiring the hardcoded negate-X part lists that hid the left-hand shoji/SideWall bug.
- A clean **datum contract**: the structure ends at Y 0; the pad's support begins at Y 0; they meet there.

## Non-goals (deferred to other sub-projects or later increments)

- The pad system, its support/access/dressing, and the pad registry (**B**).
- Loadout persistence and the `/api/v1` surface (**C**).
- Runtime pad assignment, vacant/claimed states, dark-shell / pocket-garden rendering (**B/D**).
- The real catalog, points economy, and equip UI (**E**).
- Additional base styles (tent, multi-story) and additional slots (wall art, roof/chōchin variants) — same machinery, authored later.
- **Composable story-stacking** — v1 delivers the tier ladder as discrete authored prefabs; unbounded procedural height is explicitly out.
- Repairing the legacy in-place teahouses. The 14 in `CanyonTeahouses` **freeze as legacy**; the "upgrade all 14 in place" rollout is abandoned in favor of this builder. T05/T06's left-hand shoji/SideWall bug is left as-is in the saved place — the real fix is the `MirrorX`-tagged prefab.

## Architecture

### Loadout schema

A loadout is a base-style pick plus a map of slot → equipped component id. Base style selects the prefab (the tier ladder); handedness is **not** here — it is a pad input.

```
loadout = {
  baseStyle   = "teahouse-1story",       -- selects ServerStorage.StructurePrefabs.<baseStyle>
  colorScheme = <id>,                    -- palette applied to role-tagged parts
  shoji       = { [bayIndex] = <printId> },  -- per-bay screen print
  tatami      = <id>,                    -- mat variant
  flags       = { {mount=<mountId>, item=<id>}, ... },  -- exterior flags at named mounts
  wallArt     = { {anchor=<anchorId>, item=<id>}, ... },-- interior hangings (fast-follow slot)
}
```

Empty/unknown slots fall back to the base prefab's defaults. Forward-compatible: new slots are new keys the planner ignores until taught.

### Component types (the whole mechanism)

Every catalog item resolves to exactly one of three types:

1. **Recolor** — a palette (`{ timber, wall, roof, cap }`) applied to parts carrying the matching role tag. *(colorScheme)*
2. **Texture swap** — replace a `Decal` / `SurfaceAppearance` / `Texture` on a tagged target surface. *(shoji prints, tatami)*
3. **Attachment prefab** — clone a small prefab and `PivotTo` a named `Attachment` in the base. *(flags, wall art, chōchin)*

A catalog item is plain data: `{ id, type, slot, payload }` where payload is a palette, a texture asset id, or a prefab reference.

### Slot manifest (authored on the base prefab)

The base prefab carries its own manifest so the builder is data-driven:

- **Role tags** on parts for recolor: `Role:timber`, `Role:wall`, `Role:roof`, `Role:cap`.
- **`ShojiBay` tags** with a bay index attribute, marking each swappable screen surface.
- **`Tatami` tag** on the mat surface.
- **`Attachment`s** for mounts: `FlagMount_1`, `FlagMount_2`, `ArtAnchor_*`.
- **`MirrorX` tags** on parts that flip for a left-hand build (engawa assembly, side shoji + glow + mullions, solid SideWall). Symmetric parts stay untagged.
- **Pivot** set to the floor-underside datum center; front (−Z local) = the engawa/veranda side.

`readManifest(prefab) → manifestData` (adapter) extracts this into plain data; the planner consumes only the data.

### Builder pipeline — pure planner + thin applier

Split so the hard logic is unit-tested and the Instance work is a thin adapter (the repo's DI pattern; cf. `CanyonPath` + 228 Lune tests, `GameRules` fixtures).

**`StructurePlanner` (pure, Lune-tested):**
```
plan(loadout, mount, manifestData) -> {
  recolors    = { {tag, color}, ... },
  textures    = { {tag/bay, assetId}, ... },
  attachments = { {attachmentName, prefabRef}, ... },
  mirrorTags  = { "MirrorX" } | {},        -- emitted when mount.hand == "left"
  pivotCF     = <CFrame>,                    -- datum snap to mount.cframe
}
```
Owns: slot resolution for the three types, the handedness decision (mirror the `MirrorX`-tagged parts), and the datum-snap CFrame math. Never touches a live Instance.

**`StructureBuilder` (thin adapter, runtime + Studio):**
```
build(loadout, mount, deps) ->
  m = deps.prefabs[loadout.baseStyle]:Clone()
  manifestData = readManifest(m)
  p = StructurePlanner.plan(loadout, mount, manifestData)
  if #p.mirrorTags > 0 then mirrorTaggedX(m, p.mirrorTags) end
  applyRecolors(m, p.recolors); applyTextures(m, p.textures); applyAttachments(m, p.attachments, deps.componentPrefabs)
  m:PivotTo(p.pivotCF)
  return m
```

### The pad↔structure contract (A↔B seam)

The pad (sub-project B) exposes a **mount descriptor**:
```
mount = {
  cframe    = <CFrame>,   -- position = floor-underside datum point; lookVector = veranda facing
  hand      = "left" | "right",
  footprint = { x, z },   -- pad usable footprint (fit validation)
}
```
The structure guarantees:
- Its pivot = floor-underside center; `Model:PivotTo(mount.cframe)` places *and* orients in one shot.
- **Nothing exists below Y 0.** No stilts, footings, or terrain raycasts — all support is the pad's job, built up to the same Y-0 plane.
- It declares its own footprint so a pad can validate fit before assignment.

The datum plane is the entire interface: structure ends at Y 0, pad support ends at Y 0.

### Prefab home

Base prefabs live in `ServerStorage.StructurePrefabs.*`, sourced from **committed** prefabs (Rojo-managed), not place-only geometry — versioned and runtime-cloneable server-side. Component prefabs (flags, art) live alongside in `ServerStorage.StructureComponents.*`. Materialization clones once per player per spawn — never per-frame; cost is negligible.

## Testing

- **`StructurePlanner`** — Lune unit tests against fixtures (precedent: `shared-fixtures/game-rules.json`, `tests/CanyonPath.spec.luau`): slot resolution for each component type, left- vs right-hand mirror emission, datum-snap CFrame for representative mounts, empty/unknown-slot fallthrough.
- **`StructureBuilder`** — integration-verified in Studio via the demo harness (clone + apply + pivot on a real prefab); not unit-tested.
- **Manifest** — a validation pass asserting the base prefab carries the required tags/attachments/pivot and nothing below Y 0.

## v1 deliverables

1. **Capture `teahouse-1story`** — turn the perfected `TeahousePrototype` into the canonical base prefab: fold in the session's fixes (unified frame **minus the posts**, leveled floor, black cap, grouped sliding-ready shoji); set pivot to the datum; strip everything below Y 0; author the manifest (role tags, `ShojiBay`, `Tatami`, `FlagMount_*`, `MirrorX`); commit to `ServerStorage.StructurePrefabs`.
2. **`StructurePlanner`** — pure module + Lune tests.
3. **`StructureBuilder`** — adapter (clone → readManifest → plan → apply → PivotTo).
4. **Catalog stub** — a handful of component defs exercising all three mechanisms (a couple color schemes, 1–2 shoji prints, 1–2 tatami, 1–2 flags). Not the real economy.
5. **Demo harness** — a Studio script that materializes a sample loadout onto a hand-placed test mount, for the visual gate.

## Build order

Define the manifest data schema → TDD `StructurePlanner` against it → capture the base prefab to match the schema → `StructureBuilder` adapter → catalog stub + demo harness → visual verification gate.

## Open items

- **Sliding shoji interaction** (prompt + tween + multiplayer state) is a separate follow-on; v1 only makes the panels *grouped and slide-ready* in the prefab, not interactive.
- Exact committed-prefab format (`.rbxmx` vs `.model.json`) and the Rojo mount path are a plan-level detail.
- Whether `colorScheme` is a fixed enum of palettes or free per-role colors — v1 assumes a small enum of curated palettes.
