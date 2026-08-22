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
        -- ⚠ and BEHIND the head: the tail trails backwards from the perch point, so a shoulder
        -- offset that only clears sideways still buries the tail in the avatar.
        expect(settled.z < -0.25).toBe(true)
        -- A result must outlast the instant it happened — glancing over a few seconds later
        -- should still tell you what happened.
        for _, t in { 3, 8, 14 } do
            local p = BirdFlight.offsetFor("WIN", t, 7)
            expect(p.y > 0.9 and p.y < 1.4).toBe(true)
        end
    end)

    test("WIN hops rather than sitting still", function()
        local low, high = 99, 0
        -- The exported constant, not a sampled position: sampling lands on ONE SIDE of the hop,
        -- so the comparison would be against an edge rather than the centre and the test would
        -- pass or fail on floating-point luck.
        local centre = BirdFlight.SHOULDER_X
        local left, right = false, false
        for t = 2, 6, 0.02 do
            local p = BirdFlight.offsetFor("WIN", t, 7)
            low, high = math.min(low, p.y), math.max(high, p.y)
            if p.x < centre then
                left = true
            end
            if p.x > centre then
                right = true
            end
        end
        expect(high - low > 0.08).toBe(true) -- it bobs
        expect(left and right).toBe(true) -- and shuffles to both sides of the shoulder
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

    test("fold angles run from FULLY FOLDED to FULLY SPREAD and never past", function()
        -- ⚠ These are MEASURED angles, verified in Roblox through Bone.Transform, not guesses:
        -- shoulder -70 / wrist -110 draws the wing in against the flank, 0/0 is full spread.
        local s0, w0 = BirdFlight.foldAngles(0)
        expect(s0).toBe(BirdFlight.FOLD_SHOULDER)
        expect(w0).toBe(BirdFlight.FOLD_WRIST)
        local s1, w1 = BirdFlight.foldAngles(1)
        expect(s1).toBe(0)
        expect(w1).toBe(0)
        -- monotonic, and clamped outside 0..1 so a bad caller cannot hyperextend a wing
        local prev = BirdFlight.FOLD_SHOULDER - 1
        for k = 0, 1.0001, 0.05 do
            local sh = BirdFlight.foldAngles(math.min(1, k))
            expect(sh >= prev).toBe(true)
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

    test("a PERCHED bird is still most of the time, and flutters occasionally", function()
        -- Owner, 2026-08-19: "even a perched bird flutters its wings occasionally, and certainly
        -- when arriving or leaving a perch." Occasionally is the operative word -- a bird that
        -- flutters constantly reads as distressed, not resting.
        local moving, samples = 0, 0
        local peak = 0
        for t = 0, 120, 0.05 do
            local a = BirdFlight.wingAngle(t, 7, false)
            samples += 1
            if a > 1.0 then
                moving += 1
            end
            peak = math.max(peak, a)
        end
        local share = moving / samples
        expect(share > 0.02).toBe(true) -- it does happen
        expect(share < 0.25).toBe(true) -- but it is not what the bird is doing
        expect(peak > 6).toBe(true) -- and when it happens you can see it
    end)

    test("wing lift is deterministic per seed, and seeds differ", function()
        expect(BirdFlight.wingAngle(3.3, 7, false)).toBe(BirdFlight.wingAngle(3.3, 7, false))
        local differs = false
        for t = 0, 60, 0.25 do
            if BirdFlight.wingAngle(t, 7, false) ~= BirdFlight.wingAngle(t, 8, false) then
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

    test("is deterministic per seed, so two clients draw the same bird", function()
        local a = BirdFlight.offsetFor("RESTING", 3.3, 7)
        local b = BirdFlight.offsetFor("RESTING", 3.3, 7)
        local other = BirdFlight.offsetFor("RESTING", 3.3, 8)
        expect(BirdFlight.distance(a, b)).toBe(0)
        expect(BirdFlight.distance(a, other) > 0).toBe(true)
    end)
end)
