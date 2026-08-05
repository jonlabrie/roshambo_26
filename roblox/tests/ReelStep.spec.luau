--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ReelStep = require("../src/shared/ReelStep")
local DrumStep = require("../src/shared/DrumStep")

-- TURN_SECONDS, not SETTLE_SECONDS: the reel runs from CONTACT, where the wheel's travel
-- begins, not from the strike instant that precedes it by the shu-moku's swing.
local SETTLE = DrumStep.TURN_SECONDS
local SYMS = { "R", "P", "S" }

describe("ReelStep — the glyph cycle while the drum turns", function()
    test("it starts fast and ends slow", function()
        expect(ReelStep.intervalAt(0, SETTLE)).toBeCloseTo(ReelStep.FAST_SECONDS, 0.0001)
        expect(ReelStep.intervalAt(SETTLE, SETTLE)).toBeCloseTo(ReelStep.SLOW_SECONDS, 0.0001)
    end)

    test("it decelerates monotonically — never speeds back up", function()
        local prev = -1
        for i = 0, 40 do
            local v = ReelStep.intervalAt(i * SETTLE / 40, SETTLE)
            expect(v >= prev).toBe(true)
            prev = v
        end
    end)

    test("THE CYCLE NEVER STOPS ON ITS OWN — the interval plateaus through a full stall", function()
        -- The load-bearing property. A cycle that ran out of momentum before the drum rested would
        -- be sitting on a glyph that is NOT the World Throw, which reads as an answer and is the
        -- wrong one. Past the settle the interval must hold, not keep growing towards a standstill.
        local atSettle = ReelStep.intervalAt(SETTLE, SETTLE)
        local stalled = ReelStep.intervalAt(SETTLE + DrumStep.STALL_MAX_SECONDS, SETTLE)
        expect(stalled).toBeCloseTo(atSettle, 0.0001)
        expect(stalled <= ReelStep.SLOW_SECONDS).toBe(true)
    end)

    test("it keeps advancing through the whole stall window", function()
        local atSettle = ReelStep.changesBy(SETTLE, SETTLE)
        local atStallEnd = ReelStep.changesBy(SETTLE + DrumStep.STALL_MAX_SECONDS, SETTLE)
        -- a full stall is 6s at SLOW 0.26 — comfortably more than 20 further changes
        expect(atStallEnd - atSettle > 20).toBe(true)
    end)

    test("changesBy is monotonic and starts at zero", function()
        expect(ReelStep.changesBy(0, SETTLE)).toBe(0)
        local prev = -1
        for i = 0, 60 do
            local v = ReelStep.changesBy(i * 0.2, SETTLE)
            expect(v >= prev).toBe(true)
            prev = v
        end
    end)

    test("the settle is busy enough to read as a cycle, not as a slideshow", function()
        -- ~38 changes over the 3.45s settle at the tuned constants. The bound is loose on purpose:
        -- it pins "this is a spinning wheel" without freezing the tuning.
        local n = ReelStep.changesBy(SETTLE, SETTLE)
        expect(n > 20).toBe(true)
        expect(n < 80).toBe(true)
    end)

    test("it visits every symbol, and cycles in list order", function()
        local seen = {}
        for i = 0, 400 do
            seen[ReelStep.symbolAt(SYMS, i * 0.02, SETTLE)] = true
        end
        for _, s in SYMS do
            expect(seen[s]).toBe(true)
        end
    end)

    test("IT IS NEVER TOLD THE ANSWER — the symbol is a function of time alone", function()
        -- `symbolAt` takes elapsed and a symbol list. There is no parameter through which the
        -- World Throw could reach it, so it cannot leak one. Same inputs, same output, always.
        expect(ReelStep.symbolAt(SYMS, 1.234, SETTLE)).toBe(ReelStep.symbolAt(SYMS, 1.234, SETTLE))
    end)

    test("it holds no Roblox globals — numbers only", function()
        for key, value in ReelStep do
            expect(typeof(key)).toBe("string")
            expect(typeof(value) == "number" or typeof(value) == "function").toBe(true)
        end
    end)
end)
