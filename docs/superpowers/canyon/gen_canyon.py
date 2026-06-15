#!/usr/bin/env python3
"""Phase 0 packet generator for the ZenDojo canyon.
Outputs: heightmap.png (16-bit), heightmap_preview.png (8-bit), footprint.png,
elevation.png, CanyonLayout.luau, README.md  — into docs/superpowers/canyon/."""
import math, os
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

OUT = "/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/docs/superpowers/canyon"
os.makedirs(OUT, exist_ok=True)

# ---- canyon model (contract) : X = axis (head -X .. boundary +X), Z = cross, Y up
# origin (0,0) = clearing centre. control points: (x, floorY, innerHalf)
# v2: narrower gorge, two PRONOUNCED pinches (bridges), steeper walls.
CP = [
    (-260, 122, 26),   # head plunge pool (hero fall lands here)
    (-215, 100, 30),
    (-165,  78, 11),   # PINCH 1 -> suspension bridge (above middle falls)
    (-120,  62, 34),
    (-78,   48, 38),
    (-42,   40, 13),   # PINCH 2 -> bridge (just above the clearing)
    (0,     30, 50),   # CLEARING centre (widest)
    (55,    27, 40),
    (90,    24, 30),   # boundary lip
]
RIM      = 205.0
WALLRUN  = 30.0    # horizontal run of the steep wall (inner edge -> rim) — steeper
# NOTE: no pre-incised river channel — the floor is left flat-ish (just the
# down-canyon gradient) so Gaea's hydraulic erosion carves the river itself.
MAXY     = 260.0   # heightmap maps world Y 0..MAXY -> 0..65535
# square region centred to contain the gorge
CX, CZ, HALF = -85.0, 0.0, 220.0   # centre + half-extent (studs)
RES = 1024

cpx = np.array([c[0] for c in CP], float)
cpf = np.array([c[1] for c in CP], float)
cpi = np.array([c[2] for c in CP], float)

def floor_inner(x):
    f = np.interp(x, cpx, cpf)
    h = np.interp(x, cpx, cpi)
    # head closure: ramp floor up to rim & pinch inner -> 0 just past the head
    b = np.clip((cpx[0] - x) / 40.0, 0, 1)
    f = f * (1 - b) + RIM * b
    h = h * (1 - b)
    return f, h

def smoothstep(t):
    t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

# ---- heightmap ----
xs = np.linspace(CX - HALF, CX + HALF, RES)          # cols -> X
zs = np.linspace(CZ - HALF, CZ + HALF, RES)          # rows -> Z
floorY_col, inner_col = floor_inner(xs)
F = floorY_col[None, :] + np.zeros((RES, RES))
I = inner_col[None, :] + np.zeros((RES, RES))
D = np.abs(zs)[:, None] + np.zeros((RES, RES))

wall = F + (RIM - F) * smoothstep((D - I) / WALLRUN)
H = np.where(D <= I, F, wall)
H = np.minimum(H, RIM)
# (no river groove — flat-ish floor; erosion carves the channel)
# subtle deterministic plateau texture so it isn't mathematically flat
rng = np.random.default_rng(7)
low = rng.standard_normal((32, 32))
noise = np.array(Image.fromarray(low).resize((RES, RES), Image.BICUBIC))
mask = smoothstep((D - (I + WALLRUN * 0.6)) / 30.0)
H = H + noise * 2.2 * mask
H = np.clip(H, 0, MAXY)

u16 = (H / MAXY * 65535.0).astype(np.uint16)
Image.fromarray(u16).save(f"{OUT}/heightmap.png")            # 16-bit, the import file
Image.fromarray((H / MAXY * 255).astype(np.uint8)).save(f"{OUT}/heightmap_preview.png")

