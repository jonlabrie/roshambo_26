--!strict
local harness = require("./harness")
local Bonsho = require("../tools/builders/Bonsho")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local Spec = require("../tools/builders/Spec")
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
        local rest = Spec.rotY(L.shuMoku.restPos, L.shuMoku.yaw)
        for _, c in spec.children :: any do
            if c.name == "ShuMoku" then
                expect(c.properties.CFrame[1]).toBeCloseTo(rest[1], 0.001)
                expect(c.properties.CFrame[2]).toBeCloseTo(rest[2], 0.001)
                expect(c.properties.CFrame[3]).toBeCloseTo(rest[3], 0.001)
            end
        end
    end)
    test("ShuMoku is swung onto the SW axis (rest x<0 and z<0)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "ShuMoku" then
                expect(c.properties.CFrame[1] < 0).toBe(true)
                expect(c.properties.CFrame[3] < 0).toBe(true)
            end
        end
    end)
    test("the strike boss sits on the bell's SW face (x<0 and z<0)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "LotusBoss" then
                expect(c.properties.CFrame[1] < 0).toBe(true)
                expect(c.properties.CFrame[3] < 0).toBe(true)
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
