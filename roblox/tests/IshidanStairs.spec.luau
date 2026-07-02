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

describe("IshidanStairs.dress (worn timber + flagstone — the canonical step recipe)", function()
    -- steep run (short pitch: timber-dominant, no flags) and gentle run (flags fit)
    local steep, gentle = {}, {}
    for d = 0, 22 do
        table.insert(steep, { d, 113.3 + d * (16.6 / 22), 0 })
    end
    for d = 0, 66 do
        table.insert(gentle, { d, 128.9 + d * (31.9 / 66), 0 })
    end
    local Lsteep =
        IshidanStairs.layout(steep, { riserTarget = 0.6, footY = 113.3, headY = 129.9, landings = {} })
    local Lgentle =
        IshidanStairs.layout(gentle, { riserTarget = 0.6, footY = 128.9, headY = 160.8, landings = {} })

    test("deterministic for a fixed seed", function()
        local a = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        local b = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        expect(a[3].risers[1].pos[1]).toBeCloseTo(b[3].risers[1].pos[1])
        expect(#a[3].flags).toBe(#b[3].flags)
        if #a[3].flags > 0 then
            expect(a[3].flags[1].outline[1].u).toBeCloseTo(b[3].flags[1].outline[1].u)
        end
    end)
    test("riser top sits at the tread, beam at the step front", function()
        local D = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        local step = Lgentle.steps[1]
        local r = D[1].risers[1]
        expect(r.pos[2] + r.size[2] / 2).toBeCloseTo(step.tread)
        -- beam center ~0.225 ahead of the front boundary (front = pos - dir*pitch/2)
        local frontX = step.pos[1] - step.dir[1] * step.pitch / 2
        expect(math.abs(r.pos[1] - (frontX + step.dir[1] * 0.225)) < 0.15).toBe(true)
    end)
    test("bed spans riser to riser (front+0.2 .. front+pitch+0.3)", function()
        local D = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        local step = Lgentle.steps[1]
        local bed = D[1].bed
        expect(bed.size[3]).toBeCloseTo(step.pitch + 0.1)
        -- center = stepCenter + dir*0.25
        expect(bed.pos[1]).toBeCloseTo(step.pos[1] + step.dir[1] * 0.25)
        expect(bed.pos[2] + bed.size[2] / 2).toBeCloseTo(step.tread - 0.05)
    end)
    test("flags appear on gentle treads and stay within the flag zone", function()
        local D = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        local step = Lgentle.steps[1]
        local any = false
        for _, f in D[1].flags do
            any = true
            for _, p in f.outline do
                expect(p.u >= -2.7 - 0.01 and p.u <= 2.7 + 0.01).toBe(true)
                expect(p.v >= 0.35 and p.v <= step.pitch + 0.01).toBe(true)
            end
            expect(#f.outline >= 6).toBe(true) -- subdivided + chaikin = dense organic outline
        end
        expect(any).toBe(true)
    end)
    test("steep treads get no flags (zone below minimum depth)", function()
        local D = IshidanStairs.dress(Lsteep, { seed = 20260711 })
        for _, d in D do
            if d.kind == "step" then
                expect(#d.flags).toBe(0)
            end
        end
    end)
    test("flag palette: darker mean, wide spread, bounded", function()
        local D = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        local sum, n = 0, 0
        for _, d in D do
            for _, f in d.flags do
                sum += f.g
                n += 1
                expect(f.g >= 78 and f.g <= 116).toBe(true)
            end
        end
        expect(n > 20).toBe(true)
        local mean = sum / n
        expect(mean > 88 and mean < 104).toBe(true)
    end)
    test("riser colors are the worn-timber palette", function()
        local D = IshidanStairs.dress(Lgentle, { seed = 20260711 })
        for _, d in D do
            for _, r in d.risers do
                expect(r.color[1] >= 65 and r.color[1] <= 79).toBe(true)
                expect(r.color[2]).toBe(r.color[1] - 12)
                expect(r.color[3]).toBe(r.color[1] - 24)
            end
        end
    end)
end)
