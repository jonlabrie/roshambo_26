---
shelf: practice
updated: 2026-08-15
---

# Rojo MeshPart .rbxm

How hero meshes ship in this repo: Rojo cannot render a MeshPart from a `MeshId` set
in JSON, so committed BINARY `.rbxm` files referenced by `$path` are the pipeline.

## The core fact

**Rojo CANNOT load mesh GEOMETRY from a `MeshId` set as a property in a
`.model.json`/project.json.** Such a MeshPart syncs with the MeshId string + your Size,
but `MeshSize` stays `(0,0,0)` → the geometry never loads → it renders at the mesh's
**NATIVE (unscaled) size** (the giant floating bonshō, 2026-07-20).
`ContentProvider:PreloadAsync` does NOT fix it. The `Spec.meshPart` JSON emitter is
therefore useless for rendering — kept only in case a future Rojo fixes this.

Also: you **cannot set `MeshId` from `execute_luau`** — it errors `lacking capability
NotAccessible`. Rojo (plugin capability) can set it, but that still doesn't load
geometry.

## The fix — committed binary .rbxm via $path

1. Build the MeshPart in Studio (MCP `execute_luau`, Edit datamodel) via
   `AssetService:CreateMeshPartAsync(meshId, { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic })`.
   This DOES load geometry — `MeshSize` populates, and setting `.Size` afterward
   scales correctly. Set `Name`, `Anchored=true`, `TextureID=""` (see below), `Size`,
   `CFrame`, `Material`, `MaterialVariant`, `Color`.
2. Parent the parts into a `Model`, parent that to `workspace`.
3. **The owner** right-clicks the Model in Explorer → **Save to File** → into
   `roblox/assets/meshes/`. (MCP can't write files; there is no export tool.)
4. **SAVE IT AS `.rbxm` IN THE DIALOG. Do not save `.rbxmx` and rename** — owner
   correction 2026-08-14, and the committed meshes agree: every one starts
   `<roblox!` + the BINARY magic; XML would start `<roblox xmlns…`. The rename dance
   produces an XML file wearing a binary extension; Rojo then fails with
   `Malformed rbxmx file … Unexpected token … !`. Verify before committing:
   `head -c 16 file.rbxm | od -c` should show `< r o b l o x ! 211 377`.
5. Add `"<Name>": { "$path": "assets/meshes/<Name>.rbxm" }` under `RoshamboStage` in
   `roblox/default.project.json`, AND add `<Name>` to
   `WorkspaceConvention.DECLARED_STAGE_CHILDREN` (else the stage-convention verifier
   flags it). Rojo re-reads project.json only on **reconnect** (Disconnect→Connect).

## generate_mesh (MCP) notes

Returns a `tag` only; the result lands as a **Model wrapping a MeshPart named
`body_geom`**, and the Assistant-MeshGen tag is on the **Model**, not the MeshPart. It
bakes its OWN `TextureID` → CLEAR it (`TextureID=""`) so the assigned MaterialVariant
shows ([[texturing-pack-meshes]]). Native size ≈ the `size` hint you pass. Quality was
good for a bonshō bell/ryūzu/lotus at ~2–5k tris.

## DON'T mesh a shape that's really parts (2026-07-21, painful lesson)

The shōrō hip roof was first built as an EditableMesh
(`CreateMeshPartAsync(Content.fromObject(em))`) — it renders fine IN-SESSION but
**EditableMesh geometry does NOT serialize into a `.rbxm`**: the saved MeshPart comes
back with `MeshId=""` / no geometry (a giant white-checkered native-size slab), while
the sibling *parts* saved perfectly. A roof is "literally 4 triangles" — build it as
PARTS in the builder, the way `roblox/tools/builders/Teahouse.luau` does (thin tilted
slabs via `rotX`/`rotZ` matrices + `WedgePart`s for triangular/hip pieces), emitted to
`model.json`, Rojo-synced, no `.rbxm`. For a square pyramid hip: 4 faces, each a
triangle → 2 `WedgePart`s via the **canonical triangle-from-3-points routine** (detect
the right-angle vertex by longest edge = hypotenuse; `right=ac×ab`, `up=bc×right`,
`back=bc`; two wedges split at the eave midpoint with `(right,up,back)` and
`(-right,up,-back)`) — this handles WedgePart handedness that a hand-rolled `up×base`
version got wrong on 2 of 4 faces. Build faces from the frame's own apex +
stringer-corners (the stringers ARE the ridgelines). Emit each wedge's CFrame as a
row-major matrix from the axis vectors (columns X,Y,Z). `Spec.rotY`/trig is
arch-portable through JsonEmit rounding; `math.sqrt` is fine (IEEE-exact, unlike
sin/cos — see the genmodels-portability entry on [[misc-engine-traps]]). **When the
owner gets a model to hand-tune, group it with a clean world-axis-aligned `WorldPivot`
(`PrimaryPart=nil; model.WorldPivot=CFrame.new(apex)`) so they can move it on world
axes; a diagonal PrimaryPart makes the gizmo unusable.**

## Static vs animated meshes (the unsolved problem)

Static meshes (bell, roof) ship fine as a `.rbxm` **sibling** of the rig under
RoshamboStage — they just sit at a world position. But **animated** meshes are a
problem: the client controllers spin parts by name *inside their rig model*
(`WheelController` → `Waterwheel.Wheel1` + `Paddle1_*`; `HammerController` → every
`BellDrive` child matching `^Cam`; `DrumController` → `ThrowDrum` parts). A separate
sibling `.rbxm` isn't inside that rig, so the controller won't find/animate it.
Options, decided per task: (a) a runtime `CreateMeshPartAsync` swap script that
replaces the placeholder inside the rig at startup, (b) keep those as primitives,
(c) retarget the controller to the sibling. See [[bell-engine]] and the M4b art-pass
plan `docs/superpowers/plans/2026-07-20-arena-water-striker-visual-pass.md`.

## Materials pipeline (works well)

AI `generate_material` was REJECTED by the owner (garish). Winning path = **ambientCG
CC0 scans**: download the `_1K-PNG.zip`
(`curl -sL "https://ambientcg.com/get?file=<ID>_1K-PNG.zip"`), unzip, optionally
process (e.g. `convert color.png -modulate 108,28 gray.png` to desaturate
wood→weathered gray), serve on `python3 -m http.server 8777`, MCP `upload_image` the
localhost URLs → Roblox asset ids, assign to a MaterialVariant's
`ColorMap/NormalMap/MetalnessMap/RoughnessMap` (wood/tile have no metalness → set
`""`; use `NormalGL`). **A MaterialVariant only shows when
`Part.Material == Variant.BaseMaterial`** — match the base to what the builder parts
set. Freshly-uploaded texture assets can render white/black for ~20–60s until
moderation resolves ([[image-moderation]]). Variants are place-state → SAVE/PUBLISH
the place; reproducible via a committed setup script that bakes the asset ids
(`roblox/tools/studio/setupCenterpieceMaterials.luau`). See [[place-state]] and the
terrain recipe on [[build-recipes]].
