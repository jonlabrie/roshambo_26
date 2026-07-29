--!strict
-- The river path's chapter definitions: the valley-floor stroll route from the Square
-- (x +60) west to x -377, where it meets the existing NW80FallsStair.
--
-- BAKED from the user's dragged Workspace.PathDraft.River markers (2026-07-29). The
-- earlier seed data was a straight z = -8 survey line; the real route meanders, crosses
-- the river once, and runs 490 studs for 97 of climb.
--
-- Chapter boundaries sit on the route's own pitch breaks, so no chapter mixes a terrace
-- with a climb -- the two are built by different layout engines (uniform tread vs
-- uniform riser) and mixing them produces risers the locked recipe does not allow.
--
-- Spec: docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md section 5.
-- MIRRORED into tools/studio/buildFlatShelfPath.luau, buildIshidanStairs.luau and
-- buildBridge.luau (Studio cannot require repo modules) -- keep the control points in sync.

export type Chapter = {
    name: string,
    kind: string,
    outModel: string,
    control: { { number } },
}

export type Bridge = {
    name: string,
    a: { number },
    b: { number },
}

local RiverPathChapters = {}

-- The build stops here; NW80FallsStair (centre x -392) carries the falls headwall.
RiverPathChapters.WEST_TERMINUS = -377

-- THE FLAT/STAIR CROSSOVER IS 0.10, NOT CanyonPath.STEP_GRADE (0.27).
--
-- STEP_GRADE answers a different question -- "steps or ramp" for the old CanyonPath
-- builder. The crossover that matters here is set by our own locked recipe:
-- buildFlatShelfPath lays uniform treads at treadTarget 6.0, so a grade of 0.10 already
-- produces a 0.6-stud tread rise, exactly the riserTarget buildIshidanStairs aims for.
-- Above 0.10 a "flat shelf" tread becomes a riser TALLER than the recipe allows -- at
-- grade 0.26 it is 1.56 studs, a 19-inch step. The only flat-shelf path ever built
-- (FarWallBridge2Path) runs at 0.077.
RiverPathChapters.FLAT_MAX_GRADE = 0.10

-- Marker positions carry drag noise; anything under this is not a real descent. The
-- ishidan builder derives uniform risers from footY/headY, not from per-marker Y, so
-- inch-scale wobble between markers has no effect on what gets built.
RiverPathChapters.DESCENT_TOLERANCE = 0.25

-- The route crosses the river once, between chapters MidClimb and UpperClimb. Water sits
-- under the middle half of the span; both abutments are on Slate.
local BRIDGES: { Bridge } = {
    {
        name = "RiverCrossing",
        a = { -291.7, 181.1, 10.8 }, -- east abutment, end of MidClimb
        b = { -297.9, 182.3, -11.6 }, -- west abutment, start of UpperClimb
    },
}

local CHAPTERS: { Chapter } = {
    {
        name = "Square terrace",
        kind = "flat",
        outModel = "RiverTerracePath",
        control = {
            { 60.0, 111.8, -8.0 },
            { 0.0, 114.0, -8.0 },
            { -56.3, 116.8, 16.6 },
        },
    },
    {
        -- 23.1 studs of rise in 27.9 of run. The threshold out of the Square.
        name = "First riser",
        kind = "stair",
        outModel = "RiverFirstRiser",
        control = {
            { -56.3, 116.8, 16.6 },
            { -83.8, 139.9, 11.8 },
        },
    },
    {
        -- The long middle. Its last segment (x -259 -> -292) is dead level at grade
        -- -0.003: that is the bench, and it gets a landing rather than a chapter.
        name = "Mid climb",
        kind = "stair",
        outModel = "RiverMidClimb",
        control = {
            { -83.8, 139.9, 11.8 },
            { -144.2, 155.7, 8.3 },
            { -179.6, 160.1, 11.7 },
            { -222.9, 174.4, 32.8 },
            { -259.3, 181.2, 29.4 },
            { -291.7, 181.1, 10.8 },
        },
    },
    {
        name = "Upper climb",
        kind = "stair",
        outModel = "RiverUpperClimb",
        control = {
            { -297.9, 182.3, -11.6 },
            { -326.4, 190.0, -25.2 },
            { -362.0, 202.9, -40.2 },
            { -376.9, 208.9, -15.4 },
        },
    },
}

RiverPathChapters.CHAPTERS = CHAPTERS
RiverPathChapters.BRIDGES = BRIDGES

local function grade(a: { number }, b: { number }): number
    local run = math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
    if run < 1e-4 then
        return math.huge
    end
    return math.abs(b[2] - a[2]) / run
end

RiverPathChapters.grade = grade

-- A chapter is a stair if ANY consecutive pair exceeds FLAT_MAX_GRADE. Averaging over
-- the whole chapter would smuggle a short steep pitch into a flat-shelf layout, where
-- the uniform-tread engine renders it as an unclimbable lip.
function RiverPathChapters.kindFor(control: { { number } }): string
    for i = 2, #control do
        if grade(control[i - 1], control[i]) > RiverPathChapters.FLAT_MAX_GRADE then
            return "stair"
        end
    end
    return "flat"
end

-- Returns the bridge joining chapter `ci - 1` to chapter `ci`, or nil if they should be
-- directly contiguous.
function RiverPathChapters.bridgeBetween(prevEnd: { number }, nextStart: { number }): Bridge?
    for _, br in BRIDGES do
        local matchA = math.abs(br.a[1] - prevEnd[1]) < 0.5 and math.abs(br.a[3] - prevEnd[3]) < 0.5
        local matchB = math.abs(br.b[1] - nextStart[1]) < 0.5 and math.abs(br.b[3] - nextStart[3]) < 0.5
        if matchA and matchB then
            return br
        end
    end
    return nil
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
            if c.control[i][2] < c.control[i - 1][2] - RiverPathChapters.DESCENT_TOLERANCE then
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
            local joined = true
            for axis = 1, 3 do
                if math.abs(prev[axis] - here[axis]) > 0.5 then
                    joined = false
                    break
                end
            end
            if not joined and RiverPathChapters.bridgeBetween(prev, here) == nil then
                table.insert(
                    errs,
                    ("%s: neither contiguous with %s nor joined by a bridge"):format(
                        c.name,
                        list[ci - 1].name
                    )
                )
            end
        end
    end
    local lastControl = list[#list].control
    local last = lastControl[#lastControl]
    if math.abs(last[1] - RiverPathChapters.WEST_TERMINUS) > 1.0 then
        table.insert(errs, "route does not end at WEST_TERMINUS")
    end
    for _, br in BRIDGES do
        if br.a[1] <= br.b[1] then
            table.insert(errs, ("bridge %s: abutment a must lie east of b"):format(br.name))
        end
    end
    return #errs == 0, errs
end

return RiverPathChapters
