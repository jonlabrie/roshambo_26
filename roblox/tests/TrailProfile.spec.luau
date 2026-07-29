--!strict
local harness = require("./harness")
local TrailProfile = require("../tools/builders/TrailProfile")
local RiverPathChapters = require("../tools/builders/RiverPathChapters")
local describe, test, expect = harness.describe, harness.test, harness.expect

local STRAIGHT = { { 0, 100, 0 }, { -60, 106, 0 } } -- 60 run, 6 rise, grade 0.1

local function chapter(outModel: string)
    for _, c in RiverPathChapters.CHAPTERS do
        if c.outModel == outModel then
            return c
        end
    end
    error("no chapter " .. outModel)
end

describe("TrailProfile.resample", function()
    test("spaces samples evenly along the horizontal projection", function()
        local s = TrailProfile.resample(STRAIGHT, 10)
        for i = 2, #s - 1 do
            expect(s[i].s - s[i - 1].s).toBeCloseTo(10, 1e-6)
        end
    end)

    test("emits both endpoints EXACTLY, so chapters still meet at the seam", function()
        local s = TrailProfile.resample(STRAIGHT, 7) -- 60 is not a multiple of 7
        expect(s[1].x).toBeCloseTo(0, 1e-9)
        expect(s[1].y).toBeCloseTo(100, 1e-9)
        expect(s[#s].x).toBeCloseTo(-60, 1e-9)
        expect(s[#s].y).toBeCloseTo(106, 1e-9)
    end)

    test("arc length is horizontal, ignoring rise", function()
        local steep = { { 0, 100, 0 }, { -30, 200, 0 } }
        local s = TrailProfile.resample(steep, 10)
        expect(s[#s].s).toBeCloseTo(30, 1e-6)
    end)

    test("follows a bend through its control point", function()
        local bent = { { 0, 100, 0 }, { -10, 100, 0 }, { -10, 100, 10 } }
        local s = TrailProfile.resample(bent, 5)
        expect(s[#s].s).toBeCloseTo(20, 1e-6)
        local mid = TrailProfile.at(s, 10)
        expect(mid.x).toBeCloseTo(-10, 0.01)
        expect(mid.z).toBeCloseTo(0, 0.01)
    end)

    -- REGRESSION. A single global arc phase let a sample straddle a vertex, and the
    -- line chorded the corner off -- 2.5 studs inside the marker on a 90-degree bend at
    -- spacing 5. Every control point must appear in the output.
    test("emits EVERY control point, at any spacing", function()
        local bent = { { 0, 100, 0 }, { -10, 100, 0 }, { -10, 100, 10 }, { -25, 104, 10 } }
        for _, spacing in { 1, 2, 3, 5, 7, 12, 40 } do
            local s = TrailProfile.resample(bent, spacing)
            for _, cp in bent do
                local hit = false
                for _, smp in s do
                    if math.abs(smp.x - cp[1]) < 1e-6 and math.abs(smp.z - cp[3]) < 1e-6 then
                        hit = true
                        break
                    end
                end
                expect(
                    ("spacing %d, control (%.1f, %.1f): %s"):format(
                        spacing,
                        cp[1],
                        cp[3],
                        hit and "present" or "MISSING"
                    )
                ).toBe(
                    ("spacing %d, control (%.1f, %.1f): present"):format(spacing, cp[1], cp[3])
                )
            end
        end
    end)

    -- REGRESSION. Restarting the arc phase at each vertex left a runt step before every
    -- one. `smooth` uses an INDEX window, so a runt gets a full share of elevation
    -- change over a tiny run -- which spiked the traverse's reported grade past
    -- TRAIL_MAX_GRADE on a stretch that benches perfectly well.
    test("no runt steps -- every step is within half a spacing of the target", function()
        for _, c in RiverPathChapters.CHAPTERS do
            local s = TrailProfile.resample(c.control, 2)
            for i = 2, #s do
                local step = s[i].s - s[i - 1].s
                expect(("%s step %.3f"):format(c.name, step)).toBe(("%s step %.3f"):format(c.name, step))
                expect(step > 1.0).toBe(true)
                expect(step < 3.0).toBe(true)
            end
        end
    end)

    test("arc length is monotonic and never decreases", function()
        local bent = { { 0, 100, 0 }, { -10, 100, 0 }, { -10, 100, 10 }, { -25, 104, 10 } }
        local s = TrailProfile.resample(bent, 3)
        for i = 2, #s do
            expect(s[i].s >= s[i - 1].s).toBe(true)
        end
    end)

    test("every baked chapter's control points survive resampling", function()
        for _, c in RiverPathChapters.CHAPTERS do
            local s = TrailProfile.resample(c.control, 2)
            for _, cp in c.control do
                local hit = false
                for _, smp in s do
                    if math.abs(smp.x - cp[1]) < 1e-6 and math.abs(smp.z - cp[3]) < 1e-6 then
                        hit = true
                        break
                    end
                end
                expect(("%s (%.1f): %s"):format(c.name, cp[1], hit and "kept" or "LOST")).toBe(
                    ("%s (%.1f): kept"):format(c.name, cp[1])
                )
            end
        end
    end)
end)

describe("TrailProfile.smooth", function()
    test("preserves BOTH endpoints exactly -- the shrinking window's whole purpose", function()
        local raw = TrailProfile.resample({ { 0, 100, 0 }, { -50, 100, 0 }, { -100, 140, 0 } }, 5)
        local sm = TrailProfile.smooth(raw, 4)
        expect(sm[1].y).toBeCloseTo(raw[1].y, 1e-9)
        expect(sm[#sm].y).toBeCloseTo(raw[#raw].y, 1e-9)
    end)

    test("cuts a bump down -- a tread does not follow the ground", function()
        local raw = TrailProfile.resample({ { 0, 100, 0 }, { -100, 100, 0 } }, 5)
        raw[10].y = 108 -- a boulder in the middle of the corridor
        local sm = TrailProfile.smooth(raw, 4)
        expect(sm[10].y < 103).toBe(true)
        expect(sm[10].y > 100).toBe(true)
    end)

    test("lowers the peak grade a bump introduces", function()
        local raw = TrailProfile.resample({ { 0, 100, 0 }, { -100, 100, 0 } }, 5)
        raw[10].y = 108
        local before = TrailProfile.maxGrade(raw)
        local after = TrailProfile.maxGrade(TrailProfile.smooth(raw, 4))
        expect(after < before).toBe(true)
    end)

    test("radius 0 is the identity", function()
        local raw = TrailProfile.resample(STRAIGHT, 5)
        local sm = TrailProfile.smooth(raw, 0)
        for i = 1, #raw do
            expect(sm[i].y).toBeCloseTo(raw[i].y, 1e-9)
        end
    end)

    test("leaves x and z alone -- it benches the profile, it does not move the line", function()
        local raw = TrailProfile.resample({ { 0, 100, 0 }, { -50, 100, 20 }, { -100, 140, 0 } }, 5)
        local sm = TrailProfile.smooth(raw, 4)
        for i = 1, #raw do
            expect(sm[i].x).toBeCloseTo(raw[i].x, 1e-9)
            expect(sm[i].z).toBeCloseTo(raw[i].z, 1e-9)
        end
    end)
end)

describe("TrailProfile.frames", function()
    test("forward points along travel and right is perpendicular to it", function()
        local f = TrailProfile.frames(TrailProfile.resample(STRAIGHT, 10))
        for _, fr in f do
            expect(fr.fx * fr.rx + fr.fz * fr.rz).toBeCloseTo(0, 1e-9)
            expect(math.sqrt(fr.fx ^ 2 + fr.fz ^ 2)).toBeCloseTo(1, 1e-9)
            expect(math.sqrt(fr.rx ^ 2 + fr.rz ^ 2)).toBeCloseTo(1, 1e-9)
        end
    end)

    test("right is forward rotated -90 degrees about +Y", function()
        -- travelling toward -X (westward, as the whole route does)
        local f = TrailProfile.frames(TrailProfile.resample(STRAIGHT, 10))
        expect(f[2].fx).toBeCloseTo(-1, 1e-6)
        expect(f[2].fz).toBeCloseTo(0, 1e-6)
        expect(f[2].rx).toBeCloseTo(0, 1e-6)
        expect(f[2].rz).toBeCloseTo(-1, 1e-6)
    end)

    test("returns one frame per sample", function()
        local s = TrailProfile.resample(STRAIGHT, 7)
        expect(#TrailProfile.frames(s)).toBe(#s)
    end)
end)

describe("TrailProfile.stoneSites", function()
    local OPTS = {
        spacing = 10,
        jitter = 0.35,
        halfWidth = 3,
        lateralFrac = 0.8,
        minScale = 0.6,
        maxScale = 1.4,
        sinkMin = 0.35,
        sinkMax = 0.65,
    }

    test("is deterministic for a given seed", function()
        local a = TrailProfile.stoneSites(200, OPTS, 20260729)
        local b = TrailProfile.stoneSites(200, OPTS, 20260729)
        expect(#a).toBe(#b)
        for i = 1, #a do
            expect(a[i].s).toBeCloseTo(b[i].s, 1e-12)
            expect(a[i].lateral).toBeCloseTo(b[i].lateral, 1e-12)
        end
    end)

    test("a different seed gives a different trace", function()
        local a = TrailProfile.stoneSites(200, OPTS, 20260729)
        local b = TrailProfile.stoneSites(200, OPTS, 19990101)
        local same = true
        for i = 1, math.min(#a, #b) do
            if math.abs(a[i].s - b[i].s) > 1e-9 then
                same = false
                break
            end
        end
        expect(same).toBe(false)
    end)

    test("every stone lands inside the trail and within the lateral allowance", function()
        local sites = TrailProfile.stoneSites(200, OPTS, 20260729)
        expect(#sites > 0).toBe(true)
        for _, st in sites do
            expect(st.s > 0).toBe(true)
            expect(st.s < 200).toBe(true)
            expect(math.abs(st.lateral) <= OPTS.halfWidth * OPTS.lateralFrac + 1e-9).toBe(true)
            expect(st.scale >= OPTS.minScale - 1e-9).toBe(true)
            expect(st.scale <= OPTS.maxScale + 1e-9).toBe(true)
            expect(st.sink >= OPTS.sinkMin - 1e-9).toBe(true)
            expect(st.sink <= OPTS.sinkMax + 1e-9).toBe(true)
        end
    end)

    test("stones are sparse -- a trace, not a bed", function()
        local sites = TrailProfile.stoneSites(200, OPTS, 20260729)
        -- roughly one per `spacing`, never one per sample
        expect(#sites < 200 / OPTS.spacing + 3).toBe(true)
        expect(#sites > 200 / OPTS.spacing - 3).toBe(true)
    end)

    test("sides do NOT strictly alternate -- that would read as a planted avenue", function()
        local sites = TrailProfile.stoneSites(600, OPTS, 20260729)
        local strict = true
        for i = 2, #sites do
            if (sites[i].lateral > 0) == (sites[i - 1].lateral > 0) then
                strict = false
                break
            end
        end
        expect(strict).toBe(false)
    end)

    test("but both sides get used", function()
        local sites = TrailProfile.stoneSites(600, OPTS, 20260729)
        local left, right = 0, 0
        for _, st in sites do
            if st.lateral > 0 then
                right += 1
            else
                left += 1
            end
        end
        expect(left > 0).toBe(true)
        expect(right > 0).toBe(true)
    end)
end)

describe("TrailProfile.lcg", function()
    test("stays in (0,1) and never leaves the exact-integer range", function()
        local state = 12345
        local r
        for _ = 1, 500 do
            state, r = TrailProfile.lcg(state)
            expect(r >= 0).toBe(true)
            expect(r <= 1).toBe(true)
            -- must stay an exact integer or arm64 and x86_64 CI will disagree
            expect(state).toBe(math.floor(state))
            expect(state < 2147483647).toBe(true)
        end
    end)
end)

describe("the baked trail chapters", function()
    test("the traverse benches to a tread no steeper than TRAIL_MAX_GRADE", function()
        local c = chapter("RiverTraverse")
        local sm = TrailProfile.smooth(TrailProfile.resample(c.control, 2), 3)
        expect(TrailProfile.maxGrade(sm) <= RiverPathChapters.TRAIL_MAX_GRADE).toBe(true)
    end)

    test("the pool shore benches to a tread no steeper than TRAIL_MAX_GRADE", function()
        local c = chapter("RiverPoolShore")
        local sm = TrailProfile.smooth(TrailProfile.resample(c.control, 2), 3)
        expect(TrailProfile.maxGrade(sm) <= RiverPathChapters.TRAIL_MAX_GRADE).toBe(true)
    end)

    test("smoothing does not drag the traverse off the built stair head", function()
        -- The trail starts ON RiverSquareStair's top tread at y 139.9. If smoothing
        -- moved it, walkers would step into a lip at the seam.
        local c = chapter("RiverTraverse")
        local sm = TrailProfile.smooth(TrailProfile.resample(c.control, 2), 3)
        expect(sm[1].y).toBeCloseTo(139.9, 1e-9)
        expect(sm[1].x).toBeCloseTo(-89.8, 1e-9)
    end)

    test("the traverse and the pool shore meet the falls steps exactly", function()
        local tr = chapter("RiverTraverse").control
        local st = chapter("RiverFallsSteps").control
        local ps = chapter("RiverPoolShore").control
        for axis = 1, 3 do
            expect(tr[#tr][axis]).toBeCloseTo(st[1][axis], 1e-9)
            expect(st[#st][axis]).toBeCloseTo(ps[1][axis], 1e-9)
        end
    end)
end)
