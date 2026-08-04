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