# ---- floor-protection erosion mask ----
# BLACK (0) over the channel floor + the immediate cliff foot; ramps to WHITE (1)
# up the walls and across the plateau. Feed to Gaea's erosion mask input where
# WHITE = "erode here". (If your node reads the mask as "protect where white",
# invert it.) Protecting a few studs up from the floor edge stops the over-incision
# at the cliff base.
emask = smoothstep((D - (I + 4.0)) / 12.0)
Image.fromarray((emask * 255).astype(np.uint8)).save(f"{OUT}/erosion_mask.png")

# ---- flat floor-reference heightmap (for a Combine->Max clamp) ----
# Same gorge, but walls cut off at the floor level -> a "tub" you Max against so
# erosion can carve detail but never drop the bottom below the channel grade.
floorRef = np.clip(F, 0, MAXY)  # the descending floor, full width (no walls)
Image.fromarray((floorRef / MAXY * 65535).astype(np.uint16)).save(f"{OUT}/floor_reference.png")

# ---- deterministic perch anchors (~18) ----
def frac(s):
    v = math.sin(s * 12.9898) * 43758.5453; return v - math.floor(v)
bases = [-210,-165,-120,-120,-75,-75,-35,-35,-35,0,0,0,55,55,55,-75,-120,-35]
perches = []
for k, bx in enumerate(bases):
    side = -1 if k % 2 == 0 else 1
    hf = 0.20 + frac(k * 3.1) * 0.62
    if k % 6 == 0:
        hf = 0.58 + frac(k * 1.7) * 0.34          # a few perched high
    x = bx + (frac(k * 7) - 0.5) * 30
    f, ih = floor_inner(np.array([x])); f, ih = float(f[0]), float(ih[0])
    z = side * (ih + 4 + frac(k * 5) * 6)
    y = f + (RIM - f) * hf
    perches.append((f"Perch{k+1:02d}", round(x, 1), round(y, 1), round(z, 1),
                    "L" if side < 0 else "R"))

# ---- footprint (top-down) ----
fig, ax = plt.subplots(figsize=(7, 9))
fx = np.linspace(-275, 100, 400)
ff, fih = floor_inner(fx)
rim_edge = fih + WALLRUN
ax.fill_betweenx(fx, -rim_edge, rim_edge, color="#9aa39a", alpha=0.5, label="rim span")
ax.fill_betweenx(fx, -fih, fih, color="#b8a382", alpha=0.9, label="gorge floor")
ax.plot([0, 0], [-275, 100], color="#2a6f9e", lw=2, label="river")
ax.add_patch(Rectangle((-72, -40), 144, 100, fill=False, ec="#d77757", lw=2, ls="--"))
ax.text(0, 10, "CLEARING\nshrine·bell·throw", ha="center", va="center", fontsize=8, color="#7a2")
ax.plot([-13, 13], [-165, -165], color="k", lw=2); ax.text(22, -165, "PINCH 1→bridge", fontsize=7)
ax.plot([-15, 15], [-42, -42], color="k", lw=2); ax.text(24, -42, "PINCH 2→bridge", fontsize=7)
ax.text(0, -262, "HERO FALL (head)", ha="center", fontsize=7, color="#268")
ax.text(0, 93, "BOUNDARY FALL", ha="center", fontsize=7, color="#268")
for nm, x, y, z, s in perches:
    ax.plot(z, x, "s", color="#5a3", ms=6)
ax.set_xlabel("Z (cross-canyon, studs)"); ax.set_ylabel("X (down-canyon, studs)")
ax.set_title("Canyon footprint (top-down)\norigin=clearing centre · green=teahouse perches")
ax.set_aspect("equal"); ax.invert_yaxis(); ax.legend(loc="lower right", fontsize=7)
ax.grid(alpha=0.2); plt.tight_layout(); plt.savefig(f"{OUT}/footprint.png", dpi=110); plt.close()

