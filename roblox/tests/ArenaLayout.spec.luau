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
    test("creek descends from rim to basin mouth on the SW diagonal", function()
        expect(L.creek.entry[2] > L.creek.mouth[2]).toBe(true) -- downhill
        local er = math.sqrt(L.creek.entry[1] ^ 2 + L.creek.entry[3] ^ 2)
        local mr = math.sqrt(L.creek.mouth[1] ^ 2 + L.creek.mouth[3] ^ 2)
        expect(er > L.tiers[3].radius).toBe(true)
        expect(mr < L.apronRadius).toBe(true)
        expect(L.creek.entry[1] < 0 and L.creek.entry[3] < 0).toBe(true)
        expect(L.creek.mouth[1] < 0 and L.creek.mouth[3] < 0).toBe(true)
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

describe("ArenaLayout canyon clearing", function()
    test("clearing block defines floor, pool, outcrop, boundary", function()
        expect(L.clearing ~= nil).toBe(true)
        expect(L.clearing.floorY).toBe(112)
        expect(L.clearing.poolSurfaceY <= L.clearing.floorY).toBe(true) -- water fills the channel up to the terrace edge
        expect(L.clearing.poolCentre[1] < 0).toBe(true) -- back third (−X)
        expect(L.clearing.boundaryX > 0).toBe(true) -- downstream (+X)
    end)
    test("bell is on the clearing centreline, on the floor", function()
        expect(math.abs(L.bell.pos[1]) < 8).toBe(true) -- near origin X
        expect(math.abs(L.bell.pos[3]) < 8).toBe(true) -- near centreline Z
        expect(L.bell.pos[2] > L.clearing.floorY).toBe(true) -- bell hangs above the floor
    end)
    test("waterwheel is IN-RIVER undershot: North & upriver, lower paddles in the water", function()
        local w = L.waterwheel
        local bottom = w.centers[1][2] - w.radius
        expect(w.centers[1][1] < -5).toBe(true) -- shifted upriver (West) to clear the bell+tower
        expect(w.centers[1][3] < -8).toBe(true) -- North, in the river channel
        expect(bottom < L.clearing.poolSurfaceY).toBe(true) -- bottom dips into the river current
        expect(w.overshot).toBe(false)
        expect(w.headFrom == nil).toBe(true) -- no headrace flume (undershot)
    end)
end)

describe("ArenaLayout bell engine", function()
    test("waterwheel sits North in the river, shifted upriver (West) of the tower", function()
        local c = L.waterwheel.centers[1]
        expect(c[3] < -8).toBe(true) -- North of the tower
        expect(c[1] < -5).toBe(true) -- upriver (West), clear of the bell+tower
    end)
    test("main shaft runs N-S and extends South toward the bell, West of the bell+tower", function()
        local d = L.bellDrive
        expect(d.shaftFrom[1]).toBe(d.shaftTo[1]) -- constant X → runs along Z (N-S)
        expect(d.shaftFrom[2]).toBe(d.shaftTo[2]) -- constant Y (horizontal axle)
        expect(d.shaftTo[3] > d.shaftFrom[3]).toBe(true) -- extends South (+Z) from the wheel toward the bell
        expect(d.shaftFrom[1] < -12).toBe(true) -- West of the bell (edge -8.8) and the west tower posts (-11)
    end)
    test("a bevel turns the Z drive onto an E-W cam shaft pointed East at the shu-moku", function()
        local d = L.bellDrive
        expect(d.camShaftFrom[2]).toBe(d.camShaftTo[2]) -- constant Y
        expect(d.camShaftFrom[3]).toBe(d.camShaftTo[3]) -- constant Z → runs along X (E-W)
        expect(d.camShaftTo[1] - d.camShaftFrom[1] > 5).toBe(true) -- a real E-W run, pointing East
        expect(d.camShaftFrom[3] > 5.5).toBe(true) -- South of the bell (z-span ±5), clear of it
        expect(math.abs(d.camShaftFrom[3] - L.shuMoku.restPos[3]) < 4).toBe(true) -- aimed at the shu-moku
        expect(d.camR > d.driverR * 1.7).toBe(true) -- cam gear clearly the bigger reduction gear (gate-tuned ~1.9:1)
    end)
    test("kick shaft carries the paddle at the shu-moku swing level (decoupled from the drum)", function()
        local d = L.bellDrive
        expect(d.vertTop[2] > d.vertBase[2] + 15).toBe(true) -- a real vertical shaft
        expect(math.abs(d.paddle[2] - L.shuMoku.restPos[2]) < 4).toBe(true) -- paddle at the kick-dowel level
    end)
    test("throw drum is centred over the pavilion roof, clear above it", function()
        expect(math.abs(L.throwDrum.pos[1] - L.pavilion.pos[1]) < 1).toBe(true) -- centred in X
        expect(math.abs(L.throwDrum.pos[3] - L.pavilion.pos[3]) < 1).toBe(true) -- centred in Z
        expect(L.throwDrum.pos[2] > L.pavilion.pos[2] + L.pavilion.roofHeight).toBe(true) -- clear above the roof
    end)
    test("shu-moku has a draw dowel (cam) and a kick dowel (drum)", function()
        expect(L.shuMoku.drawDowel ~= nil).toBe(true)
        expect(L.shuMoku.kickDowel ~= nil).toBe(true)
    end)
    test("throw drum is a 12-facet vertical lantern with 4 windows", function()
        expect(L.throwDrum.faces).toBe(12)
        expect(L.throwDrum.windows).toBe(4)
    end)
end)

describe("ZenDojo overlooks", function()
    local o = L.overlooks
    test("two decks cantilever East off the clearing edge at distinct tiers", function()
        expect(#o.decks).toBe(2)
        local upper, lower
        for _, d in o.decks do
            if d.tier == "upper" then
                upper = d
            elseif d.tier == "lower" then
                lower = d
            end
        end
        expect(upper ~= nil).toBe(true)
        expect(lower ~= nil).toBe(true)
        expect(upper.pos[1] > 54).toBe(true) -- East of the terrace edge (~x54)
        expect(lower.pos[1] > 54).toBe(true)
        expect(upper.pos[2] > lower.pos[2]).toBe(true) -- upper deck sits higher
    end)
    test("the look direction faces downcanyon (East + a touch North)", function()
        expect(o.facing[1] > 0).toBe(true) -- East
        expect(o.facing[3] < 0).toBe(true) -- and North (−Z)
    end)
    test("the prow sits East of the decks and below the clearing floor", function()
        expect(o.prow[1] > o.decks[1].pos[1]).toBe(true) -- further East than the decks
        expect(o.prow[2] < 111).toBe(true) -- below clearing floor
    end)
    test("the gorge swerves North and keeps descending past the prow", function()
        expect(o.swerveTo[3] < o.prow[3]).toBe(true) -- North (−Z) of the prow
        expect(o.swerveTo[2] < o.prow[2]).toBe(true) -- lower than the prow (still descending)
    end)
    test("lantern perches recede and descend down the gorge", function()
        expect(#o.lanternPerches >= 3).toBe(true)
        local first, last = o.lanternPerches[1], o.lanternPerches[#o.lanternPerches]
        expect(last[1] > first[1]).toBe(true) -- further East (deeper)
        expect(last[2] < first[2]).toBe(true) -- and lower
    end)
end)
