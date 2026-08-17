--!strict
local harness = require("./harness")
local B = require("../src/shared/RoundBandModel")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function width(s: string): number
    local n = 0
    for _ in utf8.codes(s) do
        n += 1
    end
    return n
end

describe("RoundBandModel.line", function()
    test("is always exactly cols wide, whatever the state", function()
        local states = {
            {},
            { phase = "OPEN", secondsLeft = 34, ownThrow = "R" },
            { phase = "LOCK", secondsLeft = 1 },
            { phase = "REVEAL", worldThrow = "S", worldRested = true, ownThrow = "P" },
            { phase = "NONSENSE", secondsLeft = -5 },
        }
        for _, s in states do
            expect(width(B.line(s, 16))).toBe(16)
        end
    end)

    test("counts the phase down and shows your own throw", function()
        expect(B.line({ phase = "OPEN", secondsLeft = 34, ownThrow = "R" }, 16)).toBe(
            "OPEN 34S   YOU \u{25CB}"
        )
    end)

    test("shows a dash when you have not thrown, so an unthrown round is visible at a glance", function()
        expect(B.line({ phase = "OPEN", secondsLeft = 9 }, 16)).toBe("OPEN 9S    YOU -")
    end)

    test("NEVER names the world throw before the drum is at rest", function()
        local early = B.line({ phase = "REVEAL", worldThrow = "S", worldRested = false, ownThrow = "P" }, 16)
        -- plain find: the glyph is multibyte and would otherwise be read as a pattern
        expect(early:find("\u{2227}", 1, true) == nil).toBeTruthy()
        expect(early).toBe("REVEAL     YOU \u{2500}")
    end)

    test("names it once the drum has rested", function()
        expect(B.line({ phase = "REVEAL", worldThrow = "S", worldRested = true, ownThrow = "P" }, 16)).toBe(
            "WORLD \u{2227}    YOU \u{2500}"
        )
    end)

    test("clamps the countdown rather than overrunning the field", function()
        expect(B.line({ phase = "OPEN", secondsLeft = 4000 }, 16)).toBe("OPEN 99S   YOU -")
        expect(B.line({ phase = "OPEN", secondsLeft = -3 }, 16)).toBe("OPEN 0S    YOU -")
    end)

    test("with no schedule yet it says so instead of printing a false countdown", function()
        expect(B.line({}, 16)).toBe("WAITING    YOU -")
    end)
end)
