--!strict
local serde = require("@lune/serde")
local harness = require("./harness")
local NetworkClient = require("../src/server/NetworkClient")
local describe, test, expect = harness.describe, harness.test, harness.expect

type Resp = { ok: boolean, statusCode: number?, body: string? }

local function makeDeps(script: { Resp }, opts: { now: { number }? }?)
    local calls: { { url: string, method: string, headers: { [string]: string }, body: string? } } = {}
    local sleeps: { number } = {}
    local i = 0
    local nowQueue = opts and opts.now or nil
    local nowIdx = 0
    return {
        calls = calls,
        sleeps = sleeps,
        deps = {
            request = function(req: {
                Url: string,
                Method: string,
                Headers: { [string]: string },
                Body: string?,
            }): Resp
                table.insert(
                    calls,
                    { url = req.Url, method = req.Method, headers = req.Headers, body = req.Body }
                )
                i += 1
                return script[math.min(i, #script)]
            end,
            jsonDecode = function(s: string): any
                return serde.decode("json", s)
            end,
            jsonEncode = function(t: any): string
                return serde.encode("json", t)
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

describe("NetworkClient.postThrows", function()
    test("POSTs the encoded batch with content-type and returns the 202 body", function()
        local f = makeDeps({ { ok = true, statusCode = 202, body = '{"accepted":2,"rejected":[]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postThrows({
            instanceId = "job-1",
            roundId = "r1",
            seq = 1,
            throws = { { robloxUserId = "9", throw = "R" } },
        })
        expect(res.ok).toBe(true)
        expect(res.data.accepted).toBe(2)
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/throws")
        expect(f.calls[1].headers["Content-Type"]).toBe("application/json")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.seq).toBe(1)
        expect(sent.throws[1].robloxUserId).toBe("9")
    end)

    test("409 fails fast with the decoded server error (no retry burn)", function()
        local f = makeDeps({ { ok = true, statusCode = 409, body = '{"error":"PICKS_CLOSED"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postThrows({ instanceId = "j", roundId = "r", seq = 1, throws = {} })
        expect(res.ok).toBe(false)
        expect(res.status).toBe(409)
        expect(res.error).toBe("PICKS_CLOSED")
        expect(#f.calls).toBe(1)
    end)

    test("transport failure retries POSTs like GETs", function()
        local f = makeDeps({
            { ok = false },
            { ok = true, statusCode = 202, body = '{"accepted":0,"rejected":[]}' },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        expect(net:postThrows({ instanceId = "j", roundId = "r", seq = 1, throws = {} }).ok).toBe(true)
        expect(#f.calls).toBe(2)
    end)
end)

describe("NetworkClient.getInstanceResults", function()
    test("hits the per-instance results path; 404 maps to notReady", function()
        local f = makeDeps({ { ok = true, statusCode = 404, body = '{"error":"RESULTS_NOT_READY"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getInstanceResults("job-1", "r9")
        expect(res.notReady).toBe(true)
        expect(f.calls[1].url).toBe("http://x/api/v1/instances/job-1/rounds/r9/results")
    end)
end)

describe("NetworkClient.getPlayer", function()
    test("plain fetch and country-recording variant", function()
        local f = makeDeps({
            { ok = true, statusCode = 200, body = '{"robloxUserId":"9","totalPoints":5}' },
            { ok = true, statusCode = 200, body = '{"robloxUserId":"9","totalPoints":5}' },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        expect(net:getPlayer("9").data.totalPoints).toBe(5)
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9")
        net:getPlayer("9", "US")
        expect(f.calls[2].url).toBe("http://x/api/v1/players/9?country=US")
    end)
end)

describe("NetworkClient.postBank", function()
    test("banks and returns the wallet", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"totalPoints":14,"pointsAtStake":0}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postBank("9")
        expect(res.data.totalPoints).toBe(14)
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.robloxUserId).toBe("9")
    end)

    test("409 NOTHING_STAKED fails fast with the decoded error", function()
        local f = makeDeps({ { ok = true, statusCode = 409, body = '{"error":"NOTHING_STAKED"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postBank("9")
        expect(res.ok).toBe(false)
        expect(res.error).toBe("NOTHING_STAKED")
        expect(#f.calls).toBe(1)
    end)
end)

describe("NetworkClient.getLeaderboards", function()
    test("hits the world-scope path", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"scope":"world","leaders":[]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getLeaderboards("world")
        expect(res.ok).toBe(true)
        expect(res.data.scope).toBe("world")
        expect(f.calls[1].url).toBe("http://x/api/v1/leaderboards?scope=world")
    end)
end)

describe("NetworkClient.getTeahouses", function()
    test("hits the player teahouses path and decodes the map", function()
        local f = makeDeps({
            {
                ok = true,
                statusCode = 200,
                body = '{"teahouses":{"M":{"baseStyle":"teahouse-1story","colorScheme":"scheme.vermilion"}}}',
            },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getTeahouses("90000001")
        expect(res.ok).toBe(true)
        expect(res.data.teahouses.M.baseStyle).toBe("teahouse-1story")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/90000001/teahouses")
        expect(f.calls[1].method).toBe("GET")
    end)

    test("wanderer returns an empty map, still ok", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"teahouses":{}}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getTeahouses("90000001")
        expect(res.ok).toBe(true)
        expect(next(res.data.teahouses)).toBe(nil)
    end)
end)
