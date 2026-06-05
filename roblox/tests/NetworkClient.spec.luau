--!strict
local serde = require("@lune/serde")
local harness = require("./harness")
local NetworkClient = require("../src/server/NetworkClient")
local describe, test, expect = harness.describe, harness.test, harness.expect

type Resp = { ok: boolean, statusCode: number?, body: string? }

local function makeDeps(script: { Resp }, opts: { now: { number }? })
    local calls: { { url: string, headers: { [string]: string } } } = {}
    local sleeps: { number } = {}
    local i = 0
    local nowQueue = opts and opts.now or nil
    local nowIdx = 0
    return {
        calls = calls,
        sleeps = sleeps,
        deps = {
            request = function(req: { Url: string, Method: string, Headers: { [string]: string } }): Resp
                table.insert(calls, { url = req.Url, headers = req.Headers })
                i += 1
                return script[math.min(i, #script)]
            end,
            jsonDecode = function(s: string): any
                return serde.decode("json", s)
            end,
            sleep = function(t: number)
                table.insert(sleeps, t)
            end,
            now = function(): number
                if nowQueue then
                    nowIdx += 1
                    return nowQueue[math.min(nowIdx, #nowQueue)]
                end
                return 0
            end,
            random = function(): number
                return 0.5
            end,
        },
    }
end

local CONFIG = { baseUrl = "http://x", apiKey = "k", maxAttempts = 3 }

describe("NetworkClient.getState", function()
    test("returns decoded state with rtt and localReceive timing", function()
        local f = makeDeps(
            { { ok = true, statusCode = 200, body = '{"roundId":"r1","phase":"ACTIVE","serverTime":111}' } },
            { now = { 100, 140 } } -- send at 100, receive at 140 -> rtt 40
        )
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getState()
        expect(res.ok).toBe(true)
        expect(res.data.roundId).toBe("r1")
        expect(res.rttMs).toBe(40)
        expect(res.localReceiveMs).toBe(140)
        expect(f.calls[1].url).toBe("http://x/api/v1/state")
        expect(f.calls[1].headers["X-API-Key"]).toBe("k")
    end)

    test("retries transport failures with capped exponential backoff + jitter", function()
        local f = makeDeps({
            { ok = false },
            { ok = false },
            { ok = true, statusCode = 200, body = '{"roundId":"r1"}' },
        }, {})
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getState()
        expect(res.ok).toBe(true)
        expect(#f.calls).toBe(3)
        -- backoff: 0.5*2^0 + 0.5*0.5 = 0.75; 0.5*2^1 + 0.25 = 1.25
        expect(f.sleeps[1]).toBeCloseTo(0.75)
        expect(f.sleeps[2]).toBeCloseTo(1.25)
    end)

    test("gives up after maxAttempts", function()
        local f = makeDeps({ { ok = false } }, {})
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getState()
        expect(res.ok).toBe(false)
        expect(res.error).toBe("TRANSPORT_FAILED")
        expect(#f.calls).toBe(3)
    end)

    test("invalid JSON on a 2xx returns DECODE_FAILED instead of throwing", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = "not json" } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getState()
        expect(res.ok).toBe(false)
        expect(res.error).toBe("DECODE_FAILED")
    end)

    test("5xx retries; 401 does not (fail fast, surfaced)", function()
        local f5 = makeDeps(
            { { ok = true, statusCode = 503, body = "" }, { ok = true, statusCode = 200, body = "{}" } },
            {}
        )
        local net5 = NetworkClient.new(CONFIG, f5.deps)
        expect(net5:getState().ok).toBe(true)
        expect(#f5.calls).toBe(2)

        local f4 = makeDeps({ { ok = true, statusCode = 401, body = "" } }, {})
        local net4 = NetworkClient.new(CONFIG, f4.deps)
        local res = net4:getState()
        expect(res.ok).toBe(false)
        expect(res.status).toBe(401)
        expect(#f4.calls).toBe(1)
    end)
end)

describe("NetworkClient.getRoundResult", function()
    test("hits the round result path", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"worldThrow":"S"}' } }, {})
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getRoundResult("r9")
        expect(res.ok).toBe(true)
        expect(res.data.worldThrow).toBe("S")
        expect(f.calls[1].url).toBe("http://x/api/v1/rounds/r9/result")
    end)

    test("404 maps to notReady (result not settled yet), no retry burn", function()
        local f = makeDeps({ { ok = true, statusCode = 404, body = '{"error":"RESULT_NOT_READY"}' } }, {})
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getRoundResult("r9")
        expect(res.ok).toBe(false)
        expect(res.notReady).toBe(true)
        expect(#f.calls).toBe(1)
    end)
end)
