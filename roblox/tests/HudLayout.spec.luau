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

describe("HudLayout — the ring shares the bottom row with the tape", function()
    test("the ring is exactly a throw button at both tiers", function()
        -- It is a target now, not a readout. Sizing it to the tape would make the ledger's only
        -- door smaller than every other control on the surface.
        expect(HudLayout.RING_D).toBe(HudLayout.BTN_H)
        expect(HudLayout.RING_D_TOUCH).toBe(HudLayout.BTN_H_TOUCH)
        expect(HudLayout.RING_D_TOUCH >= 44).toBe(true)
    end)

    test("the stroke scales with the ring and never vanishes", function()
        expect(HudLayout.RING_THICKNESS >= 3).toBe(true)
        expect(HudLayout.RING_THICKNESS_TOUCH >= 3).toBe(true)
        expect(HudLayout.RING_THICKNESS > HudLayout.RING_THICKNESS_TOUCH).toBe(true)
    end)

    test("the bottom row is as tall as its tallest occupant", function()
        -- The tape and the ring sit side by side. A row derived from the tape alone would let a
        -- taller ring hang out of the cluster the onboarding band is clamped against.
        expect(HudLayout.BOTTOM_ROW_H).toBe(math.max(HudLayout.TILE, HudLayout.RING_D))
        expect(HudLayout.BOTTOM_ROW_H_TOUCH).toBe(math.max(HudLayout.TILE_TOUCH, HudLayout.RING_D_TOUCH))
    end)

    test("AREA_H is buttons + gap + the bottom row", function()
        expect(HudLayout.AREA_H).toBe(HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H)
        expect(HudLayout.AREA_H_TOUCH).toBe(
            HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H_TOUCH
        )
    end)

    test("the cluster still covers bank + throws + bottom row", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch throw target still clears the 44px floor", function()
        expect(HudLayout.BTN_H_TOUCH >= 44).toBe(true)
    end)
end)

-- Carried forward from before this task: this task did not touch BTN_H, TILE, THROW_TOUCH_SCALE
-- or TAPE_TOUCH_SCALE, but it DID re-derive AREA_H from BOTTOM_ROW_H instead of TILE directly
-- (the ring, not the tape, now sets the bottom row's height). These assert the derivation
-- itself — not a value read back from the module — so a later edit to any of those primitives
-- that silently moves the cluster fails here rather than only in whichever file hand-copied the
-- old number (see the module header's warning at HudLayout.luau:7-10).
describe("HudLayout — derivation of the cluster's own primitives", function()
    test("AREA_H is the tape+buttons cluster, derived", function()
        expect(HudLayout.AREA_H).toBe(HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H)
    end)

    test("AREA_H_TOUCH is the shrunken cluster, derived", function()
        expect(HudLayout.AREA_H_TOUCH).toBe(
            HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H_TOUCH
        )
    end)

    test("the touch tier shrinks the throw button and the tape", function()
        expect(HudLayout.BTN_H_TOUCH).toBe(math.round(HudLayout.BTN_H * HudLayout.THROW_TOUCH_SCALE))
        expect(HudLayout.TILE_TOUCH).toBe(math.round(HudLayout.TILE * HudLayout.TAPE_TOUCH_SCALE))
        expect(HudLayout.BTN_H_TOUCH < HudLayout.BTN_H).toBe(true)
        expect(HudLayout.TILE_TOUCH < HudLayout.TILE).toBe(true)
    end)

    -- This module used to hold plain numbers only, then briefly gained `plateBottomOffset` (a
    -- function) while the plate measured the jump button at runtime. The owner moved the plate
    -- into the bottom row instead (2026-08-03, mid-execution) and that function was deleted with
    -- its three tests below — this module is back to numbers only, so the assertion is back to
    -- what it originally was. This is the only automated enforcement in this file that
    -- `src/shared` stays Lune-testable (no tables, no Roblox instances, no functions) as the
    -- module grows.
    test("holds no Roblox globals — numbers only", function()
        for key, value in HudLayout do
            expect(typeof(key)).toBe("string")
            expect(typeof(value)).toBe("number")
        end
    end)
end)
