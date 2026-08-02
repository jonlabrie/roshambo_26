#!/usr/bin/env bash
# Export the ZenDojo forest-preserve tree kit from the XfrogPlants Japan library.
#
# These numbers were arrived at empirically over a long session; they are not
# guesses, and changing one usually breaks something two stages downstream. Read
# the notes before touching them.
#
#   SKIRT      fraction of height stripped of foliage, so the player gets a clear
#              sightline band. XfrogPlants models open-grown specimens foliated to
#              the ground; untrimmed they can never give one. A=26%, M=32% put the
#              canopy floor at 5.5-6.5 studs (player eye is ~5).
#   SPRAY      enlarges each surviving card about its own centroid. The brush models
#              keep only ~30% of their cards to stay cheap, and coverage falls in
#              proportion, so they read as 30%-full shrubs without this. s = sqrt(1/keep).
#   wood mode  3 (PROPORTIONAL): bole, branches and root flare each get their OWN
#              decimation budget. Sharing one budget starves whichever the source
#              happens to be heavy in — it cost the sugi half its canopy once.
#   parts      Roblox's 20k triangle limit is PER MESH, so the sugi splits 2+2.
#
# Usage:  tools/blender/export_forest_kit.sh [outdir]

set -euo pipefail

BL="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XF="${XFROG:-$HOME/Desktop/Roshambo Reference/XfrogPlants_Japan_OBJ/Models}"
OUT="${1:-$HOME/Desktop/Roshambo Reference/xfrog_import_$(date +%Y-%m-%d)}"
mkdir -p "$OUT"

# XfrogPlants names its canopy materials inconsistently across the library
# (hinoki splits Leaf+Needle, cherries use Flower/FLower/Blossom), so always pass
# the full list — an unmatched canopy material is silently dropped.
KEYS="needle,leaf,flower,blossom,frond"

# label  src_obj  obj_name  foliage_tris  wood_tris  height  spray  fol_parts  wood_parts  skirt
run() {
  echo "=== $1"
  "$BL" --background --python "$HERE/export_tree.py" -- \
    "$XF/$2" "$3" "$KEYS" "$4" "$5" "$6" "$OUT/$1.fbx" "$7" 0.0 3 0.0 0.0 "$8" "$9" "${10}" 2>&1 \
    | grep -E "PROPORTIONAL|SELF-PRUNE|SKIRT|FLOATING|ORPHAN|BARE|RESULT|WROTE|ABORT|Error" \
    | sed "s/^/  /"
}

HINOKI=JA05_Chamaecyparis_obtusa_Hinoki_Falsecypress
SPRUCE=JA15_Picea_koyamai_Koyama_Spruce
FIR=JA01_Abies_homolepis_Nikko_Fir
SUGI=JA06_Cryptomeria_japonica_Japanese_Cedar

echo "### CANOPY — trimmed, for the 7-stud-and-up band"
run XfHinokiT   "$HINOKI/JA05a.obj" JA05a 15000 12000 26 1.0 1 1 0.26
run XfSugi25T   "$SUGI/JA06a.obj"   JA06a 25000 18000 26 1.0 2 2 0.26
run XfHinokiMT  "$HINOKI/JA05m.obj" JA05m 15000 10000 20 1.0 1 1 0.32
run XfSpruceMT  "$SPRUCE/JA15m.obj" JA15m 14000 10000 20 1.0 1 1 0.32
run XfFirMT     "$FIR/JA01m.obj"    JA01m 13000 10000 20 1.0 1 1 0.32

# The fringe is backdrop mass against the canyon wall, never walked among, so it
# takes the UNTRIMMED models (skirt 0): foliage to the ground is right there, and
# the sightline rule that drives the canopy trim does not apply. These three were
# exported ad hoc in an earlier session and were missing from this script, which is
# how they later got "LOD"ed by post-processing their finished FBXs — a detour that
# destroyed every bole, because a single decimate budget starves the bole exactly as
# the mode-3 note above warns. Regenerate from source instead of post-processing.
# Budgets 7000/7000 (was 13000/10000) with SPRAY 1.36 = sqrt(13000/7000), user-gated
# 2026-08-01 in a Blender side-by-side against both the originals and the trees then
# standing in the canyon. Wood is now the larger half of these trees and that is
# correct: a conifer bole cannot be cheated, only budgeted (see mode 3 above).
echo "### FRINGE — untrimmed backdrop mass for the canyon wall"
run XfHinokiM   "$HINOKI/JA05m.obj" JA05m 7000 7000 20 1.36 1 1 0
run XfSpruceM   "$SPRUCE/JA15m.obj" JA15m 7000 7000 20 1.36 1 1 0
run XfFirM      "$FIR/JA01m.obj"    JA01m 7000 7000 20 1.36 1 1 0

echo "### BRUSH — untrimmed, below the eyeline; SPRAY refills what thinning removes"
run XfHinokiYb  "$HINOKI/JA05y.obj" JA05y 2500 1200 4 1.78 1 1 0
run XfSpruceYb  "$SPRUCE/JA15y.obj" JA15y 2300 1100 4 1.76 1 1 0
run XfFirYb     "$FIR/JA01y.obj"    JA01y 1800  900 4 1.82 1 1 0
# the sugi young hangs 13,112 cards; at a 2,500 budget it keeps 11% and no amount
# of scaling fills that without the cards reading as slabs, so it buys more budget
run XfSugiYb    "$SUGI/JA06y.obj"   JA06y 6000 1400 4 1.90 1 1 0

MAPLE=JA03_Acer_palmatum_Japanese_Maple
KATSURA=JA04_Cercidiphyllum_japonicum_Katsura_Tree
BAMBOO=JA14_Phyllostachis_nigra_var_Henonis_Hachiko_Bamboo

echo "### ACCENTS — untrimmed deciduous, for the composition layer (never scatter pools);"
echo "### skirt 0: ornamental low canopy is the point, sited by hand off the sightline rule"
run XfMapleA    "$MAPLE/JA03a.obj"   JA03a 15000 12000 20 1.0 1 1 0
run XfMapleM    "$MAPLE/JA03m.obj"   JA03m 12000 10000 14 1.0 1 1 0
run XfKatsuraA  "$KATSURA/JA04a.obj" JA04a 15000 12000 26 1.0 1 1 0
run XfKatsuraM  "$KATSURA/JA04m.obj" JA04m 12000 10000 18 1.0 1 1 0

echo "### BAMBOO — one contrast grove only; culms are the look, wood budget generous"
run XfBambooA   "$BAMBOO/JA14a.obj"  JA14a 12000 14000 22 1.0 1 1 0

echo
echo "Wrote to: $OUT"
