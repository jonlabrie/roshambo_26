--!strict
-- WHEN EACH CUE FIRES. Pure: the game server owns the clock and task.delay; this module only
-- turns a show plus a start time into the moments to fire, and decides when a show may start on
-- a stage that is already playing one (spec §2.5: one show per stage at a time; a second go
-- queues behind the current show on that stage only). Testable under Lune because it never
-- touches a service.
local ShowPlayer = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Entry = { atMs: number, index: number, cue: Cue }

-- How long after the LAST cue a stage stays busy: enough for the tallest shell to burst and fade.
ShowPlayer.TAIL_MS = 6000

function ShowPlayer.durationMs(cues: { Cue }): number
    local last = 0
    for _, c in cues do
        if c.t_ms > last then
            last = c.t_ms
        end
    end
    return last + ShowPlayer.TAIL_MS
end

function ShowPlayer.schedule(
    busyUntilMs: number?,
    nowMs: number,
    cues: { Cue }
): { startAtMs: number, endAtMs: number }
    local startAt = nowMs
    if busyUntilMs ~= nil and busyUntilMs > nowMs then
        startAt = busyUntilMs
    end
    return { startAtMs = startAt, endAtMs = startAt + ShowPlayer.durationMs(cues) }
end

function ShowPlayer.timeline(cues: { Cue }, startAtMs: number): { Entry }
    local out: { Entry } = {}
    for i, c in ipairs(cues) do
        table.insert(out, { atMs = startAtMs + c.t_ms, index = i, cue = c })
    end
    return out
end

function ShowPlayer.delaysFrom(nowMs: number, timeline: { Entry }): { number }
    local out = {}
    for _, e in timeline do
        table.insert(out, math.max(0, (e.atMs - nowMs) / 1000))
    end
    return out
end

return ShowPlayer
