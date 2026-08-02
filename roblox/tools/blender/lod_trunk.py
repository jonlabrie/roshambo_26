"""Decimate a tree's twigs without ever touching its bole.

THE BUG THIS EXISTS TO PREVENT (2026-08-01, caught by eye in a Blender side-by-side,
after it had already shipped on 332 placed trees):

An xFrog trunk mesh is ~1000 LOOSE PARTS — one long bole plus hundreds of 6-30 vert
twigs and root flares. `Decimate COLLAPSE` ranks edges by quadric error, and a long,
smooth, low-curvature tube is the CHEAPEST thing in such a mesh to collapse. So the
bole is destroyed FIRST while the noisy twigs survive.

The failure is nearly invisible to every automated check: triangle count drops as
asked, the object still exists, and the BOUNDING BOX is still full height because
the branches and root flare hold it. Measured on XfHinokiM at ratio 0.30, the bole
went from 1321 verts spanning 83% of tree height to 7 verts spanning 10%. The tree
reads as a floating cloud of branches with no trunk.

Alternatives that do NOT work (measured on XfSpruceMT):
  COLLAPSE 0.60  -> bole survives at the base but band 1 is still eaten (458->134 v)
  PLANAR 5 deg   -> 100% of tris kept; a trunk has no coplanar faces to dissolve
  UNSUBDIV 1/2   -> 93%/89% kept; no meaningful reduction

So: split the bole out, decimate only the remainder, join it back.
"""
import bmesh
import bpy


def loose_parts(mesh):
    """Vertex-index sets for each connected component, with its vertical span."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    seen, comps = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        while stack:
            cur = stack.pop()
            if cur.index in seen:
                continue
            seen.add(cur.index)
            comp.append(cur)
            for e in cur.link_edges:
                n = e.other_vert(cur)
                if n.index not in seen:
                    stack.append(n)
        comps.append({
            "idx": {x.index for x in comp},
            "zspan": max(x.co.z for x in comp) - min(x.co.z for x in comp),
        })
    bm.free()
    return comps


def _keep_only(obj, idx, invert=False):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    dead = [v for v in bm.verts
            if ((v.index in idx) if invert else (v.index not in idx))]
    bmesh.ops.delete(bm, geom=dead, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate_trunk(o, ratio):
    """Reduce trunk object `o` toward `ratio` of its triangles, bole untouched.

    Returns (name, before, after, note). The bole is protected outright, so the
    twigs must absorb the entire cut — the effective twig ratio is solved for
    that and reported, and is clamped at 0.10 so a bole heavier than the target
    degrades gracefully instead of erasing every branch.
    """
    before = tris(o)
    comps = loose_parts(o.data)
    if not comps:
        return (o.name, before, before, "no geometry")

    bole = max(comps, key=lambda c: c["zspan"])["idx"]

    rest = o.copy()
    rest.data = o.data.copy()
    bpy.context.collection.objects.link(rest)
    _keep_only(o, bole)                   # o    = the bole alone, untouched
    _keep_only(rest, bole, invert=True)   # rest = every twig and root flare

    bole_tris, rest_tris = tris(o), tris(rest)
    eff = 1.0 if rest_tris == 0 else (ratio * before - bole_tris) / rest_tris
    eff = max(0.10, min(1.0, eff))
    if eff < 1.0:
        m = rest.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = eff
        bpy.context.view_layer.objects.active = rest
        bpy.ops.object.modifier_apply(modifier=m.name)

    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    rest.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    return (o.name, before, tris(o),
            f"bole {bole_tris} tris PROTECTED, twigs x{eff:.2f}")


def bole_health(obj):
    """Diagnostic: (bole_verts, bole_span_as_pct_of_height). A healthy trunk keeps
    a component spanning most of the tree; anything under ~50% means it collapsed."""
    comps = loose_parts(obj.data)
    if not comps:
        return (0, 0.0)
    zs = [v.co.z for v in obj.data.vertices]
    h = max(max(zs) - min(zs), 1e-9)
    best = max(comps, key=lambda c: c["zspan"])
    return (len(best["idx"]), round(best["zspan"] / h * 100, 1))
