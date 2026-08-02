#!/usr/bin/env python3
"""Recolour a foliage leaf atlas by rotating hue while preserving shading.

Needs Pillow + numpy; does NOT need Blender (it is a pure image operation).

    python3 recolor_leaves.py SRC.png OUT.png --hue 45 --sat 1.25 --val 1.0

Why hue rotation rather than a Roblox `SurfaceAppearance.Color` tint: a tint
MULTIPLIES, so tinting a green leaf red gives muddy brown (high-R tint x low-R
green). Rotating hue in HSV moves the colour while leaving VALUE alone, so every
vein, shadow and highlight in the original survives — which is what makes the
result read as a different season rather than a flat repaint.

Only pixels inside `--band` (default 40-110 deg, the green/yellow-green range)
are rotated. That deliberately spares the brown petiole and stem pixels sharing
the atlas, which should stay brown in autumn.

Measured on XfMapleA_leaves.png (2026-08-01): 1021x1024, 26% opaque, hue
clustered 60-77 deg, sat 0.44, val 0.44 — a narrow band, which is why this
works so cleanly here.

WHAT IS ACTUALLY LIVE IN THE CANYON. All maples derive from XfMapleA_leaves.png. The
2026-08-01 pass (green 113908195064379; gold 111846883522531 shift -27 sat 1.43 val 1.10;
red 138457704702807 shift -61 sat 1.60) read well up close but went muddy at range, so on
2026-08-02 gold and red were re-cut hotter and then run through dilate_alpha.py, which is
what makes the colour survive the mip chain:

    gold  rbxassetid://114315144065350   --shift -27 --sat 1.90 --val 1.18
    red   rbxassetid://89777902880770    --shift -61 --sat 2.10 --val 1.15
    then  dilate_alpha.py --passes 12 --fill-sat 1.35 --fill-val 1.10

Judged on preview_distance.py sheets before uploading, not by uploading and looking. GREEN
was deliberately NOT re-cut — see the moderation note below.

⚠️ MODERATION (2026-08-01, learned the hard way): Roblox REMOVED the uploaded
GREEN maple variant within hours, while the gold and red survived untouched. A
palmate, serrated, GREEN leaf reads to automated moderation as cannabis — the
colour is what completes the match, which is exactly why only the green was
pulled. Practical rules:
  * Do NOT upload green palmate foliage. You almost never need to: the vendor's
    own green colormap is already uploaded and working.
  * Autumn recolours (gold/red/bronze) are safe for the same leaf shape.
  * Re-uploading a removed asset invites escalation against the account; drop it
    and use the original instead.
"""

import argparse
import colorsys

import numpy as np
from PIL import Image

GREEN_BAND = (40.0, 110.0)


def recolor(
    src: str,
    out: str,
    hue_deg: float | None,
    sat_mul: float,
    val_mul: float,
    band: tuple[float, float] = GREEN_BAND,
    hue_shift: float | None = None,
) -> dict:
    """hue_shift ROTATES by a delta; hue_deg SETS one absolute hue.

    Prefer hue_shift: this atlas's leaves span 60-77 deg, and that spread is real
    variation between and within leaves. Setting one absolute hue flattens it —
    the result still reads well because value carries the detail, but rotating
    keeps the variation the artist painted.
    """
    img = Image.open(src).convert("RGBA")
    a = np.array(img).astype(np.float32) / 255.0
    rgb, alpha = a[:, :, :3], a[:, :, 3]

    # vectorised RGB->HSV (colorsys is per-pixel and far too slow at 1M pixels)
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    diff = mx - mn
    hue = np.zeros_like(mx)
    mask = diff > 1e-6
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    idx = mask & (mx == r)
    hue[idx] = ((g[idx] - b[idx]) / diff[idx]) % 6
    idx = mask & (mx == g)
    hue[idx] = ((b[idx] - r[idx]) / diff[idx]) + 2
    idx = mask & (mx == b)
    hue[idx] = ((r[idx] - g[idx]) / diff[idx]) + 4
    hue = (hue * 60.0) % 360.0
    sat = np.where(mx > 1e-6, diff / np.maximum(mx, 1e-6), 0.0)
    val = mx

    # rotate ONLY the leaf-green band; stems and petioles keep their brown
    lo, hi = band
    leaf = (hue >= lo) & (hue <= hi) & (alpha > 0.02)
    touched = int(leaf.sum())
    if hue_shift is not None:
        hue = np.where(leaf, (hue + hue_shift) % 360.0, hue)
    elif hue_deg is not None:
        hue = np.where(leaf, hue_deg % 360.0, hue)
    sat = np.where(leaf, np.clip(sat * sat_mul, 0.0, 1.0), sat)
    val = np.where(leaf, np.clip(val * val_mul, 0.0, 1.0), val)

    # HSV->RGB, vectorised
    c = val * sat
    hp = hue / 60.0
    x = c * (1 - np.abs(hp % 2 - 1))
    m = val - c
    z = np.zeros_like(c)
    conds = [
        (hp < 1, (c, x, z)),
        ((hp >= 1) & (hp < 2), (x, c, z)),
        ((hp >= 2) & (hp < 3), (z, c, x)),
        ((hp >= 3) & (hp < 4), (z, x, c)),
        ((hp >= 4) & (hp < 5), (x, z, c)),
        (hp >= 5, (c, z, x)),
    ]
    rr, gg, bb = z.copy(), z.copy(), z.copy()
    for cond, (cr, cg, cb) in conds:
        rr = np.where(cond, cr, rr)
        gg = np.where(cond, cg, gg)
        bb = np.where(cond, cb, bb)
    outrgb = np.stack([rr + m, gg + m, bb + m], axis=2)

    result = np.concatenate([outrgb, alpha[:, :, None]], axis=2)
    Image.fromarray((np.clip(result, 0, 1) * 255).astype(np.uint8)).save(out)
    return {"pixels_recoloured": touched, "size": img.size}


def contact_sheet(paths: list[tuple[str, str]], out: str, bg=(58, 62, 55)) -> None:
    """Composite the variants side by side on a neutral ground for review.

    A leaf atlas is ~75% transparent; viewed raw on white or on a checkerboard the
    colours are impossible to judge, so flatten onto a mid-dark neutral first.
    """
    from PIL import ImageDraw

    tiles = []
    for label, p in paths:
        im = Image.open(p).convert("RGBA")
        flat = Image.new("RGBA", im.size, bg + (255,))
        flat.alpha_composite(im)
        flat = flat.convert("RGB").resize((512, 512), Image.LANCZOS)
        d = ImageDraw.Draw(flat)
        d.rectangle([0, 0, 512, 26], fill=(0, 0, 0))
        d.text((8, 7), label, fill=(255, 255, 255))
        tiles.append(flat)
    sheet = Image.new("RGB", (512 * len(tiles), 512))
    for i, t in enumerate(tiles):
        sheet.paste(t, (512 * i, 0))
    sheet.save(out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--hue", type=float, default=None, help="ABSOLUTE target hue, degrees")
    ap.add_argument("--shift", type=float, default=None, help="hue DELTA, degrees (preferred)")
    ap.add_argument("--sat", type=float, default=1.0, help="saturation multiplier")
    ap.add_argument("--val", type=float, default=1.0, help="value multiplier")
    args = ap.parse_args()
    info = recolor(args.src, args.out, args.hue, args.sat, args.val, hue_shift=args.shift)
    print(f"{args.out}: recoloured {info['pixels_recoloured']} px of {info['size']}")
