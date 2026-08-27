# Task 2 report: survey the massing and terrain

**Status: DONE**

Studio: `Roshambo` (studio_id `d20da15b-2d39-4469-abee-b96ae287d80f`), datamodel `Edit`,
survey run 2026-08-15.

## Raw survey — pivot/size/yaw (Step 2)

```
Machiya_1    pivot(-10.061,120.907,41.854) size(24.721,17.924,13.244) yawDeg 0.000
Machiya_4    pivot(24.336,119.594,42.963)  size(16.631,14.924,13.244) yawDeg 0.000
Machiya_East pivot(74.271,119.420,47.578)  size(21.399,15.924,13.244) yawDeg -0.201
Machiya_2    pivot(-57.365,118.437,14.920) size(14.400,14.924,13.244) yawDeg -97.004
DockDeck     pivot(-44.000,112.200,-12.000) size(14.000,0.800,10.000) yawDeg 0.000
```

Matches the earlier session's quick-survey numbers to within measurement noise, with one
correction: **Machiya_East's yaw is -0.201°, not exactly 0** — inside the ±1° tolerance, so
its envelope is still built in the world frame with `shop.yaw = 0`, but it is not perfectly
axis-aligned either. **Machiya_2's yaw is -97.004°**, far past tolerance — flagged for Task 7,
not resolved here (see chayaSurvey below).

## Footing-probe tables (Step 3)

8-point footing ring per site (4 corners + 4 edge midpoints, local-frame offsets ±size/2),
raycast from `pivotY + 40` straight down 80 studs, `RaycastParams` `FilterType = Include`,
`FilterDescendantsInstances = { workspace.Terrain }` (guarantees every hit is real terrain,
never a built part).

### Machiya_1 (apparel)
| point | world (x,z) | hitY | material |
|---|---|---|---|
| NW | (-22.42, 35.23) | 113.304 | Sand |
| NE | (2.30, 35.23) | 112.532 | Sand |
| SW | (-22.42, 48.48) | 121.080 | Sand |
| SE | (2.30, 48.48) | 111.816 | Sand |
| N_mid | (-10.06, 35.23) | 112.972 | Sand |
| S_mid | (-10.06, 48.48) | 115.464 | Sand |
| W_mid | (-22.42, 41.85) | 115.215 | Sand |
| E_mid | (2.30, 41.85) | 112.305 | Sand |

Full range 111.816–121.080 (spread 9.265). Front (NW/NE/N_mid) range 112.532–113.304
(spread 0.772) — consistent. floorY = front max = **113.30**.

### Machiya_4 (accessories)
| point | world (x,z) | hitY | material |
|---|---|---|---|
| NW | (16.02, 36.34) | 112.031 | Sand |
| NE | (32.65, 36.34) | 113.144 | Sand |
| SW | (16.02, 49.59) | 111.594 | Slate |
| SE | (32.65, 49.59) | 114.993 | Slate |
| N_mid | (24.34, 36.34) | 113.213 | Sand |
| S_mid | (24.34, 49.59) | 120.238 | Slate |
| W_mid | (16.02, 42.96) | 112.290 | Sand |
| E_mid | (32.65, 42.96) | 113.936 | Sand |

Full range 111.594–120.238 (spread 8.644). Front range 112.031–113.213 (spread 1.182) —
under the 1.5-stud flag but the widest of the three fronts. floorY = front max = **113.21**.

### Machiya_East (sportsbook)
| point | world (x,z) | hitY | material |
|---|---|---|---|
| NW | (63.59, 40.92) | 109.738 | Sand |
| NE | (84.99, 40.99) | 103.414 | Slate |
| SW | (63.55, 54.16) | 119.734 | Slate |
| SE | (84.95, 54.24) | 109.207 | Slate |
| N_mid | (74.29, 40.96) | 106.634 | Slate |
| S_mid | (74.25, 54.20) | 114.080 | Slate |
| W_mid | (63.57, 47.54) | 115.156 | Slate |
| E_mid | (84.97, 47.62) | 106.029 | Slate |

Full range 103.414–119.734 (spread 16.320). **Front range 103.414–109.738, spread 6.324 —
exceeds the 1.5-stud flag threshold on its own**, and the side probes disagree too
(W_mid 115.156 vs E_mid 106.029). This is not a flat promenade grade; the ground under this
footprint is genuinely uneven in both axes. floorY set to the front's highest hit, **109.74**,
by the same rule as the other two sites, but per the brief this is recorded as a **concern**,
not smoothed with invented terracing.

