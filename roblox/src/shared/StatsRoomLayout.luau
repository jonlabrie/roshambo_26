--!strict
-- WHERE THE STATS ROOM'S BOARDS GO. Pure data plus its own invariants, so the placement is
-- checkable under Lune and the Studio tool that builds the parts stays a thin executor.
--
-- The room is PLACE-ONLY geometry (bored terrain, not a Rojo model), so the parts this describes
-- are found at runtime by CollectionService tag — never by path and never by name.
local StatsRoomLayout = {}

-- Measured by tools/studio/boreStatsCavern.luau in VERIFY mode after the owner hand-shaped the
-- cut: the nominal bore is x[-58.00,-17.83] z[62.00,85.22], the floor aliases to ~114 and
-- ROOM_ROOF 135.0 aliases down to a measured 134.00.
StatsRoomLayout.ROOM = { xW = -58.00, xE = -17.83, zN = 62.00, zS = 85.22, floorY = 114.0, ceilingY = 134.0 }

-- The tunnel meets the north wall here (boreStatsCavern DOOR_X, BORE_W ~7 net after aliasing).
-- halfWidth is deliberately generous: a board that grazes the mouth reads as blocking it.
--
-- `top` IS WHAT LETS THE CLERESTORY BAND RUN UNBROKEN. The band spans the whole north wall,
-- mouth included, and must — it is the one display that has to be visible from anywhere in the
-- room. It clears the opening because it sits at y 131 and the tunnel head is at LINTEL_TOP
-- 120.60. So the keep-out is a DOORWAY, not a column: it binds only boards that reach below
-- `top`. Without this the invariant would be either wrong or unsatisfiable.
StatsRoomLayout.DOOR = { x = -28.92, halfWidth = 4.0, top = 121.0 }

StatsRoomLayout.TAG = "StatsBoard"
StatsRoomLayout.THICKNESS = 0.4
StatsRoomLayout.STANDOFF = 0.3 -- board centre this far off the wall plane

export type Board = {
    id: string,
    wall: string,
    x: number,
    y: number,
    z: number,
    w: number,
    h: number,
    rows: number,
    cols: number,
    shuttered: boolean?,
}

-- Exported (not local): FIX 5. RoundBandController renders each segment at its OWN `cols`
-- attribute now, but this is still the single source of truth a caller reaches for rather than
-- hand-copying the literal 16 — resizing the band is genuinely a one-line change here now.
local BAND_Y, BAND_H = 131.0, 2.4
StatsRoomLayout.BAND_COLS = 16
local BAND_COLS = StatsRoomLayout.BAND_COLS

StatsRoomLayout.BOARDS = {
    -- South faces you on entry: the standings (spec section 6).
    { id = "banzuke", wall = "south", x = -37.90, y = 121.0, z = 84.92, w = 16, h = 9, rows = 10, cols = 26 },
    -- West, the longest wall: records now, rate ladders later (ruling R4).
    { id = "skill", wall = "west", x = -57.70, y = 120.5, z = 70.00, w = 12, h = 7, rows = 8, cols = 22 },
    {
        id = "skillFuture",
        wall = "west",
        x = -57.70,
        y = 120.0,
        z = 80.50,
        w = 8,
        h = 5,
        rows = 6,
        cols = 18,
        -- Section 8: shuttered, NOT unlit. A closed kosatsu reads as intentional; a dark one
        -- reads as broken.
        shuttered = true,
    },
    { id = "judgement", wall = "east", x = -18.13, y = 120.5, z = 70.00, w = 12, h = 7, rows = 8, cols = 22 },
    -- North, west of the mouth: the form guide, last thing seen on the way out.
    { id = "world", wall = "north", x = -45.00, y = 120.5, z = 62.30, w = 12, h = 7, rows = 6, cols = 22 },
    -- North, east of the mouth: the personal slip. Paper-and-wood against stone, per-viewer.
    { id = "fuda", wall = "north", x = -21.60, y = 119.0, z = 62.30, w = 6, h = 6, rows = 7, cols = 16 },
    -- The clerestory band (section 6.3). One line, four segments, the top 4 studs nothing else wants.
    {
        id = "bandNorth",
        wall = "north",
        x = -37.90,
        y = BAND_Y,
        z = 62.30,
        w = 38,
        h = BAND_H,
        rows = 1,
        cols = BAND_COLS,
    },
    {
        id = "bandSouth",
        wall = "south",
        x = -37.90,
        y = BAND_Y,
        z = 84.92,
        w = 38,
        h = BAND_H,
        rows = 1,
        cols = BAND_COLS,
    },
    {
        id = "bandWest",
        wall = "west",
        x = -57.70,
        y = BAND_Y,
        z = 73.60,
        w = 21,
        h = BAND_H,
        rows = 1,
        cols = BAND_COLS,
    },
    {
        id = "bandEast",
        wall = "east",
        x = -18.13,
        y = BAND_Y,
        z = 73.60,
        w = 21,
        h = BAND_H,
        rows = 1,
        cols = BAND_COLS,
    },
} :: { Board }

