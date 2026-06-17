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
-- their bottoms ride the log; the dowels are rigid to it. All follow the log's LIVE
-- CFrame each frame (see updateSuspension) — never mirrored offsets. These constants
-- MIRROR ArenaLayout.shuMoku (build-time only). Keep in sync with ArenaLayout.luau.

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
-- Re-staged clearing: the shu-moku hangs on the clearing axis (ArenaLayout.shuMoku.yaw
-- = 0). It draws SOUTH (+Z, away from the bell at z=0) and swings North (-Z) into it.
-- (The cam now draws the log — the old wheel→log drive rope is gone.)
local BACK = Vector3.new(0, 0, 1) -- draw direction = South (+Z)

-- Chain rail tops are FIXED; bottoms ride the log. World coords mirror
-- ArenaLayout.shuMoku (no yaw): chainTops y127, chainBottomsRest y118.6.
local chainTops = {
    Vector3.new(2, 124.5, 7.5),
    Vector3.new(2, 124.5, 11.5),
    Vector3.new(-6, 124.5, 7.5),
    Vector3.new(-6, 124.5, 11.5),
}
local chainBottomsRest = {
    Vector3.new(-1.2, 118.6, 7.5),
    Vector3.new(-1.2, 118.6, 11.5),
    Vector3.new(-2.8, 118.6, 7.5),
    Vector3.new(-2.8, 118.6, 11.5),
}

-- The dowels are rigid to the log (the cam catches the draw dowel; the swing kicks the
-- drum via the east-flank dowel), so they must move WITH it. Capture their built rest
-- CFrames and re-apply the log's delta each frame.
local dowels = {
    rig:WaitForChild("ShuMokuDrawDowel") :: BasePart,
    rig:WaitForChild("ShuMokuDowel") :: BasePart,
}
local dowelRest = {}
for i, d in dowels do
    dowelRest[i] = d.CFrame
end

-- ===== Bell-engine drive train (cam + gear-down) =====
-- The river wheel's main shaft → bevel gear-down → E-W cam shaft → single-lobe cam
-- that draws the shu-moku. We rotate these parts off the SAME draw value `p` the log
-- uses, so the cam visibly creeps the log back through ACTIVE and the gear pair
-- counter-rotates at the reduction — selling the linkage as causal (theatre, not
-- physics). Axle geometry mirrors ArenaLayout.bellDrive.
local bell = stage:FindFirstChild("BellDrive")
local CAM_DRAW_DEG = 150 -- cam sweep over the full draw (tuned live)
local CAM_AXLE_YZ = Vector2.new(116, 11) -- E-W cam shaft: world-X axis through (y116, z11)
local MAIN_AXLE_XY = Vector2.new(-15, 116) -- N-S main shaft: world-Z axis through (x-15, y116)
local REDUCTION = 3.6 / 1.6 -- camR / driverR: the driver gear turns this much faster

-- Each spinner: { part, restCF, pivotCF, axis } where axis ∈ {"X","Z"}; we rotate the
-- rest pose about the world axle line through pivotCF each frame.
local camSpinners = {} -- rotate with the cam (about X), angle = p * CAM_DRAW_DEG
local driverSpinners = {} -- the fast driver gear (about Z), counter + at the reduction
local function addCamPart(name: string)
    local part = bell and bell:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        table.insert(camSpinners, {
            part = part,
            restCF = part.CFrame,
            pivotCF = CFrame.new(part.Position.X, CAM_AXLE_YZ.X, CAM_AXLE_YZ.Y),
        })
    end
end
local function addDriverPart(name: string)
    local part = bell and bell:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        table.insert(driverSpinners, {
            part = part,
            restCF = part.CFrame,
            pivotCF = CFrame.new(MAIN_AXLE_XY.X, MAIN_AXLE_XY.Y, part.Position.Z),
        })
    end
end
-- Spin every cam-shaft part (the snail cam's base + spiral planks + drop wall, and the
-- cam gear) about the E-W cam shaft. They're all named ^Cam in the builder.
if bell then
    for _, part in bell:GetChildren() do
        if part:IsA("BasePart") and part.Name:match("^Cam") then
            addCamPart(part.Name)
        end
    end
end
addDriverPart("DriverGear")

-- Recompute the 4 chains and reposition the dowels from the log's CURRENT CFrame.
local function updateSuspension()
    local delta = arm.CFrame * restCFrame:Inverse()
    for i, chain in chains do
        local botW = delta * chainBottomsRest[i]
        local cf, len = segCF(chainTops[i], botW)
        chain.CFrame = cf
        chain.Size = Vector3.new(len, 0.25, 0.25)
    end
    for i, d in dowels do
        d.CFrame = delta * dowelRest[i]
    end
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
                    ring.CFrame = CFrame.new(gong.Position.X, gong.Position.Y, gong.Position.Z)
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

-- The hammer state (draw p, latched, released) as a pure read of the live clock.
local function currentState(): HammerCurve.State
    local secondsLeft: number
    if lastPhase == "ACTIVE" then
        local lead = 2
        local toLockout = math.max(0, (secondsToLockout or 18) - (os.clock() - phaseAt))
        secondsLeft = toLockout + lead
    else
        secondsLeft = 1
    end
    return HammerCurve.state(lastPhase, secondsLeft)
end

RunService.Heartbeat:Connect(function()
    if striking then
        return
    end
    local state = currentState()
    if not state.released then
        local p = state.angleDeg / 100 -- 0..1 draw percent
        local drawZ = p * 3.5 -- drawn ~3.5 studs South — matches the cam lobe's throw
        local riseY = p * p * 0.8 -- slight pendulum rise on the suspension arc
        -- The cam holds the log steady at full draw (no human/rope "tremble") until
        -- the trip — draw straight South (BACK = +Z) with a slight rise.
        arm.CFrame = CFrame.new(BACK * drawZ + Vector3.new(0, riseY, 0)) * restCFrame
        if state.latched and not wasLatched then
            wasLatched = true
            EventBus.Cue:Fire({ kind = "latchClick" })
        end
    end
end)

-- Cam + gear-down track the SAME draw value. The cam (and cam gear) rotate about the
-- E-W shaft (world X); the driver gear counter-rotates about the main shaft (world Z)
-- at the reduction, so the mesh reads correct. Runs every frame (incl. the strike) so
-- the cam holds at the trip while the log swings, then resets next ACTIVE.
RunService.Heartbeat:Connect(function()
    local p = currentState().angleDeg / 100
    local camTheta = -math.rad(CAM_DRAW_DEG) * p -- lobe sweeps to draw the dowel back
    local rot = CFrame.Angles(camTheta, 0, 0)
    for _, s in camSpinners do
        s.part.CFrame = s.pivotCF * rot * s.pivotCF:Inverse() * s.restCF
    end
    local driverTheta = math.rad(CAM_DRAW_DEG) * p * REDUCTION -- faster, opposite sense
    local drot = CFrame.Angles(0, 0, driverTheta)
    for _, s in driverSpinners do
        s.part.CFrame = s.pivotCF * drot * s.pivotCF:Inverse() * s.restCF
    end
end)

-- Chains + drive rope FOLLOW the log every frame, whether the log is posed by
-- the draw heartbeat above or moved by the strike tweens. Single authority:
-- always recompute from the log's live CFrame — never mirror offsets.
RunService.Heartbeat:Connect(updateSuspension)
