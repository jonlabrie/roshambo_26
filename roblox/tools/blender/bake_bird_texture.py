# bake_bird_texture.py — paint a familiar bird's ColorMap directly into its existing UVs.
#
# WHY NOT A CYCLES BAKE: the established bake recipe (blender-pipeline.md) is for transferring
# an existing high-poly look down onto a low-poly shell. Here there is no source look — the
# vendor's map is a photoreal SPARROW (chestnut cap, black bib, white collar) and the target is
# a plain olive uguisu. So this rasterises a colour FUNCTION of 3D position and normal straight
# into texel space. That keeps the whole palette as readable numbers, makes the crow a palette
# edit rather than a repaint, and produces crisp features (eye, supercilium) that a
# vertex-colour bake could never resolve on a head carrying ~100 vertices.
#
# WHY IT KEEPS THE VENDOR'S UNWRAP: a non-overlapping unwrap is genuinely valuable and is most
# of what the purchased model is worth. We repaint into it rather than re-unwrapping.
#
# OUTPUT IS 1024² — Roblox silently downscales anything larger (blender-pipeline.md).
#
# Run inside Blender (the MCP execs this file):  bake(object_name, species) -> dict

import bpy
import numpy as np
from mathutils import Vector

RES = 1024

# --- palettes, sRGB 0-255 ---------------------------------------------------------------
UGUISU = {
    # Olive, not brown. The first bake used (139,124,85) and rendered as a chocolate thrush;
    # an uguisu's upperparts carry a distinct green cast.
    "dorsal":      (132, 126, 84),    # back: olive
    "crown":       (106, 104, 72),    # crown/nape: greyer, darker
    "wing_tail":   (140, 124, 80),    # flight feathers: a touch warmer
    "ventral":     (222, 216, 198),   # throat/breast: pale buff-white
    "flank":       (186, 176, 148),   # buffier where it meets the dorsal line
    "supercilium": (214, 208, 184),   # THE field mark — pale brow over a dark eye-line.
    "eyeline":     (92, 82, 58),      # BUFF, not white: the first bake read as a paint stripe.
    "eye":         (20, 18, 16),
    "bill_upper":  (74, 64, 52),      # dark horn
    "bill_lower":  (185, 155, 121),   # pale pinkish
    "covert":      (124, 114, 76),    # the folded wing panel: a shade darker than the mantle
    "covert_edge": (100, 92, 62),     # and a line along its upper edge, or it does not read
    "leg":         (168, 136, 110),
    "gape":        (58, 42, 38),      # the interior faces the split exposed
}
# --- karasu ---------------------------------------------------------------------------
# ⚠ A CROW IS NOT A PALETTE EDIT, AND SAYING SO EARLY SAVES THE NEXT BIRD. What transfers from
# the uguisu is the MACHINERY -- the triangle rasteriser, the adaptive face/vertex normal blend,
# the dilation pass, the UV-clash guard -- and the idea that colour is a function of 3D position.
# What does not transfer is the shading LAW, because the two birds are marked differently: an
# uguisu is defined by a pale supercilium over a dark eye-line, and a karasu has no field marks
# at all. `shade_corvid` is therefore its own function rather than `shade` with two flags off;
# cramming both into one would make both harder to read and neither easier to change.
#
# ⚠ AND IT IS NOT ACTUALLY BLACK. A hashibutogarasu photographs near-black, but painting it that
# way gives a bird with no internal contrast that reads as a hole in the screen at arena
# distance -- the one thing a familiar cannot be, since the whole point is that it is legible
# across a crowded arena. Everything below sits in the 40-110 range and reads as black under
# game lighting while keeping its form. The countershading runs COOL-over-WARM rather than
# dark-over-pale: a crow's gloss is blue-violet on the mantle and its underparts are duller and
# browner, so hue does the work that lightness does on the uguisu.
KARASU = {
    # ⚠ THESE ARE THE SECOND SET. The first ran 28-88 and, rendered, the bird was a silhouette --
    # correct-looking as a photograph and useless as a familiar, which has to stay legible across
    # a crowded arena on a phone. Everything is lifted ~35% here; it still reads as a black bird
    # because the HUE relationships carry it, and now it holds its form.
    "dorsal":      (66, 68, 86),      # mantle: cool blue-black
    "crown":       (52, 53, 66),      # crown and nape, darker and flatter
    "wing_tail":   (76, 79, 104),     # flight feathers carry the most gloss
    "ventral":     (80, 77, 79),      # breast and belly: warmer, duller charcoal
    "flank":       (70, 68, 75),
    "throat":      (60, 59, 64),      # the hackles a hashibutogarasu wears on its throat
    "covert":      (62, 64, 82),      # the folded wing panel, a shade cooler than the mantle
    "covert_edge": (104, 108, 138),   # ⚠ THE ONE LINE THAT MAKES THE WING READ. The folded wing
                                      # here is deliberately low-relief geometry, so its edge has
                                      # to be drawn. Same finding as the uguisu, and it matters
                                      # more on a bird with no other markings at all.
    # ⚠ THE EYE IS A DARK SOCKET WITH ONE BIG GLINT, FRAMED BY PALER FEATHERING -- measured off
    # `birds/Jungle_crow_Close-up.jpg` on 2026-08-28, as luminance RATIOS against the plain head
    # feather beside it, so they survive this palette's ~35% legibility lift:
    #     highlight 3.08x | ear-covert stipple 1.37x | lid 0.72-0.50x | iris 0.66x | pupil 0.14x
    # ⚠ THE IRIS IS DARKER THAN THE FEATHERS, NOT LIGHTER. Two sessions in a row reasoned that a
    # bird's eye reads because the iris is a pale warm brown against black; the photograph says
    # the opposite -- every part of the eye except the glint is darker than the head around it.
    # What makes a crow's eye read is CONTRAST WITH ITS OWN SURROUND, not a light iris.
    # ⚠ NO `eye` COLOUR, and none should come back. The eyeball is a separate Roblox part with
    # its own Material and Reflectance ([[familiars]]); the texture paints only the socket.
    "lid":         (28, 26, 28),      # the socket rim, darker than the feathers it sits in
    # ⚠ `catchlight` and `periocular` are GONE and must stay gone. The glint is now a real
    # specular on a separate glossy part, which MOVES with the camera; a painted one underneath
    # would sit still beside it and give the bird two highlights, one of them obviously fake.
    "bill":        (42, 42, 48),      # heavy, matte, and the same colour top and bottom -- what
    "bill_gloss":  (72, 73, 86),      # separates the mandibles is the culmen highlight and the
    "leg":         (40, 40, 44),      # dark gape line between them, not two colours
    "gape":        (84, 54, 54),
}

