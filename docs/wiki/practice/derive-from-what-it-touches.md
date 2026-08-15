---
shelf: practice
updated: 2026-08-15
---

# Derive From What It Touches

Standing rule: size and place every member from the thing it physically MEETS, never
from a neighbour's dimension — and never make two surfaces exactly level. Two halves of
one failure, which between them produced **a dozen owner-caught defects on
2026-08-13/14** across 花火屋, the karesansui and the torii. Both are cheap to avoid up
front and invisible until somebody stands in the world.

## 1. A member's size and position come from what it MEETS

Every one of these looked correct until something else moved:

- the shop counter measured from the FRONTAGE → deepening the shop put it in the street
- the flank bays a fixed COUNT → doubling the depth stretched them from 4 studs to 8
- the torii's nuki given its OWN overhang → came out two studs shorter than the shimaki
  above it
- the **kusabi** placed as a fraction of the nuki's OVERHANG → lengthening the nuki
  slid the wedges outboard and stranded them mid-protrusion, pinning nothing
- `RingMaxR` pinned as an absolute → does not track the field it fills; must be re-set
  by hand
- `SHORO_TOP` a literal in three files → 17 studs wrong, then stale again a day later
  (see [[one-model-is-not-a-building]])

**Ask: what does this part physically touch?** The kusabi touches the PILLAR, so
derive it from `pillarD/2`. The counter belongs to the BACK WALL. The nuki matches the
SHIMAKI, computed once as one `lintelLen` and used twice. Two numbers that happen to
agree are two numbers that can stop agreeing — delete one.

**For emergent numbers, verify instead of trusting.** `ArenaLayout.towerTopY` is the
tower's height, which falls out of ThrowDrum's build rather than being an input. It has
a test that REBUILDS the tower and compares. That is what a measured constant needs;
correcting its value does not stop the next drift.

## 2. Level is NEVER the target where two surfaces meet

Coplanar same-facing faces z-fight. Six instances in two days: attic tie ends on
`SZ0/SZ1`, the stairwell floor strip on `STAIR_X1`, `WallBack` on the side walls'
planes, the kerb ends, the plinth's WIDTH — and then its HEIGHT, introduced *one commit
after* fixing the width version of the identical mistake by aiming for "level with the
kerb".

**Always overlap or stand proud**, never flush and never exactly equal:

- an end that dies into a wall: tuck ~0.06–0.1 INTO it
- a cap over a member: oversail on every edge (see `KerbCapMain*`, `KasagiCap*`)
- a stone carrying timber: proud on every shared face (plinth is 0.15 wider, an inch
  taller)
- a joint that merely touches shows a seam even when it does not fight

**Diagnosing:** scan for shared face planes where the other two axes overlap AND the
solids straddle the plane — that last condition separates a real fight from a harmless
butt joint. See [[flush-outside-edges]], which holds the counterpart rule (outer faces
at a FREE edge should be flush) and the scan itself.
