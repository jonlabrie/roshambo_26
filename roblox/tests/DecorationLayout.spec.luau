--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local DecorationLayout = require("../src/shared/DecorationLayout")

-- deck 26 x 20 (SizeClasses S-deck shape)
local DECK = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 }

describe("DecorationLayout.resolve", function()
    test("bare deck (nil teahouseFP): everything visible, order preserved", function()
        local out = DecorationLayout.resolve(DECK, nil, {
            { id = 1, propId = "bonsai", offset = { 0, 0 }, facing = "N" },
            { id = 2, propId = "bench", offset = { 4, 4 }, facing = "N" },
        })
        expect(#out).toBe(2)
        expect(out[1].id).toBe(1)
        expect(out[1].visible).toBe(true)
        expect(out[2].id).toBe(2)
        expect(out[2].visible).toBe(true)
    end)

    test("clamps an off-deck offset back onto the deck (stored input untouched)", function()
        local input = { { id = 1, propId = "bonsai", offset = { 99, 0 }, facing = "N" } }
        local out = DecorationLayout.resolve(DECK, nil, input)
        -- bonsai half 0.75; x max legal = 13 - 0.75 = 12.25
        expect(out[1].offset[1]).toBeCloseTo(12.25)
        expect(input[1].offset[1]).toBe(99) -- input not mutated
    end)

    test("a prop under the teahouse footprint is hidden; one clear of it stays visible", function()
        local teahouseFP = { minX = -6, maxX = 6, minZ = -4, maxZ = 4 }
        local out = DecorationLayout.resolve(DECK, teahouseFP, {
            { id = 1, propId = "bonsai", offset = { 0, 0 }, facing = "N" }, -- inside -> hidden
            { id = 2, propId = "bonsai", offset = { 10, 0 }, facing = "N" }, -- clear -> visible
        })
        expect(out[1].visible).toBe(false)
        expect(out[2].visible).toBe(true)
    end)

    test("edge-touch is NOT overlap (visible)", function()
        -- bonsai half 0.75 at x=6.75 spans [6.0, 7.5]; teahouse maxX=6 -> touch at x=6, no overlap
        local teahouseFP = { minX = -6, maxX = 6, minZ = -4, maxZ = 4 }
        local out = DecorationLayout.resolve(DECK, teahouseFP, {
            { id = 1, propId = "bonsai", offset = { 6.75, 0 }, facing = "N" },
        })
        expect(out[1].visible).toBe(true)
    end)

    test("rotation is honored in the overlap test (bench facing E is deep, not wide)", function()
        -- bench 4x1.5 (half 2 x 0.75). Facing E swaps -> half 0.75 x 2, spanning z in [-2,2].
        -- teahouse occupies z in [-4,4]; a bench at (10, 3) facing E spans z [1,5], x [9.25,10.75].
        -- teahouse spans x [-6,6] so no x-overlap -> visible regardless of z.
        local teahouseFP = { minX = -6, maxX = 6, minZ = -4, maxZ = 4 }
        local out = DecorationLayout.resolve(DECK, teahouseFP, {
            { id = 1, propId = "bench", offset = { 10, 3 }, facing = "E" },
        })
        expect(out[1].visible).toBe(true)
    end)

    test("unknown propIds are skipped", function()
        local out = DecorationLayout.resolve(DECK, nil, {
            { id = 1, propId = "dragon", offset = { 0, 0 }, facing = "N" },
            { id = 2, propId = "bench", offset = { 0, 0 }, facing = "N" },
        })
        expect(#out).toBe(1)
        expect(out[1].id).toBe(2)
    end)
end)
