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

describe("AccessGates.deckPerimeter", function()
    test("returns four sealing walls around the footprint", function()
        local fp = SizeClasses.deckFootprint("S")
        local walls = AccessGates.deckPerimeter(IDENTITY, "S")
        expect(#walls).toBe(4)
        local width = fp.maxX - fp.minX
        local depth = fp.maxZ - fp.minZ
        -- [1] back (+Z), [2] front (-Z): span the full width, sealing height + thickness
        expect(walls[1].cframe[3]).toBeCloseTo(fp.maxZ)
        expect(walls[1].size[1]).toBeCloseTo(width)
        expect(walls[1].size[2]).toBeCloseTo(AccessGates.GATE_H)
        expect(walls[1].size[3]).toBeCloseTo(AccessGates.GATE_T)
        expect(walls[2].cframe[3]).toBeCloseTo(fp.minZ)
        expect(walls[2].size[1]).toBeCloseTo(width)
        -- [3] right (+X), [4] left (-X): thin, span the depth plus corner overlap
        expect(walls[3].cframe[1]).toBeCloseTo(fp.maxX)
        expect(walls[3].size[1]).toBeCloseTo(AccessGates.GATE_T)
        expect(walls[3].size[3]).toBeCloseTo(depth + 2 * AccessGates.GATE_T)
        expect(walls[4].cframe[1]).toBeCloseTo(fp.minX)
        -- every wall is raised half-height
        for _, w in walls do
            expect(w.cframe[2]).toBeCloseTo(AccessGates.GATE_H / 2)
        end
    end)
end)

describe("AccessGates.revealRadius", function()
    test("covers the footprint corner plus the reveal margin", function()
        local fp = SizeClasses.deckFootprint("S")
        local halfDiag = math.sqrt(fp.maxX * fp.maxX + fp.maxZ * fp.maxZ)
        expect(AccessGates.revealRadius("S")).toBeCloseTo(halfDiag + AccessGates.REVEAL_MARGIN)
        expect(AccessGates.revealRadius("S") > halfDiag).toBe(true)
    end)
end)

describe("AccessGates.navLights", function()
    test("two lights, one at each front-corner newel (-Z) near the top", function()
        local fp = SizeClasses.deckFootprint("S")
        local lights = AccessGates.navLights(IDENTITY, "S")
        expect(#lights).toBe(2)
        -- right (+X) and left (-X) front corners, both on the front edge (-Z) at nav height
        expect(lights[1].cframe[1]).toBeCloseTo(fp.maxX - AccessGates.NAV_X_INSET)
        expect(lights[1].cframe[3]).toBeCloseTo(fp.minZ)
        expect(lights[2].cframe[1]).toBeCloseTo(fp.minX + AccessGates.NAV_X_INSET)
        expect(lights[2].cframe[3]).toBeCloseTo(fp.minZ)
        expect(lights[1].cframe[2]).toBeCloseTo(AccessGates.NAV_Y)
        expect(AccessGates.NAV_Y < 2.75).toBe(true) -- below the newel/cap top
        expect(lights[1].size[1]).toBeCloseTo(AccessGates.NAV_W)
    end)
end)
