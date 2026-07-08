--!strict
local harness = require("./harness")
local PadSiteFit = require("../src/shared/PadSiteFit")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

local IDENT = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 } -- axis-aligned mount at origin

local function rect(minX: number, minZ: number, maxX: number, maxZ: number)
    return { { minX, minZ }, { maxX, minZ }, { maxX, maxZ }, { minX, maxZ } }
end

describe("PadSiteFit.overlaps (SAT)", function()
    test("separated rects do not overlap", function()
        expect(PadSiteFit.overlaps(rect(0, 0, 2, 2), rect(3, 0, 5, 2))).toBe(false)
    end)
    test("overlapping rects overlap", function()
        expect(PadSiteFit.overlaps(rect(0, 0, 2, 2), rect(1, 1, 3, 3))).toBe(true)
    end)
    test("edge contact counts as overlap", function()
        expect(PadSiteFit.overlaps(rect(0, 0, 2, 2), rect(2, 0, 4, 2))).toBe(true)
    end)
    test("two 45-deg diamonds whose AABBs overlap but true OBBs do not -> false", function()
        local d1 = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } } -- unit diamond at origin (AABB x,z in [-1,1])
        local d2 = { { 1.5, 2.5 }, { 2.5, 1.5 }, { 1.5, 0.5 }, { 0.5, 1.5 } } -- diamond, AABB x,z in [0.5,2.5]
        expect(PadSiteFit.overlaps(d1, d2)).toBe(false) -- separated along (1,1); an AABB test would say true
    end)
end)

describe("PadSiteFit.footprintOBB", function()
    test("axis-aligned mount -> footprint corners verbatim", function()
        local obb = PadSiteFit.footprintOBB({ minX = -1, maxX = 2, minZ = -3, maxZ = 4 }, IDENT)
        expect(obb[1][1]).toBeCloseTo(-1)
        expect(obb[1][2]).toBeCloseTo(-3)
        expect(obb[3][1]).toBeCloseTo(2)
        expect(obb[3][2]).toBeCloseTo(4)
    end)
    test("90-deg-yaw mount rotates corners", function()
        -- yaw 90: local X -> world +Z, local Z -> world -X (worldX = -lz, worldZ = lx)
        local yaw90 = { 0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }
        local obb = PadSiteFit.footprintOBB({ minX = 0, maxX = 2, minZ = 0, maxZ = 0 }, yaw90)
        expect(obb[2][1]).toBeCloseTo(0) -- (maxX=2, minZ=0) -> worldX = -0 = 0
        expect(obb[2][2]).toBeCloseTo(2) -- worldZ = lx = 2
    end)
end)

describe("PadSiteFit.spacingMax", function()
    test("no keep-outs -> L", function()
        expect(PadSiteFit.spacingMax(IDENT, {})).toBe("L")
    end)
    test("a keep-out clear of M but inside L -> M", function()
        -- M maxX = 15*1.5 = 22.5; L maxX = 15*2 = 30. A rect at x[23,28] hits L, misses M.
        expect(PadSiteFit.spacingMax(IDENT, { rect(23, -5, 28, 5) })).toBe("M")
    end)
    test("a keep-out over the origin collides with every size -> nil", function()
        expect(PadSiteFit.spacingMax(IDENT, { rect(-1, -1, 1, 1) })).toBe(nil)
    end)
    test("a rotated keep-out an AABB would hit does not shrink the pad", function()
        -- diamond far off the +X footprint edge; its AABB grazes but the OBB is clear of L
        local far = { { 40, 1 }, { 41, 0 }, { 40, -1 }, { 39, 0 } }
        expect(PadSiteFit.spacingMax(IDENT, { far })).toBe("L")
    end)
end)

describe("PadSiteFit.isLevel", function()
    test("a yaw-only mount is level", function()
        expect(PadSiteFit.isLevel({ 0, 0, 0, 0.6, 0, -0.8, 0, 1, 0, 0.8, 0, 0.6 }, 1e-6)).toBe(true)
    end)
    test("a pitched mount is not level", function()
        expect(PadSiteFit.isLevel({ 0, 0, 0, 1, 0, 0, 0.3, 0.95, 0, 0, 0, 1 }, 1e-6)).toBe(false)
    end)
    test("sub-tolerance pitch noise reads as level", function()
        expect(PadSiteFit.isLevel({ 0, 0, 0, 1, 0, 0, 1e-9, 1, 1e-9, 0, 0, 1 }, 1e-6)).toBe(true)
    end)
end)

describe("PadSiteFit.normalizeYaw", function()
    test("flattens pitch noise to pure yaw, preserving position and yaw", function()
        -- Input has yaw (cos≈0.9754, sin≈-0.2204) with pitch noise; normalized: (0.9754091, -0.2204022)
        local noisy = { 5, 6, 7, 0.9754091, 0, 0.2204022, 3e-4, 1, -2e-4, -0.2204022, 1e-4, 0.9754091 }
        local out = PadSiteFit.normalizeYaw(noisy)
        expect(PadSiteFit.isLevel(out, 1e-9)).toBe(true)
        expect(out[1]).toBeCloseTo(5) -- position preserved
        expect(out[2]).toBeCloseTo(6)
        expect(out[3]).toBeCloseTo(7)
        expect(out[4]).toBeCloseTo(0.9754091) -- yaw preserved (cos)
        expect(out[6]).toBeCloseTo(0.2204022) -- yaw preserved (sin)
    end)
    test("an already-level mount is unchanged", function()
        local lvl = { 0, 0, 0, 0.6, 0, -0.8, 0, 1, 0, 0.8, 0, 0.6 }
        local out = PadSiteFit.normalizeYaw(lvl)
        for i = 1, 12 do
            expect(out[i]).toBeCloseTo(lvl[i])
        end
    end)
    test("renormalizes a grossly non-unit local-X (3,4) to a unit yaw axis", function()
        -- fx=3, fz=4 -> len=5 -> ex=0.6, ez=0.8; proves the /len divide runs
        local out = PadSiteFit.normalizeYaw({ 0, 0, 0, 3, 0, 0, 0, 1, 0, 4, 0, 0 })
        expect(out[4]).toBeCloseTo(0.6) -- ex
        expect(out[10]).toBeCloseTo(0.8) -- ez
        expect(out[6]).toBeCloseTo(-0.8) -- -ez
        expect(out[12]).toBeCloseTo(0.6) -- ex
        expect(PadSiteFit.isLevel(out, 1e-9)).toBe(true)
    end)
end)

describe("PadSiteFit.resolveMaxSize", function()
    test("returns the smaller of two sizes by rank", function()
        expect(PadSiteFit.resolveMaxSize("L", "M")).toBe("M")
        expect(PadSiteFit.resolveMaxSize("S", "L")).toBe("S")
        expect(PadSiteFit.resolveMaxSize("M", "M")).toBe("M")
    end)
end)
