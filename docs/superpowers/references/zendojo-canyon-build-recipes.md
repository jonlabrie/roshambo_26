# ZenDojo Canyon — Build Recipes (Quick Reference)

**Living doc. Source of truth for building the canyon path system at scale** (paths, switchback decks,
retaining walls, railings, lanterns). We've built ~5% of the total; this captures the hard-won recipes so
each new stretch is fast. Exact per-build params + published asset IDs live in the dated as-built specs
(linked per section); this is the *how* and the *gotchas*.

As-built specs to mine for exact numbers:
- Path: `specs/2026-06-26-zendojo-organic-path-system.md`, `specs/2026-06-27-zendojo-fw11-fw10-descent-design.md`
- Deck: `specs/2026-06-27-zendojo-fw11-switchback-deck-design.md`
- Walls: `specs/2026-06-27-zendojo-retaining-walls-design.md`
- Railings/lanterns: `specs/2026-06-27-zendojo-path-railings-lanterns-design.md`

---

## 0. Workflow (every stretch)

1. **brainstorm → spec → plan → inline execution.** Each stretch = its own spec+plan in `docs/superpowers/`.
2. **Prototype-first, ONE attempt, then STOP and ask.** Build one unit/stretch, let the user look in Studio,
   iterate on *their* read; only then batch. Never self-judge visuals. (`stop-and-ask-after-each-attempt`.)
3. **The user drives placement.** They move decks, shape draft markers, tune heights, sculpt terrain. You
   survey what they did (read live Studio state) and build to it.
4. **Draft-marker routing.** Drop a row of `Marker_*` balls (Neon, tag `DevMarker` → hidden in Play by
   `tools/studio/hideDevMarkers.client.luau`) in a `Workspace.PathDraft.<name>` folder; user drags them;
   you route a **Catmull-Rom** spline through them.
5. **Where things live:**
   - **Pipelined (Rojo + lune):** the arena, the **switchback deck** (`tools/builders/SwitchbackDeck.luau` →
     genmodels → `assets/*.model.json` → mapped in `default.project.json`), `LanternController`.
   - **Ad-hoc Workspace (published meshes/Parts):** the **paths, walls, railings, lanterns** — like the
     existing `PathSteps`/`PathMesh`. They persist via the **saved .rbxl place + published mesh assets**.
     *Remind the user to SAVE the place after any ad-hoc build.*
6. **Record as-built** (final params, counts, published asset IDs) in the stretch's spec when done.

---

## 1. Stepped-cobble path

A meandering mountain stair: timber risers + flat cobble treads + cement-gravel bed, routed through markers.

**Timbers (risers):** Part `6.4 (cross) × 1.6 (h) × 1.2 (depth)`, `Wood`, color `RGB 74,52,32`. Local **X
(RightVector) = cross-stream**; place with `CFrame.fromMatrix(pos, cross, Vector3.yAxis)`. **~3.5-stud
spacing** along the spline arc-length.

**Treads are FLAT per gap, stepping down at each timber — NOT sloped.** (Sloped treads bury the cobbles and
read wrong. The path is a staircase: flat tread, vertical riser at the timber.) Each gap's tread sits flat at
its **downhill** timber's grade.

**Cobbles (one published mesh for the whole run):**
- **Per-section Voronoi** — generate a separate cell field **inside each timber-to-timber gap** (clipped to
  the gap + tread half-width), NOT one continuous field (that runs under the timbers / over the edges).
- `~3–4 seeds per gap`, **min-sep 0.55**, **inset 0.08**, **1-pass Chaikin**, multi-ring dome **0.42**
  (×0.85–1.25), **FLAT-UP normals** (every normal `(0,1,0)` → uniform tone across the run), mono mossy
  **`122/127/117` ±~3** vertex colors, Material **Rock**, Color white, **DoubleSided**, CollisionFidelity Box.
- Apex ~`tread + 0.15` (just below the timber tops). Build **all gaps into ONE EditableMesh → publish**.

**Bed (cement-gravel):** `Concrete` + **`ZenCement2`** MaterialVariant, tint `138/142/142`. **Flat slab per
gap** (horizontal), top **~0.05 below the downhill tread**, ~1.2 thick. (A single tilted/long bed buries the
downhill end — do it per-gap, flat, keyed to the downhill timber.)

