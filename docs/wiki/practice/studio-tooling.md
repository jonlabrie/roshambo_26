---
shelf: practice
updated: 2026-08-15
---

# Studio Tooling

How we drive the owner's Roblox Studio (mid-2026, macOS) — UI facts for guiding them,
and the Studio MCP's quirks.

## Studio UI

- Panels like Explorer and Output are under the **Window** menu, not the legacy "View
  tab" ribbon. Prefer "Window → Explorer/Output" in instructions.
- The Rojo plugin lands in `~/Documents/Roblox/Plugins/RojoManagedPlugin.rbxm` and
  appears in the Plugins area after a Studio restart.

## Rojo patch-by-name gotcha (2026-06-18, cost a misdiagnosis)

Rojo syncs by patching the existing instance with the same name, only applying
properties PRESENT in the model.json. If a builder reuses a part name but CHANGES a
property you stop emitting, Rojo leaves the OLD value. Concretely: balusters were
`Shape="Cylinder"`; rewritten as boxes by just omitting Shape (relying on the Block
default) while keeping names `B0,B1…` → Rojo kept Shape=Cylinder + applied the new box
Size, rendering 0.26-long cylinders lying horizontal. FIX: when changing a part's
Shape (or any enum/bool) in a builder, declare it explicitly so the JSON carries it; a
fresh delete+resync also clears stale props. Also: a Roblox **Cylinder's length is its
X (first) Size component**, diameter = Y/Z.

## Studio MCP quirks

Installed and verified 2026-06-06 (playtest start/stop, screen_capture, execute_luau).

- `execute_luau` does NOT capture `print` output — use an explicit `return` value
  (e.g. `return table.concat(out, "\n")`).
- `execute_luau` takes a `datamodel_type` (`Edit`/`Client`/`Server`). `Edit` is
  unavailable while the owner is in Play, `Server` unavailable in Edit. Client-side
  VFX method calls (e.g. `:Emit()`) need `Client` to render ([[replication-races]]).
- `screen_capture` accepts `camera_position` + `look_at_position` (arrays of 3
  numbers) and works during play mode — use it to frame specific rigs. **GOTCHA: a
  repositioned capture leaves `workspace.CurrentCamera.CameraType = Scriptable`, which
  DISABLES the owner's right-drag edit navigation (camera feels "stuck"). ALWAYS reset
  afterwards, in the same session:**

  ```lua
  workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
  ```

- `screen_capture` eats huge context (base64 images) — use sparingly on long sessions.
- During play, `execute_luau` property/`TextBounds` reads can be unreliable
  (stale/wrong datamodel); **verify rendered UI via screenshot, not property reads**
  ([[visible-is-not-pixels]]).
- `search_game_tree` keyword search is noisy (e.g. "rig" matches every R15
  RigAttachment); prefer `execute_luau` walking `workspace` for world layout.
- Terrain edits and raycasts must not share one `execute_luau` call — the raycast
  reads pre-edit state ([[build-recipes]], terrain-carve gotchas).

Before any publish: run `roblox/tools/studio/verifyWorkspaceConvention.luau` and scan
imported third-party content ([[toolbox-backdoor-scan]]); the checklist lives on
[[place-state]].
