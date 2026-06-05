--!strict
local harness = require("./harness")
local RoundCoordinator = require("../src/server/RoundCoordinator")
local describe, test, expect = harness.describe, harness.test, harness.expect

local function makeFakes(states: { any }, results: { any })
    local logs: { string } = {}
    local stateIdx = 0
    local resultIdx = 0
    local clockSamples = 0
    return {
        logs = logs,
        net = {
            getState = function(_self): any
                stateIdx = math.min(stateIdx + 1, #states)
                return states[stateIdx]
            end,
            getRoundResult = function(_self, _roundId: string): any
                resultIdx = math.min(resultIdx + 1, #results)
                return results[resultIdx]
            end,
        },
        clock = {
            addSample = function(_self, _st, _rtt, _lr)
                clockSamples += 1
            end,
            samples = function()
                return clockSamples
            end,
        },
        log = function(msg: string)
            table.insert(logs, msg)
        end,
        random = function()
            return 0
        end,
    }
end

local function okState(roundId: string, phase: string, roundCount: number)
    return {
        ok = true,
        data = { roundId = roundId, phase = phase, roundCount = roundCount, serverTime = 1, phaseEndsAt = 2 },
        rttMs = 10,
        localReceiveMs = 1,
    }
end

describe("RoundCoordinator.pollOnce", function()
    test("logs new round and phase, feeds the clock", function()
        local f = makeFakes({ okState("r1", "ACTIVE", 7) }, {})
        local c = RoundCoordinator.new({
            net = f.net :: any,
            clock = f.clock :: any,
            log = f.log,
            random = f.random,
        })
        local delay = c:pollOnce()
        expect(#f.logs).toBe(1)
        expect(f.logs[1]).toBe("[ROUND 7] r1 ACTIVE")
        expect(f.clock.samples()).toBe(1)
        expect(delay).toBe(1) -- 1s + jitter(0)
    end)

    test("logs each phase change once, not on repeat polls", function()
        local f = makeFakes(
            { okState("r1", "ACTIVE", 7), okState("r1", "ACTIVE", 7), okState("r1", "TALLY", 7) },
            {
                {
                    ok = true,
                    data = { worldThrow = "S", distribution = { R = 100, P = 0, S = 0 }, totalPlayers = 1 },
                },
            }
        )
        local c = RoundCoordinator.new({
            net = f.net :: any,
            clock = f.clock :: any,
            log = f.log,
            random = f.random,
        })
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        expect(f.logs[1]).toBe("[ROUND 7] r1 ACTIVE")
        expect(f.logs[2]).toBe("[ROUND 7] r1 TALLY")
        expect(f.logs[3]).toBe("[ROUND 7] WORLD THROW: S | R 100% P 0% S 0% | players 1")
        expect(#f.logs).toBe(3)
    end)

    test("fetches the result exactly once per round even across REVEAL polls", function()
        local f = makeFakes(
            { okState("r1", "TALLY", 7), okState("r1", "REVEAL", 7), okState("r1", "REVEAL", 7) },
            {
                {
                    ok = true,
                    data = { worldThrow = "P", distribution = { R = 0, P = 100, S = 0 }, totalPlayers = 2 },
                },
            }
        )
        local c = RoundCoordinator.new({
            net = f.net :: any,
            clock = f.clock :: any,
            log = f.log,
            random = f.random,
        })
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        local resultLogs = 0
        for _, l in f.logs do
            if l:find("WORLD THROW") then
                resultLogs += 1
            end
        end
        expect(resultLogs).toBe(1)
    end)

    test("notReady result retries on the next poll", function()
        local f = makeFakes({ okState("r1", "TALLY", 7), okState("r1", "REVEAL", 7) }, {
            { ok = false, notReady = true },
            {
                ok = true,
                data = { worldThrow = "R", distribution = { R = 0, P = 0, S = 0 }, totalPlayers = 0 },
            },
        })
        local c = RoundCoordinator.new({
            net = f.net :: any,
            clock = f.clock :: any,
            log = f.log,
            random = f.random,
        })
        c:pollOnce()
        c:pollOnce()
        local found = false
        for _, l in f.logs do
            if l:find("WORLD THROW: R") then
                found = true
            end
        end
        expect(found).toBe(true)
    end)

    test("state failure logs and backs off harder", function()
        local f = makeFakes({ { ok = false, error = "TRANSPORT_FAILED" } }, {})
        local c = RoundCoordinator.new({
            net = f.net :: any,
            clock = f.clock :: any,
            log = f.log,
            random = f.random,
        })
        local delay = c:pollOnce()
        expect(f.logs[1]).toBe("[NET] state failed: TRANSPORT_FAILED")
        expect(delay).toBe(3)
    end)

    test("a new roundId resets the per-round result latch", function()
        local f = makeFakes(
            { okState("r1", "REVEAL", 7), okState("r2", "ACTIVE", 8), okState("r2", "TALLY", 8) },
            {
                {
                    ok = true,
                    data = { worldThrow = "S", distribution = { R = 0, P = 0, S = 0 }, totalPlayers = 0 },
                },
                {
                    ok = true,
                    data = { worldThrow = "R", distribution = { R = 0, P = 0, S = 0 }, totalPlayers = 0 },
                },
            }
        )
        local c = RoundCoordinator.new({
            net = f.net :: any,
            clock = f.clock :: any,
            log = f.log,
            random = f.random,
        })
        c:pollOnce()
        c:pollOnce()
        c:pollOnce()
        local throws = {}
        for _, l in f.logs do
            local w = l:match("WORLD THROW: (%a)")
            if w then
                table.insert(throws, w)
            end
        end
        expect(throws).toEqual({ "S", "R" })
    end)
end)