**THE SIZING RULE (so it reads right):** **timber width (6.4) > bed width (~5.8–6.4) > cobble width (~5.2–6.4).**
Timber ends then reveal proud; cobble ends tuck into the gravel. (Upper run: bed 6.42, cobbles HW 3.2. Descent:
bed 5.8, cobbles HW 2.6.)

**Heights are ANALYTIC** from the timber/marker grade — **never raycast a Box-collision mesh for Y** (returns
the flat bbox lid). Terrain raycasts are fine.

---

## 2. Switchback deck

A small posted timber viewing deck at a hairpin — smaller sibling of the clearing `Overlook`. **In the
`SwitchbackDeck` builder** (pure, lune-tested, genmodels→Rojo). Position **baked from the user's in-Studio
placement** (Rojo serve is one-way; read their move, bake it).

- **Slab:** `WoodPlanks`, 0.6 thick, color `107/79/51` ("Earth orange" = `{0.42,0.31,0.20}`). Define by
  **center + size** (exact dims; avoids float drift).
- **Posts:** `Wood` **1.125 sq** (25% lighter than Overlook's 1.5), **inset flush** with the slab edges
  (outer face aligned: `x ± POST_W/2`). Feet from a **terrain survey** at each post XZ (cliff edge ~near
  grade = stub posts; drop edge = tall). All vertical (a raking strut read "goofy" — user rejected it).
- **Girders:** `Wood` **1.2 × 0.825**, two long edges + one cross, flush, top at slab underside.
- **KŌRAN railing** on the **open-air edges only** (the view/drop sides): top cap `0.3×0.6` + mid-rail +
  **balusters `0.34` run up to the cap (no gap)** + **newels `0.62×0.62 × 3.7`**. **Open** on the cliff edge
  and the path-entry edge.
- **Result-lantern (block style):** ONE hanji lantern on the jutting view corner. `Neon` body, warm
  `0.635/0.49/0.28`, name **ends in `Lantern`** + dark `palette.ink` cap + warm `PointLight` (1.0/0.76/0.46,
  bri 0.68, range 9). The block `LanternController` finds `*Lantern` under `Workspace.RoshamboStage` and
  paints the 4-face result SurfaceGui — so block result-lanterns must live under RoshamboStage.

**Deck→path stair (Overlook connecting-stair recipe):**
- **Slate treads**, **Size `{2, 0.5, width}`** = 2 deep **along travel**, `width` across. ⚠️ `{width,0.5,2}`
  is rotated 90° (the bug we hit). Color `palette.ink`. Lerp from head→foot; ~6–7 steps.
- **Two sloped Wood stringers** via `Spec.segment(footEdge, headEdge)`, `len × 0.9 × 0.5`, dropped 0.7 below
  the treads; framing **newels** at the head.
- Place the **foot via a user-dragged target marker** (a cyan ball they position = where the path/bridge
  meets the bottom); build head→target; tune tread seat (down) + forward-overhang on the stringers to taste.

---

## 3. Ishigaki retaining wall

Dry-stone facing on the **downhill edge** where a path floats above grade. **Selective** — only on contiguous
spans where the float **> ~2.5** studs (a `SpanFinder` pass over the timbers; pad each span **±1 timber** so
single-timber spans taper naturally instead of forming nubs). Per-span **published** meshes in
`Workspace.RetainingWalls`.

**❌ What FAILED (don't repeat):** Voronoi-**domed bulgy pebbles** on a flat face (inset 0.12, dome 0.35) →
"scattered pebbles." Then flat low-dome cells → "flat wallpaper" (no joint shadows).

**✅ What WORKS (the recipe):**
- **Dark recessed backing** over the whole battered face (`COL_JOINT ~46/47/45`) + **flat proud stones on
  top** (`RELIEF ~0.22` above the backing → the gaps between stones are real recessed shadow = reads 3D).
- **Horizontally-coursed** stones: vertical stretch `SY 2.0`, min-sep `1.15` (cells ~2:1 wide).
- **Near-monochromatic** stone `96/98/94 ±3`; inset `0.12` (the joint width).
- **Batter:** top edge at the **bed edge (±3.2)**, base flared **±3.7 and down to terrain raycast − 0.4**.
- **Wall top at the BED UNDERSIDE** (~0.6 below the timber center), NOT at grade — so the timbers + bed edge
  stay visible above it and it reads as *supporting* the path.
- **`w = vs / Hs`** (map the stone field to the **local** wall height) so it fills base→top everywhere — a
  constant-height field leaves a mid-span dip where the wall is tallest.
- **Perlin-noise crown + base** so neither edge is a clean line; **taper to a ragged stub** (min-height
  clamp, not a sharp point) at span ends.

---

## 4. Bamboo railing + hanging chōchin  *(speced/planned, building next — fill in as-built after)*

- **Bamboo railing** (Parts, cylinders, tan `~170/150/90`): posts `~0.45 dia × 3.4` every **~2 timbers** at
  the bed edge on the **downhill** edge; **top rail ~2.9 + mid rail ~1.5**, open between. (Cylinder long axis
  = local X → vertical needs `CFrame.Angles(0,0,90°)`; rails along a run via `CFrame.lookAt`.)
- **Hanging chōchin** (Parts): ribbed barrel (Neon cream + thin dark rib rings + dark caps + cord +
  PointLight) on a **bamboo upright + cross-arm pole** on the **uphill** edge, ~every 6 timbers.
- **Round result display:** `LanternController` is being generalized — round lanterns are found by
  CollectionService tag **`RoundLantern`** and get a **BillboardGui** glyph (the block path = `*Lantern` name
  + 4-face SurfaceGui stays unchanged). Round lanterns can live anywhere (tag-driven).

---

## 5. Studio / EditableMesh gotchas (cross-cutting)

- **Publish meshes to keep them.** Unpublished `EditableMesh` (incl. `Content.fromObject` previews) becomes a
  **placeholder box on reload**. `AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {Name=...})` →
  returns **`(Enum.CreateAssetResult.Success, assetId)`** → `CreateMeshPartAsync(Content.fromUri("rbxassetid://"..id))`.
- **EditableMesh build:** verts in **world space**, place the MeshPart at **`CFrame.new()`** (origin). Faces
  need `AddNormal`+`SetFaceNormals` AND `AddColor`+`SetFaceColors` or they render nothing. Vertex colors
  survive publishing.
- **Tone:** two separate cobble meshes can light at different brightness — **flat-up normals** fix it; build
  a run as **one mesh**.
- **Cylinder primitive long axis = local X.** Vertical cylinder: `CFrame.Angles(0,0,math.rad(90))`.
- **Terrain raycast = fine.** Box-collision **MeshPart raycast = the flat bbox lid** (trap) — use analytic
  heights from timbers/markers.
- **MaterialVariant** for finishes: `ZenCement1` (Concrete, StudsPerTile 10, "river gravel"), `ZenCement2`
  (StudsPerTile 5, finer, the path bed). Recolor mesh packs via world-space MaterialVariant, not SurfaceAppearance.
- **Rojo:** `rojo serve` is **one-way** (file→Studio); in-Studio edits aren't written back — read them, bake
  into the builder. A **new `$path` in `default.project.json` needs a Disconnect→Connect** to apply.
- **Reversible terrain:** `Terrain:CopyRegion` to ServerStorage before carving; `PasteRegion(region, origin,
  true)` (pasteEmptyCells=**true**) to fully restore (false leaves added fill).
- **Compass (canyon-local):** the gorge bends, so N/E/S/W are not world-axis-aligned — record the world dir
  per stretch; don't assume.

---

## 6. Efficiency TODO (next big win)

The per-stretch build scripts (cobble-path generator, ishigaki generator, railing/pole/chōchin builders) were
written ad-hoc and live in the as-built specs + this session. **Extract them into reusable parameterized
functions** under `roblox/tools/studio/` (e.g. `buildSteppedPath(markersFolder)`, `buildIshigakiSpan(span)`,
`buildBambooRailing(model, prefix)`, `buildChochinPole(cframe)`) so the next valley stretch is "drop markers →
call the function," not re-derive. Biggest lever for the remaining ~95%.
