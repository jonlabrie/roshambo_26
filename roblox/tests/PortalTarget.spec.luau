--!strict
local harness = require("./harness")
local PortalTarget = require("../src/shared/PortalTarget")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("PortalTarget.deckLanding", function()
    test("identity rotation: landing = deck position + the size's local offset", function()
        local deckCF = { 10, 200, -5, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        local r = PortalTarget.deckLanding(deckCF, "L")
        local o = PortalTarget.DECK_LANDING_LOCAL.L
        expect(r[1]).toBeCloseTo(10 + o[1])
        expect(r[2]).toBeCloseTo(200 + o[2])
        expect(r[3]).toBeCloseTo(-5 + o[3])
        expect(r[4]).toBeCloseTo(1) -- rotation preserved
        expect(r[12]).toBeCloseTo(1)
    end)
    test("rotates the local offset by the deck's yaw (90deg)", function()
        -- yaw 90: rotation rows r00=0,r02=1 ; r20=-1,r22=0 (matches BuildingPlacer's convention)
        local deckCF = { 0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }
        local r = PortalTarget.deckLanding(deckCF, "L")
        local o = PortalTarget.DECK_LANDING_LOCAL.L
        expect(r[1]).toBeCloseTo(o[3]) -- wx = r02*oz = oz
        expect(r[3]).toBeCloseTo(-o[1]) -- wz = r20*ox = -ox
    end)
    test("all three sizes resolve", function()
        local deckCF = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
        for _, s in { "S", "M", "L" } do
            expect(#PortalTarget.deckLanding(deckCF, s)).toBe(12)
        end
    end)
end)

describe("PortalTarget arena constants", function()
    test("ARENA_PORTAL_CF and ARENA_LANDING are 12-number CFrames", function()
        expect(#PortalTarget.ARENA_PORTAL_CF).toBe(12)
        expect(#PortalTarget.ARENA_LANDING).toBe(12)
    end)
end)