# `landmarks` are in the FINAL mesh's own coordinates. `ref_length` is the nose-to-tail span they
# were measured at, and bake() rescales them if the mesh it is handed differs -- see the warning
# on LANDMARK_REF_LENGTH below, which was written after a 1.5x scale-up painted the supercilium
# across the breast.
SPECIES = {
    "uguisu": {"palette": UGUISU, "shader": "warbler", "ref_length": 0.552},
    "karasu": {"palette": KARASU, "shader": "corvid", "ref_length": 1.640,
               # ⚠ THESE ARE A FALLBACK AND A RECORD, NOT THE VALUES ACTUALLY USED.
               # `karasu_retarget.bake_and_finish` now OVERWRITES this dict from
               # `landmarks_final()` immediately before baking, so the paint always describes the
               # mesh that was just built. That is new on 2026-08-28 and it closed a real gap:
               # this comment used to claim every number here "comes from landmarks_final()", and
               # `eye` and `catchlight` did not -- landmarks_final did not emit them at all. They
               # were hand-measured and typed, so a reshape of the head slid the skull out from
               # under them with nothing to notice. The 2026-08-28 belly-and-culmen pass raised
               # the crown 0.0033 studs at the eye's station, 14% of the eye's radius: too small
               # to see, and exactly the size that accumulates.
               # ⚠ `throat_y` and `leg_z` still have NO derivation and are the live instance of
               # the same risk. A landmark that stops describing the geometry it draws is how the
               # uguisu's supercilium ended up painted across its breast.
               "landmarks": {
                   "eye": (0.062, 0.560, 0.836), "eye_r": 0.024,
                   # the folded wing plate's own top edge
                   "covert_edge_y": (-0.4346, -0.3092, -0.1837, -0.0917,
                                     0.0170, 0.1509, 0.2763, 0.3851),
                   "covert_edge_z": (0.2767, 0.3194, 0.3645, 0.4180,
                                     0.4724, 0.5937, 0.6522, 0.6857),
                   "covert_back_y": -0.4546, "covert_front_y": 0.3951,
                   "gape_p": (0.0, 0.7364, 0.7990), "gape_n": (0.0, 0.0599, 0.9982),
                   "bill_y": 0.6286, "throat_y": (0.280, 0.500), "leg_z": 0.230,
                   "tail_root_y": -0.2004,
               }},
}

