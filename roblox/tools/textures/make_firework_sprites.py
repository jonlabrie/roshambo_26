#!/usr/bin/env python3
"""Generate the two firework particle sprites (256x256 RGBA, premult-friendly).

dot:    a crisp round core -- solid white center, tight radial falloff
        (alpha = clamp01(1.6 - 1.6*r)^2.2 inside r<1, 0 outside; r normalized
        to 0..1 at 40% of the half-width so the core is small and HARD, the
        opposite of the engine's fuzzy sparkle).
streak: a vertical streak -- alpha = (1 - |x|)^3 * (1 - |y-0.25|)^1.2 on a tall
        gaussian-ish lobe occupying the middle 20% horizontally, full height,
        brightest 25% from the top so the motion reads downward. The vertical
        term is windowed by a short 12%-of-height ramp so alpha reaches
        EXACTLY zero at y=0 and y=1 -- no hard cut at the quad's top/bottom
        edge -- without touching the brightness peak or falloff in the interior.

Both pure white; ALL color comes from the emitter's Color/Brightness, so one
sprite serves every shell. Deterministic: same bytes every run (PIL, no
timestamps -- save with optimize=False).
Run from roblox/:  python3 tools/textures/make_firework_sprites.py
"""

import numpy as np
from PIL import Image


def make_dot(size: int = 256) -> np.ndarray:
    """Generate the dot sprite: crisp round core with tight radial falloff."""
    # Create a grid of coordinates normalized to [-1, 1]
    coords = np.linspace(-1, 1, size)
    y, x = np.meshgrid(coords, coords)

    # Distance from center
    r = np.sqrt(x**2 + y**2)

    # Normalize r to 0..1 at 40% of the half-width (51.2 pixels / 128 half-width)
    # Half-width is 128 (size/2), so 40% is 0.4
    r_normalized = r / 0.4

    # Alpha formula: clamp01(1.6 - 1.6*r)^2.2
    alpha = np.clip(1.6 - 1.6 * r_normalized, 0, 1) ** 2.2

    # Create RGBA array with pure white
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, 0] = 255  # R
    rgba[:, :, 1] = 255  # G
    rgba[:, :, 2] = 255  # B
    rgba[:, :, 3] = (alpha * 255).astype(np.uint8)  # A

    return rgba


def make_streak(size: int = 256) -> np.ndarray:
    """Generate the streak sprite: vertical streak with top-heavy brightness."""
    # Horizontal: a narrow band across the middle 20% of columns, cubic falloff.
    # x spans [-1, 1] (a width of 2), so a band of half-width 0.2 covers 20% of it.
    x = np.linspace(-1, 1, size)
    col = np.clip(1 - np.abs(x) / 0.2, 0, 1) ** 3

    # Vertical: full height, brightest 25% down from the top.
    y = np.linspace(0, 1, size)
    row = (1 - np.abs(y - 0.25)) ** 1.2

    # Edge window: fades row to EXACTLY zero at y=0 and y=1 over a short 12% ramp,
    # so the quad's top/bottom edges never show a hard alpha cut. Full strength
    # (1.0) everywhere between the two ramps, so the y=0.25 brightness peak and
    # the top-brighter-than-bottom falloff are unaffected in the interior.
    edge = np.clip(np.minimum(y, 1 - y) / 0.12, 0, 1)
    row = row * edge

    # Outer(row, col) gives [row, col] indexing -- exactly PIL's array orientation.
    alpha = np.outer(row, col)

    # Create RGBA array with pure white
    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, 0] = 255  # R
    rgba[:, :, 1] = 255  # G
    rgba[:, :, 2] = 255  # B
    rgba[:, :, 3] = (alpha * 255).astype(np.uint8)  # A

    return rgba


if __name__ == "__main__":
    # Generate dot sprite
    dot_rgba = make_dot()
    Image.fromarray(dot_rgba, "RGBA").save("tools/textures/firework_dot.png", optimize=False)
    print("Created tools/textures/firework_dot.png")

    # Generate streak sprite
    streak_rgba = make_streak()
    Image.fromarray(streak_rgba, "RGBA").save("tools/textures/firework_streak.png", optimize=False)
    print("Created tools/textures/firework_streak.png")
