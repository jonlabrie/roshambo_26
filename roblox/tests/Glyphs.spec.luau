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

describe("Glyphs day/night palette + API", function()
    test("PALETTE exposes gold/ink as 0-255 rgb arrays", function()
        for _, key in { "gold", "ink" } do
            local c = Glyphs.PALETTE[key]
            expect(c ~= nil).toBe(true)
            expect(#c).toBe(3)
            for _, ch in c do
                expect(ch >= 0 and ch <= 255).toBe(true)
            end
        end
    end)

    test("NIGHT has a valid 0-255 Neon color + a mesh id per symbol", function()
        local c = Glyphs.NIGHT.color
        expect(#c).toBe(3)
        for _, ch in c do
            expect(ch >= 0 and ch <= 255).toBe(true)
        end
        for _, sym in { "R", "P", "S" } do
            expect(Glyphs.NIGHT.mesh[sym]:match("^rbxassetid://%d+$") ~= nil).toBe(true)
        end
    end)

    test("renderDay + buildNightNeon are functions", function()
        expect(type(Glyphs.renderDay)).toBe("function")
        expect(type(Glyphs.buildNightNeon)).toBe("function")
    end)
end)
