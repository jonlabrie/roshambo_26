# Task 1 Report: scheme.dormant catalog entry

## Summary

Task 1 completed successfully. Added `scheme.dormant` recolor entry to StructureCatalog with a dark per-role palette for vacant pads.

## Implementation

### Changes Made

1. **`roblox/tests/StructureCatalog.spec.luau`**: Appended failing test validating the dormant scheme entry with expected color payload (timber, wall, roof, cap).

2. **`roblox/src/shared/StructureCatalog.luau`**: Added entry to ENTRIES table:
   ```lua
   ["scheme.dormant"] = {
       id = "scheme.dormant", type = "recolor", slot = "colorScheme",
       payload = { timber = { 48, 46, 44 }, wall = { 70, 68, 64 }, roof = { 36, 37, 40 }, cap = { 40, 42, 46 } },
   },
   ```

### Test Results

- **Baseline**: 273 passing tests
- **After test append**: 1 failed (expected)
- **After entry addition**: 274 passed, 0 failed ✓
- **Test coverage**: New test validates recolor type, colorScheme slot, and all four color values (timber, wall, roof, cap)

## TDD Process Followed

1. ✓ Appended failing test to spec
2. ✓ Verified test failure (nil return)
3. ✓ Added catalog entry with exact payload
4. ✓ Verified all tests pass (274 total)
5. ✓ Committed with proper message

## Concerns

None. Implementation strictly follows brief with TDD discipline. Entry is positioned alongside other `scheme.*` entries in catalog. No Roblox datatypes or randomness introduced.

## Commit

- **SHA**: `3d3d8e7`
- **Message**: `feat(roblox): StructureCatalog — scheme.dormant (vacant-pad dark shell)`
