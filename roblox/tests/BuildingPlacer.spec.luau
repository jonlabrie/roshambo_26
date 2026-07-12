--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local BuildingPlacer = require("../src/shared/BuildingPlacer")

describe("BuildingPlacer.facingYaw", function()
    test("maps N/E/S/W to 0/90/180/270", function()
        expect(BuildingPlacer.facingYaw("N")).toBe(0)
        expect(BuildingPlacer.facingYaw("E")).toBe(90)
        expect(BuildingPlacer.facingYaw("S")).toBe(180)
        expect(BuildingPlacer.facingYaw("W")).toBe(270)
    end)
end)

describe("BuildingPlacer.placeCF", function()
    test("pure offset with facing N is identity rotation + translation", function()
        local cf = BuildingPlacer.placeCF({ offset = { 3, -4 }, facing = "N", openSide = "left" })
        expect(cf[1]).toBeCloseTo(3)  -- x
        expect(cf[2]).toBeCloseTo(0)  -- y
        expect(cf[3]).toBeCloseTo(-4) -- z
        expect(cf[4]).toBeCloseTo(1)  -- R00 (no yaw)
        expect(cf[12]).toBeCloseTo(1) -- R22
    end)
    test("facing E is a +90deg yaw (R13 = sin90 = 1)", function()
        local cf = BuildingPlacer.placeCF({ offset = { 0, 0 }, facing = "E", openSide = "left" })
        expect(cf[6]).toBeCloseTo(1)   -- R02 = sin(90)
        expect(cf[10]).toBeCloseTo(-1) -- R20 = -sin(90)
    end)
end)
