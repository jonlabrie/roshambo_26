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

describe("IshidanStairs.slabs", function()
    local line = {}
    for d = 0, 78 do
        table.insert(line, { d, 113.3 + d * (42.4 / 78), 0 })
    end
    local layout =
        IshidanStairs.layout(line, { riserTarget = 0.6, footY = 113.3, headY = 155.7, landings = {} })
    local opts = { width = 6.4, depth = 1.25, body = 0.8, bedW = 5.8, bedH = 1.2, seed = 20260702 }

    test("deterministic for a fixed seed", function()
        local a = IshidanStairs.slabs(layout, opts)
        local b = IshidanStairs.slabs(layout, opts)
        expect(a[1].stones[1].pos[1]).toBeCloseTo(b[1].stones[1].pos[1])
        expect(a[1].stones[1].yawDeg).toBeCloseTo(b[1].stones[1].yawDeg)
    end)
    test("stone tops sit at the tread", function()
        local S = IshidanStairs.slabs(layout, opts)
        local step = layout.steps[1]
        local stone = S[1].stones[1]
        expect(stone.pos[2] + stone.size[2] / 2).toBeCloseTo(step.tread)
    end)
    test("bed top is 0.05 below the tread and narrower than the stones' full width", function()
        local S = IshidanStairs.slabs(layout, opts)
        local step = layout.steps[1]
        expect(S[1].bed.pos[2] + S[1].bed.size[2] / 2).toBeCloseTo(step.tread - 0.05)
        expect(S[1].bed.size[1]).toBeCloseTo(5.8)
    end)
    test("bed tucks uphill so its face hides behind the stone's riser face", function()
        -- bed center sits 0.35 uphill of the step center; with bed len pitch+0.5 its
        -- downhill face is then >= 0.2 behind the stone front even at worst jitter
        local S = IshidanStairs.slabs(layout, opts)
        local step = layout.steps[1]
        expect(S[1].bed.pos[1]).toBeCloseTo(step.pos[1] + step.dir[1] * 0.35)
        expect(S[1].bed.pos[3]).toBeCloseTo(step.pos[3] + step.dir[2] * 0.35)
    end)
    test("split steps: cross widths sum to width minus one 0.08 grout gap", function()
        local S = IshidanStairs.slabs(layout, opts)
        local found = false
        for _, sb in S do
            if #sb.stones == 2 then
                found = true
                expect(sb.stones[1].size[1] + sb.stones[2].size[1]).toBeCloseTo(6.4 - 0.08, 1)
            end
        end
        expect(found).toBe(true) -- with ~70 steps and splitFrac 0.5, at least one split
    end)
    test("jitter stays in bounds", function()
        local S = IshidanStairs.slabs(layout, opts)
        for _, sb in S do
            for _, st in sb.stones do
                expect(math.abs(st.yawDeg) <= 2 + 1e-6).toBe(true)
                expect(math.abs(st.tint) <= 3 + 1e-6).toBe(true)
            end
        end
    end)
    test("splitFrac=0 yields single stones; yawDeg caps jitter", function()
        local calm = {
            width = 6.4,
            depth = 1.25,
            body = 0.8,
            bedW = 5.8,
            bedH = 1.2,
            seed = 20260702,
            splitFrac = 0,
            yawDeg = 1.2,
            latJitter = 0.1,
        }
        local S = IshidanStairs.slabs(layout, calm)
        for _, sb in S do
            expect(#sb.stones).toBe(1)
            expect(math.abs(sb.stones[1].yawDeg) <= 1.2 + 1e-6).toBe(true)
        end
    end)
end)
