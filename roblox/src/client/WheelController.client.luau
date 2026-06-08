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

local kakehi = stage:WaitForChild("Kakehi")
local fallAnchor = kakehi:WaitForChild("WaterfallAnchor") :: BasePart
local fall = Instance.new("ParticleEmitter")
fall.Color = ColorSequence.new(Color3.fromRGB(127, 168, 190))
fall.Size = NumberSequence.new(0.4, 0.9)
fall.Transparency = NumberSequence.new(0.4)
fall.Lifetime = NumberRange.new(0.4, 0.6)
fall.Rate = 26
fall.Speed = NumberRange.new(7, 9)
fall.EmissionDirection = Enum.NormalId.Bottom
fall.Parent = fallAnchor

local spinning = true
local angle = 0

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        spinning = true
        fall.Rate = 26
    end
end)
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "latchClick" then
        spinning = false
        fall.Rate = 4
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
