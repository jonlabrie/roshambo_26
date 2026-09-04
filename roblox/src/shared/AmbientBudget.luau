--!strict
-- The "do not animate what the player cannot see" policy, in ONE place. Pure: no Roblox globals and
-- no instances, so Lune tests it -- unlike the .client.luau files that call it, which no harness in
-- this repo can load at all (see NorenSway.client.luau's header).
--
-- The controllers keep the vector math and the CollectionService bookkeeping; this module owns the
-- thresholds and the decision. That split is the only reason the rule is testable, and it mirrors
-- ImpostorFade's relationship to FoliageImpostorController.
local AmbientBudget = {}

export type Config = {
    radius: number, -- studs; beyond this an ambient prop is not animated
    behindDot: number, -- normalized forward dot below which the prop is behind the camera
    interval: number, -- seconds between updates while the prop IS being animated
}

AmbientBudget.DEFAULT = {
    radius = 180,
    behindDot = -0.15,
    interval = 1 / 30,
} :: Config

-- ⚠ TAKES DISTANCE SQUARED, deliberately. The caller has the squared distance for free and the
-- square root is the expensive half; for a canyon of lanterns most candidates fail THIS test, so it
-- has to be the one that can run first and short-circuit before anything calls math.sqrt.
function AmbientBudget.inRange(distSq: number, cfg: Config?): boolean
    local c = cfg or AmbientBudget.DEFAULT
    return distSq <= c.radius * c.radius
end

-- `forwardDot` is dot(normalize(prop - camera), cameraLook): 1 dead ahead, -1 directly behind.
--
-- NOT A FRUSTUM TEST, and not trying to be. `behindDot` is a MARGIN: it culls only what is clearly
-- behind the player, leaving slack for a wide FOV and for a fast turn -- because the cost of being
-- wrong is a prop the player watches start moving as it swings into view.
function AmbientBudget.inView(forwardDot: number, cfg: Config?): boolean
    local c = cfg or AmbientBudget.DEFAULT
    return forwardDot >= c.behindDot
end

-- Fixed-interval accumulator. Returns whether this frame should do the work, and the accumulator to
-- carry into the next one. Pure rather than stateful so the throttle itself is testable.
--
-- ⚠ CARRIES THE REMAINDER instead of zeroing. Zeroing discards up to a frame of time on every tick,
-- which quietly drags a nominal 30Hz down toward whatever the frame rate happens to be. The modulo
-- also bounds catch-up after a stall: one update is owed, not fifty.
function AmbientBudget.step(acc: number, dt: number, interval: number): (boolean, number)
    local elapsed = acc + dt
    if elapsed < interval then
        return false, elapsed
    end
    if interval <= 0 then
        return true, 0
    end
    return true, elapsed % interval
end

return AmbientBudget
