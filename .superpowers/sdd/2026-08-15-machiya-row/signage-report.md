# Machiya row signage pass — report (2026-08-15)

Commit: `0db82e5` `feat(roblox): sign types per shop — blade, hanging plaque, and per-character lettering`
Branch: `m4b-zendojo-art-pass`. **Stopped at the owner gate — Task 6 not started.**

## Sign type, panel and ink per shop

| Shop | Type | Panel | Ink | Why |
|---|---|---|---|---|
| 花火屋 | 板看板 wall board (unchanged geometry) | cream plaster (`ivory` on MachiyaPlaster) — as accepted | sumi (`ink`) — as accepted | Only the lettering changed, per the brief. The anchor the row is read against. |
| MachiyaApparel (呉服屋) | 袖看板 blade, perpendicular, west end of frontage | **black lacquer** — literal `{0.09,0.08,0.08}` on SmoothPlastic (no palette black is this deep; SmoothPlastic is the closest base material to urushi gloss) | **gold** — the palette's own `{0.83,0.69,0.40}` | The classic high-end gofukuya pairing, and the row's deliberate inversion: light-on-dark where 花火屋 is dark-on-light. Reads down the promenade at night. Channel-sum contrast 1.67 (test-held > 1). |
| MachiyaAccessories (小間物屋) | 掛看板 plaque hung under the eave on two visible iron hooks | **bare cedar** — `cypressWeathered` `{0.85,0.84,0.81}` on Wood + `CypressWeathered` variant (the UNROTATED grain — CypressVertical's maps run 90° and would band across a horizontal board) | **sumi** — palette `ink` `{0.18,0.19,0.22}` | Third silhouette, third ground: cream plaster / black lacquer / bare timber. Contrast 1.91. Vermilion on cedar was considered and rejected: channel-sum delta only ~0.5, weak at a glance. |
| MachiyaEast | blank wall board (`board = true`), childless, framed | cream plaster (kit default) | none | Naming deliberately out of scope (wager-language ruling). Registry entry gains `identity = { board = true }` so "keeps a blank wall board" is a tested fact; it is NOT in genmodels' outputs, so nothing shipped changes. |

## The per-character helper

`kanjiFace(name, text, face, ink, textSize, pixelsPerStud, vertical)` — module-scope local in
`roblox/tools/builders/Machiya.luau`, the ONE implementation shared by 花火屋's inline
full-interior sign and all three kit sign kinds (wall/blade/hanging), so the letterforms
cannot drift between the two paths.

- Splits `text` via `utf8.codes`; emits one `TextLabel` per character (`Char1..CharN`),
  each centred in its own equal cell along the reading axis: horizontal = Position
  `{(i-1)/n, 0}` × Size `{1/n, 1}`; vertical (tategaki) = the same cells stacked in y.
- The SurfaceGui keeps 花火屋's proven canvas recipe: `SizingMode = "PixelsPerStud"`
  (FixedSize ignores PixelsPerStud and renders specks), small canvas + fixed TextSize
  (TextScaled unreliable, TextSize caps ~100px). Per-face PPS/TextSize: wall 32/72
  (byte-compatible with the accepted 花火屋 canvas), blade 64/72, plaque 64/76 — each
  sized so glyph height/width fit the cell (fallback metric: 33/48 width ratio, measured).
- Rational arithmetic only (cell fractions) — no new trig, so genmodels stays arch-stable.

## 花火屋 spacing, before → after

- Before: one packed label; the CJK fallback advances 33px/char at size 48 → at TextSize
  72 on the 32 px/stud canvas that is **1.546875 studs** centre-to-centre — glyphs touching.
- After: three cells across the 7.8-stud board → **2.6 studs** centre-to-centre
  (+1.053 studs of air between glyph edges). Test pins cell spacing > packed advance + 0.3.

## Hanabiya diff containment (the narrow re-baseline)

The model.json is single-line, so containment was proven structurally: a deep compare of
`HEAD:roblox/assets/Hanabiya.model.json` vs regenerated found **exactly 4 differing paths**:

```
root.children[Kanban].children[Face].children[Char1] | added
root.children[Kanban].children[Face].children[Char2] | added
root.children[Kanban].children[Face].children[Char3] | added
root.children[Kanban].children[Face].children[Text]  | removed
Diffs OUTSIDE the Kanban subtree: 0
```

Every changed node lies inside Kanban → Face. No other part of the accepted building moved.

## Clearances (rotation-aware full extents, world y in studs; apparel FLOOR 113.30, accessories FLOOR 113.21)

**Blade (apparel):** board y [123.22, 126.82], z [33.53, 35.13] (SZ0−2.0 .. SZ0−0.4), x centre X0+1.5.
- underside vs kamoi line (floor+6.8 = 120.10): **+3.12**
- bottom arm underside 123.00 vs eave AABB top 122.4226: **+0.577** (board itself +0.797)
- seat also derives from the upper-floor slab's proud edge (top 122.90): arm clears **+0.10**
  — the audit caught the first seat buried 0.22 in the slab edge; re-derived, not fudged
- top arm top 127.04 vs RoofNorth AABB min 127.19: **+0.15**; vs roof spring EAVE_Y 127.30: +0.26
- west chōchin: x gap **0.91** (barrel east edge −21.92 vs board face −21.01), y gap ~1.48
- north edge Z0−1.7, **0.8 inside** the eave's own drip line (no new promenade encroachment);
  arms' rear faces ON the upper wall's street face (SZ0), outer ends flush with the board edge

**Plaque (accessories):** 4.4×1.3 board at z = Z0−1.0, y [120.1825, 121.4825].
- top vs eave AABB LOWEST corner 121.5874: **+0.105** (guard requires > 0.05)
- bottom vs kamoi head line (floor+6.8 = 120.01): **+0.17**; vs 6-stud avatar: **+0.97**
- hooks: 0.4 long, bottoms seated on the plaque top, tops pinned to the eave's underside
  PLANE (121.8825 at that z) within 0.02 — attached, not buried, not floating
- z span [Z0−1.075, Z0−0.925]: never over the frontage line, 1.42 inside the drip

**Full-extent audit** (both shops): every sign part vs every other part of its own model,
rotation-aware AABBs, 1e-4 tolerance for the deliberate flush contacts. One allowed pair:
`PlaqueHook* ↔ Eave` (the hangers), separately pinned to the underside plane. Worst
penetration after the seat fix: none above tolerance.

## TDD — RED → GREEN

RED run (before implementation): **17 failed / 1169** — the two rewritten 花火屋 sign tests +
new spacing test (Machiya.spec), and all new signage suites (MachiyaShops.spec): blade
replaces-kanban / perpendicular / tategaki / contrast / clearances, plaque replaces-kanban /
under-eave / hooks-bridge / horizontal lettering / contrast, both full-extent audits,
MachiyaEast blank board, sportsbook registry `board = true`.

GREEN: **1169 passed, 0 failed** — after one real defect the audit caught mid-implementation
(blade bottom arm buried 0.22 in the UpperFloor slab's proud edge; fixed by deriving the
seat from `max(eave top + 0.35, slab top + arm + 0.1)`).

## Gates

- `lune run tests/run`: **1169 passed, 0 failed** (final, post-stylua re-run)
- `lune run tools/genmodels` twice: **byte-identical** (sha256 over all assets, both before
  and after the stylua pass)
- changed assets committed: `Hanabiya.model.json` (contained re-baseline),
  `MachiyaApparel.model.json`, `MachiyaAccessories.model.json`
- `stylua --check src tests tools`: clean (after one auto-format pass)
- `selene src tools`: **0 errors, 0 warnings, 0 parse errors**
- `default.project.json`: untouched, as expected; no MachiyaEast asset emitted

## Open items for the owner gate

- Names 呉服屋 / 小間物屋 proceed as approved — overrulable here.
- Blade panel lacquer literal `{0.09,0.08,0.08}` and its west-end placement (x = X0+1.5) are
  gate-tunable; `board.side = "east"` already works if the owner wants it on the roji side.
- Plaque bottom rides 0.17 above the 6.8 kamoi line — deliberate (lowest legal hang so the
  sign reads at eye level); raise `HOOK_LEN` down / shrink `PLAQUE_H` if it feels tight in-game.

---

# Round 3 — nobori + mon (owner's historical corrections, 2026-08-15)

Commit: `90a9eed` `feat(roblox): the apparel shop gets a nobori, and every noren gets its mon`
Round-2 verdict recorded: 花火屋 respacing and the accessories plaque ACCEPTED as built.

## 1. The nobori (replacing the blade)

**Blade deleted, not kept.** The owner ruled the type an anachronism for this world; a kit
capability that survived its own rejection invites re-use and re-litigates the gate. The
`kind = "blade"` branch and all its tests are gone; `board.kind` is now
`"wall" | "nobori" | "hanging"` (the branch comment records why).

**Construction** (`Nobori` model, kit branch in `roblox/tools/builders/Machiya.luau`):
- **Pole**: slim cypress, not bamboo — a 0.18-dia cylinder in `CypressVertical`, the variant
  every vertical timber on the row already wears; bamboo would introduce a new material with
  no palette entry and no neighbour to rhyme with. Height 7.5, top 0.30 under the front
  girder's soffit; the bare tip rises past the kamoi in the open band between the noren
  plane and the transom, visible from the street the way a real nobori pole tip is.
- **Yokobō**: the horizontal top bar nobori actually hang from — a 1.65 cylinder running
  SOUTH from the pole (into the envelope), `CypressWeathered` (horizontal grain).
- **Ties**: three, seated ON the cloth chain's own joints (position and x-stretch computed
  from the same chain walk), bridging the pole to the cloth's edge — they follow the
  cloth's drift instead of pointing at where it used to be.
