---
shelf: practice
updated: 2026-08-31
---

# Blender Pipeline

How assets get MADE, wherever the making happens: Blender→FBX import (static and SKINNED),
the procedural river, the waterfall VFX recipe, and the SDF glyph rasteriser. Tools live in
`roblox/tools/blender/`, `roblox/tools/studio/`, `roblox/tools/textures/` and
`roblox/tools/glyphs/`.

⚠ **THIS PAGE IS TRAPS AND TECHNIQUES, NOT PROCESS.** How we WORK in Blender — what counts as one
step, who judges shape, when a Studio trip is earned, explore-then-codify — is
[[blender-working-rules]]. The separation is deliberate and was missing until 2026-08-30: 500 lines
of engine facts here and nothing anywhere saying when to stop.

⚠ **The name is narrower than the page.** This said "pipelines that feed Roblox from OUTSIDE
the engine" while its own contents list an IN-engine river — a scope statement contradicting
its own table of contents. The subject is asset *production*; two of these pipelines never
open Blender. Corrected 2026-08-27 rather than split, because neither [[build-recipes]] (a
canyon-geometry gate) nor a new page is a better home for a river technique than the page a
reader already goes to for "how do I make the thing".

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
across parts is worth engineering** — N×3 uploads become 3). ⚠ That set is a real
property, `SurfaceAppearance.TexturePack`, and it appears in a saved `.rbxm` as a
**fifth asset id** beyond the four maps — measured 2026-08-29 on the karasu, where it
is identical across body and wings, which is the proof the sharing worked. It reads
empty from a Luau property access, so a session that finds the id in the file and
greps the live instance for it will conclude the asset is corrupt. It is not.
`TextureID` stays empty,
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

**⚠ THE BLENDER MCP'S CONTEXT BREAKS THREE DIFFERENT OPERATORS, ALL THE SAME WAY.** The MCP
execs code in a context with no window, so any operator that reaches for one fails — and each
failure looks like a different bug until you have seen all three:

- **`bpy.ops.export_scene.fbx(use_selection=True)`** — that context has no `selected_objects`.
- **`bpy.ops.import_scene.fbx`** on a file containing an ARMATURE — the importer calls
  `mode_set(mode='EDIT')` while building the skeleton and dies with *"Context missing active
  object"*. Setting `view_layer.objects.active` first does **not** fix it.
- **`bpy.ops.object.mode_set`** itself, so `armature.data.edit_bones` is unreachable and no bone
  can be renamed, added or re-rolled.

**One fix covers all three** — wrap the call in a `temp_override` carrying a real window:

```python
win = bpy.context.window_manager.windows[0]
scr = win.screen
area = next((a for a in scr.areas if a.type == 'VIEW_3D'), scr.areas[0])
with bpy.context.temp_override(window=win, screen=scr, area=area, region=area.regions[-1],
                               scene=bpy.context.scene, view_layer=bpy.context.view_layer):
    bpy.ops.import_scene.fbx(filepath=fbx)
```

For export you can also just load only what you want into an empty scene and pass
`use_selection=False`.

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

### ⚠ Roblox's limits on a skinned rig — three things that DO NOT work

Found the hard way building the familiar, each after being designed around:

**`Bone.Transform` DISCARDS SCALE.** Measured: set a bone's Transform to a CFrame carrying scale
0.06 and read it back — the CFrame itself carries 0.06, the property returns 1.0000, and the
rendered part does not change size at any value. A bone transform is *rigid* by definition;
rotation and translation survive, scale cannot. A whole "collapse the wings to hide them" design
was built and committed on the assumption it worked, and its tests passed because they only
asserted the number the function returned, never that Roblox honoured it.

**A single rigid bone cannot shorten, so it cannot FOLD anything.** Swept back 88°, a wing's tip
still reached 0.37 studs against a 0.112-stud body half-width — it swings forward past the head
rather than tucking. A real wing folds at the wrist. **Two bones per wing** (shoulder + wrist,
hinged at ~46% of span) does work: 0.467 spread → 0.093 folded, verified in Roblox.

**Geometry cannot be hidden by moving it.** Folding plus translating still left 93 of 208 wing
vertices outside the body. If something must vanish completely, it has to be a **separate
MeshPart** with `Transparency = 1`. That part can still be skinned, so it keeps its bones.

