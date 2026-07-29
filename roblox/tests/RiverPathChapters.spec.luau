--!strict
local harness = require("./harness")
local RiverPathChapters = require("../tools/builders/RiverPathChapters")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RiverPathChapters.CHAPTERS", function()
    test("has three chapters, all of them climbs", function()
        expect(#RiverPathChapters.CHAPTERS).toBe(3)
        local flat, stair = 0, 0
        for _, c in RiverPathChapters.CHAPTERS do
            if c.kind == "flat" then
                flat += 1
            elseif c.kind == "stair" then
                stair += 1
            end
        end
        expect(flat).toBe(0)
        expect(stair).toBe(3)
    end)

    test("the route starts at the Square's western edge", function()
        local first = RiverPathChapters.CHAPTERS[1]
        expect(first.outModel).toBe("RiverSquareStair")
        expect(first.control[1][1]).toBeCloseTo(-51.9, 1.0)
    end)

    test("the Square stair matches NW1012South's proven grade", function()
        local c = RiverPathChapters.CHAPTERS[1].control
        local g = RiverPathChapters.grade(c[1], c[#c])
        -- NW1012South, built and walked, runs at 0.77
        expect(g).toBeCloseTo(0.77, 0.08)
    end)

    test("every chapter has at least two control points", function()
        for _, c in RiverPathChapters.CHAPTERS do
            expect(#c.control >= 2).toBe(true)
        end
    end)

    test("control points run east to west within a chapter", function()
        for _, c in RiverPathChapters.CHAPTERS do
            for i = 2, #c.control do
                expect(c.control[i][1] < c.control[i - 1][1]).toBe(true)
            end
        end
    end)

    test("consecutive chapters are contiguous or joined by a bridge", function()
        local list = RiverPathChapters.CHAPTERS
        for i = 2, #list do
            local prev = list[i - 1].control
            local prevEnd = prev[#prev]
            local thisStart = list[i].control[1]
            local contiguous = true
            for axis = 1, 3 do
                if math.abs(prevEnd[axis] - thisStart[axis]) > 0.5 then
                    contiguous = false
                    break
                end
            end
            if not contiguous then
                expect(RiverPathChapters.bridgeBetween(prevEnd, thisStart)).toBeTruthy()
            end
        end
    end)

    test("the route climbs westward and never meaningfully descends", function()
        for _, c in RiverPathChapters.CHAPTERS do
            for i = 2, #c.control do
                local drop = c.control[i - 1][2] - c.control[i][2]
                expect(drop <= RiverPathChapters.DESCENT_TOLERANCE).toBe(true)
            end
        end
    end)

    test("the west terminus stops short of NW80FallsStair", function()
        local list = RiverPathChapters.CHAPTERS
        local lastControl = list[#list].control
        local last = lastControl[#lastControl]
        expect(last[1]).toBeCloseTo(RiverPathChapters.WEST_TERMINUS, 1.0)
        expect(last[1] > -392).toBe(true)
    end)

    test("each chapter's declared kind matches its measured grade", function()
        for _, c in RiverPathChapters.CHAPTERS do
            expect(RiverPathChapters.kindFor(c.control)).toBe(c.kind)
        end
    end)

    test("outModel names are unique and prefixed River", function()
        local seen: { [string]: boolean } = {}
        for _, c in RiverPathChapters.CHAPTERS do
            expect(seen[c.outModel]).toBeNil()
            seen[c.outModel] = true
            expect(c.outModel:sub(1, 5)).toBe("River")
        end
    end)
end)

describe("RiverPathChapters.FLAT_MAX_GRADE", function()
    -- The crossover is set by the locked recipe, not by CanyonPath.STEP_GRADE (0.27):
    -- at treadTarget 6.0 a grade of 0.10 gives a 0.6-stud tread rise, exactly the
    -- ishidan riserTarget. Anything steeper in a flat-shelf layout exceeds it.
    test("is the grade at which a 6-stud tread rises one riserTarget", function()
        expect(RiverPathChapters.FLAT_MAX_GRADE * 6.0).toBeCloseTo(0.6, 0.001)
    end)

    test("is well below CanyonPath.STEP_GRADE, which asks a different question", function()
        expect(RiverPathChapters.FLAT_MAX_GRADE < 0.27).toBe(true)
    end)
end)

describe("RiverPathChapters.kindFor", function()
    test("a level run is flat", function()
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -100, 101, 0 } })).toBe("flat")
    end)

    test("a steep run is stair", function()
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -20, 125, 0 } })).toBe("stair")
    end)

    test("a 0.26 grade is a stair even though STEP_GRADE would call it a ramp", function()
        -- 26 studs of rise over 100 of run: a 1.56-stud tread at treadTarget 6.0.
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -100, 126, 0 } })).toBe("stair")
    end)

    test("one steep pair among gentle ones makes the whole chapter a stair", function()
        expect(RiverPathChapters.kindFor({
            { 0, 100, 0 },
            { -50, 101, 0 },
            { -70, 126, 0 },
        })).toBe("stair")
    end)
end)

describe("RiverPathChapters.BRIDGES", function()
    test("has one crossing", function()
        expect(#RiverPathChapters.BRIDGES).toBe(1)
    end)

    test("its abutments join Mid climb to Upper climb", function()
        local list = RiverPathChapters.CHAPTERS
        local midControl = list[2].control
        local midEnd = midControl[#midControl]
        local upperStart = list[3].control[1]
        local br = RiverPathChapters.bridgeBetween(midEnd, upperStart)
        expect(br).toBeTruthy()
        expect((br :: any).name).toBe("RiverCrossing")
    end)

    test("the span is short enough for an arch bridge", function()
        for _, br in RiverPathChapters.BRIDGES do
            local run = math.sqrt((br.b[1] - br.a[1]) ^ 2 + (br.b[3] - br.a[3]) ^ 2)
            expect(run > 8).toBe(true)
            expect(run < 40).toBe(true)
        end
    end)

    test("crossing the bridge climbs, like the rest of the route", function()
        for _, br in RiverPathChapters.BRIDGES do
            expect(br.b[2] >= br.a[2]).toBe(true)
        end
    end)
end)

describe("RiverPathChapters.validate", function()
    test("the baked data validates", function()
        local ok, errs = RiverPathChapters.validate()
        expect(#errs).toBe(0)
        expect(ok).toBe(true)
    end)
end)
