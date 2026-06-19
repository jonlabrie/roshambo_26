--!strict
local harness = require("./harness")
local CanyonPath = require("../tools/builders/CanyonPath")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("CanyonPath.classifySegment", function()
    test("gentle grade is a paver run", function()
        expect(CanyonPath.classifySegment({ 0, 10, 0 }, { 10, 11, 0 })).toBe("paver")
    end)
    test("steep grade is steps", function()
        expect(CanyonPath.classifySegment({ 0, 0, 0 }, { 2, 10, 0 })).toBe("steps")
    end)
    test("vertical/zero-run is steps", function()
        expect(CanyonPath.classifySegment({ 0, 0, 0 }, { 0, 10, 0 })).toBe("steps")
    end)
end)

describe("CanyonPath.placeAlong", function()
    local line = { { 0, 0, 0 }, { 60, 0, 0 } }
    test("interior samples every spacing, ends excluded", function()
        local s = CanyonPath.placeAlong(line, 20, false)
        expect(#s).toBe(2) -- at 20 and 40 (60 is not < total)
    end)
    test("includeEnds adds start and end", function()
        local s = CanyonPath.placeAlong(line, 20, true)
        expect(#s).toBe(4) -- 0, 20, 40, 60
    end)
    test("dir is the unit heading of the segment", function()
        local s = CanyonPath.placeAlong(line, 20, false)
        expect(s[1].dir[1]).toBeCloseTo(1)
        expect(s[1].dir[2]).toBeCloseTo(0)
    end)
    test("samples interpolate position", function()
        local s = CanyonPath.placeAlong(line, 20, false)
        expect(s[1].pos[1]).toBeCloseTo(20)
    end)
end)

local ZenDojo = require("../src/shared/themes/ZenDojo")

local function findPrefix(node, prefix)
    for _, c in node.children do
        if (c.name :: string):sub(1, #prefix) == prefix then
            return c
        end
    end
    return nil
end
local function anyLight(node)
    if not node.children then
        return false
    end
    for _, c in node.children do
        if c.className == "PointLight" then
            return true
        end
        if anyLight(c) then
            return true
        end
    end
    return false
end

describe("CanyonPath.build", function()
    local route = { name = "TestTrunk", class = "trunk", points = { { 0, 0, 0 }, { 40, 0, 0 }, { 40, 20, 40 } } }
    local m = CanyonPath.build(ZenDojo.palette, route)
    test("returns a Model", function()
        expect(m.className).toBe("Model")
    end)
    test("has an invisible colliding ramp per segment", function()
        local ramp = findPrefix(m, "Ramp")
        expect(ramp ~= nil).toBe(true)
        expect(ramp.properties.CanCollide).toBe(true)
        expect(ramp.properties.Transparency).toBe(1)
    end)
    test("trunk ramp is the trunk width", function()
        expect(findPrefix(m, "Ramp").properties.Size[3]).toBe(8)
    end)
    test("has rails", function()
        expect(findPrefix(m, "RailPost") ~= nil).toBe(true)
    end)
    test("has at least one lantern light", function()
        expect(anyLight(m)).toBe(true)
    end)
    test("spur class is narrower", function()
        local sm = CanyonPath.build(ZenDojo.palette, { name = "S", class = "spur", points = { { 0, 0, 0 }, { 40, 0, 0 } } })
        expect(findPrefix(sm, "Ramp").properties.Size[3]).toBe(5)
    end)
end)
