--!strict
local harness = require("./harness")
local M = require("../src/shared/StatsBoardModel")
local FlapScheduler = require("../src/shared/FlapScheduler")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function width(s: string): number
    local n = 0
    for _ in utf8.codes(s) do
        n += 1
    end
    return n
end

describe("StatsBoardModel.sanitize", function()
    test("uppercases, because the flap drum has no lowercase", function()
        expect(M.sanitize("Ayaka")).toBe("AYAKA")
    end)

    test("replaces off-drum characters with a single dot, never a run", function()
        -- A 3-byte kanji must not become three dots.
        expect(M.sanitize("ken\u{7530}shi")).toBe("KEN.SHI")
    end)

    test("keeps the punctuation the drum actually carries", function()
        expect(M.sanitize("a-b:c/d")).toBe("A-B:C/D")
    end)

    test("a name with nothing renderable in it becomes ANON, not blanks", function()
        expect(M.sanitize("\u{7530}\u{4E2D}")).toBe("ANON")
        expect(M.sanitize("")).toBe("ANON")
        expect(M.sanitize(nil)).toBe("ANON")
    end)
end)

describe("StatsBoardModel.figure", function()
    test("groups thousands with the drum's comma", function()
        expect(M.figure(1240)).toBe("1,240")
        expect(M.figure(1234567)).toBe("1,234,567")
    end)

    test("floors, and treats nil as zero rather than erroring", function()
        expect(M.figure(9.87)).toBe("9")
        expect(M.figure(nil)).toBe("0")
    end)
end)

describe("StatsBoardModel.compose", function()
    local O = { rows = 6, cols = 24 }

    test("every line is exactly cols wide", function()
        local lines = M.compose({
            { title = "CAREER BANKED", entries = { { name = "Ayaka", figure = "1,240" } } },
        }, O)
        expect(#lines).toBe(6)
        for _, l in lines do
            expect(width(l)).toBe(24)
        end
    end)

    test("numbers entries from 1 and right-aligns the figure to the last column", function()
        local lines = M.compose({
            { title = "T", entries = { { name = "Ayaka", figure = "1,240" } } },
        }, O)
        expect(lines[2]).toBe("1. AYAKA           1,240")
    end)

    test("an empty section says so rather than rendering as a dark row", function()
        local lines = M.compose({ { title = "T", entries = {} } }, O)
        expect(lines[2]).toBe("NO DATA YET             ")
    end)

    test("raw lines pass through fitted, without numbering", function()
        local lines = M.compose({ { title = "LAST 10", lines = { "\u{25CB} \u{2500} \u{2227}" } } }, O)
        expect(lines[2]).toBe("\u{25CB} \u{2500} \u{2227}                   ")
    end)

    test("stops at the row budget instead of overflowing the board", function()
        local many = {}
        for i = 1, 20 do
            table.insert(many, { name = "P" .. i, figure = tostring(i) })
        end
        local lines = M.compose({ { title = "T", entries = many } }, { rows = 4, cols = 24 })
        expect(#lines).toBe(4)
    end)
end)

describe("StatsBoardModel.windowLabel", function()
    test("never emits a date — window=all's `to` bound is 24h in the future", function()
        expect(M.windowLabel("all", "rolling")).toBe("ALL TIME")
        expect(M.windowLabel("week", "calendar")).toBe("THIS WEEK")
        expect(M.windowLabel("week", "rolling")).toBe("LAST 7 DAYS")
        expect(M.windowLabel("day", "calendar")).toBe("TODAY")
        expect(M.windowLabel("day", "rolling")).toBe("LAST 24 HOURS")
        expect(M.windowLabel("hour", "rolling")).toBe("LAST HOUR")
    end)

    test("an unknown window is labelled, not blank", function()
        expect(M.windowLabel(nil, nil)).toBe("RECENT")
    end)
end)

describe("StatsBoardModel.metrics", function()
    test("canvas aspect matches the board so glyphs are not stretched", function()
        local m = M.metrics(10, 26, 16 / 9)
        expect(math.abs(m.canvasW / m.canvasH - 16 / 9) < 0.01).toBeTruthy()
    end)

    test("the glyph never exceeds the 100px engine cap", function()
        for _, case in { { 10, 26, 16 / 9 }, { 7, 16, 1.0 }, { 1, 16, 38 / 2.4 } } do
            local m = M.metrics(case[1], case[2], case[3])
            expect(m.glyphSize <= 90).toBeTruthy()
        end
    end)

    test("the glyph fits inside its cell on both axes, so ClipsDescendants never bites", function()
        local m = M.metrics(7, 16, 1.0)
        expect(m.glyphSize <= m.canvasW / 16).toBeTruthy()
        expect(m.glyphSize <= m.canvasH / 7).toBeTruthy()
    end)
end)

describe("StatsBoardModel adapters", function()
    test("standings rank by lifetimeBanked, the career figure the server sorts by", function()
        local s = M.standingsSections({
            { displayName = "spender", lifetimeBanked = 900 },
            { displayName = "hoarder", lifetimeBanked = 100 },
        })
        expect(s[1].entries[1].name).toBe("spender")
        expect(s[1].entries[1].figure).toBe("900")
    end)

    test("the form guide reads world throws newest-first as drum glyphs", function()
        local s = M.worldSections({ { worldThrow = "R" }, { worldThrow = "S" } }, nil)
        expect(s[1].lines[1]).toBe("\u{25CB} \u{2227}")
    end)

    test("a missing heat board is a section that says so, not an absent section", function()
        local s = M.worldSections({}, nil)
        expect(#s).toBe(2)
        expect(#s[2].entries).toBe(0)
    end)

    test("the personal slip shows progress toward qualification, never a blank", function()
        local s = M.fudaSections({
            displayName = "Ayaka",
            career = { banked = 1240, bestStreak = 6 },
            currentStreak = 2,
            week = { throws = 142, minThrows = 350, qualified = false },
        })
        local flat = {}
        for _, sec in s do
            for _, e in sec.entries or {} do
                table.insert(flat, e.figure)
            end
        end
        expect(table.concat(flat, "|"):find("142/350") ~= nil).toBeTruthy()
    end)
end)

describe("StatsBoardModel drum parity", function()
    test("the model's drum copy matches FlapScheduler's, or cells land on wrong glyphs", function()
        expect(M.DRUM).toBe(FlapScheduler.DRUM)
    end)
end)
