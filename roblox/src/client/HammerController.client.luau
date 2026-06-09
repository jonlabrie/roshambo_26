--!strict
-- Animates the placeholder hammer arm from HammerCurve and fires the gong
-- placeholder on reveal. 4b swaps parts for art; the curve stays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
local HammerCurve = require(shared:WaitForChild("HammerCurve"))
local ZenDojo = require(shared:WaitForChild("themes"):WaitForChild("ZenDojo"))
local EventBus = require(script.Parent:WaitForChild("EventBus"))
local WATER = Color3.new(ZenDojo.palette.water[1], ZenDojo.palette.water[2], ZenDojo.palette.water[3])

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local RoundUpdate = remotes:WaitForChild("RoundUpdate") :: RemoteEvent

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("BonshoRig")
local arm = rig:WaitForChild("ShuMoku") :: BasePart
local gong = rig:WaitForChild("Bonsho") :: BasePart
local restCFrame = arm.CFrame -- rest pose: log hanging at the front of its swing
-- Offsets are applied in WORLD space (pre-multiply: `CFrame.new(v) * rest`) so
-- the draw/swing/recoil go straight back/forward regardless of each part's rest
-- rotation. ShuMoku rests rotated (CYL_ALONG_Z), so a local-frame offset would
-- send the draw sideways — world-space keeps the log moving straight.

-- Suspension + drive-rope geometry. The four chains hang from FIXED rail tops;
-- their bottoms ride the log. The drive rope runs from a fixed wheel anchor to
-- the log's back end. Both follow the log's LIVE CFrame each frame (see the
-- dedicated Heartbeat below) — never mirrored offsets.
-- These constants MIRROR ArenaLayout.shuMoku / .waterwheel (build-time only, not
-- replicated to the client). Keep in sync with tools/builders/ArenaLayout.luau.
local function v3(t: { number }): Vector3
    return Vector3.new(t[1], t[2], t[3])
end

