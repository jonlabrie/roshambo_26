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
        -- 3 tiers x 8 = 24 candidate positions on each tier's flat plateau. At the
        -- current coordinates the half-step ring (22.5°,67.5°,…) threads cleanly
        -- past the sandō gap, creek, koi pond and promontories — all 24 survive.
        -- (Re-pin if ArenaLayout coordinates change.)
        expect(lanterns).toBe(24)
    end)

    test("dressing is lanterns only — no open-air seating", function()
        local spec = TerraceDressing.build(ZenDojo.palette, L)
        for _, c in spec.children :: any do
            expect(c.name:match("^Cushion_") == nil).toBe(true)
            expect(c.name:match("^Table_") == nil).toBe(true)
        end
    end)
end)
