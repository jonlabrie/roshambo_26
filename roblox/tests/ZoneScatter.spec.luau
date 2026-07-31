--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ZoneScatter = require("../tools/builders/ZoneScatter")

-- helpers: a flat 100x100 grid of samples, 4-stud pitch
local function flatSamples(): { ZoneScatter.Sample }
    local s = {}
    for x = 0, 100, 4 do
        for z = 0, 100, 4 do
            table.insert(s, { x = x, z = z, y = 50, steep = 0 })
        end
    end
    return s
end

local CORE: ZoneScatter.Recipe = {
    pool = { { name = "SugiMidA", weight = 1 } },
    spacingMin = 10,
    spacingMax = 14,
    clumpChance = 0,
    clumpSize = 0,
    maxSteep = 0.6,
    waterMargin = 0,
    scaleJitter = 0.1,
}
local recipes: { [string]: ZoneScatter.Recipe } = {
    PreserveCore = CORE,
    FutureClearing = (function()
        local r = table.clone(CORE)
        r.innerClear = 0.5
        return r
    end)(),
}

describe("ZoneScatter", function()
    test("deterministic: same input twice = identical output", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
            },
        }
        local a = ZoneScatter.plan(zones, flatSamples(), recipes)
        local b = ZoneScatter.plan(zones, flatSamples(), recipes)
        expect(#a).toBe(#b)
        for i, p in a do
            expect(p.x).toBe(b[i].x)
            expect(p.species).toBe(b[i].species)
            expect(p.yaw).toBe(b[i].yaw)
        end
    end)
    test("spacing respected", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), recipes)
        expect(#out > 5).toBe(true)
        for i = 1, #out do
            for j = i + 1, #out do
                local dx, dz = out[i].x - out[j].x, out[i].z - out[j].z
                expect(dx * dx + dz * dz >= 10 * 10 - 1e-6).toBe(true)
            end
        end
    end)
    test("KeepOut wins over overlapping zone", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
            },
            {
                name = "KO",
                shape = "circle",
                bounds = { 50, 50, 30 },
                recipe = "KeepOut",
                densityScale = 1,
                seed = 1,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), recipes)
        for _, p in out do
            local dx, dz = p.x - 50, p.z - 50
            expect(dx * dx + dz * dz > 30 * 30).toBe(true)
        end
    end)
    test("FutureClearing inner half is empty", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "C",
                shape = "circle",
                bounds = { 50, 50, 40 },
                recipe = "FutureClearing",
                densityScale = 1,
                seed = 7,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), recipes)
        for _, p in out do
            local dx, dz = p.x - 50, p.z - 50
            expect(dx * dx + dz * dz >= 20 * 20).toBe(true)
        end
    end)
    test("mist anchors only from mist zones, wide-spaced", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
                mist = true,
            },
        }
        local _, anchors = ZoneScatter.plan(zones, flatSamples(), recipes)
        expect(#anchors >= 2).toBe(true)
        for i = 1, #anchors do
            for j = i + 1, #anchors do
                local dx, dz = anchors[i].x - anchors[j].x, anchors[i].z - anchors[j].z
                expect(dx * dx + dz * dz >= 30 * 30 - 1e-6).toBe(true)
            end
        end
    end)
    test("no mist zones = no anchors", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
            },
        }
        local _, anchors = ZoneScatter.plan(zones, flatSamples(), recipes)
        expect(#anchors).toBe(0)
    end)
    test("clumps place clumpSize trees inside spacingMin when triggered", function()
        local clumpy = table.clone(CORE)
        clumpy.clumpChance = 1
        clumpy.clumpSize = 3
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Clumpy",
                densityScale = 1,
                seed = 7,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), { Clumpy = clumpy })
        -- with clumpChance=1 every accepted dart becomes a clump: count neighbours within 8
        local clumped = 0
        for i = 1, #out do
            for j = 1, #out do
                if i ~= j then
                    local dx, dz = out[i].x - out[j].x, out[i].z - out[j].z
                    if dx * dx + dz * dz < 8 * 8 then
                        clumped += 1
                        break
                    end
                end
            end
        end
        expect(clumped > #out / 2).toBe(true)
    end)
    test("waterMargin keeps plantings off the shore", function()
        local shy = table.clone(CORE)
        shy.waterMargin = 15
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Shy",
                densityScale = 1,
                seed = 7,
            },
        }
        -- a pond cell at the grid centre
        local water = ZoneScatter.indexWater({ { 50, 50 } })
        local out = ZoneScatter.plan(zones, flatSamples(), { Shy = shy }, water)
        expect(#out > 0).toBe(true)
        for _, p in out do
            local dx, dz = p.x - 50, p.z - 50
            expect(dx * dx + dz * dz > 15 * 15).toBe(true)
        end
    end)

    test("nearWater confines margin flora to the shoreline", function()
        local margin = table.clone(CORE)
        margin.waterMargin = 0
        margin.nearWater = 12
        margin.spacingMin = 4
        margin.spacingMax = 6
        local zones: { ZoneScatter.Zone } = {
            {
                name = "M",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Margin",
                densityScale = 1,
                seed = 7,
            },
        }
        local water = ZoneScatter.indexWater({ { 50, 50 }, { 50, 62 } })
        local out = ZoneScatter.plan(zones, flatSamples(), { Margin = margin }, water)
        expect(#out > 0).toBe(true)
        for _, p in out do
            local nearest = math.huge
            for _, c in { { 50, 50 }, { 50, 62 } } do
                local dx, dz = p.x - c[1], p.z - c[2]
                nearest = math.min(nearest, dx * dx + dz * dz)
            end
            expect(nearest <= 12 * 12).toBe(true)
        end
    end)

    test("no water index = water rules are inert", function()
        local shy = table.clone(CORE)
        shy.waterMargin = 50
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Shy",
                densityScale = 1,
                seed = 7,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), { Shy = shy })
        expect(#out > 0).toBe(true)
    end)
    test("a layered zone that rejects a sample falls through to the one beneath", function()
        local core = table.clone(CORE)
        core.waterMargin = 10
        local margin = table.clone(CORE)
        margin.waterMargin = 0
        margin.nearWater = 10
        margin.pool = { { name = "Reed", weight = 1 } }
        margin.spacingMin = 5
        margin.spacingMax = 6
        -- Margin is layered LAST over an identical Core footprint: it must claim
        -- only the shoreline, leaving the rest of the ground to Core.
        local zones: { ZoneScatter.Zone } = {
            {
                name = "Core",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Core",
                densityScale = 1,
                seed = 3,
            },
            {
                name = "Margin",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Margin",
                densityScale = 1,
                seed = 4,
            },
        }
        local water = ZoneScatter.indexWater({ { 50, 50 } })
        local out = ZoneScatter.plan(zones, flatSamples(), { Core = core, Margin = margin }, water)
        local core_n, margin_n = 0, 0
        for _, p in out do
            if p.zone == "Core" then
                core_n += 1
                local dx, dz = p.x - 50, p.z - 50
                expect(dx * dx + dz * dz > 10 * 10).toBe(true)
            else
                margin_n += 1
                local dx, dz = p.x - 50, p.z - 50
                expect(dx * dx + dz * dz <= 10 * 10).toBe(true)
            end
        end
        expect(core_n > 0).toBe(true)
        expect(margin_n > 0).toBe(true)
    end)

    test("a keep-out layered UNDER other zones still vetoes", function()
        local zones: { ZoneScatter.Zone } = {
            {
                name = "KO",
                shape = "circle",
                bounds = { 50, 50, 25 },
                recipe = "KeepOut",
                densityScale = 1,
                seed = 1,
            },
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), recipes)
        expect(#out > 0).toBe(true)
        for _, p in out do
            local dx, dz = p.x - 50, p.z - 50
            expect(dx * dx + dz * dz > 25 * 25).toBe(true)
        end
    end)
    test("ground cover does not veto trees (per-layer spacing)", function()
        local trees = table.clone(CORE)
        trees.spacingMin = 12
        trees.spacingMax = 12
        local grass = table.clone(CORE)
        grass.spacingMin = 4
        grass.spacingMax = 4
        grass.layer = "ground"
        grass.pool = { { name = "Reed", weight = 1 } }
        local treesOnly: { ZoneScatter.Zone } = {
            {
                name = "T",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Trees",
                densityScale = 1,
                seed = 5,
            },
        }
        local baseline = ZoneScatter.plan(treesOnly, flatSamples(), { Trees = trees })
        -- same tree zone, with a dense ground-cover zone layered UNDER it
        local withGrass: { ZoneScatter.Zone } = {
            {
                name = "G",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Grass",
                densityScale = 1,
                seed = 6,
            },
            {
                name = "T",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Trees",
                densityScale = 1,
                seed = 5,
            },
        }
        local mixed = ZoneScatter.plan(withGrass, flatSamples(), { Trees = trees, Grass = grass })
        local treeCount = 0
        for _, p in mixed do
            if p.zone == "T" then
                treeCount += 1
            end
        end
        expect(treeCount).toBe(#baseline)
    end)
    test("a banded keep-out spares ground outside its height range", function()
        -- samples at two elevations under the same footprint
        local mixed: { ZoneScatter.Sample } = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                table.insert(mixed, { x = x, z = z, y = (x < 50) and 20 or 200, steep = 0 })
            end
        end
        local zones: { ZoneScatter.Zone } = {
            {
                name = "KO",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "KeepOut",
                densityScale = 1,
                seed = 1,
                yMin = 190,
                yMax = 210,
            },
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "PreserveCore",
                densityScale = 1,
                seed = 7,
            },
        }
        local out = ZoneScatter.plan(zones, mixed, recipes)
        expect(#out > 0).toBe(true)
        for _, p in out do
            -- only the low ground (y = 20) survives; the banded keep-out took the rest
            expect(p.y).toBe(20)
        end
    end)
end)

