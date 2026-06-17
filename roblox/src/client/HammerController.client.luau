--!strict
-- Animates the placeholder hammer arm from HammerCurve and fires the gong
-- placeholder on reveal. 4b swaps parts for art; the curve stays.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("RoshamboShared")
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
local bell = stage:WaitForChild("BellDrive")
local CAM_DIR = 1 -- cam-shaft spin direction (flip to reverse the cam + its gear)
-- cam mounting offset on the shaft (rotates the lobe/drop to the right clock position).
-- Tuning frame: viewed from EAST looking WEST, +angle = anti-clockwise (rotation about +X).
local CAM_PHASE = math.rad(69) -- high point lands on the dowel at full pullback (tuned); East-looking-West frame
-- The cam makes ONE continuous revolution per round (the wheel never stops, so the
-- drive train free-runs — NOT gated by the draw). Round length isn't in the payload,
-- so we measure it (ACTIVE→ACTIVE) and set ω = 2π/period; this default holds round 1.
local camOmega = 2 * math.pi / 22 -- rad/s (≈ once per 22s until measured)
local CAM_AXLE_YZ = Vector2.new(116, 11) -- E-W cam shaft: world-X axis through (y116, z11)
local MAIN_AXLE_XY = Vector2.new(-15, 116) -- N-S main shaft: world-Z axis through (x-15, y116)
local REDUCTION = 2 -- driver gear turns this much faster than the cam (integer → wraps seamlessly each round)

-- Each spinner: { part, restCF, pivotCF, axis } where axis ∈ {"X","Z"}; we rotate the
-- rest pose about the world axle line through pivotCF each frame.
local camSpinners = {} -- rotate with the cam (about X), free-running at CAM_OMEGA
local driverSpinners = {} -- the fast driver gear + main shaft (about Z), counter + at the reduction
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
-- Capture every cam-shaft part (the snail cam's base + spiral planks + drop wall, and
-- the cam gear; all named ^Cam) plus the driver gear + main shaft. Wrapped so it can be
-- RE-RUN lazily: the BellDrive model's ~148 parts replicate progressively in Play, so a
-- single init pass can race and miss them — the heartbeat re-captures until populated.
local function captureSpinners()
    table.clear(camSpinners)
    table.clear(driverSpinners)
    for _, part in bell:GetChildren() do
        if part:IsA("BasePart") and part.Name:match("^Cam") then
            addCamPart(part.Name)
        end
    end
    addDriverPart("DriverGear")
    addDriverPart("MainShaft") -- turns with the wheel (symmetric cylinder → rotation invisible, but correct)
end
captureSpinners()

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

local striking = false
local prevRoundId: any = nil -- to detect each new round and measure its period
local lastActiveAt: number? = nil -- start of the CURRENT round's ACTIVE (cam + draw anchor)
local camAngle = 0 -- the cam's live spin angle (shared so the strike can sample it)
local lastStrikeCamAngle = 0 -- cam angle captured at the last strike (for freeze-to-tune)

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        striking = false
        if info.roundId ~= prevRoundId then
            prevRoundId = info.roundId
            local nowc = os.clock()
            -- Re-measure the round period EVERY round (ACTIVE→ACTIVE) and re-anchor here.
            -- Re-anchoring each round means the cam re-zeroes per round → NO accumulated
            -- drift (the previous first-ACTIVE anchor drifted ~100°/long session). The cam
            -- completes ~one rev per round, so its orientation at the pullback-top is
            -- repeatable and the dowel alignment holds.
            if lastActiveAt then
                local period = nowc - lastActiveAt
                if period > 5 and period < 120 then -- ignore restarts / outliers
                    camOmega = 2 * math.pi / period
                end
            end
            lastActiveAt = nowc
        end
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongStrike" then
        striking = true
        lastStrikeCamAngle = camAngle -- remember the cam's pose at the strike (freeze-to-tune)
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

-- The shu-moku draws CONTINUOUSLY over the round (clock-anchored, like the cam) and is
-- still climbing when the strike interrupts it — so there is NO dwell/pause at the top.
-- p ramps 0→1 across the whole round period; the strike (gongStrike) always fires before
-- the round ends, so p is mid-climb at release and the swing takes over seamlessly.
local DRAW_STUDS = 2.9 -- South draw at p=1 (tuned so the dowel rests on the cam high point)
RunService.Heartbeat:Connect(function()
    -- DRAW HOLD (tuning): while the "DrawHold" attribute is set, pin the log at FULL draw
    -- (p=1, the top of its travel) and ignore the strike — so we can park the dowel at its
    -- pullback-top position and aim the cam's high point at it.
    local hold = stage:GetAttribute("DrawHold")
    if striking and not hold then
        return
    end
    local p
    if hold then
        p = 1
    else
        local period = if camOmega > 0 then 2 * math.pi / camOmega else 22
        p = math.clamp((os.clock() - (lastActiveAt or os.clock())) / period, 0, 1)
    end
    local studs = stage:GetAttribute("DrawStuds") or DRAW_STUDS -- live-tunable draw length
    local drawZ = p * studs
    local riseY = p * p * 0.9 -- slight pendulum rise on the suspension arc
    arm.CFrame = CFrame.new(BACK * drawZ + Vector3.new(0, riseY, 0)) * restCFrame
end)

-- Cam + gear-down run CONTINUOUSLY off the wheel — they never stop (the draw value
-- plateaus while the log is latched, so the mechanism must NOT be gated by it). The cam
-- (and cam gear) rotate about the E-W shaft (world X); the driver gear + main shaft
-- counter-rotate about the main shaft (world Z) at the reduction, so the mesh reads
-- correct. A free-running angle accumulates every frame regardless of phase.
RunService.Heartbeat:Connect(function()
    if #camSpinners == 0 then
        captureSpinners() -- parts hadn't replicated at init; keep trying until they do
    end
    -- Anchored to the CURRENT round's ACTIVE (re-zeroed each round → no accumulated drift).
    -- At the measured rate (2π/period) the cam does ~one rev/round and lands at the same
    -- orientation at the pullback-top every round, so the dowel alignment (CAM_PHASE / the
    -- live "CamPhaseDeg" attribute) holds. Wraps at 2π → seamless when the period is steady.
    -- FREEZE-TO-TUNE: while the "CamTuneFreeze" attribute is set, hold the cam at its last
    -- strike pose so the pullback-top orientation can be seen and dialed; clear it to resume.
    if stage:GetAttribute("CamTuneFreeze") then
        camAngle = lastStrikeCamAngle
    else
        camAngle = camOmega * (os.clock() - (lastActiveAt or os.clock()))
    end
    local phase = CAM_PHASE
    local override = stage:GetAttribute("CamPhaseDeg")
    if typeof(override) == "number" then
        phase = math.rad(override)
    end
    local rot = CFrame.Angles(CAM_DIR * camAngle + phase, 0, 0)
    for _, s in camSpinners do
        s.part.CFrame = s.pivotCF * rot * s.pivotCF:Inverse() * s.restCF
    end
    local drot = CFrame.Angles(0, 0, CAM_DIR * camAngle * REDUCTION) -- driver gear: faster, at the reduction
    for _, s in driverSpinners do
        s.part.CFrame = s.pivotCF * drot * s.pivotCF:Inverse() * s.restCF
    end
end)

-- Chains + drive rope FOLLOW the log every frame, whether the log is posed by
-- the draw heartbeat above or moved by the strike tweens. Single authority:
-- always recompute from the log's live CFrame — never mirror offsets.
RunService.Heartbeat:Connect(updateSuspension)
