# prep_foliage.py — make bought foliage safe to import into Roblox.
#
# WHY THIS EXISTS. Vendor foliage is modelled as SINGLE-SIDED CARDS and relies on
# the DCC renderer drawing both faces — Blender does that by default, and its
# materials even ship with `use_backface_culling = False` to say so. Roblox
# backface-culls, so a raw import half-vanishes as you walk past it, which reads
# as "the import broke" rather than as a geometry problem. Found on the Moss Asset
# Kit 2026-07-30: Moss_B_A had 243 boundary edges against 82 manifold and ZERO
# flipped twin pairs.
#
# ⚠️⚠️ THE DOUBLING BELOW IS THE WRONG FIX, AND THIS FILE USED TO SAY SO WRONGLY.
# It claimed Roblox "has no double-sided flag". **MeshPart.DoubleSided EXISTS**
# (verified engine 0.732.0: writable at runtime and on a fresh MeshPart), and the
# place was already relying on it — 800 MeshParts under CanyonWorld.Foliage.
# WaterFoliage have it set. Meanwhile MossScatter's 825 clumps carry DOUBLED
# GEOMETRY and not one has the flag, because they were prepped on the false claim.
#
# **Set MeshPart.DoubleSided = true at import.** It costs only the lost backface
# culling; doubling costs 2x triangles, 2x verts and 2x memory for the same result.
# There is no case here where duplicating shells wins. `--ribbon` therefore leaves
# its ribbons single-sided by design.
#
# double_faces() is kept for assets where the flag cannot be relied on, and because
# the moss shipped that way. Prefer the flag. (The moss is still carrying twice the
# triangles it needs — re-prepping it is optional cleanup, not urgent.)
#
# ⚠️ IT MUST NOT DOUBLE CLOSED SOLIDS. Reversing a copy of a watertight mesh buries
# a second inverted shell inside it: invisible, and pure cost. So the decision is
# per object, from the boundary-edge ratio, and EVERY decision is printed so the
# call is auditable rather than trusted.
#
# Sibling tool: triage_tree.py judges whether an asset is worth importing at all
# (card structure, not triangle count, decides whether budget reduction survives).
# This one prepares an asset already judged worth it.
#
# PHASE 2 (2026-07-30) — delivered as RIBBONING, not carding. The plan was to replace
# solid blades with 2-tri cards cut out by the vendor's opacity map. That is impossible
# for the Iris ensata: its four leaf materials have NO alpha at all (Leaves01..04 are
# all `ALPHA <- unlinked, value=1.00`), so the blade silhouette exists ONLY as geometry
# and there is nothing to cut a card against. The three materials that DO carry opacity
# are flower materials, two of them misleadingly named "Leaves02/03_<hash>".
#
# Carding is the right tool for a COMPOUND leaf, where one flat card replaces a whole
# spray of leaflets. An iris blade is a single sword, and for that a RIBBON is better:
# resample the blade to a flat strip that follows its own curve and taper, 2 verts per
# cross-section instead of 8. The silhouette stays geometric, so no alpha is needed.
# Measured on variant 001: 53 blades, 7047 faces -> 795, 8.9x.
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
#   --ribbon   ribbon the blades (see PHASE 2 above). Leaves them SINGLE-SIDED —
#              set MeshPart.DoubleSided at import, do not duplicate the shell
#   --patch    card the petals: replace solid petals with small CURVED grids. Selects
#              materials BY LINKED ALPHA, not by name — a card needs an opacity map to
#              cut its silhouette, and this kit names flower materials "Leaves02_<hash>"
#   --no-double  skip the doubling pass entirely and rely on MeshPart.DoubleSided at
#              import. RECOMMENDED — see the header.
#   --tube     rebuild the stems as low-poly tubes following their own centreline.
#              NOT ribboned: a stem is genuinely cylindrical and seen from every side
#   --blade-mats  material-name prefix identifying blade geometry (default Leaves0).
#              ⚠️ match the PLAIN names only — the flower materials in this kit are
#              called "Leaves02_<hash>", and ribboning a flower would destroy it.
#
# ⚠️ EXPORT SCALE IS UNVERIFIED ON THIS PATH. A Blender FBX lands in Roblox at
# exactly 100x (Blender writes centimetres, Roblox reads the raw numbers as studs);
# the verified fix is apply_unit_scale=True WITH global_scale=0.01. The export below
# uses FBX_SCALE_ALL instead, which was never checked against an actual import.
# Measure the first import rather than trusting it.
#
# On macOS: /Applications/Blender.app/Contents/MacOS/Blender

