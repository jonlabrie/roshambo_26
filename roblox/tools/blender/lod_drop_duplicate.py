"""Delete the duplicate foliage mesh and GROW the survivors to hold canopy density.

The sugi assets ship TWO near-identical foliage meshes (same card count, same
material, same UV range, centroids 0.001 apart) — a jittered density double, NOT
backfaces, so deleting one removes real leaf mass. Growing the remaining cards
about their own centroids puts that mass back without putting the triangles back.
"""
import bpy, bmesh, sys, os
argv = sys.argv[sys.argv.index("--")+1:]
src, out_fbx, GROW, TRUNK = argv[0], argv[1], float(argv[2]), float(argv[3])

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lod_trunk import decimate_trunk  # noqa: E402  (bole-preserving trunk reduction)

bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

fols = sorted([o for o in bpy.context.scene.objects
               if o.type == "MESH" and "Foliage" in o.name], key=lambda o: o.name)
before = sum(sum(len(p.vertices)-2 for p in o.data.polygons)
             for o in bpy.context.scene.objects if o.type == "MESH")

# drop every foliage mesh after the first
for o in fols[1:]:
    print(f"  dropping duplicate {o.name}")
    bpy.data.objects.remove(o, do_unlink=True)

# grow the survivors' cards about their own centroids
for o in fols[:1]:
    bm = bmesh.new(); bm.from_mesh(o.data)
    seen=set(); parts=[]
    for v in bm.verts:
        if v.index in seen: continue
        stack=[v]; comp=[]
        while stack:
            cur=stack.pop()
            if cur.index in seen: continue
            seen.add(cur.index); comp.append(cur)
            for e in cur.link_edges:
                n=e.other_vert(cur)
                if n.index not in seen: stack.append(n)
        parts.append(comp)
    for comp in parts:
        cx = sum(v.co.x for v in comp)/len(comp)
        cy = sum(v.co.y for v in comp)/len(comp)
        cz = sum(v.co.z for v in comp)/len(comp)
        for v in comp:
            v.co.x = cx + (v.co.x-cx)*GROW
            v.co.y = cy + (v.co.y-cy)*GROW
            v.co.z = cz + (v.co.z-cz)*GROW
    bm.to_mesh(o.data); bm.free(); o.data.update()
    print(f"  grew {len(parts)} cards x{GROW}")

if TRUNK < 1.0:
    for o in [x for x in bpy.context.scene.objects if x.type=="MESH" and "Trunk" in x.name]:
        name, b, a, note = decimate_trunk(o, TRUNK)
        print(f"  {name}: {b} -> {a} tris  ({note})")

after = sum(sum(len(p.vertices)-2 for p in o.data.polygons)
            for o in bpy.context.scene.objects if o.type == "MESH")
print(f"TOTAL {before} -> {after} tris ({100*after/before:.0f}%)")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=out_fbx, use_selection=True, path_mode="COPY", embed_textures=True)
print("WROTE", out_fbx)