# --- landmarks, measured off the retargeted mesh -----------------------------------------
# ⚠ THESE ARE ABSOLUTE COORDINATES, AND THE MESH CAN BE RESCALED UNDER THEM. Every landmark below
# was measured on a bird whose body ran LANDMARK_REF_LENGTH studs nose to tail. Scale the mesh and
# the vertices move while these numbers do not — the eye ends up inside the body and the
# supercilium paints across the breast, which is exactly what a 1.5x scale-up produced on
# 2026-08-21. `bake()` therefore measures the mesh and rescales every landmark to match, so the
# numbers here always mean what they meant when they were measured.
LANDMARK_REF_LENGTH = 0.552
EYE = (0.0290, 0.1290, 0.2660)        # (|x|, y, z) — mirrored, so only |x| is used
EYE_R = 0.0076
# The brow sits DIRECTLY over the line. v1 left a 0.015 gap of body colour between them, which
# read as two unrelated bars rather than one field mark.
BROW_A, BROW_B = (0.1500, 0.2745), (0.0960, 0.2812)   # supercilium, in (y, z)
LINE_A, LINE_B = (0.1500, 0.2650), (0.0990, 0.2700)   # eye-line, in (y, z)
BILL_Y = 0.1480
GAPE_P = (0.0, 0.1480, 0.2641)
GAPE_N = (0.0, -0.4510, -0.8924)      # >0 is below the gape


def _srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _seg_dist(py, pz, a, b):
    """Distance from points to the segment a->b, both given in the (y, z) plane."""
    ay, az = a
    by, bz = b
    dy, dz = by - ay, bz - az
    L2 = dy * dy + dz * dz
    t = np.clip(((py - ay) * dy + (pz - az) * dz) / L2, 0.0, 1.0)
    return np.hypot(py - (ay + t * dy), pz - (az + t * dz))


def shade(P, N, pal, S=1.0):
    """P (M,3) positions, N (M,3) normals -> (M,3) linear RGB. Vectorised."""
    C = {k: _srgb_to_linear(v) for k, v in pal.items()}
    # Work in REFERENCE space: undo the mesh's scale so every landmark constant below is
    # comparable to the coordinates it was measured in.
    P = P / S
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]
    M = len(y)
    out = np.zeros((M, 3))

    # 1. COUNTERSHADING off the normal, not off height: a bird's pale underside follows the
    #    surface facing the ground, which is what the normal already encodes. Height alone
    #    paints the top of the folded wing the same as the top of the head.
    dorsal = _smooth(-0.42, 0.52, N[:, 2])   # wide: a hard flank line reads as a paint edge
    warm = _smooth(0.02, -0.14, y)                       # toward the tail: warmer feathers
    upper = C["dorsal"] * (1 - warm)[:, None] + C["wing_tail"] * warm[:, None]
    crown = _smooth(0.070, 0.115, y)                     # crown and nape go greyer
    upper = upper * (1 - crown)[:, None] + C["crown"] * crown[:, None]
    lower = C["ventral"] * (1 - (1 - dorsal))[:, None] * 0 + C["ventral"]
    flankish = _smooth(0.15, 0.55, dorsal)
    lower = lower * (1 - flankish)[:, None] + C["flank"] * flankish[:, None]
    out = lower * (1 - dorsal)[:, None] + upper * dorsal[:, None]

    # 1b. THE FOLDED WING. It is modelled into the flank (115 sharp crease edges trace its
    #     outline from the shoulder back past the rump), but with one flat colour over the
    #     whole back its edge vanishes. A panel a shade darker than the mantle, plus a line
    #     along the covert edge, is what makes the wing read as a wing at distance.
    edge_z = 0.200 + (y - 0.050) * (0.120 - 0.200) / (-0.220 - 0.050)   # covert edge line
    under = _smooth(0.012, -0.004, z - edge_z)          # below the edge
    zone = under * _smooth(0.020, 0.032, x) * _smooth(-0.265, -0.235, y) \
        * (1.0 - _smooth(0.030, 0.070, y)) * _smooth(0.075, 0.100, z) * dorsal
    out = out * (1 - zone)[:, None] + C["covert"] * zone[:, None]
    line_w = (1.0 - _smooth(0.0015, 0.0055, np.abs(z - edge_z))) * _smooth(0.020, 0.032, x) \
        * _smooth(-0.265, -0.235, y) * (1.0 - _smooth(0.030, 0.070, y)) * dorsal
    out = out * (1 - line_w)[:, None] + C["covert_edge"] * line_w[:, None]

    # 2. Head markings. Gated on |x| so they only appear on the sides of the head.
    head = (y > 0.082) & (y < 0.168)
    if head.any():
        brow = _seg_dist(y, z, BROW_A, BROW_B)
        line = _seg_dist(y, z, LINE_A, LINE_B)
        # Gate on |x| so the marks stay on the CHEEK; v1 let them ride over the crown.
        # `taper` fades them out at both ends instead of the boolean head mask cutting them
        # square, which is what made them render as rectangles.
        side = _smooth(0.016, 0.026, x)
        taper = _smooth(0.088, 0.104, y) * (1.0 - _smooth(0.150, 0.164, y))
        wl = (1.0 - _smooth(0.0012, 0.0044, line)) * side * taper
        out = out * (1 - wl)[:, None] + C["eyeline"] * wl[:, None]
        wb = (1.0 - _smooth(0.0011, 0.0040, brow)) * side * taper
        out = out * (1 - wb)[:, None] + C["supercilium"] * wb[:, None]

    # 3. Eye
    de = np.sqrt((x - EYE[0]) ** 2 + (y - EYE[1]) ** 2 + (z - EYE[2]) ** 2)
    we = 1.0 - _smooth(EYE_R * 0.55, EYE_R, de)
    out = out * (1 - we)[:, None] + C["eye"] * we[:, None]

    # 4. Bill, split at the gape plane, plus the interior faces the split exposed
    gp = np.array(GAPE_P)
    gn = np.array(GAPE_N)
    sd = (P - gp) @ gn
    bill = y > BILL_Y - 0.004
    wu = (bill & (sd <= 0)).astype(float)
    wl2 = (bill & (sd > 0)).astype(float)
    blend = _smooth(BILL_Y - 0.004, BILL_Y + 0.006, y)
    out = out * (1 - wu * blend)[:, None] + C["bill_upper"] * (wu * blend)[:, None]
    out = out * (1 - wl2 * blend)[:, None] + C["bill_lower"] * (wl2 * blend)[:, None]
    inner = bill & (np.abs(sd) < 0.0035) & (np.abs(N[:, 2]) > 0.35)
    out = np.where(inner[:, None], C["gape"], out)

    # 5. Legs and feet
    leg = _smooth(0.090, 0.055, z) * ((y > -0.09) & (y < 0.09)).astype(float)
    out = out * (1 - leg)[:, None] + C["leg"] * leg[:, None]
    return np.clip(out, 0.0, 1.0)


