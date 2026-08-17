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
export type Section = { title: string, entries: { Entry }?, lines: { string }? }
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

-- THE 100px CAP, SOLVED ONCE. TextSize maxes at 100 and TextScaled will not scale up on a
-- SurfaceGui, so the canvas is sized SMALL enough that a ~90px glyph is already large relative
-- to a cell, and the SurfaceGui stretches it across the physical board. Canvas aspect is pinned
-- to the board's aspect or the stretch would distort the glyphs.
local TARGET_CELL = 115 -- canvas px on a cell's SMALLER axis
local MAX_CANVAS = 4096
function StatsBoardModel.metrics(rows: number, cols: number, aspect: number): Metrics
    local ratio = (aspect * rows) / cols -- cellW / cellH, independent of scale
    local cellH = if ratio >= 1 then TARGET_CELL else TARGET_CELL / ratio
    local canvasH = cellH * rows
    local canvasW = canvasH * aspect
    local over = math.max(canvasW / MAX_CANVAS, canvasH / MAX_CANVAS, 1)
    canvasH, canvasW = math.floor(canvasH / over), math.floor(canvasW / over)
    local glyph = math.min(90, math.floor(math.min(canvasW / cols, canvasH / rows) * 0.78))
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
            title = `LONGEST STREAK {StatsBoardModel.windowLabel(
                week and week.window,
                week and week.windowKind
            )}`,
            entries = streakEntries(week),
        },
        {
            title = `LONGEST STREAK {StatsBoardModel.windowLabel(all and all.window, all and all.windowKind)}`,
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
    local label = StatsBoardModel.windowLabel(week and week.window, week and week.windowKind)
    return {
        { title = `BIGGEST BANK {label}`, entries = banks },
        { title = `BIGGEST ROUND {label}`, entries = rounds },
    }
end

-- R3: ten, not twenty. /api/v1/state serves store.tape(10) and nothing carries more.
function StatsBoardModel.worldSections(tape: { any }?, heat: any?): { Section }
    local glyphs: { string } = {}
    for _, t in tape or {} do
        table.insert(glyphs, StatsBoardModel.GLYPH[t.worldThrow] or "?")
    end
    local leaders: { Entry } = {}
    for _, l in (heat and heat.leaders) or {} do
        table.insert(leaders, { name = l.displayName, figure = StatsBoardModel.figure(l.earned) })
    end
    return {
        { title = `LAST {#glyphs} WORLD THROWS`, lines = { table.concat(glyphs, " ") } },
        -- §3: heat is FORM, not standing. The title must never read as a ranking.
        {
            title = `HOT {StatsBoardModel.windowLabel(heat and heat.window, heat and heat.windowKind)}`,
            entries = leaders,
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
            entries = {
                { name = "BANKED", figure = StatsBoardModel.figure(career.banked) },
                { name = "BEST STREAK", figure = StatsBoardModel.figure(career.bestStreak) },
                { name = "STREAK NOW", figure = StatsBoardModel.figure(p.currentStreak) },
                { name = "THROWS THIS WEEK", figure = progress },
            },
        },
    }
end

return StatsBoardModel