import sys
import os
import json
import math

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


def _blade_components(bm, slot_ids):
    """Connected components over faces carrying the blade materials — one per blade."""
    seen = set()
    comps = []
    for f in bm.faces:
        if f.material_index not in slot_ids or f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nb in e.link_faces:
                    if nb.index not in seen and nb.material_index in slot_ids:
                        seen.add(nb.index)
                        stack.append(nb)
        comps.append(comp)
    return comps


# Slice positions along a blade, base(0) -> tip(1). DELIBERATELY NON-UNIFORM: even
# spacing spends resolution on the blade's uniform middle and leaves none where the
# shape actually changes. Measured on the iris, a blade loses ~94% of its width inside
# the final 10%, and evenly-spaced rails put NOTHING in that band — every ribbon came
# out blunt. Clustering toward the tip fixed it at the same triangle count.
BLADE_FRACS = (0.0, 0.22, 0.42, 0.60, 0.75, 0.86, 0.94, 0.985)


def ribbon_blades(obj, mat_prefix="Leaves0"):
    """Replace solid-modelled blades with flat ribbons following their own curve.

    Returns (faces_before, faces_after, blade_count). No-op if no material matches.
    """
    import numpy as np
    from mathutils import Vector, kdtree

    slots = [m.name if m else "" for m in obj.data.materials]
    # PLAIN names only: "Leaves02_<hash>" is a FLOWER material in this kit
    slot_ids = {i for i, n in enumerate(slots) if n.startswith(mat_prefix) and "_" not in n}
    if not slot_ids:
        return 0, 0, 0

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.active
    blade_faces = [f for f in bm.faces if f.material_index in slot_ids]
    if not blade_faces or uv_layer is None:
        bm.free()
        return 0, 0, 0
    before = len(blade_faces)

    # The PLANT ROOT — centroid of the lowest 5% of blade verts. Used to tell a blade's
    # TIP from its BASE. Comparing end WIDTHS does NOT work: a blade emerges from a
    # sheath, so it is narrow at the base as well as the tip and the test is a coin flip.
    all_co = np.array([v.co[:] for v in {l.vert for f in blade_faces for l in f.loops}])
    root = all_co[all_co[:, 2] <= np.percentile(all_co[:, 2], 5)].mean(axis=0)

    made_faces = []
    comps = _blade_components(bm, slot_ids)
    for comp in comps:
        seen_uv = {}
        for f in comp:
            for l in f.loops:
                # hold the VERT REFERENCE, not its index: creating verts below
                # invalidates bm.verts[] lookup for every later blade
                seen_uv.setdefault(l.vert, l[uv_layer].uv.copy())
        verts = list(seen_uv.keys())
        if len(verts) < 8:
            continue
        uvs = [seen_uv[v] for v in verts]
        P = np.array([v.co[:] for v in verts])
        mid = P.mean(axis=0)
        _, _, vt = np.linalg.svd(P - mid, full_matrices=False)
        along, across = vt[0], vt[1]
        t = (P - mid) @ along
        lo, hi = t.min(), t.max()
        if hi - lo < 1e-9:
            continue

        kd = kdtree.KDTree(len(verts))
        for k, v in enumerate(verts):
            kd.insert(v.co, k)
        kd.balance()

        p_lo, p_hi = P[int(np.argmin(t))], P[int(np.argmax(t))]
        tip_at_hi = np.linalg.norm(p_hi - root) > np.linalg.norm(p_lo - root)
        tip_co = Vector(p_hi if tip_at_hi else p_lo)
        tb = (t - lo) / (hi - lo)
        if not tip_at_hi:
            tb = 1.0 - tb

        raw = []
        for fr in BLADE_FRACS:
            half = 0.10 if fr < 0.7 else 0.035  # narrow window near the tip
            sel = np.abs(tb - fr) <= half
            if sel.sum() < 3:
                sel = np.argsort(np.abs(tb - fr))[:4]
            pts = P[sel]
            c = pts.mean(axis=0)  # the blade's OWN centreline here, not a straight PCA line
            u = (pts - c) @ across
            # percentiles, NOT min/max: a sheathed base wraps the stem, and one stray
            # fold setting the width threw whole blades out sideways as wedges
            raw.append([c, float(np.percentile(u, 96)), float(np.percentile(u, 4))])

        # Every blade comes to a point BY DEFINITION, so enforce it rather than hoping
        # the sampling recovers it: past the widest slice, width may never increase.
        spans = np.array([h - l for (_, h, l) in raw])
        med = float(np.median(spans))
        widest = int(np.argmax(spans))
        for i in range(len(raw)):
            c, hq, lq = raw[i]
            span = hq - lq
            cap = med * 1.6
            if i > widest:
                cap = min(cap, raw[i - 1][1] - raw[i - 1][2])
            if span > cap and span > 1e-9:
                k2 = cap / span
                m = (hq + lq) * 0.5
                raw[i][1] = m + (hq - m) * k2
                raw[i][2] = m + (lq - m) * k2

        # Keep EVERY rail. BLADE_FRACS deliberately stops at 0.985, not 1.0, so the last
        # rail is the narrow one that forms the tip and the tip vertex sits beyond it. (An
        # earlier version ran rails to t=hi — the tip's own position — which made the final
        # triangle degenerate and left the blade ending on a rail of finite width. The fix
        # then was to drop that rail; with fractional slices it must be kept.)
        rails = [(Vector(c + across * hq), Vector(c + across * lq)) for (c, hq, lq) in raw]
        pairs = [(bm.verts.new(l), bm.verts.new(r)) for (l, r) in rails]
        v_tip = bm.verts.new(tip_co)
        mi = comp[0].material_index

        def _emit(tri):
            try:
                nf = bm.faces.new(tri)
            except ValueError:
                return
            nf.material_index = mi
            for loop in nf.loops:
                _, k, _ = kd.find(loop.vert.co)
                loop[uv_layer].uv = uvs[k]  # vendor UVs, so the texture still reads
            made_faces.append(nf)

        for i in range(len(pairs) - 1):
            (l0, r0), (l1, r1) = pairs[i], pairs[i + 1]
            _emit((l0, r0, r1))
            _emit((l0, r1, l1))
        l_last, r_last = pairs[-1]
        _emit((l_last, r_last, v_tip))

    bmesh.ops.delete(bm, geom=blade_faces, context="FACES")

    # RIBBONS ARE LEFT SINGLE-SIDED ON PURPOSE. Set MeshPart.DoubleSided = true at import
    # instead — see the ⚠️ at the top of this file. Duplicating the shell would cost 2x
    # triangles, verts and memory for the same result the flag gives free.
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    return before, len(made_faces), len(comps)


