--!strict
local harness = require("./harness")
local RiverPathChapters = require("../tools/builders/RiverPathChapters")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RiverPathChapters.CHAPTERS", function()
    test("has five chapters", function()
        expect(#RiverPathChapters.CHAPTERS).toBe(5)
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

    test("chapters are contiguous: each starts where the previous ended", function()
        local list = RiverPathChapters.CHAPTERS
        for i = 2, #list do
            local prev = list[i - 1].control
            local prevEnd = prev[#prev]
            local thisStart = list[i].control[1]
            expect(thisStart[1]).toBeCloseTo(prevEnd[1], 0.5)
            expect(thisStart[2]).toBeCloseTo(prevEnd[2], 0.5)
            expect(thisStart[3]).toBeCloseTo(prevEnd[3], 0.5)
        end
    end)

    test("the route climbs westward and never descends", function()
        for _, c in RiverPathChapters.CHAPTERS do
            for i = 2, #c.control do
                expect(c.control[i][2] >= c.control[i - 1][2] - 0.01).toBe(true)
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

describe("RiverPathChapters.kindFor", function()
    test("a level run is flat", function()
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -100, 101, 0 } })).toBe("flat")
    end)

    test("a steep run is stair", function()
        expect(RiverPathChapters.kindFor({ { 0, 100, 0 }, { -20, 125, 0 } })).toBe("stair")
    end)

    test("one steep pair among gentle ones makes the whole chapter a stair", function()
        expect(RiverPathChapters.kindFor({
            { 0, 100, 0 },
            { -50, 101, 0 },
            { -70, 126, 0 },
        })).toBe("stair")
    end)
end)

describe("RiverPathChapters.validate", function()
    test("the shipped data validates", function()
        local ok, errs = RiverPathChapters.validate()
        expect(#errs).toBe(0)
        expect(ok).toBe(true)
    end)
end)
