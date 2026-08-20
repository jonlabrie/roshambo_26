---
shelf: practice
updated: 2026-08-20
---

# Blender Pipeline

The asset pipelines that feed Roblox from outside the engine: Blender→FBX import (static
and SKINNED), the in-engine procedural river technique, and the SDF glyph rasteriser. Tools live in
`roblox/tools/blender/`, `roblox/tools/textures/`, and `roblox/tools/glyphs/`.

## Blender → Roblox FBX

Established 2026-07-30 building the yamadoro lantern (5 parts, 4557 tris, 3 studs).

**1. A Blender FBX lands in Roblox at exactly 100×.** Blender writes FBX in
centimetres; Roblox reads the raw numbers as studs and ignores the file's
`UnitScaleFactor`. A 3.0-unit model arrived as **300.03 studs** — measured. **Fix at
export: `global_scale=0.01`** (keep `apply_unit_scale=True`):

```python
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True,
    apply_unit_scale=True, global_scale=0.01,      # <-- the fix
    apply_scale_options='FBX_SCALE_NONE',
    object_types={'MESH'}, use_mesh_modifiers=True, mesh_smooth_type='FACE',
    path_mode='COPY', embed_textures=False, axis_forward='-Z', axis_up='Y')
```

Re-importing that file into Blender reads 0.03, and that is CORRECT — Blender honours
the cm tag. Do not "fix" it.

**2. `PivotOffset` does NOT scale when you change `MeshPart.Size`.** Rescaling an
over-large import leaves every pivot at its old distance (pivots 52–274 studs from
1–3.6-stud parts). **Scale the offsets, don't zero them** — the importer points every
part's pivot at a shared model origin, which is what lets the assembly rotate as one:

```lua
local po = p.PivotOffset
p.PivotOffset = CFrame.new(po.Position * S) * (po - po.Position)
```

Verify by pivoting the model 30° and back (bounding box unchanged). Then set
`model.WorldPivot` to the **base centre** so it seats on ground. **Recentre geometry
at the origin in Blender before export** to keep offsets small in the first place.
Same defect family as the importer leftovers on [[material-and-mesh-traps]] §5.

**3. `MeshPart.DoubleSided` EXISTS — never duplicate shells to fake it.** Verified
engine 0.732.0: it is a real property, writable at runtime and on a fresh MeshPart.
(`prep_foliage.py` once recorded the opposite and built a geometry-doubling pass on
it — doubling costs 2× triangles for an identical result; on the iris it was the whole
difference between 8.9× and 4.4× reduction.) Single-sided vendor foliage genuinely
half-vanishes as you walk past — real symptom, wrong old diagnosis. Set the flag at
import.

**4. The importer uploads textures and builds the SurfaceAppearance for you.** Export
with `path_mode='COPY'` (writes a `.fbm` folder beside the FBX) and Studio uploads the
maps and wires them itself. Each MeshPart gets its own MeshId; all share one
SurfaceAppearance asset set when they share one UV atlas (**so one shared UV atlas
across parts is worth engineering** — N×3 uploads become 3). `TextureID` stays empty,
which is what you want ([[texturing-pack-meshes]]). `Material` defaults to Plastic —
set it to Rock/Slate for correct footstep audio.

**5. "Can't read the color or normal maps" has THREE separate causes**, which hit the
same iris import in sequence — each fully explained the symptom and each was only part
of it:

