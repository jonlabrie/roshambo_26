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

local RoundMetronome = require(shared:WaitForChild("RoundMetronome"))

-- The published round schedule (RoundScheduleConfig) drives ALL timing; see the
-- round-metronome spec. StrikeAtServerTime is written last on the server, so one
-- changed-signal on it pulls a coherent schedule.
local metronome = RoundMetronome.new()
local scheduleConfig = ReplicatedStorage:WaitForChild("RoundScheduleConfig")
local function pullSchedule()
    local strikeAt = scheduleConfig:GetAttribute("StrikeAtServerTime")
    local periodSec = scheduleConfig:GetAttribute("PeriodSec")
    if typeof(strikeAt) ~= "number" or typeof(periodSec) ~= "number" then
        return
    end
    metronome:setSchedule({
        roundId = scheduleConfig:GetAttribute("RoundId") :: string?,
        strikeAt = strikeAt,
        periodSec = periodSec,
        activeSec = (scheduleConfig:GetAttribute("ActiveSec") :: number?) or 20,
        tallySec = (scheduleConfig:GetAttribute("TallySec") :: number?) or 2,
        revealSec = (scheduleConfig:GetAttribute("RevealSec") :: number?) or 3,
    }, workspace:GetServerTimeNow())
end
scheduleConfig:GetAttributeChangedSignal("StrikeAtServerTime"):Connect(pullSchedule)
pullSchedule()

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
-- The river wheel's main shaft → face wheel → lantern pinion → E-W cam shaft →
-- snail cam that draws the shu-moku. The log's draw ramp and the cam are BOTH
-- read straight off the RoundMetronome (the published RoundScheduleConfig) each
-- frame — no measured/frozen rate, no separate anchors: drawP and omega come
-- from the same metronome:read() call, and the cam is re-pinned at every
-- scheduled strike instant — selling the linkage as causal (theatre, not physics).
-- Axle geometry mirrors ArenaLayout.bellDrive.
local bell = stage:WaitForChild("BellDrive")
local CAM_AXLE_YZ = Vector2.new(120.7, 11) -- E-W cam shaft: world-X axis through (y120.7, z11); MIRRORS ArenaLayout.bellDrive.camShaft
local MAIN_AXLE_XY = Vector2.new(-15, 116) -- N-S main shaft: world-Z axis through (x-15, y116)
local JACK_AXLE_XZ = Vector2.new(-15, 11) -- vertical lantern arbor: world-Y axis through (x-15, z11), the shafts' plan crossing; MIRRORS ArenaLayout.bellDrive.lantern
local JACK_DIR = 1 -- gear-corner handedness (gate-flipped from -1; live via "JackDir")
local LANTERN_RATIO = 12 / 9 -- cogsMain/staves: the lantern spins this much faster than the main shaft
local REDUCTION = 2 -- driver gear turns this much faster than the cam (integer → wraps seamlessly each round)
local CAM_PHASE_DEG = -5 -- fine-tune offset for the high point at the strike (gate-tuned
-- live 2026-07-23: -5 lands the cliff on the release; each -7 ≈ +0.5s at the ~25s round).
-- Live-tunable via the stage "CamPhaseDeg" attribute. The metronome's slew keeps schedule
-- refinements from stepping the cam; only a hard re-anchor (restart/new period) snaps it.

