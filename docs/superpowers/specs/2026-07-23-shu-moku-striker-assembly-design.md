# Shu-moku Striker Assembly — Design

**Date:** 2026-07-23
**Branch:** `m4b-zendojo-art-pass`
**Status:** Approved (brainstormed live; suspension/dress/rigging chosen by the user)

## Goal

Rebuild the shu-moku striker assembly so it (1) strikes the bonshō at the correct
point — the tsuki-za lotus boss — and (2) reads as finished art: tower-hung hemp
rigging and a fully dressed log. The corrected strike height is the **input for the
next task** (drive-shaft/gearing rebuild); this task deliberately leaves the low cam
geometry alone.

## The anchor numbers

| Thing | Value | Source |
|---|---|---|
| Tsuki-za (LotusBoss) centre | `(-2, 120.7, 5.3)` | measured in place (`RoshamboStage.BonshoBell.LotusBoss`) |
| New log rest centreline | `(-2, 120.7, 9)` | was `(-2, 118, 9)` — 2.7 low, the exact T5 bell-raise delta |
| Log chain-attach height | y ≈ 121.3 | log surface, r 0.8 |
| Rope tops (spreader eyes) | y ≈ 132 | just under the ring-beam level (~134) |
| Tower +Z post pair | x = 7 and −11, z = +9 | `pavilion.pos ± postSpacing/2` — z=9 sits between the chain planes (7.5 / 11.5) |

Bell mouth rim is ~116.95; the old y118 strike hit ~1 stud above the rim and 2.7
below the boss.

## Decisions (user-selected)

1. **Suspension: tower-hung.** The freestanding gantry is deleted. A cypress
   hanger beam spans the two +Z shōrō posts; ropes drop ~11 studs.
2. **Log: full dress.** Domed bronze nose cap, iron bands, rope whipping at the
   hanger attachments, iron tail ring for the draw rope.
3. **Rigging: hemp ropes** using the user-supplied ambientCG **Rope001** texture
   set (`roshambo_reference/Rope001_1K-PNG/`) as a new `HempRope` MaterialVariant.

## Components

### Builder (`tools/builders/Bonsho.luau`)
- **Delete:** `GantryPost*`, `GantryBrace*`, `Rail*` (the freestanding gantry).
- **Add — suspension:**
  - `HangerBeam` — cypress beam (round-log/joinery vocabulary, CypressWeathered),
    x −11→7 at z=9, centre y≈132, section ~1.2×1.4.
  - `Spreader1/2` — short beams across the hanger at x=2 and x=−6, z 7.5→11.5
    (2.5-stud cantilever each side of the post plane).
  - `RopeEye1-4` — small IronDark rings at the four drop points
    `(2|−6, ~131.5, 7.5|11.5)`.
- **Keep (contract):** `Bonsho` proxy, `ShuMoku`, `ShuMokuDrawDowel`,
  `ShuMokuDowel`, `Chain1-4` (names unchanged — they become ropes visually).
- **Add — log dress (rest-posed at log-relative offsets):**
  - `ShuMokuD_Nose` — domed cap (sphere/cylinder cap), BronzePatina, striking end (−Z).
  - `ShuMokuD_Band1/2` — IronDark rings at thirds of the log body.
  - `ShuMokuD_Whip1/2` — HempRope collars at the chain-attach stations (z 7.5, 11.5).
  - `ShuMokuD_TailRing` — IronDark ring at the tail (+Z) where the draw rope leads.
- Chains/ropes: builder-emitted `Chain1-4` get Size cross-section 0.35 and
  `Material=Fabric`, `MaterialVariant=HempRope`, hemp colour.

### Layout (`tools/builders/ArenaLayout.luau` — `shuMoku` block)
- `restPos[2]` 118 → **120.7**; `chainTops` y 124.5 → **132**, x unchanged
  (2 / −6), z unchanged (7.5 / 11.5); `chainBottomsRest` y 118.6 → **121.3**;
  `ropeBottomRest[2]` 118 → 120.7; `drawDowel`/`kickDowel` y 118 → **120.7**.
- `railX/railY/railZ` retired (gantry gone) — remove fields and their consumers.

### Controller (`src/client/HammerController.client.luau`)
- **Mirrored constants** (the module can't require builders): update the inlined
  `chainTops`/`chainBottomsRest` literals (y 118.6 → 121.3, tops y → 132) and any
  rest-height assumptions in the draw math (`riseY` derives from chain geometry —
  verify with the longer ropes; HammerCurve itself is height-agnostic).
- **Dress parts follow the log:** extend the existing `dowels` capture list to a
  prefix loop (`^ShuMokuD_` plus the two dowels) so all dress parts re-apply the
  arm delta each frame.
- ~~Draw-rope styling: `DriveRope` gets Fabric + HempRope too~~ **Erratum
  (2026-07-23, plan-writing):** there is no runtime `DriveRope` — the cam draws
  the log directly (the old wheel→log rope was removed with the coupled cam).
  Likewise layout `ropeBottomRest` has no consumers and is deleted with the rails.

### Materials (place-state, `tools/studio/setupCenterpieceMaterials.luau`)
- New **`HempRope`** MaterialVariant, BaseMaterial **Fabric**: Color/NormalGL/
  Roughness/Metalness from `Rope001_1K-PNG`, uploaded via the standard
  `python3 -m http.server` + `upload_image` flow (batch up front; moderation-gated
  — blank until approved). `StudsPerTile` tuned at the gate (~1). Rotation caveat:
  variants tile in world space; ropes hang vertically, so verify strand direction
  and rotate the maps 90° if the weave reads sideways (CypressVertical precedent).

## What this task does NOT do

- No cam/gear/shaft realignment: the draw rope simply steepens to the raised
  dowel. The **next task** (gearing + secondary shaft) consumes y=120.7 as its
  target and re-aims the cam line.
- No bell/BonshoBell.rbxm changes; no HammerCurve timing changes.

## Testing

- `tests/Bonsho.spec.luau` (extend/create): rest `ShuMoku` centre y equals the
  boss strike height (|Δ| ≤ 0.1 vs a `STRIKE_Y = 120.7` constant); gantry names
  absent; hanger beam/spreaders/eyes present; `Chain1-4` present with Fabric +
  HempRope; dress parts present with expected variants; dowel y == restPos y.
- `tests/CenterpieceContract.spec.luau`: swap gantry names for
  `HangerBeam`/`Spreader1/2`; keep `ShuMoku`/dowels/`Chain1-4`/`Bonsho`.
- Determinism: `lune run tools/genmodels` ×2 stable.
- **Live gate (user judges, one attempt per round):** strike lands on the boss;
  ropes read as hemp at gate distance; swing/draw clears the tower posts and the
  drum-kick dowel still reaches its paddle; night look checked under the frozen
  cycle.

## Risks / watchpoints

- Longer ropes widen the swept arc slightly (rise ~1.7 at full 6-stud draw) —
  verify dowel clearances at the gate (`railX` spacing logic is gone; the posts
  are much farther out at x=7/−11, so clearance should improve).
- The kick-dowel → drum paddle relationship moves up 2.7 with the log; the
  pin-wheel flick is ambient machinery (already decoupled), but confirm it still
  reads.
- HammerController's inlined mirrors are the classic drift hazard — the plan must
  update them in the same task as the layout values.
