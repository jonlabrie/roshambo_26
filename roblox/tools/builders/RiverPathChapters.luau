--!strict
-- The river path's chapter definitions: the valley-floor stroll route from the Square
-- (x +60) west to x -380, where it meets the existing NW80FallsStair.
--
-- The terrain divides the route for us. Sampling the lowest ground between z -30 and
-- +15 at 20-stud intervals gives two flat terraces and three climbs, with two sharp
-- risers acting as thresholds. Chapter boundaries sit ON those breaks, so no chapter
-- mixes a terrace with a climb -- which matters because the two are built by different
-- layout engines (uniform tread vs uniform riser).
--
-- Spec: docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md section 5.
-- MIRRORED into tools/studio/buildFlatShelfPath.luau and buildIshidanStairs.luau
-- (Studio cannot require repo modules) -- keep the control points in sync.
local CanyonPath = require("./CanyonPath")

export type Chapter = {
    name: string,
    kind: string,
    outModel: string,
    control: { { number } },
}

local RiverPathChapters = {}

-- The build stops here; NW80FallsStair (centre x -392) carries the falls headwall.
RiverPathChapters.WEST_TERMINUS = -380

-- SEED DATA: the surveyed corridor profile, not yet the user's line. Task 3 of the
-- plan replaces `control` with the baked marker positions; the spec tests guard it.
local CHAPTERS: { Chapter } = {
    {
        name = "Square terrace",
        kind = "flat",
        outModel = "RiverTerracePath",
        control = {
            { 60.0, 108.7, -8.0 },
            { 0.0, 109.9, -8.0 },
            { -80.0, 109.9, -8.0 },
        },
    },
    {
        name = "First riser",
        kind = "stair",
        outModel = "RiverFirstRiser",
        control = {
            { -80.0, 109.9, -8.0 },
            { -100.0, 134.4, -8.0 },
        },
    },
    {
        name = "Mid climb",
        kind = "stair",
        outModel = "RiverMidClimb",
        control = {
            { -100.0, 134.4, -8.0 },
            { -160.0, 152.2, -8.0 },
            { -200.0, 159.4, -8.0 },
            { -240.0, 174.8, -8.0 },
        },
    },
    {
        name = "The bench",
        kind = "flat",
        outModel = "RiverBenchShelf",
        control = {
            { -240.0, 174.8, -8.0 },
            { -280.0, 174.8, -8.0 },
            { -300.0, 177.2, -8.0 },
        },
    },
    {
        name = "Upper climb",
        kind = "stair",
        outModel = "RiverUpperClimb",
        control = {
            { -300.0, 177.2, -8.0 },
            { -340.0, 186.9, -8.0 },
            { -360.0, 188.7, -8.0 },
            { -380.0, 199.5, -8.0 },
        },
    },
}

RiverPathChapters.CHAPTERS = CHAPTERS

-- A chapter is a stair if ANY consecutive pair exceeds CanyonPath.STEP_GRADE (0.27).
-- Whole-chapter average would smuggle a short steep pitch into a flat-shelf layout,
-- where the uniform-tread engine would render it as an unclimbable lip.
function RiverPathChapters.kindFor(control: { { number } }): string
    for i = 2, #control do
        if CanyonPath.classifySegment(control[i - 1], control[i]) == "steps" then
            return "stair"
        end
    end
    return "flat"
end

function RiverPathChapters.validate(): (boolean, { string })
    local errs: { string } = {}
    local list = RiverPathChapters.CHAPTERS
    for ci, c in list do
        if #c.control < 2 then
            table.insert(errs, ("%s: needs at least two control points"):format(c.name))
        end
        for i = 2, #c.control do
            if c.control[i][1] >= c.control[i - 1][1] then
                table.insert(errs, ("%s: control %d does not run westward"):format(c.name, i))
            end
            if c.control[i][2] < c.control[i - 1][2] - 0.01 then
                table.insert(errs, ("%s: control %d descends"):format(c.name, i))
            end
        end
        local measured = RiverPathChapters.kindFor(c.control)
        if measured ~= c.kind then
            table.insert(errs, ("%s: declared %q but measures %q"):format(c.name, c.kind, measured))
        end
        if ci > 1 then
            local prevControl = list[ci - 1].control
            local prev = prevControl[#prevControl]
            local here = c.control[1]
            for axis = 1, 3 do
                if math.abs(prev[axis] - here[axis]) > 0.5 then
                    table.insert(
                        errs,
                        ("%s: does not start where %s ended"):format(c.name, list[ci - 1].name)
                    )
                    break
                end
            end
        end
    end
    local lastControl = list[#list].control
    local last = lastControl[#lastControl]
    if math.abs(last[1] - RiverPathChapters.WEST_TERMINUS) > 1.0 then
        table.insert(errs, "route does not end at WEST_TERMINUS")
    end
    return #errs == 0, errs
end

return RiverPathChapters
