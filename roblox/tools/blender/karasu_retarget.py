# karasu_retarget.py — the crow familiar: vendor crow -> two skinned Roblox MeshParts.
#
# WHY THIS FILE EXISTS AT ALL. The uguisu's retarget lived only in a .blend outside the repo
# (`~/Desktop/Roshambo Reference/models/birds/probe/uguisu_retarget.blend`), so the second bird
# would have had to rediscover every step. This script IS the recipe: run it and the karasu is
# rebuilt from the purchased crow, deterministically, with every measurement checked in code
# rather than by eye. Traps it encodes are on docs/wiki/practice/blender-pipeline.md.
#
# WHAT THE PURCHASE ACTUALLY BOUGHT, measured rather than assumed:
#   * a clean body unwrap — 108,504 texels at 512^2 with 23 overlapping (0.0%) and ZERO mirrored
#     texels. That is the expensive thing, and it is what makes bake_bird_texture's shade()
#     (a colour FUNCTION of 3D position) legal on this mesh at all.
#   * a real crow head and bill, which is the half of the silhouette a sparrow cannot be
#     reshaped into.
# What it did NOT buy, contrary to first expectations:
#   * usable wing BONES. The crow rig is a Maya QuickRig humanoid (`QuickRigCharacter_*`) and
#     BirdController drives the SPARROW's names (joint1/3/4/8/12/25 + wing_*/wrist_*).
#     Every bone is renamed here. ⚠ The crow's own TAIL bone is literally named `joint1`, which
#     is also the target name for the ROOT — rename via a temp namespace or one silently eats
#     the other.
#   * a folded wing. The crow ships wings SPREAD and welded into the body mesh, which is the
#     pose we do not want for the body; they are cut off at the shoulder here and the folded
#     wing is built into the flank instead.
#   * a usable tail. The vendor tail is 48 triangles of ALPHA CARDS. We ship a plain ColorMap
#     with no SurfaceAppearance, so an alpha card renders as an opaque rectangle. Rebuilt solid.
#   * a jaw. The bill is one closed shell. ⚠ It STAYS one: the plane split that used to cut it
#     was retired 2026-08-30 -- a tomium is a curve. The beak does not open.
#
# UNITS ARE STUDS, 1 stud ~ 1 foot. Built at FINAL size — 1.64 studs nose to tail, a life-size
# hashibutogarasu (~50cm), owner-chosen 2026-08-26. This one is 1:1: import it and do not rescale.
#
# ⚠ THIS COMMENT USED TO SAY the uguisu "was exported at 0.828 and rescaled to 0.552 inside
# Studio". IT WAS NOT. Measured in the live place 2026-08-27 via the Studio MCP: UguisuBody is
# 0.828 studs and BirdController does no rescaling at all. 0.552 was a figure the wiki also
# carried and it was wrong in both places — an invented number that propagated between records
# because neither was ever checked against the artifact. Run tools/studio/measureBirds.luau.
#
# AXES, working frame: +Y forward (the bird faces +Y), +Z up, +X the bird's right, feet at z = 0,
# geometry centred in x and y. Export rotates 180 degrees about Z so the model faces -Y, which is
# what Blender's FBX exporter convention wants; that is why a reimported uguisu_body.fbx reads
# rotation Z = -180.
#
# Run inside Blender (the MCP execs this file), then call:  run()

import bpy
import os
import bmesh
import math
import numpy as np
from mathutils import Matrix, Vector

VENDOR = ("/Users/jonlabrie/Desktop/Roshambo Reference/models/birds/"
          "Bird collection blend files/crow.blend")

BIRD_MESHES = ["bodywuyawuya_low_all", "polySurface2.001", "polySurface3",
               "pPlane10pPlane9", "pPlane2pPlane2pPlane1"]
VENDOR_ARM = "QuickRigCharacter_Reference"

BODY_OBJ = "bodywuyawuya_low_all"
FOOT_L, FOOT_R = "polySurface2.001", "polySurface3"
TAIL_CARDS, WING_CARDS = "pPlane10pPlane9", "pPlane2pPlane2pPlane1"

NOSE_TO_TAIL = 1.64          # studs, final
SHOULDER_CUT = 0.19          # |x| plane that separates spread wing from body. Measured: body
                             # verts stop at 0.1579 and wing-weighted verts start at 0.2267, so
                             # the cut lands in a genuine gap rather than through the shoulder.

# ---------------------------------------------------------------------------------------
# BONE MAP — vendor QuickRig name -> the name BirdController looks up
# ---------------------------------------------------------------------------------------
# roblox/src/client/BirdController.client.luau resolves exactly these by name. `joint13`,
# `joint14` and friends are referenced only in its comments, but the leg CHAINS are kept whole
# anyway: a hip rotation has to swing a real chain or the foot detaches from the leg.
BONE_MAP = {
    "QuickRigCharacter_Hips":          "joint1",       # root
    "QuickRigCharacter_Spine":         "joint2",
    "QuickRigCharacter_Spine1":        "joint2b",
    "QuickRigCharacter_Spine2":        "joint2c",
    "QuickRigCharacter_Neck":          "joint3",       # neck
    "QuickRigCharacter_Head":          "joint4",       # head
    "joint1":                          "joint8",       # ⚠ the vendor's TAIL bone, and its name
    "joint2":                          "joint9",       #   collides with the root's target name
    # ⚠ THE LEG SIDES ARE MEASURED OFF THE SHIPPED UGUISU, NOT GUESSED -- the first draft of this
    #   map had them inverted. In the uguisu's ARMATURE-LOCAL frame (bird facing +Y, same as ours)
    #   joint12 sits at x -0.038 and joint25 at x +0.088; the bird's right when facing +Y is +X;
    #   BirdController calls joint12 hipL and joint25 hipR. So joint25 is the bird's RIGHT leg.
    #   Swapping them is invisible at rest and only shows in the victory hop, where the body rolls
    #   toward the planted foot -- it would roll the wrong way, on the one animation people watch.
    "QuickRigCharacter_LeftUpLeg":     "joint12",      # bird's left  (-X here)  -> hipL
    "QuickRigCharacter_LeftLeg":       "joint13",
    "QuickRigCharacter_LeftFoot":      "joint14",
    "QuickRigCharacter_RightUpLeg":    "joint25",      # bird's right (+X here)  -> hipR
    "QuickRigCharacter_RightLeg":      "joint13.001",
    "QuickRigCharacter_RightFoot":     "joint14.001",
}

# ⚠ THE VENDOR'S WING BONES ARE DELETED, NOT RENAMED, and this is the one place the crow was
# expected to be cheaper than it is. The purchase does ship a 3-bone wing chain per side
# (Shoulder -> Arm -> ForeArm), which the sparrow lacked -- but the sparrow's absence was never
# the blocker. The uguisu builds `wing_*`/`wrist_*` from scratch on its own spread-wing part, and
# what makes those bones work is not that they exist, it is their AXES: local Y along the span,
# local Z vertical, local X fore-aft. BirdController's beat and fold are written against exactly
# that frame, including the measured fact that local X does not mirror between wings and local Z
# does. A vendor bone that merely sits in the right place with an arbitrary roll would fold the
# wrong way -- the same class of bug that shipped inverted on the uguisu for three days.
# So they are rebuilt, straight along +/-X, rolled to put local Z on world +Z.
WING_BONES_VENDOR = ["QuickRigCharacter_RightShoulder", "QuickRigCharacter_RightArm",
                     "QuickRigCharacter_RightForeArm", "QuickRigCharacter_LeftShoulder",
                     "QuickRigCharacter_LeftArm", "QuickRigCharacter_LeftForeArm"]

