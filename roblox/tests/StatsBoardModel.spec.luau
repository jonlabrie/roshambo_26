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
    -- THE INK IS WHAT MUST FIT, NOT THE TEXTSIZE. A capital draws at about INK_RATIO of its
    -- TextSize, so a glyphSize slightly taller than the cell is correct and clips nothing. This
    -- test used to demand glyphSize <= cellH, which is a stricter rule than the renderer needs
    -- and would have blocked the owner's last two size increases on a false constraint.
    test("the drawn ink never overflows its cell height", function()
        for _, case in { { 10, 26, 16 / 9 }, { 7, 16, 1.0 }, { 1, 16, 38 / 2.4 }, { 8, 22, 12 / 7 } } do
            local m = M.metrics(case[1], case[2], case[3])
            expect(m.glyphSize * M.INK_RATIO <= m.canvasH / case[1]).toBeTruthy()
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

    -- THE GLYPH ROW HAS MOVED to the round display's tape -- ten real flaps beside the timer
    -- (owner, 2026-08-17). What is left here is heat, and these pin that the row did not merely
    -- get emptied: two surfaces showing the same ten throws would disagree for the ~3.45s the
    -- drum takes to settle, since one is gated on it and the other is not.
    test("the form guide is heat alone; the throw row is gone", function()
        local s = M.worldSections({ { worldThrow = "R" }, { worldThrow = "S" } }, nil)
        expect(#s).toBe(1)
        expect(s[1].title:find("HOT", 1, true) ~= nil).toBeTruthy()
    end)

    test("a tape passed in cannot resurrect a throw row", function()
        local withTape = M.worldSections({ { worldThrow = "R" } }, nil)
        local without = M.worldSections(nil, nil)
        expect(#withTape).toBe(#without)
        expect(withTape[1].title).toBe(without[1].title)
    end)

    test("an empty heat board says so rather than rendering a dark row", function()
        local lines = M.compose(M.worldSections(nil, nil), { rows = 6, cols = 22 })
        expect(lines[2]).toBe("NO DATA YET           ")
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
        expect(figures(s)).toBe("= PLAYERS=42 = ROCK=45.2% PAPER=28.6% SCISSORS=26.2%")
    end)

    test("percentages are of THROWS, not of players present", function()
        -- 42 present, 10 threw. Rock's share is 5/10, not 5/42.
        local s = M.summarySections({ { totalPlayers = 42, distribution = { R = 5, P = 3, S = 2 } } })
        expect(figures(s)).toBe("= PLAYERS=42 = ROCK=50.0% PAPER=30.0% SCISSORS=20.0%")
    end)

    test("a settled round where nobody threw shows a dash, not a division by zero", function()
        local s = M.summarySections({ { totalPlayers = 3, distribution = { R = 0, P = 0, S = 0 } } })
        expect(figures(s)).toBe("= PLAYERS=3 = ROCK=- PAPER=- SCISSORS=-")
    end)

    test("an empty tape says so rather than rendering a dark row", function()
        local lines = M.compose(M.summarySections({}), { rows = 7, cols = 16 })
        expect(lines[2]).toBe("NO DATA YET     ")
    end)

    test("is label:value like the slip it faces, never numbered", function()
        local s = M.summarySections({ { totalPlayers = 1, distribution = { R = 1, P = 0, S = 0 } } })
        expect(s[1].numbered).toBe(false)
        -- Line 2 is now a deliberate blank (owner, 2026-08-18), so assert the SHAPE of the
        -- PLAYERS row wherever it lands rather than pinning it to an index and a width.
        local lines = M.compose(s, { rows = 8, cols = 18 })
        local players = nil
        for _, l in lines do
            if string.find(l, "PLAYERS", 1, true) then
                players = l
            end
        end
        expect(players ~= nil).toBeTruthy()
        if players then
            -- label hard left, figure hard right, no "1. " rank prefix
            expect(string.sub(players, 1, 7)).toBe("PLAYERS")
            expect(string.match(players, "1%s*$") ~= nil).toBe(true)
        end
    end)

    test("the round's throw rides the far right of the TOP line", function()
        -- Owner, 2026-08-17. The board already reports what the crowd threw; the World Throw
        -- itself is the fact the percentages are about, and it belongs on the title line where a
        -- reader looks first -- not buried in a fifth row.
        local s = M.summarySections({
            { totalPlayers = 42, worldThrow = "R", distribution = { R = 19, P = 12, S = 11 } },
        })
        expect(s[1].titleRight).toBe(M.GLYPH.R)
        local lines = M.compose(s, { rows = 7, cols = 16 })
        expect(lines[1]).toBe("LAST ROUND     " .. M.GLYPH.R)
    end)

    test("every throw gets its own glyph, and nothing else does", function()
        for sym, glyph in M.GLYPH do
            local s = M.summarySections({ { totalPlayers = 1, worldThrow = sym, distribution = {} } })
            expect(s[1].titleRight).toBe(glyph)
        end
        local unknown = M.summarySections({ { totalPlayers = 1, worldThrow = "X", distribution = {} } })
        expect(unknown[1].titleRight).toBe(nil)
    end)

    test("a round with no throw recorded leaves the title line alone", function()
        -- A settled round always has one, but the tape is external data and the title must not
        -- sprout a stray column because a field went missing.
        local s = M.summarySections({ { totalPlayers = 3, distribution = { R = 1, P = 1, S = 1 } } })
        expect(s[1].titleRight).toBe(nil)
        local lines = M.compose(s, { rows = 7, cols = 16 })
        expect(lines[1]).toBe("LAST ROUND      ")
    end)

    test("an empty tape has no throw to show", function()
        expect(M.summarySections({})[1].titleRight).toBe(nil)
    end)
end)

describe("StatsBoardModel.compose — titleRight", function()
    test("it sits hard right on the title line, past the sanitizer", function()
        -- The glyphs are multibyte and `sanitize` is byte-wise (it has to be: a display name is
        -- external input and utf8.codes does not survive malformed bytes), so a glyph put in the
        -- title itself would come out as dots. titleRight is joined AFTER sanitizing.
        local lines = M.compose({ { title = "LAST ROUND", entries = {}, titleRight = M.GLYPH.S } }, {
            rows = 3,
            cols = 16,
        })
        expect(lines[1]).toBe("LAST ROUND     " .. M.GLYPH.S)
    end)

    test("a long title is cut to make room rather than pushing the glyph off", function()
        local lines = M.compose(
            { { title = "A VERY LONG TITLE INDEED", entries = {}, titleRight = M.GLYPH.P } },
            { rows = 2, cols = 12 }
        )
        expect(lines[1]).toBe("A VERY LONG" .. M.GLYPH.P)
    end)

    test("no titleRight leaves the line exactly as it was", function()
        local lines = M.compose({ { title = "LAST ROUND", entries = {} } }, { rows = 2, cols = 16 })
        expect(lines[1]).toBe("LAST ROUND      ")
    end)
end)

describe("StatsBoardModel titles fit their real StatsRoomLayout boards", function()
    -- Mirrors StatsController.client.luau's `linesFor` id -> adapter dispatch, and must keep
    -- mirroring it: this is what caught `skillFuture` opening without an adapter. The `round*`
    -- parts belong to RoundDisplayController — they render a clock and a glyph, not sections
    -- with titles, so this module has no adapter for them by design.
    local function sectionsFor(id: string): { M.Section }?
        local S, P = StatsFixtures.STATS, StatsFixtures.PERSONAL
        if id == "banzuke" then
            return M.banzukeSections(S.board, S.leaders)
        elseif id == "skillFuture" then
            return M.depthSections(S.depths)
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

    -- CONTENT FITS, not just titles. `compose` truncates to `rows` SILENTLY, so a section list
    -- that outgrows its board loses its last lines with no error and no warning — and the lines
    -- it loses are the ones most recently added, which are the ones someone is looking for.
    -- Caught exactly that on 2026-08-18: `fuda` is 7 rows, the slip had grown to 9 lines, and
    -- `RANK` (added that day, at the owner's request) fell off the bottom. The title-fit test
    -- beside this one passed throughout, because the TITLE was fine.
    for _, b in StatsRoomLayout.BOARDS do
        if b.id:sub(1, 5) ~= "round" then
            test(`{b.id} ({b.rows} rows): every line it composes actually fits`, function()
                local sections = sectionsFor(b.id)
                expect(sections ~= nil).toBeTruthy()
                if sections then
                    local wanted = 0
                    for _, sec in sections do
                        wanted += 1 + #(sec.entries or {})
                    end
                    if wanted > b.rows then
                        error(
                            `{b.id} composes {wanted} lines onto a {b.rows}-row board — `
                                .. `{wanted - b.rows} would be silently dropped`
                        )
                    end
                end
            end)
        end
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
                        local title = M.sanitize(sec.title)
                        local right = sec.titleRight or ""
                        -- The title survives whole, the glyph (where a section has one) rides the
                        -- far right, and there is nothing but spaces in between. Comparing the
                        -- trimmed line to the title outright would fail any titled section that
                        -- also carries a titleRight, which is not truncation.
                        expect(lines[1]:sub(1, #title)).toBe(title)
                        expect(lines[1]:sub(#lines[1] - #right + 1)).toBe(right)
                        expect(trimRight(lines[1]:sub(#title + 1, #lines[1] - #right))).toBe("")
                    end
                end
            end)
        end
    end
end)

-- FIX 2: `fudaSections` used to return `entries`, so `compose` numbered the rows and the "N. "
-- rank prefix ate 3 of the fuda board's columns — "BEST STREAK" rendered as "BEST STREA".
describe("StatsBoardModel.fudaSections (FIX 2)", function()
    local FUDA = { rows = 8, cols = 18 }

    test("all four labels survive the fuda board's real width intact", function()
        local lines = M.compose(M.fudaSections(StatsFixtures.PERSONAL), FUDA)
        local joined = table.concat(lines, "\n")
        for _, label in { "BANKED", "BEST STREAK", "CURRENT STREAK", "THROWS" } do
            expect(joined:find(label, 1, true) ~= nil).toBeTruthy()
        end
    end)

    test("BEST STREAK specifically — the row the rank prefix used to truncate", function()
        local lines = M.compose(M.fudaSections(StatsFixtures.PERSONAL), FUDA)
        -- Shape, not a pinned width: this row broke twice on a column-count change, which is
        -- what it was never meant to be testing. The defect it guards is the "N. " rank prefix
        -- eating the label, so assert the label survives whole and the figure is hard right.
        local row = nil
        for _, l in lines do
            if string.find(l, "BEST STREAK", 1, true) then
                row = l
            end
        end
        expect(row ~= nil).toBeTruthy()
        if row then
            expect(string.sub(row, 1, 11)).toBe("BEST STREAK")
            expect(string.match(row, "11%s*$") ~= nil).toBe(true)
        end
    end)

    test("rows are label-then-value, not numbered", function()
        local lines = M.compose(M.fudaSections(StatsFixtures.PERSONAL), FUDA)
        local row = nil
        for _, l in lines do
            if string.find(l, "BANKED", 1, true) then
                row = l
            end
        end
        expect(row ~= nil).toBeTruthy()
        if row then
            expect(string.sub(row, 1, 6)).toBe("BANKED")
            expect(string.match(row, "12,480%s*$") ~= nil).toBe(true)
        end
    end)
end)

describe("StatsBoardModel drum parity", function()
    test("the model's drum copy matches FlapScheduler's, or cells land on wrong glyphs", function()
        expect(M.DRUM).toBe(FlapScheduler.DRUM)
    end)
end)

describe("banzukeSections", function()
    local BOARD = {
        minThrows = 360,
        worldIsCrowd = true,
        rows = {
            { displayName = "AYAKA", pointsPerThrow = 2.41, winRate = 0.41, throws = 512 },
            { displayName = "KENJI", pointsPerThrow = 0.98, winRate = 0.36, throws = 402 },
        },
    }
    local O = { rows = 10, cols = 26 }
    local function blockOf(board, leaders)
        return table.concat(M.compose(M.banzukeSections(board, leaders), O), "\n")
    end

    test("ranks by yield with the read beside it", function()
        local all = blockOf(BOARD, nil)
        for _, want in { "AYAKA", "2.4", "41%", "KENJI" } do
            expect(string.find(all, want, 1, true) ~= nil).toBe(true)
        end
    end)

    test("prints the baseline, because a bare 41% means nothing to a first-time reader", function()
        expect(string.find(blockOf(BOARD, nil), "33 IN 100", 1, true) ~= nil).toBe(true)
    end)

    test("drops the baseline line with the column it explains", function()
        local closed = { minThrows = 360, worldIsCrowd = false, rows = { BOARD.rows[1] } }
        expect(string.find(blockOf(closed, nil), "33 IN 100", 1, true) == nil).toBe(true)
    end)

    test("withholds the read column entirely when the world is a test cycle", function()
        local closed = { minThrows = 360, worldIsCrowd = false, rows = { BOARD.rows[1] } }
        expect(string.find(blockOf(closed, nil), "%%") == nil).toBe(true)
    end)

    test("the baseline is a bare line, not a section that reports NO DATA YET", function()
        -- `compose` pushes "NO DATA YET" for a section with an empty `entries` list, so the
        -- baseline has to carry `lines = {}` instead. Caught in Studio 2026-08-18.
        expect(string.find(blockOf(BOARD, nil), "NO DATA YET", 1, true) == nil).toBe(true)
    end)

    test("the rule survives a full career list — it leads, so it cannot be truncated away", function()
        -- The fallback used to put the rule AFTER the standings. `topByCareer` fetches 50 and
        -- the board is 10 rows, so the line the owner most needed to see was the one guaranteed
        -- to fall off the bottom. This is the regression test for that.
        local many = {}
        for i = 1, 50 do
            table.insert(many, { displayName = `PLAYER{i}`, lifetimeBanked = 1000 - i })
        end
        local all = blockOf({ minThrows = 360, worldIsCrowd = true, rows = {} }, many)
        expect(string.find(all, "360 THROWS PUTS YOU HERE", 1, true) ~= nil).toBe(true)
        expect(string.find(all, "CAREER BANKED", 1, true) ~= nil).toBe(true)
    end)

    test("falls back to career standings, naming the rule, when nobody qualifies", function()
        local empty = { minThrows = 360, worldIsCrowd = true, rows = {} }
        local all = blockOf(empty, { { displayName = "AYAKA", lifetimeBanked = 12480 } })
        expect(string.find(all, "360", 1, true) ~= nil).toBe(true)
        expect(string.find(all, "AYAKA", 1, true) ~= nil).toBe(true)
    end)

    test("survives a nil board entirely — the room renders before the first poll lands", function()
        expect(#M.compose(M.banzukeSections(nil, nil), O)).toBe(10)
    end)
end)

describe("fudaSections standing", function()
    local O = { rows = 10, cols = 16 }
    test("shows where you stand among the qualified", function()
        local p = {
            displayName = "AYAKA",
            career = {},
            week = { throws = 400, minThrows = 360, qualified = true, standing = { rank = 14, of = 22 } },
        }
        local all = table.concat(M.compose(M.fudaSections(p), O), "\n")
        expect(string.find(all, "14 OF 22", 1, true) ~= nil).toBe(true)
    end)

    test("a player short of the floor gets a dash, not a rank of zero", function()
        local p = {
            displayName = "AYAKA",
            career = {},
            week = { throws = 142, minThrows = 360, qualified = false },
        }
        local all = table.concat(M.compose(M.fudaSections(p), O), "\n")
        expect(string.find(all, " 0 OF ", 1, true) == nil).toBe(true)
    end)
end)

describe("summarySections spacing and precision", function()
    local O = { rows = 8, cols = 18 }
    -- 332/336/332 of 1000: two throws tied at 33.2% and the winner clear of them by four
    -- tenths. At whole percents this prints 33 / 34 / 33 and the tie disappears.
    local TAPE = { { worldThrow = "P", totalPlayers = 1000, distribution = { R = 332, P = 336, S = 332 } } }

    test("reads a tenth of a percent, because 33 and 33 and 33 hides which one won", function()
        local all = table.concat(M.compose(M.summarySections(TAPE), O), "\n")
        expect(string.find(all, "33.2%", 1, true) ~= nil).toBe(true)
    end)

    test("breathes: a blank under the title and another under PLAYERS", function()
        local lines = M.compose(M.summarySections(TAPE), O)
        local function blank(l: string): boolean
            return string.match(l, "^%s*$") ~= nil
        end
        expect(blank(lines[2])).toBe(true)
        expect(string.find(lines[3], "PLAYERS", 1, true) ~= nil).toBe(true)
        expect(blank(lines[4])).toBe(true)
        expect(string.find(lines[5], "ROCK", 1, true) ~= nil).toBe(true)
    end)
end)

describe("fudaSections content", function()
    local O = { rows = 8, cols = 18 }
    local P = {
        displayName = "AYAKA",
        career = { banked = 12480, bestStreak = 11 },
        currentStreak = 11,
        week = {
            throws = 412,
            minThrows = 360,
            qualified = true,
            winRate = 0.41,
            pointsPerThrow = 2.41,
            nerve = 3,
            standing = { rank = 14, of = 22 },
        },
    }

    test("says POINTS/THROW, not the ambiguous PER THROW", function()
        local all = table.concat(M.compose(M.fudaSections(P), O), "\n")
        expect(string.find(all, "POINTS/THROW", 1, true) ~= nil).toBe(true)
    end)

    test("says CURRENT STREAK, and a two-digit streak still fits", function()
        local lines = M.compose(M.fudaSections(P), O)
        local found = nil
        for _, l in lines do
            if string.find(l, "CURRENT STREAK", 1, true) then
                found = l
            end
        end
        expect(found ~= nil).toBe(true)
        if found then
            expect(#found <= O.cols).toBe(true)
            expect(string.find(found, "11", 1, true) ~= nil).toBe(true)
        end
    end)

    test("drops bank depth — dubious on a personal board (owner, 2026-08-18)", function()
        local all = table.concat(M.compose(M.fudaSections(P), O), "\n")
        expect(string.find(all, "BANK AT", 1, true) == nil).toBe(true)
    end)
end)

describe("depthSections", function()
    local O = { rows = 6, cols = 13 }
    test("renders a bar per depth, scaled to the largest bucket", function()
        local lines = M.compose(M.depthSections({ 4, 8, 2, 0, 0, 0, 0, 0 }), O)
        expect(#lines).toBe(6)
        local function hashes(l: string): number
            return #(string.gsub(l, "[^#]", ""))
        end
        expect(hashes(lines[3]) >= hashes(lines[2])).toBe(true)
    end)

    test("an empty room renders without dividing by zero", function()
        expect(#M.compose(M.depthSections({ 0, 0, 0 }), O)).toBe(6)
    end)
end)
