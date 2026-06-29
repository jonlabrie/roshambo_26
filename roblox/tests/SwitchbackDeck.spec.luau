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

    test("carries a single result-lantern (named *Lantern, Neon, one PointLight) + cap", function()
        local lit = 0
        for _, c in model.children do
            if c.children then
                for _, gc in c.children do
                    if gc.className == "PointLight" then
                        lit += 1
                    end
                end
            end
        end
        expect(lit).toBe(1)
        local lantern = find(model, "DeckLantern")
        expect(lantern ~= nil).toBe(true)
        expect(lantern.properties.Material).toBe("Neon")
        -- name must end in "Lantern" so LanternController paints the result SurfaceGui
        expect((lantern.name :: string):match("Lantern$") ~= nil).toBe(true)
        expect(find(model, "DeckLanternCap") ~= nil).toBe(true)
    end)

    test("has a 3-step Slate stair on stringers off the West-south edge, descending", function()
        local s1, s2, s3 = find(model, "Step1"), find(model, "Step2"), find(model, "Step3")
        expect(s1 ~= nil and s2 ~= nil and s3 ~= nil).toBe(true)
        expect(s1.properties.Material).toBe("Slate")
        -- treads descend in Y from the deck toward the foot
        expect(s1.properties.CFrame[2] > s2.properties.CFrame[2]).toBe(true)
        expect(s2.properties.CFrame[2] > s3.properties.CFrame[2]).toBe(true)
        expect(countPrefix(model, "Stringer") >= 2).toBe(true)
        -- publishes the descent's first route point, below the deck top
        expect(SwitchbackDeck.STAIR_FOOT[2] < 138.46).toBe(true)
    end)
end)
