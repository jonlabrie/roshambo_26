--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local VfxNightDim = require("../src/shared/VfxNightDim")

local function near(a: number, b: number): boolean
    return math.abs(a - b) < 1e-6
end

describe("VfxNightDim.scaleAt", function()
    test("day is a no-op — authored values pass through untouched", function()
        local s = VfxNightDim.scaleAt(0)
        expect(near(s.brightness, 1)).toBe(true)
        expect(near(s.lightEmission, 1)).toBe(true)
    end)

    test("night dims both channels but never extinguishes them", function()
        -- moonlit falls are the BRIGHTEST thing in a night canyon, not the dimmest;
        -- this is why the fix is not LightInfluence=1
        local s = VfxNightDim.scaleAt(1)
        expect(s.brightness > 0).toBe(true)
        expect(s.lightEmission > 0).toBe(true)
        expect(s.brightness < 1).toBe(true)
        expect(s.lightEmission < 1).toBe(true)
    end)

    test("LightEmission falls further than Brightness", function()
        -- LightEmission is what makes spray look self-lit, and self-lit is the specifically
        -- daytime quality; overall output should survive better than that
        local s = VfxNightDim.scaleAt(1)
        expect(s.lightEmission < s.brightness).toBe(true)
    end)

    test("nothing ever scales ABOVE authored — no brighter-than-daylight waterfall", function()
        for _, nf in { -3, -0.5, 0, 0.25, 0.5, 1, 4, 100 } do
            local s = VfxNightDim.scaleAt(nf)
            expect(s.brightness <= 1).toBe(true)
            expect(s.lightEmission <= 1).toBe(true)
        end
    end)

    test("clamped at both ends", function()
        local lo, under = VfxNightDim.scaleAt(0), VfxNightDim.scaleAt(-9)
        local hi, over = VfxNightDim.scaleAt(1), VfxNightDim.scaleAt(9)
        expect(near(under.brightness, lo.brightness)).toBe(true)
        expect(near(over.brightness, hi.brightness)).toBe(true)
        expect(near(over.lightEmission, hi.lightEmission)).toBe(true)
    end)

    test("monotonic — no flicker as nightFactor sweeps through dusk", function()
        local prevB, prevL = math.huge, math.huge
        for i = 0, 20 do
            local s = VfxNightDim.scaleAt(i / 20)
            expect(s.brightness <= prevB + 1e-9).toBe(true)
            expect(s.lightEmission <= prevL + 1e-9).toBe(true)
            prevB, prevL = s.brightness, s.lightEmission
        end
    end)

    test("halfway is halfway", function()
        local a, b, m = VfxNightDim.scaleAt(0), VfxNightDim.scaleAt(1), VfxNightDim.scaleAt(0.5)
        expect(near(m.brightness, (a.brightness + b.brightness) / 2)).toBe(true)
        expect(near(m.lightEmission, (a.lightEmission + b.lightEmission) / 2)).toBe(true)
    end)
end)
