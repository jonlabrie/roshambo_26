--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local DeckPlacement = require("../src/shared/DeckPlacement")

local S_CF = { 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local L_CF = { 9, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local PLACEMENTS = { S = S_CF, L = L_CF }

describe("DeckPlacement.resolve", function()
    test("returns the requested size's placement when authored", function()
        expect(DeckPlacement.resolve(PLACEMENTS, "S", "L")).toBe(S_CF)
        expect(DeckPlacement.resolve(PLACEMENTS, "L", "L")).toBe(L_CF)
    end)
    test("falls back to maxSize when the requested size is unauthored", function()
        expect(DeckPlacement.resolve(PLACEMENTS, "M", "L")).toBe(L_CF) -- M unauthored -> L
    end)
    test("returns nil when neither the size nor maxSize is authored", function()
        expect(DeckPlacement.resolve({ S = S_CF }, "M", "L")).toBe(nil)
    end)
end)
