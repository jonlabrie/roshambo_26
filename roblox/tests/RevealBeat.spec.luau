--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local RevealBeat = require("../src/shared/RevealBeat")
local DrumStep = require("../src/shared/DrumStep")

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

    test("the whole ceremony fits the REVEAL phase the server ships", function()
        -- THE CROSS-CODEBASE NUMBER, and the one this project keeps getting wrong by writing it
        -- down twice. REVEAL's length is not derived here — it is `ROUND_REVEAL_SECONDS` in
        -- server/src/index.ts (default 7). If that changes, this constant changes with it, and
        -- this test is what makes the drift loud instead of silent.
        local REVEAL_SECONDS = 7
        -- Measured from the strike, which IS the start of REVEAL: the drum settles, then the beat.
        local ceremony = DrumStep.SETTLE_SECONDS + RevealBeat.TAPE_DELAY_SECONDS
        expect(ceremony <= REVEAL_SECONDS).toBe(true)
        -- ...and it genuinely needed the room. REVEAL was 3s, then 5s, and the ceremony fits
        -- neither — which is why the glyph's lifetime used to be whatever time happened to be
        -- spare (3.03s, 1.81s and 4.15s across three consecutive measured rounds).
        expect(ceremony > 5).toBe(true)
    end)

    test("but a stalled drum still pushes it past the boundary, so the tolerance must stay", function()
        -- SETTLE_SECONDS is the unstalled chain only. When the World Throw is late the drum waits,
        -- rest lands later than 3.45, and the beat runs into the next round. Since stage 3 the
        -- throw arrives AFTER the strike rather than ~2s before it, so this is the common case.
        -- main.client must NOT collapse the beat when OPEN arrives; deleting that tolerance
        -- reinstates the cut-off glyph on exactly the rounds whose timing is already worst.
        local stalledCeremony = DrumStep.SETTLE_SECONDS
            + DrumStep.STALL_MAX_SECONDS
            + RevealBeat.TAPE_DELAY_SECONDS
        expect(stalledCeremony > 7).toBe(true)
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
