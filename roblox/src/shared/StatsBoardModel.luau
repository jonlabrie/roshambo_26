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
export type Section = { title: string, entries: { Entry }?, lines: { string }?, numbered: boolean? }
export type Opts = { rows: number, cols: number }
export type Metrics = { canvasW: number, canvasH: number, glyphSize: number }

local ALLOWED: { [string]: boolean } = {}
for _, code in utf8.codes(StatsBoardModel.DRUM) do
    ALLOWED[utf8.char(code)] = true
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
        push(StatsBoardModel.sanitize(sec.title))
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
                    push(labelLine(e, o.cols))
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
    local function pct(n: number): string
        if thrown <= 0 then
            return "-"
        end
        return `{math.floor(n / thrown * 100 + 0.5)}%`
    end
    return {
        {
            title = "LAST ROUND",
            -- label:value, like the 札 it faces -- not a ranking, so not numbered.
            numbered = false,
            entries = {
                { name = "PLAYERS", figure = StatsBoardModel.figure(latest.totalPlayers) },
                { name = "ROCK", figure = pct(r) },
                { name = "PAPER", figure = pct(p) },
                { name = "SCISSORS", figure = pct(sc) },
            },
        },
    }
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
                { name = "STREAK NOW", figure = StatsBoardModel.figure(p.currentStreak) },
                -- "THROWS", not "THROWS THIS WEEK": the fraction (e.g. 142/350) already reads as
                -- a weekly quota, and the full label is 17 cols wide before a figure even joins
                -- it — too wide to survive a 16-col slip regardless of width math.
                { name = "THROWS", figure = progress },
            },
        },
    }
end

return StatsBoardModel
