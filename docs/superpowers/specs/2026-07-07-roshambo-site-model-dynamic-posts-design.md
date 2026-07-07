# Roshambo Site Model + Dynamic Posts — Design (sub-project D, increment 4)

**Status:** design approved in brainstorm (2026-07-07); pre-planning. Roblox-side; pure modules Lune-tested, Studio applier proven by a real-perch visual gate. Renumbers the rest of D: **preference → D.5**, **migration sweep → D.6**.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** D.2/D.3 model a pad as a **fixed footprint**: support posts are built once at startup from that footprint, and fit-matching is rect-containment (`PadRegistry.fits`/`claimVacantFor`). A terrain survey of the 14 real canyon perches (2026-07-07) showed that model is wrong for the real geometry — perches are cliff shelves set *into* the hillside, so a fixed footprint either overhangs (overhang bug the D.3 review flagged) or the posts fight the terrain. This increment replaces it with a **site model** (each site carries a surveyed max-size) + **dynamic posts** (support built to the *materialized* structure, per occupant, skipping corners embedded in the slope). This dissolves the overhang problem and the need for best-fit.

## Problem

The survey (Deck-anchored raycasts, classifying each footprint corner as **normal** = terrain below the deck datum, **embed** = terrain above it, **void** = none) found:

- **Zero void corners** at any perch, at any size — support is never the blocker; perches are set into the hill, not cantilevered over the gorge.
- Size is capped only by **uphill clipping** (corners running into rising terrain). Current buildable spread (no terrain edits): **3 L / 4 M / 7 S**; all 14 are *clearable* to L by cutting back a few corners (a later Far Wall task).

So a site's real capacity is a **max size class**, not a footprint, and support must be built **to whatever structure lands there**, building a post only where terrain sits below the deck and resting the deck into the slope where it doesn't. The fixed-footprint pad and its `fits()` matching no longer fit reality.

## Goals

- A **site** = `{ id, mountCF (Deck-anchored: pos = deck underside datum, rot = deck rotation), maxSize }`. Fit-matching becomes an **ordinal size-cap**: materialize `min(largest owned size, site.maxSize)`, biggest-first.
- **Dynamic posts:** at claim time, for the chosen size's footprint, raycast each post position **from above the deck** and build a stilt only where terrain is **below** the datum (normal); skip corners where terrain is at/above it (embed) or absent (void). Support rebuilds with the structure on every transition.
- Prove it on **real perches** (which have embeds; the synthetic `cliff-proof` shelf does not) via a two/three-site visual gate.

## Non-goals (later D increments)

- **Perch preference** (persisted ranking + thumbs UI) — **D.5**. Biggest-first is the hook it will layer on.
- **The full 14-perch migration** (survey + register + retire *all* legacy teahouses) — **D.6**. This increment uses 3 real perches for the gate; legacy teahouses are temporarily archived, not permanently retired.
- **Terrain clearing** to lift M/L counts — a manual Far Wall task; this increment consumes the *current* surveyed max per site.
- **Per-site handedness** (left-hand engawa wrap) — sites stay right-hand (the prefab default); facing is handled by the Deck-anchored rotation. A migration cosmetic.
- **Best-fit / site-allocation fairness** (an M-owner taking an L-site) — the ephemeral pool stays first-fit; preference (D.5) refines it.

## Architecture

Same pure-brain / Studio-applier split. Three coordinated changes:

### 1. Size-cap matching (pure)

`SizeClasses` gains a rank (`S=1, M=2, L=3`) and `fitsWithin(size, maxSize) = rank[size] <= rank[maxSize]`. `SiteCoordinator:onJoin` becomes, biggest-first:

```
for size in SizeClasses.order do           -- L, M, S
    if ownedTeahouses[size] then
        for _, id in self._padIds do        -- registration order (first-fit)
            local rec = self._registry:get(id)
            if rec.occupant == nil and SizeClasses.fitsWithin(size, rec.spec.maxSize) then
                self._registry:claim(id, playerId)
                return Action{ padId=id, spec=rec.spec, treatment=lit(loadout),
                               scale=SizeClasses.scale[size], sizeClass=size,
                               footprint=SizeClasses.footprintFor(size) }
            end
        end
    end
end
return nil
```

This uses only `registry:get`/`:claim` (both exist) — `PadRegistry.claimVacantFor`/`fits`/`claimVacant` become dead (harmless, like `claimVacant` did in D.3). `vacantActions`/`onLeave` resolve the dormant size to the site's `maxSize` (a vacant L-site shows a dormant L shell): `scale`/`footprint`/`sizeClass` from `site.maxSize`.

