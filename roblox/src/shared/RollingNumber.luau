--!strict
-- Every wallet figure the HUD shows (points, streak, the pot on the bank button) animates to its
-- new value rather than snapping (spec: docs/superpowers/specs/2026-08-03-play-hud-revision-
-- design.md §2 "Numbers count rather than jump"). This module is the pure arithmetic of ONE
-- count: given where it started, where it's going, and how far through the animation the caller
-- is, what should be on screen right now.
--
-- Pure, no Roblox globals, and never requires another shared module — dependency-injected like
-- GameRules/HudModel/HudLayout, so it runs under Lune. The caller supplies `t` (elapsed fraction
-- of DURATION); this module has no wall-clock state of its own, no TweenService, nothing to fall
-- out of sync. That split is also what lets the driver (HudController) key the animation on the
-- TARGET changing rather than on render() running: the driver tracks one thing (when did the
-- target last change) and re-derives `t` every frame from that single timestamp, so a 10Hz
-- repaint that finds nothing has changed asks this module nothing new either.
local RollingNumber = {}

-- Roughly half a second, decelerating (spec).
RollingNumber.DURATION = 0.5

-- Quadratic ease-out: 1 - (1-t)^2. Monotonic and bounded to exactly [0, 1] for t in [0, 1], so
-- the interpolated value can never overshoot `to` by construction — this is not a spring or
-- anything else that could ring past the target.
local function easeOut(t: number): number
    local inv = 1 - t
    return 1 - inv * inv
end

-- `t` is the elapsed fraction of DURATION and CLAMPS to [0, 1] rather than extrapolating: a
-- caller passing a stale or negative elapsed must not send the figure past `to` or back past
-- `from`. Returns an INTEGER — this is what lands directly in a TextLabel.Text, and a fractional
-- wallet figure on screen would be its own bug.
--
-- Endpoints are pinned EXACTLY, not merely close: at t = 0, easeOut(0) = 0, so the result is
-- `from + 0` before rounding; at t >= 1 (clamped), easeOut(1) = 1, so the result is `from +
-- (to - from) = to` before rounding — both exact under IEEE754 (multiplying by 0 or 1 introduces
-- no error), and rounding an already-integer value returns it unchanged. An off-by-one at either
-- end would leave a wrong total sitting on screen permanently once the animation completes, which
-- is the one failure mode here that outlives the animation itself.
function RollingNumber.valueAt(from: number, to: number, t: number): number
    if from == to then
        return from
    end
    local clamped = math.clamp(t, 0, 1)
    local eased = easeOut(clamped)
    return math.round(from + (to - from) * eased)
end

return RollingNumber
