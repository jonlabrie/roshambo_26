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

describe("SwitchbackDeck", function()
    test("builds a WoodPlanks deck slab at deck-top 138", function()
        local slab = find(model, "DeckSlab")
        expect(slab ~= nil).toBe(true)
        expect(slab.properties.Material).toBe("WoodPlanks")
        -- slab top = center.Y + thickness/2 == 138
        expect(slab.properties.CFrame[2] + slab.properties.Size[2] / 2).toBe(138)
        -- footprint 12 (X) x 10 (Z)
        expect(slab.properties.Size[1]).toBe(12)
        expect(slab.properties.Size[3]).toBe(10)
    end)
end)
