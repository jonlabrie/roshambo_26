---
shelf: world
updated: 2026-08-15
---

# Arena Square

The Shōrō square: the canyon clearing's social heart — bell tower (shōrō) with the
water-driven bell engine inside it ([[bell-engine]]), the karesansui at its floor, the
torii on the Overlook's west edge, and the throw-drum lantern above the roof. All
Rojo-managed hero props under `Workspace.RoshamboStage` (verified 2026-08-15: Shoro,
ShoroRoof, BonshoRig, BonshoBell, BellDrive, ThrowDrum, RanmaCarvings, Karesansui,
Torii, Waterwheel, Overlook, FallsDock, Hanabiya, SwitchbackDeck, ArenaSpawn).

## As built (through 2026-08-14, all owner-gated and pushed)

- **Karesansui = the bell tower's own floor** (`17927df`, owner's gate 2026-08-14,
  reference Chion-in). Panel is the post OUTER square `x −12.2..8.2, z −10.2..10.2`,
  derived from `pavilion.pos ± (postSpacing/2 + postD/2)` and asserted. Kerb: 4×10
  cypress plank on edge running between the plinths; E/W beams carry a
  `CypressVertical` cap. `postD`/`plinthD`/`plinthH` live in `ArenaLayout` — tower and
  garden must agree. Boulder islands removed; an invisible `BellRingAnchor` at (−2,0)
  carries the ripple rings (`RingMaxR` is an absolute — re-set it whenever the panel
  is reshaped). The bell-drive's main-run bearing plinths now stand west of the kerb
  on plain terrace: the machine is beside the garden, not in it. This supersedes the
  2026-07-24 55×30 whole-machine garden (`849bf79` era) and repaid the promenade that
  the hanabiya deepening borrowed ([[hanabiya]]).
- **Field texture**: ambientCG Gravel041 + composited symmetric-sinusoid furrows
  (`tools/glyphs/groovegravel.py` — recipe + asset ids in its header; the eye reads
  SHADING not height), MaterialVariants `RakedSandNS/EW`; ripple rings = `RakingMesh`
  solid faceted disc (`RakedGravelRings` variant, no normal map — geometry does the
  relief).
- **Torii** (`tools/builders/Torii.luau`, `assets/Torii.model.json`): Myōjin, shu-iro
  `cypressVermilion`, standing ON the Overlook deck's west edge at 113.30, pillars at
  z20.5/35.5 outside the deck's exit gap, black `KasagiCap`; an invisible `SeichuBar`
  closes the centre line (正中) on the `EngawaBarrier` collision group (`cff3d95`).
  **ArenaSpawn sits on the deck** at (80, 113.8, 28), facing west.
- **Drum roof + sōrin** (`8d40514`): roofRise 14.0 (a dead 45°); sōrin = rohan,
  fukubachi, mast, nine kurin, hōju on `BronzePatinaFine`. Tower top **174.17**, held
  in `ArenaLayout.towerTopY` with a rebuild-and-compare test.
- **Shōrō roof**: one uploaded trapezoid slate mesh instanced 4× (MeshId
  `98384801935296`, RoofingTiles013A SurfaceAppearance), cypress soffit + fascia —
  `assets/meshes/ShoroRoof.rbxm`, 12 parts (`dae8f00`). Build script
  `tools/studio/buildShoroRoofMesh.luau` bakes the MeshId with a `REUPLOAD` flag.
- **Throw-drum lantern (mawari-dōrō)**: eight pierced dragon-king ranma carvings —
  framed openings, flat DoubleSided quads with pierce alpha (`9503859`); assets in
  `src/shared/DragonKings.luau`; night glyphs are extruded Neon meshes ([[day-night]]).
- **Palette**: `cypressVermilion` 0.92/0.38/0.24 (bell hammer's log + torii only —
  dowels stay grey); `bronzePatina` lifted to 0.390/0.420/0.395 with the BonshoBell
  mesh re-exported to match (`75d7330`, `399bf14`, `156d44a`).
- **Bell sound** (`126fe3d`, owner: "unbelievably great"): the owner's Byōdō-in
  recording, mastered in-repo (cut in the 65 ms squeak→impact gap, HP80 + LP600;
  masters in `~/Desktop/Roshambo Reference/`), `rbxassetid://108417212310624`.
  `BellSoundController.client.luau` clones a one-shot per strike on the `gongHit`
  cue; InverseTapered rolloff min 70; live-tune attrs `BellVolume`/`BellRollOffMin`.
- **Strike VFX cut** (`849bf79`, `c2beffc`): flash, energy rings and water splash all
  removed — the strike is bare and the bell sound carries the moment.

## Gates & decisions

- 2026-08-14 owner gate: karesansui shrinks to the tower's post-outer square; the
  machine stands beside the garden. (Corridor reservations in `ArenaLayout` were NOT
  updated to match — tracked on [[item-4-merchant-row]].)
- 2026-07-24/25 gates: karesansui furrow look (symmetric sinusoid at ~6× strength
  won); the smallest sanzon stone on the bell axis at (−2,0) was the owner's call;
  strike VFX cut in favour of the bare strike + bell sound.
- **Drum caret lore** (owner decision 2026-06-08, then revised 2026-07-21): ∧ (caret)
  is the only R/P/S glyph that is not vertically symmetric, so a two-sided drum
  necessarily flips it — one half of the arena would see ∨ (the mascot's smile, the
  "happy side"), the other ∧ (the "sad side"). On 2026-07-21 the owner **dropped the
  asymmetry for now**: all rendering unified on the PWA's upward ∧, including the HUD
  pick buttons, so the mawari-dōrō shows the same upright glyph on all faces.
  Preservable if revived: bake the chevron upright on front/back facets and inverted
  on left/right. Do not "fix" the drum builder's `faceRot` either way without asking,
  and do not restore ∨ on the pick buttons unless the owner asks.
- Owner-liked idea, never scheduled: raked circular motifs doubling as R/P/S crowd
  standing zones.

## Raw layer

- specs: `docs/superpowers/specs/2026-07-24-karesansui-square-design.md`,
  `2026-07-21-dragon-king-ranma-panels-design.md`
- key commits: `17927df` karesansui shrink · `cff3d95` seichū bar · `8d40514` drum
  roof/sōrin · `dae8f00` roof mesh · `9503859` ranma carvings · `126fe3d` bell sound ·
  `156d44a` bronze re-export
- place-only pieces (verified 2026-08-15): `NorenCloth`/`BronzePatinaFine` material
  variants, `BellRingAnchor`, `EngawaBarrier` collision group — inventory on
  [[place-state]]
