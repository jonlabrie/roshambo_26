# bird_familiar.py — parametric low-poly familiar bird -> one skinnable Blender mesh.
#
# WHY PARAMETRIC: the familiar is a ROSTER, not one bird (owner 2026-08-19: uguisu first,
# karasu second). Every species differs in the same handful of numbers — body profile,
# tail length, wing shape, bill — so the shape lives in a SPECIES dict and a new bird is a
# data edit, not a new sculpt. Hand-sculpting bird #1 would have to be redone for bird #2.
#
# WHY ONE MESH: a Roblox skinned MeshPart deforms as a single mesh. Wings, tail, head and
# legs must therefore be joined into ONE object before rigging — separate objects would
# import as separate MeshParts that no bone can bind across.
#
# UNITS ARE STUDS. Build at 1 unit = 1 stud and export with global_scale=0.01, which is the
# established fix for Blender writing FBX in centimetres while Roblox reads the raw numbers
# (see docs/wiki/practice/blender-pipeline.md §1 — a 3.0-unit model landed as 300.03 studs).
#
# AXES: +Y is forward (the bird faces +Y), +Z is up, +X is the bird's right. Body centre sits
# at the world origin, because the importer points every pivot at a shared model origin and
# off-origin geometry leaves the pivots far from the parts (blender-pipeline.md §2).
#
# BIND POSE: wings SPREAD, not folded. Folding is the harder deformation and it is the one
# that needs bones; a spread bind pose lets the rig fold them, while a folded bind pose would
# need the rig to unfold — which tears the shoulder.
#
# Run headless:  blender -b -P tools/blender/bird_familiar.py -- uguisu
# Or exec the file inside a live Blender session (what the MCP does) to see it in the viewport.

import bpy
import bmesh
import math
import sys

# ---------------------------------------------------------------------------------------
# SPECIES DATA
# ---------------------------------------------------------------------------------------
# `profile` is the body loft: a list of stations running tail-base -> bill-base, each
#   (y, half_width, half_height, z_centre)
# The shell is built by sweeping a 12-point ellipse through these stations and bridging
# them. This single tube covers breast, belly, back, neck and head as one continuous
# surface — a bird has no seam there, and neither should the mesh.

