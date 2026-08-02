# bake_clump_tree.py — dense-foliage tree -> clump-card impostor (spec
# 2026-07-25-square-canopy-foliage; built for the sugi/Japanese-cedar set).
#
# WHY: export_tree.py thins foliage by deleting whole cards. That works when a source
# uses few LARGE cards (the niwaki: ~16k fat tufts, 43% kept still reads full), but the
# sugi is built from ~22k SMALL needle sprays — thinning to a scatter-friendly budget
# keeps 2.4% of them and the tree goes bald.
#
# WHAT: the standard impostor/clump-card technique. Cluster the source sprays in space,
# orthographically BAKE a few representative clusters to an RGBA atlas (alpha from the
# vendor opacity map), then rebuild the canopy as CROSSED QUADS — 3 intersecting planes
# per clump, each carrying a baked clump image. Roblox MeshParts cannot billboard toward
# the camera, hence crossed planes rather than single cards: the clump reads as volume
# from any angle.
#
# RESULT: a FULL canopy at ~6 tris per clump (200 clumps ~= 1.2k tris) instead of a bald
# one at 3k. Reusable for any dense-foliage source.
#
# Usage (headless):
#   /Applications/Blender.app/Contents/MacOS/Blender --background --python \
#     bake_clump_tree.py -- <src.fbx> <object> <foliage mat key> <clump_cells> \
#     <trunk_tris> <height_studs> <out.fbx>
#
#   clump_cells — target clump count (grid resolution is derived from it).
#
# IN STUDIO after import, on the FOLIAGE MeshPart:
#   * SurfaceAppearance.AlphaMode = Transparency
#   * MeshPart.DoubleSided = TRUE  <-- easy to miss and costly: foliage cards are
#     single-sided planes, so with the Roblox default (false) every back-facing card is
#     CULLED and the canopy silently loses a large share of its cards from any given
#     viewpoint. Costs no triangles.
#
# (original note) File -> Import 3D, then set the foliage SurfaceAppearance.AlphaMode =
# Transparency (the atlas carries alpha in its ColorMap).

import bpy, bmesh, sys, math, os, glob, functools
import numpy as np
import mathutils

print = functools.partial(print, flush=True)

argv = sys.argv[sys.argv.index("--") + 1:]
FBX, OBJ, FOLIAGE_KEY = argv[0], argv[1], argv[2]
TARGET_CLUMPS, TRUNK_TRIS = int(argv[3]), int(argv[4])
HEIGHT_STUDS, OUT_FBX = float(argv[5]), argv[6]
# optional tuning, so density and lighting can be swept without editing the file:
#   argv[7] planes per clump   argv[8] world strength   argv[9] card frame multiplier
PLANES_OVERRIDE = int(argv[7]) if len(argv) > 7 else None
WORLD_STRENGTH = float(argv[8]) if len(argv) > 8 else 1.6
CARD_MULT = float(argv[9]) if len(argv) > 9 else 1.0

ATLAS_VARIANTS = 4        # distinct baked clump images (2x2 atlas)
TILE = 1024               # px per variant
PLANES_PER_CLUMP = 3      # crossed planes
CAM_FRAME = 2.2           # bake ortho_scale, as a multiple of clump radius
CARD_FRAME = CAM_FRAME / 2  # card half-size: keeps one texel = one world unit
MIN_ISLAND, MAX_TRUNK_ISLANDS = 200, 10

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)

tree = bpy.data.objects[OBJ]
wm = tree.matrix_world.copy()
for o in list(bpy.data.objects):
    if o.name != OBJ:
        bpy.data.objects.remove(o, do_unlink=True)
tree.parent = None
tree.matrix_world = wm
bpy.ops.object.select_all(action="DESELECT")
tree.select_set(True)
bpy.context.view_layer.objects.active = tree
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")

foliage, trunk = None, None
for o in list(bpy.data.objects):
    if any(m and FOLIAGE_KEY.lower() in m.name.lower() for m in o.data.materials):
        foliage = o
    elif trunk is None:
        trunk = o
    else:
        bpy.ops.object.select_all(action="DESELECT")
        trunk.select_set(True)
        o.select_set(True)
        bpy.context.view_layer.objects.active = trunk
        bpy.ops.object.join()
