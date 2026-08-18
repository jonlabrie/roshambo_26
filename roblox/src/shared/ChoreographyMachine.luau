--!strict
-- Turns phase changes and reveals into ordered effect cues (spec §6/§8).
-- Pure: the client TheaterController executes cues with task.delay.
local ChoreographyMachine = {}

export type Cue = { atMs: number, kind: string, userId: string?, effect: string?, worldThrow: string? }
export type Opts = {
    staggerMaxMs: number,
    random: () -> number,
    selectEffect: (slot: string, ctx: any) -> string?,
}

local PHASE_CUES: { [string]: { string } } = {
    OPEN = { "lanternsAmbient", "hammerReset", "tickerCountdown" },
    LOCK = { "lanternsDim", "drumrollStart", "heroTileSpin", "tickerCascade" },
    REVEAL = {},
}

function ChoreographyMachine.phaseCues(phase: string): { string }
    return PHASE_CUES[phase] or {}
end

function ChoreographyMachine.revealCues(reveal: any, opts: Opts): { Cue }
    -- Use an internal idx field as a tiebreaker in sort to ensure stable
    -- ordering among cues with equal atMs (Luau's table.sort is not stable).
    -- The idx field is intentionally left on the cue tables; tests do not
    -- assert its absence and stripping it would add needless complexity.
    local cues: { { atMs: number, idx: number, kind: string, userId: string?, effect: string?, worldThrow: string? } } =
        {
            { atMs = 0, idx = 1, kind = "drumrollStop" },
            { atMs = 0, idx = 2, kind = "basinErupt" },
            { atMs = 0, idx = 3, kind = "heroTileLand", worldThrow = reveal.worldThrow },
        }

    local userIds: { string } = {}
    for userId in reveal.results do
        table.insert(userIds, userId)
    end
    table.sort(userIds) -- deterministic order before randomized stagger

    for _, userId in userIds do
        local r = reveal.results[userId]
        cues[#cues + 1] = {
            atMs = math.floor(opts.random() * opts.staggerMaxMs),
            idx = #cues + 1,
            kind = "consequence",
            userId = userId,
            -- THE RESULT TRAVELS, not just the effect chosen from it. An effect is swappable data
            -- -- that is what EffectRegistry is for -- and LOSS's pool is empty, so a listener
            -- reading the effect cannot distinguish a loss from an unknown effect. `r.result` is
            -- already in hand; carrying it decouples every consumer from the effect catalog.
            result = r.result,
            effect = opts.selectEffect(r.result, { worldThrow = reveal.worldThrow }),
        }
    end

    if reveal.whiffed then
        for userId in reveal.whiffed do
            cues[#cues + 1] = { atMs = 200, idx = #cues + 1, kind = "whiffToast", userId = userId }
        end
    end

    table.sort(cues, function(a, b)
        if a.atMs == b.atMs then
            return a.idx < b.idx
        end
        return a.atMs < b.atMs
    end)
    return cues :: any
end

return ChoreographyMachine