def alpha_material_slots(obj):
    """Slots whose material actually has a linked Alpha input.

    This is the precondition for carding — a card is a rectangle and needs an opacity
    map to cut the real silhouette out of it. Selecting by ALPHA rather than by material
    NAME matters here: this kit's flower materials are called "Leaves02_39E47DCB" and
    "Leaves03_C51ACDDA", so a name rule would ribbon the flowers and card nothing.
    """
    out = set()
    for i, m in enumerate(obj.data.materials):
        if not m or not m.node_tree:
            continue
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED" and n.inputs["Alpha"].is_linked:
                out.add(i)
                break
    return out


# Grid resolution for a patched petal: nodes across x along. 3x5 -> 8 quads -> 16 tris,
# against a median 140 faces per petal. A flat 2-tri card would be cheaper still, but an
# iris fall droops and curls hard and would read wrong in profile.
PATCH_GRID = (3, 5)


def patch_petals(obj, slot_ids=None):
    """Replace solid-modelled petals with small CURVED grids carrying the vendor's UVs.

    Returns (faces_before, faces_after, petal_count).
    """
    import numpy as np
    from mathutils import Vector

    if slot_ids is None:
        slot_ids = alpha_material_slots(obj)
    if not slot_ids:
        return 0, 0, 0

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.active
    petal_faces = [f for f in bm.faces if f.material_index in slot_ids]
    if not petal_faces or uv_layer is None:
        bm.free()
        return 0, 0, 0
    before = len(petal_faces)

    gw, gl = PATCH_GRID
    made = []
    comps = _blade_components(bm, slot_ids)
    for comp in comps:
        seen_uv = {}
        for f in comp:
            for l in f.loops:
                seen_uv.setdefault(l.vert, l[uv_layer].uv.copy())
        verts = list(seen_uv.keys())
        if len(verts) < 8:
            continue
        P = np.array([v.co[:] for v in verts])
        UV = np.array([seen_uv[v][:] for v in verts])
        mid = P.mean(axis=0)
        _, _, vt = np.linalg.svd(P - mid, full_matrices=False)
        e0, e1, e2 = vt[0], vt[1], vt[2]  # long axis, width, thickness
        Q = P - mid
        a, b, c = Q @ e0, Q @ e1, Q @ e2

        # UVs from a least-squares AFFINE fit of (a, b) -> (u, v). Fitting rather than
        # assuming an axis mapping handles whatever rotation or flip the vendor used,
        # and gives sane UVs for grid nodes that sit OUTSIDE the petal outline — which
        # is the normal case, since the card is a rectangle and the alpha does the shape.
        A = np.column_stack([a, b, np.ones_like(a)])
        coef, *_ = np.linalg.lstsq(A, UV, rcond=None)

        ga = np.linspace(a.min(), a.max(), gw)
        gb = np.linspace(b.min(), b.max(), gl)
        nodes = []
        for j in range(gl):
            row = []
            for i in range(gw):
                # thickness offset by inverse-distance weighting, so the patch follows the
                # petal's curl and extrapolates smoothly past its edge
                d2 = (a - ga[i]) ** 2 + (b - gb[j]) ** 2
                w = 1.0 / (d2 + 1e-9)
                off = float((w * c).sum() / w.sum())
                pos = mid + e0 * ga[i] + e1 * gb[j] + e2 * off
                uv = coef.T @ np.array([ga[i], gb[j], 1.0])
                row.append((bm.verts.new(Vector(pos)), uv))
            nodes.append(row)

        mi = comp[0].material_index
        for j in range(gl - 1):
            for i in range(gw - 1):
                quad = [nodes[j][i], nodes[j][i + 1], nodes[j + 1][i + 1], nodes[j + 1][i]]
                try:
                    nf = bm.faces.new([q[0] for q in quad])
                except ValueError:
                    continue
                nf.material_index = mi
                for loop, (_, uv) in zip(nf.loops, quad):
                    loop[uv_layer].uv = (float(uv[0]), float(uv[1]))
                made.append(nf)

    bmesh.ops.delete(bm, geom=petal_faces, context="FACES")
    # single-sided on purpose — set MeshPart.DoubleSided at import (see the header)
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    return before, len(made), len(comps)


