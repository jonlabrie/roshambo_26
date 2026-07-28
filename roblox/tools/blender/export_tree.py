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
#     CAVEAT (2026-07-26): DoubleSided also enables Roblox's quality-gated foliage
#     TRANSMISSION shading — sun/moon behind the canopy glows through the ColorMap.
#     Great on dense/dark foliage (sugi needles); on PALE foliage it blows out white
#     (the sakura incident — transmission ignores SurfaceAppearance.Color tint, and
#     the only effective off-switch is DoubleSided=false). Dense/dark: use TRUE.
#     Pale/pastel: leave FALSE.
#
# (original note) File -> Import 3D (NOT "as package"); then set the foliage MeshPart's
# SurfaceAppearance.AlphaMode = Transparency.

import bpy, bmesh, sys, math, os, glob, functools
import numpy as np
import mathutils

print = functools.partial(print, flush=True)

argv = sys.argv[sys.argv.index("--") + 1:]
FBX, OBJ, FOLIAGE_KEY = argv[0], argv[1], argv[2]
# comma-separated keys: XfrogPlants names its canopy materials inconsistently
# (hinoki splits Leaf + Needle; Yoshino cherry uses Flower1/FLower1/Flower2;
# Kanzan cherry uses Blossom AND Flower), so one key cannot cover the library.
# Matching is case-insensitive substring. SAFE DEFAULT for the whole library:
#   "needle,leaf,flower,blossom,frond"
# An unmatched canopy material is silently dropped, so always pass the full list.
FOLIAGE_KEYS = [k.strip().lower() for k in FOLIAGE_KEY.split(",") if k.strip()]
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
#   0 = cull to the big islands, then decimate (sources with thick modelled twigs)
#   1 = SMART WOOD: decimate the main island, keep whole twigs to budget (sources
#       whose twigs are tiny slivers that decimation would shred — the sugi)
#   2 = keep EVERY island and decimate them all uniformly. DON'T USE on sources
#       with a smooth bole: a global decimate robs the trunk cylinder to pay for
#       hundreds of little branch tubes and the trunk disappears entirely.
#   3 = PROPORTIONAL: split the main island (the bole) from the branch islands and
#       decimate each with its OWN budget, so they never compete. The right mode
#       for the XfrogPlants libraries.
TRUNK_KEEP_ALL = (len(argv) > 9 and argv[9] in ("1", "2", "3"))
TRUNK_UNIFORM = (len(argv) > 9 and argv[9] == "2")
TRUNK_PROPORTIONAL = (len(argv) > 9 and argv[9] == "3")
# share of the wood budget reserved for the bole in mode 3
BOLE_SHARE = 0.35
# ...and for the root flare, which gets its own line item so the branch geometry
# cannot set its decimation ratio (see the three-way split below)
# 0.05, not 0.15: judged side by side at 1.5 studs, a 500-tri flare and a 1,500-tri
# one are indistinguishable ("I'd say they were identical if you didn't tell me
# otherwise"), and PlantDepth buries the lower half of it anyway. Saves ~1,000 tris
# per canopy tree. Raise it for a hero tree standing alone beside a path.
ROOT_SHARE = 0.05
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
# Optional 15th arg: SKIRT — delete foliage cards whose centre sits below this
# FRACTION of the tree's height. XfrogPlants models open-grown specimens that are
# foliated to the ground, so a forest of them has no clear trunk band and the
# player is permanently walking face-first into needles. Real stand-grown trees
# self-prune their lower branches; this reproduces that, and removes triangles
# rather than adding them. 0 = keep the full skirt (right for brush/understory).
SKIRT = float(argv[14]) if len(argv) > 14 else 0.0
MIN_ISLAND, MAX_TRUNK_ISLANDS = 200, 10