### Machiya_2 (chaya, Task 7 record only) — AABB probe, NOT the block's local frame
| point | world (x,z) | hitY | material |
|---|---|---|---|
| NW | (-49.92, 8.58) | 112.588 | Grass |
| NE | (-51.67, 22.87) | 118.988 | Slate |
| SW | (-63.06, 6.97) | 115.561 | Slate |
| SE | (-64.82, 21.26) | 124.657 | Slate |
| N_mid | (-50.79, 15.73) | 113.448 | Sand |
| S_mid | (-63.94, 14.11) | 120.276 | Sand |
| W_mid | (-56.49, 7.77) | 112.870 | Grass |
| E_mid | (-58.24, 22.07) | 117.856 | Slate |

Full range 112.588–124.657 (spread 12.069). Because the block is rotated -97.00°, this
axis-aligned ring is not meaningful for floor derivation — Task 7 needs to re-probe in the
block's own local (rotated) frame. Recorded here as raw data only.

### DockDeck
All 8 points hit **Water** at Y **109.922**, spread 0.000. The deck sits over the river —
there is no dry terrain under its footprint, only the water surface. Consistent with its
name and the design spec's "companion deck."

## Machiya_East / Overlook clearance survey (Step 3, second half)

`workspace.RoshamboStage.Overlook` bounding box: `x[54.00,91.60] y[92.10,128.30] z[-6.10,43.60]`.
Machiya_East's envelope AABB: `x[63.57,84.97] y[111.46,127.38] z[40.96,54.20]`.

All three axes overlap at the bounding-box level. Drilling into individual Overlook parts
(`workspace:GetPartBoundsInBox` around the envelope, `Include`-filtered to
`workspace.RoshamboStage.Overlook`, 118 candidate parts found nearby):

**18 Overlook parts' own AABBs intersect the envelope box directly**: `UpperDeck`,
`GirderUpperDeckX3`, `BarrierSUpperDeck1`, `RailSUpperDeckCap1`, `RailSUpperDeckMid1`, and 13
more `RailSUpperDeckB*` railing segments.

Nearest Overlook part strictly **outside** (west of) the envelope's `x0` (63.57): 
`RailNUpperDeckB3`, east face at x=62.27 — a **1.30-stud gap**.

**Concern**: the design spec calls for this shell's future interior to bore under the western
Overlook, so *some* proximity is by design — but a literal collision between the envelope and
the Overlook's already-built upper deck/railings is a siting problem for the shell itself
(Task 4), independent of the future cavern (item 7). Recorded, not resolved.

## Envelope derivations (Step 4) — literals, not re-derived

| Shop | x0 | x1 | z0 | z1 | floorY | yaw |
|---|---|---|---|---|---|---|
| apparel (Machiya_1) | -22.42 | 2.30 | 35.23 | 48.48 | 113.30 | 0 |
| accessories (Machiya_4) | 16.02 | 32.65 | 36.34 | 49.58 | 113.21 | 0 |
| sportsbook (Machiya_East) | 63.57 | 84.97 | 40.96 | 54.20 | 109.74 | 0 |

All three yaws measured at ≤0.20° from true — inside the ±1° tolerance, so all three envelopes
are built directly in the world frame (`shop.yaw = 0`), per the brief's rule.

North (lower world Z) confirmed as the frontage/promenade side for every south-row shell by
comparing NW/NE (lower Z, ~112-113 grade) against SW/SE (higher Z, climbing into the cut) —
the same relationship 花火屋's own Z0 (frontage)/Z1 (back, "into the cut") already documents.
floorY is therefore taken from front-probe data only, never averaged with the back's cut-side
scatter.

**Envelope depth tension** (flagged per the brief, not resolved): all three massing blocks are
13.24 studs deep in z — the same depth 花火屋's own holdout sibling measured before the owner
deepened its envelope to 16 (z44→z36, 2026-08-13) because "the shop held about three people, [a]
counter 4.6 studs in left barely three studs of floor to stand on." The archetype wants
frontage clearance + `COUNTER_STANDOFF` (4.4) + working room; at 13.24 these three envelopes
read exactly as tight as 花火屋's pre-gate one did. Not deepened here — the owner corrects it at
a gate if warranted. (Apparel and accessories are `interior = "shallow"`, which needs less depth
than 花火屋's full interior + stair, so the tension is milder for those two than it was for
花火屋; sportsbook is `interior = "none"`, closed-teaser-only, so depth matters least there.)

