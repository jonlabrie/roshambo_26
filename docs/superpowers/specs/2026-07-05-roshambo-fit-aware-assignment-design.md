# Roshambo Fit-Aware Pad Assignment — Design

**Status:** design approved in brainstorm (2026-07-05); pre-planning. A small B increment extending `PadRegistry`. Pure, Lune-tested.
**Branch:** `m4b-zendojo-art-pass`
**Relation to prior work:** extends the [`PadRegistry`](2026-07-05-roshambo-pad-registry-design.md) (B increment 2) with footprint-fit, so a structure only lands on a pad big enough. Uses the footprint rectangle from the [pad system](2026-07-05-roshambo-pad-system-design.md) (B.1) and A's structure footprint. Sub-project D calls `claimVacantFor` at spawn.

## Problem

`PadRegistry:claimVacant` claims *any* vacant pad. But pads and structures have footprints, and a larger structure (a future multi-story tier) must not be assigned to a pad whose support footprint is too small — it would overhang unsupported. Assignment needs to be **fit-aware**.

## Goals

- A pure containment check `fits(padFootprint, structFootprint)`.
- A `claimVacantFor(owner, structFootprint)` that claims the first vacant pad that fits — the spawn op D calls when it knows the player's structure size.
- Lune-tested; no Studio; the existing `PadRegistry` API is unchanged.

## Non-goals

- Assignment policies beyond first-fitting-in-registration-order (nearest-to-spawn, tier gating).
- Changing `claimVacant`/`claim`/`release`/`get`/`findVacant` (unchanged; `claimVacant` stays for callers that don't need fit).
- Any footprint source wiring (D passes the structure footprint; pads carry theirs in `spec.footprint`).

## Architecture

Both additions live in `roblox/src/shared/PadRegistry.luau`. Footprint = the mount-relative rectangle `{ minX, maxX, minZ, maxZ }` (pad = support *capacity*; structure = actual frame). Both share the datum origin, so fit is **containment**.

### `PadRegistry.fits` (pure module function)

```
PadRegistry.fits(padFootprint, structFootprint) -> boolean
  = structFootprint.minX >= padFootprint.minX and structFootprint.maxX <= padFootprint.maxX
      and structFootprint.minZ >= padFootprint.minZ and structFootprint.maxZ <= padFootprint.maxZ
```

A structure fits when its rectangle is contained in the pad's; any overhang (e.g. `structFootprint.maxX > padFootprint.maxX`) → `false`.

### `Registry:claimVacantFor` (method)

```
Registry:claimVacantFor(owner: string, structFootprint) -> { id: string, spec: any }?
```

Iterates the registry's insertion-ordered id list; for the first pad that is **vacant** *and* whose `spec.footprint` **fits** `structFootprint`, sets `occupant = owner` and returns `{ id, spec }`. Returns `nil` if no vacant pad fits. A pad whose `spec.footprint` is `nil` is **skipped** (fit unverifiable → don't assign). Deterministic (registration order), like `claimVacant`.

## Testing

Lune unit tests (in `PadRegistry.spec.luau`):
- **`fits`** — contained → `true`; exact-match → `true`; wider (`structFP.maxX` beyond pad) → `false`; deeper (`structFP.maxZ` beyond) → `false`; under-min (`structFP.minX < padFP.minX`) → `false`.
- **`claimVacantFor`** — registers pads with different footprints; skips a too-small vacant pad and claims the next fitting one (asserting the returned `id`); marks it claimed (`get(id).occupant`); returns `{id, spec}`; `nil` when none fit; skips a pad whose `spec.footprint` is `nil`; does not disturb `claimVacant`'s behavior on the untouched pads.

## v1 deliverables

1. `PadRegistry.fits` + `Registry:claimVacantFor` added to `roblox/src/shared/PadRegistry.luau`.
2. New tests appended to `roblox/tests/PadRegistry.spec.luau`.

## Build order

TDD `fits` (containment truth table) → TDD `claimVacantFor` (skip-too-small, claim-fitting, none-fit, nil-footprint-skip) → commit. Single task.
