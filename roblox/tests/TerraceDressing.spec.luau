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
        -- 3 tiers x 8 = 24 candidate positions on each tier's flat plateau. The
        -- sandō gap (a≈3π/2) carves one out, and now that the ring sits at the
        -- plateau mid-radius (where the content pads live) one more lantern lands
        -- close enough to a promontory/teahouse pad for blocked() to skip it.
        -- Net surviving: 23. (Re-pin if ArenaLayout coordinates change.)
        expect(lanterns).toBe(23)
    end)

    test("cushions land on a tier surface", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        local cushions = 0
        for _, c in spec.children :: any do
            if c.name:match("^Cushion_") then
                cushions += 1
                local y = c.properties.CFrame[2]
                -- rests just above a tier surface (tier.height + a small ground-lift)
                local onTier = false
                for _, tier in L.tiers do
                    if y > tier.height and y <= tier.height + 4 then
                        onTier = true
                    end
                end
                expect(onTier).toBe(true)
            end
        end
        expect(cushions > 12).toBe(true)
    end)
end)
