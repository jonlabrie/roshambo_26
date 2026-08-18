--!strict
-- Turns the /api/v1/stats payloads into fixed-width lines a split-flap board can land on.
-- Pure: no Roblox globals, no requires — it runs under Lune with everything else in shared.
--
-- WHY EVERY LINE IS EXACTLY `cols` WIDE. FlapScheduler.plan diffs the current line against the
-- target column by column; a shorter target leaves the tail columns holding the PREVIOUS line's
-- characters rather than clearing them. Padding here is what makes a board that shrinks its
-- content actually erase the old content.
local StatsBoardModel = {}

-- Mirrors FlapScheduler.DRUM. Deliberately a COPY, not a require: this module must stay
-- dependency-free, and the pair is pinned by a test in StatsBoardModel.spec.luau.
StatsBoardModel.DRUM = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.!?+%-:/○─∧"
StatsBoardModel.GLYPH = { R = "○", P = "─", S = "∧" }

export type Entry = { name: string?, figure: string }
-- `numbered` defaults to true (the leaderboard look: "1. AYAKA ... 1,240"). Set it false for a
-- section that lists a person's own rows, not a ranking — see `labelLine` (FIX 2).
-- `titleRight` is a raw string set hard right on the TITLE line and NOT sanitized -- it exists
-- for the throw glyphs, which are multibyte and would come back as dots from a sanitizer that
-- must stay byte-wise (display names are external input; utf8.codes does not survive malformed
-- bytes). Nothing external ever reaches it: the only caller picks from StatsBoardModel.GLYPH.
export type Section = {
    title: string,
    entries: { Entry }?,
    lines: { string }?,
    numbered: boolean?,
    titleRight: string?,
}
export type Opts = { rows: number, cols: number }

-- A DELIBERATE BLANK ROW. Not `{ name = "", figure = "" }`: that goes through `sanitize`, whose
-- fallback for a missing display name is the string "ANON", so an empty entry prints the word
-- ANON across the board. Compared by IDENTITY in `compose`, so no caller's real content can
-- collide with it.
StatsBoardModel.SPACER = { name = "", figure = "" }
export type Metrics = { canvasW: number, canvasH: number, glyphSize: number }

local ALLOWED: { [string]: boolean } = {}
for _, code in utf8.codes(StatsBoardModel.DRUM) do
    ALLOWED[utf8.char(code)] = true
end

-- A percentage as a whole number, or a BLANK when there is no figure -- never "-", which reads
-- as "zero percent" on a board where every other row carries a number. Named apart from
-- `summarySections`' own local `pct`, which answers a different question (percentage OF THROWS,
-- dash when nobody threw) and would otherwise shadow this one.
local function percentOrBlank(v: number?): string
    return if v == nil then "" else `{math.floor(v * 100 + 0.5)}%`
end

local function chars(s: string): { string }
    local out: { string } = {}
    for _, code in utf8.codes(s) do
        table.insert(out, utf8.char(code))
    end
    return out
end

local function widthOf(s: string): number
    return #chars(s)
end

local function trunc(s: string, n: number): string
    local c = chars(s)
    if #c <= n then
        return s
    end
    return table.concat(c, "", 1, math.max(0, n))
end

local function padRight(s: string, n: number): string
    local d = n - widthOf(s)
    return if d > 0 then s .. string.rep(" ", d) else trunc(s, n)
end

-- Byte-wise on purpose. A multibyte character is not renderable on the drum, so collapsing its
-- bytes to dots and then collapsing dot RUNS gives one dot per unrenderable character — which is
-- what a reader expects. Iterating codepoints instead would need utf8.codes to survive malformed
-- input from an external display name, and it does not.
function StatsBoardModel.sanitize(name: string?): string
    local raw = name or ""
    local out: { string } = {}
    for i = 1, #raw do
        local b = string.byte(raw, i) :: number
        local ch = if b < 128 then string.upper(string.char(b)) else "."
        table.insert(out, if ALLOWED[ch] then ch else ".")
    end
    local s = table.concat(out)
    s = (string.gsub(s, "%.%.+", "."))
    s = (string.gsub(s, "^[ .]+", ""))
    s = (string.gsub(s, "[ .]+$", ""))
    if s == "" then
        return "ANON"
    end
    return s
end

