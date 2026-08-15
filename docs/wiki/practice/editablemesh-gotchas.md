---
shelf: practice
updated: 2026-08-15
---

# EditableMesh Gotchas

Building meshes in-engine via `AssetService:CreateEditableMesh()` +
`AssetService:CreateMeshPartAsync(Content.fromObject(em), {...})` (Studio 2026,
verified via MCP `execute_luau`). The rules that make a procedural mesh actually
render, persist, and land where you put it.

## Two gotchas that render NOTHING (Size still correct, so it looks built)

1. **Faces without normals do not render.** Every triangle needs
   `em:SetFaceNormals(faceId, {nA, nB, nC})` (ids from `em:AddNormal(unitVec)`). UVs
   alone are not enough. A bare `AddTriangle` + `SetFaceUVs` produces an invisible
   part.
2. **`CreateMeshPartAsync` does NOT recenter geometry onto the part origin.** If you
   `AddVertex` at world coords and then `mp:PivotTo(CFrame.new(centroid))`, the mesh
   double-offsets and flies off-screen (≈ 2× centroid) — while `mp.Position` still
   reads the value you set. FIX: compute the centroid first, build verts in LOCAL
   space (`vert = worldPos - centroid`), then `PivotTo(CFrame.new(centroid))`.

Diagnosis trick: a plain Part marker at the target spot + a flagged neon mesh — if the
marker shows and the neon mesh doesn't, it's one of these two.

## Runtime (Play) restrictions — none apply in Edit/command-bar

- `CreateEditableMesh()` throws "EditableMesh is not accessible" unless **Game
  Settings → Security → Allow Mesh/Image APIs** is enabled.
- `MeshPart.DoubleSided` cannot be written from a runtime script ("lacking capability
  Plugin") — omit it; rely on upward-facing normals.
- `SurfaceAppearance.ColorMap`/`NormalMap` cannot be written from a runtime script
  either. WORKAROUND: author the SurfaceAppearance in Edit (e.g. on a template part)
  and `:Clone()` it at runtime — cloning copies the maps with no property write.
- Live UV scroll: hold the EditableMesh ref and `em:SetUV` each frame (RenderStepped).
  It animates a **SurfaceAppearance** (UV-sampled), NOT a MaterialVariant
  (world-tiled). Wrap scroll `% 1` so the reset is invisible. Run client-side.

## Persistence — the big one

An EditableMesh built in Edit via `CreateMeshPartAsync` does **NOT serialize into the
place**. It looks correct in Edit (live mesh in memory), but in **Play (or after
reopen)** the MeshPart has no real mesh and renders as a **placeholder cube** (a
SurfaceAppearance still shows on it → "cube with the water texture"). Two fixes:

1. **Rebuild at runtime** — a client LocalScript reconstructs the EditableMesh on play
   (what `roblox/tools/studio/riverFlowAnim.client.luau` does). Required if you want
   live UV-scroll built from scratch.
2. **Publish to a real mesh asset** — a stable `rbxassetid://` MeshId that persists &
   replicates like any normal mesh; you can still animate by re-deriving an
   EditableMesh from it at runtime and UV-scrolling.

**Working publish recipe (verified 2026-06-22):**

1. Build the EditableMesh `em` (normals + local-space verts).
2. `local result, assetId = AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {Name=..., Description=...})`
   — pass `em` the **Instance**, NOT `Content.fromObject(em)`; returns
   `(Enum.CreateAssetResult.Success, <assetId>)`. `CreateAssetAsync` is gated by
   default but **ungates after enabling its Studio Beta Feature + a full Studio
   RESTART** (toggling mid-session is not enough).
3. Apply by **creating the part from the asset**:
   `CreateMeshPartAsync(Content.fromUri("rbxassetid://"..assetId), {...})`. Do NOT
   write `MeshPart.MeshContent` directly — capability-locked even in Edit.
4. The resulting MeshPart **persists & replicates** (renders correctly in Play — no
   cube). Confirmed.

To publish an **already-built** unpublished ribbon (`MeshContent` shows
`Content{SourceType=Object, Object=EditableMesh}`, `MeshId=""`): grab the em back with
`local em = ribbon.MeshContent.Object`, then run the publish recipe on it. Re-verified
2026-06-26 on the ZenDojo path ribbon → swapped the asset-backed MeshPart in (PivotTo
old pivot, copy DoubleSided/Material/MaterialVariant), Play-confirmed. Republishing on
each shape change mints a new asset id — tune the geometry as an editable mesh in
Edit, publish ONCE when the shape is locked.

Motion on a persistent mesh: derive an editable copy at runtime
(`CreateEditableMeshAsync`) + UV-scroll — lighter than full rebuild. VERIFIED: a
`CreateEditableMeshAsync`-derived mesh IS live-linked — `SetUV` on it updates the
rendered MeshPart created from it.

## Smaller traps

- **`Enum.CollisionFidelity.None` does NOT exist** — valid values are `Default`,
  `Hull`, `Box`, `PreciseConvexDecomposition`. Passing `.None` throws and the part is
  never created (the script silently dies — looked like "no flow" while only the foam
  particles moved). Use `Box`.
- `CreateEditableMeshFromPartAsync` does not exist in this build (an LLM suggestion —
  wrong for this version).
- **EditableMesh-backed MeshParts do NOT replicate to Play clients** — the client sees
  a default ~1-stud cube. Ship as a committed `.rbxm` ([[rojo-meshpart-rbxm]]) or
  build client-side.

Proven in `roblox/tools/studio/upcanyonRiverPOC.luau` (Edit builder) +
`roblox/tools/studio/riverFlowAnim.client.luau` (runtime UV-scroll). See
[[blender-pipeline]] for the river pipeline that uses all of this, the flat-beam rule
on [[misc-engine-traps]], and [[canyon]].
