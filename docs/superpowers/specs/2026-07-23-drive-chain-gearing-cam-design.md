# Drive-Chain Rebuild: Gearing, Jack Shaft, Hero Snail Cam — Design

**Date:** 2026-07-23
**Branch:** `m4b-zendojo-art-pass`
**Status:** Approved (brainstormed live; push-cam / hero-scale / vertical-jack chosen by the user)

## Goal

Re-engineer the bell-drive from the wheel to the shu-moku for the new striker
height (y=120.7): a repositioned **hero snail cam that genuinely pushes the draw
dowel**, a **vertical jack shaft** with two toothed bevel corners routing power up
from the main shaft, the **drum-kick paddle realigned**, and the **tsuki-za boss
seated** on the bell face. Timing stays 100% clock-master ("theatre, not
physics" — decided against a physical sim because the strike is the round
metronome); the rebuild's job is geometric honesty at any zoom.

## Anchor numbers

| Thing | Value | Why |
|---|---|---|
| Draw dowel rest | `(-1.5..-4, 120.7, 11)`, draws +Z | striker task output |
| Cam axle | `(-2.75, 120.7, 8)`, axis X | dowel height, 3 studs north; mid-dowel-span |
| Cam base radius | 2.75 | axle-to-dowel gap at rest (11−8) minus dowel r 0.25 |
| Spiral growth | 4.1 per rev | DRAW_STUDS 4.06 + clearance; cliff at one full turn |
| Cam lobe max | ~6.85 | base + growth; bottom sweeps to ~113.85 (floor 112 → 1.9 clear) |
| Jack shaft | vertical, `(-15, 116→120.7, 8)` | connects the skew main (y116, axis Z) and cam (y120.7, axis X) shafts |
| Reduction split | main→jack **1:1** (r 1.2/1.2), jack→cam **1:2** (r 1.2/2.4) | net matches controller `REDUCTION = 2` |
| Main shaft | now ends at z=8 (was 11) | the corner moved to the cam-shaft plane |
| Cam shaft | axis X, `y=120.7, z=8`, x −15 → −1.5, octagonal | matches wheel/main shaft vocabulary |
| Kick paddle | y 118 → **120.7** | meets the raised kick dowel |

## Decisions (user-selected)

1. **Push cam** (literal karakuri): the growing spiral face pushes the dowel
   south along its swing arc; release = the dowel drops off the spiral cliff.
   (Snail-spool windlass and cam+rocker were considered and declined.)
2. **Hero scale** (~14 ft): the machine is the spectacle.
3. **Vertical jack shaft** with two bevel corners (inclined shaft declined).
4. Clock-master timing retained; physics simulation explicitly rejected
   (strike = round metronome; physics trades guaranteed sync for jitter).

## Components

### Pure module (new): `src/shared/CamProfile.luau`
`CamProfile.radius(theta, base, growth)` → Archimedean snail
`base + growth * (theta % 2π) / 2π`, cliff at θ=2π. Consumed by the builder
(segment geometry) and available to the controller; Lune-tested against the
layout numbers. **This is the honesty contract:** the controller already locks
cam angle to draw fraction p, so radius-under-the-dowel = base + p·growth by
construction — the face stays visually in contact through the whole draw.

### Layout (`tools/builders/ArenaLayout.luau`, `bellDrive` block rewrite)
- `shaftTo` z 11 → 8; new `jack = { x = -15, z = 8, yBottom = 116, yTop = 120.7 }`.
- New `camShaft = { y = 120.7, z = 8, fromX = -15, toX = -1.5 }`;
  `cam = { -2.75, 120.7, 8 }`, `camBaseR = 2.75`, `camGrowth = 4.1`,
  `camWidth = 1.6` (within the dowel span).
- Bevels: `bevelMainA` (on main shaft, axis Z, r 1.2), `bevelJackA` (jack
  bottom, axis Y, r 1.2), `bevelJackB` (jack top, axis Y, r 1.2), `bevelCamB`
  (on cam shaft, axis X, r 2.4). Rim-kiss placement tuned at the gate.
- Old `driverGear/driverR/camGear/camR/camShaftFrom/camShaftTo/camHubR/camLobeR`
  fields retired.