UGUISU = {
    "name": "Uguisu",
    # Japanese bush warbler. Reference: /Users/jonlabrie/Desktop/Roshambo Reference/birds/.
    # Three things carry the species and every one of them is a proportion, not a texture:
    #   1. a TAIL nearly as long as the body, held down and back — the whole silhouette;
    #   2. a visible NECK PINCH, so the rounded head reads as a head and not as the front
    #      of one continuous ovoid (v1 had none and looked like a dove);
    #   3. a SHORT, deep-based bill — v1's was 0.135 long and read as a hummingbird needle.
    # Wings are short and BLUNT: a warbler's wing is rounded, not swept like a swallow's.
    "profile": [
        (-0.300, 0.034, 0.034,  0.026),   # rump. Sits HIGH so the tail leaves the rump,
        (-0.220, 0.070, 0.074,  0.012),   # not the middle of the back.
        (-0.120, 0.108, 0.120,  0.000),
        ( 0.000, 0.134, 0.150, -0.006),
        ( 0.090, 0.138, 0.156, -0.010),   # deepest: the chest is fullest FORWARD of centre
        ( 0.170, 0.126, 0.142, -0.002),
        ( 0.230, 0.104, 0.112,  0.014),   # throat
        ( 0.282, 0.096, 0.098,  0.030),   # neck. BARELY a pinch — 6% narrower than the head
        ( 0.330, 0.102, 0.102,  0.046),   # beside it. Owner ruled twice that the earlier
        ( 0.388, 0.102, 0.100,  0.054),   # pinches broke the streamline; a warbler's neck is
        ( 0.448, 0.086, 0.084,  0.052),   # a continuous line, not a waist.
        ( 0.498, 0.042, 0.038,  0.048),   # bill base, tucked under the brow
    ],
    "bill": {"root_y": 0.494, "length": 0.105, "root_half": 0.032,
             "tip_half": 0.006, "root_z": 0.046, "tip_z": 0.038},
    # The eye sits only just proud of the skull. v2 had it at r=0.026/x=0.106 against a
    # 0.116 half-width head and it read as a bolt screwed into the side.
    "eye":  {"y": 0.398, "x": 0.088, "z": 0.074, "r": 0.019},
    # Tail: stations along its length as (t, half_width). Graduated, not forked — the outer
    # feathers run shorter, which is what makes a warbler tail read rounded at the tip.
    # FIVE OVERLAPPING FEATHERS, not one plank. A single tapered blade reads as a wooden
    # paddle from every angle; overlapping blades of graduated length are what makes a bird
    # tail look like feathers, and it is what makes this tail read as a warbler's rounded
    # one rather than a forked or square one. Each entry is
    #   (lateral offset, splay degrees, length scale, root half-width)
    "tail": {"root_y": -0.265, "root_z": 0.030, "length": 0.540, "thickness": 0.016,
             "droop_deg": 14.0,
             # Splayed narrow, because the tail is seen PERCHED. v3's fan was a flight
             # spread and read like a peacock's.
             "feathers": [( 0.000,   0.0, 1.00, 0.040),
                          ( 0.026,   3.5, 0.95, 0.037),
                          (-0.026,  -3.5, 0.95, 0.037),
                          ( 0.048,   8.0, 0.86, 0.033),
                          (-0.048,  -8.0, 0.86, 0.033)]},
    # Wing: stations across the SPAN as (t, leading_y, trailing_y, z, half_thickness).
    # SHORT AND BLUNT. v2's wing tapered to a near-point over a 0.50 span and read as a
    # knife blade — a swift's wing, not a warbler's. The tip keeps a real chord (0.135) and
    # the span drops to 0.43, because a bush warbler is a skulking short-winged bird.
    "wing_spread": {"root_x": 0.120, "span": 0.430,
             "stations": [(0.00,  0.150, -0.110, 0.080, 0.022),
                          (0.25,  0.152, -0.190, 0.086, 0.019),
                          (0.55,  0.128, -0.238, 0.082, 0.015),
                          (0.80,  0.082, -0.252, 0.070, 0.011),
                          (0.93,  0.020, -0.238, 0.058, 0.008),
                          (1.00, -0.055, -0.190, 0.048, 0.006)],
             "dihedral_deg": 6.0},
    # THE BIND POSE IS FOLDED (owner 2026-08-19: "nobody cares what a flying bird's wings
    # look like"). The perched wing is what players see ~90% of the time, so it is the pose
    # that gets modelled accurately and flight is the approximation the rig produces — the
    # reverse of the usual convention, and correct here for exactly that reason.
    #
    # Three overlapping groups, outermost last, each a run of (y, z_centre, half_height,
    # x_offset). x_offset must EXCEED the body half-width at that station or the group
    # vanishes inside the flank. The primaries deliberately overshoot the rump and lie over
    # the tail base — that overlap is the single most recognisable thing about a folded wing.
    "wing_folded": {
        # ONE covert plate hugging the flank, plus THREE primary tips separating at the rear.
        # v4 modelled three full-length plates and they read as blocks bolted to the side:
        # a folded wing is mostly a SMOOTH surface continuous with the body, and the feathers
        # only become individually visible in the last third, where the primaries overshoot
        # the rump and lie across the tail base. That overshoot is the recognisable part.
        #
        # x_offset must sit just proud of the body half-width at that station (a few
        # thousandths) — too little and the plate vanishes inside the flank, too much and it
        # steps off the silhouette. half_height must stay INSIDE the body's vertical span at
        # that station for the same reason.
        "thickness": 0.009,
        "covert": [( 0.205, 0.055, 0.030, 0.112),
                   ( 0.130, 0.062, 0.062, 0.134),
                   ( 0.040, 0.052, 0.078, 0.142),
                   (-0.060, 0.028, 0.072, 0.126),
                   (-0.160, 0.000, 0.052, 0.098),
                   (-0.245, -0.018, 0.028, 0.062)],
        "tips": [[(-0.190,  0.004, 0.038, 0.086), (-0.330, -0.016, 0.012, 0.040)],
                 [(-0.200, -0.020, 0.036, 0.084), (-0.350, -0.036, 0.011, 0.036)],
                 [(-0.205, -0.044, 0.030, 0.080), (-0.345, -0.056, 0.010, 0.032)]]},
    # LIFE SIZE (owner 2026-08-19: "life-size, maybe slightly larger"). A real uguisu is
    # ~15cm nose to tail; at 1 stud = 1 foot that is 0.49 studs. 0.42 lands the model at
    # ~0.60 studs / 7 inches — life-size plus a little, as asked.
    # ⚠ This invalidates the tuning in BirdFlight: PERCH_RADIUS, the orbit radii and the
    # hold heights were all set against the old 1.4-stud bird.
    "scale": 0.42,
    # Shorter and stouter than v2, which stood the bird on insect stilts. A perching bird
    # shows very little tarsus — most of the leg is tucked into the flank feathering.
    "leg":  {"x": 0.072, "y": -0.010, "top_z": -0.140, "foot_z": -0.272,
             "thickness": 0.032, "forward_lean": 0.026,
             # Anisodactyl: two toes forward, one back (the hallux). That 2+1 arrangement is
             # what lets a passerine grip a branch, and it is the shape a viewer reads as
             # "gripping" rather than "standing on" — which matters when the whole point of
             # the resting state is that the bird has landed ON something.
             "toe_len": 0.078, "toe_root_w": 0.011, "toe_tip_w": 0.004,
             "toe_thick": 0.009, "toe_splay_deg": 24.0, "hallux_len": 0.052},
}

