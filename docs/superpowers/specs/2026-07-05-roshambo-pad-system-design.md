# Roshambo Pad System — Design (cliff-perch pads + the A↔B proof)

**Status:** design approved in brainstorm (2026-07-05); pre-planning. Implementation-architecture spec for the **first increment** of sub-project B — the cliff-perch pad builder and the structure↔pad integration. Not the whole pad system.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** the pad half of the datum contract co-designed in the [structure-builder spec](2026-07-05-roshambo-structure-builder-design.md) (sub-project A, built 2026-07-05). A produced a portable structure that ends at the datum plane (frame underside) and declares a footprint; B produces the support that rises to that plane and hands back the `mount` A consumes. This increment closes the loop A's demo left open — the structure floated in mid-air because nothing held it up.

## Problem

A structure is a portable loadout that materializes at the datum plane (Y0 = its frame underside) and knows nothing about where it lives. Something has to **hold it up at a specific site** — and that something differs per site (cliff stilts vs. valley footings) and must not leak back into the structure. That is the pad. Sub-project A deliberately stripped the 6 terrain-raycasting `EngawaPost` from the teahouse; this spec builds them back on the **pad** side, decoupled, so a structure can stand on pad-built support at a real cliff.

## Decomposition context

Sub-project B (from the [meta-game](2026-07-04-roshambo-metagame-design.md) / structure-builder specs) is itself several increments: the pad builder, per-site support strategies (cliff / valley), access, dressing, vacant-state visuals, a per-server registry, and re-expressing the 14 legacy perches as pads. **This spec is only the first:** the cliff-perch pad builder + the A↔B integration proof. It stands alone as working, demonstrable software.

## Goals

- A **pure `PadPlanner`** (Lune-tested) that turns a footprint + a datum-plane placement + an injected ground-height function into a set of support-post specs.
- A **`PadBuilder`** (Studio/runtime) that supplies the real terrain raycast, builds the posts, and returns the **`mount`** that A's `StructureBuilder` consumes.
- A **demonstrated A↔B seam:** a `teahouse-1story` structure standing on pad-built stilts at a real cliff, structure frame and post tops meeting exactly at the datum.
- The pad stays **decoupled** from the structure — it receives a footprint as data, never reads a live structure.

## Non-goals (later B increments or other sub-projects)

- Valley-floor footings (a second support strategy).
- Access (bridges / stairs / paths) and terrain dressing (pad-cut, retaining walls, hanging gardens).
- Vacant-state visuals (dark base shell / pocket garden) and the claim swap — needs the runtime.
- The per-server **pad registry** and occupancy — more naturally sub-project D's runtime.
- Runtime pad **assignment** / materialization on spawn (sub-project D).
- Re-expressing the 14 legacy in-place teahouses as pads (a migration increment).

## Architecture

Mirrors A's planner/applier split (repo DI pattern; cf. `CanyonPath` + Lune tests, and A's `StructurePlanner`/`StructureBuilder`).

### PadSpec

The data that defines a pad. For v1, one **baked** cliff site (surveyed coordinates committed into the builder, per the canyon recipe rule — never depend on draft markers).

```
PadSpec = {
  mountCF   = <CFrame, 12-number array>,  -- datum-plane placement: position = where the
                                          --   structure's floor-underside centre goes;
                                          --   lookVector = veranda facing (out toward the view)
  hand      = "left" | "right",           -- which side the cliff is on (passed through to the mount)
  footprint = { minX, maxX, minZ, maxZ }, -- the structure frame rectangle the posts stand under,
                                          --   in the mount's local frame (flows structure -> pad as data)
}
```

`footprint` is read once from the `teahouse-1story` prefab's frame (the `Perim*` extents) and baked for the proof; at runtime sub-project D passes the assigned structure's footprint. The pad never reads a live structure — it is built *before* one lands.

### PadPlanner (pure, Lune-tested)

```
PadPlanner.planSupport(footprint, mountCF, groundAt) -> {
  posts   = { { pos = {x,y,z}, height = number }, ... },  -- world-space post specs
  omitted = { "corner-FL", ... },                          -- posts with no ground within reach
}
```

