--!strict
local harness = require("./harness")
local M = require("../src/shared/RoundDisplayModel")
local FlapScheduler = require("../src/shared/FlapScheduler")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function steps(current: string, target: string, drum: string): number
    return #FlapScheduler.plan(current, target, { drum = drum, maxSteps = 99 })
end

describe("RoundDisplayModel.clock", function()
    test("reads as a clock, zero-padded", function()
        expect(M.clock({ phase = "OPEN", secondsLeft = 43 })).toBe("0:43")
        expect(M.clock({ phase = "OPEN", secondsLeft = 9 })).toBe("0:09")
        expect(M.clock({ phase = "OPEN", secondsLeft = 0 })).toBe("0:00")
    end)

    test("carries minutes, so the format is not a lie if rounds ever lengthen", function()
        expect(M.clock({ phase = "OPEN", secondsLeft = 60 })).toBe("1:00")
        expect(M.clock({ phase = "OPEN", secondsLeft = 125 })).toBe("2:05")
    end)

    -- Owner: "blank space is shown in the few seconds between rounds". LOCK + REVEAL is 9s.
    -- The colon stays: a bare colon reads as a clock at rest, four blanks read as broken.
    test("blanks the digits between rounds but keeps the colon", function()
        expect(M.clock({ phase = "LOCK", secondsLeft = 2 })).toBe(" :  ")
        expect(M.clock({ phase = "REVEAL", secondsLeft = 7 })).toBe(" :  ")
    end)

    test("blanks before any schedule has replicated, rather than printing a false 0:00", function()
        expect(M.clock({})).toBe(" :  ")
    end)

    test("clamps rather than overflowing its four columns", function()
        expect(M.clock({ phase = "OPEN", secondsLeft = 99999 })).toBe("9:59")
        expect(M.clock({ phase = "OPEN", secondsLeft = -5 })).toBe("0:00")
    end)
end)

-- THE OWNER'S RULING, PINNED (2026-08-17): "a drum that is only ever going to show digits
-- should only ever have digits on it. It's a different drum." Descending, so counting DOWN is
-- forward motion — the whole reason the alphanumeric drum was wrong here.
describe("RoundDisplayModel.DIGITS", function()
    test("counting down is a single step, which is the entire point", function()
        expect(steps("3", "2", M.DIGITS)).toBe(1)
        expect(steps("9", "8", M.DIGITS)).toBe(1)
    end)

    test("running out to blank, and blank back to 9, are each one step", function()
        expect(steps("0", " ", M.DIGITS)).toBe(1)
        expect(steps(" ", "9", M.DIGITS)).toBe(1)
    end)

    -- Unavoidable on a cyclic drum carrying a blank, and correct: a real board shows the flaps
    -- it passes through. Pinned so nobody "fixes" it by moving the blank and breaking the count.
    test("the ten-second rollover passes through the blank, and that is allowed", function()
        expect(steps("0", "9", M.DIGITS)).toBe(2)
    end)

    test("carries no letters at all", function()
        expect(M.DIGITS:match("^[0-9 ]+$") ~= nil).toBeTruthy()
    end)

    test("the colon drum can reach a colon from a blank cell", function()
        -- FlapBoard starts every cell blank; a single-character drum could never leave it.
        expect(steps(" ", ":", M.COLON)).toBe(1)
    end)

    test("assigns a drum per column: digit, colon, digit, digit", function()
        local d = M.drums()
        expect(#d).toBe(4)
        expect(d[1]).toBe(M.DIGITS)
        expect(d[2]).toBe(M.COLON)
        expect(d[3]).toBe(M.DIGITS)
        expect(d[4]).toBe(M.DIGITS)
    end)
end)

describe("RoundDisplayModel.throwState", function()
    -- Shows LAST round's throw until the countdown runs out, then turns until the drum lands it.
    test("holds the previous round's throw through OPEN", function()
        local s = M.throwState({ phase = "OPEN", previousThrow = "R" })
        expect(s.glyph).toBe("R")
        expect(s.spinning).toBe(false)
    end)

    test("turns from the moment the countdown expires", function()
        expect(M.throwState({ phase = "LOCK", previousThrow = "R" }).spinning).toBe(true)
        expect(M.throwState({ phase = "REVEAL", previousThrow = "R" }).spinning).toBe(true)
    end)

    -- THE DRUM RULE. Landing is not a timer: it is the drumRest cue and nothing else.
    test("keeps turning through REVEAL until the drum has rested", function()
        local s =
            M.throwState({ phase = "REVEAL", previousThrow = "R", worldThrow = "S", worldRested = false })
        expect(s.spinning).toBe(true)
        expect(s.glyph).toBe("R") -- still last round's, never the new one
    end)

    test("lands on the new throw once the drum rests", function()
        local s =
            M.throwState({ phase = "REVEAL", previousThrow = "R", worldThrow = "S", worldRested = true })
        expect(s.spinning).toBe(false)
        expect(s.glyph).toBe("S")
    end)

    test("shows blank when there is no previous round to show", function()
        expect(M.throwState({ phase = "OPEN" }).glyph).toBe(nil)
    end)
end)
