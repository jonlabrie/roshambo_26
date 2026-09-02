---
shelf: systems
updated: 2026-08-27
checked: 2026-09-04
---

# Rojo & Place

How the Roblox place's source of truth splits between git (Rojo) and the saved
place file. Convention spec:
`docs/superpowers/specs/2026-07-08-roblox-workspace-organization-design.md`.
Current as-built inventory of place-only content: [[place-state]].

## As built

- Rojo owns **exactly** what `default.project.json` names. For this subtree, **disk
  wins** — hand-edits in Studio are disposable, overwritten on next sync. ⚠ **Read the
  file for the current list rather than trusting a copy here**; this paragraph named an
  inventory that was four entries and one whole subtree out of date within a day of the
  karasu landing. The shape, which is what a reader needs:
  - `src/shared` → `ReplicatedStorage.RoshamboShared`, `src/client` →
    `StarterPlayerScripts.RoshamboClient`, `src/server` → `ServerScriptService.Roshambo`,
    plus `RoshamboRemotes`.
  - ⚠ `ReplicatedStorage.RoshamboBirds` — the familiars' skinned meshes, as
    `assets/meshes/*.rbxm`. **Rojo-managed, so a new bird needs a `default.project.json`
    entry AND a Rojo server RESTART** (a plugin reconnect re-reads the server's snapshot,
    not disk), and its `.rbxm` must be saved out of Studio first. See [[familiars]].
  - `Workspace.RoshamboStage` → hero props, from BOTH `assets/*.model.json` (baked from
    `tools/builders/` via `lune run tools/genmodels`) and `assets/meshes/*.rbxm`, plus
    `ArenaSpawn`.
  - ⚠ **Rojo cannot change an instance's ClassName.** A node whose Studio instance is the
    wrong class is blocked permanently and silently — delete the instance, do not fight it.
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
