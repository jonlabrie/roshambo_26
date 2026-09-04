# Task 4 Report — WheelController: keep the integration, cull the writes

## Status: DONE

## Commit
- `e5fe6be` — perf(client): waterwheel keeps turning, only draws when it is on screen

## What changed
`roblox/src/client/WheelController.client.luau`:
- Added the two shared requires per the owner's correction (not local `num`/`cfg` helpers):
  - `AmbientBudget = require(ReplicatedStorage.RoshamboShared.AmbientBudget)`
  - `AmbientConfig = require(script.Parent.AmbientConfig)`
- Added a `drawable(c: AmbientBudget.Config): boolean` helper anchored on `spins[1].hub.Position`
  (distance-squared range test via `AmbientBudget.inRange`, then `math.sqrt` only for survivors,
  then `AmbientBudget.inView` on the forward dot) — same camera-math shape as
  `ChochinSway`/`NorenSway`.
- In the `Heartbeat` handler:
  - `AmbientConfig.get()` is called exactly once per frame, assigned to a local `c`.
  - `angle += dt * driveOmega * wheelDir` still runs unconditionally, every frame, culled or not.
  - The hub/paddle `CFrame` writes are now gated on `fire and visible` (throttled by
    `AmbientBudget.step` AND only when in range/view).
  - The paddle-strike boundary block still runs every frame and `lastStrike[side]` is still
    unconditionally updated; only the `b:Emit(3)` splash call is additionally gated on `visible`.

No other logic changed. Rate, direction, paddle offsets, and splash timing are identical when the
wheel is visible.

## Gates run (from `roblox/`)
- `stylua src tests tools` — clean
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors
- `lune run tests/run` — **1844 passed, 0 failed, 1844 total** (the `[WARN]` lines are expected
  output from `HandlerQueue.spec`, not failures)
- `rojo build -o /tmp/build.rbxl` — succeeded

## Concerns
None. The three integration rules from the brief (angle always advances; strike bookkeeping always
runs and only `Emit` is gated; only CFrame writes are gated) are implemented exactly as specified.
Did not touch how `DriveOmega`/`WheelDir` attributes are read, per instruction (next task adjusts
the publishing side).
