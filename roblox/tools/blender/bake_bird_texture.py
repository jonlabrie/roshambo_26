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
SPECIES = {"uguisu": UGUISU}

# --- landmarks, measured off the retargeted mesh -----------------------------------------
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


def shade(P, N, pal):
    """P (M,3) positions, N (M,3) normals -> (M,3) linear RGB. Vectorised."""
    C = {k: _srgb_to_linear(v) for k, v in pal.items()}
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


def bake(obj_name="Uguisu_R", species="uguisu", uv_name=None, res=RES):
    ob = bpy.data.objects[obj_name]
    me = ob.data
    uv_name = uv_name or me.uv_layers[0].name
    uvl = me.uv_layers[uv_name].data
    me.calc_loop_triangles()

    img = np.zeros((res, res, 3), dtype=np.float64)
    hit = np.zeros((res, res), dtype=bool)
    co = np.array([v.co[:] for v in me.vertices])
    no = np.array([v.normal[:] for v in me.vertices])
    pal = SPECIES[species]

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
        img[gy[inside].astype(int), gx[inside].astype(int)] = shade(P, N, pal)
        hit[gy[inside].astype(int), gx[inside].astype(int)] = True

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
    return {"image": name, "res": res, "texels_painted": filled,
            "coverage_pct": round(100.0 * filled / (res * res), 2),
            "tris": len(me.loop_triangles)}