describe("ZoneScatter.footingDrop", function()
    local function grid(yFn: (number, number) -> number?): { ZoneScatter.Sample }
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                local y = yFn(x, z)
                if y ~= nil then
                    table.insert(s, { x = x, z = z, y = y, steep = 0 })
                end
            end
        end
        return s
    end

    test("flat ground drops nothing", function()
        local idx = ZoneScatter.indexSamples(
            grid(function()
                return 50
            end),
            4
        )
        expect(ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)).toBe(0)
    end)

    test("a cliff lip reports the drop", function()
        local idx = ZoneScatter.indexSamples(
            grid(function(x)
                return if x >= 52 then 10 else 50
            end),
            4
        )
        local drop = ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)
        expect(drop).toBe(40)
    end)

    test("a missing probe (void/water) is nil, not level ground", function()
        local idx = ZoneScatter.indexSamples(
            grid(function(x)
                return if x >= 52 then nil else 50
            end),
            4
        )
        expect(ZoneScatter.footingDrop(idx, 4, 48, 48, 50, 4)).toBe(nil)
    end)
end)

describe("ZoneScatter.plan footing gate", function()
    test("placements never straddle the cliff", function()
        local samples = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                table.insert(samples, { x = x, z = z, y = if x >= 52 then 10 else 50, steep = 0 })
            end
        end
        local footed = table.clone(CORE)
        footed.footingRadius = 4
        footed.footingMaxDrop = 4
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Footed",
                densityScale = 1,
                seed = 7,
            },
        }
        local placements = ZoneScatter.plan(zones, samples, { Footed = footed }, nil, nil, { pitch = 4 })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            -- x=48 looks straight across the 40-stud drop to x=52, which exceeds
            -- footingMaxDrop (4) within footingRadius (4): that column can never
            -- seat a placement. The low side of the cliff (x>=52) is solid
            -- ground underfoot for a plant standing on it, so it stays open —
            -- footingDrop flags a trunk over a void, not one merely near a wall.
            expect(p.x ~= 48).toBe(true)
        end
    end)
