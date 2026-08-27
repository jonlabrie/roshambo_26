# The Stats rear doorway + cavern draft markers (2026-08-16)

Branch `m4b-zendojo-art-pass`. **Stopped at the owner gate.** No terrain touched, nothing
bored, no room built — markers only, for the owner to drag.

## Deliverable 1 — the rear doorway (identity.rearDoor)

A **per-shop capability**, `identity.rearDoor = { width, noren = {…} }`, default OFF —
the archetype's solid `WallBack` path is byte-for-byte the old code, and all three
protected assets diffed clean after genmodels (the proof). Stats sets
`rearDoor = { width = 6.0, noren = { color = {0.12,0.25,0.18}, segments = 4 } }`.

### Geometry (stats numbers; everything derived in the builder)

Wall planes: stucco box back face SZ1 = z1 − 0.30 = **42.93** (the plane the bore meets),
inner face 42.43. CX = −28.92, FLOOR = 113.30, kamoi HEAD_Y = FLOOR + 6.8 = **120.10**.

| member | size | registration |
|---|---|---|
| opening | **6.0 clear** (post face to post face), centred on CX: x[−31.92, −25.92], floor→120.10 | width is the caller's (the bore recipe nets ~6); head is the shop's own kamoi, the number every doorway in this building clears |
| WallBackWest/East | 0.71 × 9.0 × 0.5 | outer face on SZ1, WALL_T thick — exactly where WallBack sat; they run to the side walls' inner faces (x −33.12 / −24.72) so the corner stays closed, and their cut ends MEET the posts (tested: no gap, no overlap) |
| RearDoorPostWest/East | 0.49 × 6.8 × **0.84** | depth = WALL_T + FRAME_D2: through the wall, outer face **flush on SZ1** (flush-outside-edges — the tunnel meets a flush plane), standing 0.34 proud of the inner face into the vestibule ("stucco sits back, timber stands proud"); CypressVertical |
| RearDoorLintel | **6.98** × 0.5 × 0.84 | bears post outer edge to post outer edge (never floats over the clear span); bottom at HEAD_Y; CypressWeathered — a horizontal member, the stair-timber distinction |
| WallBackHead | 6.98 × 1.70 × 0.5 | sits ON the lintel's top (120.60), rises to the storey top (122.30), same width as the lintel, back on the stucco plane |

**Floor**: nothing added. The FloorSlab already runs to z1 = 43.23 with its top at 113.30;
the test holds that AND sweeps a passage box (clear width × floor→head × through the wall)
against every collidable part's rotation-aware AABB — no step, no leaf, nothing in the way.

### The noren / sway finding

`NorenSway.client.luau` groups tagged segments **by parent model** and rebuilds each frame
as `CFrame.new(pos) * CFrame.Angles(ax, 0, az)` — i.e. it assumes **yaw 0** (±z-facing
panels) and reads only the X euler as the rest lean. The rear panels satisfy both: each is
its own `RearNoren_{k}` model (so they never merge with a frontage panel's chain), built
with `rotX` only, and stats is `yaw = 0`. A test pins each segment's rotation top row at
{1,0,0}. **Tagged `NorenSeg` — safe.** (Noted for later: the same yaw-0 assumption already
applies to every frontage noren; the chaya at yaw −97° will need the client generalized
before ITS cloth is tagged.)

The hang is `emitNoren` mirrored in z: same NOREN_H 2.6 / 3-segment-panel default (stats
rides its identity's 4), same 0.16 slit, same NOREN_BELLY lean and integer jitter (bay
index 0), with the geometric walk AND the rotation negated together so the hem walks **−z,
into the vestibule**, hung 0.06 off the wall's inner face — the frontage's own standoff,
mirrored. Pine green, Fabric + NorenCloth, alpha 0.1. Sway direction cannot cross the wall:
the client scales the rest lean by 0.15×–1.85× of itself, and the rest lean points into
the room.

## Deliverable 2 — `roblox/tools/studio/draftStatsCavern.luau`

Follows the `draftRiverPathMarkers` conventions: a sub-folder of the place-only
**`Workspace.PathDraft`** (NOT RoshamboStage — Rojo owns exactly what the project file
names), 4-stud Neon balls, Anchored / CanCollide false / CanQuery false, tagged
`DevMarker` so `hideDevMarkers.client.luau` hides them in Play, terrain-Include raycast
from y 500 so every marker sits **on the surface** (+1) — visible and grabbable, never
buried in rock; the bore ignores Y anyway. Studio-pasted: no `require()`, seed literals
mirrored from `MachiyaShops.luau` / `Machiya.luau` with a comment saying so.

**Guard**: the `buildHanabiyaChochin` pattern, NOT the river tool's clobber —
`REBUILD = false` at the top; if `PathDraft.StatsCavern` exists the tool returns a refusal
naming the flag. Verified live: second run refused ("already exists (9 markers)").

### Placed (run once via Studio MCP, Edit datamodel)

Pink route (XZ handles, doorway → hill): StatsRoute_01 (−28.9, 120.7, 44.9) ·
02 (−28.9, 124.6, 48.0) · 03 (−28.4, 131.5, 52.0) · 04 (−28.0, 145.2, 56.0) ·
05 (−28.0, 152.3, 60.0). Orange room corners: NW (−35.0, 160.6, 62.0) ·
NE (−21.0, 145.7, 62.0) · SW (−35.0, 164.8, 74.0) · SE (−21.0, 158.7, 74.0).
(Y values are today's surface — the wall climbs ~40 studs over the 30-stud run, so the
seeded chamber sits ~45–50 studs under grade: real cavern depth.)

## RED → GREEN

RED first: 6 new tests failed for the right reasons (no `rearDoor` in the registry;
`WallBack` spanning the passage box; no frame parts; no RearNoren). GREEN after:
**1195 passed, 0 failed** (baseline 1188 + 7 new; the inertness test passed trivially at
RED, which is its job — it guards the future). Tests live in
`tests/MachiyaShops.spec.luau` ("stats rear doorway — the cavern's mouth").

## Gates

- `lune run tests/run`: **1195 passed, 0 failed**
- `lune run tools/genmodels` ×2: **sha256-identical** across all assets
- `git diff --exit-code` on Hanabiya / MachiyaApparel / MachiyaAccessories: **clean**
  (only `MachiyaStats.model.json` changed — committed)
- `rojo build -o /tmp/statsdoor.rbxl`: OK (no .rbxl in repo; no UDim2 touched)
- `stylua --check src tests tools`: clean; `selene src tools`: 0 errors, 0 warnings
- `default.project.json`: **untouched** (no genmodels-before-edit hazard arose)
- Live `rojo serve`: the regenerated MachiyaStats syncs from disk; markers confirmed in
  the place (9 placed, guard re-run refused)

## For the owner to drag before the bore

1. **The pink route** (StatsRoute_01..05): today it runs straight south from the doorway,
   easing slightly east. Bend it wherever the tunnel should snake; add/renumber markers to
   taste (keep indices contiguous). Route_01 sits 2 studs behind the rear wall — keep the
   first marker roughly on the doorway's centreline (x ≈ −28.9) so the bore meets the
   6-stud mouth square rather than at an angle.
2. **The orange corners** (StatsRoom_NW/NE/SW/SE): a seeded ~14 × 12 chamber whose near
   edge is 2 studs past the route's end. Drag to the footprint you want; the seeds are
   pure guesses about size AND distance into the hill.
3. Terrain shaping is yours first — nothing here carved, and the doorway's outer plane
   (z 42.93, x[−31.92, −25.92], floor 113.30 → head 120.10) is the fixed mouth the bore
   should arrive at with no step.