# ---- side elevation ----
fig, ax = plt.subplots(figsize=(11, 5))
ax.plot(fx, ff, color="#2a6f9e", lw=2.5, label="river floor (descent)")
ax.axhline(RIM, color="#777", ls="--", lw=1, label="rim ~205")
ax.fill_between(fx, ff, RIM, color="#cdd", alpha=0.25)
# hero fall + boundary fall
ax.annotate("", xy=(-260, 122), xytext=(-260, RIM), arrowprops=dict(arrowstyle="-|>", color="#268", lw=2))
ax.text(-258, 165, "HERO FALL", fontsize=8, color="#268")
ax.annotate("", xy=(96, -5), xytext=(90, 24), arrowprops=dict(arrowstyle="-|>", color="#268", lw=2))
ax.text(70, 8, "BOUNDARY\nFALL", fontsize=7, color="#268")
ax.add_patch(Rectangle((-72, 18), 132, 18, color="#b8a382", alpha=0.5))
ax.text(-6, 12, "CLEARING (gentle grade)", ha="center", fontsize=7, color="#963")
for nm, x, y, z, s in perches:
    ax.plot(x, y, "s", color=("#5a3" if s == "L" else "#3a6"), ms=6)
ax.text(-165, 82, "pinch1/bridge", fontsize=7); ax.text(-42, 44, "pinch2/bridge", fontsize=7)
ax.set_xlabel("X (down-canyon, studs)  ·  head ←   → boundary")
ax.set_ylabel("Y (studs)"); ax.set_title("Canyon side elevation — river descends the whole length; perches scatter the walls")
ax.legend(loc="upper right", fontsize=8); ax.grid(alpha=0.2)
plt.tight_layout(); plt.savefig(f"{OUT}/elevation.png", dpi=110); plt.close()

# ---- CanyonLayout.luau (the coordinate contract) ----
def perch_lua():
    out = []
    for nm, x, y, z, s in perches:
        out.append(f'        {{ name = "{nm}", pos = {{ {x}, {y}, {z} }}, wall = "{s}", facingCenter = true }},')
    return "\n".join(out)

luau = f'''--!strict
-- ZenDojo CANYON coordinate contract (Phase 0, 2026-06-15). DRAFT — not wired into
-- genmodels yet. Units: 1 = 1 stud, Y up. Origin (0,0,0) = CLEARING CENTRE.
-- X = down-canyon axis (head at -X, boundary at +X). Z = cross-canyon (centre 0).
-- Terrain is authored EXTERNALLY (Gaea/Blender) to this same frame; prop Y values
-- below are PROVISIONAL (from the greybox model) and get re-snapped onto the
-- imported terrain by a raycast pass before building. See README.md.
local CanyonLayout = {{
    meta = {{
        units = "stud", origin = "clearing-centre",
        heightmapRegion = {{ size = {2*HALF:.0f}, centre = {{ {CX:.0f}, {CZ:.0f} }} }}, -- square, studs (X,Z)
        heightRange = {{ 0, {MAXY:.0f} }}, -- heightmap 0..65535 maps world Y 0..{MAXY:.0f}
        rim = {RIM:.0f}, wallRun = {WALLRUN:.0f},
    }},
    -- river spline down the gorge: each point {{ x, floorY, innerHalf }} (floor descends)
    river = {{
{chr(10).join(f"        {{ {c[0]}, {c[1]}, {c[2]} }}," for c in CP)}
    }},
    clearing = {{ centre = {{ 0, 30, 0 }}, xRange = {{ -50, 50 }}, outcropHalf = 44, poolHalf = 16 }},
    falls = {{
        hero = {{ x = -260, topY = {RIM:.0f}, botY = 122 }},      -- tallest, at the head
        boundary = {{ x = 90, topY = 24, botY = -5 }},   -- view-only edge (no further)
        cascadeX = {{ -215, -165, -120, -78, -42 }},     -- intermediate drops between pools
    }},
    bridges = {{
        {{ kind = "suspension", x = -165 }}, -- pinch 1, above the middle falls
        {{ kind = "suspension", x = -42 }},  -- pinch 2, just above the clearing
    }},
    -- ~18 organic cliff-perch teahouses (stilted kake-zukuri). Y PROVISIONAL (snap to terrain).
    perches = {{
{perch_lua()}
    }},
    -- machinery near the clearing, fed by the fall spilling in just above it (short flume)
    machinery = {{
        shrine = {{ pos = {{ 14, 30, 18 }}, facingCenter = true }},
        bell   = {{ pos = {{ 14, 44, 18 }} }},
        wheel  = {{ pos = {{ -18, 31, 2 }}, note = "undershot, in the in-spilling fall" }},
        flume  = {{ from = {{ -34, 34, -2 }}, to = {{ -18, 32, 2 }} }}, -- short run
        sozu   = {{ pos = {{ -6, 30, -10 }} }},
    }},
}}
return CanyonLayout
'''
open(f"{OUT}/CanyonLayout.luau", "w").write(luau)

