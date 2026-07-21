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
    test("ShuMoku draws on the clearing axis (+Z, near the centreline)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name == "ShuMoku" then
                expect(c.properties.CFrame[3] > 0).toBe(true) -- draws toward +Z
                expect(math.abs(c.properties.CFrame[1]) < 8).toBe(true) -- near centreline
            end
        end
    end)
    test("emits two obi band-rings; the cast-bronze meshes ship via .rbxmx (not the builder)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local names = {}
        for _, c in spec.children :: any do
            names[c.name] = true
        end
        -- BellBody/Ryuzu/LotusBoss live in assets/meshes/BonshoBell.rbxmx (Rojo can't load
        -- mesh geometry from a MeshId in JSON), so the builder must NOT emit them.
        expect(names["BellBody"]).toBeNil()
        expect(names["BellSection1"]).toBeNil()
        expect(names["LotusBoss"]).toBeNil()
        expect(names["Band1"]).toBe(true)
        expect(names["Band2"]).toBe(true)
    end)
end)

describe("Bonsho dowel + gantry", function()
    test("emits a ShuMokuDowel peg", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        local found = false
        for _, c in spec.children :: any do
            if c.name == "ShuMokuDowel" then
                found = true
            end
        end
        expect(found).toBe(true)
    end)
    test("gantry rail is no longer than the shu-moku draw needs (<= 9 studs)", function()
        local spec = Bonsho.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            if c.name:match("^Rail%d$") then
                expect(c.properties.Size[3] <= 9).toBe(true)
            end
        end
    end)
end)
