--!strict
-- Sozu (shishi-odoshi) timing lever. Fills through ACTIVE; dumps on latchClick
-- (lockout) — the same cue that kicks the throw drum — then resets next round. A
-- cord runs from the lever's tip up to the drum's W axle end (mirrors
-- ArenaLayout.sozu.cordTop), so the dump visibly "yanks" the drum into its spin.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent
local EventBus = require(script.Parent:WaitForChild("EventBus"))

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Sozu")
local lever = rig:WaitForChild("Lever") :: BasePart
local restCFrame = lever.CFrame

-- The builder rests the lever in its fill pose; dumping tips it the other way.
local FILL = restCFrame
local DUMP = restCFrame * CFrame.Angles(math.rad(34), 0, 0)

-- Cord from the lever tip up to the drum's W axle end (ArenaLayout.sozu.cordTop).
local cordTop = Vector3.new(-7, 31, 0)
local cord = Instance.new("Part")
cord.Name = "SozuCord"
cord.Anchored = true
cord.CanCollide = false
cord.Color = Color3.fromRGB(60, 50, 40)
cord.Material = Enum.Material.Fabric
cord.Size = Vector3.new(0.15, 0.15, 1)
cord.Parent = rig

local function tipPos(): Vector3
    return (lever.CFrame * CFrame.new(0, 0, -lever.Size.Z / 2)).Position
end
local function updateCord()
    local a, b = tipPos(), cordTop
    cord.CFrame = CFrame.new((a + b) / 2, b)
    cord.Size = Vector3.new(0.15, 0.15, (b - a).Magnitude)
end
updateCord()

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        -- ease back to the fill pose for the new round
        TweenService:Create(lever, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = FILL }):Play()
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "latchClick" then
        -- dump: a quick tip toward the catch stone (the clack = the lockout cue)
        TweenService
            :Create(
                lever,
                TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { CFrame = DUMP }
            )
            :Play()
    end
end)

RunService.Heartbeat:Connect(updateCord)
