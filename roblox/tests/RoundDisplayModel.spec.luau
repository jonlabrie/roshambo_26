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

    -- FRACTIONS ARE THE ONLY VALUES THAT PIN THE ROUNDING, and every test here used whole
    -- seconds -- where floor and ceil agree -- so the wall could and did run a second ahead of
    -- the HUD's ring without a single test noticing.
    test("rounds UP, the way HudController's ring does", function()
        expect(M.clock({ phase = "OPEN", secondsLeft = 42.3 })).toBe("0:43")
        expect(M.clock({ phase = "OPEN", secondsLeft = 42.9 })).toBe("0:43")
        expect(M.clock({ phase = "OPEN", secondsLeft = 0.2 })).toBe("0:01")
    end)

    test("reads 0:00 only when the phase is genuinely spent", function()
        expect(M.clock({ phase = "OPEN", secondsLeft = 0 })).toBe("0:00")
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

    -- The colon is PAINTED between the digits, not mounted on a flap of its own. So column 2
    -- carries no drum at all -- the planner skips it, and it cannot be asked to turn.
    test("the digit columns get a drum and the colon column does not", function()
        local d = M.drums()
        expect(d[1]).toBe(M.DIGITS)
        expect(d[2]).toBe(nil)
        expect(d[3]).toBe(M.DIGITS)
        expect(d[4]).toBe(M.DIGITS)
    end)

    test("the colon is declared as a printed column instead", function()
        local st = M.statics()
        expect(st[2]).toBe(":")
        expect(st[1]).toBe(nil)
        expect(st[3]).toBe(nil)
        expect(st[4]).toBe(nil)
    end)
end)

local DrumStep = require("../src/shared/DrumStep")

-- The flipper must move in step with the HUD's ring, so these pin the SHAPE the ring has:
-- blank through LOCK and the swing, cycling from contact, stopping only on the drum.
describe("RoundDisplayModel.throwState", function()
    test("holds the previous round's throw through OPEN", function()
        local s = M.throwState({ phase = "OPEN", previousThrow = "R" })
        expect(s.glyph).toBe("R")
        expect(s.reeling).toBe(false)
    end)

    -- Owner: it "should go blank at the same time the round timer disappears in the HUD".
    test("goes blank the moment the countdown does, and stays blank through LOCK", function()
        local s = M.throwState({ phase = "LOCK", previousThrow = "R" })
        expect(s.glyph).toBe(nil)
        expect(s.reeling).toBe(false)
    end)

    -- The shu-moku's swing is 0.45s of REVEAL during which the wheel has not moved. The ring is
    -- black for it; so is this. Starting at REVEAL's edge would run 0.45s ahead of the drum, and
    -- starting at the end of OPEN -- which the first version did -- runs 2.45s ahead.
    test("stays blank through the swing, when contact is still in the future", function()
        local s = M.throwState({ phase = "REVEAL", previousThrow = "R", contactElapsed = -0.3 })
        expect(s.glyph).toBe(nil)
        expect(s.reeling).toBe(false)
    end)

    test("cycles from contact", function()
        local s = M.throwState({ phase = "REVEAL", previousThrow = "R", contactElapsed = 0.5 })
        expect(s.reeling).toBe(true)
        expect(s.glyph == "R" or s.glyph == "P" or s.glyph == "S").toBeTruthy()
    end)

    -- INHERITED FROM ReelStep AND LOAD-BEARING: a cycle that ran out before the drum rested would
    -- be sitting on a glyph that is not the World Throw -- an answer, and the wrong one.
    test("never stops cycling on its own, however long the drum takes", function()
        for _, t in { 3.0, 6.0, 12.0 } do
            expect(M.throwState({ phase = "REVEAL", contactElapsed = t }).reeling).toBe(true)
        end
    end)

    -- THE DRUM RULE. Landing is the drumRest cue and nothing else.
    test("keeps cycling through REVEAL until the drum has rested", function()
        local s = M.throwState({
            phase = "REVEAL",
            previousThrow = "R",
            worldThrow = "S",
            worldRested = false,
            contactElapsed = 1.0,
        })
        expect(s.reeling).toBe(true)
        expect(s.glyph ~= nil).toBeTruthy()
    end)

    test("lands on the new throw once the drum rests", function()
        local s = M.throwState({
            phase = "REVEAL",
            previousThrow = "R",
            worldThrow = "S",
            worldRested = true,
            contactElapsed = 2.0,
        })
        expect(s.reeling).toBe(false)
        expect(s.glyph).toBe("S")
    end)

    test("shows blank when there is no previous round to show", function()
        expect(M.throwState({ phase = "OPEN" }).glyph).toBe(nil)
    end)

    -- The cycling glyph is a function of elapsed time alone; it is never handed the answer, so it
    -- cannot leak one. Two different worldThrows must produce identical cycling output.
    test("cannot leak the answer while cycling", function()
        local a =
            M.throwState({ phase = "REVEAL", worldThrow = "R", worldRested = false, contactElapsed = 0.7 })
        local b =
            M.throwState({ phase = "REVEAL", worldThrow = "S", worldRested = false, contactElapsed = 0.7 })
        expect(a.glyph).toBe(b.glyph)
    end)

    test("paces against the wheel's travel, not the strike-to-rest window", function()
        -- TURN_SECONDS is contact-to-rest (3.0); SETTLE_SECONDS includes the 0.45 swing (3.45).
        expect(DrumStep.TURN_SECONDS < DrumStep.SETTLE_SECONDS).toBeTruthy()
        expect(DrumStep.TURN_SECONDS).toBe(DrumStep.SETTLE_SECONDS - DrumStep.STRIKE_SWING_SECONDS)
    end)
end)
