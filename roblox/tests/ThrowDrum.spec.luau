--!strict
local harness = require("./harness")
local ThrowDrum = require("../tools/builders/ThrowDrum")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function childNames(spec)
    local names = {}
    for _, c in spec.children :: any do
        names[c.name] = true
    end
    return names
end

describe("ThrowDrum mawari-dōrō builder", function()
    test("hub + 12 facets + 8 shade panels + 4 posts + hip roof/finial/base/lamp", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local names = childNames(spec)
        expect(names["Drum"]).toBe(true)
        for k = 0, 11 do
            expect(names["Face" .. k]).toBe(true)
        end
        for i = 1, 8 do
            expect(names["ShadePanel" .. i]).toBe(true) -- curve-hugging infill over the off-cardinal facets
        end
        for i = 1, 4 do
            expect(names["Post" .. i]).toBe(true)
        end
        expect(names["RoofFace1_1"]).toBe(true) -- miniature hip roof (Shoro wedge recipe)
        expect(names["HipStringer1"]).toBe(true)
        expect(names["Finial"]).toBe(true)
        expect(names["Base"]).toBe(true)
        expect(names["Lamp"]).toBe(true)
    end)

    test("exactly 12 facets, no leftover horizontal-drum parts", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        local faces, shafts, spokes = 0, 0, 0
        for _, c in spec.children :: any do
            if (c.name :: string):match("^Face%d+$") then
                faces += 1
            elseif c.name == "Shaft" then
                shafts += 1
            elseif (c.name :: string):match("^Spoke%d+$") then
                spokes += 1
            end
        end
        expect(faces).toBe(12)
        expect(shafts).toBe(0) -- vertical lantern: no horizontal axle
        expect(spokes).toBe(0)
    end)

    test("facets carry R,P,S repeated ×4 (k % 3)", function()
        local expected = { [0] = "R", [1] = "P", [2] = "S" }
        for k = 0, 11 do
            expect(ThrowDrum.SYMBOL_FOR_FACE[k]).toBe(expected[k % 3])
        end
    end)

    test("hub sits at the layout throwDrum position (centred over the roof)", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "Drum" then
                expect(math.abs(c.properties.CFrame[1] - L.throwDrum.pos[1]) < 0.01).toBe(true)
                expect(math.abs(c.properties.CFrame[2] - L.throwDrum.pos[2]) < 0.01).toBe(true)
                expect(math.abs(c.properties.CFrame[3] - L.throwDrum.pos[3]) < 0.01).toBe(true)
            end
        end
    end)

    test("facets use the CypressWeathered variant", function()
        local spec = ThrowDrum.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if (c.name :: string):match("^Face%d+$") then
                expect(c.properties.MaterialVariant).toBe("CypressWeathered")
            end
        end
    end)
end)
