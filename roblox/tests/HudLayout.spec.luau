--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudLayout = require("../src/shared/HudLayout")

describe("HudLayout — the cluster the onboarding band has to clear", function()
    test("the cluster is bank + throws + tape, and nothing else", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH).toBe(
            HudLayout.EDGE + HudLayout.AREA_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch cluster is shorter than the pointer one", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH < HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(true)
    end)

    test("the confirm strip is gone", function()
        expect((HudLayout :: any).CONFIRM_H).toBe(nil)
        expect((HudLayout :: any).CONFIRM_GAP).toBe(nil)
    end)

    test("the plate no longer reserves a band at the top", function()
        expect((HudLayout :: any).PLATE_BOTTOM).toBe(nil)
    end)

    test("the touch throw target clears the 44px floor", function()
        expect(HudLayout.BTN_H_TOUCH >= 44).toBe(true)
    end)
end)

describe("HudLayout.plateBottomOffset — where the plate sits above the jump button", function()
    test("with no jump button it falls back to the screen edge", function()
        expect(HudLayout.plateBottomOffset(400, nil)).toBe(HudLayout.EDGE)
    end)

    test("it clears a measured button by PLATE_JUMP_GAP", function()
        -- gui bottom at y=400, jump button's top edge at y=310 -> 90 up from the bottom, plus
        -- the gap.
        expect(HudLayout.plateBottomOffset(400, 310)).toBe(90 + HudLayout.PLATE_JUMP_GAP)
    end)

    test("a button measured below the screen edge cannot push the plate off-screen", function()
        -- Defensive: AbsolutePosition is read live and can be stale or nonsense for a frame.
        expect(HudLayout.plateBottomOffset(400, 500)).toBe(HudLayout.EDGE)
    end)
end)
