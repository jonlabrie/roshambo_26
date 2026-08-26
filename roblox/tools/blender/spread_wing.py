# spread_wing.py — a SPREAD wing for a familiar: one membrane, scalloped trailing edge.
#
# WHY SEPARATE GEOMETRY. The bird's own wings are modelled FOLDED, on the owner's ruling that
# perched is ~90% of viewing time. That was right and it is final: a folded wing has no wing area
# to open, so lifting it stretches flank surface instead. Measured on the uguisu, 30 degrees of
# lift moves the tip 0.037 studs — under half an inch, which is why the owner reported "NO motion
# on the bird that reads as flapping at any time" (2026-08-21). No amount of driving the folded
# wing fixes that; the geometry is absent.
#
# THE TRAILING EDGE IS WHERE THE FEATHER READ LIVES. The first version swept a cambered skin
# through six stations with a clean arc of a trailing edge, and the owner's verdict was "they look
# like crap" — it read quilted and rubbery, a paddle rather than a wing. Two further passes built
# it from separate radiating feathers, which failed the other way (see the comb note below). What
# works is a single continuous surface whose trailing edge is NOTCHED per feather: no seams
# anywhere, and the silhouette does the identifying.
#
# The wing is built in the SAME coordinate frame as the bird (+Y forward, +Z up, +X right) with
# its ORIGIN AT THE SHOULDER JOINT.

import bpy
import bmesh
import math

# ⚠ A WING IS NOT A COMB. Two passes built it from separate radiating feathers and both showed
# daylight between them: the vanes fan apart faster than they are wide, so every gap opens into a
# triangle. Real anatomy is the fix, not wider blades — the SECONDARIES overlap into a continuous
# vane, and separating them is what produced the comb. The wing is therefore ONE solid membrane
# whose trailing edge is SCALLOPED per feather.
#
# Planform stations across the span: (t, leading_y, trailing_y, z_rise)
# ⚠ THE LAST STATIONS CONVERGE, AND THEY DID NOT USED TO. The plan ended at t=1.00 with a 0.114
# chord and the loft caps the outermost column flat, so the wing finished in a SQUARED-OFF CUT.
# Found on the karasu (owner, 2026-08-26) and present here too — proportionally WORSE, at 24% of
# span against the crow's 13%. It went unnoticed for the same reason it was tolerable: this wing is
# 0.47 studs long, exists only in flight, and belongs to a bird whose wings are hidden at rest.
PLAN = [
    (0.00,  0.030, -0.150, 0.000),
    (0.16,  0.038, -0.205, 0.010),
    (0.36,  0.030, -0.248, 0.022),
    (0.56,  0.006, -0.272, 0.033),
    (0.74, -0.028, -0.276, 0.042),
    (0.88, -0.062, -0.258, 0.048),
    (0.92, -0.074, -0.250, 0.0495),
    (0.96, -0.088, -0.234, 0.0510),
    (1.00, -0.122, -0.166, 0.052),
]
SCALLOP = 0.016        # how deep the trailing edge notches between feather tips
N_SCALLOP = 9          # tips along the trailing edge
# ⚠ NO SEPARATE "FINGER" PRIMARIES. Four of them were built to extend past the trailing edge and
# they read as detached shards, not feathers (owner, 2026-08-21): they grafted onto an edge that
# is ALREADY scalloped, so a finger could spring from the bottom of a notch; they were separate
# blades, so each showed a break where it began; and at 0.02 half-width against a 0.47 wing they
# were too small to read as anatomy. The scalloped trailing edge alone carries the feather read,
# and it does it with no seams. Adding detail on top of a sufficient solution was the same
# mistake as putting gradients on the wing texture.
FEATHER_THICK = 0.0045        # a feather is a vane, not a plank
AOA_RISE = 0.026              # leading edge above trailing (owner: "forward part... above")
AOA_WASHOUT = 0.45


