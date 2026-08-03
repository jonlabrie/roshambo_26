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

-- Carried forward from before this task, unchanged: this task did not touch BTN_H, TILE,
-- THROW_TOUCH_SCALE, TAPE_TOUCH_SCALE or the AREA_H formulas built on them. These assert the
-- derivation itself — not a value read back from the module — so a later edit to any of those
-- primitives that silently moves the cluster fails here rather than only in whichever file
-- hand-copied the old number (see the module header's warning at HudLayout.luau:7-10).
describe("HudLayout — derivation of the cluster's own primitives", function()
    test("AREA_H is the tape+buttons cluster, derived", function()
        expect(HudLayout.AREA_H).toBe(HudLayout.TILE + HudLayout.ROW_GAP + HudLayout.BTN_H)
    end)

    test("AREA_H_TOUCH is the shrunken cluster, derived", function()
        expect(HudLayout.AREA_H_TOUCH).toBe(HudLayout.TILE_TOUCH + HudLayout.ROW_GAP + HudLayout.BTN_H_TOUCH)
    end)

    test("the touch tier shrinks the throw button and the tape", function()
        expect(HudLayout.BTN_H_TOUCH).toBe(math.round(HudLayout.BTN_H * HudLayout.THROW_TOUCH_SCALE))
        expect(HudLayout.TILE_TOUCH).toBe(math.round(HudLayout.TILE * HudLayout.TAPE_TOUCH_SCALE))
        expect(HudLayout.BTN_H_TOUCH < HudLayout.BTN_H).toBe(true)
        expect(HudLayout.TILE_TOUCH < HudLayout.TILE).toBe(true)
    end)

    -- Adapted, not dropped: the module used to hold plain numbers only, so this asserted
    -- `typeof(value) == "number"` for every entry. `plateBottomOffset` is now a deliberate
    -- exception (see the module header), so a function is allowed too — but nothing else. This
    -- is the only automated enforcement in this file that `src/shared` stays Lune-testable
    -- (no tables, no Roblox instances) as the module grows.
    test("holds no Roblox globals — numbers and pure functions only", function()
        for key, value in HudLayout do
            expect(typeof(key)).toBe("string")
            expect(typeof(value) == "number" or typeof(value) == "function").toBe(true)
        end
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
