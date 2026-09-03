#!/usr/bin/env python3
"""Generate the throw-glyph particle sprites (256x256 RGBA) for dan's glyph act
(owner design 2026-09-06: "falling bunches of glyphs" -- rock, paper, scissors in the
sky, the Roshambo signature). Bold filled silhouettes, pure white, alpha-only shapes,
antialiased at 4x supersampling; ALL color comes from the emitter. Deterministic.
Run from roblox/:  python3 tools/textures/make_throw_glyphs.py
"""

from PIL import Image, ImageDraw

SS = 4  # supersample factor
S = 256 * SS


def canvas():
    img = Image.new("L", (S, S), 0)
    return img, ImageDraw.Draw(img)


def save(img, name):
    a = img.resize((256, 256), Image.LANCZOS)
    rgba = Image.merge("RGBA", [Image.new("L", (256, 256), 255)] * 3 + [a])
    rgba.save(f"tools/textures/{name}", optimize=False)
    print(f"Created tools/textures/{name}")


def rock():
    # A faceted boulder: irregular convex silhouette, unmistakably a lump.
    img, d = canvas()
    pts = [(0.50, 0.12), (0.78, 0.22), (0.90, 0.48), (0.80, 0.78),
           (0.55, 0.90), (0.28, 0.84), (0.12, 0.60), (0.18, 0.30)]
    d.polygon([(x * S, y * S) for x, y in pts], fill=255)
    # two facet cracks, carved out so the silhouette reads "rock" not "blob"
    d.line([(0.50 * S, 0.12 * S), (0.46 * S, 0.55 * S), (0.28 * S, 0.84 * S)], fill=110, width=SS * 5)
    d.line([(0.46 * S, 0.55 * S), (0.90 * S, 0.48 * S)], fill=110, width=SS * 4)
    return img


def paper():
    # A sheet with a folded corner, tilted so it reads as paper mid-flutter.
    img, d = canvas()
    sheet = [(0.30, 0.10), (0.82, 0.20), (0.72, 0.88), (0.20, 0.78)]
    d.polygon([(x * S, y * S) for x, y in sheet], fill=255)
    # the fold: clip the top-right corner and redraw it dimmer, turned down
    d.polygon([(0.82 * S, 0.20 * S), (0.66 * S, 0.16 * S), (0.72 * S, 0.38 * S)], fill=0)
    d.polygon([(0.66 * S, 0.16 * S), (0.72 * S, 0.38 * S), (0.58 * S, 0.30 * S)], fill=160)
    return img


def scissors():
    # Open scissors: two crossed blades with ring handles, the classic X.
    img, d = canvas()
    def blade(x0, y0, x1, y1, w):
        d.line([(x0 * S, y0 * S), (x1 * S, y1 * S)], fill=255, width=int(w * S))
    blade(0.22, 0.14, 0.74, 0.72, 0.075)
    blade(0.78, 0.14, 0.26, 0.72, 0.075)
    for cx, cy in [(0.68, 0.84), (0.32, 0.84)]:
        d.ellipse([(cx - 0.115) * S, (cy - 0.115) * S, (cx + 0.115) * S, (cy + 0.115) * S],
                  outline=255, width=int(0.05 * S))
    return img


if __name__ == "__main__":
    save(rock(), "glyph_rock.png")
    save(paper(), "glyph_paper.png")
    save(scissors(), "glyph_scissors.png")
