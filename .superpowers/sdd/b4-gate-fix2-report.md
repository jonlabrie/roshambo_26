# B4 gate fix #2: un-fitting facings unrotatable/rejected, render falls back to N

Commit: `d59df04` — `fix(roblox): un-fitting facings are unrotatable/rejected; render falls back to N (B4 gate)`

## Root cause recap

An L teahouse rotated to face E/W needs 24.4 studs across the L deck's
`placementBounds` depth of only 23.30 (`SizeClasses.RAIL_CLEARANCE = 1.0` inset
on the L deck's Z extent). `BuildingPlacer.clamp`'s degenerate-axis branch
centers the placement regardless of overflow; `SetPlacement`'s handler
persisted that centered-but-overflowing placement with no fits-guard; and
`TreatmentApplier._buildBuilding`'s post-clamp `fits()` check then failed,
silently skipping the building (deck-only render). Deterministic for L-on-L at
facing E/W (the only size/facing combination where this happens — verified by
the new matrix test below).

## Change 1 — pure predicate + Lune TDD

**`roblox/src/shared/BuildingPlacer.luau:72-84`** — added
`BuildingPlacer.canFitFacing(buildingFP, boundsFP, facing): boolean`, placed
directly after `clamp` (was `roblox/src/shared/BuildingPlacer.luau:50-70`),
before `return BuildingPlacer`. Computes the facing-rotated half-extents (same
swap-on-90/270 logic as `fits`/`clamp`) and checks whether the full extents fit
within the bounds' dimensions at *any* offset — i.e. whether `clamp`'s
degenerate-axis branch would ever have to fire for this facing.

### TDD evidence (RED -> GREEN)

1. Added the new tests first (implementation not yet written):
   - `roblox/tests/BuildingPlacer.spec.luau:87-101` — new `describe("BuildingPlacer.canFitFacing", ...)` block, two tests.
   - `roblox/tests/SizeClasses.spec.luau:190-204` — extended the existing "every authored building still fits centered..." test with a nested facing loop.
2. RED run (`lune run tests/run`): `429 passed, 3 failed, 432 total` — all 3 failures `attempt to call a nil value` (canFitFacing undefined), at `BuildingPlacer.spec:92`, `BuildingPlacer.spec:98`, `SizeClasses.spec:200`.
3. Implemented `canFitFacing` in `BuildingPlacer.luau`.
4. GREEN run: `432 passed, 0 failed, 432 total`.

### L-on-L four-facing test matrix

`roblox/tests/SizeClasses.spec.luau`'s extended test iterates all 3 sizes x 4
facings against each size's own same-size `placementBounds`. Verified by hand
against the module constants (`BUILDING_HALF` in `SizeClasses.luau:135`,
`placementBounds` in `SizeClasses.luau:59-63`):

| size | bounds half (X, Z) | building half (X, Z) | N/S (no swap) | E/W (swap) |
|---|---|---|---|---|
| S | (12.00, 9.00) | (6.2, 3.2) | fits (12.4<=24, 6.4<=18) | fits (6.4<=24, 12.4<=18) |
| M | (13.822, 10.402) | (9.2, 6.2) | fits (18.4<=27.64, 12.4<=20.80) | fits (12.4<=27.64, 18.4<=20.80) |
| L | (15.444, 11.649) | (12.2, 9.2) | fits (24.4<=30.89, 18.4<=23.30) | **does not fit** (18.4<=30.89 ok, but 24.4<=23.30 fails) |

Result: **L/E and L/W are false; every other size x facing combination is
true.** This matches the finding exactly (24.4 needed vs 23.30 available on
the L deck's Z bounds) and is asserted directly in the test (expected =
`not (s == "L" and (facing == "E" or facing == "W"))`).

## Change 2 — client rotate skips un-fitting facings

**`roblox/src/client/MoveController.client.luau:95-112`** — extracted a single
`local function rotate()`, replacing two duplicated inline rotate blocks:
- HUD `⟳ Rotate (R)` button handler (previously `roblox/src/client/MoveController.client.luau:203-207`, now just `makeButton(1, "⟳ Rotate (R)", rotate)` at line 219).
- The `R` key `InputBegan` branch (previously `roblox/src/client/MoveController.client.luau:256-259`, now `rotate()` at line 271).

`rotate()` walks `FACING_ORDER` from the current facing's index, advancing
(wrapping) through the *other* three facings in order, calling
`BuildingPlacer.canFitFacing(buildingFP, deckFP, candidate)` for each; the
first fitting candidate becomes the new facing and `applyGhost()` runs. If
none of the other three fit, it is a no-op (stays on the current facing) —
this only happens for an L teahouse currently facing N or S (its only two
fitting facings), so rotating from there simply refuses to advance into E/W.

## Change 3 — server rejects un-fitting facings

**`roblox/src/server/main.server.luau:872-879`** (inside the `SetPlacement`
handler, after `built`/`size` are resolved) — hoisted `buildingFP`/`boundsFP`
into locals and added the gate before the existing `clamp` call:

```lua
local size = built.teahouseSize
local buildingFP = SizeClasses.buildingFootprint(size)
local boundsFP = SizeClasses.placementBounds(built.deckSize)
if not BuildingPlacer.canFitFacing(buildingFP, boundsFP, facing) then
    return -- this facing cannot fit this built combination (UI never offers it)
end
-- server-authoritative: clamp the request against the BUILT combination and persist the
-- clamped value (never raw client numbers)
local clamped = BuildingPlacer.clamp(buildingFP, boundsFP, { offset = { dx, dz }, facing = facing })
```

The footprint locals are computed once and reused by both `canFitFacing` and
`clamp` (no duplicate `SizeClasses.buildingFootprint`/`placementBounds`
calls). The gate runs before `clamp`, so the degenerate-axis path is never
reached for a rejected facing — a client that somehow requests L/E or L/W
(bypassed UI, replayed request, stale client) gets silently ignored rather
than persisted.

## Change 4 — render fallback instead of vanish

**`roblox/src/server/TreatmentApplier.luau:89-104`** (`_buildBuilding`) — on
the post-clamp `fits()` failure, retries once at facing `"N"` with the same
stored offset before giving up:

```lua
local placement = self._buildingPlacer.clamp(buildingFP, deckFP, teahouse.placement)
if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
    -- a persisted facing can stop fitting when the deck display shrinks (e.g. an L teahouse
    -- facing E/W on its own L deck, post-shrink); teahouse <= deck guarantees the N facing
    -- always fits, so fall back to it once (same offset, re-clamped) rather than vanishing
    -- the building. Only if even THAT fails (pathological data) do we skip to deck-only.
    placement = self._buildingPlacer.clamp(
        buildingFP,
        deckFP,
        { offset = teahouse.placement.offset, facing = "N" }
    )
    if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
        warn(`[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`)
        return
    end
end
```

This module has no Lune coverage (documented at the top of the file: "Roblox
datatypes -> not Lune-testable; proven by the visual gate"), so this change is
code-only, consistent with the existing convention for this file.

Why the fallback always succeeds for legitimate data: for facing N, the
building's *native* (unrotated) half-extents are checked against the bounds
without an X/Z swap, and `SizeClasses.buildingFootprint` values are authored
so that `halfX*2 <= boundsWidth` and `halfZ*2 <= boundsDepth` for every
same-size building/deck pair (asserted by both the pre-existing "every
authored building still fits centered..." assertion and the new
`canFitFacing` matrix above, which shows N/S is `true` for all three sizes).
Since `clamp`'s degenerate branch only fires when the half-extent exceeds the
available span, N never hits it, so `fits()` is guaranteed true after the
retry for any in-catalog building/deck combination — only truly pathological
(out-of-catalog) data would still fail, and that keeps the original warn+skip.

## Verification

```
$ cd roblox && lune run tests/run
432 passed, 0 failed, 432 total

$ stylua --check src tests
(clean, exit 0)

$ selene src
Results:
0 errors
0 warnings
0 parse errors
```

## Files touched

- `roblox/src/shared/BuildingPlacer.luau` (new `canFitFacing`, +14 lines)
- `roblox/src/client/MoveController.client.luau` (rotate() extraction + 2 call sites)
- `roblox/src/server/main.server.luau` (SetPlacement handler gate)
- `roblox/src/server/TreatmentApplier.luau` (_buildBuilding N-facing fallback)
- `roblox/tests/BuildingPlacer.spec.luau` (canFitFacing TDD tests)
- `roblox/tests/SizeClasses.spec.luau` (extended matrix test)

Commit: `d59df04` "fix(roblox): un-fitting facings are unrotatable/rejected; render falls back to N (B4 gate)" (one commit, all six files, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` in the body).
