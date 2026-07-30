--!strict
-- The river path's chapter definitions: the valley-floor stroll route from the Square
-- west to x -377, where it meets the existing NW80FallsStair.
--
-- BAKED from the user's dragged Workspace.PathDraft.River markers. Control Y values are
-- RAYCAST GROUND, not marker centres -- a 4-stud draft ball resting on the ground reads
-- 2 studs high, and baking marker Y floats every chapter by that much. The one exception
-- is the joint at x -89.8, which is the BUILT head of RiverSquareStair (139.9), not the
-- ground under it (138.8): the trail starts on the stair's top tread.
--
-- Spec: docs/superpowers/specs/2026-07-29-canyon-garden-floor-design.md section 5.
-- MIRRORED into tools/studio/buildIshidanStairs.luau, buildTrailPath.luau and
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

-- A spur leaves the main route and DEAD-ENDS somewhere useful. It is not a chapter:
-- chapters chain end-to-end from the Square to the falls and the tests enforce that;
-- a spur joins the route at `joinsAt` (a point inside some chapter's span) and stops.
export type Spur = {
    name: string,
    kind: string,
    outModel: string,
    joinsAt: string, -- outModel of the chapter it forks from
    control: { { number } },
}

local RiverPathChapters = {}

-- The build stops here; NW80FallsStair (centre x -392) carries the falls headwall.
RiverPathChapters.WEST_TERMINUS = -376.9

-- THREE SURFACE KINDS, and the thresholds below are ONE-DIRECTIONAL LIMITS, not a
-- classifier. Which kind a chapter gets is an AUTHORED, user-gated decision about
-- register -- formal stonework near the Square, dirt trail out west (spec section 5a).
-- The numbers here exist only to catch a chapter whose declared kind its terrain cannot
-- physically support. A "stair" is admissible at any grade above flat, because a stair is
-- always a workable answer; a "trail" is not, because a loose surface has a real limit.
--
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

-- A benched earth-and-gravel tread will not hold much past 1:3, and a walking surface of
-- loose material becomes unpleasant well before its angle of repose. Originally 0.32 --
-- where the Mid climb separates (traverse 0.310, falls climb 0.339) -- raised to 0.34
-- when the Upper climb re-registered as a trail (user-gated): its sustained middle
-- measures 0.331, and the wild west end earns the steeper game-trail tread over more
-- construction. Anything past this is a stepped pitch, not a trail.
RiverPathChapters.TRAIL_MAX_GRADE = 0.34

-- Trails undulate; the descent check exists to catch a marker dragged BELOW its eastern
-- neighbour by mistake, not to forbid a dip. The pool shore genuinely loses 0.6 studs
-- over 37 as it rounds the upper pool, and that is correct.
RiverPathChapters.DESCENT_TOLERANCE = 1.0

-- The route crosses the river once, at the upper pool's narrow west end, between the
-- Pool shore and the Upper climb. Water sits under the middle half; both abutments are
-- on Slate.
local BRIDGES: { Bridge } = {
    {
        name = "RiverCrossing",
        a = { -291.7, 178.6, 10.8 }, -- east abutment, end of Pool shore
        b = { -297.9, 180.4, -11.6 }, -- west abutment, start of Upper climb
    },
}

-- Access spurs off the main route.
local SPURS: { Spur } = {
    {
        -- Teahouse pad T07 is the only pad with no tunnel access, so the trail
        -- provides it: a single-file fork off the pool shore, up the platform's west
        -- flank to its rear (SW) corner. Narrower than anything else on the route
        -- (1.5 vs 3.5) and deliberately unstepped -- a bare desire path.
        --
        -- Verified before building: all six M-size pad posts clear this line by
        -- >= 6.2 studs (L by ~4.3) against SizeClasses.deckFootprint. If a future
        -- line runs tighter, PadPlanner already omits a blocked post and cantilevers
        -- (PadOps.blockedByPath, keyed on the AccessKeepOut tag).
        name = "T07 access spur",
        kind = "trail",
        outModel = "RiverT07Spur",
        joinsAt = "RiverPoolShore",
        control = {
            { -285.4, 179.5, 16.9 },
            { -300.1, 184.3, 17.7 },
            { -309.6, 185.5, 21.0 },
            { -312.1, 187.0, 27.9 },
            { -310.8, 188.1, 35.8 },
            { -305.0, 190.4, 42.6 },
        },
    },
}

local CHAPTERS: { Chapter } = {
    {
        -- The stairway out of the Square, over the hill that is the primary obstacle to
        -- entering the western canyon. Grade 0.551 over 45.9 of run.
        --
        -- Tread lands at 1.09, leaving 0.46 of usable flag depth -- clear of
        -- flagMinDepth 0.4 -- so unlike NW1012South this flight SHOWS its flagstone
        -- field. 2R+T is 2.29, above the 2.0-2.1 comfort target; pulling it back would
        -- need riserTarget 0.54, which drops the tread under 1.0 and loses the flagstones
        -- again. Locked riserTarget 0.6 kept and the trade accepted (user-gated).
        --
        -- AS-BUILT 2026-07-29. Do not re-bake these from markers: the draft balls have
        -- since been dragged and no longer describe what stands in the world.
        name = "Square stair",
        kind = "stair",
        outModel = "RiverSquareStair",
        control = {
            { -44.0, 114.6, 30.4 },
            { -89.8, 139.9, 27.9 },
        },
    },
    {
        -- The side-hill traverse above the river. The hillside itself rises about 0.20
        -- westward and there is no gentler line available: swinging south climbs into
        -- the canyon wall (0.32 locally), swinging north runs into the water. So the
        -- grade is the terrain's own, evened out rather than eased -- 0.135 to 0.310.
        --
        -- Dirt trail, not stonework: 200 studs west of the Square the resort's formal
        -- vocabulary overreaches the care gradient (spec section 5a).
        name = "River traverse",
        kind = "trail",
        outModel = "RiverTraverse",
        control = {
            { -89.8, 139.9, 27.9 }, -- head of RiverSquareStair (built tread, not ground)
            { -106.0, 142.7, 22.0 },
            { -121.9, 145.8, 8.7 },
            { -140.0, 151.5, 12.0 },
            { -160.0, 155.9, 4.8 },
            { -174.0, 158.6, 17.0 },
            { -188.0, 161.4, 23.0 },
            { -197.0, 163.3, 30.0 },
            { -205.0, 164.5, 34.0 },
        },
    },
    {
        -- The climb beside W05, the canyon's largest fall (~16 studs, centred at
        -- x -220, z +17). The one pitch on the route that genuinely needs steps, and a
        -- staged site in its own right, so it earns the formality.
        --
        -- The 0.156 segment at x -223.5 -> -228.0 is a NATURAL FLAT, not noise: it
        -- becomes the landing between the two flights, and it faces the fall.
        --
        -- Stretched marutakaidan proportion -- riser 0.9, tread ~2.4 -- NOT the locked
        -- riserTarget 0.6. That override is deliberate and lives on the preset, not in
        -- the recipe: chunky log-and-earth steps read as mountain trailwork rather than
        -- as a second ishidan flight (user-gated).
        name = "W05 falls steps",
        kind = "stair",
        outModel = "RiverFallsSteps",
        control = {
            { -205.0, 164.5, 34.0 },
            { -213.5, 167.4, 34.9 },
            { -218.1, 169.3, 35.1 },
            { -223.5, 172.3, 35.8 }, -- foot of the landing
            { -228.0, 173.0, 35.9 }, -- head of the landing
            { -234.0, 175.0, 36.0 },
        },
    },
    {
        -- Rounding the south shore of the big upper pool (surface 174.8), which the
        -- trail holds 2 to 5 studs above. Levels off entirely past x -246.
        name = "Pool shore",
        kind = "trail",
        outModel = "RiverPoolShore",
        control = {
            { -234.0, 175.0, 36.0 },
            { -246.0, 177.8, 36.0 },
            { -259.3, 179.2, 29.4 },
            { -291.7, 178.6, 10.8 },
        },
    },
    {
        -- Re-registered "stair" -> "trail" 2026-07-30 (user-gated, with the
        -- TRAIL_MAX_GRADE bump to 0.34 for its 0.331 sustained middle). A GAME
        -- TRAIL: single-file 1.5 width, mostly Grass underfoot -- the only chapter
        -- not on Slate -- with grey-cypress log steps only at its two bites (the
        -- bridge-exit shelf, local 0.63-0.68, and the final approach to
        -- NW80FallsStair, local 0.69-0.97). Dock approach clears the 15-stud garden
        -- radius at 16.3.
        name = "Upper climb",
        kind = "trail",
        outModel = "RiverUpperClimb",
        control = {
            { -297.9, 180.4, -11.6 },
            { -326.4, 188.0, -25.2 },
            { -362.0, 200.8, -40.2 },
            { -376.9, 205.8, -15.4 },
        },
    },
}

