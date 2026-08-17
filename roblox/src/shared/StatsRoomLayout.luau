--!strict
-- WHERE THE STATS DISPLAYS GO. Pure data plus its own invariants, so placement is checkable
-- under Lune and the Studio tool that builds the parts stays a thin executor.
--
-- Everything here is PLACE-ONLY geometry (bored terrain and a Rojo model's interior, not parts
-- Rojo manages), so the boards this describes are found at runtime by CollectionService tag --
-- never by path and never by name.
--
-- ===== THE ONE RULE THIS MODULE EXISTS TO ENFORCE (owner, 2026-08-17) =====
-- A FLAP IS A PHYSICAL MODULE, AND BOARDS ARE BUILT FROM FLAPS.
--
-- The first build had it backwards: every board declared a COLUMN COUNT and inherited its cell
-- size from whatever its surveyed width happened to be. Flap width came out anywhere from 0.375
-- studs to 2.375 -- a six-fold spread, in equipment meant to read as one machine, and the cause
-- of the uneven letter sizes the owner spotted (different cell aspects clamp the glyph
-- differently, so one board reached 75% of its cell height and another only 56%).
--
-- So the grid is the INPUT and the board's dimensions are the RESULT: `w = cols * flap.w`,
-- `h = rows * flap.h`. A board cannot be declared at a size its flaps do not add up to.
local StatsRoomLayout = {}

-- TWO FLAP SIZES, FOR TWO VIEWING DISTANCES, AND ONLY TWO. Wall boards are read from across a
-- room; the personal slip is read standing in front of it. Two deliberate modules is a design.
-- Six accidental ones was the defect. Do not add a third without a viewing distance to justify it.
StatsRoomLayout.FLAPS = {
    -- banzuke's proportions, which the owner approved at the 2026-08-17 gate.
    wall = { w = 0.615, h = 0.72 },
    -- Sized so 16 columns fit the vestibule's 7.40-stud side wall with a margin, then cut a
    -- further 20% at the owner's look (2026-08-17): the first fit filled the wall, and a slip
    -- that fills its wall reads as a board rather than as the small personal thing it is.
    -- 16 x 0.34 = 5.44 wide on a 7.40 wall, so it now sits with a stud of quiet either side.
    slip = { w = 0.34, h = 0.40 },
    -- A THIRD SIZE, and the viewing distance justifies it. Wall boards are for reading a list,
    -- slips for reading up close; this is the one element that must be legible at a glance from
    -- anywhere in the room, because a player studying a wall down here cannot hear the drum.
    -- ~2-stud digits, at the wall module's proportions.
    round = { w = 2.05, h = 2.40 },
    -- The throw flipper is ONE flap, so its module is its own size. It is not a grid of cells --
    -- it renders the Glyphs image pair, not characters -- but declaring it here keeps the rule
    -- that every board's dimensions come from a named module rather than a number typed inline.
    throwPanel = { w = 4.0, h = 4.0 },
}

-- ===== SITES =====
--
-- `seat` says whether the tool should raycast for the real surface before placing. The cavern is
-- BORED TERRAIN -- 4-stud voxels, hand-shaped afterwards -- so its nominal planes are not where
-- the rock is. The vestibule's walls are built geometry at exact coordinates, so raycasting there
-- would find whatever the ray happened to hit and move a board for no reason.
StatsRoomLayout.SITES = {
    -- Measured by tools/studio/boreStatsCavern.luau in VERIFY mode after the hand-shaping.
    cavern = {
        xW = -58.00,
        xE = -17.83,
        zN = 62.00,
        zS = 85.22,
        floorY = 114.0,
        ceilingY = 134.0,
        seat = true,
    },
    -- Interior faces of MachiyaStats' ground floor, read off the built model 2026-08-17:
    -- WallWest at x -33.37 and WallEast at -24.47, both 0.50 thick, so the clean interior faces
    -- are -33.12 and -24.72. The run is z 35.53..42.93 and the height is the FloorSlab top
    -- (113.30) to the UpperFloor underside (122.30). Posts sit embedded outboard of both faces.
    vestibule = {
        xW = -33.12,
        xE = -24.72,
        zN = 35.53,
        zS = 42.93,
        floorY = 113.30,
        ceilingY = 122.30,
        seat = false,
    },
}