1. **Dead vendor texture paths** (absolute paths to the seller's machine). Blender
   renders magenta; a COPY-mode FBX then carries nothing.
   `prep_foliage.repair_texture_paths()` fixes it. Test by RESOLVING THE PATH, not by
   `im.has_data` (lazy — False for a good image until pixels are read).
2. **Mix Shaders hide the BSDF from the exporter.** The FBX exporter only finds
   textures traceable from a Principled BSDF wired to Material Output; behind a Mix
   Shader it writes no maps. `bypass_mix_shaders()` rewires them (the two-sided trick
   they implement is unnecessary once you have DoubleSided). This produced a false
   lead — the one directly-wired material was also slot 0, so it read as "only the
   first material exports". It is not. *A test that reproduces the symptom does not
   validate the explanation.*
3. **A MeshPart takes exactly ONE SurfaceAppearance.** A multi-material mesh imports
   with NO texture even when every map is in the `.fbm`. **Always split by material
   before export** (`split_by_material`), not only when over the triangle limit.
   Bonus: Roblox then sets `DoubleSided` correctly per piece by itself.

**6. TRIANGLES are not faces, and the limit is on triangles.** Roblox caps a mesh at
**20,000 triangles**; quads count double, so face counts run ~25% low — use
`tri_count()`. Splitting by material fixed the over-limit iris variants; the Sugi
precedent goes further (split by material *then halved*).

**7. Roblox truncates instance names at 50 characters.** Name pieces by ROLE
(`Iris001_Blades01`, 16 chars), not by the vendor's full string — role is also more
truthful (identify petals by a linked alpha; this kit names flower materials
`Leaves02_*`).

**The bake recipe:** voxel remesh (needs enclosed volume) → displace → decimate to
budget → multi-object `smart_project` in one edit session so all parts share one 0–1
atlas → Cycles bake DIFFUSE (direct/indirect off) / ROUGHNESS / NORMAL to one 1024²
set (all parts share ONE material so a single Image Texture node is the bake target).
**1024² is the ceiling** — Roblox silently downscales larger. **Order matters: remesh
the WHOLE object, THEN cut it into parts** — voxel remesh needs enclosed volume;
splitting open shells first makes the remesh return almost no geometry (a 1293-poly
roof became 42). Cut the watertight solid with `bpy.ops.mesh.bisect(..., use_fill=True)`.

## Skinned meshes — a rig Roblox will drive

Verified end to end 2026-08-19. Everything below is measured, not reasoned.

**Why this matters more than it looks: bones are ordinary runtime instances.** A skinned
`MeshPart`'s `Bone` children have a writable `Transform`, so **all motion stays in Luau** —
no Animation assets, no Animation Editor, no upload round-trip per timing tweak, and the
work stays testable under Lune. Authored clips are the opposite trade, and they fight a
procedural layer that has to aim at a *specific* perch. Model the pose that is seen most;
let code produce the rest.

**Studio's 3D Importer accepts a custom, non-R15 armature.** Measured on a vendor bird: 17
Maya joints in → **16 `Bone` instances out**, hierarchy preserved, parented under the
MeshPart, `MeshPart.HasSkinnedMesh == true`. (The missing one carried no weights and was
dropped deliberately — see the flags.) This was the open question that gated the whole
approach; it is closed.

**Export flags, beyond the §1 unit fix (which still applies):**

```python
bpy.ops.export_scene.fbx(filepath=fbx, use_selection=False,
    apply_unit_scale=True, global_scale=0.01, apply_scale_options='FBX_SCALE_NONE',
    object_types={'MESH', 'ARMATURE'},
    use_mesh_modifiers=False,       # keep the armature modifier LIVE — do NOT bake it
    add_leaf_bones=False,           # Roblox does not want them
    use_armature_deform_only=True,  # drops bones carrying no weight
    bake_anim=False,
    mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False,
    axis_forward='-Z', axis_up='Y')
```

⚠ **`use_mesh_modifiers=True` silently destroys the rig.** It applies the armature modifier
and writes a static mesh; the import then *succeeds* and simply has no bones.

**Verify with a bone-drive test, never by looking.** Read a leaf bone's
`TransformedWorldCFrame`, set an ancestor's `Transform`, read it again. Measured: rotating
the neck bone 45° moved the head-tip bone **0.1390 studs** and the tail-tip bone — a
different branch — **exactly 0.0000**. Non-zero *on* the chain and zero *off* it is what
proves weights and hierarchy are sound. A screenshot proves neither.

**⚠ Maya-sourced meshes: IGNORE VERTEX COLOURS at import.** The vendor sparrow carries a
`colorSet0` layer whose values run 0.0–0.15 — a baked lighting/AO pass, not colour. Roblox
multiplies vertex colours into the surface, so importing it renders the mesh near-black and
reads for an hour as a broken material.

**Axis conversion from Maya** (+X forward, +Y up, +Z width): Blender's exporter convention
wants the model facing −Y, so put `rotation_euler = (90°, 0, 270°)` on the **armature**
object and let the mesh follow as its child. Euler XYZ applies Rz@Ry@Rx, so that composes
to +X→−Y and +Y→+Z.

**`bpy.ops.export_scene.fbx` fails under the Blender MCP with `use_selection=True`** —
that context has no `selected_objects`. Load only what you want into an empty scene and
export with `use_selection=False`, or wrap the call in a `temp_override` carrying a real
window.

**"Rigged" in a vendor listing means "has a skeleton", not "has motion."** The purchased
collection contains **zero** actions. That is fine here — we drive bones from code — but do
not buy a pack expecting animation.

### Retargeting a vendor rig — four traps, all found the hard way

Reshaping a purchased rigged mesh into a different species is cheap; four things about doing it
in script are not obvious, and each cost a full diagnostic round trip.

**1. A vendor file ships with a STORED POSE, and rescaling the armature DATA detonates it.**
The sparrow carried pose-channel transforms on 7 bones. `Armature.transform()` rescales the REST
bones but leaves pose channels in the original units, so a 0.017 scale turned a small leg offset
into a 60× explosion and the bird collapsed into a needle. Either transform the OBJECT (which
scales pose and rest together) or clear every `pose_bone.matrix_basis` afterwards. **Clear them
again after EVERY rest-bone edit** — entering and leaving edit mode re-exposes the same defect.

**2. Setting `matrix_world` on a still-parented object computes a compensating `matrix_basis`.**
The mesh silently kept the vendor's 0.1669 scale and 90° rotation and rendered at a sixth size
with the armature modifier looking guilty. It was not: toggling `show_viewport` on the modifier
gave identical dimensions either way, which is what isolated it. Zero the basis explicitly after
setting `matrix_parent_inverse`.

**3. Stale CUSTOM SPLIT NORMALS shade a crease with no matching silhouette kink.** The mesh
carries a `custom_normal` attribute baked by the vendor; move vertices even 0.03 studs and it no
longer describes the surface it is attached to. The symptom is a visible shading break that
survives every geometry fix, because the geometry was never wrong. `me.attributes.remove(...)`
and let Blender recompute.

**4. `split_edges` leaves COINCIDENT vertex pairs, so a position test cannot separate them.**
Splitting a bill along its gape leaves upper and lower vertices at identical coordinates.
Classify by the faces a vertex belongs to — average which side of the plane its `link_faces`
sit on — or both twins land in the same group and the split does nothing visible.

**5. ⚠ DO NOT POSITION AN IMPORTED MODEL WITH `PivotTo` — the importer bakes a ROTATION into
the MeshPart's `CFrame` with a compensating rotation in `PivotOffset`.** Setting the pivot to an
identity rotation therefore hands the *part* the inverse, and the bird renders lying on its back
while the geometry inside was upright all along. The tell is the Size vector: an upright bird
reads width × height × length (0.148 × 0.315 × 0.552); if height and length are swapped the
geometry really is rotated, and if they are not, the placement is at fault. **Set
`part.CFrame` directly.** Same importer behaviour as the pivot-POSITION leftovers in §2 — this is
the rotation half of it, and it cost a full round of wrong diagnosis.

**Splitting a closed shell needs its holes filled or the model shows its own interior.**
`bisect_plane` (geom restricted to the region, or it cuts the whole model) → `split_edges` →
`holes_fill` on every boundary edge → `recalc_face_normals`. Verify with counts, not by looking:
0 boundary edges and 0 non-manifold edges means watertight. Stop the cut SHORT of the hinge so
the two halves stay joined at the back — that gives a real hinge and leaves no hole in the body.

**Vendor source stays out of the repo**, same as the niwaki: it lives in
`~/Desktop/Roshambo Reference/models/birds/`. Only derived, reduced output is committed.
The generator that authors our own birds parametrically is
`roblox/tools/blender/bird_familiar.py` — a species is a dict of proportions, so a new bird
is a data edit rather than a new sculpt.


## Procedural river (in-engine, no Blender)

A working, reusable pipeline for flowing water, proven as the up-canyon "Path B" POC
(2026-06-21/22). Pieces, all committed under `roblox/tools/studio/`:

- `riverDraftMarkers.luau` — draggable `workspace.RiverDraft` control points (owner
  drags X/Z = route, Y = height).
- `upcanyonRiverPOC.luau` — Edit builder: Catmull-Rom centerline → EditableMesh swept
  ribbon (normals + local-space verts, [[editablemesh-gotchas]]) → tint/transparency +
  SurfaceAppearance slot → flat along-flow beams (TextureSpeed scroll) → boulders +
  foam.
- `riverFlowAnim.client.luau` — runtime LocalScript: rebuilds the ribbon client-side
  and scrolls its UVs each frame.
- **The system going forward: `ribbonFlowAnim.client.luau`** (generic, tag-driven) —
  animates ANY part with CollectionService tag `FlowRibbon` + attributes `FlowAsset`
  (rbxassetid of the published ribbon mesh) and `FlowSpeed` (tiles/sec). Uses
  `GetTagged` + `GetInstanceAddedSignal`, so replication timing is handled for free
  ([[replication-races]]). Adding a reach = publish mesh → tag the static part + set
  two attributes; no new code. (`channelFlowAnim.client.luau` is kept only as the
  per-reach reference.)

Division of use: ribbons are for **horizontal connectors between pools** (where
FaceCamera beams fail — rapids chutes); pools stay TERRAIN WATER. Flat beams need
Up=cross-stream ([[misc-engine-traps]]). Per-reach workflow, rock placement, and the
fall-dressing recipe (lip rocks, plunge-pool rocks, whitewater bars, foam, splash)
carried in the memory now live with the water as-builts on [[canyon]]; the durable
sizing rule: **size library rocks by ABSOLUTE target, not a multiplier** —
`r.Size = src.Size * (targetMaxStuds/maxDim)` — because `RockLibrary` base sizes vary
wildly (2–9 studs) and multipliers balloon the big ones into a fused mass. A ~10-stud
pool fits ~3 spread rocks. Always surface-snap and embed `+ Size.Y*0.35`.

Water texture options if revisiting (the generate_material water read marbled/stony):
the generated maps persist on the cloud — ZenRiverWater Color `117032050129641` /
Normal `109118604428293`, ZenRiverWater1 `120891936261441`/`99885893776364`,
ZenRiverWater2 `116355033742049`/`85551193696366`, ZenRiverWater3
`131180950523322`/`96495234564862` — or a calmer prompt (near-uniform colour, ripples
in the NORMAL map only), or a hand-picked seamless water normal map. Terrain water
settings the owner picked: `WaterColor` white (255,255,255), `WaterTransparency` 1.0,
`WaterReflectance` 0.6.

## Waterfall VFX (Beam/ParticleEmitter recipe)

From the official Roblox "Create Waterfalls" VFX tutorial
(create.roblox.com/docs/tutorials/use-case-tutorials/vfx/create-waterfalls),
captured 2026-06-22 and reused across the canyon falls. These are
particle/beam overlays layered on top of the procedural-river geometry above —
per-reach fall dressing (lip rocks, plunge-pool rocks, whitewater bars, foam,
splash) lives with the water as-builts on [[canyon]]; this section is the
reusable technique.

**Layering, cliff-top → pool:** outflow beam (foam texture, races to the lip) →
whitewater emitter (aerated spray at the edge) → cascade beams (main + slow
secondary drop, parallax via ZOffset) → splash emitters (dense burst + droplets
at plunge-pool impact) → foam emitter (ripple rings on the surface) → mist
emitters (outward + slow-rising) → a stationary camera-facing rainbow above the
mist.

**Texture asset IDs:** foam beam `4787437624`, fast-drop beam `16808804567`,
dense splash `16829556885`, splash droplets `17082061238`, whitewater
`16808075391`, foam ripples `16811365086`, mist `16830667309`, rainbow
`16828911033`. Per-emitter Size/Transparency/Speed/Acceleration keyframes are
in the tutorial; treat its values as a **starting** point, not a target — they
read too intense/tall at ZenDojo's chute scale (final-ish settings: tutorial
Size ×0.6, Speed ×0.6, accel-Y ×1.3, base Rate ×1.25, then per-spot ×0.85–1.15
jitter, Lifetime per-spot ×0.90–1.08 jitter).

