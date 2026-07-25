# export_niwaki.py — TurboSquid niwaki set -> Roblox-ready FBX (spec
# 2026-07-25-square-canopy-foliage §1, PineNiwaki role).
#
# Source: TurboSquid product 2017007 "Decorative Trees Pine Topiary Niwaki 1176"
# (purchased 2026-07-25, Standard License; archviz-density: ~50-200k polys/tree).
# NOT committed to the repo — lives in ~/Desktop/Roshambo Reference/niwaki/.
#
# Reduction: trunk = keep top-10 connected islands >=200 faces (drops modelled
# twigs), decimate to ~4k tris. Foliage = the opacity-card needle tufts, randomly
# (LCG, deterministic) thinned to ~9k tris. Diffuse+OPACITY jpgs composite into
# one RGBA PNG because Roblox SurfaceAppearance reads alpha from the ColorMap.
# Height baked in studs (Roblox 3D importer still lands 100x — ScaleTo after
# import; Blender FBX exports cm).
#
# Usage (headless):
#   /Applications/Blender.app/Contents/MacOS/Blender --background --python \
#     export_niwaki.py -- <src.fbx> "<tree object>" <foliage_tris> <height_studs> <out.fbx>
#
import bpy, bmesh, sys, math, functools, os, glob
import numpy as np
print = functools.partial(print, flush=True)

argv = sys.argv[sys.argv.index("--") + 1:]
FBX, TREE, TARGET_FOL_TRIS, HEIGHT_STUDS, OUT_FBX = argv[0], argv[1], int(argv[2]), float(argv[3]), argv[4]
FOLIAGE_KEY = "13012023 4"
TRUNK_TRIS = 4000

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)
tree = bpy.data.objects[TREE]
wm = tree.matrix_world.copy()
for o in list(bpy.data.objects):
    if o.name != TREE:
        bpy.data.objects.remove(o, do_unlink=True)
tree.parent = None
tree.matrix_world = wm
bpy.ops.object.select_all(action="DESELECT")
tree.select_set(True)
bpy.context.view_layer.objects.active = tree
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if max(tree.dimensions) > 20:
    raise SystemExit("ABORT: scale not normalized")

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")

foliage, trunk = None, None
for o in list(bpy.data.objects):
    if any(m and FOLIAGE_KEY in m.name for m in o.data.materials):
        foliage = o
    elif trunk is None:
        trunk = o
    else:
        bpy.ops.object.select_all(action="DESELECT")
        trunk.select_set(True); o.select_set(True)
        bpy.context.view_layer.objects.active = trunk
        bpy.ops.object.join()

def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

def islands_of(obj):
    bm = bmesh.new(); bm.from_mesh(obj.data); bm.faces.ensure_lookup_table()
    seen, comps = set(), []
    for f in bm.faces:
        if f.index in seen: continue
        stack, comp = [f], []; seen.add(f.index)
        while stack:
            cur = stack.pop(); comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index); stack.append(nf)
        comps.append(comp)
    return bm, comps

# TRUNK
bm, comps = islands_of(trunk)
comps.sort(key=len, reverse=True)
keep = set()
for comp in comps[:10]:
    if len(comp) >= 200 or not keep:
        keep.update(f.index for f in comp)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
bm.to_mesh(trunk.data); bm.free()
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = trunk
dec = trunk.modifiers.new("dec", "DECIMATE")
dec.ratio = min(1.0, TRUNK_TRIS / max(tri_count(trunk), 1))
bpy.ops.object.modifier_apply(modifier=dec.name)
trunk.name = "Trunk"

# FOLIAGE: thin cards to a TARGET tri count (deterministic)
bm, comps = islands_of(foliage)
per_island = max(1, round(sum(len(c) for c in comps) * 2 / len(comps)))  # tris per card
keep_n = min(len(comps), TARGET_FOL_TRIS // per_island)
state = 12345
def lcg():
    global state
    state = (1103515245 * state + 12345) % 2147483648
    return state / 2147483648
frac = keep_n / len(comps)
doomed, kept = [], 0
for comp in comps:
    if lcg() < frac:
        kept += 1
    else:
        doomed.extend(comp)
bmesh.ops.delete(bm, geom=doomed, context="FACES")
bm.to_mesh(foliage.data); bm.free()
foliage.name = "Foliage"
print(f"RESULT foliage_tris={tri_count(foliage)} trunk_tris={tri_count(trunk)} (kept {kept}/{len(comps)} cards)")

# textures: find on disk
fbx_dir = os.path.dirname(FBX)
tex_by_name = {}
for td in glob.glob(os.path.join(os.path.dirname(fbx_dir), "* Texture")):
    for f in os.listdir(td):
        tex_by_name[f.lower()] = os.path.join(td, f)
for img in bpy.data.images:
    base = os.path.basename(img.filepath).lower()
    if base in tex_by_name:
        img.filepath = tex_by_name[base]
        img.reload()

# composite diffuse RGB + opacity -> single RGBA PNG (Roblox SA reads colormap alpha)
out_dir = os.path.dirname(OUT_FBX)
os.makedirs(out_dir, exist_ok=True)
fol_mat = foliage.data.materials[0]
diff_node = next(n for n in fol_mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
diff_img = diff_node.image
opac_path = next(v for k, v in tex_by_name.items() if "opacity" in k)
opac_img = bpy.data.images.load(opac_path)
w, h = diff_img.size
if opac_img.size[0] != w or opac_img.size[1] != h:
    opac_img.scale(w, h)
diff = np.empty(w * h * 4, dtype=np.float32); diff_img.pixels.foreach_get(diff)
opac = np.empty(w * h * 4, dtype=np.float32); opac_img.pixels.foreach_get(opac)
rgba = diff.reshape(-1, 4).copy()
rgba[:, 3] = opac.reshape(-1, 4)[:, 0]  # opacity map luminance (R) -> alpha
combined = bpy.data.images.new("NeedlesRGBA", w, h, alpha=True)
combined.pixels.foreach_set(rgba.reshape(-1))
combined.filepath_raw = os.path.join(out_dir, "NiwakiNeedles.png")
combined.file_format = "PNG"
combined.save()
diff_node.image = combined
print("TEXTURE", combined.filepath_raw, f"{w}x{h}")

# scale to target stud height (1 unit = 1 stud on import)
cur_h = max(trunk.dimensions.z, foliage.location.z + foliage.dimensions.z)
lo = min((o.matrix_world @ v.co).z for o in (trunk, foliage) for v in o.data.vertices[:1])
# robust: use combined bbox
import mathutils
pts = [o.matrix_world @ mathutils.Vector(c) for o in (trunk, foliage) for c in o.bound_box]
zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
s = HEIGHT_STUDS / (zmax - zmin)
for o in (trunk, foliage):
    o.scale = (s, s, s)
bpy.ops.object.select_all(action="DESELECT")
trunk.select_set(True); foliage.select_set(True)
bpy.context.view_layer.objects.active = trunk
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bpy.ops.export_scene.fbx(
    filepath=OUT_FBX,
    global_scale=0.01,  # Blender exports cm; Roblox reads 1 unit = 1 stud
    use_selection=True,
    path_mode="COPY",
    embed_textures=True,
)
print("WROTE", OUT_FBX)
