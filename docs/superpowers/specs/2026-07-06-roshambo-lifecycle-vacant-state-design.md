# Roshambo Lifecycle + Vacant State — Design (sub-project D, increment 2)

**Status:** design approved in brainstorm (2026-07-06); pre-planning. Second increment of sub-project D — runtime materialization. Roblox-side; one Lune-tested pure module + a Studio-only applier proven by a two-pad visual gate.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** D.1 (`c8d53d3..5d9433b`) proved the toolchain statically — one hardcoded owner materialized on one pad at startup, no player lifecycle. D.2 makes materialization **player-driven and reversible**: a joining teahouse-owner claims a vacant pad from the per-server pool and their loadout materializes (lit); when they leave, the pad releases and reverts to the **dormant** vacant treatment. It wires `PadRegistry` (B.2) and `VacantState` (B.3) — pure modules with no runtime consumer until now — to `PlayerAdded`/`PlayerRemoving`, and adds the `VacantState` applier.

## Problem

D.1 hardcoded `TEST_OWNER` and materialized unconditionally at startup. The real model is an **ephemeral pool** ([[roshambo-structure-builder]]): perches are a shared per-server resource; a player who *owns* a teahouse claims a vacant perch on join, their persisted loadout materializes there for the session, and it releases when they leave (wanderers who own nothing get no perch). Two pure modules already exist for this but nothing drives them:

- `PadRegistry` (`src/shared`) — per-server occupancy (`claimVacant`/`release`/`get`), never instantiated at runtime.
- `VacantState.resolve(occupant, ownerLoadout, vacantForm) → Treatment` (`src/shared`) — maps occupancy to a treatment (`{kind="structure", loadout, lit}` | `{kind="garden"}`), with no applier.

D.2 supplies the orchestration brain that drives them from player lifecycle, plus the Studio applier that turns a `Treatment` into Instances, and reconciles two review items D.1 deferred (F2 type seam, F4 failure cleanup).

## Goals

