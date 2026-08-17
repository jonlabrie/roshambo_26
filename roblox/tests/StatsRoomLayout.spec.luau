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
    test("every board is an exact whole number of its own flaps", function()
        for _, b in L.BOARDS do
            expect(math.abs(b.w - b.cols * b.flap.w) < 1e-6).toBeTruthy()
            expect(math.abs(b.h - b.rows * b.flap.h) < 1e-6).toBeTruthy()
        end
    end)

    test("there are exactly two flap sizes, and every board uses one of them", function()
        local seen = {}
        for _, b in L.BOARDS do
            seen[`{b.flap.w}x{b.flap.h}`] = true
        end
        local n = 0
        for _ in seen do
            n += 1
        end
        expect(n).toBe(2)
        expect(seen[`{L.FLAPS.wall.w}x{L.FLAPS.wall.h}`]).toBe(true)
        expect(seen[`{L.FLAPS.slip.w}x{L.FLAPS.slip.h}`]).toBe(true)
    end)

    -- Uniform flaps make every cell the same aspect, so the glyph clamp resolves identically
    -- everywhere. This is the whole payoff: no board can read airier than its neighbour again.
    test("every board renders at the same glyph size", function()
        local StatsBoardModel = require("../src/shared/StatsBoardModel")
        for _, b in L.BOARDS do
            expect(StatsBoardModel.metrics(b.rows, b.cols, b.w / b.h).glyphSize).toBe(90)
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

    test("the band runs on all four walls, at one height, one row, one width", function()
        local band = {}
        for _, b in L.BOARDS do
            if b.id:sub(1, 4) == "band" then
                table.insert(band, b)
            end
        end
        expect(#band).toBe(4)
        for _, b in band do
            expect(b.rows).toBe(1)
            expect(b.cols).toBe(band[1].cols)
            expect(b.y).toBe(band[1].y)
        end
    end)

    test("the reserved skill panel is shuttered, not merely absent (spec section 8)", function()
        expect(byId("skillFuture").shuttered).toBe(true)
    end)

    test("yaw turns each wall's board face into the room", function()
        expect(L.yawFor("north")).toBe(180)
        expect(L.yawFor("south")).toBe(0)
        expect(L.yawFor("west")).toBe(-90)
        expect(L.yawFor("east")).toBe(90)
    end)

    test("seat moves the board to the measured rock, clamped so a bad ray cannot fling it", function()
        -- inward = +1 (north wall: room lies at greater z). A hit 5 studs along a ray that
        -- started 3 studs outside the nominal plane means rock 2 studs INTO the room.
        expect(L.seat(62.0, 5, 1, 2.5)).toBeCloseTo(64.3, 0.001)
        -- A wild ray is clamped, never obeyed.
        expect(L.seat(62.0, 30, 1, 2.5)).toBeCloseTo(64.8, 0.001)
        -- No hit at all: stay nominal, offset by the board's own standoff.
        expect(L.seat(62.0, nil, 1, 2.5)).toBeCloseTo(62.3, 0.001)
    end)

    test("check() passes on the shipped inventory", function()
        local ok, failures = L.check()
        expect(#failures).toBe(0)
        expect(ok).toBe(true)
    end)
end)
