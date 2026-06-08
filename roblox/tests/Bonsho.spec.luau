--!strict
local harness = require("./harness")
local Bonsho = require("../tools/builders/Bonsho")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Bonsho builder", function()
    test("contains the two controller-contract parts: Bonsho and ShuMoku", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        expect(names["Bonsho"]).toBe(true)
        expect(names["ShuMoku"]).toBe(true)
    end)
    test("ShuMoku rest position matches layout", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "ShuMoku" then
                expect(c.properties.CFrame[3]).toBe(L.shuMoku.restPos[3])
            end
        end
    end)
    test("bell sections widen toward the skirt", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local radii = {}
        for _, c in spec.children :: any do
            local i = c.name:match("^BellSection(%d)$")
            if i then
                radii[tonumber(i) :: number] = c.properties.Size[2]
            end
        end
        expect(radii[1] > radii[3]).toBe(true)
    end)
end)
