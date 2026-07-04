# ZenDojo Ishigaki — Step_-native builder rewrite

**Status:** design approved 2026-07-04. Plumbing rewrite of an existing builder; the §3 visual recipe is locked and unchanged.
**Branch:** `m4b-zendojo-art-pass`

## Problem

`buildIshigakiWalls.luau` surveys old cobble-path timber parts (`Timber_` / `ExtTimber_` / `DescTimber_`). The 2026-07-02 ishidan reskin **deleted** those timbers and now emits `Step_<i>` gravel beds as the downstream contract. So the ishigaki builder finds nothing to survey, and the existing published walls no longer match the relaid-out float profile of PathSteps / PathExtension / DescentPath (measured 2026-07-04: PathSteps has 5 unwalled floating gaps; DescentPath barely floats anymore; PathExtension's wall is off).

## Goal

Rewrite `buildIshigakiWalls.luau` **in place** to be `Step_`-native, remove all stale walls for the three paths, and republish spans matched to the current float profile. The locked §3 mesh generator is preserved byte-for-byte.

## Design

**Unchanged:** the entire §3 mesh generator — battered face, dark recessed backing (`COL_JOINT`) + proud coursed stones (`RELIEF 0.22`, `SY 2.0`, `MS 1.15`, mono `96/98/94 ±3`, `INSET 0.12`), Perlin crown/base, `w = vs/Hs` local-height mapping, ragged-stub taper, per-span published `MeshPart` `Wall_<model>_<first>_<last>` (world-space verts, CFrame origin, Rock, CollisionFidelity Box) into `Workspace.RetainingWalls`.

**Replaced — input survey:**
- CONFIG per path is `{ model, edgeSign, hw? }` (same shape as `buildBambooRailing` RUNS). Fixed prefix `Step`. `edgeSign` explicit (PathSteps −1, PathExtension −1, DescentPath +1); no auto-detect.
- Per step, the wall edge line = `bedCenter + horiz(RightVector) * (hw * edgeSign)`, `hw` default **3.2** (bed/riser edge; these paths weren't narrowed), optional per-path override mirroring the railing.
- Reference Y = **bed underside** (`bed.Position.Y − bed.Size.Y/2`); wall **top sits at the bed underside** directly (§3), so the riser + bed edge stay visible above it. `HW_BASE` keeps the +0.5 flare; base embedded `terrain − 0.4`.

**Replaced — span logic:**
- `findSpans(model, edgeSign, hw)`: walk `Step_` beds in index order; per step, downhill float = `bedUnder − terrain(faceXZ)`; contiguous runs with float > `THRESH` (2.5) become spans; pad ±`PAD` (1) so singletons taper to a stub. Sign is fixed per path (no per-step sign break).
- A path with no float > THRESH yields **zero spans** (DescentPath) — correct, not a special case.

**Removal / idempotency:** before building a path, destroy every `Wall_<model>_*` in `RetainingWalls`. `TimberWall_*` (§1a cut-face treatment) and `Wall_NW1012West_*` (out of scope) are untouched. Re-running is safe.

**Terrain reads:** builder only *reads* terrain (no carve), so a single execute call is fine (the "stale same-call" caveat applies only after a terrain write).

## Verification

Separate post-build call re-runs the coverage check: every step floating > 2.5 sits under a wall; no wall covers a non-floating stretch. Reported before user inspection in Studio.

## Rollout

PathSteps first (one attempt), stop for user look; then PathExtension + DescentPath. Place-only — save after approval.

## Expected result

PathSteps ~4 spans (≈0–9, 11–14, 22–29, 38–45) matched to current float; PathExtension one span; DescentPath none.
