--!strict
-- Continuously spins the waterwheels. The creek always flows, so the wheels never
-- stop — they kept turning through the round before, then froze on the lockout
-- "ratchet", which read wrong (a live stream with stalled wheels). The striker's
-- draw/latch is driven by the clock (RoundMetronome), not the wheel's real rotation,
-- so the two are decoupled and the wheels just turn forever.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))
local AmbientConfig = require(script.Parent:WaitForChild("AmbientConfig"))

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Waterwheel")

-- Spin every Wheel{n} about its own axle with everything that rides it: the paddles
-- plus the Wheel{n}T_* timber-lattice parts (rims/spokes/braces/treads/hub — Wheel{n}
-- itself is the invisible full-diameter proxy the assembly is captured against).
type Spin = { part: BasePart, hub: CFrame, paddles: { BasePart }, offsets: { CFrame } }
local spins: { Spin } = {}
for _, child in rig:GetChildren() do
    local wi = child.Name:match("^Wheel(%d+)$")
    if wi then
        local wheel = child :: BasePart
        local s: Spin = { part = wheel, hub = wheel.CFrame, paddles = {}, offsets = {} }
        for _, p in rig:GetChildren() do
            if p.Name:match(`^Paddle{wi}_%d+$`) or p.Name:match(`^Wheel{wi}T_`) then
                table.insert(s.paddles, p :: BasePart)
                table.insert(s.offsets, wheel.CFrame:ToObjectSpace((p :: BasePart).CFrame))
            end
        end
        table.insert(spins, s)
    end
end

-- Undershot water strike. The old single emitter hung off the SPINNING Wheel1 proxy, so
-- its attachment orbited the rim and sprayed nonstop from one paddle station. The strike
-- is a FIXED place in the world: two static attachments on the (non-spinning) axle where
-- the waterline crosses the wheel — a low constant churn on each, plus a splash BURST
-- each time a paddle sweeps past (paddles are equally spaced, so bursts fire every
-- 2π/paddleCount of rotation with no per-paddle bookkeeping). Emit() must be client-side
-- to render at all, which this LocalScript is.
local axle = rig:FindFirstChild("Axle1") :: BasePart?
local driver = rig:FindFirstChild("Wheel1") :: BasePart?
local bursts: { ParticleEmitter } = {}
local paddleCount = 0
for _, p in rig:GetChildren() do
    if p.Name:match("^Paddle1_%d+$") then
        paddleCount += 1
    end
end
if axle and driver then
    local R = driver.Size.Y / 2
    local waterY = (stage:GetAttribute("WheelWaterY") :: number) or 110 -- live-tunable
    local axleP = axle.Position
    local dy = math.clamp(waterY - axleP.Y, -R + 0.5, -0.5) -- waterline sits below the axle
    local half = math.sqrt(math.max(R * R - dy * dy, 1)) - 0.4 -- waterline chord half-width
    local axleDir = axle.CFrame.RightVector -- cylinder long axis
    local horiz = axleDir:Cross(Vector3.yAxis)
    horiz = horiz.Magnitude > 0.1 and horiz.Unit or Vector3.xAxis
    -- The VFX are the river/falls vocabulary (official waterfall recipe, tuned to the
    -- ZenDojo chute scale): TurbulentWW churn + gravity-arcing SplashDense strike bursts
    -- + flat foam ripples on the surface. Per-side Rate/Lifetime factors desync the two
    -- spots so they don't pulse in unison (emitters have no phase property).
    local waterBlue = ColorSequence.new(Color3.fromRGB(189, 246, 255), Color3.new(1, 1, 1))
    for si, sx in { -1, 1 } do
        local rateF = si == 1 and 0.9 or 1.12
        local lifeF = si == 1 and 0.95 or 1.05
        local att = Instance.new("Attachment")
        att.Parent = axle
        att.WorldPosition = axleP + horiz * (sx * half) + Vector3.new(0, dy + 0.2, 0)
        local churn = Instance.new("ParticleEmitter")
        churn.Texture = "rbxassetid://16808075391" -- whitewater
        churn.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.96, 0.34),
            NumberSequenceKeypoint.new(1, 1.58, 0.34),
        })
        churn.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.156, 0.044),
            NumberSequenceKeypoint.new(0.55, 0.075),
            NumberSequenceKeypoint.new(1, 1),
        })
        churn.Lifetime = NumberRange.new(0.25 * lifeF, 0.5 * lifeF)
        churn.Rate = 7.5 * rateF
        churn.Rotation = NumberRange.new(-45, 45)
        churn.RotSpeed = NumberRange.new(-40, 40)
        churn.Speed = NumberRange.new(3, 3.6)
        churn.SpreadAngle = Vector2.new(15, 15)
        churn.Acceleration = Vector3.new(0, -19.5, 0)
        churn.LightEmission = 0.6
        churn.LightInfluence = 0.1
        churn.Color = waterBlue
        churn.Parent = att
        local burst = Instance.new("ParticleEmitter")
        burst.Texture = "rbxassetid://16829556885" -- dense aerosolized splash
        burst.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.7, 0.2),
            NumberSequenceKeypoint.new(1, 2.0, 0.45),
        })
        burst.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.18),
            NumberSequenceKeypoint.new(1, 1),
        })
        burst.Lifetime = NumberRange.new(0.25, 0.35)
        burst.Rate = 0 -- burst-only: Emit() on each paddle strike
        burst.Rotation = NumberRange.new(-45, 45)
        burst.RotSpeed = NumberRange.new(-40, 40)
        burst.Speed = NumberRange.new(3, 5)
        burst.SpreadAngle = Vector2.new(35, 35)
        burst.Acceleration = Vector3.new(0, -40, 0) -- splash arcs and FALLS BACK to the water
        burst.LightEmission = 0.5
        burst.LightInfluence = 0.1
        burst.Color = waterBlue
        burst.Parent = att
        table.insert(bursts, burst)
        -- foam ripples lying flat on the surface: VelocityPerpendicular + a small UP
        -- velocity (near-zero speed goes invisible — it needs a vector to orient to)
        local foamAtt = Instance.new("Attachment")
        foamAtt.Parent = axle
        foamAtt.WorldPosition = axleP + horiz * (sx * half) + Vector3.new(0, dy + 0.05, 0)
        local foam = Instance.new("ParticleEmitter")
        foam.Texture = "rbxassetid://16811365086"
        foam.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
        foam.Size = NumberSequence.new(2, 3.5)
        foam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.143, 0.119),
            NumberSequenceKeypoint.new(0.664, 0.125),
            NumberSequenceKeypoint.new(1, 1),
        })
        foam.Lifetime = NumberRange.new(0.5 * lifeF, 0.7 * lifeF)
        foam.Rate = 5 * rateF
        foam.Rotation = NumberRange.new(0, 360)
        foam.RotSpeed = NumberRange.new(-15, 15)
        foam.Speed = NumberRange.new(0.8, 1.0)
        foam.SpreadAngle = Vector2.new(0, 0)
        foam.Acceleration = Vector3.zero
        foam.LightEmission = 0.25
        foam.LightInfluence = 0
        foam.Parent = foamAtt
    end
