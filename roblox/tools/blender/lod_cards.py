import bpy, bmesh, sys, math, os
argv = sys.argv[sys.argv.index("--")+1:]
src, out_fbx = argv[0], argv[1]
KEEP = float(argv[2])      # fraction of leaf CROSSES to keep
GROW = float(argv[3])      # linear scale on survivors
TRUNK = float(argv[4])     # decimate ratio for wood (1.0 = leave trunks alone)
# 5th arg: 0 reproduces the old per-card cull, kept only so the two can be compared
CROSS_AWARE = bool(int(argv[5])) if len(argv) > 5 else True

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lod_trunk import decimate_trunk  # noqa: E402  (bole-preserving trunk reduction)

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
        # A "card" here is one quad, but xFrog builds each needle spray as a CROSS:
        # two quads at 90 degrees sharing a centre, so the spray reads from every
        # angle. They are coincident but NOT connected, so loose-part decomposition
        # sees them as two independent cards. Culling per-card therefore deletes ONE
        # ARM of a cross and leaves the survivor as a lone flat quad — which is why
        # earlier LODs read thin and flat from the side at the same triangle budget.
        # (Measured 2026-08-01: XfHinokiM is 100% crossed, XfHinokiMT 98%; the arms
        # are perpendicular, median normal dot 0.0 — not duplicates, not backfaces.)
        # So group coincident cards into CROSSES and keep or drop a whole cross.
        cents = []
        for comp in parts:
            n = len(comp)
            cents.append((sum(v.co.x for v in comp)/n,
                          sum(v.co.y for v in comp)/n,
                          sum(v.co.z for v in comp)/n))
        zs = [v.co.z for v in bm.verts]
        tol = (max(zs) - min(zs)) * 1e-4 if zs else 1e-9
        cell = max(tol * 2.0, 1e-12)
        buckets = {}
        for i, c in enumerate(cents):
            buckets.setdefault((int(c[0]//cell), int(c[1]//cell), int(c[2]//cell)), []).append(i)
        assigned, units = {}, []
        for i, c in enumerate(cents):
            if i in assigned: continue
            k = (int(c[0]//cell), int(c[1]//cell), int(c[2]//cell))
            group = [i]; assigned[i] = True
            for dx in (-1,0,1):
                for dy in (-1,0,1):
                    for dz in (-1,0,1):
                        for j in buckets.get((k[0]+dx,k[1]+dy,k[2]+dz), ()):
                            if j in assigned: continue
                            d = cents[j]
                            if ((c[0]-d[0])**2 + (c[1]-d[1])**2 + (c[2]-d[2])**2) <= tol*tol:
                                group.append(j); assigned[j] = True
            units.append(group)

        if not CROSS_AWARE:                      # legacy per-card cull, for A/B only
            units = [[i] for i in range(len(parts))]

        # deterministic cull spread through SPACE, not index order: hash the unit
        # centroid so survivors stay evenly distributed through the canopy
        doomed = []
        kept = 0
        for grp in units:
            cx = sum(cents[i][0] for i in grp)/len(grp)
            cy = sum(cents[i][1] for i in grp)/len(grp)
            cz = sum(cents[i][2] for i in grp)/len(grp)
            hv = int(abs(cx*7919 + cy*104729 + cz*15485863)*1000) % 1000
            if hv >= KEEP*1000:
                for i in grp: doomed.append(parts[i])
            else:
                kept += 1
                # grow survivors about the CROSS centre, so both arms stay concentric
                for i in grp:
                    for v in parts[i]:
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
                       f"{len(parts)} cards in {len(units)} crosses -> {kept} crosses, x{GROW:.2f}"))
    elif "Trunk" in o.name and TRUNK < 1.0:
        report.append(decimate_trunk(o, TRUNK))

total_before = 0; total_after = 0
for name, b, a, note in report:
    print(f"  {name}: {b} -> {a} tris  ({note})")
    total_before += b; total_after += a
print(f"TOTAL foliage+trunk: {total_before} -> {total_after} tris ({100*total_after/total_before:.0f}%)")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=out_fbx, use_selection=True, path_mode="COPY", embed_textures=True)
print("WROTE", out_fbx)
