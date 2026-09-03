--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudLayout = require("../src/shared/HudLayout")

describe("HudLayout — the cluster the onboarding band has to clear", function()
    test("the cluster is bank + throws + tape, and nothing else", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH).toBe(
            HudLayout.EDGE + HudLayout.AREA_H_TOUCH + HudLayout.BANK_GAP + HudLayout.BANK_H
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

    test("BANK_GAP is the gap above the cluster, not a number nobody uses", function()
        -- It was declared for this gap and then only OnboardingController read it, while
        -- HudController and CLUSTER_TOP_FROM_BOTTOM both positioned the row with ROW_GAP. The
        -- two are different numbers, so the derivation above is what pins the repair: if a
        -- later edit puts ROW_GAP back, this fails.
        expect(HudLayout.BANK_GAP ~= HudLayout.ROW_GAP).toBe(true)
    end)

    test("the bank button stays comfortably hittable", function()
        -- The owner's ruling (spec §3): 36, not 32. Banking is the one irreversible action on
        -- this surface and a mis-tap costs real points. The throw buttons' 44px floor does not
        -- bind here — that floor is for the three targets hit every round under time pressure.
        expect(HudLayout.BANK_H).toBe(36)
    end)
end)

describe("HudLayout — the ring beside the throw buttons", function()
    test("the ring is exactly a throw button at both tiers", function()
        -- It is a target now, not a readout. Sizing it to the tape would make the ledger's only
        -- door smaller than every other control on the surface.
        expect(HudLayout.RING_D).toBe(HudLayout.BTN_H)
        expect(HudLayout.RING_D_TOUCH).toBe(HudLayout.BTN_H_TOUCH)
        expect(HudLayout.RING_D_TOUCH >= 44).toBe(true)
    end)

    test("the band stays visible at both tiers, and the phone's is the narrower", function()
        -- No longer a proportional stroke around a ragged segment ring: the band is a literal per
        -- tier, because the pie's inner edge is the centre disc's edge and needs no approximating.
        -- What still has to hold is that neither tier's band vanishes, and that the phone — whose
        -- ring is the smaller circle — carries the narrower band, so the centre keeps its room.
        expect(HudLayout.RING_THICKNESS >= 3).toBe(true)
        expect(HudLayout.RING_THICKNESS_TOUCH >= 3).toBe(true)
        expect(HudLayout.RING_THICKNESS > HudLayout.RING_THICKNESS_TOUCH).toBe(true)
    end)

    test("the cluster does NOT grow for the ring", function()
        -- The ring sits beside the throw buttons, not in the tape's row, so AREA_H keeps its
        -- original derivation. Growing it here would push the whole cluster up for nothing.
        expect(HudLayout.AREA_H).toBe(HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.TILE)
        expect(HudLayout.AREA_H_TOUCH).toBe(HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.TILE_TOUCH)
        expect((HudLayout :: any).BOTTOM_ROW_H).toBe(nil)
    end)

    test("the cluster still covers bank + throws + tape", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch throw target still clears the 44px floor", function()
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

    -- This module used to hold plain numbers only, then briefly gained `plateBottomOffset` (a
    -- function) while the plate measured the jump button at runtime — deleted when the owner
    -- moved the plate (2026-08-03), because it measured ROBLOX GEOMETRY at runtime. Amended
    -- 2026-09-03 for `clusterRef`: PURE functions of this module's own numbers are allowed —
    -- the enforcement's purpose is that `src/shared` stays Lune-testable (no tables, no Roblox
    -- instances, no runtime measuring), and a pure function under its own specs below IS
    -- Lune-tested. What stays banned is state and anything touching a Roblox global.
    test("holds no Roblox globals — numbers and pure functions only", function()
        for key, value in HudLayout do
            expect(typeof(key)).toBe("string")
            expect(typeof(value) == "number" or typeof(value) == "function").toBe(true)
        end
    end)
end)

describe("HudLayout — the cluster's horizontal reference (clusterRef)", function()
    test("AREA_W is the three-button row, derived, both tiers", function()
        expect(HudLayout.AREA_W).toBe(3 * HudLayout.BTN_H + 2 * HudLayout.BTN_GAP)
        expect(HudLayout.AREA_W_TOUCH).toBe(3 * HudLayout.BTN_H_TOUCH + 2 * HudLayout.BTN_GAP_TOUCH)
    end)

    test("landscape keeps the owner's right-thumb registration, untouched", function()
        -- "Don't move the landscape HUD, players need to be able to reach it with their right
        -- thumbs to throw" (owner, 2026-09-03). Same answer at both tiers.
        local s, o = HudLayout.clusterRef(844, 390, true)
        expect(s).toBe(1 - HudLayout.JUMP_CLEARANCE)
        expect(o).toBe(0)
        s, o = HudLayout.clusterRef(1920, 1080, false)
        expect(s).toBe(1 - HudLayout.JUMP_CLEARANCE)
        expect(o).toBe(0)
    end)

    test("a square viewport is landscape — portrait is strictly taller than wide", function()
        local s = HudLayout.clusterRef(500, 500, true)
        expect(s).toBe(1 - HudLayout.JUMP_CLEARANCE)
    end)

    test("portrait centres the ring+buttons row between the thumbstick and jump zones", function()
        -- The offset is HALF the always-visible row (ring + gap + three buttons): with the
        -- right edge anchored at 0.5 + offset, the row's own centre lands on screen centre.
        local s, o = HudLayout.clusterRef(390, 844, true)
        expect(s).toBe(0.5)
        expect(o).toBe((HudLayout.RING_D_TOUCH + HudLayout.RING_GAP + HudLayout.AREA_W_TOUCH) / 2)
        s, o = HudLayout.clusterRef(390, 844, false)
        expect(s).toBe(0.5)
        expect(o).toBe((HudLayout.RING_D + HudLayout.RING_GAP + HudLayout.AREA_W) / 2)
    end)

    test("the portrait cluster fits a narrow phone with margin on both sides", function()
        -- iPhone portrait is ~390 logical px. Right edge at 0.5*390 + offset must clear the
        -- jump button's corner (~85px), and the ring's left edge must stay on screen.
        local _, o = HudLayout.clusterRef(390, 844, true)
        local rowW = HudLayout.RING_D_TOUCH + HudLayout.RING_GAP + HudLayout.AREA_W_TOUCH
        local rightEdge = 390 * 0.5 + o
        expect(rightEdge <= 390 - 85).toBe(true)
        expect(rightEdge - rowW >= 0).toBe(true)
    end)
end)