def shade_corvid(P, N, pal, S=1.0, lm=None):
    """The karasu. A SEPARATE LAW from `shade`, not the same one with flags off.

    An uguisu is defined by two marks -- a pale supercilium over a dark eye-line -- and a karasu
    has none at all. So the whole problem inverts: the warbler shader spends its effort placing
    marks, and this one spends it manufacturing enough internal contrast that an all-black bird
    is not a hole in the screen. Three things do that work:

      1. COUNTERSHADING BY HUE, NOT BY LIGHTNESS. A crow's gloss is blue-violet on the mantle and
         its underparts are duller and browner. Cool-over-warm at nearly equal lightness reads as
         a black bird with form; light-over-dark reads as a magpie.
      2. THE COVERT EDGE LINE. The folded wing here is deliberately low-relief geometry -- it is
         shrink-wrapped to the flank so it does not read as a plate bolted on -- so its edge has
         to be drawn. The uguisu found the same thing with modelled creases; on a bird with no
         other markings it is the single most load-bearing line in the texture.
      3. A CATCHLIGHT. A crow's eye is as dark as its head, so a correctly-coloured eye is
         invisible and the face reads as a blank. The highlight is the only bright value in the
         whole palette, and it is what makes the bird look at you.

    ⚠ NO GRADIENTS ALONG THE WING OR TAIL. Same ruling as `shade_wing`: they alias into visible
    stripes wherever UVs distort, and the geometry already carries the feather read.
    """
    C = {k: _srgb_to_linear(v) for k, v in pal.items()}
    P = P / S
    x, y, z = np.abs(P[:, 0]), P[:, 1], P[:, 2]

    # 1. countershading off the NORMAL, not off height -- a bird's underside follows the surface
    #    facing the ground, which is what the normal already encodes.
    dorsal = _smooth(-0.45, 0.55, N[:, 2])
    gloss = _smooth(0.10, -0.45, y)                      # toward the tail: more blue gloss
    upper = C["dorsal"] * (1 - gloss)[:, None] + C["wing_tail"] * gloss[:, None]
    crown = _smooth(0.40, 0.56, y)
    upper = upper * (1 - crown)[:, None] + C["crown"] * crown[:, None]
    flankish = _smooth(0.18, 0.58, dorsal)
    lower = C["ventral"] * (1 - flankish)[:, None] + C["flank"] * flankish[:, None]
    out = lower * (1 - dorsal)[:, None] + upper * dorsal[:, None]

    # 1b. throat hackles -- a hashibutogarasu wears them, and they break up the underside
    t0, t1 = lm["throat_y"]
    hack = _smooth(t0, t0 + 0.08, y) * (1.0 - _smooth(t1 - 0.08, t1, y)) * (1.0 - dorsal)
    out = out * (1 - hack)[:, None] + C["throat"] * hack[:, None]

    # 2. THE FOLDED WING. Interpolating the plate's own stations rather than fitting a line means
    #    the painted edge cannot drift from the geometry it is drawing.
    edge_z = np.interp(y, lm["covert_edge_y"], lm["covert_edge_z"],
                       left=lm["covert_edge_z"][0], right=lm["covert_edge_z"][-1])
    span = (_smooth(lm["covert_back_y"], lm["covert_back_y"] + 0.10, y)
            * (1.0 - _smooth(lm["covert_front_y"] - 0.09, lm["covert_front_y"], y))
            * _smooth(0.020, 0.045, x))
    panel = _smooth(0.010, -0.010, z - edge_z) * span * dorsal
    out = out * (1 - panel)[:, None] + C["covert"] * panel[:, None]
    line = (1.0 - _smooth(0.003, 0.010, np.abs(z - edge_z))) * span
    out = out * (1 - line)[:, None] + C["covert_edge"] * line[:, None]

    # 3. THE EYE IS A SEPARATE ROBLOX PART, so all this paints is the SOCKET it sits in.
    #
    # ⚠ THREE PAINTED EYES FAILED BEFORE THIS, and the reason was never the colours -- they were
    # sampled off a photograph. A painted highlight is A BRIGHT SHAPE AT A FIXED PLACE: it cannot
    # move with the light or the camera, so it reads as a MARKING rather than as wetness, and
    # every attempt to make it more visible only made it more obviously a marking. Small read as
    # nothing; large read as "cataracts and/or possessed"; the owner's own repaint did not land
    # either. That failure mode has no tuning fix, which is why the eye left the texture entirely.
    #
    # ⚠ DO NOT PAINT AN EYE HERE AGAIN. `BirdController` parks a glossy ball on the `eye_R` /
    # `eye_L` bones; a painted one underneath would show around its edge as a second, duller eye.
    # A dark rim is all that is wanted: it gives the ball a socket to sit in, and it is measured
    # -- the lid runs 0.72-0.50x the feathers beside it, i.e. a socket is darker than what
    # surrounds it, which is the opposite of the pale ring the failed versions kept reaching for.
    e, er = lm["eye"], lm["eye_r"]
    de = np.sqrt((x - e[0]) ** 2 + (y - e[1]) ** 2 + (z - e[2]) ** 2)
    socket = 1.0 - _smooth(er * 1.15, er * 1.75, de)
    out = out * (1 - socket)[:, None] + C["lid"] * socket[:, None]

    # 4. bill. Both mandibles are the same colour on a corvid -- what separates them is the
    #    highlight along the culmen ridge and the dark line of the gape between them.
    gp, gn = np.array(lm["gape_p"]), np.array(lm["gape_n"])
    sd = (P - gp) @ gn
    bill = _smooth(lm["bill_y"] - 0.010, lm["bill_y"] + 0.030, y)
    out = out * (1 - bill)[:, None] + C["bill"] * bill[:, None]
    # a wide ramp on purpose: the bill is low-poly, and a tight one bands on its facets
    ridge = bill * _smooth(0.40, 0.95, N[:, 2]) * (1.0 - _smooth(0.030, 0.075, x))
    out = out * (1 - ridge)[:, None] + C["bill_gloss"] * ridge[:, None]
    # ⚠ THE GAPE IS THE INSIDE OF THE MOUTH AND NOTHING ELSE. A loose test here (|sd| < 0.010,
    # |Nz| > 0.35) also caught the bill's outer top and bottom, which meet near the gape line,
    # and painted a red stripe along the culmen. The interior faces lie ON the plane and face
    # almost straight up or down; both bounds are tight for that reason.
    inner = (bill > 0.6) & (np.abs(sd) < 0.0035) & (np.abs(N[:, 2]) > 0.72)
    out = np.where(inner[:, None], C["gape"], out)

    # 5. legs and feet
    leg = _smooth(lm["leg_z"] + 0.05, lm["leg_z"] - 0.03, z) * \
        ((y > -0.16) & (y < 0.22)).astype(float)
    out = out * (1 - leg)[:, None] + C["leg"] * leg[:, None]
    return np.clip(out, 0.0, 1.0)


