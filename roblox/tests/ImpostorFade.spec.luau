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

describe("ImpostorFade.edgeTransparency", function()
    test("edge-on card is hidden", function()
        expect(ImpostorFade.edgeTransparency(0)).toBe(1)
        expect(ImpostorFade.edgeTransparency(ImpostorFade.DEFAULT.edgeLo)).toBe(1)
    end)

    test("camera-facing card is fully shown", function()
        expect(ImpostorFade.edgeTransparency(ImpostorFade.DEFAULT.edgeHi)).toBe(0)
        expect(ImpostorFade.edgeTransparency(1)).toBe(0)
    end)

    test("ramp midpoint is half faded", function()
        local mid = (ImpostorFade.DEFAULT.edgeLo + ImpostorFade.DEFAULT.edgeHi) / 2
        expect(math.abs(ImpostorFade.edgeTransparency(mid) - 0.5) < 1e-6).toBe(true)
    end)
end)

describe("ImpostorFade.vertTransparency", function()
    test("facing card at eye level is fully shown", function()
        expect(ImpostorFade.vertTransparency(1, 0)).toBe(0)
    end)

    test("edge-on wins even at eye level", function()
        expect(ImpostorFade.vertTransparency(0, 0)).toBe(1)
    end)

    test("steep elevation fades even a facing card", function()
        expect(ImpostorFade.vertTransparency(1, ImpostorFade.DEFAULT.vertFadeHi)).toBe(1)
        local mid = (ImpostorFade.DEFAULT.vertFadeLo + ImpostorFade.DEFAULT.vertFadeHi) / 2
        expect(math.abs(ImpostorFade.vertTransparency(1, mid) - 0.5) < 1e-6).toBe(true)
    end)

    test("the stronger of the two fades governs", function()
        local mid = (ImpostorFade.DEFAULT.vertFadeLo + ImpostorFade.DEFAULT.vertFadeHi) / 2
        local edgeMid = (ImpostorFade.DEFAULT.edgeLo + ImpostorFade.DEFAULT.edgeHi) / 2
        local t = ImpostorFade.vertTransparency(edgeMid, mid)
        expect(math.abs(t - 0.5) < 1e-6).toBe(true)
    end)
end)

describe("ImpostorFade.planeNormal", function()
    test("plane 1 spans X so its normal points along Z", function()
        local n = ImpostorFade.planeNormal(1)
        expect(math.abs(n.x) < 1e-6).toBe(true)
        expect(math.abs(math.abs(n.z) - 1) < 1e-6).toBe(true)
    end)

    test("all three normals are unit length and 60 degrees apart", function()
        local a = ImpostorFade.planeNormal(1)
        local b = ImpostorFade.planeNormal(2)
        local dot = a.x * b.x + a.z * b.z
        expect(math.abs(math.abs(dot) - 0.5) < 1e-6).toBe(true)
    end)
end)