# ROOT FLARE PROTECTION. XfrogPlants models the buttresses at the trunk base as
# their own islands, separate from the bole and entirely below the skirt line, so
# BOTH island-culling rules destroyed every one of them and left a bare dowel
# stuck in the ground (measured: base-width/height fell from ~0.16 to ~0.04):
#   - SELF-PRUNE deleted them for dipping below the skirt (the trimmed A/M models)
#   - FLOATING WOOD deleted them once a small wood budget shrank the bole enough
#     to break contact, which is why the brush models lost theirs at SKIRT=0 too
# Identifying them needs BOTH tests. A top-height test alone also keeps 41-68 low
# branch stubs per tree; a starts-at-the-ground test alone keeps low limbs that
# sweep down to the soil. Measured on the conifer trunks: islands that start at
# the ground top out at 0.10-0.14 of tree height, real stubs at 0.15+.
ROOT_BASE_MAX = 0.05   # island must start within this fraction of height of the base
ROOT_TOP_MAX = 0.18    # ...and stay entirely below this fraction


def is_root_island(comp, z_lo, z_span):
    """True for the basal buttress islands that both rules must leave alone."""
    if z_span <= 0:
        return False
    czs = [v.co.z for c in comp for v in c.verts]
    return ((min(czs) - z_lo) < ROOT_BASE_MAX * z_span
            and (max(czs) - z_lo) < ROOT_TOP_MAX * z_span)

bpy.ops.wm.read_factory_settings(use_empty=True)
# source may be .fbx (TurboSquid game packs) or .obj (XfrogPlants libraries)
if FBX.lower().endswith(".obj"):
    # XfrogPlants OBJs are Z-UP (tallest extent is Z, base sits on Z=0), but the
    # importer assumes Y-up by default and would lay every tree on its side.
    try:
        bpy.ops.wm.obj_import(filepath=FBX, forward_axis="Y", up_axis="Z")
    except AttributeError:  # Blender < 3.3
        bpy.ops.import_scene.obj(filepath=FBX, axis_forward="Y", axis_up="Z")
else:
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
if max(tree.dimensions) > 2000:
    # everything is rescaled to HEIGHT_STUDS below; this only catches a source
    # authored in the wrong unit entirely (mm, or cm read as m).
    raise SystemExit(f"ABORT: {max(tree.dimensions):.0f} units after apply — unexpected source scale")

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")

fol_objs, trunk = [], None
for o in list(bpy.data.objects):
    if any(m and any(k in m.name.lower() for k in FOLIAGE_KEYS) for m in o.data.materials):
        fol_objs.append(o)
    elif trunk is None:
        trunk = o
    else:
        bpy.ops.object.select_all(action="DESELECT")
        trunk.select_set(True)
        o.select_set(True)
        bpy.context.view_layer.objects.active = trunk
        bpy.ops.object.join()
# a source may split its canopy across several materials (Needle1/Needle2/...);
# join them all or the extras vanish from the export
foliage = fol_objs[0] if fol_objs else None
if len(fol_objs) > 1:
    bpy.ops.object.select_all(action="DESELECT")
    for o in fol_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = foliage
    bpy.ops.object.join()
    print(f"FOLIAGE: joined {len(fol_objs)} foliage materials into one mesh")
if foliage is None or trunk is None:
    raise SystemExit(f"ABORT: could not split trunk/foliage on key {FOLIAGE_KEY!r}")
foliage_objs = [foliage]   # becomes N meshes if FOLIAGE_PARTS > 1 (see the split below)
trunk_objs = [trunk]       # becomes N meshes if TRUNK_PARTS > 1


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# Roblox renders a MeshPart at full detail only up to 20,000 triangles; above
# that it silently decimates ("exceeds 20K, will be decimated upon rendering").
# Budgets land a few triangles over surprisingly easily (40,000 foliage split two
# ways = 20,046 each), so trim whole cards off any part that crosses the line.
ROBLOX_MESH_CAP = 19900


def trim_to_cap(ob, cap=ROBLOX_MESH_CAP):
    n = tri_count(ob)
    if n <= cap:
        return n
    tb = bmesh.new()
    tb.from_mesh(ob.data)
    tb.faces.ensure_lookup_table()
    seen, comps = set(), []
    for f in tb.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            comp.append(cur.index)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seen:
                        seen.add(nf.index)
                        stack.append(nf)
        comps.append(comp)
    doomed, over = set(), n - cap
    for comp in comps:                      # drop whole islands, smallest impact first
        if over <= 0:
            break
        doomed.update(comp)
        over -= len(comp)
    bmesh.ops.delete(tb, geom=[f for f in tb.faces if f.index in doomed], context="FACES")
    tb.to_mesh(ob.data)
    tb.free()
    print(f"CAP {ob.name}: {n} -> {tri_count(ob)} tris (Roblox decimates above 20k)")
    return tri_count(ob)


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