# ---------------------------------------------------------------------------------------
# SPECIES PROPORTIONS
# ---------------------------------------------------------------------------------------
# Everything below is a fraction of NOSE_TO_TAIL unless the comment says otherwise, so the
# numbers stay readable and the bird can be rescaled without re-deriving them.
KARASU = {
    "name": "Karasu",
    # Hashibutogarasu (Corvus macrorhynchos), the bird a Japanese speaker means by "karasu":
    # ~50cm, a heavy arched bill, a flat crown, broad slotted wings and a WEDGE tail. The wedge
    # is the cheapest species tell available -- an uguisu's tail is rounded, a crow's comes to a
    # blunt point down the middle, and that difference survives arena distance where colour does
    # not (both birds are, at distance, "a dark bird").
    # ⚠ EVERY NUMBER BELOW IS MEASURED OFF THE VENDOR BODY, not chosen. `body_profile()` prints
    # the table these came from; re-run it if the mesh ever moves under them.
    "tail": {
        "root_y": -0.400,     # buried in the rump, whose tip sits at y -0.516, z 0.317
        "root_z": 0.330,
        "length": 0.750,      # sized so the tail VISIBLE past the rump is ~30% of the whole
                              # bird. A crow's tail is ~38% of its length as ornithologists
                              # measure it (from where the central rectrices emerge), but the
                              # vendor rump already extends past the vent, so 30% of the bbox is
                              # the same bird. ⚠ Total length lands at ~1.91 here and `run()`
                              # rescales the finished bird to 1.64 -- proportion first, size last.
        "thickness": 0.030,   # at the root; tapers to 55% of that at the tip
        "droop_deg": 9.0,     # a crow holds its tail nearly level; a warbler droops it
        "root_hw": 0.082,     # half-width where it leaves the rump ...
        "mid_hw": 0.076,
        "tip_hw": 0.062,      # ... narrow the whole way, because this tail is seen CLOSED
        "wedge": 0.30,        # how much shorter the outer rectrices run: THE crow tell
        "rectrices": 5.0,
        "scallop": 0.016,
        "dihedral": 0.030,
    },
    # THE FOLDED WING IS DERIVED, NOT TYPED. The uguisu's x_offsets were hand-tuned against its
    # body half-width and its own comment warns that a few thousandths either way either buries
    # the plate in the flank or steps it off the silhouette. Here the builder RAYCASTS the body at
    # each vertex and stands the plate off the surface it actually finds -- the standing "derive
    # from what it touches" rule. Only the profile along the bird stays as data.
    #
    # ⚠ ONE PLATE, NOT A PLATE PLUS THREE PRIMARY TIPS. The uguisu models a covert plate and three
    # separate primaries; built at this scale that reads as loose slats laid over the tail, with a
    # hard edge where each one begins. It is the third time this project has met the same lesson
    # -- a wing is not a comb, a tail is not a comb, and a folded wing is not a stack of blades.
    # The plate simply TAPERS TO A POINT past the rump, which is what a real folded primary group
    # does, and the overshoot over the tail base -- the most recognisable thing about a folded
    # wing -- survives as the outline of one continuous surface.
    "wing_folded": {
        "thickness": 0.014,
        "standoff": 0.005,           # how far proud of the body surface the plate sits at its
                                     # middle; it tapers to 0 at every free edge
        "cols": 15,                  # the station list below is resampled to this many, or the
                                     # plate's own outline reads as facets against a smooth body
        # (y, z_centre, half_height [, x]). x is RAYCAST from the body where one is given; past
        # the rump there is nothing to hit, so those stations carry an explicit x -- without it
        # the nearest-vertex fallback returns whatever rump vertex is closest and the tips swing
        # across the spine, which showed from directly above as an X scratched into the back.
        # z_centre rides ~65% of the way up the body's span (a folded wing sits on the UPPER
        # flank) and half_height stays INSIDE that span: above the back line it steps off the
        # silhouette, below the belly it reads as a stripe.
        # ⚠ THE TOP EDGE MUST CLEAR THE BACK LINE BY A REAL MARGIN. The first pass put it at
        # z_centre + half_height == the body's own zmax at two stations, so the left and right
        # plates met along the spine and the bird grew a Y-shaped crease down its back, plainly
        # visible from above. The margin column below is that clearance and it is the number to
        # check after any change: a folded wing sits ON the flank, and the mantle shows between
        # the two wings.
        #        y      z_ctr   half_h   [x]     body zmax   top edge   margin
        "plate": [( 0.300, 0.720, 0.100),        #   0.920      0.820     0.100
                  ( 0.170, 0.640, 0.140),        #   0.855      0.780     0.075
                  ( 0.020, 0.560, 0.150),        #   0.766      0.710     0.056
                  (-0.140, 0.450, 0.115),        #   0.600      0.565     0.035
                  (-0.270, 0.408, 0.092),        #   0.538      0.500     0.038
                  (-0.380, 0.366, 0.070, 0.070), #   0.432      0.436
                  (-0.530, 0.338, 0.044, 0.044), # past the rump (y -0.516)
                  (-0.680, 0.314, 0.017, 0.024)],# the point, lying over the tail base
    },
    # A crow's wing is BROAD and rounded with deep slots between the primaries, where a warbler's
    # is short and blunt. Both are unswept; the difference is chord and slot depth.
    # ⚠ NO SEPARATE FINGER PRIMARIES, even though a crow's slots are its silhouette. Four of them
    # were built on the uguisu and read as detached shards (owner 2026-08-21). The slot read is
    # carried by DEEPENING the scallop toward the tip instead -- same silhouette, no seams.
    "wing_spread": {
        "root_gap": 0.012,           # ⚠ the two wings must NOT share vertices at x = 0. Built
                                     # flush, the root column is ambiguous and every vertex there
                                     # binds to whichever side is tested first -- 16 of the LEFT
                                     # wing's root vertices ended up on `wing_R`, which tears the
                                     # left wing open the moment the right one beats.
        "span": 1.450,               # one wing. Tip-to-tip lands at ~1.48x body length.
                                     # ⚠ A DIAL, and the one most likely to want the owner's eye.
                                     # A live hashibutogarasu is 2.0x (50cm long, ~100cm span);
                                     # the shipped uguisu is 1.13x, i.e. it too came in well under
                                     # life proportion and was gated as good. 1.48 is deliberately
                                     # between them: unmistakably a crow's long broad wing without
                                     # a 3.3-stud glider crossing the arena.
        "chord_scale": 1.30,         # a corvid wing is BROAD; stretching span alone would give it
                                     # a gull's high aspect ratio.
        "root_z": 0.705,             # the vendor's own Arm bone head sits at y 0.135, z 0.708
        "root_y": 0.150,
        "n_scallop": 7,
        "scallop_root": 0.012,       # notch depth at the wrist ...
        "scallop_tip": 0.052,        # ... and at the tip, where a crow's slots are deep
        "thickness": 0.009,
        "aoa_rise": 0.048,
        "aoa_washout": 0.45,
        # chord the rise was sized against (the station where the taper begins, pre chord_scale)
        "aoa_ref_chord": 0.348,
        # (t, leading_y, trailing_y, z_rise)
        # ⚠ THE LAST FOUR STATIONS CONVERGE, AND THEY DID NOT USED TO. The plan ended at t=1.00
        # with a 0.188 chord and the loft caps the outermost column flat, so the wing finished in a
        # SQUARED-OFF CUT -- 0.244 studs of flat edge after chord_scale, about 2.9 inches at this
        # bird's size (owner, 2026-08-26: "why are the tips of the wings squared off?"). A corvid
        # wingtip is the iconic slotted one, so a blunt end reads wrong on a crow specifically.
        # Not tapered to a POINT: that is a swift. It closes to a narrow rounded end.
        "plan": [(0.00,  0.070, -0.300, 0.000),
                 (0.16,  0.086, -0.400, 0.014),
                 (0.36,  0.074, -0.470, 0.030),
                 (0.56,  0.030, -0.500, 0.045),
                 (0.74, -0.038, -0.496, 0.058),
                 (0.88, -0.104, -0.452, 0.066),
                 (0.92, -0.126, -0.436, 0.0685),
                 (0.96, -0.156, -0.396, 0.0705),
                 (1.00, -0.214, -0.262, 0.072)],
    },
    # ⚠ THIS IS A REFERENCE LINE, NOT A CUT. `split_bill` used to bisect the bill along it; that
    # was retired 2026-08-30 on the owner's ruling -- a tomium is a CURVE and a plane cannot follow
    # one. Measured, this plane sat 0.0107 studs below the mesh's own mouth line and left 13 faces
    # owning vertices from both mandibles.
    # ⚠ IT SURVIVES FOR ONE REASON: `reshape_body` displaces the culmen only ABOVE this line,
    # weighted to zero AT it, so the girth pass cannot flatten the mouth. That use does not need
    # the line to be the true gape -- only to sit inside the bill and stay put.
    # `measure_gape_plane()` fits a better plane from the mesh and is still deliberately unwired:
    # it reduces the error without changing its class, which is why it was never the answer.
    "bill": {"gape_p": (0.0, 0.720, 0.9555), "gape_n": (0.0, 0.0599, 0.9982),
             "hinge_y": 0.645, "tip_y": 0.830},
    # ⚠ THE KARASU'S EYE IS PAINTED, NOT MODELLED -- unlike the uguisu, which carries eye
    # GEOMETRY from `bird_familiar._eyes`. A crow's eye is as dark as its head, so a sphere buys
    # nothing a texture cannot; what sells it is the CATCHLIGHT (`bake_bird_texture`). One
    # consequence worth stating plainly, because it wasted a look on 2026-08-28: an untextured
    # solid-shaded render of this bird HAS NO EYES, and that is not a missing feature.
    #
    # ⚠ AND UNTIL NOW IT WAS THE ONE LANDMARK NOTHING COULD RE-DERIVE. `bake_bird_texture` says
    # every karasu landmark "comes from `karasu_retarget.landmarks_final()`"; `eye` and
    # `catchlight` did not -- they were measured by hand and typed, so any reshape of the head
    # slid the skull out from under them silently. Measured after the 2026-08-28 reshape: the
    # crown rose 0.0033 studs at the eye's station, 14% of the eye's own radius -- too small to
    # see, and exactly the size of drift that accumulates unnoticed.
    #
    # Now `landmarks_final` derives the eye's z from the MEASURED crown at its own station, so it
    # tracks a forehead change instead of ignoring one. `crown_drop` reproduces the hand-measured
    # z exactly on the pre-reshape bird (crown 0.897 - 0.061 = 0.836), so adopting this changed
    # nothing about how the bird looks; it only changed what happens NEXT time the head moves.
    # ⚠ These are in FINAL studs, not build coordinates -- they are compared against the
    # normalised mesh, unlike everything else in this dict.
    # ⚠ THE EYE IS MODELLED, AND THAT IS THE THIRD ANSWER AFTER TWO PAINTED ONES FAILED.
    # Owner, 2026-08-28: a flat dark disc read as nothing; a bigger brighter glint read as
    # "cataracts and/or possessed"; a hand-repaint of the same map did not satisfy either. The
    # common failure is that a painted highlight is a BRIGHT SHAPE AT A FIXED PLACE -- it cannot
    # move with the light or the camera, so it reads as a marking rather than as wetness, and
    # making it more visible only makes it more obviously a marking. A dome earns its highlight
    # from the engine instead, and its curvature shades even when nothing is specular.
    #
    # Same builder as the uguisu (`bird_familiar._eyes`, two UV spheres) -- "simply, if possible".
    #
    # ⚠ BUILD COORDINATES, like everything else in this dict. The painted version carried FINAL
    # studs as a special case; geometry has to be built before `normalise_size` exists, so the
    # special case is gone and `landmarks_final` maps the eye out like every other landmark.
    # ⚠ SMALLER AND SUNK DEEPER, 2026-08-28. Owner on the first build: "the eyeball itself is too
    # large, and protrudes too far." At `proud` 0.45 nearly half a sphere stood out of the skull,
    # which reads as a ball bearing pressed into the head rather than as an eye -- a real eye
    # shows as a shallow LENS, because most of the ball is behind the lids. Dropping `proud` does
    # more of that work than shrinking `r` does, so the radius moves only a little.
    # ⚠ y MOVED FORWARD 2026-08-28. Owner: the opening "is located a bit to the rear, instead of
    # squarely on the sides of the head." Measured, 0.5092 put it 60.6% of the way from the nape
    # to the bill hinge; 0.545 puts it at 71%, which reads as the side of the head rather than
    # behind it. Re-derive the percentage rather than nudging blind: the head runs y 0.300 to the
    # hinge at 0.645.
    "eye": {"y": 0.5450, "crown_drop": 0.0729, "r": 0.0225,
            # ⚠ x IS DERIVED FROM THE SKULL IT SITS IN, never typed. The uguisu learned this the
            # expensive way: "v2 had it at r=0.026/x=0.106 against a 0.116 half-width head and it
            # read as a bolt screwed into the side." The centre is sunk below the measured
            # surface so exactly this fraction of the radius stands proud, which also means the
            # eye follows any reshape of the head instead of floating off it.
            # ⚠ AND ONLY JUST PROUD. Owner, 2026-08-28: "if it's easy to make the eyes slightly
            # less proud, do it." ⚠ There is a floor: the ball only emerges from the head within
            # r*sqrt(1-(1-proud)^2), and the aperture must stay INSIDE that or the skull occludes
            # the eye before the lid does. At 0.24 that limit is 0.650r against an `ap_y` of
            # 0.60 -- close, and the number to re-check before lowering this further.
            "proud": 0.24,
            # ⚠ THE SOCKET IS BODY GEOMETRY, NOT A SECOND MESH. Owner, 2026-08-28: a modelled lid
            # opening would help, "but I'd hate to spend too many meshes on it." It costs none --
            # this dishes the HEAD around the eye, on the part that already exists, so the ball
            # emerges from an opening instead of sitting on the skin like a bead. The only real
            # cost is a handful of triangles from the local subdivision the dish needs to be
            # smooth on a 555-vertex head.
            # `socket_depth` is how far the skin falls away AT the eye centre, `socket_r` how far
            # out the dish reaches, both as multiples of the eye radius.
            # THE LIDS, as multiples of the eye radius. `ap_y`/`ap_z` are the half-axes of the
            # OVAL opening -- fore-aft and vertical -- and their ratio is the whole reason the
            # visible eye reads oval while the ball stays a sphere.
            # ⚠ BOTH INSIDE THE BALL'S SILHOUETTE (< 1.0), or the aperture is wider than the eye
            # and the head shows through the gap at the fore-aft extremes.
            # ⚠ BOTH WELL INSIDE THE VISIBLE CAP. The ball is sunk, so it emerges from the head
            # only within ~0.69r; an aperture drawn wider than that is BURIED, and the visible
            # edge reverts to the ball's own emergence circle -- which is why every earlier oval
            # still read as a circle at the front and back.
            "ap_y": 0.60,
            "ap_z": 0.38,
            "collar_segments": 24,   # 16 left visible flats once the ring tightened
            # ⚠ WIDTHS, NOT SCALES, and that distinction is the whole fix. Owner: "the size of
            # your periorbital ring is much larger than the eye it encloses, especially in the
            # horizontal dimension." It was built by SCALING the aperture's semi-axes, so the
            # band came out widest where the aperture was already widest -- 1.18r of ring
            # horizontally against 0.74r vertically, and over twice the eye's width overall. A
            # real lid ring is a roughly CONSTANT-WIDTH band, which means stepping along the
            # ellipse's own normal by a fixed distance. Both are multiples of the eye radius.
            # ⚠ AND THE WIDTH IS NOT CONSTANT EITHER. A uniform band was the right correction to
            # a scaled one and still wrong: owner, 2026-08-28, "too tight now vertically, and
            # still too loose in the rear/trailing part." On the bird the periorbital skin is
            # deepest above and below the eye, moderate toward the bill, and tucks in tightly
            # behind it. Three widths, blended smoothly around the ellipse by a weighted mean of
            # where you are -- front at theta 0, top/bottom at +/-90, rear at 180.
            "collar_w_front": 0.58,  # toward the bill
            "collar_w_rear": 0.52,   # behind the eye: the tightest part of the ring
            "collar_w_vert": 0.78,   # above and below, where the lids are deepest
            # The crest rides at this fraction of whatever the local width is, so the ring's
            # PROFILE stays the same shape all the way round even as its width changes.
            # ⚠ THE LID WRAPS THE BALL ON A CONCENTRIC SPHERE. A single step off the aperture and
            # then a straight run to the head CANNOT work: the ball is convex, so any chord
            # between two points near it cuts inside, and the head makes it worse by falling away
            # toward the crown -- measured, the ball escaped to 0.975r straight up while being
            # covered to 0.375r underneath. Riding a slightly larger sphere out to the ball's own
            # silhouette is outside it BY CONSTRUCTION, everywhere, and only then does the skirt
            # peel back to the head, where there is no ball left to cut.
            "collar_wraps": 3,        # loops on the concentric sphere between edge and silhouette
            "collar_wrap_end": 0.97,  # how far round to wrap, as a fraction of that sphere
            # ⚠ AND THEN LIFT IT CLEAR. A tangent step alone leaves the sphere by only
            # sqrt(r^2+t^2)-r -- 0.024r here -- so the lid GRAZES the ball instead of covering
            # it, and the eye goes on showing all the way to its own emergence circle, which is
            # round. A lid has to overlap the eyeball or it is not clipping anything. Pushing the
            # middle loop out to r*(1+lift) keeps it strictly outside (so the no-cutting
            # guarantee holds) while putting it in FRONT of the ball at that angle.
            # the lid's thickness: radius of the wrap sphere over the ball. Owner called 0.10
            # "slightly too heavy" -- this is the dial for how swollen the lid reads.
            "collar_lift": 0.07,
            "collar_sink": 0.18,     # how far the outer loop is BURIED, as a multiple of r
            "lid_height": 0.26},  # how far the crest stands proud of the feathering
    # ⚠ EVERY STATION BELOW WAS READ OFF `body_profile()`, not chosen. Owner, 2026-08-28, having
    # watched the karasu on a shoulder: "more of an arch on the culmen, and a fatter body,
    # presumably by giving the bird more of a 'belly'". The vendor crow is a lean bird and a
    # hashibutogarasu is not -- it is heavy and full-chested, and the arched culmen is the single
    # trait the bird's NAME is built on (hashibuto = thick-billed).
    "reshape": {
        # --- GIRTH: how much wider through the torso. A plain multiplier on |x|. -------------
        # ⚠ THE HEAD MUST NOT WIDEN. Measured half-width peaks at 0.188 over y 0.054..0.234 and
        # has already fallen to 0.118 by y 0.354, which is skull. Widening a crow's head costs
        # the silhouette the whole bird is recognised by, so the taper is FULLY out before the
        # head begins.
        "girth": 1.15,
        "girth_band": (-0.42, -0.18, 0.22, 0.34),   # 0, full, full, 0 -- smoothstep between
        # --- BELLY: bow the ventral line instead of ramping it --------------------------------
        # ⚠ CENTRED FORWARD OF THE LOWEST POINT, ON PURPOSE. The underside already dips hard at
        # y -0.13 (zmin 0.111, against 0.445 at the breast) and that dip is the THIGH region, not
        # the belly -- pushing it lower crowds the feet, which stand at z 0. What reads as a
        # full-bellied bird is the breast-to-vent line bowing convex, so the bulge sits over
        # y 0.08 where zmin is ~0.30 and there is room to give.
        # ⚠ 0.035 READ AS "STILL A BIT SVELTE" (owner, 2026-08-28) and this is the second pass.
        # The rear edge stays put: at y -0.126 the band is only ~4% in, so the thigh dip (zmin
        # 0.111 against feet at z 0) barely moves however far this dial goes. The front edge
        # moved OUT instead, so the fill runs up into the breast rather than deepening the vent.
        "belly": 0.060,
        "belly_band": (-0.14, -0.02, 0.20, 0.36),
        # ⚠ THE BEAK WORK OF 2026-08-28 IS DELIBERATELY GONE, all of it: culmen arch, forehead
        # lift, tip hook, tip blunt, tomium retraction, the steepened gape plane and the moved
        # hinge. Owner: "revert all the beak work." It ended with a jaw that swung through the
        # upper mandible, and the reason was structural rather than a bad number -- every attempt
        # displaced a vendor bill only a few vertex rings long, so each fix bought the next
        # defect. The measurements are kept in the comments here and on docs/wiki because they
        # are the useful part: the bill wants LOFTING from station data, the way the tail, the
        # folded wing and the eye lids in this same file already are.
    },
    "feet_target_tris": 130,         # per foot, down from the vendor's 920
}


# ---------------------------------------------------------------------------------------
# FRAME NORMALISATION
# ---------------------------------------------------------------------------------------

def _world_pts(names):
    pts = []
    for n in names:
        o = bpy.data.objects[n]
        for v in o.data.vertices:
            pts.append(o.matrix_world @ v.co)
    return pts


def load_vendor():
    """Open the purchased crow, strip everything that is not the bird, and put it in our frame.

    ⚠ Vendor source never enters the repo (same rule as the niwaki). Only derived output does.
    """
    bpy.ops.wm.open_mainfile(filepath=VENDOR)
    keep = set(BIRD_MESHES) | {VENDOR_ARM}
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)

    arm = bpy.data.objects[VENDOR_ARM]
    # ⚠ TRAP 1 (blender-pipeline). A vendor file can ship a STORED POSE, and rescaling rest data
    # under it detonates the pose channels. The crow's are identity -- unlike the sparrow's --
    # but clearing costs nothing and the failure is silent.
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    # ⚠ TRAP 3. Stale CUSTOM SPLIT NORMALS shade a crease the moved geometry no longer has, and
    # the symptom survives every geometry fix because the geometry was never wrong.
    for n in BIRD_MESHES:
        me = bpy.data.objects[n].data
        if "custom_normal" in me.attributes:
            me.attributes.remove(me.attributes["custom_normal"])

    bpy.context.view_layer.update()
    pts = _world_pts(BIRD_MESHES)
    span_y = max(p.y for p in pts) - min(p.y for p in pts)
    S = NOSE_TO_TAIL / span_y
    # The vendor bird faces -Y; the working frame faces +Y.
    M = Matrix.Scale(S, 4) @ Matrix.Rotation(math.pi, 4, 'Z')

    # ⚠ TRAP 2. Setting matrix_world on a still-parented object computes a COMPENSATING
    # matrix_basis, and the mesh silently keeps the vendor's scale and rotation. Bake the
    # transform into the DATA and zero both matrices explicitly instead.
    for n in BIRD_MESHES:
        o = bpy.data.objects[n]
        o.data.transform(M @ o.matrix_world)
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_basis = Matrix.Identity(4)
    arm.data.transform(M @ arm.matrix_world)
    arm.matrix_basis = Matrix.Identity(4)

    bpy.context.view_layer.update()
    pts = _world_pts(BIRD_MESHES)
    mn = Vector([min(p[i] for p in pts) for i in range(3)])
    mx = Vector([max(p[i] for p in pts) for i in range(3)])
    # Centre x and y; put the FEET at z = 0. The origin at the feet is load-bearing: it makes
    # perch.WorldPosition the bird's position with no fudge (familiars.md).
    T = Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
    for n in BIRD_MESHES:
        bpy.data.objects[n].data.transform(T)
    arm.data.transform(T)
    bpy.context.view_layer.update()
    return {"scale": round(S, 6), "span_y": round(span_y * S, 4)}


# ---------------------------------------------------------------------------------------
# GEOMETRY — shared builders come from bird_familiar, which is the SPEC for our birds
# ---------------------------------------------------------------------------------------

