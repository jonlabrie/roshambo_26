---
shelf: world
updated: 2026-08-15
---

# Canyon

The ZenDojo world: a steep, narrow Japanese canyon gorge (mossy-cliff onsen-resort
feel), replacing the original bowl amphitheater in the 2026-06-15 pivot. One river
descends its whole length as a staircase of falls and pools; the only near-flat ground
is the arena clearing ([[arena-square]]). 50 players per server. Terrain lives in the
saved place; git holds the generator packet and the studio tools that carved it.

## Compass & frame

- **−Z = North, +Z = South** (owner-confirmed 2026-07-11); **X runs east–west**, the
  canyon's long axis. Never re-derive from sun position or marker names.
- Clearing at world origin; **East = +X = downstream**. Hero falls far west at x≈−430;
  downcanyon outfall east at x≈+135..200. Clearing floor ~y111–115, rims to ~y316.
- Terrain imported from the Gaea packet (`docs/superpowers/canyon/`: heightmap,
  erosion mask, `CanyonLayout.luau`, `gen_canyon.py`) at **1.5× the contract** —
  size (660,390,660), positioned (−130,190,−2). Buildings and avatars stay human
  scale; prop placement multiplies contract x/z by 1.5 and raycasts Y.

## The watercourse

Named in **flow order** west→east as `W<nn>_<Name>` — 86 objects renamed in place and
in the four builder scripts (`20ac08b`), so a rebuild cannot resurrect the old names:
`W01_HeroFall` (61-stud drop) · `W02_DockFall` (21; the falls dock is here, see
[[falls-dock]]) · `W03_OutfallRun` · `W04_MicroFall` · `W05_LargestFall` (16) ·
`W06_UpperRun` · `W07_UpperStep` · `W08_MidStep` · `W09_MidRun` · `W10_LowerStep` ·
`W11_LowerRun_Rocks` (rocks only, deliberately unbuilt-out — room to add without
renumbering) · `W12_ClearingFall` (22) · `W13_SquareFall` (22, into the square) ·
`W14/15/16_*Cascade` (downcanyon). Verified 2026-08-15 in the live place:
`CanyonWorld.Arena` holds the `W##_*_Rocks`/`_VFX` groups, `CanyonWorld.Water` the runs.
Sound for all of it: [[water-audio]].

**Upcanyon pool chain** (hand-sculpted by the owner with the Sea-Level terrain tool,
2026-06-20): 8 flat terraces descending 211.4 → 188.6 → 174.7 (largest, at the
suspension-bridge markers) → 159.4 → 150.3 → 137.6 → 132.4 → clearing pool ~110.
Roblox terrain water is flat-topped and static, so the descent happens at the lips:
carved trenches + stepped pools + beam/foam VFX. Every major fall carries the full
rock+VFX dressing (Cascade/CascadeSlow beams, whitewater bars, foam, calmed splashes —
owner found tutorial values too energetic: Speed ×0.6, Rate ×0.8).

**Clearing terrain** (`7eecce7`, `roblox/tools/studio/buildClearing.luau`): no flat
slab — an organic oval gravel terrace ~108×68 at FLAT_Y=111, gently graded (owner
likes the grade for sightlines), plunge pool at the −Z back corner, river hugging the
−Z cliff base, a single bare-rock fall face at x=38 dressed by VFX.

**Downcanyon** ([[viewing-platform]] frames it): the owner hand-carved the gorge east
of the clearing (a procedural carve was rejected — it left the river no logical exit;
solve the water's exit path first, then block sightlines around it). Pools sit on the
groove floor behind basalt sills; falls are textured Beam ribbons, mist at the bases
(`ad1d341`).

**Greening**: cliff rock is tinted, not repainted — `SetMaterialColor(Basalt/Rock)`
toward dark mossy green keeps the faceted render (a full-volume repaint to a grass
material smooths cliffs into blobs; owner rejected). Later terrain art: moss/rock PBR
via TerrainDetail on Slate (`CanyonMossySlate`, `ZenMossRock`).

## Gates & decisions

- 2026-06-09 owner ruling on water features, verbatim intent: the original kakehi
  flume was "**too much engineering in a space meant to be simple and tranquil**."
  Replaced by a natural creek + **one** Asakura scoop wheel ("no reason for three");
  wheels spin continuously, downhill; water sits just below grade; wheel sized to
  match the bell/drum. When tuning ZenDojo water, favour fewer/simpler elements and a
  natural read over mechanism.
- 2026-06-15 pivot locked: 50 players/server; river steep the whole way; clearing =
  mid-low widened outcrop + modest pool; scattered organic cliff-perch teahouses, no
  tidy terraces; bridges only at pinch points.
- 2026-06-20 division of labor, standing: the **owner sculpts basins and sets water**
  (Sea-Level tool — not scriptable); scripted water fills are banned (rectangular
  corners, floating blobs). Scripted rock carving is fine.
- 2026-06-18: owner hand-carves hero terrain; scripts dress it.

## Superseded history

The bowl arena + Phase-1 tier garden (2026-06-09 engawa-channel gardens, creek
meander, `buildTerrain.luau` heightfield) were retired by the canyon pivot; the
surviving artifacts are the reusable builders (Bridge, StoneLantern, Foliage) and the
clearing machine. One line in `log.md` records the retirement; the rest of that plan
text is dead.

## Raw layer

- packet: `docs/superpowers/canyon/` (heightmap, masks, `CanyonLayout.luau`, `gen_canyon.py`)
- specs: `docs/superpowers/specs/2026-06-15-zendojo-canyon-clearing-design.md`,
  `2026-06-20-zendojo-upcanyon-watercourse-design.md` (`e47e875`)
- key commits: `74fe1da` ArenaLayout retarget · `b22dedd` overshot waterwheel ·
  `7eecce7` clearing terrain · `ad1d341` downcanyon water/VFX · `20ac08b` W## renames
- terrain backups in ServerStorage: see [[place-state]] — note
  `ClearingTerrainBackup` is the raw PRE-carve canyon (restoring it buries the
  clearing) and `UpHeadBackup` predates the owner's headwall sculpt (never paste).
