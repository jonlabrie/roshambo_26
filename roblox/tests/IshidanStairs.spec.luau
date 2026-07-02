--!strict
local harness = require("./harness")
local IshidanStairs = require("../tools/builders/IshidanStairs")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("IshidanStairs.resample", function()
    local control = { { 0, 100, 0 }, { 10, 105, 0 }, { 20, 110, 0 } }
    test("endpoints preserved", function()
        local p = IshidanStairs.resample(control, 2)
        expect(p[1][1]).toBeCloseTo(0)
        expect(p[#p][1]).toBeCloseTo(20)
    end)
    test("passes near interior control points", function()
        local p = IshidanStairs.resample(control, 0.5)
        local best = math.huge
        for _, q in p do
            best = math.min(best, math.abs(q[1] - 10) + math.abs(q[3] - 0))
        end
        expect(best < 0.6).toBe(true)
    end)
end)

describe("IshidanStairs.layout", function()
    -- straight 78-run, 42-rise line (the real NW1012 numbers, simplified)
    local line = {}
    for d = 0, 78 do
        table.insert(line, { d, 113.3 + d * (42.4 / 78), 0 })
    end
    local opts = { riserTarget = 0.6, footY = 113.3, headY = 155.7, landings = {} }

    test("uniform risers within a flight", function()
        local L = IshidanStairs.layout(line, opts)
        local r = L.steps[1].riser
        for _, s in L.steps do
            if s.kind == "step" then
                expect(s.riser).toBeCloseTo(r)
            end
        end
    end)
    test("risers near target", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[1].riser > 0.5 and L.steps[1].riser < 0.7).toBe(true)
    end)
    test("head tread is exact", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[#L.steps].tread).toBeCloseTo(155.7)
    end)
    test("treads are strictly monotonic", function()
        local L = IshidanStairs.layout(line, opts)
        for k = 2, #L.steps do
            expect(L.steps[k].tread > L.steps[k - 1].tread - 1e-6).toBe(true)
        end
    end)
    test("first tread is one riser above footY", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[1].tread).toBeCloseTo(113.3 + L.steps[1].riser)
    end)
    test("landing is flat, sits between flights, consumes its arc", function()
        local withL = {
            riserTarget = 0.6,
            footY = 113.3,
            headY = 155.7,
            landings = { { frac = 0.5, len = 5 } },
        }
        local L = IshidanStairs.layout(line, withL)
        local nLand = 0
        for k = 2, #L.steps do
            local s = L.steps[k]
            if s.kind == "landing" then
                nLand += 1
                expect(s.tread).toBeCloseTo(L.steps[k - 1].tread) -- flat: same height as step below
                expect(s.len).toBe(5)
            end
        end
        expect(nLand).toBe(1)
        expect(#L.flights).toBe(2)
    end)
    test("dir is unit horizontal heading", function()
        local L = IshidanStairs.layout(line, opts)
        expect(L.steps[1].dir[1]).toBeCloseTo(1)
        expect(L.steps[1].dir[2]).toBeCloseTo(0)
    end)
end)
