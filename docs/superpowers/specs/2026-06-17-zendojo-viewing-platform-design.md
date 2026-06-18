# ZenDojo — Downcanyon Viewing Platform + the View (design)

**Date:** 2026-06-17
**Branch:** `m4b-zendojo-art-pass`
**Status:** design approved (brainstorming), ready for implementation plan
**Related:** canyon redesign + clearing terrain (see `docs/superpowers/specs/2026-06-15-zendojo-canyon-clearing-design.md`), bell engine (`docs/superpowers/specs/2026-06-16-zendojo-bell-engine-design.md`)

## Problem

The clearing's east edge is meant to carry a **cantilevered overlook** whose main view is **Eastward / downcanyon**, at the rapidly descending river. But the imported canyon terrain ends around world **x≈+135** — past that the floor falls away into empty haze (the "rapidly descending river" currently pours into void). We need to (a) build a believable downcanyon view that terminates gracefully, and (b) rough in the overlook itself.

**Decided solution:** the canyon **swerves sharply north (−Z)** near the bottom of the existing terrain. From the platform, the eye lands on a **mossy rock prow** that blocks the straight-ahead void; the river **wraps north around it**, cascades down a few more steps, and **dissolves into fog** — depth without an infinite build.

## Compass / coordinates

Established by the canyon work: clearing at world **origin**; **East = +X = downstream**; **North = −Z**; clearing floor ≈ **y111**; existing canyon descends to floor ≈ **y70 at x≈+124**, terrain ending ≈ **x+135**. All terrain Y values are **provisional** — probed and raycast-snapped live at the gate (canyon workflow convention).

## Locked decisions (from brainstorming)

