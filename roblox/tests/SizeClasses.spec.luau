--!strict
local harness = require("./harness")
local SizeClasses = require("../src/shared/SizeClasses")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("SizeClasses.footprintFor", function()
    test("S is the base footprint (scale 1.0)", function()
        local s = SizeClasses.footprintFor("S")
        expect(s.minX).toBeCloseTo(-7.40)
        expect(s.maxX).toBeCloseTo(15.00)
        expect(s.minZ).toBeCloseTo(-11.70)
        expect(s.maxZ).toBeCloseTo(4.32)
    end)

    test("L is 2x the base", function()
        local l = SizeClasses.footprintFor("L")
        expect(l.minX).toBeCloseTo(-14.80)
        expect(l.maxX).toBeCloseTo(30.00)
        expect(l.minZ).toBeCloseTo(-23.40)
        expect(l.maxZ).toBeCloseTo(8.64)
    end)

    test("scale values and order", function()
        expect(SizeClasses.scale.S).toBe(1.0)
        expect(SizeClasses.scale.M).toBe(1.5)
        expect(SizeClasses.scale.L).toBe(2.0)
        expect(SizeClasses.order[1]).toBe("L")
        expect(SizeClasses.order[3]).toBe("S")
    end)
end)

describe("SizeClasses.nativeSize", function()
    test("a base pad's native size is S", function()
        expect(SizeClasses.nativeSize(SizeClasses.footprintFor("S"))).toBe("S")
    end)

    test("a 2x-base pad's native size is L", function()
        expect(SizeClasses.nativeSize(SizeClasses.footprintFor("L"))).toBe("L")
    end)

    test("a pad smaller than S has no native size", function()
        expect(SizeClasses.nativeSize({ minX = -1, maxX = 1, minZ = -1, maxZ = 1 })).toBe(nil)
    end)
end)
