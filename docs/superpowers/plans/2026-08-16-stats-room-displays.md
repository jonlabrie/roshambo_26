# Stats Room Displays (番付) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put readable, live split-flap displays on the four walls of the bored Stats
cavern, plus the clerestory round band that keeps a player studying them from silently
dropping out of the game.

**Architecture:** A pure text model (`StatsBoardModel`) turns the already-shipped
`/api/v1/stats` payloads into fixed-width drum-safe lines. A thin client renderer
(`FlapBoard`) — extracted from the dead `BoardController` — paints those lines as
split-flap cells on any tagged part. A pure layout module (`StatsRoomLayout`) holds the
board inventory in room coordinates; a Studio tool seats the physical parts against the
bored rock. One client controller (`StatsController`) wires tags → boards → data, and a
second pure model (`RoundBandModel`) drives the clerestory band off the same
`RoundMetronome` reading and `drumRest` cue the HUD uses.

**Tech Stack:** Luau (Roblox client + DI'd shared modules), Lune test harness, Rojo,
CollectionService tags, existing Express `/api/v1/stats` REST surface.

**Spec:** `docs/superpowers/specs/2026-08-16-stats-room-design.md` — §6 (the room),
§6.1 (per-viewer), §6.2 (visual language), §6.3 (round band), §7 (sequencing by data
maturity), §8 (nothing dark at launch).

---

## Global Constraints

- **`TextLabel.TextSize` is hard-capped at 100px** and `TextScaled` does not reliably
  scale up on a SurfaceGui. Every board uses the small-canvas-stretched-large trick:
  a canvas sized so a ≤90px glyph is already large relative to it, stretched by the
  SurfaceGui across the physical board.
- **The drum is authoritative** (owner, 2026-08-04). Nothing may reflect the World
  Throw before the `drumRest` cue. Consume `EventBus.Cue` with `kind == "drumRest"`,
  never `RevealTheater` directly.
- **The flap drum has no lowercase.** `FlapScheduler.DRUM` is
  `" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.!?+%-:/○─∧"`. Every character that reaches a
  cell must be in it, or the cell lands on a wrong glyph.
- **Rojo manages exactly `default.project.json`.** Board parts are place-only geometry
  and are found by **CollectionService tag**, never by path or by name-matching.
- **Shared modules are pure and run under Lune.** No Roblox globals in `src/shared/`.
  Client modules may touch Instances; keep them thin.
- **`/api/v1/stats/records?window=all` returns a `to` bound 24 hours in the future.**
  Never print a raw `from`/`to` on a board — render window labels from `window` +
  `windowKind` only.
- **Do not take Studio screenshots.** The owner judges visuals and chooses camera
  angles (standing directive, 2026-08-16). Report what you built and stop.
- `stylua --check src tests tools && selene src tools` must pass (selene fails on
  warnings). `lune run tests/run` must pass.

## Plan rulings (made while writing this plan; the spec is the binding authority)

- **R1 — `BoardController.client.luau` is RETIRED, not retargeted.** The owner ruled the
  retarget folds into plan 3 (2026-08-16). Executing that literally is impossible: there
  is no kōsatsu anywhere in the place (`grep -ri kosatsu src/ tools/` matches only
  BoardController's own comments), and the jumbotron it drew is gone. Its two live
  behaviours survive elsewhere — `EventBus.TickerMessage` already has two consumers
  (`LedgerController:698`, `HudController:1535`), and its `BoardData` content becomes the
  Stats room's `world` board. So: extract the renderer to `FlapBoard.luau`, delete the
  controller. **The `RevealTheater` spoiler documented at `BoardController:160-171` dies
  with the file**, and the world board takes its throw from `drumRest` by construction.
- **R2 — Displays first, built against seeded fixtures.** `StreakEvent`/`BankEvent` start
  from deploy with no backfill, so the boards are empty until people play. A fixtures
  toggle (`workspace:SetAttribute("StatsFixtures", true)`) lets the owner judge layout and
  legibility on known-good numbers.
- **R3 — The form guide reads the LAST 10 world throws, not 20.** Spec §6.2 asks for 20;
  the wire cannot supply it — `apiV1.ts:65` serves `store.tape(10)`. Ten is what exists.
- **R4 — The west wall ships Records, not rate ladders.** Spec §6 assigns west to "Skill
  (rates, participation study)", but §7 puts qualified rates in the *waits-for-a-population*
  column. West carries longest streaks (week + all-time) now, and a second west panel is
  built **shuttered** per §8 ("shuttered or furled, not unlit") reserved for the ladders.
- **R5 — The band renders ONE 16-column line, identical on all four segments.** Fewer
  columns on a wider board simply makes the cells bigger, which is what a read-at-distance
  band wants. It is a client-built SurfaceGui, so it is per-viewer already and carries the
  viewer's own throw.

---

## File Structure

**Create:**
- `roblox/src/shared/StatsBoardModel.luau` — pure. Payloads → fixed-width drum-safe lines; canvas metrics.
- `roblox/src/shared/StatsRoomLayout.luau` — pure. The board inventory in room coordinates + seating math.
- `roblox/src/shared/RoundBandModel.luau` — pure. Round state → the band's single line.
- `roblox/src/shared/StatsFixtures.luau` — pure. Seeded payloads shaped exactly like the wire.
- `roblox/src/client/FlapBoard.luau` — client module. Builds and drives split-flap cells on a part.
- `roblox/src/client/StatsController.client.luau` — wires tags → boards → data → lines.
- `roblox/tools/studio/buildStatsBoards.luau` — Studio tool; seats and tags the physical parts.
- `roblox/tests/StatsBoardModel.spec.luau`, `roblox/tests/StatsRoomLayout.spec.luau`, `roblox/tests/RoundBandModel.spec.luau`

**Modify:**
- `roblox/src/server/NetworkClient.luau` — three `/api/v1/stats` getters.
- `roblox/tests/NetworkClient.spec.luau` — cover them.
- `roblox/src/server/main.server.luau` — the stats poller and per-player push.
- `roblox/default.project.json` — `StatsData`, `StatsPersonal` RemoteEvents.

**Delete:**
- `roblox/src/client/BoardController.client.luau` (R1).

---

### Task 1: `StatsBoardModel` — payloads to drum-safe lines

**Files:**
- Create: `roblox/src/shared/StatsBoardModel.luau`
- Test: `roblox/tests/StatsBoardModel.spec.luau`

**Interfaces:**
- Consumes: nothing (pure, no requires).
- Produces:
  - `StatsBoardModel.sanitize(name: string?): string`
  - `StatsBoardModel.figure(n: number?): string`
  - `StatsBoardModel.compose(sections: { Section }, o: { rows: number, cols: number }): { string }`
  - `StatsBoardModel.windowLabel(window: string?, windowKind: string?): string`
  - `StatsBoardModel.metrics(rows: number, cols: number, aspect: number): Metrics`
  - Adapters: `standingsSections(leaders)`, `skillSections(week, all)`,
    `judgementSections(week)`, `worldSections(tape, heat)`, `fudaSections(player)`
  - Types: `Entry = { name: string?, figure: string }`,
    `Section = { title: string, entries: { Entry }?, lines: { string }? }`,
    `Metrics = { canvasW: number, canvasH: number, glyphSize: number }`

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/StatsBoardModel.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local M = require("../src/shared/StatsBoardModel")
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
            week = { throws = 142, qualifyAt = 350, qualified = false },
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `StatsBoardModel` does not exist.

- [ ] **Step 3: Write the implementation**

Create `roblox/src/shared/StatsBoardModel.luau`:

```luau
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
            title = `LONGEST STREAK {StatsBoardModel.windowLabel(week and week.window, week and week.windowKind)}`,
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
        { title = `HOT {StatsBoardModel.windowLabel(heat and heat.window, heat and heat.windowKind)}`, entries = leaders },
    }
end

function StatsBoardModel.fudaSections(player: any?): { Section }
    local p = player or {}
    local career, week = p.career or {}, p.week or {}
    local throws = math.floor(tonumber(week.throws) or 0)
    local qualifyAt = math.floor(tonumber(week.qualifyAt) or 0)
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
```

- [ ] **Step 4: Add the drum-parity test**

Add the require beside the others at the TOP of `roblox/tests/StatsBoardModel.spec.luau`, and
append the block at the end:

```luau
-- top, with the other requires
local FlapScheduler = require("../src/shared/FlapScheduler")

-- end of file
describe("StatsBoardModel drum parity", function()
    test("the model's drum copy matches FlapScheduler's, or cells land on wrong glyphs", function()
        expect(M.DRUM).toBe(FlapScheduler.DRUM)
    end)
end)
```

- [ ] **Step 5: Run tests, format, lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS, clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/StatsBoardModel.luau roblox/tests/StatsBoardModel.spec.luau
git commit -m "feat(roblox): StatsBoardModel — stats payloads become drum-safe board lines"
```

---

### Task 2: `FlapBoard` — the renderer, extracted; `BoardController` retired

**Files:**
- Create: `roblox/src/client/FlapBoard.luau`
- Delete: `roblox/src/client/BoardController.client.luau`

**Interfaces:**
- Consumes: `StatsBoardModel.Metrics` (Task 1).
- Produces:
  - `FlapBoard.new(cfg: Config): Board` where
    `Config = { part: BasePart, rows: number, cols: number, metrics: Metrics, plan: (string, string) -> { any }, faces: { Enum.NormalId }? }`
  - `Board:setRow(row: number, line: string)`
  - `Board:setAll(lines: { string })`
  - `Board:destroy()`

**Context an implementer cannot infer:** the cell construction below is a near-verbatim lift of
`BoardController.client.luau:52-113` — Frame (ivory) + seam + transparent glyph TextLabel with a
`UIPadding` that drops caps to optical centre. Do not redesign it; the tuning came from a gate.
The only changes are that geometry now comes from `metrics` instead of file-local constants, and
the part comes from the caller instead of `workspace.RoshamboStage.JumbotronBoard`.

- [ ] **Step 1: Write the module**

Create `roblox/src/client/FlapBoard.luau`:

```luau
--!strict
-- Split-flap renderer for ONE board part. Client-side by construction: the SurfaceGui is parented
-- to a world part from a LocalScript, and client-created instances do not replicate — which is
-- exactly what makes a per-viewer board need no new mechanism (spec §6.1).
--
-- Lifted from BoardController.client.luau, which drew the removed jumbotron and has been retired
-- (plan ruling R1). Cell metrics now arrive from StatsBoardModel.metrics instead of being file
-- constants, so one renderer serves a 16x9 banzuke sheet and a 38x2.4 clerestory band alike.
local TweenService = game:GetService("TweenService")

local FlapBoard = {}
FlapBoard.__index = FlapBoard

export type Metrics = { canvasW: number, canvasH: number, glyphSize: number }
export type Config = {
    part: BasePart,
    rows: number,
    cols: number,
    metrics: Metrics,
    -- FlapScheduler.plan, injected so this module requires nothing and the caller owns the
    -- step/stagger tuning per board (a 1-row band wants a snappier roll than a 10-row sheet).
    plan: (current: string, target: string) -> { any },
    faces: { Enum.NormalId }?,
}

local PAD = 0.08 -- inset fraction within each cell
local BOARD_FONT = Enum.Font.Merriweather
local GLYPH_FULL = UDim2.fromScale(1, 1)
local GLYPH_SQUASHED = UDim2.fromScale(1, 0.05)

local function buildFace(cfg: Config, faceEnum: Enum.NormalId): { { TextLabel } }
    local gui = Instance.new("SurfaceGui")
    gui.Name = "FlapFace"
    gui.Face = faceEnum
    gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    gui.CanvasSize = Vector2.new(cfg.metrics.canvasW, cfg.metrics.canvasH)
    gui.Parent = cfg.part
    local cellW, cellH = 1 / cfg.cols, 1 / cfg.rows
    local grid: { { TextLabel } } = {}
    for r = 1, cfg.rows do
        grid[r] = {}
        for c = 1, cfg.cols do
            local tile = Instance.new("Frame")
            tile.Size = UDim2.fromScale(cellW * (1 - PAD), cellH * (1 - PAD))
            tile.Position =
                UDim2.fromScale((c - 1) * cellW + cellW * PAD / 2, (r - 1) * cellH + cellH * PAD / 2)
            tile.BackgroundColor3 = Color3.fromRGB(244, 238, 222)
            tile.BorderSizePixel = 0
            tile.ClipsDescendants = true
            tile.ZIndex = 2
            tile.Parent = gui

            local seam = Instance.new("Frame")
            seam.Size = UDim2.fromScale(1, 0.035)
            seam.Position = UDim2.fromScale(0, 0.5)
            seam.AnchorPoint = Vector2.new(0, 0.5)
            seam.BackgroundColor3 = Color3.fromRGB(150, 142, 124)
            seam.BorderSizePixel = 0
            seam.ZIndex = 4
            seam.Parent = tile

            local glyph = Instance.new("TextLabel")
            glyph.Size = GLYPH_FULL
            glyph.BackgroundTransparency = 1
            glyph.TextColor3 = Color3.fromRGB(40, 30, 18)
            glyph.TextScaled = false
            glyph.TextSize = cfg.metrics.glyphSize
            glyph.Font = BOARD_FONT
            glyph.TextXAlignment = Enum.TextXAlignment.Center
            glyph.TextYAlignment = Enum.TextYAlignment.Center
            glyph.Text = " "
            glyph.ZIndex = 3
            glyph.Parent = tile

            -- All-caps ride high because the line box reserves descender space; drop them to
            -- optical centre. Sibling of the seam so the padding never shifts the seam.
            local pad = Instance.new("UIPadding")
            pad.PaddingTop = UDim.new(0.1, 0)
            pad.Parent = glyph

            grid[r][c] = glyph
        end
    end
    return grid
end

local function flapTo(cell: TextLabel, char: string)
    local squash = TweenService:Create(cell, TweenInfo.new(0.04), { Size = GLYPH_SQUASHED })
    squash:Play()
    squash.Completed:Once(function()
        cell.Text = char
        TweenService:Create(cell, TweenInfo.new(0.04), { Size = GLYPH_FULL }):Play()
    end)
end

function FlapBoard.new(cfg: Config)
    local self = setmetatable({
        _cfg = cfg,
        _faces = {},
        _current = {} :: { [number]: string },
        _dead = false,
    }, FlapBoard)
    for _, face in cfg.faces or { Enum.NormalId.Front } do
        table.insert(self._faces, buildFace(cfg, face))
    end
    return self
end

function FlapBoard.setRow(self: any, row: number, line: string)
    if self._dead or row < 1 or row > self._cfg.rows then
        return
    end
    -- No byte-based truncation anywhere on this path: a :sub() could split a multibyte glyph
    -- and crash utf8.codes inside the scheduler. Columns past `cols` are dropped by the
    -- nil-cell guard below instead.
    local plan = self._cfg.plan(self._current[row] or "", line)
    self._current[row] = line
    for _, step in plan do
        task.delay(step.atMs / 1000, function()
            if self._dead then
                return
            end
            for _, grid in self._faces do
                local cell = grid[row][step.col]
                if cell then
                    flapTo(cell, step.char)
                end
            end
        end)
    end
end

function FlapBoard.setAll(self: any, lines: { string })
    for i, line in lines do
        self:setRow(i, line)
    end
end

function FlapBoard.destroy(self: any)
    self._dead = true
    for _, gui in self._cfg.part:GetChildren() do
        if gui:IsA("SurfaceGui") and gui.Name == "FlapFace" then
            gui:Destroy()
        end
    end
    table.clear(self._faces)
end

return FlapBoard
```

- [ ] **Step 2: Retire `BoardController`**

```bash
git rm roblox/src/client/BoardController.client.luau
```

Ruling R1 in full, for the commit message and for anyone who finds the deletion later:
there is no kōsatsu in the place to retarget onto; the controller's `TickerMessage`
consumer is redundant (`LedgerController:698` and `HudController:1535` both consume it);
its `BoardData` content is taken over by the Stats room's `world` board in Task 5; and its
documented `RevealTheater` spoiler — which retargeting as-written would have resurrected —
dies with the file.

- [ ] **Step 3: Verify nothing else referenced it**

Run: `grep -rn "BoardController" roblox/ docs/ --include='*.luau' --include='*.json' --include='*.md'`
Expected: matches only in docs/plans (prose), never in `default.project.json` or any
`.luau` require. `.client.luau` files under `src/client/` are picked up by Rojo's directory
mapping, so no project-file edit is needed for the deletion.

- [ ] **Step 4: Format, lint, test**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run`
Expected: clean and green. (`FlapBoard` has no headless test — it is Instance-bound by
nature. Its only arithmetic lives in `StatsBoardModel.metrics`, which Task 1 covers.)

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/FlapBoard.luau
git commit -m "refactor(roblox): extract FlapBoard from BoardController, and retire the jumbotron controller"
```

---

### Task 3: `StatsRoomLayout` — the board inventory, and the Studio tool that seats it

**Files:**
- Create: `roblox/src/shared/StatsRoomLayout.luau`
- Create: `roblox/tools/studio/buildStatsBoards.luau`
- Test: `roblox/tests/StatsRoomLayout.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `StatsRoomLayout.ROOM = { xW, xE, zN, zS, floorY, ceilingY }`
  - `StatsRoomLayout.DOOR = { x, halfWidth }`
  - `StatsRoomLayout.BOARDS: { Board }` where
    `Board = { id: string, wall: "north"|"south"|"east"|"west", x: number, y: number, z: number, w: number, h: number, rows: number, cols: number, shuttered: boolean? }`
  - `StatsRoomLayout.TAG = "StatsBoard"`
  - `StatsRoomLayout.THICKNESS = 0.4`
  - `StatsRoomLayout.yawFor(wall: string): number`
  - `StatsRoomLayout.inwardFor(wall: string): number`
  - `StatsRoomLayout.STANDOFF = 0.3`, `StatsRoomLayout.CAST_BACK = 3.0`
  - `StatsRoomLayout.seat(nominal: number, hitDistance: number?, inward: number, maxAdjust: number): number`
  - `StatsRoomLayout.check(): (boolean, { string })`

**The coordinates, and where they came from.** The bore is recorded in
`roblox/tools/studio/boreStatsCavern.luau`: room `x[-58.00, -17.83] z[62.00, 85.22]`,
floor aliasing to ~114, `ROOM_ROOF = 135.0` aliasing down to a measured 134.00. The
tunnel meets the north wall at `DOOR_X = -28.92` with a ~7-stud clear bore.

**Yaw, derived once so nobody re-derives it wrong.** `CFrame.Angles(0, rad(yaw), 0).LookVector`
is `(-sin yaw, 0, -cos yaw)`, and a SurfaceGui on `Enum.NormalId.Front` renders on the face whose
normal is LookVector. So the face points into the room when: north wall → `+z` → **yaw 180**;
south wall → `-z` → **yaw 0**; west wall → `+x` → **yaw -90**; east wall → `-x` → **yaw 90**.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/StatsRoomLayout.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local L = require("../src/shared/StatsRoomLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function byId(id: string): any
    for _, b in L.BOARDS do
        if b.id == id then
            return b
        end
    end
    error(`no board {id}`)
end

describe("StatsRoomLayout", function()
    test("every board fits inside the bored room on both axes", function()
        for _, b in L.BOARDS do
            local halfW = b.w / 2
            if b.wall == "north" or b.wall == "south" then
                expect(b.x - halfW >= L.ROOM.xW).toBeTruthy()
                expect(b.x + halfW <= L.ROOM.xE).toBeTruthy()
            else
                expect(b.z - halfW >= L.ROOM.zN).toBeTruthy()
                expect(b.z + halfW <= L.ROOM.zS).toBeTruthy()
            end
            expect(b.y - b.h / 2 >= L.ROOM.floorY).toBeTruthy()
            expect(b.y + b.h / 2 <= L.ROOM.ceilingY).toBeTruthy()
        end
    end)

    test("nothing at door height covers the tunnel mouth", function()
        for _, b in L.BOARDS do
            if b.wall == "north" and b.y - b.h / 2 < L.DOOR.top then
                local clear = b.x - b.w / 2 >= L.DOOR.x + L.DOOR.halfWidth
                    or b.x + b.w / 2 <= L.DOOR.x - L.DOOR.halfWidth
                expect(clear).toBeTruthy()
            end
        end
    end)

    test("the clerestory band crosses the mouth, and is allowed to — it runs above the head", function()
        local band = byId("bandNorth")
        expect(band.x - band.w / 2 < L.DOOR.x).toBeTruthy()
        expect(band.x + band.w / 2 > L.DOOR.x).toBeTruthy()
        expect(band.y - band.h / 2 >= L.DOOR.top).toBeTruthy()
    end)

    test("no two boards on the same wall overlap", function()
        for i, a in L.BOARDS do
            for j, b in L.BOARDS do
                if j > i and a.wall == b.wall then
                    local aAxis = if a.wall == "north" or a.wall == "south" then a.x else a.z
                    local bAxis = if b.wall == "north" or b.wall == "south" then b.x else b.z
                    local apart = math.abs(aAxis - bAxis) >= (a.w + b.w) / 2
                    local stacked = math.abs(a.y - b.y) >= (a.h + b.h) / 2
                    expect(apart or stacked).toBeTruthy()
                end
            end
        end
    end)

    test("the band runs on all four walls, at one height, one row, one width", function()
        local band = {}
        for _, b in L.BOARDS do
            if b.id:sub(1, 4) == "band" then
                table.insert(band, b)
            end
        end
        expect(#band).toBe(4)
        for _, b in band do
            expect(b.rows).toBe(1)
            expect(b.cols).toBe(band[1].cols)
            expect(b.y).toBe(band[1].y)
        end
    end)

    test("the reserved skill panel is shuttered, not merely absent (spec section 8)", function()
        expect(byId("skillFuture").shuttered).toBe(true)
    end)

    test("yaw turns each wall's board face into the room", function()
        expect(L.yawFor("north")).toBe(180)
        expect(L.yawFor("south")).toBe(0)
        expect(L.yawFor("west")).toBe(-90)
        expect(L.yawFor("east")).toBe(90)
    end)

    test("seat moves the board to the measured rock, clamped so a bad ray cannot fling it", function()
        -- inward = +1 (north wall: room lies at greater z). A hit 5 studs along a ray that
        -- started 3 studs outside the nominal plane means rock 2 studs INTO the room.
        expect(L.seat(62.0, 5, 1, 2.5)).toBeCloseTo(64.3, 0.001)
        -- A wild ray is clamped, never obeyed.
        expect(L.seat(62.0, 30, 1, 2.5)).toBeCloseTo(64.8, 0.001)
        -- No hit at all: stay nominal, offset by the board's own standoff.
        expect(L.seat(62.0, nil, 1, 2.5)).toBeCloseTo(62.3, 0.001)
    end)

    test("check() passes on the shipped inventory", function()
        local ok, failures = L.check()
        expect(#failures).toBe(0)
        expect(ok).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `StatsRoomLayout` does not exist.

- [ ] **Step 3: Write the module**

Create `roblox/src/shared/StatsRoomLayout.luau`:

```luau
--!strict
-- WHERE THE STATS ROOM'S BOARDS GO. Pure data plus its own invariants, so the placement is
-- checkable under Lune and the Studio tool that builds the parts stays a thin executor.
--
-- The room is PLACE-ONLY geometry (bored terrain, not a Rojo model), so the parts this describes
-- are found at runtime by CollectionService tag — never by path and never by name.
local StatsRoomLayout = {}

-- Measured by tools/studio/boreStatsCavern.luau in VERIFY mode after the owner hand-shaped the
-- cut: the nominal bore is x[-58.00,-17.83] z[62.00,85.22], the floor aliases to ~114 and
-- ROOM_ROOF 135.0 aliases down to a measured 134.00.
StatsRoomLayout.ROOM = { xW = -58.00, xE = -17.83, zN = 62.00, zS = 85.22, floorY = 114.0, ceilingY = 134.0 }

-- The tunnel meets the north wall here (boreStatsCavern DOOR_X, BORE_W ~7 net after aliasing).
-- halfWidth is deliberately generous: a board that grazes the mouth reads as blocking it.
--
-- `top` IS WHAT LETS THE CLERESTORY BAND RUN UNBROKEN. The band spans the whole north wall,
-- mouth included, and must — it is the one display that has to be visible from anywhere in the
-- room. It clears the opening because it sits at y 131 and the tunnel head is at LINTEL_TOP
-- 120.60. So the keep-out is a DOORWAY, not a column: it binds only boards that reach below
-- `top`. Without this the invariant would be either wrong or unsatisfiable.
StatsRoomLayout.DOOR = { x = -28.92, halfWidth = 4.0, top = 121.0 }

StatsRoomLayout.TAG = "StatsBoard"
StatsRoomLayout.THICKNESS = 0.4
StatsRoomLayout.STANDOFF = 0.3 -- board centre this far off the wall plane

export type Board = {
    id: string,
    wall: string,
    x: number,
    y: number,
    z: number,
    w: number,
    h: number,
    rows: number,
    cols: number,
    shuttered: boolean?,
}

local BAND_Y, BAND_H, BAND_COLS = 131.0, 2.4, 16

StatsRoomLayout.BOARDS = {
    -- South faces you on entry: the standings (spec section 6).
    { id = "banzuke", wall = "south", x = -37.90, y = 121.0, z = 84.92, w = 16, h = 9, rows = 10, cols = 26 },
    -- West, the longest wall: records now, rate ladders later (ruling R4).
    { id = "skill", wall = "west", x = -57.70, y = 120.5, z = 70.00, w = 12, h = 7, rows = 8, cols = 22 },
    {
        id = "skillFuture",
        wall = "west",
        x = -57.70,
        y = 120.0,
        z = 80.50,
        w = 8,
        h = 5,
        rows = 6,
        cols = 18,
        -- Section 8: shuttered, NOT unlit. A closed kosatsu reads as intentional; a dark one
        -- reads as broken.
        shuttered = true,
    },
    { id = "judgement", wall = "east", x = -18.13, y = 120.5, z = 70.00, w = 12, h = 7, rows = 8, cols = 22 },
    -- North, west of the mouth: the form guide, last thing seen on the way out.
    { id = "world", wall = "north", x = -45.00, y = 120.5, z = 62.30, w = 12, h = 7, rows = 6, cols = 22 },
    -- North, east of the mouth: the personal slip. Paper-and-wood against stone, per-viewer.
    { id = "fuda", wall = "north", x = -21.60, y = 119.0, z = 62.30, w = 6, h = 6, rows = 7, cols = 16 },
    -- The clerestory band (section 6.3). One line, four segments, the top 4 studs nothing else wants.
    { id = "bandNorth", wall = "north", x = -37.90, y = BAND_Y, z = 62.30, w = 38, h = BAND_H, rows = 1, cols = BAND_COLS },
    { id = "bandSouth", wall = "south", x = -37.90, y = BAND_Y, z = 84.92, w = 38, h = BAND_H, rows = 1, cols = BAND_COLS },
    { id = "bandWest", wall = "west", x = -57.70, y = BAND_Y, z = 73.60, w = 21, h = BAND_H, rows = 1, cols = BAND_COLS },
    { id = "bandEast", wall = "east", x = -18.13, y = BAND_Y, z = 73.60, w = 21, h = BAND_H, rows = 1, cols = BAND_COLS },
} :: { Board }

-- CFrame.Angles(0, rad(yaw), 0).LookVector == (-sin yaw, 0, -cos yaw), and a SurfaceGui on
-- NormalId.Front renders on the LookVector face. These are the yaws that turn each wall's face
-- into the room. Derived once, here, because getting it wrong renders every board into rock.
local YAW = { north = 180, south = 0, west = -90, east = 90 }
function StatsRoomLayout.yawFor(wall: string): number
    return YAW[wall] or 0
end

-- Which way the room lies from each wall plane, along that wall's normal axis.
local INWARD = { north = 1, south = -1, west = 1, east = -1 }
function StatsRoomLayout.inwardFor(wall: string): number
    return INWARD[wall] or 1
end

-- THE BORE ALIASES, SO THE NOMINAL PLANE IS NOT THE ROCK. Terrain is 4-stud voxels and the owner
-- hand-shaped the cut afterwards, so a board pinned to the nominal wall can end up buried or
-- floating. The Studio tool casts a ray from `castBack` studs OUTSIDE the plane; this turns the
-- hit distance into a seated coordinate, clamped so a ray that escapes through a gap cannot fling
-- a board across the room. A missing hit keeps the nominal plane plus the standoff.
StatsRoomLayout.CAST_BACK = 3.0
function StatsRoomLayout.seat(nominal: number, hitDistance: number?, inward: number, maxAdjust: number): number
    if hitDistance == nil then
        return nominal + inward * StatsRoomLayout.STANDOFF
    end
    local rock = nominal + inward * (hitDistance - StatsRoomLayout.CAST_BACK)
    local adjust = math.clamp(rock - nominal, -maxAdjust, maxAdjust)
    return nominal + adjust + inward * StatsRoomLayout.STANDOFF
end

function StatsRoomLayout.check(): (boolean, { string })
    local failures: { string } = {}
    local R = StatsRoomLayout.ROOM
    for _, b in StatsRoomLayout.BOARDS do
        local half = b.w / 2
        local lo, hi, loLim, hiLim
        if b.wall == "north" or b.wall == "south" then
            lo, hi, loLim, hiLim = b.x - half, b.x + half, R.xW, R.xE
        else
            lo, hi, loLim, hiLim = b.z - half, b.z + half, R.zN, R.zS
        end
        if lo < loLim or hi > hiLim then
            table.insert(failures, `{b.id} runs off the {b.wall} wall`)
        end
        if b.y - b.h / 2 < R.floorY or b.y + b.h / 2 > R.ceilingY then
            table.insert(failures, `{b.id} runs through the floor or ceiling`)
        end
        local D = StatsRoomLayout.DOOR
        if b.wall == "north" and b.y - b.h / 2 < D.top then
            if b.x - half < D.x + D.halfWidth and b.x + half > D.x - D.halfWidth then
                table.insert(failures, `{b.id} covers the tunnel mouth`)
            end
        end
        if b.rows < 1 or b.cols < 1 then
            table.insert(failures, `{b.id} has an empty grid`)
        end
    end
    return #failures == 0, failures
end

return StatsRoomLayout
```

- [ ] **Step 4: Run tests**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Write the Studio tool**

Create `roblox/tools/studio/buildStatsBoards.luau`. Studio tools in this repo are run by
pasting into the Studio command bar, so it uses `require(game.ReplicatedStorage...)` for
shared modules and prints a report rather than returning one.

```luau
--!strict
-- Builds the Stats room's board parts, in the bored cavern, from StatsRoomLayout.
-- PASTE INTO THE STUDIO COMMAND BAR. Idempotent: re-running replaces the folder wholesale.
--
-- Place-only geometry (Workspace.CanyonWorld.Structures.StatsBoards) — Rojo manages only what
-- default.project.json names, and this is not in it. Ship by SAVING/PUBLISHING THE PLACE, never
-- by `rojo build`, which would drop every part this creates.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("StatsRoomLayout"))

local MAX_ADJUST = 2.5

local ok, failures = Layout.check()
if not ok then
    for _, f in failures do
        warn(`[statsBoards] LAYOUT FAILURE: {f}`)
    end
    error("[statsBoards] layout invariants failed — nothing built")
end

local world = workspace:FindFirstChild("CanyonWorld") or error("Workspace.CanyonWorld missing")
local structures = world:FindFirstChild("Structures") or error("CanyonWorld.Structures missing")
local existing = structures:FindFirstChild("StatsBoards")
if existing then
    existing:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "StatsBoards"
folder.Parent = structures

local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { workspace.Terrain }

local report: { string } = {}
for _, b in Layout.BOARDS do
    local inward = Layout.inwardFor(b.wall)
    local horizontal = b.wall == "north" or b.wall == "south"
    local nominal = if horizontal then b.z else b.x
    -- Cast from CAST_BACK studs OUTSIDE the nominal plane, straight along the inward normal.
    local axis = if horizontal then Vector3.new(0, 0, inward) else Vector3.new(inward, 0, 0)
    local start = Vector3.new(b.x, b.y, b.z) - axis * Layout.CAST_BACK
    local hit = workspace:Raycast(start, axis * (Layout.CAST_BACK + MAX_ADJUST + 2), rc)
    local seated = Layout.seat(nominal, hit and hit.Distance or nil, inward, MAX_ADJUST)

    local part = Instance.new("Part")
    part.Name = b.id
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Material = Enum.Material.WoodPlanks
    part.Color = Color3.fromRGB(74, 58, 40) -- dark timber frame; the flap cells supply the ivory
    part.Size = Vector3.new(b.w, b.h, Layout.THICKNESS)
    local px = if horizontal then b.x else seated
    local pz = if horizontal then seated else b.z
    part.CFrame = CFrame.new(px, b.y, pz) * CFrame.Angles(0, math.rad(Layout.yawFor(b.wall)), 0)
    part:SetAttribute("BoardId", b.id)
    part:SetAttribute("Rows", b.rows)
    part:SetAttribute("Cols", b.cols)
    part:SetAttribute("Shuttered", b.shuttered == true)
    CollectionService:AddTag(part, Layout.TAG)
    part.Parent = folder

    if b.shuttered then
        -- Section 8: a closed board, not a dark one. Two leaves meeting at the centre.
        for i, sign in { -1, 1 } do
            local leaf = Instance.new("Part")
            leaf.Name = `Shutter{i}`
            leaf.Anchored = true
            leaf.CanCollide = false
            leaf.CastShadow = false
            leaf.Material = Enum.Material.WoodPlanks
            leaf.Color = Color3.fromRGB(96, 78, 56)
            leaf.Size = Vector3.new(b.w / 2 - 0.05, b.h - 0.1, 0.25)
            leaf.CFrame = part.CFrame * CFrame.new(sign * b.w / 4, 0, -(Layout.THICKNESS / 2 + 0.13))
            leaf.Parent = part
        end
    end

    table.insert(report, `{b.id}: {b.wall} seated {string.format("%.2f", seated)} (nominal {nominal}) hit={hit ~= nil}`)
end

print("[statsBoards] built " .. #Layout.BOARDS .. " boards")
for _, line in report do
    print("  " .. line)
end
print("[statsBoards] SAVE/PUBLISH THE PLACE — these parts are place-only and rojo build drops them.")
```

- [ ] **Step 6: Format, lint, test**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run`
Expected: clean and green.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/StatsRoomLayout.luau roblox/tests/StatsRoomLayout.spec.luau roblox/tools/studio/buildStatsBoards.luau
git commit -m "feat(roblox): the Stats room's board inventory, and the tool that seats it against the rock"
```

---

### Task 4: The stats feed — `NetworkClient` getters, two remotes, one poller

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau` (append beside the other getters, ~line 128)
- Modify: `roblox/tests/NetworkClient.spec.luau`
- Modify: `roblox/default.project.json` (RoshamboRemotes folder, ~line 42)
- Modify: `roblox/src/server/main.server.luau` (beside the existing BoardData poller, ~line 672)

**Interfaces:**
- Consumes: `NetworkClient._request(method, path, body)` — existing, retry/backoff already inside.
- Produces:
  - `NetworkClient:getStatsRecords(window: string): Result`
  - `NetworkClient:getStatsHeat(window: string, instanceId: string?): Result`
  - `NetworkClient:getStatsPlayer(robloxUserId: string): Result`
  - RemoteEvent `StatsData` — broadcast: `{ leaders, recordsWeek, recordsAll, heat, tape }`
  - RemoteEvent `StatsPersonal` — per-player: the `/api/v1/stats/player/:id` payload verbatim

**Context an implementer cannot infer:** `/api/v1/stats` is mounted BEFORE the API-key gate
(`server/src/routes/mount.ts` — the order is load-bearing and has its own test), so these three
endpoints need no key. `_request` sends `X-API-Key` on everything anyway; that is harmless. The
existing `BoardData` poller at `main.server.luau:672-706` is the pattern to copy — a `task.spawn`
loop with `task.wait`, caching its last payload so `PlayerAdded` can replay it to a late joiner.

- [ ] **Step 1: Write the failing tests**

Append to `roblox/tests/NetworkClient.spec.luau`:

```luau
describe("stats endpoints", function()
    test("records asks for the window it was given", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"longestStreaks":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        local res = net:getStatsRecords("week")
        expect(res.ok).toBe(true)
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/records?window=week")
        expect(m.calls[1].method).toBe("GET")
    end)

    test("heat scopes to an instance when one is supplied, and stays global when it is not", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"leaders":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        net:getStatsHeat("hour", "job-7")
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/heat?window=hour&instanceId=job-7")
        net:getStatsHeat("hour", nil)
        expect(m.calls[2].url).toBe("http://x/api/v1/stats/heat?window=hour")
    end)

    test("an empty instanceId is treated as global, not sent as a blank scope", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"leaders":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        net:getStatsHeat("day", "")
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/heat?window=day")
    end)

    test("player stats are fetched by roblox user id", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"displayName":"Ayaka"}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        local res = net:getStatsPlayer("12345")
        expect(res.ok).toBe(true)
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/player/12345")
    end)

    test("a 404 from player stats is reported, not thrown — a player with no account is normal", function()
        local m = makeDeps({ { ok = true, statusCode = 404, body = '{"error":"NOT_FOUND"}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        expect(net:getStatsPlayer("999").ok).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `getStatsRecords` is not a method.

- [ ] **Step 3: Add the three getters**

Append to `roblox/src/server/NetworkClient.luau`, immediately after `getLeaderboards`:

```luau
-- /api/v1/stats is mounted AHEAD of the X-API-Key gate (server/src/routes/mount.ts) because these
-- boards read nothing a player could mutate. The key still rides along on _request; it is ignored.
function NetworkClient.getStatsRecords(self: any, window: string): Result
    return self:_request("GET", `/api/v1/stats/records?window={window}`)
end

function NetworkClient.getStatsHeat(self: any, window: string, instanceId: string?): Result
    local path = `/api/v1/stats/heat?window={window}`
    -- An EMPTY instanceId must not be sent: the route reads it as a scope and would resolve the
    -- presence set for the instance named "", returning an empty board instead of the global one.
    if instanceId and instanceId ~= "" then
        path ..= `&instanceId={instanceId}`
    end
    return self:_request("GET", path)
end

function NetworkClient.getStatsPlayer(self: any, robloxUserId: string): Result
    return self:_request("GET", `/api/v1/stats/player/{robloxUserId}`)
end
```

- [ ] **Step 4: Declare the remotes**

In `roblox/default.project.json`, inside `RoshamboRemotes`, after `"RequestSync"`:

```json
                "RequestSync": { "$className": "RemoteEvent" },
                "StatsData": { "$className": "RemoteEvent" },
                "StatsPersonal": { "$className": "RemoteEvent" }
```

- [ ] **Step 5: Add the poller**

In `roblox/src/server/main.server.luau`, beside the remote handles at the top (~line 77):

```luau
local StatsData = remotes:WaitForChild("StatsData") :: RemoteEvent
local StatsPersonal = remotes:WaitForChild("StatsPersonal") :: RemoteEvent
```

And after the existing `BoardData` poller block (~line 706):

```luau
-- THE STATS ROOM'S FEED. Separate from the BoardData poller above on purpose: that one is the
-- arena's 30s heartbeat and these are four REST reads whose own Cache-Control is 15-30s, so
-- pulling them on the same tick would triple the arena's request rate for walls nobody may be
-- standing in front of. 60s is slower than any of the caches and still far finer than the
-- cadence at which a career board actually moves.
local lastStats: any = nil
task.spawn(function()
    while true do
        local leaders = net:getLeaderboards("world")
        local week = net:getStatsRecords("week")
        local all = net:getStatsRecords("all")
        local heat = net:getStatsHeat("day", nil)
        -- Each field is independently nil-able: one endpoint failing must leave the other three
        -- boards showing their last good content rather than blanking the whole room.
        lastStats = {
            leaders = if leaders.ok then leaders.data.leaders else (lastStats and lastStats.leaders),
            recordsWeek = if week.ok then week.data else (lastStats and lastStats.recordsWeek),
            recordsAll = if all.ok then all.data else (lastStats and lastStats.recordsAll),
            heat = if heat.ok then heat.data else (lastStats and lastStats.heat),
            tape = lastTape,
        }
        StatsData:FireAllClients(lastStats)
        task.wait(60)
    end
end)

-- The personal slip. Per-player, so it is pushed per-player: on join, and on the same 60s beat.
local function pushStatsPersonal(player: Player)
    local res = net:getStatsPlayer(tostring(player.UserId))
    -- A 404 is the NORMAL state for someone who has never thrown. Send the empty shape rather
    -- than nothing, so the slip renders its zeros instead of hanging on "no data".
    StatsPersonal:FireClient(player, if res.ok then res.data else { displayName = player.DisplayName })
end

Players.PlayerAdded:Connect(function(player)
    if lastStats then
        StatsData:FireClient(player, lastStats)
    end
    task.spawn(pushStatsPersonal, player)
end)

task.spawn(function()
    while true do
        task.wait(60)
        for _, player in Players:GetPlayers() do
            task.spawn(pushStatsPersonal, player)
        end
    end
end)
```

- [ ] **Step 6: Run tests, format, lint**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau roblox/default.project.json roblox/src/server/main.server.luau
git commit -m "feat(roblox): the Stats room's data feed — three stats getters, two remotes, one poller"
```

---

### Task 5: `StatsController` — tags to boards to lines, with a fixtures toggle

**Files:**
- Create: `roblox/src/shared/StatsFixtures.luau`
- Create: `roblox/src/client/StatsController.client.luau`

**Interfaces:**
- Consumes: `StatsRoomLayout.TAG`, `StatsBoardModel.*` (Task 1), `FlapBoard.new` (Task 2),
  `StatsData` / `StatsPersonal` RemoteEvents (Task 4).
- Produces: `StatsFixtures.STATS` and `StatsFixtures.PERSONAL` — payloads shaped exactly like
  the two remotes carry, used by Task 6 as well.

**Ruling R2 in force here:** the boards are empty until people play (`StreakEvent`/`BankEvent`
start from deploy, no backfill). `workspace:SetAttribute("StatsFixtures", true)` in Studio makes
every board render seeded content instead, so layout and legibility can be judged now. The toggle
is read live, so flipping it repaints without a rejoin.

**This controller handles the four content boards only.** The four `band*` boards carry the same
tag and are skipped here; Task 6 drives them.

- [ ] **Step 1: Write the fixtures**

Create `roblox/src/shared/StatsFixtures.luau`:

```luau
--!strict
-- Seeded payloads shaped EXACTLY like the StatsData / StatsPersonal remotes carry, so a Studio
-- session can judge board layout before any real play exists (plan ruling R2). Names are
-- deliberately awkward — long, short, mixed-case, off-drum characters — because the point of a
-- fixture is to exercise the formatting, not to look tidy.
local StatsFixtures = {}

local function streak(name: string, length: number)
    return { displayName = name, length = length, endedBy = "LOSS" }
end

StatsFixtures.STATS = {
    leaders = {
        { displayName = "Ayaka", lifetimeBanked = 12480 },
        { displayName = "kenshin_the_unbanked", lifetimeBanked = 9310 },
        { displayName = "Mo", lifetimeBanked = 4005 },
        { displayName = "\u{7530}\u{4E2D}", lifetimeBanked = 812 },
        { displayName = "zero", lifetimeBanked = 0 },
    },
    recordsWeek = {
        window = "week",
        windowKind = "calendar",
        longestStreaks = { streak("Ayaka", 9), streak("Mo", 7), streak("kenshin_the_unbanked", 5) },
        biggestBanks = {
            { displayName = "Ayaka", amount = 6561, streakAtBank = 8 },
            { displayName = "Mo", amount = 2187, streakAtBank = 7 },
        },
        biggestRounds = { { displayName = "Ayaka", points = 4374 }, { displayName = "Mo", points = 1458 } },
    },
    recordsAll = {
        window = "all",
        windowKind = "rolling",
        longestStreaks = { streak("Mo", 12), streak("Ayaka", 11), streak("\u{7530}\u{4E2D}", 9) },
        biggestBanks = {},
        biggestRounds = {},
    },
    heat = {
        kind = "heat",
        qualified = false,
        window = "day",
        windowKind = "rolling",
        scope = "global",
        leaders = { { displayName = "Mo", earned = 810 }, { displayName = "Ayaka", earned = 486 } },
    },
    tape = {
        { worldThrow = "R" },
        { worldThrow = "S" },
        { worldThrow = "S" },
        { worldThrow = "P" },
        { worldThrow = "R" },
        { worldThrow = "P" },
        { worldThrow = "S" },
        { worldThrow = "R" },
        { worldThrow = "R" },
        { worldThrow = "P" },
    },
}

StatsFixtures.PERSONAL = {
    displayName = "Ayaka",
    career = { banked = 12480, bestStreak = 11 },
    currentStreak = 3,
    week = { throws = 142, qualifyAt = 350, qualified = false, roundsPresent = 210, participationRate = 0.68 },
}

return StatsFixtures
```

- [ ] **Step 2: Write the controller**

Create `roblox/src/client/StatsController.client.luau`:

```luau
--!strict
-- The Stats room's four content walls. Finds its boards by CollectionService tag (they are
-- place-only geometry — Rojo manages only what default.project.json names), builds one FlapBoard
-- per tagged part, and repaints whenever data or the fixtures toggle changes.
--
-- PER-VIEWER COMES FREE (spec section 6.1): this is a LocalScript, so every SurfaceGui it parents
-- to a world part exists only on this client. The `fuda` slip is private for that reason alone —
-- no Adornee, no PlayerGui, no new mechanism.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout = require(shared:WaitForChild("StatsRoomLayout"))
local Model = require(shared:WaitForChild("StatsBoardModel"))
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local StatsFixtures = require(shared:WaitForChild("StatsFixtures"))
local FlapBoard = require(script.Parent:WaitForChild("FlapBoard"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local StatsData = remotes:WaitForChild("StatsData") :: RemoteEvent
local StatsPersonal = remotes:WaitForChild("StatsPersonal") :: RemoteEvent

local FIXTURE_ATTR = "StatsFixtures"
-- The band ids belong to RoundBandModel's driver, not to this file. Same tag, different clock.
local function isBand(id: string): boolean
    return id:sub(1, 4) == "band"
end

local boards: { [Instance]: { board: any, id: string, rows: number, cols: number } } = {}
local latestStats: any = nil
local latestPersonal: any = nil

local function useFixtures(): boolean
    return workspace:GetAttribute(FIXTURE_ATTR) == true
end

local function linesFor(id: string, rows: number, cols: number): { string }?
    local o = { rows = rows, cols = cols }
    local s = if useFixtures() then StatsFixtures.STATS else latestStats
    local p = if useFixtures() then StatsFixtures.PERSONAL else latestPersonal
    if id == "banzuke" then
        return Model.compose(Model.standingsSections(s and s.leaders), o)
    elseif id == "skill" then
        return Model.compose(Model.skillSections(s and s.recordsWeek, s and s.recordsAll), o)
    elseif id == "judgement" then
        return Model.compose(Model.judgementSections(s and s.recordsWeek), o)
    elseif id == "world" then
        return Model.compose(Model.worldSections(s and s.tape, s and s.heat), o)
    elseif id == "fuda" then
        return Model.compose(Model.fudaSections(p), o)
    end
    return nil
end

local function repaint(entry: { board: any, id: string, rows: number, cols: number })
    local lines = linesFor(entry.id, entry.rows, entry.cols)
    if lines then
        entry.board:setAll(lines)
    end
end

local function repaintAll()
    for _, entry in boards do
        repaint(entry)
    end
end

local function register(part: Instance)
    if not part:IsA("BasePart") or boards[part] then
        return
    end
    local id = part:GetAttribute("BoardId")
    if typeof(id) ~= "string" or isBand(id) then
        return
    end
    -- A shuttered board is CLOSED, not broken (spec section 8) — it gets no renderer at all, so
    -- there is nothing behind the leaves to leak through if one is ever opened by hand.
    if part:GetAttribute("Shuttered") == true then
        return
    end
    local rows = tonumber(part:GetAttribute("Rows")) or 1
    local cols = tonumber(part:GetAttribute("Cols")) or 1
    local entry = {
        id = id,
        rows = rows,
        cols = cols,
        board = FlapBoard.new({
            part = part,
            rows = rows,
            cols = cols,
            -- Aspect from the PART, not from the layout table: the Studio tool seats each board
            -- against measured rock and an owner may nudge one afterwards. Reading the part keeps
            -- the canvas matched to whatever is actually there, so glyphs never stretch.
            metrics = Model.metrics(rows, cols, part.Size.X / part.Size.Y),
            plan = FlapScheduler.plan,
        }),
    }
    boards[part] = entry
    repaint(entry)
end

local function unregister(part: Instance)
    local entry = boards[part]
    if entry then
        entry.board:destroy()
        boards[part] = nil
    end
end

for _, part in CollectionService:GetTagged(Layout.TAG) do
    register(part)
end
CollectionService:GetInstanceAddedSignal(Layout.TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(Layout.TAG):Connect(unregister)

StatsData.OnClientEvent:Connect(function(data)
    latestStats = data
    repaintAll()
end)

StatsPersonal.OnClientEvent:Connect(function(data)
    latestPersonal = data
    repaintAll()
end)

-- Live, so the owner can flip fixtures on and off in Studio and watch the walls change without
-- rejoining. Costs one attribute listener.
workspace:GetAttributeChangedSignal(FIXTURE_ATTR):Connect(repaintAll)
```

- [ ] **Step 3: Format, lint, test**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run`
Expected: clean and green.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/shared/StatsFixtures.luau roblox/src/client/StatsController.client.luau
git commit -m "feat(roblox): the Stats room's four content walls, with a Studio fixtures toggle"
```

---

### Task 6: The clerestory round band

**Files:**
- Create: `roblox/src/shared/RoundBandModel.luau`
- Create: `roblox/src/client/RoundBandController.client.luau`
- Test: `roblox/tests/RoundBandModel.spec.luau`

**Interfaces:**
- Consumes: `StatsRoomLayout.TAG` + the `band*` board ids (Task 3), `FlapBoard.new` (Task 2),
  `StatsBoardModel.GLYPH` (Task 1).
- Produces: `RoundBandModel.line(state: State, cols: number): string` where
  `State = { phase: string?, secondsLeft: number?, worldThrow: string?, worldRested: boolean?, ownThrow: string? }`

**Why this is a requirement, not a convenience (spec §6.3):** the room is under ~18 studs of
rock, out of sight and earshot of the taiko drum that is the round's authoritative signal.
Without the band, walking in here means silently dropping out of the game.

**Ruling R6 — a dropped `drumRest` costs the band its world throw, and that is the correct
failure.** `main.client.luau` and `TheaterController` each carry strike-tracking backstops that
release a reveal whose `drumRest` never came; both are ~40 lines and one of them is explicitly a
deliberate duplicate of the other. The band does not get a third copy. It shows `REVEAL` for that
round and clears at the next OPEN — it fails to under-report, never to spoil, which is the only
direction the drum rule permits.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/RoundBandModel.spec.luau`:

```luau
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
        expect(B.line({ phase = "OPEN", secondsLeft = 34, ownThrow = "R" }, 16)).toBe("OPEN 34S   YOU \u{25CB}")
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
        expect(B.line({ phase = "REVEAL", worldThrow = "S", worldRested = true, ownThrow = "P" }, 16))
            .toBe("WORLD \u{2227}    YOU \u{2500}")
    end)

    test("clamps the countdown rather than overrunning the field", function()
        expect(B.line({ phase = "OPEN", secondsLeft = 4000 }, 16)).toBe("OPEN 99S   YOU -")
        expect(B.line({ phase = "OPEN", secondsLeft = -3 }, 16)).toBe("OPEN 0S    YOU -")
    end)

    test("with no schedule yet it says so instead of printing a false countdown", function()
        expect(B.line({}, 16)).toBe("WAITING    YOU -")
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `RoundBandModel` does not exist.

- [ ] **Step 3: Write the model**

Create `roblox/src/shared/RoundBandModel.luau`:

```luau
--!strict
-- The clerestory band's single line (spec section 6.3). Pure, so the drum rule below is pinned by
-- a test rather than by a reviewer's attention.
--
-- THE DRUM RULE LIVES HERE (owner, 2026-08-04): the world throw is named only when
-- `worldRested` is true. Every previous display that reflected the throw off the wire instead of
-- off `drumRest` — the result splash, the ring glyph, the points plate, BoardController's dead
-- row — spoiled it by about three seconds and had to be corrected. Making it a parameter of a
-- pure function is how this one cannot.
local RoundBandModel = {}

RoundBandModel.GLYPH = { R = "○", P = "─", S = "∧" }
RoundBandModel.NO_THROW = "-"

export type State = {
    phase: string?,
    secondsLeft: number?,
    worldThrow: string?,
    worldRested: boolean?,
    ownThrow: string?,
}

local function padRight(s: string, n: number): string
    local w = 0
    for _ in utf8.codes(s) do
        w += 1
    end
    if w >= n then
        local out, i = {}, 0
        for _, code in utf8.codes(s) do
            i += 1
            if i > n then
                break
            end
            table.insert(out, utf8.char(code))
        end
        return table.concat(out)
    end
    return s .. string.rep(" ", n - w)
end

function RoundBandModel.line(state: State, cols: number): string
    local own = RoundBandModel.GLYPH[state.ownThrow or ""] or RoundBandModel.NO_THROW
    local right = `YOU {own}` -- 5 columns
    local leftW = math.max(1, cols - 1 - 5)

    local left: string
    local phase = state.phase
    if phase == "REVEAL" then
        -- The gate. `worldRested` is set from EventBus.Cue kind == "drumRest" and from nothing else.
        if state.worldRested and state.worldThrow then
            left = `WORLD {RoundBandModel.GLYPH[state.worldThrow] or "?"}`
        else
            left = "REVEAL"
        end
    elseif phase == "OPEN" or phase == "LOCK" then
        local secs = math.clamp(math.floor(state.secondsLeft or 0), 0, 99)
        left = `{phase} {secs}S`
    else
        -- No schedule replicated yet, or a phase this build does not know. Saying so beats
        -- printing a countdown the room would be right to trust.
        left = "WAITING"
    end

    return padRight(left, leftW) .. " " .. right
end

return RoundBandModel
```

- [ ] **Step 4: Run tests**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Write the controller**

Create `roblox/src/client/RoundBandController.client.luau`:

```luau
--!strict
-- Drives the four clerestory band segments (spec section 6.3). Separate from StatsController
-- because it runs on a different clock: the walls repaint on a 60s poll, the band ticks every
-- half-second off the same published schedule the HUD reads.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local Layout = require(shared:WaitForChild("StatsRoomLayout"))
local Model = require(shared:WaitForChild("StatsBoardModel"))
local BandModel = require(shared:WaitForChild("RoundBandModel"))
local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))
local FlapScheduler = require(shared:WaitForChild("FlapScheduler"))
local FlapBoard = require(script.Parent:WaitForChild("FlapBoard"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RevealTheater = remotes:WaitForChild("RevealTheater") :: RemoteEvent

local segments: { [Instance]: { board: any, cols: number } } = {}
local metronome = RoundMetronome.new()
local pendingWorldThrow: string? = nil
local worldRested = false
local ownThrow: string? = nil
local lastLine: string? = nil

local function register(part: Instance)
    if not part:IsA("BasePart") or segments[part] then
        return
    end
    local id = part:GetAttribute("BoardId")
    if typeof(id) ~= "string" or id:sub(1, 4) ~= "band" then
        return
    end
    local rows = tonumber(part:GetAttribute("Rows")) or 1
    local cols = tonumber(part:GetAttribute("Cols")) or 1
    segments[part] = {
        cols = cols,
        board = FlapBoard.new({
            part = part,
            rows = rows,
            cols = cols,
            metrics = Model.metrics(rows, cols, part.Size.X / part.Size.Y),
            plan = FlapScheduler.plan,
        }),
    }
end

for _, part in CollectionService:GetTagged(Layout.TAG) do
    register(part)
end
CollectionService:GetInstanceAddedSignal(Layout.TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(Layout.TAG):Connect(function(part)
    local seg = segments[part]
    if seg then
        seg.board:destroy()
        segments[part] = nil
    end
end)

-- Same source the HUD's countdown uses (main.client.luau's `pullSchedule`): the replicated
-- RoundScheduleConfig attributes, read through RoundMetronome so the band slews with the HUD
-- rather than drifting against it.
task.spawn(function()
    local cfg = ReplicatedStorage:WaitForChild("RoundScheduleConfig")
    local function pull()
        local strikeAt = cfg:GetAttribute("StrikeAtServerTime")
        local periodSec = cfg:GetAttribute("PeriodSec")
        if typeof(strikeAt) ~= "number" or typeof(periodSec) ~= "number" then
            return
        end
        metronome:setSchedule({
            roundId = cfg:GetAttribute("RoundId") :: string?,
            strikeAt = strikeAt,
            periodSec = periodSec,
            openSec = (cfg:GetAttribute("OpenSec") :: number?) or 51,
            lockSec = (cfg:GetAttribute("LockSec") :: number?) or 2,
            revealSec = (cfg:GetAttribute("RevealSec") :: number?) or 7,
        }, workspace:GetServerTimeNow())
    end
    pull()
    for _, attr in { "StrikeAtServerTime", "PeriodSec", "RoundId", "OpenSec", "LockSec", "RevealSec" } do
        cfg:GetAttributeChangedSignal(attr):Connect(pull)
    end
end)

EventBus.HudPick.Event:Connect(function(sym: string)
    ownThrow = sym
end)

RevealTheater.OnClientEvent:Connect(function(r)
    -- STASHED, NOT SHOWN. RevealTheater lands at the top of REVEAL and the drum does not settle
    -- until DrumStep.SETTLE_SECONDS after the strike; painting here would name the throw about
    -- three seconds before the drum does. This is the exact defect the retired BoardController
    -- carried (plan ruling R1).
    pendingWorldThrow = r.worldThrow
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "drumRest" then
        worldRested = true
    end
end)

-- Half-second cadence: fast enough that the seconds field is never visibly stale, slow enough
-- that the flap cells are not asked to re-plan mid-roll. Nothing is sent to a board unless the
-- composed line actually changed, so a still second costs one string compare.
local accumulator = 0
RunService.Heartbeat:Connect(function(dt: number)
    accumulator += dt
    if accumulator < 0.5 then
        return
    end
    accumulator = 0
    local reading = metronome:read(workspace:GetServerTimeNow())
    if reading and reading.phase == "OPEN" then
        -- A new OPEN is the round boundary: clear last round's throw, world and own alike.
        if worldRested or pendingWorldThrow then
            pendingWorldThrow, worldRested, ownThrow = nil, false, nil
        end
    end
    local line = BandModel.line({
        phase = reading and reading.phase,
        secondsLeft = reading and reading.secondsLeft,
        worldThrow = pendingWorldThrow,
        worldRested = worldRested,
        ownThrow = ownThrow,
    }, 16)
    if line == lastLine then
        return
    end
    lastLine = line
    for _, seg in segments do
        seg.board:setRow(1, line)
    end
end)
```

- [ ] **Step 6: Format, lint, test**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run`
Expected: clean and green.

- [ ] **Step 7: Commit**

```bash
git add roblox/src/shared/RoundBandModel.luau roblox/tests/RoundBandModel.spec.luau roblox/src/client/RoundBandController.client.luau
git commit -m "feat(roblox): the Stats room's clerestory round band, gated on the drum"
```

---

## Studio gate (owner, not the implementer)

After Task 6, the boards exist in code but not in the place. The owner runs, in Studio:

```
-- command bar, from roblox/tools/studio/buildStatsBoards.luau
```

then `workspace:SetAttribute("StatsFixtures", true)` to fill the walls with seeded content,
walks the room, and judges legibility. **Do not take screenshots** — the owner chooses the
camera. Report that the tool ran and what it printed; stop there.

Two things the owner should be told to check, because only they can:
1. Whether the boards are seated proud of the rock everywhere, or buried where the hand-shaping
   pushed the wall in. The tool prints `seated`, `nominal` and `hit` per board — a board with
   `hit=false` fell back to nominal and is the likely offender.
2. Whether the band's 16 columns read from the far corner. It is the one number in this plan
   chosen for feel rather than derived, and it is a one-line change in `StatsRoomLayout`.

After the gate, save/publish the place — these parts are place-only and `rojo build` drops them.

---

## Deliberately NOT in this plan (spec §6.2 items, deferred with reasons)

Both are spec requirements. Neither is dropped — they are named here so the gap is visible
rather than discovered later as an omission.

- **The 番付 as a printed sheet with rank encoded by calligraphy size.** §6.2 asks for a
  regenerated sheet that "reads as one image from the door", not a flap board. That is a
  different renderer entirely — composed labels or a generated texture on a slow cadence — with
  no split-flap cells in it. Building the south wall as a flap board first gets the standings
  live and legible; the sheet treatment is an art pass over the same tagged part, and needs no
  data work. **This is the owner's call to make at the Studio gate**, and the substitution is
  visible there: if the flap sheet reads well enough, the art pass may never be worth it.
- **Avatar plinths for the top three.** Feasible — `LEADERBOARD_FIELDS` already carries
  `robloxId` — but it is rig assembly plus `GetHumanoidDescriptionFromUserId` calls with their
  own failure and perf profile, and it shares nothing with the board machinery this plan builds.
  It belongs beside the room, after the walls are judged.

## Ordering notes for the executor

Tasks 1→6 are in dependency order and none can be usefully reordered:

- Task 2 imports `Metrics` from Task 1.
- Task 3's Studio tool is unrunnable until the module it reads exists — but it is also
  unrunnable in this session at all (Studio is the owner's). Ship the code; the owner runs it.
- Task 5 needs Tasks 1-4: the model, the renderer, the tag contract, and the remotes.
- Task 6 reuses Task 2's renderer against Task 3's `band*` parts and Task 1's `metrics`.

Nothing in this plan can be verified visually by the implementer. Headless coverage
(`lune run tests/run`) proves the arithmetic, the drum rule, the formatting and the layout
invariants; everything else is the owner's Studio gate.
