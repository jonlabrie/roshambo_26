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

## Dormant tools (2026-08-15 census)

Every `roblox/tools/{studio,builders,textures,blender,glyphs}` script not already
cited by another wiki page, one line each. "One-shot" = already run against its
target; safe to leave alone. "Live" = re-runnable / still the current tool for its job.

**One-shot / baked (safe to ignore):**
- `studio/auditTeahouseEnvelopes.luau` — read-only clearance/tier audit per placed
  teahouse; survey, not a builder.
- `studio/bakeEastBackdrop.luau` — one-shot plant of the far-east skyline-massing
  trees into `CanyonWorld.Foliage.EastBackdrop`.
- `studio/bakeNW1012Stairway.luau` — one-shot survey; its printed literals are
  already baked into `buildIshidanStairs`/`buildStairLandingPad` CONFIG (2026-07-02).
- `studio/bakePathMarkers.luau` — one-shot: prints an `ArenaLayout.paths` table from
  `PathDraft` markers (that folder no longer exists in the place, see [[place-state]]).
- `studio/buildPadDemo.luau`, `studio/materializeStructureDemo.luau`,
  `studio/vacantStateDemo.luau` — one-shot A/B integration visual-gate demos for the
  Structure builder (pad, loadout, vacant-vs-claimed state); already proved.
- `studio/buildUpcanyon.luau` — one-shot terrain sculpt/carve for the up-canyon
  watercourse; mutates live terrain, already executed.
- `studio/reprepMoss.luau` — one-shot fix-up (re-pointed moss scatter to
  single-sided meshes + `DoubleSided`); the defect it fixes is closed.
- `studio/teahousePerches.luau` — 2026-06-20 scouted site-list snapshot, superseded
  once stamped into `workspace.CanyonTeahouses`.
- `studio/upcanyonFalls.luau` — a recovery/checkpoint artifact reconstructing the
  up-canyon falls VFX if the place save were ever lost; not a build step.
- `blender/export_niwaki.py` — one-shot exporter tied to a specific purchased
  TurboSquid asset (2017007) that lives outside the repo; re-run only if
  re-exporting that asset.

**Live / still reusable:**
- `studio/buildDeckBalustrade.luau`, `studio/buildFlatShelfPath.luau`,
  `studio/buildMossScatter.luau`, `studio/buildMossTransitions.luau`,
  `studio/buildRanmaCarvings.luau`, `studio/buildShoreRocks.luau`,
  `studio/buildStairLandingPad.luau`, `studio/buildSuspensionBridge.luau`,
  `studio/buildTimberRetainingWall.luau`, `studio/buildTrailPath.luau`,
  `studio/carveRiverPath.luau`, `studio/cullWaterMargin.luau`,
  `studio/padOccupancyPreview.luau`, `studio/placeCanopyHeroes.luau`,
  `studio/surveyDeckPlacements.luau` — reusable builders/scatter/survey scripts for
  their respective structures (railings, paths, moss, shore rocks, bridge, retaining
  walls, trails, culling, pad previews); re-run per new site as needed.
- `studio/buildPaths.luau` — the current canyon path-network builder (baked snapshot
  of `PathDraft`, mirrors `builders/CanyonPath.luau`).
- `studio/draftRiverPathMarkers.luau` — draggable river-path waypoint markers, the
  live successor network.
- `studio/hideDevMarkers.client.luau` — runtime client script
  (`StarterPlayerScripts`) hiding `DevMarker`-tagged instances in Play.
- `studio/padSites.luau` — data module of surveyed cliff `PadSpec`s feeding the pad
  system.
- `builders/CanopyScatter.luau`, `builders/Creek.luau`, `builders/Footpath.luau`,
  `builders/Graybox.luau`, `builders/OffstageCull.luau`,
  `builders/TerraceDressing.luau` — pure placement/dressing modules (canopy scatter,
  creek stones, garden circulation, massing-shell validator, sky/rock cull
  classification, terrace lantern rings).
- `textures/bump_to_normal.py`, `textures/preview_distance.py` — texture-pipeline
  utilities (bump-to-normal conversion; preview a foliage atlas at distance without
  uploading).
- `blender/bake_clump_tree.py`, `blender/bake_grass_patch.py`, `blender/lod_cards.py`,
  `blender/lod_drop_duplicate.py`, `blender/lod_trunk.py`, `blender/split_fbx.py` —
  foliage LOD/impostor pipeline (clump-card baking, LOD thinning/growing, per-object
  FBX split).
- `glyphs/rakedtex.cjs` — dependency-free raked-sand texture generator (tileable
  albedo + normal, deterministic LCG).
- `glyphs/png.cjs` — dependency-free PNG decode/encode (Node built-ins only, 8/16-bit
  RGB/RGBA/gray/palette in, 8-bit RGBA out); shared I/O library other glyph scripts
  (e.g. `pierce.cjs`) `require`.
- `glyphs/pierce.cjs` — bakes sukashibori cut-through alpha into a relief albedo from
  the Marigold shading map's near-black regions (flood-fill + area-gated transparency);
  gate-locked threshold from the 2026-07-22 Nanda pass.

**Flags:**
- `builders/CanopyScatter.luau`'s header says its Studio mirror is
  `tools/studio/scatterCanopy.luau` — **that file does not exist** anywhere in the <!-- lint-ok: named to say it is missing -->
  repo or its git history; the mirror was never committed, or was renamed to
  `studio/placeCanopyHeroes.luau` without updating the header comment.
- `studio/draftPathMarkers.luau` — its own header calls it a superseded legacy
  network ("do not run it, it would destroy" the river-path markers) and its target
  (`Workspace.PathDraft`) no longer exists in the place ([[place-state]]); dormant,
  keep for reference only.
