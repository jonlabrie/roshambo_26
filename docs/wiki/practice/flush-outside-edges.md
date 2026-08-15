---
shelf: practice
updated: 2026-08-15
---

# Flush Outside Edges

Standing rule for any built structure (owner, emphatic, 2026-07-01): **outside/outer
edges are flush** — a support member's OUTER FACE aligns with the edge of what it
supports, never proud of it, never inset (unless inappropriate for the piece).

## The rule

Center a part of half-width `h` so its outer face sits ON the edge: `center = edge − h`
(inward). Examples that bit us and got corrected:

- Landing **deck posts**: outer corner flush with the perimeter-beam/deck outer corner
  (post at local ±2.4/±5.4 for a 1.2-wide post on a deck edge at ±3/±6), not ±2.5/±5.5
  (0.1 proud).
- Landing **kōran newels/rails**: outer face flush with the deck edge (inset the
  0.6-wide parts by 0.3), not centered on the corner (0.3 proud).
- Stair **stringers + posts**: outer faces flush with the tread edge (`WIDTH/2`), not
  proud of it.

**Why:** the owner cares about clean, aligned outer planes; proud/misaligned edges read
as sloppy and get sent back every time. **How to apply:** before finalizing any built
part that sits at an edge, compute its outer-face position and confirm it equals the
edge it should be flush with. Applies across teahouse decks, landings, stairs, paths,
railings. See [[build-recipes]], [[switchback-deck]].

## The counterpart rule: a member that DIES INTO something must never be flush with it

Flush is for an OUTER face at a free edge. The opposite case — an end meant to
disappear into a wall or floor — must be **tucked, never flush**, or you get two
coplanar same-facing faces and Roblox z-fights them. Three instances in one session on
花火屋 (2026-08-13), all found by the owner seeing a flicker:

- attic tie beams sized to `SZ0..SZ1`, so their cut ends sat on the upper walls' OUTER
  faces
- the stairwell's floor strip sized to the wall's inner face `STAIR_X1`, so its edge
  and the wall face shared a plane at exactly attic-floor level — it read as "a beam
  against the wall"
- `WallBack` sized to the full `SW`, so its end faces sat on the side walls' outer
  planes

**The signature of the mistake:** sizing a member to the ENVELOPE constant (`SZ0`,
`SX1`, `STAIR_X1`) when what you want is a member that dies into the thing that
constant describes. Tuck by an inch (1/12 stud) or so and assert the tuck is smaller
than the wall is thick. The general sizing rule is [[derive-from-what-it-touches]].

**Diagnosing a flicker — scan, don't guess.** Over every pair of unrotated parts, find
shared face planes (`|face1 - face2| < 1e-6`) where the other two axes overlap AND the
solids also straddle that plane; that last condition separates a real z-fight from a
harmless touching joint. Corner joints and buried faces produce many benign hits, so
read the list rather than fixing all of it.

## Related gotcha: invisible fall-barriers can choke the walkway

A 15-stud fall barrier must be THIN across the path and LONG along it. With
`CFrame.fromMatrix(pos, R, yAxis)`, `Size.X` runs along `R` and `Size.Z` along the
cross axis — easy to swap. Stair barriers built `(0.3, 15, 2.53)` with the 2.53 on the
CROSS axis reached to within 0.48 of centerline, leaving a **0.95-stud gap** — the
~2-wide character couldn't climb. Fix: thin dimension on the cross axis (barrier
`(2.53,15,0.3)` → ~3.2-stud gap). Always sanity-check the walkable gap between
collidable barriers ≥ ~3 studs.