- **Cloth**: a JOINED CHAIN (the noren's lesson) — 3 segments, one per kanji, top of each
  exactly on the bottom of the one above (chain test held), drifting 2.5° west into the
  doorway's open air. Fabric + `NorenCloth` variant + the noren's own 0.1 transparency.
  Colour DERIVED from `identity.noren.color` (the shop's indigo — omit `board.panel` and
  the kit reads the noren); lettering 呉服屋 in shironuki white (`SHIRO`), one character
  per segment via the shared `kanjiFace`, on BOTH faces (TextSize 80, PPS 64).

**NorenSway adoption: NOT taken — shipped still-air, deliberately.** Discovery is by
CollectionService tag `NorenSeg` + parent grouping, which WOULD adopt the banner — but the
client rebuilds each tagged segment's orientation as `CFrame.Angles(rx, 0, az)` from the
X-euler alone: it assumes yaw-0 street-facing panels. The banner's segments face east/west
and lean about Z; tagging them today would snap the cloth flat on the first frame. Making
the client preserve yaw is a client-script change — its own gate, offered as a follow-up.
A test pins the segments untagged with this reasoning in its comment.

**Siting and clearances** (apparel: FLOOR 113.30, Z0 35.23; pole flanks the CENTRE post's
west side — both doorways' clear thirds meet there, since the leaves park toward the closed
end bays):
- Envelope containment (rotation-aware full extents, still-air = swept since no sway ships):
  x [−13.605, −13.155] — margins **8.82 west / 9.99 east**; z [35.625, 37.29] — margins
  **0.395 to the frontage line** (test floor 0.3), 11.19 to the back. Nothing at z < Z0:
  the promenade is untouched.
- Noren FULL CLIENT SWAY: worst hem z = Z0 + 0.06 + 2.6·sin((3.6°+0.35°)·1.85) = Z0+0.391;
  pole near face Z0+0.53 → **0.139 clear of cloth that can never reach further** (test ≥ 0.1).
- Doorway walk line: parked leaf's east edge −15.92 to the nobori's westmost point −13.61 →
  **2.32 studs clear** (test ≥ 2.2); the east doorway is untouched.
- Pole top ↔ girder soffit **0.30**; bar top ↔ kamoi line **0.12**; cloth top ↔ transom
  bottom **0.24** below (the cloth crosses the transom's z-plane only under the kamoi);
  pole ↔ HeadRail z-gap 0.23; chōchin ≥ 9.5 away; fold table 1.17 in z; racks 3.5+ in x
  (owner's `APPAREL_RACK_OVERRIDES` untouched).
- Full-extent audit (every Nobori part vs every other part, rotation-aware AABB, 1e-4):
  clean. The audit now skips only `Threshold` — the invisible trigger volume that
  deliberately spans the shop and is not geometry.

## 2. 丸に文字 — the mon

**Mechanism (the one deviation, and why).** The owner asked for a ring PART parented to the
segment. In Roblox a part does not inherit its parent's CFrame — an anchored ring parented
under Seg2 would hang frozen in world space while NorenSway CFrames the cloth through it,
which is exactly the "pinned in front of a moving curtain" failure the owner forbade. The
only rigid bind is a WeldConstraint, and its Part0/Part1 are Ref properties a committed
`.model.json` cannot express. So the mon is built as the segment's OWN SurfaceGui: a
circular Frame (UICorner 0.5) with a UIStroke rim and one `kanjiLabel` — the ring renders
in the segment's coordinate frame, so **the animated segment's CFrame is literally the
transform carrying the mon**. No image uploads; the ring is geometry-of-the-GUI, the
character is the same shared label recipe every sign uses (`kanjiLabel`, factored out of
`kanjiFace` so the two cannot fork).

**Attachment, verified by test**: host is `Seg2` — second from the top, the upper-middle of
the hang where a real noren carries its crest — of the doorway's centre panel, and the test
asserts the host part carries the `NorenSeg` tag (the exact part NorenSway animates).
Hosts: 花火屋 `Noren2_2/Seg2` + `Noren3_2/Seg2`; apparel same pattern; accessories
`Noren2_1/Seg2` + `Noren3_1/Seg2`. **One mon per doorway** (test-counted). Accessories'
even pair puts the doorway's true centre on the slit, so its mon rides the WEST panel of
each pair — flagged for the gate.

**Sizes** (shironuki white ring + kanji, PPS 128, capped at 60% of panel width and 90% of
the host segment's height, floored to whole pixels):
- 花火屋 丸に花 — 89 px = 0.695 studs = **59.4% of panel width** (TextSize 53)
- 呉服屋 丸に呉 — 59 px = 0.461 studs = **36% of panel width** (its 5-segment noren has
  short segments; the segment cap governs) (TextSize 35)
- 小間物屋 丸に小 — 74 px = 0.578 studs = **39.7% of panel width** (TextSize 44)

## Hanabiya diff containment (round 3)

Structural deep-compare, `HEAD~1` (pre-round-3) vs regenerated:

```
2 differing paths:
  root.children[Noren2_2].children[Seg2].children | added
  root.children[Noren3_2].children[Seg2].children | added
Diffs OUTSIDE the noren subtree: 0
```

Both paths are the two doorways' mon. The accepted building did not move.

## TDD — RED → GREEN

RED: **10 failed / 1173** — 7 nobori tests (replaces-blade, rig parts, joined chain +
per-segment lettering both faces, untagged-by-design, envelope containment, noren-sway +
doorway clearance) + 3 mon tests (one per shop) + the audit's blade→nobori swap; the 6
blade tests were deleted with their subject.

GREEN: **1173 passed, 0 failed** — after one real find: **UDim2 offsets are Int32 in
rbx-dom**; the mon ring's float pixel size (`[0, 89.9175]`) made rojo reject the ENTIRE
Hanabiya model as invalid JSON. Diameters now floor to whole pixels (floor, not round —
rounding up breached the 0.9×segH sizing cap by 0.0008 and two tests caught it).
`rojo build` is now part of the local gate run; it passed on the round-2 assets baseline
and on the final round-3 assets.

## Gates (round 3)

- `lune run tests/run`: **1173 passed, 0 failed**
- `lune run tools/genmodels` ×2: **byte-identical** (sha256 all assets)
- `rojo build`: **OK** (new gate, added after the Int32 find)
- `stylua --check src tests tools`: clean; `selene src tools`: 0 errors, 0 warnings
- `default.project.json`: untouched
- Committed: `Hanabiya.model.json` (contained: 2 noren-subtree paths),
  `MachiyaApparel.model.json` (blade→nobori + mon), `MachiyaAccessories.model.json` (mon)

## Open items for the owner gate

- NorenSway adoption for the banner (yaw-preserving client change) — offered as its own gate.
- Accessories' mon on the west panel of its even pair — or a mon per panel, if preferred.
- Apparel's mon is the smallest (36% — its 5-segment noren bounds the ring); dropping the
  noren to 4 segments would let the crest grow to ~46% if it reads small in-game.
- Nobori drift (2.5° west), pole side (`board.side = "east"` mirrors it), and shiro
  lettering are all gate-tunable literals.

---

# Round 4 — the nobori goes out front; the mon grow (2026-08-15)

Commit: `7c59f61` `fix(roblox): the nobori stands out front, and the mon grow`

## 1. The promenade rule, corrected and applied

The owner's clarification (verbatim in the code now): the promenade bars **buildings**,
not signage. Both places that over-read the rule were fixed:
- The `NOREN_BELLY` block no longer claims the promenade is "inviolable at ground level";
  it states the real rule and records that the noren's inward lean is retained for its own
  reasons — it is the pose every accepted shop shipped with, and moving it moves every
  byte gate — not because a hem over the line would be forbidden. **Noren geometry untouched**
  (Hanabiya byte-identical this round proves it).
- The nobori's siting comment carries the owner's verbatim ruling.

**New siting** (apparel, FLOOR 113.30, Z0 35.23): pole at x = X0+1.5 (−20.92), planted on
the promenade at z = Z0 − 2.93, in front of the **closed** west end bay. Bar and cloth run
NORTH, away from the building. Freed from the kamoi ceiling it stood under indoors, it
takes a real nobori's height: 9.2 pole (tip proud above the yokobō), 5.2 × 1.2 cloth
(~4.3:1), hem ~3.2 off the ground, TextSize 96 at PPS 64.

**Clearances** (as-emitted, rotation-aware extents):
- z-extent [30.71, 32.55] vs drip line 32.73 → **0.18 beyond the drip** at the closest
  point (the base's south face); test floor 0.15. Nothing under the soffit.
- **Nothing overhangs it — proven, not asserted**: a new guard walks every building part
  and requires zero x∧z overlap with any nobori part. The eave/hisashi end at the drip
  line it stands beyond; the west chōchin's barrel is x-separated by **0.685**.
- **Walking lane**: measured as the ground-level corridor between the banner's colliding
  parts (base + pole — the cloth is walk-through and aerial) and the frontage plane Z0,
  i.e. the lane a pedestrian hugging the shopfronts uses: **2.68 studs** (test ≥ 2.5).
  North of the banner the open promenade is unbounded. Both doorways untouched: the
  banner's x-max (−20.67) is 3.3 studs west of the westmost doorway jamb (test ≥ 0.5).
- x-extent [−21.17, −20.67] wholly inside the shop's own frontage (x0 −22.42).
- Grounding: base bottom at floorY − 0.1 — the survey's NW front probe (x −22.42, z 35.23,
  Sand at exactly 113.30) is the nearest committed measurement to the site; there is no
  committed promenade geometry out there to register to (karesansui reduction pending),
  so the stand registers to that probe with a 0.1 bury for grade variance. Flagged for a
  Studio eyeball at the gate.
- Full-extent audit (vs every part of the model): clean.

## 2. Apparel noren → 4 segments; ring growth logic

`noren.segments = 4` (owner). The ring sizing was already the uniform "grow where the
segment allows" rule — `min(60% of panel width, 90% of host segment height)`, floored to
whole pixels — so no shop is "at whatever it happens to be":

| Shop | Ring | Fraction of panel width | What caps it |
|---|---|---|---|
| 花火屋 | 89 px = 0.695 studs | **59.4%** | the 60%-of-panel-width rule (its 0.867 segments would allow 66%) |
| 呉服屋 | 74 px = 0.578 studs | **45.1%** (was 36%) | 90% of its new 0.65 segment height |
| 小間物屋 | 74 px = 0.578 studs | **39.7%** | 90% of its 0.65 segment height |

(TextSize follows the ring: 53 / 44 / 44.)

## 3. Accessories' pair flanks the central post

Even-count placement generalized: the crest rides the panel nearest the frontage's
central post (post 3, between the two open bays) — bays west of it take their east panel,
bays east their west panel. As emitted: `Noren2_2/Seg2` + `Noren3_1/Seg2` — the two
innermost panels, a matched set across the post. 花火屋 and apparel stay one centred mon
per doorway (`Noren*_2/Seg2`). Still exactly one mon per doorway everywhere (test-counted).

## Hanabiya containment (round 4)

```
Hanabiya differing paths: 0
```

The model is **byte-identical** this round — the coordinator anticipated a possible mon
resize, but 花火屋's ring was already at its width cap and the odd-count placement is
unchanged, so the containment check holds trivially: zero differing paths, none outside
the noren subtree, and the accepted building did not move at all.

## TDD — RED → GREEN

RED: **5 failed / 1174** — the inverted siting test (out front, beyond drip, x inside own
frontage, grounded at probe grade), the open-sky footprint guard, the doorway/lane test,
and the two changed mon cases (apparel 4-seg + 74 px; accessories flanking map
`{bay2→panel2, bay3→panel1}` + 74 px). The hanabiya mon case stayed green throughout —
correctly, since nothing about it changed.

GREEN: **1174 passed, 0 failed.**

## Gates (round 4)

- `lune run tests/run`: **1174 passed, 0 failed**
- `lune run tools/genmodels` ×2: **byte-identical**; `rojo build`: OK
- `stylua --check`: clean; `selene`: 0 errors, 0 warnings
- `default.project.json`: untouched
- Committed: `MachiyaApparel.model.json` (nobori resite + 4-seg noren + grown mon),
  `MachiyaAccessories.model.json` (flanking mon). `Hanabiya.model.json` unchanged.

## Open items for the owner gate

- The nobori's stand height rides the NW front probe (113.30); worth one in-Studio glance
  at the actual terrain under (−20.9, 32.3) — the 0.1 bury absorbs small variance only.
- NorenSway adoption for the banner (yaw-preserving client change) remains on offer.
- Nobori height/cloth (9.2 / 5.2 × 1.2), drift (2.5° toward the shop centre), and the
  0.43 drip standoff are gate-tunable literals.
