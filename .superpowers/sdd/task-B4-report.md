# Task 1: PadRegistry Fit-Aware Assignment — Report

## Status
**COMPLETED** — All tests passing; implementation complete and committed.

## Commit
- **SHA:** `810fb1f`
- **Subject:** `feat(roblox): PadRegistry — fit-aware assignment (fits + claimVacantFor)`

## Test Summary
- **Baseline:** 278 passing
- **New tests:** 4 appended and passing
  - `fits: contained/exact -> true; overhang -> false`
  - `claimVacantFor: skips a too-small vacant pad, claims the first fitting one`
  - `claimVacantFor: nil when none fit`
  - `claimVacantFor: skips a pad whose spec has no footprint`
- **Final result:** 282 passing, 0 failed (100% green)

## Implementation Details

### Added to `roblox/src/shared/PadRegistry.luau`

1. **Footprint type export:**
   ```lua
   export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }
   ```

2. **Pure module function `PadRegistry.fits(padFootprint, structFootprint)`:**
   - Returns `true` if `structFootprint` is fully contained within `padFootprint`
   - Checks all four dimensions: minX, maxX, minZ, maxZ
   - Used by `claimVacantFor` to filter candidate pads

3. **Method `Registry:claimVacantFor(owner, structFootprint)`:**
   - Iterates through pads in registration order
   - Skips occupied pads
   - Skips pads with no footprint in spec
   - Skips pads whose footprint does not fit the structure
   - Claims and returns the first fitting vacant pad
   - Returns `nil` if no pad fits

### Changes to tests `roblox/tests/PadRegistry.spec.luau`

Appended 4 new tests:
- Comprehensive truth-table test for `fits` function (contained, exact, and 3 overhang cases)
- Two-pad scenario testing skip-then-claim behavior
- Nil-when-none-fit edge case
- Nil-footprint skip behavior

## Concerns
None. Implementation follows the brief exactly:
- Uses only the provided code
- Maintains all existing method signatures (no breaking changes)
- Follows TDD pattern: failing tests first, then implementation
- Full test suite passes
- Type annotations complete and consistent