def build(name="UguisuWing", span=0.47, scale=1.0, uv_region=(0.06, 0.06, 0.30)):
    """span is ONE wing, shoulder to tip. A real uguisu is 15-16cm long with a 19-22cm span, so
    full span runs about 1.35x body length — not the 1.7x a first guess reaches for, which
    produced a bird that read as a gull."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)

    bm = bmesh.new()

    def plan_at(u):
        for i in range(len(PLAN) - 1):
            a, b = PLAN[i], PLAN[i + 1]
            if a[0] <= u <= b[0]:
                f = (u - a[0]) / max(1e-6, b[0] - a[0])
                return tuple(a[k] + (b[k] - a[k]) * f for k in (1, 2, 3))
        return PLAN[-1][1], PLAN[-1][2], PLAN[-1][3]

    # 1. THE MEMBRANE. One continuous surface, sampled finely enough that the scalloped trailing
    #    edge lands on real geometry rather than being faked by the texture.
    # ⚠ 25 IS DELIBERATE, NOT INHERITED. 1/25 = 0.04 exactly, so the taper stations at 0.88, 0.92,
    # 0.96 and 1.00 land ON columns rather than being interpolated between them — the convergence
    # is sampled where it is defined. Raising this would need the stations moved to match.
    COLS = 25
    cols = []
    for c in range(COLS + 1):
        u = c / COLS
        lead, trail, zr = plan_at(u)
        x = u * span
        # Scallop: the trailing edge notches back and forth so each bump is one feather tip.
        phase = u * N_SCALLOP * math.pi
        # ⚠ CLAMPED TO THE LOCAL CHORD — see the karasu's copy of this for the full reasoning.
        # A fixed notch against a now-narrowing tip chord would invert the trailing edge.
        depth = min(SCALLOP * (0.35 + 0.65 * u), abs(trail - lead) * 0.35)
        notch = (0.5 - 0.5 * math.cos(2.0 * phase)) * depth
        trail += notch
        base_z = zr + AOA_RISE * 0.5 * (1.0 - (1.0 - AOA_WASHOUT) * u)
        rows = []
        for k in range(4):
            f = k / 3.0
            y = lead + (trail - lead) * f
            tilt = (0.5 - f) * AOA_RISE * (1.0 - (1.0 - AOA_WASHOUT) * u)
            camber = math.sin(math.pi * min(1.0, f * 1.4)) * 0.006 * (1.0 - 0.6 * u)
            rows.append((x, y, base_z + tilt + camber))
        cols.append(rows)
    top, bot = [], []
    for rows in cols:
        top.append([bm.verts.new((x, y, z + FEATHER_THICK)) for (x, y, z) in rows])
        bot.append([bm.verts.new((x, y, z - FEATHER_THICK)) for (x, y, z) in rows])
    for i in range(COLS):
        for k in range(3):
            bm.faces.new((top[i][k], top[i][k + 1], top[i + 1][k + 1], top[i + 1][k]))
            bm.faces.new((bot[i + 1][k], bot[i + 1][k + 1], bot[i][k + 1], bot[i][k]))
        bm.faces.new((top[i][0], top[i + 1][0], bot[i + 1][0], bot[i][0]))
        bm.faces.new((bot[i][3], bot[i + 1][3], top[i + 1][3], top[i][3]))
    for idx, sgn in ((0, 1), (-1, -1)):
        for k in range(3):
            a, b = top[idx][k], top[idx][k + 1]
            c, d = bot[idx][k], bot[idx][k + 1]
            bm.faces.new((a, b, d, c) if sgn > 0 else (c, d, b, a))

    if scale != 1.0:
        bmesh.ops.scale(bm, vec=(scale, scale, scale), verts=bm.verts[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # FLAT SHADING. Smooth shading over a feathered wing melts the separations back together —
    # the hard edge between vanes is the whole point.
    for p in me.polygons:
        p.use_smooth = False

    # uv_region is (u0, v0, size) and MUST be free space in the bird's own unwrap — pass it from
    # bake_bird_texture.find_free_uv_block(). Upper and lower shells split the region's height,
    # with a gap so bilinear sampling cannot pull one into the other.
    uv = me.uv_layers.new(name="DiffuseUV")
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    ru, rv, rs = uv_region
    half = rs * 0.46
    gap = rs * 0.08
    for poly in me.polygons:
        upper = poly.normal.z >= 0.0
        vbase = rv if upper else rv + half + gap
        for li in poly.loop_indices:
            c = me.vertices[me.loops[li].vertex_index].co
            u = (c.x - x0) / max(1e-6, x1 - x0)
            v = (c.y - y0) / max(1e-6, y1 - y0)
            uv.data[li].uv = (ru + u * rs, vbase + v * half)

    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return {"object": name, "verts": len(me.vertices),
            "tris": sum(len(p.vertices) - 2 for p in me.polygons),
            "dims": tuple(round(d, 4) for d in ob.dimensions)}
