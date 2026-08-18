--!strict
local harness = require("./harness")
local BirdFlight = require("../src/shared/BirdFlight")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("BirdFlight", function()
    test("idle orbits without drifting away", function()
        for t = 0, 10, 0.25 do
            expect(BirdFlight.magnitude(BirdFlight.offsetFor("IDLE", t, 7)) < 6).toBe(true)
        end
    end)

    test("WIN rises — the only state whose height increases", function()
        local a = BirdFlight.offsetFor("WIN", 0.1, 7)
        local b = BirdFlight.offsetFor("WIN", 1.5, 7)
        expect(b.y > a.y).toBe(true)
    end)

    test("SAFE settles onto a perch and STAYS there", function()
        local a = BirdFlight.offsetFor("SAFE", 1.5, 7)
        local b = BirdFlight.offsetFor("SAFE", 2.0, 7)
        expect(BirdFlight.distance(a, b) < 0.05).toBe(true)
        -- shoulder height, not overhead: a landed bird is the whole point
        expect(a.y < 3).toBe(true)
    end)

    test("LOSS darts away and comes back", function()
        local away = BirdFlight.offsetFor("LOSS", 0.5, 7)
        local back = BirdFlight.offsetFor("LOSS", BirdFlight.DURATION.LOSS, 7)
        local idle = BirdFlight.offsetFor("IDLE", BirdFlight.DURATION.LOSS, 7)
        expect(BirdFlight.magnitude(away) > 8).toBe(true)
        -- lands back ON the idle orbit, so nothing snaps when the state expires
        expect(BirdFlight.distance(back, idle) < 1.5).toBe(true)
    end)

    test("every state returns to IDLE when its beat is over", function()
        for _, s in { "WIN", "SAFE", "LOSS" } do
            expect(BirdFlight.stateAfter(s, BirdFlight.DURATION[s] + 0.01)).toBe("IDLE")
            expect(BirdFlight.stateAfter(s, 0.1)).toBe(s)
        end
    end)

    test("is deterministic per seed, so two clients draw the same bird", function()
        local a = BirdFlight.offsetFor("IDLE", 3.3, 7)
        local b = BirdFlight.offsetFor("IDLE", 3.3, 7)
        local other = BirdFlight.offsetFor("IDLE", 3.3, 8)
        expect(BirdFlight.distance(a, b)).toBe(0)
        expect(BirdFlight.distance(a, other) > 0).toBe(true)
    end)
end)
