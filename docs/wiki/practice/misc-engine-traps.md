---
shelf: practice
updated: 2026-08-16
---

# Misc Engine Traps

Small, self-contained Roblox engine and pipeline traps that don't belong to a bigger
recipe. Each cost real time once.

## SurfaceGui text: TextSize caps at 100px — use a SMALL canvas

`TextLabel.TextSize` is hard-capped at **100px** — setting 300 reads back 100. And
`TextScaled = true` did **not** scale up on the Roshambo jumbotron SurfaceGui
(TextBounds stuck at 100 even on a half-canvas probe label, with or without a
`UITextSizeConstraint.MaxTextSize`).

**How to get large SurfaceGui text:** make the `CanvasSize` SMALL so a ≤100px glyph is
already large *relative to the canvas*; the SurfaceGui (SizingMode=FixedSize) then
stretches that small canvas across the big world part. Jumbotron (168×96 studs):
CanvasSize ≈ `#rows*150 × (that*168/96)`, fixed `TextSize=90`, `TextScaled=false`,
scale-based cell positions → ~10-stud glyphs readable across the bowl. Code in
`roblox/src/client/BoardController.client.luau` (commit `bb3ea7c`). Verify rendered
text via screenshot, not property reads ([[studio-tooling]]).

## `require()` caches per VM — probe `.Source`, not the returned table

Studio's command-bar / plugin VM caches a ModuleScript's *result*. Once anything in that
VM has `require`d a module, every later `require` in the same session returns the SAME
table — even after Rojo syncs new source into it. Nothing invalidates it but a Studio
restart or a Play-mode transition into a fresh VM.

**How this bites:** a diagnostic that reads current values by `require`ing the module
reports the state at first-require, not the state now. Chasing "some boards didn't take
the change" 2026-08-17, a probe compared built parts against `require(StatsRoomLayout)`
and reported the module as un-synced. It was fully synced; the probe was reading a table
cached when `buildStatsBoards.luau` ran an hour earlier. The real cause was elsewhere
(the Studio tool had not been re-run, so the PARTS were stale).

**Do this instead:** read `module.Source` and search it for the expected text. Source is
a live property and is never cached.

```luau
local m = ReplicatedStorage.RoshamboShared.StatsRoomLayout
print(m.Source:find("h = 7.2", 1, true) ~= nil)  -- truth; require() may lie
```

Corollary for any Studio build tool that reads a shared module: **its output can be stale
in two independent ways** — the source may not have synced, or the VM may be holding an
old copy. They look identical from the built artefact. See [[studio-tooling]].

## Flat Beams: width follows the attachment's UP vector

A Beam's WIDTH extends along its **attachment's Up vector**, and `FaceCamera=false`
keeps that orientation fixed. So:

- Attachment Up = world **+Y** → the beam stands up as a **vertical fin**
  perpendicular to the flow (the classic bug). `CFrame.lookAt(p, p+flow, UP)` produces
  exactly this — wrong for flat water.
- Attachment Up = **horizontal cross-stream** → the beam lies **flat** (width spreads
  sideways, surface faces up). Build it with
  `CFrame.fromMatrix(pos, flowDir.Unit, crossStream)` where
  `crossStream = flowDir:Cross(Vector3.yAxis).Unit` (Right=flow, Up=cross).

`FaceCamera=true` is fine for VERTICAL beams (waterfall cascades) but terrible for
horizontal/flat ones — it tilts them to billboard the camera. Proven in
`roblox/tools/studio/upcanyonRiverPOC.luau` flow beams ([[blender-pipeline]]).

## Curved tunnel bore (Catmull-Rom + FillBlock)

Boring a curved buried tunnel (teahouse tunnels, 2026-07-01/04): route a Catmull-Rom
spline through waypoints, snapshot the region, carve Air boxes along it.

- **FillBlock voxel-resolution gotcha (the big one):** terrain voxels are **4 studs**.
  A box thinner than ~4 in ANY dimension gets antialiased to nothing — it won't clear
  the voxel. Every box dimension ≥ ~5–6, and step the boxes so they **overlap
  generously** (`W=10,H=13,len=8,step=2.0` worked → each voxel fully inside several
  boxes).
- **Carve HEIGHT ≥ 12 (not 8).** H=8 pinched to ~4 studs of walkable headroom after
  voxel aliasing on a climbing ramp. H=12 with box bottom 1 stud below the floor line
  gives a reliable 8-stud clear. Width can be narrow (carve W~7 → net ~6).
- **Verify the bore with OCCUPANCY-COLUMN reads, NOT raycasts.** Read a tall thin
  column (`Region3` 2-wide in XZ, ±16 in Y), scan occupancy `<0.4` = air, report the
  air Y-range = floor..ceiling. Raycasts land in/out of the pocket unpredictably, and
  `ReadVoxels` + `ExpandToGrid(4)` can snap to the solid floor below (false "solid").