end)

describe("ZoneScatter submersion", function()
    local function shoreSamples(): { ZoneScatter.Sample }
        -- x<=48 dry bank y=50; x>=52 shallow water: ground 49, half a stud deep
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                if x >= 52 then
                    table.insert(s, { x = x, z = z, y = 49, steep = 0, depth = 0.5 })
                else
                    table.insert(s, { x = x, z = z, y = 50, steep = 0 })
                end
            end
        end
        return s
    end
    local zones: { ZoneScatter.Zone } = {
        {
            name = "A",
            shape = "rect",
            bounds = { 0, 0, 100, 100 },
            recipe = "R",
            densityScale = 1,
            seed = 7,
        },
    }

    test("a dry recipe never plants in water", function()
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = CORE })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x <= 48).toBe(true)
        end
    end)

    test("a wet-footed recipe wades in, to its depth limit", function()
        local reed = table.clone(CORE)
        reed.submergeMax = 1.0
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = reed })
        local wet = 0
        for _, p in placements do
            if p.x >= 52 then
                wet += 1
            end
        end
        expect(wet > 0).toBe(true)
    end)

    test("too deep is still too deep", function()
        local reed = table.clone(CORE)
        reed.submergeMax = 0.3 -- shallower than the 0.5 water
        local placements = ZoneScatter.plan(zones, shoreSamples(), { R = reed })
        for _, p in placements do
            expect(p.x <= 48).toBe(true)
        end
    end)
