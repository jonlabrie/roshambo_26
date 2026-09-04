# Final review fix wave

Applied the 8 findings from the whole-branch code review. One binding constraint held
throughout: no visual change on any device.

## C1 — HammerController.client.luau suspension-loop lag

`updateSuspension()` (the loop at the file's tail) now bypasses the `AmbientBudget.step`
throttle whenever `striking` is true, so the chains/dowels track `arm.CFrame` every
rendered frame during a strike, matching the display-rate TweenService tween that drives
the log. The visibility gate (`machineDrawable`) is unchanged — off-camera, nothing runs
either way. Added a comment explaining why `striking` bypasses the throttle (the tween
runs at display rate; a 30 Hz follower visibly detaches from a log moving up to ~17
studs/s).

## M3 — HammerController.client.luau redundant WaitForChild

Line 12's `AmbientBudget` require now reuses the `shared` local (already bound at line 8)
instead of re-walking `ReplicatedStorage:WaitForChild("RoshamboShared")`, matching
`ShopController.client.luau:27`.

## I1 — arena machinery culled at lantern radius

Added `AmbientConfig.arena()` to `roblox/src/client/AmbientConfig.luau`: returns
`AmbientConfig.get()` with `radius` widened to `math.max(c.radius, ArenaRadius or 450)`.
Safe because `get()` already returns a fresh table per call. `HammerController.client.luau`
(all three heartbeats: draw pose, cam/gear spin, suspension) and
`WheelController.client.luau` now call `AmbientConfig.arena()` instead of
`AmbientConfig.get()`. `ChochinSway.client.luau` and `NorenSway.client.luau` were left
untouched — they keep the lantern radius as instructed.

## I2 — main.server.luau streaming-radius writes

Wrapped the two `workspace.StreamingMinRadius` / `StreamingTargetRadius` property writes
in a `pcall` that `warn()`s (naming `StreamingEnabled` as the likely cause) rather than
letting a throw there kill the whole boot. The attribute publishes
(`SetAttribute("StreamMinRadius"/"StreamTargetRadius")`) stay outside the pcall so they
still reflect what was attempted. The pcall's two locals (`streamOk`, `streamErr`) are
scoped inside a `do...end` block rather than left as new file-scope locals — the file was
already at the Luau compiler's 200-local-register ceiling, and two more file-scope locals
pushed it over (`Compiles.spec` failed with "Out of local registers... exceeded limit 200"
until this was scoped down).

## M1 — AccessGateController.client.luau stale comment

Reworded the collision-snap comment from "solid the instant you're in range" to "solid
within a poll of entering range" — the block above it is throttled (`POLL = 0.25`), so
collision can lag up to 250ms. No behavior change.

## M2 — FlapBoard.luau oversold comment

Rewrote the `BOARD_MAX_DISTANCE` comment: it no longer claims boards "render from anywhere
in the canyon" (that stopped being true one commit earlier when `StreamingTargetRadius`
was capped at 512) and now says explicitly that `MaxDistance` caps draw cost only — the
~8,400 GUI instances still exist and still cost memory, which is what the A13 figure
actually measured. No behavior change.

## M6 — AmbientConfig.luau unclamped attributes

`AmbientRadius` is now clamped to `math.max(0, ...)` and `AmbientBehindDot` to
`math.clamp(..., -1, 1)` in `AmbientConfig.get()`, with a comment explaining these are
hand-typed live during a phone walk and must degrade gracefully rather than blank the
world on a typo. `AmbientHz` was already guarded.

## M5 — AmbientBudget.spec.luau test gaps

Added three tests:
1. `AmbientBudget.inView` custom-config case (mirrors the existing `inRange` custom-config
   case) — until now every `inView` test exercised only the `cfg or DEFAULT` fallback,
   despite all five real callers passing an explicit cfg.
2. A negative-interval `step` case, confirming it lands in the same safe `interval <= 0`
   branch as zero.
3. A 600-iteration loop test at `dt = 1/60` against `interval = 1/30`, asserting the fire
   count is within 1 of 300 — demonstrates (rather than infers) that the throttle doesn't
   drift over hundreds of frames.

## Verification

- `stylua src tests tools && selene src tools` — 0 errors, 0 warnings.
- `lune run tests/run` — 1847 passed, 0 failed (1844 baseline + 3 new M5 tests).
- `rojo build -o /tmp/build.rbxl` — succeeds.
