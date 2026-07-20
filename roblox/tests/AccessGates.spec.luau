--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local AccessGates = require("../src/shared/AccessGates")
local SizeClasses = require("../src/shared/SizeClasses")

-- identity deck at the world origin: deck-local axes == world axes
local IDENTITY = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }

describe("AccessGates.deckBackGate", function()
    test("spans the full deck width at the +Z back edge", function()
        local fp = SizeClasses.deckFootprint("S")
        local g = AccessGates.deckBackGate(IDENTITY, "S")
        -- width = full deck width; thickness + height are the sealing wall
        expect(g.size[1]).toBeCloseTo(fp.maxX - fp.minX)
        expect(g.size[2]).toBeCloseTo(AccessGates.GATE_H)
        expect(g.size[3]).toBeCloseTo(AccessGates.GATE_T)
        -- centered on X, half-height up, at the back edge z = maxZ
        expect(g.cframe[1]).toBeCloseTo(0)
        expect(g.cframe[2]).toBeCloseTo(AccessGates.GATE_H / 2)
        expect(g.cframe[3]).toBeCloseTo(fp.maxZ)
    end)
    test("is tall enough to seal (well above a jump)", function()
        expect(AccessGates.GATE_H >= 10).toBe(true)
    end)
end)

describe("AccessGates.evictionPoint", function()
    test("sits outside the back edge on the path side (+Z), at standing height", function()
        local fp = SizeClasses.deckFootprint("S")
        local e = AccessGates.evictionPoint(IDENTITY, "S")
        expect(e[1]).toBeCloseTo(0)
        expect(e[2]).toBeCloseTo(AccessGates.EVICT_Y)
        expect(e[3]).toBeCloseTo(fp.maxZ + AccessGates.EVICT_OUT)
    end)
end)
