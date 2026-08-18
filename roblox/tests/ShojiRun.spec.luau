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

describe("ShojiRun.runAxis — the one place the per-side run direction lives", function()
    test("front and back run along local X", function()
        expect(ShojiRun.runAxis("front")).toEqual({ x = 1, y = 0, z = 0 })
        expect(ShojiRun.runAxis("back")).toEqual({ x = 1, y = 0, z = 0 })
    end)

    test("left and right run along local Z", function()
        expect(ShojiRun.runAxis("left")).toEqual({ x = 0, y = 0, z = 1 })
        expect(ShojiRun.runAxis("right")).toEqual({ x = 0, y = 0, z = 1 })
    end)

    test("an unrecognised side answers nil, not a guess", function()
        expect(ShojiRun.runAxis("up")).toBe(nil)
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

describe("ShojiRun.isSlidable — only a bay RESOLVED to shoji has a screen to slide", function()
    test("the applied state, not the presence of a variant, is the gate", function()
        -- applyBays hides a variant by transparency, never by removing it, so a solid bay still
        -- answers FindFirstChild("Shoji"). This is the rule that stops a "Slide open" prompt
        -- appearing on every solid wall in the game.
        expect(ShojiRun.isSlidable("shoji")).toBe(true)
        expect(ShojiRun.isSlidable("solid")).toBe(false)
        expect(ShojiRun.isSlidable("door")).toBe(false)
    end)

    test("an unwritten or junk BayState is not slidable", function()
        -- a bay applyBays skipped (missing variant, unknown state) carries no attribute at all;
        -- the safe reading of "I don't know" is "no prompt, no hold"
        expect(ShojiRun.isSlidable(nil)).toBe(false)
        expect(ShojiRun.isSlidable(true)).toBe(false)
        expect(ShojiRun.isSlidable(3)).toBe(false)
        expect(ShojiRun.isSlidable("Shoji")).toBe(false)
    end)
end)

describe("ShojiRun.ordinalOf — the wire carries a RAW bay number, the run carries ordinals", function()
    test("a raw bay number becomes its position within the run", function()
        -- Bay_back_2 and Bay_back_5 are the only shoji bays of that wall: they are ordinals 1 and 2
        expect(ShojiRun.ordinalOf({ 2, 5 }, 2)).toBe(1)
        expect(ShojiRun.ordinalOf({ 2, 5 }, 5)).toBe(2)
    end)

    test("a bay outside the run has no ordinal, and never borrows a neighbour's", function()
        expect(ShojiRun.ordinalOf({ 2, 5 }, 3)).toBe(nil)
        expect(ShojiRun.ordinalOf({}, 1)).toBe(nil)
    end)

    test("junk on the wire resolves to nothing rather than an ordinal", function()
        expect(ShojiRun.ordinalOf({ 1, 2 }, "1" :: any)).toBe(nil)
        expect(ShojiRun.ordinalOf({ 1, 2 }, 1.5)).toBe(nil)
        expect(ShojiRun.ordinalOf({ 1, 2 }, 0)).toBe(nil)
        expect(ShojiRun.ordinalOf({ 1, 2 }, 0 / 0)).toBe(nil)
        expect(ShojiRun.ordinalOf({ 1, 2 }, nil :: any)).toBe(nil)
    end)
end)

describe("ShojiRun.quantize — a travel small enough to fit the loadout budget", function()
    test("three decimal places is the persisted precision", function()
        expect(ShojiRun.quantize(0.1234567)).toBe(0.123)
        expect(ShojiRun.quantize(-0.9876)).toBe(-0.988)
        expect(ShojiRun.quantize(2)).toBe(2)
    end)

    test("junk quantizes to closed, same posture as clamp", function()
        expect(ShojiRun.quantize(0 / 0)).toBe(0)
        expect(ShojiRun.quantize(math.huge)).toBe(0)
        expect(ShojiRun.quantize(nil :: any)).toBe(0)
    end)
end)
