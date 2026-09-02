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
        local cf = BuildingPlacer.placeCF({ offset = { 3, -4 }, facing = "N" })
        expect(cf[1]).toBeCloseTo(3) -- x
        expect(cf[2]).toBeCloseTo(0) -- y
        expect(cf[3]).toBeCloseTo(-4) -- z
        expect(cf[4]).toBeCloseTo(1) -- R00 (no yaw)
        expect(cf[12]).toBeCloseTo(1) -- R22
    end)
    test("facing E is a +90deg yaw (R13 = sin90 = 1)", function()
        local cf = BuildingPlacer.placeCF({ offset = { 0, 0 }, facing = "E" })
        expect(cf[6]).toBeCloseTo(1) -- R02 = sin(90)
        expect(cf[10]).toBeCloseTo(-1) -- R20 = -sin(90)
    end)
end)

describe("BuildingPlacer.fits", function()
    local deck = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } -- S deck 26x20
    local bldg = { minX = -9.35, maxX = 9.35, minZ = -6.35, maxZ = 6.35 } -- ~18.7x12.7 centered
    test("centered, facing N, fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = { 0, 0 }, facing = "N" })).toBe(true)
    end)
    test("tucked to a corner (leaving engawa) still fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = { 3.6, 3.6 }, facing = "N" })).toBe(true)
    end)
    test("overhanging the +X edge does not fit", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = { 5, 0 }, facing = "N" })).toBe(false)
    end)
    test("facing E swaps the building's X/Z extents; 18.7-wide across the 20-deep deck fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = { 0, 0 }, facing = "E" })).toBe(true)
    end)
    test("facing N with an 18.7-deep building on a 20-deep deck barely fits but not offset", function()
        local tall = { minX = -6.35, maxX = 6.35, minZ = -9.35, maxZ = 9.35 }
        expect(BuildingPlacer.fits(tall, deck, { offset = { 0, 2 }, facing = "N" })).toBe(false)
    end)
end)

describe("BuildingPlacer.clamp", function()
    -- building 12x6 (half 6x3) on a deck 26x20 (SizeClasses S-deck shape)
    local B = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 }
    local D = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 }

    test("in-bounds placement is returned unchanged", function()
        local p = BuildingPlacer.clamp(B, D, { offset = { 2, -4 }, facing = "N" })
        expect(p.offset[1]).toBe(2)
        expect(p.offset[2]).toBe(-4)
        expect(p.facing).toBe("N")
    end)
    test("slides the minimum distance back into bounds per axis", function()
        -- x max legal = 13 - 6 = 7; z min legal = -10 + 3 = -7
        local p = BuildingPlacer.clamp(B, D, { offset = { 11, -9 }, facing = "N" })
        expect(p.offset[1]).toBe(7)
        expect(p.offset[2]).toBe(-7)
    end)
    test("rotated facings swap the half-extents", function()
        -- facing E: halfX becomes 3, halfZ becomes 6 -> x legal to 10, z legal to 4
        local p = BuildingPlacer.clamp(B, D, { offset = { 12, 9 }, facing = "E" })
        expect(p.offset[1]).toBe(10)
        expect(p.offset[2]).toBe(4)
        expect(p.facing).toBe("E")
    end)
    test("clamped result always fits", function()
        local p = BuildingPlacer.clamp(B, D, { offset = { 99, -99 }, facing = "W" })
        expect(BuildingPlacer.fits(B, D, p)).toBe(true)
    end)
    test("degenerate axis (building wider than deck) centers that axis", function()
        local wide = { minX = -30, maxX = 30, minZ = -3, maxZ = 3 }
        local p = BuildingPlacer.clamp(wide, D, { offset = { 5, 2 }, facing = "N" })
        expect(p.offset[1]).toBe(0) -- centered on the too-narrow axis
        expect(p.offset[2]).toBe(2) -- other axis untouched (in bounds)
    end)
end)