SPECIES = {"uguisu": UGUISU}

RING_SEGMENTS = 12          # around the body. 12 keeps the crown round in a close-up.
WING_CHORD_SEGMENTS = 4     # front-to-back divisions of the wing plate


# ---------------------------------------------------------------------------------------
# GEOMETRY HELPERS
# ---------------------------------------------------------------------------------------

def _ring(y, hw, hh, zc, n):
    """One ellipse of n points in the XZ plane at station y. Index 0 is the TOP (spine),
    which matters because the bake reads object-space Z for countershading."""
    pts = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        pts.append((hw * math.sin(a), y, zc + hh * math.cos(a)))
    return pts


def _bridge(bm, ring_a, ring_b):
    """Quad-bridge two equal-length vertex rings."""
    n = len(ring_a)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ring_a[i], ring_a[j], ring_b[j], ring_b[i]))


def _cap(bm, ring, centre_co):
    """Close a ring with a triangle fan to a centre vertex, rather than an n-gon — an
    n-gon at the crown shades as a flat facet and reads as a dent."""
    c = bm.verts.new(centre_co)
    n = len(ring)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ring[i], ring[j], c))
    return c


def _body(bm, spec):
    prof = spec["profile"]
    rings = []
    for (y, hw, hh, zc) in prof:
        rings.append([bm.verts.new(p) for p in _ring(y, hw, hh, zc, RING_SEGMENTS)])
    for a, b in zip(rings[:-1], rings[1:]):
        _bridge(bm, a, b)
    # Tail-end cap pulled slightly back, bill-end cap slightly forward, so both read as
    # rounded closures rather than flat lids.
    y0, _, _, z0 = prof[0]
    y1, _, _, z1 = prof[-1]
    _cap(bm, list(reversed(rings[0])), (0.0, y0 - 0.030, z0))
    _cap(bm, rings[-1], (0.0, y1 + 0.022, z1))


def _bill(bm, spec):
    b = spec["bill"]
    ry, L = b["root_y"], b["length"]
    # A four-sided taper. The tip drops slightly below the root: a straight-on-top,
    # faintly downcurved bill is what separates a warbler from a finch.
    root = [(-b["root_half"], ry, b["root_z"] + b["root_half"] * 0.55),
            ( b["root_half"], ry, b["root_z"] + b["root_half"] * 0.55),
            ( b["root_half"], ry, b["root_z"] - b["root_half"] * 0.55),
            (-b["root_half"], ry, b["root_z"] - b["root_half"] * 0.55)]
    tip = [(-b["tip_half"], ry + L, b["tip_z"] + b["tip_half"]),
           ( b["tip_half"], ry + L, b["tip_z"] + b["tip_half"]),
           ( b["tip_half"], ry + L, b["tip_z"] - b["tip_half"]),
           (-b["tip_half"], ry + L, b["tip_z"] - b["tip_half"])]
    rv = [bm.verts.new(p) for p in root]
    tv = [bm.verts.new(p) for p in tip]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((rv[i], rv[j], tv[j], tv[i]))
    bm.faces.new(tuple(reversed(tv)))
    bm.faces.new(tuple(rv))


def _eyes(bm, spec):
    e = spec["eye"]
    for sx in (-1.0, 1.0):
        bmesh.ops.create_uvsphere(
            bm, u_segments=8, v_segments=6, radius=e["r"],
            matrix=_translate(sx * e["x"], e["y"], e["z"]))


def _translate(x, y, z):
    from mathutils import Matrix
    return Matrix.Translation((x, y, z))