# SELF-PRUNING: if the canopy skirt is being trimmed, the BRANCHES that carried
# it must go too, or the tree keeps a fringe of bare dead limbs below the foliage.
# The main bole island is always kept.
if SKIRT > 0.0:
    sb = bmesh.new()
    sb.from_mesh(trunk.data)
    sb.faces.ensure_lookup_table()
    seenS, islS = set(), []
    for f in sb.faces:
        if f.index in seenS:
            continue
        stack, comp = [f], []
        seenS.add(f.index)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seenS:
                        seenS.add(nf.index)
                        stack.append(nf)
        islS.append(comp)
    islS.sort(key=len, reverse=True)
    zsS = [v.co.z for f in sb.faces for v in f.verts]
    if zsS:
        cutS = min(zsS) + SKIRT * (max(zsS) - min(zsS))
        prunable = islS[1:]  # never the bole
        spanS = max(zsS) - min(zsS)
        doomedS, pruned, rootsS = [], 0, 0
        for comp in prunable:
            # the root flare lives entirely below the skirt line, so the strict
            # rule below would delete all of it — see ROOT_BASE_MAX above
            if is_root_island(comp, min(zsS), spanS):
                rootsS += 1
                continue
            # STRICT: prune any limb that intrudes below the skirt line at all.
            # Centre- or tip-based rules leave bare wood hanging in the cleared
            # band, and a spike floating at the player's eyeline wrecks a tree
            # that otherwise reads beautifully. Dead wood is fine; dead wood
            # suspended in mid-air is not.
            if min(v.co.z for c in comp for v in c.verts) < cutS:
                doomedS.extend(comp)
                pruned += 1
        if doomedS:
            bmesh.ops.delete(sb, geom=doomedS, context="FACES")
        print(f"SELF-PRUNE: dropped {pruned} branch islands below the skirt, "
              f"kept {rootsS} root-flare islands")
    sb.to_mesh(trunk.data)
    sb.free()
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = trunk
if TRUNK_PROPORTIONAL and TRUNK_TRIS > 0:
    pb = bmesh.new(); pb.from_mesh(trunk.data); pb.faces.ensure_lookup_table()
    seen, isl = set(), []
    for f in pb.faces:
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
        isl.append(comp)
    isl.sort(key=len, reverse=True)
    main = set(f.index for f in isl[0])
    # THREE-WAY SPLIT, not two. Surviving the island culls is not enough: the root
    # buttresses used to land in the branch mesh and be decimated with it, and on a
    # source with heavy branch geometry (the fir: 18,460-face bole, ~870 branch
    # islands) the ratio is severe enough to collapse a 25-face buttress to a
    # sliver. That is why the fir still exported a bare stick with the culls fixed.
    # The whole flare is ~300 faces, so exempting it from decimation costs nothing.
    zsP = [v.co.z for f in pb.faces for v in f.verts]
    zP_lo, zP_span = (min(zsP), max(zsP) - min(zsP)) if zsP else (0.0, 0.0)
    roots, nroot = set(), 0
    for comp in isl[1:]:
        if is_root_island(comp, zP_lo, zP_span):
            roots.update(f.index for f in comp)
            nroot += 1
    pb.free()

    def carve(keep_pred, name):
        """copy of trunk.data holding only the faces keep_pred accepts"""
        me = bpy.data.meshes.new(name)
        b = bmesh.new(); b.from_mesh(trunk.data); b.faces.ensure_lookup_table()
        bmesh.ops.delete(b, geom=[f for f in b.faces if not keep_pred(f.index)],
                         context="FACES")
        b.to_mesh(me); b.free()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        for m in trunk.data.materials:
            me.materials.append(m)
        return ob

    br = carve(lambda i: i not in main and i not in roots, "branches")
    rt = carve(lambda i: i in roots, "rootflare") if roots else None
    # bole stays on `trunk`
    bm_b = bmesh.new(); bm_b.from_mesh(trunk.data); bm_b.faces.ensure_lookup_table()
    bmesh.ops.delete(bm_b, geom=[f for f in bm_b.faces if f.index not in main], context="FACES")
    bm_b.to_mesh(trunk.data); bm_b.free()

    # The flare needs its OWN budget, not exemption: at full detail it is 5-6k tris,
    # which on a 4-stud brush model with a 900-tri wood budget is absurd. Sharing the
    # branch budget is what destroyed it, because the branch ratio is set by geometry
    # the flare has nothing to do with. Its own line item keeps the silhouette at a
    # fraction of the cost.
    # The root budget is ADDITIVE, not a slice of TRUNK_TRIS. Taking it out of the
    # branch allocation cost the sugi 2,700 branch tris, and because its 38,780
    # cards hang on fine twigs, starving the twigs stranded the cards and the
    # orphan/bare-limb culls then deleted them — canopy fell from 21.5k tris to
    # 12k. The flare is ~1.5-2.7k on a fixed schedule; the canopy is what the
    # player actually sees.
    bole_budget = max(600, int(TRUNK_TRIS * BOLE_SHARE))
    root_budget = max(250, int(TRUNK_TRIS * ROOT_SHARE))
    branch_budget = max(200, TRUNK_TRIS - bole_budget)
    for ob, budget in ((trunk, bole_budget), (br, branch_budget),
                       (rt, root_budget) if rt else (None, 0)):
        if ob is not None and budget < tri_count(ob) and tri_count(ob) > 0:
            bpy.context.view_layer.objects.active = ob
            d = ob.modifiers.new("dec", "DECIMATE")
            d.ratio = min(1.0, budget / max(tri_count(ob), 1))
            bpy.ops.object.modifier_apply(modifier=d.name)
    print(f"PROPORTIONAL WOOD: bole {tri_count(trunk)} tris, branches {tri_count(br)} tris"
          f" ({len(isl) - 1} branch islands kept), root flare {tri_count(rt) if rt else 0}"
          f" tris from {nroot} islands")
    bpy.ops.object.select_all(action="DESELECT")
    trunk.select_set(True); br.select_set(True)
    if rt:
        rt.select_set(True)
    bpy.context.view_layer.objects.active = trunk
    bpy.ops.object.join()