### ⚠ A BONE SURVIVES TO ROBLOX ONLY IF IT DEFORMS A VERTEX — two filters, both silent

Found 2026-08-28 on the karasu's eyes, after an import that "succeeded" three times. A bone can
be dropped at either end of the trip, and neither end reports it: the export succeeds, the mesh
is fine, and the loss only shows as a `nil` from a lookup by name — at runtime, in play.

**Filter 1, on export: `use_armature_deform_only=True` drops bones with NO WEIGHTS ON THE MESH
BEING EXPORTED** — not merely bones flagged non-deform. `eye_R`/`eye_L` were flagged
`use_deform = True` and carried a position rather than any weights, so the flag culled them: 21
bones in Blender, 15 in the imported body. Set it **`False`** whenever a rig carries position-only
bones.

**Filter 2, on import: Roblox strips bones that influence nothing, and no flag turns that off.**
Fixing filter 1 changed nothing visible, and the proof was the asset id — the re-imported body and
wings came back with the *same* `rbxassetid` as the previous import. Roblox content-hashes the
mesh, so an identical id means identical uploaded data: a weightless bone adds nothing the
importer records. **A bone that moves no vertex cannot reach Roblox.** If you want one there, give
it geometry to hold; if nothing needs it, delete it from the rig rather than fighting for it.

**And the trap underneath both: a vertex group is NOT skinning.** `KarasuEyes` was built with a
`joint4` group and left unparented, on the belief that putting the armature in the scene is what
makes a mesh skinned. It is not — Blender's FBX exporter writes a `Skin` deformer only for a mesh
carrying an **ARMATURE MODIFIER**. Without it the group is inert, the file has no deformer, and
the mesh imports static with zero bones: the eyes would have hung in world space ignoring every
head turn. Diagnose from the file, not the exporter's success message —
`strings x.fbx | grep -c Skin` is 0 for a static mesh and ≥1 for a skinned one.

### ⚠ An imported MeshPart's CFrame and PivotOffset are IMPORTER ARTEFACTS

This trap bit three times in one file, wearing a different hat each time:

- **`PivotTo` bakes a rotation.** (§5 above.)
- **A clone inherits the template's rotation.** `UguisuBody` imported with LookVector `(0, 1, 0)`
  — nose straight up. Any code that reads a part's existing CFrame as a baseline inherits it. Set
  an explicit rotation on clone; never carry one forward.
- **`PivotOffset` carries the FBX axis conversion** — measured `(90, 0, -180)` on every part from
  a single export. So `PivotTo(identity)` restores the nose-up attitude you just fixed.

**The rule:** read POSITION from `PivotOffset` when you need the authored origin — that is
genuinely useful, it is the offset from the bbox centre to the point the mesh was exported around
— and never inherit either one's ROTATION. Take rotation from whatever you are aiming the object
with.

**Seat by the authored origin, not the bounding-box centre.** `part.CFrame = target` puts the
CENTRE there. The uguisu's centre rides 0.236 studs above its feet, more than half its height, so
every perched bird sank into its perch. `target * CFrame.new(-part.PivotOffset.Position)` puts the
authored origin there instead — measured accurate to 0.021 studs, and two halves of a split mesh
then agree to 0.00000 studs at a shared bone.

**Splitting one skinned mesh into two parts** (body + wings) works and keeps both skinned. Export
both seated on the SAME origin — seat the rig once, on one half, and let the other inherit it —
or they mate with an offset that looks like a rigging bug.

**Vendor source stays out of the repo**, same as the niwaki: it lives in
`~/Desktop/Roshambo Reference/models/birds/`. Only derived, reduced output is committed.
The generator that authors our own birds parametrically is
`roblox/tools/blender/bird_familiar.py` — a species is a dict of proportions, so a new bird
is a data edit rather than a new sculpt.

⚠ **THE RETARGET ITSELF MUST BE A SCRIPT, AND THE UGUISU'S WAS NOT.** Its retarget existed only
as `probe/uguisu_retarget.blend` on one machine, so the second bird had to rediscover every step
from prose. `roblox/tools/blender/karasu_retarget.py` is the karasu's, and it is re-runnable
end to end: `run()` goes vendor blend → two rigged meshes, `verify_rig()` proves the rig by
driving it, `bake_and_finish()` writes both FBXs, the ColorMap and the working blend. Treat that
as the standard for bird #3.