def uv_occupancy(me, res=512, pad=1):
    """Boolean map of which texels a mesh's UV islands already claim."""
    me.calc_loop_triangles()
    uvl = me.uv_layers[0].data
    occ = np.zeros((res, res), dtype=bool)
    for tri in me.loop_triangles:
        uv = np.array([uvl[l].uv[:] for l in tri.loops]) * res
        x0 = max(0, int(np.floor(uv[:, 0].min())) - pad)
        x1 = min(res, int(np.ceil(uv[:, 0].max())) + pad + 1)
        y0 = max(0, int(np.floor(uv[:, 1].min())) - pad)
        y1 = min(res, int(np.ceil(uv[:, 1].max())) + pad + 1)
        if x1 > x0 and y1 > y0:
            occ[y0:y1, x0:x1] = True
    return occ


def find_free_uv_block(me, w, h, res=512):
    """Lowest-left free rectangle in a mesh's UV space, or None.

    ⚠ THIS EXISTS BECAUSE HARDCODING A REGION SILENTLY CORRUPTED THE BIRD. The spread wing was
    given a fixed patch at u,v = 0.06..0.36 without checking the vendor unwrap, and that patch was
    97.9% occupied — so the wing bake, which runs second, painted straight over one side of the
    torso. It read as texel bleed and was not: bleed is symmetric, and this was on one flank only,
    because that is where those islands happened to sit (owner, 2026-08-21, from a top view).
    """
    occ = uv_occupancy(me, res)
    I = np.zeros((res + 1, res + 1), dtype=np.int32)
    I[1:, 1:] = np.cumsum(np.cumsum(occ.astype(np.int32), axis=0), axis=1)
    bw, bh = int(w * res), int(h * res)
    for b in range(0, res - bh, 4):
        for a in range(0, res - bw, 4):
            c, d = a + bw, b + bh
            if I[d, c] - I[b, c] - I[d, a] + I[b, a] == 0:
                return (a / res, b / res, w, h)
    return None


