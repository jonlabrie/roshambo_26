--!strict
-- HTTP client for the Roshambo /api/v1 (server-to-server). All side effects
-- (transport, json, sleep, clock, random) are injected so this module runs
-- under Lune tests and Roblox alike. Never reaches Roblox clients.
local NetworkClient = {}
NetworkClient.__index = NetworkClient

export type Response = { ok: boolean, statusCode: number?, body: string? }
export type Deps = {
    request: (
        req: { Url: string, Method: string, Headers: { [string]: string }, Body: string? }
    ) -> Response,
    jsonDecode: (s: string) -> any,
    jsonEncode: (t: any) -> string,
    sleep: (seconds: number) -> (),
    now: () -> number, -- local epoch ms
    random: () -> number, -- [0,1)
}
export type Config = { baseUrl: string, apiKey: string, maxAttempts: number? }

export type Result = {
    ok: boolean,
    data: any?,
    status: number?,
    error: string?,
    notReady: boolean?,
    rttMs: number?,
    localReceiveMs: number?,
}

function NetworkClient.new(config: Config, deps: Deps)
    return setmetatable({
        _base = config.baseUrl,
        _key = config.apiKey,
        _maxAttempts = config.maxAttempts or 3,
        _deps = deps,
    }, NetworkClient)
end

local function backoffSeconds(attempt: number, random: () -> number): number
    -- 0.5 * 2^(attempt-1) plus up to 0.5s jitter
    return 0.5 * 2 ^ (attempt - 1) + random() * 0.5
end

function NetworkClient._request(self: any, method: string, path: string, bodyTable: any?): Result
    local d: Deps = self._deps
    local headers: { [string]: string } = { ["X-API-Key"] = self._key }
    local bodyStr: string? = nil
    if bodyTable ~= nil then
        headers["Content-Type"] = "application/json"
        bodyStr = d.jsonEncode(bodyTable)
    end
    for attempt = 1, self._maxAttempts do
        local sentAt = d.now()
        local resp =
            d.request({ Url = self._base .. path, Method = method, Headers = headers, Body = bodyStr })
        local receivedAt = d.now()
        if resp.ok and resp.statusCode then
            local code = resp.statusCode
            if code >= 200 and code < 300 then
                local decodeOk, decoded = pcall(d.jsonDecode, resp.body or "null")
                if not decodeOk then
                    return { ok = false, status = code, error = "DECODE_FAILED" }
                end
                return {
                    ok = true,
                    data = decoded,
                    status = code,
                    rttMs = receivedAt - sentAt,
                    localReceiveMs = receivedAt,
                }
            end
            if code == 404 then
                return { ok = false, notReady = true, status = code }
            end
            if code < 500 then
                -- 4xx: fail fast. Surface the server's error string when the body has one
                -- (409 ROUND_MISMATCH / PICKS_CLOSED / NOTHING_STAKED are protocol signals).
                local decodeOk, decoded = pcall(d.jsonDecode, resp.body or "null")
                local serverError = if decodeOk and type(decoded) == "table" then decoded.error else nil
                return {
                    ok = false,
                    status = code,
                    error = serverError or ("HTTP_" .. tostring(code)),
                    data = if decodeOk then decoded else nil,
                }
            end
        end
        if attempt < self._maxAttempts then
            d.sleep(backoffSeconds(attempt, d.random))
        end
    end
    return { ok = false, error = "TRANSPORT_FAILED" }
end

function NetworkClient.getState(self: any): Result
    return self:_request("GET", "/api/v1/state")
end

function NetworkClient.getRoundResult(self: any, roundId: string): Result
    return self:_request("GET", `/api/v1/rounds/{roundId}/result`)
end

function NetworkClient.postThrows(self: any, batch: any): Result
    return self:_request("POST", "/api/v1/throws", batch)
end

function NetworkClient.getInstanceResults(self: any, instanceId: string, roundId: string): Result
    return self:_request("GET", `/api/v1/instances/{instanceId}/rounds/{roundId}/results`)
end

function NetworkClient.getPlayer(self: any, robloxUserId: string, country: string?): Result
    local path = `/api/v1/players/{robloxUserId}`
    if country then
        path ..= `?country={country}`
    end
    return self:_request("GET", path)
end

function NetworkClient.postBank(self: any, robloxUserId: string): Result
    return self:_request("POST", "/api/v1/bank", { robloxUserId = robloxUserId })
end

function NetworkClient.getLeaderboards(self: any, scope: string): Result
    return self:_request("GET", `/api/v1/leaderboards?scope={scope}`)
end

function NetworkClient.getTeahouses(self: any, robloxUserId: string): Result
    return self:_request("GET", `/api/v1/players/{robloxUserId}/teahouses`)
end

function NetworkClient.setPreferences(self: any, robloxUserId: string, padPreferences: { string }): Result
    return self:_request(
        "PUT",
        `/api/v1/players/{robloxUserId}/preferences`,
        { padPreferences = padPreferences }
    )
end

function NetworkClient.setTeahouse(self: any, robloxUserId: string, sizeClass: string, loadout: any): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/teahouses/{sizeClass}`, { loadout = loadout })
end

function NetworkClient.getEconomy(self: any, robloxUserId: string): Result
    return self:_request("GET", `/api/v1/players/{robloxUserId}/economy`)
end

function NetworkClient.postPurchase(self: any, robloxUserId: string, item: string): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/purchase`, { item = item })
end

function NetworkClient.postDisplay(
    self: any,
    robloxUserId: string,
    deckDisplay: string?,
    teahouseDisplay: string?
): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/display`, {
        deckDisplay = deckDisplay,
        teahouseDisplay = teahouseDisplay,
    })
end

function NetworkClient.setDecorations(self: any, robloxUserId: string, decorations: { any }): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/decorations`, { decorations = decorations })
end

return NetworkClient
