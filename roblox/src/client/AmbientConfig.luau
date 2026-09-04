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
        radius = num("AmbientRadius", d.radius),
        behindDot = num("AmbientBehindDot", d.behindDot),
        -- An unset or nonsensical AmbientHz falls back to the module default rather than dividing
        -- by zero or inverting a negative.
        interval = if hz > 0 then 1 / hz else d.interval,
    }
end

return AmbientConfig
