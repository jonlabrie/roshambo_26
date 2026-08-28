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

    test("WIN lands on the shoulder and stays there", function()
        -- ⚠ This REPLACES "WIN rises". Owner, 2026-08-21, on seeing the real mesh in play: at
        -- 0.55 studs against a 5-stud avatar it read as an insect at the old 8.2-stud orbit.
        -- Legibility beats occlusion — an unreadable bird communicates nothing at any height.
        local settled = BirdFlight.offsetFor("WIN", 3, 7)
        expect(settled.y > 0.9 and settled.y < 1.4).toBe(true)
        expect(math.abs(settled.x) > 0.7).toBe(true) -- well off to one side, clear of the head
        -- ⚠ AND IT FACES FORWARD, with the avatar (owner ruling 2026-08-25). The outboard yaw it
        -- replaced was justified as putting the bird in profile; the owner looked at it in play and
        -- disagreed, which is the only evidence that counts for a question of "can you read it".
        expect(BirdFlight.SHOULDER_YAW).toBe(0)
        -- ⚠ ON the shoulder, not hovering off it. This used to assert z < -0.25, which encoded a
        -- sign error: Roblox -Z is FORWARD, so that put the bird in front of the avatar rather
        -- than behind it, floating. The tail is cleared by yawing outboard, not by standing off.
        expect(math.abs(settled.z) < 0.20).toBe(true)
        -- A result must outlast the instant it happened — glancing over a few seconds later
        -- should still tell you what happened.
        for _, t in { 3, 8, 14 } do
            local p = BirdFlight.offsetFor("WIN", t, 7)
            expect(p.y > 0.9 and p.y < 1.4).toBe(true)
        end
    end)

    test("WIN still BOBS, even though it no longer shuffles", function()
        -- ⚠ REPLACES a test that asserted the bird shuffled left and right across the shoulder.
        -- That behaviour was removed on the owner's note that it "might make it look worse" — the
        -- legs hop now (see legPose) and the body only rises and falls.
        local low, high = 99, 0
        for t = BirdFlight.ENTRY.WIN + 0.5, 10, 0.02 do
            local p = BirdFlight.offsetFor("WIN", t, 7)
            low, high = math.min(low, p.y), math.max(high, p.y)
        end
        expect(high - low > 0.02).toBe(true)
        expect(high - low < 0.12).toBe(true) -- a bob, not a bounce
    end)

    test("the victory hop stays IN PLACE — the bird does not shuffle sideways", function()
        -- ⚠ Owner, 2026-08-22: "change it from the whole bird hopping left to right to it simply
        -- hopping between left and right legs while staying in place". The old hop translated the
        -- whole bird 0.09 studs each way, which read as sliding on the shoulder.
        local xs = {}
        -- sample AFTER the fly-in lerp has finished, or the approach itself moves x
        for t = BirdFlight.ENTRY.WIN + 0.5, 10, 0.02 do
            xs[#xs + 1] = BirdFlight.offsetFor("WIN", t, 7).x
        end
        local lo, hi = xs[1], xs[1]
        for _, v in ipairs(xs) do
            lo, hi = math.min(lo, v), math.max(hi, v)
        end
        expect(hi - lo < 0.01).toBe(true)
    end)

    test("the feet ALTERNATE, and never both leave the perch at once", function()
        local bothUp, oneUp, samples = 0, 0, 0
        local sawLeft, sawRight = false, false
        for t = 0, 30, 1 / 60 do
            local l, r = BirdFlight.legPose(t, 7)
            expect(l >= 0 and l <= 1).toBe(true)
            expect(r >= 0 and r <= 1).toBe(true)
            if l > 0.35 and r > 0.35 then
                bothUp += 1
            end
            if l > 0.35 or r > 0.35 then
                oneUp += 1
            end
            if l > 0.5 then
                sawLeft = true
            end
            if r > 0.5 then
                sawRight = true
            end
            samples += 1
        end
        expect(bothUp).toBe(0) -- a bird that lifts both feet has let go of the branch
        expect(sawLeft and sawRight).toBe(true) -- it really does alternate
        expect(oneUp / samples < 0.55).toBe(true) -- and a hop is quick, not a permanent limp
    end)

    test("the body ROLLS toward whichever foot is planted", function()
        -- The weight shift is what makes a hop-in-place read as weight rather than a twitch.
        local worst = 0
        for t = 0, 30, 1 / 60 do
            local l, r, roll = BirdFlight.legPose(t, 7)
            worst = math.max(worst, math.abs(roll))
            if l > 0.6 then
                expect(roll < 0.01).toBe(true) -- left foot up => lean right
            elseif r > 0.6 then
                expect(roll > -0.01).toBe(true)
            end
        end
        expect(worst > 1).toBe(true)
        expect(worst < 12).toBe(true)
    end)

    test("a result LAPSES, so a bird does not wear it until the next round", function()
        -- It used to hold for the whole ~60s round, which the owner found too long: the bird just
        -- hovered instead of going back to living in the world.
        expect(BirdFlight.stateAfter("WIN", BirdFlight.RESULT_HOLD - 1)).toBe("WIN")
        expect(BirdFlight.stateAfter("WIN", BirdFlight.RESULT_HOLD + 1)).toBe("RESTING")
        -- ⚠ A LOSS IS NEVER WORN AT ALL, so it does not lapse — it never starts. Owner, 2026-08-26:
        -- "no bird animation for a loss or tie."
        for _, t in { 0, 1, BirdFlight.RESULT_HOLD - 1, BirdFlight.RESULT_HOLD + 1, 999 } do
            expect(BirdFlight.stateAfter("LOSS", t)).toBe("RESTING")
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

    test("a LOSS does NOTHING — the bird carries on exactly as if nothing happened", function()
        -- ⚠ REPLACES "LOSS bolts, then SINKS and stays low". The bolt-and-sink was watched in play
        -- and rejected: "not in the same visual class as a bird dancing on your shoulder" (owner,
        -- 2026-08-25), then ruled out entirely the next day — "no bird animation for a loss or tie".
        -- LOSS now behaves exactly like SAFE, which has always been the do-nothing case.
        for _, t in { 0, 0.5, 3, 8, 14, 60 } do
            expect(
                BirdFlight.distance(BirdFlight.offsetFor("LOSS", t, 7), BirdFlight.offsetFor("RESTING", t, 7))
            ).toBe(0)
            expect(
                BirdFlight.distance(BirdFlight.offsetFor("LOSS", t, 7), BirdFlight.offsetFor("SAFE", t, 7))
            ).toBe(0)
        end
    end)

    test("⚠ RETIRED RULE: a loss now DOES look like a player who has not thrown yet", function()
        -- This test used to assert the exact opposite, and the rule behind it stood from
        -- 2026-08-18: letting a loss return to the resting orbit would make "lost" and "has not
        -- thrown" identical. That was true, and the owner has ruled the distinction is not worth an
        -- animation (2026-08-26). Kept, inverted, rather than deleted — so that anyone about to
        -- reinstate the low orbit to restore the distinction finds out here that it was a decision
        -- rather than an oversight.
        for _, t in { 3, 8, 14 } do
            local lost = BirdFlight.offsetFor("LOSS", t, 7)
            local idle = BirdFlight.offsetFor("RESTING", t, 7)
            expect(BirdFlight.distance(lost, idle)).toBe(0)
        end
    end)

    test("the reserved WIN orbit is still separable from RESTING by height alone", function()
        -- ⚠ ONLY TWO HOLDS DIFFER NOW, not three. WIN perches on the shoulder and LOSS does nothing
        -- at all, so this pins the HIGH ORBIT kept in reserve against RESTING — if the shoulder
        -- perch is ever abandoned and the orbit comes back, this is already asserting the right
        -- thing. The RESTING/LOSS half it used to carry is gone with the LOSS animation.
        local win = BirdFlight.HOLD_WIN_ORBIT_Y
        local resting = BirdFlight.offsetFor("RESTING", 10, 7).y
        expect(win > resting + 3).toBe(true)
    end)

    test("neither beat axis ever exceeds its ceiling", function()
        for _, flying in { true, false } do
            for t = 0, 40, 0.1 do
                local vertical, foreAft = BirdFlight.beatPose(t, 7, flying)
                expect(math.abs(vertical) <= BirdFlight.WING_BEAT_DEG + 1e-9).toBe(true)
                expect(math.abs(foreAft) <= BirdFlight.WING_SWEEP_DEG + 1e-9).toBe(true)
            end
        end
    end)

    test("a perched bird's wings are FOLDED, a flying bird's are SPREAD", function()
        -- ⚠ Owner, 2026-08-22: the wings "should completely disappear when the bird is
        -- perched/at rest". Folding alone cannot achieve that -- measured, 93 of 208 wing verts
        -- stay outside the body at the best fold -- so the wings are a separate MeshPart and the
        -- controller drives its Transparency. This function only owns the OPENNESS.
        expect(BirdFlight.wingExtension(0, 7, false)).toBe(0)
        expect(BirdFlight.wingExtension(99, 7, false)).toBe(0)
        for t = 0, 20, 0.05 do
            local e = BirdFlight.wingExtension(t, 7, true)
            expect(e >= 0).toBe(true)
            expect(e <= 1).toBe(true)
        end
    end)

    test("wings OPEN over time rather than snapping", function()
        -- Owner: wings "only unfold when the bird takes flight ... quickly fold in and disappear
        -- when it lands". Opening is eased; closing is instant, which is why there is no
        -- corresponding close-over-time assertion.
        local first = BirdFlight.wingExtension(0, 7, true)
        local mid = BirdFlight.wingExtension(BirdFlight.WING_OPEN_TIME * 0.5, 7, true)
        local done = BirdFlight.wingExtension(BirdFlight.WING_OPEN_TIME * 2, 7, true)
        expect(first < mid).toBe(true)
        expect(mid < done).toBe(true)
        expect(done > 0.99).toBe(true)
    end)

    test("the fold sweeps the wing BACKWARD over the body, never forward past the head", function()
        -- ⚠ MEASURED ON THE LIVE BIRD, 2026-08-25, not guessed. These bones turn about a local Z
        -- that runs vertical, so the fold is a horizontal fore-and-aft sweep. Wingtip in
        -- part-local space, where -Z is forward: spread rests at z -0.123; the fold as shipped
        -- (-70/-110) reached z -0.391, a quarter-stud PAST the head; corrected (+70/+110) it
        -- reaches z +0.146, back over the body. A POSITIVE fold is the one that tucks.
        expect(BirdFlight.FOLD_SHOULDER > 0).toBe(true)
        expect(BirdFlight.FOLD_WRIST > 0).toBe(true)
    end)

    test("fold angles run from FULLY FOLDED to FULLY SPREAD and never past", function()
        local s0, w0 = BirdFlight.foldAngles(0)
        expect(s0).toBe(BirdFlight.FOLD_SHOULDER)
        expect(w0).toBe(BirdFlight.FOLD_WRIST)
        local s1, w1 = BirdFlight.foldAngles(1)
        expect(s1).toBe(0)
        expect(w1).toBe(0)
        -- monotonic TOWARD ZERO, and clamped outside 0..1 so a bad caller cannot hyperextend a
        -- wing. Stated as magnitude so it holds whichever way the fold sweeps.
        local prev = math.abs(BirdFlight.FOLD_SHOULDER) + 1
        for k = 0, 1.0001, 0.05 do
            local sh = math.abs((BirdFlight.foldAngles(math.min(1, k))))
            expect(sh <= prev).toBe(true)
            prev = sh
        end
        expect(BirdFlight.foldAngles(-5)).toBe(BirdFlight.FOLD_SHOULDER)
        expect(BirdFlight.foldAngles(5)).toBe(0)
    end)

    test("a beat goes UP as well as down -- it is not a one-sided sweep", function()
        -- ⚠ MEASURED AXES, 2026-08-25. local X lifts the tip (0.712 studs of vertical travel
        -- over +/-60 deg, and ZERO fore-aft); local Z sweeps it fore-and-aft (0.712 fore-aft, ZERO
        -- vertical); local Y runs along the span and moves the tip not at all. The beat used to
        -- put its whole amplitude on Z, so the bird sculled instead of flying.
        local up, down = 0, 0
        for t = 0, 4, 0.02 do
            local vertical = BirdFlight.beatPose(t, 7, true)
            up = math.min(up, vertical)
            down = math.max(down, vertical)
        end
        expect(down > BirdFlight.WING_BEAT_DEG * 0.9).toBe(true)
        expect(up < -BirdFlight.WING_BEAT_DEG * 0.9).toBe(true)
    end)

    test("the tip traces a LOOP: forward on the downstroke, back on the upstroke", function()
        -- Owner, 2026-08-25: "in actual flight it's both - forward and up, backward and down".
        -- Right that it is compound; the pairing runs the other way, because the DOWNSTROKE is the
        -- power stroke and sweeps forward as it descends, the upstroke recovering back and up.
        --
        -- ⚠ THIS IS THE ASSERTION THAT MAKES IT A LOOP RATHER THAN A LINE. Fore-aft must track
        -- the DIRECTION of vertical travel, not its position -- in phase, the two would trace a
        -- straight diagonal and retrace it, which reads worse than the single axis it replaced.
        local dt = 0.0005
        local checked = 0
        for t = 0, 2, 0.01 do
            local v0 = BirdFlight.beatPose(t, 7, true)
            local v1 = BirdFlight.beatPose(t + dt, 7, true)
            local _, foreAft = BirdFlight.beatPose(t, 7, true)
            if math.abs(v1 - v0) > 1e-7 then
                checked += 1
                if v1 > v0 then
                    expect(foreAft <= 1e-9).toBe(true) -- descending -> forward (negative Z)
                else
                    expect(foreAft >= -1e-9).toBe(true) -- ascending -> back
                end
            end
        end
        expect(checked > 100).toBe(true) -- the sweep actually exercised both halves
    end)

    test("fore-aft is the SECONDARY component, not an equal partner", function()
        -- A real beat is dominated by vertical excursion; the fore-aft sweep is what tilts the
        -- loop, not what carries it. Equal amplitudes read as a circular paddle.
        expect(BirdFlight.WING_SWEEP_DEG < BirdFlight.WING_BEAT_DEG * 0.5).toBe(true)
        expect(BirdFlight.WING_SWEEP_DEG > 0).toBe(true)
    end)

    test("a PERCHED bird does not BEAT its wings -- lift is a flight thing", function()
        -- ⚠ THE PERCHED FLUTTER USED TO LIVE HERE, AND WAS UNOBSERVABLE. `wingExtension` returns
        -- 0 whenever the bird is not flying, and Transparency follows openness -- so the wings
        -- were invisible for the whole burst and the lift rotated something nobody could see.
        -- Two channels fighting: one hid the wing, the other animated it.
        --
        -- ⚠ SWEEP, DO NOT SPOT-CHECK. Two sampled instants both passed against the OLD fluttering
        -- implementation, because they happened to fall between bursts -- the same shape of
        -- vacuous assertion that let a zeroed FLIGHT_MIN_TIME through in this file a week ago.
        for t = 0, 120, 0.05 do
            local vertical, foreAft = BirdFlight.beatPose(t, 7, false)
            expect(vertical).toBe(0)
            expect(foreAft).toBe(0)
        end
    end)

    test("a flutter is a COUPLE of half-unfolds, not one big spread", function()
        -- Owner, 2026-08-25: "a quick 'half unfold/refold' cycle a couple of times that might
        -- read as a flutter". Driving the FOLD channel is what makes it visible at all -- the
        -- wing appears BECAUSE it is unfolding, rather than being revealed and then rotated.
        local peaks, prev, rising = 0, -1, false
        local high = 0
        for t = 0, BirdFlight.FLUTTER_BURST, 0.005 do
            local e = BirdFlight.flutterExtension(t, 7)
            high = math.max(high, e)
            if e > prev then
                rising = true
            elseif rising and e < prev then
                peaks += 1
                rising = false
            end
            prev = e
        end
        expect(peaks).toBe(3) -- owner, 2026-08-25: three, because two read as too slow
        expect(high > 0.25).toBe(true) -- far enough out to read as a flutter
        expect(high < 0.6).toBe(true) -- but a HALF unfold, not a spread
        -- ⚠ AND THE THREE MUST BE COMPARABLE. A plain sine envelope gives the middle flex twice
        -- the reach of its neighbours, which reads as one flex with a stutter either side.
        local outer = BirdFlight.flutterExtension(BirdFlight.FLUTTER_BURST / 6, 7)
        expect(outer > high * 0.6).toBe(true)
    end)

    test("a flutter stays readable on a 30fps phone", function()
        -- ⚠ THE PRODUCT IS PHONES AND TABLETS (friends-and-family baseline: kid-first, touch).
        -- A flex is an up AND a down, so it needs frames to resolve as motion rather than strobe.
        -- Under about five frames per flex at 30fps the peaks fall between samples, the three
        -- flexes come out visibly uneven, and "quicker" stops buying anything.
        --
        -- This is the floor that decides HOW the flutter gets faster: shortening the burst is
        -- capped here, so past this point the only honest way to speed it up is fewer flexes.
        local framesPerFlex = (BirdFlight.FLUTTER_BURST / BirdFlight.FLUTTER_CYCLES) * 30
        expect(framesPerFlex >= 5).toBe(true)
    end)

    test("a flutter starts, ends and PASSES THROUGH fully folded", function()
        expect(BirdFlight.flutterExtension(0, 7)).toBe(0)
        expect(BirdFlight.flutterExtension(-1, 7)).toBe(0)
        expect(BirdFlight.flutterExtension(BirdFlight.FLUTTER_BURST, 7)).toBe(0)
        expect(BirdFlight.flutterExtension(BirdFlight.FLUTTER_BURST + 5, 7)).toBe(0)
        -- refolds to nothing BETWEEN flexes too, which is what makes it a cycle and not a bump.
        -- Three flexes put the troughs at thirds, so the midpoint is now a PEAK, not a trough.
        expect(BirdFlight.flutterExtension(BirdFlight.FLUTTER_BURST / 3, 7) < 0.02).toBe(true)
    end)

    test("wings FADE IN over the first sliver of opening rather than popping", function()
        -- ⚠ At the best fold, 93 of 208 wing verts are still OUTSIDE the body: the wings are
        -- hidden by Transparency, NOT by geometry. So a binary flip pops a fully-tucked wing into
        -- existence in a single frame -- on a stationary perched bird, exactly where the viewer
        -- is looking. Flight is untouched; takeoff crosses this band in about 40ms, and landing
        -- still snaps shut because openness goes to 0 in one step.
        expect(BirdFlight.wingTransparency(0)).toBe(1)
        expect(BirdFlight.wingTransparency(1)).toBe(0)
        expect(BirdFlight.wingTransparency(-1)).toBe(1)
        expect(BirdFlight.wingTransparency(5)).toBe(0)
        local prev = 2
        for k = 0, 1, 0.02 do
            local a = BirdFlight.wingTransparency(k)
            expect(a <= prev).toBe(true)
            prev = a
        end
        expect(BirdFlight.wingTransparency(0.3)).toBe(0) -- opaque well before half open
        -- ⚠ AND IT IS GENUINELY A FADE. Every assertion above this line also passes against the
        -- BINARY version it replaced -- verified by mutation, which is the only way that gets
        -- found. A partly-open wing must be partly transparent, and that is the whole change.
        local mid = BirdFlight.wingTransparency(0.05)
        expect(mid > 0).toBe(true)
        expect(mid < 1).toBe(true)
    end)

    test("idle flutters are RARE and jittered on top of the triggered ones", function()
        -- Owner, 2026-08-25: "event triggered plus a longer idle period". Landing and winning
        -- fire a flutter outright -- the controller owns those -- so this is only the background
        -- rate, and it is deliberately slower than the 9s it used to free-run at.
        local lo, hi = math.huge, 0
        for i = 1, 200 do
            local g = BirdFlight.nextFlutterGap(7, i)
            lo, hi = math.min(lo, g), math.max(hi, g)
        end
        expect(lo > 9).toBe(true) -- longer than the old period, in every draw
        expect(hi < 60).toBe(true) -- but still inside the time someone stands and watches
        expect(hi > lo * 1.15).toBe(true) -- jittered rather than metronomic
        expect(BirdFlight.nextFlutterGap(7, 3)).toBe(BirdFlight.nextFlutterGap(7, 3))
        local differs = false
        for i = 1, 50 do
            if BirdFlight.nextFlutterGap(7, i) ~= BirdFlight.nextFlutterGap(8, i) then
                differs = true
                break
            end
        end
        expect(differs).toBe(true)
    end)

    test("a perch turn is a real turn -- neither a twitch nor a spin", function()
        -- Owner, 2026-08-25: "a short hop that changes the direction the bird is facing".
        local sawLeft, sawRight = false, false
        for i = 1, 200 do
            local d = BirdFlight.turnAmount(7, i)
            local m = math.abs(d)
            expect(m >= 35).toBe(true) -- under this it reads as a twitch, not a decision
            expect(m <= 110).toBe(true) -- over it, as a spin
            if d < 0 then
                sawLeft = true
            else
                sawRight = true
            end
        end
        expect(sawLeft).toBe(true)
        expect(sawRight).toBe(true) -- it turns BOTH ways
        expect(BirdFlight.turnAmount(7, 3)).toBe(BirdFlight.turnAmount(7, 3))
        local differs = false
        for i = 1, 50 do
            if BirdFlight.turnAmount(7, i) ~= BirdFlight.turnAmount(8, i) then
                differs = true
                break
            end
        end
        expect(differs).toBe(true)
    end)

    test("the turn HOPS: off the perch and back onto it, peaking mid-turn", function()
        local p0, h0 = BirdFlight.turnPose(0)
        expect(p0).toBe(0)
        expect(h0).toBe(0)
        local p1, h1 = BirdFlight.turnPose(BirdFlight.TURN_TIME)
        expect(p1).toBe(1)
        expect(h1).toBe(0) -- ⚠ back DOWN at the end, or the bird is left floating
        local pLate, hLate = BirdFlight.turnPose(BirdFlight.TURN_TIME + 9)
        expect(pLate).toBe(1)
        expect(hLate).toBe(0)

        local prev, peak, peakAt = -1, -1, 0
        for t = 0, BirdFlight.TURN_TIME, 0.002 do
            local p, h = BirdFlight.turnPose(t)
            expect(p >= prev).toBe(true) -- one way only; backtracking reads as a stumble
            prev = p
            if h > peak then
                peak, peakAt = h, t / BirdFlight.TURN_TIME
            end
        end
        expect(peak > 0.03).toBe(true) -- a hop you can actually see
        expect(peak < 0.12).toBe(true) -- but not a launch
        expect(peakAt > 0.3).toBe(true) -- and airborne in the MIDDLE of the turn
        expect(peakAt < 0.7).toBe(true)
    end)

    test("idle turns are rare, jittered, and never in lockstep with flutters", function()
        local lo, hi = math.huge, 0
        for i = 1, 200 do
            local g = BirdFlight.nextTurnGap(7, i)
            lo, hi = math.min(lo, g), math.max(hi, g)
        end
        expect(lo > 6).toBe(true)
        expect(hi < 60).toBe(true)
        expect(hi > lo * 1.15).toBe(true)
        expect(BirdFlight.nextTurnGap(7, 3)).toBe(BirdFlight.nextTurnGap(7, 3))
        -- ⚠ TURNS AND FLUTTERS MUST DRIFT AGAINST EACH OTHER. Sharing a period would fire them
        -- together every time and read as one compound move rather than two habits.
        local same = 0
        for i = 1, 50 do
            if math.abs(BirdFlight.nextTurnGap(7, i) - BirdFlight.nextFlutterGap(7, i)) < 1e-6 then
                same += 1
            end
        end
        expect(same).toBe(0)
    end)

    test("a perched bird's head SNAPS and HOLDS rather than sweeping", function()
        -- ⚠ THIS IS THE WHOLE POINT OF THE IDLE. A bird does not pan its head smoothly; it
        -- snaps to a new angle, holds it, and snaps again. A sinusoidal sweep reads as a
        -- security camera. So the head must be STILL for most of any sample.
        local moving, samples = 0, 0
        local prev = nil
        for t = 0, 60, 1 / 30 do
            local yaw = BirdFlight.idlePose(t, 7)
            if prev ~= nil and math.abs(yaw - prev) > 0.20 then
                moving += 1
            end
            prev = yaw
            samples += 1
        end
        local share = moving / samples
        expect(share > 0.01).toBe(true) -- it does move
        expect(share < 0.30).toBe(true) -- but it is mostly holding a pose
    end)

    test("some head moves are CHECKS — go look, then come straight back", function()
        -- ⚠ Owner, 2026-08-22: "head twists left to check something, then immediately returns to
        -- where it was." Without this every move is a commitment to a new heading, and the bird
        -- reads as slowly rotating over time rather than reacting to things.
        local checks = 0
        local window = BirdFlight.LOOK_HOLD
        for slot = 1, 80 do
            local t0 = slot * window
            local before = BirdFlight.idlePose(t0 - 0.02, 7)
            local after = BirdFlight.idlePose(t0 + window - 0.02, 7)
            -- widest excursion anywhere inside the slot
            local far = before
            for u = 0, window, window / 24 do
                local y = BirdFlight.idlePose(t0 + u, 7)
                if math.abs(y - before) > math.abs(far - before) then
                    far = y
                end
            end
            if math.abs(after - before) < 1.0 and math.abs(far - before) > 12 then
                checks += 1
            end
        end
        expect(checks >= 4).toBe(true) -- they happen
        expect(checks <= 50).toBe(true) -- but they are not every move
    end)

    test("the head never turns further than a bird's neck allows", function()
        for t = 0, 120, 0.05 do
            local yaw, pitch = BirdFlight.idlePose(t, 7)
            expect(math.abs(yaw) <= BirdFlight.HEAD_YAW_MAX + 0.001).toBe(true)
            expect(math.abs(pitch) <= BirdFlight.HEAD_PITCH_MAX + 0.001).toBe(true)
        end
    end)

    test("the head actually visits several distinct angles", function()
        -- A "snap and hold" that always returns to the same spot is a twitch, not looking around.
        local seen = {}
        for t = 0, 60, 0.25 do
            local yaw = BirdFlight.idlePose(t, 7)
            seen[math.floor(yaw / 6)] = true
        end
        local n = 0
        for _ in pairs(seen) do
            n += 1
        end
        expect(n >= 4).toBe(true)
    end)

    test("the tail flicks: rare, brief, and always a downward stroke", function()
        -- Warblers flick the tail constantly, and it is one of the cheapest signs of life. It
        -- must not read as a wag: the stroke goes one way and returns.
        local flicking, samples, peak = 0, 0, 0
        for t = 0, 120, 1 / 30 do
            local _, _, tail = BirdFlight.idlePose(t, 7)
            expect(tail >= -0.001).toBe(true) -- one direction only
            if tail > 0.5 then
                flicking += 1
            end
            peak = math.max(peak, tail)
            samples += 1
        end
        expect(flicking / samples < 0.15).toBe(true)
        expect(peak > 3).toBe(true)
    end)

    test("idle is deterministic per seed, and two birds do not idle in lockstep", function()
        expect(BirdFlight.idlePose(3.3, 7)).toBe(BirdFlight.idlePose(3.3, 7))
        local differs = false
        for t = 0, 60, 0.25 do
            if BirdFlight.idlePose(t, 7) ~= BirdFlight.idlePose(t, 8) then
                differs = true
                break
            end
        end
        expect(differs).toBe(true)
    end)

    test("a flight has THREE PHASES, in order, and always all three", function()
        -- Owner, 2026-08-22: "there needs to be phases - takeoff, flight, landing". A bird that
        -- simply translates between perches reads as sliding, which is exactly what it did.
        local seen = {}
        local order = {}
        for k = 0, 1.0001, 0.005 do
            local ph = BirdFlight.flightPhase(math.min(1, k))
            if order[#order] ~= ph then
                table.insert(order, ph)
            end
            seen[ph] = true
        end
        expect(#order).toBe(3)
        expect(order[1]).toBe("TAKEOFF")
        expect(order[2]).toBe("CRUISE")
        expect(order[3]).toBe("LANDING")
    end)

    test("a flight RAMPS: it is slow at both ends and quick in the middle", function()
        -- ⚠ THE ORIGINAL DEFECT. A speed-capped lerp is at full speed on frame one and stops
        -- dead on arrival — owner: "flying very fast between perches, there doesn't seem to be a
        -- smooth ramp". Speed here is d(along)/dk, so it must be near zero at both ends.
        local function speedAt(k)
            local h = 0.002
            local a = BirdFlight.flightPoint(math.max(0, k - h), 20, "DIRECT")
            local b = BirdFlight.flightPoint(math.min(1, k + h), 20, "DIRECT")
            return (b - a) / (2 * h)
        end
        local launch, mid, arrive = speedAt(0.01), speedAt(0.5), speedAt(0.99)
        expect(launch < mid * 0.5).toBe(true)
        expect(arrive < mid * 0.5).toBe(true)
        -- and it never runs backwards
        local prev = -1
        for k = 0, 1.0001, 0.01 do
            local along = BirdFlight.flightPoint(math.min(1, k), 20, "DIRECT")
            expect(along >= prev - 1e-6).toBe(true)
            prev = along
        end
    end)

    test("a flight starts and ends EXACTLY on its perches", function()
        for _, shape in { "DIRECT", "ARC", "CIRCLE" } do
            for _, d in { 3, 12, 40 } do
                local a0, s0, r0 = BirdFlight.flightPoint(0, d, shape)
                local a1, s1, r1 = BirdFlight.flightPoint(1, d, shape)
                expect(math.abs(a0) < 1e-6).toBe(true)
                expect(math.abs(s0) < 1e-6).toBe(true)
                expect(math.abs(r0) < 1e-6).toBe(true)
                expect(math.abs(a1 - 1) < 1e-6).toBe(true)
                expect(math.abs(s1) < 1e-6).toBe(true)
                expect(math.abs(r1) < 1e-6).toBe(true)
            end
        end
    end)

    test("a takeoff CLIMBS OUT, it does not go up like a rocket and then turn", function()
        -- Owner, 2026-08-25: "on takeoff, the bird rises almost vertically first, then changes
        -- vector... the bird should be heading more or less along an arc heading towards its
        -- destination right from the start."
        --
        -- ⚠ THE CAUSE WAS TWO CLOCKS. `along` is the integral of a speed profile, so it is
        -- deliberately near-zero at the start (the bird is launching from rest on a perch), while
        -- `rise` was a function of raw t and climbed immediately. At 10% of the flight that put the
        -- bird 2x higher than it was far along. Driving rise off ALONG instead ties the arc to
        -- where the bird has got to rather than how long it has been going.
        for _, shape in { "DIRECT", "ARC", "CIRCLE" } do
            for _, d in { 20, 40 } do
                local worst, worstAt = 0, 0
                for i = 1, 99 do
                    local k = i / 100
                    local along, _, rise = BirdFlight.flightPoint(k, d, shape)
                    local horizontal = along * d
                    if horizontal > 1e-6 then
                        local gradient = rise / horizontal
                        if gradient > worst then
                            worst, worstAt = gradient, k
                        end
                    end
                end
                -- a climb steeper than 45 degrees anywhere reads as a rocket, not a bird
                expect(worst < 1.0).toBe(true)
                expect(worstAt >= 0).toBe(true)
            end
        end
    end)

    test("the legs TUCK in flight and are down again before touchdown", function()
        -- Owner, 2026-08-25: "the fixed legs make it look like a plane flying with the wheels
        -- down; it would be much better if the legs were tucked up under the body in flight, then
        -- extended right before landing."
        expect(BirdFlight.legTuck(0)).toBe(0) -- standing on the perch
        expect(BirdFlight.legTuck(1)).toBe(0) -- standing on the next one
        local peak, peakAt = 0, 0
        for i = 0, 100 do
            local v = BirdFlight.legTuck(i / 100)
            expect(v >= 0 and v <= 1).toBe(true)
            if v > peak then
                peak, peakAt = v, i / 100
            end
        end
        expect(peak > 0.99).toBe(true) -- fully tucked at some point
        expect(peakAt > 0.15 and peakAt < 0.85).toBe(true) -- and that point is mid-flight
        -- ⚠ GEAR DOWN BEFORE THE WHEELS TOUCH, not at the moment they do
        expect(BirdFlight.legTuck(0.95) < 0.5).toBe(true)
        expect(BirdFlight.legTuck(0.30) > 0.9).toBe(true) -- and up shortly after takeoff
    end)

    test("the path is NOT a beeline — it rises, and sometimes swings wide", function()
        -- Owner: "the flight has to be more than a straight beeline ... sometimes a gently arc
        -- upwards then down to land, maybe sometimes a half circle around the perch".
        local function peak(shape, which)
            local best = 0
            for k = 0, 1, 0.01 do
                local _, side, rise = BirdFlight.flightPoint(k, 20, shape)
                best = math.max(best, math.abs(if which == "side" then side else rise))
            end
            return best
        end
        expect(peak("DIRECT", "rise") > 0.5).toBe(true) -- even the plain one arcs
        expect(peak("ARC", "rise") > peak("DIRECT", "rise")).toBe(true)
        expect(peak("CIRCLE", "side") > 3).toBe(true) -- and this one goes around
        expect(peak("DIRECT", "side") < 0.001).toBe(true)
    end)

    test("even a SHORT hop takes long enough to be seen", function()
        -- A hop to the next spot on the same rail used to finish in a frame or two, which is why
        -- it read as the bird sliding sideways down the rail rather than flying.
        -- ⚠ ASSERT AN ABSOLUTE, NOT THE CONSTANT. Comparing against FLIGHT_MIN_TIME is vacuous:
        -- zero the constant and the test still passes while every hop becomes a slide again.
        expect(BirdFlight.flightDuration(0.5) > 0.6).toBe(true)
        expect(BirdFlight.flightDuration(0) > 0.6).toBe(true)
        expect(BirdFlight.flightDuration(40) > BirdFlight.flightDuration(4)).toBe(true)
    end)

    test("flight shape varies, and is deterministic per bird", function()
        expect(BirdFlight.flightShape(7, 3)).toBe(BirdFlight.flightShape(7, 3))
        local kinds = {}
        for i = 1, 60 do
            kinds[BirdFlight.flightShape(7, i)] = true
        end
        local n = 0
        for _ in pairs(kinds) do
            n += 1
        end
        expect(n >= 2).toBe(true)
    end)

    test("is deterministic per seed, so two clients draw the same bird", function()
        local a = BirdFlight.offsetFor("RESTING", 3.3, 7)
        local b = BirdFlight.offsetFor("RESTING", 3.3, 7)
        local other = BirdFlight.offsetFor("RESTING", 3.3, 8)
        expect(BirdFlight.distance(a, b)).toBe(0)
        expect(BirdFlight.distance(a, other) > 0).toBe(true)
    end)
end)

describe("BirdFlight.shouldReplan", function()
    test("⚠ a flight in progress is NOT torn up by a target that merely DRIFTS", function()
        -- THE BUG THIS EXISTS TO PREVENT. A result-state orbit is a MOVING target: LOSS orbits at
        -- radius 2.0 and speed 0.55, so it slides 1.1 studs a second and crosses the 0.35 replan
        -- threshold every ~0.32s -- while the flight it triggers lasts ~0.88s. The flight could
        -- therefore never finish, `k` never reached 1, the arrive-and-track branch never engaged,
        -- and every replan ALSO re-rolled the path shape. The bird restarted its takeoff three
        -- times a second along a randomly changing arc: "jerking around between many orientations
        -- and locations" (owner, 2026-08-25).
        expect(BirdFlight.shouldReplan(false, 0.4)).toBe(false)
        expect(BirdFlight.shouldReplan(false, 2.0)).toBe(false)
        expect(BirdFlight.shouldReplan(false, 4.0)).toBe(false) -- a full LOSS orbit diameter
    end)

    test("once ARRIVED, a small move is a new destination and is flown", function()
        expect(BirdFlight.shouldReplan(true, 0.4)).toBe(true)
        expect(BirdFlight.shouldReplan(true, 0.34)).toBe(false) -- still the same spot
        expect(BirdFlight.shouldReplan(true, 0)).toBe(false)
    end)

    test("a GENUINE change of destination interrupts even mid-flight", function()
        -- Perch-to-perch is tens of studs; no orbit in the game spans this far (the widest is
        -- RESTING at r 2.6, so 5.2 across), which is what makes the two cases separable at all.
        expect(BirdFlight.shouldReplan(false, 9)).toBe(true)
        expect(BirdFlight.shouldReplan(false, 40)).toBe(true)
    end)

    test("the interrupt threshold clears every orbit in the game", function()
        -- ⚠ If an orbit could ever span more than this, drift would masquerade as a destination
        -- change and the jerking would come straight back.
        expect(BirdFlight.REPLAN_INTERRUPT > 2 * 2.6).toBe(true) -- RESTING, the widest
        expect(BirdFlight.REPLAN_INTERRUPT > 2 * 3.4).toBe(true) -- the reserved WIN orbit
    end)
end)

-- ===== SCALE =====
-- ⚠ THE PROPERTY THAT MAKES THIS SAFE TO LAND is that the uguisu, at scale 1, comes out
-- BIT-IDENTICAL. It is the only bird anyone has watched, every constant in the module was tuned
-- by eye against it, and nobody has yet seen a karasu perch -- so the reference bird must be
-- provably untouched before the second bird's numbers are worth arguing about.
describe("BirdFlight scale", function()
    local SEEDS = { 0, 0.17, 1.3, 7.77, 41.0 }

    test("the reference profile is the module's own constants", function()
        local p = BirdFlight.profile(1)
        expect(p.scale).toBe(1)
        expect(p.linear).toBe(1)
        expect(p.time).toBe(1)
        expect(p.TURN_TIME).toBe(BirdFlight.TURN_TIME)
        expect(p.FLUTTER_BURST).toBe(BirdFlight.FLUTTER_BURST)
    end)

    test("distances go LINEARLY and durations as the SQUARE ROOT", function()
        -- Bigger animals move slower, roughly as sqrt(length) for pendulum-like limbs, so a 2x
        -- bird is about 1.41x slower -- NOT 2x, which overshoots into slow motion.
        local p = BirdFlight.profile(4)
        expect(p.linear).toBe(4)
        expect(p.time).toBe(2)
        expect(p.TURN_TIME).toBe(BirdFlight.TURN_TIME * 2)
        expect(p.FLUTTER_BURST).toBe(BirdFlight.FLUTTER_BURST * 2)
    end)

    test("a bird with no size is refused rather than divided by", function()
        -- scale 0 makes every duration 0 and every clock a division by zero, which surfaces as
        -- NaN positions frames later and diagnoses as "the bird vanished".
        expect(pcall(BirdFlight.profile, 0)).toBe(false)
        expect(pcall(BirdFlight.profile, -1)).toBe(false)
        expect(pcall(BirdFlight.profile, 0 / 0)).toBe(false)
    end)

    test("the REFERENCE bird is bit-identical, profile or no profile", function()
        local p = BirdFlight.profile(1)
        for _, seed in SEEDS do
            for t = 0, 6, 0.05 do
                local ay, ap, at = BirdFlight.idlePose(t, seed)
                local by, bp, bt = BirdFlight.idlePose(t, seed, p)
                expect(by).toBe(ay)
                expect(bp).toBe(ap)
                expect(bt).toBe(at)

                local al, ar, aroll = BirdFlight.legPose(t, seed)
                local bl, br, broll = BirdFlight.legPose(t, seed, p)
                expect(bl).toBe(al)
                expect(br).toBe(ar)
                expect(broll).toBe(aroll)

                expect(BirdFlight.flutterExtension(t, seed, p)).toBe(BirdFlight.flutterExtension(t, seed))
                expect(BirdFlight.wingExtension(t, seed, true, p)).toBe(
                    BirdFlight.wingExtension(t, seed, true)
                )

                local ax, az = BirdFlight.beatPose(t, seed, true)
                local bx, bz = BirdFlight.beatPose(t, seed, true, p)
                expect(bx).toBe(ax)
                expect(bz).toBe(az)

                local aprog, ahop = BirdFlight.turnPose(t)
                local bprog, bhop = BirdFlight.turnPose(t, p)
                expect(bprog).toBe(aprog)
                expect(bhop).toBe(ahop)

                for _, state in { "WIN", "RESTING" } do
                    local a = BirdFlight.offsetFor(state, t, seed)
                    local b = BirdFlight.offsetFor(state, t, seed, p)
                    expect(b.x).toBe(a.x)
                    expect(b.y).toBe(a.y)
                    expect(b.z).toBe(a.z)
                end
            end
            for d = 0, 40, 2.5 do
                expect(BirdFlight.flightDuration(d, p)).toBe(BirdFlight.flightDuration(d))
            end
        end
    end)

    test("a bigger bird runs the SAME motion on a slower clock -- angles never change", function()
        -- ⚠ THE STRONGEST STATEMENT OF THE RULE. 45 degrees is 45 degrees on a wren or an eagle,
        -- so every angular output must be reproducible on the scaled bird simply by waiting
        -- longer. If a scale factor ever leaks into an angle, this fails.
        local p = BirdFlight.profile(4) -- time exactly 2x, so the dilation is exact in binary
        for _, seed in SEEDS do
            for t = 0, 6, 0.05 do
                local ay, ap, at = BirdFlight.idlePose(t, seed)
                local by, bp, bt = BirdFlight.idlePose(t * 2, seed, p)
                expect(by).toBe(ay)
                expect(bp).toBe(ap)
                expect(bt).toBe(at)

                local al, ar, aroll = BirdFlight.legPose(t, seed)
                local bl, br, broll = BirdFlight.legPose(t * 2, seed, p)
                expect(bl).toBe(al)
                expect(br).toBe(ar)
                expect(broll).toBe(aroll)

                expect(BirdFlight.flutterExtension(t * 2, seed, p)).toBe(BirdFlight.flutterExtension(t, seed))
                expect(BirdFlight.wingExtension(t * 2, seed, true, p)).toBe(
                    BirdFlight.wingExtension(t, seed, true)
                )

                local ax, az = BirdFlight.beatPose(t, seed, true)
                local bx, bz = BirdFlight.beatPose(t * 2, seed, true, p)
                expect(bx).toBe(ax)
                expect(bz).toBe(az)
            end
        end
    end)

    test("the perch turn takes longer AND hops higher, each by its own rule", function()
        local p = BirdFlight.profile(4)
        for t = 0, BirdFlight.TURN_TIME, 0.01 do
            local aprog, ahop = BirdFlight.turnPose(t)
            local bprog, bhop = BirdFlight.turnPose(t * 2, p)
            expect(bprog).toBe(aprog) -- progress is scale-free
            expect(bhop).toBeCloseTo(ahop * 4, 1e-9) -- the hop is a DISTANCE
        end
        -- ⚠ AND THE WINDOW ITSELF MOVED, rather than the same window being re-parameterised. At
        -- the REFERENCE bird's turn time the bigger bird is still mid-turn; it finishes on its
        -- own clock. This is the assertion that would fail if TURN_TIME were read from the
        -- module instead of the profile -- which is exactly the mistake the controller can make.
        expect(select(1, BirdFlight.turnPose(BirdFlight.TURN_TIME, p)) < 1).toBe(true)
        expect(select(1, BirdFlight.turnPose(p.TURN_TIME, p))).toBe(1)
        expect(select(2, BirdFlight.turnPose(p.TURN_TIME, p))).toBe(0) -- never left standing in air
    end)

    test("a bigger bird's victory hop is bigger, not just slower", function()
        -- ⚠ HOP_HEIGHT was ABSOLUTE at 0.05 studs: 6.0% of the uguisu's body but 3.0% of the
        -- karasu's. A crow doing a uguisu-sized hop reads as STIFF.
        local p = BirdFlight.profile(4)
        local settled = BirdFlight.ENTRY.WIN * 2 + 10 -- well past the scaled entry animation
        local peak = 0
        for t = settled, settled + 3, 0.005 do
            peak = math.max(peak, BirdFlight.offsetFor("WIN", t, 0.3, p).y - BirdFlight.SHOULDER_Y)
        end
        local refPeak = 0
        for t = BirdFlight.ENTRY.WIN + 10, BirdFlight.ENTRY.WIN + 13, 0.005 do
            refPeak = math.max(refPeak, BirdFlight.offsetFor("WIN", t, 0.3).y - BirdFlight.SHOULDER_Y)
        end
        expect(peak).toBeCloseTo(refPeak * 4, 1e-3)
    end)

    test("the shoulder is an ANCHOR ON THE AVATAR and does not grow with the bird", function()
        -- The bird's origin is at its feet (the PivotOffset contract measureBirds checks), so
        -- the perch offset says where the FEET go. A 5-stud avatar's shoulder does not move
        -- because the bird standing on it got bigger.
        local p = BirdFlight.profile(4)
        local held = BirdFlight.ENTRY.WIN * 2 + 10
        local o = BirdFlight.offsetFor("WIN", held, 0.3, p)
        expect(o.x).toBe(BirdFlight.SHOULDER_X)
        expect(o.y >= BirdFlight.SHOULDER_Y).toBe(true)
    end)

    test("a flight of proportional length takes proportionally longer", function()
        -- CRUISE_SPEED is a distance over a time, so it goes as linear/time; the minimum flight
        -- time is a time. Together: a 4x bird crossing 4x the distance takes 2x as long.
        local p = BirdFlight.profile(4)
        for d = 0, 40, 2.5 do
            expect(BirdFlight.flightDuration(d * 4, p)).toBeCloseTo(BirdFlight.flightDuration(d) * 2, 1e-9)
        end
    end)

    test("fidget GAPS are character, not proportion, and stay put", function()
        -- ⚠ How OFTEN a bird flutters or turns is per-species character to be chosen by eye, not
        -- a consequence of its length. A crow is plausibly more deliberate than a warbler, but
        -- that is a decision somebody makes, not arithmetic. Scaling these silently would take
        -- the choice away and hide it inside a square root.
        for _, seed in SEEDS do
            for i = 0, 8 do
                expect(BirdFlight.nextFlutterGap(seed, i) > 0).toBe(true)
                expect(BirdFlight.nextTurnGap(seed, i) > 0).toBe(true)
            end
        end
        expect(BirdFlight.profile(4).FLUTTER_GAP).toBeNil()
        expect(BirdFlight.profile(4).TURN_GAP).toBeNil()
    end)

    test("a wider bird is given back exactly the width it gained, and no more", function()
        -- ⚠ THE SEAT SAYS WHERE THE FEET GO; THE BODY IS WHAT CROWDS THE NECK. Owner, 2026-08-28,
        -- looking at the karasu on a shoulder: "a little tight to the head". SEAT_INBOARD is a
        -- proportion of the AVATAR's arm and is right to stay that way -- a shoulder does not
        -- move because the bird on it got bigger -- but a bird centred on its feet reaches half
        -- its width inboard, so a wider bird crowds the neck from an identical footprint.
        --
        -- ⚠ BOTH WIDTHS ARE MEASURED; NEITHER IS INFERRED FROM LENGTH. The first version of this
        -- took the reference width as `width / scale`, on the assumption that a bigger bird is a
        -- scaled one. Measured in the live place the same day, the karasu is 1.98x the uguisu in
        -- LENGTH, 1.90x in height and only 1.47x in WIDTH -- it is a slimmer bird for its length,
        -- and the assumption over-relieved by about a third of an inch. Two measured numbers need
        -- no scale factor at all, so the approximation is gone rather than corrected.
        for _, w in { 0.1, 0.328, 1.0, 2.5 } do
            expect(BirdFlight.seatRelief(w, w)).toBe(0) -- ⚠ EXACTLY: the uguisu was gated here
        end
        -- the karasu against the uguisu, both measured off the shipped meshes
        expect(BirdFlight.seatRelief(0.328, 0.222)).toBeCloseTo(0.053, 1e-12)
        -- ⚠ A NARROWER-THAN-REFERENCE BIRD GOES THE OTHER WAY, and that is not a sign error: it
        -- can sit closer in without crowding anything, so the relief is negative.
        expect(BirdFlight.seatRelief(0.15, 0.222) < 0).toBe(true)
        -- monotonic in the bird's own width, so no bird is relieved less than a narrower one
        local last = -math.huge
        for _, w in { 0.1, 0.222, 0.328, 0.5, 1.0 } do
            local r = BirdFlight.seatRelief(w, 0.222)
            expect(r > last).toBe(true)
            last = r
        end
    end)

    test("the karasu is about twice the uguisu, so it moves about 1.41x slower", function()
        local BirdSpecies = require("../src/shared/BirdSpecies")
        local p = BirdFlight.profile(BirdSpecies.scaleOf("Karasu") :: number)
        expect(p.linear).toBeCloseTo(2, 0.05)
        expect(p.time).toBeCloseTo(1.41, 0.02)
        -- The trap this whole pass exists to avoid: times must NOT track length.
        expect(p.time < p.linear * 0.8).toBe(true)
    end)
end)
