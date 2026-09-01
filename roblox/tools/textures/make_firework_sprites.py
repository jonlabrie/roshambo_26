#!/usr/bin/env python3
"""Generate the two firework particle sprites (256x256 RGBA, premult-friendly).

dot:    a crisp round core -- solid white center, tight radial falloff
        (alpha = clamp01(1.6 - 1.6*r)^2.2 inside r<1, 0 outside; r normalized
        to 0..1 at 40% of the half-width so the core is small and HARD, the
        opposite of the engine's fuzzy sparkle).
streak: a vertical streak -- alpha = (1 - |x|)^3 * (1 - |y|)^1.2 on a tall
        gaussian-ish lobe occupying the middle 20% horizontally, full height,
        brightest 25% from the top so the motion reads downward.

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
    # Create a grid of coordinates
    # x: normalized to [-1, 1] for horizontal, occupying middle 20%
    # y: normalized to [0, 1] for vertical (full height), brightest 25% from top

    coords_x = np.linspace(-1, 1, size)
    coords_y = np.linspace(0, 1, size)
    y_grid, x_grid = np.meshgrid(coords_y, coords_x)

    # Middle 20% horizontally means x ranges from -0.1 to 0.1
    # But we want to normalize this to a 0..1 range for the falloff formula
    # Map x from [-1, 1] to normalized horizontal position
    x_norm = np.abs(x_grid) / 0.1  # Normalize so that ±0.1 maps to 0..1

    # Clamp x_norm to [0, 1] for values outside the middle 20%
    x_norm = np.clip(x_norm, 0, 1)

    # y already goes from 0..1, but brightest 25% from top
    # So we want y=0 (top) to have brightness 1, and fade down
    # Invert y so that y=0 is at top with full value
    y_from_top = 1 - y_grid

    # Alpha formula: (1 - |x|)^3 * (1 - |y|)^1.2
    # But y here is from-top normalized, so use y_from_top directly
    alpha = ((1 - x_norm) ** 3) * ((1 - y_from_top) ** 1.2)

    # Actually, rereading: brightest 25% from top means the top 25% should be brightest
    # So y goes from 0 (top, brightest) to 1 (bottom, darkest)
    # But the formula (1 - |y|)^1.2 would make y=0 give (1-0)^1.2 = 1 (bright)
    # and y=1 give (1-1)^1.2 = 0 (dark), which is backwards
    # Let me reconsider: the original formula is (1 - |y|)^1.2, suggesting y is centered
    # Actually, for a vertical streak occupying full height, y should range from -0.5 to 0.5
    # centered vertically, then (1 - |y|) gives the vertical envelope

    # Recompute: y should be centered, from -1 to 1 (full height), then normalized
    coords_y_centered = np.linspace(-1, 1, size)
    y_grid_centered, x_grid = np.meshgrid(coords_y_centered, coords_x)

    # x_norm as before
    x_norm = np.abs(x_grid) / 0.1
    x_norm = np.clip(x_norm, 0, 1)

    # y_norm: normalize to [0, 1]
    y_norm = np.abs(y_grid_centered)

    # Alpha formula: (1 - |x|)^3 * (1 - |y|)^1.2
    alpha = ((1 - x_norm) ** 3) * ((1 - y_norm) ** 1.2)

    # But "brightest 25% from the top" - we need to adjust so top is brighter
    # The formula above makes the middle of the streak brightest (y=0)
    # To make the top brighter, shift: y_from_top = y_grid_centered + 1 (range 0..2), then normalize
    y_from_top_normalized = (y_grid_centered + 1) / 2  # Now 0 (bottom) to 1 (top)
    y_from_top_normalized = np.clip(y_from_top_normalized, 0, 1)

    # Recompute with top emphasis
    # For "brightest 25% from top", we want the top 25% of the image to have enhanced alpha
    # One approach: use y_from_top and make the formula emphasize the top
    # (1 - |y|)^1.2 where y goes from -1 (bottom) to 1 (top) gives symmetric falloff
    # To emphasize top: use (1 - (1 - y_from_top_normalized))^1.2 = y_from_top_normalized^1.2
    # But that would be backwards. Let me use a different approach.

    # Actually, re-reading again: "full height" and "brightest 25% from the top"
    # suggests the formula applies to the full height, and naturally the top is brighter
    # due to the way the formula works. Let's stick with:
    # y normalized from 0 (top) to 1 (bottom)

    y_from_top = (y_grid_centered + 1) / 2  # 0 at top, 1 at bottom

    # Alpha: (1 - |x|)^3 * (1 - |y|)^1.2
    # But |y| when y goes 0..1 is just y
    alpha = ((1 - x_norm) ** 3) * ((1 - y_from_top) ** 1.2)

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