if foliage is None or trunk is None:
    raise SystemExit(f"ABORT: could not split on key {FOLIAGE_KEY!r}")
# Blender invalidates Python object references across bpy.data.objects.remove() — the
# bake loop removes temp objects, which silently corrupted `trunk` (it started reporting
# a 0.012 scale and exported 100x small). Work by NAME and re-fetch after every removal.
trunk.name = "TRUNK_WORK"
foliage.name = "FOLIAGE_WORK"


# Bake each object's transform into its MESH now, while the transforms are still
# trustworthy, and zero the object matrices. From here everything (clustering, card
# building, trunk culling, final scaling) works in ONE shared space, so a spurious
# object scale appearing later cannot corrupt geometry or separate the two meshes.
for _o in (trunk, foliage):
    _o.data.transform(_o.matrix_world)
    _o.matrix_world = mathutils.Matrix.Identity(4)
    _o.data.update()


def T():
    return bpy.data.objects["TRUNK_WORK"]


def F():
    return bpy.data.objects["FOLIAGE_WORK"]


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)



# ---- textures: repoint to the vendor's sibling maps folder ------------------
tex_by_name = {}
for td in [os.path.dirname(FBX)] + glob.glob(os.path.join(os.path.dirname(FBX), "*")):
    if os.path.isdir(td):
        for f in os.listdir(td):
            tex_by_name.setdefault(f.lower(), os.path.join(td, f))
for img in bpy.data.images:
    base = os.path.basename(img.filepath).lower()
    if base in tex_by_name:
        img.filepath = tex_by_name[base]
        img.reload()

# wire the opacity map into alpha so the BAKE cuts out needle silhouettes
fol_mat = foliage.data.materials[0]
nt = fol_mat.node_tree
principled = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
opac_path = next((v for k, v in tex_by_name.items() if "opa" in k and "leaves" in k), None)
if opac_path is None:
    opac_path = next((v for k, v in tex_by_name.items() if "opa" in k), None)
if principled and opac_path:
    otex = nt.nodes.new("ShaderNodeTexImage")
    otex.image = bpy.data.images.load(opac_path)
    otex.image.colorspace_settings.name = "Non-Color"
    nt.links.new(otex.outputs["Color"], principled.inputs["Alpha"])
for attr, val in (("blend_method", "CLIP"), ("surface_render_method", "DITHERED")):
    try:
        setattr(fol_mat, attr, val)
    except Exception:
        pass

# ---- cluster foliage islands into clumps -----------------------------------
bm = bmesh.new()
bm.from_mesh(foliage.data)
bm.faces.ensure_lookup_table()
seen, islands = set(), []
for f in bm.faces:
    if f.index in seen:
        continue
    stack, comp = [f], []
    seen.add(f.index)
    while stack:
        cur = stack.pop()
        comp.append(cur)
        for e in cur.edges:
            for nf in e.link_faces:
                if nf.index not in seen:
                    seen.add(nf.index)
                    stack.append(nf)
    islands.append(comp)

centroids = []
for comp in islands:
    acc = mathutils.Vector((0, 0, 0))
    n = 0
    for f in comp:
        for v in f.verts:
            acc += v.co
            n += 1
    centroids.append(acc / max(n, 1))

lo = mathutils.Vector((min(c.x for c in centroids), min(c.y for c in centroids), min(c.z for c in centroids)))
hi = mathutils.Vector((max(c.x for c in centroids), max(c.y for c in centroids), max(c.z for c in centroids)))
span = hi - lo
# grid cell sized so occupied cells ~= TARGET_CLUMPS (canopy fills ~35% of its bbox)
vol = max(span.x * span.y * span.z, 1e-6)
cell = (vol * 0.35 / max(TARGET_CLUMPS, 1)) ** (1 / 3)
buckets = {}
for idx, c in enumerate(centroids):
    key = (int((c.x - lo.x) / cell), int((c.y - lo.y) / cell), int((c.z - lo.z) / cell))
    buckets.setdefault(key, []).append(idx)
