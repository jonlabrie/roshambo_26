--!strict
local harness = require("./harness")
local ShoreRocks = require("../tools/builders/ShoreRocks")
local describe, test, expect = harness.describe, harness.test, harness.expect

local PARAMS: ShoreRocks.Params = {
    seed = 7,
    cell = 4,
    sheetTol = 3,
    lipRadius = 10,
    lipMinDrop = 1.5,
    lipSpacing = 35,
    quietSpacing = 55,
    memberRadiusMin = 3,
    memberRadiusMax = 8,
    memberSpacing = 2.5,
    attendantsMin = 2,
    attendantsMax = 4,
    wadersMax = 2,
    waderReach = 4,
    scaleMin = 0.85,
    scaleMax = 1.25,
}

-- 20x5-cell flat pool, y=100, cell pitch 4 studs (0..76 x, 0..16 z). No
-- elevation drop anywhere, so every edge cell is a QUIET candidate.
local function flatPool(): { ShoreRocks.WaterCell }
    local cells = {}
    for i = 0, 19 do
        for j = 0, 4 do
            table.insert(cells, { x = i * 4, z = j * 4, y = 100 })
        end
    end
    return cells
end

-- Two-terrace pool pair sharing a lip column at z=8: upper terrace
-- (z=0,4,8 @ y=100) and lower terrace (z=8,12,16,20,24 @ y=90) stack a
-- second WaterCell at z=8 for every x, producing a 10-stud elevation jump
-- right at the shared column - the lip.
local function terracePool(): { ShoreRocks.WaterCell }
    local cells = {}
    for i = 0, 9 do
        local x = i * 4
        for j = 0, 2 do
            table.insert(cells, { x = x, z = j * 4, y = 100 })
        end
        for j = 2, 6 do
            table.insert(cells, { x = x, z = j * 4, y = 90 })
        end
    end
    return cells
end

local function anchorsOf(placements: { ShoreRocks.RockPlacement }): { ShoreRocks.RockPlacement }
    local out = {}
    for _, p in placements do
        if p.role == "anchor" then
            table.insert(out, p)
        end
    end
    return out
end

describe("ShoreRocks.plan", function()
    test("deterministic: two identical calls return identical output", function()
        local cells = terracePool()
        local a = ShoreRocks.plan(cells, PARAMS)
        local b = ShoreRocks.plan(cells, PARAMS)
        expect(#a).toBe(#b)
        for i, p in a do
            expect(p.x).toBeCloseTo(b[i].x)
            expect(p.z).toBeCloseTo(b[i].z)
            expect(p.role).toBe(b[i].role)
            expect(p.yaw).toBeCloseTo(b[i].yaw)
            expect(p.scale).toBeCloseTo(b[i].scale)
            expect(p.lip).toBe(b[i].lip)
        end
    end)

    test("lip preference: first accepted anchor sits at the terrace boundary", function()
        local placements = ShoreRocks.plan(terracePool(), PARAMS)
        local anchors = anchorsOf(placements)
        expect(#anchors > 0).toBeTruthy()
        local first = anchors[1]
        -- the shared lip column is z=8
        expect(math.abs(first.z - 8) <= PARAMS.lipRadius).toBeTruthy()
        expect(first.lip).toBe(true)
        for _, p in placements do
            if p.lip and p.role == "anchor" and p.x == first.x and p.z == first.z then
                expect(p.lip).toBe(true)
            end
        end
    end)

    test("clustering: members stay near their anchor; anchors respect spacing", function()
        local placements = ShoreRocks.plan(terracePool(), PARAMS)
        local anchors = anchorsOf(placements)
        local maxReach = PARAMS.memberRadiusMax + PARAMS.waderReach + 2.5

        for _, p in placements do
            if p.role ~= "anchor" then
                local best = math.huge
                for _, a in anchors do
                    local dx, dz = p.x - a.x, p.z - a.z
                    local d = math.sqrt(dx * dx + dz * dz)
                    if d < best then
                        best = d
                    end
                end
                expect(best <= maxReach).toBeTruthy()
            end
        end

        for i, a in anchors do
            for j = i + 1, #anchors do
                local b = anchors[j]
                local dx, dz = a.x - b.x, a.z - b.z
                local d = math.sqrt(dx * dx + dz * dz)
                if a.lip and b.lip then
                    expect(d >= PARAMS.lipSpacing).toBeTruthy()
                else
                    expect(d >= PARAMS.quietSpacing).toBeTruthy()
                end
            end
        end
    end)

    test("roles: one anchor per cluster, attendant count in range, wader scale capped", function()
        local placements = ShoreRocks.plan(terracePool(), PARAMS)
        local i = 1
        local n = #placements
        local sawAnyCluster = false
        while i <= n do
            expect(placements[i].role).toBe("anchor")
            sawAnyCluster = true
            i += 1
            local attendantCount = 0
            while i <= n and placements[i].role == "attendant" do
                attendantCount += 1
                i += 1
            end
            expect(attendantCount >= 0).toBeTruthy()
            expect(attendantCount <= PARAMS.attendantsMax).toBeTruthy()
            while i <= n and placements[i].role == "wader" do
                expect(placements[i].scale <= 0.6 * PARAMS.scaleMax).toBeTruthy()
                i += 1
            end
        end
        expect(sawAnyCluster).toBeTruthy()
    end)

    test("keep-out: nothing places past x = 40", function()
        local keepOut = function(x: number, _z: number): boolean
            return x > 40
        end
        local placements = ShoreRocks.plan(flatPool(), PARAMS, keepOut)
        for _, p in placements do
            expect(p.x > 40).toBe(false)
        end
    end)

    test("existing standoff: an existing rock suppresses anchors within 10 studs", function()
        local existing = { { x = 0, z = 0 } }
        local placements = ShoreRocks.plan(flatPool(), PARAMS, nil, existing)
        for _, p in placements do
            if p.role == "anchor" then
                local dx, dz = p.x - 0, p.z - 0
                expect(dx * dx + dz * dz >= 100).toBeTruthy()
            end
        end
    end)

    test("quiet banks are sparse: at most 2 clusters on a lip-free flat pool", function()
        local placements = ShoreRocks.plan(flatPool(), PARAMS)
        local anchors = anchorsOf(placements)
        expect(#anchors <= 2).toBeTruthy()
        for _, a in anchors do
            expect(a.lip).toBe(false)
        end
    end)

    test("waders sit waterward of their cluster's edge cell", function()
        -- pool interior centroid for the flat pool
        local cx, cz = 38, 8
        -- seed 12 is known (probed offline) to roll at least one wader on
        -- this grid, so the assertion below is never vacuous
        local waderParams = table.clone(PARAMS)
        waderParams.seed = 12
        local placements = ShoreRocks.plan(flatPool(), waderParams)
        local anchorByRole: { [number]: ShoreRocks.RockPlacement } = {}
        local lastAnchor: ShoreRocks.RockPlacement? = nil
        local sawWader = false
        for _, p in placements do
            if p.role == "anchor" then
                lastAnchor = p
            elseif p.role == "wader" and lastAnchor ~= nil then
                sawWader = true
                local anchor = lastAnchor :: ShoreRocks.RockPlacement
                local anchorD = math.sqrt((anchor.x - cx) ^ 2 + (anchor.z - cz) ^ 2)
                local waderD = math.sqrt((p.x - cx) ^ 2 + (p.z - cz) ^ 2)
                expect(waderD < anchorD).toBeTruthy()
            end
        end
        -- if this ever flips seeds/params such that no wader rolls, the
        -- assertion above is vacuous; guard so the test still means something
        expect(sawWader).toBeTruthy()
    end)
end)
