--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShojiRun = require("../src/shared/ShojiRun")

describe("ShojiRun.clamp — a screen stops at the ends of its own run", function()
    test("the end screens can only travel inward", function()
        -- a four-bay run: bay 1 can go 0..+3, bay 4 can go -3..0
        expect(ShojiRun.clamp(1, 4, 3)).toBe(3)
        expect(ShojiRun.clamp(1, 4, 4)).toBe(3)
        expect(ShojiRun.clamp(1, 4, -1)).toBe(0)
        expect(ShojiRun.clamp(4, 4, -3)).toBe(-3)
        expect(ShojiRun.clamp(4, 4, 1)).toBe(0)
    end)

    test("an interior screen travels both ways", function()
        expect(ShojiRun.clamp(3, 4, -2)).toBe(-2)
        expect(ShojiRun.clamp(3, 4, 1)).toBe(1)
        expect(ShojiRun.clamp(3, 4, 2)).toBe(1)
    end)

    test("there is no per-screen cap — only the run", function()
        -- the owner's ruling, 2026-08-18: a whole run may tuck into one bay
        expect(ShojiRun.clamp(1, 4, 3)).toBe(3)
    end)

    test("a one-bay run cannot move at all", function()
        expect(ShojiRun.clamp(1, 1, 2)).toBe(0)
    end)

    test("nonsense resolves to closed rather than erroring", function()
        expect(ShojiRun.clamp(1, 4, 0 / 0)).toBe(0)
        expect(ShojiRun.clamp(1, 4, nil :: any)).toBe(0)
    end)
end)

describe("ShojiRun — a whole run can stack in any single bay", function()
    test("every screen can reach every bay position", function()
        for count = 2, 4 do
            for target = 1, count do
                for index = 1, count do
                    local want = target - index
                    expect(ShojiRun.clamp(index, count, want)).toBe(want)
                end
            end
        end
    end)
end)

describe("ShojiRun.grooveOffset — one channel per screen, centred on the wall", function()
    test("two grooves straddle the wall's mid-plane", function()
        expect(ShojiRun.grooveOffset(1, 2)).toBe(-0.1)
        expect(ShojiRun.grooveOffset(2, 2)).toBe(0.1)
    end)

    test("three grooves put the middle screen on the mid-plane", function()
        expect(ShojiRun.grooveOffset(1, 3)).toBe(-0.2)
        expect(ShojiRun.grooveOffset(2, 3)).toBe(0)
        expect(ShojiRun.grooveOffset(3, 3)).toBe(0.2)
    end)

    test("four grooves span 0.60 between the outer two", function()
        expect(ShojiRun.grooveOffset(4, 4) - ShojiRun.grooveOffset(1, 4)).toBeCloseTo(0.6, 0.0001)
    end)

    test("no two screens in a run share a groove", function()
        for count = 2, 4 do
            local seen = {}
            for i = 1, count do
                local z = ShojiRun.grooveOffset(i, count)
                expect(seen[z]).toBe(nil)
                seen[z] = true
            end
        end
    end)
end)

describe("ShojiRun.directionFrom — which way a hold sends a screen", function()
    test("a screen mostly open comes home", function()
        expect(ShojiRun.directionFrom(1, 4, 0.5)).toBe(-1)
        expect(ShojiRun.directionFrom(1, 4, 2)).toBe(-1)
        expect(ShojiRun.directionFrom(4, 4, -2)).toBe(1)
    end)

    test("a screen barely open keeps going the way it started", function()
        -- reversing under the player's finger is the thing this rule exists to prevent
        expect(ShojiRun.directionFrom(2, 4, 0.4)).toBe(1)
        expect(ShojiRun.directionFrom(2, 4, -0.4)).toBe(-1)
    end)

    test("a screen at rest opens toward the far end of its run", function()
        expect(ShojiRun.directionFrom(1, 4, 0)).toBe(1)
        expect(ShojiRun.directionFrom(3, 4, 0)).toBe(1)
    end)

    test("the LAST screen in a run opens back down it, not into a wall", function()
        -- +1 from the last bay is clamped to nothing, so a rule that returns it here hands
        -- the player a prompt that does nothing when held
        expect(ShojiRun.directionFrom(4, 4, 0)).toBe(-1)
        expect(ShojiRun.directionFrom(2, 2, 0)).toBe(-1)
    end)

    test("a one-bay run still answers, even though nothing can move", function()
        expect(ShojiRun.directionFrom(1, 1, 0)).toBe(-1)
    end)
end)

describe("ShojiRun.displacement — travel in bay-widths becomes studs", function()
    test("one bay-width is the pitch", function()
        expect(ShojiRun.displacement(1)).toBe(6)
        expect(ShojiRun.displacement(-2)).toBe(-12)
        expect(ShojiRun.displacement(0.5)).toBe(3)
    end)
end)

describe("ShojiRun.resolve — a stored map becomes one number per bay", function()
    test("missing entries are closed", function()
        expect(ShojiRun.resolve(nil, 3)).toEqual({ 0, 0, 0 })
        expect(ShojiRun.resolve({ 1 }, 3)).toEqual({ 1, 0, 0 })
    end)

    test("stored values are clamped to the run they land in", function()
        -- a house that shrank: a saved offset from a wider run must not hang a screen off the end
        expect(ShojiRun.resolve({ 3, 0 }, 2)).toEqual({ 1, 0 })
    end)

    test("junk in a slot is closed, not an error", function()
        expect(ShojiRun.resolve({ "x" :: any, 1 }, 2)).toEqual({ 0, 0 })
    end)

    test("junk in the WHOLE slot -- not a list at all -- is closed, not an error", function()
        -- a stray boolean/number/string from an older document shape, in place of the per-bay
        -- list; must read as fully absent rather than indexing into it and throwing
        expect(ShojiRun.resolve(true :: any, 3)).toEqual({ 0, 0, 0 })
        expect(ShojiRun.resolve(5 :: any, 3)).toEqual({ 0, 0, 0 })
        expect(ShojiRun.resolve("nope" :: any, 3)).toEqual({ 0, 0, 0 })
    end)
end)