# ⚠ THE FALLBACK BELOW IS THE PATH ACTUALLY TAKEN, in all three places that use it. The MCP
# EXECS this file's source rather than importing it, so `__file__` is undefined and the fallback
# resolves every helper import. It pointed at `.worktrees/assets/...` -- the ASSET THREAD's
# worktree, retired 2026-08-26 and slated for deletion ([[parallel-threads]]) -- so this script
# loaded its shared builders and its texture baker from a copy nobody maintains, and would have
# broken outright the moment that worktree was removed. Checked 2026-08-28: the two copies of
# `bird_familiar` and `bake_bird_texture` were still identical, so nothing had gone wrong yet.
# That was luck, not design -- `spread_wing.py` HAD already diverged, and only escaped mattering
# because nothing here loads it.
def _bf():
    """bird_familiar.py holds `_blade` (a flat two-sided blade, for tail feathers) and
    `_flank_blade` (a blade whose thickness runs along X, so it presents its FACE outward --
    a folded wing is seen side-on and never edge-on). Both are species-agnostic; only the
    station data differs. Importing rather than copying keeps one builder."""
    import importlib.util
    import os
    import sys
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
        "/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/blender"
    if here not in sys.path:
        sys.path.insert(0, here)
    spec = importlib.util.spec_from_file_location(
        "bird_familiar", os.path.join(here, "bird_familiar.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def split_wings(cut=SHOULDER_CUT):
    """Cut the vendor's SPREAD wings off the body at the shoulder and close the holes.

    The crow's wings are welded into the body mesh in a spread pose. We need the opposite for
    the body (folded, sculpted into the flank -- perched is ~90% of viewing time), so they come
    off. ⚠ Verify by COUNTS, never by looking: 0 boundary edges and 0 non-manifold edges is what
    proves the body is watertight again. A closed shell that is not closed shows its own interior.
    """
    o = bpy.data.objects[BODY_OBJ]
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    for sgn in (1.0, -1.0):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6,
                               plane_co=Vector((sgn * cut, 0, 0)), plane_no=Vector((sgn, 0, 0)),
                               clear_inner=False, clear_outer=False)
    bm.faces.ensure_lookup_table()
    outboard = [f for f in bm.faces if abs(f.calc_center_median().x) > cut - 1e-6]
    bmesh.ops.delete(bm, geom=outboard, context='FACES')
    bm.verts.ensure_lookup_table()
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.edges.ensure_lookup_table()
    boundary = [e for e in bm.edges if e.is_boundary]
    fill = bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    # ⚠ A FLAT FILL LEAVES A FLAT WALL. holes_fill caps each shoulder with a plate standing at
    # exactly |x| = cut, so the body reads with two vertical slabs where its flanks should round
    # off -- the profile shows half-width pinned at 0.190 for the whole shoulder run instead of
    # following the torso. Poke each cap to a centre vertex and pull that vertex INBOARD, which
    # turns the plate into a rounded shoulder. The folded wing sits over this, but the spread
    # wing is Transparency = 1 at rest and the body is what shows.
    caps = [f for f in fill.get("faces", []) if f.is_valid]
    if caps:
        poked = bmesh.ops.poke(bm, faces=caps)
        for v in {v for f in poked.get("faces", []) for v in f.verts}:
            if abs(v.co.x) > cut - 1e-6:
                v.co.x = math.copysign(cut * 0.80, v.co.x)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.edges.ensure_lookup_table()
    stats = {"holes_closed": len(boundary),
             "boundary_after": len([e for e in bm.edges if e.is_boundary]),
             "non_manifold": len([e for e in bm.edges if not e.is_manifold]),
             "body_verts": len(bm.verts)}
    bm.to_mesh(me)
    me.update()
    bm.free()
    # The vendor's alpha cards are dead weight from here: the tail is rebuilt solid and the
    # spread wing is rebuilt from spread_wing's planform. Both would render as opaque rectangles
    # against a plain ColorMap, which is all a MeshPart TextureID gives us.
    for n in (TAIL_CARDS, WING_CARDS):
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    return stats


def _smoothstep(t):
    t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
    return t * t * (3.0 - 2.0 * t)


def _band(y, y0, y1, y2, y3):
    """0 outside [y0, y3], 1 across [y1, y2], smoothstep on the shoulders.

    ⚠ SMOOTHSTEP, NOT LINEAR. A linear ramp is C0 -- its slope jumps at each knee -- and on a
    555-vertex body that shows as a visible crease ring where the taper starts, exactly the
    "blocks bolted on" read the folded wing already had to learn its way out of.
    """
    if y <= y0 or y >= y3:
        return 0.0
    if y < y1:
        return _smoothstep((y - y0) / (y1 - y0))
    if y > y2:
        return _smoothstep((y3 - y) / (y3 - y2))
    return 1.0


def _z_envelope(co, step=0.04):
    """Per-station zmin/zmax/zmid of the body, as arrays to interpolate against.

    This is what lets a displacement be VENTRAL or DORSAL rather than global: a vertex is weighted
    by where it sits between the midline and the surface at its OWN station, so the belly bulges
    without the back moving and the forehead lifts without the throat following.
    """
    y0, y1 = float(co[:, 1].min()), float(co[:, 1].max())
    edges = np.arange(y0, y1 + step, step)
    ys, zlo, zhi = [], [], []
    for a in edges:
        m = (co[:, 1] >= a - step) & (co[:, 1] < a + step)   # overlapping, so the curve is smooth
        if m.sum() >= 3:
            ys.append(a)
            zlo.append(float(co[m][:, 2].min()))
            zhi.append(float(co[m][:, 2].max()))
    return np.array(ys), np.array(zlo), np.array(zhi)


def reshape_body(spec=KARASU):
    """Fatten the torso, drop a belly into the ventral line, and arch the culmen.

    ⚠ THIS RUNS AFTER `split_wings` AND BEFORE EVERYTHING ELSE, and the position is load-bearing
    in BOTH directions:

      * AFTER the wing cut, because the cut is a plane at |x| = SHOULDER_CUT chosen to land in a
        measured GAP -- body verts stop at 0.1579, wing verts start at 0.2267. Widening the body
        first pushes the flank into that gap and the plane starts slicing shoulder.
      * BEFORE the tail, the folded wing and the bill, because every one of those MEASURES the
        body rather than assuming it -- `build_folded_wings` raycasts the flank at each station,
        the tail seats on the rump. Reshape afterwards and the folded wing is shrink-wrapped to a
        body that no longer exists, which is the "two flat fins with daylight behind them" bug.

    ⚠ AND THE CULMEN IS DISPLACED ONLY ABOVE THE GAPE PLANE, weighted to zero AT it. The plane is
    typed in `spec["bill"]` and nothing re-measures it, so moving the mandible out from under it
    would leave the beak splitting along the wrong seam -- and `split_bill`'s guard only catches a
    plane that cuts NOTHING, not one that cuts in the wrong place.
    """
    r = spec["reshape"]
    b = spec["bill"]
    o = bpy.data.objects[BODY_OBJ]
    me = o.data
    co = np.array([v.co[:] for v in me.vertices], dtype=float)
    before = {"hw": round(float(np.abs(co[:, 0]).max()), 4),
              "zmin": round(float(co[:, 2].min()), 4),
              "zmax": round(float(co[:, 2].max()), 4)}

    ys, zlo, zhi = _z_envelope(co)
    gp, gn = gape_plane(spec)
    fwd = co[:, 1] > b["hinge_y"]
    d_all = (co[:, 0] - gp.x) * gn.x + (co[:, 1] - gp.y) * gn.y + (co[:, 2] - gp.z) * gn.z
    # A sanity check on the plane itself: if nothing sits above it, it is not describing the bill.
    d_max = float(d_all[fwd].max()) if fwd.any() else 1.0
    if d_max <= 1e-6:
        raise RuntimeError("no bill geometry above the gape plane -- check bill.gape_p / gape_n")

    girth, belly = r["girth"], r["belly"]
    gb, bb = r["girth_band"], r["belly_band"]
    moved = {"girth": 0, "belly": 0}

    for i, v in enumerate(me.vertices):
        y, z = co[i, 1], co[i, 2]
        lo = float(np.interp(y, ys, zlo))
        hi = float(np.interp(y, ys, zhi))
        mid = 0.5 * (lo + hi)

        # --- girth: a plain multiplier on |x| across the torso ---------------------------
        g = _band(y, *gb)
        if g > 0.0:
            v.co.x = co[i, 0] * (1.0 + (girth - 1.0) * g)
            moved["girth"] += 1

        # --- belly: push DOWN, ventral verts only ----------------------------------------
        w = _band(y, *bb)
        if w > 0.0 and mid - lo > 1e-6:
            ventral = _smoothstep((mid - z) / (mid - lo))
            if ventral > 0.0:
                v.co.z -= belly * w * ventral
                moved["belly"] += 1

    me.update()
    co2 = np.array([v.co[:] for v in me.vertices], dtype=float)
    after = {"hw": round(float(np.abs(co2[:, 0]).max()), 4),
             "zmin": round(float(co2[:, 2].min()), 4),
             "zmax": round(float(co2[:, 2].max()), 4)}
    # ⚠ THE GAPE LINE MUST NOT HAVE MOVED. Reported rather than trusted: this is the one number
    # that says `split_bill` will still cut where it was measured to cut.
    d2 = (co2[:, 0] - gp.x) * gn.x + (co2[:, 1] - gp.y) * gn.y + (co2[:, 2] - gp.z) * gn.z
    near = fwd & (np.abs(d_all) < 0.004)
    gape_shift = round(float(np.abs(d2[near] - d_all[near]).max()), 6) if near.any() else None
    return {"before": before, "after": after, "moved": moved,
            "gape_line_shift": gape_shift, "gape_line_verts": int(near.sum()),
            "d_max_above_gape": round(d_max, 4)}


LAST_EYE = None      # (x, y, z, r) in BUILD coords, recorded by build_eyes for landmarks_final


_BRIDGE_INFO = []
LAST_GAPE = None     # (gape_p, gape_n) fitted from the mesh by measure_gape_plane


def gape_plane(spec=KARASU):
    """The gape plane in use: MEASURED if it has been fitted, otherwise the spec's typed values."""
    if LAST_GAPE is not None:
        return Vector(LAST_GAPE[0]), Vector(LAST_GAPE[1]).normalized()
    b = spec["bill"]
    return Vector(b["gape_p"]), Vector(b["gape_n"]).normalized()


def measure_gape_plane(spec=KARASU):
    """Fit the gape plane to the bill's own mouth line instead of trusting a typed one.

    ⚠ THE TOMIUM IS THE WIDEST PART OF EVERY CROSS-SECTION. A bill is a wedge in section, so the
    lateral extreme at each station IS the cutting edge -- which means the mouth line can be
    measured rather than declared, and this is the only thing here that ever knew where it was.

    ⚠ THIS EXISTS BECAUSE A TYPED PLANE WRECKED THE MOUTH. To keep a hooked tip on the upper side
    of the classifier, `gape_n` was steepened from 0.0599 to 0.1907 -- and measured on the VENDOR
    mesh, before any reshaping, the real mouth line is essentially FLAT (z 0.9574 at y 0.59
    against 0.9557 at 0.81). The steepened plane fell 0.043 across the same span, so it crossed
    the mouth diagonally: above the tomium at the back, below it at the front. `split_bill` then
    sliced the bill at an angle to its own anatomy and the "lower mandible" came out a wedge --
    a thin blade that swung through the upper when the jaw opened.
    ⚠ Do not re-steepen this to solve a tip-classification problem. Fix the tip.
    """
    global LAST_GAPE
    b = spec["bill"]
    o = bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]
    co = np.array([v.co[:] for v in o.data.vertices])
    ys, zs = [], []
    step = 0.02
    for y0 in np.arange(b["hinge_y"] - 0.06, b["tip_y"] - 0.02, step):
        m = (co[:, 1] >= y0) & (co[:, 1] < y0 + step)
        # ⚠ SKIP THIN STATIONS. Rings of 2-3 vertices are ends and seams, not sections, and their
        # "widest" point is noise -- one of them sat 0.045 off the line and would have tilted the
        # whole fit on its own.
        if m.sum() < 8:
            continue
        sub = co[m]
        i = int(np.argmax(np.abs(sub[:, 0])))
        ys.append(float(sub[i, 1]))
        zs.append(float(sub[i, 2]))
    if len(ys) < 3:
        raise RuntimeError("not enough bill sections to fit a gape plane")
    a, c = np.polyfit(np.array(ys), np.array(zs), 1)
    ymid = float(np.mean(ys))
    gp = (0.0, ymid, float(a * ymid + c))
    gn = Vector((0.0, float(-a), 1.0)).normalized()      # z = a*y + c  =>  normal (0, -a, 1)
    LAST_GAPE = (gp, tuple(gn))
    return {"stations_used": len(ys), "slope": round(float(a), 5),
            "gape_p": [round(v, 4) for v in gp], "gape_n": [round(v, 4) for v in gn],
            "typed_gape_n": list(b["gape_n"]),
            "residual_max": round(float(np.max(np.abs(np.array(zs) - (a * np.array(ys) + c)))), 4)}


def eye_site(spec=KARASU):
    """WHERE the eye goes. Measures only -- it builds no geometry at all, and that is the point.

    ⚠ THE EYE IS A SEPARATE ROBLOX PART, NOT MESH IN THIS BODY, and the reason is a constraint
    this file cannot fix. The bird ships as one MeshPart wearing one plain ColorMap with no
    SurfaceAppearance, so there is no per-texel roughness: an eye modelled INTO the body cannot be
    wet unless the whole bird is wet (tested at roughness 0.10 -- a glossy black plastic crow, and
    the eye still did not read). A separate part carries its own Material, Color and Reflectance,
    which is the only way to get a highlight that MOVES with the camera. A painted one cannot,
    which is why three painted attempts read as markings rather than as wetness.
    Owner, 2026-08-28: "wouldn't you put a separate sphere in that space and give it a material
    like an eyeball?" -- and the precedent was already here: `KarasuWings` is a separate part that
    `BirdController` CFrames onto the body every frame.

    ⚠ SO THIS SHIPS A BONE, NOT A MESH. `rebuild_rig` puts `eye_R`/`eye_L` at these coordinates,
    parented to the head, and the controller reads `Bone.TransformedWorldCFrame` to place a ball
    there. The POSITION therefore travels inside the asset and is never transcribed into Luau --
    and because the bone is a child of the head, the eyes follow every head turn for free.

    ⚠ RUNS AFTER `reshape_body`, so it seats against the skull that ships, and x is RAYCAST off
    that skull rather than typed. Change the forehead or the girth and the eye moves with the
    head instead of sinking into it or standing off it -- the uguisu learned the typed version as
    "a bolt screwed into the side".
    """
    global LAST_EYE
    e = spec["eye"]
    body = bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]
    co = np.array([v.co[:] for v in body.data.vertices])
    near = np.abs(co[:, 1] - e["y"]) < 0.04
    if not near.any():
        raise RuntimeError("no head geometry at the eye station -- check eye.y")
    z = float(co[near][:, 2].max()) - e["crown_drop"]
    # ⚠ MEASURE EACH SIDE SEPARATELY. THE HEAD IS NOT MIRROR-SYMMETRIC. Owner, seeing the first
    # build: "the eye is very visible on one side of the head and missing on the other." Measured
    # at the eye station -- the surface stands at 0.0514 on the right and 0.0610 on the left, and
    # the vendor head carries 120 vertices on one side against 163 on the other. Measuring one
    # side and MIRRORING it, which is what the uguisu's `_eyes` builder does, is guaranteed to be
    # wrong on the other side of any bird that was not modelled symmetrically -- and none of them
    # were.
    #
    # ⚠ AND CLEAR THE FOOTPRINT, NOT A POINT. A single raycast is exact for the triangle it hits
    # and misleading on a 555-vertex head: the ray struck 0.0379 on the right where vertices in
    # the same footprint reached 0.0514. Seated against that dip the ball vanished INSIDE the
    # head at every zoom. The ball spans +/- r in y and z, so what it has to clear is the surface
    # across that whole footprint, per side.
    sites = {}
    for side, sfx in ((1.0, "R"), (-1.0, "L")):
        ray = body_surface_x(e["y"], z, side, body)
        m = ((np.abs(co[:, 1] - e["y"]) < e["r"]) & (np.abs(co[:, 2] - z) < e["r"])
             & (np.sign(co[:, 0]) == side))
        local = float(np.abs(co[m][:, 0]).max()) if m.any() else ray
        surf = max(ray, local)
        # The centre sits below the skin by the part we do not want showing, so exactly `proud`
        # of the radius stands out -- on THIS side, against THIS side's surface.
        sites[sfx] = {"x": round(surf - e["r"] * (1.0 - e["proud"]), 5),
                      "surface": round(surf, 5), "raycast": round(ray, 5),
                      "local_max": round(local, 5), "verts_in_footprint": int(m.sum())}
    LAST_EYE = {"R": sites["R"]["x"], "L": sites["L"]["x"], "y": e["y"], "z": round(z, 5),
                "r": e["r"]}
    return {"sites": sites, "y": e["y"], "z": round(z, 5), "r": e["r"],
            "proud_studs": round(e["r"] * e["proud"], 5),
            "asymmetry": round(abs(sites["R"]["surface"] - sites["L"]["surface"]), 5),
            "crown": round(z + e["crown_drop"], 5)}


