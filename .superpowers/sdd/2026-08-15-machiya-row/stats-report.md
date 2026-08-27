# 番付 — the Stats false front (Task: stats shell, 2026-08-15)

Branch `m4b-zendojo-art-pass`. **Stopped at the owner gate.**

Owner rulings honoured: the barred term appears nowhere in shipped names, identifiers,
or signage — the registry key is `stats`, the model/asset is **MachiyaStats**, the sign
reads **番付** (banzuke, the Edo ranking list — literally a leaderboard, no wagering
sense). The Machiya_East siting is dropped: the old registry entry was renamed and
re-sited, not left dead; the massing block stays parked, unassigned; the old survey
lives in git history.

## Envelope derivation (pinned by tests)

| edge | value | derivation |
|---|---|---|
| x1 | −23.92 | apparel's x0 (−22.42) − 1.5 roji — the row's own gap, relationship-tested like the two 花火屋 neighbour tests |
| x0 | −33.92 | x1 − 10: a 10-stud two-bay frontage |
| z0 | 35.23 | = apparel's z0 — the street line runs continuous |
| z1 | 43.23 | z0 + 8: shallow, it is a facade against the hill |
| floorY | 113.30 | = apparel's — one promenade grade |

`frontage = "open"`, `interior = "shallow"` (vestibule: no counter, no goods, no dress;
the cavern opens from the back wall at a later item), `frontPosts = 3`.

## FRONT_POSTS made per-shop — what it touched

`Machiya.build` now reads `shop.frontPosts or 5` (assert ≥ 3). Everything that keyed
off the constant, and what each does at 3 posts / 2 bays:

- **CLOSED end bays** — only assigned when there are ≥ 3 bays. A two-bay front closes
  nothing: BOTH bays open (the ruling).
