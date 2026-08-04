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

-- HOW LONG A COUNT TAKES IS A FUNCTION OF HOW FAR IT GOES (spec §3a). A flat duration meant
-- banking 2000 points took the same half second as banking 1, and the owner's word for it was
-- that it "transferred" rather than paid out.
--
-- LOGARITHMIC, so it flattens on its own: no pot however large can run away with the screen,
-- and the ceiling is reached rather than approached. Values it produces:
--   1 -> 0.56s   30 -> 1.18s   300 -> 1.70s   3000 -> 2.23s   10000+ -> 2.50s
RollingNumber.MIN_DURATION = 0.4
RollingNumber.MAX_DURATION = 2.5
RollingNumber.SCALE_CAP = 10000

-- `delta` is signed; only its MAGNITUDE matters. The bank button drains to zero while the
-- balance fills, and those are one event — a count down that finished before the count up would
-- show the points arriving from nowhere.
function RollingNumber.durationFor(delta: number): number
    local magnitude = math.min(math.abs(delta), RollingNumber.SCALE_CAP)
    local span = RollingNumber.MAX_DURATION - RollingNumber.MIN_DURATION
    local fraction = math.log(1 + magnitude) / math.log(1 + RollingNumber.SCALE_CAP)
    return RollingNumber.MIN_DURATION + span * fraction
end

-- SMOOTHSTEP, not the quadratic ease-out this replaces. A payoff winds up, races, then settles;
-- ease-out did the opposite — fastest at the start, so three quarters of a two-second count
-- landed in the first second and the last quarter crawled. Smoothstep keeps every guarantee the
-- tests below assert: monotonic on [0,1], bounded to exactly [0,1], and exact at both endpoints
-- (0 -> 0, 1 -> 1*(3-2) = 1), so the interpolated value still cannot overshoot `to`.
local function smoothstep(t: number): number
    return t * t * (3 - 2 * t)
end

-- `t` is the elapsed fraction of the caller's chosen duration (see `durationFor`) and CLAMPS to
-- [0, 1] rather than extrapolating: a caller passing a stale or negative elapsed must not send
-- the figure past `to` or back past `from`. Returns an INTEGER — this is what lands directly in a
-- TextLabel.Text, and a fractional wallet figure on screen would be its own bug.
--
-- Endpoints are pinned EXACTLY, not merely close: at t = 0, smoothstep(0) = 0, so the result is
-- `from + 0` before rounding; at t >= 1 (clamped), smoothstep(1) = 1, so the result is `from +
-- (to - from) = to` before rounding — both exact under IEEE754 (multiplying by 0 or 1 introduces
-- no error), and rounding an already-integer value returns it unchanged. An off-by-one at either
-- end would leave a wrong total sitting on screen permanently once the animation completes, which
-- is the one failure mode here that outlives the animation itself.
function RollingNumber.valueAt(from: number, to: number, t: number): number
    if from == to then
        return from
    end
    local clamped = math.clamp(t, 0, 1)
    local eased = smoothstep(clamped)
    return math.round(from + (to - from) * eased)
end

return RollingNumber