-- Each spinner: { part, restCF, pivotCF, axis } where axis ∈ {"X","Z"}; we rotate the
-- rest pose about the world axle line through pivotCF each frame.
local camSpinners = {} -- rotate with the cam (about X), free-running at the metronome's omega
local driverSpinners = {} -- the fast driver gear + main shaft (about Z), counter + at the reduction
local jackSpinners = {} -- the vertical jack shaft + its bevels (about Y), at the driver rate
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
local function addJackPart(name: string)
    local part = bell and bell:FindFirstChild(name)
    if part and part:IsA("BasePart") then
        table.insert(jackSpinners, {
            part = part,
            restCF = part.CFrame,
            pivotCF = CFrame.new(JACK_AXLE_XZ.X, part.Position.Y, JACK_AXLE_XZ.Y),
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
    table.clear(jackSpinners)
    for _, part in bell:GetChildren() do
        if part:IsA("BasePart") and part.Name:match("^Cam") then
            addCamPart(part.Name)
        end
        if part:IsA("BasePart") and (part.Name:match("^JackShaftF") or part.Name:match("^JackLantern")) then
            addJackPart(part.Name) -- NOT bare ^Jack: JackFrame*/JackBand* are static
        end
    end
    -- MainShaft (the invisible proxy) plus its MainShaftF* octagon flats — the visible
    -- faceted prism whose turning reads (a smooth cylinder's rotation was invisible) —
    -- plus the toothed bevel at the jack corner.
    for _, part in bell:GetChildren() do
        if part:IsA("BasePart") and (part.Name:match("^MainShaft") or part.Name:match("^FaceWheelMain")) then
            addDriverPart(part.Name)
        end
    end
end
captureSpinners()

-- SMOOTH CAM FLANK: a client-built EditableMesh (CamMesh geometry) — EditableMesh
-- parts don't replicate server→client and Rojo JSON can't carry mesh geometry, so
-- each client assembles its own and it joins the cam spin group directly (inserted
-- by hand, NOT via captureSpinners: a late re-capture would re-baseline every
-- spinner's rest pose mid-rotation). Falls back silently to the bare hub if the
-- EditableMesh APIs are unavailable.
task.spawn(function()
    local ok, err = pcall(function()
        local CamMesh = require(shared:WaitForChild("CamMesh")) :: any
        local camHub = bell:WaitForChild("Cam") :: BasePart
        -- geometry mirrors ArenaLayout.bellDrive/shuMoku (build-time constants;
        -- draw also mirrors DRAW_STUDS, declared later in this file)
        -- clearance 0.35 = 0.1 slew hair + 0.25 dowel-radius shave (gate-measured:
        -- the analytic path assumes contact out to full draw p=1, but the metronome
        -- strike lands at drawP=(active+tally)/period ~= 0.88, so the flank ran
        -- proud by ~one dowel radius and buried the face to the dowel's center).
        local G = { gapZ = 2.2, draw = 3.0, rise = 0.45, dowelR = 0.25, dropDeg = 12, clearance = 0.35 }
        local mesh = CamMesh.build(G, 64, 0.35) -- halfWidth = camWidth/2
        local AssetService = game:GetService("AssetService")
        local em = AssetService:CreateEditableMesh()
        local vids = table.create(#mesh.verts)
        local nids = table.create(#mesh.normals)
        for i, v in mesh.verts do
            vids[i] = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
            nids[i] = em:AddNormal(Vector3.new(mesh.normals[i][1], mesh.normals[i][2], mesh.normals[i][3]))
        end
        for _, t in mesh.tris do
            local f = em:AddTriangle(vids[t[1]], vids[t[2]], vids[t[3]])
            em:SetFaceNormals(f, { nids[t[1]], nids[t[2]], nids[t[3]] })
        end
        local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
        part.Name = "CamMeshFlank" -- ^Cam by name, but inserted into the spin group by hand
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Wood
        part.MaterialVariant = "CypressWeathered"
        part.Color = Color3.new(
            ZenDojo.palette.cypressWeathered[1],
            ZenDojo.palette.cypressWeathered[2],
            ZenDojo.palette.cypressWeathered[3]
        )
        local restCF = CFrame.new(camHub.Position) -- axle-centred, local axes = world (mesh built about the axle)
        part.CFrame = restCF
        part.Parent = bell
        table.insert(camSpinners, { part = part, restCF = restCF, pivotCF = CFrame.new(camHub.Position) })
    end)
    if not ok then
        warn("[HammerController] cam mesh flank unavailable, hub only:", err)
    end
end)

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
-- The cam is anchored to the RELEASE (strike) event, not ACTIVE: at each strike we set its
-- orientation so the high point is exactly on the dowel, then it free-runs at the metronome's
-- omega until the next strike. This makes the high point meet the dowel at EVERY release
-- regardless of network jitter — the strike itself is self-timed off the metronome's schedule,
-- not off any server event. anchorNet = cam net rotation pinned at the last strike; anchorAt =
-- the SCHEDULED strike instant (metronome prevStrikeAt), not the frame time it was noticed.
local anchorNet: number? = nil
local anchorAt: number? = nil
local lastMetroNow: number? = nil

RoundUpdate.OnClientEvent:Connect(function(info)
    if info.phase == "ACTIVE" then
        striking = false -- new round: the draw ramp owns the log again
    end
end)

-- The strike is SELF-TIMED from the metronome (spec: strike on schedule; late
-- reveal data is absorbed by the drum, never by the bell). `atTime` is the
-- scheduled strike instant: the cam anchors there, not at frame time.
local function strike(atTime: number)
    striking = true
    -- Pin the cam so its high point is on the dowel at THIS release. The high point
    -- points along the cam's net rotation, so set net = the dowel's current world-angle
    -- about the axle (+ a small fine-tune offset). It free-runs from here until the next.
    local dp = dowels[1].Position
    local fineDeg = (stage:GetAttribute("CamPhaseDeg") :: number) or CAM_PHASE_DEG
    anchorNet = math.atan2(dp.Z - CAM_AXLE_YZ.Y, dp.Y - CAM_AXLE_YZ.X) + math.rad(fineDeg)
    anchorAt = atTime
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
                TweenService:Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
                    Size = Vector3.new(0.25, 30 - i * 4, 30 - i * 4),
                    Transparency = 1,
                }):Play()
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

-- The shu-moku draws CONTINUOUSLY over the round (metronome-anchored, like the cam) and is
-- still climbing when the self-timed strike interrupts it — so there is NO dwell/pause at
-- the top. p (drawP from the metronome) ramps 0→1 across the whole round period, and the
-- strike always fires before the round ends, so p is mid-climb at release and the swing
-- takes over seamlessly.
local DRAW_STUDS = 3.0 -- South draw at p=1; MIRRORS ArenaLayout.shuMoku.drawStuds (the cam flank is generated from it — keep DrawStuds attr ≤ it)
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
        local r = metronome:read(workspace:GetServerTimeNow())
        if not r then
            return -- no schedule yet: hold rest pose
        end
        p = r.drawP
    end
    local studs = stage:GetAttribute("DrawStuds") or DRAW_STUDS -- live-tunable draw length
    local drawZ = p * studs
    local riseY = p * p * 0.45 -- pendulum rise on the arc; MIRRORS ArenaLayout.bellDrive.camDowelRise
    arm.CFrame = CFrame.new(BACK * drawZ + Vector3.new(0, riseY, 0)) * restCFrame
end)

-- CONSTANT-SPEED cam. The cam turns continuously at the metronome's rate (omega = 2π/period),
-- RE-PINNED at each strike so the high point is on the dowel at every release — the strike
-- is now self-timed off the metronome's schedule (no ACTIVE/reveal event jitter to inherit);
-- before this client's first strike it free-runs phase-locked to the strike instants as a
-- fallback. The ONLY timing constraint is the high point at release — set by CAM_PHASE
-- (live-tunable via the "CamPhaseDeg" attribute, degrees). Everything else is sold by the cam
-- PROFILE, not by coupling. CAM_DIR flips the spin direction.
local CAM_DIR = 1
local DRIVER_DIR = 1 -- sign of the driver gear + main shaft about Z (live-tunable "DriverDir")
-- Publish the live-tunable knobs so they're visible/editable on RoshamboStage in the
-- Explorer during Play — a read-only GetAttribute never materialises in the panel
-- (only already-set attributes show; DriveOmega shows because we publish it).
for attr, default in
    { CamPhaseDeg = CAM_PHASE_DEG, DrawStuds = DRAW_STUDS, JackDir = JACK_DIR, DriverDir = DRIVER_DIR } :: { [string]: number }
do
    if stage:GetAttribute(attr) == nil then
        stage:SetAttribute(attr, default)
    end
end
RunService.Heartbeat:Connect(function()
    if #camSpinners == 0 then
        captureSpinners() -- parts hadn't replicated at init; keep trying until they do
    end
    local nowSt = workspace:GetServerTimeNow()
    local r = metronome:read(nowSt)
    if r == nil then
        return
    end
    if lastMetroNow and not striking and metronome:strikesBetween(lastMetroNow, nowSt) > 0 then
        strike(r.prevStrikeAt)
    end
    lastMetroNow = nowSt
    -- Self-timed backstop: RoundUpdate("ACTIVE") normally clears `striking`, but a
    -- dropped broadcast must not freeze the machine (spec: it never stops). Clear once
    -- the next round's ramp is underway — drawP has wrapped low — never mid-REVEAL
    -- (releasing early would slam the log back to near-full draw before the wrap).
    if striking and anchorAt and nowSt - anchorAt > 2 and r.drawP < 0.5 then
        striking = false
    end
    -- Free-run at constant speed FROM the last release anchor (so the high point is on the
    -- dowel at each strike, by construction).
    local camNet
    if anchorNet and anchorAt then
        camNet = anchorNet + CAM_DIR * r.omega * (nowSt - anchorAt)
    else
        -- before this client's first strike: constant-speed free-run, phase-locked
        -- to the strike instants (high point lands near the dowel from round one)
        camNet = CAM_DIR * r.camAngle
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
    -- Jack shaft: 1:1 off the main shaft through the corner bevel, spun about world Y.
    local jackDir = (stage:GetAttribute("JackDir") :: number) or JACK_DIR
    local jrot = CFrame.Angles(0, jackDir * driverDir * camNet * REDUCTION * LANTERN_RATIO, 0)
    for _, s in jackSpinners do
        s.part.CFrame = s.pivotCF * jrot * s.pivotCF:Inverse() * s.restCF
    end
    stage:SetAttribute("DriveOmega", driverDir * CAM_DIR * r.omega * REDUCTION) -- rad/s about Z, for the wheel
end)

-- Chains + drive rope FOLLOW the log every frame, whether the log is posed by
-- the draw heartbeat above or moved by the strike tweens. Single authority:
-- always recompute from the log's live CFrame — never mirror offsets.
RunService.Heartbeat:Connect(updateSuspension)