def build_eye_lids(spec=KARASU):
    """Raise a CONVEX ring of periorbital skin around an OVAL aperture.

    ⚠ THE FIRST VERSION DISHED THE HEAD INWARD AND THAT WAS BACKWARDS. Owner, against the
    reference photograph: "the area surrounding the eye in the bird is convex, not concave -- the
    skin is rising up from the surface to enclose the eyeball - and the visible eyeball itself is
    not circular, but oval." Both are plainly true in the photo and neither was true of the dish:
    a crow's periorbital skin is a puffy bare ring standing PROUD of the feathering, and the lids
    close over the ball top and bottom so what shows is an oval, not a disc.

    ⚠ THE APERTURE IS ELLIPTICAL, AND THAT IS WHERE THE OVAL COMES FROM -- not from squashing the
    eyeball. The ball stays a sphere; the lids decide how much of it you see, which is what
    happens on the animal. Distance is measured in aperture units, so `d == 1` IS the lid edge
    wherever you are around it: wider fore-aft (`ap_y`) than vertically (`ap_z`).

    ⚠ RUNS AFTER `eye_site` AND BEFORE `build_eye_mesh`, for the same reason the dish did: the
    site must be measured against undisturbed skin, or the eye seats itself into its own lids.
    """
    if LAST_EYE is None:
        raise RuntimeError("eye_site() has not run")
    E, e = LAST_EYE, spec["eye"]
    r = E["r"]
    ap_y, ap_z = r * e["ap_y"], r * e["ap_z"]
    outer, height = e["lid_outer"], r * e["lid_height"]
    o = bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)

    def aperture_d(y, z):
        return math.sqrt(((y - E["y"]) / ap_y) ** 2 + ((z - E["z"]) / ap_z) ** 2)

    before = len(bm.faces)
    # ⚠ ONE ROUND OF LOCAL SUBDIVISION. Two cost 1396 triangles -- 52% of the whole body -- for
    # two eye rings on a 19.7-inch bird. The lid is a smooth low-frequency shape and does not
    # need the density; triangles spent here are triangles not spent on a silhouette anyone sees.
    # ⚠ SPEND THE TRIANGLES AT THE RIM, NOT ACROSS THE WHOLE RING. The lid's shape is smooth
    # everywhere except one place -- the aperture edge, where the skin has to close over the ball
    # along a curve. Subdividing the whole region evenly made that edge JAGGED while paying for
    # density out where nothing happens. Two passes, each narrower than the last, put the
    # vertices where the curve is.
    for reach in (outer * 1.1,):
        bm.faces.ensure_lookup_table()
        region = [f for f in bm.faces
                  if aperture_d(f.calc_center_median().y, f.calc_center_median().z) < reach]
        if not region:
            continue
        edges = set()
        for f in region:
            edges.update(f.edges)
        bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=1, use_grid_fill=True)

    # 2. lift the ring: highest right at the lid edge, falling to nothing by `outer`
    bm.verts.ensure_lookup_table()
    raised = 0
    clearance = r * 0.02
    for v in bm.verts:
        d = aperture_d(v.co.y, v.co.z)
        # ⚠ INSIDE THE APERTURE, LEAVE THE SKIN ALONE. That is the hole the eyeball shows
        # through; raising it there would push the head out THROUGH the ball.
        if d <= 1.0 or d >= outer:
            continue
        side = 1.0 if v.co.x > 0 else -1.0
        cx = E["R"] if side > 0 else E["L"]
        # ⚠ THE LID MUST COVER THE BALL, and a decorative ring alone does not. The first version
        # only added `height * w`, which FALLS OFF as `d` grows -- and `d` grows fastest
        # vertically, so the lids came out thinnest exactly where they had to be thickest. The
        # visible eye stayed a circle: the ball pokes through wherever it stands above the skin,
        # and with a constant skin height that boundary is a circle by construction, whatever
        # shape the aperture is drawn.
        #
        # So raise the skin to CLEAR THE BALL for every vertex outside the aperture. The visible
        # region is then exactly `d <= 1` -- an ellipse, because that is what the aperture is --
        # and the ball stays a sphere, which is what happens on the animal.
        # ⚠ THE PER-VERTEX "COVER THE BALL" LIFT IS DELIBERATELY GONE. It is the right IDEA and
        # the wrong MECHANISM: clipping a smooth analytic ellipse by displacing whichever
        # vertices happen to sit near it cannot produce a clean curve, and three attempts each
        # came out visibly lumpy -- the last at +630 triangles. A clean oval needs an edge loop
        # that FOLLOWS the ellipse, which means lofting the lid ring as explicit geometry, the
        # way the tail and the folded wing in this same file are built. Until that exists this
        # raises a smooth convex ring and leaves the visible eye circular, which is honest.
        _ = (cx, clearance)
        w = 1.0 - _smoothstep((d - 1.0) / (outer - 1.0))
        lift = height * w
        if lift <= 0.0:
            continue
        v.co.x += side * lift
        raised += 1

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    added = len(bm.faces) - before
    bm.to_mesh(me)
    me.update()
    bm.free()
    return {"faces_added": added, "verts_raised": raised,
            "aperture_y": round(ap_y, 5), "aperture_z": round(ap_z, 5),
            "aperture_ratio": round(ap_y / ap_z, 2), "lid_height": round(height, 5)}


def build_lid_collar(spec=KARASU):
    """The lid: an edge loop ON THE EYEBALL, bridged back to the head.

    ⚠ THE BRIDGE MUST NEVER CUT THROUGH THE EYEBALL (owner, 2026-08-28). Earlier versions could:
    with a tight band the straight run from the lid edge to the head descends STEEPER than the
    sphere's own surface does, so it dives back inside the ball and the lid clips the eye it is
    supposed to frame.

    ⚠ SO THE FIRST STEP LEAVES ALONG THE TANGENT, which makes the failure impossible rather than
    merely unlikely. A sphere is convex, so its tangent plane at any point lies entirely OUTSIDE
    it -- a bridge that departs tangentially cannot re-enter, at any width, for any bird. Only
    the second step bends down to the head, and by then it is already clear of the surface.
    The check at the end is belt and braces: it measures every generated vertex against the
    sphere and refuses to build a lid that intrudes.

    ⚠ AND THE WHOLE APERTURE MUST LIE ON THE VISIBLE CAP. The ball is sunk, so it only emerges
    from the head within some radius; an aperture drawn wider than that is BURIED, and then the
    visible edge is the ball's own emergence circle rather than the oval that was drawn. That is
    why the earlier ovals kept reading as circles with the sides chewed.

    THREE LOOPS per eye: on the ball, one tangent step out, then buried in the head.
    """
    if LAST_EYE is None:
        raise RuntimeError("eye_site() has not run")
    E, e = LAST_EYE, spec["eye"]
    r = E["r"]
    ap_y, ap_z = r * e["ap_y"], r * e["ap_z"]
    n = int(e["collar_segments"])
    w_front, w_rear = r * e["collar_w_front"], r * e["collar_w_rear"]
    w_vert = r * e["collar_w_vert"]
    sink = r * e["collar_sink"]
    lift = e["collar_lift"]
    R = r * (1.0 + lift)                       # the wrap sphere, concentric and strictly outside
    wraps, wrap_end = int(e["collar_wraps"]), e["collar_wrap_end"]
    body = bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]

    def band_width(th):
        """Ring width at this angle. theta 0 is toward the bill, +90 up, 180 aft.

        ⚠ A WEIGHTED MEAN, not a sum -- adding a vertical bonus to a horizontal base inflates the
        DIAGONALS past either, and the ring bulges at the corners and stops reading as a lid.
        """
        c, sn = math.cos(th), math.sin(th)
        wf, wr, wv = max(0.0, c), max(0.0, -c), abs(sn)
        total = wf + wr + wv
        return (wf * w_front + wr * w_rear + wv * w_vert) / total if total else w_front

    me = bpy.data.meshes.new("KarasuLids")
    ob = bpy.data.objects.new("KarasuLids", me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    worst = 1e9

    for sfx, side in (("R", 1.0), ("L", -1.0)):
        cx = E[sfx]
        n_loops = 2 + wraps
        rings = [[] for _ in range(n_loops)]
        for i in range(n):
            th = 2.0 * math.pi * i / n
            cth, sth = math.cos(th), math.sin(th)
            py, pz = ap_y * cth, ap_z * sth
            rho0 = math.hypot(py, pz)
            if rho0 >= r:
                raise RuntimeError("aperture is wider than the eyeball -- lower ap_y / ap_z")
            uy, uz = (py / rho0, pz / rho0) if rho0 > 1e-9 else (cth, sth)
            width = band_width(th)
            pts = []
            # 1. the visible lid EDGE, on the ball itself
            pts.append(Vector((math.sqrt(r * r - rho0 * rho0), py, pz)))
            # 2. wrap loops on the concentric sphere, out to the ball's silhouette
            rho_end = wrap_end * R
            for k in range(1, wraps + 1):
                rho = rho0 + (rho_end - rho0) * (k / wraps)
                pts.append(Vector((math.sqrt(max(0.0, R * R - rho * rho)), uy * rho, uz * rho)))
            # 3. the skirt, buried in the head -- past the silhouette, so no ball left to cut
            oy, oz = uy * (rho_end + width), uz * (rho_end + width)
            surf = body_surface_x(E["y"] + oy, E["z"] + oz, side, body)
            pts.append(Vector((surf - cx - sink, oy, oz)))
            for k, q in enumerate(pts):
                worst = min(worst, q.length)
                rings[k].append(bm.verts.new((side * (cx + q.x), E["y"] + q.y, E["z"] + q.z)))

        bm.verts.ensure_lookup_table()
        for A, B in zip(range(n_loops - 1), range(1, n_loops)):
            for i in range(n):
                j = (i + 1) % n
                quad = (rings[A][i], rings[A][j], rings[B][j], rings[B][i])
                bm.faces.new(quad if side > 0 else tuple(reversed(quad)))

    # ⚠ ASSERT IT, do not trust the argument. Every vertex must sit at or outside the sphere.
    if worst < r - 1e-6:
        bm.free()
        raise RuntimeError(f"lid intrudes into the eyeball: {worst:.5f} < r {r:.5f}")

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    grp = ob.vertex_groups.new(name="joint4")
    grp.add([v.index for v in me.vertices], 1.0, 'REPLACE')
    return {"verts": len(me.vertices), "tris": sum(len(p_.vertices) - 2 for p_ in me.polygons),
            "segments": n, "aperture_ratio": round(ap_y / ap_z, 2),
            "closest_vertex_to_eye_centre": round(worst, 5), "eye_radius": round(r, 5),
            "clears_eyeball_by": round(worst - r, 6),
            "aperture_vs_eye_front": round(ap_y / r, 2),
            "aperture_vs_eye_vert": round(ap_z / r, 2)}


def build_eye_mesh(spec=KARASU):
    """The eyeballs, as their OWN MeshPart -- the same shape the wings already are.

    ⚠ A `Part` BALL WAS TRIED FIRST AND WAS THE WRONG CALL. It was chosen for a trade that does
    not exist: "tunable in Studio without a Blender round trip". Measured in Studio -- a MeshPart
    keeps `Color`, `Material` AND `Reflectance` at runtime, every dial the ball was supposed to
    buy, and it also has `TextureID`, which a Part does not. So the ball gave up the iris and gave
    up being VISIBLE WHILE AUTHORING, and bought nothing back. Nor is it meaningfully cheaper:
    both are one Instance per eye, and instance count is what costs.

    Owner ruling 2026-08-28, and it generalises past this bird: build and conditionally approve in
    BLENDER, then play and give final approval in Studio. Manual imports are not a burden worth
    designing around, and Blender is where control over the outcome actually lives.

    ⚠ ONE MESH, BOTH EYES, sharing the body's origin exactly as the wings do -- so it is one extra
    part per bird rather than two, and `PivotOffset` seats it with no fudge.
    """
    if LAST_EYE is None:
        raise RuntimeError("eye_site() has not run")
    E = LAST_EYE
    me = bpy.data.meshes.new("KarasuEyes")
    ob = bpy.data.objects.new("KarasuEyes", me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    # ⚠ NOT `bird_familiar._eyes`, and that is the whole fix. It builds both eyes by MIRRORING a
    # single x, which is correct only on a symmetric head -- and measured, this one stands 0.0514
    # proud on the right against 0.0610 on the left. Same sphere resolution as the uguisu's (8x6)
    # so the two birds still read as one family; only the placement is per side.
    for sfx, side in (("R", 1.0), ("L", -1.0)):
        bmesh.ops.create_uvsphere(
            bm, u_segments=8, v_segments=6, radius=E["r"],
            matrix=Matrix.Translation(Vector((side * E[sfx], E["y"], E["z"]))))
    bm.to_mesh(me)
    bm.free()
    # ⚠ SHADE IT SMOOTH, AND THAT IS THE WHOLE FIX FOR THE FACETING. Owner: "can't it simply be a
    # sphere? Or does that not survive the export to Studio?" It can, and it does. The visible
    # faceting was never polygon count -- `create_uvsphere` makes FLAT faces, and a flat-shaded
    # 8x6 sphere shows every one of them. The body is 87.7% smooth-shaded and reads smooth in
    # Studio today, which is the proof that it survives: `export()` writes
    # `mesh_smooth_type='FACE'`, i.e. per-face smoothing groups, so a smooth face exports smooth.
    # ⚠ Do NOT answer faceting by raising `u_segments`/`v_segments` here. That spends triangles on
    # a problem that costs one flag, and the uguisu's 8x6 is deliberately matched.
    for poly in me.polygons:
        poly.use_smooth = True
    # ⚠ WEIGHT IT TO THE HEAD -- this group is what makes the eyes follow the head, and it is
    # the ONLY bone they need. `run()` gives this object the armature modifier that turns the
    # group into a skin deformer; the group alone does nothing, which is exactly how these
    # shipped once as a static mesh with zero bones. One bone, not two: `eye_R`/`eye_L` carry a
    # position for a runtime Part that the owner retired in favour of this mesh, and a bone that
    # deforms no vertex is stripped by Roblox's importer regardless.
    g = ob.vertex_groups.new(name="joint4")
    g.add([v.index for v in me.vertices], 1.0, 'REPLACE')
    return {"verts": len(me.vertices), "tris": sum(len(p_.vertices) - 2 for p_ in me.polygons),
            "x_right": E["R"], "x_left": E["L"], "y": E["y"], "z": E["z"], "r": E["r"]}


def plate_margins(spec=KARASU):
    """Top edge of each folded-wing station against the body's own zmax there.

    ⚠ NEGATIVE MARGIN IS A SHIPPED BUG WITH A NAME. When the plate's top edge reached the body's
    zmax the left and right plates met along the spine and the bird grew a Y-shaped crease down
    its back, plainly visible from above. The `plate` z stations are TYPED; the body under them is
    not, so anything that reshapes the body has to re-read this table rather than assume it.
    """
    # The body is renamed to KarasuBody by `join_all`, so accept either -- the same lookup
    # `body_profile` and `body_surface_x` already use. Called after `run()` the numbers are in the
    # normalised frame; the check that matters is the one either side of `reshape_body`.
    o = bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]
    co = np.array([v.co[:] for v in o.data.vertices])
    rows = []
    for st in spec["wing_folded"]["plate"]:
        y, zc, hh = st[0], st[1], st[2]
        # ⚠ A 4-TUPLE MEANS "PAST THE RUMP" -- the station carries an explicit x precisely because
        # there is no body left to raycast there, so it lies over the TAIL BASE and has no margin
        # to measure. Reporting one anyway produced a -0.032 that looks like the spine-crease bug
        # and is not: the nearest body verts are 0.05 forward of the station.
        if len(st) > 3:
            rows.append({"y": y, "top_edge": round(zc + hh, 3), "past_rump": True})
            continue
        m = np.abs(co[:, 1] - y) < 0.075
        zmax = float(co[m][:, 2].max()) if m.any() else None
        rows.append({"y": y, "top_edge": round(zc + hh, 3),
                     "body_zmax": None if zmax is None else round(zmax, 3),
                     "margin": None if zmax is None else round(zmax - (zc + hh), 3)})
    return rows


def body_half_width(y, z, zwin=0.09):
    """How wide is the body at this station? The folded wing stands off THIS, not off a typed
    constant -- the standing 'derive from what it touches' rule. The uguisu's x_offsets were
    hand-tuned and its own comment warns that a few thousandths either way buries the plate in
    the flank or steps it off the silhouette."""
    me = bpy.data.objects[BODY_OBJ].data
    co = np.array([v.co[:] for v in me.vertices])
    m = (np.abs(co[:, 1] - y) < 0.075) & (np.abs(co[:, 2] - z) < zwin)
    if not m.any():
        m = np.abs(co[:, 1] - y) < 0.13
    return float(np.abs(co[m][:, 0]).max()) if m.any() else 0.10


def build_tail(spec=KARASU):
    """A SOLID wedge tail -- ONE membrane, not a stack of blades.

    ⚠ A TAIL IS NOT A COMB EITHER. The first pass built it the way the uguisu's is built, from
    seven overlapping graduated blades, and at 1.64 studs the blunt ends of those blades stepped
    visibly against each other: a staircase, not feathers. That is the same failure spread_wing
    records for a wing built from separate radiating vanes, and it has the same fix -- one
    continuous surface whose OUTLINE does the identifying. The uguisu gets away with blades
    because it is a third the size and the steps fall inside a texel.

    The outline is what says "crow": a WEDGE. An uguisu's tail is rounded, a crow's comes to a
    blunt point down the middle, and that difference survives arena distance where colour does
    not -- both birds are, at distance, just a dark bird.

    The tail is SPLAYED NARROW on purpose. It is seen PERCHED ~90% of the time, and a fanned tail
    is a flight spread; the uguisu's v3 fanned and read like a peacock's.
    """
    t = spec["tail"]
    droop = math.radians(t["droop_deg"])
    L = t["length"]
    COLS, ROWS = 12, 6
    bm = bmesh.new()

    def hw_at(u):
        return (t["root_hw"] + (t["mid_hw"] - t["root_hw"]) * (u / 0.5) if u <= 0.5
                else t["mid_hw"] + (t["tip_hw"] - t["mid_hw"]) * ((u - 0.5) / 0.5))

    grid = []
    for j in range(COLS + 1):
        v = -1.0 + 2.0 * j / COLS                       # across the tail
        # THE WEDGE: outer rectrices run shorter than the central pair.
        vlen = L * (1.0 - t["wedge"] * abs(v) ** 1.6)
        # ...with a shallow scallop per rectrix, so the tip reads as feather ends rather than as
        # one cut edge -- detail in the OUTLINE, where it cannot band or seam.
        vlen -= t["scallop"] * (0.5 - 0.5 * math.cos(v * t["rectrices"] * math.pi))
        col = []
        for i in range(ROWS + 1):
            u = i / ROWS                                # along the tail
            d = u * vlen
            x = v * hw_at(u)
            y = t["root_y"] - d * math.cos(droop)
            # the tail's own droop, plus a slight dihedral so it is not a dead-flat plank
            z = t["root_z"] - d * math.sin(droop) - abs(v) * t["dihedral"] * u
            th = (t["thickness"] * (1.0 - 0.45 * u)) * 0.5
            col.append((x, y, z, th))
        grid.append(col)
    top = [[bm.verts.new((x, y, z + th)) for (x, y, z, th) in c] for c in grid]
    bot = [[bm.verts.new((x, y, z - th)) for (x, y, z, th) in c] for c in grid]
    for j in range(COLS):
        for i in range(ROWS):
            bm.faces.new((top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i]))
            bm.faces.new((bot[j + 1][i], bot[j + 1][i + 1], bot[j][i + 1], bot[j][i]))
        bm.faces.new((top[j][ROWS], bot[j][ROWS], bot[j + 1][ROWS], top[j + 1][ROWS]))
        bm.faces.new((bot[j][0], top[j][0], top[j + 1][0], bot[j + 1][0]))
    for j, sgn in ((0, 1), (COLS, -1)):
        for i in range(ROWS):
            a, b = top[j][i], top[j][i + 1]
            c, d = bot[j][i], bot[j][i + 1]
            bm.faces.new((a, b, d, c) if sgn > 0 else (c, d, b, a))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("KarasuTail")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new("KarasuTail", me)
    bpy.context.scene.collection.objects.link(ob)
    return {"object": "KarasuTail", "verts": len(me.vertices),
            "tris": sum(len(p.vertices) - 2 for p in me.polygons)}


