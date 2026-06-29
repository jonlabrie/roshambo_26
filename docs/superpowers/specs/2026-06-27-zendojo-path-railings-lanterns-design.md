# ZenDojo Path Railings & Hanging Chōchin (Design)

Status: design, awaiting user review (2026-06-27).

Related: `docs/superpowers/specs/2026-06-27-zendojo-fw11-switchback-deck-design.md` (KŌRAN railing + hanji
result-lantern), `2026-06-27-zendojo-retaining-walls-design.md`; memory `zendojo-fw11-switchback-deck`.
Reference: user's images — bamboo post-and-rail on the drop edge, hanging ribbed chōchin on cross-arm poles
up the cliff edge.

## Purpose

Furnish the canyon path system (upper run, extension, descent — ~270 studs) with a **bamboo railing** along
the downhill/drop edge and **hanging chōchin lanterns** on cross-arm poles up the cliff edge. The chōchin
**display the World-Throw result** like the deck/canyon lanterns. The existing teahouse "lantern" (a plain
Neon block + cylinder SpecialMesh) is the look being replaced — a proper ribbed chōchin is designed and
prototyped first, and the shared lantern controller is generalized to drive both block and round styles.

## Sub-projects / build order

1. **LanternController generalization** (code) — support a `round` display style.
2. **Chōchin model** (Parts) — prototype + iterate the look; must glow AND show the result in Play.
3. **Bamboo railing** — prototype one stretch.
4. **Deploy** railings + chōchin poles along all three paths.