print(f"CLUSTERED {len(islands)} sprays -> {len(buckets)} clumps (cell {cell:.2f})")

clumps = []
for key, idxs in buckets.items():
    pts = [centroids[i] for i in idxs]
    ctr = sum(pts, mathutils.Vector((0, 0, 0))) / len(pts)
    rad = max((p - ctr).length for p in pts) if len(pts) > 1 else cell * 0.4
    clumps.append({"idxs": idxs, "ctr": ctr, "rad": max(rad, cell * 0.35)})
clumps.sort(key=lambda c: -len(c["idxs"]))

# ---- bake ATLAS_VARIANTS representative clumps to an RGBA atlas ------------
scene = bpy.context.scene
scene.render.engine = "CYCLES"
# TEXTURE DATA, NOT A PHOTOGRAPH. Blender's default view transform is AgX, which
# desaturates and darkens on save — measured 2026-08-02 it pulled the sugi atlas from
# the source's [102,107,32] to [84,80,14], muddy and yellow, and every species came out
# duller than its own leaf map. Baking a colour map means writing shaded albedo through
# unchanged, so the transform must be Standard.
try:
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
except Exception as _e:
    print("WARN could not set Standard view transform:", _e)
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = TILE
scene.render.resolution_y = TILE
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

world = bpy.data.worlds.new("BakeWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = WORLD_STRENGTH
# NOTE: a flat white world bakes NO self-shadowing, so the clump reads brighter and
# flatter than the source tree, whose cards shade and occlude one another.
scene.world = world

cam_data = bpy.data.cameras.new("BakeCam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("BakeCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

trunk.hide_render = True
foliage.hide_render = True
out_dir = os.path.dirname(OUT_FBX)
os.makedirs(out_dir, exist_ok=True)
base_name = os.path.splitext(os.path.basename(OUT_FBX))[0]
tmp_dir = os.path.join(out_dir, "_bake")
os.makedirs(tmp_dir, exist_ok=True)

# pick variants spread through the size distribution (dense -> medium)
picks = [clumps[int(i * len(clumps) / (ATLAS_VARIANTS * 2))] for i in range(ATLAS_VARIANTS)]
tiles = []
for vi, clump in enumerate(picks):
    tmp_mesh = bpy.data.meshes.new(f"clump{vi}")
    tmp_obj = bpy.data.objects.new(f"clump{vi}", tmp_mesh)
    scene.collection.objects.link(tmp_obj)
    tb = bmesh.new()
    vmap = {}
    keep_faces = set()
    for i in clump["idxs"]:
        keep_faces.update(f.index for f in islands[i])
    for f in bm.faces:
        if f.index not in keep_faces:
            continue
        verts = []
        for v in f.verts:
            if v.index not in vmap:
                vmap[v.index] = tb.verts.new(v.co)
            verts.append(vmap[v.index])
        try:
            nf = tb.faces.new(verts)
            nf.material_index = 0
        except ValueError:
            pass
    tb.verts.index_update()
    # copy UVs so the needle texture shows
    src_uv = bm.loops.layers.uv.active
    dst_uv = tb.loops.layers.uv.new("UVMap")
    src_faces = {f.index: f for f in bm.faces if f.index in keep_faces}
    for tf, sfi in zip(tb.faces, sorted(src_faces.keys())):
        sf = src_faces[sfi]
        for tl, sl in zip(tf.loops, sf.loops):
            tl[dst_uv].uv = sl[src_uv].uv
    tb.to_mesh(tmp_mesh)
    tb.free()
    tmp_mesh.materials.append(fol_mat)

    ctr, rad = clump["ctr"], clump["rad"]
    cam_data.ortho_scale = rad * CAM_FRAME
    # NEAR CLIP MUST TRACK THE SCALE. These trees are exported at Roblox scale (1 stud =
    # 0.01), so a 20-stud tree is 0.2 units and a clump radius is ~0.01 — putting the
    # camera at rad*8 = 0.08, INSIDE Blender's default 0.1 near plane. The clump is then
    # clipped away and the tile renders empty. Measured 2026-08-02: three of four atlases
    # came out 0.00% coverage and their impostors rendered as blank cards; only the sugi
    # baked, purely because its larger cell put the camera at 0.16.
    cam_data.clip_start = max(rad * 0.01, 1e-6)
    cam_data.clip_end = max(rad * 100.0, 1.0)
    cam.location = ctr + mathutils.Vector((0, -rad * 8, 0))
    cam.rotation_euler = (math.radians(90), 0, 0)
    path = os.path.join(tmp_dir, f"tile{vi}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    tiles.append(path)
    bpy.data.objects.remove(tmp_obj, do_unlink=True)
    print(f"BAKED tile{vi} ({len(clump['idxs'])} sprays, r={rad:.2f})")

trunk, foliage = T(), F()  # re-fetch: the bake loop removed temp objects

# assemble 2x2 atlas
atlas = np.zeros((TILE * 2, TILE * 2, 4), dtype=np.float32)
for vi, path in enumerate(tiles):
    img = bpy.data.images.load(path)
    px = np.empty(TILE * TILE * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    t = px.reshape(TILE, TILE, 4)
    r, c = vi // 2, vi % 2
    atlas[r * TILE:(r + 1) * TILE, c * TILE:(c + 1) * TILE] = t
# ALPHA BLEED: transparent pixels come out of the render as BLACK rgb. Bilinear
# filtering then samples that black at cutout edges and paints dark halos (and whole
# dark cards at distance/mip levels). Flood the colour of opaque neighbours outward into
# the transparent region so every sampled texel carries plausible foliage colour.
rgb, a = atlas[:, :, :3], atlas[:, :, 3]
mask = a > 0.02
for _ in range(6):
    if mask.all():
        break
    src_rgb = np.where(mask[:, :, None], rgb, 0.0)
    src_w = mask.astype(np.float32)
    acc = np.zeros_like(src_rgb)
    accw = np.zeros_like(src_w)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
        acc += np.roll(np.roll(src_rgb, dy, axis=0), dx, axis=1)
        accw += np.roll(np.roll(src_w, dy, axis=0), dx, axis=1)
    grow = (~mask) & (accw > 0)
    rgb[grow] = (acc[grow] / accw[grow][:, None])
    mask = mask | grow
atlas[:, :, :3] = rgb  # alpha channel untouched: silhouettes unchanged
print(f"ALPHA-BLEED filled {int((~(a > 0.02)).sum())} transparent texels with neighbour colour")

atlas_img = bpy.data.images.new(base_name + "_clumps", TILE * 2, TILE * 2, alpha=True)
atlas_img.pixels.foreach_set(atlas.reshape(-1))
atlas_path = os.path.join(out_dir, base_name + "_clumps.png")
atlas_img.filepath_raw = atlas_path
atlas_img.file_format = "PNG"
atlas_img.alpha_mode = "STRAIGHT"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
atlas_img.save_render(filepath=atlas_path, scene=scene)
print(f"ATLAS {atlas_path} {TILE * 2}x{TILE * 2}")

# ---- rebuild canopy as crossed quads ---------------------------------------
bm.free()
card_mesh = bpy.data.meshes.new(base_name + "_cards")
card_obj = bpy.data.objects.new(base_name + "_cards", card_mesh)
scene.collection.objects.link(card_obj)
cb = bmesh.new()
uv_layer = cb.loops.layers.uv.new("UVMap")

state = 20260725


def rnd():
    global state
    state = (1103515245 * state + 12345) % 2147483648
    return state / 2147483648


UV_CELLS = [(0.0, 0.5), (0.5, 0.5), (0.0, 0.0), (0.5, 0.0)]  # (u0, v0) of each tile
for clump in clumps:
    # THE CARD MUST MATCH THE BAKE FRAME OR THE IMAGE IS STRETCHED. The tile was
    # rendered with ortho_scale = rad*CAM_FRAME, i.e. a half-width of rad*CAM_FRAME/2,
    # so a card built at 1.5*rad draws that image 1.36x oversized and the canopy reads
    # as giant blobs (user, 2026-08-02: "wildly oversized foliage images"). Clumps still
    # knit together because their radii already overlap in space — not the card's job.
    ctr, rad = clump["ctr"], clump["rad"] * CARD_FRAME * CARD_MULT
    tile = UV_CELLS[int(rnd() * ATLAS_VARIANTS) % ATLAS_VARIANTS]
    base_yaw = rnd() * math.pi
    _planes = PLANES_OVERRIDE or PLANES_PER_CLUMP
    for p in range(_planes):
        yaw = base_yaw + p * math.pi / _planes
        tilt = (rnd() - 0.5) * 0.5
        rot = mathutils.Euler((tilt, 0, yaw), "XYZ").to_matrix()
        corners = [
            mathutils.Vector((-rad, 0, -rad)),
            mathutils.Vector((rad, 0, -rad)),
            mathutils.Vector((rad, 0, rad)),
            mathutils.Vector((-rad, 0, rad)),
        ]
        verts = [cb.verts.new(ctr + rot @ c) for c in corners]
        f = cb.faces.new(verts)
        u0, v0 = tile
        uvs = [(u0, v0), (u0 + 0.5, v0), (u0 + 0.5, v0 + 0.5), (u0, v0 + 0.5)]
        for loop, uv in zip(f.loops, uvs):
            loop[uv_layer].uv = uv
cb.normal_update()
cb.to_mesh(card_mesh)
cb.free()

card_mat = bpy.data.materials.new(base_name + "_leaves")
card_mat.use_nodes = True
cnt = card_mat.node_tree
cp = next(n for n in cnt.nodes if n.type == "BSDF_PRINCIPLED")
ctex = cnt.nodes.new("ShaderNodeTexImage")
ctex.image = bpy.data.images.load(atlas_path)
cnt.links.new(ctex.outputs["Color"], cp.inputs["Base Color"])
cnt.links.new(ctex.outputs["Alpha"], cp.inputs["Alpha"])
for attr, val in (("blend_method", "CLIP"), ("surface_render_method", "DITHERED")):
    try:
        setattr(card_mat, attr, val)
    except Exception:
        pass
card_mesh.materials.append(card_mat)
bpy.data.objects.remove(bpy.data.objects["FOLIAGE_WORK"], do_unlink=True)
trunk = T()  # re-fetch after the removal
card_obj.name = "FOLIAGE_WORK"
foliage = card_obj
foliage.hide_render = False
trunk.hide_render = False

# ---- trunk reduction --------------------------------------------------------
bmt = bmesh.new()
bmt.from_mesh(trunk.data)
bmt.faces.ensure_lookup_table()
seen, comps = set(), []
for f in bmt.faces:
    if f.index in seen:
        continue
    stack, comp = [f], []
    seen.add(f.index)
    while stack:
        cur = stack.pop()
        comp.append(cur)
        for e in cur.edges:
            for nf in e.link_faces:
                if nf.index not in seen:
                    seen.add(nf.index)
                    stack.append(nf)
    comps.append(comp)
comps.sort(key=len, reverse=True)
keep = set()
for comp in comps[:MAX_TRUNK_ISLANDS]:
    if len(comp) >= MIN_ISLAND or not keep:
        keep.update(f.index for f in comp)
bmesh.ops.delete(bmt, geom=[f for f in bmt.faces if f.index not in keep], context="FACES")
bmt.to_mesh(trunk.data)
bmt.free()
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = trunk
dec = trunk.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, TRUNK_TRIS / max(tri_count(trunk), 1))
bpy.ops.object.modifier_apply(modifier=dec.name)

print(f"RESULT foliage_tris={tri_count(foliage)} trunk_tris={tri_count(trunk)} clumps={len(clumps)}")

# STRIP VERTEX COLOURS. These vendor meshes carry a black colour attribute
# (RGB 0,0,0). Roblox MULTIPLIES vertex colours into a MeshPart's TextureID, so the
# trunk rendered pure BLACK no matter which texture was assigned — including textures
# known-good on other meshes. (SurfaceAppearance OVERRIDES vertex colour instead of
# multiplying, which is why the foliage was unaffected and why the trunk looked merely
# white back when it still had a SurfaceAppearance.)
for _o in (trunk, foliage):
    for _ca in list(_o.data.color_attributes):
        _o.data.color_attributes.remove(_ca)
    print(f"VCOL stripped from {_o.name}")

# ---- scale + export ---------------------------------------------------------
# Scale by transforming MESH DATA directly, never object scale: bpy.ops.transform_apply
# is context/selection sensitive and silently left the trunk carrying an 0.01 object
# scale, which the exporter's global_scale then multiplied AGAIN (trunk imported 100x
# too small). Direct mesh transform + identity object matrix is deterministic.
# MESH DATA is authoritative: both meshes are built in the same source space (the
# trunk's LOCAL coords stay correct even when Blender leaves a spurious object scale on
# it — baking matrix_world in would import the trunk 100x small). Discard object
# transforms, then scale the mesh data itself.
pts = []
for o in (trunk, foliage):
    pts += [v.co for v in o.data.vertices]
zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
s = HEIGHT_STUDS / (zmax - zmin)
for o in (trunk, foliage):
    # reset every transform component explicitly, then force a depsgraph update: the FBX
    # exporter evaluates objects through the depsgraph, so without this it still writes
    # the trunk's stale spurious scale (exported 100x small even with a clean matrix).
    o.delta_location = (0.0, 0.0, 0.0)
    o.delta_rotation_euler = (0.0, 0.0, 0.0)
    o.delta_scale = (1.0, 1.0, 1.0)
    o.location = (0.0, 0.0, 0.0)
    o.rotation_euler = (0.0, 0.0, 0.0)
    o.scale = (1.0, 1.0, 1.0)
    o.matrix_world = mathutils.Matrix.Identity(4)
    o.data.transform(mathutils.Matrix.Scale(s, 4))
    o.data.update()
bpy.context.view_layer.update()

# Rehost both meshes in FRESHLY CREATED objects. The FBX-imported trunk carries hidden
# importer state that survives clearing location/rotation/scale/deltas and a depsgraph
# update — the exporter kept writing it 100x small — while the newly-built card object
# always exported correctly. A new object wrapping a copy of the mesh data (UVs and
# materials included) reliably exports at unit scale.
fresh = []
for o in (trunk, foliage):
    no = bpy.data.objects.new(o.name + "_X", o.data.copy())
    bpy.context.scene.collection.objects.link(no)
    fresh.append(no)
for o in (trunk, foliage):
    bpy.data.objects.remove(o, do_unlink=True)
trunk, foliage = fresh
trunk.name = base_name + "_Trunk"
foliage.name = base_name + "_Foliage"
bpy.context.view_layer.update()
trunk.name = base_name + "_Trunk"
foliage.name = base_name + "_Foliage"
for o in (trunk, foliage):
    zs = [v.co.z for v in o.data.vertices]
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    tr = tuple(round(v, 3) for v in o.matrix_world.to_translation())
    print(f"PRE-EXPORT {o.name}: loc={tr} x[{min(xs):.2f},{max(xs):.2f}] y[{min(ys):.2f},{max(ys):.2f}] z[{min(zs):.2f},{max(zs):.2f}]")
bpy.ops.object.select_all(action="DESELECT")
trunk.select_set(True)
foliage.select_set(True)
bpy.context.view_layer.objects.active = trunk
if "BakeCam" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["BakeCam"], do_unlink=True)

bpy.ops.export_scene.fbx(
    filepath=OUT_FBX,
    use_selection=True,
    path_mode="COPY",
    embed_textures=True,
    global_scale=0.01,
)
print("WROTE", OUT_FBX)
print(f"ATLAS PNG kept beside the FBX: {atlas_path}")
print("  If Studio's import shows opaque cards, set the foliage SurfaceAppearance's")
print("  ColorMap to this PNG by hand and AlphaMode=Transparency.")
