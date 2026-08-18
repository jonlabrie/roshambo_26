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

    test("WIN rises, and STAYS up for the rest of the round", function()
        local a = BirdFlight.offsetFor("WIN", 0.1, 7)
        local b = BirdFlight.offsetFor("WIN", 1.5, 7)
        expect(b.y > a.y).toBe(true)
        -- the point of the change: a result is a standing display, not a flourish. Long after the
        -- entry animation it is still visibly high.
        for _, t in { 5, 20, 55 } do
            expect(BirdFlight.offsetFor("WIN", t, 7).y > 6).toBe(true)
        end
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
        for _, t in { 5, 20, 55 } do
            expect(BirdFlight.offsetFor("LOSS", t, 7).y < 1.6).toBe(true)
        end
    end)

    test("a loss never looks like a player who has not thrown yet", function()
        -- Returning to the idle orbit would make those two states identical, which is the reason
        -- LOSS holds low rather than simply coming home.
        for _, t in { 5, 20, 55 } do
            local lost = BirdFlight.offsetFor("LOSS", t, 7)
            local idle = BirdFlight.offsetFor("RESTING", t, 7)
            expect(BirdFlight.distance(lost, idle) > 1.5).toBe(true)
        end
    end)

    test("the three holds that differ are separable by HEIGHT alone, across a room", function()
        local win = BirdFlight.offsetFor("WIN", 30, 7).y
        local resting = BirdFlight.offsetFor("RESTING", 30, 7).y
        local loss = BirdFlight.offsetFor("LOSS", 30, 7).y
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
