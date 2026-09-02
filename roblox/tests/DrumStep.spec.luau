--!strict
local harness = require("./harness")
local DrumStep = require("../src/shared/DrumStep")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("DrumStep (12 faces)", function()
    test("faceForThrow maps R/P/S to 0/1/2", function()
        expect(DrumStep.faceForThrow("R")).toBe(0)
        expect(DrumStep.faceForThrow("P")).toBe(1)
        expect(DrumStep.faceForThrow("S")).toBe(2)
    end)
    test("symmetric steps +3 (90 degrees) and preserves the symbol", function()
        for i = 0, 11 do
            expect(DrumStep.symmetric(i)).toBe((i + 3) % 12)
            expect(DrumStep.symmetric(i) % 3).toBe(i % 3)
        end
    end)
    test("landingStep lands on the throw's symbol within 1..3 steps, over 12 faces", function()
        for cur = 0, 11 do
            for _, t in { "R", "P", "S" } do
                local f = DrumStep.landingStep(cur, t)
                expect(f % 3).toBe(DrumStep.faceForThrow(t))
                local steps = (f - cur) % 12
                expect(steps >= 1 and steps <= 3).toBe(true)
            end
        end
    end)
end)

-- The settle duration is the number the SERVER schedules the winner's avatar grow against, so it is
-- asserted as a DERIVATION rather than a literal: a future tweak to the swing, the spin or the glide
-- has to move the grow with it, and a hand-copied 3.45 somewhere would go on describing the old
-- choreography while the drum turned to a different beat.
describe("DrumStep — the strike-to-rest timing", function()
    test("SETTLE_SECONDS is swing + spin + glide, derived", function()
        expect(DrumStep.SETTLE_SECONDS).toBe(
            DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS
        )
    end)

    test("every leg is a positive duration", function()
        for _, key in { "STRIKE_SWING_SECONDS", "SPIN_SECONDS", "GLIDE_SECONDS", "SETTLE_SECONDS" } do
            expect(typeof((DrumStep :: any)[key])).toBe("number")
            expect((DrumStep :: any)[key] > 0).toBe(true)
        end
    end)
end)

-- THE FALLBACK MUST SIT BEHIND THE DRUM. main.client.luau releases the round's result on `drumRest`
-- with these as the safety windows if that cue is lost. The old fallback was a flat 3s armed from
-- RevealResult ARRIVING and it won the race on every instrumented round, showing the glyph while the
-- drum was still gliding onto its detent — so what is asserted here is the RELATION to the
-- choreography, not the numbers: a fallback that is not strictly longer than the rest it protects is
-- a spoiler, whichever literal it happens to hold.
describe("DrumStep — the reveal-safety windows", function()
    test("the normal window clears the whole strike-to-rest chain, with margin", function()
        expect(DrumStep.SAFETY_MARGIN_SECONDS > 0).toBe(true)
        expect(DrumStep.SAFETY_AFTER_STRIKE_SECONDS).toBe(
            DrumStep.SETTLE_SECONDS + DrumStep.SAFETY_MARGIN_SECONDS
        )
        expect(DrumStep.SAFETY_AFTER_STRIKE_SECONDS > DrumStep.SETTLE_SECONDS).toBe(true)
    end)

    test("the stalled window also clears the stall", function()
        -- DrumController waits STALL_MAX_SECONDS past the end of the spin for a late World Throw
        -- before it settles at all; a fallback that ignored that would merely race a different way.
        expect(DrumStep.STALL_MAX_SECONDS > 0).toBe(true)
        expect(DrumStep.SAFETY_AFTER_STRIKE_STALLED_SECONDS).toBe(
            DrumStep.SAFETY_AFTER_STRIKE_SECONDS + DrumStep.STALL_MAX_SECONDS
        )
        -- The worst legitimate rest, measured from the strike: swing + spin + stall + glide.
        local worstRest = DrumStep.SETTLE_SECONDS + DrumStep.STALL_MAX_SECONDS
        expect(DrumStep.SAFETY_AFTER_STRIKE_STALLED_SECONDS > worstRest).toBe(true)
    end)
end)

-- THE DRUM IS AUTHORITATIVE (owner's ruling, 2026-08-04). A round four attempt let the personal
-- result splash fire ahead of `drumRest` — first at a fixed lead, then refined to a trigger on the
-- glide's residual angle. Both violated the rule: nothing may reflect the world's throw anywhere
-- else until the drum has fully settled on it. That arithmetic and its threshold constant have
-- been retracted; see DrumStep's header for where they used to live and why they are gone.
-- KICK_OMEGA survives the retraction (it moved out of DrumController for an unrelated reason — a
-- stage attribute could retune it with no test able to see it), so its value is still worth
-- pinning here.
describe("DrumStep.KICK_OMEGA", function()
    test("is the drum's live spin velocity", function()
        expect(DrumStep.KICK_OMEGA).toBe(4)
    end)
end)

-- The honest miss (owner, 2026-09-05): a stalled-out drum rests BETWEEN windows, never on a
-- stale face. -75 degrees mod 90 is midway between the sector's last symbol (-60) and the next
-- sector's first (-90 = 0); no symbol angle (0/-30/-60 mod 90) can coincide with it.
describe("DrumStep.missTargetTheta", function()
    test("rests between windows, at least dmin below theta, stepping one direction", function()
        for _, theta in { 0, 1.3, -2.7, 10 * math.pi, -35.2 } do
            for _, dmin in { 0, 0.4, 2.1 } do
                local tgt = DrumStep.missTargetTheta(theta, dmin)
                expect(tgt <= theta - dmin).toBe(true)
                -- congruent to -75 degrees modulo the 90-degree sector
                local frac = (tgt - math.rad(-75)) / (math.pi / 2)
                expect(math.abs(frac - math.floor(frac + 0.5)) < 1e-9).toBe(true)
                -- and NOT congruent to any face angle
                for sym = 0, 2 do
                    local faceFrac = (tgt - math.rad(-sym * 30)) / (math.pi / 2)
                    expect(math.abs(faceFrac - math.floor(faceFrac + 0.5)) > 1e-6).toBe(true)
                end
            end
        end
    end)
end)