RiverPathChapters.CHAPTERS = CHAPTERS
RiverPathChapters.BRIDGES = BRIDGES
RiverPathChapters.SPURS = SPURS

local function grade(a: { number }, b: { number }): number
    local run = math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
    if run < 1e-4 then
        return math.huge
    end
    return math.abs(b[2] - a[2]) / run
end

RiverPathChapters.grade = grade

-- The steepest consecutive pair in a chapter. Averaging over the whole chapter would
-- smuggle a short steep pitch into a gentle layout, where it renders as an unclimbable
-- lip.
function RiverPathChapters.maxGrade(control: { { number } }): number
    local worst = 0
    for i = 2, #control do
        worst = math.max(worst, grade(control[i - 1], control[i]))
    end
    return worst
end

-- Can this terrain carry a chapter of this kind? One-directional: see the threshold
-- comments above. Returns false plus a human-readable reason.
function RiverPathChapters.admits(kind: string, control: { { number } }): (boolean, string?)
    local worst = RiverPathChapters.maxGrade(control)
    if kind == "flat" then
        if worst > RiverPathChapters.FLAT_MAX_GRADE then
            return false,
                ("grade %.3f exceeds FLAT_MAX_GRADE %.2f"):format(worst, RiverPathChapters.FLAT_MAX_GRADE)
        end
    elseif kind == "trail" then
        if worst > RiverPathChapters.TRAIL_MAX_GRADE then
            return false,
                ("grade %.3f exceeds TRAIL_MAX_GRADE %.2f -- a loose tread will not hold"):format(
                    worst,
                    RiverPathChapters.TRAIL_MAX_GRADE
                )
        end
    elseif kind == "stair" then
        if worst <= RiverPathChapters.FLAT_MAX_GRADE then
            return false, ("grade %.3f is flat enough that a stair would build zero risers"):format(worst)
        end
    else
        return false, ("unknown kind %q -- expected flat, trail or stair"):format(kind)
    end
    return true, nil
