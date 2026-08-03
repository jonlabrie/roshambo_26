--!strict
local harness = require("./harness")
local HudLayout = require("../src/shared/HudLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

-- These look tautological read as arithmetic, and that is the point: the derived numbers used to be
-- hand-computed literals in two files (`AREA_H = 120`), and the failure mode is someone tweaking a
-- primitive here — BTN_H, SLOT_H — while a stale literal elsewhere goes on describing the old
-- layout. Asserting DERIVATION rather than a value is what fails if a future edit re-freezes one.
describe("HudLayout", function()
    test("AREA_H is the tape+buttons cluster, derived", function()
        expect(HudLayout.AREA_H).toBe(HudLayout.TILE + HudLayout.ROW_GAP + HudLayout.BTN_H)
    end)

    test("PLATE_BOTTOM is the plate's footprint from the top edge, derived", function()
        expect(HudLayout.PLATE_BOTTOM).toBe(HudLayout.EDGE + HudLayout.PLATE_H)
    end)

    test("CLUSTER_TOP_FROM_BOTTOM covers the slot as well as the cluster, derived", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.SLOT_H
        )
    end)

    test("the two bands leave a usable gap on a short landscape phone", function()
        -- 375px is the shortest viewport this HUD targets (landscape phone). The safe band the
        -- onboarding card is clamped into is what is left between the two footprints; if a future
        -- tweak ate it entirely, cards would have nowhere legal to go and the clamp would collapse
        -- onto one of the live buttons.
        local band = 375 - HudLayout.PLATE_BOTTOM - HudLayout.CLUSTER_TOP_FROM_BOTTOM
        expect(band > 0).toBe(true)
    end)

    test("holds no Roblox globals — plain numbers only", function()
        for key, value in HudLayout do
            expect(typeof(key)).toBe("string")
            expect(typeof(value)).toBe("number")
        end
    end)
end)
