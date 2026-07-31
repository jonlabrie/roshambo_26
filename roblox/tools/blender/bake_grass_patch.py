# bake_grass_patch.py — trunkless ground-cover patch -> crossed-card clump impostor.
#
# WHY: bake_clump_tree.py expects a trunk + foliage material split and rebuilds a tree
# canopy cell-by-cell. Ground grass (the muhly set: 6 patch objects, 400k-1.15M tris of
# strand islands each, NO trunk) needs the whole plant in the image: thinning keeps ~2%
# of strands and goes bald, and there is no branch structure for clustering to betray —
# the one case where card impostors are simply right (spec 2026-07-30-foliage-finish §1).
#
# WHAT: per mesh object in the source, render two horizontal orthographic views (front
# -Y and side -X) with the vendor materials and a transparent film, compose them into
# one 2:1 RGBA atlas, and rebuild the patch as THREE crossed vertical quads (60° apart,
# 6 tris) UV'd to the two tiles. Origin at base centre. Height normalised per clump.
#
# Usage (headless):
#   /Applications/Blender.app/Contents/MacOS/Blender --background --python \
#     bake_grass_patch.py -- <src.fbx|.blend> <out_dir> <height_studs> [tile_px=512]
#
# Writes per object: <out_dir>/<Name>.fbx + <Name>_atlas.png (also embedded via the
# material so the Roblox importer uploads it).
#
# IN STUDIO after import, on the MeshPart:
#   * SurfaceAppearance.AlphaMode = Transparency (atlas alpha does the silhouette)
#   * DoubleSided: muhly plumes are PALE — leave FALSE first (transmission blowout,
#     the sakura lesson); flip only if card culling reads broken at the gate.

import bpy, sys, os, math, functools
import numpy as np

print = functools.partial(print, flush=True)

argv = sys.argv[sys.argv.index("--") + 1 :]
SRC, OUT_DIR, HEIGHT_STUDS = argv[0], argv[1], float(argv[2])
TILE = int(argv[3]) if len(argv) > 3 else 512
# post-bake grade: BRIGHTNESS lifts the whole image (dense self-shadowed bases bake
# near-black); ALPHA_GAIN fights mip erosion of wispy edges at distance; PINK_BOOST
# multiplies R (and slightly B) only where a pixel already leans red — plumes pink up,
# green stems stay green.
BRIGHTNESS = float(argv[4]) if len(argv) > 4 else 1.0
ALPHA_GAIN = float(argv[5]) if len(argv) > 5 else 1.0
PINK_BOOST = float(argv[6]) if len(argv) > 6 else 1.0
STEM_DARKEN = float(argv[7]) if len(argv) > 7 else 1.0  # <1 darkens green-leaning pixels

os.makedirs(OUT_DIR, exist_ok=True)

if SRC.lower().endswith(".blend"):
    bpy.ops.wm.open_mainfile(filepath=SRC)
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=SRC)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print(f"PATCHES: {[o.name for o in meshes]}")

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.film_transparent = True
scene.render.resolution_x = TILE
scene.render.resolution_y = TILE
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

sun = bpy.data.objects.new("bake_sun", bpy.data.lights.new("bake_sun", "SUN"))
scene.collection.objects.link(sun)
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(60), 0, math.radians(30))

# fill + ambient so dense plant bases don't bake to self-shadowed black
fill = bpy.data.objects.new("bake_fill", bpy.data.lights.new("bake_fill", "SUN"))
scene.collection.objects.link(fill)
fill.data.energy = 1.5
fill.rotation_euler = (math.radians(75), 0, math.radians(210))
world = bpy.data.worlds.new("bake_world")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (1, 1, 1, 1)
bg.inputs[1].default_value = 0.6

cam = bpy.data.objects.new("bake_cam", bpy.data.cameras.new("bake_cam"))
scene.collection.objects.link(cam)
cam.data.type = "ORTHO"
scene.camera = cam


