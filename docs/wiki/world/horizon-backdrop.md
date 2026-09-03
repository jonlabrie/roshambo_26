---
shelf: world
updated: 2026-09-03
---

# Horizon Backdrop

The mountain ranges outside the canyon, and the atmosphere they are seen through. The terrain
is a hard box (see [[canyon]]: rims ~y300 to the very edge on three sides, the east side open),
so every vantage that looks over a rim or out the east mouth used to see the cut edge against
empty sky, and below the horizon the skybox's bottom face. The backdrop hides both while
leaving Roblox's own sky alone: the sun, moon and 3000 stars are drawn by the engine on top of
whatever the Sky object shows, and the day/night cycle is still nothing but `Lighting.ClockTime`
([[day-night]] scope ruling untouched).

## As built (trial home, place-only)

`Workspace.Sandbox.SkyBackdropTrial`, rebuilt by `roblox/tools/studio/buildSkyBackdrop.luau`
(MCP `execute_luau`, Edit). It holds:

- **Ground**: 25 flat 2000-stud tiles whose top sits just above y0, so the skybox never shows
  below the horizon.
- **NearRange / FarRange**: MeshPart strips on two ellipses outside the terrain footprint, each
  a normalised 1000 × 500 × 400 height-field scaled by `MeshPart.Size`. Anchored, no
  collision, no shadows, `Slate` tinted toward the cliff rock, `ModelStreamingMode = Persistent`
  so instance streaming never drops them.

**Heights are derived, not chosen.** The canyon is a 300-stud gorge and every vantage looks up
at its rim, so each strip's crest is computed from the terrain skyline as seen from the five
vantages in the builder's `VANTAGES` table (clearing, both platforms, suspension bridge, falls
landing) plus a clearance angle, capped at the engine's 2048-stud axis. Read the result off the
parts: every strip carries `CrestY` and `CrestDrivenBy` attributes. To re-measure a skyline, the
builder's `skylineAngle` is the probe. The rings' radii, depths, strip counts and the clearance
angle live in that file; the near ring is as close as its depth allows without the footprint
crossing the terrain box (the builder pushes a strip outward if any corner would).

**Shapes come from Blender.** `roblox/tools/blender/backdrop_ranges.py` generates six ridge
strips (three "near" with a foothill apron, three broader "far") as low-poly flat-shaded
height-fields — ridged noise, meandering crest, tapered ends so strips overlap on the ring —
and exports each to its own FBX per [[blender-pipeline]] §1. The owner imports them once with
Studio's 3D Importer; the builder's `MESH_IDS` table records what that minted. Outputs are
derived, so they live in the reference folder, not `art/`. The file's `AGGRESSION` knob scales
crest variance, meander, spur detail and profile concavity; `VERSION` suffixes the exports so a
re-import never collides with the previous set.

The importer's originals are parked in `ServerStorage.BackdropImports` (both the v1 and v2
sets) as the import record; they are not scenery.

## Atmosphere

One global `Lighting.Atmosphere` fades the ranges into the sky by distance, which is what makes
them follow the day/night cycle with no code — and it is also what decides whether they read
as rock or as a tint in the fog. Nothing in `roblox/src` writes to it. Read the live values in
Studio's Properties panel rather than from here; the two that matter for the backdrop are
`Density` (how fast surfaces fade with distance) and `Offset` (how much a distant silhouette
stays distinct from the sky).

## Gates & decisions

- **2026-09-03 owner: approach chosen** — real geometry outside the box plus the existing
  Atmosphere, over feathering the terrain outward or painting mountains into a custom cubemap
  (a skybox is at infinity: no parallax, and a painted band cannot follow the atmosphere's
  tint through dusk and night, where this world lives).
- **2026-09-03 owner: part-built silhouettes rejected twice.** Rolled blocks "read as boxes";
  wedge-pyramid massifs "still just look like triangles, possibly more so". Hence meshes. Both
  trials were throwaway and are not in the repo.
- **2026-09-03 owner, on the v1 meshes:** "a little bit the same"; then "peaks a bit jagged and
  sharp, make them half as aggressive", "too low on the horizon", "too far in the distance".
  v2 = `AGGRESSION 0.5`, rings moved in, clearance raised, rings deepened so the closer
  placement does not re-sharpen slopes.
- **2026-09-03 owner: Atmosphere retuned** for the backdrop — Offset raised (silhouettes hold
  against the sky), Density lowered one step after 0.22 was "too much". "Pretty good. Let's run
  with that for now." Written to the Edit data model; saved with the place.
- The 3D Importer's dialog reports **wrapper asset ids, not mesh ids**: `CreateMeshPartAsync`
  on them fails with "Failed to load mesh asset". The usable id is `MeshId` on the MeshPart it
  created. Recorded on [[rojo-meshpart-rbxm]]'s neighbour page here because it cost a build.

## Raw layer

- generator: `roblox/tools/blender/backdrop_ranges.py` · builder:
  `roblox/tools/studio/buildSkyBackdrop.luau`
- key commits: `75b4de2` v1 (generator + sightline-sized placement) · `4308c22` v2 (softer,
  closer, taller)
- reference folder: `~/Desktop/Roshambo Reference/backdrop_2026-09-03/` (FBX exports, scratch
  blends — derived, untracked)
