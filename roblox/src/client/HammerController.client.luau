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

-- Rope tops are FIXED on the tower spreaders; bottoms ride the log. World coords
-- mirror ArenaLayout.shuMoku (no yaw): chainTops y132, chainBottomsRest y121.3.
local chainTops = {
    Vector3.new(2, 130.25, 7.5),
    Vector3.new(2, 130.25, 11.5),
    Vector3.new(-6, 130.25, 7.5),
    Vector3.new(-6, 130.25, 11.5),
}
local chainBottomsRest = {
    Vector3.new(-1.2, 121.3, 7.5),
    Vector3.new(-1.2, 121.3, 11.5),
    Vector3.new(-2.8, 121.3, 7.5),
    Vector3.new(-2.8, 121.3, 11.5),
}

-- The dowels are rigid to the log (the cam catches the draw dowel; the swing kicks the
-- drum via the east-flank dowel), so they must move WITH it. Capture their built rest
-- CFrames and re-apply the log's delta each frame.
local dowels = {
    rig:WaitForChild("ShuMokuDrawDowel") :: BasePart,
    rig:WaitForChild("ShuMokuDowel") :: BasePart,
    -- full-dress fittings (2026-07-23): rigid to the log exactly like the dowels
    rig:WaitForChild("ShuMokuD_Nose") :: BasePart,
    rig:WaitForChild("ShuMokuD_Band1") :: BasePart,
    rig:WaitForChild("ShuMokuD_Band2") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip1") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip1b") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip1c") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip2") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip2b") :: BasePart,
    rig:WaitForChild("ShuMokuD_Whip2c") :: BasePart,
    rig:WaitForChild("ShuMokuD_TailRing") :: BasePart,
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
-- The cam is mechanically COUPLED to the draw (see the coupled-cam heartbeat below); it
-- no longer free-runs. camOmega is the measured round rate, kept only to time the DRAW
-- ramp (p = elapsed/period). Round length isn't in the payload, so we measure it
-- (ACTIVE→ACTIVE) and set ω = 2π/period; this default holds round 1.
local camOmega = 2 * math.pi / 22 -- rad/s (≈ once per 22s until measured)
local CAM_AXLE_YZ = Vector2.new(116, 11) -- E-W cam shaft: world-X axis through (y116, z11)
local MAIN_AXLE_XY = Vector2.new(-15, 116) -- N-S main shaft: world-Z axis through (x-15, y116)
local REDUCTION = 2 -- driver gear turns this much faster than the cam (integer → wraps seamlessly each round)
local CAM_PHASE_DEG = 0 -- fine-tune offset for the high point at the strike (0 = peak exactly on the dowel)

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
    -- MainShaft (the invisible proxy) plus its MainShaftF* octagon flats — the visible
    -- faceted prism whose turning reads (a smooth cylinder's rotation was invisible).
    for _, part in bell:GetChildren() do
        if part:IsA("BasePart") and part.Name:match("^MainShaft") then
            addDriverPart(part.Name)
        end
    end
end
captureSpinners()

-- Recompute the 4 chains and reposition the dowels from the log's CURRENT CFrame.
local function updateSuspension()
    local delta = arm.CFrame * restCFrame:Inverse()
    for i, chain in chains do
        local botW = delta * chainBottomsRest[i]
        local cf, len = segCF(chainTops[i], botW)
        chain.CFrame = cf
        chain.Size = Vector3.new(len, 0.22, 0.22) -- hemp-rope cross-section (matches the builder)
    end
    for i, d in dowels do
        d.CFrame = delta * dowelRest[i]
    end
end

local striking = false
local prevRoundId: any = nil -- to detect each new round and measure its period
local lastActiveAt: number? = nil -- start of the CURRENT round's ACTIVE (draw ramp anchor)
local omegaLocked = false -- freeze the rate after one good sample (constant ω between strikes)
-- The cam is anchored to the RELEASE (strike) event, not ACTIVE: at each strike we set its
-- orientation so the high point is exactly on the dowel, then it free-runs at camOmega until
-- the next strike. This makes the high point meet the dowel at EVERY release regardless of
-- the independent network jitter between the ACTIVE and reveal events. anchorNet = cam net
-- rotation pinned at the last strike; anchorAt = when.
local anchorNet: number? = nil
local anchorAt: number? = nil

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        striking = false
        if info.roundId ~= prevRoundId then
            prevRoundId = info.roundId
            local nowc = os.clock()
            -- Measure the period ONCE (ACTIVE→ACTIVE), then FREEZE the rate. Re-measuring
            -- every round let tiny period jitter wobble the cam's accumulated angle by the
            -- strike (~±10°). A constant ω + the per-round re-anchor below = stable strike
            -- orientation (no wobble) AND no long-term drift.
            if lastActiveAt and not omegaLocked then
                local period = nowc - lastActiveAt
                if period > 5 and period < 120 then -- ignore restarts / outliers
                    camOmega = 2 * math.pi / period
                    omegaLocked = true
                end
            end
            lastActiveAt = nowc
        end
    end
end)

EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongStrike" then
        striking = true
        -- Pin the cam so its high point is on the dowel at THIS release. The high point
        -- points along the cam's net rotation, so set net = the dowel's current world-angle
        -- about the axle (+ a small fine-tune offset). It free-runs from here until the next.
        local dp = dowels[1].Position
        local fineDeg = (stage:GetAttribute("CamPhaseDeg") :: number) or CAM_PHASE_DEG
        anchorNet = math.atan2(dp.Z - 11, dp.Y - 116) + math.rad(fineDeg)
        anchorAt = os.clock()
        -- Stage 1: swing forward (toward the bell = -BACK) to overshoot into it.
        local swing = TweenService:Create(
            arm,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { CFrame = CFrame.new(-BACK * 0.8) * restCFrame }
        )
        swing.Completed:Connect(function()
            -- Contact moment (the actual strike): the dowel kicks the pin-wheel HERE, not at
            -- the swing's start — fire a "gongHit" cue so the drum spins on contact, not early.
            EventBus.Cue:Fire({ kind = "gongHit" })
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
local DRAW_STUDS = 4.06 -- South draw at p=1 (tuned so the dowel rests on the cam high point at the strike)
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

-- CONSTANT-SPEED cam. The cam turns continuously at the round rate (camOmega = 2π/period),
-- anchored to the CURRENT round's ACTIVE so it re-zeroes each round (no accumulated drift)
-- and reaches the SAME orientation at the strike every round. The ONLY timing constraint is
-- that the high point is on the dowel at the moment of release (the strike) — set by CAM_PHASE
-- (live-tunable via the "CamPhaseDeg" attribute, degrees). Everything else is sold by the cam
-- PROFILE, not by coupling. CAM_DIR flips the spin direction.
local CAM_DIR = 1
local DRIVER_DIR = 1 -- sign of the driver gear + main shaft about Z (live-tunable "DriverDir")
RunService.Heartbeat:Connect(function()
    if #camSpinners == 0 then
        captureSpinners() -- parts hadn't replicated at init; keep trying until they do
    end
    -- Free-run at constant speed FROM the last release anchor (so the high point is on the
    -- dowel at each strike, by construction). Before the first strike, free-run from ACTIVE.
    local camNet
    if anchorNet and anchorAt then
        camNet = anchorNet + CAM_DIR * camOmega * (os.clock() - anchorAt)
    else
        camNet = CAM_DIR * camOmega * (os.clock() - (lastActiveAt or os.clock()))
    end
    local rot = CFrame.Angles(camNet, 0, 0)
    for _, s in camSpinners do
        s.part.CFrame = s.pivotCF * rot * s.pivotCF:Inverse() * s.restCF
    end
    -- Driver gear + main shaft are CO-AXIAL with the waterwheel (one N-S shaft), so they
    -- turn at the cam rate × REDUCTION. We publish that shaft's signed angular velocity so
    -- WheelController can LOCK the wheel to it (matched rate + direction) instead of
    -- free-spinning at its own constant. DRIVER_DIR flips the whole shaft live.
    local driverDir = (stage:GetAttribute("DriverDir") :: number) or DRIVER_DIR
    local drot = CFrame.Angles(0, 0, driverDir * camNet * REDUCTION)
    for _, s in driverSpinners do
        s.part.CFrame = s.pivotCF * drot * s.pivotCF:Inverse() * s.restCF
    end
    stage:SetAttribute("DriveOmega", driverDir * CAM_DIR * camOmega * REDUCTION) -- rad/s about Z, for the wheel
end)

-- Chains + drive rope FOLLOW the log every frame, whether the log is posed by
-- the draw heartbeat above or moved by the strike tweens. Single authority:
-- always recompute from the log's live CFrame — never mirror offsets.
RunService.Heartbeat:Connect(updateSuspension)
