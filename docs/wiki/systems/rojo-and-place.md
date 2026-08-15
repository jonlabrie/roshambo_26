---
shelf: systems
updated: 2026-08-15
---

# Rojo & Place

How the Roblox place's source of truth splits between git (Rojo) and the saved
place file. Convention spec:
`docs/superpowers/specs/2026-07-08-roblox-workspace-organization-design.md`.
Current as-built inventory of place-only content: [[place-state]].

## As built

- Rojo owns **exactly** what `default.project.json` names — `src/shared` →
  `ReplicatedStorage.RoshamboShared`, `src/client` →
  `StarterPlayerScripts.RoshamboClient`, `src/server` →
  `ServerScriptService.Roshambo`, `RoshamboRemotes`, and `assets/*.model.json`
  (baked from `tools/builders/` via `lune run tools/genmodels`) → the declared
  children of `Workspace.RoshamboStage` + `ArenaSpawn`. For this subtree, **disk
  wins** — hand-edits in Studio are disposable, overwritten on next sync.
- Everything else in Workspace is **place-only**, living only in the saved
  `.rbxl`: `Workspace.CanyonWorld` (shipped geometry/VFX, foldered
  Arena/Paths/Structures/Legacy/Foliage/Water/Ambience — see [[place-state]] for
  the live inventory) and `Workspace.Sandbox` (throwaway prototypes). Generated
  geometry from builder scripts must parent under `CanyonWorld`, never at
  Workspace root.
- `RoshamboStage` holds only its Rojo-declared children — never hand-add anything
  to it in Studio.
- Ship by **publishing/saving the place from Studio, never `rojo build`** — a
  build emits only the declared `RoshamboStage` children and drops all
  place-only content. Before publishing, run
  `tools/studio/verifyWorkspaceConvention.luau` in Studio. CI
  (`roblox-ci.yml`) fails the build if any `.rbxl(x)` is ever committed.

## Gates & decisions

- 2026-07-08: workspace convention established and enforced — `RoshamboStage`
  reserved for exactly its Rojo-declared instances; all hand-built content moved
  into `CanyonWorld`/`Sandbox`.

## Raw layer

- `default.project.json`
- `tools/studio/verifyWorkspaceConvention.luau`,
  `src/shared/WorkspaceConvention.luau` (Lune-tested)
- CI: `.github/workflows/roblox-ci.yml`
- spec: `docs/superpowers/specs/2026-07-08-roblox-workspace-organization-design.md`
