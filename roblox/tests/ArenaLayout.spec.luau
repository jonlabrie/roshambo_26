--!strict
local harness = require("./harness")
local L = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("ArenaLayout", function()
    test("rings nest strictly: basin < apron < tiers ascending < bowl", function()
        expect(L.basinRadius < L.apronRadius).toBe(true)
        expect(L.apronRadius < L.tiers[1].radius).toBe(true)
        expect(L.tiers[1].radius < L.tiers[2].radius).toBe(true)
        expect(L.tiers[2].radius < L.tiers[3].radius).toBe(true)
        expect(L.tiers[3].radius < L.bowlRadius).toBe(true)
    end)
    test("tier heights ascend", function()
        expect(L.tiers[1].height < L.tiers[2].height).toBe(true)
        expect(L.tiers[2].height < L.tiers[3].height).toBe(true)
    end)
    test("promontories sit on tier 2 inside its radius", function()
        for _, p in L.promontories do
            local d = math.sqrt(p.pos[1] ^ 2 + p.pos[3] ^ 2)
            expect(d < L.tiers[2].radius and d > L.tiers[1].radius).toBe(true)
            expect(p.pos[2]).toBe(L.tiers[2].height)
        end
    end)
    test("flume runs downhill: pool higher than wheel top", function()
        expect(L.flume.poolPos[2] > L.flume.wheelPos[2] + L.flume.wheelRadius).toBe(true)
    end)
    test("teahouses sit on tiers, outside the apron", function()
        for _, t in L.teahouses do
            local d = math.sqrt(t.pos[1] ^ 2 + t.pos[3] ^ 2)
            expect(d > L.apronRadius).toBe(true)
        end
    end)
end)
