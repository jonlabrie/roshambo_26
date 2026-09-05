--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShowPlayer = require("../src/shared/ShowPlayer")

local CUES = {
    { t_ms = 0, slot = "hand", shellId = "firecracker" },
    { t_ms = 1500, slot = "mortar:S", shellId = "peony" },
    { t_ms = 1500, slot = "mortar:M", shellId = "wa" },
    { t_ms = 4000, slot = "mortar:L", shellId = "kamuro" },
}

describe("ShowPlayer.durationMs", function()
    test("last cue plus the tail", function()
        expect(ShowPlayer.durationMs(CUES)).toBe(4000 + ShowPlayer.TAIL_MS)
    end)
    test("a one-cue show is just the tail", function()
        expect(ShowPlayer.durationMs({ CUES[1] })).toBe(ShowPlayer.TAIL_MS)
    end)
end)

describe("ShowPlayer.schedule -- one show per stage at a time", function()
    test("a free stage starts now", function()
        expect(ShowPlayer.schedule(nil, 10000, CUES)).toEqual({
            startAtMs = 10000,
            endAtMs = 10000 + 4000 + ShowPlayer.TAIL_MS,
        })
    end)
    test("a stage busy in the past is free", function()
        expect(ShowPlayer.schedule(9000, 10000, CUES).startAtMs).toBe(10000)
    end)
    test("a busy stage queues the show behind the current one", function()
        local s = ShowPlayer.schedule(12500, 10000, CUES)
        expect(s.startAtMs).toBe(12500)
        expect(s.endAtMs).toBe(12500 + 4000 + ShowPlayer.TAIL_MS)
    end)
end)

describe("ShowPlayer.timeline / delaysFrom", function()
    test("one entry per cue, in order, offset by the start", function()
        local tl = ShowPlayer.timeline(CUES, 5000)
        expect(#tl).toBe(4)
        expect(tl[1]).toEqual({ atMs = 5000, index = 1, cue = CUES[1] })
        expect(tl[3]).toEqual({ atMs = 6500, index = 3, cue = CUES[3] })
        expect(tl[4].atMs).toBe(9000)
    end)
    test("delays are seconds from now and never negative", function()
        local tl = ShowPlayer.timeline(CUES, 5000)
        expect(ShowPlayer.delaysFrom(5000, tl)).toEqual({ 0, 1.5, 1.5, 4 })
        expect(ShowPlayer.delaysFrom(6000, tl)).toEqual({ 0, 0.5, 0.5, 3 })
    end)
end)
