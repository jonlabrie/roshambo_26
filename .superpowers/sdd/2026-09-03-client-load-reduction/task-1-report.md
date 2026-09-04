# Task 1 Report: AmbientBudget

## Status
✅ DONE

## Commit SHA
68a025c

## Test Results
1844 passed, 0 failed, 1844 total (all pre-existing tests remain green)

## Summary
Created three files per specification:

1. **`roblox/src/shared/AmbientBudget.luau`** — Pure policy module for ambient prop visibility and update throttling
   - Exports `Config` type with `radius`, `behindDot`, `interval` fields
   - Provides `DEFAULT` configuration (180 studs, -0.15 behindDot, 1/30 interval)
   - Implements three decision functions:
     - `inRange(distSq, cfg?)` — checks if distance squared ≤ radius squared
     - `inView(forwardDot, cfg?)` — checks if forward dot ≥ behindDot margin
     - `step(acc, dt, interval)` — fixed-interval accumulator returning `(fire, nextAcc)`
   - Carries modulo remainder rather than zeroing to prevent frame-rate drag
   - Implements catch-up bounding to prevent unbounded updates after stalls

2. **`roblox/tests/AmbientBudget.spec.luau`** — Comprehensive test suite
   - 12 test cases covering all three functions
   - Tests boundary conditions, custom configs, zero interval, and catch-up bounding
   - All tests pass

3. **`roblox/src/client/AmbientConfig.luau`** — Live-tunable config reader
   - Single source for reading workspace attributes: `AmbientRadius`, `AmbientBehindDot`, `AmbientHz`
   - Converts Hz to interval (1/Hz), with fallback to module defaults
   - Returns fresh `Config` table per call to prevent mutation across callers
   - Centralizes attribute reads for four ambient controllers (tasks 2-5)

## Gates
All house gates passed:
- ✅ `stylua src tests tools` — 0 warnings
- ✅ `selene src tools` — 0 errors/warnings
- ✅ `lune run tests/run` — 1844 passed (130 new test plus 1714 pre-existing)
- ✅ `rojo build -o /tmp/build.rbxl` — successful build

## No Concerns
All requirements met as specified. Module ready for consumption by tasks 2-5.