- **Buried draft markers are invisible/ungrabbable** (inside rock). Place route
  markers ON THE SURFACE (raycast surface Y) as XZ handles; ignore their Y and RAMP
  the floor below.
- **Stay buried:** before boring, sample the surface along the planned XZ and require
  `surface > floorY + headroom`. The direct line often crosses a low gorge — route
  through the high rock corridor. Mouths may be exposed.
- **T-junction into an existing tunnel — match the WALL and the FLOOR:** enter the
  wall the corridor naturally reaches ("from the north/south" is ambiguous — clarify
  which WALL), and aim the curve's end at the existing tunnel's **actual floor**
  (probe it), not the marker Y — else a ~10-stud step at the junction.
- **PasteRegion rollback is UNRELIABLE** (residue; and a follow-up FillBlock "cleanup"
  made bulges — worse). If a bore goes wrong: the owner restores their own backup, OR
  restore the CopyRegion snapshot and STOP — don't chase residue with more FillBlock.
  And don't rely on the snapshot surviving: a Studio Ctrl+Z once swept up CopyRegion +
  bore together.
- **Terrain writes are INVISIBLE to raycasts in the same execution.** A `FillBlock` then a
  `Raycast` in one `execute_luau` call reads the OLD surface — a before/after profile came
  back byte-identical and looked like the fill had silently failed. Always verify in a
  SEPARATE run. (Stats cavern, 2026-08-16.)
- **A flat-topped box over a ramping target overshoots** by the ramp's rise across the box
  depth, and voxel rounding adds more: a berm planned at 126 landed at 128.85 and pierced a
  roof eave. Use THIN slices (depth ~2, step 0.5) with the top computed at each slice's own z.
- **A rotated part's lowest point is not `Position.Y - Size.Y/2`.** Compute it from the 8
  transformed corners. A machiya's sloped `RoofSouth` read 129.3 naively and 127.20 truly —
  a 2.1-stud error, in the direction that drives terrain through the roof.
- **Carve PROUD of the intended wall (~1.5).** Boundary boxes have no successor to overlap
  with, so the finished face erodes inward; a chamber came out ~2 studs short on every edge.
- **A "clear >= N" filter cannot then report min-clear** — it is self-referential and always
  reports ~N. Take extents from the filter, then re-measure over an INSET interior.
- **Rays starting inside partial-occupancy voxels report phantom breaches.** An upward ray
  from inside sub-threshold material hits nothing and reads as "open to sky". Corroborate any
  breach claim against a surface raycast before believing it.
- **DON'T over-sanitize tunnels — organic imperfection is WANTED** (owner,
  2026-07-01). Lumpy walls, an oblique T-junction, an accidental tight squeeze were
  all praised as character. Get the walkable floor + wall/junction right; leave the
  rough interior; don't fill hidden pockets unless asked. ([[owner-rulings]])

## genmodels arch portability (CI drift)

The `roblox-ci` step "Generated models are current" runs `lune run tools/genmodels`
then `git diff --exit-code assets` — committed `roblox/assets/*.model.json` must be
**byte-identical to what genmodels produces on GitHub's x86_64 runner**, and dev
machines are arm64. Transcendental libm functions (`math.sin/cos/atan/...`) are NOT
bit-identical across arch; IEEE basic ops (`+ - * / %`, `math.floor`, `math.sqrt`)
ARE. Two rules for `roblox/tools/builders/`:

1. **No transcendental-based pseudo-random.** The `fract(sin(seed*12.9898)*43758.5453)`
   sine-hash is the worst offender. Use a portable integer hash (LCG over basic ops) —
   `FoliageScatter.luau` is the reference pattern.
2. **Snap near-zero residues to 0.** Rotation matrices from trig carry residues like
   `cos(pi/2)=6.12e-17` whose exact value is arch-dependent. `JsonEmit.encode` snaps
   `|v| < 1e-9` to `0`.

Fixed in `57e0a92`; verified by regenerating in an emulated
`--platform linux/amd64 ubuntu:24.04` container with the pinned lune x86_64 binary and
byte-comparing (0/13 assets drifted).

## Teahouse floor vs pivot

The legacy canyon teahouses are **kake-zukuri** — cantilevered on long `EngawaPost`
stilts mostly buried in the cliff. So the model **pivot / bounding-box centre Y is NOT
the floor level** — it's pulled way down by the stilts (Teahouse_01: pivot Y≈94.6,
actual deck floor Y≈201.5 — a ~107-stud difference; it once made a level tunnel exit
read as a 108-stud cliff descent).

**To find the real living/entry level, probe named parts, NOT the pivot:** `Deck` (top
≈ floor), `EngawaF`/`EngawaS` (veranda floor), `Table`, `RailCap`/`RailMid`. Stilt /
`EngawaPost` / `Girder` / `Perim*` parts run far below. Same family as the rotated
bounding-box trap on [[one-model-is-not-a-building]]. (The legacy teahouses now live
in `ServerStorage.RetiredLegacyTeahouses` — [[teahouses]]; compass N=−Z / S=+Z —
[[canyon]].)
