# backdrop_ranges.py — procedural mountain-range strips for the canyon's horizon backdrop.
#
# WHY: the terrain is a hard box (x -460..460, z -320..320, rims ~y300) and every vantage that
# looks over a rim or out the east mouth sees its cut edge against empty sky. The backdrop is a
# ring of range strips OUTSIDE that box; Lighting.Atmosphere fades them into the sky colour by
# distance, so they follow the day/night cycle with no code of their own. Two part-built trials
# (rolled blocks, then wedge pyramids) read as boxes/triangles — hence real meshes.
#
# WHAT: each strip is a height-field ridge — a meandering crest with a concave alpine cross
# profile, ridged multi-octave noise for sub-peaks and spurs, tapered to zero at both ends and
# both long edges so strips overlap and blend on the ring. Decimated to a low-poly FLAT-shaded
# mesh: the faceted read matches the canyon's tinted-rock cliffs. Flat zero-height apron at the
# base sits under the ground plane in Studio.
#
# SIZE: every strip is normalised so its bounding box is exactly L x D x H (below) with the
# base at z=0 and the crest at z=H. Real sizes are set in Studio via MeshPart.Size — non-uniform
# scaling is free — so the Studio placement script owns "how tall must this be from the
# suspension bridge", not this file. (Roblox caps any part axis at 2048 studs.)
#
# Export follows docs/wiki/practice/blender-pipeline.md §1 (global_scale=0.01 or the importer
# reads centimetres). Each strip goes to its OWN .fbx because Studio's 3D Importer budgets per
# file. Outputs are DERIVED (reproducible from this file) so they live in the untracked
# reference folder, never under art/ (see art/README.md).
#
# Usage:
#   headless:  /Applications/Blender.app/Contents/MacOS/Blender --background --python \
#                  roblox/tools/blender/backdrop_ranges.py -- [outdir]
#   live MCP:  exec(open(<this file>).read()); run(outdir)   # builds in the open session
#
# Stdlib + bpy only (repo policy).

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector, noise

# Canonical export box (studs). Placement rescales; keep the aspect plausible so preview reads.
L, D, H = 1000.0, 500.0, 400.0
RES_U, RES_V = 160, 48          # grid before decimation (15,360 tris)
TARGET_TRIS = 3000              # after decimation; silhouette over detail

# name, seed, kind — 'near' strips are busier (more sub-peaks, a foothill apron); 'far' strips
# are broader and calmer because atmosphere eats their detail anyway.
STRIPS = [
    ("RangeNearA", 11, "near"),
    ("RangeNearB", 12, "near"),
    ("RangeNearC", 13, "near"),
    ("RangeFarA", 21, "far"),
    ("RangeFarB", 22, "far"),
    ("RangeFarC", 23, "far"),
]

COLLECTION = "BackdropRanges"
DEFAULT_OUT = os.path.expanduser("~/Desktop/Roshambo Reference/backdrop_2026-09-03")


