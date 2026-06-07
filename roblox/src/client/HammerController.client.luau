--!strict
-- Animates the placeholder hammer arm from HammerCurve and fires the gong
-- placeholder on reveal. 4b swaps parts for art; the curve stays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HammerCurve = require(shared:WaitForChild("HammerCurve"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local arm = stage:WaitForChild("HammerArm") :: BasePart
local gong = stage:WaitForChild("GongPad") :: BasePart
local pivot = arm.CFrame * CFrame.new(0, 0, arm.Size.Z / 2) -- hinge at the arm's rear end

local lastPhase = "ACTIVE"
local secondsToLockout: number? = nil
local phaseAt = os.clock()
local wasLatched = false
local striking = false

RoundUpdate.OnClientEvent:Connect(function(info)
    lastPhase = info.phase
    secondsToLockout = info.secondsToLockout
    phaseAt = os.clock()
    if info.phase == "ACTIVE" then
        wasLatched = false
        striking = false
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongStrike" then
        striking = true
        TweenService
            :Create(arm, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = pivot * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, 0, -arm.Size.Z / 2),
            })
            :Play()
        local light = Instance.new("PointLight")
        light.Brightness = 12
        light.Range = 30
        light.Parent = gong
        task.delay(0.6, function()
            light:Destroy()
        end)
    elseif cue.kind == "basinErupt" then
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true
        ring.CanCollide = false
        ring.Transparency = 0.5
        ring.Color = Color3.fromRGB(127, 180, 201)
        ring.Size = Vector3.new(0.3, 2, 2)
        ring.CFrame = CFrame.new(gong.Position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = workspace
        TweenService:Create(ring, TweenInfo.new(1.2), { Size = Vector3.new(0.3, 26, 26), Transparency = 1 })
            :Play()
        task.delay(1.3, function()
            ring:Destroy()
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if striking then
        return
    end
    local secondsLeft: number
    if lastPhase == "ACTIVE" then
        local lead = 2
        local toLockout = math.max(0, (secondsToLockout or 18) - (os.clock() - phaseAt))
        secondsLeft = toLockout + lead
    else
        secondsLeft = 1
    end
    local state = HammerCurve.state(lastPhase, secondsLeft)
    if not state.released then
        local tremble = if state.trembling then math.rad((math.random() - 0.5) * 2) else 0
        arm.CFrame = pivot
            * CFrame.Angles(math.rad(state.angleDeg) + tremble, 0, 0)
            * CFrame.new(0, 0, -arm.Size.Z / 2)
        if state.latched and not wasLatched then
            wasLatched = true
            EventBus.Cue:Fire({ kind = "latchClick" })
        end
    end
end)