function StatsBoardModel.figure(n: number?): string
    local v = math.floor(tonumber(n) or 0)
    local sign = if v < 0 then "-" else ""
    local s = tostring(math.abs(v))
    while true do
        local next_, k = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
        s = next_
        if k == 0 then
            break
        end
    end
    return sign .. s
end

-- "1. AYAKA           1,240" — rank, name filling the slack, figure hard right.
local function entryLine(rank: number, e: Entry, cols: number): string
    local head = tostring(rank) .. "."
    local fig = trunc(e.figure, math.max(1, cols - 5))
    local nameW = math.max(1, cols - widthOf(head) - widthOf(fig) - 2)
    return padRight(`{head} {padRight(StatsBoardModel.sanitize(e.name), nameW)} {fig}`, cols)
end

-- "BANKED         12,480" — label, then figure hard right, no rank prefix. FIX 2: a numbered
-- entry ("1. BEST STREAK") eats 3 columns on the rank alone, which is why this exists instead of
-- reusing entryLine for a section that is a person's own stats rather than a leaderboard. Reuses
-- the same padRight/trunc/widthOf width math, computed against the REAL `cols` at compose time —
-- same reason entryLine takes `cols` as a parameter instead of a caller guessing a width.
local function labelLine(e: Entry, cols: number): string
    local fig = trunc(e.figure, math.max(1, cols - 1))
    local labelW = math.max(1, cols - widthOf(fig) - 1)
    return padRight(`{padRight(StatsBoardModel.sanitize(e.name or ""), labelW)} {fig}`, cols)
end

function StatsBoardModel.compose(sections: { Section }, o: Opts): { string }
    local lines: { string } = {}
    local function push(s: string)
        if #lines < o.rows then
            table.insert(lines, padRight(s, o.cols))
        end
    end
    for _, sec in sections do
        local title = StatsBoardModel.sanitize(sec.title)
        local right = sec.titleRight
        if right and right ~= "" then
            -- The title yields, not the glyph: a title cut short still reads, a glyph pushed off
            -- the end is simply absent. Same rule entryLine follows for a figure.
            local w = widthOf(right)
            title = padRight(trunc(title, math.max(0, o.cols - w)), math.max(0, o.cols - w)) .. right
        end
        push(title)
        if sec.lines then
            for _, l in sec.lines do
                push(l)
            end
        else
            local entries = sec.entries or {}
            if #entries == 0 then
                -- §8: no display is dark at launch. An empty board must SAY it is empty.
                push("NO DATA YET")
            elseif sec.numbered == false then
                for _, e in entries do
                    if e == StatsBoardModel.SPACER then
                        push("")
                    else
                        push(labelLine(e, o.cols))
                    end
                end
            else
                for i, e in entries do
                    push(entryLine(i, e, o.cols))
                end
            end
        end
    end
    while #lines < o.rows do
        table.insert(lines, string.rep(" ", o.cols))
    end
    return lines
end

-- NEVER derived from the payload's `from`/`to`. /records?window=all reports a `to` 24 hours in
-- the future (it is a rolling bound taken from `now`), so printing it would label the all-time
-- board as ending tomorrow.
function StatsBoardModel.windowLabel(window: string?, windowKind: string?): string
    local w, k = window or "", windowKind or ""
    if w == "all" then
        return "ALL TIME"
    elseif w == "week" then
        return if k == "calendar" then "THIS WEEK" else "LAST 7 DAYS"
    elseif w == "day" then
        return if k == "calendar" then "TODAY" else "LAST 24 HOURS"
    elseif w == "hour" then
        return "LAST HOUR"
    end
    return "RECENT"
end

-- A compact suffix for headings that must share a 22-col board with "LONGEST STREAK - " (17
-- cols, the tightest prefix that uses this). Still derived from window/windowKind, not a literal
-- that papers over what the payload actually says — `day` still distinguishes calendar/rolling.
function StatsBoardModel.shortWindowLabel(window: string?, windowKind: string?): string
    local w, k = window or "", windowKind or ""
    if w == "all" then
        return "ALL"
    elseif w == "week" then
        return "WEEK"
    elseif w == "day" then
        return if k == "calendar" then "TODAY" else "DAY"
    elseif w == "hour" then
        return "HOUR"
    end
    return "NOW"
