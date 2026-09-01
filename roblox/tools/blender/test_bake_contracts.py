#!/usr/bin/env python3
"""Contract tests between the bird palettes and the shaders that read them.

⚠ WHY THIS IS NOT A UNIT TEST OF THE SHADING. Nothing here asserts what a bird looks like -- that
is the owner's eye, and no assertion substitutes for it. What this catches is the class of defect
that IS mechanical: a palette missing a key its shader reads, a species naming a shader that does
not exist, or a landmark constant that has drifted out of the relationship another constant
assumes. Those fail at BAKE time, deep inside numpy, on whichever bird you happened to be
working on -- which is a bad place to learn about a typo.

⚠ IT RUNS THE REAL SHADERS. Parsing the source for `C["..."]` would be guessing; calling each
shader with its own palette over points chosen to reach every branch means a missing key raises
the same KeyError it would raise in a real bake. The points below are not arbitrary -- see
`_probe_points`.

Runs WITHOUT Blender: the shaders are pure numpy, so `bpy` is stubbed. Run it with
`python3 roblox/tools/blender/test_bake_contracts.py`.
"""
import sys
import types
import importlib.util
import os

for _m in ("bpy", "bmesh", "bpy_extras"):
    sys.modules.setdefault(_m, types.ModuleType(_m))
if "mathutils" not in sys.modules:
    _mu = types.ModuleType("mathutils")
    _mu.Vector = object
    _mu.Matrix = object
    sys.modules["mathutils"] = _mu

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "bake_bird_texture", os.path.join(_HERE, "bake_bird_texture.py"))
bbt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bbt)

FAILS = []


def check(name, fn):
    try:
        fn()
        print(f"  PASS  {name}")
    except Exception as e:
        FAILS.append((name, f"{type(e).__name__}: {e}"))
        print(f"  FAIL  {name}\n          {type(e).__name__}: {e}")


def _probe_points():
    """Points chosen to REACH EVERY BRANCH, not to sample evenly.

    ⚠ A KEY READ INSIDE A CONDITIONAL IS ONLY CHECKED IF THE CONDITION IS TRUE. `shade` looks up
    `eyeline` and `supercilium` inside `if head.any()`, so a probe set with nothing in the head
    band 0.082 < y < 0.168 would pass while the palette was missing both. Stations below cover
    tail, body, head and bill, with normals spanning up and down so the countershading blend
    reaches its dorsal and ventral limits.
    """
    ys = [-0.25, -0.10, 0.02, 0.12, 0.13, 0.16, 0.20]
    pts, nrm = [], []
    for y in ys:
        for z in (0.05, 0.20, 0.266, 0.30):
            for nz in (-1.0, 1.0):
                pts.append((0.03, y, z))
                nrm.append((0.0, 0.0, nz))
    return np.array(pts, dtype=float), np.array(nrm, dtype=float)


P, N = _probe_points()


def test_species_entries_are_complete():
    for name, sp in bbt.SPECIES.items():
        assert "palette" in sp, f"{name} has no palette"
        assert "shader" in sp, f"{name} has no shader"
        assert sp["shader"] in bbt.SHADERS, f"{name} names shader {sp['shader']!r}, which does not exist"
        assert isinstance(sp.get("ref_length"), (int, float)) and sp["ref_length"] > 0, \
            f"{name} has no positive ref_length -- landmarks cannot be rescaled without it"


def test_every_palette_satisfies_its_shader():
    """The whole point of the file: run each species' shader over its own palette."""
    for name, sp in bbt.SPECIES.items():
        shader = bbt.SHADERS[sp["shader"]]
        out = shader(P.copy(), N.copy(), sp["palette"], 1.0, sp.get("landmarks"))
        assert out.shape == (len(P), 3), f"{name}: shader returned {out.shape}, expected {(len(P), 3)}"
        assert np.isfinite(out).all(), f"{name}: shader produced non-finite values"
        assert (out >= 0.0).all() and (out <= 1.0).all(), \
            f"{name}: shader returned values outside [0,1] -- range {out.min()}..{out.max()}"


def test_roughness_shaders_satisfy_ROUGH():
    for shader in (bbt.shade_roughness, bbt.shade_wing_roughness):
        out = shader(P.copy(), N.copy(), bbt.UGUISU, 1.0)
        assert out.shape == (len(P), 3), f"{shader.__name__} returned {out.shape}"
        assert (out >= 0.0).all() and (out <= 1.0).all(), f"{shader.__name__} out of [0,1]"
        # a roughness map is read as a SCALAR; three unequal channels is a colour leak
        assert np.abs(out[:, 0] - out[:, 1]).max() == 0.0 and \
               np.abs(out[:, 1] - out[:, 2]).max() == 0.0, \
            f"{shader.__name__} returned unequal channels -- colour has leaked into a scalar map"


