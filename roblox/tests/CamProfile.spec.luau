--!strict
local harness = require("./harness")
local CamProfile = require("../src/shared/CamProfile")
local describe, test, expect = harness.describe, harness.test, harness.expect

local G = { gapZ = 3, draw = 4.06, rise = 0.9, dowelR = 0.25, dropDeg = 12, strikeP = 0.88 }

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
    test("samples: base arc then rising locus, angle decreasing to the cliff at 0", function()
        -- locus construction (round-metronome): 8+1 base-arc points at rest radius,
        -- then n draw-locus points ending at the cliff (local angle exactly 0)
        local s = CamProfile.samples(G, 40)
        expect(#s).toBe(9 + 40)
        for i = 2, #s do
            expect(s[i].r >= s[i - 1].r).toBe(true)
            expect(s[i].deg < s[i - 1].deg).toBe(true)
        end
        expect(s[1].deg).toBeCloseTo(360 - G.dropDeg, 0.001) -- base arc starts behind the drop wall
        expect(s[1].r).toBeCloseTo(select(1, CamProfile.contact(0, G)), 0.001)
        expect(s[#s].deg).toBeCloseTo(0, 0.001) -- the cliff sits AT the anchor azimuth
        expect(s[#s].r).toBeCloseTo(select(1, CamProfile.contact(G.strikeP or 1, G)), 0.001)
    end)
end)