end

local angle = 0
local FALLBACK_OMEGA = 0.5 -- rad/s until HammerController publishes the real shaft rate (signed for WHEEL_DIR below)
local WHEEL_DIR = -1 -- maps the published shaft ω onto the wheel's local axle (live-tunable "WheelDir")
local lastStrike: { number } = { math.huge, math.huge } -- per-side paddle-boundary counters
local acc = 0

-- Range/view for the wheel itself, anchored on the first spin group's hub.
local function drawable(c: AmbientBudget.Config): boolean
    if #spins == 0 then
        return false
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return false
    end
    local camCF = cam.CFrame
    local d = spins[1].hub.Position - camCF.Position
    local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
    if not AmbientBudget.inRange(distSq, c) then
        return false
    end
    local dist = math.sqrt(distSq)
    local look = camCF.LookVector
    local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
    return AmbientBudget.inView(fdot, c)
end

RunService.Heartbeat:Connect(function(dt)
    -- The wheel IS the driver gear's shaft, so it turns at the EXACT angular velocity the
    -- bell-engine drive publishes ("DriveOmega", rad/s about Z) — matched rate + direction,
    -- not a free constant that out-runs the gears. WHEEL_DIR corrects the wheel's local axle
    -- orientation; flip it (or "DriverDir") live to fix the spin direction.
    local driveOmega = (stage:GetAttribute("DriveOmega") :: number) or FALLBACK_OMEGA
    local wheelDir = (stage:GetAttribute("WheelDir") :: number) or WHEEL_DIR
    -- ⚠ INTEGRATED, so it advances EVERY frame whether or not the wheel is drawn. Freezing it while
    -- the player looks away would bring the wheel back at a stale phase.
    angle += dt * driveOmega * wheelDir

    local c = AmbientConfig.arena()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    local visible = drawable(c)
    if fire and visible then
        -- ONE WRITE PER WHEEL. The timbers and paddles are welded to this proxy at server boot
        -- (see main.server.luau), so the engine carries them; this loop used to write 266
        -- individual part CFrames every frame to do the same thing.
        --
        -- `s.paddles` and `s.offsets` are still captured at startup and are now unused by the
        -- spin. They are kept deliberately: the offsets are the exact relative poses the weld
        -- now holds, so restoring the per-part write is a two-line revert if the weld ever has
        -- to come out. Delete them only together with that option.
        for _, s in spins do
            s.part.CFrame = s.hub * CFrame.Angles(angle, 0, 0)
        end
    end
    -- splash when a paddle strikes the waterline: one boundary per 2π/paddleCount of
    -- rotation; the two sides (enter/exit) are offset half a bay so they alternate.
    --
    -- ⚠ RUNS EVERY FRAME AND ALWAYS UPDATES lastStrike, even when culled. Only the Emit is gated:
    -- skipping the bookkeeping would bank a boundary and splash on re-entry for a strike the player
    -- never saw.
    if paddleCount > 0 then
        local spacing = 2 * math.pi / paddleCount
        for side, b in bursts do
            local k = math.floor((angle + (side - 1) * spacing / 2) / spacing)
            if k ~= lastStrike[side] then
                if lastStrike[side] ~= math.huge and visible then
                    b:Emit(3)
                end
                lastStrike[side] = k
            end
        end
    end
end)