## Spec tables written (Step 5)

`roblox/tools/builders/MachiyaShops.luau` gained `MachiyaShops.apparel`,
`MachiyaShops.accessories`, `MachiyaShops.sportsbook` (envelopes/yaw/frontage/interior above,
each with a survey comment block: date, pivot, size, yaw, the full footing-ring readout, and
concerns where found), plus a `chayaSurvey` comment block (not a `Shop` table) recording
Machiya_2 and DockDeck for Task 7. `identity = nil` on all three (per the brief; kits are
Task 3+/4-6's work).

`frontage`/`interior` per the design spec: apparel and accessories are `"open"`/`"shallow"`;
sportsbook is `"koshi"`/`"none"`.

## RED/GREEN evidence (Step 6)

**RED** — `git stash push -- tools/builders/MachiyaShops.luau` (reverting only the shop
tables, keeping the new test file), then `lune run tests/run`:

```
FAIL  MachiyaShops registry > apparel carries the surveyed Machiya_1 envelope
      .../tests/MachiyaShops.spec:22: attempt to index nil with 'name'
FAIL  MachiyaShops registry > accessories carries the surveyed Machiya_4 envelope
      .../tests/MachiyaShops.spec:35: attempt to index nil with 'name'
FAIL  MachiyaShops registry > sportsbook carries the surveyed Machiya_East envelope
      .../tests/MachiyaShops.spec:48: attempt to index nil with 'name'
1110 passed, 3 failed, 1113 total
```

**GREEN** — `git stash pop`, then `lune run tests/run`:

```
1113 passed, 0 failed, 1113 total
```

(1110 pre-existing + 3 new registry tests. The `[WARN] [QUEUE] ...` / `HandlerQueue.spec:80:
boom` lines are pre-existing intentional-failure noise, unrelated to this task, present before
and after.)

`build()` was not called on any of the three new shops (Task 1's assert — "only the hanabiya
configuration is implemented until Task 3" — is still in place and untouched).

## Snapshot gate

```
$ lune run tools/genmodels
wrote assets/BonshoRig.model.json ... wrote assets/Hanabiya.model.json ... (17 total)

$ git status --porcelain assets/
(empty)

$ git diff --exit-code assets/Hanabiya.model.json
(exit 0, no diff)
```

## Lint

```
$ stylua --check src tests tools
(exit 0, no output)

$ selene src tools
0 errors, 0 warnings, 0 parse errors
```

## Concerns for the controller / owner

1. **Machiya_East terrain is uneven, not a grade.** Front-probe spread alone is 6.32 studs
   (103.41–109.74), and the west/east probes disagree by ~9 studs too. floorY 109.74 is the
   best literal reading available (highest front hit), but this site does not sit on a clean
   promenade shelf the way the other two do — worth a look before Task 4 builds on it.
2. **Machiya_East's envelope collides with the built Overlook.** 18 Overlook parts (deck,
   girder, 16 railing/barrier segments) have AABBs intersecting the envelope box; the nearest
   clear part west of the envelope is only 1.30 studs away. Some proximity is intentional (the
   future cavern bores under the Overlook), but the shell's own footprint overlapping the
   already-built upper deck is a separate siting question.
3. **Envelope depth tension** — all three shells inherit the massing blocks' 13.24-stud depth,
   the same depth 花火屋's holdout was before the owner deepened it to 16 for headroom behind
   the counter. Not fixed here (owner-surveyed literals are never re-derived); flagged for the
   owner to weigh in at a gate.
4. **Machiya_4's front spread (1.18 studs)** is under the 1.5 flag threshold but is the widest
   of the two "clean" fronts — worth knowing it's not as flat as Machiya_1's.
5. **Machiya_2 (chaya) is rotated -97.00°**, far past the ±1° tolerance used for the other
   sites. Its footing ring above is an axis-aligned AABB probe and is NOT the right frame to
   derive a floor from — Task 7 needs to re-survey in the block's own local (rotated) frame
   before writing its envelope.

## Files touched

- `roblox/tools/builders/MachiyaShops.luau` — added `apparel`, `accessories`, `sportsbook`
  Shop tables + survey comments + `chayaSurvey` comment block.
- `roblox/tests/MachiyaShops.spec.luau` — extended with three new registry tests.
