--!strict
local harness = require("./harness")
local FlapScheduler = require("../src/shared/FlapScheduler")
local describe, test, expect = harness.describe, harness.test, harness.expect

local OPTS = { stepMs = 100, staggerMs = 50 }

local function stepsFor(plan: { any }, col: number): { any }
    local out = {}
    for _, s in plan do
        if s.col == col then
            table.insert(out, s)
        end
    end
    table.sort(out, function(a, b)
        return a.atMs < b.atMs
    end)
    return out
end

describe("FlapScheduler", function()
    test("unchanged columns produce no steps", function()
        expect(#FlapScheduler.plan("AB", "AB", OPTS)).toBe(0)
    end)

    test("steps cycle the drum from current to target", function()
        -- drum order contains "...ABC..."; A->C is exactly 2 steps: B then C
        local plan = FlapScheduler.plan("A", "C", OPTS)
        local s = stepsFor(plan, 1)
        expect(#s).toBe(2)
        expect(s[1].char).toBe("B")
        expect(s[1].atMs).toBe(0)
        expect(s[1].isFinal).toBe(false)
        expect(s[2].char).toBe("C")
        expect(s[2].atMs).toBe(100)
        expect(s[2].isFinal).toBe(true)
    end)

    test("columns are staggered left to right", function()
        local plan = FlapScheduler.plan("AA", "BB", OPTS)
        expect(stepsFor(plan, 1)[1].atMs).toBe(0)
        expect(stepsFor(plan, 2)[1].atMs).toBe(50)
    end)

    test("wraps around the end of the drum", function()
        -- drum ends "...9,.!?+%○─∧" then wraps to leading space then A
        local plan = FlapScheduler.plan("∧", "A", OPTS)
        local s = stepsFor(plan, 1)
        expect(s[#s].char).toBe("A")
        expect(s[#s].isFinal).toBe(true)
        expect(#s).toBe(2) -- ∧ -> space -> A
    end)

    test("shorter strings are padded with spaces", function()
        local plan = FlapScheduler.plan("A", "AB", OPTS)
        -- col 1 unchanged; col 2 goes space -> ... -> B (space is drum position 1, A is 2, B is 3)
        local s = stepsFor(plan, 2)
        expect(#s).toBe(2)
        expect(s[#s].char).toBe("B")
    end)

    test("multibyte glyphs count as single columns", function()
        local plan = FlapScheduler.plan("○─∧", "○─○", OPTS)
        expect(#stepsFor(plan, 1)).toBe(0)
        expect(#stepsFor(plan, 2)).toBe(0)
        local s = stepsFor(plan, 3)
        expect(s[#s].char).toBe("○")
        expect(s[1].atMs).toBe(100) -- stagger: (3-1)*50ms
    end)

    test("the drum carries minus, colon and slash", function()
        for _, ch in { "-", ":", "/" } do
            local plan = FlapScheduler.plan(" ", ch, OPTS)
            local s = stepsFor(plan, 1)
            expect(#s > 0).toBe(true)
            expect(s[#s].char).toBe(ch)
            expect(s[#s].isFinal).toBe(true)
        end
    end)

    test("adding punctuation did not disturb the glyph block wrap", function()
        -- glyphs stay contiguous at the drum's end so the wrap to space is unchanged
        expect(#stepsFor(FlapScheduler.plan("\u{2227}", "A", OPTS), 1)).toBe(2)
    end)

    test("long transitions are capped so the cell never shows a long roll", function()
        -- A -> Z is 25 raw steps; the cap must shorten it
        local s = stepsFor(FlapScheduler.plan("A", "Z", OPTS), 1)
        expect(#s).toBe(9)
        expect(s[#s].char).toBe("Z")
        expect(s[#s].isFinal).toBe(true)
    end)

    test("a capped run is still contiguous on the drum, ending at the target", function()
        -- the cheat is a jump-in, not a shuffle: the shown chars are the last N before target
        local s = stepsFor(FlapScheduler.plan("A", "Z", OPTS), 1)
        expect(s[1].char).toBe("R") -- Z is index 27, 9 back is R (index 18) -> first shown is R
        expect(s[2].char).toBe("S")
        expect(s[1].atMs).toBe(0)
        expect(s[2].atMs).toBe(100)
    end)

    test("short transitions are untouched by the cap", function()
        expect(#stepsFor(FlapScheduler.plan("A", "C", OPTS), 1)).toBe(2)
    end)

    test("maxSteps is configurable", function()
        local s = stepsFor(FlapScheduler.plan("A", "Z", { stepMs = 100, staggerMs = 50, maxSteps = 3 }), 1)
        expect(#s).toBe(3)
        expect(s[#s].char).toBe("Z")
    end)
end)

-- ===== THE DRUM LADDER (owner, 2026-08-18) =====
-- The wall boards ran every cell on the 49-character drum, so ~82% of changed cells hit the
-- 9-step cap and rolled the alphabet to reach a digit. The clock's fix (a drum bolted per
-- COLUMN) does not transfer: a clock column has a fixed kind, a leaderboard column does not.
-- So the drum is chosen from the TRANSITION -- the smallest drum carrying both characters.
describe("FlapScheduler.drumFor", function()
    test("digit to digit takes the digits drum", function()
        expect(FlapScheduler.drumFor("7", "3")).toBe(FlapScheduler.DIGITS)
    end)

    test("on the digits drum the cap never fires, so a roll is honest end to end", function()
        -- Max distance on a 10-character drum is 9, which is the cap -- so no digit
        -- transition is ever truncated and jump-cut. 7 -> 3 is (3-7) mod 10 = 6.
        local s = stepsFor(
            FlapScheduler.plan("7", "3", { stepMs = 100, staggerMs = 50, drum = FlapScheduler.DIGITS }),
            1
        )
        expect(#s).toBe(6)
        expect(s[#s].char).toBe("3")
        for _, step in s do
            expect(string.find(FlapScheduler.DIGITS, step.char, 1, true) ~= nil).toBe(true)
        end
    end)

    test("a comma meeting a digit takes the figures drum, not the alphabet", function()
        -- 1,234 -> 12,345 walks the comma across a column; without this that one cell
        -- rolls letters mid-number beside neighbours that do not.
        expect(FlapScheduler.drumFor(",", "3")).toBe(FlapScheduler.FIGURES)
    end)

    test("percent, slash, minus and space are all on the figures drum", function()
        for _, ch in { "%", "/", "-", " " } do
            expect(FlapScheduler.drumFor(ch, "0")).toBe(FlapScheduler.FIGURES)
        end
    end)

    test("plus and period ride the figures drum as headroom", function()
        -- Owner's ruling: nothing prints these today; they are reserved so a signed delta
        -- or a decimal costs no digit motion when it arrives.
        expect(FlapScheduler.drumFor("+", "1")).toBe(FlapScheduler.FIGURES)
        expect(FlapScheduler.drumFor(".", "1")).toBe(FlapScheduler.FIGURES)
    end)

    test("a letter falls all the way to the full drum", function()
        expect(FlapScheduler.drumFor("A", "3")).toBe(FlapScheduler.DRUM)
        expect(FlapScheduler.drumFor("A", "B")).toBe(FlapScheduler.DRUM)
    end)

    test("a throw glyph falls to the full drum", function()
        expect(FlapScheduler.drumFor("○", " ")).toBe(FlapScheduler.DRUM)
    end)

    test("the ladder is ordered smallest-first, so digits never pay for punctuation", function()
        expect(#FlapScheduler.DIGITS < #FlapScheduler.FIGURES).toBe(true)
        expect(#FlapScheduler.FIGURES < #FlapScheduler.DRUM).toBe(true)
    end)

    test("every digits character is on the figures drum, and every figures character on the full", function()
        for _, code in utf8.codes(FlapScheduler.DIGITS) do
            expect(string.find(FlapScheduler.FIGURES, utf8.char(code), 1, true) ~= nil).toBe(true)
        end
        for _, code in utf8.codes(FlapScheduler.FIGURES) do
            expect(string.find(FlapScheduler.DRUM, utf8.char(code), 1, true) ~= nil).toBe(true)
        end
    end)
end)