**Tuning dials are independent, not interchangeable:**
- **Frequency** = `Rate` (particles/sec) — how *often* puffs appear. Raising
  Rate alone does not shrink the plumes.
- **Density** = the `Size` keyframe sequence (scale every keypoint + envelope
  together) — how thick each puff reads.
- **Height** = `Speed` (upward launch) + `Acceleration.Y` (more negative pulls
  plumes down faster) + `Lifetime` (longer life travels further before dying).
- **Desync:** `ParticleEmitter` has no phase/offset property, so multiple
  emitters pulse in lockstep by default. Break it by giving each emitter
  slightly different Rate *and* Lifetime (incommensurate periods → permanent
  phase drift); ~0.85–1.15 per-spot factors are enough.

**Flat foam-on-water:** to make a foam-ripple emitter lie flat on the surface
(not billboard toward the camera), use `Orientation = VelocityPerpendicular`
with `EmissionDirection = Top`, `Speed = 0.6–1.0`, `Acceleration = (0,0,0)`,
`SpreadAngle = (0,0)` — the quad orients perpendicular to velocity, so a small
upward velocity yields a horizontal quad. Near-zero Speed (0–0.01) goes nearly
invisible under `VelocityPerpendicular` — it needs a real velocity vector to
orient against. Read the actual terrain water height with
`Terrain:ReadVoxels` before placing (guessing Y leaves foam floating above the
pool). `FaceCamera=true` is fine for the vertical cascade beams but wrong for
flat foam — see [[misc-engine-traps]] for the general Beam-Up-vector rule.

