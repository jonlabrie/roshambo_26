#!/usr/bin/env python3
"""Generate the salute flare sprites (256x256 RGBA, premult-friendly).

Salutes are a FIRST-CLASS effect (owner, 2026-09-06): the flash is purpose-made
burst art, not stacked engine primitives. Three crossed streak sprites read as a
line whenever the engine's random rotations happened to align; these bake the
star shape INTO the texture, so one sprite per shot always reads as a burst,
and the shuffle + random rotation happens per shot in the controller.

Each flare = a hot gaussian core + N radial spikes of varied length/width at
irregular angles. Four variants so a salvo never repeats a silhouette:
  a: 4-point classic star, one long axis        b: 6-point, irregular lengths
  c: 5-point asymmetric                          d: 8 short jagged spikes, fat core

Pure white; ALL color comes from the emitter. Deterministic: fixed seeds, same
bytes every run. Run from roblox/:  python3 tools/textures/make_salute_flares.py
"""

import numpy as np
from PIL import Image


def make_flare(seed: int, spikes: int, core_r: float, spike_len: tuple, spike_w: tuple) -> np.ndarray:
    rng = np.random.default_rng(seed)
    size = 256
    coords = np.linspace(-1, 1, size)
    y, x = np.meshgrid(coords, coords)
    r = np.sqrt(x**2 + y**2)
    theta = np.arctan2(y, x)

    # The hot core: gaussian, hard center.
    alpha = np.exp(-((r / core_r) ** 2)) ** 1.4

    # Spikes at irregular angles: evenly spaced base angles jittered up to a
    # third of the spacing, so no variant is a perfect regular star.
    base = np.linspace(0, 2 * np.pi, spikes, endpoint=False)
    jitter = rng.uniform(-np.pi / spikes / 1.5, np.pi / spikes / 1.5, spikes)
    for ang, jit in zip(base, jitter):
        a = ang + jit
        length = rng.uniform(*spike_len)
        width = rng.uniform(*spike_w)
        # Distance along and perpendicular to the spike axis.
        along = x * np.cos(a) + y * np.sin(a)
        perp = -x * np.sin(a) + y * np.cos(a)
        # The spike tapers: wide at the core, needle at the tip.
        taper = np.clip(1 - along / length, 0, 1)
        spike = np.exp(-((perp / (width * (0.25 + 0.75 * taper))) ** 2)) * taper**1.6
        spike = np.where(along > 0, spike, 0)
        alpha = np.maximum(alpha, spike)

    # Noisy edges (owner, 2026-09-06: "the edges of those images should be a
    # little noisier"): multiplicative grain weighted toward LOW alpha, so the
    # hot core stays solid while spike edges go ragged. Two octaves -- chunky
    # quarter-res grain (survives mipmapping at distance) plus fine per-pixel
    # sparkle.
    chunky = np.kron(rng.uniform(0, 1, (size // 4, size // 4)), np.ones((4, 4)))
    fine = rng.uniform(0, 1, (size, size))
    grain = 0.65 * chunky + 0.35 * fine
    alpha = alpha * (1 - 0.5 * (1 - alpha) ** 1.5 * grain)

    # Border window: alpha reaches EXACTLY zero before the quad's edge, so a
    # rotated sprite never shows a hard cut.
    edge = np.clip((0.98 - np.maximum(np.abs(x), np.abs(y))) / 0.08, 0, 1)
    alpha = np.clip(alpha * edge, 0, 1)

    rgba = np.zeros((size, size, 4), dtype=np.uint8)
    rgba[:, :, :3] = 255
    rgba[:, :, 3] = (alpha * 255).astype(np.uint8)
    return rgba


FLARES = {
    "a": dict(seed=11, spikes=4, core_r=0.10, spike_len=(0.55, 0.92), spike_w=(0.055, 0.085)),
    "b": dict(seed=23, spikes=6, core_r=0.11, spike_len=(0.40, 0.85), spike_w=(0.045, 0.075)),
    "c": dict(seed=37, spikes=5, core_r=0.10, spike_len=(0.45, 0.90), spike_w=(0.050, 0.080)),
    "d": dict(seed=52, spikes=8, core_r=0.15, spike_len=(0.30, 0.55), spike_w=(0.050, 0.070)),
}

if __name__ == "__main__":
    for name, spec in FLARES.items():
        path = f"tools/textures/firework_flare_{name}.png"
        Image.fromarray(make_flare(**spec), "RGBA").save(path, optimize=False)
        print(f"Created {path}")