- A pure, Lune-tested **`SiteCoordinator`** turning join/leave/startup into `Action`s by composing `PadRegistry` + `VacantState`.
- A Studio-only **`TreatmentApplier`** that builds pad support once and (re)builds the structure per `Treatment`, applying the **dormant** extras when not lit.
- Lifecycle wiring in `main.server.luau` replacing D.1's static block: two pads registered, both dormant at startup; a joining owner claims one (lit); leaving releases (dormant).
- A **second surveyed pad** so the gate shows vacant + claimed side by side.
- Reconcile **F2** (the `Mount`/footprint type seam) and **F4** (clean up a pad's folder if its build fails).

## Non-goals (later D increments)

- **Multi-size fit matching** — `SiteCoordinator` uses `claimVacant` (first-vacant), not `claimVacantFor`. Size-class → footprint defs and best-fit selection are **D.3**.
- **Perch preference** — persisted ordered ranking + thumbs UI. **D.4**.
- **The garden vacant-form applier** — `VacantState` can return `{kind="garden"}` for valley pads; D.2's pads are both cliff (`dormant-structure`), so the applier handles `structure` only and leaves `garden` a deferred no-op (as `VacantState` already flags). **D.5**.
- **Real perch survey + legacy migration.** **D.5** (both D.2 pads reuse terrain-backed cliff shelves).
- **Release-on-leave in the visual gate** — solo Studio Play tears everything down on leave, so release is proven by the `SiteCoordinator` unit test, not the gate.

## Architecture

Same pure-brain / Studio-applier split as A/B/D.1. The pad **support** (stilts) is built once per pad at startup; only the **structure model** is destroyed and rebuilt on a vacant↔claimed transition (simpler than in-place re-skin, and it handles a claimed loadout whose `baseStyle` differs from the dormant base). One `Action` shape — `{padId, spec, treatment}` — covers startup-vacant, join-claim, and leave-revacate; the applier does the same thing for all three (rebuild the pad's `Structure` child from the treatment).

```
startup:  register cliff-proof, cliff-proof-2  →  buildSupport ×2  →  apply(dormant) ×2      [both dark, shuttered]
join:     getTeahouses(you) → onJoin → claimVacant(cliff-proof) → apply(lit owner loadout)   [pad A vermilion, glowing]
leave:    onLeave → release(padId) → apply(dormant)                                           [Lune-tested]
```

### Component 1 — `SiteCoordinator.luau` *(src/shared, pure, Lune-tested)*

Stateful object composing an injected `PadRegistry` + a `{[playerId]: padId}` hold map. No Roblox datatypes.

```
type Action = { padId: string, spec: any, treatment: VacantState.Treatment }

SiteCoordinator.new(registry) -> SiteCoordinator

:onJoin(playerId: string, ownedLoadout: any?) -> Action?
   -- ownedLoadout == nil (wanderer)            -> nil
   -- registry:claimVacant(playerId) == nil     -> nil   (owner, but pool full this server)
   -- claimed {id, spec}                         -> record hold; treatment = VacantState.resolve(playerId, ownedLoadout, spec.vacantForm)  (lit); return {id, spec, treatment}

:onLeave(playerId: string) -> Action?
   -- not holding a pad -> nil
   -- else registry:release(padId); clear hold; spec = registry:get(padId).spec;
   --      treatment = VacantState.resolve(nil, nil, spec.vacantForm)  (dormant); return {padId, spec, treatment}

:vacantActions() -> { Action }
   -- for every registered pad (all unclaimed at startup): {padId, spec, treatment = VacantState.resolve(nil, nil, spec.vacantForm)}  (dormant)
```

`onJoin` uses `claimVacant` (single-size); `spec` is the opaque `PadSpec` carried through to the applier so it needs no registry access.

### Component 2 — `TreatmentApplier.luau` *(src/server, Studio-only, no Lune)*

Injected with the workspace container + the builders/catalog/ops. Owns the mapping `padId → siteFolder`.

- `:buildSupport(spec)` — startup, once per pad: create `MaterializedSite_<id>` folder, `PadBuilder.build(spec, PadOps.new(CFrame.new(unpack(spec.mountCF)), folder))`; the 6 posts persist for the pad's life.
- `:apply(padId, spec, treatment)` — destroy the folder's existing `Structure` child if any; if `treatment.kind == "structure"`: derive `mount = { cframe = spec.mountCF, hand = spec.hand, footprint = spec.footprint }`, `model = StructureBuilder.build(treatment.loadout, mount, catalog, StructureOps)`, name it `Structure`, and **if not `treatment.lit`** apply the dormant shutter; parent to the folder, `ModelStreamingMode = Persistent`. If `treatment.kind == "garden"`: no-op (deferred to D.5). **Wrap the build in `pcall`; on failure `warn` and destroy the folder's partial `Structure` (F4).**
- **Dormant shutter** (keyed off `lit`, per the [[roshambo-structure-builder]] rule): parts named `Shoji` → `Transparency = 0` (opaque/closed); parts named `ShojiGlow` → hidden (`Transparency = 1`) and any child `PointLight` disabled; a `ChochinSwing` model → destroyed. Lit structures keep glow + chōchin as built (the dormant recolor itself comes from `scheme.dormant` already baked into `VacantState.dormant()`'s loadout, applied by `StructureBuilder`).

### Component 3 — `PadSites.luau` *(add a second entry)*

Add `["cliff-proof-2"]` — a second terrain-backed shelf spot surveyed via MCP (verify all/most of its 6 posts hit `workspace.Terrain`, as done for `cliff-proof` on 2026-07-06). Same footprint (shared prefab extents). Register `cliff-proof` first so the sole local joiner claims it (lit) and `cliff-proof-2` stays dormant.

### Component 4 — `StructurePlanner.luau` (F2 reconcile)

`StructurePlanner.Mount.footprint` is currently `{ x: number, z: number }` while `PadBuilder`'s returned mount carries `PadPlanner.Footprint` (`{minX,maxX,minZ,maxZ}`). `StructurePlanner.plan` reads only `mount.cframe`/`mount.hand`, so it's runtime-harmless, but the annotations disagree across the A↔B seam D.2 now drives at runtime. Change `StructurePlanner.Mount.footprint` to the `{minX,maxX,minZ,maxZ}` shape (matching `PadPlanner.Footprint`) and update the `Mount` literals in `StructurePlanner.spec` / `StructureBuilder.spec` fixtures accordingly. No behavior change.

### Component 5 — `main.server.luau` wiring

Replace D.1's static `TEST_OWNER` block with:
- Startup: `local registry = PadRegistry.new()`; register `PadSites["cliff-proof"]` then `["cliff-proof-2"]`; `local coordinator = SiteCoordinator.new(registry)`; `local applier = TreatmentApplier.new(...)`; for each `vacantActions()`: `applier:buildSupport(spec)` then `applier:apply(...)`.
- `PlayerAdded`: `task.spawn` → `net:getTeahouses(tostring(player.UserId))` → `loadout = (res.data.teahouses or {}).M` (nil for a wanderer) → `local action = coordinator:onJoin(tostring(player.UserId), loadout)` → if action, `applier:apply(action.padId, action.spec, action.treatment)`.
- `PlayerRemoving`: `local action = coordinator:onLeave(tostring(player.UserId))` → if action, `applier:apply(...)`.

(The existing `PlayerAdded`/`PlayerRemoving` handlers for leaderstats/profiles/fates/board stay; the D.2 logic is added alongside.)

## Testing

- **Lune — `SiteCoordinator.spec.luau`** (against a real `PadRegistry.new()`; `VacantState` is pure):
  - `onJoin` owner → claims first vacant, action carries the pad's spec + a **lit** structure treatment (`treatment.lit == true`, `treatment.loadout == ownedLoadout`).
  - `onJoin` wanderer (`nil` loadout) → `nil`, no pad claimed.
  - `onJoin` when all pads occupied → `nil`.
  - `onLeave` a holder → releases, action carries a **dormant** treatment (`lit == false`, `loadout.colorScheme == "scheme.dormant"`); pad becomes claimable again.
  - `onLeave` a non-holder → `nil`.
  - Full cycle: join → leave → a second owner can now claim the same pad.
  - Two owners + two pads → both claim distinct pads; a third owner → `nil`.
  - `vacantActions()` → one dormant action per registered pad.
- **F2**: `StructurePlanner`/`StructureBuilder` specs updated for the new `Mount.footprint` shape stay green; full Lune suite green.
- **Visual gate (user, two pads, ONE attempt then stop):** read the local player's Roblox `UserId` in Play, seed it a loadout (`PUT .../teahouses/M`, vermilion), Play → **pad A claimed/lit** (vermilion, `ShojiGlow` on, chōchin present) and **pad B vacant/dormant** (`scheme.dormant` dark, `Shoji` opaque, no chōchin), both standing on 6 stilts. Console shows the claim. Release-on-leave is covered by the unit test, not the gate.

## v1 deliverables

1. `roblox/src/shared/SiteCoordinator.luau` + `roblox/tests/SiteCoordinator.spec.luau`.
2. `roblox/src/server/TreatmentApplier.luau` (Studio-only).
3. `roblox/src/server/PadSites.luau` — second surveyed entry `cliff-proof-2`.
4. `roblox/src/shared/StructurePlanner.luau` F2 type reconcile (+ `StructurePlanner.spec`/`StructureBuilder.spec` fixture updates).
5. `roblox/src/server/main.server.luau` — lifecycle wiring replacing the D.1 static block (F4 cleanup in the applier).

## Build order

TDD `SiteCoordinator` (Lune) → F2 type reconcile (keep specs green) → build `TreatmentApplier` (Studio) → survey + bake `cliff-proof-2` → wire `main.server` (register 2, startup dormant, join/leave) → seed the local player + run the two-pad visual gate → stop for user review.
