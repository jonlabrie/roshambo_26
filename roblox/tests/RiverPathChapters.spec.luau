--!strict
local harness = require("./harness")
local RiverPathChapters = require("../tools/builders/RiverPathChapters")
local describe, test, expect = harness.describe, harness.test, harness.expect

describe("RiverPathChapters.CHAPTERS", function()
    test("has five chapters in three registers", function()
        expect(#RiverPathChapters.CHAPTERS).toBe(5)
        local flat, trail, stair = 0, 0, 0
        for _, c in RiverPathChapters.CHAPTERS do
            if c.kind == "flat" then
                flat += 1
            elseif c.kind == "trail" then
                trail += 1
            elseif c.kind == "stair" then
                stair += 1
            end
        end
        expect(flat).toBe(0)
        expect(trail).toBe(3)
        expect(stair).toBe(2)
    end)

    test("the route starts at the Square's western edge", function()
        local first = RiverPathChapters.CHAPTERS[1]
        expect(first.outModel).toBe("RiverSquareStair")
        expect(first.control[1][1]).toBeCloseTo(-44.0, 1.0)
    end)

    test("the Square stair is a climbable stair, not a cliff or a ramp", function()
        local c = RiverPathChapters.CHAPTERS[1].control
        local g = RiverPathChapters.grade(c[1], c[#c])
        -- Steeper than the flat-shelf crossover, gentler than NW1012South's proven 0.77.
        expect(g > RiverPathChapters.FLAT_MAX_GRADE).toBe(true)
        expect(g < 0.77).toBe(true)
    end)

    test("the Square stair is gentle enough to carry flagstones", function()
        -- At riserTarget 0.6 the tread is run/steps; flags need pitch - 0.55 - 0.08
        -- to clear flagMinDepth 0.4. This is what distinguishes it from NW1012South,
        -- which is too steep and carries none.
        local c = RiverPathChapters.CHAPTERS[1].control
        local run = math.sqrt((c[2][1] - c[1][1]) ^ 2 + (c[2][3] - c[1][3]) ^ 2)
        local rise = c[2][2] - c[1][2]
        local steps = math.floor(rise / 0.6)
        local usable = run / steps - 0.63
        expect(usable > 0.4).toBe(true)
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

    test("every chapter's terrain admits its declared kind", function()
        for _, c in RiverPathChapters.CHAPTERS do
            local ok, why = RiverPathChapters.admits(c.kind, c.control)
            -- surface WHICH chapter failed and why; a bare false tells the next person nothing
            expect(("%s: %s"):format(c.name, why or "ok")).toBe(("%s: ok"):format(c.name))
            expect(ok).toBe(true)
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

describe("the trail register", function()
    -- The whole point of chapter 2: the care gradient governs the path's OWN
    -- construction, not just what grows beside it. Formal stonework near the Square,
    -- dirt trail out west. If someone re-registers the traverse as a stair, this fails.
    test("the traverse and the pool shore are trails, not stonework", function()
        local byName: { [string]: string } = {}
        for _, c in RiverPathChapters.CHAPTERS do
            byName[c.outModel] = c.kind
        end
        expect(byName.RiverTraverse).toBe("trail")
        expect(byName.RiverPoolShore).toBe("trail")
    end)

    test("the falls climb is the ONLY stepped thing between the Square and the bridge", function()
        local stairs = {}
        for _, c in RiverPathChapters.CHAPTERS do
            local x = c.control[1][1]
            if c.kind == "stair" and x < -89.0 and x > -297.0 then
                table.insert(stairs, c.outModel)
            end
        end
        expect(table.concat(stairs, ",")).toBe("RiverFallsSteps")
    end)

    test("the falls climb carries a landing, not one unbroken flight", function()
        -- A pitch gentle enough to walk, sitting between two that are not, is a landing.
        local c
        for _, ch in RiverPathChapters.CHAPTERS do
            if ch.outModel == "RiverFallsSteps" then
                c = ch
            end
        end
        expect(c).toBeTruthy()
        local control = (c :: any).control
        local gentle = 0
        for i = 2, #control do
            if RiverPathChapters.grade(control[i - 1], control[i]) < 0.2 then
                gentle += 1
            end
        end
        expect(gentle).toBe(1)
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

    test("the three thresholds are ordered flat < trail", function()
        expect(RiverPathChapters.FLAT_MAX_GRADE < RiverPathChapters.TRAIL_MAX_GRADE).toBe(true)
    end)
end)

describe("RiverPathChapters.admits", function()
    local LEVEL = { { 0, 100, 0 }, { -100, 105, 0 } } -- 0.05
    local WALKABLE = { { 0, 100, 0 }, { -100, 125, 0 } } -- 0.25
    local STEEP = { { 0, 100, 0 }, { -20, 125, 0 } } -- 1.25

    test("a loose tread is refused above TRAIL_MAX_GRADE", function()
        local ok, why = RiverPathChapters.admits("trail", STEEP)
        expect(ok).toBe(false)
        expect(type(why)).toBe("string")
    end)

    test("a walkable grade admits a trail", function()
        expect(RiverPathChapters.admits("trail", WALKABLE)).toBe(true)
    end)

    test("a stair is admissible at ANY grade above flat -- the limit is one-directional", function()
        expect(RiverPathChapters.admits("stair", WALKABLE)).toBe(true)
        expect(RiverPathChapters.admits("stair", STEEP)).toBe(true)
    end)

    test("a stair on level ground is refused -- it would build zero risers", function()
        expect(RiverPathChapters.admits("stair", LEVEL)).toBe(false)
    end)

    test("a flat shelf is refused above FLAT_MAX_GRADE", function()
        expect(RiverPathChapters.admits("flat", WALKABLE)).toBe(false)
        expect(RiverPathChapters.admits("flat", LEVEL)).toBe(true)
    end)

    test("an unknown kind is refused rather than silently passing", function()
        expect(RiverPathChapters.admits("cobble", WALKABLE)).toBe(false)
    end)

    test("one steep pair among gentle ones disqualifies a trail", function()
        expect(RiverPathChapters.admits("trail", {
            { 0, 100, 0 },
            { -50, 101, 0 },
            { -70, 126, 0 },
        })).toBe(false)
    end)
end)

describe("RiverPathChapters.maxGrade", function()
    test("reports the steepest pair, not the average", function()
        expect(RiverPathChapters.maxGrade({
            { 0, 100, 0 },
            { -100, 100, 0 },
            { -110, 105, 0 },
        })).toBeCloseTo(0.5, 0.001)
    end)
end)

describe("RiverPathChapters.BRIDGES", function()
    test("has one crossing", function()
        expect(#RiverPathChapters.BRIDGES).toBe(1)
    end)

    test("its abutments join the Pool shore to the Upper climb", function()
        local list = RiverPathChapters.CHAPTERS
        local shoreControl = list[4].control
        local shoreEnd = shoreControl[#shoreControl]
        local upperStart = list[5].control[1]
        local br = RiverPathChapters.bridgeBetween(shoreEnd, upperStart)
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
        expect(table.concat(errs, " | ")).toBe("")
        expect(ok).toBe(true)
    end)
end)
