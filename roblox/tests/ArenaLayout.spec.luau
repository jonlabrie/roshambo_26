--!strict
local harness = require("./harness")
local L = require("../tools/builders/ArenaLayout")
local Spec = require("../tools/builders/Spec")
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
    test("waterwheel cluster clears every pavilion post", function()
        local s = L.pavilion.postSpacing / 2
        for _, c in L.waterwheel.centers do
            for _, corner in { { s, s }, { s, -s }, { -s, s }, { -s, -s } } do
                local dx = c[1] - corner[1]
                local dz = c[3] - corner[2]
                expect(math.sqrt(dx * dx + dz * dz) > L.waterwheel.radius).toBe(true)
            end
        end
    end)
    test("koi pond fits inside the bowl", function()
        local d = math.sqrt(L.koiPond.pos[1] ^ 2 + L.koiPond.pos[3] ^ 2)
        expect(d + L.koiPond.radius < L.bowlRadius).toBe(true)
    end)
    test("spawn lands on the sandō", function()
        expect(L.spawn.pos[3] >= L.sando.fromZ and L.spawn.pos[3] <= L.sando.toZ).toBe(true)
        expect(math.abs(L.spawn.pos[1]) <= L.sando.width / 2).toBe(true)
    end)
    test("vertical stack: drum clears the bell, roof clears the bell, bell clears the water", function()
        -- The jumbotron/heroTile display was replaced by the throw drum atop the
        -- shōrō; the live stack is drum → roof → suspended bell → basin water.
        local bellTop = L.bell.pos[2] + L.bell.height / 2
        local bellBottom = L.bell.pos[2] - L.bell.height / 2
        local drumBottom = L.throwDrum.pos[2] - L.throwDrum.radius
        expect(drumBottom > bellTop).toBe(true)
        expect(L.pavilion.roofHeight > bellTop).toBe(true)
        expect(bellBottom > 0).toBe(true)
    end)
    test("creek descends from rim to basin mouth on the SW diagonal", function()
        expect(L.creek.entry[2] > L.creek.mouth[2]).toBe(true) -- downhill
        local er = math.sqrt(L.creek.entry[1] ^ 2 + L.creek.entry[3] ^ 2)
        local mr = math.sqrt(L.creek.mouth[1] ^ 2 + L.creek.mouth[3] ^ 2)
        expect(er > L.tiers[3].radius).toBe(true)
        expect(mr < L.apronRadius).toBe(true)
        expect(L.creek.entry[1] < 0 and L.creek.entry[3] < 0).toBe(true)
        expect(L.creek.mouth[1] < 0 and L.creek.mouth[3] < 0).toBe(true)
    end)
    test("waterwheels sit on the creek line (SW quadrant), descending order", function()
        local mmag = math.sqrt(L.creek.mouth[1] ^ 2 + L.creek.mouth[3] ^ 2)
        local prev = 0
        for i, c in L.waterwheel.centers do
            expect(c[1] < 0 and c[3] < 0).toBe(true) -- SW quadrant
            local cmag = math.sqrt(c[1] ^ 2 + c[3] ^ 2)
            -- collinear with the creek mouth direction (normalized cross ~ 0)
            local cross = (c[1] * L.creek.mouth[3] - c[3] * L.creek.mouth[1]) / (cmag * mmag)
            expect(math.abs(cross) < 0.02).toBe(true)
            if i > 1 then
                expect(cmag > prev).toBe(true) -- further out as we go up the creek
            end
            prev = cmag
        end
        expect(L.waterwheel.driver >= 1 and L.waterwheel.driver <= #L.waterwheel.centers).toBe(true)
    end)
    test("shu-moku rests on the drive line, SW of and outside the bell", function()
        local rest = Spec.rotY(L.shuMoku.restPos, L.shuMoku.yaw)
        expect(rest[1] < 0 and rest[3] < 0).toBe(true) -- SW quadrant
        local d = math.sqrt(rest[1] ^ 2 + rest[3] ^ 2)
        expect(d > L.bell.radius).toBe(true) -- clears the bell body
        -- collinear with the creek line, so the log aligns with the wheel driving it
        local mmag = math.sqrt(L.creek.mouth[1] ^ 2 + L.creek.mouth[3] ^ 2)
        local cross = (rest[1] * L.creek.mouth[3] - rest[3] * L.creek.mouth[1]) / (d * mmag)
        expect(math.abs(cross) < 0.02).toBe(true)
    end)
    test("sozu sits streamside near the driving wheel; cord targets the drum axle end", function()
        local driver = L.waterwheel.centers[L.waterwheel.driver]
        local d = math.sqrt((L.sozu.pivot[1] - driver[1]) ^ 2 + (L.sozu.pivot[3] - driver[3]) ^ 2)
        expect(d < 14).toBe(true)
        expect(math.abs(L.sozu.cordTop[2] - L.throwDrum.pos[2]) < 1).toBe(true)
        expect(math.abs(math.abs(L.sozu.cordTop[1] - L.throwDrum.pos[1]) - L.throwDrum.length / 2) < 1.5).toBe(
            true
        )
    end)
end)

describe("ArenaLayout garden", function()
    test("gardenTiers covers tiers 1 & 2 with the established counts", function()
        expect(#L.gardenTiers).toBe(2)
        expect(L.gardenTiers[1].tier).toBe(1)
        expect(L.gardenTiers[1].houseCount).toBe(7)
        expect(L.gardenTiers[2].houseCount).toBe(9)
        expect(L.topTier.houseCount).toBe(15) -- tier 3, dry garden
    end)

    test("each garden tier nests path < channel < houses, all on its plateau", function()
        for _, g in L.gardenTiers do
            expect(g.pathR < g.channelR).toBe(true)
            expect(g.channelR < g.houseR).toBe(true)
            local tier = L.tiers[g.tier]
            local nextR = L.tiers[g.tier + 1].radius
            expect(g.pathR > tier.radius).toBe(true)
            expect(g.houseR < nextR - 7).toBe(true)
        end
    end)

    test("creek meander + branch weirs + pool radius are defined", function()
        expect(L.creek.meander.amp > 0).toBe(true)
        expect(L.creek.meander.waves > 0).toBe(true)
        expect(#L.branchWeirs).toBe(2)
        expect(L.poolRadius > 0).toBe(true)
        expect(#L.foliage.heroCherry).toBe(3)
        expect(L.firefly.heroLightCount > 0).toBe(true)
    end)
end)