# Rebuilt stem resolution: sides around x rings along. 5 sides reads round enough on
# something this thin at planting distance; 4 reads visibly square in silhouette.
TUBE_RES = (5, 8)


def tube_stems(obj, mat_prefix="Stem"):
    """Rebuild solid stem tubes at low resolution, following their own centreline.

    Ribboning is wrong here — a stem is genuinely cylindrical and seen from every side,
    so it keeps its round section and only loses radial and lengthwise resolution.
    Returns (faces_before, faces_after, stem_count).
    """
    import numpy as np
    from mathutils import Vector, kdtree

    slots = [m.name if m else "" for m in obj.data.materials]
    slot_ids = {i for i, n in enumerate(slots) if n.startswith(mat_prefix)}
    if not slot_ids:
        return 0, 0, 0

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.active
    stem_faces = [f for f in bm.faces if f.material_index in slot_ids]
    if not stem_faces or uv_layer is None:
        bm.free()
        return 0, 0, 0
    before = len(stem_faces)

    sides, rings = TUBE_RES
    made = []
    comps = _blade_components(bm, slot_ids)
    for comp in comps:
        seen_uv = {}
        for f in comp:
            for l in f.loops:
                seen_uv.setdefault(l.vert, l[uv_layer].uv.copy())
        verts = list(seen_uv.keys())
        if len(verts) < 12:
            continue
        uvs = [seen_uv[v] for v in verts]
        P = np.array([v.co[:] for v in verts])
        mid = P.mean(axis=0)
        _, _, vt = np.linalg.svd(P - mid, full_matrices=False)
        along, u1, u2 = vt[0], vt[1], vt[2]
        t = (P - mid) @ along
        lo, hi = t.min(), t.max()
        if hi - lo < 1e-9:
            continue

        kd = kdtree.KDTree(len(verts))
        for k, v in enumerate(verts):
            kd.insert(v.co, k)
        kd.balance()

        step = (hi - lo) / (rings - 1)
        ringverts = []
        for r in range(rings):
            a = lo + step * r
            sel = np.abs(t - a) <= step * 0.75
            if sel.sum() < 3:
                sel = np.argsort(np.abs(t - a))[:4]
            pts = P[sel]
            c = pts.mean(axis=0)  # the stem's OWN centreline, so its curve survives
            # ...but SLIDE it back onto the slice's intended position along the axis. A
            # windowed mean is pulled inward at the ends, so the tube stopped ~9% short of
            # the true tip — and since flower heads are separate components that did not
            # move, the stem no longer reached its flower. The symptom reads as "thin
            # stems"; it is actually a gap under the bloom.
            c = c - along * (float((c - mid) @ along) - a)
            d = pts - c
            radius = float(np.sqrt((d @ u1) ** 2 + (d @ u2) ** 2).mean())
            # CIRCUMSCRIBE, don't inscribe. Ring verts placed ON a circle of radius R give
            # a polygon whose flat sides sit at R*cos(pi/sides) — for 5 sides that is 0.809R,
            # so the stem renders up to 19% thinner than the tube it replaced. Measured: the
            # rebuilt flower stalks were visibly wispier than the originals.
            radius /= math.cos(math.pi / sides)
            ring = []
            for s in range(sides):
                ang = 2.0 * math.pi * s / sides
                pos = c + u1 * (radius * math.cos(ang)) + u2 * (radius * math.sin(ang))
                ring.append(bm.verts.new(Vector(pos)))
            ringverts.append(ring)

        mi = comp[0].material_index
        # no end caps: a stem is buried at one end and meets the flower at the other,
        # so the caps are never seen and would be pure cost
        for r in range(rings - 1):
            for s in range(sides):
                s2 = (s + 1) % sides
                quad = [ringverts[r][s], ringverts[r][s2], ringverts[r + 1][s2], ringverts[r + 1][s]]
                try:
                    nf = bm.faces.new(quad)
                except ValueError:
                    continue
                nf.material_index = mi
                for loop in nf.loops:
                    _, k, _ = kd.find(loop.vert.co)
                    loop[uv_layer].uv = uvs[k]
                made.append(nf)

    bmesh.ops.delete(bm, geom=stem_faces, context="FACES")
    bm.to_mesh(obj.data)
    obj.data.update()
    bm.free()
    return before, len(made), len(comps)


