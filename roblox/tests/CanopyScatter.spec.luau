--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local CanopyScatter = require("../tools/builders/CanopyScatter")

local CONIFERS = { { name = "ConiferA", weight = 3 }, { name = "ConiferB", weight = 1 } }

local function baseCfg(): CanopyScatter.Config
    return {
        yMin = 10,
        yMax = 100,
        maxSteep = 0.5,
        spacing = 5,
        spacingJitter = 0,
        rects = {},
        circles = {},
        waterCells = {},
        waterMargin = 6,
        conifers = CONIFERS,
        broadleaf = nil,
        heroMix = {},
        heroMixRadius = 40,
        keepLowY = nil,
        scaleJitter = 0.2,
        tintJitter = 0.1,
    }
end

local function sample(x: number, z: number, y: number, steep: number?): CanopyScatter.Sample
    return { x = x, z = z, y = y, steep = steep or 0.2 }
end

describe("CanopyScatter.plan filters", function()
    test("rejects samples outside the altitude band", function()
        local out =
            CanopyScatter.plan({ sample(0, 0, 5), sample(20, 0, 105), sample(40, 0, 50) }, baseCfg(), 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(40)
    end)
    test("rejects samples steeper than maxSteep", function()
        local out = CanopyScatter.plan({ sample(0, 0, 50, 0.9), sample(20, 0, 50, 0.3) }, baseCfg(), 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(20)
    end)
    test("rejects samples inside a keep-out rect", function()
        local cfg = baseCfg()
        cfg.rects = { { -10, -10, 10, 10 } }
        local out = CanopyScatter.plan({ sample(0, 0, 50), sample(30, 0, 50) }, cfg, 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(30)
    end)
    test("rejects samples inside a keep-out circle", function()
        local cfg = baseCfg()
        cfg.circles = { { 0, 0, 12 } }
        local out = CanopyScatter.plan({ sample(4, 4, 50), sample(30, 0, 50) }, cfg, 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(30)
    end)
    test("rejects samples within waterMargin of a water cell", function()
        local cfg = baseCfg()
        cfg.waterCells = { { 0, 0 } }
        local out = CanopyScatter.plan({ sample(3, 0, 50), sample(30, 0, 50) }, cfg, 1)
        expect(#out).toBe(1)
        expect(out[1].x).toBe(30)
    end)
end)

describe("CanopyScatter.plan spacing", function()
    test("enforces min spacing between accepted placements", function()
        local out =
            CanopyScatter.plan({ sample(0, 0, 50), sample(3, 0, 50), sample(20, 0, 50) }, baseCfg(), 1)
        expect(#out).toBe(2) -- the 3-stud neighbour of the first accept is rejected
    end)
end)

describe("CanopyScatter.plan determinism", function()
    local FIELD = {}
    for i = 0, 9 do
        for j = 0, 9 do
            table.insert(FIELD, sample(i * 8, j * 8, 50))
        end
    end
    test("same seed reproduces the identical plan", function()
        local a = CanopyScatter.plan(FIELD, baseCfg(), 42)
        local b = CanopyScatter.plan(FIELD, baseCfg(), 42)
        expect(a).toEqual(b)
    end)
    test("different seeds differ", function()
        local a = CanopyScatter.plan(FIELD, baseCfg(), 42)
        local b = CanopyScatter.plan(FIELD, baseCfg(), 43)
        local differs = #a ~= #b
        if not differs then
            for i, p in a do
                if p.yaw ~= b[i].yaw or p.species ~= b[i].species then
                    differs = true
                    break
                end
            end
        end
        expect(differs).toBe(true)
    end)
    test("rolls stay in range", function()
        local out = CanopyScatter.plan(FIELD, baseCfg(), 7)
        expect(#out > 10).toBe(true)
        for _, p in out do
            expect(p.yaw >= 0 and p.yaw < 2 * math.pi).toBe(true)
            expect(p.scale >= 0.8 and p.scale <= 1.2).toBe(true)
            expect(p.tint >= 0.9 and p.tint <= 1.1).toBe(true)
            expect(p.y).toBe(50)
        end
    end)
end)

describe("CanopyScatter.plan species", function()
    test("mixes broadleaf only near hero centres", function()
        local cfg = baseCfg()
        cfg.broadleaf = { name = "BroadleafMid", weight = 1000 } -- overwhelm conifer weights
        cfg.heroMix = { { 0, 0 } }
        cfg.heroMixRadius = 15
        local nearOut = CanopyScatter.plan({ sample(6, 0, 50) }, cfg, 5)
        expect(nearOut[1].species).toBe("BroadleafMid")
        local farOut = CanopyScatter.plan({ sample(60, 0, 50) }, cfg, 5)
        expect(farOut[1].species == "ConiferA" or farOut[1].species == "ConiferB").toBe(true)
    end)
    test("respects conifer weights deterministically", function()
        local field = {}
        for i = 0, 19 do
            for j = 0, 19 do
                table.insert(field, sample(i * 8, j * 8, 50))
            end
        end
        local out = CanopyScatter.plan(field, baseCfg(), 9)
        local counts = { ConiferA = 0, ConiferB = 0 }
        for _, p in out do
            counts[p.species] += 1
        end
        expect(counts.ConiferA > counts.ConiferB).toBe(true) -- weight 3 vs 1
    end)
end)

describe("CanopyScatter.plan density ramp", function()
    test("keepLowY=0 drops everything at yMin and keeps at yMax", function()
        local cfg = baseCfg()
        cfg.keepLowY = 0
        cfg.spacing = 0.5
        local lows, highs = {}, {}
        for i = 0, 19 do
            table.insert(lows, sample(i * 8, 0, 10))
            table.insert(highs, sample(i * 8, 40, 100))
        end
        local lowOut = CanopyScatter.plan(lows, cfg, 3)
        local highOut = CanopyScatter.plan(highs, cfg, 3)
        expect(#lowOut).toBe(0)
        expect(#highOut).toBe(20)
    end)
end)
