# ZenDojo FarWall_11 Switchback — Rest-Terrace Deck (Design)

Status: design, awaiting user review (2026-06-27).

Related: memory `zendojo-canyon-village`, `zendojo-organic-cobble-path`, `zendojo-viewing-platform`;
spec `docs/superpowers/specs/2026-06-26-zendojo-organic-path-system.md` (the FW11→tunnel path this
descent continues from). Reference build: `Workspace.RoshamboStage.Overlook` (the clearing's two-tier deck).

## Purpose

FarWall_11 is the **hairpin apex** of the whole canyon path: the upper FW11→tunnel run arrives here, and
the lower run doubles back ~180° to descend toward FarWall_10. This spec covers the **turning landing** at
that hairpin — built as a **small posted timber viewing deck**, a smaller/simpler sibling of the clearing
Overlook. It is the keystone of the FW11→FW10 descent; its landing position determines where the traverse
path begins. The descent itself (the cobble traverse FW11→FW10) and any ishigaki facing are **separate,
later work** — not in this spec.

## Compass (recorded to avoid ambiguity at build time)

The user's canyon compass (canyon-local, not world-cardinal — the gorge bends, so these are not
strictly orthogonal world axes; the **World dir** column is what the build keys off). Confirmed 2026-06-27:

| Compass | World dir | At the deck |
|---|---|---|
| **East** | **+Z** | downcanyon — toward the clearing & falls; the basin drops away here (the main view) |
| **South** | **+X** | open slope side; deck stands on posts |
| **North** | **−Z** | the cliff wall (rises to ~160–173); deck tucks against it |
| **West** | **−X** | up-canyon; the upper path enters here AND the trail exits toward FW10 here |

## Siting

- **FW11 marker:** `(133, 138.4, −74.2)`. **Upper-path arrival** (Timber_0): `(131, 139, −74)`, walking in
  heading **+X** (≈ `(0.99, −0.10, 0.13)`).
- **Onward heading** FW11→FW10: `(−0.92, 0, 0.39)` — i.e. −X and +Z. Both the entry and the exit lie on the
  **West (−X)** side; the deck extends South/East to give turning room. Net turn ≈ 180°.
- **Natural ledge:** a narrow band at grade **~138** running x≈120–140 in the z≈−74 to −78 strip, bounded by
  the cliff wall to the North (z≈−82 → 160+) and the drop to the East (z≥−70 falls toward the basin ~122–125).
- **Deck footprint:** ~**12 (along the cliff, X) × 10 (out over the drop, Z)**, **deck top Y ≈ 138** (flush
  with the arriving path). Occupies roughly x≈123–135, z≈−76 to −66 — tucked against the cliff on the West
  edge, cantilevered on posts over the Eastern drop.
- The posted deck **bridges the steep notch on its legs**, so the hairpin needs **no earthen fill**.

## Structure & materials (matched to the Overlook)

All timber colour **RGB 107/79/51** (BrickColor "Earth orange"), as the Overlook.

- **Deck slab:** `Material.WoodPlanks`, thickness **0.6**, ~12 × 10, top at Y≈138.
- **Girders:** `Material.Wood`, section **1.6 × 1.1**, under the two long edges + one mid-span beam.
- **Posts:** `Material.Wood`, **1.5 × 1.5** square, from girders down to terrain: short (~2–4) on the
  North/cliff edge, tall (~12–16) on the East/downhill edge (ground ~122–125 there). One simple **X-brace**
  between the two tall outer (East) posts for believability.
- **Simpler than the Overlook:** single level (no upper/lower tiers), one ring of posts, no girder grid.

## Railings & lanterns

- **Railed edges:** **East** (downcanyon / basin view) and **South** (open slope) — the two open-air sides,
  forming an **L**. Railing = **newel posts** (`Wood`, 0.62 × 0.62, **3.7** tall) at corners and run ends +
  **balusters** (`Wood`, 0.34 × 0.34, **3.2** tall) spaced ~2 studs + a **top rail** (`Wood`, ~0.34 × 0.34)
  capping them at ~3.2 height. Matches the Overlook.