describe("BuildingPlacer.canFitFacing", function()
    test("N and E both fit within a roomy bounds", function()
        local bldg = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 } -- 12x6
        local bounds = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } -- 26x20
        expect(BuildingPlacer.canFitFacing(bldg, bounds, "N")).toBe(true)
        expect(BuildingPlacer.canFitFacing(bldg, bounds, "E")).toBe(true)
    end)
    test("the swap matters: a long-thin building fits N but not E in tight-depth bounds", function()
        local bldg = { minX = -10, maxX = 10, minZ = -2, maxZ = 2 } -- 20 wide x 4 deep
        local bounds = { minX = -11, maxX = 11, minZ = -3, maxZ = 3 } -- 22 wide x 6 deep
        expect(BuildingPlacer.canFitFacing(bldg, bounds, "N")).toBe(true)
        expect(BuildingPlacer.canFitFacing(bldg, bounds, "E")).toBe(false)
    end)
end)

describe("BuildingPlacer.resolveFit", function()
    local D = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } -- S deck 26x20

    test("in-bounds requested placement is returned as-is", function()
        local B = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 } -- 12x6
        local p = BuildingPlacer.resolveFit(B, D, { offset = { 2, -4 }, facing = "N" })
        expect(p ~= nil).toBe(true)
        expect((p :: any).offset[1]).toBe(2)
        expect((p :: any).offset[2]).toBe(-4)
        expect((p :: any).facing).toBe("N")
    end)

    test("a stored placement that no longer fits gets clamped back in, facing preserved", function()
        local B = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 } -- 12x6
        local p = BuildingPlacer.resolveFit(B, D, { offset = { 99, -99 }, facing = "N" })
        expect(p ~= nil).toBe(true)
        expect(BuildingPlacer.fits(B, D, p :: any)).toBe(true)
        expect((p :: any).facing).toBe("N")
    end)

    test("a facing that still doesn't fit after clamping falls back to N, re-clamped", function()
        -- long-thin building: fits facing N, but facing E swaps the extents onto axes the
        -- (tight-depth) deck cannot hold at ANY offset -- same fixture as the
        -- BuildingPlacer.canFitFacing "the swap matters" case above.
        local long = { minX = -10, maxX = 10, minZ = -2, maxZ = 2 } -- 20 wide x 4 deep
        local tight = { minX = -11, maxX = 11, minZ = -3, maxZ = 3 } -- 22 wide x 6 deep
        expect(BuildingPlacer.canFitFacing(long, tight, "N")).toBe(true)
        expect(BuildingPlacer.canFitFacing(long, tight, "E")).toBe(false)
        local p = BuildingPlacer.resolveFit(long, tight, { offset = { 0, 0 }, facing = "E" })
        expect(p ~= nil).toBe(true)
        expect((p :: any).facing).toBe("N")
        expect(BuildingPlacer.fits(long, tight, p :: any)).toBe(true)
    end)

    test("nothing fits (building wider on every axis than the deck, even at N): nil", function()
        local huge = { minX = -50, maxX = 50, minZ = -50, maxZ = 50 }
        local p = BuildingPlacer.resolveFit(huge, D, { offset = { 0, 0 }, facing = "N" })
        expect(p).toBe(nil)
    end)
end)

describe("BuildingPlacer.footprintBounds", function()
    local B = { minX = -6, maxX = 6, minZ = -3, maxZ = 3 } -- 12 x 6, centered
    test("facing N centers the AABB at the offset with the base half-extents", function()
        local b = BuildingPlacer.footprintBounds(B, { offset = { 2, -4 }, facing = "N" })
        expect(b.minX).toBeCloseTo(-4)
        expect(b.maxX).toBeCloseTo(8)
        expect(b.minZ).toBeCloseTo(-7)
        expect(b.maxZ).toBeCloseTo(-1)
    end)
    test("facing E swaps the half-extents (halfX<->halfZ)", function()
        local b = BuildingPlacer.footprintBounds(B, { offset = { 0, 0 }, facing = "E" })
        expect(b.minX).toBeCloseTo(-3)
        expect(b.maxX).toBeCloseTo(3)
        expect(b.minZ).toBeCloseTo(-6)
        expect(b.maxZ).toBeCloseTo(6)
    end)
end)
