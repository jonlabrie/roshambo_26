#!/usr/bin/env python3
"""Flood leaf colour outward into a foliage atlas's TRANSPARENT texels.

    python3 dilate_alpha.py SRC.png OUT.png [--passes 8]

WHY THIS MATTERS MORE THAN IT SOUNDS. A foliage atlas is mostly transparent — 12% opaque
on the sugi, 26% on the maple — and the compositing step leaves those transparent texels
BLACK in RGB. Alpha hides them at full resolution, so the tree looks right up close. But
a MIP LEVEL is an average of its texels, and that average includes the black. By the time
a tree is small on screen it is sampling a mip whose colour is mostly black:

    XfSugi40   leaf RGB [113,119,34]  ->  distant mip [15, 16, 5]   (13% of its brightness)
    XfSpruceM  leaf RGB [ 74, 88,41]  ->  distant mip [12, 14, 7]
    XfMapleA   leaf RGB [104,112,63]  ->  distant mip [27, 29,16]

So the canyon's foliage goes dark and grey with distance, and no amount of geometry fixes
it. The user's words, 2026-08-02: the maples "read great up close, but just don't have
the colorful punch I want from a distance".

THE FIX is standard for alpha-tested foliage: dilate (flood-fill) the opaque colour
outward into the transparent region, so every texel a mip can average carries plausible
leaf colour. The ALPHA CHANNEL IS NEVER TOUCHED — silhouettes are unchanged, and nothing
new becomes visible. Only the colour hiding under transparent pixels changes.

bake_clump_tree.py already does this for its baked atlas and explains why; this brings the
same treatment to the vendor atlases export_tree.py writes.

HOW STRONG THE EFFECT ACTUALLY IS — measured, and REVERTED, 2026-08-02
----------------------------------------------------------------------
The numbers above are UNWEIGHTED texel means. Computing the ALPHA-WEIGHTED (premultiplied)
mip instead gives sugi [111,115,38] and spruce [71,86,43] at mip4 — *identical* before and
after dilation, because a premultiplied chain never lets a zero-alpha texel contribute
colour at all. So the two measurements bracket the two possible renderers, and shipping
the dilated atlases decided which one Roblox is: the trees visibly changed, therefore
**Roblox filters RGB independently of alpha (straight, not premultiplied)**. That is worth
knowing on its own — it also means the black under transparent texels bleeds into leaf
EDGES at full resolution, not only into distant mips.

Which is why the change was not subtle and not confined to distance. Flooding black →
leaf colour lifts every partially-transparent texel, and partial alpha is a big share of
these atlases: 28.7% of sugi's visible texels, 25.6% of spruce's, against 9.3% hinoki and
2.2% maple. The species the user singled out as "way brighter" were exactly the top two.
Per-species `--fill-sat` / `--fill-val` trims of ±10% were noise beside that.

The nine canyon atlases were reverted to their pre-dilation uploads. If this is revisited,
the knob is `--fill-val` around 0.5-0.6, NOT 0.9: dark-but-not-black kills the edge fringe
while keeping the canopy's value where the user has already approved it.
"""

import argparse

import numpy as np
from PIL import Image


def _hsv_adjust(rgb: np.ndarray, sat: float, val: float) -> np.ndarray:
    """Scale saturation/value of an RGB array in place-safe fashion."""
    if sat == 1.0 and val == 1.0:
        return rgb
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    grey = mn
    # saturation about the grey axis, then value
    out = grey[:, :, None] + (rgb - grey[:, :, None]) * sat
    out = out * val
    return np.clip(out, 0.0, 1.0)


def dilate(
    src: str,
    out: str,
    passes: int = 8,
    threshold: float = 0.02,
    fill_sat: float = 1.0,
    fill_val: float = 1.0,
) -> dict:
    """fill_sat / fill_val tune ONLY the colour flooded into transparent texels — i.e.
    only what a distant mip averages. The opaque leaf pixels are never touched, so the
    tree's close-up appearance is unchanged. Use this to tune distance separately from
    near: user, 2026-08-02, wanted sugi and fir 10% darker at range while the maples
    wanted MORE saturation, and both are the same knob pointed in opposite directions."""
    im = Image.open(src).convert("RGBA")
    a = np.array(im).astype(np.float32) / 255.0
    rgb, alpha = a[:, :, :3].copy(), a[:, :, 3]

    known = alpha > threshold
    before_mip = rgb.reshape(-1, 3).mean(axis=0) * 255
    leaf = rgb[known].mean(axis=0) * 255 if known.any() else np.zeros(3)

    for _ in range(passes):
        if known.all():
            break
        src_rgb = np.where(known[:, :, None], rgb, 0.0)
        src_w = known.astype(np.float32)
        acc = np.zeros_like(src_rgb)
        accw = np.zeros_like(src_w)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            acc += np.roll(np.roll(src_rgb, dy, axis=0), dx, axis=1)
            accw += np.roll(np.roll(src_w, dy, axis=0), dx, axis=1)
        grow = (accw > 0) & (~known)
        filled = np.divide(acc, np.maximum(accw, 1e-6)[:, :, None])
        rgb = np.where(grow[:, :, None], filled, rgb)
        known = known | grow

    # any texel still unreached (a big empty region) gets the average leaf colour, so the
    # coarsest mips cannot fall back toward black either
    if not known.all():
        rgb = np.where(known[:, :, None], rgb, (leaf / 255.0).reshape(1, 1, 3))

    if fill_sat != 1.0 or fill_val != 1.0:
        filled_only = ~(np.array(Image.open(src).convert("RGBA"))[:, :, 3] > threshold * 255)
        adj = _hsv_adjust(rgb, fill_sat, fill_val)
        rgb = np.where(filled_only[:, :, None], adj, rgb)

    after_mip = rgb.reshape(-1, 3).mean(axis=0) * 255
    result = np.concatenate([rgb, alpha[:, :, None]], axis=2)
    Image.fromarray((np.clip(result, 0, 1) * 255).astype(np.uint8)).save(out)
    return {
        "opaque_pct": round(float(known.mean() * 100), 1),
        "leaf_rgb": [int(round(v)) for v in leaf],
        "mip_before": [int(round(v)) for v in before_mip],
        "mip_after": [int(round(v)) for v in after_mip],
    }


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--passes", type=int, default=8)
    ap.add_argument("--fill-sat", type=float, default=1.0, help="saturation of the FILL only")
    ap.add_argument("--fill-val", type=float, default=1.0, help="brightness of the FILL only")
    args = ap.parse_args()
    info = dilate(args.src, args.out, args.passes, fill_sat=args.fill_sat, fill_val=args.fill_val)
    print(
        f"{args.out}: leaf {info['leaf_rgb']}  "
        f"distant mip {info['mip_before']} -> {info['mip_after']}"
    )
