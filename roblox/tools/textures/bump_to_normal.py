#!/usr/bin/env python3
"""Convert an XfrogPlants `_b` BUMP map into a tangent-space NORMAL map for Roblox.

    python3 bump_to_normal.py JA15brk_b.tif JA15brk_normal.png [--strength 2.0]
    python3 bump_to_normal.py --flat 0.8 out.png      # constant-value map, for filling
                                                      # a missing Roughness/Metalness slot

WHY THIS EXISTS. The XfrogPlants library ships a height/bump map beside every bark
diffuse — 18 `brk_b.tif` files — and export_tree.py never used them. It composites the
diffuse plus the leaf opacity map into one RGBA ColorMap and stops there. That left every
tree we exported with a ColorMap-ONLY SurfaceAppearance, which Roblox renders warm and
shiny because it substitutes its own defaults for the missing channels (see the trunk
investigation, 2026-08-02: the user called it "chestnut brown", and it hit the warm barks
— spruce warmth 62, hinoki 44 — while leaving neutral maple, warmth 3, looking fine).

Roblox's NormalMap wants tangent-space normals, not height, so the gradient of the height
field becomes the XY of the normal and Z is whatever is left of the unit vector:

    n = normalize(-dH/dx * strength, -dH/dy * strength, 1)
    encoded as (n * 0.5 + 0.5) in RGB

`--strength` scales the relief. Bark wants a fairly strong value — 2 to 4 — because the
source height range is shallow.
"""

import argparse

import numpy as np
from PIL import Image


def bump_to_normal(src: str, out: str, strength: float = 2.0) -> dict:
    im = Image.open(src).convert("L")
    h = np.array(im).astype(np.float32) / 255.0

    # central differences, wrapped: bark tiles, so the seam should not read as a ridge
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5

    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length

    rgb = np.stack([nx, ny, nz], axis=2) * 0.5 + 0.5
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(out)
    return {
        "size": im.size,
        "height_range": [float(h.min()), float(h.max())],
        "mean_slope": float(np.abs(np.stack([dx, dy])).mean()),
    }


def flat(value: float, out: str, size: int = 16) -> None:
    """A constant map, to fill a channel Roblox would otherwise default for us."""
    v = int(round(np.clip(value, 0.0, 1.0) * 255))
    Image.fromarray(np.full((size, size, 3), v, dtype=np.uint8)).save(out)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("out")
    ap.add_argument("--strength", type=float, default=2.0)
    ap.add_argument("--flat", type=float, default=None, help="write a constant map instead")
    args = ap.parse_args()
    if args.flat is not None:
        flat(args.flat, args.out)
        print(f"{args.out}: constant {args.flat}")
    else:
        info = bump_to_normal(args.src, args.out, args.strength)
        print(
            f"{args.out}: {info['size']} from height range "
            f"{info['height_range'][0]:.2f}-{info['height_range'][1]:.2f}, "
            f"mean slope {info['mean_slope']:.4f}"
        )
