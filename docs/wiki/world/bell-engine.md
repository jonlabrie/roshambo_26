---
shelf: world
updated: 2026-08-15
---

# Bell Engine

The clearing's throw machine: a water-powered bell engine — river drives the wheel,
the wheel drives a gear train and snail cam that draws and releases the shu-moku
striker into the bonshō, and a pin-wheel drive spins the throw drum that settles on
the World Throw. All nine plan tasks built, gated and signed off (2026-06-16..07-24).
Lives in [[arena-square]]'s shōrō; geometry authored by `tools/builders/BellDrive.luau`
/ `Bonsho.luau` / `Waterwheel.luau` against `ArenaLayout.bellDrive`.

## As built

- **Layout is the single truth** (`ArenaLayout.bellDrive`); `HammerController` carries
  mirrored constants (CAM_AXLE_YZ (120.7,11), JACK_AXLE_XZ (−15,11), DRAW_STUDS 3.0,
  LANTERN_RATIO 12/9) — update in lockstep.
- **Drive line**: overshot wheel (r9) upriver at x≈−15, its Z-axle = the main shaft →
  right-angle drive down the tower's west side → E–W cam shaft in the clear corridor
  z≈11 → **hero snail cam** at (−3.8, 120.7, 11). Wheel + main shaft + driver gear are
  one rigid shaft; `HammerController` publishes signed `DriveOmega` and
  `WheelController` locks to it.
- **Mill gearing** (photo-referenced, `f0022cf..0e1d7de`): FaceWheelMain (12 cogs) and
  CamFaceWheel (24 cogs) comb one short lantern pinion at the shafts' plan crossing —
  reduction 2; corner bearing pillow generalized as `{x,z,y,axis,baseY}` stations,
  shōrō-style slate plinths under all bearing posts (`bearingPlinthTop` 113.6).
  `faceWheelMainPhaseDeg = −7` is FINAL (owner swept values live; a perfectly clean
  cog/stave read is geometrically impossible at these sizes — slimmer cogs are a
  beauty-pass item).
- **Cam** (`bb3bce9`): faceted snail with a sharp drop wall (a teardrop is wrong — no
  drop means no free-fall strike). The flank is the **exact runtime contact locus**
  (`CamProfile` inverts the dowel's measured draw path); `CamMesh` builds it
  client-side as an EditableMesh. The cam is **anchored to the strike event itself**
  and free-runs from there — anchoring to round-start events wobbles ±10° with
  network jitter. `CamPhaseDeg = 0` since the metronome (the old −5 compensated a
  legacy blend and was never saved).
- **Drum** (`17db64a`): strike-keyed spin→glide — steady spin ~1.0 s, then a
  cubic-Hermite glide starting at spin velocity and ending at exactly zero on the
  World-Throw detent. Keyed off **`gongHit`** (actual contact), not `gongStrike`.
- **Round metronome** (`a1c91be..8ab3ba7`): all timing is scheduled clockwork —
  Express `/state` publishes durations + exact phase timestamps, `RoundCoordinator`
  emits the absolute strike time, pure `RoundMetronome.luau` slews ≤2 s and snaps
  beyond. This killed the "racing wheel" (a measured-period clock poisoned by
  Play-starting mid-round). Cam rotation derives from the metronome's camAngle,
  never a frozen wall-clock anchor. The 60 s round did not break the mechanism read:
  owner-gated 2026-08-05, "cam still sells" at 1 rpm — no re-gearing needed
  ([[round-and-hud]]).
- **Task 9 water seat** (`073d107`): owner set river water (~110, hydrostatic flat);
  wheel nudged ~4 ft south toward the bank; bottom third submerged. To go shallower,
  the owner lowers terrain water — never raise the wheel (axle Y cascades through the
  whole drive train).
- **Sōzu removed** entirely (builder, tests, controller, asset, layout block).

## Gates & decisions

- Every task 1–9 was owner-gated live; heavy staging tuned in Studio (`598a07e`,
  owner sign-off iterative; drive-chain rebuild "a thing of beauty").
- Water rules (owner-vetoed alternatives): never sculpt water with `FillBlock`;
  water level is set by the owner with the Sea-Level tool. See [[canyon]].
- 2026-07-23 owner ask, deliberately unscheduled: a beauty pass (toothed gear meshes,
  textured/chamfered timber, cast-bronze bonshō, smooth cam mesh, rope/chain meshes)
  — recorded on [[backlog]]; do it only after forms/pivots stop shifting.
- Live-tune knobs published as RoshamboStage attributes: `CamPhaseDeg`, `DrawStuds`,
  `DrawHold`, `JackDir`, `DriverDir`, `WheelDir`, `DrumKick`.

## Raw layer

- spec: `docs/superpowers/specs/2026-06-16-zendojo-bell-engine-design.md` (`c0734a3`);
  plan `docs/superpowers/plans/2026-06-16-zendojo-bell-engine.md`
- task commits: T1–5 `ac2059d`, `c34561e`, `e52a23e`, `4e99dcb`, `1423348` · T6
  staging `598a07e` · T7 cam `bb3bce9` · T8 drum+gears `17db64a` · T9 `073d107` ·
  drive-chain rebuild `f0022cf..0e1d7de` · metronome `a1c91be..8ab3ba7`
