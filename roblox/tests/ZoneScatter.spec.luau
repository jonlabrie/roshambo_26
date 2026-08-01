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
        -- the affinity gate itself checks proximity to the exact (unjittered)
        -- anchor grid point; every placement (canopy included) is then
        -- jittered up to GROVE_JITTER_MAX studs per axis, so a boundary
        -- understory sample can end up a hair over the raw radius from the
        -- nearest jittered canopy placement — pad the assertion accordingly
        local slack = 3
        for _, u in understoryPlacements do
            local nearest = math.huge
            for _, c in canopyPlacements do
                local dx, dz = u.x - c.x, u.z - c.z
                nearest = math.min(nearest, dx * dx + dz * dz)
            end
            expect(nearest <= (20 + slack) * (20 + slack)).toBe(true)
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

    describe("legacy dart-era fields are inert (anchorDarts, memberTries)", function()
        -- the grove pre-pass no longer dart-throws (see the "starvation
        -- regression" describe below for why); both fields are kept in
        -- GroveConfig purely so existing recipe literals don't need to drop
        -- them, and are never read by the exhaustive placer.
        test("memberTries is inert: byte-identical with or without it", function()
            local withTries = groveRecipe()
            withTries.grove.memberTries = 6
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

        test("anchorDarts is inert: byte-identical regardless of its value", function()
            local few = groveRecipe()
            few.grove.anchorDarts = 1
            local many = groveRecipe()
            many.grove.anchorDarts = 5000
            local outA = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = few })
            local outB = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = many })
            expect(#outA).toBe(#outB)
            for i, p in outA do
                expect(p.x).toBe(outB[i].x)
                expect(p.z).toBe(outB[i].z)
                expect(p.species).toBe(outB[i].species)
                expect(p.scale).toBe(outB[i].scale)
                expect(p.yaw).toBe(outB[i].yaw)
            end
        end)
    end)

    describe("free-mix groves (coherent = false)", function()
        local SIX_POOL = {
            { name = "SpA", weight = 1 },
            { name = "SpB", weight = 1 },
            { name = "SpC", weight = 1 },
            { name = "SpD", weight = 1 },
            { name = "SpE", weight = 1 },
            { name = "SpF", weight = 1 },
        }

        local function freeMixRecipe(): ZoneScatter.Recipe
            local r = table.clone(CORE)
            r.pool = SIX_POOL
            r.grove = {
                spacing = 30,
                radiusMin = 3,
                radiusMax = 7,
                membersMin = 5,
                membersMax = 8,
                memberSpacing = 3,
                dominantScale = 1.6,
                anchorDarts = 60,
                maxGroves = 4,
                memberTries = 4,
                coherent = false,
            }
            return r
        end

        test("coherent unset behaves byte-identically to before (coherent = true explicit)", function()
            local explicitTrue = groveRecipe()
            explicitTrue.grove.coherent = true
            local unset = groveRecipe()
            local outA = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = explicitTrue })
            local outB = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = unset })
            expect(#outA).toBe(#outB)
            for i, p in outA do
                expect(p.x).toBe(outB[i].x)
                expect(p.z).toBe(outB[i].z)
                expect(p.species).toBe(outB[i].species)
                expect(p.scale).toBe(outB[i].scale)
                expect(p.yaw).toBe(outB[i].yaw)
            end
        end)

        test("coherent=false with a 6-species pool yields >=3 distinct species in one grove", function()
            local recipe = freeMixRecipe()
            local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
            expect(#out > 0).toBe(true)
            local clusters = clusterPlacements(out, recipe.grove.radiusMax * 2)
            local bestDistinct = 0
            for _, c in clusters do
                local species: { [string]: boolean } = {}
                for _, p in c do
                    species[p.species] = true
                end
                local n = 0
                for _ in species do
                    n += 1
                end
                bestDistinct = math.max(bestDistinct, n)
            end
            expect(bestDistinct >= 3).toBe(true)
        end)
    end)

    describe("single-grove anchors seek the centre (maxGroves = 1)", function()
        local function centeredRecipe(): ZoneScatter.Recipe
            local r = groveRecipe()
            r.grove.maxGroves = 1
            return r
        end

        -- placements are jittered up to GROVE_JITTER_MAX studs per axis off
        -- their exact (gate-checked) grid point, so distance assertions near
        -- a boundary need a little slack — the gate itself is exact, only
        -- the rendered position wobbles.
        local JITTER_SLACK = 2

        test("open centre: single-grove anchor lands within 8 studs of the zone centroid", function()
            local recipe = centeredRecipe()
            local out = ZoneScatter.plan(groveZones(), flatSamples(), { Grove = recipe })
            expect(#out > 0).toBe(true)
            local elder = out[1]
            local dx, dz = elder.x - 50, elder.z - 50
            expect(dx * dx + dz * dz <= (8 + JITTER_SLACK) ^ 2).toBe(true)
        end)

        test("blocked centre: single-grove anchor hugs the keep-out boundary, not the far edge", function()
            local recipe = centeredRecipe()
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
                    name = "KO_Centre",
                    shape = "circle",
                    bounds = { 50, 50, 15 },
                    recipe = "KeepOut",
                    densityScale = 1,
                    seed = 1,
                },
            }
            local out = ZoneScatter.plan(zones, flatSamples(), { Grove = recipe })
            expect(#out > 0).toBe(true)
            local elder = out[1]
            local dx, dz = elder.x - 50, elder.z - 50
            local d2 = dx * dx + dz * dz
            expect(d2 >= (15 - JITTER_SLACK) ^ 2).toBe(true)
            expect(d2 < (25 + JITTER_SLACK) ^ 2).toBe(true)
        end)
    end)

    describe("starvation regression: exhaustive placement finds sparse legal ground", function()
        test("a contiguous patch of exactly M legal spots yields a FULL M-member grove", function()
            -- ONLY 5 samples exist in the entire world: a plus-shaped patch,
            -- 4 studs apart, nothing else. The old dart-throw pre-pass threw
            -- continuous random (x,z) darts and needed one to land on the
            -- EXACT grid cell of one of these 5 points to ever plant
            -- anything here — vanishingly unlikely. The exhaustive placer
            -- considers every legal sample directly, so a fully-supported
            -- compact patch should yield a complete grove using every spot.
            local patch: { ZoneScatter.Sample } = {
                { x = 48, z = 48, y = 50, steep = 0 },
                { x = 52, z = 48, y = 50, steep = 0 },
                { x = 44, z = 48, y = 50, steep = 0 },
                { x = 48, z = 52, y = 50, steep = 0 },
                { x = 48, z = 44, y = 50, steep = 0 },
            }
            local recipe = groveRecipe()
            recipe.grove.maxGroves = 1
            recipe.grove.membersMin = 5
            recipe.grove.membersMax = 5
            recipe.grove.radiusMax = 8
            recipe.grove.memberSpacing = 3
            local zones: { ZoneScatter.Zone } = {
                {
                    name = "Grove",
                    shape = "rect",
                    bounds = { 0, 0, 100, 100 },
                    recipe = "Grove",
                    densityScale = 1,
                    seed = 11,
                },
            }
            local out = ZoneScatter.plan(zones, patch, { Grove = recipe })
            expect(#out).toBe(5)
        end)

        test("legal ground scattered beyond radiusMax of each other starves a grove of members", function()
            -- the inverse control: candidates exist but none are within
            -- radiusMax of any other, so support is always 0 — a grove can
            -- still anchor (an elder needs no neighbours) but can never grow
            -- past the elder, proving the placer isn't just "always fills M"
            local scattered: { ZoneScatter.Sample } = {
                { x = 10, z = 10, y = 50, steep = 0 },
                { x = 90, z = 10, y = 50, steep = 0 },
                { x = 10, z = 90, y = 50, steep = 0 },
                { x = 90, z = 90, y = 50, steep = 0 },
                { x = 50, z = 50, y = 50, steep = 0 },
            }
            local recipe = groveRecipe()
            recipe.grove.maxGroves = 1
            recipe.grove.membersMin = 3
            recipe.grove.membersMax = 5
            recipe.grove.radiusMax = 7
            recipe.grove.memberSpacing = 3
            local zones: { ZoneScatter.Zone } = {
                {
                    name = "Grove",
                    shape = "rect",
                    bounds = { 0, 0, 100, 100 },
                    recipe = "Grove",
                    densityScale = 1,
                    seed = 11,
                },
            }
            local out = ZoneScatter.plan(zones, scattered, { Grove = recipe })
            expect(#out).toBe(1)
        end)
    end)
end)

-- helper: a flat 100x100 grid of samples, 4-stud pitch, all uniformly
-- submerged to `depth` studs (shore-margin recipes, unlike CORE, opt in)
local function wetSamples(depth: number): { ZoneScatter.Sample }
    local s = {}
    for x = 0, 100, 4 do
        for z = 0, 100, 4 do
            table.insert(s, { x = x, z = z, y = 49, steep = 0, depth = depth })
        end
    end
    return s
end

describe("ZoneScatter per-species submergence override", function()
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

    test("species submergence gates: the deeper-tolerant species always wins the re-pick", function()
        -- FernA can't tolerate ANY water (submergeMax=0); ReedB tolerates up
        -- to 2 studs. Over uniformly 1-stud-deep samples, every FernA draw
        -- must re-pick — with only two species in the pool, that always
        -- lands on ReedB, so nothing but ReedB should ever be placed.
        local recipe = table.clone(CORE)
        recipe.submergeMax = 5 -- outer bound: generous, not the limiting factor
        recipe.pool = {
            { name = "FernA", weight = 1, submergeMax = 0 },
            { name = "ReedB", weight = 1, submergeMax = 2 },
        }
        local out = ZoneScatter.plan(zones, wetSamples(1), { R = recipe })
        expect(#out > 0).toBe(true)
        for _, p in out do
            expect(p.species).toBe("ReedB")
        end
    end)

    test("skip when all 4 attempts fail: zero placements, not a crash or a fallback", function()
        -- a single-species pool whose only species can't tolerate ANY water:
        -- every attempt (all 4) draws the same intolerant species, so every
        -- sample is skipped outright.
        local recipe = table.clone(CORE)
        recipe.submergeMax = 5
        recipe.pool = { { name = "FernA", weight = 1, submergeMax = 0 } }
        local out = ZoneScatter.plan(zones, wetSamples(1), { R = recipe })
        expect(#out).toBe(0)
    end)

    test("no override = unchanged (pinned to the pre-change baseline, not a re-run of this code)", function()
        -- two species, NEITHER carries a submergeMax override: pickWadingSpecies
        -- must behave as a pure pass-through, so this is byte-identical to
        -- the plan this exact recipe/sample/seed produced before the feature
        -- existed. Counts pinned by hand against the unmodified planner.
        local recipe = table.clone(CORE)
        recipe.submergeMax = 2
        recipe.pool = { { name = "SpeciesA", weight = 1 }, { name = "SpeciesB", weight = 1 } }
        local out = ZoneScatter.plan(zones, wetSamples(1), { R = recipe })
        expect(#out).toBe(68)
        local counts: { [string]: number } = {}
        for _, p in out do
            counts[p.species] = (counts[p.species] or 0) + 1
        end
        expect(counts.SpeciesA).toBe(38)
        expect(counts.SpeciesB).toBe(30)
    end)

    test("the recipe-level gate is still the outer bound: a species override can't widen it", function()
        -- ReedB claims it can tolerate 5 studs, but the RECIPE's submergeMax
        -- (0.3) is the pre-filter checked in `accepts`, before any species is
        -- ever drawn — a 1-stud-deep sample never reaches species selection.
        local recipe = table.clone(CORE)
        recipe.submergeMax = 0.3
        recipe.pool = { { name = "ReedB", weight = 1, submergeMax = 5 } }
        local out = ZoneScatter.plan(zones, wetSamples(1), { R = recipe })
        expect(#out).toBe(0)
    end)

    test(
        "determinism: a plan using submergence override + rockAffinity together is identical across runs",
        function()
            local recipe = table.clone(CORE)
            recipe.submergeMax = 5
            recipe.pool = {
                { name = "FernA", weight = 1, submergeMax = 0 },
                { name = "ReedB", weight = 1, submergeMax = 2 },
            }
            recipe.rockAffinity = { radius = 10, inside = 1, outside = 0.5 }
            local opts = { rocks = { { x = 50, z = 50 }, { x = 20, z = 80 } } }
            local a = ZoneScatter.plan(zones, wetSamples(1), { R = recipe }, nil, nil, opts)
            local b = ZoneScatter.plan(zones, wetSamples(1), { R = recipe }, nil, nil, opts)
            expect(#a).toBe(#b)
            for i, p in a do
                expect(p.x).toBe(b[i].x)
                expect(p.species).toBe(b[i].species)
                expect(p.yaw).toBe(b[i].yaw)
            end
        end
    )
end)

describe("ZoneScatter rockAffinity", function()
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

    test("inside/outside: every placement lies within radius of the injected rock", function()
        local shore = table.clone(CORE)
        shore.spacingMin = 4
        shore.spacingMax = 6
        shore.rockAffinity = { radius = 10, inside = 1, outside = 0 }
        local out = ZoneScatter.plan(zones, flatSamples(), { R = shore }, nil, nil, {
            rocks = { { x = 50, z = 50 } },
        })
        expect(#out > 0).toBe(true)
        for _, p in out do
            local dx, dz = p.x - 50, p.z - 50
            expect(dx * dx + dz * dz <= 10 * 10).toBe(true)
        end
    end)

    test("no rocks supplied behaves as all-outside", function()
        local shore = table.clone(CORE)
        shore.spacingMin = 4
        shore.spacingMax = 6
        shore.rockAffinity = { radius = 10, inside = 1, outside = 0 }
        -- opts.rocks nil (not even passed) — outside=0 means every sample is
        -- treated as outside, so nothing plants at all
        local out = ZoneScatter.plan(zones, flatSamples(), { R = shore })
        expect(#out).toBe(0)
    end)

    test("compounds with careDensity: BOTH apply, so the combined count beats either factor alone", function()
        -- "strictly between the single-factor counts" isn't a reliable
        -- relationship here — the two multipliers interact with the shared
        -- LCG stream and the greedy min-spacing pass in a way that isn't
        -- simply monotonic sample-by-sample. What IS reliable, and what
        -- actually proves the two multipliers compound (rather than one
        -- silently overwriting the other, or only one taking effect), is
        -- that the combined-multiplier count sits below EITHER single-factor
        -- count on its own. Values pinned empirically for this seed/recipe.
        local careOnly = table.clone(CORE)
        careOnly.careDensity = { PRESERVE = 0.5 }
        local rockOnly = table.clone(CORE)
        rockOnly.rockAffinity = { radius = 15, inside = 1, outside = 0.3 }
        local both = table.clone(CORE)
        both.careDensity = { PRESERVE = 0.5 }
        both.rockAffinity = { radius = 15, inside = 1, outside = 0.3 }

        local careBand = function(_x: number, _z: number): string
            return "PRESERVE"
        end
        local rocks = { { x = 50, z = 50 } }

        local outCare = ZoneScatter.plan(
            zones,
            flatSamples(),
            { R = careOnly },
            nil,
            nil,
            { careBand = careBand }
        )
        local outRock = ZoneScatter.plan(zones, flatSamples(), { R = rockOnly }, nil, nil, { rocks = rocks })
        local outBoth = ZoneScatter.plan(zones, flatSamples(), { R = both }, nil, nil, {
            careBand = careBand,
            rocks = rocks,
        })

        expect(#outBoth < #outCare).toBe(true)
        expect(#outBoth < #outRock).toBe(true)
    end)
end)

-- 2026-08-01 user gate: "irises are popping up too far away from the water ...
-- they're a water's edge plant". nearWater was recipe-wide, so iris inherited the
-- same bank width as reeds. A species may now NARROW it for itself.
describe("per-species nearWater", function()
    local WATER = { { 0, 0 } }
    local function bankSamples()
        -- a line of samples marching away from a single water cell at (0,0)
        local out = {}
        for d = 2, 20, 2 do
            table.insert(out, { x = d, z = 0, y = 100, steep = 0, depth = 0 })
        end
        return out
    end
    local function recipe(pool)
        return {
            pool = pool,
            spacingMin = 0.5,
            spacingMax = 0.5,
            clumpChance = 0,
            clumpSize = 0,
            maxSteep = 1,
            waterMargin = 0,
            scaleJitter = 0,
            nearWater = 20, -- the RECIPE allows the whole bank
            layer = "ground",
        }
    end
    local ZONE = {
        {
            name = "bank",
            shape = "rect",
            bounds = { -30, -30, 30, 30 },
            recipe = "bank",
            densityScale = 1,
            seed = 5,
            mist = false,
        },
    }

    test("a species with a tight nearWater stays close to the water", function()
        local plan = ZoneScatter.plan(
            ZONE,
            bankSamples(),
            { bank = recipe({ { name = "Iris", weight = 1, nearWater = 5 } }) },
            ZoneScatter.indexWater(WATER),
            ZoneScatter.indexWater({}),
            { pitch = 2 }
        )
        expect(#plan > 0).toBeTruthy()
        for _, p in plan do
            -- every iris must sit within its own 5-stud limit, not the recipe's 20
            expect(math.abs(p.x) <= 5).toBeTruthy()
        end
    end)

    test("a species without the override still uses the recipe's width", function()
        local plan = ZoneScatter.plan(
            ZONE,
            bankSamples(),
            { bank = recipe({ { name = "Reed", weight = 1 } }) },
            ZoneScatter.indexWater(WATER),
            ZoneScatter.indexWater({}),
            { pitch = 2 }
        )
        local far = 0
        for _, p in plan do
            if p.x > 5 then
                far += 1
            end
        end
        expect(far > 0).toBeTruthy()
    end)
end)

-- 2026-08-01 user gate: "your approach is also either/or, never and ... I like
-- the shuffled mix, but it should be a line of shuffled mixes marching along
-- the shore." Two faults fixed: clumps were monospecific (a clump child
-- inherited its parent's species), and placement was area-scatter (every
-- nearWater sample was a candidate, so plants spread across the whole band
-- instead of tracking the shoreline). The shoreline pre-pass replaces both
-- with stations (spaced ALONG the shore) whose members each independently
-- draw their own species.
describe("ZoneScatter shoreline pass", function()
    -- a straight shoreline along x = WATER_X, running the full z span so
    -- station-spacing tests have plenty of shore to walk
    local WATER_X = 50
    local function waterLine(): ZoneScatter.WaterIndex
        local cells = {}
        for z = 0, 100, 4 do
            table.insert(cells, { WATER_X, z })
        end
        return ZoneScatter.indexWater(cells)
    end
    -- like the submersion describe block's shoreSamples(), but with a
    -- configurable depth so submergence tests can check the ACTUAL nearest
    -- sample's depth (ground truth) rather than inferring "in water" from an
    -- x threshold, which the member's continuous (non-grid) offset makes
    -- unreliable near the boundary.
    local function shoreSamples(waterDepth: number): { ZoneScatter.Sample }
        local s = {}
        for x = 0, 100, 4 do
            for z = 0, 100, 4 do
                if x >= WATER_X then
                    table.insert(s, { x = x, z = z, y = 49, steep = 0, depth = waterDepth })
                else
                    table.insert(s, { x = x, z = z, y = 50, steep = 0 })
                end
            end
        end
        return s
    end
    -- replicates the planner's own nearestSample lookup (unexported) so a
    -- test can ask "what depth did THIS placement's member actually see",
    -- exactly what pickWadingSpecies gated on internally
    local function nearestDepth(samples: { ZoneScatter.Sample }, x: number, z: number): number
        local bestD, bestDepth = math.huge, 0
        for _, s in samples do
            local dx, dz = s.x - x, s.z - z
            local d = dx * dx + dz * dz
            if d < bestD then
                bestD, bestDepth = d, s.depth or 0
            end
        end
        return bestDepth
    end
    -- ground-truth "distance to nearest water cell", using the exact cell
    -- list the water index was built from — independent of the planner's
    -- internals, unlike nearestDepth above (which deliberately mirrors them)
    local function nearestWaterDistSq(x: number, z: number): number
        local best = math.huge
        for z2 = 0, 100, 4 do
            local dx, dz = x - WATER_X, z - z2
            best = math.min(best, dx * dx + dz * dz)
        end
        return best
    end
    local function shoreZone(): { ZoneScatter.Zone }
        return {
            {
                name = "Shore",
                shape = "rect",
                bounds = { 0, 0, 100, 100 },
                recipe = "Shore",
                densityScale = 1,
                seed = 21,
            },
        }
    end
    local function shoreRecipe(pool: { ZoneScatter.Species }): ZoneScatter.Recipe
        return {
            pool = pool,
            spacingMin = 3,
            spacingMax = 3,
            clumpChance = 0,
            clumpSize = 0,
            maxSteep = 1,
            waterMargin = 0,
            scaleJitter = 0.1,
            nearWater = 16,
            shoreline = {
                stationSpacing = 12,
                membersMin = 2,
                membersMax = 4,
                spread = 3,
                inland = 2,
            },
        }
    end
    -- single-linkage clustering by proximity, to recover "which station"
    -- a placement belongs to from the output alone — same technique as the
    -- grove pre-pass describe block's local helper (duplicated rather than
    -- shared: that one is scoped inside its own describe).
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

    test("deterministic: same shoreline input twice = identical output", function()
        local recipe = shoreRecipe({ { name = "SpeciesA", weight = 1 } })
        local water = waterLine()
        local a = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
        local b = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
        expect(#a).toBe(#b)
        for i, p in a do
            expect(p.x).toBe(b[i].x)
            expect(p.z).toBe(b[i].z)
            expect(p.species).toBe(b[i].species)
            expect(p.yaw).toBe(b[i].yaw)
        end
    end)

    test("follows the shore: placements track the water line, spread along it more than across it", function()
        local recipe = shoreRecipe({ { name = "SpeciesA", weight = 1 } })
        local water = waterLine()
        local out = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
        expect(#out > 0).toBe(true)
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
        for _, p in out do
            expect(nearestWaterDistSq(p.x, p.z) <= recipe.nearWater * recipe.nearWater).toBe(true)
            minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
            minZ, maxZ = math.min(minZ, p.z), math.max(maxZ, p.z)
        end
        -- the shore runs along z; a band-scatter fault would spread roughly
        -- as wide across (x) as along (z) — a shoreline should spread FAR
        -- more along the shore than across it
        expect((maxZ - minZ) > (maxX - minX)).toBe(true)
    end)

    test("stations are spaced: no two are closer than stationSpacing*0.8", function()
        -- one member per station isolates this test to STATION spacing
        -- alone, independent of any within-station member-spread geometry —
        -- every output placement IS a station, so pairwise placement
        -- distance is exactly pairwise station distance. A large
        -- stationSpacing against a small spacingMin (the ordinary per-sample
        -- fault's own spacing) is what makes this fail pre-implementation:
        -- the old per-sample path packs the whole band at ~spacingMin, far
        -- tighter than stations are supposed to be.
        local recipe = shoreRecipe({ { name = "SpeciesA", weight = 1 } })
        recipe.shoreline.stationSpacing = 40
        recipe.shoreline.membersMin = 1
        recipe.shoreline.membersMax = 1
        recipe.shoreline.spread = 2
        recipe.shoreline.inland = 1
        recipe.spacingMin = 8
        recipe.spacingMax = 10
        local water = waterLine()
        local out = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
        expect(#out > 0).toBe(true)
        for i = 1, #out do
            for j = i + 1, #out do
                local dx, dz = out[i].x - out[j].x, out[i].z - out[j].z
                expect(dx * dx + dz * dz >= (recipe.shoreline.stationSpacing * 0.8) ^ 2).toBe(true)
            end
        end
    end)

    test("handfuls are mixed: at least one station contains more than one distinct species", function()
        local recipe = shoreRecipe({
            { name = "SpeciesA", weight = 1 },
            { name = "SpeciesB", weight = 1 },
        })
        recipe.shoreline.membersMin = 3
        recipe.shoreline.membersMax = 4
        local water = waterLine()
        local out = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
        expect(#out > 0).toBe(true)
        local clusters = clusterPlacements(out, (recipe.shoreline.spread + recipe.shoreline.inland) * 2)
        local mixedStations = 0
        for _, cluster in clusters do
            local species: { [string]: boolean } = {}
            for _, p in cluster do
                species[p.species] = true
            end
            local distinct = 0
            for _ in species do
                distinct += 1
            end
            if distinct >= 2 then
                mixedStations += 1
            end
        end
        expect(mixedStations > 0).toBe(true)
    end)

    test(
        "per-species gates still sort within a handful: Wet stays near water, Dry stays out of it",
        function()
            local recipe = shoreRecipe({
                { name = "Wet", weight = 1, nearWater = 3 },
                { name = "Dry", weight = 1, submergeMax = 0 },
            })
            recipe.submergeMax = 5 -- outer bound: generous enough that depth 0.5 clears it
            recipe.shoreline.spread = 8
            recipe.shoreline.inland = 6
            recipe.shoreline.stationSpacing = 10
            recipe.shoreline.membersMin = 3
            recipe.shoreline.membersMax = 5
            local samples = shoreSamples(0.5)
            local water = waterLine()
            local out = ZoneScatter.plan(shoreZone(), samples, { Shore = recipe }, water)
            expect(#out > 0).toBe(true)
            local sawWet, sawDry = false, false
            for _, p in out do
                if p.species == "Wet" then
                    sawWet = true
                    expect(nearestWaterDistSq(p.x, p.z) <= 3 * 3).toBe(true)
                elseif p.species == "Dry" then
                    sawDry = true
                    expect(nearestDepth(samples, p.x, p.z)).toBe(0)
                end
            end
            expect(sawWet).toBe(true)
            expect(sawDry).toBe(true)
        end
    )

    test("member count is respected: no station has more than membersMax placements", function()
        local recipe = shoreRecipe({ { name = "SpeciesA", weight = 1 } })
        recipe.shoreline.stationSpacing = 30
        recipe.shoreline.membersMin = 1
        recipe.shoreline.membersMax = 3
        local water = waterLine()
        local out = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
        expect(#out > 0).toBe(true)
        local clusters = clusterPlacements(out, (recipe.shoreline.spread + recipe.shoreline.inland) * 2)
        for _, cluster in clusters do
            expect(#cluster <= recipe.shoreline.membersMax).toBe(true)
        end
    end)

    test(
        "a shoreline recipe's zone does NOT also scatter per-sample: bounded by stations * membersMax",
        function()
            local recipe = shoreRecipe({ { name = "SpeciesA", weight = 1 } })
            recipe.shoreline.stationSpacing = 20
            recipe.shoreline.membersMax = 4
            local water = waterLine()
            local out = ZoneScatter.plan(shoreZone(), flatSamples(), { Shore = recipe }, water)
            expect(#out > 0).toBe(true)
            -- the shoreline runs the full 0..100 z-span; at stationSpacing=20 the
            -- greedy walk can accept at most floor(100/20)+1 stations along it.
            -- A per-sample-scatter fault (the bug being fixed) would blow far
            -- past this bound, since every nearWater sample is a candidate.
            local maxStations = math.floor(100 / recipe.shoreline.stationSpacing) + 1
            expect(#out <= maxStations * recipe.shoreline.membersMax).toBe(true)
        end
    )
end)
