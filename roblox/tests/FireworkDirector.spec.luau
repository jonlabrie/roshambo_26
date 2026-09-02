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

describe("FireworkDirector — heavy shells (the L tube's weight)", function()
    test("weight multiplies the particle budget at every band", function()
        for _, d in { 0, FireworkDirector.NEAR_STUDS + 100, FireworkDirector.DROP_STUDS } do
            local base = FireworkDirector.lodFor(d).particles
            local heavy = FireworkDirector.lodFor(d, FireworkDirector.WEIGHT_HEAVY).particles
            expect(heavy).toBe(base * FireworkDirector.WEIGHT_HEAVY)
        end
    end)

    test("weight 1 (and nil) is byte-identical to today's budget", function()
        for d = 0, FireworkDirector.DROP_STUDS, 50 do
            expect(FireworkDirector.lodFor(d, 1).particles).toBe(FireworkDirector.lodFor(d).particles)
        end
    end)

    test("THE WEIGHTED CEILING HOLDS: no burst exceeds NEAR x its declared weight", function()
        -- The mobile-floor measurement's invariant, restated for weights: a heavy shell
        -- spends more because it is CHARGED more (weighted admission), never for free.
        for d = 0, FireworkDirector.DROP_STUDS, 10 do
            local heavy = FireworkDirector.lodFor(d, FireworkDirector.WEIGHT_HEAVY).particles
            expect(heavy <= FireworkDirector.PARTICLES_NEAR * FireworkDirector.WEIGHT_HEAVY).toBe(true)
        end
    end)

    test("weight never changes the sound gate", function()
        local d = FireworkDirector.AUDIBLE_STUDS - 1
        expect(FireworkDirector.lodFor(d, FireworkDirector.WEIGHT_HEAVY).sound).toBe(true)
        local far = FireworkDirector.AUDIBLE_STUDS + 1
        expect(FireworkDirector.lodFor(far, FireworkDirector.WEIGHT_HEAVY).sound).toBe(false)
    end)
end)
