# export_tree.py — archviz tree FBX -> Roblox-ready FBX
#
# APPROVED SUGI RECIPE (2026-07-26, user-gated in Studio at 68k tris):
#   <src> <object> leaves 38000 30000 <height_studs> <out.fbx> 1.6 0.0 1 0.0 0.0 2 2
#   i.e. foliage 38k over 2 meshes, wood 30k over 2 meshes, spray scale 1.6,
#        snap/relax/orphan-cull ALL OFF, TRUNK_KEEP_ALL=1 (smart wood reduction).
#
# Why those numbers:
#   * Roblox's 20k triangle cap is PER MESH, not per model, and a model may hold any
#     number of MeshParts — so splitting foliage/wood across meshes buys real budget.
#     BUT Studio's 3D IMPORTER enforces a file-level budget, so each mesh must be
#     exported to its OWN .fbx and reassembled in Studio (see tools/blender/split_fbx
#     usage and the manifest.json it writes with true part offsets).
#   * Keeping the twigs is what fixes foliage "floating": sprays hang on ~4,250 twig
#     islands, and deleting them orphans the foliage. Snap/relax/orphan-cull were all
#     compensation for that and are unnecessary once the twigs survive.
#   * SMART WOOD: decimate the main island only (smooth, decimates cleanly) and keep
#     twigs WHOLE, dropping whole twigs to fit. Uniform decimation shreds them.
#   * Spray scale compensates for thinning: keep ~29% of cards -> 1.6x linear. The old
#     2.6x belonged to the 14%-of-cards era and reads coarse at this density. (spec 2026-07-25-square-canopy-foliage).
#
# Generalizes export_niwaki.py to any "trunk mesh + opacity-card foliage" source tree.
# Used for: the TurboSquid niwaki set (product 2017007) and the sugi/Japanese-cedar set
# (6 variants, 178k-395k polys). Sources are NOT committed — they live in
# ~/Desktop/Roshambo Reference/<set>/.
#
# Reduction:
#   trunk   — keep the top-N connected islands >= MIN_ISLAND faces (drops modelled twigs
#             that decimate into spaghetti), then decimate to TRUNK_TRIS.
#   foliage — the opacity-card leaf/needle clusters, deterministically (integer LCG)
#             thinned by whole islands to ~FOLIAGE_TRIS. Card geometry is preserved, so
#             the source's own leaf textures keep doing the visual work.
#   texture — diffuse RGB + the OPACITY jpg composite into ONE RGBA PNG, because Roblox
#             SurfaceAppearance reads alpha from the ColorMap and ignores a separate map.
#   scale   — height baked in studs; global_scale=0.01 on export or the Roblox importer
#             sees centimetres and clamps at 2048 studs.
#
# Usage (headless):
#   /Applications/Blender.app/Contents/MacOS/Blender --background --python export_tree.py -- \
#       <src.fbx> <object name> <foliage material key> <foliage_tris> <trunk_tris> \
#       <height_studs> <out.fbx>
#
# IN STUDIO after import, on the FOLIAGE MeshPart:
#   * SurfaceAppearance.AlphaMode = Transparency
#   * MeshPart.DoubleSided = TRUE  <-- easy to miss and costly: foliage cards are
#     single-sided planes, so with the Roblox default (false) every back-facing card is
#     CULLED and the canopy silently loses a large share of its cards from any given
#     viewpoint. Costs no triangles.
#
# (original note) File -> Import 3D (NOT "as package"); then set the foliage MeshPart's
# SurfaceAppearance.AlphaMode = Transparency.

import bpy, bmesh, sys, math, os, glob, functools
import numpy as np
import mathutils

print = functools.partial(print, flush=True)

