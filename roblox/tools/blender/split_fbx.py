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
# Roblox reassembly: the FBX importer's Y-up conversion NEGATES X — verified by vertex
# fingerprint against the imported asset (EditableMesh), which matched
# (-x, z, y) to 7e-5 studs while (x, z, y) missed by 2.6 studs. (x, z, y) is an
# improper mirror, not a rotation; assuming it displaced every part in X by 2*dx and
# produced the 2026-07-26 "severed branch" registration seam.
# So: RobloxOffset = (-d(blender x), d(blender z), d(blender y)) * 100 (m -> studs at
# the 0.01 export scale). roblox_offset_from_first below is exactly that, ready to use:
# part.Position = firstPart.Position + Vector3.new(unpack(offset)).
names = [k for k in man if not k.startswith("_")]
first = man[names[0]]["centre_blender_xyz"]
for k in names:
    c = man[k]["centre_blender_xyz"]
    man[k]["roblox_offset_from_first"] = [
        round(-(c[0] - first[0]) * 100, 4),
        round((c[2] - first[2]) * 100, 4),
        round((c[1] - first[1]) * 100, 4),
    ]
man["_note"] = ("Roblox offset from the FIRST part = (-d(blender x), d(blender z), "
                "d(blender y)) * 100 studs — see roblox_offset_from_first. The importer "
                "negates X in its Y-up conversion; do NOT use (+dx, dz, dy).")
open(os.path.join(OUT_DIR, "manifest.json"), "w").write(json.dumps(man, indent=1))
print("MANIFEST", os.path.join(OUT_DIR, "manifest.json"))
