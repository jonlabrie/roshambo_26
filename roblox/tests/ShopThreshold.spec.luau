--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShopThreshold = require("../src/shared/ShopThreshold")

local function v(x: number, y: number, z: number)
    return { x = x, y = y, z = z }
end

-- 花火屋's volume: the owner's footprint, with the front edge inset one stud past the frontage.
local SHOP = { x0 = -1.67, x1 = 16.26, y0 = 113.1, y1 = 118.0, z0 = 45.0, z1 = 52.0 }

describe("ShopThreshold", function()
    test("a player standing in the middle of the shop is inside", function()
        expect(ShopThreshold.isInside(v(7, 114, 48), SHOP)).toBe(true)
    end)

    test("THE PROMENADE IS NOT THE SHOP", function()
        -- The whole reason the volume starts at z45 rather than the z44 frontage: a trigger on
        -- the frontage line fires on every player crossing the square.
        expect(ShopThreshold.isInside(v(7, 114, 44.5), SHOP)).toBe(false)
        expect(ShopThreshold.isInside(v(7, 114, 36), SHOP)).toBe(false)
    end)

    test("the front inset is exactly one stud", function()
        expect(ShopThreshold.FRONT_INSET).toBe(1)
    end)

    test("walking off either end leaves the shop", function()
        expect(ShopThreshold.isInside(v(-2.5, 114, 48), SHOP)).toBe(false)
        expect(ShopThreshold.isInside(v(17, 114, 48), SHOP)).toBe(false)
    end)

    test("walking through the back wall leaves the shop", function()
        expect(ShopThreshold.isInside(v(7, 114, 53), SHOP)).toBe(false)
    end)

    test("height is bounded, so standing on the roof is not shopping", function()
        expect(ShopThreshold.isInside(v(7, 126, 48), SHOP)).toBe(false)
        expect(ShopThreshold.isInside(v(7, 110, 48), SHOP)).toBe(false)
    end)

    test("the bounds are inclusive at their faces", function()
        expect(ShopThreshold.isInside(v(-1.67, 113.1, 45.0), SHOP)).toBe(true)
        expect(ShopThreshold.isInside(v(16.26, 118.0, 52.0), SHOP)).toBe(true)
    end)

    test("a degenerate box admits nothing", function()
        local empty = { x0 = 0, x1 = 0, y0 = 0, y1 = 0, z0 = 0, z1 = 0 }
        expect(ShopThreshold.isInside(v(1, 1, 1), empty)).toBe(false)
    end)
end)