-- Kept as an alias: the cavern was the only site when this module was written, and callers and
-- tests still say ROOM when they mean it.
StatsRoomLayout.ROOM = StatsRoomLayout.SITES.cavern

-- The tunnel meets the cavern's north wall here (boreStatsCavern DOOR_X, BORE_W ~7 net after
-- aliasing). halfWidth is deliberately generous: a board that grazes the mouth reads as blocking
-- it. Applies to the CAVERN only -- the vestibule's doorway is in a wall no board sits on.
--
-- `top` MAKES THE KEEP-OUT A DOORWAY RATHER THAN A COLUMN: it binds only boards that reach
-- below the tunnel head (LINTEL_TOP 120.60), so anything mounted high may pass over the mouth.
-- Written for the clerestory band, which spanned the whole north wall; that band is gone, but
-- the rule outlives it -- the round display is mounted high too, and the north wall above the
-- mouth is the obvious home for whatever comes next. A test exercises the exemption directly
-- rather than through whichever board happens to use it.
StatsRoomLayout.DOOR = { x = -28.92, halfWidth = 4.0, top = 121.0 }

StatsRoomLayout.TAG = "StatsBoard"
StatsRoomLayout.THICKNESS = 0.4
StatsRoomLayout.STANDOFF = 0.3 -- board centre this far off the wall plane

export type Flap = { w: number, h: number }
export type Board = {
    id: string,
    site: string,
    wall: string,
    x: number,
    y: number,
    z: number,
    w: number,
    h: number,
    rows: number,
    cols: number,
    flap: Flap,
    -- Per-column width MULTIPLIERS, defaulting to 1 each. A printed separator is not a flap and
    -- should not occupy a flap's worth of wall (owner, 2026-08-17: the colon column "should be
    -- narrower by 50%"). The board's width is the SUM of these times the module, so the rule that
    -- dimensions are derived still holds -- it is just no longer a plain multiplication.
    colWidths: { number }?,
    shuttered: boolean?,
}

-- A board is DECLARED by its grid and where it sits along its wall; `resolve` below turns that
-- into world coordinates and derived dimensions. `along` is the centre coordinate on the wall's
-- own axis -- x for north/south walls, z for east/west ones.
type Decl = {
    id: string,
    site: string,
    wall: string,
    flap: Flap,
    rows: number,
    cols: number,
    along: number,
    y: number,
    colWidths: { number }?,
    shuttered: boolean?,
}

local WALL = StatsRoomLayout.FLAPS.wall
local SLIP = StatsRoomLayout.FLAPS.slip
local ROUND = StatsRoomLayout.FLAPS.round
local THROW = StatsRoomLayout.FLAPS.throwPanel