-- CFrame.Angles(0, rad(yaw), 0).LookVector == (-sin yaw, 0, -cos yaw), and a SurfaceGui on
-- NormalId.Front renders on the LookVector face. These are the yaws that turn each wall's face
-- into the room. Derived once, here, because getting it wrong renders every board into rock.
local YAW = { north = 180, south = 0, west = -90, east = 90 }
function StatsRoomLayout.yawFor(wall: string): number
    return YAW[wall] or 0
end

-- Which way the room lies from each wall plane, along that wall's normal axis.
local INWARD = { north = 1, south = -1, west = 1, east = -1 }
function StatsRoomLayout.inwardFor(wall: string): number
    return INWARD[wall] or 1
end

-- THE BORE ALIASES, SO THE NOMINAL PLANE IS NOT THE ROCK. Terrain is 4-stud voxels and the owner
-- hand-shaped the cut afterwards, so a board pinned to the nominal wall can end up buried or
-- floating. The Studio tool casts a ray from `castBack` studs OUTSIDE the plane; this turns the
-- hit distance into a seated coordinate, clamped so a ray that escapes through a gap cannot fling
-- a board across the room. A missing hit keeps the nominal plane plus the standoff.
StatsRoomLayout.CAST_BACK = 3.0
function StatsRoomLayout.seat(
    nominal: number,
    hitDistance: number?,
    inward: number,
    maxAdjust: number
): number
    if hitDistance == nil then
        return nominal + inward * StatsRoomLayout.STANDOFF
    end
    local rock = nominal + inward * (hitDistance - StatsRoomLayout.CAST_BACK)
    local adjust = math.clamp(rock - nominal, -maxAdjust, maxAdjust)
    return nominal + adjust + inward * StatsRoomLayout.STANDOFF
end

function StatsRoomLayout.check(): (boolean, { string })
    local failures: { string } = {}
    local R = StatsRoomLayout.ROOM
    for _, b in StatsRoomLayout.BOARDS do
        local half = b.w / 2
        local lo, hi, loLim, hiLim
        if b.wall == "north" or b.wall == "south" then
            lo, hi, loLim, hiLim = b.x - half, b.x + half, R.xW, R.xE
        else
            lo, hi, loLim, hiLim = b.z - half, b.z + half, R.zN, R.zS
        end
        if lo < loLim or hi > hiLim then
            table.insert(failures, `{b.id} runs off the {b.wall} wall`)
        end
        if b.y - b.h / 2 < R.floorY or b.y + b.h / 2 > R.ceilingY then
            table.insert(failures, `{b.id} runs through the floor or ceiling`)
        end
        local D = StatsRoomLayout.DOOR
        if b.wall == "north" and b.y - b.h / 2 < D.top then
            if b.x - half < D.x + D.halfWidth and b.x + half > D.x - D.halfWidth then
                table.insert(failures, `{b.id} covers the tunnel mouth`)
            end
        end
        if b.rows < 1 or b.cols < 1 then
            table.insert(failures, `{b.id} has an empty grid`)
        end
    end
    return #failures == 0, failures
end

return StatsRoomLayout
