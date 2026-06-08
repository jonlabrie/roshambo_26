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
    test("teahouses sit on a tier band at that tier's height", function()
        for _, t in L.teahouses do
            local d = math.sqrt(t.pos[1] ^ 2 + t.pos[3] ^ 2)
            local matched = false
            for i, tier in L.tiers do
                local inner = if i == 1 then L.apronRadius else L.tiers[i - 1].radius
                if d > inner and d < tier.radius then
                    expect(t.pos[2]).toBe(tier.height)
                    matched = true
                end
            end
            expect(matched).toBe(true)
        end
    end)
    test("waterwheel clears every pavilion post", function()
        local s = L.pavilion.postSpacing / 2
        for _, corner in { { s, s }, { s, -s }, { -s, s }, { -s, -s } } do
            local dx = L.flume.wheelPos[1] - corner[1]
            local dz = L.flume.wheelPos[3] - corner[2]
            expect(math.sqrt(dx * dx + dz * dz) > L.flume.wheelRadius).toBe(true)
        end
    end)
    test("flume pool is a raised header cistern on the Z axis, north of the wheel", function()
        -- pool moved off the tiers: it's a raised cistern feeding the wheel
        expect(L.flume.poolPos[1]).toBe(0) -- on the Z axis
        expect(L.flume.poolPos[2] > L.flume.wheelPos[2]).toBe(true) -- raised above the wheel
        expect(L.flume.poolPos[3] > L.flume.wheelPos[3]).toBe(true) -- north of the wheel
    end)
    test("koi pond fits inside the bowl", function()
        local d = math.sqrt(L.koiPond.pos[1] ^ 2 + L.koiPond.pos[3] ^ 2)
        expect(d + L.koiPond.radius < L.bowlRadius).toBe(true)
    end)
    test("spawn lands on the sandō", function()
        expect(L.spawn.pos[3] >= L.sando.fromZ and L.spawn.pos[3] <= L.sando.toZ).toBe(true)
        expect(math.abs(L.spawn.pos[1]) <= L.sando.width / 2).toBe(true)
    end)
    test("vertical stack: jumbotron clears hero tile clears bell", function()
        local jumboBottom = L.jumbotron.pos[2] - L.jumbotron.size[2] / 2
        local heroTop = L.heroTile.pos[2] + L.heroTile.size[2] / 2
        local heroBottom = L.heroTile.pos[2] - L.heroTile.size[2] / 2
        local bellTop = L.bell.pos[2] + L.bell.height / 2
        expect(jumboBottom > heroTop).toBe(true)
        expect(heroBottom > bellTop).toBe(true)
    end)
end)