def main():
    args = argv_after_dashdash()
    report_only = "--report" in args
    ratio = flag(args, "--ratio", 0.35, float)
    out = flag(args, "--out", None)
    scale = flag(args, "--scale", 1.0, float)
    do_ribbon = "--ribbon" in args
    do_patch = "--patch" in args
    do_tube = "--tube" in args
    blade_mats = flag(args, "--blade-mats", "Leaves0")
    stem_mats = flag(args, "--stem-mats", "Stem")

    meshes = [o for o in bpy.data.objects if o.type == "MESH" and len(o.data.polygons) > 0]
    # the kits ship a leftover default Cube; it is a closed solid so `decide`
    # skips it anyway, but do not export it
    meshes = [o for o in meshes if o.name != "Cube"]
    meshes.sort(key=lambda o: o.name)

    # RIBBON FIRST, then double: ribbons are open sheets, so they must be present
    # before `decide` measures the boundary ratio, or they will not get doubled.
    ribbon_rows = []
    if do_ribbon and not report_only:
        for o in meshes:
            b, a, n = ribbon_blades(o, blade_mats)
            if n:
                ribbon_rows.append(
                    {"name": o.name, "blades": n, "blade_faces_before": b, "blade_faces_after": a}
                )

    tube_rows = []
    if do_tube and not report_only:
        for o in meshes:
            b, a, n = tube_stems(o, stem_mats)
            if n:
                tube_rows.append(
                    {"name": o.name, "stems": n, "stem_faces_before": b, "stem_faces_after": a}
                )

    patch_rows = []
    if do_patch and not report_only:
        for o in meshes:
            b, a, n = patch_petals(o)
            if n:
                patch_rows.append(
                    {"name": o.name, "petals": n, "petal_faces_before": b, "petal_faces_after": a}
                )

    # ⚠️ --ribbon / --patch / --tube all leave their output SINGLE-SIDED on purpose, for
    # MeshPart.DoubleSided to handle at import. Letting the doubling pass run afterwards
    # undoes that AND misfires: uncapped stem tubes push the object's boundary ratio past
    # the threshold, so `decide` reads the whole plant as open cards and doubles
    # everything. Measured: variant 001 came out at 2388 instead of 1194.
    # --no-double is the RECOMMENDED posture now that MeshPart.DoubleSided is known to
    # exist (see the header). Doubling remains available for assets where the flag cannot
    # be relied on.
    rebuilt = do_ribbon or do_patch or do_tube or ("--no-double" in args)
    rows = []
    doubled_total = 0
    for o in meshes:
        st = mesh_stats(o)
        should, why = decide(st, ratio)
        if rebuilt:
            should, why = False, "left single-sided on purpose; use MeshPart.DoubleSided"
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
                "ribboned": ribbon_rows,
                "patched": patch_rows,
                "tubed": tube_rows,
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
