# B4 gate fix: railing-inset placement bounds + deck-plane drag

## Finding 1 — RAIL_CLEARANCE derivation

Source geometry: `roblox/src/server/PadOps.luau`'s `buildRailing` (lines 134-210), built from
`PadBuilder.luau`'s edge list (front/left/right; back is open — no railing there).

The comment on `PadBuilder.Edge` (PadBuilder.luau:18-19) states the convention explicitly: each
edge carries the OUTER boundary line plus an INWARD unit normal, "so the railing seats its OUTER
face flush to the deck edge (standing flush-outer-edges rule)." `buildRailing`'s `member()`
helper (PadOps.luau:145-153) centers each rail member at `edge line + normal * (width/2)` — i.e.
the member's outer face sits exactly on the deck boundary and its full width extends inward from
there. So the inboard reach of any rail member, measured from the deck's outer edge, equals that
member's full width (not half).

Member widths (PadOps.luau:29-37):
- `CAP_W = 0.45` (charcoal cap rail)
- `MID_W = 0.15` (mid rail)
- `NEWEL_W = 0.45` (corner posts, side edges only)
- `BAL_W = 0.15` (balusters)
- `BARRIER_T = 0.3` (invisible collidable fall-guard, `Transparency = 1`)

The deepest any VISIBLE railing part reaches inboard is **0.45 studs** (cap rail / newel, tied).
This is unambiguous — the flush-outer-edge convention and the exact widths are both explicit in
the source, not inferred.

`RAIL_CLEARANCE = 0.45 (deepest visible rail inset) + 0.5 (visual clearance) = 0.95, rounded to
one decimal = 1.0`.

Implemented as `SizeClasses.RAIL_CLEARANCE = 1.0` in `roblox/src/shared/SizeClasses.luau:59`
(comment block at 48-58 walks through the derivation for future readers), with
`SizeClasses.placementBounds(deckSize)` (lines 59-63) returning `deckFootprint(deckSize)` inset
by `RAIL_CLEARANCE` on all four sides.

Note: the invisible fall-guard barrier (`BARRIER_T = 0.3`, collidable) reaches less far inboard
than the cap rail/newel, so the 1.0 clearance also clears it with margin (1.0 - 0.3 = 0.7 studs
to spare) — no separate check needed.

## Change sites

1. **`roblox/src/shared/SizeClasses.luau`** (lines 48-63, new) — added `RAIL_CLEARANCE` constant
   and `placementBounds(deckSize)` function, exactly per the requested contract. `deckFootprint`
   itself is untouched (still describes the physical deck slab).

2. **`roblox/src/server/main.server.luau`** (line 876) — `SetPlacement` handler's
   `BuildingPlacer.clamp(...)` now receives `SizeClasses.placementBounds(built.deckSize)` instead
   of `SizeClasses.deckFootprint(built.deckSize)`.

3. **`roblox/src/server/TreatmentApplier.luau`** (lines 79-88) — `_buildBuilding`'s `deckFP` is
   now `self._sizeClasses.placementBounds(deckSize)`, used by both the `clamp` call and the
   `fits` guard directly below it. Added a comment explaining why (railings occupy the deck
   perimeter) and updated the `Deps` type comment (line 19) to mention `placementBounds`.

4. **`roblox/src/client/MoveController.client.luau`** (line 235, in `enter()`) — `deckFP =
   SizeClasses.placementBounds(deckSize)` instead of `deckFootprint`.

Not touched: `PadBuilder.luau:37` (`SizeClasses.deckFootprint(deckSize)` — this builds the actual
physical deck slab/beams/railings and must stay keyed to the true deck extent, not the
placement-clamped inset).

## TDD evidence (Finding 1)

RED (before implementation), added to `roblox/tests/SizeClasses.spec.luau`:
```
FAIL  SizeClasses.placementBounds > insets deckFootprint by RAIL_CLEARANCE on all four sides
      attempt to call a nil value
FAIL  SizeClasses.placementBounds > M and L also inset by RAIL_CLEARANCE ...
      attempt to call a nil value
FAIL  SizeClasses.placementBounds > every authored building still fits centered ...
      attempt to call a nil value
427 passed, 3 failed, 430 total
```

GREEN (after implementing `RAIL_CLEARANCE` + `placementBounds`):
```
430 passed, 0 failed, 430 total
```

