--!strict
-- Spins the waterwheel while the machine draws; ratchet-freezes at latch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EventBus = require(script.Parent:WaitForChild("EventBus"))
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Waterwheel")

-- Asakura cluster: spin every Wheel{n} about its own axle, with its paddles.
type Spin = { part: BasePart, hub: CFrame, paddles: { BasePart }, offsets: { CFrame } }
local spins: { Spin } = {}
for _, child in rig:GetChildren() do
    local wi = child.Name:match("^Wheel(%d+)$")
    if wi then
        local wheel = child :: BasePart
        local s: Spin = { part = wheel, hub = wheel.CFrame, paddles = {}, offsets = {} }
        for _, p in rig:GetChildren() do
            if p.Name:match(`^Paddle{wi}_%d+$`) then
                table.insert(s.paddles, p :: BasePart)
                table.insert(s.offsets, wheel.CFrame:ToObjectSpace((p :: BasePart).CFrame))
            end
        end
        table.insert(spins, s)
    end
end

-- Undershot: foam at the driving wheel's waterline (no overshot waterfall).
local driver = rig:FindFirstChild("Wheel1") :: BasePart?
local fall = Instance.new("ParticleEmitter")
fall.Color = ColorSequence.new(Color3.fromRGB(210, 222, 228))
fall.Size = NumberSequence.new(0.5, 1.1)
fall.Transparency = NumberSequence.new(0.5)
fall.Lifetime = NumberRange.new(0.3, 0.5)
fall.Rate = 22
fall.Speed = NumberRange.new(3, 5)
fall.SpreadAngle = Vector2.new(40, 40)
if driver then
    local sink = Instance.new("Attachment")
    sink.Position = Vector3.new(0, -driver.Size.Y / 2 + 0.4, 0)
    sink.Parent = driver
    fall.Parent = sink
end

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
    for _, s in spins do
        local spun = s.hub * CFrame.Angles(angle, 0, 0)
        s.part.CFrame = spun
        for i, p in s.paddles do
            p.CFrame = spun * s.offsets[i]
        end
    end
end)
