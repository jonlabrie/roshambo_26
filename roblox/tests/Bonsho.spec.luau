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

describe("Shu-moku striker assembly (tower-hung, boss-height)", function()
    local STRIKE_Y = 120.7 -- tsuki-za LotusBoss centre, measured in place
    local spec = Bonsho.build(ZenDojo.palette, L)
    local byName = {}
    for _, c in spec.children :: any do
        byName[c.name] = c
    end
    test("the log rests at the boss strike height and the dowels ride with it", function()
        expect(math.abs(byName["ShuMoku"].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
        expect(math.abs(byName["ShuMokuDrawDowel"].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
        expect(math.abs(byName["ShuMokuDowel"].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
    end)
    test("the freestanding gantry is gone; the tower suspension exists", function()
        for _, c in spec.children :: any do
            expect(c.name:match("^Rail%d$")).toBeNil()
            expect(c.name:match("^GantryPost")).toBeNil()
            expect(c.name:match("^GantryBrace")).toBeNil()
        end
        expect(byName["HangerBeam"] ~= nil).toBe(true)
        expect(byName["Spreader1"] ~= nil).toBe(true)
        expect(byName["Spreader2"] ~= nil).toBe(true)
        for i = 1, 4 do
            expect(byName["RopeEye" .. i] ~= nil).toBe(true)
        end
        -- the hanger beam spans the two +Z pavilion posts, just under the ring beams
        local hb = byName["HangerBeam"].properties
        expect(hb.CFrame[2]).toBeCloseTo(L.shuMoku.hangerY, 0.001)
        expect(hb.Size[1] >= L.pavilion.postSpacing).toBe(true)
    end)
    test("the four hangers are hemp ropes dropping from the spreaders to the log", function()
        for i = 1, 4 do
            local ch = byName["Chain" .. i].properties
            expect(ch.Material).toBe("Fabric")
            expect(ch.MaterialVariant).toBe("HempRope")
            expect(ch.Size[2]).toBeCloseTo(0.35, 0.001)
            expect(ch.Size[1] > 9).toBe(true) -- long tower drop, not the old 6-stud gantry chain
        end
    end)
    test("the log is fully dressed: nose cap, bands, whipping, tail ring", function()
        expect(byName["ShuMokuD_Nose"].properties.MaterialVariant).toBe("BronzePatina")
        expect(byName["ShuMokuD_Band1"].properties.MaterialVariant).toBe("IronDark")
        expect(byName["ShuMokuD_Band2"].properties.MaterialVariant).toBe("IronDark")
        expect(byName["ShuMokuD_Whip1"].properties.MaterialVariant).toBe("HempRope")
        expect(byName["ShuMokuD_Whip2"].properties.MaterialVariant).toBe("HempRope")
        expect(byName["ShuMokuD_TailRing"].properties.MaterialVariant).toBe("IronDark")
        -- dress rings sit on the log's centreline height
        for _, n in { "ShuMokuD_Band1", "ShuMokuD_Whip1", "ShuMokuD_TailRing" } do
            expect(math.abs(byName[n].properties.CFrame[2] - STRIKE_Y) <= 0.1).toBe(true)
        end
    end)
end)
