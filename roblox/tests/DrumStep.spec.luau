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

describe("DrumStep.SPLASH_LEAD_SECONDS — how early the personal result may land", function()
    test("it is a real lead, but strictly inside the glide", function()
        -- At or beyond the glide's whole length the cue would fire the moment the glide STARTS,
        -- while the drum is still visibly travelling — which is the spoiler the drum-rest gate
        -- exists to prevent. At zero it buys nothing.
        expect(DrumStep.SPLASH_LEAD_SECONDS > 0).toBe(true)
        expect(DrumStep.SPLASH_LEAD_SECONDS < DrumStep.GLIDE_SECONDS).toBe(true)
    end)

    test("it leaves the drum most of the way home before the result shows", function()
        -- Whatever the lead is, the drum must have covered a large majority of its travel by the
        -- time the splash fires, or the face is not yet readable in the window.
        --
        -- The glide is a HERMITE, not a bare smoothstep: DrumController carries the spin's velocity
        -- into it, so θ = θ₀ − D·(3s² − 2s³) − ω·G·(s³ − 2s² + s). The second term matters here.
        -- The smoothstep alone reads only 72% at s = 0.65, and reasoning from it would say the lead
        -- is far too long; the carried velocity puts the real figure at 83–88%.
        --
        -- Both terms are reproduced from DrumController's own defaults (ω = DRUM_KICK = 4 rad/s).
        -- The travel D is not a constant: `landTargetFor` steps down to the first detent at least
        -- ω·G/2 below the current θ, and detents recur every π/2 — so D ∈ [ω·G/2, ω·G/2 + π/2).
        -- The WORST case for how far along the drum is at the splash is the LARGEST D (the fixed
        -- velocity term is then the smallest share of it), so that is what is asserted.
        local G = DrumStep.GLIDE_SECONDS
        local s = (G - DrumStep.SPLASH_LEAD_SECONDS) / G
        local carried = 4 * G -- ω·G
        local travel = carried / 2 + math.pi / 2 -- the largest D the lander can choose
        local travelled = (3 * s * s - 2 * s * s * s) + carried * (s * (1 - s) * (1 - s)) / travel
        expect(travelled > 0.8).toBe(true)
    end)

    test("the drum's own timings are unchanged", function()
        -- The bell/drum choreography is signed off. This round changes when a CLIENT reacts,
        -- never how long the drum takes — and the server reads SETTLE_SECONDS to time round
        -- scheduling.
        expect(DrumStep.SETTLE_SECONDS).toBe(
            DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS
        )
    end)
end)