### Authoring traps found building the karasu (2026-08-26)

**⚠ A WING IS NOT A COMB — AND NEITHER IS A TAIL, NOR A FOLDED WING.** `spread_wing.py` records
this for the spread wing: separate radiating feathers fan apart faster than they are wide, so
every gap opens into a triangle. The karasu met the identical failure twice more. A tail built
from seven overlapping graduated blades (the way the uguisu's is) stepped into a visible
**staircase** at 1.64 studs, and a folded wing built as a covert plate plus three separate
primaries read as **loose slats laid over the tail**. Both fixes are the same one: ONE
continuous surface whose OUTLINE does the identifying. The uguisu gets away with blades only
because it is a third the size and the steps fall inside a texel — so this scales in, and bird
#3 should start from one surface rather than rediscover it.

**⚠ A FOLDED WING MUST BE SHRINK-WRAPPED TO THE FLANK, AND A NEAREST-VERTEX PROBE IS NOT GOOD
ENOUGH.** Placed at a constant x against a round body, the plate stands off as a flat fin with
daylight behind it — obvious from directly above and invisible from the side. RAYCAST the body
at every vertex (`obj.ray_cast`); a 555-vertex body is far too sparse to sample by proximity.
Then taper the standoff to **zero at the plate's top, bottom and leading edges** so those die
into the flank and only the trailing edge breaks the silhouette — the [[flush-outside-edges]]
rule, applied to a feather group.

**⚠ AND CHECK THE PLATE'S TOP EDGE CLEARS THE BACK LINE.** At two stations it equalled the
body's own `zmax`, so the left and right plates met along the spine and the bird grew a Y-shaped
crease down its back. The mantle has to show between the two wings.

**⚠ A PLANAR UV PROJECTION COLLAPSES A TWO-SIDED PLATE'S SHELLS ONTO EACH OTHER.** Every plate
here — tail, folded wing, wing membrane — is closed and two-sided, and projecting it down one
axis puts its inward- and outward-facing shells on the same texels. The bake then paints both
and the last triangle wins, which showed as **pale rectangular patches** where the inward shell
had overwritten the outward one (they get opposite countershading, so they are not the same
colour). `spread_wing.py` already carried the fix for one wing — *"upper and lower shells split
the region's height, with a gap so bilinear sampling cannot pull one into the other"* — and it
applies to every plate.

**⚠ CREATE A BMESH CUSTOM-DATA LAYER BEFORE THE OP, NOT AFTER.** Adding a layer reallocates
custom data, so writes through references taken beforehand land nowhere. The tag reported success
and read back as zero on every face.

**⚠ `bmesh.ops.holes_fill` UNDER-REPORTS THE FACES IT CREATED.** It returned ONE face for two
holes it demonstrably closed (0 boundary edges afterwards). Tag fill faces by GEOMETRY — a fill
face is exactly one all of whose vertices lie on the cut plane — not by the op's return value.

**⚠ AND DO NOT FIND THE GAPE BY A GEOMETRIC GUESS EITHER.** "Forward of the hinge and facing up
or down" also catches the OUTSIDE of the bill's top and bottom, which meet near the gape line.
That reprojected the whole bill into the gape's texture block and painted a raw red stripe down
the culmen of a bird that is meant to be black.

**⚠ A SILENT UV CAP IS A SILENT RESOLUTION LOSS.** A vendor unwrap already claims ~41% of the
atlas in fragments, so a block request that does not fit is normal. `UVAllocator` steps the size
down rather than failing — and RECORDS what it actually gave, because "no silent caps" applies to
texture space as much as to coverage.


## ⚠ A BONE'S LOCAL AXES ARE NOT THE BODY'S — `CFrame.Angles(pitch, yaw, 0)` is a guess

Measured 2026-08-31 on `MejiroBody`, each bone-local axis written in body space (body X = right,
Y = up, Z = length):

| bone | local X | local Y | local Z |
|---|---|---|---|
| `joint3` (neck) | −body Y | −body Z | **+body X** |
| `joint4` (head) | −body Z | +body Y | **+body X** |

So pitch is slot **Z** on both neck bones. `BirdController` and `watchWingbeat` had written
`CFrame.Angles(pitch, yaw, 0)` since the birds shipped: the pitch went into a yaw on the neck and a
roll on the head, the yaw rolled the neck, and **the song's head-lift never fired once on any
bird**. The two bones also yawed against each other (−body Y against +body Y), producing an S-bend
that read as a side-to-side wobble and was mistaken for a damping fault.

⚠ **NOTHING FLAGS THIS, BECAUSE THE WRONG ANSWER STILL LOOKS ALIVE.** A head that yaws and rolls
when you asked for pitch is still a moving head. It took an owner saying "it does NOT lift up its
beak" to surface it.

**Read the axes off the rig**: `BirdRig.axesOf(bone, body)` converts a body-space direction into
bone-local space via `BirdFlight.toBoneSpace` (pure, so Lune can test it — Lune has no `CFrame`),
and `BirdRig.pose` builds the Transform with `CFrame.fromAxisAngle`, yaw first so a bird that has
looked left raises its beak along the way it faces. Resolved once at spawn; the axes are constants
of the armature. A hardcoded slot permutation would be the same silent failure on the next rig.

## Recipe: exporting a scaled sibling (a second bird from one authored mesh)

The mejiro is the uguisu at 0.773. Do this in Blender, **never** by resizing the MeshPart in Studio.

1. **`save_as_mainfile` to a scratch path FIRST.** It switches the session off the authored blend,
   so nothing that follows can reach `art/` — a stronger guarantee than remembering not to save.
2. `S = target_length / body_data_y_span`. The uguisu's span is 0.82805 and matches `bodyLength`.
3. **Transform the DATA, never the object**: `o.data.transform(Matrix.Scale(S, 4))` for every mesh
   bound to the rig, and `arm.data.transform(M)` for the armature. An object-level scale rides on
   the armature and `Bone.Transform` **discards scale** in Roblox — the bird imports at the right
   size and animates at the wrong one.
4. **Do not re-centre.** `normalise_size()` also re-seats feet at z = 0, which would put the pivot
   at the feet and make the sibling behave unlike the bird it is. Leaving the origin alone keeps
   them identical up to scale, so they share one measured seat number.
5. Rename the objects, then `export(part, path, textures=False)` — the shared-mesh trap.
6. Verify the round trip before anyone imports: **21 bones on both halves** and `materials=NONE`.

⚠ **UVs DO NOT MOVE UNDER A VERTEX SCALE**, so an already-baked colormap stays valid and does not
need re-uploading. Re-bakes are safe too: `bake()` derives `landmark_scale` from the mesh's own span
against `ref_length`, so landmarks follow the new size on their own.

⚠ **`import_scene.fbx` FAILS UNDER THE MCP WITHOUT A FULL WINDOW OVERRIDE** — its armature branch
calls `mode_set()`, whose poll needs an active object, and it dies mid-hierarchy with
`Context missing active object`. Use the same `temp_override(window, screen, area, region, …)` that
`export()` uses. An empty startup file is not enough on its own.

## ⚠ RESIZING A MESHPART DOES NOT RESIZE ITS `PivotOffset`

The mejiro is the uguisu's mesh scaled to 0.773 in Studio. The mesh scaled; the pivot did not, and
the two carry a byte-identical `PivotOffset.Position` of −0.215. Measured with each pivot placed at
y = 100, reading the rendered box bottom:

| part | centre | size Y | bottom | offset from pivot |
|---|---|---|---|---|
| `KarasuBody` | 100.449 | 0.897 | 100.000 | **0.000** — the pivot *is* the feet |
| `UguisuBody` | 100.215 | 0.472 | 99.979 | −0.021 |
| `MejiroBody` | 100.215 | 0.365 | 100.033 | **+0.033**, the other way |

Both seating paths placed the **pivot** on the perch and a comment cited "feet land within 0.021 of
the target" as verification — that 0.021 was the uguisu's own residual, accepted once and then
treated as a property of all birds. Two birds sharing a mesh, a rig and a pivot now land 0.054
apart, 15% of the mejiro's height, and the error grows with the scale factor.

**Seat by the pivot** — the authored origin — and that was right before any of it. Measured against
the owner's eye on a flat plank at kasagi height, pivot-seating lands the karasu exactly and the
uguisu within 0.002 studs. Only the resized bird missed.

⚠ **TWO MODELS WERE FITTED TO THE MEJIRO ALONE AND EACH BROKE A SPECIES THAT HAD BEEN CORRECT.**
First the mesh bounds — measured right to 0.004 studs and read as a bird sunk into the rail. Then a
"toe droop" clearance scaled by body length, which predicted the *larger* uguisu wanted *more* lift;
put side by side, it wanted none. Both had passing tests and mutation-proven constants. Neither had
a mechanism anyone had verified, and the tests only confirmed arithmetic that was already assumed.

⚠ **THE MEASUREMENT THAT SETTLED IT WAS THREE SPECIES ON ONE PLANK AT ONCE.** One bird at a time
cannot distinguish "this bird is wrong" from "the rule is wrong", and three rounds were spent
before that was done. `BirdSpecies.seatNudge` now carries only the eye-measured residual — 0.000
karasu, −0.002 uguisu and mejiro — and a value larger than a hair is a smell, not a setting.

**Root cause, and the actual fix**: the mejiro was the uguisu's MeshPart *resized inside Studio*,
so it alone needed a 0.0164 correction. It is now exported from Blender at its own 0.640 and the
special case is gone. See the recipe below.

⚠ **`Bone.WorldCFrame` IS NOT A USABLE MEASUREMENT ON A RESIZED MESHPART.** The mejiro and the
uguisu report their lowest bone at an identical −0.093 from the pivot despite a 0.773 scale factor
between them, so bone positions read back unscaled. Measure feet from `Size`, not from bones.

## ⚠ MIRRORING A MEASUREMENT ASSUMES A SYMMETRY THE MESH DOES NOT HAVE

Found 2026-08-28 on the karasu's eyes. Owner: *"the eye is very visible on one side of the head
and missing on the other."*

Two independent faults, and they stack:

- **The surface was measured on ONE side and mirrored.** `bird_familiar._eyes` builds both eyes
  from a single `x`, which is correct only on a symmetric head. Measured at the karasu's eye
  station the surface stands at **0.0514 on the right against 0.0610 on the left**, and the
  vendor head carries **120 vertices on one side against 163** on the other. Purchased models are
  not mirror-symmetric, and none of ours have been.
- **A single raycast is not the surface.** The ray struck 0.0379 where vertices in the same
  footprint reached 0.0514 — exact for the triangle it hit, and misleading on a 555-vertex head.
  Seated against that dip the eyeball vanished INSIDE the skull at every zoom.

**The rule:** anything seated against a surface must measure **per side**, and must clear the
**footprint** it occupies rather than the point at its centre. Verify by asserting the protrusion
on BOTH sides, not by looking at one and assuming — that assertion is what turned "it looks fine"
into "both sides are proud by exactly 0.0108".

## ⚠ THE MCP EXECS A SCRIPT, IT DOES NOT IMPORT IT — so `__file__` is undefined

Found 2026-08-28. Every helper import in `karasu_retarget.py` is written as

```python
here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else <fallback>
```

and **the fallback is the branch actually taken, every time**, because the Blender MCP `exec`s the
file's source rather than importing it as a module. That makes the fallback path load-bearing
where it reads as a safety net.

⚠ **All three of them pointed into `.worktrees/assets/`** — the asset thread's worktree, retired
2026-08-26 and slated for deletion ([[parallel-threads]]). So the karasu's shared builders AND its
texture baker were being loaded from a copy nobody maintains, and the script would have broken
outright the moment that worktree was removed. Checked when found: `bird_familiar.py` and
`bake_bird_texture.py` were still byte-identical between the two, so nothing had gone wrong yet.
**That was luck** — `spread_wing.py` had already diverged, and escaped mattering only because
nothing in the karasu path loads it.

**The rule:** a fallback path in a script the MCP runs is not a fallback, it is the path. Point it
at the repo, and treat any reference to a worktree in committed code as a defect.

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