- **View ambition:** *solid set-piece* — non-traversable, but holds up from multiple angles (platform, future overlook perches, a flying camera). Real-looking rock + a believable descending river.
- **Far-end resolve:** *cascade into mist* — the river tumbles down a few more falls/pools as the gorge bends, then dissolves into fog around the corner.
- **Build method:** *Approach A — native Roblox voxel, sculpted in-Studio, iterative.* (Alternatives considered below.)
- **Platform:** *tiered twin overlooks* — two stepped decks at different heights framing the gorge from two vantages.
- **Railing:** *bamboo* handrail (matches the reference foreground's path-overlook feel; distinct from the teahouse kōran).
- **Aesthetic target:** the misty mossy-gorge references — moss-green walls (not bare grey), clinging trees/foliage, warm paper lanterns, pale rocky river, dusk/mist.

## Design

### 1. Composition (the "stage")

Top-down (North = −Z up, East = +X right; clearing at origin):

```
                    N (−Z)
                      ↑
                 ┌── fog ──┐        far gorge dissolves into mist
              ╔══╧════╗
              ║  PROW  ║              mossy rock buttress blocks the void
              ╚══╤════╝
   clearing      │  river wraps N around the prow, cascades down
 ┌──────────┐    │
 │  terrace  │═══╪══════════          existing canyon floor:
 │  (origin) │ boundary  descent       boundary fall → descending river
 │  ▣ machine│  fall                    (world x≈+54 → +135, floor ~111 → ~70)
 │  P1 ┐     │
 │  P2 ┴─────┼──→ ESE sightline
 └──────────┘
       W ←——————→ E (+X)
```

From the east terrace edge the two platforms look **ESE**. The eye follows the existing canyon (boundary fall + the river dropping away), meets the **mossy rock prow** straight-east in the middle distance (~world x+140–175), follows the river **north around** the prow into a few more cascade steps, and loses the far end in **fog**. No true horizon is ever built.

Three spatial pieces:
1. **The join** — extend/finish the existing canyon floor + walls from ~x+100 east to the bend, descending; seamless to existing voxel.
2. **The swerve** — the rock prow + the new north-running gorge segment behind/around it (the backdrop that kills the void), descending and fogging out.
3. **The platforms** — two stepped decks cantilevered off the east terrace edge (§3).

### 2. The view terrain (Approach A — native voxel)

- **Carve pass.** A scripted, idempotent voxel pass (modeled on `tools/studio/buildClearing.luau`, run via MCP `execute_luau` in Edit) lays in the join + swerve: a continuing river channel with descending floor + flanking walls, bent north around the prow. Then **hand-finish** in the Terrain Editor for organic irregularity.
- **Snapshot first.** Terrain edits are destructive and non-recoverable: `Terrain:CopyRegion` → park in `ServerStorage` before any write; the carve script pastes it first for idempotent re-runs. (Lesson from the clearing carve.)
- **The prow.** A voxel mass (mossy buttress jutting into the channel, river wrapping its north side). Reserve a single **MeshPart** *only* if its silhouette wants a crisp overhang voxel can't hold — otherwise pure voxel (moss + fog hide facets).
- **The descending river.** Calm stepped pools = **terrain water**; the drops between them = the established **water-sheet mesh + Beam + mist-particle** VFX (terrain water can't sheet down a fall — documented from the clearing). A few cascade steps wrapping the bend, each smaller, the last lost in fog.
- **Greening.** Walls re-materialed from bare grey toward moss (terrain Grass/LeafyGrass + `Terrain:SetMaterialColor` toward mossy green) and dressed with foliage + clinging trees (reuse `Foliage.luau`). Density highest near the platforms, thinning into the fog.
- **Mist + life.** A fog volume (Atmosphere + layered `ParticleEmitter` banks) at the far end hides the terrain cutoff and builds the depth gradient. A scatter of **warm lantern props + PointLights** on the far (non-traversable) perches reads as distant teahouses — cheap depth/life, reusing the chōchin / `StoneLantern` primitives.

### 3. The twin overlooks

Two stepped **kake-zukuri** decks cantilevered off the clearing's east terrace edge, both aimed ESE, reusing the locked teahouse building blocks (substructure, deck, railing, lanterns) — **overlooks, not buildings**.

- **Upper deck** — at ~clearing floor level (y≈111–113), the wider main overlook, projecting east over the edge on kake-zukuri posts seated into the terrace lip. Frames the full composition: boundary fall → river → prow → fog.
- **Lower deck** — a few steps down (y≈105–107), offset and projecting a touch further, for a second framing closer to the dropping river. Reached by a short **lantern-lined stone stair** between the tiers.
- **Railing & lanterns** — **bamboo handrail**; a hero **hanging chōchin** at the upper deck's outer corner; **standing ishidōrō** at the rail line. The warm-glow anchors of the vantage.

### 4. Reusable canyon-wide greening (principle)

The greening / foliage / lantern-dot / mist treatment is **not** a downcanyon one-off — the same look applies upriver across the whole gorge (per the master reference). So author it as **reusable passes**, with the downcanyon view as the first application:
- consistent moss material targets (`SetMaterialColor` values) reused canyon-wide;
- a **foliage-scatter helper** (region + density → placed foliage on terrain via raycast-snap);
- a **lantern-dot helper** (anchors → lantern prop + PointLight);
- shared **mist/Atmosphere** settings.

This keeps the whole canyon coherent and avoids redoing the look later.

## Components

- **`ArenaLayout.luau`** — add an `overlooks` block (per-deck `{pos, facing, tier}` anchors) and any prow/far-gorge + lantern-perch anchors needed for placement. Coordinate authority stays code-side.
- **Overlook builder** (new pure builder, `tools/builders/`) — emits the two decks + posts + bamboo rails + lanterns + connecting stair as a committed `*.model.json` via `lune run tools/genmodels`; reuses teahouse substructure/deck/lantern recipes.
- **`tools/studio/buildDowncanyon.luau`** (new, MCP-run, not Rojo-synced) — snapshot + voxel carve of the join/swerve/prow + water pools; mirrors `buildClearing.luau` structure.
- **Greening/foliage/lantern helpers** — reusable scatter + material + lantern-dot utilities (canyon-wide).
- **VFX** — reuse the clearing's fall water-sheet + mist pattern for the cascade steps; fog volume at the far end.
- **Prop-snap pass** — raycast-snap the overlooks + foliage + lanterns onto the finished terrain (bridge code↔terrain).

## Testing

- **Lune (relationship tests):** the `overlooks` block defines two decks at distinct tiers off the east edge, facing downcanyon; the builder emits both decks with rails + lanterns + the connecting stair; parts present and named (builder↔controller/snap contract). Assert *relationships*, not exact coords (tuned at the gate).
- **Live MCP gates (USER):** terrain carve/swerve/prow reads right from both decks; the river cascades and fogs out with no visible cutoff; greening + lanterns + mist sell the reference look; the two decks frame the gorge as intended. Snapshot before terrain writes; sign off at the gate before committing.

## Scope / fidelity

- **In scope:** rough-in/blockout of the downcanyon view terrain (join + swerve + prow + cascading river + basic greening + mist + lantern-dots) and the twin overlooks (decks + posts + bamboo rail + lantern placeholders + connecting stair). Reusable greening/foliage/lantern/mist helpers introduced here.
- **Out of scope (later):** the full art/beauty pass (detailed foliage models, textures, materials); applying the greening pass to the *rest* of the canyon (this round only builds the reusable helpers + the downcanyon application); traversal/teahouses down in the view (it stays non-traversable); the boundary-fall VFX polish beyond what reads at rough-in.
- **Explicitly not:** raising/regenerating the existing canyon via a Gaea re-import (destructive; would wipe the clearing carve + machine staging).

## Approaches considered (for the record)

- **A — native Roblox voxel, in-Studio (CHOSEN).** Same medium as existing terrain → seamless seam; distant + misty view makes voxel fidelity plenty; iterate live over MCP; reuses `buildClearing` + clearing VFX; no destructive re-import. Con: no crisp overhangs (mitigated by reserving a MeshPart for the prow if needed).
- **B — Gaea round-trip.** Best erosion detail, matches original pipeline. Rejected: stitching a new region to existing voxel at 1.5× is fiddly and destructive (a re-import wipes the clearing carve + machine staging); slow round-trips; documented Gaea pain; erosion detail is wasted under moss + fog.
- **C — hybrid (voxel join + MeshPart far wall).** Buys a crisp overhang silhouette. Held in reserve only if the prow demands it; otherwise a second medium for marginal distant gain.
