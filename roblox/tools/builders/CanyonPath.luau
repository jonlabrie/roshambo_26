--!strict
-- Canyon circulation builder: from a polyline of waypoints, emit a route's geometry —
-- an invisible smooth collision ramp (walkability) under decorative pavers/steps, slim
-- timber rails on both edges, and warm lanterns at intervals. Pure + deterministic
-- (no math.random) so it is Lune-tested; the Studio snap pass (buildPaths.luau) mirrors
-- this logic since MCP Studio scripts cannot require repo modules — keep them in sync.
local Spec = require("./Spec")
local StoneLantern = require("./StoneLantern")

local CanyonPath = {}

CanyonPath.TRUNK_WIDTH = 8
CanyonPath.SPUR_WIDTH = 5
CanyonPath.RAIL_HEIGHT = 3
CanyonPath.RAIL_SPACING = 6
CanyonPath.LANTERN_INTERVAL = 22
CanyonPath.STEP_GRADE = 0.27 -- tan(~15°): rise/run above this => steps

local function hyp(dx: number, dz: number): number
    return math.sqrt(dx * dx + dz * dz)
end

function CanyonPath.classifySegment(a: { number }, b: { number }): string
    local run = hyp(b[1] - a[1], b[3] - a[3])
    local rise = math.abs(b[2] - a[2])
    if run < 1e-4 then
        return "steps"
    end
    return rise / run > CanyonPath.STEP_GRADE and "steps" or "paver"
end

return CanyonPath
