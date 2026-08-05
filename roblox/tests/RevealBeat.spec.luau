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

    test("the beat is a real beat, and outlives the round boundary on purpose", function()
        -- The drum rests with about a second left before the next round opens. A beat that had to
        -- fit inside that was cut off almost immediately — the owner saw the glyph appear correctly
        -- and be replaced by the fresh countdown in under a second. So it now runs ACROSS the
        -- boundary rather than being squeezed to fit, and main.client no longer collapses it when
        -- ACTIVE arrives.
        expect(RevealBeat.TAPE_DELAY_SECONDS > 2).toBe(true)
    end)

    test("but it must finish well before the NEXT reveal", function()
        -- The one real ceiling. Two overlapping beats would mean the older one's tape tile is
        -- released by the newer beat's arrival instead of by its own schedule — the tile still
        -- lands, but its timing stops being the beat's to control.
        expect(RevealBeat.TAPE_DELAY_SECONDS < RevealBeat.MAX_SAFE_SECONDS).toBe(true)
    end)

    test("it holds no Roblox globals — numbers only", function()
        for key, value in RevealBeat do
            expect(typeof(key)).toBe("string")
            expect(typeof(value)).toBe("number")
        end
    end)
end)
