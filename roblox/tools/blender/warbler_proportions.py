"""Proportion sets for the warbler body plan -- the uguisu's mesh, reshaped per species.

⚠ ONE RETARGET, FOUR PROPORTION SETS. docs/wiki/world/ambient-birds.md chose four perching birds
-- yamagara, mejiro, hiyodori, sekirei -- on the grounds that they are ONE body plan and therefore
one retarget with four proportion sets, "not four efforts". The mejiro was the degenerate case
(proportions identical, size only) and shipped as a pure scale. The hiyodori is the first that
actually needs a set.

⚠ THIS IS NOT A SUBSTITUTE FOR SCULPTING, IT IS A SUBSTITUTE FOR RESIZING IN STUDIO. A MeshPart
resized in Studio keeps unscaled pivot data and needs a per-bird seat correction; see
practice/blender-pipeline.md. Everything here produces a bird at its own native size.

⚠ THE ARMATURE TAKES THE SAME WARP AS THE MESHES, and it must, or the bind pose no longer matches
the geometry and the bird deforms around bones that are no longer inside it. A uniform scale can go
through `arm.data.transform()`; the tail ramp cannot, because it is not a matrix -- it is a
piecewise y-warp, so the edit bones are moved point by point through the same function.

Run inside Blender on art/birds/uguisu/uguisu_authored.blend, then:  build("hiyodori")
"""

import bpy
import math
from mathutils import Matrix, Vector

SCRATCH_DIR = "/private/tmp/claude-501/-Users-jonlabrie-Desktop-ClaudeCode-Roshambo-26/9d213590-78cd-432b-8bd7-bf72af27ff65/scratchpad/"
OUT_DIR = "/Users/jonlabrie/Desktop/Roshambo Reference/models/birds/probe/"
AUTHORED = "/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/art/birds/uguisu/uguisu_authored.blend"

# ⚠ MEASURED OFF THE GIRTH PROFILE, NOT GUESSED. The body's height collapses from 0.347 to 0.187
# between y = -0.115 and -0.157, so the body/tail transition sits in there. The ramp spans it
# rather than cutting at one station: a hard cut leaves a 10% step in the dorsal line that reads
# as a HUNCH ON THE BIRD'S BACK -- which is exactly what the owner caught on the first attempt.
RAMP = (-0.10, -0.25)

# ⚠ `section` SCALES x AND z ON EVERY VERTEX, ungated. The first version gated it on y > ramp
# start, which is a step, and a step in the dorsal line is the hunch above. A uniform cross-section
# scale cannot produce a seam at all.
SPECIES = {
    # tail: elongation of everything behind the ramp. section: cross-section. length: nose-to-tail.
    "uguisu": {"tail": 1.00, "section": 1.00, "length": 0.828},
    "mejiro": {"tail": 1.00, "section": 1.00, "length": 0.640},
    # owner-approved 2026-08-31 from side-by-side ladders: tail from T_130, section from N_both,
    # size from S_115. A hiyodori is 0.92 studs life-size; this ships at 1.25x, between the
    # karasu's 1x and the uguisu/mejiro's ~1.75x.
    "hiyodori": {"tail": 1.30, "section": 0.90, "length": 1.15},
}

RIG = "Uguisu_Rig"
BODY, WINGS = "UguisuBody", "UguisuWings"


def _smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def warp(co, spec):
    """The proportion set as a pure point map. Meshes and BONES both go through this one function,
    which is the only way the two can be guaranteed to agree."""
    y0, y1 = RAMP
    y = co.y
    if y < y0 and spec["tail"] != 1.0:
        y = y0 + (y - y0) * (1 + (spec["tail"] - 1) * _smoothstep(y0, y1, co.y))
    s = spec["section"]
    return Vector((co.x * s, y, co.z * s))


def _bound(objs):
    ys = [v.co.y for o in objs for v in o.data.vertices]
    return max(ys) - min(ys)


def build(species, export_fn=None):
    """`export_fn` is karasu_retarget.export, passed in rather than imported.

    ⚠ THE MCP EXECS A SCRIPT, IT DOES NOT IMPORT IT (practice/blender-pipeline.md), so `import
    karasu_retarget` fails in the only context this ever runs in. Passing the function in also
    keeps the one hard-won set of FBX flags in one file."""
    spec = SPECIES[species]
    name = species.capitalize()
    # ⚠ SAVE-AS IS THE GUARD, NOT THE PRODUCT. It switches the session off the authored blend so
    # nothing below can reach it -- stronger than remembering not to save. The file on disk is
    # therefore the PRE-warp state; the finished bird exists only in memory and in the FBXs.
    bpy.ops.wm.save_as_mainfile(filepath=SCRATCH_DIR + "%s_export.blend" % species, copy=False)

    rig = bpy.data.objects[RIG]
    meshes = [o for o in bpy.data.objects
              if o.type == 'MESH' and any(m.type == 'ARMATURE' and m.object == rig
                                          for m in o.modifiers)]
    for o in meshes:
        for v in o.data.vertices:
            v.co = warp(v.co, spec)

    # the armature, through the SAME function
    prev_active = bpy.context.view_layer.objects.active
    bpy.context.view_layer.objects.active = rig
    win = bpy.context.window_manager.windows[0]
    scr = win.screen
    area = next((a for a in scr.areas if a.type == 'VIEW_3D'), scr.areas[0])
    with bpy.context.temp_override(window=win, screen=scr, area=area,
                                   region=area.regions[-1], scene=bpy.context.scene,
                                   view_layer=bpy.context.view_layer):
        bpy.ops.object.mode_set(mode='EDIT')
        for eb in rig.data.edit_bones:
            eb.head = warp(eb.head, spec)
            eb.tail = warp(eb.tail, spec)
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.objects.active = prev_active

    # ⚠ SIZE LAST, so every proportion above stays in one readable coordinate system and only this
    # number carries real-world size. Same discipline as karasu_retarget.normalise_size().
    body = bpy.data.objects[BODY]
    S = spec["length"] / _bound([body])
    M = Matrix.Scale(S, 4)
    for o in meshes:
        o.data.transform(M)
    rig.data.transform(M)
    bpy.context.view_layer.update()

    for old, new in ((BODY, name + "Body"), (WINGS, name + "Wings"), (RIG, name + "_Rig")):
        if old in bpy.data.objects:
            bpy.data.objects[old].name = new

    report = {"species": species, "scale_last": round(S, 6),
              "length": round(_bound([bpy.data.objects[name + "Body"]]), 5),
              "bones": len(bpy.data.objects[name + "_Rig"].data.bones)}
    if export_fn:
        report["files"] = []
        for part in (name + "Body", name + "Wings"):
            path = OUT_DIR + part + ".fbx"
            # ⚠ textures=False: these meshes are shared between species and an FBX carrying one
            # bird's colormap is a trap that has already shipped once.
            export_fn(part, path, textures=False)
            report["files"].append(path)
    return report
