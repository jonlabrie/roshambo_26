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

    test("bank stones wander laterally per the meander amplitude", function()
        local spec = Creek.build(ZenDojo.palette, L)
        local CK_DIRX, CK_DIRZ = -0.8387, -0.5446
        local maxOff = 0
        for _, c in spec.children :: any do
            if c.name:match("^Stone") then
                local x, z = c.properties.CFrame[1], c.properties.CFrame[3]
                local off = math.abs(x * CK_DIRZ - z * CK_DIRX)
                maxOff = math.max(maxOff, off)
            end
        end
        expect(maxOff > L.creek.width / 2 + L.creek.meander.amp - 2).toBe(true)
    end)
end)