# ---- README ----
readme = f"""# ZenDojo Canyon — Phase 0 packet

Coordinate contract for the canyon. **Author terrain to this exact frame** so the
code-placed props snap onto it later.

## Frame
- 1 unit = 1 stud, Y up. Origin (0,0,0) = **clearing centre**.
- **X** = down-canyon axis: head (hero fall) at **x=-260**, boundary at **x=+90**.
- **Z** = cross-canyon, centred on 0.
- Rim ≈ y{RIM:.0f}; floor descends y122 (head) → y24 (clearing/boundary).

## heightmap.png  (the import file — 16-bit grayscale, {RES}×{RES})
- Covers a **square {2*HALF:.0f}×{2*HALF:.0f} stud** region centred at world (X={CX:.0f}, Z={CZ:.0f}).
  → region X [{CX-HALF:.0f}, {CX+HALF:.0f}], Z [{CZ-HALF:.0f}, {CZ+HALF:.0f}].
- White (65535) = world Y **{MAXY:.0f}**; black (0) = Y **0**. So set the terrain's
  vertical scale to **{MAXY:.0f} studs** over the {2*HALF:.0f}-stud region.
- Image axes: **width = X** (head at LEFT), **height = Z** (top = Z={CZ-HALF:.0f}).
- `heightmap_preview.png` is an 8-bit copy just for eyeballing.

## Using it in Gaea
1. New build → drop a **File/Heightmap Import** node, load `heightmap.png` as the base.
2. Erode/sculpt the rock character on top (Erosion, Stratify, etc.). The base already
   has the gorge channel, the descent, the pinch, and the clearing — keep those readable.
   (Heightmaps can't do overhangs; add those in Blender later if you want them.)
3. Export a 16-bit heightmap (Route A: → Roblox Terrain importer) **or** a decimated
   mesh (Route B: → Blender cleanup → MeshPart). Keep the **same region size + height
   scale** so the contract holds.

## Using it in Roblox (Route A, voxel)
Terrain Editor → Import → heightmap.png, set region size **({2*HALF:.0f}, {MAXY:.0f}, {2*HALF:.0f})** studs,
position the region so its centre is world (X={CX:.0f}, 0, Z={CZ:.0f}). Pick a base material.

## CanyonLayout.luau
The prop contract (river spline, clearing, falls, bridge pinch, ~18 perches, machinery).
Prop **Y values are provisional** — once your terrain is imported, I run a raycast-snap
pass to set each prop's real Y + surface normal, then regenerate the builders.

## Footprint / Elevation
`footprint.png` (top-down) and `elevation.png` (side) document the intended shape so
your Gaea sculpt matches — especially the **descent profile** and the **pinch**.
"""
open(f"{OUT}/README.md", "w").write(readme)

print("wrote:", sorted(os.listdir(OUT)))
print(f"height range built: {H.min():.1f}..{H.max():.1f}  perches: {len(perches)}")
