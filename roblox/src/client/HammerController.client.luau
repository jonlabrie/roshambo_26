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
local restCFrame = arm.CFrame -- rest pose: log hanging at the front of its swing

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
        -- Stage 1: swing forward (gravity-accelerated) to overshoot into the bell.
        local swing = TweenService:Create(
            arm,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { CFrame = restCFrame * CFrame.new(0, 0, -0.8) }
        )
        swing.Completed:Connect(function()
            -- Contact moment: flash + basin ring fire here, not at cue time.
            local light = Instance.new("PointLight")
            light.Brightness = 6
            light.Range = 18
            light.Parent = gong
            TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
            task.delay(0.3, function()
                light:Destroy()
            end)
            local ring = Instance.new("Part")
            ring.Shape = Enum.PartType.Cylinder
            ring.Anchored = true
            ring.CanCollide = false
            ring.Transparency = 0.5
            ring.Color = Color3.fromRGB(127, 180, 201)
            ring.Size = Vector3.new(0.3, 2, 2)
            ring.CFrame = CFrame.new(gong.Position.X, 0.5, gong.Position.Z)
                * CFrame.Angles(0, 0, math.rad(90))
            ring.Parent = workspace
            TweenService
                :Create(ring, TweenInfo.new(1.2), { Size = Vector3.new(0.3, 26, 26), Transparency = 1 })
                :Play()
            task.delay(1.3, function()
                ring:Destroy()
            end)
            -- Stage 2: recoil bounce off the bell, then settle back to rest.
            local recoil = TweenService:Create(
                arm,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = restCFrame * CFrame.new(0, 0.15, 1.1) }
            )
            recoil.Completed:Connect(function()
                TweenService:Create(
                    arm,
                    TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { CFrame = restCFrame }
                ):Play()
            end)
            recoil:Play()
        end)
        swing:Play()
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
        local p = state.angleDeg / 100 -- 0..1 draw percent
        local drawZ = p * 6 -- drawn 6 studs backward (away from the bell, +Z)
        local riseY = p * p * 1.2 -- slight pendulum rise on the suspension arc
        local shiver = if state.trembling
            then math.sin(os.clock() * 28) * 0.6 + (math.random() - 0.5) * 0.1
            else 0
        local pose = restCFrame * CFrame.new(0, riseY, drawZ + shiver)
        if state.trembling then
            pose = pose * CFrame.Angles(0, math.rad(math.sin(os.clock() * 23) * 1.5), 0)
        end
        arm.CFrame = pose
        if state.latched and not wasLatched then
            wasLatched = true
            EventBus.Cue:Fire({ kind = "latchClick" })
        end
    end
end)
