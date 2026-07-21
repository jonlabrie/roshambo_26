--!strict
local harness = require("./harness")
local Glyphs = require("../src/shared/Glyphs")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Glyphs image map", function()
    test("exposes a core + outline image asset for each throw", function()
        for _, sym in { "R", "P", "S" } do
            local layers = Glyphs.IMAGE[sym]
            expect(layers ~= nil).toBe(true)
            expect(type(layers.core) == "string" and #layers.core > 0).toBe(true)
            expect(type(layers.outline) == "string" and #layers.outline > 0).toBe(true)
            expect(layers.core:match("^rbxassetid://") ~= nil).toBe(true)
            expect(layers.outline:match("^rbxassetid://") ~= nil).toBe(true)
        end
    end)

    test("core and outline are distinct assets", function()
        for _, sym in { "R", "P", "S" } do
            expect(Glyphs.IMAGE[sym].core ~= Glyphs.IMAGE[sym].outline).toBe(true)
        end
    end)
end)
