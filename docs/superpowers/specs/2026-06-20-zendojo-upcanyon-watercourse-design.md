# ZenDojo Up-Canyon Watercourse — Design

**Status:** approved design, pre-plan (2026-06-20)
**Branch:** `m4b-zendojo-art-pass`
**Scope:** the up-canyon (head, −X) terrain + water feature — a descending chain of falls and pools from the western headwall down into the existing clearing pool. Sibling to the canyon-village sub-projects (paths/teahouses/bridge/interiors); this is the *terrain skeleton* the floor path + floor teahouses attach to later.

## Goal

Realize the **North Star** up-canyon water feature: a tall **hero waterfall** plunging down the western headwall into an upper basin, then **staged falls into generous, reflective pools** stepping down a **braided gravel streambed** to the clearing — mossy walls, dusk mist, calm and tranquil. The down-canyon (+X) falls/pools already exist; this builds the matching head-to-clearing half.

## World frame & current terrain (probed 2026-06-20)

- East = +X (downstream, built), **West = −X (head, up-canyon — this work)**, North = −Z, South = +Z. Y is provisional/voxel.
- Clearing pool ≈ **y110** (Terrain water), ends ~x−80. The **existing clearing in-fall** drops the dry floor (~y144 at x−120) into the clearing pool — **this fall is untouched and is NOT one of the three new falls.**
- Dry up-canyon floor climbs smoothly **y144 (x−120) → y205 (x−400)**, then **jumps to y243 at x−440** — a steep, **featureless** rise = the western headwall to be sculpted.
- Gorge width along the run: ~95–160 studs (pinches near x−240 ≈95).
- Place has `StreamingEnabled = true`. Material is Basalt/Rock voxels at RES 4.

## The watercourse (head → clearing)

Three NEW falls, largest at the western infall, into three generous pools, linked by a braided gravel stream, terminating at the existing clearing in-fall.

1. **Western headwall (x≈−400…−460):** sculpt the featureless end UP into a tall containing cliff / amphitheater — a rock face for the hero infall to plunge down, with side walls cupping the upper basin so the water reads as *contained*, not sheeting off a slope.
2. **Hero infall (largest) + Upper Basin pool (x≈−370, surface y≈195):** the hero fall plunges ~30–40 studs down the headwall into the upper basin — the biggest, most reflective pool, the most mist. The visual climax.
3. **Fall 2 + Mid pool (x≈−280, surface y≈172):** a ~23-stud carved fall face from the basin into the mid pool.
4. **Fall 3 + Lower pool (x≈−180, surface y≈150):** a ~22-stud drop into the lower pool.
5. **Braided gravel stream:** shallow water over a gravel bed with mossy boulders and **walkable banks + stepping-stone potential**, linking the three pools and running from the Lower pool down to the existing clearing in-fall (x−120, y144) → clearing pool (y110, unchanged).

Pool surfaces are flat terraces carved into the current smooth slope; banks sit on the sides within the 95–160-stud width. Elevations are starting targets — refined against live terrain during the build.

## Components & build approach (native voxel — approach 1, reuse-everything)

- **Terrain sculpt/carve (`tools/studio/*`, MCP Edit-mode):** `FillBlock`/`WriteVoxels` to (a) raise + shape the western headwall, (b) carve the three stepped pool basins + fall faces into the slope, (c) cut the braided shallow channel + banks. **Every carve takes a `CopyRegion` backup to ServerStorage first** (reversible), keyed per region (precedent: `T*PadBackup`, `GreenCanyonBackup`). RES-4 chunkiness is acceptable — hidden by moss + mist, and these are non-walkway scenery faces.
  - **Verification caveat:** raycast probes IN THE SAME SCRIPT as a `FillBlock` read STALE — always verify carves with a fresh probe pass.
- **Water:** Roblox **Terrain water** filling each carved basin + the shallow stream at the matching surface level (y195 / y172 / y150, stream graded between).
- **Falls VFX:** reuse + parameterize the **down-canyon beam-fall system** (already built/tuned to the official tutorial): FaceCamera beams + water texture + `TextureMode=Stretch`/`TextureLength=1`, crest foam, splash, mist particles. Hero infall = tallest/widest/most mist; falls 2 & 3 smaller. Housed in a **Persistent Model** so split-endpoint beams render under streaming (precedent: `DowncanyonVFX`).
- **Greening:** extend the `greenCanyon` moss-skin (Rock/Basalt → recolored LeafyGrass) + sparse clinging foliage over the new headwall/walls/banks, thinning to bare wet rock near the waterlines. Pink-maple accents are a later polish pass.

## Out of scope (per the agreed boundary)

- **Floor path + stepping-stone/plank crossings** — path sub-project, built against the finished stream.
- **Floor hero-teahouse + zen-garden terrace** (image foreground) — teahouse sub-project.
- **The suspension bridge** at the head — bridge sub-project (the falls just need to read well behind where it will cross).
- Wall teahouses are already placed (`workspace.CanyonTeahouses`); the new walls/mist must not bury them — greening + mist tuned to leave their perches readable.

## Success criteria

- Walking/flying the gorge head→clearing reads as ONE continuous descending river: hero infall → upper basin → fall → mid pool → fall → lower pool → braided stream → existing clearing in-fall, with no dry gaps or floating water.
- The western headwall reads as a sculpted containing cliff, not a featureless slope; the hero infall is clearly the dominant fall.
- Falls render during Play (streaming) and read as water (not blobs/arrows), per the down-canyon standard.
- All terrain carves are backed up and reversible.

## Open questions (resolve during build, not blocking)

- Exact pool footprints/widths per the live width pinches (esp. the x−240 ≈95 pinch).
- Whether the upper basin wants an island/boulder or stays open water.
- Mist density balance so it evokes the image without hiding the teahouses or tanking framerate.
