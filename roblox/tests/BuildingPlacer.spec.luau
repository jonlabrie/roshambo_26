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

describe("BuildingPlacer.fits", function()
    local deck = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } -- S deck 26x20
    local bldg = { minX = -9.35, maxX = 9.35, minZ = -6.35, maxZ = 6.35 } -- ~18.7x12.7 centered
    test("centered, facing N, fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {0,0}, facing = "N", openSide = "left" })).toBe(true)
    end)
    test("tucked to a corner (leaving engawa) still fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {3.6, 3.6}, facing = "N", openSide = "left" })).toBe(true)
    end)
    test("overhanging the +X edge does not fit", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {5, 0}, facing = "N", openSide = "left" })).toBe(false)
    end)
    test("facing E swaps the building's X/Z extents; 18.7-wide across the 20-deep deck fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {0,0}, facing = "E", openSide = "left" })).toBe(true)
    end)
    test("facing N with an 18.7-deep building on a 20-deep deck barely fits but not offset", function()
        local tall = { minX = -6.35, maxX = 6.35, minZ = -9.35, maxZ = 9.35 }
        expect(BuildingPlacer.fits(tall, deck, { offset = {0, 2}, facing = "N", openSide = "left" })).toBe(false)
    end)
end)