local DECLS: { Decl } = {
    -- ===== CAVERN =====
    -- South faces you on entry: the standings.
    {
        id = "banzuke",
        site = "cavern",
        wall = "south",
        flap = WALL,
        rows = 10,
        cols = 26,
        along = -37.90,
        y = 121.0,
    },
    -- West, the longest wall: records now, rate ladders later.
    {
        id = "skill",
        site = "cavern",
        wall = "west",
        flap = WALL,
        rows = 8,
        cols = 22,
        along = 70.00,
        y = 120.5,
    },
    {
        id = "skillFuture",
        site = "cavern",
        wall = "west",
        flap = WALL,
        rows = 6,
        -- 13, not the 18 it carried before the flap standardisation. At the standard flap 18
        -- columns is 11.07 studs and `skill` already takes z 63.24..76.77, leaving 8.45 to the
        -- south wall. This is the shape of thing the inversion is meant to surface: the old
        -- declaration asked for 18 columns on an 8-stud board and silently got 0.44-stud flaps.
        cols = 13,
        along = 81.00,
        y = 120.0,
        -- Shuttered, NOT unlit. A closed kosatsu reads as intentional; a dark one reads as broken.
        shuttered = true,
    },
    {
        id = "judgement",
        site = "cavern",
        wall = "east",
        flap = WALL,
        rows = 8,
        cols = 22,
        along = 70.00,
        y = 120.5,
    },
    -- North, west of the tunnel mouth: the form guide, last thing seen on the way out.
    {
        id = "world",
        site = "cavern",
        wall = "north",
        flap = WALL,
        rows = 6,
        cols = 22,
        along = -45.00,
        y = 120.5,
    },
    --
    -- The cavern's north wall EAST of the mouth is deliberately empty. `fuda` used to sit there
    -- and has moved to the vestibule; the owner has given the freed wall to a rotating avatar
    -- display of current leaders, which is its own piece of work (it needs image assets, and
    -- nothing in this room renders anything but text cells).
    --
    -- ===== THE ROUND DISPLAY (owner, 2026-08-16/17) =====
    -- ONE unit, high on the west wall, replacing the four clerestory band segments that held
    -- this ground. Glyph left, countdown right, as one instrument -- so `roundThrow` sits at the
    -- HIGHER z: a viewer inside the room faces west, which puts +z on their left.
    {
        id = "roundThrow",
        site = "cavern",
        wall = "west",
        flap = THROW,
        rows = 1,
        cols = 1,
        along = 78.10,
        y = 129.0,
    },
    {
        id = "roundClock",
        site = "cavern",
        wall = "west",
        flap = ROUND,
        rows = 1,
        cols = 4,
        -- The colon is printed, not flipped, so it takes half a flap's width rather than a whole
        -- one: 3.5 modules of wall, not 4.
        colWidths = { 1, 0.5, 1, 1 },
        along = 71.20,
        y = 129.0,
    },

    -- The tape: the last ten World Throws, on the wall module so the cells match the boards'.
    -- Sited by two constraints from the owner (2026-08-17) -- "below the timer" and "to the right
    -- of and on the same lower horizontal line as the larger current throw display" -- so its
    -- BOTTOM edge is roundThrow's bottom (127.00), which sets y to 127.00 + 0.72/2.
    {
        id = "roundTape",
        site = "cavern",
        wall = "west",
        flap = WALL,
        rows = 1,
        cols = 10,
        along = 72.90,
        y = 127.36,
    },

    -- ===== VESTIBULE =====
    -- MATCHING PAIR, and that is why they share the slip flap and the same grid: the owner asked
    -- for "a matching board on the opposite wall", so they must read as one pair of instruments
    -- rather than two boards that happen to face each other.
    {
        id = "fuda",
        site = "vestibule",
        wall = "west",
        flap = SLIP,
        rows = 7,
        cols = 16,
        along = 39.23,
        y = 117.5,
    },
    {
        id = "summary",
        site = "vestibule",
        wall = "east",
        flap = SLIP,
        rows = 7,
        cols = 16,
        along = 39.23,
        y = 117.5,
    },
}

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

function StatsRoomLayout.isHorizontal(wall: string): boolean
    return wall == "north" or wall == "south"
end

-- The wall's own plane coordinate, before standoff or seating.
function StatsRoomLayout.planeFor(site: any, wall: string): number
    if wall == "north" then
        return site.zN
    elseif wall == "south" then
        return site.zS
    elseif wall == "west" then
        return site.xW
    end
    return site.xE
end

-- Declaration -> world. The ONLY place a board's dimensions are computed, so a board can never
-- carry a size its own grid does not produce.
function StatsRoomLayout.widthUnits(cols: number, colWidths: { number }?): number
    if not colWidths then
        return cols
    end
    local total = 0
    for i = 1, cols do
        total += colWidths[i] or 1
    end
    return total
end

local function resolve(d: Decl): Board
    local site = StatsRoomLayout.SITES[d.site]
    local plane = StatsRoomLayout.planeFor(site, d.wall)
    local off = plane + StatsRoomLayout.inwardFor(d.wall) * StatsRoomLayout.STANDOFF
    local horizontal = StatsRoomLayout.isHorizontal(d.wall)
    return {
        id = d.id,
        site = d.site,
        wall = d.wall,
        x = if horizontal then d.along else off,
        y = d.y,
        z = if horizontal then off else d.along,
        w = StatsRoomLayout.widthUnits(d.cols, d.colWidths) * d.flap.w,
        h = d.rows * d.flap.h,
        rows = d.rows,
        cols = d.cols,
        flap = d.flap,
        colWidths = d.colWidths,
        shuttered = d.shuttered,
    }
end

