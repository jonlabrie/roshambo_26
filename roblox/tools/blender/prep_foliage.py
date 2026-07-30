# prep_foliage.py — make bought foliage safe to import into Roblox.
#
# WHY THIS EXISTS. Vendor foliage is modelled as SINGLE-SIDED CARDS and relies on
# the DCC renderer drawing both faces — Blender does that by default, and its
# materials even ship with `use_backface_culling = False` to say so. Roblox does
# NOT: MeshParts are backface-culled and there is no double-sided flag. So a raw
# import half-vanishes as you walk past it, which reads as "the import broke"
# rather than as a geometry problem. Found on the Moss Asset Kit 2026-07-30:
# Moss_B_A had 243 boundary edges against 82 manifold and ZERO flipped twin pairs.
#
# So this doubles the faces — duplicate the shell, reverse the copy's winding —
# which is cheap for card geometry (a 122-tri moss tuft becomes 244; one iris
# ensata is 11,827) and is the only thing that actually fixes it.
#
# ⚠️ IT MUST NOT DOUBLE CLOSED SOLIDS. Reversing a copy of a watertight mesh buries
# a second inverted shell inside it: invisible, and pure cost. So the decision is
# per object, from the boundary-edge ratio, and EVERY decision is printed so the
# call is auditable rather than trusted.
#
# Sibling tool: triage_tree.py judges whether an asset is worth importing at all
# (card structure, not triangle count, decides whether budget reduction survives).
# This one prepares an asset already judged worth it. The planned Phase 2 addition
# here is leaf-carding: replace solid-modelled blades with 2-tri cards using the
# vendor's own diffuse+opacity maps — the Iris ensata needs it badly (median 152
# faces per blade, ~70x overspend), and it belongs in this file, not a new one.
#
# Usage (headless):
#   blender --background <in.blend> --python prep_foliage.py -- \
#       [--report] [--ratio 0.35] [--out <out.fbx>] [--scale 1.0]
#
#   --report   analyse and print, change nothing (ALWAYS run this first)
#   --ratio    boundary/total edge ratio above which an object counts as cards
#   --out      export the prepped objects to FBX
#   --scale    uniform scale applied before export (the moss kit is 2-19 cm; at
#              1 stud = 1 foot it needs ~4-8x to read at Roblox scale)
#
# On macOS: /Applications/Blender.app/Contents/MacOS/Blender

import sys
import os
import json

import bpy
import bmesh


def argv_after_dashdash():
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1 :]
    return []


def flag(args, name, default=None, cast=str):
    if name in args:
        i = args.index(name)
        if i + 1 < len(args):
            return cast(args[i + 1])
    return default


def mesh_stats(obj):
    """Boundary/manifold edge split and existing flipped-twin count."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    boundary = 0
    manifold = 0
    worse = 0
    for e in bm.edges:
        n = len(e.link_faces)
        if n == 1:
            boundary += 1
        elif n == 2:
            manifold += 1
        elif n > 2:
            worse += 1
    total = max(1, len(bm.edges))

    # A face already having a coincident opposite-facing partner means the asset
    # was authored two-sided and must NOT be doubled again.
    from collections import defaultdict

    buckets = defaultdict(list)
    for f in bm.faces:
        c = f.calc_center_median()
        buckets[(round(c.x, 5), round(c.y, 5), round(c.z, 5))].append(f)
    twins = 0
    for faces in buckets.values():
        for i in range(len(faces)):
            for j in range(i + 1, len(faces)):
                if faces[i].normal.dot(faces[j].normal) < -0.9:
                    twins += 1
    stats = {
        "faces": len(bm.faces),
        "edges": len(bm.edges),
        "boundary_edges": boundary,
        "manifold_edges": manifold,
        "nonmanifold_3plus": worse,
        "boundary_ratio": round(boundary / total, 3),
        "flipped_twin_pairs": twins,
    }
    bm.free()
    return stats


def decide(stats, ratio_threshold):
    """Card geometry needs doubling; a closed solid or an already-two-sided mesh
    must be left alone. Returns (should_double, reason)."""
    if stats["faces"] == 0:
        return False, "no faces"
    if stats["flipped_twin_pairs"] > 0:
        return False, "already two-sided (%d twin pairs)" % stats["flipped_twin_pairs"]
    if stats["boundary_ratio"] >= ratio_threshold:
        return True, "open cards (boundary ratio %.2f)" % stats["boundary_ratio"]
    return False, "closed solid (boundary ratio %.2f)" % stats["boundary_ratio"]


def double_faces(obj):
    """Duplicate the shell and reverse the copy's winding. bmesh.ops.duplicate
    carries UVs and material indices, which hand-building faces does not."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    res = bmesh.ops.duplicate(bm, geom=geom)
    new_faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    if new_faces:
        bmesh.ops.reverse_faces(bm, faces=new_faces)
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    return len(new_faces)


def main():
    args = argv_after_dashdash()
    report_only = "--report" in args
    ratio = flag(args, "--ratio", 0.35, float)
    out = flag(args, "--out", None)
    scale = flag(args, "--scale", 1.0, float)

    meshes = [o for o in bpy.data.objects if o.type == "MESH" and len(o.data.polygons) > 0]
    # the kits ship a leftover default Cube; it is a closed solid so `decide`
    # skips it anyway, but do not export it
    meshes = [o for o in meshes if o.name != "Cube"]
    meshes.sort(key=lambda o: o.name)

    rows = []
    doubled_total = 0
    for o in meshes:
        st = mesh_stats(o)
        should, why = decide(st, ratio)
        added = 0
        if should and not report_only:
            added = double_faces(o)
            doubled_total += added
        rows.append(
            {
                "name": o.name,
                "faces_before": st["faces"],
                "faces_after": st["faces"] + added,
                "boundary_ratio": st["boundary_ratio"],
                "action": ("DOUBLE" if should else "skip"),
                "reason": why,
            }
        )

    print("PREP_REPORT_START")
    print(
        json.dumps(
            {
                "objects": len(rows),
                "ratio_threshold": ratio,
                "report_only": report_only,
                "faces_added": doubled_total,
                "to_double": sum(1 for r in rows if r["action"] == "DOUBLE"),
                "skipped": sum(1 for r in rows if r["action"] == "skip"),
                "rows": rows,
            },
            indent=1,
        )
    )
    print("PREP_REPORT_END")

    if report_only or not out:
        return

    if scale != 1.0:
        for o in meshes:
            o.scale = (o.scale[0] * scale, o.scale[1] * scale, o.scale[2] * scale)

    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0] if meshes else None

    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=out,
        use_selection=True,
        # Roblox reads metres; bake the scale in rather than leaving a unit surprise
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=False,
        axis_forward="-Z",
        axis_up="Y",
    )
    print("EXPORTED", out)


main()
