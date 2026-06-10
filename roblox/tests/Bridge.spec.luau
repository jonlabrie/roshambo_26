--!strict
local harness = require("./harness")
local Bridge = require("../tools/builders/Bridge")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Bridge.arch", function()
    test("returns a deck, two rails and two abutment posts", function()
        local parts = Bridge.arch(ZenDojo.palette, { 0, 6, 0 }, { 0, 6, 10 }, 4, "X")
        local names = {}
        for _, p in parts do
            names[p.name] = true
        end
        expect(names["DeckX"]).toBe(true)
        expect(names["RailXL"]).toBe(true)
        expect(names["RailXR"]).toBe(true)
        expect(names["PostXA"]).toBe(true)
        expect(names["PostXB"]).toBe(true)
    end)

    test("the deck centre rises above the endpoints (camber)", function()
        local parts = Bridge.arch(ZenDojo.palette, { 0, 6, 0 }, { 0, 6, 10 }, 4, "Y")
        local deckY
        for _, p in parts do
            if p.name == "DeckY" then
                deckY = p.properties.CFrame[2]
            end
        end
        expect(deckY > 6).toBe(true)
    end)
end)
