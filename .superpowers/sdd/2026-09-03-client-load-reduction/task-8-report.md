# Task 8 Report: Stats-room MaxDistance

## Status
DONE

## Changes
- Added `BOARD_MAX_DISTANCE = 150` constant with full comment documenting the measurement and rationale
- Set `gui.MaxDistance = BOARD_MAX_DISTANCE` in `buildFace()` immediately after `gui.CanvasSize` assignment
- File modified: `roblox/src/client/FlapBoard.luau`

## Verification
- **stylua**: 0 errors, 0 warnings, 0 parse errors
- **selene**: No warnings
- **Tests**: 1844 passed, 0 failed
- **rojo build**: Successful to `/tmp/build.rbxl`

## Commit
`1e55c9c` — perf(client): stats-room boards stop rendering from outside the room

## Notes
- No visual changes at reading distance (MaxDistance is a rendering optimization only)
- FlapBoard's only caller (StatsController) returns early for round display, so this reaches wall boards only
- Step 2 (Studio walk-through) skipped as noted in requirements — not possible in this environment
