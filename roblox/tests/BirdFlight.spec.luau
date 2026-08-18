--!strict
local harness = require("./harness")
local BirdFlight = require("../src/shared/BirdFlight")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BirdFlight", function()
    test("idle orbits without drifting away", function()
        for t = 0, 10, 0.25 do
            expect(BirdFlight.magnitude(BirdFlight.offsetFor("RESTING", t, 7)) < 6).toBe(true)
        end
    end)

    test("WIN rises, and stays up long enough to be noticed", function()
        local a = BirdFlight.offsetFor("WIN", 0.1, 7)
        local b = BirdFlight.offsetFor("WIN", 1.5, 7)
        expect(b.y > a.y).toBe(true)
        -- A result must outlast the instant it happened -- glancing over a few seconds later
        -- should still tell you what happened.
        for _, t in { 3, 8, 14 } do
            expect(BirdFlight.offsetFor("WIN", t, 7).y > 6).toBe(true)
        end
    end)

    test("a result LAPSES, so a bird does not wear it until the next round", function()
        -- It used to hold for the whole ~60s round, which the owner found too long: the bird just
        -- hovered instead of going back to living in the world.
        for _, s in { "WIN", "LOSS" } do
            expect(BirdFlight.stateAfter(s, BirdFlight.RESULT_HOLD - 1)).toBe(s)
            expect(BirdFlight.stateAfter(s, BirdFlight.RESULT_HOLD + 1)).toBe("RESTING")
        end
        -- resting never lapses into anything
        expect(BirdFlight.stateAfter("RESTING", 9999)).toBe("RESTING")
    end)

    test("SAFE has NO behaviour — nothing changed, so the bird does not change", function()
        for _, t in { 1, 10, 40 } do
            expect(
                BirdFlight.distance(BirdFlight.offsetFor("SAFE", t, 7), BirdFlight.offsetFor("RESTING", t, 7))
            ).toBe(0)
        end
    end)

    test("LOSS bolts, then SINKS and stays low", function()
        expect(BirdFlight.magnitude(BirdFlight.offsetFor("LOSS", 0.5, 7)) > 8).toBe(true)
        for _, t in { 3, 8, 14 } do
            expect(BirdFlight.offsetFor("LOSS", t, 7).y < 1.6).toBe(true)
        end
    end)

    test("a loss never looks like a player who has not thrown yet", function()
        -- Returning to the idle orbit would make those two states identical, which is the reason
        -- LOSS holds low rather than simply coming home.
        for _, t in { 3, 8, 14 } do
            local lost = BirdFlight.offsetFor("LOSS", t, 7)
            local idle = BirdFlight.offsetFor("RESTING", t, 7)
            expect(BirdFlight.distance(lost, idle) > 1.5).toBe(true)
        end
    end)

    test("the three holds that differ are separable by HEIGHT alone, across a room", function()
        local win = BirdFlight.offsetFor("WIN", 10, 7).y
        local resting = BirdFlight.offsetFor("RESTING", 10, 7).y
        local loss = BirdFlight.offsetFor("LOSS", 10, 7).y
        expect(win > resting + 3).toBe(true)
        expect(resting > loss + 1.5).toBe(true)
    end)

    test("is deterministic per seed, so two clients draw the same bird", function()
        local a = BirdFlight.offsetFor("RESTING", 3.3, 7)
        local b = BirdFlight.offsetFor("RESTING", 3.3, 7)
        local other = BirdFlight.offsetFor("RESTING", 3.3, 8)
        expect(BirdFlight.distance(a, b)).toBe(0)
        expect(BirdFlight.distance(a, other) > 0).toBe(true)
    end)
end)
