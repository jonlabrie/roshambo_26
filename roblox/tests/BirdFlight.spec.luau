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
        local win = BirdFlight.HOLD_WIN_ORBIT_Y
        local resting = BirdFlight.offsetFor("RESTING", 10, 7).y
        local loss = BirdFlight.offsetFor("LOSS", 10, 7).y
        -- ⚠ WIN now perches on the shoulder, so this no longer describes the shipped WIN — it
        -- pins the HIGH ORBIT that is kept in reserve, and the RESTING/LOSS separation that is
        -- still live. If the shoulder diagnostic fails and the orbit comes back, this test is
        -- already asserting the right thing.
        expect(win > resting + 3).toBe(true)
        expect(resting > loss + 1.5).toBe(true)
    end)

    test("wing lift NEVER exceeds the ceiling", function()
        for _, flying in { true, false } do
            for t = 0, 40, 0.1 do
                local a = BirdFlight.wingAngle(t, 7, flying)
                expect(a >= 0).toBe(true)
                expect(a <= BirdFlight.WING_MAX_DEG).toBe(true)
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

    test("a flying bird beats its wings continuously", function()
        local high, low = 0, 99
        for t = 0, 4, 0.02 do
            local a = BirdFlight.wingAngle(t, 7, true)
            high = math.max(high, a)
            low = math.min(low, a)
        end
        expect(high > BirdFlight.WING_MAX_DEG * 0.8).toBe(true)
        expect(low < BirdFlight.WING_MAX_DEG * 0.25).toBe(true)
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
            expect(BirdFlight.wingAngle(t, 7, false)).toBe(0)
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
