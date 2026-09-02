--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkDirector = require("../src/shared/FireworkDirector")

describe("FireworkDirector — the concurrency budget", function()
    test("an empty sky renders at once", function()
        local d = FireworkDirector.admit(0, 100)
        expect(d.render).toBe(true)
        expect(d.delayMs).toBe(0)
    end)

    test("a full sky staggers rather than dropping — the burst still happens", function()
        local d = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT, 100)
        expect(d.render).toBe(true)
        expect(d.delayMs >= 100).toBe(true)
        expect(d.delayMs <= 300).toBe(true)
    end)

    test("the stagger grows with the overflow, so a burst of launches spreads out", function()
        local one = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT + 1, 100)
        local many = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT + 8, 100)
        expect(many.delayMs > one.delayMs).toBe(true)
    end)

    test("the stagger is bounded — a whole server firing cannot delay a shell forever", function()
        local absurd = FireworkDirector.admit(FireworkDirector.MAX_CONCURRENT + 5000, 100)
        expect(absurd.render).toBe(true)
        expect(absurd.delayMs <= 300).toBe(true)
    end)

    test("beyond DROP_STUDS a burst is dropped, not staggered", function()
        -- Too far to see. Rendering it costs fill-rate for pixels nobody looks at.
        local d = FireworkDirector.admit(0, FireworkDirector.DROP_STUDS + 1)
        expect(d.render).toBe(false)
    end)
end)

describe("FireworkDirector — distance LOD", function()
    test("near bursts get the full budget and sound", function()
        local l = FireworkDirector.lodFor(FireworkDirector.NEAR_STUDS - 1)
        expect(l.particles).toBe(FireworkDirector.PARTICLES_NEAR)
        expect(l.sound).toBe(true)
    end)

    test("far bursts are thinned but still HEARD -- audio reaches the far decks", function()
        -- Owner, 2026-09-05: cross-canyon audibility is the product premise; audio used to
        -- cut at NEAR_STUDS and a teahouse could not hear the bridge.
        local l = FireworkDirector.lodFor(FireworkDirector.FAR_STUDS + 1)
        expect(l.particles).toBe(FireworkDirector.PARTICLES_FAR)
        expect(l.sound).toBe(true)
    end)

    test("sound ends at AUDIBLE_STUDS, inside the render drop", function()
        expect(FireworkDirector.lodFor(FireworkDirector.AUDIBLE_STUDS - 1).sound).toBe(true)
        expect(FireworkDirector.lodFor(FireworkDirector.AUDIBLE_STUDS + 1).sound).toBe(false)
        expect(FireworkDirector.AUDIBLE_STUDS < FireworkDirector.DROP_STUDS).toBe(true)
    end)

    test("particle count never rises with distance", function()
        local prev = math.huge
        for d = 0, FireworkDirector.DROP_STUDS, 25 do
            local n = FireworkDirector.lodFor(d).particles
            expect(n <= prev).toBe(true)
            prev = n
        end
    end)

    test("NO BURST EVER COSTS MORE THAN THE NEAR BUDGET", function()
        -- The ceiling the mobile floor measurement bought. If a code path can exceed it, the
        -- measurement stops meaning anything.
        for d = 0, FireworkDirector.DROP_STUDS, 10 do
            expect(FireworkDirector.lodFor(d).particles <= FireworkDirector.PARTICLES_NEAR).toBe(true)
        end
    end)

    test("and never fewer than the far budget, however distant", function()
        expect(FireworkDirector.lodFor(FireworkDirector.DROP_STUDS).particles).toBe(
            FireworkDirector.PARTICLES_FAR
        )
    end)
end)
