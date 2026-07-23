--!strict
local harness = require("./harness")
local CamProfile = require("../src/shared/CamProfile")
local describe, test, expect = harness.describe, harness.test, harness.expect

local G = { gapZ = 3, draw = 4.06, rise = 0.9, dowelR = 0.25, dropDeg = 12 }

describe("CamProfile (analytic snail flank)", function()
    test("contact at rest is the base radius, dead ahead", function()
        local r, az = CamProfile.contact(0, G)
        expect(r).toBeCloseTo(3 - 0.25, 0.001) -- gapZ - dowelR = 2.75
        expect(az).toBeCloseTo(0, 0.001)
    end)
    test("contact at full draw reaches the lobe, tilted up by the pendulum rise", function()
        local r, az = CamProfile.contact(1, G)
        expect(r).toBeCloseTo(math.sqrt(7.06 ^ 2 + 0.9 ^ 2) - 0.25, 0.001) -- ≈ 6.867
        expect(az).toBeCloseTo(math.deg(math.atan2(0.9, 7.06)), 0.001) -- ≈ 7.26
    end)
    test("samples: radius monotonic, angle decreasing to the cliff, count honoured", function()
        local s = CamProfile.samples(G, 40)
        expect(#s).toBe(41)
        for i = 2, #s do
            expect(s[i].r > s[i - 1].r).toBe(true)
            expect(s[i].deg < s[i - 1].deg).toBe(true)
        end
        expect(s[1].deg).toBeCloseTo(360 - G.dropDeg, 0.001) -- rest contact sits just behind a full turn
        local _, az1 = CamProfile.contact(1, G)
        expect(s[#s].deg).toBeCloseTo(az1, 0.001) -- the flank ends at the tilted release azimuth
    end)
end)
