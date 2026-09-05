--!strict
-- HAND-AUTHORED SHOWS for the proving verb and the A13 test (spec §10 row B). Pure data. These are
-- the first programs the sequencer plays and the first thing that puts many shells in one sky on
-- purpose; finale_v1 is deliberately dense so the director's concurrent-shell budget is exercised
-- at scale for the first time. Author here, sync with Rojo, press Play, open the proving panel.
local FireworkShows = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Draft = { title: string, cues: { Cue } }

local S = { "north arena", "bridge", "upper north", "mid pool", "hi west" }
local ROOF = "hanabiya roof"

local function cue(t_ms: number, slot: string, shellId: string): Cue
    return { t_ms = t_ms, slot = slot, shellId = shellId }
end

-- Build a program section: every `gapMs`, one shell round-robin across the five stations.
local function walk(startMs: number, gapMs: number, shells: { string }, count: number): { Cue }
    local out = {}
    for i = 1, count do
        table.insert(
            out,
            cue(startMs + (i - 1) * gapMs, S[((i - 1) % #S) + 1], shells[((i - 1) % #shells) + 1])
        )
    end
    return out
end

-- Fire `shellId` from every station (and the roof) within `spreadMs` of `atMs`.
local function volley(atMs: number, shellId: string, spreadMs: number, withRoof: boolean): { Cue }
    local out = {}
    for i, st in S do
        table.insert(out, cue(atMs + math.floor((i - 1) * spreadMs / #S), st, shellId))
    end
    if withRoof then
        table.insert(out, cue(atMs, ROOF, shellId))
    end
    return out
end

local function concat(...: { Cue }): { Cue }
    local out = {}
    for _, list in { ... } do
        for _, c in list do
            table.insert(out, c)
        end
    end
    table.sort(out, function(a, b)
        return a.t_ms < b.t_ms
    end)
    return out
end

FireworkShows.DRAFTS = {
    -- A short program to check timing by eye before anything heavy: one shell every second.
    warmup = {
        title = "Warm-up (5 shells, 1 s apart)",
        cues = walk(0, 1000, { "peony", "kiku", "wa", "rai", "willow" }, 5),
    },
    -- THE STRESS PROGRAM. ~2 minutes: an opening walk, three volleys that put six bursts in the
    -- sky inside 300 ms, a quiet middle, then a finale that stacks heavies. Shipped shells only.
    finale_v1 = {
        title = "Finale v1 (stress: volleys + heavies)",
        cues = concat(
            walk(0, 900, { "peony", "kiku", "rai" }, 15), -- 0–12.6 s: opening walk
            volley(15000, "wa", 250, true), -- 15 s: six red rings
            walk(18000, 600, { "willow", "hotaru", "banrai" }, 20), -- 18–29.4 s: faster walk
            volley(32000, "yashi", 200, true), -- 32 s
            volley(33000, "kiku", 200, false), -- 33 s: back-to-back volleys
            walk(37000, 1500, { "peony" }, 8), -- 37–47.5 s: quiet middle
            walk(52000, 400, { "wa", "rai", "kiku", "banrai" }, 20), -- 52–59.6 s: build
            volley(62000, "kamuro", 300, true), -- 62 s: heavies together — the case the budget exists for
            volley(63500, "janken", 300, false), -- 63.5 s
            volley(65000, "kamuro", 250, true), -- 65 s
            walk(68000, 300, { "hotaru", "yashi" }, 12) -- 68–71.3 s: close
        ),
    },
}

FireworkShows.ORDER = { "warmup", "finale_v1" }

return FireworkShows