The `Action` gains **`footprint`** (the chosen size's footprint) so the Studio applier can build posts without requiring `SizeClasses`. Full `Action = { padId, spec, treatment, scale, sizeClass, footprint }`.

### 2. Dynamic posts (support built to the structure)

- **`PadOps.raycastGround`** now rays **from high above the deck** (`mountCF.Y + 250`, down `250 + MAXPOST + buffer`) and returns the terrain Y (which may be **above or below** the datum), or `nil`. (Was: from `mountCF.Y + 4` down — blind to uphill terrain.)
- **`PadPlanner.planSupport`** classifies each corner against the datum plane (the post-top Y): build a post iff `groundY ~= nil and groundY < topY and (topY - groundY) <= MAXPOST` (**normal**); otherwise **skip** (embed = groundY ≥ topY, or void = nil/too-deep). Returns `{ posts, skipped }`. `MAXPOST = 80`.
- Support is built **per occupant** from the materialized size's footprint (`Action.footprint`), not once at startup from a pad footprint.

### 3. Applier rebuilds support + structure together (Studio)

`TreatmentApplier:apply(padId, spec, treatment, scale, footprint)` (drop the separate `buildSupport`): transactionally rebuild the site's contents for the new occupant —
1. build the structure via `StructureBuilder` (pcall, F4), `ScaleTo(scale)`, shutter if dormant;
2. on success, destroy the site folder's old `Structure` **and** old `PadPost`s, then build the new posts via `PadBuilder.build({ mountCF, footprint }, PadOps.new(mountCF, folder))` (dynamic classification) and parent the new structure.

Startup no longer pre-builds support; each site is materialized (dormant) once at startup via `apply`, which builds its dormant-size posts + shell.

## Data flow / gate

```
sites (Deck-anchored, surveyed max): T02 max=L, T06 max=M, T04 max=S   (register T02 first)
seed local player: { S, M, L }  (vermilion)
startup:  each site -> dormant at its maxSize, dynamic posts (embed corners skipped)
join:     biggest-first -> L owned, T02 max=L -> claim T02, materialize L, lit, posts only at normal corners
result:   T02 = lit L teahouse flush on the cliff, stilts only where terrain drops away, no post where it beds into the slope
```

Legacy teahouses at T02/T06/T04 are **temporarily archived** to `ServerStorage` (reversible) so the materialized ones stand in their place.

## Testing

- **Lune — `SizeClasses.spec`**: `rank` values; `fitsWithin` (S fits M/L site, L doesn't fit an M site, size fits its own).
- **Lune — `PadPlanner.spec` additions**: `planSupport` builds a post for a below-datum corner, **skips an above-datum (embed)** corner, skips a `nil` (void) corner, and skips a too-deep corner (> `MAXPOST`); post length/position for normal corners unchanged from the existing tests.
- **Lune — `SiteCoordinator.spec` rewrite**: biggest-first size-cap (owns {S,M,L}, sites {maxL, maxM, maxS} → claims the L site at L); fallback (a player owning only {L} with only an M-site vacant → **nil**, since L exceeds the M-site's cap and no smaller size is owned; a player owning {L,M} in the same situation → claims the M-site at **M**); `vacantActions`/`onLeave` carry the site's `maxSize` scale/footprint; wanderer/double-join guards intact. Existing D.3 footprint-fit tests replaced by size-cap tests.
- **Visual gate (real perches, ONE attempt then stop):** T02 materializes a **lit L** teahouse flush to the cliff with posts only at normal corners (embed corners post-free, deck bedded into the slope); T06/T04 show dormant M/S. Server-side check verifies post count = normal-corner count and no floating/overhang. Console shows the claimed size. Fallback/dormant are Lune-covered.

## v1 deliverables

1. `SizeClasses.luau` — `rank` + `fitsWithin` (+ spec).
2. `PadOps.luau` — high-origin `raycastGround` returning above/below-datum terrain Y.
3. `PadPlanner.luau` — embed/void classification in `planSupport` (+ spec).
4. `SiteCoordinator.luau` — biggest-first size-cap `onJoin`; `Action.footprint`; dormant = site `maxSize` (+ spec rewrite).
5. `TreatmentApplier.luau` — merge support into `apply`; dynamic posts + structure rebuilt together.
6. `PadSites.luau` — 3 real Deck-anchored perch sites (T02/T06/T04) with surveyed `maxSize` (mountCFs captured via MCP during the build).
7. `main.server.luau` — register the 3 sites (T02 first), startup dormant, join/leave with `footprint` threaded.

## Build order

TDD `SizeClasses.rank`/`fitsWithin` → TDD `PadPlanner` embed/void classification + update `PadOps` high-ray (Studio) → rewrite `SiteCoordinator:onJoin` to size-cap biggest-first (+ `Action.footprint`, dormant=maxSize) → merge dynamic support into `TreatmentApplier:apply` (Studio) → MCP-capture the 3 Deck-anchored site specs + bake `PadSites` → wire `main.server` + archive the 3 legacy perches + seed {S,M,L} → real-perch visual gate → stop for user review.
