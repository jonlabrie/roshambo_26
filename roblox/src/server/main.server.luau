--!strict
-- Composition root: wires Roblox services into the runtime-agnostic modules.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkClient = require(script.Parent:WaitForChild("NetworkClient"))
local RoundCoordinator = require(script.Parent:WaitForChild("RoundCoordinator"))
local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local RoundClock = require(shared:WaitForChild("RoundClock"))

local secretsModule = script.Parent:FindFirstChild("SecretsLocal")
    or script.Parent:WaitForChild("SecretsExample")
local config = require(secretsModule) :: { baseUrl: string, apiKey: string }

local deps = {
    request = function(req)
        local ok, resp = pcall(function()
            return HttpService:RequestAsync({
                Url = req.Url,
                Method = req.Method,
                Headers = req.Headers,
                Body = req.Body,
            })
        end)
        if not ok then
            return { ok = false }
        end
        return { ok = true, statusCode = resp.StatusCode, body = resp.Body }
    end,
    jsonDecode = function(s: string)
        return HttpService:JSONDecode(s)
    end,
    sleep = function(seconds: number)
        task.wait(seconds)
    end,
    now = function()
        return DateTime.now().UnixTimestampMillis
    end,
    random = function()
        return math.random()
    end,
}

local net = NetworkClient.new({ baseUrl = config.baseUrl, apiKey = config.apiKey }, deps)
local clock = RoundClock.new()
local coordinator = RoundCoordinator.new({
    net = net,
    clock = clock,
    log = print,
    random = math.random,
})

print(`[ROSHAMBO] walking skeleton starting against {config.baseUrl}`)
task.spawn(function()
    while true do
        local delay = coordinator:pollOnce()
        task.wait(delay)
    end
end)