def shade_wing(P, N, pal, S=1.0):
    """FLAT per surface — dark above, pale below, and nothing else.

    ⚠ DO NOT PUT GRADIENTS HERE. Earlier passes shaded the wing with a span gradient, a tip
    darkening and a pale trailing edge, and every one of them aliased into visible stripes: the
    wing gets a small corner of the atlas, its scalloped trailing edge distorts UVs at each notch,
    and the dilation then smears the result. A wing is seen in motion and usually at distance, so
    flat colour costs nothing and cannot band. The GEOMETRY carries the feather read — the
    scallops and the separated primaries — which is where that work belongs.
    """
    C = {k: _srgb_to_linear(v) for k, v in pal.items()}
    up = _smooth(-0.10, 0.10, N[:, 2])
    return np.clip(C["wing_tail"] * up[:, None] + C["flank"] * (1 - up)[:, None], 0.0, 1.0)


def _raster(me, uvl, co, no, img, hit, res, shader, pal, S=1.0, lm=None):
    for tri in me.loop_triangles:
        uv = np.array([uvl[l].uv[:] for l in tri.loops]) * res
        vi = list(tri.vertices)
        x0 = max(0, int(np.floor(uv[:, 0].min())) - 1)
        x1 = min(res, int(np.ceil(uv[:, 0].max())) + 2)
        y0 = max(0, int(np.floor(uv[:, 1].min())) - 1)
        y1 = min(res, int(np.ceil(uv[:, 1].max())) + 2)
        if x1 <= x0 or y1 <= y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        ax, ay = uv[0]
        bx, by = uv[1]
        cx, cy = uv[2]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -0.004) & (w1 >= -0.004) & (w2 >= -0.004)
        if not inside.any():
            continue
        W = np.stack([w0[inside], w1[inside], w2[inside]], axis=1)
        P = W @ co[vi]
        fn = np.array(tri.normal[:])
        vn = W @ no[vi]
        vl = np.linalg.norm(vn, axis=1, keepdims=True)
        vn = vn / np.where(vl == 0, 1, vl)
        blend = _smooth(0.85, 0.45, vn @ fn)[:, None]
        N = vn * (1 - blend) + fn[None, :] * blend
        n = np.linalg.norm(N, axis=1, keepdims=True)
        N = N / np.where(n == 0, 1, n)
        img[gy[inside].astype(int), gx[inside].astype(int)] = shader(P, N, pal, S)
        hit[gy[inside].astype(int), gx[inside].astype(int)] = True


SHADERS = {"warbler": lambda P, N, pal, S, lm: shade(P, N, pal, S),
           "corvid": shade_corvid}


