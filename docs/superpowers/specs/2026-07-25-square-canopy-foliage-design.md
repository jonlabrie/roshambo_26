# Square Canopy Foliage — Design

**Date:** 2026-07-25
**Status:** Approved (brainstormed with user)
**Layer:** Shōrō-square amplification, layer 1 of 5 (foliage densification)

## Vision

Two reference images govern the experience's foliage, and this pass synthesizes them:

- `The Shoro square.png` — the arena square amplified: brilliant red and gold maples
  framing the falls and merchant row, sculpted pines by the buildings, dense conifer
  walls behind. Jewel tones concentrated at the heart.
- `forest_valley_teahouses.png` — the valley north star: near-monochrome deep mossy
  greens, lantern chains, mist, with rare pale-blush accent trees.

**Synthesis rule: color density is a function of proximity to the square.** The arena
erupts in autumn jewel tones; the canyon beyond stays evergreen moss and lanternlight.
This pass builds the square's viewshed only — but the species kit and scatter builder
are designed for reuse when the valley pass extends the system down-canyon with a
mossier palette.

## Scope

- **In:** the canopy tree layer (maples, conifers, pines) for everything visible from
  the square — cliff walls, falls frame, stair slopes, merchant-row backdrop.
- **Out (later passes):** valley-wide greening; clean-swap of the existing salvaged
  ground-layer scatter (~1,300 reeds/ferns/weeds in `Sandbox.WaterFoliage`) and bamboo
  grove — those stay as-is for now; ground/canopy interplay tuning beyond exclusion.

## Current state (2026-07-25)

The existing foliage system (`Sandbox.FoliagePicks` + water-margin scatter) is
ground-layer only — zero maples, zero conifers — and its assets are salvaged,
prototype-only, and cannot ship. The canopy layer does not exist yet; this pass
creates it with clean-sourced assets from day one.

## Approach (chosen: hybrid)

Hand-placed **heroes** (the ~20–35 storytelling trees) + a parameterized **mass
scatter** (the conifer walls). Composition where the eye lingers, procedure where
it's texture. Rejected alternatives: all-scatter (RNG fights jewel-tone placement),
all-hand-placed (unscalable to the valley, nothing reusable).

## 1. Species kit

Six roles, each 1–3 clean meshes, curated into a new canonical `FoliageKit` folder
(the salvaged `FoliagePicks` is untouched until the ground-layer swap):

| Role | Purpose | Share |
|---|---|---|
| Cliff conifer (2–3 silhouette variants) | the mass; deep desaturated green, slight blue distance shift | ~70% of placements |
| Red maple | hero jewel (momiji) | heroes only |
| Gold maple | falls-edge counterpoint, nearest water | heroes only |
| Sculpted pine (niwaki) | building-adjacent silhouettes: machiya row, square corners | heroes only |
| Mid-green broadleaf | transition cushion between jewel tones and dark cedar | scatter-mixed near heroes |
| Blush accent (sakura) | valley-palette seed; 2–3 placements high on the stair slope | heroes only |

**Sourcing:** Roblox Creator Store, Roblox-endorsed packs first (clean license by
construction). Candidates are inserted into an offscreen staging area, and **every
import is backdoor-scanned** (standing rule; require(assetId) / attr-hidden payloads)
before use; rejects deleted immediately. User picks silhouettes from screenshot
line-ups. Recolors via `SurfaceAppearance.Color` tint (established pipeline; clear
baked TextureID washout per the texturing recipe if needed).

**Color authority is night-first:** tints chosen at night lighting (`DayNightLockT`
0.75, lanterns on), day-checked second (0.19).

## 2. Hero placement flow

- New committed survey tool `tools/studio/placeCanopyHeroes.luau`, the
  `surveyDeckPlacements` place/bake pattern:
  - MODE="place" stamps draggable heroes from the kit per the CONFIG draft;
    user drags / swaps species / deletes / duplicates in Studio.
  - MODE="bake" reads live positions back into CONFIG literals — the composition
    is reproducible from code even though clones are place-only.