- **HeadRail + Counter** — re-registered to the OPEN span (first open bay's west post →
  last open bay's east post), computed once. With the default closed ends that is
  `postX[2]..postX[FRONT_POSTS−1]`, the exact expression they always used; at 3 posts
  the rail spans the whole frontage (9.51 studs). The counter (full interiors only)
  rides the same span, killing the latent zero-width-counter bug at 3 posts.
- **Door leaves** — a parked full-width leaf needs a CLOSED neighbour to hide its
  slid-away third behind; with none anywhere it would overhang the corner or the next
  doorway. Bays with no closed neighbour ship their screens STORED (no leaf); transoms
  remain. Default bays each have a closed neighbour → identical emission.
- **Noren** — walks the open bays as before; both stats bays hang three pine-green
  panels; `centrePostIdx` (even-count mon flanking) is only read for even panel counts.
- **Sign widths** — key off W, not the post count; the wall kanban is W·(7.8/17.93) =
  4.35 at this frontage, ample for two characters.
- **Found while here (width, not post count, but load-bearing)**: the mushiko-mado
  window was unconditionally 12 wide — on the 10-wide envelope its jambs went
  NEGATIVE. `WIN_HALF = min(6.0, SW/2 − 1.0)` (every wider shop lands on the literal
  6.0 — accessories' 6.145 is the tightest); the kōshi bar count now follows the
  window at the same 1.5/stud pitch (2·WIN_HALF·1.5 = exactly 18 at the default).
  A test holds every stats part to strictly positive size.

**Default-inertness proof**: after all changes, `lune run tools/genmodels` left EVERY
committed asset byte-identical (`git diff --exit-code` clean; sha256 of Hanabiya /
MachiyaApparel / MachiyaAccessories unchanged from pre-task baseline
bdf6127f… / b276fcba… / 9ffe2734…), plus a test pinning the default build at 5 posts /
2 closed / 2 leaves.

## Identity choices

- **Noren**: deep pine green `{0.12, 0.25, 0.18}`, 4 segments, mon **丸に番** (same
  monFace mechanism, 74 px like the others). Chosen against the row: apparel's indigo
  leans violet, accessories' navy is its deeper cousin, 花火屋 is vermilion — the
  row's cloth is all blues and reds, so green is unclaimed and distinct at a glance.
- **Chōchin**: pale celadon `{172, 192, 178}` — green with a cool lean (b > r), off
  accessories' warm moss `{168,180,152}` (r > b); Rec. 709 luminance **0.732** ≥ the
  0.55 guard (Chochin.spec walks every registry tint automatically).
  **`corners = "west"` — ONE lantern** (new kit opt-in, nil = pair, byte-inert): the
  east corner sits on the roji where a barrel would truly intersect apparel's west
  lantern — same z0 AND floorY, centres 1.2 apart against 1.3 of summed radii. The
  cross-shop audit test would have caught this; the option removes it.
- **Board**: lettered wall kanban, `kind = "wall", text = "番付"` — shared `kanjiFace`
  per-character lettering (Char1 番, Char2 付), cream plaster + sumi (the wall kind's
  defaults), framed, tilted −15°, occlusion-guarded above the eave.
- **Glow**: the row's warm `{1.0, 0.85, 0.6}` at 1.2.

## Terrain cut (Studio, place-only — **cannot be unit-tested; the owner's eye is the gate**)

**Before** (raycast grid, Terrain-filtered, y at x = −35.42 … −22.92 step 2, z rows):

```
z=33.23: 113.87 113.80 113.66 113.46 113.35 113.19 112.93 112.85
z=35.23: 114.67 114.28 114.08 113.74 113.56 113.29 112.96 112.87
z=37.23: 116.04 115.59 114.99 114.37 113.90 113.39 113.07 112.95
z=39.23: 117.54 117.10 116.52 115.65 114.80 113.53 113.21 113.06
z=41.23: 119.18 118.63 117.93 117.23 116.25 114.72 113.39 112.54
z=43.23: 121.78 120.48 119.52 118.87 118.04 116.28 114.02 112.69
z=44.23: 123.32 122.02 120.36 119.71 118.94 117.60 114.34 112.79
```

**Operations, in order (all removal — nothing was filled anywhere):**
1. `Terrain:FillBlock(CFrame(−28.92, 119.025, 38.73), (12.0, 11.95, 9.0), Air)` —
   box x[−34.92,−22.92] y[113.05,125.0] z[34.23,43.23].
2. `Terrain:FillBlock(CFrame(−29.17, 119.025, 39.48), (12.5, 11.95, 10.5), Air)` —
   extended 1.5 south / 0.5 west after pass 1 left the interior 1+ proud.
3. `WriteVoxels` on a 4k-aligned region — **no-op** (0 cells), which exposed that the
   voxel grid here is OFFSET BY 2 (cells span [4k+2, 4k+6)); 4k-aligned ops resample.
4. `WriteVoxels` true grid, region x[−34,−22] y[110,126] z[34,42]: floor layer
   y[110,114] occupancy capped at **0.825** (isosurface → 110 + 4·0.825 = 113.3 =
   floorY), `min(existing, cap)` so ground already below floor is untouched;
   y[114,126] → air. 3 cells changed.
5. `WriteVoxels` two cells x[−34,−30] z[34,38]/[38,42] y[110,114] → occ 0.60, trying
   to pull the west bulge down; the render CLAMPS at the cell top (114.00) against the
   full west columns — no visible change; left in place (the dip hides under the slab).

Deliberately NOT touched: z ≥ 42 cells (the hill the back wall stands against — the
vestibule's back being rock is the design; flush-clearing needs a 2.8-stud bite into
the cavern's own front slice, the later item), x < −34 hill face, street z < 34, y < 110.

**After** (same grid):

```
z=33.23: 113.83 113.71 113.51 113.23 113.12 113.04 112.91 112.82
z=35.23: 114.10 113.96 113.84 113.45 113.18 113.05 112.90 112.81
z=37.23: 114.93 114.00 113.95 113.61 113.24 113.09 112.94 112.85
z=39.23: 115.85 114.00 113.95 113.64 113.31 113.16 113.00 112.88
z=41.23: 117.55 114.00 113.87 113.61 113.70 113.23 113.01 112.40
z=43.23: 121.34 119.70 117.36 116.48 115.62 113.87 113.04 112.43
z=44.23: 123.22 121.64 119.57 118.72 117.89 116.04 113.15 112.53
```

**Result**: east doorway approach at/just under grade; centre floor within ~0.3 of the
slab; the rock back rises from ~z 42 (the concept). **Residuals for the owner's eye**:
(a) a west interior strip clamps at 114.00 — ≤ 0.7 proud through the slab for ~1.5–2
studs off the west wall, tapering east (reads as the hill's toe spilling into the
room's west side; pushing lower would pit the STREET, since that voxel cell straddles
the frontage); (b) the west doorway approach steps up 0.3–0.6 at the jamb.

**Collateral (flagged, not reversible from data held)**: the resampled FillBlock pass 2
cleared the x[−38,−34] cell column above y 114 across z 34–44.7 — the hill slice just
west of the shell dropped ~1–1.6 on the measured x −35.42 column (e.g. z 41.23:
119.18 → 117.55), and the z 44.23 toe behind the back wall eased 0.1–1.4. It reads as
a wider bench beside the shell; I hold surface probes, not voxel snapshots, so exact
restoration isn't possible — the owner's eye gates it. (Lesson recorded in the ops
list: this terrain's grid is offset by 2; use offset-aligned WriteVoxels only.)

## Clearances (rotation-aware full extents; tests hold the starred ones)

- *Roji to apparel*: envelope gap 1.5; built wall faces 1.88 apart; stats' ridge east
  end −23.32 vs the guard line apparel.x0 − 0.8 = −23.22 (0.10 margin); eave −23.42.
  Apparel's west chōchin (x ≥ −23.256) is 6 studs z-separated from the ridge.
  *Cross-shop audit: zero 3-axis overlap between every stats part and every apparel part.*
- *Stair*: the live RiverSquareStair geometry measures x[−90.3, −43.8] z[23.6, 34.8] —
  its east end is **9.2 studs** west of stats' westmost part (ridge −34.52) and ~5.8
  west of the westmost terrain disturbance (x ≈ −38). Nothing undercut. (The brief's
  "x −49.9…6.4" did not match anything at the site; measured live instead.)
- *Doorways*: two, each **4.27 studs clear** post-face to post-face (no leaves), 6.8
  head clearance (kamoi).
- *Promenade*: at ground level nothing crosses z0; aerial only — eave AABB to z0−2.52,
  west chōchin barrel to z0−2.84, both a storey up (the row's accepted overhang; the
  drip line sits 0.13 south of z 32.6).
- *Back wall burial*: rock against the back face from ~0.1 above floor at the east end
  to **~6.4 studs** (119.7) at the west corner; hill behind rises to 123+ at z 44.
- *Tower*: every part ≤ towerTopY − 9 (tested).

## RED → GREEN

RED: suite collection fails on `MachiyaShops.stats == nil` (registry, relationship,
shell, mon-CASES and cross-audit tests all written first). GREEN after implementation:
**1188 passed, 0 failed** (from a 1174 baseline; the two Machiya_East tests were
replaced with their stats successors). One mid-implementation find promoted to a test:
the negative-jamb window (positive-size guard).

## Gates

- `lune run tests/run`: **1188 passed, 0 failed**
- `lune run tools/genmodels` ×2: **byte-identical** (sha256 over all assets)
- `git diff --exit-code` on Hanabiya / MachiyaApparel / MachiyaAccessories: **clean**
- genmodels ran BEFORE the project.json edit; registration order: asset →
  `default.project.json` (`MachiyaStats`) → `WorkspaceConvention.DECLARED_STAGE_CHILDREN`
  (with comment) → genmodels again
- `rojo build -o /tmp/statsbuild.rbxl`: **OK** (no .rbxl in the repo); UDim2 offsets all
  whole ints (kanjiFace/monFace already floor them)
- `stylua --check src tests tools`: clean; `selene src tools`: 0 errors, 0 warnings
- `default.project.json`: valid JSON
- Live serve: MachiyaStats confirmed standing in the place (63 parts probed at site)

## For the owner's eye

1. The west interior floor strip (≤ 0.7 proud) and the rock toe at the vestibule's
   back — intended character or further hand-sculpt?
2. The collateral bench west of the shell (x −38…−34 slice, ~1–1.6 lower than before).
3. Pine/celadon pairing and the single west lantern — all gate-tunable literals.
4. The kanban ground is the wall kind's cream+sumi (same ground as 花火屋's board);
   say the word if the fourth shop should take a fourth ground.