end)

describe("ZoneScatter keep-out gate", function()
    local CanyonKeepOuts = require("../tools/builders/CanyonKeepOuts")
    local zones: { ZoneScatter.Zone } = {
        {
            name = "A",
            shape = "rect",
            bounds = { 0, 0, 100, 100 },
            recipe = "R",
            densityScale = 1,
            seed = 7,
        },
    }

    test("an injected keep-out vetoes ground and clump children alike", function()
        local clumpy = table.clone(CORE)
        clumpy.clumpChance = 1
        clumpy.clumpSize = 3
        local placements = ZoneScatter.plan(zones, flatSamples(), { R = clumpy }, nil, nil, {
            keepOut = function(x, _z, _m)
                return x > 50
            end,
        })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x <= 50).toBe(true)
        end
    end)

    test("CanyonKeepOuts slots straight in as the callback", function()
        -- samples over the karesansui zone (x -25..38, z -16..22) get vetoed
        local samples = {}
        for x = -40, 60, 4 do
            for z = -30, 40, 4 do
                table.insert(samples, { x = x, z = z, y = 0, steep = 0 })
            end
        end
        local wide: { ZoneScatter.Zone } = {
            {
                name = "W",
                shape = "rect",
                bounds = { -40, -30, 60, 40 },
                recipe = "R",
                densityScale = 1,
                seed = 3,
            },
        }
        local placements = ZoneScatter.plan(wide, samples, { R = CORE }, nil, nil, {
            keepOut = function(x, z, m)
                return (CanyonKeepOuts.blocks(x, z, m))
            end,
        })
        for _, p in placements do
            expect(CanyonKeepOuts.zoneAt(p.x, p.z)).toBe(nil)
        end
    end)
end)

