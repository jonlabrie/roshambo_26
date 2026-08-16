--!strict
-- Plans split-flap transitions: which cell flips when, cycling through the
-- character drum to its target (spec §4.2). Pure — the client controller
-- executes the schedule with tweens and clacks.
local FlapScheduler = {}

-- Punctuation sits BEFORE the ○─∧ glyph block on purpose: the glyphs stay contiguous at
-- the drum's end so ∧ still wraps straight to the leading space (pinned by a test).
FlapScheduler.DRUM = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.!?+%-:/○─∧"

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

function FlapScheduler.plan(current: string, target: string, opts: Opts?): { Step }
    local o = opts or {}
    local stepMs = o.stepMs or 83 -- ~12 steps/sec
    local staggerMs = o.staggerMs or 60
    local maxSteps = math.max(1, o.maxSteps or DEFAULT_MAX_STEPS)
    local drum = toChars(o.drum or FlapScheduler.DRUM)
    local index: { [string]: number } = {}
    for i, ch in drum do
        index[ch] = i
    end

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
