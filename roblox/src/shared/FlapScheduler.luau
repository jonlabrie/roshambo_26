--!strict
-- Plans split-flap transitions: which cell flips when, cycling through the
-- character drum to its target (spec §4.2). Pure — the client controller
-- executes the schedule with tweens and clacks.
local FlapScheduler = {}

FlapScheduler.DRUM = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.!?+%○─∧"

export type Step = { col: number, atMs: number, char: string, isFinal: boolean }
export type Opts = { stepMs: number?, staggerMs: number?, drum: string? }

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
            for k = 1, count do
                table.insert(steps, {
                    col = col,
                    atMs = (col - 1) * staggerMs + (k - 1) * stepMs,
                    char = drum[(ci + k - 1) % n + 1],
                    isFinal = k == count,
                })
            end
        end
    end
    return steps
end

return FlapScheduler
