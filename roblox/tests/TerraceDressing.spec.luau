--!strict
local harness = require("./harness")
local TerraceDressing = require("../tools/builders/TerraceDressing")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("TerraceDressing lanterns", function()
    test("no lantern sits in a garden tier's channel band", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        for _, lan in spec.children :: any do
            local ti = tonumber(lan.name:match("^Lantern_(%d)_"))
            local base
            for _, p in lan.children do
                if p.name == "Base" then
                    base = p
                end
            end
            local x, z = base.properties.CFrame[1], base.properties.CFrame[3]
            local r = math.sqrt(x * x + z * z)
            for _, g in L.gardenTiers do
                if g.tier == ti then
                    local inBand = r > g.channelR - g.channelWidth / 2 - 2
                        and r < g.channelR + g.channelWidth / 2 + 2
                    expect(inBand).toBe(false)
                end
            end
        end
    end)

    test("garden-tier lanterns sit just inside the path", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        for _, lan in spec.children :: any do
            local ti = tonumber(lan.name:match("^Lantern_(%d)_"))
            local base
            for _, p in lan.children do
                if p.name == "Base" then
                    base = p
                end
            end
            local x, z = base.properties.CFrame[1], base.properties.CFrame[3]
            local r = math.sqrt(x * x + z * z)
            for _, g in L.gardenTiers do
                if g.tier == ti then
                    expect(r < g.pathR).toBe(true)
                end
            end
        end
    end)
end)
