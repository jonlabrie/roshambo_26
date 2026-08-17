--!strict
local harness = require("./harness")
local L = require("../src/shared/StatsRoomLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function byId(id: string): any
    for _, b in L.BOARDS do
        if b.id == id then
            return b
        end
    end
    error(`no board {id}`)
end

describe("StatsRoomLayout", function()
    test("every board fits inside ITS OWN site on both axes", function()
        for _, b in L.BOARDS do
            local site = L.SITES[b.site]
            expect(site ~= nil).toBeTruthy()
            local halfW = b.w / 2
            if L.isHorizontal(b.wall) then
                expect(b.x - halfW >= site.xW).toBeTruthy()
                expect(b.x + halfW <= site.xE).toBeTruthy()
            else
                expect(b.z - halfW >= site.zN).toBeTruthy()
                expect(b.z + halfW <= site.zS).toBeTruthy()
            end
            expect(b.y - b.h / 2 >= site.floorY).toBeTruthy()
            expect(b.y + b.h / 2 <= site.ceilingY).toBeTruthy()
        end
    end)

    -- THE RULE THE MODULE EXISTS FOR. Before the 2026-08-17 inversion a board declared its own
    -- width and a column count independently, and the flap size fell out of the division --
    -- which is how one room ended up with flaps from 0.375 to 2.375 studs wide.
    test("every board's size is exactly its modules, summed", function()
        for _, b in L.BOARDS do
            local units = L.widthUnits(b.cols, b.colWidths)
            expect(math.abs(b.w - units * b.flap.w) < 1e-6).toBeTruthy()
            expect(math.abs(b.h - b.rows * b.flap.h) < 1e-6).toBeTruthy()
        end
    end)

    -- A printed separator is not a flap and should not take a flap's worth of wall. The width is
    -- still DERIVED -- it is the sum of the column weights rather than a plain multiplication --
    -- so a board still cannot be declared at a size its own columns do not add up to.
    test("the printed colon column is half a flap wide, and the board is 3.5 modules", function()
        local c = byId("roundClock")
        expect(c.colWidths).toEqual({ 1, 0.5, 1, 1 })
        expect(L.widthUnits(c.cols, c.colWidths)).toBe(3.5)
        expect(math.abs(c.w - 3.5 * L.FLAPS.round.w) < 1e-6).toBeTruthy()
    end)

    test("a board without column weights is still a plain multiple", function()
        expect(L.widthUnits(26, nil)).toBe(26)
    end)

    -- The invariant that actually matters: no board may invent a size. Every one has to come
    -- from a NAMED module in FLAPS, so adding a size is a deliberate edit to a short list with
    -- a stated purpose per entry, not a number typed inline in a board declaration.
    test("every board's module is one declared in FLAPS", function()
        local declared = {}
        for name, f in L.FLAPS do
            declared[`{f.w}x{f.h}`] = name
        end
        for _, b in L.BOARDS do
            local key = `{b.flap.w}x{b.flap.h}`
            if not declared[key] then
                error(`{b.id} uses an undeclared module {key}`)
            end
        end
    end)

    test("the modules stay few, because each is a viewing distance", function()
        local n = 0
        for _ in L.FLAPS do
            n += 1
        end
        -- wall (read a list across a room), slip (read up close), round (read at a glance from
        -- anywhere), throwPanel (the single glyph flipper). Adding a fifth should require a
        -- reason good enough to change this number on purpose.
        expect(n).toBe(4)
    end)

    -- Uniform flaps make every cell the same aspect, so the glyph clamp resolves identically
    -- everywhere. This is the whole payoff: no board can read airier than its neighbour again.
    -- The payoff of one flap size: every wall board has the same cell aspect, so the glyph rule
    -- resolves identically on all of them and no board can read airier than its neighbour. The
    -- round display is excluded -- physical flaps, sized by their own charFraction.
    test("every wall board renders at the same glyph size", function()
        local StatsBoardModel = require("../src/shared/StatsBoardModel")
        local sizes = {}
        for _, b in L.BOARDS do
            if b.id:sub(1, 5) ~= "round" then
                table.insert(sizes, StatsBoardModel.metrics(b.rows, b.cols, b.w / b.h).glyphSize)
            end
        end
        expect(#sizes > 1).toBeTruthy()
        for _, size in sizes do
            expect(size).toBe(sizes[1])
        end
    end)

    test("the matching vestibule pair really matches", function()
        local fuda, summary = byId("fuda"), byId("summary")
        expect(fuda.flap).toBe(summary.flap)
        expect(fuda.rows).toBe(summary.rows)
        expect(fuda.cols).toBe(summary.cols)
        expect(fuda.y).toBe(summary.y)
        expect(fuda.wall).toBe("west")
        expect(summary.wall).toBe("east")
        expect(fuda.site).toBe("vestibule")
    end)

    test("nothing at door height covers the cavern's tunnel mouth", function()
        for _, b in L.BOARDS do
            if b.site == "cavern" and b.wall == "north" and b.y - b.h / 2 < L.DOOR.top then
                local clear = b.x - b.w / 2 >= L.DOOR.x + L.DOOR.halfWidth
                    or b.x + b.w / 2 <= L.DOOR.x - L.DOOR.halfWidth
                expect(clear).toBeTruthy()
            end
        end
    end)

    -- Tests the EXEMPTION, not a board that happens to use it. The clerestory band used to span
    -- the whole north wall and cross the mouth; since the flap standardisation it is only 9.84
    -- studs and clears the opening by position instead. The rule still has to hold for whatever
    -- spans that wall next -- the round display is going high on a wall too.
    test("a board above the door head may cross the mouth; one below it may not", function()
        local above = { site = "cavern", wall = "north", x = L.DOOR.x, w = 30, h = 2, y = L.DOOR.top + 10 }
        local below = { site = "cavern", wall = "north", x = L.DOOR.x, w = 30, h = 2, y = L.DOOR.top - 5 }
        local function crossesAtDoorHeight(b: any): boolean
            if b.y - b.h / 2 >= L.DOOR.top then
                return false
            end
            return b.x - b.w / 2 < L.DOOR.x + L.DOOR.halfWidth and b.x + b.w / 2 > L.DOOR.x - L.DOOR.halfWidth
        end
        expect(crossesAtDoorHeight(above)).toBe(false)
        expect(crossesAtDoorHeight(below)).toBe(true)
    end)

    test("no two boards on the same wall of the same site overlap", function()
        for i, a in L.BOARDS do
            for j, b in L.BOARDS do
                if j > i and a.site == b.site and a.wall == b.wall then
                    local aAxis = if L.isHorizontal(a.wall) then a.x else a.z
                    local bAxis = if L.isHorizontal(b.wall) then b.x else b.z
                    local apart = math.abs(aAxis - bAxis) >= (a.w + b.w) / 2
                    local stacked = math.abs(a.y - b.y) >= (a.h + b.h) / 2
                    expect(apart or stacked).toBeTruthy()
                end
            end
        end
    end)

    -- The round display supersedes the four clerestory band segments (owner, 2026-08-16): one
    -- unit, west wall, glyph beside countdown. `roundThrow` sits at the higher z because a
    -- viewer inside the room faces west, which puts +z on their left.
    test("the round display is one unit on the west wall, glyph left of the clock", function()
        local throwPanel, clock = byId("roundThrow"), byId("roundClock")
        expect(throwPanel.wall).toBe("west")
        expect(clock.wall).toBe("west")
        expect(throwPanel.z > clock.z).toBeTruthy()
        expect(throwPanel.y).toBe(clock.y)
        expect(clock.cols).toBe(4) -- 0 : 0 0
        expect(throwPanel.cols).toBe(1) -- a single flipper, not a grid
    end)

    test("the clerestory band is gone, not merely unused", function()
        for _, b in L.BOARDS do
            expect(b.id:sub(1, 4) ~= "band").toBeTruthy()
        end
    end)

    test("the reserved skill panel is shuttered, not merely absent (spec section 8)", function()
        expect(byId("skillFuture").shuttered).toBe(true)
    end)

    test("columns tile the board exactly, edge to edge, in order", function()
        local c = byId("roundClock")
        local cols = L.columns(c)
        expect(#cols).toBe(4)
        -- No gaps and no overlaps: each column starts where the last ended.
        local cursor = c.w / 2
        for _, col in cols do
            expect(math.abs((col.x + col.w / 2) - cursor) < 1e-6).toBeTruthy()
            cursor -= col.w
        end
        expect(math.abs(cursor + c.w / 2) < 1e-6).toBeTruthy()
    end)

    -- THE DIRECTION IS THE BUG THIS PINS. A part's local +X falls on the viewer's LEFT when they
    -- face its front, so column 1 -- the leftmost as read -- must have the HIGHEST local X.
    -- Ascending X printed the clock backwards: "00:0", seconds ticking in the far-left column.
    test("column 1 is the viewer's leftmost, so local X descends", function()
        local cols = L.columns(byId("roundClock"))
        for i = 2, #cols do
            expect(cols[i].x < cols[i - 1].x).toBeTruthy()
        end
    end)

    test("the printed colon's column is half the width of a digit's", function()
        local cols = L.columns(byId("roundClock"))
        expect(math.abs(cols[2].w - cols[1].w / 2) < 1e-6).toBeTruthy()
        expect(math.abs(cols[3].w - cols[1].w) < 1e-6).toBeTruthy()
    end)

    test("a single-column board is one full-width column centred on the board", function()
        local cols = L.columns(byId("roundThrow"))
        expect(#cols).toBe(1)
        expect(cols[1].x).toBe(0)
        expect(cols[1].w).toBe(byId("roundThrow").w)
    end)

    test("yaw turns each wall's board face into the room", function()
        expect(L.yawFor("north")).toBe(180)
        expect(L.yawFor("south")).toBe(0)
        expect(L.yawFor("west")).toBe(-90)
        expect(L.yawFor("east")).toBe(90)
    end)

    -- The ray is cast from CAST_BACK (3) studs INSIDE the room towards the wall, so its distance
    -- is measured against that 3 rather than from the board.
    test("seat places the board against the measured rock", function()
        -- inward = +1 (north wall: the room lies at greater z), plane 62.0.
        expect(L.seat(62.0, 3, 1, 2.5)).toBeCloseTo(62.3, 0.001) -- rock on the plane
        expect(L.seat(62.0, 1, 1, 2.5)).toBeCloseTo(64.3, 0.001) -- rock 2 into the room
        expect(L.seat(62.0, 5, 1, 2.5)).toBeCloseTo(60.3, 0.001) -- rock 2 further out
    end)

    test("a wild ray is clamped, never obeyed", function()
        expect(L.seat(62.0, 30, 1, 2.5)).toBeCloseTo(59.8, 0.001)
        expect(L.seat(62.0, 0, 1, 2.5)).toBeCloseTo(64.8, 0.001)
    end)

    test("no hit keeps the nominal plane plus the standoff, on either kind of wall", function()
        expect(L.seat(62.0, nil, 1, 2.5)).toBeCloseTo(62.3, 0.001)
        expect(L.seat(85.22, nil, -1, 2.5)).toBeCloseTo(84.92, 0.001)
    end)

    -- THE DOUBLE-STANDOFF GUARD. seat() adds the standoff itself and a Board's own x/z already
    -- carries it from resolve(), so handing a Board coordinate in here stands it off twice --
    -- exactly what the Studio tool did until 2026-08-17, putting every board 0.6 off its wall.
    test("seat takes the PLANE; a board's own coordinate is already offset from it", function()
        local b = byId("banzuke")
        local plane = L.planeFor(L.SITES[b.site], b.wall)
        local inward = L.inwardFor(b.wall)
        expect(math.abs(b.z - (plane + inward * L.STANDOFF)) < 1e-6).toBeTruthy()
        expect(L.seat(plane, nil, inward, 2.5)).toBeCloseTo(b.z, 0.001)
    end)

    test("check() passes on the shipped inventory", function()
        local ok, failures = L.check()
        expect(#failures).toBe(0)
        expect(ok).toBe(true)
    end)
end)
