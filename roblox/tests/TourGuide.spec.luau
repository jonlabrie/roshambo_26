--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local TourGuide = require("../src/shared/TourGuide")

describe("TourGuide — the step derived from what has been seen", function()
    test("a fresh player is on no tour", function()
        expect(TourGuide.step({})).toBe("NONE")
        expect(TourGuide.beamTag(TourGuide.step({}))).toBe(nil)
    end)

    test("dismissing the bank card starts the tour at the shop", function()
        -- seen ids are marked at DISMISSAL, so 'bank' in seen means the bank card was tapped
        -- away — exactly the moment the tour begins (spec §2).
        expect(TourGuide.step({ "welcome", "throw", "win", "bank" })).toBe("SHOP")
        expect(TourGuide.beamTag("SHOP")).toBe("TourStop_Shop")
    end)

    test("each tour card seen moves the beam one stop on", function()
        expect(TourGuide.step({ "bank", "shopDoor" })).toBe("SHOP") -- card read, shell not yet bought
        expect(TourGuide.step({ "bank", "shopDoor", "launchDoor" })).toBe("LAUNCH")
        expect(TourGuide.beamTag("LAUNCH")).toBe("TourStop_Launch")
        expect(TourGuide.step({ "bank", "shopDoor", "launchDoor", "modelDoor" })).toBe("MODEL")
        expect(TourGuide.beamTag("MODEL")).toBe("TourStop_Model")
    end)

    test("the model-home card seen ends the tour for good", function()
        expect(TourGuide.step({ "bank", "shopDoor", "launchDoor", "modelDoor", "modelHome" })).toBe("DONE")
        expect(TourGuide.beamTag("DONE")).toBe(nil)
    end)

    test("derivation survives a rejoin with holes — later ids dominate", function()
        -- a card can be marked seen while an earlier one was dropped; the FURTHEST id wins,
        -- so a resumed session never walks the guest backwards.
        expect(TourGuide.step({ "modelDoor" })).toBe("MODEL")
        expect(TourGuide.step({ "modelHome" })).toBe("DONE")
        expect(TourGuide.step({ "launchDoor", "bank" })).toBe("LAUNCH")
    end)

    test("order in the seen list is irrelevant", function()
        expect(TourGuide.step({ "modelDoor", "bank", "launchDoor", "shopDoor" })).toBe("MODEL")
    end)
end)