end

-- Returns the bridge joining `prevEnd` to `nextStart`, or nil if they should be
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
        local ok, why = RiverPathChapters.admits(c.kind, c.control)
        if not ok then
            table.insert(errs, ("%s: declared %q but %s"):format(c.name, c.kind, why or "?"))
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
    for _, sp in SPURS do
        local ok, why = RiverPathChapters.admits(sp.kind, sp.control)
        if not ok then
            table.insert(errs, ("spur %s: declared %q but %s"):format(sp.name, sp.kind, why or "?"))
        end
        local host = nil
        for _, c in CHAPTERS do
            if c.outModel == sp.joinsAt then
                host = c
            end
        end
        if host == nil then
            table.insert(errs, ("spur %s: joinsAt %q is not a chapter"):format(sp.name, sp.joinsAt))
        else
            -- the fork must actually touch its host chapter's span
            local x = sp.control[1][1]
            local lo, hi = host.control[#host.control][1], host.control[1][1]
            if x < lo - 1.0 or x > hi + 1.0 then
                table.insert(
                    errs,
                    ("spur %s: forks at x %.1f, outside %s (%.1f..%.1f)"):format(
                        sp.name,
                        x,
                        sp.joinsAt,
                        lo,
                        hi
                    )
                )
            end
        end
    end
    return #errs == 0, errs
end

return RiverPathChapters