def render_view(obj, direction, path):
    """Ortho render of obj's bbox from a horizontal direction ('front' -Y or 'side' -X).

    The render is a SQUARE tile covering a square (span x span) world region, so the
    plant occupies only a centred sub-rectangle of the image. Returns that occupancy
    as (width_fraction, height_fraction) — build_clump maps the quad UVs to exactly
    this sub-rect. Mapping the full tile onto an aspect-ratio quad double-applies the
    aspect (the v1 squish/stretch bug).
    """
    from mathutils import Vector

    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    ctr = (lo + hi) / 2
    size = hi - lo
    horiz = size.x if direction == "front" else size.y
    span = max(size.z, horiz) * 1.02
    cam.data.ortho_scale = span
    dist = max(size.x, size.y) * 2 + 1
    if direction == "front":
        cam.location = (ctr.x, lo.y - dist, ctr.z)
        cam.rotation_euler = (math.radians(90), 0, 0)
    else:
        cam.location = (lo.x - dist, ctr.y, ctr.z)
        cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return horiz / span, size.z / span


def grade(px):
    """Brightness lift + selective pink boost + alpha gain, in place (Nx4 array)."""
    rgb = px[:, :3]
    a = px[:, 3:4]
    rgb *= BRIGHTNESS
    if PINK_BOOST > 1.0:
        # plume pixels lean red; stems lean green — boost only the former
        reddish = rgb[:, 0] > rgb[:, 1] * 1.02
        rgb[reddish, 0] *= PINK_BOOST
        rgb[reddish, 2] *= 1.0 + (PINK_BOOST - 1.0) * 0.55
    if STEM_DARKEN < 1.0:
        greenish = rgb[:, 1] > rgb[:, 0] * 1.02
        rgb[greenish] *= STEM_DARKEN
    np.clip(rgb, 0.0, 1.0, out=rgb)
    np.clip(a * ALPHA_GAIN, 0.0, 1.0, out=a)


def compose_atlas(front_png, side_png, out_png):
    """Two square tiles -> one 2:1 atlas (front left, side right), graded."""
    a = bpy.data.images.load(front_png)
    b = bpy.data.images.load(side_png)
    atlas = bpy.data.images.new("atlas", TILE * 2, TILE, alpha=True)
    pa = np.array(a.pixels[:], dtype=np.float32).reshape(TILE, TILE, 4)
    pb = np.array(b.pixels[:], dtype=np.float32).reshape(TILE, TILE, 4)
    for tile_px in (pa, pb):
        grade(tile_px.reshape(-1, 4))
    out = np.concatenate([pa, pb], axis=1)
    atlas.pixels = out.ravel().tolist()
    atlas.filepath_raw = out_png
    atlas.file_format = "PNG"
    atlas.save()
    for img in (a, b, atlas):
        bpy.data.images.remove(img)


