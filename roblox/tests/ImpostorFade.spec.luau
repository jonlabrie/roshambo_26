--!strict
local harness = require("./harness")
local ImpostorFade = require("../src/shared/ImpostorFade")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ImpostorFade.elevation", function()
    test("level with the anchor is zero degrees", function()
        expect(ImpostorFade.elevation(0, 20)).toBe(0)
    end)

    test("equal rise and run is 45 degrees", function()
        expect(math.abs(ImpostorFade.elevation(10, 10) - 45) < 1e-6).toBe(true)
    end)

    test("below the anchor is negative", function()
        expect(ImpostorFade.elevation(-10, 10) < 0).toBe(true)
    end)

    test("directly overhead is 90 degrees", function()
        expect(math.abs(ImpostorFade.elevation(10, 0) - 90) < 1e-6).toBe(true)
    end)
end)

describe("ImpostorFade.capTransparency", function()
    -- LocalTransparencyModifier semantics: 1 = hidden, 0 = fully shown.
    test("caps hidden at eye level", function()
        expect(ImpostorFade.capTransparency(0)).toBe(1)
        expect(ImpostorFade.capTransparency(ImpostorFade.DEFAULT.capFadeLo)).toBe(1)
    end)

    test("caps fully shown from high vantage", function()
        expect(ImpostorFade.capTransparency(ImpostorFade.DEFAULT.capFadeHi)).toBe(0)
        expect(ImpostorFade.capTransparency(89)).toBe(0)
    end)

    test("midpoint of the ramp is half faded", function()
        local mid = (ImpostorFade.DEFAULT.capFadeLo + ImpostorFade.DEFAULT.capFadeHi) / 2
        expect(math.abs(ImpostorFade.capTransparency(mid) - 0.5) < 1e-6).toBe(true)
    end)

    test("custom band is respected", function()
        local cfg = { capFadeLo = 10, capFadeHi = 20 }
        expect(ImpostorFade.capTransparency(10, cfg)).toBe(1)
        expect(ImpostorFade.capTransparency(20, cfg)).toBe(0)
        expect(math.abs(ImpostorFade.capTransparency(15, cfg) - 0.5) < 1e-6).toBe(true)
    end)

    test("a degenerate band (hi <= lo) snaps rather than dividing by zero", function()
        local cfg = { capFadeLo = 30, capFadeHi = 30 }
        expect(ImpostorFade.capTransparency(29, cfg)).toBe(1)
        expect(ImpostorFade.capTransparency(31, cfg)).toBe(0)
    end)
end)