- Draft composition from the reference: red maples on the NW slope over the machiya
  row and flanking the falls' shoulder; golds at the water's edge below the falls and
  by the wheel pool; niwaki at the merchant-corridor mouth and square corners; blush
  accents high on the stair slope.
- Each hero raycast-grounded to terrain; random yaw; ±15% scale jitter off a per-tree
  base.
- Clones live under `CanyonWorld.Foliage.Heroes` (place-only per the workspace
  convention — foliage never enters RoshamboStage). Mandatory engine flags applied at
  stamp time (see §5).
- **Heroes precede the mass scatter** — composition first; the scatter excludes a
  radius around each baked hero so the walls never crowd a silhouette.

## 3. Conifer-mass scatter builder

- Pure placement core `tools/builders/CanopyScatter.luau` (Lune-tested; see §4) +
  thin Studio shell `tools/studio/scatterCanopy.luau` that feeds it terrain samples
  and stamps results.
- **Sampling:** raycast columns on a 4-stud grid over the viewshed; each column
  records surface altitude + slope normal.
- **Placement rules:** plantable-slope threshold; altitude above the valley-floor
  band (water margins belong to the ground layer); Poisson-style min-spacing
  8–14 studs jittered; density greatest high on the walls, thinning toward the floor.
- **Determinism:** silhouette variant, yaw, ±20% scale, small tint jitter — all drawn
  from an integer-LCG seed; re-running reproduces the identical forest, so gate
  iteration = parameter edits.
- **Exclusions:** square precinct + karesansui garden; ArenaLayout reserved corridors
  (`shopCorridor`, `eastCorridor`); path/step footprints; WaterMap water cells
  (reused); radius around every baked hero; the falls' visual corridor (white water
  stays framed, never curtained).
- **Transition weighting:** within ~40 studs of a hero cluster the picker mixes in
  mid-green broadleaf — the references' cushion rule, encoded.
- **Output:** `CanyonWorld.Foliage.CliffMass`; first-run budget ~250–400 conifers.

## 4. Testing

The placement math — LCG, band selection, spacing rejection, exclusion tests, species
weighting, transition mixing — is a pure module with Lune tests (repo builder pattern;
TDD). Studio scripts stay thin I/O shells with no testable logic.

## 5. Performance

- Mandatory per-clone flags baked into both tools: `RenderFidelity=Automatic`,
  `CastShadow=false`, `CanCollide=false`, `CanQuery=false`, `CanTouch=false`;
  strip any `BillboardGui`.
- After both layers pass visually: publish and bench on a real phone — framerate at
  the square with full canopy in view; streaming arriving from a teahouse.
- Fallback levers in order: reduce mass count → drop a silhouette variant → shrink
  alpha canopy meshes. Bench results feed the future valley pass, which multiplies
  these counts.

## 6. Sequence & gates

1. **Kit curation** — stage candidates, scan, screenshot line-up → **user picks**.
2. **Heroes** — one composed attempt → **user walks it** (square floor, deck, one
   western teahouse) before iteration. Standing one-attempt-then-stop rule.
3. **Mass scatter** — one run → **user walks it**.
4. **Perf bench** on published place with a phone.
5. **Place save/publish** (carries the trees; also carries the pending workspace-cruft
   deletion from 2026-07-25).

Git carries: the two Studio tools, the pure module, its tests, this spec, the plan.
The trees themselves are place-only.

## Deferred / adjacent

- Valley-wide canopy pass (reuses kit + builder, mossy palette, blush accents).
- Ground-layer clean-swap (replaces `Sandbox.WaterFoliage` species with clean
  equivalents; same placements).
- Bamboo grove clean-swap / LOD strategy (RealisticBamboo is high-poly).
- Falls/mist atmospherics beyond foliage (separate art layer if wanted).
