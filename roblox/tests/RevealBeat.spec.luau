--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RevealBeat = require("../src/shared/RevealBeat")

describe("RevealBeat — the sequence after the drum stops", function()
    test("the glyph gets a real beat, not a flash", function()
        -- The owner asked for "a few seconds". Before this, the glyph lived on leftover time and
        -- measured 3.03s, 1.81s and 4.15s across three consecutive rounds — the variance is what
        -- made it read as absent.
        expect(RevealBeat.HOLD_SECONDS >= 1.5).toBe(true)
        expect(RevealBeat.FADE_SECONDS > 0).toBe(true)
    end)

    test("the tape lands AFTER the glyph has fully gone", function()
        -- THE ORDERING THE WHOLE BEAT EXISTS FOR. The tape tile arriving with the glyph is what
        -- made the glyph invisible: three things in one frame and the smallest loses.
        expect(RevealBeat.TAPE_DELAY_SECONDS).toBe(RevealBeat.HOLD_SECONDS + RevealBeat.FADE_SECONDS)
    end)

    test("the whole beat fits the runway, with headroom", function()
        -- RUNWAY_SECONDS is measured, not guessed: the drum rests ~3.2s into the gap between
        -- rounds, and Task 2 made that gap TALLY(2) + REVEAL(5) = 7s.
        expect(RevealBeat.TAPE_DELAY_SECONDS < RevealBeat.RUNWAY_SECONDS).toBe(true)
        -- Not merely fitting: the tape must be readable before the next round opens.
        expect(RevealBeat.RUNWAY_SECONDS - RevealBeat.TAPE_DELAY_SECONDS >= 1).toBe(true)
    end)

    test("it holds no Roblox globals — numbers only", function()
        for key, value in RevealBeat do
            expect(typeof(key)).toBe("string")
            expect(typeof(value)).toBe("number")
        end
    end)
end)
