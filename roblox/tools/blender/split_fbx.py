import bpy, sys, os, json, functools, mathutils
print = functools.partial(print, flush=True)
a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT_DIR = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
os.makedirs(OUT_DIR, exist_ok=True)
man = {}
for o in [x for x in bpy.data.objects if x.type == "MESH"]:
    pts = [o.matrix_world @ v.co for v in o.data.vertices]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) / 2
    man[o.name] = {"centre_blender_xyz": [round(c.x,4), round(c.y,4), round(c.z,4)],
                   "tris": sum(len(pl.vertices)-2 for pl in o.data.polygons)}
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT_DIR, o.name + ".fbx"),
                             use_selection=True, path_mode="COPY",
                             embed_textures=True, global_scale=1.0)
# Roblox reassembly: offset = (dx, dz_blender, dy_blender) from the anchor part
man["_note"] = ("Roblox offset from anchor = (dx, d(blender z), d(blender y)). "
                "Blender is Z-up; Roblox is Y-up.")
open(os.path.join(OUT_DIR, "manifest.json"), "w").write(json.dumps(man, indent=1))
print("MANIFEST", os.path.join(OUT_DIR, "manifest.json"))