def build_clump(name, aspect_front, aspect_side, occ_front, occ_side, atlas_png):
    """A fan of MANY small cards, not 3 big crossed quads.

    Big flat quads each take one uniform lighting value, so the whole clump pops
    light/dark as the camera/sun angle changes (the v6 in-Play tinting bug). Ten
    smaller cards at jittered yaw/tilt break the clump into varied facets, and
    custom normals BENT OUTWARD from the clump core make lighting roll smoothly
    across it (the standard foliage-billboard trick). ~20 tris per clump.

    occ_* are the (width, height) fractions of each square tile the plant actually
    occupies (centred); UVs map each card to exactly that sub-rect.
    """
    import random

    h = HEIGHT_STUDS
    rng = random.Random(sum(ord(c) for c in name))  # deterministic per variant
    N = 10
    mesh = bpy.data.meshes.new(name)
    verts, faces, uvs = [], [], []
    for i in range(N):
        use_side = i % 3 == 2
        aspect = aspect_side if use_side else aspect_front
        fx, fz = occ_side if use_side else occ_front
        frac = 0.95 if i == 0 else rng.uniform(0.62, 0.8)
        ch = h * frac
        cw = ch * aspect
        ang = rng.uniform(0, 2 * math.pi)
        rad = 0.0 if i == 0 else rng.uniform(0.08, 0.2) * h * aspect_front
        cx, cy = math.cos(ang) * rad, math.sin(ang) * rad
        yaw = rng.uniform(0, math.pi)
        dx, dy = math.cos(yaw), math.sin(yaw)
        nxd, nyd = -dy, dx  # card's horizontal normal direction
        lean = math.sin(math.radians(rng.uniform(-9, 9))) * ch
        w = cw / 2
        base = len(verts)
        verts += [
            (cx - w * dx, cy - w * dy, 0.0),
            (cx + w * dx, cy + w * dy, 0.0),
            (cx + w * dx + nxd * lean, cy + w * dy + nyd * lean, ch),
            (cx - w * dx + nxd * lean, cy - w * dy + nyd * lean, ch),
        ]
        faces.append((base, base + 1, base + 2, base + 3))
        uc = 0.75 if use_side else 0.25
        u0, u1 = uc - 0.25 * fx, uc + 0.25 * fx  # tile is half the atlas wide
        v0, v1 = 0.5 - 0.5 * fz, 0.5 + 0.5 * fz
        uvs.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    mesh.from_pydata(verts, [], faces)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    li = 0
    for f, quad_uv in zip(mesh.polygons, uvs):
        for corner_uv in quad_uv:
            uv_layer.data[li].uv = corner_uv
            li += 1
    mesh.update()

    # bend normals outward from a point below the clump core so shading rolls
    # smoothly across the cards instead of flipping per flat plane
    import mathutils

    core = mathutils.Vector((0.0, 0.0, -h * 0.25))
    bent = []
    for v in mesh.vertices:
        n = (mathutils.Vector(v.co) - core).normalized()
        bent.append(n)
    try:
        mesh.normals_split_custom_set_from_vertices(bent)
        print(f"  bent normals OK ({len(bent)} verts)")
    except Exception as e:
        print(f"  bent normals FAILED ({e}) — cards will shade flat")

    mat = bpy.data.materials.new(name + "_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(atlas_png)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    mat.blend_method = "CLIP" if hasattr(mat, "blend_method") else None
    mesh.materials.append(mat)

    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj


for src_obj in meshes:
    name = src_obj.name
    short = "MuhlyGrass" if name.endswith("_01") else "MuhlyGrass" + name[-2:].replace("0", "")
    for o in meshes:
        o.hide_render = o is not src_obj
    from mathutils import Vector

    bb = [src_obj.matrix_world @ Vector(c) for c in src_obj.bound_box]
    sx = max(v.x for v in bb) - min(v.x for v in bb)
    sy = max(v.y for v in bb) - min(v.y for v in bb)
    sz = max(v.z for v in bb) - min(v.z for v in bb)
    front_png = os.path.join(OUT_DIR, f"{short}_front.png")
    side_png = os.path.join(OUT_DIR, f"{short}_side.png")
    atlas_png = os.path.join(OUT_DIR, f"{short}_atlas.png")
    occ_front = render_view(src_obj, "front", front_png)
    occ_side = render_view(src_obj, "side", side_png)
    compose_atlas(front_png, side_png, atlas_png)
    clump = build_clump(short, sx / sz, sy / sz, occ_front, occ_side, atlas_png)

    bpy.ops.object.select_all(action="DESELECT")
    clump.select_set(True)
    bpy.context.view_layer.objects.active = clump
    out_fbx = os.path.join(OUT_DIR, f"{short}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=out_fbx,
        use_selection=True,
        global_scale=0.01,
        path_mode="COPY",
        embed_textures=True,
    )
    bpy.data.objects.remove(clump, do_unlink=True)
    os.remove(front_png)
    os.remove(side_png)
    print(f"WROTE {out_fbx} (atlas {atlas_png}, aspects f={sx/sz:.2f} s={sy/sz:.2f})")

print("DONE")
