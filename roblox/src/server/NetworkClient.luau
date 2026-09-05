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

-- Percent-encode a query value. `HttpService:UrlEncode` would do this, but this module takes
-- every side effect by injection and requires no Roblox service, so it runs under Lune -- and a
-- Roblox DisplayName legally carries spaces and non-ASCII, either of which makes a malformed URL.
-- Byte-wise `gsub` is correct for UTF-8 precisely because percent-encoding is defined per byte.
local function urlEncode(value: string): string
    return (
        string.gsub(value, "[^%w%-%.%_%~]", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    )
end

-- THE NAME RIDES THE JOIN CALL. Nothing on the Roblox path ever recorded a display name, so
-- every board naming a Roblox player showed "Anonymous" -- found 2026-08-18 by the owner reading
-- their own slip. This is the request every player already makes on join, and the name travels
-- exactly as `country` does rather than earning an endpoint of its own.
function NetworkClient.getPlayer(self: any, robloxUserId: string, country: string?, name: string?): Result
    local path = `/api/v1/players/{robloxUserId}`
    local query: { string } = {}
    if country then
        table.insert(query, `country={country}`)
    end
    -- An EMPTY name is omitted, never sent blank: the server guards against blanking a stored
    -- name, and sending one anyway would lean on that guard instead of not asking for it.
    if name and name ~= "" then
        table.insert(query, `name={urlEncode(name)}`)
    end
    if #query > 0 then
        path ..= "?" .. table.concat(query, "&")
    end
    return self:_request("GET", path)
end

-- `keep` is what stays riding after the bank; 0 is the full bank, which is what every caller
-- shipped before partial banking sends. The SERVER validates it against the player's own pot
-- (GameRules.keepOptions) and answers an invalid one with 409, the same shape as nothing staked.
function NetworkClient.postBank(self: any, robloxUserId: string, keep: number?): Result
    return self:_request("POST", "/api/v1/bank", { robloxUserId = robloxUserId, keep = keep or 0 })
end

function NetworkClient.getLeaderboards(self: any, scope: string): Result
    return self:_request("GET", `/api/v1/leaderboards?scope={scope}`)
end

-- /api/v1/stats is mounted AHEAD of the X-API-Key gate (server/src/routes/mount.ts) because these
-- boards read nothing a player could mutate. The key still rides along on _request; it is ignored.
function NetworkClient.getStatsRecords(self: any, window: string): Result
    return self:_request("GET", `/api/v1/stats/records?window={window}`)
end

function NetworkClient.getStatsHeat(self: any, window: string, instanceId: string?): Result
    local path = `/api/v1/stats/heat?window={window}`
    -- An EMPTY instanceId must not be sent: the route reads it as a scope and would resolve the
    -- presence set for the instance named "", returning an empty board instead of the global one.
    if instanceId and instanceId ~= "" then
        path ..= `&instanceId={instanceId}`
    end
    return self:_request("GET", path)
end

-- No window parameter: the board is the rolling week by definition and the route decides. Taking
-- one would invite a caller to ask for a window the 360-throw floor was never derived for --
-- that floor separates a +5-point edge from luck over ~356 throws, and means nothing over an
-- afternoon.
function NetworkClient.getStatsBoard(self: any): Result
    return self:_request("GET", "/api/v1/stats/board")
end

function NetworkClient.getStatsPlayer(self: any, robloxUserId: string): Result
    return self:_request("GET", `/api/v1/stats/player/{robloxUserId}`)
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

function NetworkClient.putHudPreference(self: any, robloxUserId: string, body: { [string]: any }): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/preferences-hud`, body)
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

function NetworkClient.getFireworks(self: any, robloxUserId: string, lastWorldThrow: string?): Result
    local q = if lastWorldThrow then `?lastWorldThrow={lastWorldThrow}` else ""
    return self:_request("GET", `/api/v1/players/{robloxUserId}/fireworks{q}`)
end

function NetworkClient.postFireworkSpend(self: any, robloxUserId: string, shellId: string): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/fireworks/spend`, { shellId = shellId })
end

-- A SHOW IS RESERVED BEFORE IT PLAYS: the server debits every shell the cue list needs in one
-- conditional update, so a show that cannot be fully paid takes nothing. 409 INSUFFICIENT (with
-- needed/held) and 409 MORTAR_MISSING both arrive as ordinary failed Results.
function NetworkClient.postShowReserve(self: any, robloxUserId: string, show: any): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/shows/reserve`, { show = show })
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

function NetworkClient.putMortarPlacements(
    self: any,
    robloxUserId: string,
    placements: { [string]: any }
): Result
    return self:_request(
        "PUT",
        `/api/v1/players/{robloxUserId}/mortar-placements`,
        { placements = placements }
    )
end

function NetworkClient.setAccess(self: any, robloxUserId: string, access: any): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/access`, { access = access })
end

return NetworkClient
