# ZenDojo Canyon — Phase 0 packet

Coordinate contract for the canyon. **Author terrain to this exact frame** so the
code-placed props snap onto it later.

## Frame
- 1 unit = 1 stud, Y up. Origin (0,0,0) = **clearing centre**.
- **X** = down-canyon axis: head (hero fall) at **x=-260**, boundary at **x=+90**.
- **Z** = cross-canyon, centred on 0.
- Rim ≈ y205; floor descends y122 (head) → y24 (clearing/boundary).

## heightmap.png  (the import file — 16-bit grayscale, 1024×1024)
- Covers a **square 440×440 stud** region centred at world (X=-85, Z=0).
  → region X [-305, 135], Z [-220, 220].
- White (65535) = world Y **260**; black (0) = Y **0**. So set the terrain's
  vertical scale to **260 studs** over the 440-stud region.
- Image axes: **width = X** (head at LEFT), **height = Z** (top = Z=-220).
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
Terrain Editor → Import → heightmap.png, set region size **(440, 260, 440)** studs,
position the region so its centre is world (X=-85, 0, Z=0). Pick a base material.

## CanyonLayout.luau
The prop contract (river spline, clearing, falls, bridge pinch, ~18 perches, machinery).
Prop **Y values are provisional** — once your terrain is imported, I run a raycast-snap
pass to set each prop's real Y + surface normal, then regenerate the builders.

## Footprint / Elevation
`footprint.png` (top-down) and `elevation.png` (side) document the intended shape so
your Gaea sculpt matches — especially the **descent profile** and the **pinch**.
