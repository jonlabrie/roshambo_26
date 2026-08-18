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
            { { ok = true, statusCode = 200, body = '{"roundId":"r1","phase":"OPEN","serverTime":111}' } },
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
    test("carries the player's display name, percent-encoded", function()
        local m = makeDeps({
            { ok = true, statusCode = 200, body = "{}" },
            { ok = true, statusCode = 200, body = "{}" },
        })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        net:getPlayer("9", "US", "Ayaka")
        expect(m.calls[1].url).toBe("http://x/api/v1/players/9?country=US&name=Ayaka")
        -- Spaces and non-ASCII are both legal in a Roblox DisplayName and would otherwise
        -- produce a malformed URL.
        net:getPlayer("9", nil, "Ayaka \u{7530}")
        expect(m.calls[2].url).toBe("http://x/api/v1/players/9?name=Ayaka%20%E7%94%B0")
    end)

    test("an empty display name is omitted rather than sent blank", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = "{}" } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        net:getPlayer("9", nil, "")
        expect(m.calls[1].url).toBe("http://x/api/v1/players/9")
    end)

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

describe("NetworkClient.putHudPreference", function()
    test("PUTs the preference body to /preferences-hud", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"escalationPrompts":false}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:putHudPreference("9", { escalationPrompts = false })
        expect(res.ok).toBe(true)
        expect(res.data.escalationPrompts).toBe(false)
        expect(f.calls[1].method).toBe("PUT")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/preferences-hud")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.escalationPrompts).toBe(false)
    end)

    test("surfaces a 400 BAD_REQUEST fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"BAD_REQUEST"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:putHudPreference("9", { seenBeat = "b1" })
        expect(res.ok).toBe(false)
        expect(res.error).toBe("BAD_REQUEST")
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

describe("NetworkClient.setPreferences", function()
    test("PUTs the list to /preferences and returns the echo", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"padPreferences":["T06"]}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setPreferences("9", { "T06" })
        expect(res.ok).toBe(true)
        expect(res.data.padPreferences[1]).toBe("T06")
        expect(f.calls[1].method).toBe("PUT")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/preferences")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.padPreferences[1]).toBe("T06")
    end)

    test("surfaces a 400 BAD_REQUEST fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"BAD_REQUEST"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setPreferences("9", { "T06" })
        expect(res.ok).toBe(false)
        expect(res.error).toBe("BAD_REQUEST")
        expect(#f.calls).toBe(1)
    end)
end)

describe("NetworkClient.setTeahouse", function()
    test("PUTs the loadout to the per-size teahouse path and returns the echo", function()
        local f = makeDeps({
            {
                ok = true,
                statusCode = 200,
                body = '{"sizeClass":"L","loadout":{"baseStyle":"teahouse-1story"}}',
            },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setTeahouse(
            "9",
            "L",
            { baseStyle = "teahouse-1story", wallBays = { back = { "solid", "door", "solid" } } }
        )
        expect(res.ok).toBe(true)
        expect(res.data.sizeClass).toBe("L")
        expect(f.calls[1].method).toBe("PUT")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/teahouses/L")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.loadout.baseStyle).toBe("teahouse-1story")
        expect(sent.loadout.wallBays.back[2]).toBe("door")
    end)

    test("surfaces a 400 fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"BAD_WALLBAYS"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setTeahouse("9", "L", { baseStyle = "t" })
        expect(res.ok).toBe(false)
        expect(res.error).toBe("BAD_WALLBAYS")
        expect(#f.calls).toBe(1)
    end)
end)

describe("NetworkClient.getEconomy + postPurchase", function()
    test("getEconomy GETs the economy path and decodes it", function()
        local f = makeDeps({
            {
                ok = true,
                statusCode = 200,
                body = '{"totalPoints":120,"maxDeckSize":"S","teahouseSizes":["S"],"catalog":{"deck":{"S":50}}}',
            },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:getEconomy("9")
        expect(res.ok).toBe(true)
        expect(res.data.maxDeckSize).toBe("S")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/economy")
        expect(f.calls[1].method).toBe("GET")
    end)

    test("postPurchase POSTs the item and returns the new state", function()
        local f = makeDeps({
            {
                ok = true,
                statusCode = 200,
                body = '{"item":"deck:M","totalPoints":500,"maxDeckSize":"M","teahouseSizes":["S"]}',
            },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postPurchase("9", "deck:M")
        expect(res.ok).toBe(true)
        expect(res.data.maxDeckSize).toBe("M")
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/purchase")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.item).toBe("deck:M")
    end)

    test("postPurchase surfaces a 400 fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"INSUFFICIENT_POINTS"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postPurchase("9", "deck:M")
        expect(res.ok).toBe(false)
        expect(res.error).toBe("INSUFFICIENT_POINTS")
        expect(#f.calls).toBe(1)
    end)
end)

describe("stats endpoints", function()
    test("records asks for the window it was given", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"longestStreaks":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        local res = net:getStatsRecords("week")
        expect(res.ok).toBe(true)
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/records?window=week")
        expect(m.calls[1].method).toBe("GET")
    end)

    test("the board takes no window — the route decides, and it is always the rolling week", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"rows":[],"depths":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        local res = net:getStatsBoard()
        expect(res.ok).toBe(true)
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/board")
        expect(m.calls[1].method).toBe("GET")
    end)

    test("heat scopes to an instance when one is supplied, and stays global when it is not", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"leaders":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        net:getStatsHeat("hour", "job-7")
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/heat?window=hour&instanceId=job-7")
        net:getStatsHeat("hour", nil)
        expect(m.calls[2].url).toBe("http://x/api/v1/stats/heat?window=hour")
    end)

    test("an empty instanceId is treated as global, not sent as a blank scope", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"leaders":[]}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        net:getStatsHeat("day", "")
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/heat?window=day")
    end)

    test("player stats are fetched by roblox user id", function()
        local m = makeDeps({ { ok = true, statusCode = 200, body = '{"displayName":"Ayaka"}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        local res = net:getStatsPlayer("12345")
        expect(res.ok).toBe(true)
        expect(m.calls[1].url).toBe("http://x/api/v1/stats/player/12345")
    end)

    test("a 404 from player stats is reported, not thrown — a player with no account is normal", function()
        local m = makeDeps({ { ok = true, statusCode = 404, body = '{"error":"NOT_FOUND"}' } })
        local net = NetworkClient.new({ baseUrl = "http://x", apiKey = "k" }, m.deps)
        expect(net:getStatsPlayer("999").ok).toBe(false)
    end)
end)