def body_surface_x(y, z, side, obj=None):
    """Exactly how far out is the body's skin at this point? Raycast, don't guess.

    ⚠ Sampling nearby VERTICES instead is what made the first folded wing stand off the flank
    as two flat fins with daylight behind them (visible from directly above). A 555-vertex body
    is far too sparse for a nearest-vertex probe, and the plate then sits at a constant x while
    the body underneath it is round.
    """
    obj = obj or bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]
    ok, loc, _, _ = obj.ray_cast(Vector((side * 3.0, y, z)), Vector((-side, 0.0, 0.0)))
    if ok:
        return abs(loc.x)
    me = obj.data
    co = np.array([v.co[:] for v in me.vertices])
    d = (co[:, 1] - y) ** 2 + (co[:, 2] - z) ** 2
    return float(abs(co[int(np.argmin(d)), 0]))


def build_folded_wings(spec=KARASU):
    """The folded wing, SHRINK-WRAPPED onto the flank rather than parked beside it.

    ⚠ A FOLDED WING IS MOSTLY A SMOOTH SURFACE CONTINUOUS WITH THE BODY. The uguisu learned this
    the expensive way -- v4 modelled three full-length plates and they read as blocks bolted to
    the side. The feathers only become individually visible in the last third, where the
    primaries overshoot the rump and lie across the tail base, and that overshoot is the
    recognisable part.

    Three things make it read as part of the bird rather than an attachment:
      1. every vertex takes its x from a RAYCAST against the body, so the plate follows the
         flank's curvature instead of standing at a constant offset from a round surface. A
         nearest-VERTEX probe is not good enough -- a 555-vertex body is far too sparse, and the
         first pass built two flat fins with daylight visible behind them from directly above;
      2. the standoff TAPERS TO ZERO at the plate's top, bottom and leading edges, so those edges
         die into the flank and only the trailing edge -- where a wing's edge belongs -- breaks
         the silhouette. That is the standing "flush outside edges" rule;
      3. it is ONE surface tapering to a point past the rump, not a covert plus loose primaries.

    ⚠ THE PLATE IS DELIBERATELY LOW-RELIEF, so most of the wing's read has to come from the BAKE,
    not from here. That is not a shortcut: the uguisu found that with one flat colour over the
    whole back the modelled wing edge vanishes anyway, and that a panel a shade darker than the
    mantle plus a line along the covert edge is what makes a wing read as a wing at distance.
    """
    w = spec["wing_folded"]
    stand = w["standoff"]
    half_t = w["thickness"] * 0.5
    ROWS = 7                     # 5 put a visible ridge down the middle of the plate, because
                                 # the standoff bump peaked on a single row of vertices
    N = w["cols"]
    bm = bmesh.new()

    src = w["plate"]

    def station(f):
        """Resample the station list at f in [0,1]. Without this the plate's outline reads as
        facets against the smooth body it sits on."""
        t = f * (len(src) - 1)
        i = min(int(t), len(src) - 2)
        g = t - i
        a, b = src[i], src[i + 1]
        y = a[0] + (b[0] - a[0]) * g
        zc = a[1] + (b[1] - a[1]) * g
        hh = a[2] + (b[2] - a[2]) * g
        xa = a[3] if len(a) > 3 else None
        xb = b[3] if len(b) > 3 else None
        if xa is None and xb is None:
            fx = None
        elif xa is None:
            fx = xb          # first station past the body: hand it the explicit value
        elif xb is None:
            fx = xa
        else:
            fx = xa + (xb - xa) * g
        return y, zc, hh, fx

    for side in (1.0, -1.0):
        cols_out, cols_in = [], []
        for c in range(N + 1):
            f = c / N
            y, zc, hh, fx = station(f)
            along = math.sin(math.pi * min(1.0, max(0.0, f * 1.35))) if f < 0.2 else 1.0
            out_col, in_col = [], []
            for k in range(ROWS):
                r = k / (ROWS - 1.0)
                z = zc + hh * (1.0 - 2.0 * r)
                bump = math.sin(math.pi * r)     # 0 at the plate's top and bottom edges
                x = fx if fx is not None else \
                    body_surface_x(y, z, side) + stand * bump * along
                out_col.append(bm.verts.new((side * (x + half_t), y, z)))
                in_col.append(bm.verts.new((side * (x - half_t), y, z)))
            cols_out.append(out_col)
            cols_in.append(in_col)
        for i in range(N):
            for k in range(ROWS - 1):
                bm.faces.new((cols_out[i][k], cols_out[i][k + 1],
                              cols_out[i + 1][k + 1], cols_out[i + 1][k]))
                bm.faces.new((cols_in[i + 1][k], cols_in[i + 1][k + 1],
                              cols_in[i][k + 1], cols_in[i][k]))
            bm.faces.new((cols_out[i][0], cols_out[i + 1][0], cols_in[i + 1][0], cols_in[i][0]))
            bm.faces.new((cols_in[i][-1], cols_in[i + 1][-1],
                          cols_out[i + 1][-1], cols_out[i][-1]))
        for idx in (0, -1):
            for k in range(ROWS - 1):
                bm.faces.new((cols_out[idx][k], cols_out[idx][k + 1],
                              cols_in[idx][k + 1], cols_in[idx][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("KarasuFolded")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True     # a continuation of the body's surface, not a blade
    ob = bpy.data.objects.new("KarasuFolded", me)
    bpy.context.scene.collection.objects.link(ob)
    return {"object": "KarasuFolded", "verts": len(me.vertices),
            "tris": sum(len(p.vertices) - 2 for p in me.polygons)}


def build_spread_wings(spec=KARASU):
    """Both spread wings as ONE mesh, origin shared with the body.

    Adapted from spread_wing.py, whose two hard-won rulings both still hold and are both about
    NOT adding detail on top of a sufficient solution:
      * a wing is not a comb -- separate radiating feathers show daylight between them, because
        the vanes fan apart faster than they are wide. One continuous membrane, scalloped.
      * no separate finger primaries -- they read as detached shards.
    What is species-specific is that a crow's slots are DEEP, so the scallop grows from 0.012 at
    the wrist to 0.052 at the tip instead of staying uniform. Silhouette, not seams.
    """
    w = spec["wing_spread"]
    plan = w["plan"]
    bm = bmesh.new()

    def plan_at(u):
        for i in range(len(plan) - 1):
            a, b = plan[i], plan[i + 1]
            if a[0] <= u <= b[0]:
                f = (u - a[0]) / max(1e-6, b[0] - a[0])
                return tuple(a[k] + (b[k] - a[k]) * f for k in (1, 2, 3))
        return plan[-1][1], plan[-1][2], plan[-1][3]

    # ⚠ 40, not 26. The taper lives in the last 12% of span, and at 26 columns there were only
    # three samples in it — the convergence read as a chamfer rather than a round. Wing triangles
    # rise from 856 to roughly 1.3k, which is nothing for a part that exists only in flight.
    COLS, ROWS = 40, 4
    for side in (1.0, -1.0):
        cols = []
        for c in range(COLS + 1):
            u = c / COLS
            lead, trail, zr = plan_at(u)
            cs = w.get("chord_scale", 1.0)
            lead, trail = lead * cs, trail * cs
            x = side * (w["root_gap"] + u * w["span"])
            phase = u * w["n_scallop"] * math.pi
            depth = w["scallop_root"] + (w["scallop_tip"] - w["scallop_root"]) * (u ** 1.6)
            # ⚠ CLAMP THE NOTCH TO THE LOCAL CHORD. The scallop DEEPENS toward the tip (0.052 at
            # the end) while the tapered chord NARROWS to 0.048 — unclamped, the notch is 108% of
            # the chord and the trailing edge crosses the leading one, turning the last feather
            # into inverted geometry. The two features were designed apart and only conflict now
            # that the tip actually narrows.
            depth = min(depth, abs(trail - lead) * 0.35)
            trail += (0.5 - 0.5 * math.cos(2.0 * phase)) * depth
            base_z = w["root_z"] + zr + w["aoa_rise"] * 0.5 * \
                (1.0 - (1.0 - w["aoa_washout"]) * u)
            # ⚠ TILT SCALES WITH THE LOCAL CHORD — see spread_wing.py for the full reasoning.
            # `aoa_rise` is an absolute vertical offset sized against the untapered tip chord; once
            # the tip narrows, the same rise over a shorter chord steepens the angle and the tip
            # turns down. Here it was worse than the uguisu: 8 degrees becoming 19.
            chord = abs(trail - lead)
            aoa_scale = min(1.0, chord / w.get("aoa_ref_chord", chord))
            rows = []
            for k in range(ROWS):
                f = k / (ROWS - 1.0)
                y = w["root_y"] + lead + (trail - lead) * f
                tilt = (0.5 - f) * w["aoa_rise"] * (1.0 - (1.0 - w["aoa_washout"]) * u) * aoa_scale
                camber = math.sin(math.pi * min(1.0, f * 1.4)) * 0.012 * (1.0 - 0.6 * u)
                rows.append((x, y, base_z + tilt + camber))
            cols.append(rows)
        t = w["thickness"]
        top = [[bm.verts.new((x, y, z + t)) for (x, y, z) in r] for r in cols]
        bot = [[bm.verts.new((x, y, z - t)) for (x, y, z) in r] for r in cols]
        for i in range(COLS):
            for k in range(ROWS - 1):
                bm.faces.new((top[i][k], top[i][k + 1], top[i + 1][k + 1], top[i + 1][k]))
                bm.faces.new((bot[i + 1][k], bot[i + 1][k + 1], bot[i][k + 1], bot[i][k]))
            bm.faces.new((top[i][0], top[i + 1][0], bot[i + 1][0], bot[i][0]))
            bm.faces.new((bot[i][-1], bot[i + 1][-1], top[i + 1][-1], top[i][-1]))
        for idx in (0, -1):
            for k in range(ROWS - 1):
                bm.faces.new((top[idx][k], top[idx][k + 1], bot[idx][k + 1], bot[idx][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    old = bpy.data.objects.get("KarasuWings")
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new("KarasuWings")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new("KarasuWings", me)
    bpy.context.scene.collection.objects.link(ob)
    return {"object": "KarasuWings", "verts": len(me.vertices),
            "tris": sum(len(p.vertices) - 2 for p in me.polygons),
            "dims": [round(d, 4) for d in ob.dimensions]}




def simplify_feet(spec=KARASU):
    """The vendor's feet are 920 triangles EACH against a 1,096-triangle body -- more geometry in
    the toes than in the whole bird. Decimate before joining."""
    out = {}
    for n in (FOOT_L, FOOT_R):
        o = bpy.data.objects[n]
        before = sum(len(p.vertices) - 2 for p in o.data.polygons)
        m = o.modifiers.new("dec", 'DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = min(1.0, spec["feet_target_tris"] / max(1, before))
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        o.modifiers.remove(m)
        old = o.data
        o.data = me
        bpy.data.meshes.remove(old)
        out[n] = {"tris_before": before,
                  "tris_after": sum(len(p.vertices) - 2 for p in me.polygons)}
    return out


# ---------------------------------------------------------------------------------------
# UV — new geometry has to be given atlas space that the vendor unwrap is not already using
# ---------------------------------------------------------------------------------------

def _bake_mod():
    import importlib.util
    import os
    import sys
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
        "/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/blender"
    if here not in sys.path:
        sys.path.insert(0, here)
    spec = importlib.util.spec_from_file_location(
        "bake_bird_texture", os.path.join(here, "bake_bird_texture.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class UVAllocator:
    """Hands out free rectangles in the body's atlas, and REMEMBERS what it handed out.

    ⚠ HARDCODING A REGION SILENTLY CORRUPTED THE UGUISU. The spread wing was given a fixed patch
    at u,v 0.06..0.36 without checking the vendor unwrap; that patch was 97.9% occupied, so the
    wing bake painted straight over one flank of the torso. It read as texel bleed and was not --
    bleed is symmetric, and this was on one side only. `find_free_uv_block` exists for that
    reason; this wrapper adds the other half of it, which is that TWO allocations must not
    collide with each other either.
    """

    def __init__(self, mesh, res=512):
        self.bake = _bake_mod()
        self.res = res
        self.occ = self.bake.uv_occupancy(mesh, res)
        self.shrunk = {}

    def take(self, w, h, name=""):
        """Ask for a rectangle; SHRINK rather than fail, and say so.

        The vendor unwrap already claims 41% of the atlas in fragments, so a request that does
        not fit is normal rather than exceptional. Refusing outright stops the whole bake, and
        overlapping is the corruption this class exists to prevent -- so it steps down instead,
        and records what it actually gave. ⚠ The record matters: a silently smaller block is a
        silent resolution loss, and "no silent caps" is a standing rule here.
        """
        I = np.zeros((self.res + 1, self.res + 1), dtype=np.int32)
        I[1:, 1:] = np.cumsum(np.cumsum(self.occ.astype(np.int32), axis=0), axis=1)
        for shrink in (1.0, 0.88, 0.78, 0.68, 0.58, 0.5, 0.42, 0.34):
            bw, bh = int(w * shrink * self.res), int(h * shrink * self.res)
            if bw < 8 or bh < 8:
                break
            for b in range(0, self.res - bh, 2):
                for a in range(0, self.res - bw, 2):
                    c, d = a + bw, b + bh
                    if I[d, c] - I[b, c] - I[d, a] + I[b, a] == 0:
                        pad = 2
                        self.occ[max(0, b - pad):d + pad, max(0, a - pad):c + pad] = True
                        if shrink < 1.0:
                            self.shrunk[name or f"{w}x{h}"] = round(shrink, 2)
                        return (a / self.res, b / self.res, bw / self.res, bh / self.res)
        raise RuntimeError(f"no free block for {name} even at a third of {w}x{h}")


def thicken_degenerate_uvs(me, texels=3.0, res=1024):
    """Give every face a NON-ZERO UV footprint, in place, without moving it in the atlas.

    ⚠ `_project_faces` unwraps a whole piece down ONE axis, so any face lying edge-on to that axis
    collapses to a LINE in UV -- zero area. Measured on the karasu: 60 body faces, all of them added
    geometry, several exactly 0.0 texels tall. A zero-area face samples a single texel row, so it
    renders as a streak or as untextured, showing the MeshPart's flat `Color` instead. Owner saw it
    as a bright patch on the belly and legs.

    ⚠ THIS THICKENS RATHER THAN RE-PROJECTS, and the reason is that the ColorMap is a hand-graded
    file we cannot regenerate (`COLORMAP_AUTHORITY`). Re-projecting these faces into a fresh atlas
    block would move them somewhere that file has no paint for them. Thickening keeps each face
    exactly where it already is and merely gives it area, so it samples its OWN piece's existing
    paint -- which at this scale is near-uniform, so a few texels is enough and the colour is right.

    The footprint is built in the face's own plane, so the little triangle keeps the face's shape
    and winding rather than being an arbitrary blob.
    """
    uvl = me.uv_layers[0].data
    lim = 1.0 / res
    fixed = 0
    for poly in me.polygons:
        us = [uvl[li].uv[0] for li in poly.loop_indices]
        vs = [uvl[li].uv[1] for li in poly.loop_indices]
        if (max(us) - min(us)) >= lim and (max(vs) - min(vs)) >= lim:
            continue
        cu, cv = sum(us) / len(us), sum(vs) / len(vs)
        n = Vector(poly.normal)
        if n.length < 1e-9:
            continue
        # an orthonormal basis IN the face's plane, so the footprint mirrors the face's own shape
        t1 = Vector((0.0, 0.0, 1.0)).cross(n)
        if t1.length < 1e-6:
            t1 = Vector((1.0, 0.0, 0.0)).cross(n)
        t1.normalize()
        # ⚠ `Vector.normalize()` normalises IN PLACE and returns None -- assigning its result
        # gives you None, and the error surfaces later as "invalid 'other' arg" on the dot product.
        t2 = n.cross(t1)
        t2.normalize()
        ctr = Vector(poly.center)
        loc = [((me.vertices[me.loops[li].vertex_index].co - ctr).dot(t1),
                (me.vertices[me.loops[li].vertex_index].co - ctr).dot(t2))
               for li in poly.loop_indices]
        # ⚠ NORMALISE THE TWO AXES INDEPENDENTLY. Preserving the face's aspect ratio sounds
        # respectful and defeats the purpose: a face that is a thin sliver in 3D stays a thin
        # sliver in UV, and seven of them came back still under a texel tall. These faces are
        # degenerate by definition, so an isotropic footprint is the correct answer -- shape
        # fidelity is worthless on a face that currently has no area at all.
        sx = max(max(abs(x) for x, _ in loc), 1e-9)
        sy = max(max(abs(y) for _, y in loc), 1e-9)
        r = texels / res
        for li, (x, y) in zip(poly.loop_indices, loc):
            uvl[li].uv = (cu + r * x / sx, cv + r * y / sy)
        fixed += 1
    return {"thickened": fixed, "texels": texels}


def _project_faces(me, face_idx, axis, block, split_shells=True):
    """Planar-project a set of faces down `axis` and fit them into `block` = (u0, v0, w, h).

    ⚠ SPLIT THE TWO SHELLS OR THEY OVERPAINT EACH OTHER. Every piece built here is a closed
    two-sided plate -- a tail, a folded-wing plate, a wing membrane -- and a planar projection
    collapses its top and bottom onto the same texels. The bake then paints both into one place
    and whichever triangle rasterises last wins, which showed up as pale rectangular patches on
    the finished bird where the plate's INWARD-facing shell had overwritten its outward-facing
    one (the two get opposite countershading, so they are not the same colour). spread_wing.py
    already carried this rule for the uguisu's wing -- "upper and lower shells split the region's
    height, with a gap so bilinear sampling cannot pull one into the other" -- and it applies to
    every plate, not just that one.
    """
    uvl = me.uv_layers[0].data
    a, b = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[axis]
    face_idx = list(face_idx)
    pts = [me.vertices[me.loops[li].vertex_index].co for fi in face_idx
           for li in me.polygons[fi].loop_indices]
    if not pts:
        return
    amin, amax = min(p[a] for p in pts), max(p[a] for p in pts)
    bmin, bmax = min(p[b] for p in pts), max(p[b] for p in pts)
    u0, v0, w, h = block
    inset = 0.05
    half = h * 0.46
    gap = h * 0.08
    for fi in face_idx:
        poly = me.polygons[fi]
        if split_shells:
            # which way does this face look along the projection axis?
            outward = poly.normal[axis] >= 0.0
            if axis == 0:                      # flank plates: "outward" means away from the spine
                outward = (poly.normal[0] >= 0.0) == (poly.center[0] >= 0.0)
            vbase = v0 if outward else v0 + half + gap
            vspan = half
        else:
            vbase, vspan = v0, h
        for li in poly.loop_indices:
            c = me.vertices[me.loops[li].vertex_index].co
            fu = (c[a] - amin) / max(1e-9, amax - amin)
            fv = (c[b] - bmin) / max(1e-9, bmax - bmin)
            uvl[li].uv = (u0 + w * (inset + fu * (1 - 2 * inset)),
                          vbase + vspan * (inset + fv * (1 - 2 * inset)))


# ---------------------------------------------------------------------------------------
# JOIN — a Roblox skinned MeshPart deforms as ONE mesh
# ---------------------------------------------------------------------------------------

def _append(bm, uv_dst, dv_dst, src_obj, group_names):
    """Copy src_obj's mesh into bm, carrying UVs and vertex weights. Returns the new faces."""
    sme = src_obj.data
    sbm = bmesh.new()
    sbm.from_mesh(sme)
    uv_src = sbm.loops.layers.uv.verify()
    dv_src = sbm.verts.layers.deform.verify()
    src_groups = {g.index: g.name for g in src_obj.vertex_groups}
    vmap = {}
    new_faces = []
    for f in sbm.faces:
        nv = []
        for v in f.verts:
            if v not in vmap:
                nvv = bm.verts.new(v.co)
                vmap[v] = nvv
                for gi, wt in v[dv_src].items():
                    name = src_groups.get(gi)
                    if name in group_names:
                        nvv[dv_dst][group_names[name]] = wt
            nv.append(vmap[v])
        try:
            nf = bm.faces.new(nv)
        except ValueError:
            continue
        nf.smooth = f.smooth
        for ls, ld in zip(f.loops, nf.loops):
            ld[uv_dst].uv = ls[uv_src].uv
        new_faces.append(nf)
    sbm.free()
    return new_faces


# ---------------------------------------------------------------------------------------
# RIG
# ---------------------------------------------------------------------------------------

def _edit_armature(arm, fn):
    """Enter edit mode on `arm` and run fn(edit_bones).

    ⚠ Under the Blender MCP `bpy.ops.object.mode_set` fails with "Context missing active object"
    -- the same defect family as `export_scene.fbx(use_selection=True)` failing there, and as the
    FBX IMPORTER dying on an armature in an empty scene. All three want a real window. Wrap the
    call in a temp_override carrying one.
    """
    win = bpy.context.window_manager.windows[0]
    scr = win.screen
    area = next((a for a in scr.areas if a.type == 'VIEW_3D'), scr.areas[0])
    ctx = dict(window=win, screen=scr, area=area, region=area.regions[-1],
               scene=bpy.context.scene, view_layer=bpy.context.view_layer,
               active_object=arm, object=arm, selected_objects=[arm],
               selected_editable_objects=[arm])
    bpy.context.view_layer.objects.active = arm
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.mode_set(mode='EDIT')
        try:
            out = fn(arm.data.edit_bones)
        finally:
            bpy.ops.object.mode_set(mode='OBJECT')
    return out


def rebuild_rig(spec=KARASU):
    """Rename the vendor's QuickRig skeleton to the names BirdController drives, drop its wing
    chain, and build ours."""
    arm = bpy.data.objects[VENDOR_ARM]
    arm.name = "Karasu_Rig"
    arm.data.name = "Karasu_Rig"

    # ⚠ TWO-PASS RENAME. The vendor's TAIL bone is named `joint1`; so is the ROOT's target name.
    # A single pass renames Hips->joint1 onto a live `joint1`, Blender silently makes it
    # `joint1.001`, and the root the controller looks up is then the tail.
    def _rename(ebs):
        for src in list(BONE_MAP):
            if src in ebs:
                ebs[src].name = "__tmp__" + BONE_MAP[src]
        for src, dst in BONE_MAP.items():
            b = ebs.get("__tmp__" + dst)
            if b:
                b.name = dst
        for n in WING_BONES_VENDOR:
            if n in ebs:
                ebs.remove(ebs[n])
        return sorted(b.name for b in ebs)
    renamed = _edit_armature(arm, _rename)

    # vertex groups do NOT follow a bone rename
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        for src, dst in BONE_MAP.items():
            g = o.vertex_groups.get(src)
            if g:
                g.name = dst
        for n in WING_BONES_VENDOR:
            g = o.vertex_groups.get(n)
            if g:
                o.vertex_groups.remove(g)

    wings = bpy.data.objects.get("KarasuWings")
    xs = [v.co.x for v in wings.data.vertices]
    ys = [v.co.y for v in wings.data.vertices]
    zs = [v.co.z for v in wings.data.vertices]
    reach = max(xs)
    # Same proportions the uguisu shipped: the bone pair covers 88% of the wing's outer reach,
    # starting a little off centre, hinged at the halfway point of that run.
    x0 = reach * 0.043
    seg = (reach * 0.88 - x0) * 0.5
    by = max(ys) - 0.15 * (max(ys) - min(ys))       # near the LEADING edge, as the uguisu's is
    bz = (max(zs) + min(zs)) * 0.5

    def _wings(ebs):
        for n in ("wing_R", "wrist_R", "wing_L", "wrist_L"):
            if n in ebs:
                ebs.remove(ebs[n])
        made = {}
        # ⚠ THE EYE BONES CARRY A POSITION, NOT A DEFORMATION. Nothing is weighted to them and
        # nothing ever should be: they exist so the eye's place travels INSIDE the asset, where
        # `BirdController` can read it off `Bone.TransformedWorldCFrame` and park a ball there.
        # Parented to the head, so the eyes follow every head turn and check with no extra code.
        # ⚠ They must stay DEFORM bones despite deforming nothing -- `export()` passes
        # `use_armature_deform_only=True`, which silently drops any bone that is not.
        if LAST_EYE:
            E = LAST_EYE
            for side, sfx in ((1.0, "R"), (-1.0, "L")):
                if ("eye_" + sfx) in ebs:
                    ebs.remove(ebs["eye_" + sfx])
                b = ebs.new("eye_" + sfx)
                # ⚠ PER SIDE, matching the mesh. A mirrored x puts one bone inside the skull.
                ex, ey, ez, er = E[sfx], E["y"], E["z"], E["r"]
                b.head = Vector((side * ex, ey, ez))
                # The tail points outboard and is one radius long. ⚠ THE LENGTH DOES NOT SURVIVE
                # IMPORT -- a Roblox `Bone` is an Attachment, a POINT with an orientation, and has
                # no notion of a tail. So the radius cannot ride along here and lives on
                # `BirdSpecies` instead; what this direction buys is the bone's ORIENTATION, which
                # does survive, and which says which way is outboard.
                b.tail = Vector((side * (ex + er), ey, ez))
                b.parent = ebs["joint4"]
                b.use_connect = False
                b.use_deform = True
                made["eye_" + sfx] = True
        for side, sfx in ((1.0, "R"), (-1.0, "L")):
            w = ebs.new("wing_" + sfx)
            w.head = Vector((side * x0, by, bz))
            w.tail = Vector((side * (x0 + seg), by, bz))
            w.parent = ebs["joint1"]
            w.use_connect = False
            # ⚠ THE ROLL IS THE WHOLE POINT. BirdController's beat rotates about the bone's local
            # X (vertical travel) and its fold about local Z (fore-and-aft sweep), and it relies
            # on measured facts about which of those MIRRORS between wings. Both only hold if
            # local Z is world +Z, which is what align_roll pins here.
            w.align_roll(Vector((0.0, 0.0, 1.0)))
            r = ebs.new("wrist_" + sfx)
            r.head = w.tail.copy()
            r.tail = Vector((side * (x0 + 2 * seg), by, bz))
            r.parent = w
            r.use_connect = True
            r.align_roll(Vector((0.0, 0.0, 1.0)))
            made["wing_" + sfx] = list(w.head) + list(w.tail)
        return made
    made = _edit_armature(arm, _wings)
    # ⚠ ASSERT THE ROSTER. `BirdController` looks these up BY NAME, and a missing one fails
    # SILENTLY at runtime -- no error, just a familiar with a jaw that will not open.
    #
    # ⚠ EVERY NAME HERE MUST DEFORM SOMETHING, which is why `eye_R`/`eye_L` are NOT listed even
    # though the rig still builds them. Roblox strips any bone that influences no vertex, so a
    # position-only bone cannot reach the game however carefully it is exported -- listing one
    # here would assert a guarantee this script has no power to make. The eyes are placed by
    # CFraming the `KarasuEyes` mesh off the BODY's joint4; the two eye bones are vestigial and
    # can go the next time the rig is rebuilt. A session lost two commits and two import cycles
    # to fighting for them.
    required = ("joint1", "joint3", "joint4", "joint8", "joint12", "joint25",
                "wing_R", "wing_L", "wrist_R", "wrist_L")
    have = {b.name for b in arm.data.bones}
    missing = [n for n in required if n not in have]
    if missing:
        raise RuntimeError(f"rig is missing bones BirdController drives: {missing}")
    return {"bones": renamed, "wing_bones": made,
            "total": len(arm.data.bones), "required_present": len(required)}


def weight_to_nearest(obj, vert_idx, bone_names, arm=None):
    """Bind a run of new vertices rigidly to whichever of `bone_names` is closest.

    Rigid rather than blended on purpose: a tail feather, a folded-wing plate and a spread-wing
    membrane are stiff appendages, and a smooth falloff across them only produces shearing.
    """
    arm = arm or bpy.data.objects["Karasu_Rig"]
    segs = []
    for n in bone_names:
        b = arm.data.bones.get(n)
        if b:
            segs.append((n, Vector(b.head_local), Vector(b.tail_local)))
    if not segs:
        return {}
    groups = {}
    for n, _, _ in segs:
        groups[n] = obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n)
    hits = {n: 0 for n, _, _ in segs}
    for vi in vert_idx:
        p = obj.data.vertices[vi].co
        best, bestd = None, 1e18
        for n, h, t in segs:
            d = t - h
            L2 = d.dot(d)
            u = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, (p - h).dot(d) / L2))
            dist = (p - (h + d * u)).length
            if dist < bestd:
                best, bestd = n, dist
        groups[best].add([vi], 1.0, 'REPLACE')
        hits[best] += 1
    return hits


# ---------------------------------------------------------------------------------------
# ASSEMBLE
# ---------------------------------------------------------------------------------------

def join_all():
    """Fold the tail, the folded wings and both feet into the body -- a Roblox skinned MeshPart
    deforms as ONE mesh, so separate objects would import as separate MeshParts that no bone can
    bind across. Then give every new face atlas space the vendor unwrap is not already using."""
    body = bpy.data.objects[BODY_OBJ]
    body.name = "KarasuBody"
    body.data.name = "KarasuBody"
    me = body.data
    alloc = UVAllocator(me)

    bm = bmesh.new()
    bm.from_mesh(me)
    uv_dst = bm.loops.layers.uv.verify()
    dv_dst = bm.verts.layers.deform.verify()

    added = {}
    for src_name in ("KarasuTail", "KarasuFolded", "KarasuLids", FOOT_L, FOOT_R):
        src = bpy.data.objects.get(src_name)
        if not src:
            continue
        for g in src.vertex_groups:
            if not body.vertex_groups.get(g.name):
                body.vertex_groups.new(name=g.name)
        gmap = {g.name: g.index for g in body.vertex_groups}
        before = len(bm.faces)
        _append(bm, uv_dst, dv_dst, src, gmap)
        bm.faces.ensure_lookup_table()
        bm.verts.ensure_lookup_table()
        added[src_name] = (before, len(bm.faces))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    me.update()
    bm.free()
    for n in ("KarasuTail", "KarasuFolded", "KarasuLids", FOOT_L, FOOT_R):
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)

    # UVs for the new faces. The feet arrive with the vendor's own (clean, non-overlapping)
    # unwrap but it sits ON TOP of the body's islands, so they are repacked too.
    # each block now holds BOTH shells stacked, so it is taller than the piece's own aspect
    # ⚠ THE LIDS PROJECT ALONG X, the axis they face -- a ring on the side of a head unwraps
    # cleanly from the side and degenerately from anywhere else.
    plan = {"KarasuTail": (2, 0.17, 0.19), "KarasuFolded": (0, 0.19, 0.17),
            "KarasuLids": (0, 0.09, 0.07),
            FOOT_L: (0, 0.08, 0.10), FOOT_R: (0, 0.08, 0.10)}
    packed = {}
    for name, (lo, hi) in added.items():
        axis, w, h = plan[name]
        blk = alloc.take(w, h, name)
        _project_faces(me, range(lo, hi), axis, blk)
        packed[name] = [round(v, 4) for v in blk]

    # The bill split's fill faces came out of holes_fill with no meaningful UV; give the gape a
    # patch of its own or it paints whatever happens to sit at the atlas origin. The faces are
    # the ones split_bill TAGGED, not the ones a geometric test guesses at.
    tag = me.attributes.get("gape")
    gape = [i for i, v in enumerate(tag.data) if v.value == 1] if tag else []
    if gape:
        blk = alloc.take(0.045, 0.045, "gape")
        _project_faces(me, gape, 1, blk, split_shells=False)
        packed["gape"] = [round(v, 4) for v in blk]

    # ⚠ TAG WHAT THE VENDOR NEVER PAINTED. Everything appended above -- tail, folded wings, feet
    # -- plus the gape fill is geometry the purchased model did not have, so no vendor art exists
    # for it and it MUST be painted procedurally. Everything else is the vendor's own mesh wearing
    # the vendor's own unwrap, where the hand-painted map beats anything a colour function can
    # compute. The bake reads this to decide which texels it owns; without it the choice would be
    # a UV rectangle typed by hand, which is the thing that goes stale the first time a block moves.
    newgeo = me.attributes.get("newgeo") or me.attributes.new("newgeo", 'INT', 'FACE')
    vals = [0] * len(me.polygons)
    for _n, (lo, hi) in added.items():
        for i in range(lo, hi):
            vals[i] = 1
    for i in gape:
        vals[i] = 1
    newgeo.data.foreach_set("value", vals)

    packed["thickened_body"] = thicken_degenerate_uvs(me)["thickened"]

    wings = bpy.data.objects["KarasuWings"]
    if not wings.data.uv_layers:
        wings.data.uv_layers.new(name=me.uv_layers[0].name)
    wblk = alloc.take(0.22, 0.17, "KarasuWings")
    _project_faces(wings.data, range(len(wings.data.polygons)), 2, wblk)
    packed["KarasuWings"] = [round(v, 4) for v in wblk]
    # ⚠ THE WINGS NEED IT TOO, and are worse: a membrane is a two-sided plate, so its rim faces
    # are edge-on to any projection. 88 of 652 collapsed before this ran.
    packed["thickened_wings"] = thicken_degenerate_uvs(wings.data)["thickened"]

    tri = lambda m: sum(len(p.vertices) - 2 for p in m.polygons)
    return {"body_verts": len(me.vertices), "body_tris": tri(me), "gape_faces": len(gape),
            "wing_verts": len(wings.data.vertices), "wing_tris": tri(wings.data),
            "uv_blocks": packed, "uv_shrunk": alloc.shrunk, "face_ranges": {k: list(v) for k, v in added.items()}}


def bind(added_ranges):
    """Weight everything that was not weighted by the vendor."""
    body = bpy.data.objects["KarasuBody"]
    arm = bpy.data.objects["Karasu_Rig"]
    me = body.data
    out = {}

    def verts_of(lo, hi):
        s = set()
        for i in range(lo, hi):
            s.update(me.polygons[i].vertices)
        return sorted(s)

    if "KarasuTail" in added_ranges:
        lo, hi = added_ranges["KarasuTail"]
        out["tail"] = weight_to_nearest(body, verts_of(lo, hi), ["joint8", "joint9"], arm)
    if "KarasuFolded" in added_ranges:
        lo, hi = added_ranges["KarasuFolded"]
        # The folded wing rides the FLANK, so it follows the body, not the wing bones -- the
        # wing bones live on the other MeshPart entirely.
        # ⚠ NOT joint8. The primaries deliberately overshoot the rump and lie across the tail
        # base -- that overlap is the most recognisable thing about a folded wing -- and
        # nearest-bone therefore hands 54 of 96 vertices to the TAIL. The wingtips would then
        # swing with every tail flick, which is not a thing wings do.
        out["folded"] = weight_to_nearest(
            body, verts_of(lo, hi), ["joint1", "joint2", "joint2b", "joint2c"], arm)

    # Anything the vendor left unweighted (the shoulder caps, the gape fill) would collapse to
    # the origin the moment a bone moves. Catch it explicitly rather than discovering it in play.
    orphans = [v.index for v in me.vertices if not v.groups]
    if orphans:
        out["orphans_bound"] = weight_to_nearest(
            body, orphans, [b.name for b in arm.data.bones if b.use_deform], arm)

    wings = bpy.data.objects["KarasuWings"]
    for n in ("wing_R", "wrist_R", "wing_L", "wrist_L"):
        if not wings.vertex_groups.get(n):
            wings.vertex_groups.new(name=n)
    # ⚠ THE WING FOLDS AT THE WRIST, and that is the whole reason there are two bones. A single
    # rigid bone cannot shorten, so it cannot fold: swept back 88 degrees the uguisu's tip still
    # reached 0.37 studs against a 0.112 body half-width. Split the membrane at the hinge.
    hinge = abs(arm.data.bones["wrist_R"].head_local.x)
    counts = {}
    for v in wings.data.vertices:
        sfx = "R" if v.co.x >= 0 else "L"
        name = ("wrist_" if abs(v.co.x) > hinge else "wing_") + sfx
        wings.vertex_groups[name].add([v.index], 1.0, 'REPLACE')
        counts[name] = counts.get(name, 0) + 1
    out["wings"] = counts
    out["orphan_count"] = len(orphans)
    out["normalise_body"] = normalise_weights(body, arm)
    out["normalise_wings"] = normalise_weights(wings, arm)
    return out


def normalise_weights(obj, arm, max_influences=4):
    """Every vertex's weights must sum to 1, across at most `max_influences` bones.

    ⚠ A VERTEX THAT SUMS TO LESS THAN 1 UNDER-DEFORMS -- it moves only that fraction of the way
    with its bones, so it lags the geometry around it and the surface tears or creases as the rig
    moves. Measured on the karasu before this existed: 417 of 1591 body vertices summed to anything
    from 0.288 to 1.508, while the wings were clean at 1.000 -- which is what makes it a defect
    rather than a style. The vendor's own weights arrive un-normalised and every operation that
    merges or appends geometry carries them along unchanged.

    ⚠ AND IT IS INVISIBLE AT REST. Weights only express themselves under motion, so nothing about
    a still bird -- in Blender, in Studio Edit, in any screenshot -- can show this. Blender does not
    normalise on the fly either: measured, a vertex totalling 0.502 moved 69% as far as a fully
    weighted one.

    ⚠ FOUR INFLUENCES IS ROBLOX'S LIMIT, not a tidiness preference. A skinned mesh stores four per
    vertex; a fifth is dropped at import, and dropping one from a set that summed to 1 leaves the
    remainder summing to less -- re-introducing the same defect at the point where nobody is
    looking. So trim first, then normalise, and the file that leaves here already satisfies the
    constraint the importer would otherwise enforce silently.
    """
    deform = {b.name for b in arm.data.bones if b.use_deform}
    idx_ok = {g.index for g in obj.vertex_groups if g.name in deform}
    before, trimmed, rebound = [], 0, 0
    for v in obj.data.vertices:
        gs = [g for g in v.groups if g.group in idx_ok and g.weight > 0.0]
        before.append(sum(g.weight for g in gs))
        if len(gs) > max_influences:
            gs.sort(key=lambda g: -g.weight)
            for g in gs[max_influences:]:
                g.weight = 0.0
            # ⚠ RE-READ rather than slicing the list we just mutated. Zeroing a weight can
            # invalidate the element references, and normalising a stale set left one vertex at
            # 0.9975 -- small, but the whole point here is that the total is exactly 1.
            gs = [g for g in v.groups if g.group in idx_ok and g.weight > 0.0]
            trimmed += 1
        tot = sum(g.weight for g in gs)
        if tot <= 1e-6:
            # nothing holds this vertex; it would collapse to the origin the moment a bone moves
            weight_to_nearest(obj, [v.index], sorted(deform), arm)
            rebound += 1
            continue
        for g in gs:
            g.weight = g.weight / tot
    after = [sum(g.weight for g in v.groups if g.group in idx_ok) for v in obj.data.vertices]
    off = [t for t in after if abs(t - 1.0) > 1e-4]
    return {"verts": len(before),
            "was_off_by_more_than_0.01": sum(1 for t in before if abs(t - 1.0) > 0.01),
            "was_min": round(min(before), 4) if before else None,
            "was_max": round(max(before), 4) if before else None,
            "trimmed_over_%d_influences" % max_influences: trimmed,
            "rebound_unweighted": rebound,
            "still_off": len(off)}


def normalise_size(target=NOSE_TO_TAIL):
    """Scale LAST, so every proportion above stays in one readable coordinate system and only
    this one number carries real-world size -- the same discipline bird_familiar uses.

    Then: feet at z = 0, centred in x and y. ⚠ THE ORIGIN AT THE FEET IS LOAD-BEARING. It makes
    perch.WorldPosition the bird's position with no fudge, and it is what retired the
    `+ Vector3.new(0, 0.2, 0)` the four-part bird needed.
    """
    arm = bpy.data.objects["Karasu_Rig"]
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    pts = _world_pts([o.name for o in meshes])
    span = max(p.y for p in pts) - min(p.y for p in pts)
    S = target / span
    M = Matrix.Scale(S, 4)
    for o in meshes:
        o.data.transform(M)
    arm.data.transform(M)
    bpy.context.view_layer.update()
    pts = _world_pts([o.name for o in meshes])
    mn = Vector([min(p[i] for p in pts) for i in range(3)])
    mx = Vector([max(p[i] for p in pts) for i in range(3)])
    T = Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
    for o in meshes:
        o.data.transform(T)
    arm.data.transform(T)
    bpy.context.view_layer.update()
    pts = _world_pts([o.name for o in meshes])
    mn = [round(min(p[i] for p in pts), 5) for i in range(3)]
    mx = [round(max(p[i] for p in pts), 5) for i in range(3)]
    # ⚠ REMEMBER THE TRANSFORM. Every proportion in KARASU is in BUILD coordinates, and the mesh
    # the texture bake sees is in FINAL ones. Transcribing a station by hand into
    # bake_bird_texture is how a landmark silently stops describing the geometry it draws --
    # the same defect that painted the uguisu's supercilium across its breast after a rescale.
    # `landmarks_final()` maps them instead.
    global LAST_TRANSFORM
    LAST_TRANSFORM = (S, tuple(T.translation))
    body = bpy.data.objects["KarasuBody"]
    bco = [v.co for v in body.data.vertices]
    return {"scale": round(S, 6), "bbox_min": mn, "bbox_max": mx,
            "size_studs": [round(mx[i] - mn[i], 4) for i in range(3)],
            "body_size_studs": [round(max(c[i] for c in bco) - min(c[i] for c in bco), 4)
                                for i in range(3)],
            "length_inches": round((mx[1] - mn[1]) * 12.0, 1)}


# ---------------------------------------------------------------------------------------
# EXPORT
# ---------------------------------------------------------------------------------------

OUT_DIR = "/Users/jonlabrie/Desktop/Roshambo Reference/models/birds/probe/"

# ⚠ HAND-GRADED BY THE OWNER, AND NOT REPRODUCIBLE FROM THIS SCRIPT. `bake_bird_texture` can
# regenerate the composite it started from, but not the Photoshop curve applied on top -- measured
# against the bake, its non-black median luma is 9.6 against 15.6 and its p95 is 14.9 against 86,
# i.e. crushed dark with the catchlights kept. Treat this file as source, back it up, and never
# let a bake write to it.
COLORMAP_AUTHORITY = "karasu_colormap_graded_2.png"

# ⚠ FILES THIS SCRIPT MUST NEVER WRITE. Everything here was authored by the owner in a tool we do
# not drive, so nothing in this pipeline can reproduce it -- a Photoshop curve is not re-derivable
# from the bake it was applied to. A tool that regenerates its own input eventually destroys work
# nobody can get back, and it does so silently, on a run that was about something else entirely.
# Rule 8 of practice/blender-working-rules.md, as a check rather than a sentence.
OWNER_AUTHORED = {COLORMAP_AUTHORITY}


def assert_writable(path):
    """Refuse to write over anything in OWNER_AUTHORED. Call before every file write."""
    name = os.path.basename(path)
    if name in OWNER_AUTHORED:
        raise RuntimeError(
            f"refusing to write {name}: it is owner-authored and this script cannot reproduce it. "
            f"If it genuinely needs replacing, the owner replaces it -- or remove it from "
            f"OWNER_AUTHORED deliberately, which is a decision and should look like one.")
    return path

# The derived PBR channels that ship with it. ⚠ ALL OR NOTHING -- a partial set renders WORSE than
# none (practice/material-and-mesh-traps.md §8): Roblox substitutes its own defaults for whatever
# is missing and a ColorMap-only SurfaceAppearance comes out warm and shiny.
PBR_MAPS = {"roughness": "karasu_roughness.png", "normal": "karasu_normal.png",
            "metalness": "karasu_metalness.png"}

LAST_TRANSFORM = None       # (uniform scale, translation) applied by normalise_size


def landmarks_final(spec=KARASU):
    """Map the build-coordinate proportions in KARASU into the finished mesh's own coordinates,
    ready to paste into bake_bird_texture.SPECIES["karasu"]["landmarks"]. Run after run()."""
    if LAST_TRANSFORM is None:
        raise RuntimeError("run() first -- normalise_size has not recorded a transform")
    S, T = LAST_TRANSFORM

    def pt(y, z):
        return (round(y * S + T[1], 4), round(z * S + T[2], 4))
    plate = spec["wing_folded"]["plate"]
    ys, zs = [], []
    for st in plate:
        y, z = pt(st[0], st[1] + st[2])          # the plate's TOP edge, which is the covert line
        ys.append(y)
        zs.append(z)
    order = sorted(range(len(ys)), key=lambda i: ys[i])
    b = spec["bill"]
    gy, gz = pt(b["gape_p"][1], b["gape_p"][2])
    # ⚠ THE EYE IS MEASURED OFF THE FINISHED HEAD, not mapped through the transform like the
    # rest. Its z is a drop from the CROWN at its own station, so a forehead change carries the
    # eye with it instead of leaving it behind -- which is the drift this function did not
    # previously catch, because it did not emit the eye at all.
    # ⚠ THE EYE LANDMARK IS THE SPHERE'S OWN CENTRE, mapped out through the same transform. It
    # is not re-derived and not re-measured: the paint describes the geometry because it IS the
    # geometry's numbers. Before this the eye was hand-typed, drifted silently when the head
    # moved, and `landmarks_final` did not emit it at all.
    if LAST_EYE is None:
        raise RuntimeError("eye_site() has not run -- call run() first")
    # ⚠ ONE x FOR A TWO-SIDED FACT, and it is the honest compromise rather than an oversight.
    # The eyes sit at DIFFERENT depths because the head is not symmetric, but the shader works in
    # `abs(x)` -- it literally cannot tell the sides apart -- so the socket it paints has to use a
    # single value. The mean is right in the middle of a ~0.01 spread against a 0.024 radius, and
    # the socket's falloff is soft and 0.6 radii wide, so it lands on both. If a future bird is
    # wildly asymmetric this is where that shows up first.
    ex = (LAST_EYE["R"] + LAST_EYE["L"]) * 0.5
    ey, ez, er = LAST_EYE["y"], LAST_EYE["z"], LAST_EYE["r"]
    return {"covert_edge_y": tuple(ys[i] for i in order),
            "covert_edge_z": tuple(zs[i] for i in order),
            "covert_back_y": round(plate[-1][0] * S + T[1] - 0.02, 4),
            "covert_front_y": round(plate[0][0] * S + T[1] + 0.01, 4),
            "gape_p": (0.0, gy, gz),
            "bill_y": round(b["hinge_y"] * S + T[1] - 0.045, 4),
            "tail_root_y": round(spec["tail"]["root_y"] * S + T[1], 4),
            "eye": (round(ex * S, 4), round(ey * S + T[1], 4), round(ez * S + T[2], 4)),
            "eye_r": round(er * S, 4),
            "scale": round(S, 6), "translate": [round(v, 5) for v in T]}


def export(part, filepath):
    """One FBX per MeshPart, BOTH around the same origin and carrying the SAME rig.

    ⚠ Export both halves seated on the SAME origin or they mate with an offset that looks like a
    rigging bug. The mechanism is simply that one armature is exported twice with a different
    mesh in the scene -- which is exactly what uguisu_body.fbx and uguisu_wings.fbx do (both
    reimport with an identical 22-bone armature at identical loc/rot/scale).
    """
    assert_writable(filepath)
    arm = bpy.data.objects["Karasu_Rig"]
    scene = bpy.context.scene
    others = [o for o in bpy.data.objects
              if o.type == 'MESH' and o.name != part and o.name in scene.collection.all_objects]
    holders = {}
    for o in others:
        holders[o] = list(o.users_collection)
        for c in holders[o]:
            c.objects.unlink(o)
    # Blender's exporter convention wants the model facing -Y; the working frame faces +Y.
    prev = tuple(arm.rotation_euler)
    arm.rotation_euler = (0.0, 0.0, math.pi)
    bpy.context.view_layer.update()
    try:
        win = bpy.context.window_manager.windows[0]
        scr = win.screen
        area = next((a for a in scr.areas if a.type == 'VIEW_3D'), scr.areas[0])
        with bpy.context.temp_override(window=win, screen=scr, area=area,
                                       region=area.regions[-1], scene=scene,
                                       view_layer=bpy.context.view_layer):
            bpy.ops.export_scene.fbx(
                filepath=filepath,
                # ⚠ use_selection=True FAILS under the Blender MCP -- that context has no
                # selected_objects. Put only what you want in the scene and export all of it.
                use_selection=False,
                apply_unit_scale=True,
                global_scale=0.01,           # Blender writes FBX in cm; Roblox reads raw numbers
                apply_scale_options='FBX_SCALE_NONE',
                object_types={'MESH', 'ARMATURE'},
                use_mesh_modifiers=False,    # ⚠ True SILENTLY DESTROYS THE RIG: it applies the
                                             # armature modifier and writes a static mesh. The
                                             # import then SUCCEEDS and simply has no bones.
                add_leaf_bones=False,
                # ⚠ FALSE, AND THE REASON IS THE EYE BONES. This flag does not merely drop
                # non-deform bones -- it drops bones with NO WEIGHTS ON THE MESH BEING EXPORTED.
                # `eye_R`/`eye_L` carry a POSITION and deform nothing by design, so it culled
                # them silently: the rig had 21 bones in Blender and the imported body had 15
                # (21 minus 4 wing bones, which live on the other mesh, minus the 2 eyes). The
                # bird arrived in Studio with no way to place its own eyes, and nothing reported
                # it -- the export succeeded, the mesh was fine, only a lookup by name would ever
                # have failed. Every bone this rig builds is a deform bone, so turning it off
                # costs nothing but a few inert bones on each mesh.
                use_armature_deform_only=False,
                bake_anim=False,
                mesh_smooth_type='FACE',
                path_mode='COPY', embed_textures=False,
                axis_forward='-Z', axis_up='Y')
    finally:
        arm.rotation_euler = prev
        for o, cs in holders.items():
            for c in cs:
                c.objects.link(o)
        bpy.context.view_layer.update()
    return filepath


# ---------------------------------------------------------------------------------------

def body_profile(step=0.06):
    """The measurement table every proportion in KARASU was read off. Re-run after any change
    that moves the body under them."""
    me = bpy.data.objects.get("KarasuBody") or bpy.data.objects[BODY_OBJ]
    co = np.array([v.co[:] for v in me.data.vertices])
    rows = []
    for y0 in np.arange(co[:, 1].min(), co[:, 1].max(), step):
        m = (co[:, 1] >= y0) & (co[:, 1] < y0 + step)
        if m.sum() >= 3:
            rows.append({"y": round(float(y0 + step / 2), 3), "n": int(m.sum()),
                         "zmin": round(float(co[m][:, 2].min()), 3),
                         "zmax": round(float(co[m][:, 2].max()), 3),
                         "hw": round(float(np.abs(co[m][:, 0]).max()), 3)})
    return rows


def run(spec=KARASU, do_export=False, eyes=True):
    """The whole pipeline, vendor blend -> two rigged meshes in the working frame.

    ⚠ `eyes=False` BUILDS A PLAIN SKULL -- no lid collar, no eyeball mesh -- so the eye can be
    PAINTED instead. That is not a debug switch; it is the fork between the two approaches, and
    the reason it exists is that a painted eye cannot be judged against a modelled one while the
    modelled one's geometry is still in the mesh. The lofted collar is a raised ring exactly where
    the paint has to lie flat, so paint on top of it reads as a lumpy annulus no matter how good
    the art is (owner, 2026-08-29: "that's not going to work because of all the modeling done
    around the eyeballs").
    ⚠ `eye_site` still runs either way -- it only MEASURES, and `landmarks_final` and the texture
    bake both need the seat it records.
    """
    log = {}
    log["load"] = load_vendor()
    log["split_wings"] = split_wings()
    # ⚠ `measure_gape_plane(spec)` would go HERE and is deliberately not called. It fits the cut
    # to the bill's own mouth line and is strictly better than the typed plane -- but it belongs
    # with a bill that is lofted, not displaced, and wiring it alone changes the split under a
    # bill nobody has re-approved.
    # ⚠ ORDER IS LOAD-BEARING -- see reshape_body's docstring. After the wing cut (which needs the
    # measured gap at |x| 0.19), before everything that MEASURES the body it attaches to.
    log["reshape"] = reshape_body(spec)
    log["eyes"] = eye_site(spec)            # after the reshape: it seats on the shipped skull
    # ⚠ NO SEPARATE DISPLACEMENT SWELL. `build_eye_lids` used to lift a broad ring of body
    # vertices before this ran; between them they produced a halo more than twice the eye's width.
    # The collar's own crest IS the skin rising, it is a fixed width all the way round, and
    # dropping the displacement takes 224 triangles with it.
    if eyes:
        log["lid_collar"] = build_lid_collar(spec)
        log["eye_mesh"] = build_eye_mesh(spec)
    else:
        log["lid_collar"] = log["eye_mesh"] = "SKIPPED -- painted eye, plain skull"
    log["tail"] = build_tail(spec)
    log["folded"] = build_folded_wings(spec)
    log["spread"] = build_spread_wings(spec)
    # ⚠ THE BEAK IS NOT SPLIT, AND THAT IS DELIBERATE (owner, 2026-08-30). The plane bisect that
    # used to run here is retired: a bird's tomium is a CURVE and a plane cannot follow one. It sat
    # 0.0107 studs below the mesh's own mouth line and left 13 faces owning vertices from both
    # mandibles -- a web that stretches instead of a jaw that hinges. Two attempts at a replacement
    # (a fitted plane, then a lofted bill grafted onto this head) both failed on assembly.
    # ⚠ THE JAW BONE GOES WITH IT. A `bill_lower` driving nothing is worse than no bone: it reads
    # as a working feature to anyone scanning the rig, and `BirdController` would look it up, find
    # it, and drive geometry that no longer separates. See practice/owner-rulings.md.
    log["feet"] = simplify_feet(spec)
    log["rig"] = rebuild_rig(spec)
    j = join_all()
    log["join"] = {k: v for k, v in j.items() if k != "face_ranges"}
    log["join"]["gape_faces"] = j.get("gape_faces")
    log["bind"] = bind(j["face_ranges"])
    log["size"] = normalise_size()
    # reparent every mesh to the rig with an identity basis (trap 2 again)
    # ⚠ ALL THREE, AND THE EYES ARE THE ONE THAT WAS MISSED. `KarasuEyes` was built with a
    # `joint4` vertex group and left unparented, on the belief that putting the armature in the
    # scene is what makes a mesh skinned. It is not -- Blender's FBX exporter writes a skin
    # deformer only for a mesh that carries an ARMATURE MODIFIER, and a vertex group with no
    # modifier behind it is inert. The eyes imported as a static MeshPart with zero bones, so
    # they would have hung in world space ignoring every head turn.
    arm = bpy.data.objects["Karasu_Rig"]
    for n in ("KarasuBody", "KarasuWings", "KarasuEyes"):
        o = bpy.data.objects.get(n)
        if not o:
            continue
        o.parent = arm
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.matrix_basis = Matrix.Identity(4)
        if not any(m.type == 'ARMATURE' for m in o.modifiers):
            m = o.modifiers.new("Armature", 'ARMATURE')
            m.object = arm
    log["eye_bones_note"] = ("eye_R/eye_L are vestigial and unshippable -- Roblox strips any bone "
                             "that influences no vertex")
    if do_export:
        log["export"] = {
            "body": export("KarasuBody", OUT_DIR + "karasu_body.fbx"),
            "wings": export("KarasuWings", OUT_DIR + "karasu_wings.fbx")}
    return log


# ---------------------------------------------------------------------------------------
# VERIFICATION — drive the rig, do not look at it
# ---------------------------------------------------------------------------------------

def verify_rig():
    """Rotate each driven bone and MEASURE what moved.

    ⚠ A SCREENSHOT PROVES NOTHING HERE. The uguisu's fold shipped with an inverted sign for three
    days precisely because the only two poses anyone ever looked at -- fully spread and fully
    folded -- are the two where the sign cannot show. Non-zero displacement ON a chain and zero
    OFF it is what proves weights and hierarchy; a picture of a bird proves that it is a bird.

    The wing checks are the important ones, because BirdController's beat and fold are written
    against two MEASURED facts about these bones that only hold if the roll is right:
    rotating about local X raises BOTH wings for the same sign (it does not mirror), and
    rotating about local Z sweeps them in OPPOSITE directions (it does).
    """
    arm = bpy.data.objects["Karasu_Rig"]
    dg = bpy.context.evaluated_depsgraph_get()

    def rest(obj):
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return np.array([v.co[:] for v in ev.data.vertices])

    def moved(obj, bone, axis, deg):
        base = rest(obj)
        pb = arm.pose.bones[bone]
        pb.rotation_mode = 'XYZ'
        e = [0.0, 0.0, 0.0]
        e["XYZ".index(axis)] = math.radians(deg)
        pb.rotation_euler = e
        bpy.context.view_layer.update()
        ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        now = np.array([v.co[:] for v in ev.data.vertices])
        d = np.linalg.norm(now - base, axis=1)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        return base, now, d

    body = bpy.data.objects["KarasuBody"]
    wings = bpy.data.objects["KarasuWings"]
    out = {}

    base = rest(body)
    head = base[:, 1] > 0.45
    tail = base[:, 1] < -0.45
    legL = (base[:, 0] < -0.02) & (base[:, 2] < 0.24)
    legR = (base[:, 0] > 0.02) & (base[:, 2] < 0.24)

    for bone, on, off, label in (("joint4", head, tail, "head_vs_tail"),
                                 ("joint8", tail, head, "tail_vs_head"),
                                 ("joint3", head, tail, "neck_vs_tail"),
                                 ("joint12", legL, legR, "hipL_vs_legR"),
                                 ("joint25", legR, legL, "hipR_vs_legL")):
        _, _, d = moved(body, bone, 'X', 25.0)
        out[label] = {"on_chain_max": round(float(d[on].max()) if on.any() else -1.0, 5),
                      "off_chain_max": round(float(d[off].max()) if off.any() else -1.0, 5)}

    _, _, d = moved(body, "bill_lower", 'X', 20.0)
    lower = body.vertex_groups["bill_lower"]
    li = np.array([any(g.group == lower.index for g in v.groups) for v in body.data.vertices])
    out["bill_lower_vs_rest"] = {
        "on_chain_max": round(float(d[li].max()), 5),
        "off_chain_max": round(float(d[~li].max()), 5)}

    # --- wing axes, the two facts BirdController is written against
    wb = rest(wings)
    right = wb[:, 0] > 0
    axes = {}
    for axis, name in (('X', "lift"), ('Z', "sweep")):
        _, nowR, _ = moved(wings, "wing_R", axis, 40.0)
        _, nowL, _ = moved(wings, "wing_L", axis, 40.0)
        tipR = int(np.argmax(wb[:, 0]))
        tipL = int(np.argmin(wb[:, 0]))
        axes[name] = {
            "R_tip_dz": round(float(nowR[tipR, 2] - wb[tipR, 2]), 4),
            "L_tip_dz": round(float(nowL[tipL, 2] - wb[tipL, 2]), 4),
            "R_tip_dy": round(float(nowR[tipR, 1] - wb[tipR, 1]), 4),
            "L_tip_dy": round(float(nowL[tipL, 1] - wb[tipL, 1]), 4)}
    out["wing_axes"] = axes
    out["wing_axes_verdict"] = {
        "local_X_raises_both_wings":
            axes["lift"]["R_tip_dz"] > 0.01 and axes["lift"]["L_tip_dz"] > 0.01,
        "local_Z_sweeps_them_opposite":
            axes["sweep"]["R_tip_dy"] * axes["sweep"]["L_tip_dy"] < 0,
        "local_X_is_the_lift_axis":
            abs(axes["lift"]["R_tip_dz"]) > abs(axes["lift"]["R_tip_dy"]),
        "local_Z_is_the_sweep_axis":
            abs(axes["sweep"]["R_tip_dy"]) > abs(axes["sweep"]["R_tip_dz"])}

    _, _, d = moved(wings, "wing_R", 'X', 40.0)
    out["wing_R_vs_wing_L"] = {"on_chain_max": round(float(d[right].max()), 5),
                               "off_chain_max": round(float(d[~right].max()), 5)}
    _, _, d = moved(wings, "wrist_R", 'Z', 40.0)
    hinge = abs(arm.data.bones["wrist_R"].head_local.x)
    out["wrist_R_outboard_only"] = {
        "outboard_max": round(float(d[wb[:, 0] > hinge].max()), 5),
        "inboard_max": round(float(d[(wb[:, 0] > 0) & (wb[:, 0] < hinge * 0.8)].max()), 5)}
    rest(body)
    rest(wings)
    return out


def bake_and_finish(res=1024):
    """Paint the ColorMap, wire it onto both meshes, and write the two FBXs plus the PNG.

    The PNG is saved SEPARATELY rather than relying on the FBX to carry it: the uguisu ships as a
    MeshPart `TextureID` (a plain ColorMap, no SurfaceAppearance), which the owner uploads by
    hand. Body and wings share ONE atlas, so that is one upload for the whole bird.
    """
    import importlib.util
    import os
    import sys
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
        "/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox/tools/blender"
    spec = importlib.util.spec_from_file_location(
        "bake_bird_texture", os.path.join(here, "bake_bird_texture.py"))
    bbt = importlib.util.module_from_spec(spec)
    sys.modules["bake_bird_texture"] = bbt
    spec.loader.exec_module(bbt)

    # ⚠ PAINT AGAINST THE MESH THAT WAS JUST BUILT, NOT AGAINST A TRANSCRIPT OF AN OLDER ONE.
    # `bake_bird_texture` carries a typed `landmarks` dict whose own comment says to re-derive it
    # from `landmarks_final()` after any change to KARASU -- and nothing enforced that, so the
    # numbers were only ever as fresh as somebody's memory. They go stale in the direction that
    # is hardest to see: the 2026-08-28 reshape raised the crown 0.0033 studs under a hand-typed
    # eye, which is 14% of the eye's radius and invisible until it is not.
    # MERGED, not replaced -- `throat_y` and `leg_z` have no derivation and still come from there.
    bbt.SPECIES["karasu"]["landmarks"] = {**bbt.SPECIES["karasu"]["landmarks"],
                                          **landmarks_final()}
    info = bbt.bake("KarasuBody", "karasu", res=res, wing_name="KarasuWings")
    img = bpy.data.images[info["image"]]
    # ⚠ THE SHIPPED ColorMap IS THE OWNER'S FILE, NOT THIS BAKE'S OUTPUT (2026-08-29). The bake
    # produces a STARTING POINT; the owner then graded it in Photoshop for contrast and black
    # level, and that hand-edit is the thing the bird wears. Writing over `COLORMAP_AUTHORITY`
    # would silently destroy it -- the whole reason it is named here rather than left implicit.
    # The bake's own output goes to a separate file so it stays available for comparison and as
    # the base for the NEXT grade.
    png = assert_writable(OUT_DIR + "karasu_colormap_baked.png")
    img.filepath_raw = png
    img.file_format = 'PNG'
    img.save()
    authority = OUT_DIR + COLORMAP_AUTHORITY
    if not os.path.exists(authority):
        raise RuntimeError(
            f"the shipped ColorMap {COLORMAP_AUTHORITY} is missing from {OUT_DIR}. It is a "
            f"hand-graded file that this script cannot regenerate -- recover it rather than "
            f"substituting the bake, which is a different image.")
    png = authority

    mat = bpy.data.materials.get("KarasuMat") or bpy.data.materials.new("KarasuMat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-320, 0)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.location = (-720, 0)
    # ⚠ Keep the map wired straight from an Image Texture to a PRINCIPLED BSDF to Material
    # Output. The FBX exporter only finds textures traceable along exactly that path -- behind a
    # Mix Shader it writes no maps at all, which is one of the three separate causes of
    # "can't read the color or normal maps".
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    for n in ("KarasuBody", "KarasuWings"):
        o = bpy.data.objects[n]
        o.data.materials.clear()
        o.data.materials.append(mat)
    eyes = bpy.data.objects.get("KarasuEyes")
    if eyes:
        em = bpy.data.materials.get("KarasuEyeMat") or bpy.data.materials.new("KarasuEyeMat")
        em.use_nodes = True
        nt2 = em.node_tree
        b2 = next((n for n in nt2.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if b2:
            b2.inputs["Base Color"].default_value = (0.006, 0.005, 0.005, 1.0)
            b2.inputs["Roughness"].default_value = 0.08   # so the VIEWPORT shows what Roblox will
        eyes.data.materials.clear()
        eyes.data.materials.append(em)

    files = {"body": export("KarasuBody", OUT_DIR + "karasu_body.fbx"),
             "wings": export("KarasuWings", OUT_DIR + "karasu_wings.fbx"),
             # ⚠ NO ColorMap ON THE EYES. They are a plain glossy black ball for now and the
             # controller sets Color/Material/Reflectance; when the iris arrives it gets its own
             # small TextureID rather than a slice of the bird's atlas, because the atlas is
             # painted by 3D POSITION and an eyeball wants a flat little iris disc instead.
             "colormap": png}
    if "KarasuEyes" in bpy.data.objects:
        files["eyes"] = export("KarasuEyes", OUT_DIR + "karasu_eyes.fbx")
    bpy.ops.wm.save_as_mainfile(filepath=OUT_DIR + "karasu_retarget.blend")
    return {"bake": info, "files": files}
