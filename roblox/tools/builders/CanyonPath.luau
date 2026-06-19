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

-- Walk the polyline; emit a sample every `spacing` studs of 3D length. Each sample
-- carries the unit horizontal heading (dir) of the segment it falls on, so callers
-- can offset rails/lanterns perpendicular to the path. includeEnds adds 0 and total.
function CanyonPath.placeAlong(
    points: { { number } },
    spacing: number,
    includeEnds: boolean
): { { pos: { number }, dir: { number } } }
    local segs = {}
    local total = 0
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local dir = run > 1e-4 and { (b[1] - a[1]) / run, (b[3] - a[3]) / run } or { 1, 0 }
        table.insert(segs, { a = a, b = b, len = len, dir = dir, start = total })
        total += len
    end
    local function sample(d: number)
        for _, s in segs do
            if d <= s.start + s.len + 1e-6 then
                local t = s.len > 1e-6 and math.clamp((d - s.start) / s.len, 0, 1) or 0
                return {
                    pos = {
                        s.a[1] + (s.b[1] - s.a[1]) * t,
                        s.a[2] + (s.b[2] - s.a[2]) * t,
                        s.a[3] + (s.b[3] - s.a[3]) * t,
                    },
                    dir = s.dir,
                }
            end
        end
        local last = segs[#segs]
        return { pos = last and last.b or points[1], dir = last and last.dir or { 1, 0 } }
    end
    local out = {}
    if includeEnds then
        table.insert(out, sample(0))
    end
    local d = spacing
    while d < total - 1e-6 do
        table.insert(out, sample(d))
        d += spacing
    end
    if includeEnds and total > 1e-6 then
        table.insert(out, sample(total))
    end
    return out
end

return CanyonPath
