# export_tree.py — archviz tree FBX -> Roblox-ready FBX (spec 2026-07-25-square-canopy-foliage).
#
# Generalizes export_niwaki.py to any "trunk mesh + opacity-card foliage" source tree.
# Used for: the TurboSquid niwaki set (product 2017007) and the sugi/Japanese-cedar set
# (6 variants, 178k-395k polys). Sources are NOT committed — they live in
# ~/Desktop/Roshambo Reference/<set>/.
#
# Reduction:
#   trunk   — keep the top-N connected islands >= MIN_ISLAND faces (drops modelled twigs
#             that decimate into spaghetti), then decimate to TRUNK_TRIS.
#   foliage — the opacity-card leaf/needle clusters, deterministically (integer LCG)
#             thinned by whole islands to ~FOLIAGE_TRIS. Card geometry is preserved, so
#             the source's own leaf textures keep doing the visual work.
#   texture — diffuse RGB + the OPACITY jpg composite into ONE RGBA PNG, because Roblox
#             SurfaceAppearance reads alpha from the ColorMap and ignores a separate map.
#   scale   — height baked in studs; global_scale=0.01 on export or the Roblox importer
#             sees centimetres and clamps at 2048 studs.
#
# Usage (headless):
#   /Applications/Blender.app/Contents/MacOS/Blender --background --python export_tree.py -- \
#       <src.fbx> <object name> <foliage material key> <foliage_tris> <trunk_tris> \
#       <height_studs> <out.fbx>
#
# In Studio: File -> Import 3D (NOT "as package"); then set the foliage MeshPart's
# SurfaceAppearance.AlphaMode = Transparency.

import bpy, bmesh, sys, math, os, glob, functools
import numpy as np
import mathutils

print = functools.partial(print, flush=True)

argv = sys.argv[sys.argv.index("--") + 1:]
FBX, OBJ, FOLIAGE_KEY = argv[0], argv[1], argv[2]
FOLIAGE_TRIS, TRUNK_TRIS = int(argv[3]), int(argv[4])
HEIGHT_STUDS, OUT_FBX = float(argv[5]), argv[6]
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
if max(tree.dimensions) > 200:
    raise SystemExit(f"ABORT: {max(tree.dimensions):.0f} units after apply — unexpected source scale")

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
    raise SystemExit(f"ABORT: could not split trunk/foliage on key {FOLIAGE_KEY!r}")


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def islands_of(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    seen, comps = set(), []
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
        comps.append(comp)
    return bm, comps


# TRUNK: main islands only, then decimate
bm, comps = islands_of(trunk)
comps.sort(key=len, reverse=True)
keep = set()
for comp in comps[:MAX_TRUNK_ISLANDS]:
    if len(comp) >= MIN_ISLAND or not keep:
        keep.update(f.index for f in comp)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
bm.to_mesh(trunk.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = trunk
dec = trunk.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, TRUNK_TRIS / max(tri_count(trunk), 1))
bpy.ops.object.modifier_apply(modifier=dec.name)

# FOLIAGE: thin whole cards to the target tri budget (deterministic LCG)
bm, comps = islands_of(foliage)
per_island = max(1, round(sum(len(c) for c in comps) * 2 / len(comps)))
frac = min(1.0, (FOLIAGE_TRIS // per_island) / len(comps))
state = 12345
doomed, kept = [], 0
for comp in comps:
    state = (1103515245 * state + 12345) % 2147483648
    if state / 2147483648 < frac:
        kept += 1
    else:
        doomed.extend(comp)
bmesh.ops.delete(bm, geom=doomed, context="FACES")
bm.to_mesh(foliage.data)
bm.free()
print(f"RESULT foliage_tris={tri_count(foliage)} trunk_tris={tri_count(trunk)} (kept {kept}/{len(comps)} cards)")

# textures: repoint to whatever sits next to the FBX (vendors ship a *_maps sibling)
tex_by_name = {}
search_dirs = [os.path.dirname(FBX)] + glob.glob(os.path.join(os.path.dirname(FBX), "*")) \
    + glob.glob(os.path.join(os.path.dirname(os.path.dirname(FBX)), "* Texture"))
for td in search_dirs:
    if os.path.isdir(td):
        for f in os.listdir(td):
            tex_by_name.setdefault(f.lower(), os.path.join(td, f))
for img in bpy.data.images:
    base = os.path.basename(img.filepath).lower()
    if base in tex_by_name:
        img.filepath = tex_by_name[base]
        img.reload()

# composite diffuse RGB + opacity -> one RGBA PNG (Roblox SA reads ColorMap alpha)
out_dir = os.path.dirname(OUT_FBX)
os.makedirs(out_dir, exist_ok=True)
fol_mat = foliage.data.materials[0]
diff_node = next((n for n in fol_mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image
                  and "opa" not in n.image.name.lower()), None)
opac_path = next((v for k, v in tex_by_name.items()
                  if "opa" in k and FOLIAGE_KEY.split("_")[0].lower() in k), None)
if opac_path is None:
    opac_path = next((v for k, v in tex_by_name.items() if "opa" in k), None)
if diff_node and opac_path:
    diff_img = diff_node.image
    opac_img = bpy.data.images.load(opac_path)
    w, h = diff_img.size
    if opac_img.size[0] != w or opac_img.size[1] != h:
        opac_img.scale(w, h)
    diff = np.empty(w * h * 4, dtype=np.float32)
    diff_img.pixels.foreach_get(diff)
    opac = np.empty(w * h * 4, dtype=np.float32)
    opac_img.pixels.foreach_get(opac)
    rgba = diff.reshape(-1, 4).copy()
    rgba[:, 3] = opac.reshape(-1, 4)[:, 0]
    name = os.path.splitext(os.path.basename(OUT_FBX))[0]
    combined = bpy.data.images.new(name + "_leaves", w, h, alpha=True)
    combined.pixels.foreach_set(rgba.reshape(-1))
    combined.filepath_raw = os.path.join(out_dir, name + "_leaves.png")
    combined.file_format = "PNG"
    combined.save()
    diff_node.image = combined
    print(f"TEXTURE {combined.filepath_raw} {w}x{h}")
else:
    print("WARN no diffuse/opacity pair found — foliage will import opaque")

# scale to target stud height, then name meshes per output file (Asset Manager legibility)
pts = [o.matrix_world @ mathutils.Vector(c) for o in (trunk, foliage) for c in o.bound_box]
zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
s = HEIGHT_STUDS / (zmax - zmin)
for o in (trunk, foliage):
    o.scale = (s, s, s)
bpy.ops.object.select_all(action="DESELECT")
trunk.select_set(True)
foliage.select_set(True)
bpy.context.view_layer.objects.active = trunk
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

base_name = os.path.splitext(os.path.basename(OUT_FBX))[0]
trunk.name = base_name + "_Trunk"
foliage.name = base_name + "_Foliage"

bpy.ops.export_scene.fbx(
    filepath=OUT_FBX,
    use_selection=True,
    path_mode="COPY",
    embed_textures=True,
    global_scale=0.01,  # Blender exports cm; Roblox reads 1 unit = 1 stud
)
print("WROTE", OUT_FBX)
