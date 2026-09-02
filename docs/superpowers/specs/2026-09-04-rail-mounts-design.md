# Rail Mounts — Design

**Date:** 2026-09-04
**Status:** Approved in conversation (owner, 2026-09-04)
**Program context:** Fireworks distribution thread, immediately following the deck-mortars
ship + gate. Owner direction at that gate: "if you were firing mortars from your deck you'd
probably mount them somehow on the upper rail of the engawa and aim them out over the canyon"
— and deck shells should "head forward and out over the canyon, and not straight up because
they're harder to see that way."

## Purpose

Mortars become aimable hardware whose visible geometry IS the launch direction: a tube
clamped to the engawa's front rail leans out over the canyon and its shells fly the way it
points. Three rulings shape everything:

- **Both mounts** (owner): rail mounting joins floor placement rather than replacing it —
  the `mount` vocabulary is built to grow (roof mounts are an anticipated future kind).
- **Fixed-azimuth, three aims** (owner): every mortar aims within a 60° arc anchored to the
  DECK-FRONT direction — `C` straight out over the canyon, `L`/`R` at ±30° — regardless of
  mount kind or where the tube sits. No free-angle aiming this round.
- **Trajectory follows the hardware**: the flight's axis is the tube's axis. A payload
  without a heading behaves exactly as today, which is the compatibility story for public
  sites, the proving range, and hand-thrown firecrackers — all explicitly unchanged.

## 1. Placement model & persistence

The mortar placement record evolves from `{ offset: [x, z], facing }` to:

```
{ mount: 'floor' | 'rail', offset: [number, number], aim: 'L' | 'C' | 'R' }
```

- `mount = 'floor'`: `offset` is deck-local `(x, z)` exactly as today — defaults, clamp,
  and teahouse nudge unchanged.
- `mount = 'rail'`: `offset[1]` is `t`, the position along the FRONT rail cap (deck-local X
  along the canyon-facing edge), clamped inside the newels; `offset[2]` is carried but
  ignored (kept so the record shape and validator stay uniform). Front rail only this
  round; the enum exists so side/roof mounts can arrive without another schema change.
- `aim`: `C` = deck-front (local −Z, the canyon side — verified in the live place
  2026-09-04: Nobori on −Z, back-door PortalControl on +Z). Sign convention, pinned:
  standing on the deck facing the canyon (LookVector −Z, RightVector +X), `L` yaws the
  heading 30° toward local −X (the viewer's left), `R` 30° toward +X.
- **Elevation is a fixed constant per mount kind**, single tunables:
  `RAIL_ELEVATION = 25°`, `FLOOR_ELEVATION = 12°` from vertical, starting values to be
  tuned live at the owner gate.
- **Reader-side migration, no script**: a stored record without `mount`/`aim` (everything
  saved before this feature) reads as `mount = 'floor', aim = 'C'` — old placements keep
  their spot and gain the canyon bias. `facing` on old records is ignored. A mortar with
  NO stored record at all (including a brand-new owner's) also defaults to `floor`/`C` at
  the front-edge stagger — the shipped behavior, unchanged. Making `rail` the default for
  new owners is a deliberate one-line lever left for the owner to pull at the gate if the
  rail look should be the out-of-box experience.
- Backend: `validateMortarPlacements` accepts the new record — known `mount` and `aim`
  enums required WHEN PRESENT (absent = legacy, valid), offsets finite and bounded by
  `MAX_PLACEMENT_OFFSET`, unknown keys rejected as today. PUT/GET shapes otherwise
  unchanged.

## 2. Pose: one function, two consumers

A new pure `MortarPlacement.pose(deckRow, placement, mortarId)` returns the tube's full
world pose — mount point ∘ aim yaw ∘ mount-kind elevation, composed with the 12-number
deck row — and BOTH consumers read it:

- `TreatmentApplier` renders the leaning tube from the pose.
- `muzzleOriginFor` takes the muzzle as mount point + tilted axis × tube length, and the
  same tilted axis becomes the launch heading.

The rendered tube and the launch origin/heading can never disagree because they are the
same numbers — the `resolveFit` lesson from deck-mortars, promoted to a rule. The
PivotTo/PivotOffset discipline from the gate carries into the pose math.

Render specifics (placeholder-grade, art pass later):
- **Rail mount**: the existing hollow CSG tube (templates unchanged) leans outward from a
  small wood clamp block saddling the `RailCap` (cap top = deck + 2.75, 0.45 wide, outer
  face flush with the deck edge). Rail-mount defaults stagger S/M/L along the cap the way
  floor defaults stagger along the front edge.
- **Floor mount**: keeps the timber base; the tube leans 12° toward its aim instead of
  standing plumb.
- Everything stays server-built in `TreatmentApplier:_buildMortars` and visitor-visible.

## 3. Trajectory

- `FireworkLaunched` gains `heading`: a unit vector the SERVER computes once per launch
  from the pose. One authority; every client — visitors included — renders the same
  leaning arc.
- `FireworkController` generalizes from "up": burst point = `origin + heading × 60` plus
  today's ±jitter; the bezier control point sits along the heading (at 0.9 of the run)
  instead of vertically; the bonus `apexScale` stretches along the heading.
- `heading = nil` (public sites, proving range, firecrackers) reproduces today's vertical
  flight exactly.
- Net effect at a deck: a C-aimed rail shell bursts ~25 studs out past the rail at ~54 up;
  L/C/R fan a show across the 60° arc over the canyon.

## 4. Editor UX

- **The drop decides the mount**: releasing a dragged tube on or near the front rail cap
  snaps it to the rail (`mount = 'rail'`, offset = along-rail `t`); releasing anywhere else
  on the deck is a floor placement. No mode picker.
- The rotate control during a mortar drag cycles the three aims `L → C → R` (mortars only;
  decorations keep their four cardinal facings). The ghost leans as the aim cycles, so the
  launch direction is visible before the drop.
- `SetMortarPlacement` payload becomes `{ mortarId, mount, offset, aim }`, validated
  occupant-only as today (owned id, known enums, finite bounded offset).
- Move-only stands: no remove/sell affordance, mortars never count against
  `MAX_DECORATIONS`.

## 5. Tests

- Lune (`MortarPlacement.spec.luau`): pose math hand-checked against identity and rotated
  deck rows for all three aims and both elevations (the `muzzleWorld` treatment); rail-`t`
  clamping inside the newel margins; legacy-record reader defaults (`floor`/`C`); heading
  comes back unit-length.
- Vitest: validator accepts the new record, rejects unknown `mount`/`aim`, still accepts
  legacy records without them.
- `shared-fixtures/firework-shells.json` untouched — `SHELL_MORTAR` and the promotion
  pipeline are unaffected by this feature.

## Owner gate (in addition to the usual)

- Tune `RAIL_ELEVATION` / `FLOOR_ELEVATION` live.
- Rail snap feel at the drop; arc legibility from the owner's deck AND from Falls Landing;
  a visitor's view of a leaning tube; ⚠ carry forward the STILL-UNVERIFIED same-server
  rejoin check from deck-mortars (published place only).

## Non-goals

- Side-rail and roof mounts (the `mount` enum is the concession to that future).
- Free-angle azimuth or player-adjustable elevation (future "gunner's" upgrade).
- Public-site, proving-range, or firecracker changes.
- Mortar art pass.