StatsRoomLayout.BOARDS = (function(): { Board }
    local out: { Board } = {}
    for _, d in DECLS do
        table.insert(out, resolve(d))
    end
    return out
end)()

-- THE BORE ALIASES, SO THE NOMINAL PLANE IS NOT THE ROCK. Terrain is 4-stud voxels and the owner
-- hand-shaped the cut afterwards, so a board pinned to the nominal wall can end up buried or
-- floating. The Studio tool casts a ray from `castBack` studs OUTSIDE the plane; this turns the
-- hit distance into a seated coordinate, clamped so a ray that escapes through a gap cannot fling
-- a board across the room. A missing hit keeps the nominal plane plus the standoff.
--
-- Only sites with `seat = true` get this. Built geometry needs no correction and would be moved
-- by whatever a ray happened to strike.
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

-- Per-column geometry in the board's OWN frame: each column's centre offset along local X, and
-- its width in studs. The physical flaps need this to place themselves; keeping it here rather
-- than in the controller means the renderer and the declared width cannot disagree about where
-- column three begins.
--
-- COLUMN 1 IS THE VIEWER'S LEFTMOST, AND THAT MEANS LOCAL X RUNS DOWN, NOT UP. Standing in front
-- of a part's FRONT face you look along its local +Z, so its local +X falls on your LEFT -- a
-- property of the face, not of which wall the board is on. Laying columns out from -w/2 upward
-- therefore puts column 1 on the viewer's RIGHT and prints the clock backwards: the owner saw
-- "00:0", with the seconds ticking down in the far-left column (2026-08-17).
--
-- SurfaceGui canvases are unaffected and must not be "fixed" to match: a canvas already runs
-- left-to-right as seen from the front, which is why the GUI wall boards read correctly.
export type Column = { x: number, w: number }
function StatsRoomLayout.columns(board: Board): { Column }
    local units = StatsRoomLayout.widthUnits(board.cols, board.colWidths)
    local unitW = board.w / units
    local out: { Column } = {}
    local cursor = board.w / 2
    for c = 1, board.cols do
        local w = ((board.colWidths and board.colWidths[c]) or 1) * unitW
        table.insert(out, { x = cursor - w / 2, w = w })
        cursor -= w
    end
    return out
end

function StatsRoomLayout.check(): (boolean, { string })
    local failures: { string } = {}
    for _, b in StatsRoomLayout.BOARDS do
        local site = StatsRoomLayout.SITES[b.site]
        if not site then
            table.insert(failures, `{b.id} names an unknown site '{b.site}'`)
            continue
        end
        local half = b.w / 2
        local lo, hi, loLim, hiLim
        if StatsRoomLayout.isHorizontal(b.wall) then
            lo, hi, loLim, hiLim = b.x - half, b.x + half, site.xW, site.xE
        else
            lo, hi, loLim, hiLim = b.z - half, b.z + half, site.zN, site.zS
        end
        if lo < loLim or hi > hiLim then
            table.insert(failures, `{b.id} runs off the {b.site} {b.wall} wall`)
        end
        if b.y - b.h / 2 < site.floorY or b.y + b.h / 2 > site.ceilingY then
            table.insert(failures, `{b.id} runs through the {b.site} floor or ceiling`)
        end
        -- The cavern's tunnel mouth. A DOORWAY, not a column: only boards reaching below its head.
        local D = StatsRoomLayout.DOOR
        if b.site == "cavern" and b.wall == "north" and b.y - b.h / 2 < D.top then
            if b.x - half < D.x + D.halfWidth and b.x + half > D.x - D.halfWidth then
                table.insert(failures, `{b.id} covers the tunnel mouth`)
            end
        end
        if b.rows < 1 or b.cols < 1 then
            table.insert(failures, `{b.id} has an empty grid`)
        end
        -- The rule this module exists for. A derived dimension cannot drift, but it CAN be
        -- broken by someone reaching past resolve(), so it is asserted rather than assumed.
        local units = StatsRoomLayout.widthUnits(b.cols, b.colWidths)
        if math.abs(b.w - units * b.flap.w) > 1e-6 or math.abs(b.h - b.rows * b.flap.h) > 1e-6 then
            table.insert(failures, `{b.id} is not an exact multiple of its flap`)
        end
    end
    return #failures == 0, failures
end

return StatsRoomLayout
