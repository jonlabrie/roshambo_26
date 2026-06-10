--!strict
local harness = require("./harness")
local Footpath = require("../tools/builders/Footpath")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("Footpath", function()
    test("emits a ring of slabs for each garden tier, on that tier's surface", function()
        local spec = Footpath.build(ZenDojo.palette, L)
        local perTier = { [1] = 0, [2] = 0 }
        for _, c in spec.children :: any do
            local ti = tonumber(c.name:match("^PathSlab(%d)_"))
            if ti then
                perTier[ti] += 1
                local g
                for _, gt in L.gardenTiers do
                    if gt.tier == ti then
                        g = gt
                    end
                end
                local y = c.properties.CFrame[2]
                expect(math.abs(y - (g.height + 2)) < 2).toBe(true)
            end
        end
        expect(perTier[1] > 0).toBe(true)
        expect(perTier[2] > 0).toBe(true)
    end)

    test("ring slabs sit at the tier's pathR, clear of the channel band", function()
        local spec = Footpath.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            local ti = tonumber(c.name:match("^PathSlab(%d)_"))
            if ti then
                local x, z = c.properties.CFrame[1], c.properties.CFrame[3]
                local r = math.sqrt(x * x + z * z)
                local g
                for _, gt in L.gardenTiers do
                    if gt.tier == ti then
                        g = gt
                    end
                end
                expect(r < g.channelR - g.channelWidth / 2).toBe(true)
            end
        end
    end)

    test("is deterministic", function()
        local a = Footpath.build(ZenDojo.palette, L)
        local b = Footpath.build(ZenDojo.palette, L)
        expect(#a.children).toBe(#b.children)
    end)
end)