describe("ZoneScatter care-banded density", function()
    test("a zero GARDEN multiplier clears the tended front yard", function()
        local weedy = table.clone(CORE)
        weedy.careDensity = { GARDEN = 0 }
        local zones: { ZoneScatter.Zone } = {
            {
                name = "A",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "R",
                densityScale = 1,
                seed = 7,
            },
        }
        local placements = ZoneScatter.plan(zones, flatSamples(), { R = weedy }, nil, nil, {
            careBand = function(x, _z)
                return if x < 50 then "GARDEN" else "PRESERVE"
            end,
        })
        expect(#placements > 0).toBe(true)
        for _, p in placements do
            expect(p.x >= 50).toBe(true)
        end
    end)
end)

describe("ZoneScatter grove pre-pass", function()
    local GROVE_POOL = {
        { name = "SugiMidA", weight = 1 },
        { name = "MapleA", weight = 1 },
        { name = "PineA", weight = 1 },
    }

    local function groveRecipe(): ZoneScatter.Recipe
        local r = table.clone(CORE)
        r.pool = GROVE_POOL
        r.grove = {
            spacing = 30,
            radiusMin = 3,
            radiusMax = 7,
            membersMin = 3,
            membersMax = 6,
            memberSpacing = 3,
            dominantScale = 1.6,
            anchorDarts = 60,
            maxGroves = 4,
        }
        return r
    end

    local function groveZones(): { ZoneScatter.Zone }
        return {
            {
                name = "Grove",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Grove",
                densityScale = 1,
                seed = 11,
            },
        }
    end

    -- single-linkage clustering: link any two placements within `linkDist`,
    -- transitively. Simplest robust way to test "grove structure" without
    -- assuming the planner's own internal bookkeeping.
    local function clusterPlacements(
        placements: { ZoneScatter.Placement },
        linkDist: number
    ): { { ZoneScatter.Placement } }
        local clusters: { { ZoneScatter.Placement } } = {}
        for _, p in placements do
            local merged: { ZoneScatter.Placement } = { p }
            local kept: { { ZoneScatter.Placement } } = {}
            for _, cluster in clusters do
                local linked = false
                for _, q in cluster do
                    local dx, dz = p.x - q.x, p.z - q.z
                    if dx * dx + dz * dz <= linkDist * linkDist then
                        linked = true
                        break
                    end
                end
                if linked then
                    for _, q in cluster do
                        table.insert(merged, q)
                    end
                else
                    table.insert(kept, cluster)
                end
            end
            table.insert(kept, merged)
            clusters = kept
        end
        return clusters
    end

    test("deterministic: same grove input twice = identical output", function()
        local recipe = groveRecipe()
        local out1 = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        local out2 = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        expect(#out1).toBe(#out2)
        for i, p in out1 do
            expect(p.x).toBe(out2[i].x)
            expect(p.z).toBe(out2[i].z)
            expect(p.species).toBe(out2[i].species)
            expect(p.scale).toBe(out2[i].scale)
        end
    end)

    test("clustering: groves form <= maxGroves clusters, each within [1, membersMax]", function()
        local recipe = groveRecipe()
        local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        expect(#out > 0).toBe(true)
        local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
        expect(#clusters <= recipe.grove.maxGroves).toBe(true)
        for _, c in clusters do
            expect(#c >= 1).toBe(true)
            expect(#c <= recipe.grove.membersMax).toBe(true)
        end
    end)

    test("meadows: with spacing 50, cluster centroids stay spacing*0.8 apart", function()
        local recipe = groveRecipe()
        recipe.grove.spacing = 50
        recipe.grove.maxGroves = 3
        recipe.grove.anchorDarts = 300
        local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
        expect(#clusters >= 2).toBe(true)
        local centroids = {}
        for _, c in clusters do
            local sx, sz = 0, 0
            for _, p in c do
                sx += p.x
                sz += p.z
            end
            table.insert(centroids, { sx / #c, sz / #c })
        end
        for i = 1, #centroids do
            for j = i + 1, #centroids do
                local dx, dz = centroids[i][1] - centroids[j][1], centroids[i][2] - centroids[j][2]
                expect(dx * dx + dz * dz >= (recipe.grove.spacing * 0.8) ^ 2).toBe(true)
            end
        end
    end)

    test("species coherence: each cluster has <= 2 distinct species", function()
        local recipe = groveRecipe()
        local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
        expect(#clusters > 0).toBe(true)
        for _, c in clusters do
            local species: { [string]: boolean } = {}
            for _, p in c do
                species[p.species] = true
            end
            local n = 0
            for _ in species do
                n += 1
            end
            expect(n <= 2).toBe(true)
        end
    end)

    test("elder: cluster max scale reflects dominantScale and beats the median", function()
        local recipe = groveRecipe()
        local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
        expect(#clusters > 0).toBe(true)
        local sawMultiMember = false
        for _, c in clusters do
            local scales = {}
            for _, p in c do
                table.insert(scales, p.scale)
            end
            table.sort(scales)
            local maxScale = scales[#scales]
            expect(maxScale >= recipe.grove.dominantScale * (1 - recipe.scaleJitter)).toBe(true)
            if #scales > 1 then
                sawMultiMember = true
                local median
                local n = #scales
                if n % 2 == 1 then
                    median = scales[(n + 1) / 2]
                else
                    median = (scales[n / 2] + scales[n / 2 + 1]) / 2
                end
                expect(maxScale > median).toBe(true)
            end
        end
        expect(sawMultiMember).toBe(true)
    end)

    test("gates hold: keepOut vetoes grove anchors and members alike", function()
        local recipe = groveRecipe()
        recipe.grove.spacing = 15
        recipe.grove.anchorDarts = 200
        recipe.grove.maxGroves = 6
        local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe }, nil, nil, {
            keepOut = function(x, _z, _m)
                return x > 50
            end,
        })
        expect(#out > 0).toBe(true)
        for _, p in out do
            expect(p.x <= 50).toBe(true)
        end
    end)

    test("gates hold: grove pre-pass honors KeepOut zones - pads are sacred too", function()
        local recipe = groveRecipe()
        recipe.grove.spacing = 15
        recipe.grove.anchorDarts = 300
        recipe.grove.maxGroves = 8
        local zones: { ZoneScatter.Zone } = {
            {
                name = "Grove",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Grove",
                densityScale = 1,
                seed = 11,
            },
            {
                name = "KO_Pad",
                shape = "rect",
                bounds = { 50, 0, 100, 100 },
                recipe = "KeepOut",
                densityScale = 1,
                seed = 1,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), { Grove = recipe })
        expect(#out > 0).toBe(true)
        for _, p in out do
            expect(p.x < 50).toBe(true)
        end
    end)

    test("groveAffinity plants understory only near grove placements", function()
        local canopy = groveRecipe()
        local understory = table.clone(CORE)
        understory.layer = "understory"
        understory.pool = { { name = "FernA", weight = 1 } }
        understory.spacingMin = 2
        understory.spacingMax = 3
        understory.groveAffinity = { radius = 20, inside = 1, outside = 0 }
        local zones: { ZoneScatter.Zone } = {
            {
                name = "Grove",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Grove",
                densityScale = 1,
                seed = 11,
            },
            {
                name = "Under",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Under",
                densityScale = 1,
                seed = 12,
            },
        }
        local out = ZoneScatter.plan(zones, flatSamples(), { Grove = canopy, Under = understory })
        local canopyPlacements = {}
        local understoryPlacements = {}
        for _, p in out do
            if p.zone == "Grove" then
                table.insert(canopyPlacements, p)
            elseif p.zone == "Under" then
                table.insert(understoryPlacements, p)
            end
        end
        expect(#canopyPlacements > 0).toBe(true)
        expect(#understoryPlacements > 0).toBe(true)
        for _, u in understoryPlacements do
            local nearest = math.huge
            for _, c in canopyPlacements do
                local dx, dz = u.x - c.x, u.z - c.z
                nearest = math.min(nearest, dx * dx + dz * dz)
            end
            expect(nearest <= 20 * 20).toBe(true)
        end
    end)

    test("a grove-recipe zone does not plant via the per-sample path", function()
        local recipe = groveRecipe()
        local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
        expect(#out <= recipe.grove.maxGroves * recipe.grove.membersMax).toBe(true)
    end)

    describe("grove saplings", function()
        local FULL_MAP = { SugiMidA = "SugiMidA_Yb", MapleA = "MapleA_Yb", PineA = "PineA_Yb" }

        -- elder = the max-scale placement in each cluster (established by the
        -- "elder" test above: it's boosted by dominantScale and strictly
        -- beats the cluster median when there's more than one member)
        local function elderOf(cluster: { ZoneScatter.Placement }): ZoneScatter.Placement
            local best = cluster[1]
            for _, p in cluster do
                if p.scale > best.scale then
                    best = p
                end
            end
            return best
        end

        test("chance=1 + full map: every non-elder member is a mapped young species", function()
            local recipe = groveRecipe()
            recipe.grove.saplings = { chance = 1, map = FULL_MAP }
            local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
            expect(#out > 0).toBe(true)
            local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
            local sawMember = false
            for _, c in clusters do
                local elder = elderOf(c)
                expect(elder.species:match("_Yb$")).toBe(nil)
                for _, p in c do
                    if p ~= elder then
                        sawMember = true
                        expect(p.species:match("_Yb$") ~= nil).toBe(true)
                    end
                end
            end
            expect(sawMember).toBe(true)
        end)

        test(
            "chance=0: byte-identical to a run without saplings config (stream-ordering discipline)",
            function()
                local withSaplings = groveRecipe()
                withSaplings.grove.saplings = { chance = 0, map = FULL_MAP }
                local without = groveRecipe()
                local outA = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = withSaplings })
                local outB = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = without })
                expect(#outA).toBe(#outB)
                for i, p in outA do
                    expect(p.x).toBe(outB[i].x)
                    expect(p.z).toBe(outB[i].z)
                    expect(p.species).toBe(outB[i].species)
                    expect(p.scale).toBe(outB[i].scale)
                    expect(p.yaw).toBe(outB[i].yaw)
                end
            end
        )

        test("an unmapped species stays adult even at chance=1", function()
            local recipe = groveRecipe()
            recipe.grove.saplings = { chance = 1, map = { PineA = "PineA_Yb" } }
            local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
            expect(#out > 0).toBe(true)
            local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
            local sawMember = false
            for _, c in clusters do
                local elder = elderOf(c)
                for _, p in c do
                    if p ~= elder then
                        sawMember = true
                        -- PineA is always mapped away (chance=1, mapped); the
                        -- other two species have no map entry and stay adult
                        expect(p.species ~= "PineA").toBe(true)
                        expect(p.species == "SugiMidA" or p.species == "MapleA" or p.species == "PineA_Yb").toBe(
                            true
                        )
                    end
                end
            end
            expect(sawMember).toBe(true)
        end)
    end)

    describe("grove member retries", function()
        local function hostileZones(): { ZoneScatter.Zone }
            return {
                {
                    name = "Grove",
                    shape = "rect",
                    bounds = { 0, 0, 100, 100 },
                    recipe = "Grove",
                    densityScale = 1,
                    seed = 11,
                },
                -- keep-out covers 60% of the zone by width (x in [0,60]),
                -- forcing anchors into a narrow strip and many single-dart
                -- member attempts to land on hostile ground
                {
                    name = "KO_Hostile",
                    shape = "rect",
                    bounds = { 0, 0, 60, 100 },
                    recipe = "KeepOut",
                    densityScale = 1,
                    seed = 1,
                },
            }
        end

        test("memberTries=1 is byte-identical to a run without memberTries config", function()
            local withTries = groveRecipe()
            withTries.grove.memberTries = 1
            local without = groveRecipe()
            local outA = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = withTries })
            local outB = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = without })
            expect(#outA).toBe(#outB)
            for i, p in outA do
                expect(p.x).toBe(outB[i].x)
                expect(p.z).toBe(outB[i].z)
                expect(p.species).toBe(outB[i].species)
                expect(p.scale).toBe(outB[i].scale)
                expect(p.yaw).toBe(outB[i].yaw)
            end
        end)

        test(
            "memberTries=6 on hostile ground yields substantially fuller groves than memberTries=1",
            function()
                local tries1 = groveRecipe()
                tries1.grove.memberTries = 1
                tries1.grove.anchorDarts = 200
                tries1.grove.maxGroves = 6
                local tries6 = groveRecipe()
                tries6.grove.memberTries = 6
                tries6.grove.anchorDarts = 200
                tries6.grove.maxGroves = 6

                local out1 = ZoneScatter.plan(hostileZones(), flatSamples(), { Grove = tries1 })
                local out6 = ZoneScatter.plan(hostileZones(), flatSamples(), { Grove = tries6 })

                -- anchors are unaffected by memberTries (same darts, same
                -- spacing/maxGroves), so any growth in total placement count is
                -- entirely recovered members that a single dart would have lost
                expect(#out1 > 0).toBe(true)
                expect(#out6 > #out1).toBe(true)
            end
        )
    end)
end)