end

-- THE 100px CAP, SOLVED ONCE. TextSize maxes at 100 and TextScaled will not scale up on a
-- SurfaceGui, so the canvas is sized SMALL enough that a ~90px glyph is already large relative
-- to a cell, and the SurfaceGui stretches it across the physical board. Canvas aspect is pinned
-- to the board's aspect or the stretch would distort the glyphs.
-- THESE ARE THE JUMBOTRON'S OWN NUMBERS, restored (2026-08-17). The first version of this
-- function invented its own rule -- size the glyph from `min(cellW, cellH) * 0.78` -- and on
-- boards whose cells are taller than they are wide that made the glyph about four-fifths the
-- size it should be, which then rode low in the cell because the tuned UIPadding is a
-- proportion of the TILE, not of the glyph. That is what the owner saw on the west wall.
--
-- The reference implementation (BoardController, gate-tuned 2026-06-07, now retired into
-- FlapBoard) sized from HEIGHT alone: 150 canvas-px per row, a flat 90px glyph, i.e. 60% of
-- cell height -- and let the glyph EXCEED the cell's width by 3%, which is safe because a
-- letter's drawn advance is only ~half its point size. Clamping to width was the mistake.
-- FLAP HEIGHT, RETUNED FOR JOSEFINSANS (owner, 2026-08-17): "the vertical size of the flaps is
-- wrong for this font, they need to be shorter by about 20%". JosefinSans is geometric with a
-- small x-height, so its caps leave more air in a cell than Merriweather's did and the flap read
-- as too tall.
--
-- The two numbers move TOGETHER with the 20% board-height cut in StatsRoomLayout, and that is the
-- whole point: 150 -> 120 canvas px per row is the same 20%, and 0.60 -> 0.75 puts the same 90px
-- glyph in the shorter cell. Net effect on the wall: the flap loses a fifth of its height and the
-- LETTER DOES NOT CHANGE SIZE AT ALL. Canvas width is unaffected too -- shrinking board height
-- raises the aspect by the reciprocal, so `canvasH * aspect` comes out identical.
-- Change one of the three without the others and the letters resize.
-- Sized so the INK lands at ~85% of the cell (owner, 2026-08-17). Working backwards through
-- INK_RATIO: 0.85 / 0.72 = 1.18 of TextSize, and 90 / 1.18 gives the canvas row.
local ROW_PX = 75 -- canvas px per row
local GLYPH_OF_HEIGHT = 1.2 -- 90/75
-- THE WIDTH CEILING, AND WHY IT IS WELL ABOVE 1.0. A letter's DRAWN advance is only about half
-- its point size, so a glyph sized wider than its cell still renders whole -- the jumbotron ran
-- at 1.03 deliberately. The ceiling exists only to stop a genuinely absurd size clipping, since
-- ClipsDescendants is on and overflow is a cut rather than a spill.
--
-- Raised to 1.4 when the owner asked for 30% larger lettering (2026-08-17): at 1.03 the WIDTH
-- clamp bound first and capped the increase at 16%, so moving the height alone would have
-- delivered half of what was asked. Since the flap standardisation every wall board shares one
-- cell aspect, so this single number governs all of them identically.
local GLYPH_OF_WIDTH = 1.4
-- A capital's drawn height as a share of its TextSize. Roughly true across faces and the number
-- to reach for when predicting what the eye will see -- it is why "30% larger" and "10% larger"
-- are asked for against ink, while every constant here is expressed against TextSize.
StatsBoardModel.INK_RATIO = 0.72
local MAX_CANVAS = 4096
function StatsBoardModel.metrics(rows: number, cols: number, aspect: number): Metrics
    local canvasH = rows * ROW_PX
    local canvasW = canvasH * aspect
    local over = math.max(canvasW / MAX_CANVAS, canvasH / MAX_CANVAS, 1)
    canvasH, canvasW = math.floor(canvasH / over), math.floor(canvasW / over)
    local cellH, cellW = canvasH / rows, canvasW / cols
    -- GLYPH_OF_HEIGHT ABOVE 1.0 IS CORRECT, not a slip. `glyphSize` is a TextSize, and a
    -- capital's DRAWN height is only about INK_RATIO of that -- the rest of the em is leading
    -- and room for ascenders and descenders. So a TextSize a little taller than the cell puts
    -- ink at roughly three quarters of it, which is what the eye reads.
    local glyph = math.min(90, math.floor(cellH * GLYPH_OF_HEIGHT), math.floor(cellW * GLYPH_OF_WIDTH))
    return { canvasW = canvasW, canvasH = canvasH, glyphSize = math.max(1, glyph) }
