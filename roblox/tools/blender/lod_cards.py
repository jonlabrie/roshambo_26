import bpy, bmesh, sys, math
argv = sys.argv[sys.argv.index("--")+1:]
src, out_fbx = argv[0], argv[1]
KEEP = float(argv[2])      # fraction of leaf cards to keep
GROW = float(argv[3])      # linear scale on survivors
TRUNK = float(argv[4])     # decimate ratio for wood

bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
report = []

for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        continue
    before = sum(len(p.vertices)-2 for p in o.data.polygons)

    if "Foliage" in o.name:
        bm = bmesh.new(); bm.from_mesh(o.data)
        # group verts into loose parts = leaf cards
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
        # deterministic 50% cull spread through SPACE, not index order: hash the
        # centroid so survivors stay evenly distributed through the canopy
        doomed=[]
        for i, comp in enumerate(parts):
            cx = sum(v.co.x for v in comp)/len(comp)
            cy = sum(v.co.y for v in comp)/len(comp)
            cz = sum(v.co.z for v in comp)/len(comp)
            hv = int(abs(cx*7919 + cy*104729 + cz*15485863)*1000) % 1000
            if hv >= KEEP*1000:
                doomed.append(comp)
            else:
                # grow survivors about their own centroid to hold canopy density
                for v in comp:
                    v.co.x = cx + (v.co.x-cx)*GROW
                    v.co.y = cy + (v.co.y-cy)*GROW
                    v.co.z = cz + (v.co.z-cz)*GROW
        dead = set()
        for comp in doomed:
            for v in comp: dead.add(v)
        bmesh.ops.delete(bm, geom=list(dead), context='VERTS')
        bm.to_mesh(o.data); bm.free()
        o.data.update()
        report.append((o.name, before, sum(len(p.vertices)-2 for p in o.data.polygons),
                       f"cards {len(parts)} -> {len(parts)-len(doomed)}, x{GROW:.2f}"))
    elif "Trunk" in o.name and TRUNK < 1.0:
        m = o.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"; m.ratio = TRUNK
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
        report.append((o.name, before, sum(len(p.vertices)-2 for p in o.data.polygons),
                       f"decimate {TRUNK:.2f}"))

total_before = 0; total_after = 0
for name, b, a, note in report:
    print(f"  {name}: {b} -> {a} tris  ({note})")
    total_before += b; total_after += a
print(f"TOTAL foliage+trunk: {total_before} -> {total_after} tris ({100*total_after/total_before:.0f}%)")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=out_fbx, use_selection=True, path_mode="COPY", embed_textures=True)
print("WROTE", out_fbx)