argv = sys.argv[sys.argv.index("--") + 1:]
FBX, OBJ, FOLIAGE_KEY = argv[0], argv[1], argv[2]
FOLIAGE_TRIS, TRUNK_TRIS = int(argv[3]), int(argv[4])
HEIGHT_STUDS, OUT_FBX = float(argv[5]), argv[6]
# Optional 8th arg: scale each SURVIVING card about its own centroid. Thinning removes
# cards; enlarging the survivors refills the canopy without adding triangles. The
# vendor's own UVs are untouched, so every card still carries a real needle spray (this
# is why clump-BAKING was abandoned — see bake_clump_tree.py's blobby output).
SPRAY_SCALE = float(argv[7]) if len(argv) > 7 else 1.0
# Optional 9th arg: how far to snap each card toward the nearest surviving trunk vertex
# (1.0 = touch it, 0 = off). See the snap block below for why this is needed.
SNAP = float(argv[8]) if len(argv) > 8 else 1.0
# Optional 10th arg: 1 = keep ALL trunk islands (the ~4,250 fine twigs the sprays
# actually hang on) and let DECIMATE thin the whole thing. 0 = cull to the big islands
# first, which is right for sources whose twigs are modelled thick (the niwaki) but
# orphans the foliage on sources like the sugi.
TRUNK_KEEP_ALL = (len(argv) > 9 and argv[9] == "1")
# Optional 11th arg: RELAX — per-card random displacement (source units, deterministic
# LCG). Snapping pulls many cards onto the same few surviving trunk vertices, which
# reads as tight pom-poms; a little jitter loosens the cluster back into foliage.
RELAX = float(argv[10]) if len(argv) > 10 else 0.0
# Optional 12th arg: ORPHAN_MAX — after snapping, DELETE any card still further than
# this (source units) from surviving trunk geometry. These are sprays that hung on the
# longest culled twigs; no snap can reach them, so they read as foliage floating in
# space. 0 = keep everything.
ORPHAN_MAX = float(argv[11]) if len(argv) > 11 else 0.0
# Optional 13th arg: split the foliage across N MeshParts. Roblox's 20k triangle limit
# is PER MESH, not per model, and a model may hold any number of MeshParts — so N
# foliage meshes buy N x 20k of canopy. Costs extra draw calls; fine for hero trees.
FOLIAGE_PARTS = int(argv[12]) if len(argv) > 12 else 1
# Optional 14th arg: split the WOOD across N MeshParts too. With TRUNK_KEEP_ALL=1 and
# TRUNK_TRIS=0 this ships the complete trunk + all ~4,250 twig islands with NO
# decimation — the twigs are what the sprays actually hang on, so keeping them removes
# the need for snapping/orphan-culling entirely.
TRUNK_PARTS = int(argv[13]) if len(argv) > 13 else 1
MIN_ISLAND, MAX_TRUNK_ISLANDS = 200, 10

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)

tree = bpy.data.objects[OBJ]
wm = tree.matrix_world.copy()
for o in list(bpy.data.objects):
    if o.name != OBJ:
        bpy.data.objects.remove(o, do_unlink=True)
tree.parent = None
tree.matrix_world = wm
bpy.ops.object.select_all(action="DESELECT")
tree.select_set(True)
bpy.context.view_layer.objects.active = tree
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if max(tree.dimensions) > 200:
    raise SystemExit(f"ABORT: {max(tree.dimensions):.0f} units after apply — unexpected source scale")

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")

foliage, trunk = None, None
for o in list(bpy.data.objects):
    if any(m and FOLIAGE_KEY.lower() in m.name.lower() for m in o.data.materials):
        foliage = o
    elif trunk is None:
        trunk = o
    else:
        bpy.ops.object.select_all(action="DESELECT")
        trunk.select_set(True)
        o.select_set(True)
        bpy.context.view_layer.objects.active = trunk
        bpy.ops.object.join()
if foliage is None or trunk is None:
    raise SystemExit(f"ABORT: could not split trunk/foliage on key {FOLIAGE_KEY!r}")