def test_eye_stack_does_not_overlap():
    """⚠ THE RINGS ARE DEFINED BY FOUR CONSTANTS THAT MUST STAY ORDERED. Pupil inside iris inside
    orbital inside white ring. Any inversion silently paints one over another."""
    assert bbt.PUPIL0 < bbt.PUPIL1 <= 1.0, "pupil is not inside the iris"
    assert bbt.HIYO_PUPIL0 < bbt.HIYO_PUPIL1 <= 1.0, "hiyodori pupil is not inside its iris"
    # the hiyodori's stack is pupil -> iris -> black rim, and the rim must start OUTSIDE the iris
    # or it eats the ring it is meant to frame
    assert bbt.HIYO_RIM_IN0 > bbt.HIYO_PUPIL1, "hiyodori rim starts inside the pupil fade"
    assert bbt.HIYO_RIM_IN1 < bbt.HIYO_RIM_OUT0, "hiyodori rim has no width"
    assert bbt.HIYO_RIM_OUT0 > 1.0, "hiyodori rim closes inside the eye instead of around it"
    # ⚠ THE ORBITAL MUST BE WIDE ENOUGH TO SURVIVE THE BAKE. The rim it backs is 0.2 texels at
    # 1024 and renders as speckle; the whole point of the shadow is that it does not. Two texels
    # is the floor at which a soft edge still reads as an edge.
    _texel = 1.15 / bbt.RES * 3.0        # studs per texel on a 1.15-stud bird at ship resolution
    _orbit_w = (bbt.HIYO_ORBIT_OUT1 - bbt.HIYO_ORBIT_IN1) * bbt.EYE_R
    assert _orbit_w / _texel > 2.0, \
        "hiyodori orbital is only %.1f texels wide -- it will bake as speckle" % (_orbit_w / _texel)
    # ⚠ AND THE PUPIL MUST ACTUALLY BE DARKER THAN THE IRIS IT SITS IN. The hiyodori shipped with
    # iris (96,60,44) against pupil (28,22,20): the two read as one dark bead and the owner could
    # not see the iris at all. A ring needs contrast, not just an order.
    #
    # ⚠ THE THRESHOLD IS 200 BECAUSE THE KNOWN-BAD PAIR SCORES 130. Written first at 120, which
    # let the exact defect it was written for pass -- a guard set below the value that motivated
    # it tests nothing. Mutation-checked by restoring (96,60,44)/(28,22,20) and confirming failure.
    for sp in ("mejiro", "hiyodori", "karasu"):
        pal = bbt.SPECIES[sp]["palette"]
        if "iris" in pal:
            gap = sum(pal["iris"]) - sum(pal["eye"])
            assert gap > 200, \
                "%s: iris is only %d brighter than its pupil -- it will not read" % (sp, gap)
    assert bbt.ORBIT_OUT0 >= 1.0, "orbital grey starts inside the iris"
    assert bbt.RING_IN0 >= bbt.ORBIT_OUT0, "the white ring starts before the orbital grey ends"
    assert bbt.RING_IN1 < bbt.RING_OUT0, "the white ring has no width"
    assert bbt.GRAIN_FADE1 > bbt.RING_OUT1, \
        "the roughening dies before the ring's outer edge, so one edge is crisp and one is not"


def test_lore_still_aims_at_the_eye():
    """It is derived from EYE on purpose; a typed pair would drift the moment the eye moved."""
    assert bbt.LORE_A == (bbt.EYE[1], bbt.EYE[2]), \
        f"LORE_A {bbt.LORE_A} no longer reads off EYE {bbt.EYE[1:]}"


def test_throat_sits_behind_the_bill():
    assert bbt.THROAT_Y0 < bbt.THROAT_Y1 <= bbt.BILL_Y, \
        "the yellow throat runs past the bill line"


if __name__ == "__main__":
    print("bake_bird_texture contracts")
    for nm, fn in sorted(globals().items()):
        if nm.startswith("test_") and callable(fn):
            check(nm, fn)
    if FAILS:
        print(f"\n{len(FAILS)} FAILED")
        sys.exit(1)
    print("\nall contracts hold")
