--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local PadFrame = require("../src/shared/PadFrame")

local S = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 }

describe("PadFrame.nodes", function()
    test("6 nodes at the corners + mid-long-edges, inset by PH", function()
        local n = {}
        for _, node in PadFrame.nodes(S) do
            n[node.id] = node
        end
        expect(n.FL.x).toBeCloseTo(-13 + 0.6)
        expect(n.FL.z).toBeCloseTo(-10 + 0.6)
        expect(n.BR.x).toBeCloseTo(13 - 0.6)
        expect(n.BR.z).toBeCloseTo(10 - 0.6)
        expect(n.MF.x).toBeCloseTo(0)
        expect(n.MF.z).toBeCloseTo(-10 + 0.6)
    end)
end)

describe("PadFrame.beams", function()
    test("2 long + 3 short, tying the 6 nodes", function()
        local b = PadFrame.beams(S)
        expect(#b).toBe(5)
        local pairs_ = {}
        for _, beam in b do
            pairs_[beam.from .. "-" .. beam.to] = true
        end
        expect(pairs_["FL-FR"]).toBe(true) -- long front
        expect(pairs_["BL-BR"]).toBe(true) -- long back
        expect(pairs_["FL-BL"]).toBe(true) -- short left
        expect(pairs_["FR-BR"]).toBe(true) -- short right
        expect(pairs_["MF-MB"]).toBe(true) -- short middle
    end)
end)