def _blade(bm, stations, half_t):
    """Bridge a run of (centre_x, y, z, half_width) stations into a flat two-sided blade."""
    top, bot = [], []
    for (cx, y, z, w) in stations:
        top.append([bm.verts.new((cx - w, y, z + half_t)), bm.verts.new((cx + w, y, z + half_t))])
        bot.append([bm.verts.new((cx - w, y, z - half_t)), bm.verts.new((cx + w, y, z - half_t))])
    for i in range(len(stations) - 1):
        bm.faces.new((top[i][0], top[i][1], top[i + 1][1], top[i + 1][0]))
        bm.faces.new((bot[i + 1][0], bot[i + 1][1], bot[i][1], bot[i][0]))
        bm.faces.new((top[i][1], bot[i][1], bot[i + 1][1], top[i + 1][1]))
        bm.faces.new((bot[i][0], top[i][0], top[i + 1][0], bot[i + 1][0]))
    bm.faces.new((top[0][0], bot[0][0], bot[0][1], top[0][1]))
    bm.faces.new((top[-1][1], bot[-1][1], bot[-1][0], top[-1][0]))


def _tail(bm, spec):
    t = spec["tail"]
    droop = math.radians(t["droop_deg"])
    half_t = t["thickness"] * 0.5
    for (off_x, splay_deg, lscale, hw) in t["feathers"]:
        yaw = math.radians(splay_deg)
        L = t["length"] * lscale
        stations = []
        for (u, wf) in ((0.0, 1.00), (0.55, 0.92), (1.0, 0.42)):
            d = u * L
            y = t["root_y"] - d * math.cos(droop) * math.cos(yaw)
            # Outer feathers ride slightly LOWER, so the fan layers instead of z-fighting.
            z = t["root_z"] - d * math.sin(droop) - abs(off_x) * 0.30
            cx = off_x + d * math.sin(yaw)
            stations.append((cx, y, z, hw * wf))
        _blade(bm, stations, half_t)


def _flank_blade(bm, side, stations, half_t):
    """A feather group lying flat against the flank. Thickness runs along X so the blade
    presents its FACE outward — a folded wing is seen side-on and never edge-on, which is
    the opposite of the tail and needs its own builder."""
    out, inn = [], []
    for (y, zc, hh, xo) in stations:
        x = side * xo
        t = side * half_t
        out.append([bm.verts.new((x + t, y, zc + hh)), bm.verts.new((x + t, y, zc - hh))])
        inn.append([bm.verts.new((x - t, y, zc + hh)), bm.verts.new((x - t, y, zc - hh))])
    for i in range(len(stations) - 1):
        bm.faces.new((out[i][0], out[i][1], out[i + 1][1], out[i + 1][0]))
        bm.faces.new((inn[i + 1][0], inn[i + 1][1], inn[i][1], inn[i][0]))
        bm.faces.new((out[i][0], out[i + 1][0], inn[i + 1][0], inn[i][0]))
        bm.faces.new((inn[i][1], inn[i + 1][1], out[i + 1][1], out[i][1]))
    bm.faces.new((out[0][0], out[0][1], inn[0][1], inn[0][0]))
    bm.faces.new((inn[-1][0], inn[-1][1], out[-1][1], out[-1][0]))


def _wing_folded(bm, spec, side):
    w = spec["wing_folded"]
    half_t = w["thickness"] * 0.5
    _flank_blade(bm, side, w["covert"], half_t)
    for tip in w["tips"]:
        _flank_blade(bm, side, tip, half_t * 0.8)


def _wing(bm, spec, side):
    w = spec["wing_spread"]
    dih = math.radians(w["dihedral_deg"])
    cols = []
    for (u, lead_y, trail_y, z, ht) in w["stations"]:
        x = side * (w["root_x"] + u * w["span"])
        zz = z + abs(u * w["span"]) * math.sin(dih)
        upper, lower = [], []
        for k in range(WING_CHORD_SEGMENTS + 1):
            f = k / WING_CHORD_SEGMENTS
            y = lead_y + (trail_y - lead_y) * f
            # Camber: thickest a third back from the leading edge, thin at both edges.
            camber = math.sin(math.pi * min(1.0, f * 1.35)) * ht
            upper.append(bm.verts.new((x, y, zz + camber)))
            lower.append(bm.verts.new((x, y, zz - camber * 0.45)))
        cols.append((upper, lower))
    for i in range(len(cols) - 1):
        ua, la = cols[i]
        ub, lb = cols[i + 1]
        for k in range(WING_CHORD_SEGMENTS):
            if side > 0:
                bm.faces.new((ua[k], ua[k + 1], ub[k + 1], ub[k]))
                bm.faces.new((lb[k], lb[k + 1], la[k + 1], la[k]))
            else:
                bm.faces.new((ub[k], ub[k + 1], ua[k + 1], ua[k]))
                bm.faces.new((la[k], la[k + 1], lb[k + 1], lb[k]))
        bm.faces.new((ua[0], ub[0], lb[0], la[0]) if side > 0
                     else (la[0], lb[0], ub[0], ua[0]))
        bm.faces.new((la[-1], lb[-1], ub[-1], ua[-1]) if side > 0
                     else (ua[-1], ub[-1], lb[-1], la[-1]))
    ut, lt = cols[-1]
    for k in range(WING_CHORD_SEGMENTS):
        bm.faces.new((ut[k], ut[k + 1], lt[k + 1], lt[k]) if side > 0
                     else (lt[k], lt[k + 1], ut[k + 1], ut[k]))