end

-- ===== adapters: wire payloads -> sections =====

function StatsBoardModel.standingsSections(leaders: { any }?): { Section }
    local entries: { Entry } = {}
    for _, l in leaders or {} do
        table.insert(entries, { name = l.displayName, figure = StatsBoardModel.figure(l.lifetimeBanked) })
    end
    return { { title = "CAREER BANKED", entries = entries } }
end

local function streakEntries(records: any?): { Entry }
    local entries: { Entry } = {}
    for _, r in (records and records.longestStreaks) or {} do
        table.insert(entries, { name = r.displayName, figure = StatsBoardModel.figure(r.length) })
    end
    return entries
end

function StatsBoardModel.skillSections(week: any?, all: any?): { Section }
    return {
        {
            title = `LONGEST STREAK - {StatsBoardModel.shortWindowLabel(
                week and week.window,
                week and week.windowKind
            )}`,
            entries = streakEntries(week),
        },
        {
            title = `LONGEST STREAK - {StatsBoardModel.shortWindowLabel(
                all and all.window,
                all and all.windowKind
            )}`,
            entries = streakEntries(all),
        },
    }
end

function StatsBoardModel.judgementSections(week: any?): { Section }
    local banks: { Entry } = {}
    for _, r in (week and week.biggestBanks) or {} do
        table.insert(banks, { name = r.displayName, figure = StatsBoardModel.figure(r.amount) })
    end
    local rounds: { Entry } = {}
    for _, r in (week and week.biggestRounds) or {} do
        table.insert(rounds, { name = r.displayName, figure = StatsBoardModel.figure(r.points) })
    end
    local label = StatsBoardModel.shortWindowLabel(week and week.window, week and week.windowKind)
    return {
        { title = `BIGGEST BANK - {label}`, entries = banks },
        { title = `BIGGEST ROUND - {label}`, entries = rounds },
    }
end

-- THE FORM GUIDE, WHICH IS NOW HEAT ALONE. It used to open with a row of glyphs -- the last ten
-- World Throws -- and that row has moved to the round display as a tape of its own: ten real
-- flaps beside the timer and the throw flipper, where the owner wanted it (2026-08-17). Keeping
-- it here as well would put the same ten throws on two surfaces in one room, one of them a
-- physical flap and the other a printed line, and they would disagree for the ~3.45s the drum
-- takes to settle.
--
-- The `tape` argument stays in the signature and stays unused: the caller has it to hand and a
-- future section may want it, and dropping it would churn every call site to save nothing.
function StatsBoardModel.worldSections(_tape: { any }?, heat: any?): { Section }
    local leaders: { Entry } = {}
    for _, l in (heat and heat.leaders) or {} do
        table.insert(leaders, { name = l.displayName, figure = StatsBoardModel.figure(l.earned) })
    end
    return {
        -- §3: heat is FORM, not standing. The title must never read as a ranking.
        {
            title = `HOT {StatsBoardModel.windowLabel(heat and heat.window, heat and heat.windowKind)}`,
            entries = leaders,
        },
    }
end

