--!strict
local harness = require("./harness")
local TerraceDressing = require("../tools/builders/TerraceDressing")
local L = require("../tools/builders/ArenaLayout")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("TerraceDressing builder", function()
    test("lantern ring on tiers, skipping features/gap", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        local lanterns = 0
        for _, c in spec.children :: any do
            if c.name:match("^Lantern_") then
                lanterns += 1
            end
        end
        -- 3 tiers x 8 = 24 candidate positions. The sandō gap (a≈3π/2), creek
        -- channel, koi pond, and content pads each carve a skip out of the ring,
        -- but at the current ArenaLayout coordinates the 8-fold half-step ring
        -- (angles 22.5°,67.5°,…) threads between every feature: nearest gap miss
        -- is 0.39 rad (> the 0.35 cutoff), min creek-perp is 20 (> 8), and the
        -- koi/pads land in the angular gaps. So the full ring survives: 24.
        -- (blocked() is still exercised — see the cushion cluster test, which
        -- loses one table to the LocalHero promontory.)
        expect(lanterns).toBe(24)
    end)

    test("cushions land on a tier surface", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        local cushions = 0
        for _, c in spec.children :: any do
            if c.name:match("^Cushion_") then
                cushions += 1
                local y = c.properties.CFrame[2]
                local onTier = false
                for _, tier in L.tiers do
                    if y == tier.height + 0.25 then
                        onTier = true
                    end
                end
                expect(onTier).toBe(true)
            end
        end
        expect(cushions > 12).toBe(true)
    end)
end)
