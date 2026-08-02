--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local VfxNightDim = require("../src/shared/VfxNightDim")

local function near(a: number, b: number): boolean
    return math.abs(a - b) < 1e-6
end

-- the real authored shape of a whitewater emitter in this canyon
local function authored(): VfxNightDim.Values
    return { brightness = 1.0, lightEmission = 0.6, lightInfluence = 0.0 }
end

describe("VfxNightDim.at", function()
    test("day is a no-op — authored values pass through untouched", function()
        local v = VfxNightDim.at(authored(), 0)
        expect(near(v.brightness, 1.0)).toBe(true)
        expect(near(v.lightEmission, 0.6)).toBe(true)
        expect(near(v.lightInfluence, 0.0)).toBe(true)
    end)

    test("LightInfluence RISES at night, from an authored zero", function()
        -- the bug that made the first pass invisible: a scale cannot move a value of 0, so
        -- influence must be lerped toward a target rather than multiplied
        local v = VfxNightDim.at(authored(), 1)
        expect(v.lightInfluence > 0.5).toBe(true)
    end)

    test("emission channels FALL at night but never reach zero", function()
        -- moonlit falls are the brightest thing in a night canyon, not the dimmest
        local v = VfxNightDim.at(authored(), 1)
        expect(v.brightness > 0).toBe(true)
        expect(v.lightEmission > 0).toBe(true)
        expect(v.brightness < 1.0).toBe(true)
        expect(v.lightEmission < 0.6).toBe(true)
    end)

    test("emission is a FRACTION of authored, so objects keep their relative look", function()
        -- foam (0.25) must stay subtler than whitewater (0.60) after dark
        local foam = VfxNightDim.at({ brightness = 1, lightEmission = 0.25, lightInfluence = 0 }, 1)
        local ww = VfxNightDim.at({ brightness = 1, lightEmission = 0.6, lightInfluence = 0 }, 1)
        expect(foam.lightEmission < ww.lightEmission).toBe(true)
        local hero = VfxNightDim.at({ brightness = 2, lightEmission = 0.6, lightInfluence = 0 }, 1)
        expect(hero.brightness > ww.brightness).toBe(true)
    end)

    test("influence converges to the SAME place regardless of authored value", function()
        -- unlike emission, influence describes a relationship to the scene, not a look
        local a = VfxNightDim.at({ brightness = 1, lightEmission = 0.6, lightInfluence = 0.0 }, 1)
        local b = VfxNightDim.at({ brightness = 1, lightEmission = 0.6, lightInfluence = 0.1 }, 1)
        expect(near(a.lightInfluence, b.lightInfluence)).toBe(true)
    end)

    test("nothing ever exceeds authored emission — no brighter-than-daylight waterfall", function()
        for _, nf in { -3, -0.5, 0, 0.25, 0.5, 1, 4, 100 } do
            local v = VfxNightDim.at(authored(), nf)
            expect(v.brightness <= 1.0 + 1e-9).toBe(true)
            expect(v.lightEmission <= 0.6 + 1e-9).toBe(true)
            expect(v.lightInfluence <= 1.0).toBe(true)
            expect(v.lightInfluence >= 0.0).toBe(true)
        end
    end)

    test("clamped at both ends", function()
        local lo, under = VfxNightDim.at(authored(), 0), VfxNightDim.at(authored(), -9)
        local hi, over = VfxNightDim.at(authored(), 1), VfxNightDim.at(authored(), 9)
        expect(near(under.brightness, lo.brightness)).toBe(true)
        expect(near(under.lightInfluence, lo.lightInfluence)).toBe(true)
        expect(near(over.brightness, hi.brightness)).toBe(true)
        expect(near(over.lightInfluence, hi.lightInfluence)).toBe(true)
    end)

    test("colour: day leaves the authored ramp exactly alone", function()
        -- the pale-cyan birth colour is deliberate authoring and is correct in daylight
        local keys = { { t = 0, r = 189 / 255, g = 246 / 255, b = 1 }, { t = 1, r = 1, g = 1, b = 1 } }
        local out = VfxNightDim.neutraliseColor(keys, 0)
        expect(near(out[1].r, 189 / 255)).toBe(true)
        expect(near(out[1].g, 246 / 255)).toBe(true)
        expect(near(out[2].r, 1)).toBe(true)
    end)

    test("colour: night walks the cast out to white", function()
        local keys = { { t = 0, r = 189 / 255, g = 246 / 255, b = 1 }, { t = 1, r = 1, g = 1, b = 1 } }
        local out = VfxNightDim.neutraliseColor(keys, 1)
        expect(near(out[1].r, 1)).toBe(true)
        expect(near(out[1].g, 1)).toBe(true)
        expect(near(out[1].b, 1)).toBe(true)
    end)

    test("colour: keypoint TIMES are preserved exactly", function()
        -- Roblox demands first at 0, last at 1, strictly increasing; regenerating times
        -- would be a way to build an invalid ColorSequence
        local keys = {
            { t = 0, r = 0.5, g = 0.5, b = 1 },
            { t = 0.37, r = 0.8, g = 0.9, b = 1 },
            { t = 1, r = 1, g = 1, b = 1 },
        }
        for _, nf in { 0, 0.5, 1 } do
            local out = VfxNightDim.neutraliseColor(keys, nf)
            expect(#out).toBe(3)
            expect(near(out[1].t, 0)).toBe(true)
            expect(near(out[2].t, 0.37)).toBe(true)
            expect(near(out[3].t, 1)).toBe(true)
        end
    end)

    test("colour: partway is partway, and never overshoots white", function()
        local keys = { { t = 0, r = 0.5, g = 0.5, b = 1 } }
        local mid = VfxNightDim.neutraliseColor(keys, 0.5)
        expect(mid[1].r > 0.5).toBe(true)
        expect(mid[1].r < 1).toBe(true)
        for _, nf in { 1, 5, 100 } do
            local out = VfxNightDim.neutraliseColor(keys, nf)
            expect(out[1].r <= 1 + 1e-9).toBe(true)
        end
    end)

    test("monotonic — no flicker as nightFactor sweeps through dusk", function()
        local prevB, prevL, prevI = math.huge, math.huge, -math.huge
        for i = 0, 20 do
            local v = VfxNightDim.at(authored(), i / 20)
            expect(v.brightness <= prevB + 1e-9).toBe(true)
            expect(v.lightEmission <= prevL + 1e-9).toBe(true)
            expect(v.lightInfluence >= prevI - 1e-9).toBe(true)
            prevB, prevL, prevI = v.brightness, v.lightEmission, v.lightInfluence
        end
    end)
end)