Three new tests added:
- `placementBounds("S")` equals `deckFootprint("S")` inset by `RAIL_CLEARANCE` on all four sides.
- Same inset property holds for M and L (bounds scale with `deckFootprint`, not hardcoded per
  size).
- Sanity: every authored building (S/M/L) still fits centered (`offset={0,0}`, `facing="N"`) in
  its own size's `placementBounds`, using `BuildingPlacer.fits` (required in the spec file per
  the `BuildingPlacer.spec.luau` convention). Margins are generous at every size (smallest margin
  ~3.2 studs on the L deck's Z axis), so this assertion is robust even if `RAIL_CLEARANCE` were
  later retuned within a reasonable range.

## Finding 2 — deck-plane drag

`roblox/src/client/MoveController.client.luau`:
- `stepDrag` (lines 95-117) no longer builds `RaycastParams`/calls `workspace:Raycast` against
  the site folder. It now intersects the camera's aim ray against the deck's own plane, defined
  by `mountCF.Position` (a point on the plane) and `mountCF.UpVector` (the plane normal):
  `t = (planePoint - ray.Origin):Dot(normal) / ray.Direction:Dot(normal)`, guarding both a
  near-parallel ray (`|denom| < 1e-4`) and a plane-behind-camera case (`t <= 0`) by holding the
  last position (returning early, ghost unchanged).
- The `folder` parameter was removed from `stepDrag` (now zero-arg) since the geometry filter
  that needed it is gone. The call site (`enter()`, was lines 250-255, now line 249) simplified
  from a wrapping closure to `RunService.RenderStepped:Connect(stepDrag)` — matching the existing
  codebase pattern of connecting a bare zero-arg handler directly (see
  `HammerController.client.luau:333`, `RunService.Heartbeat:Connect(updateSuspension)`). `folder`
  itself is still used earlier in `enter()` for `structure`/`MountCF`/`DeckSize`/`TeahouseSize`
  attribute reads, so it stays a local.
- Header comment (lines 8-13) now documents that dragging is a deck-plane math intersection, not
  a geometry raycast, and explicitly calls out the resulting "aim past the corner to park in the
  corner" behavior (an out-of-bounds plane point gets pulled in-bounds by
  `BuildingPlacer.clamp` inside `applyGhost`).
- `makeGhost`'s comment (line 63) was updated since it previously justified `g.Parent = workspace`
  by referencing "the drag raycast" — that raycast no longer exists, so the comment now just
  notes the ghost is kept independent of the site folder's own lifecycle.

This file is a Roblox-runtime client script (`.client.luau`, uses `game:GetService`, `workspace`,
`CFrame`, etc. at module scope) and is not `require`d by the Lune test harness (consistent with
how the codebase already treats Roblox-datatype files as "not Lune-testable" — see
`TreatmentApplier.luau`'s and `PadOps.luau`'s header comments for the same convention). No Lune
test exists or was added for it; it will need visual verification in Studio play mode (dragging
the ghost toward/past a deck corner and confirming it parks flush in the corner rather than
holding at the last raycast hit).

## Full verification

```
$ cd roblox && lune run tests/run
430 passed, 0 failed, 430 total

$ stylua --check src tests
(clean, exit 0)

$ selene src
Results:
0 errors
0 warnings
0 parse errors
```

## Files changed

- `roblox/src/shared/SizeClasses.luau` — `RAIL_CLEARANCE` + `placementBounds`
- `roblox/tests/SizeClasses.spec.luau` — new `placementBounds` describe block (3 tests)
- `roblox/src/server/main.server.luau` — `SetPlacement` handler uses `placementBounds`
- `roblox/src/server/TreatmentApplier.luau` — `_buildBuilding`'s `deckFP` uses `placementBounds`
- `roblox/src/client/MoveController.client.luau` — `placementBounds` for `deckFP`; `stepDrag`
  rewritten as deck-plane intersection; header/inline comments updated

## Concerns / gate-tunable notes

- `RAIL_CLEARANCE = 1.0` was derived, not defaulted to the 1.5 fallback — the geometry was
  unambiguous (explicit flush-outer-edge convention + explicit member widths in PadOps.luau). If
  a future rail restyle changes `CAP_W`/`NEWEL_W`, this constant should be revisited.
- Finding 2's fix has no automated test (the file is Roblox-runtime-only, matching existing
  convention for this codebase's client controllers); it needs a Studio play-mode check per the
  "stop and ask after each attempt" house rule before considering it visually confirmed.
