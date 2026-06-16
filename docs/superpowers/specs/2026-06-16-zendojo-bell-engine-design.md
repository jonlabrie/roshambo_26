# ZenDojo Bell Engine — Design Spec (2026-06-16)

## Goal

Rebuild the clearing's throw machine as a single, legible **water-powered bell
engine**: one waterwheel in the river drives a visible cam-and-gear train that
**draws and trips a shu-moku striker** against the bonshō (the *gong*), and the
striker's swing **kicks a vertical shaft that spins the throw drum**. One water
input, two synchronized outputs (strike + drum-spin), all exposed on an open
timber frame so the gathered crowd watches the contraption work.

This replaces the milestone-4a machine, which collapsed an Asakura wheel cluster
into a single free-spinning wheel, drove the striker only with a thin runtime rope,
left the drum embedded in the roof with no support, and read as a loose collection
of parts rather than one engine.

## Context & current state

- **Coordinate authority:** `tools/builders/ArenaLayout.luau` holds the machine
  coordinates (clearing centre = world origin). Builders read its fields by name.
- **Builders** are pure, `require("./Spec")`, deterministic, and emit model specs
  baked to `assets/*.model.json` via `lune run tools/genmodels` (CI drift-checked).
  Rojo syncs them into `workspace.RoshamboStage`. Relevant: `Waterwheel`, `Bonsho`
  (bell + shu-moku + gantry), `ThrowDrum`, `Shoro` (the frame).
- **Controllers** (`src/client/*.client.luau`) are DI'd runtime scripts that animate
  the named parts: `WheelController` (spins the wheel), `HammerController` (draws/
  swings the shu-moku via the clock-driven `HammerCurve`), `DrumController` (spins
  the drum). Part names are the builder↔controller contract.
- **Clock, not physics:** the round is a phase machine (`ACTIVE 20s → TALLY 2s →
  REVEAL 3s`). The machine's motion is **choreographed to the clock**, not a physics
  sim. The wheel turns continuously as theatre; the draw/release and the drum's
  stop-on-face are clock-driven.
- **Frame (compass):** clearing runs E–W. Up-canyon = West (−X), down-canyon = East
  (+X). River/wheel side = North (−Z); gathering terrace = South (+Z). The bell's
  struck face points South (+Z) toward the crowd.

## Design

### Form & composition
An **open timber mill-frame** (the evolved shōrō) on the terrace at the North water's
edge: corner posts and a roof over the bell, with the drive train fully exposed on a
trestle. A **single waterwheel** sits in the river immediately North of the frame,
its lower paddles in the current; **the wheel's axle runs South into the house as the
main drive shaft.**

### Drive train (one input → two synchronized outputs)
1. **Wheel → main shaft.** The wheel's Z-axle (cross-current, so the +X flow drives
   the lower paddles) extends South into the frame as the main shaft.
2. **Gear-down.** A small fast gear on the main shaft meshes a large slow wooden gear
   on the **cam shaft**, a large visible reduction so the cam shaft turns ~once per
   round. (Ratio is thematic — the cam only needs to creep, then trip, once per
   round.)
3. **Cam → draw.** A cam (wiper/lug) on the cam shaft catches the shu-moku's tail and
   **draws it back over the round** (cocking), then slips past and **trips it** at
   reveal.
4. **Strike.** The released **shu-moku swings into the bonshō's South face → gong.**
5. **Drum kick.** A **dowel on the shu-moku's flank strikes a paddle on a vertical
   shaft** as it swings; the impulse **spins the vertical shaft → spins the throw
   drum** up top. The drum coasts and settles on the world-throw face. Re-cock next
   round.

### Striker (bonshō + shu-moku)
Keep the historically-correct **side-struck bonshō** and the **shu-moku** striking
log, but drive the swing from the cam (authentic water power) rather than a human/
rope. **Shorten the gantry rail** to the shu-moku's actual travel (the current rail is
a holdover sized for the old SW-axis layout).

### Throw drum
Mounted **up top above the bell on the vertical shaft**, carried by a **bearing yoke /
arms clear of the roof** (currently it has no visible support and clips the roof).
**Rotated 90°** so its result faces present up/downriver (±X) — readable to the crowd
spread along the terrace and to the up-/down-canyon cliff perches.

### Dropped
The **sōzu** is removed; the throw-lockout beat moves to sound/UI.