-- A cylinder (long axis = +X = RightVector) spanning a→b: CFrame + length.
local function segCF(a: Vector3, b: Vector3): (CFrame, number)
    local dir = b - a
    local len = dir.Magnitude
    local x = dir.Unit
    local up = if math.abs(x.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
    local z = x:Cross(up).Unit
    local y = z:Cross(x).Unit
    return CFrame.fromMatrix((a + b) / 2, x, y, z), len
end

local chains = {
    rig:WaitForChild("Chain1") :: BasePart,
    rig:WaitForChild("Chain2") :: BasePart,
    rig:WaitForChild("Chain3") :: BasePart,
    rig:WaitForChild("Chain4") :: BasePart,
}
-- The drive train is rotated onto the SW->NE diagonal (mirrors
-- ArenaLayout.shuMoku.yaw = 225). yawV rotates the proven +Z gantry geometry;
-- BACK is the draw direction (back toward the wheel = SW).
local YAW = CFrame.Angles(0, math.rad(237), 0)
local function yawV(t: { number }): Vector3
    return (YAW * CFrame.new(v3(t))).Position
end
local BACK = (YAW * CFrame.new(0, 0, 1)).Position

local chainTops = {
    yawV({ 3, 15, 7.5 }),
    yawV({ 3, 15, 11.5 }),
    yawV({ -3, 15, 7.5 }),
    yawV({ -3, 15, 11.5 }),
}
local chainBottomsRest = {
    yawV({ 0.8, 6.6, 7.5 }),
    yawV({ 0.8, 6.6, 11.5 }),
    yawV({ -0.8, 6.6, 7.5 }),
    yawV({ -0.8, 6.6, 11.5 }),
}

-- The drive rope is a client visual created at runtime (no builder part).
-- mirrors ArenaLayout.waterwheel.ropeAnchor = onLine(20.6, 5) at the same yaw
local ropeWheelAnchor = (YAW * CFrame.new(0, 5, 20.6)).Position
local ropeBottomRest = yawV({ 0, 6.2, 13 }) -- ArenaLayout.shuMoku.ropeBottomRest (rotated)
local driveRope = Instance.new("Part")
driveRope.Name = "DriveRope"
driveRope.Anchored = true
driveRope.CanCollide = false
driveRope.Shape = Enum.PartType.Cylinder
driveRope.Color = Color3.new(0.55, 0.48, 0.35)
driveRope.Material = Enum.Material.Fabric
driveRope.Size = Vector3.new(1, 0.2, 0.2)
driveRope.Parent = rig

-- Recompute all 4 chains + the drive rope from the log's CURRENT CFrame.
local function updateSuspension()
    local delta = arm.CFrame * restCFrame:Inverse()
    for i, chain in chains do
        local botW = delta * chainBottomsRest[i]
        local cf, len = segCF(chainTops[i], botW)
        chain.CFrame = cf
        chain.Size = Vector3.new(len, 0.25, 0.25)
    end
    local ropeLog = delta * ropeBottomRest
    local rcf, rlen = segCF(ropeWheelAnchor, ropeLog)
    driveRope.CFrame = rcf
    driveRope.Size = Vector3.new(rlen, 0.2, 0.2)
end

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
        -- Stage 1: swing forward (toward the bell = -BACK) to overshoot into it.
        local swing = TweenService:Create(
            arm,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { CFrame = CFrame.new(-BACK * 0.8) * restCFrame }
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
            for i = 1, 3 do
                task.delay((i - 1) * 0.22, function()
                    local ring = Instance.new("Part")
                    ring.Shape = Enum.PartType.Cylinder
                    ring.Anchored = true
                    ring.CanCollide = false
                    ring.Transparency = 0.35 + (i - 1) * 0.15
                    ring.Color = WATER
                    ring.Size = Vector3.new(0.25, 2, 2)
                    ring.CFrame = CFrame.new(gong.Position.X, 0.4, gong.Position.Z)
                        * CFrame.Angles(0, 0, math.rad(90))
                    ring.Parent = workspace
                    TweenService
                        :Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
                            Size = Vector3.new(0.25, 30 - i * 4, 30 - i * 4),
                            Transparency = 1,
                        })
                        :Play()
                    task.delay(1.5, function()
                        ring:Destroy()
                    end)
                end)
            end
            local splash = Instance.new("ParticleEmitter")
            splash.Color = ColorSequence.new(WATER)
            splash.Lifetime = NumberRange.new(0.5, 0.9)
            splash.Speed = NumberRange.new(9, 14)
            splash.SpreadAngle = Vector2.new(70, 70)
            splash.Rate = 0
            splash.Parent = gong
            splash:Emit(36)
            task.delay(1.2, function()
                splash:Destroy()
            end)
            -- Stage 2: recoil back toward the wheel (+BACK), then settle to rest.
            local recoil = TweenService:Create(
                arm,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { CFrame = CFrame.new(BACK * 1.1 + Vector3.new(0, 0.15, 0)) * restCFrame }
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
            then math.sin(os.clock() * 28) * 0.15 + (math.random() - 0.5) * 0.04
            else 0
        -- draw back toward the wheel along the SW axis (BACK), plus a slight rise
        local draw = CFrame.new(BACK * (drawZ + shiver) + Vector3.new(0, riseY, 0))
        local pose = draw * restCFrame
        if state.trembling then
            pose = pose * CFrame.Angles(0, math.rad(math.sin(os.clock() * 23) * 0.4), 0)
        end
        arm.CFrame = pose
        if state.latched and not wasLatched then
            wasLatched = true
            EventBus.Cue:Fire({ kind = "latchClick" })
        end
    end
end)

-- Chains + drive rope FOLLOW the log every frame, whether the log is posed by
-- the draw heartbeat above or moved by the strike tweens. Single authority:
-- always recompute from the log's live CFrame — never mirror offsets.
RunService.Heartbeat:Connect(updateSuspension)