-- THE SUMMARY SLIP -- the vestibule board facing the personal 札 across the room. Reads the most
-- recent tape entry, which the Roblox server already forwards on StatsData: `GlobalResult` has
-- carried `distribution { R, P, S }` and `totalPlayers` since settlement was written, so this
-- board needed no server work at all.
--
-- LAST ROUND, NOT THIS ONE. The tape's newest entry is the last CLOSED round -- the current
-- round's throws are still arriving and its distribution would be a partial count that moves
-- while you read it. The title says so, because a percentage with no period attached invites
-- exactly the wrong reading.
function StatsBoardModel.summarySections(tape: { any }?): { Section }
    local latest = tape and tape[1]
    if not latest then
        return { { title = "LAST ROUND", entries = {} } }
    end
    local d = latest.distribution or {}
    local r, p, sc = tonumber(d.R) or 0, tonumber(d.P) or 0, tonumber(d.S) or 0
    local thrown = r + p + sc
    -- A round can settle with a player count but no throws (everyone present, nobody committed),
    -- so the denominator is guarded separately from `totalPlayers`.
    -- ONE DECIMAL (owner, 2026-08-18). A near-even round is the interesting one and whole
    -- percents flatten it: 101/99/101 of 301 reads as "34 33 34" whole, hiding that two of them
    -- tied. The World Throw is decided by exactly that margin.
    local function pct(n: number): string
        if thrown <= 0 then
            return "-"
        end
        return string.format("%.1f%%", n / thrown * 100)
    end
    local BLANK = StatsBoardModel.SPACER
    return {
        {
            title = "LAST ROUND",
            -- THE THROW ITSELF, hard right on the title line (owner, 2026-08-17). The four rows
            -- below are all ABOUT the World Throw without ever naming it; a reader had to infer
            -- it from the percentages, which is the one thing this board could simply say. It
            -- goes on the title line rather than in a fifth row because that is where the eye
            -- lands first, and because the row grid is a slip's, not a headline's.
            --
            -- Reading it here is safe: this is the last CLOSED round, and StatsController holds a
            -- tape whose newest entry the drum has not finished announcing (`drumRest`), so the
            -- glyph cannot outrun the drum any more than the percentages beneath it can.
            titleRight = StatsBoardModel.GLYPH[tostring(latest.worldThrow)],
            -- label:value, like the 札 it faces -- not a ranking, so not numbered.
            numbered = false,
            entries = {
                BLANK,
                { name = "PLAYERS", figure = StatsBoardModel.figure(latest.totalPlayers) },
                BLANK,
                { name = "ROCK", figure = pct(r) },
                { name = "PAPER", figure = pct(p) },
                { name = "SCISSORS", figure = pct(sc) },
            },
        },
    }
end

-- THE BANZUKE. Ranked on yield; the read carried BESIDE it, never blended in. Yield is the only
-- figure that captures the compounding the design measures -- a strong reader riding deep earns
-- many times what a blind one riding to the same depth does, a gap win rate alone renders as a
-- few percentage points -- and the read column is what tells a reader whether someone is up
-- there on skill or on nerve.
function StatsBoardModel.banzukeSections(board: any?, leaders: { any }?): { Section }
    local b = board or {}
    local rows = b.rows or {}
    if #rows == 0 then
        -- NEVER EMPTY. Before anyone has thrown six hours the wall shows career standings and
        -- says what the ranking is waiting for: a blank board reads as broken, and the rule is
        -- the one thing a new player most wants to know.
        local careerEntries: { Entry } = {}
        for _, l in leaders or {} do
            table.insert(
                careerEntries,
                { name = l.displayName, figure = StatsBoardModel.figure(l.lifetimeBanked) }
            )
        end
        -- TWO BOARDS, AND THE RULE BELONGS TO THE FIRST (owner, 2026-08-18). It read
        -- "360 THROWS PUTS YOU HERE" directly above "CAREER BANKED", which promises entry to the
        -- wrong list: career banked has no entry requirement at all -- bank once and you are on
        -- it -- and what 360 throws actually buys is a place on the points-per-throw ranking,
        -- which is a different board that simply has nobody on it yet.
        --
        -- So the ranking names itself, says how to get on it, and the career list keeps its own
        -- heading underneath as the standing that IS available meanwhile.
        --
        -- Carried as `lines`, not `entries`: compose prints "NO DATA YET" for a section with an
        -- empty entries list, which is right for a board with nothing to show and wrong here,
        -- where the caption already says what is missing and why.
        --
        -- BOTH HEADINGS LEAD. `topByCareer` fetches fifty names onto a ten-row board, so anything
        -- placed after the career list is guaranteed to be truncated away -- which is exactly
        -- what happened to the first version of this line.
        return {
            {
                title = "POINTS PER THROW - 7 DAYS",
                lines = { `THROW {b.minThrows or 360} A WEEK TO RANK` },
            },
            { title = "CAREER BANKED", entries = careerEntries },
        }
    end
    local entries: { Entry } = {}
    for _, r in rows do
        local read = if b.worldIsCrowd then percentOrBlank(r.winRate) else ""
        local yield = string.format("%.1f", tonumber(r.pointsPerThrow) or 0)
        table.insert(entries, {
            name = r.displayName,
            figure = if read == "" then yield else `{yield} {read}`,
        })
    end
    local sections: { Section } = { { title = "POINTS PER THROW - 7 DAYS", entries = entries } }
    if b.worldIsCrowd then
        -- THE BASELINE, PRINTED. "41%" means nothing to a reader who does not know that a blind
        -- player scores 33 -- and every reader is in that position the first time. A section
        -- with no entries renders as a bare line under the ranking. Only when the read column is
        -- actually showing: without it the line explains a column that is not there.
        table.insert(sections, { title = "LUCK ALONE WINS 33 IN 100", lines = {} })
    end
    return sections