### Clock reconciliation
The wheel spins continuously (theatre). The **draw curve, trip timing, and the drum's
stop-on-face stay clock-driven** (`HammerCurve` and the reveal cue). The large
gear-down is what makes the **cam visibly creep once per round** so the mechanism
*reads* as causing the strike and the spin even though the motion is choreographed.
The dowel-kick, vertical-shaft spin, and drum settle are visual consequences keyed to
the same strike event.

## Components

### New builder — `tools/builders/BellDrive.luau`
The exposed drive train: **main shaft** (the wheel axle extended South), the
**gear-down** pair (small driver gear + large cam gear), the **cam** on the cam shaft,
the **vertical shaft** with its **paddle**, and the **drum bearing yoke / arms**. Pure,
reads coordinates from `ArenaLayout` (`bellDrive` block). Part names are the
controller contract (e.g. `MainShaft`, `DriverGear`, `CamGear`, `Cam`, `VertShaft`,
`VertPaddle`, `DrumYoke`).

### Modified builders
- **`Bonsho.luau`** — add the **dowel** on the shu-moku flank (named `ShuMokuDowel`);
  shorten the gantry rail per the new `shuMoku` travel.
- **`ThrowDrum.luau`** — re-orient 90° (faces ±X); mount on the vertical-shaft top;
  no longer self-supporting (carried by the yoke).
- **`Waterwheel.luau`** — already in-river undershot; confirm the axle aligns to the
  main shaft heading and seats in the current.
- **`Shoro.luau`** — open frame + roof sized to clear the drum yoke and house the
  trestle.

### Controllers
- **`WheelController`** — spin the wheel continuously (unchanged in spirit).
- **`HammerController`** — drive the shu-moku draw/swing from `HammerCurve` (as now);
  **additionally rotate the cam + gear-down to track the draw** (cam creeps with the
  cock, snaps past at the trip) so the linkage reads as causal.
- **`DrumController`** — the drum spin is **keyed to the strike** (the dowel-kick
  moment): spin the vertical shaft + drum up, then settle on the world-throw face;
  otherwise at rest. (Replaces continuous/ACTIVE spinning.)

### `ArenaLayout.luau`
Add/maintain the coordinate blocks the builders read: `waterwheel` (in-river, axle
heading), `bell`, `shuMoku` (+ dowel + shortened gantry), `bellDrive` (main shaft,
gear positions/radii, cam, vertical shaft + paddle, drum yoke), `throwDrum`
(re-oriented, on the vertical shaft). Values are starting points, tuned at the live
gate.

## Testing

- **Lune builder fixtures** (per existing pattern): each builder emits its named parts
  at the layout coordinates. New `BellDrive.spec` asserts the train exists and is
  self-consistent — gear-down present (two meshing gears), cam on the cam shaft, the
  vertical shaft's paddle lies on the shu-moku's swing arc at the dowel's radius, the
  drum yoke carries the drum above the bell, drum faces present ±X.
- **`ArenaLayout.spec`** relationship checks: wheel in the river North of the tower;
  main shaft runs South into the house; bell struck face South; drum faces ±X.
- **MCP/live gate** (Studio Play): run a round and verify the choreography reads —
  wheel turns; cam creeps the shu-moku back through ACTIVE; at reveal the cam trips,
  the shu-moku swings and gongs the bell, the dowel kicks the paddle, the drum spins
  up and settles on the world-throw face. Tune coordinates until it reads as one
  causal engine. Capture from the spawn (downstream, up-canyon) and a sample perch.

## Out of scope / future

- **Cantilevered viewing platform** off the lower (downstream) edge of the clearing —
  a separate design discussion after this.
- **Water-sheet + mist VFX** for the in-fall and boundary fall (existing Task 7).
- **Moss / lanterns / gravel-tone dressing** of the clearing (later art pass).
- The drum's actual face artwork (R/P/S, happy/sad caret/caron) is unchanged lore.

## Risks & notes

- **Readability of causality.** The strongest risk is the linkage reading as
  decorative rather than causal. The gear-down creeping once per round and the
  dowel-kick coinciding exactly with the drum spin are the two beats that sell it —
  both are tuned at the live gate.
- **Footprint.** The exposed train adds parts, but the grown clearing (~172×96 ft)
  has room; the wheel lives in the river (North), the tower core on the terrace.
- **Decoupled motion drift.** Because motion is choreographed, the cam and the actual
  draw must stay visually locked (both keyed to `HammerCurve`), or the cam will appear
  to slip against the striker.