foliage_objs = [foliage]   # becomes N meshes if FOLIAGE_PARTS > 1 (see the split below)
trunk_objs = [trunk]       # becomes N meshes if TRUNK_PARTS > 1


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def islands_of(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    seen, comps = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        comps.append(comp)
    return bm, comps


# TRUNK: main islands only, then decimate
bm, comps = islands_of(trunk)
comps.sort(key=len, reverse=True)
keep = set()
if TRUNK_KEEP_ALL:
    for comp in comps:
        keep.update(f.index for f in comp)
else:
    for comp in comps[:MAX_TRUNK_ISLANDS]:
        if len(comp) >= MIN_ISLAND or not keep:
            keep.update(f.index for f in comp)
print(f"TRUNK islands={len(comps)} kept={'ALL' if TRUNK_KEEP_ALL else len(keep)}")
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
bm.to_mesh(trunk.data)
bm.free()
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = trunk
if TRUNK_KEEP_ALL and TRUNK_TRIS > 0:
    # SMART WOOD REDUCTION. The main island (trunk + major branches) is smooth solid
    # geometry and decimates cleanly; the twigs are ~6-face slivers that decimation
    # shreds into visible shards. So decimate ONLY the island, and keep twigs WHOLE,
    # dropping a deterministic subset to fit the budget. Uniform decimation over both
    # is what produced the earlier spaghetti.
    wb = bmesh.new(); wb.from_mesh(trunk.data); wb.faces.ensure_lookup_table()
    seen, isl = set(), []
    for f in wb.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop(); comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index); stack.append(nf)
        isl.append([f.index for f in comp])
    isl.sort(key=len, reverse=True)
    main_idx, twig_isl = set(isl[0]), isl[1:]
    tri_of = {f.index: len(f.verts) - 2 for f in wb.faces}
    wb.free()

    MAIN_BUDGET = max(1500, int(TRUNK_TRIS * 0.18))
    twig_budget = max(0, TRUNK_TRIS - MAIN_BUDGET)
    state_t = 24680
    kept_twigs, used = [], 0
    for comp in twig_isl:                      # largest twigs first, then deterministic
        cost = sum(tri_of[i] for i in comp)
        if used + cost <= twig_budget:
            kept_twigs.append(comp); used += cost
    keep_faces = set(main_idx)
    for comp in kept_twigs:
        keep_faces.update(comp)
    bm2 = bmesh.new(); bm2.from_mesh(trunk.data); bm2.faces.ensure_lookup_table()
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.index not in keep_faces],
                     context="FACES")
    bm2.to_mesh(trunk.data); bm2.free()
    print(f"SMART WOOD: island->{MAIN_BUDGET} tris, twigs kept {len(kept_twigs)}/{len(twig_isl)} whole ({used} tris)")

    # decimate the island alone: isolate it, decimate, then rejoin the untouched twigs
    bm3 = bmesh.new(); bm3.from_mesh(trunk.data); bm3.faces.ensure_lookup_table()
    seen, isl2 = set(), []
    for f in bm3.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop(); comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index); stack.append(nf)
        isl2.append([f.index for f in comp])
    isl2.sort(key=len, reverse=True)
    big = set(isl2[0])
    bm3.free()
    tw_mesh = bpy.data.meshes.new("twigs_keep")
    bt = bmesh.new(); bt.from_mesh(trunk.data); bt.faces.ensure_lookup_table()
    bmesh.ops.delete(bt, geom=[f for f in bt.faces if f.index in big], context="FACES")
    bt.to_mesh(tw_mesh); bt.free()
    bi = bmesh.new(); bi.from_mesh(trunk.data); bi.faces.ensure_lookup_table()
    bmesh.ops.delete(bi, geom=[f for f in bi.faces if f.index not in big], context="FACES")
    bi.to_mesh(trunk.data); bi.free()
    bpy.context.view_layer.objects.active = trunk
    dec = trunk.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, MAIN_BUDGET / max(tri_count(trunk), 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    tw_obj = bpy.data.objects.new("twigs_keep", tw_mesh)
    bpy.context.scene.collection.objects.link(tw_obj)
    for m in trunk.data.materials:
        tw_mesh.materials.append(m)
    bpy.ops.object.select_all(action="DESELECT")
    trunk.select_set(True); tw_obj.select_set(True)
    bpy.context.view_layer.objects.active = trunk
    bpy.ops.object.join()
    print(f"SMART WOOD total = {tri_count(trunk)} tris")
elif TRUNK_TRIS > 0:
    dec = trunk.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, TRUNK_TRIS / max(tri_count(trunk), 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
else:
    print(f"TRUNK kept undecimated at {tri_count(trunk)} tris")

# tree axis = trunk centre in XZ; spray scaling anchors to whichever card vertex is
# nearest this axis (see below)
_tv = [trunk.matrix_world @ v.co for v in trunk.data.vertices]
TRUNK_PTS = [v.co.copy() for v in trunk.data.vertices]
AXIS_X = sum(v.x for v in _tv) / max(len(_tv), 1)
AXIS_Z = sum(v.z for v in _tv) / max(len(_tv), 1)

# FOLIAGE: thin whole cards to the target tri budget (deterministic LCG)
bm, comps = islands_of(foliage)
# measure ACTUAL triangles per island (a face may be a quad or a tri); the old
# estimate assumed 2 tris per face for every island and undershot the budget by ~2x.
_tris = sum(len(f.verts) - 2 for c in comps for f in c)
per_island = max(1.0, _tris / len(comps))
frac = min(1.0, (FOLIAGE_TRIS / per_island) / len(comps))
state = 12345
doomed, kept = [], 0
for comp in comps:
    state = (1103515245 * state + 12345) % 2147483648
    if state / 2147483648 < frac:
        kept += 1
    else:
        doomed.extend(comp)
bmesh.ops.delete(bm, geom=doomed, context="FACES")
if SPRAY_SCALE != 1.0 or RELAX > 0.0:
    bm.faces.ensure_lookup_table()
    seen2, grown = set(), 0
    orphan_faces = []
    for f in bm.faces:
        if f.index in seen2:
            continue
        stack, comp_v, comp_f = [f], set(), []
        seen2.add(f.index)
        while stack:
            cur = stack.pop()
            comp_v.update(cur.verts)
            comp_f.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen2:
                        seen2.add(nf.index)
                        stack.append(nf)
        # Anchor at the card's INNER end — the vertex closest to the tree's vertical
        # axis, i.e. where the spray meets its branch. Scaling about the centroid
        # (the obvious choice) grows the card in BOTH directions, pulling its
        # attachment end away from the branch tip and leaving foliage visibly
        # floating in space.
        anchor, best = None, None
        for v in comp_v:
            dx, dz = v.co.x - AXIS_X, v.co.z - AXIS_Z
            d2 = dx * dx + dz * dz
            if best is None or d2 < best:
                best, anchor = d2, v.co.copy()
        # SNAP TO SURVIVING BRANCH. The source hangs its sprays on ~4,250 tiny twig
        # islands; the trunk budget can only keep the one big island (trunk + major
        # branches), so every spray is left orphaned a stud or so out in space.
        # Translate each card so its inner vertex meets the nearest surviving trunk
        # vertex — foliage then sits on geometry the player can actually see.
        shift = mathutils.Vector((0, 0, 0))
        residual = 0.0
        if TRUNK_PTS:
            tgt, bd = None, None
            for tp in TRUNK_PTS:
                d2 = (tp - anchor).length_squared
                if bd is None or d2 < bd:
                    bd, tgt = d2, tp
            if tgt is not None:
                shift = (tgt - anchor) * SNAP
                residual = (bd ** 0.5) * (1.0 - SNAP)
        if ORPHAN_MAX > 0.0 and residual > ORPHAN_MAX:
            orphan_faces.extend(comp_f)
            continue
        if RELAX > 0.0:
            jitter = mathutils.Vector((0, 0, 0))
            for _ax in range(3):
                state = (1103515245 * state + 12345) % 2147483648
                jitter[_ax] = (state / 2147483648 * 2 - 1) * RELAX
            shift = shift + jitter
        for v in comp_v:
            v.co = (anchor + (v.co - anchor) * SPRAY_SCALE) + shift
        grown += 1
    if orphan_faces:
        bmesh.ops.delete(bm, geom=orphan_faces, context="FACES")
        print(f"ORPHANS culled: {len(orphan_faces)} faces beyond {ORPHAN_MAX} of any branch")
    print(f"SPRAY-SCALE x{SPRAY_SCALE} on {grown} surviving cards")
bm.to_mesh(foliage.data)
bm.free()
print(f"RESULT foliage_tris={tri_count(foliage)} trunk_tris={tri_count(trunk)} (kept {kept}/{len(comps)} cards)")

# textures: repoint to whatever sits next to the FBX (vendors ship a *_maps sibling)
tex_by_name = {}
search_dirs = [os.path.dirname(FBX)] + glob.glob(os.path.join(os.path.dirname(FBX), "*")) \
    + glob.glob(os.path.join(os.path.dirname(os.path.dirname(FBX)), "* Texture"))
for td in search_dirs:
    if os.path.isdir(td):
        for f in os.listdir(td):
            tex_by_name.setdefault(f.lower(), os.path.join(td, f))
for img in bpy.data.images:
    base = os.path.basename(img.filepath).lower()
    if base in tex_by_name:
        img.filepath = tex_by_name[base]
        img.reload()

# composite diffuse RGB + opacity -> one RGBA PNG (Roblox SA reads ColorMap alpha)
out_dir = os.path.dirname(OUT_FBX)
os.makedirs(out_dir, exist_ok=True)
fol_mat = foliage.data.materials[0]
diff_node = next((n for n in fol_mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image
                  and "opa" not in n.image.name.lower()), None)
opac_path = next((v for k, v in tex_by_name.items()
                  if "opa" in k and FOLIAGE_KEY.split("_")[0].lower() in k), None)
if opac_path is None:
    opac_path = next((v for k, v in tex_by_name.items() if "opa" in k), None)
if diff_node and opac_path:
    diff_img = diff_node.image
    opac_img = bpy.data.images.load(opac_path)
    w, h = diff_img.size
    if opac_img.size[0] != w or opac_img.size[1] != h:
        opac_img.scale(w, h)
    diff = np.empty(w * h * 4, dtype=np.float32)
    diff_img.pixels.foreach_get(diff)
    opac = np.empty(w * h * 4, dtype=np.float32)
    opac_img.pixels.foreach_get(opac)
    rgba = diff.reshape(-1, 4).copy()
    rgba[:, 3] = opac.reshape(-1, 4)[:, 0]
    name = os.path.splitext(os.path.basename(OUT_FBX))[0]
    combined = bpy.data.images.new(name + "_leaves", w, h, alpha=True)
    combined.pixels.foreach_set(rgba.reshape(-1))
    combined.filepath_raw = os.path.join(out_dir, name + "_leaves.png")
    combined.file_format = "PNG"
    combined.save()
    diff_node.image = combined
    print(f"TEXTURE {combined.filepath_raw} {w}x{h}")
else:
    print("WARN no diffuse/opacity pair found — foliage will import opaque")

# TRUNK MATERIAL: vendors wire albedo + normal + roughness; Roblox's importer picks
# one for SurfaceAppearance.ColorMap and picked a GRAYSCALE map (trunk imported
# bone-white). Keep only the albedo image so the choice is unambiguous.
for _m in trunk.data.materials:
    if not (_m and _m.use_nodes):
        continue
    _nt = _m.node_tree
    _texs = [n for n in _nt.nodes if n.type == "TEX_IMAGE" and n.image]
    # match on FILEPATH: the importer names images "Map #123456", so image.name
    # never contains "alb"/"nrm"/"rough" — only the filepath does.
    def _isalb(n):
        return "alb" in os.path.basename(n.image.filepath).lower()

    _alb = next((n for n in _texs if _isalb(n)), None)
    if _alb:
        for n in _texs:
            if n is not _alb:
                _nt.nodes.remove(n)
        _p = next((n for n in _nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if _p:
            _nt.links.new(_alb.outputs["Color"], _p.inputs["Base Color"])
        print(f"TRUNK-TEX kept {_alb.image.name}, dropped {len(_texs) - 1} non-albedo maps")

# STRIP VERTEX COLOURS. These vendor meshes carry a black colour attribute
# (RGB 0,0,0). Roblox MULTIPLIES vertex colours into a MeshPart's TextureID, so the
# trunk rendered pure BLACK no matter which texture was assigned — including textures
# known-good on other meshes. (SurfaceAppearance OVERRIDES vertex colour instead of
# multiplying, which is why the foliage was unaffected and why the trunk looked merely
# white back when it still had a SurfaceAppearance.)
for _o in trunk_objs + foliage_objs:
    for _ca in list(_o.data.color_attributes):
        _o.data.color_attributes.remove(_ca)
    print(f"VCOL stripped from {_o.name}")

# scale to target stud height, then name meshes per output file (Asset Manager legibility)
pts = [o.matrix_world @ mathutils.Vector(c) for o in (trunk, foliage) for c in o.bound_box]
zmin, zmax = min(p.z for p in pts), max(p.z for p in pts)
s = HEIGHT_STUDS / (zmax - zmin)
for o in (trunk, foliage):
    o.scale = (s, s, s)
bpy.ops.object.select_all(action="DESELECT")
for _o in trunk_objs + foliage_objs:
    _o.select_set(True)
bpy.context.view_layer.objects.active = trunk
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- split foliage into FOLIAGE_PARTS meshes (each gets its own 20k budget) ---
if TRUNK_PARTS > 1:
    sbm = bmesh.new(); sbm.from_mesh(trunk.data); sbm.faces.ensure_lookup_table()
    seen, isl = set(), []
    for f in sbm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop(); comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index); stack.append(nf)
        isl.append([f.index for f in comp])   # capture indices BEFORE freeing the bmesh
    isl.sort(key=len, reverse=True)
    sbm.free()
    # greedy bin-pack islands by size so the big trunk island doesn't blow one bin
    bins = [[] for _ in range(TRUNK_PARTS)]
    loads = [0] * TRUNK_PARTS
    for comp in isl:
        b = loads.index(min(loads))
        bins[b].extend(comp)
        loads[b] += len(comp)
    trunk_objs = []
    for bi, keep_idx in enumerate(bins):
        nm = bpy.data.meshes.new(f"wood_part{bi}")
        nb = bmesh.new(); nb.from_mesh(trunk.data); nb.faces.ensure_lookup_table()
        ks = set(keep_idx)
        bmesh.ops.delete(nb, geom=[f for f in nb.faces if f.index not in ks], context="FACES")
        nb.to_mesh(nm); nb.free()
        for m in trunk.data.materials:
            nm.materials.append(m)
        nob = bpy.data.objects.new(f"wood_part{bi}", nm)
        bpy.context.scene.collection.objects.link(nob)
        trunk_objs.append(nob)
    bpy.data.objects.remove(trunk, do_unlink=True)
    trunk = trunk_objs[0]
    print("WOOD SPLIT into " + str(TRUNK_PARTS) + " meshes: "
          + ", ".join(str(sum(len(p.vertices)-2 for p in o.data.polygons)) for o in trunk_objs))

if FOLIAGE_PARTS > 1:
    sbm = bmesh.new(); sbm.from_mesh(foliage.data); sbm.faces.ensure_lookup_table()
    seen, cards = set(), []
    for f in sbm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop(); comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index); stack.append(nf)
        cards.append(comp)
    buckets = [[] for _ in range(FOLIAGE_PARTS)]
    for i, comp in enumerate(cards):
        buckets[i % FOLIAGE_PARTS].extend(f.index for f in comp)   # interleave so each
                                                                   # part covers the whole
                                                                   # canopy, not a slab
    sbm.free()
    foliage_objs = []
    for bi, keep_idx in enumerate(buckets):
        nm = bpy.data.meshes.new(f"foliage_part{bi}")
        nb = bmesh.new(); nb.from_mesh(foliage.data); nb.faces.ensure_lookup_table()
        ks = set(keep_idx)
        bmesh.ops.delete(nb, geom=[f for f in nb.faces if f.index not in ks], context="FACES")
        nb.to_mesh(nm); nb.free()
        for m in foliage.data.materials:
            nm.materials.append(m)
        nob = bpy.data.objects.new(f"foliage_part{bi}", nm)
        bpy.context.scene.collection.objects.link(nob)
        foliage_objs.append(nob)
    bpy.data.objects.remove(foliage, do_unlink=True)
    foliage = foliage_objs[0]
    print(f"FOLIAGE SPLIT into {FOLIAGE_PARTS} meshes: "
          + ", ".join(str(sum(len(p.vertices)-2 for p in o.data.polygons)) for o in foliage_objs))

base_name = os.path.splitext(os.path.basename(OUT_FBX))[0]
# FBX-imported objects carry hidden importer state that survives transform_apply: the
# exporter writes them at 0.01, which global_scale multiplies AGAIN (imports 100x small).
# Rehosting the meshes in FRESHLY CREATED objects reliably exports at unit scale.
_fresh = []
for _o in trunk_objs + foliage_objs:
    _n = bpy.data.objects.new(_o.name + "_X", _o.data.copy())
    bpy.context.scene.collection.objects.link(_n)
    _fresh.append(_n)
for _o in trunk_objs + foliage_objs:
    bpy.data.objects.remove(_o, do_unlink=True)
nT = len(trunk_objs)
trunk_objs, foliage_objs = _fresh[:nT], _fresh[nT:]
trunk, foliage = trunk_objs[0], foliage_objs[0]
bpy.context.view_layer.update()
for i, _o in enumerate(trunk_objs):
    _o.name = base_name + ("_Trunk" if len(trunk_objs) == 1 else f"_Trunk{i+1}")
for i, _o in enumerate(foliage_objs):
    _o.name = base_name + ("_Foliage" if len(foliage_objs) == 1 else f"_Foliage{i+1}")
bpy.ops.object.select_all(action="DESELECT")
for _o in trunk_objs + foliage_objs:
    _o.select_set(True)
bpy.context.view_layer.objects.active = trunk

bpy.ops.export_scene.fbx(
    filepath=OUT_FBX,
    use_selection=True,
    path_mode="COPY",
    embed_textures=True,
    global_scale=0.01,  # Blender exports cm; Roblox reads 1 unit = 1 stud
)
print("WROTE", OUT_FBX)
