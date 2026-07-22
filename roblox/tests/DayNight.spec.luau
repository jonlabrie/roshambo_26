--!strict
local harness = require("./harness")
local DayNight = require("../src/shared/DayNight")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- a t sitting squarely inside each band
local MID = { dawn = 0.05, day = 0.19, dusk = 0.405, night = 0.76 }

describe("DayNight pure core", function()
    test("PHASES cover [0,1) contiguously and sum to 1", function()
        expect(#DayNight.PHASES).toBe(4)
        expect(DayNight.PHASES[1].from).toBe(0)
        expect(DayNight.PHASES[4].to).toBe(1)
        local total = 0
        local cursor = 0
        for _, band in DayNight.PHASES do
            expect(band.from).toBeCloseTo(cursor) -- no gaps/overlaps
            total += band.to - band.from
            cursor = band.to
        end
        expect(total).toBeCloseTo(1)
    end)

    test("phaseAt names the right band in each band", function()
        expect(DayNight.phaseAt(MID.dawn).phase).toBe("dawn")
        expect(DayNight.phaseAt(MID.day).phase).toBe("day")
        expect(DayNight.phaseAt(MID.dusk).phase).toBe("dusk")
        expect(DayNight.phaseAt(MID.night).phase).toBe("night")
    end)

    test("nightFactor is exactly 0 through day and 1 through night", function()
        expect(DayNight.phaseAt(0.15).nightFactor).toBe(0)
        expect(DayNight.phaseAt(MID.day).nightFactor).toBe(0)
        expect(DayNight.phaseAt(MID.night).nightFactor).toBe(1)
        expect(DayNight.phaseAt(0.99).nightFactor).toBe(1)
    end)

    test("nightFactor is continuous at every band boundary", function()
        -- sample just inside each boundary from both sides; the gap must be tiny
        local eps = 1e-4
        for _, b in { 0.10, 0.28, 0.53 } do
            local lo = DayNight.phaseAt(b - eps).nightFactor
            local hi = DayNight.phaseAt(b + eps).nightFactor
            expect(math.abs(hi - lo) < 0.01).toBe(true)
        end
        -- wrap boundary t=0: end-of-night (→1) meets start-of-dawn (→1)
        expect(DayNight.phaseAt(0.0).nightFactor).toBeCloseTo(1)
    end)

    test("nightFactor decreases monotonically across dawn (1→0)", function()
        local prev = 2
        for i = 0, 10 do
            local nf = DayNight.phaseAt(0.10 * (i / 10) * 0.999).nightFactor
            expect(nf <= prev + 1e-6).toBe(true)
            prev = nf
        end
        expect(prev < 0.05).toBe(true) -- reached ~0 by end of dawn
    end)

    test("nightFactor increases monotonically across dusk (0→1)", function()
        local prev = -1
        for i = 0, 10 do
            local t = 0.28 + (0.53 - 0.28) * (i / 10) * 0.999
            local nf = DayNight.phaseAt(t).nightFactor
            expect(nf >= prev - 1e-6).toBe(true)
            prev = nf
        end
        expect(prev > 0.95).toBe(true)
    end)

    test("phaseAt normalizes t outside [0,1)", function()
        expect(DayNight.phaseAt(1.19).phase).toBe("day") -- 1.19 % 1 = 0.19
        expect(DayNight.phaseAt(-0.81).phase).toBe("day") -- -0.81 % 1 = 0.19
    end)

    test("lightingAt returns in-range values", function()
        for _, t in MID do
            local L = DayNight.lightingAt(t)
            expect(L.brightness >= 0 and L.brightness <= 3).toBe(true)
            expect(L.fogEnd > 0).toBe(true)
            for _, ch in L.outdoorAmbient do
                expect(ch >= 0 and ch <= 1).toBe(true)
            end
            for _, ch in L.fogColor do
                expect(ch >= 0 and ch <= 1).toBe(true)
            end
        end
    end)

    test("lightingAt clockTime is monotonic increasing across the loop (5→29)", function()
        local prev = -1
        for i = 0, 40 do
            local ct = DayNight.lightingAt((i / 41)).clockTime
            expect(ct >= prev - 1e-6).toBe(true)
            prev = ct
        end
        expect(DayNight.lightingAt(0).clockTime).toBeCloseTo(5)
        expect(DayNight.lightingAt(0.999).clockTime < 29.01).toBe(true)
    end)

    test("day is brighter than night", function()
        expect(DayNight.lightingAt(MID.day).brightness > DayNight.lightingAt(MID.night).brightness).toBe(true)
    end)
end)
