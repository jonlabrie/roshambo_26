--!strict
local harness = require("./harness")
local SwitchbackDeck = require("../tools/builders/SwitchbackDeck")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local model = SwitchbackDeck.build(ZenDojo.palette, ArenaLayout)

local function find(node, name)
    for _, c in node.children do
        if c.name == name then
            return c
        end
    end
    return nil
end

local function countPrefix(node, prefix)
    local n = 0
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            n += 1
        end
    end
    return n
end

describe("SwitchbackDeck", function()
    test("builds a WoodPlanks deck slab at deck-top 138.46", function()
        local slab = find(model, "DeckSlab")
        expect(slab ~= nil).toBe(true)
        expect(slab.properties.Material).toBe("WoodPlanks")
        -- slab top = center.Y + thickness/2 ~= 138.46
        expect(math.abs(slab.properties.CFrame[2] + slab.properties.Size[2] / 2 - 138.46) < 1e-4).toBe(true)
        -- footprint 18 (X) x 15 (Z)
        expect(slab.properties.Size[1]).toBe(18)
        expect(slab.properties.Size[3]).toBe(15)
    end)

    test("stands on >=5 vertical posts plus a raking SE strut, with under-slab girders", function()
        expect(countPrefix(model, "Post_") >= 5).toBe(true)
        expect(countPrefix(model, "Girder") >= 3).toBe(true)
        local strut = find(model, "StrutSE")
        expect(strut ~= nil).toBe(true)
        -- raking, not vertical: the strut's long axis (local X = rot col 1 = cf[4],cf[7],cf[10])
        -- is not world-X, so cf[4] (ux) is well below 1
        local cf = strut.properties.CFrame
        expect(math.abs(cf[4]) < 0.5).toBe(true)
    end)
end)