- **Post positions:** the footprint's 4 corners + the 2 long-side mids (6 load points, matching the stripped `EngawaPost`), each transformed by `mountCF` into world space. Each post is 1.2 sq with its **outer corner flush** to the footprint corner (post centre = corner pulled inward by half the post width).
- **Post height:** from the datum plane (`mountCF` Y at that x/z) **down to** `groundAt(x, z)`, embedded ~1 stud into terrain — the sizing the old upgrade used (`Size.Y = datumY - (groundY - 1)`).
- **`groundAt(x, z) -> number?`** is **injected** — a fake in Lune tests (flat / sloped / nil), a terrain raycast at runtime. When it returns `nil` (the veranda cantilevers past the cliff edge), that post is **omitted** and named in `omitted` rather than dangling a stub — the cantilever floats, as kake-zukuri verandas do.

No Roblox datatypes; CFrames are 12-number arrays (`Spec.cframe` convention).

### PadBuilder (Studio / runtime applier)

```
PadBuilder.build(padSpec, ops) -> mount
```

- Supplies the real `groundAt` via `ops.raycastGround(x, z)` (cast down `workspace.Terrain`).
- Calls `PadPlanner.planSupport(...)`, then `ops.buildPost(pos, height)` for each post (Part, 1.2 sq, black ink `Color3.fromRGB(45,48,56)`, `Wood`, `Anchored`, `CanCollide=false`, `CastShadow=false` — matching the stripped `EngawaPost`).
- Returns `mount = { cframe = padSpec.mountCF, hand = padSpec.hand, footprint = padSpec.footprint }` for A's `StructureBuilder`.

The injected `ops` keeps the orchestration testable (fake ops record calls; the real ops raycasts and builds), consistent with A's `StructureBuilder`.

### The A↔B seam

`PadBuilder.build` returns a `mount`; `StructureBuilder.build(loadout, mount, catalog, ops)` clones/mirrors/fills the structure and `PivotTo`s it to `mount.cframe`. Because the prefab's pivot is the frame underside and the posts top out at the same datum Y, the structure's frame lands exactly on the post tops — no gap, no overlap. The pad's posts stand under the frame corners the structure declared.

## Testing

- **`PadPlanner`** — Lune unit tests (precedent: `StructurePlanner.spec`, `CanyonPath.spec`): post positions at the footprint corners + mids for a representative `mountCF`; heights against a flat `groundAt` and a sloped one; flush placement (outer corner on the footprint corner); and the over-void case (`groundAt` returns `nil` → post omitted and named).
- **`PadBuilder`** — a Lune test with a fake `ops` (records `raycastGround` calls + `buildPost` specs, returns the mount), asserting orchestration and the returned mount shape.
- **The integration** — the Studio visual gate: build the pad at the baked site, materialize a `teahouse-1story` on the returned mount, screenshot, verify the frame meets the posts at the datum, stop for the user.

## v1 deliverables

1. **`PadPlanner`** — pure module + Lune tests.
2. **`PadBuilder`** — ops-driven applier + Lune test (fake ops).
3. **A baked `PadSpec`** for one real cliff site (surveyed `mountCF` + `hand` + the `teahouse-1story` footprint read from the prefab).
4. **The integration demo** — a Studio script that builds the pad and mounts a structure on it, for the visual gate.

## Build order

Define the `PadSpec` / plan shapes → TDD `PadPlanner` (post layout, heights, flush, over-void) → TDD `PadBuilder` (fake-ops orchestration) → survey + bake the one cliff `PadSpec` → integration demo + visual gate.

## Open items

- **Real terrain `ops`** (the runtime `raycastGround` + `buildPost`) live in a committed module that sub-project D wires; for v1 the integration demo may inline them (MCP Studio scripts can't `require` repo modules — same constraint and mirror pattern as A's demo).
- **Over-void posts** are omitted in v1; whether tall visual stilts or diagonal bracing are wanted for deep cantilevers is a later cliff-support increment.
- **Footprint source of truth:** read from the `teahouse-1story` prefab's `Perim*` extents for the proof; when tiers arrive, each structure declares its own footprint (already the contract — it flows as data).