def _toe(bm, x0, y0, z0, ang_deg, length, root_w, tip_w, thick):
    """One tapered toe laid on the perch plane, splayed ang_deg off straight-ahead."""
    a = math.radians(ang_deg)
    dx, dy = math.sin(a), math.cos(a)
    px, py = math.cos(a), -math.sin(a)

    def quad(x, y, z, w, t):
        return [bm.verts.new((x - px * w, y - py * w, z + t)),
                bm.verts.new((x + px * w, y + py * w, z + t)),
                bm.verts.new((x + px * w, y + py * w, z - t)),
                bm.verts.new((x - px * w, y - py * w, z - t))]

    root = quad(x0, y0, z0, root_w, thick)
    tip = quad(x0 + dx * length, y0 + dy * length, z0 - thick * 0.35, tip_w, thick * 0.5)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((root[i], root[j], tip[j], tip[i]))
    bm.faces.new(tuple(root))
    bm.faces.new(tuple(reversed(tip)))


def _leg(bm, spec, side):
    g = spec["leg"]
    x = side * g["x"]
    r = g["thickness"] * 0.5
    top_y, foot_y = g["y"], g["y"] + g["forward_lean"]
    ring_top, ring_bot = [], []
    for i in range(6):
        a = 2.0 * math.pi * i / 6
        ring_top.append(bm.verts.new((x + r * math.sin(a), top_y + r * math.cos(a), g["top_z"])))
        ring_bot.append(bm.verts.new((x + r * 0.7 * math.sin(a),
                                      foot_y + r * 0.7 * math.cos(a), g["foot_z"])))
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new((ring_top[i], ring_top[j], ring_bot[j], ring_bot[i]))
    bm.faces.new(tuple(ring_top))
    tl, tw, tt = g["toe_len"], g["toe_root_w"], g["toe_thick"]
    sp = g["toe_splay_deg"]
    for ang, ln in ((-sp, tl * 0.95), (sp, tl), (180.0, g["hallux_len"])):
        _toe(bm, x, foot_y, g["foot_z"], ang, ln, tw, g["toe_tip_w"], tt)


# ---------------------------------------------------------------------------------------
# BUILD
# ---------------------------------------------------------------------------------------

def build(species_key="uguisu", pose="folded"):
    spec = SPECIES[species_key]
    name = spec["name"]

    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)

    bm = bmesh.new()
    _body(bm, spec)
    bm.faces.ensure_lookup_table()
    body_face_count = len(bm.faces)     # smooth-shade only these; see below
    _bill(bm, spec)
    _eyes(bm, spec)
    _tail(bm, spec)
    for side in (-1.0, 1.0):
        (_wing_folded if pose == "folded" else _wing)(bm, spec, side)
        _leg(bm, spec, side)

    # Scale LAST, so every number in the species dict stays in one readable coordinate
    # system and only this one value carries real-world size.
    sc = spec.get("scale", 1.0)
    if sc != 1.0:
        bmesh.ops.scale(bm, vec=(sc, sc, sc), verts=bm.verts[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # Smooth the body shell ONLY. A 12-segment body reads faceted like a cut gem when
    # flat-shaded, but a smooth-shaded wing plate or bill loses the hard edge that makes
    # it legible in silhouette — the one thing that survives at arena distance.
    for i, poly in enumerate(me.polygons):
        poly.use_smooth = i < body_face_count

    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    dims = tuple(round(d, 3) for d in ob.dimensions)
    return {"object": name, "pose": pose, "verts": len(me.vertices), "tris": tris,
            "dims_studs": dims, "length_inches": round(dims[1] * 12.0, 1)}


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["uguisu"]
    print(build(argv[0], argv[1] if len(argv) > 1 else "folded"))
