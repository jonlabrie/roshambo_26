#!/usr/bin/env python3
"""Hanabi-catalog posters for the fireworks shop (owner, 2026-09-03).

One poster per shell, derived from the shell's ACTUAL recipe data (FireworkCatalog
colors / spread / droop) so the poster shows the burst a buyer will see in the sky —
the visual-identity rule (never invent art for a concept players see elsewhere) applied
to merchandising. Style: vintage hanabi catalog — deep dusk ground, the break drawn as
clean radial strokes in the shell's signature hues, gold keyline frame. The shell's NAME
is deliberately absent: the in-place poster frame carries it on a nameplate label typeset
in Josefin Sans, the signage face, which lives in the engine and not on this machine.

Artwork band: the lower ~120px stays quiet for that nameplate.

Deterministic: seeded per shell, same bytes every run (PIL, optimize=False), like
make_firework_sprites.py. Run from roblox/:
    python3 tools/textures/make_shell_posters.py [shellId ...]
Outputs to tools/textures/posters/<shellId>.png (generated, not committed — the uploaded
asset ids get baked into the poster-hanging Studio tool, the pipeline's usual shape).
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

W, H = 512, 768
CENTER = (256, 300)
NAMEPLATE_BAND = 120  # artwork keeps clear of the bottom band

# Palette anchors from the game's identity: board black family, INK_CREAM, glyph gold.
DUSK_TOP = (14, 13, 22)
DUSK_BOTTOM = (38, 28, 36)
GOLD = (212, 176, 102)
CREAM = (240, 234, 216)

# Per-shell burst data, transcribed from FireworkCatalog.luau's burst phases (core color,
# edge color, spread, droop). Multi-act shells list their signature act(s).
SHELLS = {
    # transcribed from FireworkCatalog.luau burst phases (core, edge, spread, droop, style)
    "firecracker": {"core": (255, 236, 170), "edge": (255, 200, 120), "spread": 18, "droop": False, "style": "rocket"},
    "peony": {"core": (255, 120, 140), "edge": (255, 190, 200), "spread": 42, "droop": False, "style": "radial"},
    "willow": {"core": (255, 190, 90), "edge": (255, 226, 160), "spread": 34, "droop": True, "style": "radial"},
    "ishibana": {"core": (226, 222, 210), "edge": (198, 194, 186), "spread": 26, "droop": False, "style": "radial"},
    "kiku": {"core": (255, 190, 90), "edge": (255, 150, 60), "spread": 38, "droop": False, "style": "radial", "dense": True},
    "wa": {"core": (255, 60, 40), "edge": (255, 240, 220), "spread": 42, "style": "ring", "ring2": {"core": (255, 90, 60), "spread": 60}},
    "yashi": {"core": (255, 180, 60), "edge": (255, 230, 160), "spread": 44, "style": "palm", "points": 4},
    "kamuro": {"core": (255, 170, 40), "edge": (255, 220, 140), "spread": 60, "style": "crown"},
    "hotaru": {"core": (235, 245, 255), "edge": (180, 220, 255), "spread": 48, "style": "strobe", "cloud2": 60},
    "janken": {"core": (70, 150, 255), "edge": (240, 234, 216), "spread": 40, "style": "glyph",
               "deck": [(170, 60, 255), (60, 255, 110), (70, 150, 255), (255, 160, 60), (255, 60, 50)]},
    "rai": {"core": (255, 230, 200), "edge": (255, 200, 140), "spread": 18, "style": "salute", "bangs": 3},
    "banrai": {"core": (255, 230, 200), "edge": (255, 200, 140), "spread": 22, "style": "salute", "bangs": 7},
}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    grad = np.linspace(0, 1, H)[:, None, None]
    top = np.array(DUSK_TOP, dtype=float)[None, None, :]
    bottom = np.array(DUSK_BOTTOM, dtype=float)[None, None, :]
    img = top + (bottom - top) * grad
    img = np.repeat(img, W, axis=1)
    # gentle vignette so the burst owns the frame
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xs - W / 2) / (W / 2)) ** 2 + ((ys - H / 2) / (H / 2)) ** 2)
    img *= (1.0 - 0.25 * np.clip(d - 0.4, 0, 1)) [..., None] if False else (1.0 - 0.25 * np.clip(d - 0.4, 0, 1))[..., None]
    return Image.fromarray(img.astype(np.uint8), "RGB")


def glow(draw_img, center, color, radius, peak_alpha):
    """Soft radial glow composited additively-ish via per-pixel alpha discs."""
    overlay = Image.new("RGBA", draw_img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    steps = 24
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(peak_alpha * (1 - i / steps) ** 2)
        od.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (a,))
    draw_img.alpha_composite(overlay)


def draw_burst(img, spec, rng):
    d = ImageDraw.Draw(img)
    cx, cy = CENTER
    core, edge = spec["core"], spec["edge"]
    n_rays = 44
    base_len = 40 + spec["spread"] * 3.6  # spread 42 -> ~191px
    glow(img, CENTER, core, base_len * 0.55, 70)
    for i in range(n_rays):
        theta = 2 * math.pi * i / n_rays + rng.uniform(-0.02, 0.02)
        length = base_len * rng.uniform(0.86, 1.0)
        droop = spec["droop"]
        samples = 26
        prev = None
        for s in range(samples + 1):
            t = s / samples
            r = length * t
            x = cx + math.cos(theta) * r
            y = cy + math.sin(theta) * r
            if droop:
                y += (t**2) * length * 0.55  # willow-family strands fall
            color = lerp(core, edge, t)
            width = 3.4 * (1 - t) + 1.2
            if prev:
                d.line([prev, (x, y)], fill=color + (int(235 * (1 - 0.35 * t)),), width=int(round(width)))
            prev = (x, y)
        # terminal star
        tx, ty = prev
        d.ellipse([tx - 2.4, ty - 2.4, tx + 2.4, ty + 2.4], fill=edge + (255,))
    # pistil sparkle at the heart
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(4, base_len * 0.22)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        s = rng.uniform(1.0, 2.2)
        d.ellipse([x - s, y - s, x + s, y + s], fill=lerp(core, (255, 255, 255), 0.5) + (220,))




def draw_ring(img, spec, rng):
    d = ImageDraw.Draw(img)
    cx, cy = CENTER

    def one_ring(radius, core, alpha):
        # ON EDGE (owner, 2026-09-03): the ring drawn as a perspective ellipse, so wa
        # reads as its own species next to the radial family.
        squash = 0.40
        glow(img, CENTER, core, radius * 0.8, 40)
        n = 64
        for i in range(n):
            a = 2 * math.pi * i / n + rng.uniform(-0.015, 0.015)
            r = radius * rng.uniform(0.98, 1.02)
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * squash
            sz = rng.uniform(2.2, 3.4)
            d.ellipse([x - sz, y - sz, x + sz, y + sz], fill=core + (alpha,))
            d.ellipse([x - sz * 0.45, y - sz * 0.45, x + sz * 0.45, y + sz * 0.45], fill=spec["edge"] + (alpha,))

    one_ring(40 + spec["spread"] * 2.6, spec["core"], 245)
    r2 = spec.get("ring2")
    if r2:
        one_ring(40 + r2["spread"] * 2.6, r2["core"], 175)  # the boost ring, a beat behind


def draw_palm(img, spec, rng):
    d = ImageDraw.Draw(img)
    cx, cy = CENTER
    core, edge = spec["core"], spec["edge"]
    glow(img, CENTER, core, 90, 70)
    n = spec.get("points", 4)
    # Owner correction (2026-09-03): "four clusters growing from the ends of those arms" —
    # the arm is a short stem; the SHOW is the cluster at its end.
    length = (40 + spec["spread"] * 3.2) * 0.55
    for i in range(n):
        theta = -math.pi / 2 + (i - (n - 1) / 2) * (2 * math.pi / (n + 1.6)) + rng.uniform(-0.06, 0.06)
        samples = 16
        prev = None
        for sN in range(samples + 1):
            t = sN / samples
            r = length * t
            x = cx + math.cos(theta) * r
            y = cy + math.sin(theta) * r + (t**2) * length * 0.5
            color = lerp(core, edge, t)
            width = 3.6 * (1 - t) + 1.2
            if prev:
                d.line([prev, (x, y)], fill=color + (225,), width=int(round(width)))
            prev = (x, y)
        tx, ty = prev
        # the cluster: a mini golden break growing from the arm's end, then its rain
        glow(img, (tx, ty), core, 34, 70)
        for j in range(16):
            ca = 2 * math.pi * j / 16 + rng.uniform(-0.06, 0.06)
            cl = rng.uniform(22, 40)
            ex, ey = tx + math.cos(ca) * cl, ty + math.sin(ca) * cl * 0.9 + cl * 0.25
            d.line([(tx, ty), (ex, ey)], fill=lerp(core, edge, 0.5) + (235,), width=2)
            d.ellipse([ex - 1.6, ey - 1.6, ex + 1.6, ey + 1.6], fill=edge + (255,))
        for _ in range(9):  # rain strands falling from the cluster
            ra = rng.uniform(-0.4, 0.4)
            rl = rng.uniform(26, 56)
            sx = tx + rng.uniform(-14, 14)
            d.line([(sx, ty + 6), (sx + math.sin(ra) * 10, ty + 6 + rl)], fill=edge + (140,), width=1)


def draw_crown(img, spec, rng):
    d = ImageDraw.Draw(img)
    cx, cy = CENTER
    core, edge = spec["core"], spec["edge"]
    glow(img, CENTER, core, 110, 80)
    length = 40 + spec["spread"] * 3.0
    for i in range(72):
        theta = 2 * math.pi * i / 72 + rng.uniform(-0.02, 0.02)
        L = length * rng.uniform(0.9, 1.0)
        samples = 30
        prev = None
        for sN in range(samples + 1):
            t = sN / samples
            r = L * t
            x = cx + math.cos(theta) * r
            y = cy + math.sin(theta) * r + (t**2.2) * L * 0.62  # the crown falls long
            color = lerp(core, edge, t)
            width = 2.8 * (1 - t) + 1.0
            if prev:
                d.line([prev, (x, y)], fill=color + (int(225 * (1 - 0.3 * t)),), width=int(round(width)))
            prev = (x, y)


def draw_strobe(img, spec, rng):
    d = ImageDraw.Draw(img)
    cx, cy = CENTER
    core, edge = spec["core"], spec["edge"]

    def cloud(radius, count, alpha):
        for _ in range(count):
            a = rng.uniform(0, 2 * math.pi)
            r = abs(rng.normal(0, radius * 0.45))
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.85
            sz = rng.uniform(0.9, 2.6)
            c = core if rng.uniform(0, 1) < 0.7 else edge
            d.ellipse([x - sz, y - sz, x + sz, y + sz], fill=c + (alpha,))

    glow(img, CENTER, edge, 90, 40)
    cloud(40 + spec["spread"] * 2.6, 190, 235)  # the break
    if spec.get("cloud2"):
        cloud(40 + spec["cloud2"] * 2.6, 110, 120)  # the add-on, a beat behind and wider


def draw_flash(img, pos, size, core, edge, rng):
    d = ImageDraw.Draw(img)
    x, y = pos
    glow(img, pos, core, size * 1.5, 90)
    for i in range(10):
        a = 2 * math.pi * i / 10 + rng.uniform(-0.1, 0.1)
        L = size * (1.0 if i % 2 == 0 else 0.55) * rng.uniform(0.85, 1.05)
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=edge + (235,), width=2)
    d.ellipse([x - size * 0.2, y - size * 0.2, x + size * 0.2, y + size * 0.2], fill=(255, 255, 255, 255))


def draw_salute(img, spec, rng):
    cx, cy = CENTER
    # the small warm pop first, then the salvo scattered in the fall
    small = dict(spec)
    small["droop"] = False
    d = ImageDraw.Draw(img)
    glow(img, CENTER, spec["core"], 60, 60)
    for i in range(24):
        a = 2 * math.pi * i / 24
        L = (40 + spec["spread"] * 1.6) * rng.uniform(0.85, 1.0)
        d.line([(cx, cy), (cx + math.cos(a) * L, cy + math.sin(a) * L)], fill=lerp(spec["core"], spec["edge"], 0.5) + (200,), width=2)
    bangs = spec.get("bangs", 3)
    for _ in range(bangs):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(55, 150)
        pos = (cx + math.cos(a) * r, cy + math.sin(a) * r * 0.8 + 30)
        draw_flash(img, pos, rng.uniform(22, 34), spec["core"], spec["edge"], rng)


def draw_glyph_marks(d, pos, kind, k, color, alpha=255):
    """The APPROVED marks, at the canonical proportions from src/components/Symbols.tsx
    (24-unit box): R = circle r8; P = round-capped bar x 5..19; S = the SHALLOW caret
    (6,15)-(12,9)-(18,15) — twice as wide as tall — with round caps and joins. Never an
    ad-hoc shape (owner, 2026-09-03: "always use approved RPS glyphs"). k = px per unit."""
    x, y = pos
    w = max(2, int(round(2.5 * k)))
    if kind == "R":
        r = 8 * k
        d.ellipse([x - r, y - r, x + r, y + r], outline=color + (alpha,), width=w)
    elif kind == "P":
        x0, x1 = x - 7 * k, x + 7 * k
        d.line([(x0, y), (x1, y)], fill=color + (alpha,), width=w)
        for ex in (x0, x1):
            d.ellipse([ex - w / 2, y - w / 2, ex + w / 2, y + w / 2], fill=color + (alpha,))
    else:
        p1 = (x - 6 * k, y + 3 * k)
        apex = (x, y - 3 * k)
        p2 = (x + 6 * k, y + 3 * k)
        d.line([p1, apex], fill=color + (alpha,), width=w)
        d.line([apex, p2], fill=color + (alpha,), width=w)
        for pt in (p1, apex, p2):  # round caps + fused joint, as the SDF renders them
            d.ellipse([pt[0] - w / 2, pt[1] - w / 2, pt[0] + w / 2, pt[1] + w / 2], fill=color + (alpha,))


def draw_glyph(img, spec, rng):
    d = ImageDraw.Draw(img)
    cx, cy = CENTER
    deck = spec["deck"]
    # act one: four small dealt-color peonies, scattered and faint, behind the bloom
    # dealt to the quadrants (the sky scatters them; the poster composes them) so no
    # two of the four ever clump on top of each other
    corners = [(-105, -75), (95, -100), (-65, -145), (80, -30)]
    for i in range(4):
        c = deck[i % len(deck)]
        ox = corners[i][0] + rng.uniform(-12, 12)
        oy = corners[i][1] + rng.uniform(-12, 12)
        for j in range(18):
            a = 2 * math.pi * j / 18
            L = 52 * rng.uniform(0.85, 1.0)
            d.line(
                [(cx + ox, cy + oy), (cx + ox + math.cos(a) * L, cy + oy + math.sin(a) * L)],
                fill=c + (95,),
                width=2,
            )
    # the glyph cascade (owner, 2026-09-03, replacing the arm spread: "a few smaller
    # glyphs of each style cascading down between the other bursts"). One dealt color,
    # as the sky deals the whole bloom; three of each mark, falling and fading.
    bloom = deck[2]
    glow(img, CENTER, bloom, 70, 55)
    marks = ["R", "P", "S", "P", "S", "R", "S", "R", "P"]
    for i, mark in enumerate(marks):
        t = i / (len(marks) - 1)
        x = cx + rng.uniform(-110, 110)
        y = cy + 30 + t * 200 + rng.uniform(-14, 14)  # starts below the peony band
        k = 2.3 - 1.0 * t  # smaller as they fall
        alpha = int(255 - 110 * t)  # and fading out under the sizzle
        draw_glyph_marks(d, (x, y), mark, k, bloom, alpha)


def draw_rocket(img, spec, rng):
    # the Bottle Rocket: the TRAIL is the show -- long climb, small quick pop up high
    d = ImageDraw.Draw(img)
    cx, cy = CENTER[0], CENTER[1] - 60
    x0, y0 = cx + 30, H - NAMEPLATE_BAND - 20
    for s in range(46):
        t = s / 45
        x = x0 + (cx - x0) * t + math.sin(t * math.pi * 1.2) * 14
        y = y0 + (cy - y0) * t
        a = int(70 + 150 * t)
        r = 1.1 + 1.1 * t
        d.ellipse([x - r, y - r, x + r, y + r], fill=GOLD + (a,))
    spec2 = dict(spec)
    old_center = CENTER
    globals()["CENTER"] = (cx, cy)
    try:
        glow(img, (cx, cy), spec["core"], 60, 80)
        for i in range(26):
            theta = 2 * math.pi * i / 26 + rng.uniform(-0.03, 0.03)
            L = (40 + spec["spread"] * 2.6) * rng.uniform(0.85, 1.0)
            samples = 12
            prev = None
            for sN in range(samples + 1):
                t = sN / samples
                x = cx + math.cos(theta) * L * t
                y = cy + math.sin(theta) * L * t
                if prev:
                    d.line([prev, (x, y)], fill=lerp(spec["core"], spec["edge"], t) + (235,), width=int(round(2.6 * (1 - t) + 1.0)))
                prev = (x, y)
            tx, ty = prev
            d.ellipse([tx - 1.8, ty - 1.8, tx + 1.8, ty + 1.8], fill=spec["edge"] + (255,))
    finally:
        globals()["CENTER"] = old_center


STYLE_DRAW = {
    "radial": None,  # resolved in make_poster
    "ring": draw_ring,
    "palm": draw_palm,
    "crown": draw_crown,
    "strobe": draw_strobe,
    "salute": draw_salute,
    "glyph": draw_glyph,
    "rocket": draw_rocket,
}


def draw_trail(img, rng):
    """The rising trail: a faint gold dotted arc from the bottom band to the break."""
    d = ImageDraw.Draw(img)
    cx, cy = CENTER
    x0, y0 = cx + 14, H - NAMEPLATE_BAND - 24
    for s in range(34):
        t = s / 33
        x = x0 + (cx - x0) * t + math.sin(t * math.pi) * 10
        y = y0 + (cy - y0) * t
        a = int(60 + 120 * t)
        r = 1.2 + 0.8 * t
        d.ellipse([x - r, y - r, x + r, y + r], fill=GOLD + (a,))


def draw_frame(img):
    d = ImageDraw.Draw(img)
    d.rectangle([14, 14, W - 15, H - 15], outline=CREAM + (90,), width=2)
    d.rectangle([22, 22, W - 23, H - 23], outline=GOLD + (200,), width=3)


def make_poster(shell_id):
    spec = SHELLS[shell_id]
    rng = np.random.RandomState(abs(hash(shell_id)) % (2**31))
    # hash() is salted per-process for str — determinism needs a stable seed:
    rng = np.random.RandomState(sum(ord(c) * (31**i) for i, c in enumerate(shell_id)) % (2**31))
    img = background().convert("RGBA")
    style = spec.get("style", "radial")
    if style != "rocket":
        draw_trail(img, rng)
    if style == "radial":
        draw_burst(img, spec, rng)
        if spec.get("dense"):
            draw_burst(img, spec, rng)  # kiku burns hot: a second pass thickens the gold
    else:
        STYLE_DRAW[style](img, spec, rng)
    draw_frame(img)
    return img.convert("RGB")


def main():
    out_dir = Path(__file__).parent / "posters"
    out_dir.mkdir(exist_ok=True)
    ids = sys.argv[1:] or list(SHELLS)
    for shell_id in ids:
        img = make_poster(shell_id)
        path = out_dir / f"{shell_id}.png"
        img.save(path, optimize=False)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
