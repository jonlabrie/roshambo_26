--!strict
-- Live-tunable AmbientBudget config, read from Workspace attributes, in ONE place.
--
-- This is a CLIENT module rather than part of AmbientBudget itself because it needs the `workspace`
-- global, and AmbientBudget must stay free of Roblox globals so Lune can test it. Four ambient
-- controllers need these same three attribute reads; one module beats four copies. The shape --
-- a client ModuleScript required by sibling scripts -- is the same one FlapBoard.luau already uses.
--
-- Attributes (all optional, all live-tunable during a walk without a rebuild):
--   AmbientRadius     studs; beyond this an ambient prop is not animated
--   AmbientBehindDot  normalized forward dot below which a prop counts as behind the camera
--   AmbientHz         updates per second while a prop IS animated (converted to an interval)
--   ArenaRadius       studs; the wider radius AmbientConfig.arena() applies for the bell drive
--                     and waterwheel, which read from much farther away than an ambient prop
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))

local AmbientConfig = {}

local function num(attr: string, default: number): number
    local v = workspace:GetAttribute(attr)
    return if typeof(v) == "number" then v else default
end

-- A fresh table per call, so a caller can never mutate the defaults out from under its neighbours.
function AmbientConfig.get(): AmbientBudget.Config
    local d = AmbientBudget.DEFAULT
    local hz = num("AmbientHz", 0)
    return {
        -- These two are hand-typed into the Explorer live during a phone walk, so a typo must
        -- degrade gracefully rather than blank the world: a negative/mistyped radius would
        -- otherwise silently cull every ambient prop in the place, and a behindDot above 1 would
        -- cull everything regardless of facing.
        radius = math.max(0, num("AmbientRadius", d.radius)),
        behindDot = math.clamp(num("AmbientBehindDot", d.behindDot), -1, 1),
        -- An unset or nonsensical AmbientHz falls back to the module default rather than dividing
        -- by zero or inverting a negative.
        interval = if hz > 0 then 1 / hz else d.interval,
    }
end

-- The arena machinery (bell drive, waterwheel) needs a far wider radius than the ambient props
-- this module was sized for. AmbientBudget.DEFAULT.radius (180) was chosen for a two-foot lantern
-- that is under a pixel past thirty feet; the bell drive and the waterwheel are the centrepiece of
-- the place and are read from the teahouse decks 340-400 studs out, which sit well inside
-- StreamingTargetRadius. Culling them at the lantern radius freezes the arena from exactly the
-- vantage the fireworks are watched from -- and the waterwheel's foam emitter is not gated, so a
-- culled wheel churns foam while standing still. Live-tunable separately from AmbientRadius, which
-- is the point: one number cannot serve both a lantern and a landmark.
function AmbientConfig.arena(): AmbientBudget.Config
    local c = AmbientConfig.get()
    c.radius = math.max(c.radius, num("ArenaRadius", 450))
    return c
end

return AmbientConfig
