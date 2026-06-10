--!strict
local harness = require("./harness")
local Foliage = require("../tools/builders/Foliage")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function clusterCount(spec: any, prefix: string): number
    local n = 0
    for _, c in spec.children :: any do
        if c.name:match("^" .. prefix) then
            n += 1
        end
    end
    return n
end

describe("Foliage", function()
    test("places the hero weeping cherry at the layout anchor", function()
        local spec = Foliage.build(ZenDojo.palette, L)
        local cherry
        for _, c in spec.children :: any do
            if c.name == "Cherry" then
                cherry = c
            end
        end
        expect(cherry ~= nil).toBe(true)
        local trunk
        for _, p in cherry.children do
            if p.name == "Trunk" then
                trunk = p
            end
        end
        expect(math.abs(trunk.properties.CFrame[1] - L.foliage.heroCherry[1]) < 0.01).toBe(true)
    end)

    test("scatters maples, pines and bamboo", function()
        local spec = Foliage.build(ZenDojo.palette, L)
        expect(clusterCount(spec, "Maple") > 0).toBe(true)
        expect(clusterCount(spec, "Pine") > 0).toBe(true)
        expect(clusterCount(spec, "Bamboo") > 0).toBe(true)
    end)

    test("keeps trees off the channel water", function()
        local spec = Foliage.build(ZenDojo.palette, L)
        for _, tree in spec.children :: any do
            local trunk
            for _, p in tree.children do
                if p.name == "Trunk" then
                    trunk = p
                end
            end
            if trunk then
                local x, z = trunk.properties.CFrame[1], trunk.properties.CFrame[3]
                local r = math.sqrt(x * x + z * z)
                for _, g in L.gardenTiers do
                    local inChannel = r > g.channelR - g.channelWidth / 2 - 1
                        and r < g.channelR + g.channelWidth / 2 + 1
                    expect(inChannel).toBe(false)
                end
            end
        end
    end)

    test("is deterministic", function()
        expect(#Foliage.build(ZenDojo.palette, L).children).toBe(#Foliage.build(ZenDojo.palette, L).children)
    end)
end)