Build 1+2 together (the chōchin can't be validated without the controller change). Prototype-first throughout.

## §1 — Chōchin model

A round ribbed paper lantern, built from Parts (fast to iterate, reused per pole):

- **Body:** warm Neon barrel with a slight bulge (e.g. stacked cylinders or a short barrel), warm cream
  (~`255/225/170`), partial transparency for paper feel; a warm `PointLight` inside (range ~16).
- **Ribs:** ~10–12 thin rib rings around the body (slightly darker/proud) — the bamboo banding.
- **Caps:** dark wood disc caps top & bottom, with small red/dark accent rings (the fittings).
- **Cord:** a short thin dark cord from the top cap up to the hanger.
- **Result display:** CollectionService-tagged **`RoundLantern`**; the controller paints a **billboard
  glyph** (see §2). No flat faces needed.
- Reusable as a unit (clone/rebuild per pole).

## §2 — LanternController generalization (`src/client/LanternController.client.luau`)

Today: finds `*Lantern` BaseParts under `Workspace.RoshamboStage`, builds a kumiko-frame + glyph
**SurfaceGui on 4 faces** (Front/Back/Left/Right). **Leave that block path exactly as-is** (no regression,
no retagging, and the teahouse `Lantern` stays untouched), and **add** a parallel round path:

- **Round lanterns are discovered by CollectionService tag `RoundLantern`** (`GetTagged` +
  `GetInstanceAddedSignal`), canyon-wide (anywhere in `workspace`).
- Each round lantern gets a single **BillboardGui** with the warm-ink glyph (GothamBlack), centred and sized
  to the body, facing the viewer — instead of the 4-face SurfaceGui.
- **Shared telegraph:** round glyph labels register in the same `glyphLabels` list and ride the existing
  reveal→drumRest→show, fade, and blank-lead logic unchanged. Glyph set `{R="○",P="─",S="∧"}`, ink colour
  shared with the block path.
- Net change: the script keeps its current block behaviour and gains a `RoundLantern`-tag scan + a
  `buildBillboard(part)` branch. Existing deck/Overlook/canyon lanterns need no edits.

## §3 — Bamboo railing

Warm-tan bamboo **cylinder** post-and-rail along the **downhill edge** of each path:

- **Posts:** ~0.45 dia, ~3.4 tall, every **~2 timbers (~7 studs)**, at the bed edge, plumb (slight grade lean
  ok). Bamboo colour (~`170/150/90`), Material Wood/Bamboo-like.
- **Rails:** two horizontal bamboo runs (~0.3 dia) post-to-post following the path — **top ~2.9** and **mid
  ~1.5** above the tread. Open between (no balusters).
- Continuous along all three paths' downhill edges.

## §4 — Chōchin poles & placement

- **Pole:** tall bamboo upright (~0.35 dia, ~5.5 tall) on the **uphill/cliff edge**, with a short horizontal
  **cross-arm bracket** near the top; the chōchin hangs from the cross-arm end by its cord.
- **Spacing:** ~every **6 timbers** (accents, a handful per path).
- Each hung chōchin is CollectionService-tagged **`RoundLantern`**.

## Units

- **LanternController** (`src/`) — adds a `RoundLantern`-tag scan + `buildBillboard` branch; block path
  unchanged. Verified in Play. (Client runtime script, not lune-tested — verification is Play + the existing
  lune suite stays green and untouched.)
- **Chōchin** (Parts unit) — body + ribs + caps + cord + light; tagged.
- **ChochinPole** (Parts) — upright + cross-arm + hung chōchin, placed along the uphill edge.
- **BambooRailing** (Parts) — posts + 2 rails along the downhill edge.

## Where it lives

- Controller: `src/client/LanternController.client.luau` (Rojo pipeline, committed).
- Geometry: ad-hoc Parts in `Workspace.PathRailings` + `Workspace.PathLanterns` (tag-driven controller finds
  lanterns anywhere). Persists via the saved place. Consistent with the ad-hoc paths.

## Out of scope

- Standing box lanterns (the square peaked-roof type in the ref) — only the round hanging chōchin this pass.
- Replacing the teahouse lantern model — out of scope here (this designs the path chōchin; the teahouse swap
  can reuse it later).
- The river bridge(s).

## Open questions

- Exact rib count / barrel proportions / cord length — tuned on the prototype.
- Billboard glyph size & how "painted-on" vs floating it reads — tuned on the prototype in Play.
- Railing post spacing (~2 timbers) and lantern spacing (~6 timbers) — confirm on the prototype stretch.

---

## As-built — chōchin + pole (2026-06-29)

Prototyped and locked through ~18 visual iterations in Studio; extracted to the reusable Studio runnable
**`roblox/tools/studio/buildChochinPole.luau`** (CONFIG: path/interval/posJitter/uphillOffset/maxDownhill/
dhMaxDrop/seed). Geometry is **place-only** (Workspace.PathLanterns); the controllers (Rojo) drive it by tag.

**Controllers (committed):**
- `LanternController.client.luau` — round lanterns paint a **world-space SurfaceGui glyph on a tagged
  `GlyphPlate`** (occluded, scales with distance → reads as ink on the paper), NOT a billboard. Round glyphs
  rest at **20% transparency** (block `*Lantern` faces stay at 0). Two plates per lantern, oriented
  **perpendicular to the crosspiece** (universal — not path-relative), so a walker sees a glyph from either way.
- `ChochinSway.client.luau` — rocks each tagged `Swing` sub-model ±~3° on a slow desynced sine (a light breeze).

**Bamboo frame (static, in the pole model):** dark wood `RGB 88,70,40`, `Material Wood`.
- Pole: `0.38` dia × `12.8` tall, foot at ~path level (uphill edge, +RightVector × 4.5).
- Crosspiece: `0.225` dia, reaches `2.38` over the path + `poleR+0.12` back through the pole (~1in stub).
- Knee brace: `0.18` dia, pole(−1.4) → arm(+1.1 out).

**Hanging assembly (in `Swing` sub-model; WorldPivot = hang point on the crosspiece; tagged `ChochinSwing`):**
- Metal loop: 14-seg torus, `0.10` tube, `RGB 120,122,128` Metal, draped over the crosspiece end.
- Paper barrel: **18 Neon slices**, `bodyH 2.8`, superellipse profile `r=capR+(Rmax−capR)(1−d⁶)^0.5`
  (`Rmax 0.9`, `capR 0.30` → straight middle, sharp corners, continuous = no brightness step), overlap ×1.15
  (hides seams), `Transparency 0.42`. **Vertical gradient** (per-slice colour ×f, `f=clamp(1−0.22d−topExtra,0.4,1)`,
  `topExtra=0.15(2t−1)` for the upper half → centre bright, top dimmer) on desaturated cream base `RGB 200,170,143`.
- Ribs (`INK 46,40,30`, Wood): 16 **horizontal** `0.025` thick (r=profile+0.05); **6 vertical** `0.03` thick at
  `Rmax+0.05`, offset 30° from the glyph faces, spanning horizontal ribs j4..j13 (straight zone, so ends don't
  poke past the curve).
- Caps: `0.66` dia × 0.26 (−40% from the first pass), INK.
- Soft point source (cheap, no extra lights): **Flame** ball `0.5` `RGB 255,238,205` T0.12 + **FlameHalo** ball
  `1.15` `RGB 255,205,150` T0.88, both at barrel centre. PointLight `RGB 255,168,96` bri 0.5 range 16, no shadows.
- Glyph plates: 2 transparent `1.2×1.6×0.05` at `lc ± perp×(Rmax+0.04)`, facing ±perp, tagged `RoundLantern`.

**Deployment (first pass):** `PathSteps`, a pole every **6 timbers** with **±0.35-gap stagger** (≈5–10% spacing
variation, seeded), **2 on the downhill side** where terrain was within `dhMaxDrop 8` studs (raycast-gated,
grounded to that terrain). 8 poles. Spawn left at `DevChannelSpawn` (on the path) for ongoing review.

**Still TODO:** chōchin on `PathExtension` / `DescentPath`; the top-of-DescentPath deck-style railing; then
restore the clearing spawn. SAVE THE PLACE (lanterns + railings are place-only).

### Update (2026-06-29, evening) — glow sprite, deck lanterns, light spill

- **Lit-from-within glow is now a soft radial SPRITE, not Neon balls** (on ALL lanterns). A Neon ball
  reads as a hard "uniform sphere" — especially on the small block deck lanterns. Replaced with a
  `BillboardGui` + `ImageLabel` using a **custom soft radial-glow PNG uploaded to the user's account:
  `rbxassetid://135490760661320`** (white center → transparent edge; tint via ImageColor3). One
  camera-facing quad → lighter than two translucent Neon spheres. NOTE: marketplace "circle" assets are
  Decals whose IDs don't load in an ImageLabel (`IsLoaded=false`) — had to upload our own Image. NOTE:
  freshly-uploaded asset may need moderation time to show for other players.
  - **Chōchin** (round, in `buildChochinPole.luau`): sprite parented to `ChochinBody` (sways), Size scale
    3.2, tint `255,208,155`, ImageTransparency 0.2 (the gradient paper already glows).
  - **Deck/block lanterns** (`LanternController.buildGlow`, runtime): sprite Size 2.1, tint `255,208,155`,
    ImageTransparency 0.1; added to every `*Lantern` under `RoshamboStage` alongside the 4 glyph faces.
- **Deck result-lanterns retoned to match the chōchin** (warm cream, dimmed ×0.75), **translucent paper**
  (T 0.42), and the **Overlook thinned 10→6** (skip NW-upper, SE-lower, + the two stair-top N-rail-end
  lanterns; posts kept, via a `skipLanterns` set on `deck()`).
- **Glyph fixes** (`LanternController`): canvas aspect now matches the (non-square 1×1.5) face so the ○
  renders round, not a vertical oval; fade slowed 0.18→0.35s.
- **Light spill cut** on all lanterns: PointLight Brightness 0.5→0.3; Range chōchin 16→9, deck 9→5 — so
  they read as contained warm points at dusk rather than washing the cliff.

### As-built — bamboo railing (2026-06-29) — LOCKED, `tools/studio/buildBambooRailing.luau`

Continuous bamboo post-and-rail along each path's **downhill/open-air edge**, dark bamboo (`70,55,32`, Wood).
Supersedes the §3 sketch (warm tan → dark; mid rail 1.5 → 1.25; +smooth top / rustic lower / barriers).

- **Edge line:** each timber's **±RightVector END**, `HW=3.0` from centre (≈ the timber edge). Posts ALWAYS
  embed at the timber edge — **terrain is irrelevant, never plant on ground**. Baseline = timber top.
- **Top rail:** SMOOTH continuous **Catmull-Rom** (`S=4`) through the edge points; cylinder segs + ball joints,
  dia `0.32` at **+2.9**.
- **Lower rail:** same run dia `0.22` at **+1.25**, control points get low-frequency **jitter** (`±0.154`
  lateral / `±0.112` vertical, seeded `20260629`) before the spline → hand-built wobble; interior points only
  (endpoints stay put → clean joins). User wanted it ~30% looser than the first pass, then "leave it."
- **Posts:** dia `0.45 × 3.0`, every **2 timbers** at the edge baseline.
- **Barriers:** invisible `CanCollide` `Transparency 1` box per gap (`10` tall, `0.4` thick).
- **Side selection:** rail the **finite-drop** edge; the no-hit (`999`) side is the cliff/wall — don't rail it.
  `edgeSign` picks it; one side per run (switching sides = a new run). The USER knows the side — ask, don't
  guess from a terrain probe alone (a wrong-side pick cost a redo here).
- **Connectors:** straight top+mid rail + barrier bridging two runs' endpoints so sections read continuous.
- **Deployed:** `Rail_PathSteps` (`Timber 0–47`, downhill), `Rail_PathExtension` (`ExtTimber 1–5`),
  `Rail_DescentPath` (`DescTimber 2–20`, downhill), `Connector_1` (PathSteps↔PathExtension ~4.4-stud seam),
  all in `Workspace.PathRailings`. DescentPath top (`DescTimber_2`) terminates clean for a future deck-style
  railing; its bottom stands alone.
