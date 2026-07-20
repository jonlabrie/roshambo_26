--!strict
-- Client-pull for per-player state (2026-07-20). The server pushes EconomyState (+ preferences, back
-- door, access) ONCE on join, but on a live server those one-shot pushes can fire before this client
-- has its listeners connected -- and RemoteEvents don't queue for late listeners -- so the teahouse
-- panel would sit on "Loading..." forever. We fire RequestSync on startup and retry every second
-- until our EconomyState arrives; the server re-echoes our state once we're listening. (Studio's
-- fast local timing hid this; a real published server exposed it -- same class as needing the client
-- to WaitForChild replicated instances rather than assume they're already there.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local EconomyState = remotes:WaitForChild("EconomyState") :: RemoteEvent
local RequestSync = remotes:WaitForChild("RequestSync") :: RemoteEvent

local received = false
EconomyState.OnClientEvent:Connect(function()
    received = true
end)

task.spawn(function()
    -- up to ~20s of retries; stops the instant EconomyState lands (usually the first or second try).
    for _ = 1, 20 do
        if received then
            break
        end
        RequestSync:FireServer()
        task.wait(1)
    end
end)
