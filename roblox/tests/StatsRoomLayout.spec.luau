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
    test("every board fits inside the bored room on both axes", function()
        for _, b in L.BOARDS do
            local halfW = b.w / 2
            if b.wall == "north" or b.wall == "south" then
                expect(b.x - halfW >= L.ROOM.xW).toBeTruthy()
                expect(b.x + halfW <= L.ROOM.xE).toBeTruthy()
            else
                expect(b.z - halfW >= L.ROOM.zN).toBeTruthy()
                expect(b.z + halfW <= L.ROOM.zS).toBeTruthy()
            end
            expect(b.y - b.h / 2 >= L.ROOM.floorY).toBeTruthy()
            expect(b.y + b.h / 2 <= L.ROOM.ceilingY).toBeTruthy()
        end
    end)

    test("nothing at door height covers the tunnel mouth", function()
        for _, b in L.BOARDS do
            if b.wall == "north" and b.y - b.h / 2 < L.DOOR.top then
                local clear = b.x - b.w / 2 >= L.DOOR.x + L.DOOR.halfWidth
                    or b.x + b.w / 2 <= L.DOOR.x - L.DOOR.halfWidth
                expect(clear).toBeTruthy()
            end
        end
    end)

    test("the clerestory band crosses the mouth, and is allowed to — it runs above the head", function()
        local band = byId("bandNorth")
        expect(band.x - band.w / 2 < L.DOOR.x).toBeTruthy()
        expect(band.x + band.w / 2 > L.DOOR.x).toBeTruthy()
        expect(band.y - band.h / 2 >= L.DOOR.top).toBeTruthy()
    end)

    test("no two boards on the same wall overlap", function()
        for i, a in L.BOARDS do
            for j, b in L.BOARDS do
                if j > i and a.wall == b.wall then
                    local aAxis = if a.wall == "north" or a.wall == "south" then a.x else a.z
                    local bAxis = if b.wall == "north" or b.wall == "south" then b.x else b.z
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