end

-- NERVE AS A SHAPE, NOT A RANKING. Index 1 is depth 1; the last bucket is "this deep or more".
-- A leaderboard here would crown whoever rides past their own read and banks nothing.
function StatsBoardModel.depthSections(depths: { number }?): { Section }
    local d = depths or {}
    local most = 0
    for _, n in d do
        most = math.max(most, n)
    end
    local entries: { Entry } = {}
    for i, n in d do
        -- Guard the empty room: with no banks at all every bar is zero-width, not an error.
        local bars = if most > 0 then math.floor(n / most * 5 + 0.5) else 0
        -- The last bucket is "this deep OR MORE" and has to say so, or it reads as exactly that
        -- depth and the tail looks like it vanished.
        local label = if i == #d then `{i}+` else tostring(i)
        table.insert(entries, { name = label .. string.rep("#", bars), figure = tostring(n) })
    end
    return { { title = "BANK AFTER", entries = entries } }
end

function StatsBoardModel.fudaSections(player: any?): { Section }
    local p = player or {}
    local career, week = p.career or {}, p.week or {}
    local throws = math.floor(tonumber(week.throws) or 0)
    local qualifyAt = math.floor(tonumber(week.minThrows) or 0)
    -- Honest progress, per spec §6: "142 / 350 throws", never a blank where a rate would go.
    local progress = if week.qualified
        then StatsBoardModel.figure(throws)
        else `{StatsBoardModel.figure(throws)}/{StatsBoardModel.figure(qualifyAt)}`
    return {
        {
            title = StatsBoardModel.sanitize(p.displayName),
            -- FIX 2: this is one person's own rows, not a leaderboard of one — no rank prefix.
            numbered = false,
            entries = {
                { name = "BANKED", figure = StatsBoardModel.figure(career.banked) },
                { name = "BEST STREAK", figure = StatsBoardModel.figure(career.bestStreak) },
                { name = "CURRENT STREAK", figure = StatsBoardModel.figure(p.currentStreak) },
                -- "THROWS", not "THROWS THIS WEEK": the fraction (e.g. 142/360) already reads as
                -- a weekly quota, and the full label is 17 cols wide before a figure even joins
                -- it — too wide to survive the slip regardless of width math.
                { name = "THROWS", figure = progress },
                { name = "BEAT WORLD", figure = if week.winRate then percentOrBlank(week.winRate) else "-" },
                -- "PER THROW" of WHAT (owner, 2026-08-18). The slash keeps it inside the label
                -- budget, where "POINTS PER THROW" would leave no room for the figure.
                {
                    name = "POINTS/THROW",
                    figure = if week.pointsPerThrow then string.format("%.1f", week.pointsPerThrow) else "-",
                },
                -- BANK DEPTH IS DELIBERATELY ABSENT (owner, 2026-08-18): "a dubious stat for a
                -- personal board". It lives on as the room-wide histogram, where it describes a
                -- crowd's habit instead of implying a personal score. `nerve` still travels on
                -- the wire, for that board and for anything later that wants it.
                -- WHERE YOU STAND, and the whole reason it is on the slip rather than the wall:
                -- the banzuke is ten rows, so most of the room never sees its own name there.
                -- "14 OF 22" and not "14/22" -- a slash reads as the progress fraction directly
                -- above ("142/360") and would be taken for one.
                {
                    name = "RANK",
                    figure = if week.standing then `{week.standing.rank} OF {week.standing.of}` else "-",
                },
            },
        },
    }
end

return StatsBoardModel
