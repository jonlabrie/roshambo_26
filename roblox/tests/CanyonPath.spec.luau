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
