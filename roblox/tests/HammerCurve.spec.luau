--!strict
local harness = require("./harness")
local HammerCurve = require("../src/shared/HammerCurve")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("HammerCurve", function()
    test("round start: hammer at rest, not latched", function()
        local s = HammerCurve.state("ACTIVE", 20)
        expect(s.angleDeg).toBe(0)
        expect(s.latched).toBe(false)
        expect(s.released).toBe(false)
    end)

    test("mid-round: halfway up the crank", function()
        -- crank runs over 18s (20 - 2 lockout lead); at secondsLeft 11, elapsed 9 -> p = 0.5
        local s = HammerCurve.state("ACTIVE", 11)
        expect(s.angleDeg).toBeCloseTo(50)
    end)

    test("at lockout: apex + latched", function()
        local s = HammerCurve.state("ACTIVE", 2)
        expect(s.angleDeg).toBe(100)
        expect(s.latched).toBe(true)
    end)

    test("TALLY: trembling at apex", function()
        local s = HammerCurve.state("TALLY", 1)
        expect(s.angleDeg).toBe(100)
        expect(s.trembling).toBe(true)
    end)

    test("REVEAL: released", function()
        local s = HammerCurve.state("REVEAL", 3)
        expect(s.released).toBe(true)
    end)
end)
