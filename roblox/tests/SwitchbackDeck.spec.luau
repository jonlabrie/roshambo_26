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

    test("stands on 6 vertical posts with under-slab girders", function()
        expect(countPrefix(model, "Post_")).toBe(6)
        expect(countPrefix(model, "Girder") >= 3).toBe(true)
        -- posts are vertical (identity rotation): no StrutSE
        expect(find(model, "StrutSE")).toBe(nil)
    end)

    test("railing only on the East + South open-air edges, with balusters and newels", function()
        expect(find(model, "RailEastCap") ~= nil).toBe(true)
        expect(find(model, "RailSouthCap") ~= nil).toBe(true)
        expect(countPrefix(model, "RailNorth")).toBe(0)
        expect(countPrefix(model, "RailWest")).toBe(0)
        expect(countPrefix(model, "Baluster_") >= 6).toBe(true)
        expect(countPrefix(model, "Newel_") >= 2).toBe(true)
    end)
end)
