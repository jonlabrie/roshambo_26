--!strict
-- Plans split-flap transitions: which cell flips when, cycling through the
-- character drum to its target (spec §4.2). Pure — the client controller
-- executes the schedule with tweens and clacks.
local FlapScheduler = {}

-- Punctuation sits BEFORE the ○─∧ glyph block on purpose: the glyphs stay contiguous at
-- the drum's end so ∧ still wraps straight to the leading space (pinned by a test).
FlapScheduler.DRUM = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.!?+%-:/○─∧"

-- ===== THE DRUM LADDER (owner, 2026-08-18) =====
-- The clock solved this by bolting a drum to each COLUMN (`RoundDisplayModel.drums`), which
-- works because a clock column has a fixed kind -- column 3 is always a tens digit. A wall
-- board column has no kind at all: `1. JONNY        1,234` holds a digit in one row, a space in
-- the next and a letter in the third, and it all moves when the window changes. So the drum is
-- chosen from the TRANSITION instead: the smallest drum carrying BOTH characters.
--
-- WHY SMALLEST-FIRST AND NOT ONE NUMERIC DRUM. `maxSteps` caps a roll at 9, and on the
-- 49-character drum a changed cell clears that cap ~82% of the time -- which is the ~750ms
-- roll that never settles. A smaller drum does not remove the cap, it just fires it less, and
-- the shrink has to be big to pay: `7 -> 3` is 45 steps on the full drum and still 11 on a
-- 15-character numeric one, capped either way. On a TEN-character drum it is 6, and the
-- greatest distance possible is 9 -- exactly the cap -- so no digit transition is ever
-- truncated and the jump-cut cheat goes quiet. Every character added to a rung costs steps on
-- every transition that uses it, which is why digits get a rung of their own.
FlapScheduler.DIGITS = "0123456789"

-- Rung 2 catches the cells where a figure meets its punctuation -- `1,234 -> 12,345` walks the
-- comma across a column, and without this that one cell rolls the alphabet mid-number while its
-- neighbours do not. Contents are what the boards actually print (`StatsBoardModel.figure` emits
-- digits, `,` and a leading `-`; `pct` adds `%` and a bare `-` for a round with no throws; the
-- weekly quota adds `/`; padding adds the space) PLUS `+` and `.` as headroom (owner,
-- 2026-08-18): nothing emits them today, and reserving them here means a signed delta or a
-- decimal costs nothing on rung 1 when it arrives.
FlapScheduler.FIGURES = "0123456789+-.,%/ "

-- Ordered smallest to largest. `drumFor` returns the first rung carrying both characters, so a
-- rung is only ever paid for by transitions that need it.
local LADDER = { FlapScheduler.DIGITS, FlapScheduler.FIGURES, FlapScheduler.DRUM }

local memberCache: { [string]: { [string]: boolean } } = {}
local function membersOf(drum: string): { [string]: boolean }
    local m = memberCache[drum]
    if not m then
        m = {}
        for _, code in utf8.codes(drum) do
            m[utf8.char(code)] = true
        end
        memberCache[drum] = m
    end
    return m
end

-- The full drum is the floor: a character on no rung at all (anything the sanitizer let past)
-- still plans, because `plan` maps an unknown character to the drum's first position.
function FlapScheduler.drumFor(current: string, target: string): string
    for _, drum in LADDER do
        local m = membersOf(drum)
        if m[current] and m[target] then
            return drum
        end
    end
    return FlapScheduler.DRUM
end

export type Step = { col: number, atMs: number, char: string, isFinal: boolean }
export type Opts = { stepMs: number?, staggerMs: number?, drum: string?, maxSteps: number? }

-- THE CHEAT. A true split-flap must traverse the whole drum, so a worst-case cell would
-- roll 45 characters (~3.8s at the default stepMs) while the reader waits. Instead, cap the
-- run: a capped cell JUMPS to maxSteps before its target and rolls in from there, so it
-- always lands correctly and the shown characters are still a contiguous drum run — the
-- jump is masked by the motion. Short transitions are untouched, so the settle time still
-- varies naturally from cell to cell, which is where the charm lives.
local DEFAULT_MAX_STEPS = 9

local function toChars(s: string): { string }
    local chars: { string } = {}
    for _, code in utf8.codes(s) do
        table.insert(chars, utf8.char(code))
    end
    return chars
end

-- A drum's character array and its reverse index, built once per distinct drum. `plan` used to
-- rebuild both on EVERY call, which cost nothing while a caller planned a whole line at a time.
-- The ladder changed that: a per-column caller plans one cell per call, so a 10x40 board repaint
-- went from 10 index builds to 400. The drums are string constants, so the cache is bounded by
-- how many exist (three).
type DrumInfo = { chars: { string }, index: { [string]: number } }
local drumCache: { [string]: DrumInfo } = {}
local function drumInfo(drum: string): DrumInfo
    local info = drumCache[drum]
    if not info then
        local chars = toChars(drum)
        local index: { [string]: number } = {}
        for i, ch in chars do
            index[ch] = i
        end
        info = { chars = chars, index = index }
        drumCache[drum] = info
    end
    return info
end

function FlapScheduler.plan(current: string, target: string, opts: Opts?): { Step }
    local o = opts or {}
    local stepMs = o.stepMs or 83 -- ~12 steps/sec
    local staggerMs = o.staggerMs or 60
    local maxSteps = math.max(1, o.maxSteps or DEFAULT_MAX_STEPS)
    local info = drumInfo(o.drum or FlapScheduler.DRUM)
    local drum, index = info.chars, info.index

    local cur = toChars(current)
    local tgt = toChars(target)
    local cols = math.max(#cur, #tgt)
    local steps: { Step } = {}

    for col = 1, cols do
        local c = cur[col] or " "
        local t = tgt[col] or " "
        if c ~= t then
            local ci = index[c] or 1
            local ti = index[t] or 1
            local n = #drum
            local count = (ti - ci) % n
            local shown = math.min(count, maxSteps)
            for k = 1, shown do
                -- walk the LAST `shown` positions before the target, so the run always ends on it
                table.insert(steps, {
                    col = col,
                    atMs = (col - 1) * staggerMs + (k - 1) * stepMs,
                    char = drum[(ti - shown + k - 1) % n + 1],
                    isFinal = k == shown,
                })
            end
        end
    end
    return steps
end

return FlapScheduler
