# Task 4 Report — Apparel (Machiya_1), the row's first shell

**Status: COMPLETE — stopped at the OWNER GATE.** Commit `48a15ea` on `m4b-zendojo-art-pass`.

## Identity values chosen

| Field | Value | Why / source |
|---|---|---|
| `noren` | `color = {0.16, 0.18, 0.32}`, `segments = 5` | The brief's fallback literal. Checked `roblox/src/shared/themes/ZenDojo.luau` first: its only blue is `water = {0.20, 0.35, 0.43}`, a mid teal, not a deep indigo — so no palette entry qualified. Noted in-code for the owner to retune at the gate. |
| `chochin` | `true` | Per brief — eave-corner pair, the kit emits `ChochinWest`/`ChochinEast` (hem-height assert passed at this shell's 9.0 storey). |
| `board` | `true` | Blank timber kanban (`SignBoard`) above the kamoi. No texture — the glyph-pipeline treatment is a gate follow-up, per brief. |
| `glow` | `color = {1.0, 0.85, 0.6}`, `brightness = 1.2` | Per brief. Interior is `"shallow"`, so both `InteriorGlow_*` hooks emit. |
| `dress` | function, below | `Spec` now required at the top of `MachiyaShops.luau` (needed for `Spec.part`/`Spec.cframe`/`Spec.model`). |

## Dressing manifest (env: x[-22.42, 2.30], z[35.23, 48.48], floorY 113.30; w=24.72, d=13.25, cx=-10.06)

All positions derived from `ctx.env` / `ctx.consts` — no world literals. All Y below given as offsets from floorY.

**Two kimono racks** (`KimonoRackWest` / `KimonoRackEast`), one per open bay, plane at z0+1.2 (z=36.43):
- The frontage's 5 posts make 4 bays; outer two closed, so open bays 2 and 3 (centers cx∓W/8 = −13.15 / −6.97) are trivially "the two westmost open bays".
- Posts: 0.3² × 5.5, centers ±2.85 from rack center (span 5.7). **Thinned from the brief's implied geometry**: the two bays are adjacent (6.18 studs each), and a rack wide enough for three 2.2-stud cloths (≥6.6) would interpenetrate its neighbour at the shared mid-post. Per the "thin it, never push through" rule: span 5.7, cloths thinned 2.2 → **1.7** wide (× 3.8 × 0.15, Fabric, hem 1.5 off the floor). Gap between the racks' facing posts: 0.18.
- Rail: 0.2² × 6.0, ends flush with post outer faces, top flush with post tops (mortise read: rail passes through the 0.3 posts — the only intentional overlap in the set).
- Cloth colours alternate `palette.vermilion` / `palette.water` with the parity offset between racks (V-W-V / W-V-W).
- **Collision:** posts collide; rail and cloths are `CanCollide=false` — the racks stand in the only two doorways, the rail at 5.4 would clothesline a 6-stud avatar, and colliding cloth would seal the shop. Players walk through cloth, around posts.

**Fold table** (`FoldTable`), mid-CUSTOMER-floor at (cx, z=39.75) — halfway between the rack plane and the counter's front face, not the envelope's cz (a 2.6-deep table at cz pokes 0.08 into the counter; caught in planning, not emitted):
- Top 4.0 × 0.2 × 2.6, surface at +2.5; four 0.25² legs, outer faces flush with the top's edges.
- Three folded-cloth stacks 0.9 × 0.5 × 0.6, Fabric, on the surface at scattered offsets, vermilion/water/vermilion.
- Aisles: 1.87 to the racks, 2.03 to the counter face.

**Counter**: 14.83 (60% of w) × `ctx.consts.COUNTER_H` (3.0) × 2.0, center z1−4.4 (花火屋's `COUNTER_STANDOFF`, measured to the CENTRE exactly as `Machiya.luau` does). Working aisle behind it: back face z1−3.4 to the back wall's inner face = 2.6 — same as 花火屋 post-gate. Customer floor front-to-counter-face ≈ 6.65 studs: not cramped, no thinning needed there.

**Rear shelf** (`RearShelf`): board 14.83 (full counter width) × 0.4 × 1.2, center +5.5, **back face exactly on WallBack's inner face** (z1 − 0.8 = STUCCO_SETBACK 0.30 + WALL_T 0.5 — the one derivation restating archetype constants not in `ctx.consts`; commented in-code, walls-register-to-structure). Two 0.3 × 0.3 × 1.0 brackets under it against the wall (a board 5.5 up with nothing holding it reads as a floater). Five 0.8³ cloth bolts sitting on the top surface, vermilion/water with a gold centre.

## TDD

- **RED**: added requires (Machiya, ZenDojo, ArenaLayout) + `allParts`/`find` helpers (copied from `Machiya.spec.luau`, with its nested-model note) + the brief's `apparel shell` describe block to `roblox/tests/MachiyaShops.spec.luau`. Run: `1120 passed, 1 failed` — the Dressing test failed (`expected false to be true`, no Dressing yet); the tower guard passed against the bare shell.
- **GREEN**: after filling `identity`: `1121 passed, 0 failed, 1121 total`.

## Gates

- **Byte gate**: `git diff --exit-code roblox/assets/Hanabiya.model.json` clean after genmodels (identity kit is fully nil-guarded; 花火屋 untouched).
- **Suite**: 1121/1121 (the HandlerQueue `[WARN]` lines are that spec's own expected noise).
- **Lint**: `stylua --check src tests tools` clean; `selene src tools` 0 errors / 0 warnings.
- **Registration**: genmodels `OUTPUTS["MachiyaApparel"]`; `default.project.json` line after Hanabiya's; `WorkspaceConvention.DECLARED_STAGE_CHILDREN` entry with comment. `assets/MachiyaApparel.model.json` generated (70KB) and committed. No trig-derived floats in the dressing (plain arithmetic only) — arch-stable.

## Self-review (full-extent AABB walk, scripted)

Built the model and checked every Dressing part's rotation-aware AABB pairwise against every other Dressing part and every shell part (Threshold trigger excluded), plus envelope and floor bounds:

- **Overlaps found: 4** — each rack's rail through its two posts, 0.2 deep, the intentional mortise. Nothing else.
- **Dressing vs shell: zero** — clear of door leaves (rack front faces at z0+1.05/1.125 vs leaf back ~z0+1.0), bay panels, walls, frontage posts.
- **Envelope/floor: zero violations** — full extents, not just centers. Max z is the shelf's back face at 47.68, exactly the wall's inner face, 0.8 inside z1.
- **Floaters: none** — cloth tops flush to rail underside, bolts on shelf top, stacks on tabletop, legs and posts on the floor, brackets flush to shelf underside and wall.

## Concerns for the owner's eye

1. **Cloth width 1.7 vs the design's 2.2** — the geometric necessity above. If the owner prefers full-width cloths, options are: two cloths per rack at 2.2, or racks shifted apart so ~1/3 hides behind the closed end bays.
2. **Racks occupy both doorways** — the brief's placement. Enterable (non-collide cloth/rail), but the first-person read of walking through hanging cloth is the owner's call.
3. **Noren indigo is a non-palette literal** — flagged for retune.
4. **Shelf underside at +5.3** could brush a 6-stud avatar standing hard against the back wall; it lives behind the counter, off the customer floor.

**Next**: owner reconnects Rojo (project.json re-read needs plugin reconnect) and looks. Task 5 not touched.

---

# Fix report — gate correction round 1 (commit `94d7882`)

**Finding relayed:** the apparel footprint overlapped 花火屋 — surveyed x1 = 2.30 vs hanabiya x0 = −1.67, ~3.97 studs of interpenetration. The massing block predates the built shop; register to the BUILT edge.

## Envelope, old → new

| | old | new |
|---|---|---|
| x1 | 2.30 (stale survey) | **−3.17** = 花火屋's west face (−1.67) − 1.5 roji |
| x0 / z0 / z1 / floorY | −22.42 / 35.23 / 48.48 / 113.30 | unchanged (still surveyed) |
| w / cx | 24.72 / −10.06 | 19.25 / −12.795 |

Comment in `MachiyaShops.luau` now records the re-registration and that the survey's x1 was stale against the built neighbour.

## RED / GREEN

- **RED**: added `apparel registers to the built neighbour` describe to `MachiyaShops.spec.luau` — `expect(apparel.envelope.x1 + 1.5).toBeCloseTo(hanabiya.envelope.x0, 0.001)` failed against 2.30 (1121 passed / 1 failed / 1122).
- **GREEN**: envelope literal fixed; the existing envelope test's x1 expectation updated to −3.17 with a comment pointing at the relationship test. 1122/1122.

## Dressing re-fit

The rack span was a literal (5.7) sized for the old width — at w = 19.25 the two racks would have crossed at the shared mid-post. Now derived from the envelope: `BAY_W = env.w/4`; `RACK_SPAN = BAY_W − POST − 0.2` (= 4.3125, facing posts keep a 0.2 clear gap); `CLOTH_W = (RACK_SPAN − 0.6)/3` (= 1.2375, 0.1 gaps between cloths, 0.05 to each post). Everything else (counter 60% → 11.55 wide, table at cx, shelf, bolts) re-fit automatically from `ctx.env`.

## AABB re-check (full extents, scripted)

- Dressing↔Dressing: only the 4 intentional rail-through-post mortises (0.2).
- Dressing↔shell: zero. Envelope/floor: zero violations; nothing floats.
- Rack gap verified: west rack's east post face −12.90 vs east rack's west post face −12.70 = 0.20.
- **Cross-shell check (new):** built apparel's east-most extent −2.305 (an invisible chochin GlyphPlateB tag at ~y118) vs built 花火屋's west-most −2.270 (its roof Ridge at apex height) → 0.035 positive x-gap, and the two parts share no y-band; the visible eaves clear each other by ~0.5. No interpenetration anywhere.

## Gates

genmodels run FIRST (project.json untouched this round), then: Hanabiya byte gate clean; suite 1122/1122; stylua clean; selene 0/0.

**Note for the owner:** cloths are now 1.24 × 3.8 — narrower than round 1's 1.7 and the design's 2.2. On a 4.81-stud bay that is what three-per-rack holds; if that reads too banner-like, two cloths per rack at ~1.95 is the alternative.

---

# Fix report — gate correction round 2 (commit `0726013`)

**Corrections relayed:** (1) two cloths per rack at ~1.95 (three at 1.24 read banner-ish); (2) racks off the frontage — one either side of the fold table, splayed on a diagonal, mirror-imaged, opening toward the entrance.

## New rack geometry (all from ctx.env; rotation via Spec.rotY/rotYMat only — arch-stable)

- Layout lines hoisted: `counterZ = z1 − 4.4`, `tableZ = ((z0 + 1.2) + (counterZ − 1.0)) / 2` (= 39.755); the rack group registers to the table.
- Rack centers: `cx ± RACK_DX` (RACK_DX = 4.5) at tableZ → (−17.295, 39.755) and (−8.295, 39.755). Yaw **west −35° / east +35°** — each rack's OUTER end swings north, so the pair funnels open toward the door; mirror-symmetric about the table's centre line (x = cx).
- Members unchanged in section: posts 0.3² × 5.5, RACK_SPAN 4.4 (centre-to-centre), rail (4.7 × 0.2 × 0.2) top flush with post tops, ends flush with post outer faces.
- Cloths: **two per rack, `CLOTH_W = (RACK_SPAN − 0.5)/2 = 1.95`** × 3.8 × 0.15, local offsets ±1.025 (0.1 gap between, 0.05 to each post inner face), colour order mirrored between racks (W: vermilion/water; E: water/vermilion). Rail + cloth still non-colliding, posts collide.
- Doorways now completely clear: nothing in the dressing north of z = 38.28.

## Rotation-aware extent check (projection: extent = |r.x|·sx/2 + |r.y|·sy/2 + |r.z|·sz/2 per axis)

- **Dressing↔shell: zero overlaps** (AABB, conservative — so definitive).
- **Dressing↔Dressing:** the 4 intentional rail-through-post mortises (0.2), plus post×cloth 0.088 and cloth×cloth 0.004 flags that are **AABB false positives on rotated parts**: every part in a rack shares the same yaw, so the true test is the rack's local frame, where it is exact — cloth edges span ±[0.05, 2.0] (0.1 clear between cloths), post inner faces at ±2.05 (0.05 clear of the outer cloth edges). No true interpenetration.
- Racks vs table: 0.489 x-gap each side (inner post AABB to table edge). Racks vs each other: table between, >4.9 apart.
- Nothing below the floor; nothing crosses a wall (west/east rack outer extents −19.306 / −6.284 vs wall inner faces −21.62 / −3.97).
- **Tightest full-extent envelope margin: 0.800** (ShelfBoard's back face on WallBack's inner face vs z1 — the deliberate registration, unchanged since round 0). Guard-test centers all remain inside.

## Walking-line clearances (reported numbers)

| segment | clear width |
|---|---|
| frontage plane (z0) → group's north edge | **3.05** |
| wall channels past the rack outer ends (both sides, by symmetry) | **2.31** |
| group's south edge → counter front face | **1.85** (only at the racks' inner-post tips; 2.03 along the table) |
| rack ↔ table (display-group interior, not a walk lane) | 0.49 |

An avatar (2-stud hitbox) entering either open bay has 3.05 studs of clear floor, rounds the group through a 2.31-stud wall channel, and stands at the counter in a ≥1.85 aisle — no squeezing past a rack on the path.

## Gates

genmodels FIRST (project.json untouched; rojo serve safe), then: Hanabiya byte gate clean; suite **1143/1143** (grew from 1122 with the landed Chochin.luau work — not touched by me); stylua clean (after `stylua` reflowed one call); selene 0 errors / 0 warnings.

**For the owner:** ±35° is the first attempt at the splay angle; RACK_DX 4.5 sets the group's width. Both are single literals in the dress function if the angle or spread wants tuning.

---

# Fix report — gate correction round 3 (commit `2de7496`)

**Correction relayed:** the owner hand-rotated and moved BOTH racks into the corners in Studio ("the racks were sort of in the way"). The builder must reproduce their placement exactly or the next Rojo sync reverts their hand work.

## What was baked

`APPAREL_RACK_OVERRIDES` in `MachiyaShops.luau` — the as-built pattern (cf. the path builders' terminusRock / steps.ranges): placement data a builder cannot re-derive is stored; everything else stays derived.

| rack | rail-centre rel (x, z) from envelope centre | yaw |
|---|---|---|
| KimonoRackWest | (−6.786, −2.407) | **−105.86°** |
| KimonoRackEast | (6.451, −3.394) | **+129.97°** |

- Offsets are RELATIVE TO THE ENVELOPE CENTRE so an envelope nudge carries the racks.
- The yaws are NOT mirror images — free-hand placement; the comment forbids re-deriving or symmetrizing.
- Internals (posts at ±2.2 along the rail, two 1.95 cloths at ±1.025, all sizes/heights, colour mirroring) remain derived from the rail centre + yaw.
- The round-2 splay/spread literals (RACK_YAW 35, RACK_DX 4.5) are deleted, and the tableZ comment no longer claims the racks register to the table.

## Reproduction check (the critical gate)

Rebuilt model vs the coordinator's per-part live reads, all 10 rack parts matched by name:

- **Worst position delta: 0.0008 studs** (most parts ≤0.0003) — the recorded rail centres carry rounding to 3 decimals, and the derived internals land back on the recorded posts/cloths within that rounding. Orders of magnitude under the 0.05 stop-and-report ceiling; **no silent revert of the owner's work**.
- Yaw recovered from every part's rotation matrix: exactly −105.860 / +129.970 (delta 0.000).

## Rotation-aware extent audit at the new transforms

- **Dressing↔shell: zero overlaps** (door leaves, bay panels, walls, posts all checked — the east rack noses 0.34 clear of bay 3's parked leaf, inside the audit's shell set).
- **Dressing↔Dressing:** the 4 intentional rail-through-post mortises (0.2). The post×cloth (0.013/0.106) and cloth×cloth (0.020) flags are rotated-AABB false positives, same class as round 2: every part in a rack shares one yaw, and in the rack's local frame the clearances are exact — 0.1 between cloths, 0.05 cloth-to-post.
- **West rack → west wall inner face: true margin 1.252** (westmost point −20.368 vs −21.62). East rack → east wall inner face: **0.749** — the owner's corner placement, recorded not judged.
- Nothing below the floor; every full extent inside the envelope; racks clear of the counter by 1.33 (z) and of the table by 4.05 (west) / 2.87 (east).

## Walking clearances (post-move)

| segment | clear |
|---|---|
| frontage plane → table front edge (now the first obstacle) | **3.23** |
| table back edge → counter front face | **2.03** |
| past the west rack (rack ↔ table) | **4.05** |
| past the east rack (rack ↔ table) | **2.87** |
| nearest rack part to the frontage plane | 1.33 |
| nearest rack part to the counter front | 1.33 |

The floor now reads as the owner arranged it: racks tucked in the corners, table mid-floor, both bays walking straight to the counter with ≥2.87 on either side of the table group.

## Gates

genmodels FIRST (project.json untouched), then: Hanabiya byte gate clean; suite 1143/1143; stylua clean; selene 0 errors / 0 warnings.
