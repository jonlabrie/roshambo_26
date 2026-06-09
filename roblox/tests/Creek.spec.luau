--!strict
local harness = require("./harness")
local Creek = require("../tools/builders/Creek")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Creek dressing builder", function()
    test("places stones along the creek line (−X/−Z quadrant), descending entry→mouth", function()
        local spec = Creek.build(ZenDojo.palette, L)
        local stones = 0
        local maxY, minY = -1e9, 1e9
        for _, c in spec.children :: any do
            if c.name:match("^Stone%d+$") then
                stones += 1
                expect(c.properties.CFrame[1] < 0 and c.properties.CFrame[3] < 0).toBe(true)
                maxY = math.max(maxY, c.properties.CFrame[2])
                minY = math.min(minY, c.properties.CFrame[2])
            end
        end
        expect(stones >= 6).toBe(true)
        expect(maxY > minY).toBe(true) -- descends from rim to mouth
    end)
end)