def smoothstep(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def fbm(p: Vector, octaves: int, lac: float = 2.0, gain: float = 0.5) -> float:
    """Plain fractal Brownian motion in about [-1, 1]."""
    amp, freq, total, norm = 1.0, 1.0, 0.0, 0.0
    for _ in range(octaves):
        total += amp * noise.noise(p * freq)
        norm += amp
        amp *= gain
        freq *= lac
    return total / norm


def ridged(p: Vector, octaves: int, lac: float = 2.1, gain: float = 0.55) -> float:
    """Ridged multifractal in [0, 1]: sharp crests, rounded valleys — reads as rock, not cloud."""
    amp, freq, total, norm, weight = 1.0, 1.0, 0.0, 0.0, 1.0
    for _ in range(octaves):
        n = 1.0 - abs(noise.noise(p * freq))
        n = n * n * weight
        weight = max(0.0, min(1.0, n * 2.0))
        total += n * amp
        norm += amp
        amp *= gain
        freq *= lac
    return total / norm


def height(u: float, v: float, seed: float, kind: str) -> float:
    """u in [0,1] along the strip, v in [-1,1] across it. Returns [0,1]-ish before normalisation."""
    s = Vector((seed * 7.31, seed * 3.17, seed * 1.73))

    # crest meanders across the depth; shape differs per seed
    crest = 0.22 * math.sin(2 * math.pi * (1.15 * u + seed * 0.37)) + 0.12 * fbm(s + Vector((u * 3.0, 0.0, 0.0)), 3)
    # crest height along the strip: ridged so peaks are sharp and saddles are real
    peaks_freq = 4.0 if kind == "near" else 2.6
    crestH = 0.45 + 0.55 * ridged(s + Vector((u * peaks_freq, 0.5, 0.0)), 4)
    # cross profile: concave alpine — steep at the crest, flaring at the base
    halfWidth = 0.75 + 0.25 * fbm(s + Vector((u * 2.0, 9.0, 0.0)), 2)
    d = abs(v - crest) / halfWidth
    profile = max(0.0, 1.0 - d) ** 1.35
    # 2D detail: spurs and sub-peaks down the faces; stronger on 'near' strips
    detail_amp = 0.42 if kind == "near" else 0.28
    detail_freq = 6.0 if kind == "near" else 4.0
    detail = ridged(s + Vector((u * detail_freq, v * detail_freq * 0.5 + 20.0, 0.0)), 4)
    h = crestH * profile * (1.0 - detail_amp + detail_amp * detail)
    # foothill apron on the front face of 'near' strips: a low second ridge toward -v
    if kind == "near":
        apron_c = crest - 0.55
        ad = abs(v - apron_c) / 0.35
        apron = max(0.0, 1.0 - ad) ** 1.2 * (0.18 + 0.14 * ridged(s + Vector((u * 7.0, 40.0, 0.0)), 3))
        h = max(h, apron)
    # taper to zero at both ends and both long edges so strips overlap cleanly on the ring
    end = smoothstep(0.0, 0.16, u) * smoothstep(0.0, 0.16, 1.0 - u)
    edge = smoothstep(0.0, 0.12, 1.0 - abs(v))
    return h * end * edge


def build_strip(name: str, seed: int, kind: str, col: bpy.types.Collection) -> bpy.types.Object:
    bm = bmesh.new()
    grid = [[None] * (RES_V + 1) for _ in range(RES_U + 1)]
    hs = [[0.0] * (RES_V + 1) for _ in range(RES_U + 1)]
    hmax = 1e-9
    for i in range(RES_U + 1):
        u = i / RES_U
        for j in range(RES_V + 1):
            v = -1.0 + 2.0 * j / RES_V
            h = height(u, v, float(seed), kind)
            hs[i][j] = h
            hmax = max(hmax, h)
    for i in range(RES_U + 1):
        u = i / RES_U
        for j in range(RES_V + 1):
            v = -1.0 + 2.0 * j / RES_V
            z = hs[i][j] / hmax * H            # crest lands exactly on z = H
            grid[i][j] = bm.verts.new(Vector(((u - 0.5) * L, v * 0.5 * D, z)))
    for i in range(RES_U):
        for j in range(RES_V):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)

    # decimate to a low-poly faceted mesh; flat shading is the look
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = TARGET_TRIS / (RES_U * RES_V * 2)
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.select_set(False)
    for poly in ob.data.polygons:
        poly.use_smooth = False
    ob["backdrop_kind"] = kind
    ob["backdrop_seed"] = seed
    return ob


def export_strip(ob: bpy.types.Object, path: str) -> None:
    """Export ONE object: a temp scene holding only it, because the MCP context has no reliable
    selection for use_selection=True (blender-pipeline.md traps)."""
    saved_loc = ob.location.copy()
    ob.location = (0.0, 0.0, 0.0)
    tmp = bpy.data.scenes.new("_export_tmp")
    tmp.collection.objects.link(ob)
    prev = bpy.context.window.scene
    bpy.context.window.scene = tmp
    try:
        bpy.ops.export_scene.fbx(
            filepath=path,
            use_selection=False,
            apply_unit_scale=True,
            global_scale=0.01,
            apply_scale_options="FBX_SCALE_NONE",
            object_types={"MESH"},
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
            path_mode="COPY",
            embed_textures=False,
            axis_forward="-Z",
            axis_up="Y",
        )
    finally:
        bpy.context.window.scene = prev
        bpy.data.scenes.remove(tmp)
        ob.location = saved_loc


def run(outdir: str = DEFAULT_OUT) -> dict:
    os.makedirs(outdir, exist_ok=True)
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    # rebuild only our own objects; touch nothing else in the scene
    for ob in list(col.objects):
        me = ob.data
        bpy.data.objects.remove(ob)
        if me and me.users == 0:
            bpy.data.meshes.remove(me)

    report = {}
    row = {"near": 0.0, "far": D * 2.2}
    for idx, (name, seed, kind) in enumerate(STRIPS):
        ob = build_strip(name, seed, kind, col)
        # lay the strips out in two rows for viewing; export zeroes the location
        ob.location = ((idx % 3) * (L * 1.15) - L * 1.15, row[kind], 0.0)
        fbx = os.path.join(outdir, f"{name}.fbx")
        export_strip(ob, fbx)
        report[name] = {"tris": len(ob.data.polygons), "verts": len(ob.data.vertices), "fbx": fbx}

    # viewport: solid + flat is the honest look for untextured facets; long clip so 3000-stud rows fit
    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                for space in area.spaces:
                    if space.type == "VIEW_3D":
                        space.shading.type = "SOLID"
                        space.clip_end = 50000.0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(outdir, "backdrop_ranges_scratch.blend"), copy=True)
    return report


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = run(argv[0] if argv else DEFAULT_OUT)
    for k, v in out.items():
        print(f"{k}: {v['tris']} tris -> {v['fbx']}")