- `paddle[2]` 118 → 120.7.
- `bearings` generalized: each entry `{ x, z, y, axis }` ("Z" main-run pillow
  blocks at y116; new tall "X"-axis pillow post under the cam shaft at
  `(-5, 8, 120.7)`; the old z=11 main bearing moves to z=6.5; the old
  `(-5.5, 11)` cam bearing entry is replaced by the tall post).

### Builder (`tools/builders/BellDrive.luau`)
- Main shaft octagon shortens automatically (layout-driven).
- **JackShaft**: vertical octagonal prism (4 boxes, `JackShaftF1-4`), cypress.
- **Four toothed bevel gears** (`BevelMainA`, `BevelJackA`, `BevelJackB`,
  `BevelCamB`): disc rim + peg teeth (pin-wheel vocabulary), tooth counts
  proportional to radii (e.g. 10/10 and 10/20) so the mesh reads at rate.
- **CamShaftF1-4**: octagonal cam shaft along X (named `Cam*` → existing
  controller capture spins it with the cam).
- **Cam rebuild** (`Cam*` parts): ~24 tangential plank segments following
  `CamProfile.radius`, spiral side cheeks, cliff drop wall, hub boss; cypress
  planks + iron cheek straps. Old cam parts replaced wholesale.
- **Bearings**: reuse the pillow-block spec (cypress pier + square plate +
  IronDark ring + wider spinning collar) per generalized entries; jack shaft
  held by a timber corner frame bracket at the SW corner.
- Kick paddle rises via layout (no builder change beyond consuming it).

### Controller (`src/client/HammerController.client.luau`)
- New **jack spin group**: `JackShaft*` + `BevelJackA/B` rotate about Y at the
  driver rate (1:1 off the main shaft).
- `BevelMainA` joins the existing driver group (axis Z); `Cam*` capture
  unchanged (cam, cam shaft, `BevelCamB` all spin together at cam rate).
- Mirrored constants: cam pivot moves to `(-2.75, 120.7, 8)`; any rest-pose
  assumptions re-anchored. `CamPhaseDeg` stays the strike-alignment knob;
  `DrawStuds` attr stays live-tunable (default 4.06 — must stay ≤ `camGrowth`).

### Boss seating (place asset, folded into this task)
Raycast in Edit from outside the bell toward its axis at y=120.7 to find the
real mesh surface; move `LotusBoss` inboard to embed ~0.1 into it; user
Save-to-File over `assets/meshes/BonshoBell.rbxm`; commit. No layout change.

## Out of scope

- Physics simulation of any part of the chain (decided against).
- The upper pin-wheel → mawari-dōrō lantern reconnection (stays ambient
  machinery; separate staging question).
- Waterwheel-side changes (T7 shipped) and any HammerCurve timing change.

## Testing

- `tests/CamProfile.spec.luau` (new): radius at θ=0 is base; at 2π⁻ is
  base+growth; monotonic; wraps.
- `tests/BellDrive.spec.luau` (extend): bevel pair ratios equal the reduction
  split (1.2/1.2, 1.2/2.4); cam segments' max radial reach ≈ base+growth;
  cam parts named `Cam*`; jack shaft parts present; kick paddle at 120.7;
  cam clears the floor (lobe bottom ≥ floor + 1.5).
- `tests/CenterpieceContract.spec.luau`: BellDrive requireAll updated (new
  gear/jack names in; `DriverGear`/`CamGear` out).
- genmodels ×2 deterministic; stylua/selene clean.
- **Live gate (user judges, one attempt per round):** cam face visibly carries
  the dowel through the whole draw at close zoom; cliff release reads; gears
  counter-rotate at believable rates; kick paddle meets the dowel; boss seated;
  daylight lock active.

## Risks / watchpoints

- Cam sweep envelope: lobe max 6.85 about (120.7, 8) — verify no collision
  with tower post plane (z=9 posts are at x=7/−11, clear of cam x −2.75) and
  the hemp rope drops (x=2/−6, also clear) — pinned by a test on layout math.
- HammerController's mirrored cam constants are the drift hazard again — same
  rule: update in the same task as the layout.
- `DrawStuds` attr > `camGrowth` would push the dowel off the spiral face —
  document the bound at the attr read.
