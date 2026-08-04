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

-- WHEN THE PERSONAL RESULT MAY LAND (spec §2, amended 2026-08-04).
--
-- The cue used to fire at a fixed SPLASH_LEAD_SECONDS = 0.7 chosen against "the drum has covered
-- >80% of its travel". That criterion measures the wrong thing: 83–88% travelled still left 28.1°
-- (best landing) to 53.4° (worst) to turn, and facets are 30° apart carrying DIFFERENT symbols, so
-- the window showed a NEIGHBOURING throw for a further 0.19–0.34s while the splash named the
-- result. The trigger is now the RESIDUAL ANGLE, and these tests assert the invariants that make
-- that safe rather than any one number.
--
-- ω is READ from DrumStep, never copied: it used to be a literal 4 here, and the old assertion
-- INVERTED across the plausible range (ω = 1 gave 0.780 and failed; ω = 8 passed while describing a
-- different drum). STILL UNTESTED: DrumController's "DrumKick" stage attribute overrides ω at
-- runtime and nothing here can see it — but the residual formulation is exactly what makes that
-- harmless, since the controller feeds `glideResidual` the LIVE ω.
--
-- The travel `d` is not a constant: `landTargetFor` steps down to the first detent at least ω·G/2
-- below the current θ, and detents recur every π/2 — so d ∈ [ω·G/2, ω·G/2 + π/2). Both extremes are
-- derived from DrumStep's own constants below, never hand-copied.
local G = DrumStep.GLIDE_SECONDS
local D_MIN = DrumStep.KICK_OMEGA * G / 2
local D_MAX = D_MIN + math.pi / 2 -- the open end of the range; the conservative worst case

-- The drum's facet count, derived from the module rather than restated: `symmetric` steps +3 and
-- preserves the symbol, so the number of steps back to face 0 times 3 is the ring's size.
local FACES = 0
do
    local face = 0
    for _ = 1, 100 do
        face = DrumStep.symmetric(face)
        FACES += 3
        if face == 0 then
            break
        end
    end
end

-- The first s at which the residual has fallen to the threshold — i.e. when DrumController fires
-- `drumSettling`. Bisection is valid because the residual is monotone decreasing (asserted below).
local function crossingS(d: number, omega: number, threshold: number): number
    local lo, hi = 0, 1
    for _ = 1, 60 do
        local mid = (lo + hi) / 2
        if DrumStep.glideResidual(d, omega, mid) > threshold then
            lo = mid
        else
            hi = mid
        end
    end
    return hi
end

describe("DrumStep.glideResidual — how much turn the drum still owes", function()
    test("at s = 0 the whole travel is still owed, exactly", function()
        for _, d in { D_MIN, D_MAX, 1, 12 } do
            expect(DrumStep.glideResidual(d, DrumStep.KICK_OMEGA, 0)).toBe(d)
        end
    end)

    test("at s = 1 the drum is home, exactly zero", function()
        -- Not merely close: the smoothstep term is exactly 1 and the carried term exactly 0 at
        -- s = 1, so a cue keyed on the residual can never be owed a last sliver after `drumRest`.
        for _, d in { D_MIN, D_MAX, 1, 12 } do
            for _, omega in { 0, 1, DrumStep.KICK_OMEGA, 8 } do
                expect(DrumStep.glideResidual(d, omega, 1)).toBe(0)
            end
        end
    end)

    test("it decreases monotonically across the whole range of travel the lander can pick", function()
        -- The cue latches on the FIRST frame at or below the threshold, so a residual that dipped
        -- and rose again would announce the result while the drum was still a facet out. It also
        -- licenses the bisection in `crossingS`. The carried-velocity term is what could break
        -- this — it is only safe because d ≥ ω·G/2 > ω·G/3, and `landTargetFor` guarantees that.
        for i = 0, 20 do
            local d = D_MIN + (D_MAX - D_MIN) * i / 20
            local prev = DrumStep.glideResidual(d, DrumStep.KICK_OMEGA, 0)
            for j = 1, 1000 do
                local now = DrumStep.glideResidual(d, DrumStep.KICK_OMEGA, j / 1000)
                expect(now <= prev + 1e-12).toBe(true)
                prev = now
            end
        end
    end)
end)

describe("DrumStep.SPLASH_RESIDUAL_RADIANS — the threshold that protects the player", function()
    test("it is at most half a facet", function()
        -- THE ONE THAT MATTERS. Facets carry different symbols, so a threshold wider than half a
        -- facet lets a NEIGHBOURING symbol still be the one nearest the window when the splash
        -- names the result — the exact spoiler the gate exists to prevent.
        expect(FACES).toBe(12)
        expect(DrumStep.SPLASH_RESIDUAL_RADIANS > 0).toBe(true)
        expect(DrumStep.SPLASH_RESIDUAL_RADIANS <= (2 * math.pi / FACES) / 2).toBe(true)
    end)

    test("the lead it buys is worth having, at both extremes of travel", function()
        -- The point of the change is a splash that arrives sooner than `drumRest` — but not by a
        -- fixed amount. Solving residual(s) = threshold with the real kick velocity gives
        --   shortest travel (d = ω·G/2)      → lead ≈ 0.512s
        --   longest travel  (d = ω·G/2 + π/2) → lead ≈ 0.358s
        -- i.e. the splash lands ~2.94–3.09s after the strike instead of 3.45s. The band is asserted
        -- with margin, not to those digits: retiming the glide or the kick should move the lead,
        -- and only a lead that has collapsed to nothing (no gain over `drumRest`) or grown past the
        -- readable point should fail here.
        local leadShortest = (1 - crossingS(D_MIN, DrumStep.KICK_OMEGA, DrumStep.SPLASH_RESIDUAL_RADIANS)) * G
        local leadLongest = (1 - crossingS(D_MAX, DrumStep.KICK_OMEGA, DrumStep.SPLASH_RESIDUAL_RADIANS)) * G
        expect(leadShortest > 0.3 and leadShortest < 0.7).toBe(true)
        expect(leadLongest > 0.25 and leadLongest < 0.7).toBe(true)
        -- A longer travel is still moving faster at any given residual, so it reaches the threshold
        -- later: the worst case is always the shorter lead, never the other way round.
        expect(leadLongest < leadShortest).toBe(true)
    end)

    test("the drum's own timings are unchanged", function()
        -- The bell/drum choreography is signed off. This round changes when a CLIENT reacts,
        -- never how long the drum takes — and the server reads SETTLE_SECONDS to time round
        -- scheduling.
        expect(DrumStep.SETTLE_SECONDS).toBe(
            DrumStep.STRIKE_SWING_SECONDS + DrumStep.SPIN_SECONDS + DrumStep.GLIDE_SECONDS
        )
        expect(DrumStep.KICK_OMEGA).toBe(4)
    end)
end)
