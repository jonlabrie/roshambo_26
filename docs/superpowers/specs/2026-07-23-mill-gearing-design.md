# Mill Gearing: Face-Cog Wheels + Lantern Pinion — Design

**Date:** 2026-07-23
**Branch:** `m4b-zendojo-art-pass`
**Status:** Approved (user-supplied reference: `Roshambo Reference/water mill gears.webp` — big through-cog face wheel + columnar lantern pinion)

## Goal

Replace the four peg-tooth bevel discs at the jack corner with the reference's
water-mill vocabulary: two **face-cog wheels** (rectangular cogs mortised
THROUGH the rim, tails proud on the back — individually replaceable, per the
photo) and a single tall **lantern pinion** on the vertical arbor that both
wheels comb — the user's "single vertical gear."

## Why the geometry moves: the shaft-intersection bug

The current jack shaft and cam shaft INTERSECT at the point (−15, 120.7, 11)
— hidden by the old peg discs. The lantern arbor moves to **z = 9.3**: staves
(ring radius 0.9) sweep past the cam shaft's z=11 line with 0.3 clearance,
and the cam wheel's rim dips into the cage from its upper quadrant — which
also reproduces the reference's composition.

## Ratio math (the stave count cancels)

lantern = main × cogsMain/staves; cam = lantern × staves/cogsCam
→ **cam/main = cogsMain/cogsCam = 12/24 = 1/2** = the controller's
`REDUCTION = 2`. Staves (9) are pure aesthetics. Controller's jack group
spins at `LANTERN_RATIO = 12/9` × the driver rate.

## Anchor numbers

| Thing | Value |
|---|---|
| Lantern arbor (jack) | `x=-15, z=9.3`, arbor y **117.0 → 124.9** (bottom CLEARS the main shaft — the old arbor pierced it, same bug class as the shaft crossing) |
| Lantern flanges | r 1.15 × 0.35 discs at y **117.2** and **124.2** |
| Staves | **9** dowels, Size `{6.65, 0.28, 0.28}` vertical, ring radius **0.9**, centred y 120.7, half-pitch phase offset |
| FaceWheelMain | on the main shaft, disc r **1.6** × 0.4, plane z **10.65** (disc clear of the stave sweep, z ≤ 10.34); **12** cogs |
| Main cogs | Size `{0.35, 0.35, ~1.2}`, ring radius 1.35, centred z 10.45 (protrude toward the cage, tail proud behind) |
| CamFaceWheel | on the cam shaft, disc r **3.2** × 0.4, plane x **−13.65** (disc clear of the stave sweep, x ≥ −13.96); **24** cogs; 3 through-spoke accents + iron hub band |
| Cam cogs | Size `{~1.2, 0.35, 0.35}`, ring radius 2.95, centred x −13.85 (protrude toward the cage, tail proud behind) |
| Meshes | main wheel combs the cage at y≈117.6 (bottom); cam wheel at y≈123.5 (top quadrant) |
| BearingPost3 | back to z=6.5 (its z=9.0 spot is inside the new cage) |
| Clearances | staves ↔ cam shaft ≥ 0.3; arbor bottom ↔ main shaft ≥ 0.28; cog length variance ±0.06 (deterministic LCG) for the hand-hammered read |

*(Values corrected at plan-writing: wheel planes pulled off the stave sweep,
arbor lifted off the main shaft, bearing re-sited — three latent collisions
caught on paper.)*

## Components

### Layout (`ArenaLayout.bellDrive`)
- Remove: `bevelMainA/bevelJackA/bevelJackB/bevelCamB/bevelR1/bevelR2`.
- Add:
  ```lua
  faceWheelMain = { -15, 116, 10.35 },
  faceWheelMainR = 1.6,
  faceWheelMainCogs = 12,
  camFaceWheel = { -14.35, 120.7, 11 },
  camFaceWheelR = 3.2,
  camFaceWheelCogs = 24, -- camFaceWheelCogs/faceWheelMainCogs MIRRORS REDUCTION = 2
  lantern = { x = -15, z = 9.3, staves = 9, staveRingR = 0.9, flangeR = 1.15, yBottom = 116.6, yTop = 124.2 },
  ```
- `jack` moves to `{ x = -15, z = 9.3, yBottom = 116, yTop = 124.9 }`.

### Builder (`BellDrive.luau`)
- Delete `bevelGear` helper + its four calls.
- `faceCogWheel(name, pos, r, cogs, axis, cogTowards)` helper: cypress disc,
  through-cogs (iron-banded? no — cypress cogs, slight LCG length jitter),
  cog tails visible on the back face. CamFaceWheel additionally gets 6 spoke
  accent boxes + an IronDark hub band.
- Lantern: `JackLanternFlange1/2` discs + `JackLanternStave1..9` dowels
  (all cypress; stave ring phase offset so no stave starts dead on a mesh).
- `JackFramePost/Arm/JackBand*` re-site to z=9.3; arm/band above the top
  flange (post to y≈125.4, band on the arbor stub at y≈124.9).
- Wheel part names: `FaceWheelMain` + `FaceWheelMain_C{k}`; `CamFaceWheel` +
  `CamFaceWheel_C{k}` (the `Cam` prefix keeps them in the cam spin group).

### Controller (`HammerController.client.luau`)
- `LANTERN_RATIO = 12 / 9` (mirrors cogsMain/staves); jack group angle =
  `driverNet × LANTERN_RATIO × jackDir`.
- Captures: driver group adds `^FaceWheelMain`; jack group captures
  `^JackShaftF` and `^JackLantern` (NOT bare `^Jack` — JackFrame/JackBand are
  static); cam group needs no change (`^Cam` already matches CamFaceWheel*).

## Out of scope

Cam mesh/profile, striker assembly, waterwheel, kick chain, HammerCurve
timing — all untouched.

## Testing

- `BellDrive.spec`: new gear describe — names present (both wheels, 12+24
  cogs counted by `_C%d` suffix, 2 flanges, 9 staves); old `Bevel*` absent;
  `camFaceWheelCogs / faceWheelMainCogs == 2` (REDUCTION mirror);
  **shafts no longer intersect**: `|camShaft.z − lantern.z| ≥ staveRingR + camShaft.r + 0.2`;
  stave length spans flange gap; cog rings inside their discs' radii.
- `ArenaLayout.spec`: the jack-corner test swaps `bevelR2/bevelR1` for the
  cog-count ratio.
- `CenterpieceContract.spec`: `Bevel*`/`JackShaftF1` list → `FaceWheelMain`,
  `CamFaceWheel`, `JackLanternFlange1`, `JackShaftF1`.
- genmodels ×2 deterministic; stylua/selene.
- **Live gate:** mesh reads at both cage stations (cogs comb between staves,
  no cog/stave interpenetration at rest); rotation senses correct (`JackDir`
  live knob); the through-cog tails read on the wheel backs; lantern clears
  the cam shaft through a full revolution.

## Risks / watchpoints

- Cog↔stave phase at rest is not simulated — pick rest phases so nothing
  interpenetrates at build pose (stave ring offset half a stave pitch from
  the mesh azimuths); minor overlap during rotation is accepted (theatre).
- The controller's rest-pose capture means new rate (4/3) shows immediately;
  if the lantern reads too fast, the aesthetic fix is more staves + more main
  cogs at the same ratio (e.g., 8/12/24 → lantern 3/2) — counts stay
  layout-driven.
- JackFramePost at z=9.3 must clear the main shaft run (shaft at y116 along
  z −19..11 at x −15; post is at x −16.4 → clear by construction).