def base_from_image(name, res):
    """The vendor's own diffuse, box-filtered to `res`, as the ground the bake paints onto.

    ⚠ BOX FILTER, NOT NEAREST. The vendor map is 2048 and the ceiling is 1024, so every output
    texel covers four source texels; picking one of the four throws away three quarters of the
    hand-painted detail this exists to keep, and does it worst exactly where detail is finest.

    ⚠ `pixels` IS SCENE-LINEAR for an sRGB image, which is the same space `shade_*` works in and
    the same space `bake` writes back out. No conversion here, and none should be added.
    """
    im = bpy.data.images[name]
    w, h = im.size
    px = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(px)
    a = px.reshape(h, w, 4)[:, :, :3].astype(np.float64)
    while a.shape[0] > res and a.shape[0] % 2 == 0:
        a = 0.25 * (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2])
    if a.shape[0] != res:
        yi = (np.arange(res) * a.shape[0] // res)
        xi = (np.arange(res) * a.shape[1] // res)
        a = a[yi][:, xi]
    return a


def eye_preserve(eyes_name="KarasuEyes", inner=1.9, outer=3.2):
    """Spheres around each eyeball inside which the vendor's paint is kept, blended out by `outer`.

    ⚠ MEASURED OFF THE EYEBALL MESH, never off `SPECIES[...]["landmarks"]`. Those landmarks carry
    |x| 0.062 and r 0.024 against an actual 0.0216/0.0346 and 0.0188 -- they were transcribed and
    have drifted, which is the exact failure `landmarks_final()` was written to prevent. The mesh
    is the measurement.
    """
    ob = bpy.data.objects[eyes_name]
    co = [v.co.copy() for v in ob.data.vertices]
    out = []
    for side in (lambda c: c.x > 0, lambda c: c.x < 0):
        pts = [c for c in co if side(c)]
        ctr = Vector((sum(p.x for p in pts) / len(pts),
                      sum(p.y for p in pts) / len(pts),
                      sum(p.z for p in pts) / len(pts)))
        r = max((p - ctr).length for p in pts)
        out.append((ctr, r * inner, r * outer))
    return out


def bake(obj_name="Uguisu_R", species="uguisu", uv_name=None, res=RES, wing_name=None,
         base_image=None, preserve=None):
    ob = bpy.data.objects[obj_name]
    me = ob.data
    uv_name = uv_name or me.uv_layers[0].name
    uvl = me.uv_layers[uv_name].data
    me.calc_loop_triangles()

    # HOW BIG IS THIS BIRD, relative to the one the landmarks were measured on?
    sp = SPECIES[species]
    lm = sp.get("landmarks")
    shader = SHADERS[sp["shader"]]
    ys = [v.co.y for v in me.vertices]
    S = (max(ys) - min(ys)) / sp.get("ref_length", LANDMARK_REF_LENGTH)

    # ⚠ THE GROUND MATTERS. With no `base_image` this is black and every unpainted texel is a
    # hole the dilation has to smear shut. With one, the vendor's own art is underneath, so
    # anything this bake declines to paint FALLS THROUGH to hand-painted work rather than to
    # black -- which is the whole mechanism behind `preserve`.
    base = base_from_image(base_image, res) if base_image else None
    img = np.zeros((res, res, 3), dtype=np.float64) if base is None else base.copy()
    hit = np.zeros((res, res), dtype=bool)
    # 3D position per texel, kept so `preserve` can be evaluated in WORLD space after the raster
    # rather than in UV space during it -- an eye is a place on the bird, not a rectangle in an
    # atlas, and its island is not contiguous.
    pos = np.zeros((res, res, 3), dtype=np.float64)
    co = np.array([v.co[:] for v in me.vertices])
    no = np.array([v.normal[:] for v in me.vertices])
    pal = sp["palette"]

    for tri in me.loop_triangles:
        uv = np.array([uvl[l].uv[:] for l in tri.loops]) * res
        vi = list(tri.vertices)
        x0 = max(0, int(np.floor(uv[:, 0].min())) - 1)
        x1 = min(res, int(np.ceil(uv[:, 0].max())) + 2)
        y0 = max(0, int(np.floor(uv[:, 1].min())) - 1)
        y1 = min(res, int(np.ceil(uv[:, 1].max())) + 2)
        if x1 <= x0 or y1 <= y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        ax, ay = uv[0]
        bx, by = uv[1]
        cx, cy = uv[2]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1.0 - w0 - w1
        # generous epsilon: adjacent triangles must not leave unpainted seams between them
        inside = (w0 >= -0.004) & (w1 >= -0.004) & (w2 >= -0.004)
        if not inside.any():
            continue
        W = np.stack([w0[inside], w1[inside], w2[inside]], axis=1)
        P = W @ co[vi]
        # ⚠ FACE normal, weighted over the interpolated vertex normal. A tail feather is a
        # thin flat blade whose vertices are shared by its top and bottom faces, so the
        # AVERAGED vertex normal there is near-horizontal — countershading then paints the top
        # of the tail as flank and the whole tail bakes pale. The face normal is what actually
        # faces the sky. Keeping a quarter of the vertex normal preserves smooth shading
        # across the body, where faceted colour bands would show.
        # ADAPTIVE, not a fixed mix. A thin tail feather's vertices are shared by its top and
        # bottom faces, so the averaged vertex normal there is near-horizontal and
        # countershading bakes the whole tail pale. But leaning on the face normal everywhere
        # facets the flank into visible triangles. Detect the case instead: on a smooth body
        # the face and vertex normals agree, on a thin blade they are ~perpendicular.
        fn = np.array(tri.normal[:])
        vn = W @ no[vi]
        vl = np.linalg.norm(vn, axis=1, keepdims=True)
        vn = vn / np.where(vl == 0, 1, vl)
        agree = vn @ fn
        blend = _smooth(0.85, 0.45, agree)[:, None]      # 0 = trust vertex, 1 = trust face
        N = vn * (1 - blend) + fn[None, :] * blend
        n = np.linalg.norm(N, axis=1, keepdims=True)
        N = N / np.where(n == 0, 1, n)
        img[gy[inside].astype(int), gx[inside].astype(int)] = shader(P, N, pal, S, lm)
        pos[gy[inside].astype(int), gx[inside].astype(int)] = P
        hit[gy[inside].astype(int), gx[inside].astype(int)] = True

    # The spread wing shares this atlas — one upload for the whole bird, and the wing cannot be
    # left unpainted or it renders as whatever the dilation smeared there.
    if wing_name and wing_name in bpy.data.objects:
        wme = bpy.data.objects[wing_name].data
        # ⚠ GUARD. Refuse to bake a wing whose UVs sit on top of the body's — that corruption is
        # invisible in the atlas and only shows as odd banding on one flank of the model.
        body_occ = uv_occupancy(me, 512)
        wing_occ = uv_occupancy(wme, 512, pad=0)
        clash = int((body_occ & wing_occ).sum())
        if clash > 0:
            raise RuntimeError(
                f"wing UVs overlap the body's by {clash} texels — the wing bake would paint over "
                f"the bird. Place the wing with find_free_uv_block(body_mesh, w, h).")
        wme.calc_loop_triangles()
        _raster(wme, wme.uv_layers[0].data,
                np.array([v.co[:] for v in wme.vertices]),
                np.array([v.normal[:] for v in wme.vertices]),
                img, hit, res, shade_wing, pal, S)  # flat per surface -- see shade_wing
        filled = int(hit.sum())

    # ⚠ HAND BACK THE EYE. Everything above painted the whole bird, this returns the one region
    # the vendor already did better. Three painted eyes were rejected before the eye was modelled
    # instead -- and all three were THIS bake's own output. The vendor's painted eye was never in
    # that sample, and the conclusion drawn from it ("a painted eye cannot read") was generalised
    # into an engine constraint it never was.
    #
    # ⚠ FEATHERED, NOT CUT. A hard boundary between vendor art and this palette reads as a decal
    # pasted on the face; `inner`..`outer` is a smoothstep so the two grounds meet in a ring.
    if preserve and base is not None:
        d = np.full((res, res), np.inf)
        for ctr, _r_in, _r_out in preserve:
            c = np.array(ctr[:])
            d = np.minimum(d, np.linalg.norm(pos - c[None, None, :], axis=2))
        r_in = min(p_[1] for p_ in preserve)
        r_out = max(p_[2] for p_ in preserve)
        keep = 1.0 - _smooth(r_in, r_out, d)          # 1 = vendor, 0 = this bake
        keep[~hit] = 0.0                              # never resurrect it outside painted texels
        img = base * keep[:, :, None] + img * (1.0 - keep[:, :, None])
        preserved = int((keep > 0.5).sum())
    else:
        preserved = 0

    # DILATE. Bilinear sampling at a UV island's edge reaches past it; without padding every
    # seam shows a dark fringe on the model.
    filled = int(hit.sum())
    for _ in range(6):
        empty = ~hit
        acc = np.zeros_like(img)
        cnt = np.zeros(hit.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            s = np.roll(np.roll(img, dy, 0), dx, 1)
            m = np.roll(np.roll(hit, dy, 0), dx, 1)
            acc += s * m[:, :, None]
            cnt += m
        grow = empty & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        hit |= grow

    name = f"{species}_colormap"
    if name in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[name])
    bi = bpy.data.images.new(name, res, res, alpha=True)
    bi.colorspace_settings.name = 'sRGB'
    px = np.concatenate([img, np.ones((res, res, 1))], axis=2).astype(np.float32)
    bi.pixels.foreach_set(px.ravel())
    bi.update()
    # Any texel this bake never reached keeps the vendor's art rather than a dilation smear.
    if base is not None:
        img[~hit] = base[~hit]

    return {"image": name, "res": res, "landmark_scale": round(S, 4), "texels_painted": filled,
            "coverage_pct": round(100.0 * filled / (res * res), 2),
            "base": base_image, "texels_kept_from_vendor": preserved,
            "tris": len(me.loop_triangles)}
