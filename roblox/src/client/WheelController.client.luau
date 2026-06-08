--!strict
-- Spins the waterwheel while the machine draws; ratchet-freezes at latch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Waterwheel")
local wheel = rig:WaitForChild("Wheel") :: BasePart
local hub = wheel.CFrame
local paddles: { BasePart } = {}
local paddleOffsets: { CFrame } = {}
for _, child in rig:GetChildren() do
    if child.Name:match("^Paddle%d$") then
        table.insert(paddles, child :: BasePart)
        table.insert(paddleOffsets, hub:ToObjectSpace((child :: BasePart).CFrame))
    end
end

local spinning = true
local angle = 0

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        spinning = true
    end
end)
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "latchClick" then
        spinning = false
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if not spinning then
        return
    end
    angle += dt * 0.9
    local spun = hub * CFrame.Angles(angle, 0, 0)
    wheel.CFrame = spun
    for i, p in paddles do
        p.CFrame = spun * paddleOffsets[i]
    end
end)
