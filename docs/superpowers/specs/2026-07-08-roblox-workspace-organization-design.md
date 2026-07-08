# Roblox Workspace Organization — Rojo/Place-Only Convention (Design)

**Status:** design, pre-planning (2026-07-08).
**Branch:** `m4b-zendojo-art-pass`.
**Scope:** Reorganize `Workspace` so the Rojo-managed and place-only instance sets are physically separated, establish a durable declarative convention, preserve the arena's streaming behavior across the move, and add two guards against the `rojo build` data-loss trap. **Mostly a Studio re-parenting exercise plus one small server-code change and two lightweight repo/Studio guards.**

## Problem

`Workspace` is a flat dump with no visible boundary between the two kinds of content:

- `Workspace.RoshamboStage` (a Folder declared in `project.json`) currently holds **37 children**: the **8 Rojo-declared** instances (7 hero-prop models from `assets/*.model.json` + `ArenaSpawn`) **mixed with 29 hand-built place-only** instances (river/falls VFX, rock models, POCs, decks, `DevChannelSpawn`).
- ~22 more loose place-only canyon items (paths, walls, bridges, lanterns, railings, drafts, the 14 legacy `CanyonTeahouses`, `Stairs_40_50`) sit directly under `Workspace`, alongside `Terrain` and `Camera`.

Because Rojo reconciles **by declared name**, the place-only instances coexist safely today — but the boundary is invisible, so "is this managed by Rojo?" can't be answered by looking at the tree. Worse, a `rojo build` (place file generated from disk only) would emit a `RoshamboStage` containing **only** the 8 declared children and silently drop all place-only content — the exact reason for the standing "publish the place, never `rojo build`" rule.

## The convention (declarative, location-mirrors-truth)

**Rojo owns exactly what `project.json` names — and everything it names lives under `RoshamboStage`. Everything else is place-only, and is organized by lifecycle, not by tool.**

| Folder | Contents | Rule |
| :-- | :-- | :-- |
| `Workspace.RoshamboStage` | The **8 Rojo-declared** instances only (7 hero models + `ArenaSpawn`) | Rojo-owned; disk wins; **never hand-edit or add children in Studio**. |
| `Workspace.CanyonWorld` | All **shipped** place-only geometry/VFX/rocks/paths/walls/bridges/decks/lanterns | Place-only; publish the place; **never `rojo build`**. Organized into sub-folders (below). |
| `Workspace.Sandbox` | Throwaway prototypes + drafts | Place-only, disposable. |

`Terrain` and `Camera` stay at `Workspace` root (engine-owned singletons; not movable/relevant).

### `CanyonWorld` sub-structure

- `CanyonWorld/Arena` — the **arena-visible** place-only set (river/falls VFX + rocks + landing decks near the clearing that players view from spawn ~200 studs away). **These stay `ModelStreamingMode = Persistent`** (see Streaming below).
- `CanyonWorld/Paths` — descent paths, steps, stairs, railings, lanterns.
- `CanyonWorld/Structures` — bridges, retaining walls, falls walls, bench/landing structures.
- `CanyonWorld/Legacy` — the 14 legacy `CanyonTeahouses` (frozen; retired later in D.6.2).

## Instance classification

### `RoshamboStage` (37 children) → destinations

**STAY (8 — Rojo-declared, pinned by `project.json` + runtime path lookups; do not move or rename):**
`BonshoRig`, `Shoro`, `Waterwheel`, `BellDrive`, `ThrowDrum`, `Overlook`, `SwitchbackDeck`, `ArenaSpawn`.

**→ `CanyonWorld/Arena` (24 — shipped, arena-visible; keep Persistent):**
VFX parts/folders (10): `Reach2VFX`, `Reach3VFX`, `Reach4VFX`, `LowerStepVFX`, `ClearingInfallVFX`, `HeroInfallVFX`, `ClearingFallVFX`, `TopToOutfallVFX`, `MicroToLargestVFX`, `LargestInfallVFX`.
Rock models (10): `Reach2Rocks`, `Reach3Rocks`, `Reach4Rocks`, `LowerStepRocks`, `ClearingInfallRocks`, `HeroInfallRocks`, `ClearingFallRocks`, `TopToOutfallRocks`, `MicroToLargestRocks`, `LargestInfallRocks`.
Decks/landings + canyon-wide VFX (4): `FallsLanding`, `LandingDeck`, `DowncanyonVFX`, `UpcanyonVFX`.

**→ `Sandbox` (5 — prototypes + dev spawn):**
POCs (4): `Reach159POC`, `Reach2POC`, `Reach3POC`, `OutfallChannelPOC`.
Dev spawn (1): `DevChannelSpawn` (a dev/test SpawnLocation, not shipped).

*(8 stay + 24 → Arena + 5 → Sandbox = 37 children accounted for.)*

### `Workspace` top-level place-only items → destinations

**→ `CanyonWorld/Paths`:** `NW80FallsStair`, `NW40Descent`, `NW2040Path`, `NW1012West`, `NW1012South`, `NW1211Path`, `DescentPath`, `PathExtension`, `PathSteps`, `PathRailings`, `PathLanterns`, `Stairs_40_50`.

**→ `CanyonWorld/Structures`:** `Bridges`, `RetainingWalls`, `NWFallsWall`, `BenchLanding`, `EngawaSafetyRail`.

**→ `CanyonWorld/Legacy`:** `CanyonTeahouses`.

**→ `Sandbox`:** `PathDraft`, `ReachDraft`, `TempBridgeAbutments`.

