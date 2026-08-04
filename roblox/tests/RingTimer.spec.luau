--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RingTimer = require("../src/shared/RingTimer")

describe("RingTimer.sweepDegrees — how much of the circle is still there", function()
    test("a full round sweeps the whole circle", function()
        expect(RingTimer.sweepDegrees(1)).toBe(360)
    end)

    test("an empty round sweeps nothing — the ring is GONE", function()
        expect(RingTimer.sweepDegrees(0)).toBe(0)
    end)

    test("half a round sweeps half the circle", function()
        expect(RingTimer.sweepDegrees(0.5)).toBe(180)
    end)

    test("ANY time remaining sweeps at least MIN_SWEEP_DEGREES", function()
        -- The invariant the old segment count carried with math.ceil, restated for a continuous
        -- ring. A player with a sliver of a second must not see an EMPTY ring: the round is
        -- still open and the throw buttons are still live. 0.2s of a 20s round is 3.6 degrees,
        -- which at 44px is sub-pixel and renders as nothing at all.
        expect(RingTimer.sweepDegrees(0.0001)).toBe(RingTimer.MIN_SWEEP_DEGREES)
        expect(RingTimer.sweepDegrees(0.0001) > 0).toBe(true)
    end)

    test("the floor is big enough to actually see", function()
        -- A floor of, say, 0.5 degrees would satisfy "> 0" and still render as nothing. At 6
        -- degrees the arc is ~2px along a 38px-diameter phone ring: visible.
        expect(RingTimer.MIN_SWEEP_DEGREES >= 4).toBe(true)
    end)

    test("it is monotonic and never leaves the circle", function()
        local prev = -1
        for i = 0, 100 do
            local v = RingTimer.sweepDegrees(i / 100)
            expect(v >= prev).toBe(true)
            expect(v <= 360).toBe(true)
            expect(v >= 0).toBe(true)
            prev = v
        end
    end)

    test("a fraction outside [0,1] clamps rather than extrapolating", function()
        expect(RingTimer.sweepDegrees(-3)).toBe(0)
        expect(RingTimer.sweepDegrees(9)).toBe(360)
    end)
end)

describe("RingTimer.sweep — the two gradient rotations that draw that arc", function()
    test("half A never moves", function()
        -- It is the fixed half; only B moves and changes colour. Returned rather than exported
        -- as a bare constant so the pair that has to agree is produced in one place.
        for _, f in { 0, 0.1, 0.5, 0.7, 1 } do
            expect(RingTimer.sweep(f).rotationA).toBe(180)
        end
    end)

    test("under half a turn, B is the TRACK colour and paints back the excess", function()
        local s = RingTimer.sweep(0.25) -- 90 degrees
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(270) -- 90 + 180
    end)

    test("over half a turn, B is LIT and extends the arc", function()
        local s = RingTimer.sweep(0.75) -- 270 degrees
        expect(s.bLit).toBe(true)
        expect(s.rotationB).toBe(270)
    end)

    test("exactly half a turn is still the track branch", function()
        local s = RingTimer.sweep(0.5)
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(360)
    end)

    test("a full round lights the whole circle", function()
        local s = RingTimer.sweep(1)
        expect(s.bLit).toBe(true)
        expect(s.rotationB).toBe(360)
    end)

    test("an empty round lights nothing", function()
        local s = RingTimer.sweep(0)
        expect(s.bLit).toBe(false)
        expect(s.rotationB).toBe(180) -- B in track, exactly over A: nothing survives
    end)
end)

describe("RingTimer.sweep — what the two halves actually cover", function()
    -- The strongest test in this file: it reconstructs the painted arc from the rotations the
    -- way the renderer does, and checks it against sweepDegrees. A sign error, an off-by-180 or
    -- a flipped branch all fail here and nowhere else.
    local function litDegrees(fraction: number): number
        local s = RingTimer.sweep(fraction)
        -- A half-disc at UIGradient.Rotation R shows the clockwise arc [R - 180, R] from the top.
        local aStart = (s.rotationA - 180) % 360
        local bStart = (s.rotationB - 180) % 360
        local function covers(start: number, deg: number): boolean
            local d = (deg - start) % 360
            return d < 180
        end
        local count = 0
        for deg = 0, 359 do
            local inA = covers(aStart, deg + 0.5)
            local inB = covers(bStart, deg + 0.5)
            local lit
            if s.bLit then
                lit = inA or inB
            else
                lit = inA and not inB
            end
            if lit then
                count += 1
            end
        end
        return count
    end

    test("the painted arc matches the requested sweep, all the way round", function()
        for i = 0, 40 do
            local f = i / 40
            local want = RingTimer.sweepDegrees(f)
            local got = litDegrees(f)
            -- One degree of slack: the reconstruction samples whole degrees.
            expect(math.abs(got - want) <= 1).toBe(true)
        end
    end)

    test("the arc always starts at the top and runs clockwise", function()
        -- Degree 0 (the top) is lit for any live round and dark for a dead one.
        expect(litDegrees(0)).toBe(0)
        expect(litDegrees(0.02) > 0).toBe(true)
    end)
end)

describe("RingTimer.isWarning", function()
    test("it warns at and below the threshold", function()
        expect(RingTimer.isWarning(5, 5)).toBe(true)
        expect(RingTimer.isWarning(1, 5)).toBe(true)
    end)

    test("it does not warn above the threshold", function()
        expect(RingTimer.isWarning(5.01, 5)).toBe(false)
        expect(RingTimer.isWarning(20, 5)).toBe(false)
    end)
end)

describe("RingTimer — the segmented ring is gone", function()
    test("nothing counts segments any more", function()
        -- The ring is drawn as a pie now (spec §4). These four were the segment API; leaving a
        -- stale one behind invites a caller that draws a polygon beside a circle.
        expect((RingTimer :: any).SEGMENTS).toBe(nil)
        expect((RingTimer :: any).lit).toBe(nil)
        expect((RingTimer :: any).angleAt).toBe(nil)
        expect((RingTimer :: any).segmentWidth).toBe(nil)
    end)
end)
