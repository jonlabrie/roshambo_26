---
shelf: practice
updated: 2026-08-15
---

# Blender Pipeline

The asset pipelines that feed Roblox from outside the engine: Blender→FBX import, the
in-engine procedural river technique, and the SDF glyph rasteriser. Tools live in
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
ZenRiverWater/1/2/3 map asset IDs persist on the cloud (Color/Normal pairs, in the
raw-layer memory of this page's history); a calmer prompt (near-uniform colour,
ripples in the NORMAL map only); or a hand-picked seamless water normal map. Terrain
water settings the owner picked: `WaterColor` white (255,255,255),
`WaterTransparency` 1.0, `WaterReflectance` 0.6.

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
