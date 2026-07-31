--!strict
local harness = require("./harness")
local MossTransitions = require("../tools/builders/MossTransitions")
local describe, test, expect = harness.describe, harness.test, harness.expect

local PARAMS: MossTransitions.Params = {
    seed = 11,
    spacing = 1.5,
    maxDist = 6,
    dartsPerSeed = 24,
    kindDensity = { stone = 1.0, waterline = 0.8 },
    pool = { { name = "Moss_A", weight = 3 }, { name = "Moss_B", weight = 1 } },
    scaleMin = 0.8,
    scaleMax = 1.3,
}

describe("MossTransitions.plan", function()
    test("deterministic: same input twice = identical output", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "stone" } }
        local a = MossTransitions.plan(seeds, PARAMS)
        local b = MossTransitions.plan(seeds, PARAMS)
        expect(#a).toBe(#b)
        for i, p in a do
            expect(p.x).toBe(b[i].x)
            expect(p.species).toBe(b[i].species)
        end
    end)

    test("moss hugs the transition: density falls with distance", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "stone" } }
        local near, far = 0, 0
        for _, p in MossTransitions.plan(seeds, PARAMS) do
            local d = math.sqrt(p.x * p.x + p.z * p.z)
            expect(d <= PARAMS.maxDist).toBe(true)
            if d <= PARAMS.maxDist / 2 then
                near += 1
            else
                far += 1
            end
        end
        expect(near > far).toBe(true)
    end)

    test("spacing holds across neighbouring seeds", function()
        local seeds = {
            { x = 0, z = 0, y = 10, kind = "stone" },
            { x = 3, z = 0, y = 10, kind = "stone" },
        }
        local placements = MossTransitions.plan(seeds, PARAMS)
        for i, p in placements do
            for j = i + 1, #placements do
                local q = placements[j]
                local dx, dz = p.x - q.x, p.z - q.z
                expect(dx * dx + dz * dz >= PARAMS.spacing * PARAMS.spacing).toBe(true)
            end
        end
    end)

    test("an unknown kind places nothing", function()
        local seeds = { { x = 0, z = 0, y = 10, kind = "confetti" } }
        expect(#MossTransitions.plan(seeds, PARAMS)).toBe(0)
    end)
end)
