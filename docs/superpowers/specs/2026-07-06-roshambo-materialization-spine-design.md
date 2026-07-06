# Roshambo Materialization Spine — Design (sub-project D, increment 1)

**Status:** design approved in brainstorm (2026-07-06); pre-planning. First increment of sub-project D — runtime materialization. Roblox-side; one Lune-tested module + Studio-only appliers proven by a single visual gate.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** ties together A (`StructureBuilder`/`StructurePlanner`/`StructureCatalog`), B (`PadBuilder`/`PadPlanner` — the registry waits for D.2's lifecycle), and C (`GET /api/v1/players/:id/teahouses`). A + B + C each proved their layer in isolation (A↔B with a throwaway stilt demo, C with Vitest). D.1 proves the layers compose end-to-end: a **persisted loadout becomes a correctly-standing teahouse on a surveyed pad**, statically, before D.2 adds the player lifecycle.

## Problem

Everything to materialize a teahouse exists but has never run as one chain in the real runtime:

- A's `StructureBuilder.build(loadout, mount, catalog, ops)` and B's `PadBuilder.build(padSpec, ops)` are pure orchestrators driven by an injected `ops` adapter — but the **real ops live inline in throwaway demos** (`tools/studio/materializeStructureDemo.luau`, `buildPadDemo.luau`). Memory flags "the committed runtime ops module is sub-project D."
- C.1's `GET /players/:id/teahouses` is live on the server, but `NetworkClient` (`roblox/src/server/NetworkClient.luau`) has **no method to call it** — only `getPlayer`/`postBank`/`getLeaderboards`.
- `PadRegistry` and `VacantState` are pure decision modules; nothing yet applies their output to real Instances or wires them to `main.server.luau`.

D.1 closes the smallest loop that exercises every layer: at server startup, fetch one known player's persisted loadout, build the pad support, materialize the structure on it, and confirm it stands correctly.

## Goals

- A committed, reusable **runtime `ops` adapter** for both builders (`StructureOps`, `PadOps`), productionized from the demo ops.
- A `NetworkClient:getTeahouses(robloxUserId)` method (Lune-tested) calling C.1.
- One **surveyed NearWall pad spec** (`PadSites`) with a canonical stable id.
- Startup wiring in `main.server.luau` that runs the full chain once for a hardcoded owner + pad.
- A single visual gate: a teahouse built from the **persisted, visibly-customized** loadout, standing on pad-built stilts at the surveyed perch, floor-underside flush on the post tops at the datum.

## Non-goals (later D increments)

- **Player lifecycle** — join → `claimVacant` → materialize; leave → `release`. Sub-project **D.2**. D.1 is static: one hardcoded owner, one pad, materialized at startup, never released.
- **Vacant-state applier** (dormant recolor / shoji opaque / chōchin removed from `VacantState.resolve`). **D.2**.
- **Multi-size matching** (generalize `claimVacantFor` to pick the best-fitting owned size). **D.3**.
- **Perch preference** (persisted per-player ordered pad ranking + thumbs UI, honored in assignment). **D.4**.
- **Migration sweep** — surveying/registering the remaining perches and *permanently* retiring legacy teahouses. **D.5** (the Studio grind that consumes this machinery; access track runs alongside).
- **Committing the `teahouse-1story` prefab via Rojo.** Separate open follow-up (memory). D.1 depends on the prefab being present in the *running saved place*; it does not try to solve the Rojo-mount problem.

## Architecture

Same planner/applier split the rest of the sub-projects use. The pure decision math already exists (A/B/C); D.1 adds one testable network method and a set of Studio-only appliers, then composes them in the composition root.

Startup-time flow, fully hardcoded (no lifecycle):

```
getTeahouses(TEST_OWNER)  ──► loadout ─────────────────────┐
                                                           ├─► StructureBuilder.build(loadout, mount, catalog, StructureOps) ─► model ─► Workspace (Persistent)
PadSites["nearwall-1"] ──► PadBuilder.build(padSpec, PadOps) ──► mount ─┘
```

### Component 1 — `NetworkClient:getTeahouses(robloxUserId)` *(Lune-tested)*

New method mirroring `getPlayer`: `GET {baseUrl}/api/v1/players/{robloxUserId}/teahouses`, `X-API-Key` header, injected `request`/`jsonDecode`. Returns `{ ok = true, data = { teahouses = {...} } }` on 200, `{ ok = false, status/error }` otherwise. This is the only new pure logic in D.1 and the only unit-tested piece.

### Component 2 — `StructureOps.luau` *(Studio-only, no Lune)*

The six real ops **productionized from `materializeStructureDemo`** (reuse, do not re-derive), matching `StructureBuilder.Ops`:

- `clonePrefab(baseStyle)` → `ServerStorage.StructurePrefabs[baseStyle]:Clone()`
- `readManifest(model)` → reads CollectionService tags / attributes (`Role_timber/wall/roof/cap`, `MirrorX`, `MirrorXRigid`, `ShojiBay`+`Bay`, `Tatami`, `FlagMount_1/2`) into the `StructurePlanner.Manifest` shape
- `mirrorX(model)` → reflect `MirrorX`-tagged parts, rigid-relocate `MirrorXRigid` models (the chōchin-swing handedness fix)
- `recolor(model, role, color)` → set `Color` on parts tagged `Role_<role>`
- `setTexture(model, target, assetId)` → set the shoji/tatami texture (placeholder asset ids until real prints exist — will not render, expected)
- `attachPrefab(model, mount, prefabId)` → clone a component prefab to the named anchor
- `pivotTo(model, cf12)` → 12-number array → `CFrame` → `model:PivotTo(...)`

### Component 3 — `PadOps.luau` *(Studio-only)*

Productionized from `buildPadDemo`, matching `PadBuilder.Ops`:

- `raycastGround(x, z)` → downward raycast to terrain, return hit Y (or `nil`)
- `buildPost(pos, height)` → spawn the black wood post part (`45,48,56` Wood, 1.2 studs square) matching the stripped `EngawaPost`

### Component 4 — `PadSites.luau` *(baked data)*

One surveyed NearWall perch:

```
{
  id = "nearwall-1",          -- canonical, stable across all server instances
  mountCF = { … 12 numbers }, -- pos = floor-underside datum, look = veranda facing
  hand = "right" | "left",    -- pad input, not a loadout field
  footprint = { … },          -- the { -x, x, -z, w }-style rect PadPlanner/PadRegistry consume
  vacantForm = "dormant-structure",
}
```

Survey method: read the chosen perch's floor-underside datum + facing from its existing legacy teahouse — probe `Deck`/`EngawaF`/`Table` for the real floor level (per the floor-vs-pivot rule), **not** the dragged-down pivot/bbox. Footprint from the `teahouse-1story` prefab.

### Component 5 — Wiring in `main.server.luau`

At startup, after the existing composition: require `StructureBuilder`, `PadBuilder`, `StructureCatalog`, `StructureOps`, `PadOps`, `PadSites`; run the flow above once for `TEST_OWNER`; parent the model to Workspace and set `ModelStreamingMode = Persistent` (StreamingEnabled — same treatment as `RoshamboStage`, so client controllers/viewers see it far from spawn). **`PadRegistry` is deliberately not used here** — the single pad is baked and materialized directly; the registry (register / `claimVacant` / `release`) lands in D.2 with the player lifecycle.

## Dependencies & staging (flagged, not hidden)

- **Seeded loadout in Mongo** for `TEST_OWNER`: seed once via `PUT /api/v1/players/{TEST_OWNER}/teahouses/M { loadout }` with a **visibly customized** loadout (non-default `colorScheme` + a `shoji` entry) so the gate proves the customization path, not just "a teahouse appears."
- **`teahouse-1story` prefab present in the running saved place** (PLACE-ONLY; Rojo-commit is a separate follow-up).
- **Legacy-perch staging:** archive the chosen NearWall perch's legacy teahouse to `ServerStorage` (reversible) so the materialized structure stands in a clean, apples-to-apples spot for the gate.

## Testing / gate

- **Lune:** `getTeahouses` spec added to the existing `NetworkClient` suite — 200 → `{ ok = true, data }`; non-200 → `{ ok = false, status }`; decode failure handled. No other new pure logic.
- **Visual gate (user):** one attempt, then stop. Pass criteria — teahouse built from the persisted loadout with the customization visibly applied; correct handedness; standing on 6 pad-built posts down to terrain; floor-underside flush on the post tops at the datum; veranda facing correct.

## v1 deliverables

1. `NetworkClient:getTeahouses` + its spec (`roblox/src/server/NetworkClient.luau`, `tests/NetworkClient.spec.luau`).
2. `roblox/src/server/StructureOps.luau` (productionized from `materializeStructureDemo`).
3. `roblox/src/server/PadOps.luau` (productionized from `buildPadDemo`).
4. `roblox/src/server/PadSites.luau` (one surveyed NearWall perch).
5. Startup wiring in `roblox/src/server/main.server.luau`.
6. Seeded `TEST_OWNER` loadout (one-off `PUT`, documented in the plan).

## Build order

Add `NetworkClient:getTeahouses` (TDD, Lune) → productionize `StructureOps` + `PadOps` (Studio) → survey the perch → bake `PadSites` → seed the loadout → wire `main.server.luau` → run the visual gate → stop for user review.
