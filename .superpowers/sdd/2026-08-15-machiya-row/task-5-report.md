# Task 5 Report — Accessories (Machiya_4), the Piece B window display

**Status: COMPLETE — stopped at the OWNER GATE.** Commit `bd6f90b` on `m4b-zendojo-art-pass`.

## Envelope decision (the pre-caught defect, fixed before the first attempt)

| | surveyed | built |
|---|---|---|
| x0 | 16.02 (stale massing — 0.24 INTO 花火屋's built east face at 16.26) | **17.76** = 16.26 + 1.5 roji, mirroring apparel's resolution |
| x1 / z0 / z1 / floorY | 32.65 / 36.34 / 49.58 / 113.21 | unchanged (still surveyed) |
| w / cx | 16.63 / 24.335 | 14.89 / 25.205 |

The envelope comment in `roblox/tools/builders/MachiyaShops.luau` records the stale-massing class and that the west edge REGISTERS TO 花火屋's east face at a 1.5 standoff (derive-from-what-it-touches; also keeps the side walls off a shared plane).

## Identity values

| Field | Value | Why |
|---|---|---|
| `noren` | `color = {0.55, 0.28, 0.18}`, `segments = 4` | Brief literal — warm russet. |
| `chochin` | `{ paper = {168, 180, 152} }` | **Light moss / green-grey**, the tint reserved for accessories in the palette note. Measured through `Chochin.luminance`: **0.68795** — clears the 0.55 floor with the same headroom as canonical cream (0.68422). Chochin.spec's table-walking guard now covers it (suite grew by that test). Glyph plates untinted, per the kit contract. |
| `board` | `true` | Blank timber kanban; signage copy out of scope. |
| `glow` | `{1.0, 0.85, 0.6}`, brightness 1.2 | Apparel's values; interior "shallow" emits both hooks. |
| `dress` | function, below | All derived from `ctx.env` / `ctx.consts` — no world literals. |

## Dressing manifest (env: x[17.76, 32.65], z[36.34, 49.58], floorY 113.21; w=14.89, cx=25.205)

All Y below are offsets from floorY. Wall inner faces are the archetype's own planes (STUCCO_SETBACK 0.30 + WALL_T 0.5): west x0+0.8, east x1−0.8, back z1−0.8.

**Two shelf walls** (`ShelfWallWest`/`ShelfWallEast`), boards registered back-face-ON the built side walls:
- Run: z from z0+1.45 (37.79 — clear of the frontage's deepest timber, which lives inside z0+1.3) to counterZ−1.05 (44.13, 0.05 shy of the counter's front face — running past it would pinch the staff channel around the counter's end from 2.18 to under 1 stud). Length 6.34.
- Three boards each, 1.2 × 0.4 × 6.34, centres at +2.2/+4.2/+6.2 (the brief's heights).
- **Support: two vertical front standards per wall** (0.3² × 6.4, floor to the top board's top, front faces flush with the board fronts — flush-outside-edges; the wall carries the back). Boards run THROUGH the standards at their ends — 12 named mortises, apparel's rail-through-post class. This replaced my first attempt (apparel-style under-brackets), which the extent audit caught colliding 0.2 deep with lower-tier stock — a bracket hanging 0.3 below a board eats the very headroom the stock needs; standards hang nothing below any board.
- **Stock per shelf** (the Piece B catalog preview; a packed line, ~0.05 gaps, mirrored on alternating tiers/walls so the two walls don't read copy-paste; all merchandise non-colliding/non-query/no-shadow — 54 micro-parts of physics would be waste):
  - 2 × **mini stone lantern** (`MiniLantern_*`): stacked cylinders + cube per `StoneLantern.luau`'s silhouette — base disc 0.9 × 0.25, shaft 0.3, firebox cube 0.55 (gold Neon), cap disc 1.0 × 0.2 (cap wider than base, as the real one). 1.6 tall on the top tier; **1.5 on tiers 1–2** (shaft trimmed 0.6→0.5): the 2.0 tier step minus the 0.4 board leaves 1.6 of headroom, and 1.6-tall stock would sit flush against the board above — thin it, never push through.
  - 2 × **folding-screen slab** (`ScreenSlab_*`): 1.2 wide × 1.8 tall × 0.08, standing in a 15° V (yaws 90±15 via `Spec.rotY`/`rotYMat` only — arch-stable), hinge toward the wall, opening toward the shopper. Height 1.8 top tier, **1.5 tiers 1–2** (same headroom rule). The leaves' mid-plane edges coincide at the fold: a ≤0.04 hinge-knuckle interpenetration, named intentional.
  - 3 × **rolled flag** (`RolledFlag_*`): 0.3 dia × 1.4 vertical cylinders, ±0.2 depth jitter, vermilion/gold/water cycling with tier.

**Display plinth** (`DisplayPlinth`), centre-floor at (cx, 40.86 — the same customer-floor midline apparel's table uses, midway between z0+1.2 and the counter's front face): 1.8³ timber cube (collides), topped by the **2.2 hero lantern** (base 1.25 × 0.35, shaft 0.4 × 0.8, firebox 0.75 with a soft PointLight 0.6/range 10 — StoneLantern's warm colour — cap 1.4 × 0.3; solid).

**Counter**: 8.934 (60% of w) × 3.0 (`ctx.consts.COUNTER_H`) × 2.0 at 花火屋's 4.4 COUNTER_STANDOFF (to the CENTRE, exactly as Machiya.luau). Working aisle behind it: 2.6 — same as 花火屋/apparel.

**Rear shelf** (`RearShelf`): exactly apparel's build — board 8.934 × 0.4 × 1.2 at +5.5, back face ON WallBack's inner face, two brackets beneath, five 0.8³ items on top (this shop's goods: timber/moss boxed stock with a gold centre, Wood not Fabric).

## TDD

- **RED**: added the brief's `accessories shell` describe + the mirror relationship test (`accessories.envelope.x0 − 1.5 ≈ hanabiya.envelope.x1`) to `roblox/tests/MachiyaShops.spec.luau`. Run: **1150 passed, 2 failed** — relationship test failed at the stale 16.02 (`expected 14.52 to be within 0.001 of 16.26`), Dressing test failed (no Dressing yet). Tower guard passed on the bare shell.
- **GREEN**: envelope literal → 17.76 (registry test's x0 expectation updated with a pointer comment, like apparel's) + full identity: **1153 passed, 0 failed** (grew 1152→1153: Chochin.spec's guard auto-added the accessories tint test).

## Rotation-aware full-extent audit (extent = Σ|R[axis][j]|·size[j]/2, scripted, temp file deleted)

- **Dressing↔shell: zero** (Threshold excluded; door leaves, bay panels, walls, posts, glow carriers all in the set). 102 dressing parts vs 267 shell parts.
- **Dressing↔Dressing: 18 flags, all named intentional joinery** — 12 board-through-standard mortises (0.300 = the standard's width) + 6 screen hinge knuckles (0.021). The first audit run had found 4 REAL 0.2-deep collisions (lantern caps/screens vs the next tier's under-brackets) — fixed by the standards redesign above, not waved through.
- **Envelope/floor: zero violations**, full extents. Tightest margin **0.800** — RearShelf's board back face ON WallBack's inner face, the deliberate registration (same number as apparel's).
- **Floaters: none** — standards on the floor, boards borne by standards + wall, all stock bottoms on board surfaces, plinth on the floor, hero lantern on the plinth top, brackets flush under the rear shelf.
- **Cross-shell vs built 花火屋**: zero intersections; west-most accessories extent 16.895 (ChochinWest's invisible GlyphPlateA tag) vs 花火屋's east-most 16.86 (Ridge, at apex height) → 0.035 positive gap, the same part-class pair as apparel's report; visible eaves clear by ~0.5 (eave overhangs 0.5 past each envelope edge → 17.26 vs 16.76).

## Walking-line clearances

| segment | clear |
|---|---|
| open doorways (bays 2/3, x 21.48–28.93) | **completely clear** — nothing in the dressing north of z 37.79, and the shelf walls sit at x ≤19.76 / ≥30.65, outside the bays |
| frontage plane → plinth north face (first mid-floor obstacle) | **3.62** |
| plinth ↔ each shelf-wall front | **4.55** (both sides, symmetric) |
| plinth south face → counter front face | **2.42** |
| counter-end channels into the staff aisle (both sides) | **2.18** — the shelf runs stop 0.05 before the counter's front plane precisely to keep these open |
| working aisle behind the counter | **2.60** |

Nothing on a walk lane is under 2 studs. The one sub-2 figure anywhere is stock-to-stock spacing ON the shelves (~0.05 gaps) — deliberate, a stocked shelf, not a lane.

## Gates (all run from `roblox/`)

- Suite: **1153/1153** (HandlerQueue `[WARN]` lines are that spec's expected noise).
- `git diff --exit-code assets/Hanabiya.model.json` **clean** and `assets/MachiyaApparel.model.json` **clean** (after genmodels).
- genmodels twice → **byte-identical** (sha256 compared).
- `stylua --check src tests tools` clean; `selene src tools` **0 errors / 0 warnings**.
- `python3 -c "import json;json.load(open('roblox/default.project.json'))"` valid.
- Registration order honored for the live serve: OUTPUTS entry → genmodels (file exists, 108KB) → `default.project.json` (after MachiyaApparel) + `WorkspaceConvention.DECLARED_STAGE_CHILDREN` (with comment) → genmodels again. No trig floats outside `Spec.rotY`/`rotYMat` — arch-stable.

## Concerns for the owner's eye

1. **The moss tint {168,180,152}** is my pick within "light moss/green-grey" — luminance-safe with room to go a touch greener/darker (floor 0.55 vs measured 0.688) if it reads too pale by 花火屋's cream.
2. **Shelves are packed** (~0.05 gaps by design). If it reads cluttered, dropping one flag per shelf opens the line to ~0.14 gaps with no other change.
3. **Lower-tier miniatures are 1.5 tall vs the brief's 1.6/1.8** — the 2.0 tier step bounds them; the full-height pieces live on the top tier. If the owner wants full-height stock everywhere, the tier step must grow (heights are the brief's 2.2/4.2/6.2).
4. **Part count**: the dressing is 102 parts (the miniatures are the shop), all anchored, merchandise non-colliding/no-shadow. One extra PointLight total (the hero lantern).

**Next**: owner reconnects Rojo (project.json re-read needs plugin reconnect) and looks. ONE visual attempt — stopping here per the gate protocol. Task 6 not touched.

---

# Fix report — gate correction round 1 (commit `90d0c4b`)

**Corrections relayed:** noren (1) dark blue instead of russet, distinctly bluer and deeper than apparel's violet-leaning indigo; (2) two wider panels per doorway instead of three, WITHOUT touching the file-level `NOREN_PER_BAY` the accepted shells share; (3) a regression test pinning the per-shop divergence.

## Colour chosen: prussian navy {0.07, 0.15, 0.32}

Chosen against the neighbour, not in isolation. Apparel's {0.16, 0.18, 0.32} leans violet because its red (0.16) sits nearly at its green (0.18). This keeps the blue channel at apparel's own 0.32 — the two hang at the same chroma depth in blue — but halves the red to 0.07, which kills the violet lean (B−R spread 0.16 → 0.25), and drops relative luminance 0.186 → 0.145, so it reads DEEPER at a glance. No drift toward russet; the side-by-side same-family risk is left to the owner in situ, as directed.

## perBay: a per-shop opt-in, defaulting to the archetype

- `emitNoren(colour, nSegs, perBay: number?)` in `Machiya.luau`; `nPanels = perBay or NOREN_PER_BAY`. The kit call passes `identity.noren.perBay`; 花火屋's inline call passes nothing. The default path evaluates the identical arithmetic (`openW / nPanels` with `nPanels = NOREN_PER_BAY`), so non-opting shells emit identical floats — **proven by the gates, not asserted**: `git diff --exit-code assets/Hanabiya.model.json assets/MachiyaApparel.model.json` both clean after regeneration.
- The lean-jitter hash `((i * 3 + k) % 3 − 1) * 0.35` was deliberately NOT rewritten in terms of the panel count — it is an integer hash for hem variation, not a count, and touching it would move the accepted shells.
- Accessories: `noren = { color = {0.07, 0.15, 0.32}, segments = 4, perBay = 2 }`. `segments` (the vertical drape chain) untouched, per the correction's warning not to conflate.

## Measured panel geometry (read back from the built model, not computed by hand)

| | 3-per-bay (before) | **2-per-bay (built)** |
|---|---|---|
| panel width | 0.918 | **1.456** |
| slit between panels | 0.16 | **0.16** |

Four panels emitted (`Noren2_1/2`, `Noren3_1/2` — the two open bays), edge coordinates confirming a 0.16 slit at each bay's centre and 0.08 clear to each post face. The 0.16 slit is the row's shared constant (the same slit 花火屋's three-panel noren shows); with two panels there is now exactly ONE slit per doorway, centred — the push-through line. The per-segment hem lean jitter (±0.35°) keeps adjacent hems from reading as one sealed sheet. If in situ the single centre slit reads too sealed, it is one constant (the 0.16 in `panelW = openW / nPanels − 0.16`) — but that constant is shared row-wide, so widening it is an owner decision, not a local tweak.

## RED / GREEN

- **RED**: added `per-shop noren panel count` describe (counts `Noren{bay}_{k}` models per bay) — accessories expected 2/bay, failed at 3 (**1154 passed / 1 failed / 1155**); the apparel-default companion test passed before and after.
- **GREEN**: after `perBay` landed: **1155/1155**.

## Gates

genmodels run FIRST (project.json untouched this round — live serve safe), twice → byte-identical; **both** accepted-shell byte gates clean (the real check that the default is right); suite 1155/1155; stylua clean; selene 0 errors / 0 warnings.

**Still stopped at the OWNER GATE.** Task 6 not touched.

---

# Fix report — kit defect: the kanban (commit `b79a872`)

**Owner's finding:** "you have to actually have a kanban board — even a blank one — on the shops. You do not." Diagnosis confirmed: the kit's `board = true` emitted a frameless `SignBoard` slab at the kamoi line whose whole z-span fell inside the tilted `Eave`'s — top covered, face shaded, a cream slab under a cream soffit. Both kit shells had it.

## The fix — 花火屋's construction, generalized in the kit's board branch

`Machiya.luau`'s board branch now builds the full framed kanban (names matching 花火屋's: `Kanban`, `KanbanFrameTop/Bottom/West/East`), BLANK — no SurfaceGui, no copy (the owner is choosing a naming style separately; the sports-book wager-language ruling also stands):

- **Panel**: 2.6 high × 0.11 thick (花火屋's), width = `W * (7.8 / 17.93)` — 花火屋's own panel-to-frontage ratio, where the inline sign is instead sized to its three characters.
- **y**: centred on the shop's own mushiko-mado band, `WIN_Y0 + WIN_H / 2` — derived, not hardcoded (the band is itself centred on the upper storey by construction).
- **z**: `SZ0 − 0.95` — 花火屋's standoff DERIVED against its own envelope (sign centre Z0 − 0.65 vs upper wall front face at Z0 + 0.30 → 0.95 proud), not a copied literal.
- **Tilt**: 花火屋's −15°, top toward the path; the frame members ride the same rotated-plane offset function (`kanbanPos`, the inline `signPos` restated).
- **Frame**: four lapped members, 0.32 section, 0.34 deep (proud of the panel), timber/CypressVertical — identical sections to the inline sign.
- 花火屋's inline kanban NOT touched — its byte gate proves it (below).

## Sanity numbers (read back from the built models, rotation-aware extents)

| shop | panel width | kanban y span | clearance above Eave top | standoff proud of upper wall face |
|---|---|---|---|---|
| apparel | **8.374** | **123.53 – 126.07** | **1.107** | **0.950** |
| accessories | **6.478** | **123.44 – 125.98** | **1.107** | **0.950** |

(Apparel's mushiko band runs 123.80–125.80; the panel centres exactly on it at 124.80.) A full rotation-aware sweep of the 5-part kanban assembly against EVERY other shell part: **zero overlaps** on both shops — clear of the upper walls, the mushiko lattice, the hisashi eave, and the main roof.

## The occlusion guard (the test that would have caught this)

`MachiyaShops.spec.luau`: for each shop whose identity carries a board, the Kanban panel's full rotation-aware extent must NOT intersect the `Eave`'s in y and z, AND its bottom must sit above the Eave's top — open air, not soffit. The assertion binds whichever panel it finds (`Kanban` or the old `SignBoard` name), so a rename can never smuggle the sign back under the eave.

- **RED**: against the kamoi placement — both shops failed (apparel board y 120.50–122.30 vs eave top ~122.42, z-span inside the eave's). 1155 passed / 2 failed / 1157.
- **GREEN**: after the move — **1157/1157**.

`Machiya.spec.luau`'s identity-kit test updated with the fix: the kit board is now asserted as the framed construction (`Kanban` + exactly 4 `KanbanFrame*`), still blank (no children) — including in the sealed `interior = "none"` branch, which keeps the sports-book no-children guard working.

## Gates

genmodels run FIRST (project.json untouched — live serve safe), twice → byte-identical; `git diff --exit-code assets/Hanabiya.model.json` **clean** (the inline kanban untouched); MachiyaApparel + MachiyaAccessories JSON both changed and committed; suite 1157/1157; stylua clean; selene 0 errors / 0 warnings.

**Still stopped at the OWNER GATE.** Task 6 not touched.
