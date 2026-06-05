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

function NetworkClient._get(self: any, path: string): Result
    local d: Deps = self._deps
    for attempt = 1, self._maxAttempts do
        local sentAt = d.now()
        local resp = d.request({
            Url = self._base .. path,
            Method = "GET",
            Headers = { ["X-API-Key"] = self._key },
        })
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
                -- 4xx other than 404: our bug or config problem; retrying won't help
                return { ok = false, status = code, error = "HTTP_" .. tostring(code) }
            end
            -- 5xx falls through to retry
        end
        if attempt < self._maxAttempts then
            d.sleep(backoffSeconds(attempt, d.random))
        end
    end
    return { ok = false, error = "TRANSPORT_FAILED" }
end

function NetworkClient.getState(self: any): Result
    return self:_get("/api/v1/state")
end

function NetworkClient.getRoundResult(self: any, roundId: string): Result
    return self:_get(`/api/v1/rounds/{roundId}/result`)
end

return NetworkClient
