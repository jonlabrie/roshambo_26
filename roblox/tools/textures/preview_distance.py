#!/usr/bin/env python3
"""Show what a foliage atlas will look like AT DISTANCE in Roblox, without uploading it.

    python3 preview_distance.py sheet.png  LabelA=a.png  LabelB=b.png ...

WHY THIS IS POSSIBLE AT ALL. Roblox filters foliage RGB independently of alpha (proven
2026-08-02: dilating the transparent texels visibly changed the trees, which a
premultiplied chain could not do). Straight filtering is fully specified, so a distant
tree's colour can be COMPUTED rather than uploaded and eyeballed:

    mip_rgb   = plain box average of RGB, transparent texels included
    mip_alpha = plain box average of alpha
    on screen = mip_alpha * mip_rgb + (1 - mip_alpha) * background

Note the alpha appears TWICE when the transparent texels are black — once in the darkened
mip_rgb, once in the composite — which is why untreated foliage falls off a cliff with
distance. A 26%-opaque atlas lands at 0.26 x 0.26 = 7% of its leaf colour.

COMPOSITE MORE THAN ONE LAYER or the preview lies. A maple atlas is 26% opaque, so a
single card is three-quarters background and every candidate looks the same — the first
version of this script showed a 4/255 spread across treatments that are obviously
different in the canopy. A view ray through a real canopy crosses several cards, and the
colour compounds: N layers reach 1-(1-a)^N coverage, so at a=0.26 four layers give 70%.
LAYERS is that depth, and it is what makes a colour difference visible at range.

This exists because the upload-and-look loop is a bad way to judge colour: it costs an
asset ID per attempt, it cannot be undone, and it takes minutes per round. The user's
words, 2026-08-02: "I don't want to keep re-uploading these things to check, that's a
ridiculous approval pipeline."

Each column is one candidate; each row is a viewing distance (mip level), composited over
a canyon-ish background. Read DOWN a column to see how a tree holds its colour as it
recedes, and ACROSS a row to compare candidates at the same distance.
"""

import argparse

import numpy as np
from PIL import Image, ImageDraw

# roughly the canyon's far ground and its hazy sky, so a candidate is judged against what
# it will actually sit in front of rather than against white
BACKGROUNDS = [("over rock", (86, 82, 74)), ("over sky", (150, 162, 172))]
MIPS = [0, 4, 5, 6]
TILE = 200
LAYERS = 4  # cards a view ray crosses in a canopy; see the docstring


def mip_chain(rgb: np.ndarray, alpha: np.ndarray, levels: int):
    """Straight (non-premultiplied) box filter — Roblox's actual behaviour."""
    out = [(rgb, alpha)]
    for _ in range(levels):
        rgb, alpha = out[-1]
        h, w = alpha.shape
        h, w = h - h % 2, w - w % 2
        rgb = rgb[:h, :w].reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))
        alpha = alpha[:h, :w].reshape(h // 2, 2, w // 2, 2).mean(axis=(1, 3))
        out.append((rgb, alpha))
    return out


def sheet(candidates: list[tuple[str, str]], out: str) -> dict:
    rows = len(MIPS) * len(BACKGROUNDS)
    img = Image.new("RGB", (TILE * len(candidates) + 130, TILE * rows + 30), (24, 24, 26))
    d = ImageDraw.Draw(img)
    report: dict = {}

    for col, (label, path) in enumerate(candidates):
        src = Image.open(path).convert("RGBA")
        a = np.array(src).astype(np.float32) / 255.0
        chain = mip_chain(a[:, :, :3], a[:, :, 3], max(MIPS))
        d.text((130 + col * TILE + 6, 10), label, fill=(255, 255, 255))
        report[label] = {}

        for bi, (bgname, bg) in enumerate(BACKGROUNDS):
            bgv = np.array(bg, dtype=np.float32) / 255.0
            for mi, level in enumerate(MIPS):
                rgb, alpha = chain[level]
                a3 = alpha[:, :, None]
                comp = np.broadcast_to(bgv, rgb.shape).copy()
                for _ in range(LAYERS):
                    comp = a3 * rgb + (1.0 - a3) * comp
                tile = Image.fromarray((np.clip(comp, 0, 1) * 255).astype(np.uint8))
                # NEAREST so a coarse mip stays honest about how few texels it has
                tile = tile.resize((TILE, TILE), Image.NEAREST if level > 2 else Image.LANCZOS)
                y = 30 + (bi * len(MIPS) + mi) * TILE
                img.paste(tile, (130 + col * TILE, y))
                if col == 0:
                    tag = "full res" if level == 0 else f"mip {level}"
                    d.text((8, y + TILE // 2 - 12), f"{tag}", fill=(210, 210, 210))
                    d.text((8, y + TILE // 2 + 2), bgname, fill=(130, 130, 130))
                if level == 5:
                    report[label][bgname] = [int(round(v * 255)) for v in comp.mean(axis=(0, 1))]

    img.save(out)
    return report


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("candidates", nargs="+", help="Label=path.png")
    args = ap.parse_args()
    pairs = [(c.split("=", 1)[0], c.split("=", 1)[1]) for c in args.candidates]
    rep = sheet(pairs, args.out)
    for label, byBg in rep.items():
        parts = "  ".join(f"{k} {v}" for k, v in byBg.items())
        print(f"{label:22s} mip5 on screen: {parts}")