## SDF glyphs (the R/P/S image pipeline)

R/P/S World-Throw glyphs are **uploaded IMAGE assets**, not native UI. Source of truth
is the PWA's `src/components/Symbols.tsx` (○ ring, ─ bar, ∧ chevron). Generated by
`roblox/tools/glyphs/glyphgen.cjs` (dependency-free Node SDF rasteriser → 6 white
PNGs: a `core` + a uniformly-wider `outline` per symbol). Uploaded, tinted at runtime
via `ImageColor3` (2-layer: ink outline behind + gold core front) — recolourable.
`roblox/src/shared/Glyphs.luau` holds `Glyphs.IMAGE = {R/P/S = {core, outline}}` and
`Glyphs.render(parent, symbol, coreColor, outlineColor?)`. Rock +20% / paper −10%.
**∧-up everywhere** — the ∨ pick-button asymmetry was dropped 2026-07-21
([[arena-square]], [[owner-rulings]]).

**Why images, not native UI:** Roblox `UIStroke` draws OUTWARD-only, so a native
ring's keyline came out lopsided and rotated-bar chevron arms wouldn't fuse. Centred
strokes rendered via SDF give symmetric outlines + clean round joins. (ImageMagick
`convert` is x86-only and won't run on the arm64 Mac; the pure-Node rasteriser is the
workaround.)

**Normal maps from photos:** derive from a carving photo's luminance (≈height) →
gradient. Roblox may need the **green channel flipped** (OpenGL vs DX) — verify in
Play, flip if relief inverts. The image→normal + AO-baked-albedo tooling lives in
`roblox/tools/glyphs/` (e.g. `relief_marigold.cjs`, for the ranma panels).

Upload mechanics and moderation behaviour: [[image-moderation]]. EditableMesh
replication limits that shaped this: [[rojo-meshpart-rbxm]], [[editablemesh-gotchas]].
