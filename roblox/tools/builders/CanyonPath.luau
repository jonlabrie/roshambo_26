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

-- A standing paper-lantern on a dark post.
function CanyonPath.lanternPole(palette: { [string]: { number } }, at: { number }): Spec.PartSpec
    local x, y, z = at[1], at[2], at[3]
    return Spec.model("LanternPole", {
        Spec.part("Pole", {
            Size = { 0.3, 6, 0.3 },
            CFrame = Spec.cframe({ x, y + 3, z }),
            Color = palette.ink,
            Material = "Wood",
        }),
        Spec.part("Chochin", {
            Size = { 1.6, 2.2, 1.6 },
            CFrame = Spec.cframe({ x, y + 6, z }),
            Color = palette.gold,
            Material = "Neon",
            Transparency = 0.25,
            children = {
                {
                    name = "Glow",
                    className = "PointLight",
                    properties = { Brightness = 0.9, Range = 16, Color = { 1.0, 0.78, 0.46 } },
                },
            },
        }),
    })
end

-- Build one route's full geometry from its waypoints.
function CanyonPath.build(palette: { [string]: { number } }, route: any): Spec.PartSpec
    local width = route.class == "spur" and CanyonPath.SPUR_WIDTH or CanyonPath.TRUNK_WIDTH
    local pts = route.points
    local children = {}

    -- tread + invisible collision ramp per segment
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local pos, len, rot = Spec.segment(a, b)
        local kind = CanyonPath.classifySegment(a, b)
        table.insert(
            children,
            Spec.part("Ramp" .. (i - 1), {
                Size = { len, 0.5, width },
                CFrame = Spec.cframe(pos, rot),
                Transparency = 1,
                Material = "SmoothPlastic",
                CanCollide = true,
            })
        )
        table.insert(
            children,
            Spec.part((kind == "steps" and "Steps" or "Paver") .. (i - 1), {
                Size = { len, 0.4, width - 0.4 },
                CFrame = Spec.cframe({ pos[1], pos[2] + 0.45, pos[3] }, rot),
                Color = kind == "steps" and palette.timber or palette.gravel,
                Material = kind == "steps" and "WoodPlanks" or "Slate",
                CanCollide = false,
            })
        )
    end

    -- rail posts on both edges
    local posts = CanyonPath.placeAlong(pts, CanyonPath.RAIL_SPACING, true)
    for k, s in posts do
        local px, pz = -s.dir[2], s.dir[1] -- perpendicular in XZ
        for _, side in { -1, 1 } do
            table.insert(
                children,
                Spec.part(("RailPost%d_%d"):format(k, side), {
                    Size = { 0.4, CanyonPath.RAIL_HEIGHT, 0.4 },
                    CFrame = Spec.cframe({
                        s.pos[1] + px * (width / 2) * side,
                        s.pos[2] + CanyonPath.RAIL_HEIGHT / 2,
                        s.pos[3] + pz * (width / 2) * side,
                    }),
                    Color = palette.timber,
                    Material = "Wood",
                    CanCollide = false,
                })
            )
        end
    end

    -- top rails per segment, both sides
    for i = 2, #pts do
        local a, b = pts[i - 1], pts[i]
        local run = hyp(b[1] - a[1], b[3] - a[3])
        local px = run > 1e-4 and -(b[3] - a[3]) / run or 0
        local pz = run > 1e-4 and (b[1] - a[1]) / run or 1
        for _, side in { -1, 1 } do
            local ox, oz = px * (width / 2) * side, pz * (width / 2) * side
            local aa = { a[1] + ox, a[2] + CanyonPath.RAIL_HEIGHT, a[3] + oz }
            local bb = { b[1] + ox, b[2] + CanyonPath.RAIL_HEIGHT, b[3] + oz }
            local rpos, rlen, rrot = Spec.segment(aa, bb)
            table.insert(
                children,
                Spec.part(("RailTop%d_%d"):format(i - 1, side), {
                    Size = { rlen, 0.3, 0.3 },
                    CFrame = Spec.cframe(rpos, rrot),
                    Color = palette.timber,
                    Material = "Wood",
                    CanCollide = false,
                })
            )
        end
    end

    -- lanterns at intervals, alternating pole / stone, set just off the path edge
    local stops = CanyonPath.placeAlong(pts, CanyonPath.LANTERN_INTERVAL, false)
    for k, s in stops do
        local px, pz = -s.dir[2], s.dir[1]
        local edge = { s.pos[1] + px * (width / 2 + 1), s.pos[2], s.pos[3] + pz * (width / 2 + 1) }
        if k % 2 == 1 then
            table.insert(children, CanyonPath.lanternPole(palette, edge))
        else
            table.insert(children, StoneLantern.build(palette, edge))
        end
    end

    return Spec.model(route.name or "CanyonPath", children)
end

-- A small flat paver node where routes branch/meet, with a feature lantern.
function CanyonPath.landing(palette: { [string]: { number } }, at: { number }, radius: number): Spec.PartSpec
    local x, y, z = at[1], at[2], at[3]
    return Spec.model("Landing", {
        Spec.part("Pad", {
            Shape = "Cylinder",
            Size = { 0.5, radius * 2, radius * 2 },
            CFrame = Spec.cframe({ x, y, z }, Spec.ROT.CYL_VERTICAL),
            Color = palette.gravel,
            Material = "Slate",
            CanCollide = true,
        }),
        CanyonPath.lanternPole(palette, { x, y, z }),
    })
end

return CanyonPath
