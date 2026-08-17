--!strict
local harness = require("./harness")
local M = require("../src/shared/StatsBoardModel")
local FlapScheduler = require("../src/shared/FlapScheduler")
local StatsRoomLayout = require("../src/shared/StatsRoomLayout")
local StatsFixtures = require("../src/shared/StatsFixtures")
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

    -- THIS TEST USED TO ASSERT THE GLYPH FITS BOTH AXES, AND THAT IS WHAT BROKE THE SIZING.
    -- Vertical overflow is a real cut -- ClipsDescendants is on -- so height must bound the
    -- glyph. Horizontal is different: a letter's drawn advance is only about half its point
    -- size, so a glyph slightly wider than its cell still renders whole. The gate-tuned
    -- jumbotron ran at 103% of cell width deliberately. Demanding it fit the width forced the
    -- glyph down to ~80% of the size it should be on every taller-than-wide board.
    test("the glyph never overflows its cell HEIGHT", function()
        for _, case in { { 10, 26, 16 / 9 }, { 7, 16, 1.0 }, { 1, 16, 38 / 2.4 }, { 8, 22, 12 / 7 } } do
            local m = M.metrics(case[1], case[2], case[3])
            expect(m.glyphSize <= m.canvasH / case[1]).toBeTruthy()
        end
    end)

    -- A letter's DRAWN advance is only about half its point size, so a glyph sized wider than
    -- its cell still renders whole -- the gate-tuned jumbotron ran at 1.03 on purpose. The
    -- ceiling exists to stop an absurd size clipping, not to keep the glyph inside the cell.
    test("the glyph may exceed its cell WIDTH, up to the stated ceiling", function()
        for _, case in { { 10, 26, 16 / 9 }, { 7, 16, 1.0 }, { 8, 22, 12 / 7 } } do
            local m = M.metrics(case[1], case[2], case[3])
            expect(m.glyphSize <= (m.canvasW / case[2]) * 1.401).toBeTruthy()
        end
    end)

    -- READS THE REAL BOARD, deliberately. This test first hardcoded `M.metrics(8, 22, 12 / 7)`
    -- and broke the moment the board's height changed -- it was asserting against a copy of the
    -- layout, not the layout. Anything that pins a specific glyph size has to source its
    -- dimensions from StatsRoomLayout or it is testing a number nobody maintains.
    test("a board with room for it gets essentially the full 90px cap", function()
        local skill
        for _, b in StatsRoomLayout.BOARDS do
            if b.id == "skill" then
                skill = b
            end
        end
        -- 89, not 90: the height rule lands on 89.7 and floors. The point of the assertion is
        -- that nothing CLAMPS it well below the cap, not that it hits an exact integer.
        expect(M.metrics(skill.rows, skill.cols, skill.w / skill.h).glyphSize >= 89).toBeTruthy()
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

    -- FIX 6: at launch there is no tape yet. Before the fix this fell into the `lines` branch's
    -- no-empty-path and rendered "LAST 0 WORLD THROWS" over a blank row — §8 says no display is
    -- dark at launch, and a labelled blank row reads as broken rather than empty.
    test("the empty form guide says so, not '...0 WORLD THROWS' over a blank row", function()
        local s = M.worldSections({}, nil)
        expect(s[1].lines[1]).toBe("NO DATA YET")
        expect(s[1].title:find("0", 1, true)).toBe(nil)
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

-- FIX 1: StatsBoardModel picks titles and StatsRoomLayout picks column counts, and nothing ever
-- multiplied them together — three shipped boards truncated a title mid-word. This pins the two
-- modules to each other: every real board, at its real rows/cols, composing the real adapter's
-- real fixture payload, must not truncate its title line(s).
describe("StatsBoardModel.summarySections", function()
    local function figures(sections)
        local out = {}
        for _, sec in sections do
            for _, e in sec.entries or {} do
                table.insert(out, `{e.name}={e.figure}`)
            end
        end
        return table.concat(out, " ")
    end

    test("reads the LAST CLOSED round, and says so", function()
        local s = M.summarySections({
            { totalPlayers = 42, distribution = { R = 19, P = 12, S = 11 } },
            { totalPlayers = 9, distribution = { R = 9, P = 0, S = 0 } },
        })
        expect(s[1].title).toBe("LAST ROUND")
        expect(figures(s)).toBe("PLAYERS=42 ROCK=45% PAPER=29% SCISSORS=26%")
    end)

    test("percentages are of THROWS, not of players present", function()
        -- 42 present, 10 threw. Rock's share is 5/10, not 5/42.
        local s = M.summarySections({ { totalPlayers = 42, distribution = { R = 5, P = 3, S = 2 } } })
        expect(figures(s)).toBe("PLAYERS=42 ROCK=50% PAPER=30% SCISSORS=20%")
    end)

    test("a settled round where nobody threw shows a dash, not a division by zero", function()
        local s = M.summarySections({ { totalPlayers = 3, distribution = { R = 0, P = 0, S = 0 } } })
        expect(figures(s)).toBe("PLAYERS=3 ROCK=- PAPER=- SCISSORS=-")
    end)

    test("an empty tape says so rather than rendering a dark row", function()
        local lines = M.compose(M.summarySections({}), { rows = 7, cols = 16 })
        expect(lines[2]).toBe("NO DATA YET     ")
    end)

    test("is label:value like the slip it faces, never numbered", function()
        local s = M.summarySections({ { totalPlayers = 1, distribution = { R = 1, P = 0, S = 0 } } })
        expect(s[1].numbered).toBe(false)
        local lines = M.compose(s, { rows = 7, cols = 16 })
        expect(lines[2]:sub(1, 3)).toBe("PLA")
    end)
end)

describe("StatsBoardModel titles fit their real StatsRoomLayout boards", function()
    -- Mirrors StatsController.client.luau's `linesFor` id -> adapter dispatch. `skillFuture` is
    -- shuttered, and the `round*` parts belong to RoundDisplayController — they render a clock
    -- and a glyph, not sections with titles, so this module has no adapter for them by design.
    local function sectionsFor(id: string): { M.Section }?
        local S, P = StatsFixtures.STATS, StatsFixtures.PERSONAL
        if id == "banzuke" then
            return M.standingsSections(S.leaders)
        elseif id == "skill" then
            return M.skillSections(S.recordsWeek, S.recordsAll)
        elseif id == "judgement" then
            return M.judgementSections(S.recordsWeek)
        elseif id == "world" then
            return M.worldSections(S.tape, S.heat)
        elseif id == "fuda" then
            return M.fudaSections(P)
        elseif id == "summary" then
            return M.summarySections(S.tape)
        end
        return nil
    end

    local function trimRight(s: string): string
        return (s:gsub("%s+$", ""))
    end

    for _, b in StatsRoomLayout.BOARDS do
        if b.id:sub(1, 5) ~= "round" and not b.shuttered then
            test(`{b.id} (cols={b.cols}): title line(s) are not truncated`, function()
                local sections = sectionsFor(b.id)
                expect(sections ~= nil).toBeTruthy()
                if sections then
                    for _, sec in sections do
                        local lines = M.compose({ sec }, { rows = b.rows, cols = b.cols })
                        local want = trimRight(M.sanitize(sec.title))
                        expect(trimRight(lines[1])).toBe(want)
                    end
                end
            end)
        end
    end
end)

-- FIX 2: `fudaSections` used to return `entries`, so `compose` numbered the rows and the "N. "
-- rank prefix ate 3 of the fuda board's 16 columns — "BEST STREAK" rendered as "BEST STREA".
describe("StatsBoardModel.fudaSections (FIX 2)", function()
    local FUDA = { rows = 7, cols = 16 }

    test("all four labels survive the fuda board's real 16 cols intact", function()
        local lines = M.compose(M.fudaSections(StatsFixtures.PERSONAL), FUDA)
        local joined = table.concat(lines, "\n")
        for _, label in { "BANKED", "BEST STREAK", "STREAK NOW", "THROWS" } do
            expect(joined:find(label, 1, true) ~= nil).toBeTruthy()
        end
    end)

    test("BEST STREAK specifically — the row the rank prefix used to truncate", function()
        local lines = M.compose(M.fudaSections(StatsFixtures.PERSONAL), FUDA)
        expect(lines[3]).toBe("BEST STREAK   11")
    end)

    test("rows are label-then-value, not numbered", function()
        local lines = M.compose(M.fudaSections(StatsFixtures.PERSONAL), FUDA)
        expect(lines[2]).toBe("BANKED    12,480")
    end)
end)

describe("StatsBoardModel drum parity", function()
    test("the model's drum copy matches FlapScheduler's, or cells land on wrong glyphs", function()
        expect(M.DRUM).toBe(FlapScheduler.DRUM)
    end)
end)