- **Open edges (no railing):** **North** (against the cliff) and **West** (path enters + steps leave).
- **Lanterns:** **two** lantern-newels (`Material.Neon` block **1 × 1.5 × 1**, warm **RGB 161/124/71**, with
  a warm `PointLight` child) at the **two ends of the railed L-run**, flanking the openings, with the jutting
  SE view corner between them.

## Hairpin flow & descent handoff

1. **Enter (West/−X edge):** the last cobble steps of the upper path land flush onto the deck at grade ~138.
   A flat **flagstone/timber threshold** marks cobble-path → wood-deck.
2. **Turn:** pivot ~180° on the open deck; you now face the onward (−X/+Z) direction.
3. **Leave (West/−X edge, offset +Z):** **2–3 wooden step-downs** (deck timber) off the edge shed the first
   ~2 studs, then **transition to the proven stepped-cobble path** (timber risers + Voronoi cobble treads,
   per the organic-path spec) for the traverse to FW10. Clean handoff: deck reads timber, trail reads cobble.

## Units (each independently buildable/testable)

- **DeckPlatform** — slab + girders + posts + X-brace. Input: footprint rect, deck-top Y, terrain sampler.
- **DeckRailing** — newels + balusters + top rail along a given edge polyline. Input: which edges, heights.
- **DeckLanterns** — lantern-newel + PointLight at given points. Input: 2 corner positions.
- **DeckThreshold + StepDown handoff** — flagstone threshold at entry; 2–3 timber step-downs at exit, ending
  at the cobble-path start point. Input: entry point, exit point + onward tangent.

Reuse existing builders where they fit: `StoneLantern.luau` is stone-style (the Overlook lanterns are the
timber-newel + Neon style — match the Overlook, not StoneLantern, for consistency here).

## Out of scope (later, separate specs/plans)

- The FW11→FW10 cobble traverse itself (route, bench, steps).
- Any ishigaki facing on the descent's downhill edge.
- Greening / planting around the deck.

## As-built (2026-06-27)

Built via the `SwitchbackDeck` builder (genmodels → Rojo), synced to
`Workspace.RoshamboStage.SwitchbackDeck`. Diverged from the original design in these ways:

- **Relocated** by the user from the original basin-edge spot out onto a higher promontory shelf:
  deck center **(159.7, −66.6)**, top **138.46**, footprint 18 × 15. Sits on near-grade ground on the
  North/cliff edge, cantilevering over the drop toward the SE corner.
- **Legs:** six vertical posts (1.125 sq, 25% lighter than the Overlook), feet baked from the terrain
  survey; under-slab girder frame (two long + one cross, 1.2 × 0.825). The SE "raking strut" idea was
  tried and dropped — terrain there is higher than expected, so a plain vertical reads better.
- **Railing:** KŌRAN (cap + mid-rail + balusters to the cap + three newels) on the East (downcanyon) and
  South (X1) open-air edges; North (cliff) + West (path) open.
- **Lantern:** ONE hanji **result-lantern** on the SE corner (not two plain lanterns). Body named
  `DeckLantern` so the runtime `LanternController` paints the live World-Throw result SurfaceGui on it
  (recipe matched from `Overlook.luau`'s `hanjiLantern`: Neon body + warm PointLight + ink timber cap).
- **Upper-path extension:** the upper FW11→tunnel cobble path was extended ~20 studs (near-flat) to reach
  the relocated deck, landing flush on the West edge. Built **ad-hoc in `Workspace.PathExtension`**
  (`ExtTimber_*` + `ExtBed` Parts; `ExtCobbles` per-section Voronoi mesh **published as
  `rbxassetid://82556346085009`**; `ExtThreshold` Slate sill at the deck join). Cobble recipe = the
  existing run's (per-section gaps, min-sep 0.55, dome 0.42, flat-up normals, 122/127/117).

## Deferred follow-ups

- **FW11 → FW10 descent** — the actual downhill traverse route (and any step-downs off the deck) is its
  own project; not designed yet. Needs a separate spec/plan. (The plan's Task-5 step-down stub was dropped.)
- **Consolidate the extension into the pipeline** — `PathExtension` is ad-hoc workspace geometry; fold it
  into a builder or committed/published model so it's reproducible like the deck.

## Open questions

- Whether the far/drop-edge posts want a stone footing pad where they meet the slope (deferred; cosmetic).