**STAY / FLAG:** `Terrain`, `Camera` (stay). `Decal` (a loose `Decal` at Workspace root is anomalous — **flag to user during execution; do not move blindly**, it may be orphaned or a skybox/placeholder).

> Every classification above is a reasonable-default call. The user reviews this table at the spec-review gate and during execution; anything mis-bucketed is a cheap re-parent to fix.

## Streaming persistence (the one real dependency)

`main.server.luau` (current) walks `RoshamboStage:GetChildren()` and sets `ModelStreamingMode = Persistent` on every Model, so the arena is always replicated to distant spawn-watchers (comment: controllers that capture parts at startup otherwise capture nothing). The place-only VFX/rocks are Persistent **today only because they live in RoshamboStage.** After they move to `CanyonWorld/Arena`, the loop must also cover that folder or they lose persistence → intermittent vanishing at distance.

**Change:** generalize the startup loop to persist Models under **both** `RoshamboStage` **and** `CanyonWorld/Arena` (two stable named paths; `Arena` uses `WaitForChild` like `RoshamboStage`). The far canyon (`Paths`/`Structures`/`Legacy`) is deliberately **not** persisted — it streams normally, exactly as those top-level items do today (they were never persisted). This preserves current behavior precisely: the set that is Persistent before the move is Persistent after.

This is the only source-code change, it is Rojo-synced/version-controlled, and it is unit-observable (see Testing).

## Enforcement (two guards — "CI check" adapted to reality)

CI runs against the **repo (disk)**; place-only instances are not on disk, so no GitHub job can assert `CanyonWorld` exists. The robust equivalent is two complementary guards:

1. **Repo guard (CI, disk-side) — no committed place files.** Add a CI step (and a `.gitignore` entry) that **fails if any `*.rbxl` / `*.rbxlx` is tracked in git.** A committed built place file is the fingerprint of the dangerous `rojo build` path and of place-state leaking into the repo. This is a genuine GitHub CI check.
2. **Pre-publish assertion (Studio-side) — structure present.** A small Luau assertion (run via the Studio MCP / command bar before publishing) that verifies the convention holds in the live place:
   - `Workspace.RoshamboStage` exists and its **only** children are the 8 declared names (fails if any hand-built instance crept back in).
   - `Workspace.CanyonWorld` and `Workspace.CanyonWorld.Arena` exist and are non-empty.
   - Prints a PASS/FAIL summary with counts.
   Committed as `roblox/tools/studio/verifyWorkspaceConvention.luau` and referenced in a "Before you publish" checklist in `README_DEPLOY.md` / `CLAUDE.md`. It is a manual gate (Studio-only, cannot run in headless CI), but it is version-controlled and repeatable.

## Non-goals

- No change to any of the 8 Rojo-declared assets, their `assets/*.model.json`, or `project.json`'s Workspace subtree.
- No geometry/VFX authoring, retexturing, or deletion — pure re-parenting (plus flagging `Decal`).
- Not retiring the legacy `CanyonTeahouses` — that is D.6.2. This spec only *relocates* them into `CanyonWorld/Legacy`.
- No automatic (headless) verification of place-only structure — that is impossible; guard 2 is a documented manual gate.

## Execution method & risk

- **Re-parenting** is done in Studio via MCP `execute_luau` (build the folder skeleton, then `instance.Parent = target` per classification), in small verifiable batches, **saving/publishing the place afterward — never `rojo build`.** Per the standing "one visual attempt then stop" rule, execution pauses for the user to eyeball the tree after the skeleton + first batch.
- **Reversibility:** re-parenting is trivially reversible; nothing is deleted.
- **Runtime-reference safety (audited):** no source references any place-only instance by path except the `RoshamboStage` streaming loop (handled above). The 8 Rojo assets keep their `RoshamboStage.<Name>` paths. `git grep` confirmed zero references to any of the ~51 place-only names.
- **Rojo interaction:** `RoshamboStage` stays a declared inline folder; removing hand-built children from it makes disk and place *more* consistent, not less. `CanyonWorld`/`Sandbox` are undeclared, so `rojo serve` ignores them (correct).

## Testing

- **Server (Vitest? no — Luau):** add/adjust a Lune-testable seam if the persistence loop is extracted into a pure helper (e.g. `stagePersistence.persistTargets(roots) -> {Model}`) — a pure function returning the Models to mark, unit-tested with fake trees. If extraction is disproportionate, keep the loop inline and rely on guard 2 + manual Play verification (document which).
- **Guard 1:** a CI step asserting no tracked `*.rbxl(x)`; verify it fails on a deliberately-added dummy place file, then passes once removed.
- **Guard 2:** run `verifyWorkspaceConvention.luau` in the live place post-reorg; expect PASS. Deliberately re-parent one stray instance into `RoshamboStage`; expect FAIL; move it back.
- **Manual Play:** enter Play, confirm the arena VFX/rocks still render from spawn distance (persistence preserved) and controllers (`WheelController`, `HammerController`, `DrumController`) still bind their rigs.

## Deliverables

1. Live place reorganized to the convention (Studio re-parent + save/publish).
2. `main.server.luau` persistence loop generalized to `RoshamboStage` + `CanyonWorld/Arena` (optionally via a Lune-tested `stagePersistence` helper).
3. `roblox/tools/studio/verifyWorkspaceConvention.luau` (guard 2) + checklist entry.
4. CI step + `.gitignore` rule rejecting tracked `*.rbxl(x)` (guard 1).
5. Convention documented in `CLAUDE.md` and the `roblox-rojo-vs-place-state` memory updated to the declarative framing with the RoshamboStage-cohabitation caveat resolved.