elif TRUNK_UNIFORM and TRUNK_TRIS > 0:
    dec = trunk.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, TRUNK_TRIS / max(tri_count(trunk), 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    print(f"UNIFORM WOOD: all islands kept, decimated to {tri_count(trunk)} tris")
elif TRUNK_KEEP_ALL and TRUNK_TRIS > 0:
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

# FLOATING-WOOD CULL. Xfrog models every branch as its own unwelded island that
# merely TOUCHES the trunk surface. Decimation shrinks the bole a little, so those
# inner ends end up starting in mid-air — bare limbs hanging in space, which is
# exactly what wrecks an otherwise good tree at the player's eyeline. Drop any
# wood island that no longer reaches other wood.
if True:
    wb = bmesh.new()
    wb.from_mesh(trunk.data)
    wb.verts.ensure_lookup_table()
    wb.faces.ensure_lookup_table()
    seenW, islW = set(), []
    for f in wb.faces:
        if f.index in seenW:
            continue
        stack, comp = [f], []
        seenW.add(f.index)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf.index not in seenW:
                        seenW.add(nf.index)
                        stack.append(nf)
        islW.append(comp)
    islW.sort(key=len, reverse=True)
    if len(islW) > 1:
        zsW = [v.co.z for v in wb.verts]
        # Tolerance for "this limb touches that one". Too tight and real branch
        # junctions read as breaks, so reachability-from-the-bole strands whole
        # healthy limbs (0.006 cost 663 of them and left the tree gaunt). Genuine
        # floaters sit well clear, so a generous value still catches them.
        reach = 0.012 * (max(zsW) - min(zsW))
        cellW = max(reach, 1e-4)
        # bucket every vertex with the island it belongs to, so an island can be
        # tested against OTHER wood only (twigs legitimately hang off big limbs)
        gridW = {}
        for idx, comp in enumerate(islW):
            for c in comp:
                for v in c.verts:
                    k = (int(v.co.x // cellW), int(v.co.y // cellW), int(v.co.z // cellW))
                    gridW.setdefault(k, []).append((idx, v.co.copy()))

        # Build island adjacency once, then keep only what is REACHABLE FROM THE
        # BOLE. Testing "touches any other island" is not enough: a cluster of
        # adrift limbs touching each other passes it while anchored to nothing,
        # which leaves outliers hanging far off the centreline.
        adj = {i: set() for i in range(len(islW))}
        for idx, comp in enumerate(islW):
            for c in comp:
                for v in c.verts:
                    k = (int(v.co.x // cellW), int(v.co.y // cellW), int(v.co.z // cellW))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            for dz in (-1, 0, 1):
                                for oidx, ov in gridW.get((k[0] + dx, k[1] + dy, k[2] + dz), ()):
                                    if oidx != idx and (ov - v.co).length <= reach:
                                        adj[idx].add(oidx)
                                        adj[oidx].add(idx)
        reachable, queue = {0}, [0]          # island 0 is the bole
        while queue:
            cur = queue.pop()
            for nb in adj[cur]:
                if nb not in reachable:
                    reachable.add(nb)
                    queue.append(nb)

        # Debris: decimation leaves 3-face slivers that pass every connectivity
        # and foliage test because they ARE attached and DO sit near cards — yet
        # they read as chips of wood hanging in the air, and they cluster around
        # the skirt line where the eye is. Nothing that small is a branch.
        # 0 = keep them. Tried 8: it removed 1,582 slivers and stranded 2,122
        # cards, gutting the canopy — those fragments are the twig tips the
        # needles hang on, i.e. load-bearing, not debris. Left as a knob because
        # a source with genuinely detached chips would want it.
        MIN_LIMB_FACES = 0
        spanW = max(zsW) - min(zsW)
        doomedW, floated, debris, rootsW = [], 0, 0, 0
        for idx in range(1, len(islW)):
            # a small wood budget decimates the bole until the root buttresses no
            # longer touch it; without this they read as "adrift" and are culled,
            # which is how the SKIRT=0 brush models still lost their flares
            if is_root_island(islW[idx], min(zsW), spanW):
                rootsW += 1
                continue
            if idx not in reachable:
                doomedW.extend(islW[idx])
                floated += 1
            elif len(islW[idx]) < MIN_LIMB_FACES:
                doomedW.extend(islW[idx])
                debris += 1
        print(f"DEBRIS: dropped {debris} slivers under {MIN_LIMB_FACES} faces")
        if doomedW:
            bmesh.ops.delete(wb, geom=doomedW, context="FACES")
        print(f"FLOATING WOOD: dropped {floated} limbs not reaching other wood, "
              f"kept {rootsW} root-flare islands")
    wb.to_mesh(trunk.data)
    wb.free()

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
if SKIRT > 0.0:
    bm.faces.ensure_lookup_table()
    zs = [v.co.z for f in bm.faces for v in f.verts]
    if zs:
        z_lo, z_hi = min(zs), max(zs)
        # the trunk defines the tree's height; foliage may not reach the base
        t_lo = min((v.co.z for v in trunk.data.vertices), default=z_lo)
        t_hi = max((v.co.z for v in trunk.data.vertices), default=z_hi)
        cut = t_lo + SKIRT * (t_hi - t_lo)
        seen3, doomed3, kept3 = set(), [], 0
        for f in bm.faces:
            if f.index in seen3:
                continue
            stack, comp = [f], []
            seen3.add(f.index)
            while stack:
                cur = stack.pop()
                comp.append(cur)
                for e in cur.edges:
                    for nf in e.link_faces:
                        if nf.index not in seen3:
                            seen3.add(nf.index)
                            stack.append(nf)
            centre = sum(v.co.z for c in comp for v in c.verts) / max(
                sum(len(c.verts) for c in comp), 1
            )
            if centre < cut:
                doomed3.extend(comp)
            else:
                kept3 += 1
        if doomed3:
            bmesh.ops.delete(bm, geom=doomed3, context="FACES")
        print(f"SKIRT {SKIRT}: bare to {cut - t_lo:.1f} units, {kept3} cards kept")

if SKIRT > 0.0 and TRUNK_PTS:
    # ORPHAN CULL. Branch pruning is strict (any limb dipping below the skirt
    # goes) but card removal is centre-based, so cards carried by a pruned limb
    # can survive with no wood beneath them — foliage hanging in mid-air, which
    # reads far worse than an untrimmed tree. Drop any card left stranded from
    # surviving wood. Trunk points are bucketed; a brute-force scan is
    # cards x trunk-verts and takes minutes.
    bm.faces.ensure_lookup_table()
    _z = [v.co.z for f in bm.faces for v in f.verts]
    _reach = 0.04 * (max(_z) - min(_z)) if _z else 0.0
    if _reach > 0:
        _cell = _reach
        _grid = {}
        for _tp in TRUNK_PTS:
            _k = (int(_tp.x // _cell), int(_tp.y // _cell), int(_tp.z // _cell))
            _grid.setdefault(_k, []).append(_tp)

        def _stranded(pt):
            _k = (int(pt.x // _cell), int(pt.y // _cell), int(pt.z // _cell))
            for _dx in (-1, 0, 1):
                for _dy in (-1, 0, 1):
                    for _dz in (-1, 0, 1):
                        for _tp in _grid.get((_k[0] + _dx, _k[1] + _dy, _k[2] + _dz), ()):
                            if (_tp - pt).length <= _reach:
                                return False
            return True

        seen4, doomed4, culled4 = set(), [], 0
        for f in bm.faces:
            if f.index in seen4:
                continue
            stack, comp = [f], []
            seen4.add(f.index)
            while stack:
                cur = stack.pop()
                comp.append(cur)
                for e in cur.edges:
                    for nf in e.link_faces:
                        if nf.index not in seen4:
                            seen4.add(nf.index)
                            stack.append(nf)
            vs = [v.co for c in comp for v in c.verts]
            anchor_pt = min(vs, key=lambda c: c.z)   # the card's attachment end
            if _stranded(anchor_pt):
                doomed4.extend(comp)
                culled4 += 1
        if doomed4:
            bmesh.ops.delete(bm, geom=doomed4, context="FACES")
        print(f"ORPHAN CULL: dropped {culled4} cards stranded from surviving wood")

# BARE-LIMB CULL (must run AFTER the card trim + orphan cull, since it depends
# on which foliage actually survived). A limb still anchored to the tree but
# stripped of every card reads as a spike jutting into open air — the "outliers
# far out from the trunk" that survive every connectivity test because they are,
# in fact, connected. Above the skirt, wood without foliage is not wanted.
if SKIRT > 0.0:
    fol_pts = [v.co.copy() for v in foliage.data.vertices]
    if fol_pts:
        lb = bmesh.new()
        lb.from_mesh(trunk.data)
        lb.faces.ensure_lookup_table()
        seenB, islB = set(), []
        for f in lb.faces:
            if f.index in seenB:
                continue
            stack, comp = [f], []
            seenB.add(f.index)
            while stack:
                cur = stack.pop()
                comp.append(cur)
                for e in cur.edges:
                    for nf in e.link_faces:
                        if nf.index not in seenB:
                            seenB.add(nf.index)
                            stack.append(nf)
            islB.append(comp)
        islB.sort(key=len, reverse=True)
        zsB = [v.co.z for f in lb.faces for v in f.verts]
        span = max(zsB) - min(zsB)
        near = 0.05 * span
        cellB = near
        gridB = {}
        for fp in fol_pts:
            k = (int(fp.x // cellB), int(fp.y // cellB), int(fp.z // cellB))
            gridB.setdefault(k, []).append(fp)

        def has_foliage(comp):
            for c in comp:
                for v in c.verts:
                    k = (int(v.co.x // cellB), int(v.co.y // cellB), int(v.co.z // cellB))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            for dz in (-1, 0, 1):
                                for fp in gridB.get((k[0] + dx, k[1] + dy, k[2] + dz), ()):
                                    if (fp - v.co).length <= near:
                                        return True
            return False

        doomedB, bare_n, rootsB = [], 0, 0
        zB_lo = min(zsB)
        for idx in range(1, len(islB)):
            # the root flare carries no cards BY DEFINITION, so this rule deletes
            # all of it — the last of the three culls that had to learn about it
            if is_root_island(islB[idx], zB_lo, span):
                rootsB += 1
                continue
            if not has_foliage(islB[idx]):
                doomedB.extend(islB[idx])
                bare_n += 1
        if doomedB:
            bmesh.ops.delete(lb, geom=doomedB, context="FACES")
        print(f"BARE LIMBS: dropped {bare_n} limbs left with no foliage, "
              f"kept {rootsB} root-flare islands")
        lb.to_mesh(trunk.data)
        lb.free()

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
                  if "opa" in k and FOLIAGE_KEYS[0].split("_")[0] in k), None)
if opac_path is None:
    opac_path = next((v for k, v in tex_by_name.items() if "opa" in k), None)
if opac_path is None and diff_node is not None and diff_node.image:
    # XfrogPlants convention: diffuse JA05ned.tif -> alpha JA05ned_a.tif
    _stem, _ext = os.path.splitext(os.path.basename(diff_node.image.filepath))
    opac_path = tex_by_name.get((_stem + "_a" + _ext).lower())
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
    mask = opac.reshape(-1, 4)[:, 0]
    lum = rgba[:, :3].mean(axis=1)
    bg, leaf = lum < 0.08, lum > 0.12
    if bg.any() and leaf.any() and mask[bg].mean() > mask[leaf].mean():
        # inverted matte (white = transparent) — the XfrogPlants convention
        mask = 1.0 - mask
        print("ALPHA: inverted matte detected (white = background), flipping")
    rgba[:, 3] = mask
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

for _o in trunk_objs + foliage_objs:
    trim_to_cap(_o)

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

# ROBLOX TEXTURE FORMATS: the importer accepts PNG/JPG/TGA/BMP and REJECTS TIFF
# ("unsupported format") — XfrogPlants ships every bark map as .tif, so re-save
# anything exotic as PNG next to the output and repoint the material at it.
for _o in trunk_objs + foliage_objs:
    for _m in _o.data.materials:
        if not (_m and _m.use_nodes):
            continue
        for _n in _m.node_tree.nodes:
            if _n.type != "TEX_IMAGE" or not _n.image:
                continue
            _ext = os.path.splitext(_n.image.filepath)[1].lower()
            if _ext in (".png", ".jpg", ".jpeg", ".tga", ".bmp"):
                continue
            _stem = os.path.splitext(os.path.basename(_n.image.filepath))[0]
            _png = os.path.join(out_dir, _stem + ".png")
            # the datablock is lazily loaded and usually has no pixels to save, so
            # re-load the file from disk before converting
            _src = bpy.path.abspath(_n.image.filepath)
            if not os.path.exists(_src):
                _src = tex_by_name.get(os.path.basename(_n.image.filepath).lower(), _src)
            if not os.path.exists(_src):
                print(f"WARN cannot find {_stem}{_ext} to convert — trunk may fail to import")
                continue
            # Blender will not decode these TIFFs in background mode ("does not
            # have any image data"), so convert with the OS tool and load the PNG.
            _ok = False
            try:
                import subprocess

                subprocess.run(
                    ["sips", "-s", "format", "png", _src, "--out", _png],
                    check=True, capture_output=True,
                )
                _ok = os.path.exists(_png)
            except Exception as _exc:  # not macOS, or sips missing
                print(f"WARN sips conversion failed for {_stem}{_ext}: {_exc}")
            if not _ok:
                try:
                    _fresh = bpy.data.images.load(_src)
                    _ = _fresh.pixels[0]  # force the lazy load
                    _fresh.filepath_raw = _png
                    _fresh.file_format = "PNG"
                    _fresh.save()
                    _ok = True
                except Exception as _exc:
                    print(f"WARN could not convert {_stem}{_ext}: {_exc}")
            if not _ok:
                continue
            _n.image = bpy.data.images.load(_png)
            print(f"TEXCONV {_stem}{_ext} -> PNG (Roblox rejects TIFF)")

bpy.ops.export_scene.fbx(
    filepath=OUT_FBX,
    use_selection=True,
    path_mode="COPY",
    embed_textures=True,
    global_scale=0.01,  # Blender exports cm; Roblox reads 1 unit = 1 stud
)
print("WROTE", OUT_FBX)
