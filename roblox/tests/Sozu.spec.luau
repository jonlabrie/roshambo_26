--!strict
local harness = require("./harness")
local Sozu = require("../tools/builders/Sozu")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Sozu builder", function()
    test("has a Lever and a Pivot at the layout pivot", function()
        local spec = Sozu.build(ZenDojo.palette, L)
        local names: { [string]: boolean } = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Lever"]).toBe(true)
        expect(names["Pivot"]).toBe(true)
    end)
    test("the lever sits at the streamside pivot height", function()
        local spec = Sozu.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "Lever" then
                expect(math.abs(c.properties.CFrame[1] - L.sozu.pivot[1]) < L.sozu.troughLen).toBe(true)
            end
        end
    end)
end)
